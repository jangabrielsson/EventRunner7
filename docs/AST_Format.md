# EventScript AST Format Reference

## Compilation Pipeline

```
Source string
    │
    ▼
Tokenizer.lua       ──→  Token stream  (ER.tokenStream)
    │
    ▼
Parser.lua          ──→  Parser AST     (ER.parse / makeParser)
    │
    ▼
Compiler.lua        ──→  CSP AST        (ER.compileAST / ER.compileRuleBody)
    │
    ▼
CSP.lua             ──→  CPS function   (ER.csp.compile / ER.csp.eval)
```

There are **two AST representations** in EventScript:

1. **Parser AST** — High-level, Lua-like, produced by the recursive-descent parser. Every expression, statement, and rule is a Lua table where element `[1]` is an opcode string and subsequent elements are child nodes or raw values.

2. **CSP AST** — Low-level, instruction-oriented, produced by `Compiler.lua`. Targets the continuation-passing-style VM in `CSP.lua`. The CSP VM executes via a trampoline (`eval`/`trampoline`) and supports async `YIELD` for `wait()` and `sleep()`.

---

## Parser AST Reference

### Node metadata

Every Parser AST node may carry optional source-position fields (set via the `P()` helper):

| Field  | Type   | Description                      |
|--------|--------|----------------------------------|
| `_pos` | number | Byte offset in source string     |
| `_len` | number | Length of the source span        |

### Literals

| Opcode   | Shape                        | Example source        |
|----------|------------------------------|-----------------------|
| `NUMBER` | `{'NUMBER', value}`          | `42`, `3.14`, `07:30` |
| `STRING` | `{'STRING', "hello"}`        | `"hello"`, `'hello'`  |
| `BOOL`   | `{'BOOL', true|false}`       | `true`, `false`       |
| `NIL`    | `{'NIL'}`                    | `nil`                 |

Time literals (`HH:MM`, `HH:MM:SS`, `YYYY/MM/DD`, etc.) are tokenized directly as `NUMBER` (epoch or seconds-since-midnight).

### Identifiers and variables

| Opcode | Shape                    | Source form          |
|--------|--------------------------|----------------------|
| `NAME` | `{'NAME', "id"}`         | plain identifier     |
| `GV`   | `{'GV', "varName"}`     | `$varName`           |
| `QV`   | `{'QV', "varName"}`     | `$$varName`          |
| `PV`   | `{'PV', "varName"}`     | `$$$varName`         |

### Unary operators

| Opcode     | Shape                     | Source form       |
|------------|---------------------------|-------------------|
| `NEG`      | `{'NEG', expr}`           | `-expr`           |
| `NOT`      | `{'NOT', expr}`           | `!expr`, `not e`  |
| `DAILY`    | `{'DAILY', expr}`         | `@10:00`          |
| `INTERV`   | `{'INTERV', expr}`        | `@@00:05`         |
| `TODAY`    | `{'TODAY', expr}`         | `t/10:00`         |
| `NEXTTIME` | `{'NEXTTIME', expr}`      | `n/10:00`         |
| `PLUSTIME` | `{'PLUSTIME', expr}`      | `+/01:30`         |

### Binary operators

All binary operators follow the shape `{OPCODE, lhs, rhs}`.

| Opcode   | Source operator      | Notes                              |
|----------|----------------------|------------------------------------|
| `ADD`    | `+`                  |                                    |
| `SUB`    | `-`                  |                                    |
| `MUL`    | `*`                  |                                    |
| `DIV`    | `/`                  |                                    |
| `MOD`    | `%`                  |                                    |
| `POW`    | `^`                  |                                    |
| `EQ`     | `==`                 |                                    |
| `NEQ`    | `~=`                 |                                    |
| `LT`     | `<`                  |                                    |
| `LTE`    | `<=`                 |                                    |
| `GT`     | `>`                  |                                    |
| `GTE`    | `>=`                 |                                    |
| `AND`    | `&`                  | short-circuit (returns first falsy)|
| `OR`     | `\|`                 | short-circuit (returns first truthy)|
| `NILCO`  | `??`                 | nil-coalescing                     |
| `CONCAT` | `++`                 | string concatenation               |
| `BETW`   | `..`                 | time-range (compiles to ER.betw()) |

### Field access, indexing, and properties

| Opcode      | Shape                                   | Source form               |
|-------------|-----------------------------------------|----------------------------|
| `PAREN`     | `{'PAREN', expr}`                       | `(expr)`                   |
| `INDEX`     | `{'INDEX', obj, key}`                   | `obj[key]`                 |
| `FIELD`     | `{'FIELD', obj, "fieldname"}`           | `obj.field`                |
| `GETPROP`   | `{'GETPROP', obj, "propname"}`          | `obj:propname`             |
| `SETPROP`   | `{'SETPROP', obj, "propname", value}`   | `obj:propname = value`     |

For `GETPROP`: the compiler keeps `key` as a raw string (not an expression). It resolves to `ER.getProp(obj, key)` at runtime.

For `FIELD`: compiled to `INDEX(obj, CONST("fieldname"))` — plain Lua table field access.

### Calls

| Opcode       | Shape                                              | Source form              |
|--------------|----------------------------------------------------|--------------------------|
| `CALL`       | `{'CALL', func, arg1, arg2, ...}`                  | `f(a, b)`                |
| `METHODCALL` | `{'METHODCALL', obj, "method", arg1, ...}`         | `obj:method(a, b)`       |

`METHODCALL` is syntactic sugar: the compiler wraps it as a `CALL` where `self` (the object) is passed as the first argument, matching Lua's `:` semantics.

### Statements

| Opcode            | Shape                                                      | Source form                          |
|-------------------|------------------------------------------------------------|--------------------------------------|
| `ASSIGN`          | `{'ASSIGN', {vars...}, {vals...}}`                         | `x, y = 1, 2`                        |
| `INCVAR`          | `{'INCVAR', var, expr, op}`                                | `x += 5` (`op` is `"plus"`)          |
| `LOCAL`           | `{'LOCAL', {names...}, {values...}}`                       | `local x, y = 1, 2`                  |
| `LOCAL_FUNCTION`  | `{'LOCAL_FUNCTION', name, funcbody}`                       | `local function f() ... end`         |
| `FUNCTION_STAT`   | `{'FUNCTION_STAT', name, funcbody}`                        | `function f() ... end`               |
| `IF`              | `{'IF', cond, then_block, elseifs, else_block}`            | `if ... then ... elseif ... else ... end` |
| `WHILE`           | `{'WHILE', cond, body}`                                    | `while ... do ... end`               |
| `REPEAT`          | `{'REPEAT', body, cond}`                                   | `repeat ... until ...`               |
| `FOR_NUM`         | `{'FOR_NUM', name, start, limit, step, body}`              | `for i=1,10,2 do ... end`            |
| `FOR_IN`          | `{'FOR_IN', {names...}, {iters...}, body}`                 | `for k,v in pairs(t) do ... end`     |
| `DO`              | `{'DO', body}`                                             | `do ... end`                         |
| `RETURN`          | `{'RETURN', val1, val2, ...}`                              | `return x, y`                        |
| `BREAK`           | `{'BREAK'}`                                                | `break`                              |

**IF node details:** `elseifs` is a list of `{cond, block}` pairs. `else_block` is `nil` when absent.

**FOR_NUM:** `step` is `nil` when absent (defaults to 1 in the compiler).

**FOR_IN:** `names` is a single-name list for `for v in ...`, or `{k, v}` for `for k,v in ...`. When only one name is given, the parser adds an implicit `'v_val'` key variable.

### Blocks and scripts

| Opcode   | Shape                           | Description                      |
|----------|---------------------------------|----------------------------------|
| `BLOCK`  | `{'BLOCK', stat1, stat2, ...}`  | Sequence of statements           |
| `SCRIPT` | `{'SCRIPT', block}`             | Top-level script (non-rule code) |

### Rules

| Opcode | Shape                                      | Description           |
|--------|--------------------------------------------|-----------------------|
| `RULE` | `{'RULE', condition_ast, action_ast [, {modifiers}]}` | EventScript rule |

**Modifier table** (optional fourth element): `{single=true}` when the `single` modifier is present. Other modifiers (`since`, `debounce`, `cooldown`, `every`, `first_in`) are desugared directly into the condition AST by the parser rather than stored as flags.

### Functions

| Opcode     | Shape                                 | Source form               |
|------------|---------------------------------------|---------------------------|
| `FUNCTION` | `{'FUNCTION', {params...}, body}`     | `function(p1,p2) ... end` or `(p1,p2) -> expr` |

Lambda arrow syntax (`x -> expr`, `(a,b) -> expr`) parses to `FUNCTION` nodes. List comprehensions desugar inline to `BLOCK` containing `LOCAL` + `FOR_IN` — no dedicated AST node.

### Tables

| Opcode        | Shape                             | Source form         |
|---------------|-----------------------------------|---------------------|
| `TABLE`       | `{'TABLE', field1, field2, ...}`  | `{1, 2, a=3}`       |
| `TFIELD_NAME` | `{'TFIELD_NAME', "key", value}`   | `{name = value}`    |
| `TFIELD_EXPR` | `{'TFIELD_EXPR', key_expr, value}`| `{[expr] = value}`  |
| `TFIELD_VAL`  | `{'TFIELD_VAL', value}`           | `{value}` (positional) |

Table fields can be separated by `,` or `;`.

### Special

| Opcode | Shape      | Description                            |
|--------|------------|----------------------------------------|
| `NOW`  | `{'NOW'}`  | Current time (evaluates to `ER.now()`) |

### Operator precedence (lowest → highest)

```
or (|)
and (&)
nilco (??)
comparison (==, ~=, <, <=, >, >=)
concat (++), between (..)    ← same level
addition (+), subtraction (-)
multiplication (*), division (/), modulo (%)
unary (-, !, t/, n/, +/)
power (^)
```

Pre-rule unary operators `@` (daily) and `@@` (interval) have lower precedence than arithmetic so `@sunset-01:00` parses as `@(sunset - 01:00)`.

### Scene declarations

The `scene` soft keyword desugars inline at parse time:

```lua
scene lights = {
    kitchen:on = true,
    activate: { hall:on = true }
    deactivate: { hall:off = true }
}
```

Becomes an `ASSIGN` to the name with a `CALL` to `Scene(...)`. No dedicated AST node.

---

## CSP AST Reference (Compiler output)

The CSP AST is the instruction set for the continuation-passing-style VM. Every CSP node is a Lua table where `[1]` is an opcode string. Scalar values (numbers, strings, booleans) are implicitly wrapped in `CONST` by `CSP.compile()`.

### Constants and literals

| Opcode  | Shape              | Description                         |
|---------|--------------------|-------------------------------------|
| `CONST` | `{'CONST', v}`     | Constant value (any Lua type)       |

Pascal AST `NUMBER`, `STRING`, `BOOL`, `NIL` all compile to `CONST` (or raw values auto-wrapped by `ca()`).

### Binary operations

| Opcode   | Shape                          | Description                      |
|----------|--------------------------------|----------------------------------|
| `ADD`    | `{'ADD', lhs, rhs}`            | Arithmetic addition              |
| `SUB`    | `{'SUB', lhs, rhs}`            | Subtraction                      |
| `MUL`    | `{'MUL', lhs, rhs}`            | Multiplication                   |
| `DIV`    | `{'DIV', lhs, rhs}`            | Division                         |
| `MOD`    | `{'MOD', lhs, rhs}`            | Modulo                           |
| `POW`    | `{'POW', lhs, rhs}`            | Exponentiation                   |
| `EQ`     | `{'EQ', lhs, rhs}`             | Equality (uses `msstr` coercion) |
| `LT`     | `{'LT', lhs, rhs}`             | Less-than                        |
| `LTE`    | `{'LTE', lhs, rhs}`            | Less-or-equal                    |
| `GT`     | `{'GT', lhs, rhs}`             | Greater-than                     |
| `GTE`    | `{'GTE', lhs, rhs}`            | Greater-or-equal                 |
| `AND`    | `{'AND', lhs, rhs}`            | Logical AND (short-circuit)      |
| `OR`     | `{'OR', lhs, rhs}`             | Logical OR (short-circuit)       |
| `NILCO`  | `{'NILCO', lhs, rhs}`          | Nil-coalescing                   |
| `CONCAT` | `{'CONCAT', lhs, rhs}`         | String concatenation             |
| `BETW`   | `{'BETW', lhs, rhs}`           | Time-range check                 |

`NEQ` (from Parser AST) compiles to `{'NOT', {'EQ', lhs, rhs}}`.

### Unary operations

| Opcode   | Shape               | Description                       |
|----------|---------------------|-----------------------------------|
| `NOT`    | `{'NOT', expr}`     | Logical negation                  |
| `NEG`    | `{'NEG', expr}`     | Arithmetic negation               |
| `DAILY`  | `{'DAILY', expr}`   | Daily trigger flag check          |
| `INTERV` | `{'INTERV', expr}`  | Interval trigger flag check       |

### Variable environment (lexical scoping)

| Opcode      | Shape                                              | Description                              |
|-------------|----------------------------------------------------|------------------------------------------|
| `GET`       | `{'GET', "name"}`                                  | Read variable (local → global → _G)      |
| `SET`       | `{'SET', "name", val}`                             | Write variable                           |
| `LET`       | `{'LET', "name", val, body}`                       | Single let-binding                       |
| `LETS`      | `{'LETS', {"n1","n2",...}, {v1,v2,...}, body}`     | Multi let-binding (parallel evaluation)  |
| `INCVAR`    | `{'INCVAR', "name", "OP", val}`                     | Compound assignment (`+=`, `-=`, etc.)   |
| `DEFGLOBAL` | `{'DEFGLOBAL', "name", val}`                       | Define a global variable                 |

**Scope semantics:** Variables are boxed as `{value}` so `nil` is a valid binding. `LET`/`LETS` push a new frame with metatable-based shadowing. `GET` searches local chain first, then globals, then raw `_G`.

### Special variables (HC3 integration)

| Opcode   | Shape                                  | Description                           |
|----------|----------------------------------------|---------------------------------------|
| `GETVAR` | `{'GETVAR', "GV"|"QV"|"PV", "name"}`  | Read Fibaro variable                  |
| `SETVAR` | `{'SETVAR', "GV"|"QV"|"PV", "name", v}`| Write Fibaro variable                |

- **GV** — Fibaro global variable (`$name`)
- **QV** — QuickApp variable (`$$name`)
- **PV** — Persistent/internalStorage variable (`$$$name`)

These call `ER.getVar()` / `ER.setVar()` at runtime.

### Table and field access

| Opcode     | Shape                                    | Description                        |
|------------|------------------------------------------|------------------------------------|
| `INDEX`    | `{'INDEX', obj, key}`                    | Table read (`obj[key]`)            |
| `SETINDEX` | `{'SETINDEX', obj, key, val}`            | Table write (`obj[key] = val`)     |
| `SETFIELD` | `{'SETFIELD', obj, "key", val}`          | Field write (`obj.key = val`)      |

Note: `key` in `SETFIELD` is a raw string, while in `INDEX`/`SETINDEX` it's a compiled expression.

### Device property access

| Opcode    | Shape                                 | Description                          |
|-----------|---------------------------------------|--------------------------------------|
| `GETPROP` | `{'GETPROP', obj, "prop"}`            | Device property read (key is raw string) |
| `SETPROP` | `{'SETPROP', obj, "prop", val}`       | Device property write (key is raw string) |

Calls `ER.getProp(obj, key)` / `ER.setProp(obj, key, val)` at runtime. The property system resolves objects (device IDs, collections, custom classes) and provides trigger subscriptions for rule activation.

### Function calls

| Opcode  | Shape                               | Description            |
|---------|-------------------------------------|------------------------|
| `CALL`  | `{'CALL', func, arg1, arg2, ...}`   | Function application   |
| `CFUN`  | `{'CFUN', raw_lua_fn, arg1, ...}`   | Call raw Lua function  |

`CALL` evaluates `func` as an expression, evaluates args, then invokes. Supports async functions via `ER.ASYNCFUNS` (triggers `YIELD`). `CFUN` takes a direct Lua function reference (not an expression) and passes `(continuation, ctx_snapshot, ...args)`.

### Control flow

| Opcode   | Shape                                  | Description                              |
|----------|----------------------------------------|------------------------------------------|
| `IF`     | `{'IF', cond, then_br, else_br}`       | Conditional (else_br optional)           |
| `LOOP`   | `{'LOOP', body}`                       | Infinite loop (exit via BREAK)           |
| `BREAK`  | `{'BREAK'}`                            | Break out of innermost LOOP              |
| `RETURN` | `{'RETURN', val, ...}`                 | Early exit from expression               |
| `TRY`    | `{'TRY', body, handler_fn}`            | Try-catch (handler_fn is raw Lua function)|
| `THROW`  | `{'THROW', val, ...}`                  | Throw to active error handler            |
| `PROGN`  | `{'PROGN', e1, e2, ..., en}`           | Sequential evaluation (returns last)     |

**IF:** The `else_br` argument is optional. When absent, the false branch returns `nil`.

**WHILE** compiles to: `LOOP(IF(cond, body, BREAK()))`.

**REPEAT** compiles to: `LOOP(body, IF(cond, BREAK()))`.

**FOR_NUM** compiles to: `LET(var, start, LOOP(IF(GT(GET(var), end), BREAK), body, SET(var, ADD(GET(var), step))))`.

**FOR_IN** compiles to: `LETS({f,t,k,v}, {iter_fn}, LOOP(PROGN(ASSIGN k,v = f(t,k), IF(NOT(k), BREAK), body)))`.

### Async / YIELD

| Opcode  | Shape                                 | Description                   |
|---------|---------------------------------------|-------------------------------|
| `YIELD` | `{'YIELD', "sleep"|nil, time}`       | Suspend and resume later      |

The `YIELD` instruction pauses the CPS trampoline and returns a token that the runtime can `resume()` later. Used by `wait(seconds)` which compiles to `YIELD('sleep', seconds)`.

### Tables and functions

| Opcode      | Shape                                           | Description                             |
|-------------|-------------------------------------------------|-----------------------------------------|
| `MAKETABLE` | `{'MAKETABLE', k1, v1, k2, v2, ...}`            | Table construction (key-value pairs)    |
| `LAMBDA`    | `{'LAMBDA', {"p1","p2",...}, body}`             | Anonymous function (captures env)       |

**MAKETABLE keys** are compiled expressions. **LAMBDA params** are raw name strings; `body` is a compiled CSP expression. `LAMBDA` returns a Lua function that, when called, evaluates `body` with params bound to arguments.

### Debug and utilities

| Opcode  | Shape                      | Description                           |
|---------|----------------------------|---------------------------------------|
| `PRINT` | `{'PRINT', arg1, ...}`    | Print to HC3 console                  |
| `TRACE` | `{'TRACE', val}`           | Set trace flag (boolean)              |
| `NOW`   | `{'NOW'}`                  | Current Unix timestamp                |
| `TR`    | `{'TR', continuation_fn}`  | Wraps a continuation (internal helper)|

---

## Parser AST → CSP AST mapping summary

| Parser AST node      | CSP AST output                                          |
|----------------------|---------------------------------------------------------|
| `NUMBER` / `STRING`  | `CONST` (or raw scalar)                                 |
| `BOOL`               | `CONST`                                                 |
| `NIL`                | `CONST(nil)`                                            |
| `NAME`               | `GET(name)`                                             |
| `GV` / `QV` / `PV`   | `GETVAR(type, name)`                                    |
| `NEG`                | `NEG`                                                   |
| `NOT`                | `NOT`                                                   |
| `DAILY`              | `DAILY(expr)`                                           |
| `INTERV`             | `INTERV(expr)`                                          |
| `TODAY`              | `ADD(GET('midnight'), expr)`                            |
| `NEXTTIME`           | `CALL(GET('nexttime'), GET('midnight'), expr)`          |
| `PLUSTIME`           | `ADD(CALL(GET('ostime')), expr)`                        |
| `ADD`/`SUB`/etc.     | Same (direct binop mapping)                             |
| `EQ`/`LT`/etc.       | Same                                                    |
| `NEQ`                | `NOT(EQ(lhs, rhs))`                                     |
| `AND` / `OR`         | Same                                                    |
| `NILCO`              | Same                                                    |
| `CONCAT`             | Same                                                    |
| `BETW`               | Same                                                    |
| `PAREN`              | Compile inner expression directly                       |
| `INDEX`              | `INDEX(obj, key)`                                       |
| `FIELD`              | `INDEX(obj, CONST("field"))` — key is raw string         |
| `GETPROP`            | `GETPROP(obj, "prop")` — key is raw string               |
| `SETPROP`            | `SETPROP(obj, "prop", val)` — key is raw string          |
| `CALL`               | `CALL(func, args...)`                                   |
| `METHODCALL`         | `LET('__self__', obj, CALL(INDEX(GET('__self__'), method), GET('__self__'), args...))` |
| `ASSIGN`             | `SET` / `SETINDEX` / `SETFIELD` / `SETVAR`             |
| `INCVAR`             | `INCVAR(name, op, val)`                                 |
| `LOCAL`              | `LET` / `LETS` (hoisted across subsequent statements)   |
| `IF`                  | `IF` (with nested IF for elseif)                        |
| `WHILE`              | `LOOP(IF(cond, body, BREAK()))`                         |
| `REPEAT`             | `LOOP(body, IF(cond, BREAK()))`                         |
| `FOR_NUM`            | `LET + LOOP + IF + BREAK`                               |
| `FOR_IN`             | `LETS + LOOP + PROGN + IF + BREAK`                      |
| `DO`                 | Compile inner body directly                             |
| `RETURN`             | `RETURN`                                                |
| `BREAK`              | `BREAK`                                                 |
| `BLOCK` / `SCRIPT`   | `PROGN` (or single expression if one statement)         |
| `RULE`               | `IF(CALL(_ruleCondition, cond), action, RETURN(STRING(ER.ruleFail)))` |
| `FUNCTION`           | `LAMBDA(params, body)`                                  |
| `TABLE`              | `MAKETABLE(k1, v1, k2, v2, ...)`                        |
| `NOW`                | `NOW`                                                   |

### Intrinsics (special `CALL` handling)

When `CALL` targets a bare `NAME`, `Compiler.lua` checks the `intrinsics` table for special handling:

| Function call       | CSP output                              |
|---------------------|-----------------------------------------|
| `wait(seconds)`     | `YIELD('sleep', seconds)`               |
| Other intrinsics    | Defined by `ER.intrinsics` table entries|

---

## Source position tracking

Both AST layers support source-position annotation for error messages:

- **Parser AST:** Nodes carry `_pos` and `_len` fields (set by `P()` helper).
- **CSP AST:** The compiler optionally produces a `_srcmap` table that maps CSP instruction tables → `{pos, len}`. When active, `CSP.compile()` wraps instrumented closures to set `_ctx._curpos` before execution. This enables error messages to annotate the exact source location.

Use `ER.compileASTWithMap(ast)` to get both the CSP tree and the srcmap.

---

## Rule compilation specifics

Rules go through a special path:

1. Parser produces `{'RULE', cond_ast, action_ast [, modifiers]}`.
2. `ER.compileRuleBody()` wraps the rule as:
   ```
   IF(CALL(_ruleCondition, cond_ast), action_ast, RETURN(STRING(ER.ruleFail)))
   ```
3. The `_ruleCondition` function at runtime calls the condition compiled CSP and returns true/false.
4. When the condition is false, `RETURN(STRING(ER.ruleFail))` causes an early exit with a sentinel value — the rule runner detects this and suppresses the action.

Modifiers are preserved in the CSP result table as `_modifiers` for the rule runner to handle at runtime.

---

## Runtime VM (CSP.lua)

The CSP VM executes expressions via continuation-passing style:

- Every CSP instruction is a function `(continuation) → ...`
- The `trampoline()` loop drives evaluation without stack growth.
- `YIELD` returns `('suspended', token, ...values)` — the caller can `resume(token, new_value)` to continue.
- `LOOP`/`BREAK` manage a break-continuation stack.
- `TRY`/`THROW` manage an error-handler stack with snapshot/restore.
- Variable scopes use metatable-chained frames (boxed values).

The VM entry points are:
- `ER.csp.eval(expr, opts)` — evaluate an expression, returns `'ok', value` or `'suspended', token, yields`
- `ER.csp.resume(token, ...)` — resume a suspended expression
- `ER.csp.compile(tree, srcmap)` — compile CSP tree → CPS function
