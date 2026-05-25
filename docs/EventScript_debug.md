# EventScript Debug Tooling

EventScript provides a set of runtime debug functions that help you understand why rules fire (or don't). All functions work on both **plua** (development) and the real **HC3** (production) — output goes through the standard log console in both environments.

## Table of Contents

- [Named Rules](#named-rules)
- [Rule Inspector — `info()`](#rule-inspector----info)
- [Live Watch — `watchOn()` / `watchOff()`](#live-watch----watchon--watchoff)
- [Invocation History — `historyOn()` / `showHistory()`](#invocation-history----historyon--showhistory)
- [Combining Tools](#combining-tools)
- [Function Reference](#function-reference)

---

## Named Rules

All debug functions identify rules by **name**. Give a rule a name via the `{name=...}` option:

```lua
rule("sensor:breached => lights:on", {name="entry-light"})
```

Without a name, rules get an automatic name like `"RULE3"` (based on their registration order). You can still address them by name or by numeric ID:

```lua
watchOn("RULE3")    -- by auto-name
watchOn(3)          -- by numeric ID
watchOn("entry-light")  -- by explicit name
```

The rule name also appears in all standard log output:

```
✅ entry-light: {type='device', id=42, property='breached', value=true}
```

---

## Rule Inspector — `info()`

`info(rule)` prints a snapshot of everything known about a rule at that moment: its source, triggers, enabled/disabled status, active modifier state, and history recording status.

```lua
info("entry-light")
```

**Sample output:**

```
ℹ️  [entry-light] (id=3)
   src:     sensor:breached => lights:on
   status:  ✅ enabled
   triggers:
     📌 {type='device', id=42, property='breached', value=true}
   history:  off (size=10, entries=0)
```

For a rule with modifiers and active state:

```lua
rule("sensor:breached cooldown 00:01 => notify('Door!')", {name="door-alert"})
```

```
ℹ️  [door-alert] (id=5)
   src:     sensor:breached cooldown 00:01 => notify('Door!')
   status:  ✅ enabled
   triggers:
     📌 {type='device', id=42, property='breached', value=true}
   cooldown:  last fired 08:14:22
   history:   recording (size=5, entries=3)
```

**Trigger from another rule:**

```lua
rule("@@12:00 => info('door-alert')")
```

---

## Live Watch — `watchOn()` / `watchOff()`

Watch prints a log line **immediately** every time a rule's condition is evaluated — pass or fail. Use it when you want real-time feedback without needing to dump a buffer later.

```lua
watchOn("entry-light")
```

Every trigger now produces a line like:

```
👁  [entry-light] 08:14:22  ✅ PASS  {type='device', id=42, ...}
👁  [entry-light] 08:17:05  ❌ FAIL  {type='device', id=42, ...}
```

**Turn it off:**

```lua
watchOff("entry-light")
```

**Watch all rules at once:**

```lua
watchOnAll()
watchOffAll()
```

**Schedule a watch window from a rule:**

```lua
-- Watch 'entry-light' for 30 minutes each morning
rule("@@07:00 =>
  watchOn('entry-light')
  wait(00:30)
  watchOff('entry-light')
")
```

`watchOn` and `historyOn` are independent — you can use both on the same rule simultaneously.

---

## Invocation History — `historyOn()` / `showHistory()`

History records the last N invocations of a rule in a circular buffer. Unlike `watch`, it doesn't print anything immediately — you dump it on demand with `showHistory()`.

**Start recording:**

```lua
historyOn("entry-light", 10)   -- keep last 10 entries
```

**Stop recording (buffer is preserved):**

```lua
historyOff("entry-light")
```

**Dump the buffer:**

```lua
showHistory("entry-light")
```

**Sample output:**

```
📋 [entry-light] Last 3 invocations:
  08:14:22  ✅ PASS  {type='device', id=42, property='breached', value=true}
  08:17:05  ❌ FAIL  {type='device', id=42, property='breached', value=true}
  08:19:11  ✅ PASS  {type='device', id=42, property='breached', value=true}
```

**All-rules variants:**

```lua
historyOnAll(5)   -- start recording on every rule, buffer size 5
historyOffAll()   -- stop recording on all rules (buffers preserved)
```

**Set buffer size at definition time** (recording still starts off):

```lua
rule("sensor:breached => lights:on", {name="entry-light", historySize=20})
```

**Scheduled history window:**

```lua
rule("@@08:00 => historyOn('entry-light', 10)")
rule("@@22:00 =>
  showHistory('entry-light')
  historyOff('entry-light')
")
```

---

## Combining Tools

The debug functions compose freely. A typical investigation pattern:

```lua
-- 1. Name the rule you're investigating
rule("sensor:breached first_in 07:00..08:00 => radio:play", {name="morning-radio"})

-- 2. Turn on watch + history during the window of interest
rule("@@06:55 =>
  watchOn('morning-radio')
  historyOn('morning-radio', 20)
")

-- 3. Inspect state and dump history after the window
rule("@@08:05 =>
  info('morning-radio')
  showHistory('morning-radio')
  watchOff('morning-radio')
")
```

---

## Function Reference

| Function | Description |
|---|---|
| `info(rule)` | Print full rule snapshot: src, triggers, modifier state, history status |
| `watchOn(rule)` | Print a log line immediately on every condition evaluation |
| `watchOff(rule)` | Stop live logging for this rule |
| `watchOnAll()` | Enable live logging for all rules |
| `watchOffAll()` | Disable live logging for all rules |
| `historyOn(rule, size?)` | Start recording invocations into a circular buffer; resets buffer |
| `historyOff(rule)` | Stop recording (buffer is preserved) |
| `historyOnAll(size?)` | Start recording on all rules |
| `historyOffAll()` | Stop recording on all rules |
| `showHistory(rule)` | Print the recorded buffer for this rule |

All functions accept a rule **name** (string), numeric **ID**, or the **rule object** itself.
