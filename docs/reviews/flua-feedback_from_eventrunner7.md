# flua feedback — migration of EventRunner7 from plua

Report on the plua → flua migration of EventRunner7 (findings against
flua 0.1.90; #1 and #2 resolved by flua 0.1.91 — noted inline; remaining
items open as of 0.1.91). Covers where flua behavior cost time, where it
could be more helpful, and gaps in the agent docs/skills that made things
harder than they needed to be. Everything below was observed first-hand
during the migration; probes were run to confirm the claims.

## 1. Path resolution inconsistency (fixed in 0.1.91 — half of it remains)

`--%%file`/`--%%include` now resolve **relative to the file that declared
them** (main QA's dir for main-declared, the include file's own dir for
include-declared) — fixed in flua 0.1.91. `io.open`/`dofile` inside a QA
still resolve **relative to the process cwd**, so the two mechanisms still
disagree, but the QA-file side is now sane.

What 0.1.90 forced, and what 0.1.91 changed:

- Under 0.1.90 a QA in `tests/` could not `--%%file` the repo-root
  `EventRunner.inc` (paths resolved against `tests/`). The project shipped
  `er-load.lua` — a boot-time module loader that walked up from the QA
  directory to find the repo root and loaded every module
  `EventRunner.inc` lists — purely to work around the resolution rule.
- With 0.1.91, a nested test QA just declares
  `--%%include:../EventRunner.inc` and the `.inc`'s own `--%%file:src/…`
  entries anchor to the `.inc`'s directory. Verified: ER boots, Sim devices
  load, `er.eval` works with no loader. All 46 test files were migrated to
  `--%%include:<depth>/EventRunner.inc` and `er-load.lua` deleted.
- `scripts/er` no longer needs its `cd`-to-repo-root workaround (verified
  running from `/tmp`).
- `test/_diag.lua` (at `test/`) had a wrong-depth `--%%file:../../er-load.lua`
  from a mechanical header rewrite; only `flua --check` caught it (see #9).
  The depth trap is gone with the new scheme (each file's depth is correct
  relative to *itself*, and `--check` still verifies it).
- Remaining inconsistency: `io.open` is still cwd-relative, so QA code that
  reads project files (e.g. `src/Sim.lua` loading `tests/stdQAs/*.lua`) only
  works when flua is started from the repo root. Suggest: set cwd to the QA
  file's directory so both mechanisms agree, or document that QAs with
  relative `io.open` must be run from the project root.

## 2. plua's `--%%headers:` — solved by 0.1.91's `--%%include`

`--%%headers:EventRunner.inc` (plua: inline a header file's directives into
every QA) was an **unknown directive** in flua 0.1.90 — it warned and
ignored it (verified: `WARNING flua.config: unknown --%% directive`). This
was the single biggest structural migration issue: every one of the 28
regression QAs and all `tests/*.lua` suites used it, and there was no
drop-in replacement.

flua 0.1.91 fixes it: `--%%include:FILE` is the equivalent, and its
`--%%file` entries anchor to the include file's own directory, so
`--%%include:../EventRunner.inc` from a nested test QA just works (nested
includes anchor per level). The whole `er-load.lua` mechanism from #1 was
deleted in favor of a one-line include. The flua-setup skill should now
simply say: plua `--%%headers:X` → flua `--%%include:X`, with paths
relative to the declaring file.

## 3. `--instant` breaks ER-style event engines

`--instant` (recommended by AGENTS.md for "timers fire immediately") collapses
the whole timer heap into one pass. ER computes delays against
`os.time()`, so this corrupts its event engine. Reproduced with a minimal
probe (`@@00:00:05 => log(...)` plus `wait(3); log(...)`):

- `--speed 60`: interval fires at 12:00:02, :07, :12, :17; `wait(3)` fires 3 s
  later. Correct.
- `--instant`: the interval **never fires** in 30 simulated seconds, and
  `wait(3)` fires 27 s late at the moment the run ends (12:00:30).

This cost a full debugging detour during the migration (the runner was first
converted to `--instant` because it looked like the fast option; the verdict
only emerged from diagnosing the `@@` interval behavior). The workaround is
`--speed 3600 --max-hours 24` in `test/run-tests.sh`.

Suggestion: document that `--instant` is only safe for QAs that never compute
delays from the clock (pure `setTimeout` chains), and that engines using
`os.time()`-relative logic (ER, and anything with `@@`/daily timers) need
`--speed`. AGENTS.md currently recommends `--instant` unconditionally for
timer logic — for this project that advice is actively harmful.

## 4. `--speed` runs the virtual clock continuously — solved by 0.1.92 `--step`

plua's `speedTime` fast-forwarded **deterministically** (advance to the next
timer deadline). flua's `--speed N` runs the virtual clock continuously at
N× wall speed, so virtual time passes *while your code executes*:

- ER boot takes ~30 ms wall → ~100 virtual seconds of drift at `--speed
  3600` before `main()` even runs. Host-side captures like
  `os.time()`/`os.date()` in a test body land ~1–2 s away from the value
  `now`/`ostime()` computes inside the expression — pure flakiness.
- Tight now-relative windows (`now..now`, `now+1..now+2`) flake because each
  `now` read inside one expression can land in a different virtual second
  (1 virtual s = 278 µs wall at 3600×).
- The workaround was drift-agnostic rewrites in `test/expr/time.lua` (range/
  pattern assertions) and `tests/eventrunner_test.lua` (pinned boot epoch,
  ≥60 s between-windows, `wait(4)` → "≥ 4 s") — two test files had to be
  weakened, and the failures were intermittent (a suite can pass 2/3 runs).

**flua 0.1.92 added `--step`** — "deterministic deadline-ordered fast-forward
(plua speedTime): the clock advances to each timer's deadline before its
callback runs, one timer at a time". Verified: the clock holds at the pinned
`--%%time` instant between deadlines (host-side `os.time()` captures are
exact), `wait(4)` measures exactly 4, tight `now..now` between-windows are
stable, and `@@` intervals fire at exactly their clock-aligned boundaries.
The drift-agnostic rewrites were **reverted** to the original strict
assertions, `test/run-tests.sh` switched from `--speed 3600` to `--step`,
and the regression suite dropped from ~minutes to **6 s** (the 24 h main
suite from ~25 s to **0.24 s**).

`--step` + negative `--run-for` follow-ups (verified on 0.1.93):

- **Fixed in 0.1.93**: a far-future timer beyond the horizon now fires
  (`--step --run-for -30` with a single 9 h timer: fires at 21:00, exits in
  ~0.35 s; `-40000` likewise). The negative form in step mode is now
  "step through everything scheduled, end when idle; N is the wall leash".
- **Fixed in 0.1.95**: the wall leash is now enforced for never-idle QAs —
  the self-rescheduling timer under `--step --run-for -10` exits after 10 s
  wall with `flua: --run-for -10.0s wall cap reached with work pending
  (exit 1)`. And `--max-hours` now accepts fractional values (`0.0083` for
  a 30 s horizon works, exit 0 with "virtual time limit reached").
- **Fixed in 0.1.96 via a new escape hatch**: `_FLUA.background(fn)` tags a
  callback as housekeeping — it still fires while the run is alive, but does
  not count as pending work. ER's midnight loop now tags itself
  (`src/Rule.lua`, guarded so it is inert on the HC3 and older flua), so a
  test QA counts as idle once real rules/timers drain and
  `--step --run-for -N` exits 0 instead of spinning the wall leash.
- `scripts/er` now runs with `--step --max-hours 24 --run-for -N`:
  `wait(4)` rules and `@08:00` daily triggers fire at CPU speed (~0.2 s
  wall per invocation), daily rules fire exactly once (the 24 h window
  stops the next-day re-arm), and `-t` is a wall leash.
- **Fixed in 0.1.97**: the idle-exit under `--step` now uses a settle
  streak, so an in-flight timer re-arm wins over the exit — the
  non-deterministic early exits are gone. The no-cap daily chain now
  deterministically runs to the wall leash (exit 0, by design); the
  `er` script's `--max-hours 24` keeps single-fire output deterministic
  (verified 3/3 runs: exactly one `@08:00` fire).

## 5. No auto-termination; `--run-for` masks hangs with exit 0

flua QAs do not terminate when the event queue drains; a test that forgets
`os.exit` hangs forever. `--run-for N` caps the run but **exits 0 when it
kills the QA** (verified: a QA that only prints "started, never exits"
returned exit 0 after `--run-for 3`). For CI this means a hung/incomplete
suite looks green unless you also grep the log for the completion line —
exactly the class of false pass the migration almost shipped (`--run-for`
capped runs of suites that never finished).

Suggestion: exit non-zero when `--run-for` expires, and/or emit a
"run-for expired" marker in `--log json` so runners can detect it.

## 6. `json.encode` output differs from HC3/plua

flua's `json.encode` pads arrays with spaces (`[2, 4, 6]`); plua and the real
HC3 encoder emit `[2,4,6]`. String-exact assertions written for plua fail
under flua even though the data is identical (this was the last red test in
the regression suite, `test/expr/listcomp.lua`). The tests had to normalize
whitespace before comparing — meaning the tests no longer pinned the encoder
format at all.

**Status: fixed in 0.1.92** — verified on the installed build:
`json.encode({2,4,6})` now emits `[2,4,6]` (compact, HC3-compatible). The
whitespace-normalization workaround in `test/expr/listcomp.lua` was reverted
to the original strict comparison; the regression suite passes 13/13.

## 7. What worked well (worth keeping)

- **`flua --check`** caught the wrong-depth `--%%file` in `test/_diag.lua`
  with an exact "no such file" message — the static check is genuinely useful
  and was the safety net for the mechanical header rewrite.
- **plua-style directive warning** (`-- %%save`, space before `%%`) flagged
  every stale plua directive in the codebase.
- **Unknown device type error** listed valid alternatives
  ("did you mean 'com.fibaro.device'?").
- **`_FLUA.loadQAfromFile`/`loadFQAfromFile`** are documented in USAGE.md and
  replaced plua's `loadQAString`/`loadFQA` cleanly (`src/Sim.lua`,
  `tests/fqa_test.lua`).
- **`flua-test`** assertions library exists and works as AGENTS.md claims
  (verified with a probe). Note: the repo kept its own plua-era
  `test/harness.lua` instead; a note in the skills about "migrate an existing
  plua harness → keep it or switch to flua-test" would have removed the
  decision.
- **`--nogreet`, `--color never`, `--log json`** made machine-readable runs
  easy.

## 8. Agent doc / skill gaps

- AGENTS.md: "`flua --api local --instant qa.lua # timers fire immediately`"
  — harmful for ER (see #3). Needs a caveat: only for QAs without
  os.time()-relative delay logic.
- AGENTS.md documents `flua-test` but the repo's own harness does the same
  job; no guidance on which to use when migrating an existing plua test
  harness.
- AGENTS.md's `--instant` recommendation (see #3) should now point to
  `--step` for ER-style QAs — 0.1.92's help text already describes the
  distinction well; the project docs just need to reference it.
- The path-resolution (#1), `--%%headers:` (#2) and deterministic-clock (#4)
  gaps are now solved by 0.1.91/0.1.92; the flua-setup skill should document
  the direct mappings (`--%%headers:X` → `--%%include:X`,
  declaring-file-relative paths; speedTime → `--step`).
- `--run-for` exit semantics (#5) and `json.encode` spacing (#6) are
  undocumented traps for CI.

## Summary of the asks

Items #1 (declaring-file path anchoring) and #2 (`--%%headers:` equivalent)
are **done** in flua 0.1.91. The rest remain open as of 0.1.91:

| # | Ask | Status |
|---|-----|--------|
| 1 | `--%%root`/cwd-consistent path resolution | done (declaring-file anchor; `io.open` cwd caveat remains) |
| 2 | `--%%headers:` equivalent | done (`--%%include` with declaring-file anchor) |
| 3 | Document `--instant` safety limits (or warn) | open — doc |
| 4 | Deterministic clock-advance mode (plua speedTime semantics) | open — medium |
| 5 | Non-zero exit / marker when `--run-for` expires | open — small |
| 6 | HC3-compatible compact `json.encode` | open — small |
