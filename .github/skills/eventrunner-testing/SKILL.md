---
name: eventrunner-testing
description: How to write and run tests for EventScript/EventRunner — parser tests, expression eval tests, and full integration tests. Covers the three test tiers, the builtin-availability problem (setupFuns), how to use ER.compileAST vs er.eval, and common pitfalls. USE FOR: writing new tests, diagnosing "Undefined variable" for builtins, choosing the right test tier, understanding what's a valid EventScript statement vs expression.
---

# EventRunner / EventScript — Test Writing Guide

Three tiers of tests exist in `tests/`. Choose the right tier for what you're testing.

---

## Tier 1 — Parser tests (`tests/parser_test.lua`)

**Tests:** tokenization + parsing only (AST shape). No compilation, no evaluation.

**Pattern:**
```lua
--%%name:Parser unit tests
--%%offline:true
--%%headers:EventRunner.inc

local ER    = fibaro.ER
local parse = ER.parse

local function check(label, src, expected) ... end   -- deep-equal AST check
check("my feature", "x -> x * 2", {'FUNCTION', {'x'}, ...})
```

**Key facts:**
- No `QuickApp:onInit`, no `fibaro.EventRunner()` call needed.
- `ER.parse` is available immediately after the headers load.
- `checkErr(label, src)` verifies the source throws a parse error.
- Run: `plua --fibaro --nodebugger --run-for 3 tests/parser_test.lua`

---

## Tier 2 — Expression eval tests (`tests/expr_test.lua` style)

**Tests:** parse → compile → eval for pure expression correctness. No device events, no timers.

**The builtin-availability problem** — IMPORTANT:

`setupFuns()` in `ScriptFuns.lua` registers all builtins (`sum`, `size`, `map`, `filter`, `reduce`, `sort`, etc.) via `vm.defGlobal`. It is **only called from `bootEventRunner`**, which is triggered by `fibaro.EventRunner(cb)`. If you call `vm.eval` directly without booting EventRunner, builtins are **not** in `_global_env` and you get `#Undefined variable: 'sum'`.

**Fix:** call `pcall(ER.setupFuns)` before your tests. This registers all builtins up to (but not including) the `async` section, which is sufficient for math/table/string/collection builtins. The `pcall` swallows the error when `ER.async` is nil.

```lua
--%%name:My eval tests
--%%offline:true
--%%headers:EventRunner.inc

local ER = fibaro.ER
local vm = ER.csp
pcall(ER.setupFuns)   -- ← REQUIRED to make builtins (sum, map, filter, etc.) available

local parse      = ER.parse
local compileAST = ER.compileAST   -- NOT ER.compile (that doesn't exist)

local passed, failed = 0, 0

local function test(name, src, expected)
  local ok, result = pcall(function()
    local ast  = parse(src)
    local csp  = compileAST(ast)
    local code = vm.compile(csp)
    local _, val = vm.eval(code)
    return val
  end)
  if ok and result == expected then
    passed = passed + 1; print("PASS: " .. name)
  elseif ok then
    failed = failed + 1
    print("FAIL: " .. name .. "  expected=" .. tostring(expected) .. "  got=" .. tostring(result))
  else
    failed = failed + 1; print("ERROR: " .. name .. "  " .. tostring(result))
  end
end

test("addition",  "1 + 2",   3)
test("lambda",    "(x -> x * 2)(5)", 10)
test("map+sum",   "sum(map({1,2,3}, x -> x * 2))", 12)

print(string.format("\n%d passed, %d failed", passed, failed))
```

**Compile function names — important:**
| Name | Where | What |
|------|-------|-------|
| `ER.parse(src)` | Parser.lua | source → EventScript AST |
| `ER.compileAST(ast)` | Compiler.lua | AST → CSP instruction tree |
| `ER.compileASTWithMap(ast)` | Compiler.lua | same + returns srcmap |
| `vm.compile(csp)` | CSP.lua | CSP tree → closure |
| `vm.eval(closure)` | CSP.lua | closure → `(status, val)` |
| ~~`ER.compile`~~ | — | **does not exist** |

---

## Tier 3 — Integration tests (`tests/eventrunner_plua_test.lua` style)

**Tests:** full EventRunner lifecycle — rules, device events, timers, triggers.

**Pattern:**
```lua
--%%name:My integration test
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%offline:true
--%%file:Sim.lua,sim
--%%file:tests/testfuns.lua,test

local function main(er)
  local rule = er.eval
  -- use er.eval, er.variables, er.test, loadDevice, etc.
  rule("turnOn(42) => turnOff(42)")
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
```

**Key facts:**
- `fibaro.EventRunner(main)` calls `bootEventRunner` which calls `ER.setupFuns()` — all builtins available.
- `er.eval(src)` evaluates rules AND bare expressions synchronously (returns value for pure expressions).
- `er.eval(src, {throw=true})` re-raises parse/compile/runtime errors instead of logging them.

---

## What is a valid EventScript statement?

Knowing this prevents "Expected '='" surprises when writing eval tests.

**Valid statements:**
```
x = expr              -- assignment
local x = expr        -- local var declaration  
f(args)               -- function call (including lambda call)
(x -> x+1)(5)         -- immediately-invoked lambda
if ... then ... end   -- control flow
for ... do ... end
while ... do ... end
```

**NOT valid as a standalone statement (even though valid as expressions):**
```
t[k]                  -- index expression  (use local v = t[k]; ... instead)
1 + 2                 -- bare arithmetic
x .. y                -- concatenation
```

**Common workarounds:**
```lua
-- Want to test map({1,2,3}, x->x*2)[2] == 4?
-- WRONG: "map({1,2,3}, x->x*2)[2]"   → Expected '=' at statement level
-- RIGHT: use sum/size/reduce to collapse the result to a scalar call:
"sum(map({1,2,3}, x -> x * 2))"           -- sum = 12
"size(filter({1,2,3}, x -> x > 1))"       -- count = 2
"(x -> x)(map({1,2,3}, x -> x*2)[2])"     -- identity lambda trick → 4
```

---

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `#Undefined variable: 'sum'` | `setupFuns` not called | Add `pcall(ER.setupFuns)` |
| `attempt to call a nil value (upvalue 'compile')` | Using `ER.compile` | Use `ER.compileAST` |
| `Expected '='` at statement level | Expression used as statement | Wrap in function call or use `local` |
| `Unexpected character '#'` | `#t` used as length | Use `size(t)` — `#` is event prefix in EventScript |
| Builtins work in integration test but not eval test | EventRunner not booted | Use `pcall(ER.setupFuns)` in Tier 2 tests |
| `async` nil crash in `setupFuns` | Called before `bootEventRunner` sets `er.async` | Wrap with `pcall` — early builtins still register |

---

## Run commands

```bash
# Tier 1 — parser tests
plua --fibaro --nodebugger --run-for 3 tests/parser_test.lua

# Tier 2 — expression eval tests
plua --fibaro --nodebugger --run-for 3 tests/expr_test.lua
plua --fibaro --nodebugger --run-for 3 tests/lambda_test.lua

# Tier 3 — integration tests (real time, ~20s)
plua --fibaro --nodebugger --run-for 30 tests/eventrunner_plua_test.lua

# Tier 3 — integration tests with speedTime (~5s simulated time)
plua --fibaro --nodebugger --run-for 30 tests/eventrunner_test.lua
```
