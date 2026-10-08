# EventRunner Agent — English → EventScript Rule Compiler

> Status: **Specification (draft)** — nothing in this document is implemented yet.
> It describes a Python application that turns plain-English home automation
> requests into validated EventRunner7 (ER) rules, with agent-assisted conflict
> resolution, and deploys them to a Fibaro HC3.

## Table of Contents

- [1. Goal](#1-goal)
- [2. Design principles](#2-design-principles)
- [3. Architecture](#3-architecture)
- [4. Components](#4-components)
  - [4.1 HC3 Context Provider](#41-hc3-context-provider)
  - [4.2 Agent Provider abstraction](#42-agent-provider-abstraction)
  - [4.3 RuleIntent schema](#43-ruleintent-schema)
  - [4.4 EventScript Compiler](#44-eventscript-compiler)
  - [4.5 Validator (plua bridge)](#45-validator-plua-bridge)
  - [4.6 Conflict Analyzer](#46-conflict-analyzer)
  - [4.7 Simulator (dry-run)](#47-simulator-dry-run)
  - [4.8 Deployer](#48-deployer)
- [5. Pipeline](#5-pipeline)
- [6. Conflict taxonomy](#6-conflict-taxonomy)
- [7. Safety & human-in-the-loop](#7-safety--human-in-the-loop)
- [8. Project layout](#8-project-layout)
- [9. Roadmap (phased)](#9-roadmap-phased)
- [10. Open questions](#10-open-questions)

---

## 1. Goal

ER rules are powerful but require users to learn EventScript, device property
names, trigger syntax, and rule modifiers. Small mistakes produce rules that
silently do the wrong thing (see the `trueFor` timing bug, 2026-08) or never
fire.

The **EventRunner Agent** is a Python app that:

1. Accepts home automation requests in plain English
   ("when there is motion in the kitchen after sunset, turn on the kitchen
   light for 5 minutes").
2. Compiles them into validated EventScript rules.
3. Retrieves device/type/status context from the HC3 so the agent can map
   names like "kitchen light" to real device IDs and properties.
4. Analyzes the new rule against existing rules, detects conflicts and
   inconsistencies, and resolves them in dialogue with the user.
5. Optionally dry-runs the resulting rule set in simulation before deploying.
6. Deploys the rules to the EventRunner7 QuickApp on the HC3.

The output of the tool is **not** freeform code — it is a small set of
structured `RuleIntent` JSON documents that a deterministic Python compiler
turns into EventScript. The LLM/agent only does natural-language understanding,
explanation, and conflict dialogue; correctness of the emitted language is the
compiler's job.

## 2. Design principles

1. **LLM does NLU, not code generation.**
   The agent produces structured intents (`RuleIntent`, §4.3). A deterministic
   compiler maps intents to EventScript. The agent never emits EventScript text.
   This is the primary guard against "rules that look right but aren't".

2. **ER's own parser is the validator.**
   Validity is checked by running the generated rules through EventRunner's
   real parser/compiler via `plua` (offline), not by a Python reimplementation.
   A rule is only valid if `er.eval(...)` accepts it.

3. **Offline-first.**
   Context gather and deploy are the only steps that need the HC3. Compilation,
   validation, conflict analysis, and simulation all run offline (plua +
   `src/Sim.lua`).

4. **Human-in-the-loop.**
   The tool proposes, previews, and explains. It never deploys without explicit
   confirmation. Every deploy is versioned and reversible.

5. **Pluggable agents.**
   The agent behind the NLU is an interface, not a dependency (§4.2). Providers
   include OpenAI-compatible endpoints (OpenAI, DeepSeek, Ollama, llama.cpp,
   local models), Anthropic, macOS 26+/27 built-in LLM (Apple Foundation Models
   framework, details TBD), and a deterministic no-LLM fallback.

6. **Graceful degradation.**
   Without any LLM configured, the deterministic provider still handles common
   phrasing patterns. LLM providers extend coverage; they don't gate the tool.

## 3. Architecture

```
                        ┌──────────────────────────────────────────────┐
                        │                Python app (CLI)              │
                        │                                              │
  HC3 ── REST ──────────►  Context Provider ── ContextBundle ──────────┤
                        │        │                                     │
  user: "when motion    │        ▼                                     │
  in kitchen after     │   Agent Provider ◄── English + ContextBundle  │
  sunset, turn on      │   (pluggable)                                  │
  the light 5 min" ────┤        │  RuleIntent JSON                      │
                        │        ▼                                     │
                        │   EventScript Compiler (deterministic)       │
                        │        │  EventScript rule strings            │
                        │        ▼                                     │
                        │   Validator (plua, offline)                  │
                        │        │  valid?  ──no──► repair loop ──► agent
                        │        ▼  yes                                │
                        │   Conflict Analyzer (static + agent)         │
                        │        │  conflict list / explanations       │
                        │        ▼                                     │
                        │   Simulator (plua + Sim.lua, optional)       │
                        │        │  dry-run trace                      │
                        │        ▼                                     │
                        │   Deployer (quickApp files API, versioned)   │
                        └──────────────┬───────────────────────────────┘
                                       ▼
                        HC3 EventRunner7 QuickApp (PUT main + restart)
```

## 4. Components

### 4.1 HC3 Context Provider

A thin REST client (`httpx`) that builds a `ContextBundle` — the single JSON
document handed to the agent. Credentials come from the same `.env` convention
plua uses (`HC3_URL`, username/password).

Sources (all documented in `.github/skills/hc3-rest-api/SKILL.md`):

| Purpose | Endpoint |
|---|---|
| All devices (id, name, type, roomID) | `GET /api/devices` |
| Filtered devices | `/api/devices?type=com.fibaro.binarySwitch`, `?roomID=5`, `?interface=quickApp` |
| Device detail + current state | `GET /api/devices/{id}`, `/api/devices/{id}/properties` |
| Rooms | `GET /api/rooms` |
| Scenes | `GET /api/scenes` |
| Global variables (ER globals, modes) | `GET /api/globalVariables` |
| ER QuickApp variables | `GET /api/plugins/{id}/variables` |
| Location (for sunrise/sunset context) | `GET /api/settings/location` |
| Custom events | `GET /api/customEvents` |
| Weather | `GET /api/weather` |
| Existing rules | read from the ER QuickApp main file: `GET /api/quickApp/{id}/files/main` |

`ContextBundle` shape (summary form — full device dumps are kept as an appendix
so the prompt can stay small):

```json
{
  "location": {"latitude": 59.3, "longitude": 18.0},
  "devices": [
    {"id": 54, "name": "Kitchen light", "type": "com.fibaro.binarySwitch",
     "room": "Kitchen", "props": {"value": false, "power": 12.4}}
  ],
  "rooms": [{"id": 1, "name": "Kitchen"}],
  "scenes": [{"id": 10, "name": "Good night"}],
  "globals": {"HomeMode": "Away"},
  "sun": {"sunrise": "03:31", "sunset": "21:14"},
  "existingRules": [
    {"src": "kitchen.motion:breached => kitchen.light:on", "name": "RULE1"}
  ],
  "fullDeviceDump": { "...": "appendix, not fed to the prompt by default" }
}
```

### 4.2 Agent Provider abstraction

```python
class AgentProvider(Protocol):
    def compile_intent(self, utterance: str, ctx: ContextBundle) -> list[RuleIntent]: ...
    def explain_conflict(self, conflict: Conflict, rules: list[Rule]) -> str: ...
    def suggest_resolution(self, conflict: Conflict, rules: list[Rule]) -> list[RuleIntent]: ...
    def summarize_rules(self, rules: list[Rule]) -> str: ...
```

Planned providers:

- **`OpenAICompatibleProvider`** — any OpenAI-chat-completions-style HTTP
  endpoint. Covers OpenAI, DeepSeek, Ollama, llama.cpp server, vLLM, etc.
  First provider implemented (easiest to test, works on any machine).
- **`AnthropicProvider`** — same interface, Anthropic Messages API.
- **`MacOSNativeProvider`** — Apple's built-in LLM surface. On macOS 26 this
  is the Foundation Models framework (on-device + Private Cloud Compute
  inference), reachable from Python via PyObjC. macOS 27's announced built-in
  agent/LLM APIs are the primary target once their surface is documented; the
  provider stays behind the same interface either way. Marked experimental
  until API details land.
- **`DeterministicProvider`** — no LLM at all. Pattern-matches common
  phrasings ("when X is on then Y on", "at HH:MM do Z", "after sunset ...")
  into `RuleIntent`s. Doubles as the regression baseline for LLM providers:
  the same utterance set must produce the same intents from any provider.

All providers return the same structured `RuleIntent` JSON; nothing
provider-specific may leak into the compiler. Prompt templates live in
`agent/src/er_agent/prompts/` and are versioned.

### 4.3 RuleIntent schema

The intermediate representation. One `RuleIntent` ≈ one ER rule
(one rule can generate 1–N EventScript statements for housekeeping).

```json
{
  "name": "Kitchen motion light",
  "group": "lights",
  "trigger": {
    "kind": "device",
    "deviceId": 77,
    "property": "value",
    "operator": "==",
    "value": true
  },
  "guard": {
    "kind": "between",
    "start": "sunset",
    "stop": "sunrise",
    "startOffset": "-00:30"
  },
  "actions": [
    {"kind": "device", "deviceId": 54, "property": "value", "value": true}
  ],
  "delays": [{"action": 0, "wait": "00:05:00", "then": {
    "kind": "device", "deviceId": 54, "property": "value", "value": false
  }}],
  "modifiers": {"debounce": "00:00:10"},
  "notes": "Free-form user-facing description"
}
```

Trigger kinds: `device`, `time` (`@HH:MM`, `@@interval`), `sun`
(`@sunrise`, `@sunset` ± offset), `globalVariable`, `customEvent`,
`scene`, `triggerVariable`.

Action kinds: device property set, scene activation, global variable set,
`post` custom event, `log`, custom function call (user-defined Lua, limited
allowlist).

### 4.4 EventScript Compiler

Pure-Python, deterministic: `RuleIntent → EventScript source`.

- Maps device IDs → ER device expressions (`54:on`, `77:value == true`).
- Emits modifiers (`single`, `since`, `debounce`, `cooldown`, `every`,
  `first_in`) using the syntax documented in `docs/RULES.md`.
- Emits `trueFor(T, cond)` for "must stay true for T" and `since T` forms.
- Emits `wait(sec)` chains for delayed follow-up actions.
- Emits `between` guards (`sunset..sunrise`).
- Supports the rule group syntax `{group="name"}`.
- Is covered by its own unit tests (intent fixtures → expected EventScript).

The compiler is the only place EventScript text is produced. Anything the
compiler can't express is a compiler limitation to fix — not an invitation
for the agent to write code.

### 4.5 Validator (plua bridge)

Runs generated rules through the **real** ER stack offline:

1. Write a throwaway QuickApp test file (same pattern as `test/rules/*.lua`):
   `main(er)` calls `er.eval(src)` for every generated rule.
2. Run `plua --fibaro --offline --run-for N <file>` (or the `plua` Python API,
   which keeps everything in-process since plua is a pip package).
3. Parse results: rule registration errors, trigger scan errors
   (`scanHead: missing op`), etc. are validation failures.
4. On failure, feed the error message + offending intent back to the agent
   for repair (max 3 rounds), then fall back to asking the user.

Validation also checks **naming**: every device ID referenced must exist in
the `ContextBundle`; unknown IDs fail fast with a clear message
("device 88 not found — did you mean 'Kitchen light' (54)?").

The validator loads ER sources directly from **this repository**
(`EventRunner.inc` + `src/*.lua`), so generated rules are always validated
against the exact ER version the agent deploys.

### 4.6 Conflict Analyzer

Two layers:

**Static (deterministic, no LLM).** Over the merged rule set
(existing rules parsed from the QuickApp main file + new intents):

- **Action conflicts** — two rules can set the same device property to
  different values under overlapping conditions.
- **Window overlaps** — overlapping `between`/`@time` guards with
  contradictory outcomes.
- **Modifier contradictions** — `single` + `debounce` + `cooldown` combos
  that make a rule effectively unfireable; `trueFor` durations longer than
  the async watchdog horizon (see the 2026-08 `trueFor` bug — the analyzer
  can flag suspiciously long durations defensively).
- **Dead references** — devices/globals/scenes that no longer exist on the HC3.
- **Trigger storms** — rule A posts an event rule B triggers on and vice versa.
- **Unreachable rules** — condition is a tautology/contradiction in the
  static cases the analyzer can decide.

**Agent-assisted (explanatory).** Each static finding becomes a `Conflict`
object; the provider turns it into plain-English explanation and a proposed
resolution (`suggest_resolution`), e.g.:

> "Rule 'Kitchen motion light' turns Kitchen light on when motion is
> breached; rule 'Goodnight' turns it off at 22:00 every day. Between
> 22:00 and sunrise both can fire. Do you want 'Goodnight' to win
> (add `between sunset..21:59` guard to the motion rule)?"

The user accepts, edits, or rejects; accepted resolutions are merged back as
intents and re-validated.

### 4.7 Simulator (dry-run)

Uses `src/Sim.lua` + plua offline simulation (same machinery as
`tests/eventrunner_testground*.lua` and the `er.loadSimDevice`,
`er.createSimGlobal`, `er.loadPluaDevice` APIs):

1. Instantiate simulated devices from the `ContextBundle` types.
2. Load the merged rule set.
3. Replay a scripted event trace (motion breached at 21:00, light on at
   21:00:01, …) with virtual time.
4. Produce a trace: which rules fired, which devices changed, and when.

This gives the user a "what would have happened yesterday" report before any
deployment. It is also the basis for future fuzz-style testing of rule sets
for unintended interactions.

### 4.8 Deployer

Deployment = update the ER QuickApp's main file and restart it:

```
PUT  /api/quickApp/{id}/files/main      {name="main", type="lua",
                                         isMain=true, content=...}
POST /api/plugins/restart               {deviceId={id}}
```

Procedure:

1. Read the current `main` file from the HC3.
2. Replace only the rules section between `--%%rules:start` / `--%%rules:end`
   markers (the tool inserts these markers on first deploy; user-written
   `main` code outside the markers is preserved).
3. Save the previous content to a local versioned store
   (`~/.er-agent/deploys/{host}/{timestamp}/main.lua.bak`).
4. Show a diff; require explicit confirmation.
5. PUT + restart; poll `/api/plugins/{id}/variables` or QA logs to confirm
   the QA came back up; auto-rollback to the backup on startup failure.

Alternative deployment (later phase): dynamic rule hot-loading through a
global-variable + `ER_subscription` channel, if/when ER grows a runtime rule
API. Until then, file update + restart is the only supported path — this is
an open question in §10.

## 5. Pipeline

CLI session sketch:

```
$ er-agent "when there is motion in the kitchen after sunset, \
            turn on the kitchen light for 5 minutes"

  ▸ Fetching context from HC3 (192.168.1.10)… 41 devices, 7 rooms
  ▸ Agent: compiled 1 intent → 2 rules
    RULE "Kitchen motion light"
      77:breached & between(sunset,sunrise) => 54:on; wait(00:05); 54:off
  ▸ Validated offline with plua ✓
  ▸ Conflict scan: 0 new conflicts (2 informational notes)
  ▸ Simulate? [y/N]
  ▸ Deploy? [y/N]   (shows diff)
```

Non-interactive mode (`--json`) emits every stage as JSON for CI or the
future web UI.

## 6. Conflict taxonomy

| Code | Name | Detection | Resolution |
|---|---|---|---|
| C1 | Contradictory action | static | guard/timeslot adjustment |
| C2 | Window overlap | static | merge or explicit priority |
| C3 | Modifier contradiction | static | simplify modifiers |
| C4 | Dead reference | static (HC3 context) | re-target or delete |
| C5 | Trigger storm | static graph walk | break cycle |
| C6 | Unreachable condition | static | simplify condition |
| C7 | Timing-unit suspicion | static lint | fix units (`trueFor` bug class) |
| C8 | Semantic ambiguity | agent-only | clarify with user |

## 7. Safety & human-in-the-loop

- **Never auto-deploy.** Deploy requires an explicit confirmation after a
  diff preview. `--yes` is allowed but still prints the diff.
- **Rollback.** Every deploy is backed up; failed startup auto-restores.
- **No blind device writes.** The tool only reads HC3 state for context.
  Device actions happen exclusively through deployed ER rules — and only
  after deploy confirmation.
- **Prompt integrity.** Agent providers receive only the `ContextBundle`
  (summary + needed details), not HC3 credentials. Credentials live in the
  Python process and are never sent to a remote model.
- **Deterministic core.** If the agent misbehaves, the compiler still emits
  only valid-or-rejected EventScript; the validator is the final gate.

## 8. Project layout

```
agent/                          # new top-level dir in this repo
  pyproject.toml                # python 3.10+, httpx, pydantic, plua
  README.md
  src/er_agent/
    __init__.py
    cli.py                      # typer CLI
    config.py                   # .env loading (HC3_URL, provider keys)
    context.py                  # HC3 REST client → ContextBundle
    intents.py                  # RuleIntent / ContextBundle models
    compiler.py                 # RuleIntent → EventScript
    validator.py                # plua bridge (offline compile/run)
    conflicts.py                # static analysis
    simulator.py                # plua + Sim.lua dry-run bridge
    deploy.py                   # quickApp files API, backups, rollback
    providers/
      base.py                   # AgentProvider protocol + registry
      openai_compat.py
      anthropic.py
      macos_native.py           # Foundation Models / macOS 27 builtin (TBD)
      deterministic.py          # no-LLM fallback + baseline
    prompts/                    # versioned prompt templates
      compile_intent.md
      explain_conflict.md
      suggest_resolution.md
  tests/
    test_compiler.py            # intent fixtures → expected EventScript
    test_conflicts.py
    test_deterministic_provider.py
    test_validator.py           # uses plua offline against this repo
    fixtures/
      context_bundle.json
      intents/
```

`plua` points at **this** repository's `EventRunner.inc` + `src/*.lua` for
validation/simulation, so the agent always validates against the exact ER
version it will deploy.

## 9. Roadmap (phased)

- **Phase 0 — Groundwork.** Spec review; plua validation harness for
  arbitrary rule strings (a `validate_rule(src)` test file); compiler
  skeleton with 10 intent fixtures compiling correctly.
- **Phase 1 — Deterministic core.** `ContextProvider` (HC3 read-only),
  `Compiler`, `Validator`, `Deployer` (with backup/rollback), CLI
  `--json` mode. No LLM yet; the `DeterministicProvider` covers a small
  pattern set end-to-end.
- **Phase 2 — First LLM provider.** `OpenAICompatibleProvider` + prompt
  templates; repair loop on validation failures; `explain_conflict` for
  C1–C4.
- **Phase 3 — Conflict & simulation.** Full static analyzer (C1–C8),
  Sim.lua dry-run traces, "yesterday replay" report.
- **Phase 4 — macOS native + UX.** `MacOSNativeProvider` once Apple's
  builtin agent/LLM API is documented (Foundation Models on macOS 26,
  macOS 27 surface TBD); richer interactive CLI (or thin web UI) for the
  conflict dialogue; dynamic hot-load deployment if ER supports it by then.

## 10. Open questions

1. **macOS 27 builtin agent surface.** Which framework/API exposes the
   built-in LLM (Foundation Models? osagent CLI? App Intents for
   Developers?), and can Python call it without entitlements? Phase 4
   target; provider interface is unaffected meanwhile.
2. **Dynamic rule loading in ER.** Today rules live in `main(er)` and load
   at QA startup. A runtime rule API (add/remove rules via a global
   variable or QuickApp variable) would let the agent deploy without a QA
   restart and shrink the rollback window. Needs an ER-side feature.
3. **Rule extraction from existing installs.** Users have rules in
   `main(er)` in arbitrary formats (Lua loops, templates via
   `er.template(...)`, string-built rules). Extracting a machine-readable
   inventory of existing rules from that file is heuristic; how much do we
   promise? (Phase 3 risk.)
4. **Context privacy with remote models.** Device names/IDs leave the LAN
   when a cloud provider is used. Default to local/on-device providers
   where available, and document this clearly.
