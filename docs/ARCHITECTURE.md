# EventRunner7 Architecture

## Pipeline Overview

```
┌──────────────┐    ┌──────────┐    ┌───────────┐    ┌────────────┐
│ Tokenizer.lua│───→│Parser.lua│───→│Compiler   │───→│  CSP.lua   │
│  tokenStream │    │  AST     │    │  CSP AST  │    │ CPS eval   │
└──────────────┘    └──────────┘    └───────────┘    └────────────┘
                                                           ↑
                                                    ┌──────┴──────┐
                                                    │  Rule.lua   │
                                                    │ trigger scan│
                                                    │ rule runner │
                                                    └─────────────┘
```

Four layers, two domains:

- **Frontend** (Tokenizer + Parser + Compiler): EventScript source → CSP instruction tree
- **Runtime** (CSP + Rule): CSP VM evaluates instructions; Rule.lua manages trigger subscriptions, rule lifecycle, and the async action loop

The CSP VM is self-contained with a clean extension API (`registerInstruction`). Domain-specific primitives (GETPROP, DAILY, BETW, etc.) are registered by Rule.lua at startup, not baked into the core VM.

## Module Map

| Module | Lines | Role |
|--------|-------|------|
| `src/Tokenizer.lua` | 395 | Lexer: source text → token stream |
| `src/Parser.lua` | 926 | Recursive descent parser: tokens → AST (incl. structured rule modifiers) |
| `src/Compiler.lua` | 535 | AST → CSP instruction tree (incl. the modifier gate chain) |
| `src/CSP.lua` | 912 | CPS VM: trampoline, YIELD, LOOP/BREAK, variable scoping |
| `src/Rule.lua` | 1342 | Rule lifecycle, trigger scanning, yield handlers, gate cores, event loop, module loading |
| `src/ScriptFuns.lua` | 463 | Built-in functions (log, math, HTTP, async wrappers, etc.) |
| `src/Props.lua` | 556 | Device property definitions, get/set/trigger mappings |
| `src/Utils.lua` | 1017 | JSON, alarm, setTimeout, base64, table helpers |
| `src/Setup.lua` | 244 | Engine boot, weather object, dimmer support |
| `src/Templates.lua` | 776 | High-level parameterized templates |
| `src/Sim.lua` | 113 | Device simulation for offline testing |

## Dependency Flow

```
EventRunner7.lua (entry point)
  └─ EventRunner.inc (module manifest)
       ├─ src/Tokenizer.lua
       ├─ src/Parser.lua       → Tokenizer
       ├─ src/CSP.lua          → (self-contained)
       ├─ src/Utils.lua
       ├─ src/Props.lua
       ├─ src/Compiler.lua     → Parser, CSP
       ├─ src/ScriptFuns.lua   → CSP, Props
       ├─ src/Rule.lua         → all above
       └─ src/Templates.lua    → Rule
  └─ src/Setup.lua             → Rule
```

All modules share the `fibaro.ER` namespace. The CSP VM is the only module with no upward dependencies — it can run standalone with a host interface.

## CSP VM Design

The CSP VM evaluates instruction trees in continuation-passing style. Core instructions (~30) are generic: arithmetic, logic, control flow, variable scoping, lambdas. Domain instructions (~8) are registered as extensions:

**Core (in `expr` table):**
`PROGN`, `CALL`, `CONST`, `IF`, `LOOP`, `BREAK`, `YIELD`, `LET`, `LETS`, `GET`, `SET`, `LAMBDA`, `CFUN`, `TRY`, `THROW`, `RETURN`, arithmetic and comparison ops

**Extensions (registered by Rule.lua):**
`GETPROP`, `SETPROP`, `GETVAR`, `SETVAR`, `DAILY`, `INTERV`, `BETW`, `TRIGGER_EVENT`

**Host hooks (via `vm.host`):**
- `isAsync(fn)` — async function detection
- `onVarWrite(name, val)` — trigger variable notification
- `formatSource(src, pos, len)` — error formatting

See [CSP_README.md](CSP_README.md) for the full IR contract.

## Rule Lifecycle

Rule construction is split across named builders in Rule.lua: `newRule`
(create + register), `attachRun` (timer registry, `killTimers`, `runRule`),
`setupTriggers` / `setupInterval` / `setupDailys` (subscriptions and time
scheduling), and `defineRuleAPI` (the public rule surface). `compRule`
orchestrates them.

1. **Registration** (`er.eval("cond => action")`):
   - Parser produces `{'RULE', cond, action, modifiers}` with *structured*
     modifiers — no AST rewrites.
   - `compileRuleBody` wraps the condition in the **modifier gate chain**
     (source order): `since` → `YIELD('sinceGate', T, cond)`, `cooldown` /
     `every` / `first_in` → `CFUN` gates, `debounce` → `wait(T)` prefixed to
     the action; `ruleCondition` stays outermost so stats/logging see the
     whole gated condition.
   - `scanHead` walks the compiled condition to discover triggers and
     enforces **head purity** (see Trigger Scanning); names are resolved
     here — the compile-time binding rule. Triggers are subscribed via
     `sourceTrigger` and stored on `rule.subs` (for recompile).

2. **Firing** (trigger event arrives):
   - `runRule` (honoring `single`'s `killTimers`) → `ruleRunner` evaluates
     the rule's compiled `IF` via the CSP VM.
   - Gate state lives in one home per gate: `rule.trueFor` (since) and
     `rule._mstate` (cooldown / every / first_in).
   - Actions may suspend (`wait`, async functions, the since gate) —
     suspensions do not block other rules; `onDone` fires on completion.

3. **Async execution**: suspending constructs yield to `yieldHandlers`
   (`sleep`, `asyncFun`, `sinceGate`). Async functions receive a typed
   **ExecutionEnv** on the callback (`cb.env`: rule, event, timers) — no
   continuation-snapshot reach-ins. Every timer is tracked in
   `rule.timers`; `killTimers` bumps `rule.gen`, and resuming continuations
   from superseded runs are discarded by the generation guard.

4. **Lifecycle API**: `rule:state()` ('enabled'/'disabled'), `rule.active`
   (in-flight runs), `enable`/`disable` (disable also stops the interval
   scheduler; enable restarts it — clock-aligned at the next boundary),
   `terminate` (cancels all timers, incl. the interval), and
   `rule:recompile()` — rebuilds from `rule.src` first (a broken source
   leaves the old binding running), then tears down (timers, subscriptions,
   modifier state, stats) and re-registers on the same rule object.

5. **Error policy**: a runtime error that aborts a run is counted
   (`rule.failCount`); `disableOnError` = true (default: disable on first
   error), N (disable after N consecutive errored runs; clean completions
   reset the streak), or false (never disable). `er.eval` returns
   `nil, errmsg` on failure, distinguishing failed from async/suspended.

## Trigger Scanning

`scanHead` (Rule.lua) walks the compiled condition to discover event
subscriptions at rule registration time. The HOPS dispatch table maps CSP
opcodes to trigger scanning logic:

| HOPS handler | Discovers |
|-------------|-----------|
| `GETPROP` | Device property triggers (object expression evaluated at registration — compile-time binding) |
| `BETW` | Time-range boundaries |
| `DAILY` | Daily time triggers |
| `INTERV` | Interval triggers |
| `GETVAR` | Global/QuickApp variable triggers |
| `GET` | Trigger variable references |
| `TRIGGER_EVENT` | Custom event triggers |
| `CALL` | Head-purity whitelist: bare-name calls must be in `ER._headFuns`, else registration error |
| `YIELD` | Only the `sinceGate` tag is allowed in a condition (`wait` in a head errors) |

This is the only place where the runtime "reads" CSP AST structure — it's
the host layer consuming its own output format, not a VM leak.

## Extension Points

- **Custom device properties**: `er.addStdProp()` / `er.definePropClass()`
- **Custom CSP instructions**: `vm.registerInstruction(name, impl, compiler)`
- **Custom templates**: `Templates.register(name, schema, generate)`
- **Module system**: `MODULE[#MODULE+1] = {name, prio, code}` — negative prio runs before user's `main()`, positive runs after
- **Head-purity whitelist**: `fibaro.ER._headFuns.myFun = true` allows a
  user helper in rule conditions
- **Per-rule error policy**: `disableOnError` opt (true / N / false)

Historical review documents live in `docs/reviews/` (`Architectural_Review.md`,
`Rule_Layer_Review.md`).
