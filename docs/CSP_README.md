# CSP.lua — Continuation-Passing VM

A small trampoline-based expression VM written in Lua. Expressions are built from composable functions and evaluated without growing the Lua call stack. Supports yielding, resuming, loops, variables, and error handling.

## Concepts

Every expression is a function `expr(cont)` that calls `cont(value)` when done instead of returning. The trampoline unwinds these tail-calls iteratively so deep expression trees never overflow the stack.

`TR(fn)` wraps a continuation so it returns `fn, args...` as a trampoline bounce instead of calling `fn` directly.

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

## compile

`vm.compile(t)` turns a nested table tree into an expression, so you don't need to call the expression constructors directly.

Rules:
- `{"OPCODE", args...}` — compiled recursively
- Scalar args (number, string, boolean, function) are auto-wrapped in `CONST`
- Table args are compiled as sub-expressions
- `{"CONST", v}` — `v` is always a literal (safe for table values)
- `GET`, `SET`, `DEFGLOBAL`, `LET` — first arg is a raw variable name string, not compiled
- `CALL` — all args including the function are compiled (a raw function is auto-wrapped in `CONST`)
- `TRY` — body is compiled; handler is a raw Lua function

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

## Global variables

Global variables are shared across all expressions and are never reset by `eval`.

```lua
vm.defGlobal("name", value)   -- define or reset a global
vm.getGlobal("name")          -- returns value (or nil if undefined)
vm.setGlobal("name", value)   -- mutate existing global (returns bool)
```

From inside an expression, use `DEFGLOBAL` to define a global.

---

## Expression reference

### Values

| Expression | Description |
|---|---|
| `CONST(v)` | Evaluates to the literal value `v` |

### Arithmetic

| Expression | Description |
|---|---|
| `ADD(a, b)` | `a + b` |
| `SUB(a, b)` | `a - b` |
| `MUL(a, b)` | `a * b` |
| `DIV(a, b)` | `a / b` |
| `MOD(a, b)` | `a % b` |
| `POW(a, b)` | `a ^ b` |

### Comparison

| Expression | Description |
|---|---|
| `EQ(a, b)` | `a == b` |
| `LT(a, b)` | `a < b` |
| `LTE(a, b)` | `a <= b` |
| `GT(a, b)` | `a > b` |
| `GTE(a, b)` | `a >= b` |

### Control flow

| Expression | Description |
|---|---|
| `IF(cond, then_expr[, else_expr])` | Conditional; `else_expr` is optional, evaluates to `nil` if omitted |
| `PROGN(e1, e2, ...)` | Sequence; evaluates all, returns value of last |
| `LOOP(e1[, e2, ...])` | Runs body repeatedly until `BREAK`; multiple exprs auto-wrapped in `PROGN` |
| `BREAK(val...)` | Exits the innermost `LOOP`, returning `val...` |
| `YIELD(val...)` | Suspends execution, yielding `val...` to the caller |

### Variables

| Expression | Description |
|---|---|
| `LET(name, val_expr, body)` | Binds `name` to result of `val_expr` for the scope of `body` |
| `GET(name)` | Reads the innermost binding of `name` |
| `SET(name, val_expr)` | Mutates the innermost binding of `name` |
| `DEFGLOBAL(name, val_expr)` | Defines (or resets) a global variable |

### Functions & I/O

| Expression | Description |
|---|---|
| `CALL(fn_expr, arg1, ...)` | Evaluates `fn_expr` to get a Lua function, calls it with evaluated args; passes through multiple return values |
| `PRINT(arg1, ...)` | Shorthand for `CALL(print, ...)` |

### Diagnostics

| Expression | Description |
|---|---|
| `TRACE(val_expr)` | Evaluates `val_expr`, sets the trace flag to its truthiness, passes the value through |

### Error handling

| Expression | Description |
|---|---|
| `TRY(body, handler_fn)` | Runs `body`; if `THROW` fires, calls `handler_fn(err...)` which must return an expression |
| `THROW(val...)` | Transfers control to the active `TRY` handler, or raises a Lua error if none |

A small trampoline-based expression VM written in Lua. Expressions are built from composable functions and evaluated without growing the Lua call stack. Supports yielding, resuming, loops, variables, and error handling.

## Concepts

Every expression is a function `expr(cont)` that calls `cont(value)` when done instead of returning. The trampoline unwinds these tail-calls iteratively so deep expression trees never overflow the stack.

`TR(fn)` wraps a continuation so it returns `fn, args...` as a trampoline bounce instead of calling `fn` directly.

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

## Global variables

Global variables are shared across all expressions and are never reset by `eval`.

```lua
vm.defGlobal("name", value)   -- define or reset a global
vm.getGlobal("name")          -- returns value (or nil if undefined)
vm.setGlobal("name", value)   -- mutate existing global (returns bool)
```

From inside an expression, use `DEFGLOBAL` to define a global.

---

## Expression reference

### Values

| Expression | Description |
|---|---|
| `CONST(v)` | Evaluates to the literal value `v` |

### Arithmetic

| Expression | Description |
|---|---|
| `ADD(a, b)` | `a + b` |
| `SUB(a, b)` | `a - b` |
| `MUL(a, b)` | `a * b` |
| `DIV(a, b)` | `a / b` |
| `MOD(a, b)` | `a % b` |
| `POW(a, b)` | `a ^ b` |

### Comparison

| Expression | Description |
|---|---|
| `EQ(a, b)` | `a == b` |
| `LT(a, b)` | `a < b` |
| `LTE(a, b)` | `a <= b` |
| `GT(a, b)` | `a > b` |
| `GTE(a, b)` | `a >= b` |

### Control flow

| Expression | Description |
|---|---|
| `IF(cond, then_expr, else_expr)` | Conditional |
| `PROGN(e1, e2, ...)` | Sequence; evaluates all, returns value of last |
| `LOOP(body)` | Runs `body` repeatedly until `BREAK` is called |
| `BREAK(val...)` | Exits the innermost `LOOP`, returning `val...` |
| `YIELD(val...)` | Suspends execution, yielding `val...` to the caller |

### Variables

| Expression | Description |
|---|---|
| `LET(name, val_expr, body)` | Binds `name` to result of `val_expr` for the scope of `body` |
| `GET(name)` | Reads the innermost binding of `name` |
| `SET(name, val_expr)` | Mutates the innermost binding of `name` |
| `DEFGLOBAL(name, val_expr)` | Defines (or resets) a global variable |
| `TRACE(val_expr)` | Evaluates `val_expr` and sets the trace flag to its truthiness; evaluates to the value |

### Functions

| Expression | Description |
|---|---|
| `CALL(fn, arg1, ...)` | Calls a plain Lua function with evaluated arguments; passes through multiple return values |

### Error handling

| Expression | Description |
|---|---|
| `TRY(body, handler_fn)` | Runs `body`; if `THROW` fires, calls `handler_fn(err...)` which must return an expression |
| `THROW(val...)` | Transfers control to the active `TRY` handler, or raises a Lua error if none |
