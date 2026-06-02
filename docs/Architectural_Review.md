# Architectural Review: EventScript Compilation Pipeline

**Date:** 2026-06-02
**Scope:** Tokenizer → Parser → Compiler → CSP VM (4-layer pipeline)
**Goal:** Assess separation of concerns, identify abstraction leaks, and evaluate CSP.lua as a generic runtime target for other languages.

---

## 1. Current Architecture

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

Four layers, two of which (`Rule.lua`, `CSP.lua`) have bidirectional coupling through the `ER` global table. The CSP VM is not a sealed runtime — it reaches outward into `ER.getProp`, `ER.betw`, `ER.sourceTrigger`, and ten other EventScript-specific entry points.

---

## 2. Leak Inventory: CSP.lua

The CSP VM (`CSP.lua`, 902 lines) is the continuation-passing-style evaluator. It should know about CPS mechanics (trampoline, YIELD, LOOP/BREAK, TRY/THROW, variable scoping). In practice it had 19 call sites into `ER.*` — every one a leak.

### 2.1 Category: Device property system (HIGH)

| CSP primitive | ER call | Line | Why it leaks |
|---|---|---|---|
| `GETPROP` | `ER.getProp(obj, key, _ctx)` | 390 | Device properties are EventScript/HC3 concepts. A LISP runtime doesn't need `obj:value` to read a sensor. |
| `SETPROP` | `ER.setProp(obj, key, v, _ctx)` | 402 | Same. Setting a Fibaro device property (`light:on`) has no meaning in a generic VM. |

**Evidence:** `getProp`/`setProp` in `ScriptFuns.lua` resolve property objects via `ER.propFilters`, call `gp:getTrigger()`, and interact with the HC3 device model. The VM should never touch this.

### 2.2 Category: HC3 variable types (HIGH)

| CSP primitive | ER call | Line | Why it leaks |
|---|---|---|---|
| `GETVAR` | `ER.getVar(typ, name)` | 628 | `$var`, `$$var`, `$$$var` are Fibaro QuickApp concepts. The type strings `"GV"`, `"QV"`, `"PV"` are hardcoded both here and in `Compiler.lua`. |
| `SETVAR` | `ER.setVar(typ, name, v)` | 639 | Same. |

**Evidence:** `ER.getVar` in `Utils.lua:869` does `if typ == 'GV' then fibaro.getGlobalVariable(name)`. The type dispatch lives outside the VM but the type tags are a cross-cutting concern.

### 2.3 Category: Time semantics (MEDIUM)

| CSP primitive | ER call | Line | Why it leaks |
|---|---|---|---|
| `BETW` | `ER.betw(start, stop)` | 311 | Time-range check specific to EventScript's `07:00..08:00` syntax. Calls `ER.betw` which handles epoch vs. seconds-since-midnight disambiguation — domain logic that doesn't belong in a generic VM. |
| `NOW` | `ER.now()` | 837 | Wraps `os.time()` with Fibaro-specific adjustments. |

### 2.4 Category: Trigger variable notification (HIGH — worst leak)

| CSP primitive | ER call | Line | Why it leaks |
|---|---|---|---|
| `SET` | `ER._triggerVars[name]` + `ER.sourceTrigger:post(...)` | 597-598 | Every variable write in the VM notifies EventScript's trigger system. A generic VM shouldn't know trigger variables exist. |
| `INCVAR` | Same pattern | 610-611 | Same leak, doubled. |

### 2.5 Category: Async function dispatch (MEDIUM)

| CSP primitive | ER call | Line | Why it leaks |
|---|---|---|---|
| `CALL` | `ER.ASYNCFUNS[f]` check | 420 | The VM decides whether a function is async by consulting an EventScript-maintained table. A generic VM should ask the host: "is this async?" |

### 2.6 Category: Error formatting (LOW)

| Site | ER call | Line | Why it leaks |
|---|---|---|---|
| `eval()` | `ER.sourceMarker(src, pos, len)` | 506 | Error messages include source position markers — useful but the formatting logic is EventScript-specific. |
| `resume()` | Same pattern | 598 | |

### 2.7 Category: VM internals exposed globally (MEDIUM)

| Pattern | ER call | Line | Why it leaks |
|---|---|---|---|
| Context exposure | `ER._ctx = _ctx` | 422 | The CPS VM's internal context is stored on a global table so that `CFUN` wrappers can access it. Any code anywhere can read/write the VM's execution state. |

---

## 3. Leak Inventory: Rule.lua (Trigger Scanning)

`scanHead` in `Rule.lua` walks CSP AST nodes to discover triggers (device events, times, globals, custom events). This is a reverse compilation: it must understand every CSP opcode that can appear in a rule condition head.

### 3.1 General scanHead leak

| Aspect | Problem | Severity |
|---|---|---|
| Hardcoded opcode knowledge | `HOPS` dispatch table in Rule.lua (line 352-462) duplicates the compiler's knowledge of CSP AST structure | HIGH |
| AST walking | `scanHead` recursively descends CSP AST, knows which table positions are sub-expressions vs. literals | HIGH |
| In-place AST mutation | `HOPS.MAKETABLE` rewrites CSP instruction tables from `MAKETABLE` → `CFUN` on-the-fly (lines 438-455) | CRITICAL |

### 3.2 Specific HOPS entries

| Handler | What it does | Severity |
|---|---|---|
| `HOPS.GETPROP` | Evaluates obj expression at scan time; calls `ER.resolvePropObject` → `gp:getTrigger()` — whole device property system | HIGH |
| `HOPS.BETW` | Compiles CSP sub-expressions to evaluate time constants; inserts into `trs.between` — EventScript-specific | MEDIUM |
| `HOPS.DAILY` | Compiles CSP sub-expressions; inserts into `trs.dailys`; checks `catchValue` — EventScript-specific | MEDIUM |
| `HOPS.INTERV` | Asserts single-interval; stores `trs.interval` — EventScript-specific | MEDIUM |
| `HOPS.GETVAR` | Knows `"GV"` → `global-variable`, `"QV"` → `quickvar` — HC3 type system | HIGH |
| `HOPS.GET` | Reads `ER._triggerVars[name]` — global trigger registry | MEDIUM |
| `HOPS.MAKETABLE` | Creates `CFUN` wrappers with event-key closures; mutates AST in-place | CRITICAL |

---

## 4. Leak Inventory: Compiler.lua

The compiler (`Compiler.lua`, 475 lines) bridges Parser AST → CSP AST. Its leaks are mostly about assumed bindings in the CSP environment:

### 4.1 Hardcoded global names

| Parser node | Compiles to CSP that assumes | Line |
|---|---|---|
| `TODAY` | `ADD(GET('midnight'), expr)` — assumes `midnight` global exists | 322 |
| `NEXTTIME` | `CALL(GET('nexttime'), GET('midnight'), expr)` — assumes `nexttime` and `midnight` | 323 |
| `PLUSTIME` | `ADD(CALL(GET('ostime')), expr)` — assumes `ostime` global exists | 321 |

These globals are defined by `Rule.lua` at startup (e.g., `ER.defglobals.sunrise`, `ER.midnight()`). A LISP frontend would need to provide equivalent bindings or compile differently.

### 4.2 Hardcoded gensyms

| Pattern | Gensym | Line |
|---|---|---|
| `METHODCALL` | `__self__` | 411 |
| `FOR_IN` (single var) | `v_val` | 254 |
| `FOR_IN` (iterator) | `f_var`, `t_var` | 257 |

These are implementation details with low leak potential — any compiler needs temporary names. But they assume no user code will collide with these names.

### 4.3 Rule compilation assumptions

`compRuleBody` (line 454) wraps rules as:

```
IF(CALL(_ruleCondition, cond_ast), action_ast, RETURN(STRING(ER.ruleFail)))
```

This assumes:
- `_ruleCondition` is a callable function in the CSP environment
- `ER.ruleFail` is a sentinel string

Both are EventScript-specific.

### 4.4 Parser AST direct mapping

Many Parser AST nodes map 1:1 to CSP instructions (e.g., `AND` → `AND`, `IF` → `IF`). These are fine — they represent generic computation concepts. The problematic ones are: `GV`/`QV`/`PV` (hardcoded type strings), `TODAY`/`NEXTTIME`/`PLUSTIME` (time semantics), and `RULE` (trigger model).

---

## 5. The CSP VM as a Generic Target: Assessment

### What works (generic primitives)

These CSP instructions are language-agnostic and would map naturally to a LISP:

| CSP opcode | LISP equivalent |
|---|---|
| `CONST` | literal / quote |
| `GET` / `SET` / `LET` / `LETS` | `let` / `set!` |
| `IF` | `if` |
| `LOOP` / `BREAK` | `loop` / `break` (or tail recursion) |
| `CALL` / `CFUN` | function application |
| `LAMBDA` | `lambda` |
| `MAKETABLE` | `list` / `cons` / `vector` |
| `PROGN` | `begin` / `progn` |
| `TRY` / `THROW` / `RETURN` | `try`/`catch` / `throw` / `return` |
| `YIELD` | `call/cc` or async primitives |
| `ADD`, `SUB`, `MUL`, `DIV`, `MOD`, `POW` | `+`, `-`, `*`, `/`, `mod`, `expt` |
| `EQ`, `LT`, `LTE`, `GT`, `GTE` | `=`, `<`, `<=`, `>`, `>=` |
| `AND`, `OR`, `NOT` | `and`, `or`, `not` |
| `CONCAT` | `string-append` |
| `INDEX` / `SETINDEX` / `SETFIELD` | `aref` / `aset` / `setf` |

### What doesn't work (domain-specific primitives)

| CSP opcode | Problem |
|---|---|
| `GETPROP` / `SETPROP` | Device property reads/writes. LISP would call these through FFI, not as VM primitives. |
| `GETVAR` / `SETVAR` | HC3 variable types. No equivalent in a generic language. |
| `DAILY` / `INTERV` | EventScript trigger model. LISP would use library functions. |
| `BETW` | Time-range. A library function, not a VM primitive. |
| `NOW` | Calls `ER.now()` — Fibaro-specific. |
| `SET` / `INCVAR` trigger notification | Couples variable writes to EventScript's trigger system. |

### Verdict

**The CSP VM is ~70% generic.** The core CPS machinery (trampoline, YIELD, LOOP/BREAK, TRY/THROW, variable scoping, LAMBDA) is clean. The remaining 30% is EventScript/HC3 domain logic baked into VM primitives. To make the VM a viable target for LISP or any other language, all `ER.*` references must be removed and replaced with a pluggable host interface.

---

## 6. Recommendations

### 6.1 Introduce a HostInterface (PRIORITY 1)

Currently the CSP VM reaches into `ER` directly. Instead, pass a host interface to `eval()` and store it alongside `_ctx`:

```lua
-- Proposed _ctx extension
_ctx._host = {
  getProp   = function(obj, key, ctx) ... end,
  setProp   = function(obj, key, val, ctx) ... end,
  getVar    = function(typ, name) ... end,
  setVar    = function(typ, name, val) ... end,
  now       = function() ... end,
  betw      = function(start, stop) ... end,
  isAsync   = function(fn) ... end,          -- replaces ER.ASYNCFUNS check
  onVarWrite = function(name, val) ... end,   -- replaces ER.sourceTrigger:post
  formatSource = function(src, pos, len) ... end, -- replaces ER.sourceMarker
}

-- eval entry point change:
-- Before: eval(expr, opts)
-- After:  eval(expr, opts)  -- opts.host provides the interface
```

**Impact:** All 19 `ER.*` call sites in `CSP.lua` become `_ctx._host.*` calls. The VM becomes fully self-contained. EventScript provides a host implementation; LISP provides a different one; tests provide a mock.

### 6.2 Remove trigger notification from SET/INCVAR (PRIORITY 1)

This is the worst architectural violation. The VM's `SET` instruction should write a variable and stop. The trigger notification belongs in the host layer:

```lua
-- After SET writes the variable:
if _host and _host.onVarWrite then
  _host.onVarWrite(name, v)
end
-- or: the compiler wraps trigger-variable SETs in an explicit notification,
-- rather than baking it into every SET.
```

### 6.3 Remove ER._ctx exposure from CALL (PRIORITY 2)

The `ER._ctx = _ctx` pattern (line 422) exposes VM internals globally. Replace with explicit context threading:

- Option A: Only `CFUN` (which already receives `ctx` as an argument) is used for host-callable functions. Regular `CALL` never exposes `_ctx`.
- Option B: Store the host interface in `_ctx` and pass it to called functions explicitly, not via a global.

### 6.4 Separate trigger scanning from CSP AST (PRIORITY 2)

Currently `scanHead` in `Rule.lua` walks CSP AST nodes and must understand every opcode. Two directions:

**Option A: Trigger descriptors from the compiler.** When the compiler produces a CSP AST for a rule, it also produces a separate trigger-descriptor table:

```lua
-- Proposed compiler output for a rule:
{
  csp = {'IF', ...},           -- the compiled CSP expression
  triggers = {                 -- trigger descriptors (no AST walking needed)
    {type='device', device=54, property='value'},
    {type='daily', time_fn=...},
    {type='global', name='houseMode'},
  }
}
```

This moves trigger discovery from runtime AST walking to compile time, where it belongs.

**Option B: Annotation pass.** The compiler annotates CSP nodes with metadata that `scanHead` uses via a generic visitor, rather than `scanHead` hardcoding the structure of every opcode.

Either option eliminates Rule.lua's need to understand CSP AST internals.

### 6.5 Eliminate HOPS.MAKETABLE AST mutation (PRIORITY 2)

The in-place `MAKETABLE` → `CFUN` mutation (Rule.lua lines 438-454) should be moved to the compiler. The compiler, when processing `#EventName{fields...}`, should emit the event-key-checking wrapper directly in the CSP AST. The trigger scanner should not modify the AST.

### 6.6 Make EventScript primitives opt-in extensions (PRIORITY 3)

`DAILY`, `INTERV`, `BETW`, `GETPROP`, `SETPROP`, `GETVAR`, `SETVAR`, `NOW` can remain as CSP opcodes but should be documented as **host-dependent instructions** — they only work when the host interface provides the corresponding implementation. The core VM should treat them the same as `ADD` or `IF`: call the host function and return its result.

Currently `DAILY` and `INTERV` hardcode their semantics in the VM (reading `event.type` from the var environment). These should be generalized to host-callable functions.

### 6.7 Document the CSP IR contract (PRIORITY 3)

Create a formal specification of which CSP opcodes are:
- **Core** (guaranteed, language-agnostic): `CONST`, `GET`, `SET`, `LET`, `LETS`, `IF`, `LOOP`, `BREAK`, `PROGN`, `CALL`, `CFUN`, `LAMBDA`, `MAKETABLE`, `INDEX`, `SETINDEX`, `SETFIELD`, `RETURN`, `TRY`, `THROW`, `YIELD`, `DEFGLOBAL`, `PRINT`, `TRACE`, `INCVAR`, `ADD`, `SUB`, `MUL`, `DIV`, `MOD`, `POW`, `EQ`, `LT`, `LTE`, `GT`, `GTE`, `AND`, `OR`, `NOT`, `NEG`, `CONCAT`, `NILCO`
- **Host-extension** (require host interface): `GETPROP`, `SETPROP`, `GETVAR`, `SETVAR`, `BETW`, `NOW`
- **EventScript-only** (may be deprecated for generic use): `DAILY`, `INTERV`

---

## 7. Migration Path

### Phase 1: HostInterface (low risk, high value)
1. Define `HostInterface` table structure.
2. Add `_ctx._host` field, populated from `opts.host` in `eval()`.
3. Change one leak (e.g., `NOW`) from `ER.now()` to `_ctx._host.now()`.
4. Verify all existing tests pass.
5. Repeat for remaining 18 `ER.*` sites, one at a time.
6. EventScript's host implementation lives in `Rule.lua` (or a new `Host.lua`).

### Phase 2: Decouple trigger scanning
1. Add a trigger-descriptor-producing pass to `Compiler.lua`.
2. Have `Rule.lua` consume descriptors instead of walking CSP AST.
3. Remove `HOPS` dispatch table from `Rule.lua`.
4. Remove `HOPS.MAKETABLE` AST mutation.

### Phase 3: Generalize for multi-language
1. Split CSP opcodes into `core` and `extension` sets in the `expr` table.
2. Document the IR contract.
3. Implement a LISP frontend that produces CSP AST.
4. The LISP host interface provides `getProp` → FFI to HC3, `betw` → pure Lua implementation, etc.

---

## 8. Summary of Findings

| Area | Assessment |
|---|---|
| Parser (Tokenizer + Parser.lua) | Clean. Produces a reasonable Lua-like AST. Domain-specific syntax is the parser's job. |
| Compiler.lua | Mostly clean. Hardcoded global names and gensyms are minor. Rule compilation has EventScript assumptions but that's appropriate for this layer. |
| CSP.lua (the runtime) | **Problematic.** 19 `ER.*` references make it a coupled EventScript evaluator, not a generic CPS VM. The CPS machinery itself is sound — the leaks are in specific primitives that should be host-provided. |
| Rule.lua (trigger scanning) | **Problematic.** Walking CSP AST internals with hardcoded opcode knowledge duplicates compiler concerns. AST mutation in `HOPS.MAKETABLE` is indefensible. |
| Overall | The pipeline is well-structured in principle. The core issue is that CSP.lua was built as EventScript's evaluator from the start, with no boundary between "generic CPS VM" and "EventScript runtime services." A HostInterface is the minimal change that fixes this. |

---

## 9. Implementation Status (2026-06-02 Update)

The codebase has been substantially refactored since the original review. Below is a per-recommendation status, comparing the proposed design with what was actually shipped.

### 9.1 HostInterface — IMPLEMENTED (improved approach)

**What was proposed:** A flat `_ctx._host` table with 9 function pointers (getProp, setProp, getVar, setVar, now, betw, isAsync, onVarWrite, formatSource).

**What was implemented:** A two-layer design that is cleaner than the proposal:

*Layer 1 — Behavioral hooks (`vm.host`, CSP.lua:896-900):*
| Hook | Purpose | Default | Overridden by |
|---|---|---|---|
| `vm.host.isAsync(f)` | Async function detection | `return false` | Rule.lua → checks `ER.ASYNCFUNS` |
| `vm.host.onVarWrite(name, v)` | Variable-write side effects | no-op | Rule.lua → posts trigger-variable events |
| `vm.host.formatSource(src, pos, len)` | Error source formatting | default format | Rule.lua → uses `ER.sourceMarker` |

*Layer 2 — Instruction extension API (`vm.registerInstruction` / `vm.registerInstructions`, CSP.lua:883-894):*
Instead of baking domain primitives into the VM with host-provided implementations, domain primitives are registered as first-class CPS instruction implementations by the host layer. Rule.lua registers 7 instructions (GETPROP, SETPROP, GETVAR, SETVAR, DAILY, INTERV, BETW) via `vm.registerInstructions()` at lines 792-812.

**Result:** All 19 `ER.*` call sites have been removed from CSP.lua. The only remaining `ER.` reference in CSP.lua is the export `fibaro.ER.csp = vm` (line 902). The VM is now clean.

**Assessment:** The implemented approach is superior to the proposal. The flat-host-interface proposal would have required the VM to know about 9 specific domain concepts (getProp, betw, etc.). The extension API instead lets the VM remain genuinely unaware of what primitives exist — it just provides a mechanism for registering them. This is more extensible and cleaner.

### 9.2 Trigger notification from SET/INCVAR — IMPLEMENTED

SET (CSP.lua:532-541) and INCVAR (CSP.lua:544-556) now call `vm.host.onVarWrite(name, v)` instead of reaching into `ER._triggerVars` and `ER.sourceTrigger` directly. The trigger-variable notification logic lives entirely in Rule.lua (lines 815-819):

```lua
function vm.host.onVarWrite(name, val)
  if ER._triggerVars and ER._triggerVars[name] then
    ER.sourceTrigger:post({type='trigger-variable', name = name, value = val})
  end
end
```

**Assessment:** Exactly as proposed — the VM writes variables, the host decides whether to broadcast.

### 9.3 ER._ctx global exposure — IMPLEMENTED

The `ER._ctx = _ctx` global-assignment pattern is gone. A grep for `ER._ctx` across all 95 Lua files returns zero matches. The execution context is now a fully encapsulated object (CSP.lua:20-144) accessed through `vm.getCTX()` (line 875). Rule.lua's registered primitives use `ctx()` to reach into it when needed (e.g., GETPROP at line 716 reads `ctx()` to access var environment).

**Assessment:** Implemented in spirit. The context is still exposed to host primitives via `vm.getCTX()`, but this is a deliberate API rather than a global variable leak. The encapsulation of `_ctx` itself (private upvalues inside a `do/end` block, all access through methods) is well-done.

### 9.4 Separate trigger scanning from CSP AST — WON'T IMPLEMENT (not a leak)

`scanHead` (Rule.lua:457-462) walks CSP AST nodes using the `HOPS` dispatch table (lines 352-462). The original review framed this as a leak because scanHead "must understand every opcode" — but that framing assumed the CSP AST was a VM-internal detail.

After the refactoring, CSP.lua is a sealed VM. The CSP AST is the **published interface** between Compiler.lua and the VM. Rule.lua sits at the compiler level — it *produces* CSP AST (via `compileRuleBody` → Compiler.lua), *registers* CSP extension opcodes (via `registerInstructions`), and *inspects* the AST it produced to discover triggers. This is not a leak — it's the host layer reading its own output format.

**Why trigger descriptors would not help:** Adding a parallel descriptor format would duplicate trigger information — once in the CSP AST (for execution) and once in descriptors (for scanning). Every new opcode would need both a compiler change (emit descriptor) and a HOPS handler (consume descriptor). Same maintenance surface, different format, no actual decoupling. The CSP AST is already the canonical representation; making Rule.lua parse a shadow format instead of the AST it owns is indirection without benefit.

**Current risk:** Low. Rule.lua and Compiler.lua are both EventScript-specific and already co-maintained. Adding a new trigger type requires updating both files regardless of format — either in the AST structure (as now) or in a parallel descriptor schema.

### 9.5 HOPS.MAKETABLE AST mutation — IMPLEMENTED

The in-place `MAKETABLE` → `CFUN` mutation has been eliminated. The logic has been moved to compile time, where it belongs. The design uses three coordinated pieces:

**Compiler.lua** introduces an `isCondition` flag (line 11). When compiling a rule's condition body (`compileRuleBody`, line 476), this flag is set to `true`. While active, the TABLE handler (line 370) checks whether the table literal contains a `type` field — if it does, the table is recognized as an event descriptor (e.g., `#myEvent{type='foo'}`) and the compiler emits a `TRIGGER_EVENT(args, id)` CSP instruction instead of bare `MAKETABLE(args)`.

**Rule.lua** registers `TRIGGER_EVENT` as a CSP extension instruction (line 814). Its CPS implementation (line 769) evaluates the table and ID expressions, then checks `_evKey` from the variable environment against the event ID — the same event-matching logic that was previously done by the mutated `CFUN` wrapper.

**Trigger scanning** uses `HOPS.TRIGGER_EVENT` (line 439) to discover event triggers from the CSP AST. The old `HOPS.MAKETABLE` — which performed the AST mutation — is now a dead no-op (line 446) and is no longer in the HOPS dispatch table.

**Assessment:** Clean. The event-key-checking wrapper is now produced by the compiler, not by a runtime mutation of the AST. The `isCondition` scope is properly managed (set before compiling the condition, cleared immediately after). This moves the concern from runtime to compile time — exactly what the recommendation asked for.

### 9.6 EventScript primitives as opt-in extensions — IMPLEMENTED (improved approach)

Domain-specific primitives are no longer in the core `expr` table. They are registered by Rule.lua at startup via `vm.registerInstructions()`:

| Primitive | Registered by Rule.lua? | Still in core expr table? |
|---|---|---|
| GETPROP | Yes (line 793) | No |
| SETPROP | Yes (line 797) | No |
| GETVAR | Yes (line 801) | No |
| SETVAR | Yes (line 805) | No |
| DAILY | Yes (line 809) | No |
| INTERV | Yes (line 810) | No |
| BETW | Yes (line 811) | No |
| NOW | No — defined in CSP.lua:746-752 | Yes |

**NOW status:** NOW is still in the core `expr` table (CSP.lua:746-752), but it no longer calls `ER.now()`. It computes seconds-since-midnight directly using `os.date("*t")`. This makes it neutral — any host that has Lua's `os.date` available gets the same behavior. For a truly generic VM, this should be moved to an extension as well, since the concept of "seconds since midnight" is an HC3 convention.

**Assessment:** The extension mechanism (`registerInstruction` + `specialCompilers`) is a clean design. Each extension can provide both a CPS implementation and a custom compiler (for instructions with non-standard argument handling). Hosts can add or override primitives without modifying CSP.lua.

### 9.7 CSP IR contract documentation — IMPLEMENTED

The IR contract is now documented in `docs/CSP_README.md` (357 lines). The document specifies:

**Core opcodes (in `expr` table, CSP.lua:726-752):**
TR, PROGN, CALL, CONST, ADD, SUB, MUL, DIV, MOD, POW, EQ, LT, LTE, GT, GTE, NILCO, AND, OR, NOT, NEG, CONCAT, INDEX, SETINDEX, SETFIELD, INCVAR, MAKETABLE, IF, YIELD, LOOP, BREAK, DEFGLOBAL, TRACE, PRINT, LET, LETS, GET, SET, TRY, THROW, RETURN, CFUN, LAMBDA, NOW

**Extension opcodes (registered by Rule.lua):**
GETPROP, SETPROP, GETVAR, SETVAR, DAILY, INTERV, BETW, TRIGGER_EVENT

**Extension API:**
- `vm.registerInstruction(name, impl_fn, specialCompiler_fn)` — adds to `expr` table
- `vm.registerInstructions({name = {impl=..., compile=...}, ...})` — batch registration
- `vm.host.isAsync(fn)` — async function detection hook
- `vm.host.onVarWrite(name, val)` — variable-write hook
- `vm.host.formatSource(src, pos, len)` — error formatting hook
- `vm.getCTX()` — returns execution context (for host primitives that need var/env access)

---

## 10. Updated Verdict

| Area | Original Assessment | Current Assessment |
|---|---|---|
| Parser (Tokenizer + Parser.lua) | Clean | Unchanged — still clean |
| Compiler.lua | Mostly clean | Unchanged |
| CSP.lua (the runtime) | **Problematic** — 19 ER.* references | **Fixed** — zero ER.* references; clean extension API; well-encapsulated context |
| Rule.lua (trigger scanning) | **Problematic** — AST walking + MAKETABLE mutation | **Resolved** — MAKETABLE mutation eliminated; AST walking is legitimate (host layer reading its own output format, not a VM leak) |
| Extension mechanism | Did not exist | **New** — `registerInstruction`/`registerInstructions` is clean and well-designed |
| Host interface | Did not exist | **Implemented** — `vm.host` with 3 hooks covers the essential cross-cutting concerns |

**Overall:** All seven recommendations are now resolved — six implemented, one rejected on review (6.4). The implementation quality exceeds the original proposals in several areas — the instruction-extension API is more elegant than the flat-host-interface proposal, and the MAKETABLE mutation fix (6.5) cleanly separates compile-time event-table detection from runtime AST mutation via the `isCondition` flag. The CSP IR contract (6.7) is now documented in `docs/CSP_README.md` with opcode-level CSP table notation, stability guarantees, host-extension taxonomy, and a "Writing a new frontend" guide. The core CPS evaluator is genuinely self-contained and ready for alternative language frontends.
