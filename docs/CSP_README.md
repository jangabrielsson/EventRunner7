# CSP.lua — Continuation-Passing VM (IR Contract)

A small trampoline-based expression VM written in Lua. Expressions are built from composable functions and evaluated without growing the Lua call stack. Supports yielding, resuming, loops, variables, and error handling.

This document is the **IR contract** — it specifies what the VM guarantees, what the host must provide, and what frontend compilers can rely on. It is the reference for anyone writing a new language frontend that targets the CSP VM.

---

## Concepts

Every expression is a function `expr(cont)` that calls `cont(value)` when done instead of returning. The trampoline unwinds these tail-calls iteratively so deep expression trees never overflow the stack.

`TR(fn)` wraps a continuation so it returns `fn, args...` as a trampoline bounce instead of calling `fn` directly. It is an internal primitive — frontend compilers never emit it.

---

## eval / resume

```lua
local status, ... = vm.eval(expr, opts)
```

Runs `expr` from a clean context. Returns:
- `'ok', val...` — expression completed normally
- `'suspended', token, yieldvals...` — expression hit a `YIELD`

`opts` is an optional table:
```lua
{
  trace = true,           -- enable step tracing for this expression
  vars  = { x=1, y=2 },  -- initial local variables visible to the expression
}
```

```lua
local status, ... = vm.resume(token, val...)
```

Resumes a suspended expression. The `YIELD` expression inside the chain evaluates to the values passed here. Returns the same shape as `eval`.

### Example

```lua
local e = vm.expr
local status, token, yv = vm.eval(
  e.LET("x", e.CONST(10),
    e.PROGN(
      e.YIELD(e.GET("x")),       -- suspends, yields 10
      e.ADD(e.GET("x"), e.CONST(5))
    )
  )
)
-- status == 'suspended', yv == 10

local status2, result = vm.resume(token)
-- status2 == 'ok', result == 15
```

---

## compile

`vm.compile(tree, srcmap)` turns a nested table tree into an expression, so frontends don't need to call the expression constructors directly.

Rules:
- `{"OPCODE", args...}` — compiled recursively
- Scalar args (number, string, boolean, function) are auto-wrapped in `CONST`
- Table args are compiled as sub-expressions
- `{"CONST", v}` — `v` is always a literal (safe for table values)
- `GET`, `SET`, `DEFGLOBAL`, `LET` — first arg is a raw variable name string, not compiled
- `SETFIELD` — second arg (field name) is a raw string
- `INCVAR` — first arg is a raw name; second arg is the op string (e.g. `"ADD"`)
- `CALL` — all args including the function are compiled (a raw function is auto-wrapped in `CONST`)
- `TRY` — body is compiled; handler is a raw Lua function `function(err...) return expr end`
- `CFUN` — first arg is a raw Lua function; remaining args are compiled as expressions
- `LAMBDA` — first arg is a raw list of param name strings; second arg is the compiled body tree
- `LETS` — first arg is a raw list of name strings; second arg is a list of compiled exprs; third is compiled body

The optional `srcmap` maps CSP instruction table references to `{pos, len}` source positions. When provided, compiled closures are wrapped to update the execution context's `_curpos` on entry, enabling source-position enrichment of runtime errors.

### Example

```lua
local prog = vm.compile{
  "PROGN",
  {"DEFGLOBAL", "i", 0},
  {"LOOP",
    {"PRINT", "i =", {"GET", "i"}},
    {"SET", "i", {"ADD", {"GET", "i"}, 1}},
    {"IF", {"GT", {"GET", "i"}, 5}, {"BREAK"}}
  }
}
vm.eval(prog)
```

---

## Context model

The execution context (`_ctx`) is fully encapsulated — all access goes through methods. It is saved and restored atomically at every `eval`/`yield`/`resume` boundary so parallel expressions never corrupt each other's state.

### Variable environment

Variables use a metatable chain of frames. Each frame is a table `{[name] = {value}}` — values are boxed so `nil` is a valid binding and inner frames always shadow outer ones.

- **Locals** — per-expression chain, saved/restored on yield. Created by `LET`/`LETS`.
- **Globals** — single shared frame, never snapshotted. All expressions see the same globals. Created by `DEFGLOBAL` or `vm.defGlobal()`.

Variable lookup order: local chain → globals → `_G[name]` (Lua global fallback for builtins).

### vm context API

```lua
vm.defGlobal("name", value)      -- define or reset a global
vm.getGlobal("name")             -- returns value (or nil if undefined)
vm.setGlobal("name", value)      -- mutate existing global (returns bool)
vm.lookupGlobal("name")          -- returns value, same as getGlobal
vm.resetGlobals()                -- clear all globals (used on rule reload)
vm.getCTX()                      -- returns the current _ctx (for host primitives)
```

---

## Extension API

The VM supports registering new opcodes at runtime. This is how host layers (EventScript, a hypothetical LISP frontend) inject domain-specific primitives without modifying CSP.lua.

### registerInstruction / registerInstructions

```lua
vm.registerInstruction(name, impl_fn, specialCompiler_fn)
vm.registerInstructions({
  OPNAME = { impl = impl_fn, compile = specialCompiler_fn },
  ...
})
```

- `impl_fn` — the CPS expression implementation `function(...) return function(cont) ... end end`
- `specialCompiler_fn` — optional; a `function(csp_table) -> compiled_expr` for opcodes with non-standard argument handling. When omitted, `compile()` uses the default generic-arg path (all positional args compiled via `ca()`).

### vm.host hooks

The VM calls these host-provided functions for cross-cutting concerns. Defaults are no-ops. The host layer overwrites them after `fibaro.ER.csp = vm`.

```lua
vm.host = {
  isAsync      = function(fn) return false end,           -- is fn an async callback?
  onVarWrite   = function(name, val) end,                  -- side-effect on SET/INCVAR
  formatSource = function(src, pos, len) return ... end,   -- error source formatting
}
```

---

## Opcode taxonomy

| Category | Meaning |
|---|---|
| **Core** | Guaranteed by the VM. Available in every CSP runtime without host registration. Stable across minor versions. |
| **Host-extension** | Not in the core `expr` table. Must be registered by the host via `registerInstruction`. Availability depends on the host. |
| **Internal** | Used by the trampoline/compiler machinery. Frontend compilers never emit these. |

---

## Core opcodes

### Values

| Opcode | CPS signature | Description | Stable |
|---|---|---|---|
| `CONST(v)` | `function(cont) → cont(v)` | Evaluates to the literal value `v` | ✅ |

### Arithmetic

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `ADD(a, b)` | `{"ADD", a, b}` | `a + b` | ✅ |
| `SUB(a, b)` | `{"SUB", a, b}` | `a - b` | ✅ |
| `MUL(a, b)` | `{"MUL", a, b}` | `a * b` | ✅ |
| `DIV(a, b)` | `{"DIV", a, b}` | `a / b` | ✅ |
| `MOD(a, b)` | `{"MOD", a, b}` | `a % b` | ✅ |
| `POW(a, b)` | `{"POW", a, b}` | `a ^ b` | ✅ |
| `NEG(a)` | `{"NEG", a}` | `-a` (unary minus) | ✅ |

### Comparison

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `EQ(a, b)` | `{"EQ", a, b}` | `a == b` (uses `__tostring` metamethod for comparison if available) | ✅ |
| `LT(a, b)` | `{"LT", a, b}` | `a < b` | ✅ |
| `LTE(a, b)` | `{"LTE", a, b}` | `a <= b` | ✅ |
| `GT(a, b)` | `{"GT", a, b}` | `a > b` | ✅ |
| `GTE(a, b)` | `{"GTE", a, b}` | `a >= b` | ✅ |

### Boolean logic

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `AND(a, b)` | `{"AND", a, b}` | Short-circuit: returns first falsy value, or last value if all truthy (Lua semantics) | ✅ |
| `OR(a, b)` | `{"OR", a, b}` | Short-circuit: returns first truthy value, or last value if all falsy (Lua semantics) | ✅ |
| `NOT(a)` | `{"NOT", a}` | `not a` (boolean negation) | ✅ |

### Coalesce

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `NILCO(a, b)` | `{"NILCO", a, b}` | Nil-coalesce: returns `a` if non-nil, otherwise `b` | ✅ |

### String

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `CONCAT(a, b)` | `{"CONCAT", a, b}` | `tostring(a) .. tostring(b)` | ✅ |

### Control flow

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `IF(cond, then[, else])` | `{"IF", cond, then, else}` | Conditional; `else` is optional, evaluates to `nil` if omitted | ✅ |
| `PROGN(e1, e2, ...)` | `{"PROGN", e1, ...}` | Sequence; evaluates all, returns value of last | ✅ |
| `LOOP(body)` | `{"LOOP", body}` | Runs body repeatedly until `BREAK`; multiple exprs auto-wrapped in `PROGN` | ✅ |
| `BREAK(val...)` | `{"BREAK", val...}` | Exits the innermost `LOOP`, returning `val...` | ✅ |
| `RETURN(val...)` | `{"RETURN", val...}` | Exits the current expression immediately via the exit continuation; `val...` becomes the result | ✅ |
| `YIELD(val...)` | `{"YIELD", val...}` | Suspends execution, yielding `val...` to the caller; resumes with the values passed to `vm.resume()` | ✅ |

### Variables

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `LET(name, val, body)` | `{"LET", name, val, body}` | Binds `name` to `val` in a new frame scoped to `body` | ✅ |
| `LETS(names, vals, body)` | `{"LETS", names, vals, body}` | Binds multiple `names` to corresponding `vals` in a single frame scoped to `body`; `names` is a raw list of strings, `vals` is a list of compiled exprs | ✅ |
| `GET(name)` | `{"GET", name}` | Reads the innermost binding of `name`; errors if undefined | ✅ |
| `SET(name, val)` | `{"SET", name, val}` | Mutates the innermost binding of `name`; errors if undefined. Calls `vm.host.onVarWrite(name, val)` after writing. | ✅ |
| `INCVAR(name, op, val)` | `{"INCVAR", name, op, val}` | Reads `name`, applies arithmetic op (`"ADD"`, `"SUB"`, `"MUL"`, `"DIV"`, `"MOD"`), writes result. Calls `vm.host.onVarWrite(name, result)`. | ✅ |
| `DEFGLOBAL(name, val)` | `{"DEFGLOBAL", name, val}` | Defines or resets a global variable visible to all expressions | ✅ |

### Tables

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `MAKETABLE(k1,v1, k2,v2, ...)` | `{"MAKETABLE", k1, v1, ...}` | Builds a fresh table from alternating key/value expression pairs. Positional keys can be integers. | ✅ |
| `INDEX(obj, key)` | `{"INDEX", obj, key}` | `obj[key]` — evaluates both `obj` and `key` as expressions. `key` can be a string literal (auto-wrapped in CONST) or any expression. | ✅ |
| `SETINDEX(obj, key, val)` | `{"SETINDEX", obj, key, val}` | `obj[key] = val`. Errors if `obj` is not a table. | ✅ |
| `SETFIELD(obj, field, val)` | `{"SETFIELD", obj, field, val}` | `obj.field = val`. `field` is a raw string (not compiled). Errors if `obj` is not a table. | ✅ |

### Functions

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `CALL(fn, arg1, ...)` | `{"CALL", fn, arg1, ...}` | Evaluates `fn` to get a Lua function, calls it with evaluated args; passes through multiple return values. If `vm.host.isAsync(fn)` returns true, the call yields and resumes when the callback fires. | ✅ |
| `CFUN(lua_fn, arg1, ...)` | `{"CFUN", lua_fn, arg1, ...}` | Calls a raw Lua function `lua_fn(cont, ctx_snapshot, ...evaluated_args)`. The function is responsible for calling `cont(value)` to produce a result. Args after the function are compiled as expressions. | ✅ |
| `LAMBDA(params, body)` | `{"LAMBDA", params, body}` | Creates a closure: captures the current var-env snapshot, returns a Lua function `function(...)` that binds params to args in a fresh frame and evaluates `body`. `params` is a raw list of name strings; `body` is a compiled CSP tree. | ✅ |

### Error handling

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `TRY(body, handler)` | `{"TRY", body, handler}` | Runs `body`; if `THROW` fires, unwinds all frames to TRY entry, calls `handler(err...)` which must return a CSP expression to continue with | ✅ |
| `THROW(val...)` | `{"THROW", val...}` | Transfers control to the active `TRY` handler with `val...` as the error; raises a Lua error if no handler is installed | ✅ |

### Diagnostics

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `PRINT(arg1, ...)` | `{"PRINT", arg1, ...}` | Shorthand for `CALL(print, ...)`. Uses a cached `CONST(print)` to avoid allocation. | ✅ |
| `TRACE(val)` | `{"TRACE", val}` | Evaluates `val`, sets the trace flag to its truthiness, passes `val` through. When trace is on, many primitives emit `[TRACE]` output. | ✅ |

### Time (borderline core)

| Opcode | CSP table | Description | Stable |
|---|---|---|---|
| `NOW()` | `{"NOW"}` | Returns seconds-since-midnight via `os.date("*t")`. In the core expr table but conceptually a host concern — different hosts may want different time semantics. | ⚠️ |

---

## Host-extension opcodes (registered by Rule.lua)

These opcodes are not in the core `expr` table. They are registered by the EventScript host layer (`Rule.lua`) via `vm.registerInstructions()`. A different host (e.g. a LISP frontend) would register a different set — or not register these at all.

| Opcode | CSP table | Description | Requires |
|---|---|---|---|
| `GETPROP(obj, key)` | `{"GETPROP", obj, key}` | Reads a device property via `ER.getProp()`. `key` is a raw string. | Host provides property system |
| `SETPROP(obj, key, val)` | `{"SETPROP", obj, key, val}` | Writes a device property via `ER.setProp()`. `key` is a raw string. | Host provides property system |
| `GETVAR(typ, name)` | `{"GETVAR", typ, name}` | Reads a Fibaro variable. `typ` is `"GV"`/`"QV"`/`"PV"` (raw string, not compiled); `name` is compiled. | Host provides variable system |
| `SETVAR(typ, name, val)` | `{"SETVAR", typ, name, val}` | Writes a Fibaro variable. | Host provides variable system |
| `DAILY(time_val)` | `{"DAILY", time_val}` | Returns `true` if the current invocation was triggered by a daily event. Reads `event.type` from the var environment — EventScript trigger-model specific. | EventScript trigger model |
| `INTERV(time_val)` | `{"INTERV", time_val}` | Wraps a time value into an interval event descriptor `{type='Interval', interval=v}`. | EventScript trigger model |
| `BETW(start, stop)` | `{"BETW", start, stop}` | Time-range check via `ER.betw()`. Handles epoch timestamps and seconds-since-midnight with midnight wrap-around. | Host provides time-range logic |
| `TRIGGER_EVENT(tab, id)` | `{"TRIGGER_EVENT", tab, id}` | Event-key check: evaluates the table and ID, then checks `_evKey` from the var environment. Returns the table if the event key matches, `false` otherwise. Emitted by the compiler for `#EventName{...}` in rule conditions. | EventScript trigger model |

---

## Internal opcodes

These exist in the `expr` table but are used only by the trampoline/compiler machinery. Frontend compilers never emit them directly.

| Opcode | Purpose |
|---|---|
| `TR(fn)` | Wraps a continuation for trampoline bounce. Used internally by every CPS primitive to return `fn, args...` instead of calling `fn` directly. |

---

## Host interface contract

When the VM is used as a standalone runtime (before `Rule.lua` initializes), these defaults apply:

```lua
vm.host = {
  isAsync      = function(fn) return false end,   -- all functions are synchronous
  onVarWrite   = function(name, val) end,           -- variable writes have no side effects
  formatSource = function(src, pos, len)             -- basic source formatting
                   return src .. " :" .. pos
                 end,
}
```

A host layer must override these after acquiring `vm` (typically via `vm = ER.csp`):

| Hook | Contract |
|---|---|
| `isAsync(fn)` | Return `true` if `fn` is an async callback that expects `fn(callback, ...)` and will call `callback(result)` later. The VM yields on `CALL` when this returns true. |
| `onVarWrite(name, val)` | Called after every `SET` and `INCVAR`. Use for trigger-variable notification or other write-side effects. Must not throw. |
| `formatSource(src, pos, len)` | Called to format source positions in error messages. Return a string to append to the error. |

Additionally, host primitives can access the execution context through:

```lua
local ctx = vm.getCTX()        -- the current _ctx object
ctx:getVar('event')             -- read a variable
ctx:getOpts()                   -- get eval options
```

This is the deliberate escape hatch for primitives that need environment access (e.g., `GETPROP` reads `_ctx` to pass to `ER.getProp`). New host layers should prefer passing needed state through `CFUN` closures rather than reaching into `getCTX()`.

---

## Writing a new frontend

A frontend targeting the CSP VM needs:

1. **A parser** that produces an AST in the frontend's source language.
2. **A compiler** that maps the AST to CSP table notation using only **Core** opcodes plus any **Host-extension** opcodes the frontend registers.
3. **A host layer** that:
   - Sets `vm.host.isAsync`, `vm.host.onVarWrite`, `vm.host.formatSource` as needed.
   - Registers domain-specific opcodes via `vm.registerInstructions()`.
   - Defines global variables (`vm.defGlobal()`) for builtins the compiled code expects.
   - Calls `vm.eval(code, opts)` to execute.

The core opcodes marked ✅ Stable are guaranteed available and will not change semantics in a minor version. Opcodes marked ⚠️ may move to host-extension in a future release.

---

## Runtime error enrichment

When a source map is provided to `vm.compile()`, CSP instruction closures are instrumented to set `_ctx._curpos` before executing. On error, `eval()` / `resume()` read the current source position and call `vm.host.formatSource()` to append source context to the error message.

Errors are raised via Lua's `error()` with position 0 (so the pcall in `eval` catches them directly). The error message is enriched with source position before re-throwing.
