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
| `src/Tokenizer.lua` | 388 | Lexer: source text → token stream |
| `src/Parser.lua` | 900 | Recursive descent parser: tokens → AST |
| `src/Compiler.lua` | 488 | AST → CSP instruction tree |
| `src/CSP.lua` | 902 | CPS VM: trampoline, YIELD, LOOP/BREAK, variable scoping |
| `src/Rule.lua` | 974 | Rule lifecycle, trigger scanning, event loop, module loading |
| `src/ScriptFuns.lua` | 510 | Built-in functions (log, math, HTTP, trueFor, etc.) |
| `src/Props.lua` | 550 | Device property definitions, get/set/trigger mappings |
| `src/Utils.lua` | 984 | JSON, alarm, setTimeout, base64, table helpers |
| `src/Setup.lua` | 125 | Engine boot, weather object, dimmer support |
| `src/Templates.lua` | 681 | High-level parameterized templates |
| `src/Sim.lua` | — | Device simulation for offline testing |

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

1. **Registration** (`er.eval("cond => action")`):
   - Compiler produces CSP AST for condition + action
   - `scanHead` walks the condition AST to discover triggers
   - Triggers are subscribed via `sourceTrigger`

2. **Firing** (trigger event arrives):
   - `ruleRunner` evaluates the condition via CSP VM
   - If true and no modifier blocks it, action executes
   - Action may `wait()` — suspends without blocking other rules
   - `onDone` callback fires when action completes

3. **Modifiers** (applied between condition evaluation and action execution):
   - `single` — cancel pending timers from prior run
   - `since T` — condition must be continuously true for T seconds
   - `debounce T` — wait T seconds of silence
   - `cooldown T` — suppress re-firing for T seconds
   - `every N` — fire only on Nth true evaluation

## Trigger Scanning

`scanHead` (Rule.lua) walks CSP AST nodes to discover event subscriptions at rule registration time. The HOPS dispatch table maps CSP opcodes to trigger scanning logic:

| HOPS handler | Discovers |
|-------------|-----------|
| `GETPROP` | Device property triggers |
| `BETW` | Time-range boundaries |
| `DAILY` | Daily time triggers |
| `INTERV` | Interval triggers |
| `GETVAR` | Global/QuickApp variable triggers |
| `GET` | Trigger variable references |
| `TRIGGER_EVENT` | Custom event triggers |

This is the only place where the runtime "reads" CSP AST structure — it's the host layer consuming its own output format, not a VM leak.

## Extension Points

- **Custom device properties**: `er.addStdProp()` / `er.definePropClass()`
- **Custom CSP instructions**: `vm.registerInstruction(name, impl, compiler)`
- **Custom templates**: `Templates.register(name, schema, generate)`
- **Module system**: `MODULE[#MODULE+1] = {name, prio, code}` — negative prio runs before user's `main()`, positive runs after
