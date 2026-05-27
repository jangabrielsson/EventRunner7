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
local v = rule("wait(0.1); return 7")  -- v == nil immediately, logs 📋 7 after 100ms
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

---

## Rule modifiers

Modifiers are optional keywords placed between the condition expression and `=>`. They adjust *when* and *how* the action fires without changing the condition itself. Multiple modifiers may be combined.

```
condition [modifier...] => action
```

### `restart`

If the condition re-fires while the action has pending timers (e.g. suspended in a `wait` or a scheduled `post`), cancel all those pending timers and start a fresh run. The currently-executing synchronous portion of the action is not interrupted — only the timed continuations are dropped.

```lua
rule("doorbell:pressed restart => wait(0.5); chime:play")
-- If doorbell fires again while waiting the 500 ms, the wait is cancelled
-- and a new 500 ms wait starts, so the chime always plays 500 ms
-- after the *last* press.
```

### `since <duration>`

The condition must have been *continuously* true for `<duration>` seconds before the action fires. Desugars to `trueFor(duration, condition)`.

```lua
rule("motion:breached since 00:02 => alarm:on")
-- Only fires if motion has been continuously detected for 2 minutes.
```

### `debounce <duration>`

Wait `<duration>` seconds after the *last* true evaluation before running the action. If the condition re-fires during the wait the timer resets (implies `restart`).

```lua
rule("search:keypress debounce 0.5 => searchAPI(query)")
-- Waits 500 ms of silence after last keypress before calling the API.
```

### `cooldown <duration>`

After the action runs, suppress re-triggering for `<duration>` seconds.

```lua
rule("motion:breached cooldown 00:05 => notify('Motion detected')")
-- Sends at most one notification every 5 minutes.
```

### `every <n>`

Fire only on every `<n>`-th true evaluation of the condition.

```lua
rule("tempSensor:value every 4 => log('Temp: %d', tempSensor:value)")
-- Logs temperature on every 4th change, not every change.
```

### Combining modifiers

Modifiers compose left-to-right. Common combinations:

```lua
rule("button:pressed restart cooldown 2 => wait(100); light:toggle")
-- Restarts on rapid-press; after toggle completes, silent for 2 s.

rule("noise:detected since 00:01 cooldown 00:10 => sendAlert()")
-- Sustained noise for 1 min triggers alert; won't re-alert for 10 min.
```

---

## Rule Groups

A rule can be assigned to a named group by passing `group` in the opts table at registration:

```lua
rule("motion:breached => hallLight:on",  {group="hallway"})
rule("@23:00 => hallLight:off",          {group="hallway"})
rule("motion:safe =&gt; hallLight:off",     {group="hallway"})
```

### enable / disable

The built-in `enable(arg)` and `disable(arg)` functions (available inside any rule action) accept:

| Argument type | Effect |
|---------------|--------|
| `"groupName"` (string) | Enable/disable every rule in the named group |
| rule object | Enable/disable that specific rule |
| integer id | Enable/disable the rule with that `RULE<n>` id |
| *(no argument)* | Enable/disable the **current** rule |

```lua
rule("sleepButton:pressed => disable('hallway')")  -- disable whole group
rule("wakeButton:pressed  => enable('hallway')")   -- re-enable whole group

local nightRule = rule("@@00:01 => nightCheck()", {group="night"})
rule("@22:00 => enable(nightRule)")    -- rule object reference
rule("@07:00 => disable(nightRule)")
```

### Accessing groups from Lua

`ER.getGroup(name)` returns the list of rule objects in a group, or `nil` if the group does not exist:

```lua
for _, r in ipairs(ER.getGroup("hallway") or {}) do
  print(tostring(r), r._disabled and "off" or "on")
end
```

---

### Trigger variables

Declare a name as a trigger variable before using it in a rule:

```lua
er.triggerVars.myvar = initialValue
```

Writing to `er.triggerVars.myvar` posts a `{type='trigger-variable', name='myvar', value=v}` event via `sourceTrigger`, which fires any rule whose condition reads `myvar`.

---

## Stopping rule processing early: `BREAK`

When multiple rules share the same trigger, EventRunner fires them all in registration order. A rule action can return `BREAK` to stop processing any further rules for that trigger event:

```lua
er.triggerVars.a = 0
rule("a == 1 => log('OK1'); return BREAK")  -- fires, then stops
rule("a == 1 => log('OK2')")                -- never reached
rule("a = 1")                               -- sets a → fires the two rules above
```

`BREAK` is a special sentinel value (`'%BREAK%'`) exposed via `er.defglobals.BREAK`. It is checked by the event engine after each rule's action returns — if the value matches, event dispatch stops immediately.

Rules that *don't* share the same trigger pattern are unaffected.

> **Important:** `BREAK` only works in **synchronous** rule actions (no `wait()` calls). When an action suspends on a `wait()`, the event engine has already moved on and subsequent rules for the same trigger have already fired. Returning `BREAK` from inside or after a `wait()` continuation has no effect.

---

## Logging

The `log` function prints a message from a rule action.

```lua
rule("door:breached => log('Door opened')")
rule("temp:value => log('Temp is %d°C', temp:value)")
```

### Coloured output with `#C:color#`

Wrap a colour tag in the format string to colour the entire message in the HC3 debug log:

```lua
log('#C:beige#Verlichting wastafel - Uit')
log('#C:lightblue#$Bezetting_Badkamer = %s', $Bezetting_Badkamer)
```

### Colour-dot shorthand: `log.color(...)`

As a cleaner alternative, access `log` with a dot and any CSS colour name. The colour is prepended automatically:

```lua
log.beige('Verlichting wastafel - Uit')
log.lightblue('$Bezetting_Badkamer = %s', val)
log.red('Error code: %d', code)
log.cyan('Checkpoint A')
```

Any valid CSS colour name works: `log.beige`, `log.lightblue`, `log.orange`, `log.tomato`, `log.lime`, etc.

`log(...)` without a dot continues to work as before and also supports the `#C:color#` tag inside the format string.

---

## Asynchronous actions: `wait(secs)`

`wait(secs)` suspends the rule action and resumes it after `secs` seconds (fractional values allowed: `wait(0.5)` = 500 ms) via `setTimeout`. Multiple `wait` calls chain correctly:

```
cond => wait(0.5); doSomething(); wait(1); return result
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
