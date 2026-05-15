# The EventScript Rule System

## Overview

A **rule** is an EventScript expression of the form:

```
condition => action
```

Rules are registered by passing them to `er.eval()`. When the condition's triggers fire, the action runs — potentially asynchronously.

A **plain expression** (no `=>`) runs immediately and returns its value.

---

## eval() API contract

```lua
local er  -- EventRunner instance passed to main(er)
local rule = er.eval -- alias for er.eval, better name

-- Rule form: registers the rule, logs ✅ RULE<n> with triggers, returns rule object
local r = rule("tvar == 5 => return tvar * 2")

-- Synchronous expression: runs now, logs 📋 result, returns value(s)
local v = rule("return 3 + 4")   -- v == 7

-- Asynchronous expression: contains wait(); logs 💤, returns nil immediately;
-- logs 📋 result when done
local v = rule("wait(100); return 7")  -- v == nil immediately, logs 📋 7 after 100ms
```

| Input | `eval()` returns | Logs immediately | Logs later |
|-------|-----------------|-----------------|------------|
| `"cond => action"` | rule object | `✅ RULE<n>` + trigger list | per verbosity on fire |
| Sync expression | value(s) | `📋 result` | — |
| Async expression (has `wait`) | `nil` | `💤 <suspended>` | `📋 result` when done |

---

## Rule object

```lua
local r = rule("cond => action")

r.id          -- integer, assigned at registration time
r.verbosity   -- "silent" | "normal" (default) | "verbose"
r.onDone      -- optional hook function: called with action return values on completion

tostring(rule)   -- "RULE1", "RULE2", ...

r.start()       -- fire the rule manually, regardless of event state
r.dumpTriggers()  -- print registered trigger/daily list to console
```

---

## Verbosity levels

Set on a rule object at any time before (or after) registration:

```lua
rule.verbosity = "verbose"   -- full lifecycle logging
rule.verbosity = "normal"    -- errors only (default)
rule.verbosity = "silent"    -- nothing logged
```

| Event | `"silent"` | `"normal"` | `"verbose"` |
|-------|-----------|-----------|------------|
| Rule fires | — | — | `🎬 RULE<n>` |
| `wait(n)` starts | — | — | `💤 RULE<n> sleeping Nms` |
| `wait(n)` resumes | — | — | `⏰ RULE<n> woke after Nms` |
| Action completes | — | — | `👍 RULE<n> result...` |
| Error in action | — | `❌ RULE<n> msg` | `❌ RULE<n> msg` |

---

## Trigger types

`scanHead` inspects the condition AST at registration time and registers an event subscription for each trigger found.

| EventScript syntax | Trigger event type |
|-------------------|-------------------|
| `tvar == x` (trigger-variable) | `{type='trigger-variable', name='tvar'}` |
| `$foo == x` (Fibaro global variable) | `{type='global-variable', name='foo'}` |
| `$$qv == x` (QuickApp variable) | `{type='quickvar', name='qv'}` |
| `123:isOn` (device property) | `{type='device', id=123, property='value'}` |
| `@10:30` (daily time) | Fires daily at 10:30 |
| `@@00:05` (interval) | Fires every 5 minutes |
| `10:00..12:00` (between / BETW) | Fires at 10:00 and 12:00 boundary |

For `GETPROP` triggers the property name (`isOn`, `isOff`, `value`, etc.) maps to the HC3 device property via `ER.getProps[key]`.

### Trigger variables

Declare a name as a trigger variable before using it in a rule:

```lua
er.triggerVars.myvar = initialValue
```

Writing to `er.triggerVars.myvar` posts a `{type='trigger-variable', name='myvar', value=v}` event via `sourceTrigger`, which fires any rule whose condition reads `myvar`.

---

## Asynchronous actions: `wait(ms)`

`wait(ms)` suspends the rule action and resumes it after `ms` milliseconds via `setTimeout`. Multiple `wait` calls chain correctly:

```
cond => wait(500); doSomething(); wait(1000); return result
```

- `eval()` / `rule:run()` return **immediately** when the action suspends
- The `onDone` hook (if set) fires when the action eventually completes (synchronously or asynchronously)
- The rule's `verbosity` setting controls `💤`/`⏰` logging around each wait

---

## onDone hook

Attach a callback to capture the action's return values — useful in tests and for chaining:

```lua
local rule = er.eval("cond => wait(100); return 42")
rule.onDone = function(v, ...)
  print("action returned:", v)   -- fires after the wait completes
end
rule:run()
```

`onDone` is called whether the completion is synchronous or asynchronous.

---

## EventRunner initialisation

```lua
function QuickApp:onInit()
  fibaro.EventRunner(function(er)
    -- er.eval is available here
    -- SourceTrigger is running (started 500ms after QA init)
    local rule = er.eval("...")
  end)
end
```

`fibaro.EventRunner(cb)` sets up globals, initialises `SourceTrigger`, and calls `cb(er)` after 500ms (to give the HC3 refresh-state poller time to start).

---

## Testing rules

See `tests/rule_test.lua` for the full harness. Key patterns:

### Synchronous rule test

```lua
-- Condition evaluated at run() time; result available immediately.
testRule("name", "cond => return x",
  function(er, rule)
    er.triggerVars.x = 5
    rule:run()           -- fires synchronously
  end,
  expected_value)
```

### Asynchronous rule test (contains wait)

```lua
-- onDone fires after timer drains; assertion lives inside the hook.
testAsync("name", "cond => wait(5); return x",
  function(er, rule)
    er.triggerVars.x = 5
    rule:run()
  end,
  expected_value)
```

### sourceTrigger:post test

`sourceTrigger:post` dispatches **asynchronously** through the event engine. Always use `testAsync` for these, and use a **dedicated trigger variable** (not shared with other tests) to avoid cross-test contamination:

```lua
er.triggerVars.pvar = 0
testAsync("via post",
  "pvar == 7 => return pvar + 1",
  function(er, rule)
    er.triggerVars.pvar = 7
    fibaro.ER.sourceTrigger:post({type='trigger-variable', name='pvar', value=7})
  end,
  8)
```

> **Why dedicate a variable per async test?**  
> `st:post` is deferred via `setTimeout`. By the time it fires, later sync tests may have mutated shared variables. Each async test must own its variable and set it to the expected value before calling `post`.

---

## Pipeline summary

```
EventScript source
      │
      ▼  ER.parse(src)
    AST  {RULE, cond_ast, action_ast}  or  {SCRIPT, block_ast}
      │
      ▼  ER.compileAST(ast)
    CSP tables  {'IF', cond, action, {}}  (via CALL to compRule)
      │
      ▼  ER.csp.compile(tree)
    CSP expression (closure tree)
      │
      ▼  ruleRunner(code)  /  compRule(r) at runtime
    rule object  +  event subscriptions registered in SourceTrigger
```
