# EventRunner7 — Architecture & Language Review

> Written 2026-06-03 by CodeWhale (deepseek-v4-pro) after a deep read of
> CSP.lua, Rule.lua, Compiler.lua, and docs/EventScript.md.
> This is an external perspective — treat it as a structured set of observations,
> not a mandate.

---

## 1. Async / Wait Architecture

### Current design

Two parallel paths converge at `resumeRunner` in Rule.lua:

```
Path A — wait(n):
  Compiler intrinsic → YIELD('sleep', n)
  → CSP trampoline → 'suspended', cf, 'sleep', n
  → resumeRunner → yieldHandlers.sleep → setTimeout → resume(cf, ms)

Path B — asyncFun(f, args):
  CALL(f, args) → vm.host.isAsync(f) → YIELD('asyncFun', f, args)
  → CSP trampoline → 'suspended', cf, 'asyncFun', f, args
  → resumeRunner → yieldHandlers.asyncFun → f(cb, args) + timeout → resume(cf, ...)
```

### Verdict: correct and defensible

The layering is clean:

| Layer | Knows about | Doesn't know about |
|-------|------------|-------------------|
| CSP (`YIELD`, `trampoline`) | Suspension/resumption tokens, context snapshots | Timers, callbacks, HC3, logging |
| Rule (`yieldHandlers`, `resumeRunner`) | Timers, async callbacks, logging, cancellation | CSP internals, compilation |

The `yieldHandlers` dispatch table is the boundary — the same pattern used in
effect systems (OCaml 5, Koka, Haskell's IO).

### Should `wait` be folded into `asyncFun`?

Technically possible but **not recommended**. Reasons:

1. **Extra trampoline overhead.** `YIELD('sleep', n)` is one suspension.
   `CALL(asyncWait, n)` requires arg evaluation → `isAsync` check → a second
   yield — two cycles for a primitive.

2. **Wrong timeout semantics.** The `asyncFun` handler defaults to 3 s timeout.
   `wait(60)` would get killed. Special-casing timeout for `wait` defeats the
   unification.

3. **`wait` is a language construct, not a library function.** The compiler
   intrinsic `YIELD('sleep', n)` honestly represents what it is: a suspension
   point at the language level.

### Real simplification opportunities

1. **Extract shared timer management.** Both `sleep` and `asyncFun` handlers
   set timers and track them for cancellation (`ctx.timers` / `timeref`).
   A single `scheduleTimer(ctx, ms, onFire)` helper used by both would
   eliminate duplicated timer lifecycle code.

2. **Extract the `safeResume` pattern.** This incantation appears verbatim
   three times (lines 476-481, 500-504, 516-521 in Rule.lua):

   ```lua
   local ok, err = pcall(function()
     resumeRunner(table.pack(ER.csp.resume(cf, ...)), ctx, cb)
   end)
   if not ok then
     ctx:log("normal", o.errorPrefix, err)
   end
   ```

   Extract to a single function: `safeResume(cf, ctx, cb, ...)`.

3. **Consider opening the yield handler table.** Users (or at least the
   compiler) should be able to register new yield tags for custom async
   primitives, rather than forcing everything through the callback-based
   `asyncFun` path. Example:

   ```lua
   er.registerYieldHandler('http.get', function(cf, ctx, cb, url)
     net.HTTPClient():request(url, {
       success = function(resp) safeResume(cf, ctx, cb, resp) end,
       error   = function(err)  safeResume(cf, ctx, cb, nil, err) end,
     })
   end)
   ```

   Then a compiler intrinsic maps `http.get(url)` → `YIELD('http.get', url)`.

---

## 2. EventScript Language Verdict

EventScript is a **genuinely well-designed home automation DSL**. It occupies
a sweet spot: more expressive than YAML rule engines (Home Assistant), less
boilerplate than raw Lua/Python, and with language-level primitives for the
patterns that actually matter in home automation.

### What's excellent

- **`trigger => action` syntax.** Matches the mental model. "When X happens, do Y."
- **Rule modifiers.** `single`, `debounce`, `cooldown`, `since`, `every`,
  `first_in` — solve real automation problems at the language level. The fact
  that `debounce` implies `single` shows design thought.
- **Property system.** `device:property` as a unified read+trigger syntax.
  List aggregations (`:average`, `:someTrue`). Custom property classes
  (`er.definePropClass`) make it extensible without touching the core.
- **List comprehensions and arrow lambdas.** `[x*2 for x in t if x>0]` and
  `x -> x*2` in a home automation DSL shows genuine ambition. These are
  table-stakes in general-purpose languages but rare in this domain.
- **Scenes as first-class values.** Activate/deactivate semantics with
  lazy evaluation of expressions (re-evaluated on each activation, not
  captured at declaration time) — correct default.
- **Separation of trigger scanning from evaluation.** The compiler scans the
  trigger expression to discover subscriptions before generating evaluation
  code. Right architecture.

### Where it hurts users

The main friction is **not** in the language design — it's in three
cross-cutting concerns: **discoverability** (users don't know what's possible),
**debuggability** (users can't tell why something failed), and the
**string-embedding UX tax** (no highlighting, no autocomplete, no inline
errors for code inside `rule("...")` strings).

---

## 3. Prioritized Improvements

### Tier 1 — High impact, low implementation cost

#### 3.1 Rule inspector / diagnostic function

The single biggest pain point in any automation system is "why didn't my rule
fire?" The data is already collected (`rule.stats`, `rule.timers`,
`trs.triggers`). Expose it:

```lua
er.inspect("myRule")
-- Rule 3: motion:breached => light:on
--   Status: enabled
--   Last fired: 08:15:32 ✓   (47 fires, 3 fails)
--   Active timers: none
--   Subscribed to: device[55].value, time[08:00]
```

This alone would dramatically reduce support questions.

#### 3.2 Friendlier runtime errors with rule context

The CSP error enrichment at `CSP.lua:644-651` adds source positions. Add the
rule name and trigger event:

```
Before:  #Attempt to index a non-table value: nil with key 'value'
After:   [Rule:3 "motion:breached => light:on"] Triggered by device[55].value:
           #Attempt to index a non-table value: nil with key 'value'
```

The difference between these two messages is the difference between a confused
forum post and a self-solved problem. The `ctx` and `opts.rule` are available
at the enrichment point.

#### 3.3 Parse errors with caret markers

The source map already maps CSP instructions to character positions inside the
rule string. Use it to print visual carets:

```
Error in rule at line 42:
  motion:breached =>   light:on
                      ^^ unexpected token
```

This makes the DSL feel like a real language rather than a string that
sometimes works.

### Tier 2 — Medium impact, moderate work

#### 3.4 Explicit trigger/guard separation in syntax

The current model — "everything before `=>` is both subscription key and
guard" — is powerful but confusing. The compiler already separates these
conceptually. Make it visible:

```
Current:   rule("motion:breached & lux < 100 => light:on")
Proposed:  rule("on motion:breached when lux < 100 => light:on")
```

- `on X` — declares what events to subscribe to (device refs, event patterns
  only — no side effects, no control flow)
- `when Y` — guard expression evaluated at fire time
- `=> action` — unchanged

Backward-compatible: when `on` is absent, the whole expression is both
subscription and guard, exactly as today.

Benefits:
- Users understand the two-phase evaluation model
- "I put a side effect in the trigger" mistakes become parse errors
- The compiler can give better error messages ("'on' clause can only contain
  device properties and event patterns")

#### 3.5 Property type annotations

```lua
er.addStdProp("temp", {
  type = "number",   -- new optional field
  get = function(prop, id, event) ... end,
  trigger = { type = 'device', property = 'value' },
})
```

Then at compile time: `temp:value > 'hello'` → warning: "comparing number
property 'temp' to string." Catches a common class of silent bugs before they
reach runtime.

Supported types: `"number"`, `"string"`, `"boolean"`, `"table"`, `"any"`
(default for unannotated properties).

#### 3.6 Staggered action helper

The CSP `wait()` already supports mid-loop suspension, enabling staggered
execution:

```lua
rule("@08:00 => for _,l in ipairs(lights) do l:on; wait(0.5) end")
```

This is a power feature that users won't discover. Add a dedicated helper
that signals intent:

```lua
rule("@08:00 => stagger(lights, 'on', 0.5)")
```

`stagger(list, action, delay_seconds)` turns on each light 0.5 s apart.
Sugar for the `for`+`wait` pattern, but prevents off-by-one errors and
documents the feature by its existence.

### Tier 3 — Longer-term, ecosystem-level

#### 3.7 Reusable rule library / import system

Every EventRunner user starts from a blank `main()`. A minimal `use()`
directive:

```lua
use "github:user/repo/motion-lighting.er"   -- remote
use "./my-helpers.er"                        -- local file
```

Even a simple textual include (paste the file contents inline before
compilation) would unlock code sharing and let users build up libraries
of common patterns.

A shared repository of community rules (motion-lighting, away-mode,
energy-saving, notification-throttling) would drive adoption more than
any single language feature.

#### 3.8 VS Code language support

The `rule("...")` string embedding means no syntax highlighting, no
autocomplete, no inline error squiggles. A VS Code extension that:

- Highlights EventScript inside `rule("...")` strings
- Auto-completes `deviceID:prop` from the HC3 device list (fetched via plua)
- Shows trigger subscriptions on hover
- Underlines parse errors with red squiggles

This would be the single biggest daily UX improvement. The plua setup already
has VS Code integration — this is the natural extension.

#### 3.9 Fix or document the `case` statement

The current docs show:

```lua
case
  || <test> >> <statements>
  || <test> >> <statements>
  :
  || <test> >> <statements>
end
```

- `||` for cases is non-standard
- `>>` for the action body is unusual
- `:` as a separator is undocumented — is it a fallthrough barrier? A default
  case marker?

If this is stable, document it with examples showing fallthrough behavior and
the meaning of `:`. If experimental, move it out of the main language docs
and into a "preview features" section.

---

## 4. What NOT to change

These aspects of the design are correct and should be preserved:

- **CSP as the evaluation model.** The trampoline + yield/resume pattern is
  the right foundation for cooperative concurrency in a single-threaded HC3
  QuickApp. Don't replace it with callbacks or promises.

- **The two-path async design.** Keeping `sleep` as a compiler intrinsic
  (`YIELD('sleep', n)`) separate from the `asyncFun` callback protocol is the
  simpler design, not the more complex one. Don't merge them.

- **The property system's `obj:prop` syntax.** It's intuitive, consistent
  across reads/triggers/writes, and extensible. Don't add a separate
  "trigger syntax" or "action syntax."

- **Rule modifiers as postfix keywords.** They compose cleanly
  (`single cooldown 2`) and read naturally. Don't move them to a separate
  configuration table.

- **The guard-is-the-trigger model** (in its current form). While the `on X
  when Y` syntax proposed above clarifies intent, the underlying architecture
  — scanning the guard expression for subscriptions — is correct and should
  remain. The proposed syntax change is sugar, not a semantic change.

---

## 5. Summary table

| # | Improvement | Impact | Effort | Section |
|---|------------|--------|--------|---------|
| 1 | Rule inspector (`er.inspect`) | High | Low | 3.1 |
| 2 | Error messages with rule/trigger context | High | Low | 3.2 |
| 3 | Caret-positioned parse errors | High | Medium | 3.3 |
| 4 | `on X when Y =>` syntax | Medium | Medium | 3.4 |
| 5 | Property type checking | Medium | Low | 3.5 |
| 6 | `stagger()` helper | Medium | Low | 3.6 |
| 7 | `use()` import system | High | High | 3.7 |
| 8 | VS Code language support | High | High | 3.8 |
| 9 | Fix/document `case` syntax | Low | Low | 3.9 |
| — | Extract `safeResume` / `scheduleTimer` | Low | Low | 1 |
| — | Open yield handler registration | Medium | Medium | 1 |
