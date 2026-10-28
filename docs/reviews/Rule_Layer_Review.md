# Rule Layer Review: EventRunner7

**Date:** 2026-10-27
**Scope:** Rule handling only — `src/Rule.lua`, modifier code in `src/ScriptFuns.lua`, trigger scanning, `SourceTrigger` engine in `src/Utils.lua`, and the rule boundaries in `src/Parser.lua` / `src/Compiler.lua`.
**Complements:** `Architectural_Review.md` (frontend pipeline + CSP VM leak audit, dated 2026-06-02).

---

## Resolution (2026-10-28)

All eight findings are implemented or explicitly accepted (status table
below). The review is closed; this document is kept as the historical record
of the rule-layer cleanup, complementing `Architectural_Review.md`
(frontend/CSP leak audit, 2026-06-02).

Work that grew out of the review, beyond the findings themselves:

- **Modifier combination enforcement** — the parser rejects duplicate
  modifiers and `single`/`debounce` + `first_in` at registration;
  `RULES.md` documents the full combination semantics table.
- **`rule:recompile()`** — rebinds a single rule in place (the granular
  answer to compile-time binding); subscriptions are stored on the rule and
  the interval timer became cancellable, so `terminate()` now truly stops
  interval rules.
- **Interval lifecycle** — `disable()` stops the interval scheduler,
  `enable()` restarts it (clock-aligned intervals resume at the next
  boundary, relative ones restart from enable time); `single` no longer
  cancels the scheduler.
- **Async watchdog protocol** — `(true, false)` = no watchdog; `since`
  windows no longer carry a 30-day watchdog.
- **Docs** — `RULES.md`, `EventScript.md` and `AST_Format.md` updated for
  the whitelist, error policy, gate chain, and combination rules.

Test net grew from 27 to 38 behavioral/regression tests, all passing under
`./test/run-tests.sh`.

---

## Verdict

The EventScript frontend (Tokenizer → Parser → Compiler) and the CSP VM are in good shape — the earlier review's leak fixes held. The rule layer is not. `Rule.lua` (~1000 lines) is five subsystems in one module, modifier semantics are smeared across three files, and several state-lifetime bugs existed in the timer machinery. None of it required a rewrite; the high-value items below are now implemented.

## Status (2026-10-27)

| Finding | State |
|---|---|
| 1 — trigger discovery | Compile-time binding is intentional (documented in the finding). Head-purity whitelist **implemented**: `ER._headFuns` + `HOPS.CALL` registration errors; `log` is the sanctioned debug exception; user-extensible via `ER._headFuns.name = true`. Unknown-op assert message clarified. Daily same-time dedup is intentional. Test: `test/rules/head_purity.lua`. |
| 3 — CSP-internals reach-in | **Implemented**: async functions now get a typed `cb.env` (`rule`, `event`, `_evKey`, `setTimeout`, `cancel`, `post`), built once in `ruleRunner`. No `cb.cf.ctx.var_env` access remains in `ScriptFuns.lua`/`Rule.lua`. |
| 4 — timer/state lifetime | **Implemented**: trueFor ref validation + reset in `killTimers` (single/terminate wedge fixed); asyncFun watchdogs tracked in `rule.timers`; `rule.gen` run generation discards callbacks from superseded runs. Tests: `test/rules/since_single.lua`, `test/rules/async_cancel.lua`. |
| 5 — error policy | **Implemented**: `disableOnError` per-rule option — `true` (default, disable on first error), `N` (disable after N consecutive errored runs, clean completions reset the streak), `false` (never disable). `rule.enable()` resets the counter; `er.eval` returns `nil, errmsg` on failure so failed and async/suspended are distinguishable. Documented in `RULES.md`. Test: `test/rules/error_policy.lua`. |
| 7 — opts plumbing | Partly **implemented**: duplicated `ctx:log` factored into `makeLogger` (rules and expression contexts share one implementation). The per-eval `ER.er.opts` re-metatable is deliberate — users may reassign `ER.er.opts`; kept with its comment. |
| 6 — compRule god-function | **Implemented**: `compRule` split into `newRule` / `attachRun` / `mkEvVars` / `setupTriggers` / `setupInterval` / `setupDailys` / `defineRuleAPI`; `rule:state()` accessor (`enabled`/`disabled`) and `rule.active` in-flight run counter. Also fixed a latent crash: the daily-recalc loop now guards interval-only rules (no `setupDaily`). Test: `test/rules/lifecycle.lua`. |
| 2 — modifier pipeline | **Implemented**: Parser emits structured modifiers; `compileRuleBody` builds an explicit gate chain — `since` → `YIELD 'sinceGate'`, `cooldown`/`every`/`first_in` → `CFUN` gates (state in `rule._mstate`), `debounce` → `wait(T)` action prefix. Gate cores in `Rule.lua`; the public async functions delegate to the same cores. Behavioral test: `test/rules/modifier_gates.lua`. |
| 8 | Accepted: `DAILY`/`TRIGGER_EVENT` read invocation state through the VM var frame, which is the sanctioned interface post-seam. |

## What the rule layer actually does

One module (`Rule.lua`) plus scattered helpers implement:

1. **Trigger discovery** — `scanHead` + `HOPS` dispatch, Rule.lua:366–486
2. **Rule lifecycle** — registration, subscription wiring, daily/interval scheduling — `compRule`, Rule.lua:134–363
3. **The async run loop** — `ruleRunner`, `resumeRunner`, `yieldHandlers`, Rule.lua:492–648
4. **Modifier semantics** — parser rewrites (Parser.lua:822–885) + implementations (ScriptFuns.lua:340–465)
5. **Observability** — stats, history, watch, logging — `ruleCondition`, Rule.lua:704–728

## Findings

### 1. Trigger discovery must evaluate at registration time — but the mechanism has real costs — MEDIUM

**Design rationale (intentional, keep it):** EventScript binds variables at compile time. `rule("dID = 88")` followed by `rule("dID:value => log('hupp')")` must resolve `dID` to 88 when the second rule is registered; if `dID` changes later, the compiled rule still refers to 88 until it is recompiled. Trigger scanning therefore cannot be purely static — resolving the trigger object requires evaluating the condition's object expressions at registration time. This is a language semantic, not a leak.

*Note:* this binding rule is currently undocumented — `docs/RULES.md` does not state it. Recommend documenting it explicitly, since it is the contract that makes the evaluation-based scanner correct.

**Remaining mechanism costs (independent of the semantic):**

- **Double compilation.** `exprFun` (Rule.lua:366–372) compiles each scanned fragment separately, then `ER.compileRuleBody` compiles the whole rule again. Two compile passes over the same condition.
- **Registration-time side effects.** Any side-effecting call in a condition runs once, at registration, and never again. A whitelist already exists — the `HOPS` dispatch table (Rule.lua:377–486): ops without a HOPS entry hit the `assert` at Rule.lua:479, so assignments (`SET`, `SETVAR`, `SETPROP`, `INCVAR`, …) already hard-error at registration. Two gaps remain: **(a)** the assert message ("missing op in AST node") doesn't say the op is illegal in a rule head or what is allowed; **(b)** `CALL` is whitelisted and only scans its children, so the *called function* is never checked — `setGlobal('x',1)` in a head compiles and runs its side effect at registration silently. Add a head-function whitelist for CALL targets (pure builtins + the condition-modifier functions the parser injects: `trueFor`, `cool_down`, `every_other`, `first_in_win`), erroring on anything else, and give both the op and function errors a clear message. Rationale: a side effect in the head can never be anticipated, and the rule may appear to work and then fail mysteriously later — failing at registration is consistent with the compile-time binding model.
- **Implicit frozen/live split.** Device triggers are resolved once and frozen (by design). DAILY/BETW fragments are kept as re-evaluable closures and re-run at midnight or on `_recalc` triggers (Rule.lua:304–330), so live lookups (`getGlobal(...)`, etc.) refresh while compile-time-bound IDs stay fixed. The behavior is correct, but the boundary between frozen and live expressions is implicit — it depends on whether the fragment happened to be stored as a closure. Worth documenting as part of the binding rule.
- **Daily time dedup (intentional).** `setupDaily` builds `ts[t0] = subev` keyed by the evaluated time value (Rule.lua:318), so duplicate daily times (`@{17:00, 17:00}`, or two expressions evaluating to the same time) collapse to a single posted event — sufficient, since one DAILY event triggers the rule regardless of which expression produced it. Deliberate dedup, not a collision; worth a one-line note in `RULES.md` so nobody mistakes it for a bug.

### 2. Modifiers are parser AST surgery, not a rule-layer concept — HIGH

Parser.lua:822–885 rewrites modifiers into ordinary function calls:

| Modifier | Rewrite |
|---|---|
| `since 5` | `cond` → `trueFor(5, cond)` |
| `cooldown 5` | `cond` → `AND cond cool_down(5)` |
| `every 3` | `cond` → `AND cond every_other(3)` |
| `debounce 5` | `single=true` + prepend `wait(5)` to the *action* |
| `first_in W` | `cond` → `AND cond first_in_win(W, W[3])` |

The compiler, the CSP IR, and the rule object all see ordinary `CALL`s. Modifiers are functions whose *purpose is their side effects* — `cool_down` and `every_other` mutate state and gate the condition. Nothing in the model knows a modifier exists, which is why `rule.info()` (ScriptFuns.lua:313–335) has to reconstruct modifier state ad hoc from `r.modifiers` and `r._mstate`. Also note `debounce` smuggles scheduling (`wait`) into the action block — time semantics live in the action, not the rule.

### 3. Modifier implementations reach into CSP internals — HIGH

The async modifier functions in ScriptFuns.lua:340–465 depend on the internal shape of the CSP continuation snapshot and var frames:

- `async.trueFor` reads `cb.cf.ctx.var_env[1]`, `env.setTimeout[1]`, `env.cancel[1]`, `env.event` (ScriptFuns.lua:340–362). `env` is the first frame of the snapshot's var-chain, and every value is boxed as `{v}` because of the VM's frame representation.
- `first_in_win`, `cool_down`, `every_other` read `cb.cf.ctx.opts` and store state either in `rule._mstate` (rules) **or** `cb.ctx` itself (expressions) — two state homes for one concept (ScriptFuns.lua:371, 418, 434).
- `async.again` calls `cb.ctx:run(trueFor.trigger)` (ScriptFuns.lua:449–457) — an async modifier re-firing its own rule through the public API from inside the VM. The most cross-layer call in the codebase.

Any refactor of CSP frames/snapshots silently breaks all of this. The `{v}` boxing in `mkEvVars` (Rule.lua:219–232) leaks the VM's variable representation all the way into application code.

### 4. Timer/state lifetime bugs — HIGH

- **`asyncFun` watchdogs are not tracked.** The timeout timer in `yieldHandlers.asyncFun` (Rule.lua:525–555) is not added to `ctx.timers`, unlike `sleep` (Rule.lua:506–520). `killTimers` therefore cannot cancel pending async watchdogs, and — worse — the callback of an in-flight async function resumes the *old* suspended run even after `single` started a new one. There is no run-generation check: superseded continuations interleave with the current run.
- **`single` + `since` wedges.** `killTimers` cancels the trueFor timer but leaves `trueFor.ref` set (ScriptFuns.lua:348–350). Every later evaluation sees a non-nil `ref` and calls `cb(false)`; the condition can never become true again. The armed 30-day asyncFun watchdog (ScriptFuns.lua:353) will eventually fire `resume(cf, false)` — a dead run resuming 30 days later.
- **`terminate()` does not actually terminate.** It only cancels timers in `rule.timers`; async watchdogs and already-queued continuations survive.

### 5. Error policy: one runtime error permanently disables the rule — MEDIUM

`ruleRunner` (Rule.lua:637–645): any error → log → `ctx.disable()`. A transient failure (device offline, bad HTTP) kills the rule until manually re-enabled. Meanwhile `eval()` (Rule.lua:655–703) swallows errors unless `opts.throw` is set and returns `nil` both on error and on async suspension — callers cannot distinguish "failed" from "still running".

### 6. `compRule` god-function and ad-hoc rule object — MEDIUM

`compRule` (Rule.lua:134–363) interleaves registration, stats/history/watch init, trigger subscription wiring, interval scheduling, daily scheduling, manual-run plumbing, and introspection in one closure nest. The rule object has no lifecycle state machine — it is a pile of flags (`_disabled`, `historyOn`, `watchOn`) and side tables (`timers`, `dailys`, `_mstate`, `trueFor`) mutated from everywhere. `ruleCondition` (Rule.lua:704–728) does logging + stats + history + watch in the condition hot path, with stats counted in two different layers (`runs` in `runRule`, `successes/failures` in `ruleCondition`).

### 7. Options plumbing: metatable chains and duplicated logic — LOW

`eval()` re-metatables `ER.er.opts` on every call (Rule.lua:657), producing `opts → ER.er.opts → dfltPrefix`, then `ruleRunner` layers `evalOpts → ctx.opts` on top (Rule.lua:603–605). `makeExprCtx:log` (Rule.lua:100–116) duplicates the rule's `log` method verbatim. `vars._opts = {evalOpts}` (Rule.lua:627) is pushed into the env but nothing consumes it — dead plumbing next to the live `cb.cf.ctx.opts` reach-in.

### 8. Invocation state leaks into condition semantics — LOW

`DAILY` and `TRIGGER_EVENT` instructions read `ctx():getVar('event')` / `getVar('_evKey')` (Rule.lua:795–819). A condition's meaning depends on *how it was invoked*; in a bare expression context `DAILY(...)` silently evaluates false. The invocation identity (`_evKey`) is threaded through the same var-frame mechanism as user variables.

## What is good

- **Frontend pipeline** — Tokenizer/Parser/Compiler are clean; `isCondition` in `compileRuleBody` (Compiler.lua:472–487) cleanly separated compile-time event-table handling from runtime AST mutation.
- **CSP extension API** — `registerInstruction` + `vm.host` is a good seam. The rule layer just never built an equivalent seam for itself.
- **`yieldHandlers`** — a decent dispatch point; it passes the wrong payload (raw continuation snapshot) instead of a typed execution environment.
- **SourceTrigger engine** (Utils.lua:340–570) — self-contained, with a reasonable pattern-compile/hash/matching design.

## Recommendations (in order)

1. **ExecutionEnv seam.** Define a typed environment object handed to yield handlers and async functions: `env.event`, `env.rule`, `env.setTimeout`, `env.cancel`, `env.state`. Replace all `cb.cf.ctx.var_env[1]` unboxing with it. This single seam resolves findings 3, 7, and 8's plumbing and makes the modifier code readable.
2. **First-class modifier pipeline.** Parse to structured modifiers (the parser already collects them, then discards the structure into rewrites) and compile the condition into an explicit gate chain (`since → cooldown → every → ...`) living in the rule, with all state in one home (`rule.modState`). Removes side-effectful condition wrappers and the rule/expr state split.
3. **Run-generation guard + full timer tracking.** Every suspended continuation carries a run id; `resume` checks currency before continuing. All timers — including async watchdogs — go into `rule.timers`. Fixes the `single` interleaving, the `single`+`since` wedge, and makes `terminate()` real.
4. **Single-pass trigger resolution.** Keep registration-time evaluation (the compile-time binding rule requires it), but move it into the compiler: evaluate the compiled condition once in an instrumented trigger-collection mode that records `GETPROP` objects as they resolve, instead of `scanHead` compiling and evaluating each fragment separately. Same semantics, one compile pass, and the frozen/live boundary becomes explicit in one place. Fold head-purity enforcement into the same pass: the `HOPS` op whitelist already errors on unknown ops — add the missing CALL-target function whitelist (pure builtins + condition modifiers) and clear error messages for both. Document the compile-time binding rule and the whitelist in `RULES.md`.
5. **Rule lifecycle state machine + error policy.** Split `compRule` into builder / scheduler / introspection. Give the rule explicit states (defined → enabled → running → suspended). Replace auto-disable-on-error with consecutive-failure counting or an explicit opt-in; make `eval` return an explicit status.
6. **Bug fixes regardless of refactor:** trueFor ref cleanup on cancel (finding 4).

## Appendix: key locations

| Concern | Location |
|---|---|
| Rule creation | `src/Rule.lua:134` (`compRule`) |
| Trigger scan | `src/Rule.lua:366–486` (`exprFun`, `HOPS`, `scanHead`) |
| Run loop / yield | `src/Rule.lua:492–648` (`yieldHandlers`, `resumeRunner`, `ruleRunner`) |
| Rule eval entry | `src/Rule.lua:655` (`eval`) |
| Condition wrapper | `src/Rule.lua:704` (`ER.ruleCondition`) |
| CSP extension impls | `src/Rule.lua:740–857` (`addCSPfuns`) |
| Modifier impls | `src/ScriptFuns.lua:340–465` (`trueFor`, `first_in_win`, `cool_down`, `every_other`, `again`) |
| Modifier parsing | `src/Parser.lua:798–899` (`parseScript`) |
| Rule compilation | `src/Compiler.lua:472` (`ER.compileRuleBody`) |
| Event engine | `src/Utils.lua:340–570` (`createEventEngine`) |
