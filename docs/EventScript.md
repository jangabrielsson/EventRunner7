# EventScript Language Documentation

EventScript is the rule-based automation language used by EventRunner7 for creating home automation rules on Fibaro HC3 controllers. It provides an intuitive syntax for defining triggers, conditions, and actions in automation scenarios.

## Table of Contents

- [EventScript Language Documentation](#eventscript-language-documentation)
  - [Table of Contents](#table-of-contents)
  - [Language Overview](#language-overview)
  - [Basic Syntax](#basic-syntax)
  - [Control Structures](#control-structures)
    - [Conditional Statements](#conditional-statements)
    - [Loop Statements](#loop-statements)
  - [Assignment](#assignment)
    - [Simple Assignment](#simple-assignment)
    - [Multiple Assignment](#multiple-assignment)
  - [Tables](#tables)
    - [Table Creation](#table-creation)
    - [Table Access](#table-access)
  - [Expressions](#expressions)
    - [Variables](#variables)
      - [Variable Declaration](#variable-declaration)
      - [Variable Resolution Order](#variable-resolution-order)
      - [Variable Assignment](#variable-assignment)
    - [Constants](#constants)
      - [Time Constants](#time-constants)
      - [Time Representation](#time-representation)
      - [Predefined Constants](#predefined-constants)
    - [Operators](#operators)
      - [Logical Operators](#logical-operators)
      - [Arithmetic Operators](#arithmetic-operators)
      - [Comparison Operators](#comparison-operators)
      - [Assignment Operators](#assignment-operators)
      - [Coalesce Operator](#coalesce-operator)
  - [Triggers](#triggers)
    - [Daily Triggers](#daily-triggers)
    - [Interval Triggers](#interval-triggers)
    - [Event Triggers](#event-triggers)
    - [Device Triggers](#device-triggers)
    - [Trigger Variables](#trigger-variables)
    - [Startup Events](#startup-events)
  - [Functions](#functions)
    - [trueFor Function](#truefor-function)
    - [Date Functions](#date-functions)
      - [Day Testing Functions](#day-testing-functions)
      - [Time Range Testing](#time-range-testing)
    - [Log and Formatting Functions](#log-and-formatting-functions)
    - [Event Functions](#event-functions)
    - [Math Functions](#math-functions)
    - [Global Variable Functions](#global-variable-functions)
    - [Lambda Functions](#lambda-functions)
    - [List Comprehension](#list-comprehension)
    - [Table Functions](#table-functions)
    - [Rule Functions](#rule-functions)
    - [HTTP Functions](#http-functions)
  - [Property Functions](#property-functions)
    - [Device Properties](#device-properties)
    - [Device Control Actions](#device-control-actions)
    - [Device Assignment Properties](#device-assignment-properties)
    - [Partition Properties](#partition-properties)
    - [Thermostat Properties](#thermostat-properties)
    - [Scene Properties](#scene-properties)
    - [Information Properties](#information-properties)
    - [List Operations](#list-operations)
    - [Weather Object](#weather-object)
  - [Named Scenes](#named-scenes)
  - [Extending the Property System](#extending-the-property-system)
    - [Adding Custom Device Properties](#adding-custom-device-properties-eraddstdprop)
    - [Defining Custom Property Classes](#defining-custom-property-classes-erdefinepropclass)
  - [Examples](#examples)
    - [Basic Device Control](#basic-device-control)
    - [Conditional Logic](#conditional-logic)
    - [Time-based Automation](#time-based-automation)
    - [List Operations](#list-operations-1)
    - [Advanced Scenarios](#advanced-scenarios)
  - [Rule Modifiers](#rule-modifiers)
  - [Reserved Keywords](#reserved-keywords)
  - [BREAK — stop rule dispatch early](#break--stop-rule-dispatch-early)
  - [Rule management functions](#rule-management-functions)
    - [Rule Groups](#rule-groups)
  - [Best Practices](#best-practices)

## Language Overview

EventScript uses a simple `triggerExpression => action` syntax where:
- **Triggers** define when a rule should execute
- **Actions** define what should happen when triggered
- **Properties** provide access to device states and controls

## Basic Syntax

```lua
rule("triggerExpression => action")
```

Rules are defined using the `rule()` function with a string containing the trigger-action pattern.
The trigger is an expression returning true or false, and when true the action is executed. It can thus be thought of as
```lua
IF trigger THEN action END
```
The trigger must be an "pure" expression and not contain any control statements or side effects. Ex. assignments or print statemenets. The reason being that while compiling the rules, the trigger part may be evaluated multiple times.
The trigger part is inspected during compilation to find out what events causes the rule to be triggered. Ex. if an fibaro global variable or a device property is used as part of the expression, the rule will trigger when those change in the system.

## Control Structures

EventScript supports standard control flow structures for implementing complex logic within rules.

### Conditional Statements

Use conditional statements to execute code based on conditions:

```lua
-- Simple if statement
if <test> then 
  <statements> 
end

-- If-else statement
if <test> then 
  <statements> 
else 
  <statements> 
end

-- If-elseif-else statement (elseif can be repeated)
if <test> then 
  <statements> 
elseif <test2> then 
  <statements> 
else 
  <statements> 
end

case
  || <test> >> <statements>
  || <test> >> <statements>
  :
  || <test> >> <statements>
end
```

**Examples:**
```lua
rule("sensor:breached => if luxSensor:value < 100 then light:on end")
rule("@sunset => if house:isAllOff then alarm:arm else log('House not secure') end")
```

### Loop Statements

EventScript supports various loop constructs:

```lua
-- Numeric for loop
for i = 1, n[, step] do 
  <statements> 
end

-- Iterator for loop (arrays)
for _, v in ipairs(<list>) do 
  <statements> 
end

-- Iterator for loop (tables)
for k, v in pairs(<table>) do 
  <statements> 
end

-- While loop
while <test> do 
  <statements> 
end

-- Repeat-until loop
repeat 
  <statements> 
until <test>
```

**Examples:**
```lua
rule("@08:00 => for i=1,5 do lights[i]:on end")
rule("motionDetected => for _,light in ipairs(hallwayLights) do light:on end")
```

## Assignment

EventScript supports various assignment patterns for working with variables and values.

### Simple Assignment

Assign values to variables using the assignment operator:

```lua
var = <expr>
```

**Examples:**
```lua
rule("sensor:temp => temperature = sensor:temp")
rule("@morning => lightLevel = 80")
```

### Multiple Assignment

Assign multiple values in a single statement:

```lua
var1, var2, ..., varn = expr1, expr2, ...
```

Functions can return multiple values, with the last expression supporting multiple return values:

```lua
var1, var2, var3 = 42, twoValuesFun()
```

**Examples:**
```lua
rule("weatherUpdate => temp, humidity = weatherStation:temp, weatherStation:humidity")
```

## Tables

Tables are the primary data structure in EventScript, used for arrays, dictionaries, and complex data organization.

### Table Creation

Create tables using various syntaxes:

```lua
-- Array-style table
local v = { <expr1>, <expr2>, ..., <exprn> }

-- Dictionary-style table
local v = { <key1> = <expr1>, <key2> = <expr2>, ..., <keyn> = <exprn> }

-- Mixed table with computed keys
local v = { [<expr1>] = <expr2>, [<expr3>] = <expr4>, ..., [<exprn>] = <exprm> }
```

**Examples:**
```lua
-- Device groups
livingRoomLights = {66, 67, 68}
deviceStates = { motion = false, door = "closed", temp = 22 }
sensorMap = { [101] = "kitchen", [102] = "bedroom" }
```

### Table Access

Access and modify table values:

```lua
-- Dot notation (for string keys)
<table>.<key> = <expr>
value = <table>.<key>

-- Bracket notation (for any key type)
<table>[<expr>] = <expr>
value = <table>[<expr>]
```

**Examples:**
```lua
rule("motion:breached => deviceStates.motion = true")
rule("temp:value => sensorData[temp:id] = temp:value")
```

## Expressions

Expressions in EventScript are used to create complex trigger conditions and perform calculations within rules.

### Variables

EventScript supports both local and global variables with a specific scope resolution order.

#### Variable Declaration

```lua
-- Local variables (scoped to the current rule)
local v1, ..., vn [= expr1, ..., exprn]

-- Global variables (accessible across all rules)
v1, ..., vn [= expr1, ..., exprn]
```

#### Variable Resolution Order

When accessing a variable, EventScript checks in this order:
1. **Local EventScript variable** (rule-scoped)
2. **Global EventScript variable** (system-wide)
3. **Global Lua variable** (built-in functions and constants)

#### Variable Assignment

When assigning to a variable that doesn't exist, EventScript creates an EventScript Global variable by default.

**Examples:**
```lua
rule("@08:00 => local brightness = 80; lights:value = brightness")
rule("sensor:temp => temp = sensor:temp")  -- Creates global variable
rule("motion:breached => if temp > 25 then fan:on end")  -- Uses global variable
```

### Constants

EventScript provides various types of constants for use in expressions.

#### Time Constants

Time values can be specified in `HH:MM:SS` or `HH:MM` format:

```lua
rule("sensor:breached & 23:00..05:00 => log('Breached at night')")
rule("@@00:00:10 => log('Ping every 10 seconds')")
```

#### Time Representation

- **Short times**: Times between 00:00 and 24:00, represented as seconds after midnight
- **Long times**: Epoch times (like Lua's `os.time()`) for absolute timestamps

An absolue long time [YEAR]/MONTH/DAY/HOUR.MIN[:SEC]
```lua
rule("post(#futureEvent,2027/10/04/23:00)")  -- Post October 4, 23:00 2027
rule("post(#futureEvent,/12/23/18:00)")  -- Post on Xmas eve, this year
rule("#futureEvent => log('Future event'))")
```

Note that long times can't be compared to short times. To convert a long time to a short time, subtract midnight. Normally, need for such calculations are rare.


#### Predefined Constants

| Constant | Type | Description |
|----------|------|-------------|
| `sunset` | Short time | Sunset time, updates daily at midnight |
| `sunrise` | Short time | Sunrise time, updates daily at midnight |
| `dawn` | Short time | Dawn time, updates daily at midnight |
| `dusk` | Short time | Dusk time, updates daily at midnight |
| `now` | Short time | Current time (HH:MM:SS) |
| `midnight` | Long time | Midnight timestamp, updates daily |
| `wnum` | Number | Current week number |
| `uptime` | Number | HC3 gateway uptime in seconds since last boot |
| `uptimeStr` | String | HC3 uptime as human-readable string, e.g. `"1 days, 3 hours, 12 minutes"` |
| `uptimeMinutes` | Number | HC3 gateway uptime in minutes |

**Examples:**
```lua
rule("@sunset => outdoorLights:on")
rule("sensor:breached & sunrise..sunset => securityAlert()")
rule("@00:00 & wnum % 2 == 0 => weeklyMaintenance()")  -- Every other week (even week numbers)
```

### Operators

EventScript supports various operators for building complex expressions.

#### Logical Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `&` | Logical AND | `sensor:breached & 22:00..06:00` |
| `\|` | Logical OR | `door:open \| window:open` |
| `!` | Logical NOT | `!alarm:armed` |

#### Arithmetic Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `+` | Addition | `temp1:value + temp2:value` |
| `-` | Subtraction | `sunset - 00:30` |
| `*` | Multiplication | `price * quantity` |
| `/` | Division | `total / count` |
| `%` | Modulo | `minute % 15 == 0` |
| `^` | Exponentiation | `base ^ power` |

#### Comparison Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equal | `temp:value == 22` |
| `!=` or `~=` | Not equal | `door:state != "closed"` |
| `<` | Less than | `lux:value < 100` |
| `<=` | Less or equal | `humidity <= 60` |
| `>` | Greater than | `temp:value > 25` |
| `>=` | Greater or equal | `battery >= 20` |

#### Assignment Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `+=` | Add and assign | `counter += 1` |
| `-=` | Subtract and assign | `energy -= consumption` |
| `*=` | Multiply and assign | `scale *= factor` |
| `/=` | Divide and assign | `average /= count` |

#### Coalesce Operator
| Operator | Description | Example |
|----------|-------------|---------|
| `??` | Assign if not nil | `counter = a ??` 7 |

**Examples:**
```lua
rule("temp:value > 25 & humidity < 60 => fan:on")
rule("@sunset-00:30 => lights:on")  -- 30 minutes before sunset
rule("motion:breached => counter += 1; log('Motion count: %d', counter)")
```

## Triggers

Triggers define the conditions under which rules should execute.
The triggerExpression part of a rule can be a complex expression of triggers returning true or false

### Daily Triggers

Execute rules at specific times during the day:

```lua
rule("@time => action")                    -- Trigger at specific time
rule("@{time1,time2,...} => action")      -- Trigger at multiple times
rule("@{time,catch} => action")           -- Catchup: Run if deployed after time
rule("12:00..sunset => action")           -- Time interval guard, mostly part of more complex triggers
```
Daily triggers can only specify a time during the day. To invoke the rule on specific days add a guard to the triggerExpression to test that it is the right day.

**Examples:**
```lua
rule("@08:00 => lights:on")               -- Turn on lights at 8 AM
rule("@{07:00,19:00} => securityCheck()")   -- Check security at 7 AM and 7 PM
rule("@sunset => outdoorLights:on")       -- Turn on outdoor lights at sunset
rule("@15:00 & wday('mon-fri') => outdoorLights:on") -- Turn on outdoor lights at 15:00 on weekdays 
```

### Interval Triggers

Execute rules at regular intervals:

```lua
rule("@@00:05 => action")     -- Every 5 minutes
rule("@@-00:05 => action")    -- Every 5 minutes, aligned to clock
```

**Examples:**
```lua
rule("@@00:15 => temperatureCheck()")       -- Check temperature every 15 minutes
rule("@@-01:00 => hourlyReport()")          -- Generate report on the hour
```

### Event Triggers

Respond to custom events:

```lua
rule("#myEvent => action")                -- Trigger on custom event
rule("#myEvent{param=value} => action")   -- Trigger on event with parameters
```

**Examples:**
```lua
rule("#myEvent => temperatureCheck()")       -- Check temperature when getting #MyEvent
rule("@sunset => post(#myEvent)")            --POst #MyEvent at sunset
```

> **Note:** `#event` is shorthand for `{type='event'}`, and `#event{k1=v1,...}` expands to `{type='event', k1=v1, ...}`

**Event matching**
```lua
rule("#myEvent{x=42} => log('x is %s',env.event.x)")  -- Trigger on event with parameters
rule("post(#myEvent{x=42})")                      -- Post event with parameters
```
Values of type string and starting with prefix '\$' is considered a pattern, and will bind the variable after the '\$' to the value if there is a match. The value is added as a local variable to the rule.
Note: the event that triggers the rule is also available in the local variable ev.p.<name\>

```lua
rule("#myEvent{x='$v'} => log('x is %s',v)")  -- Trigger on event with pattern match
rule("post(#myEvent{x=42})")                      -- Post event with parameters
```
Patterns can also contain conditions/constraints

```lua
rule("#myEvent{x='$v>8'} => log('x is %s',v)")  -- Trigger on event with pattern match
rule("post(#myEvent{x=9})")                      -- Post event with parameters
```
The trigger event only match, and the local variable is bound, if the constraint is true.
In the above example v must be greater than 8 for the trigger event to match.
Possible operators are
| Operator | Description | Example |
|----------|-------------|---------|
| `$var>value` | value greater than | `#ev{key="$v>8"}` |
| `$var<value` | value less than | `#ev{key="$v<8"}` |
| `$var>=value` | value greater or equal than | `#ev{key="$v>=8"}` |
| `$var<=value` | value greater or less than | `#ev{key="$v<=8"}` |
| `$var~=value` | value differs from | `#ev{key="$v~=8"}` |
| `$var==value` | value equal | `#ev{key="$v==8"}` |
| `$var<>value` | value string match | `#ev{key="$m<>date.*"}` |

### Device Triggers

React to device state changes:

```lua
rule("device:property => action")         -- Single device trigger
rule("{dev1,dev2,...}:property => action") -- Multiple device trigger
```

**Examples:**
```lua
rule("motionSensor:value => hallLight:on")
rule("{door1,door2,window1}:breached => alarm:on")
```

### Trigger Variables

Use custom variables as triggers:

```lua
er.triggerVariables.x = 9    -- Define trigger variable
rule("x => action")          -- Trigger when x changes
rule("x = 42")              -- Change x to trigger above rule
```

### Startup Events

If the HC3 gateway itself has just booted (uptime less than 3 minutes), EventRunner automatically posts a `se-start` event. Use this to run one-time initialization logic that should only happen after a real HC3 reboot — not after every QuickApp restart.

| Field | Value | Description |
|-------|-------|-------------|
| `type` | `'se-start'` | Event type |
| `property` | `'start'` | Event property |
| `value` | `true` | Always true |
| `uptime` | number | Gateway uptime in seconds at the time of posting |

**Examples:**
```lua
rule("#se-start => log('HC3 just booted, uptime: %d seconds', event.uptime)")
rule("#se-start => -- Reinitialize state after reboot\n  $mode = 'home'\n  allLights:off")
```

## Functions

Built-in functions available in rule triggers and actions.

### trueFor Function

Execute actions when conditions remain true for a specified duration:

```lua
rule("trueFor(duration, condition) => action")
```

**Examples:**
```lua
rule("trueFor(00:05, sensor1:safe & sensor2:safe) => light:off")
-- Turn off light when sensors has been safe for 5 minutes

rule("trueFor(00:10, door:open) => log('Door open for %d minutes', 10*again(5))")
-- Log at 10-min intervals while door stays open; again(5) re-enables firing up to 5 more times
```

### Date Functions

Date functions allow you to test properties of the current day and time ranges.

#### Day Testing Functions

```lua
wday('wed-thu,sun')     -- Test current weekday
day('1,13-last')        -- Test current day of month
month('jul-sep')        -- Test current month
date('* 10-12 * 8 *')   -- Full date/time test (min,hour,day,month,wday)
```

**Day Function Syntax:**
- `day('1,13-last')` - 'last' refers to the last day in month
- `day('1,lastw-last')` - First day and last week in month (lastw = last day - 6)

**Examples:**
```lua
rule("@15:00 & wday('mon-fri') => workdayRoutine()")     -- Weekday schedule
rule("@08:00 & day('1') => monthlyReport()")             -- First day of month
rule("@sunset & month('dec-feb') => winterLights:on")    -- Winter months
rule("@12:00 & date('* * 1,15 * *') => biweeklyCheck()") -- 1st and 15th of month
```

#### Time Range Testing

```lua
<time1>..<time2>       -- Test if current time is between times (inclusive)
```

**Examples:**
```lua
rule("motion:breached & 22:00..06:00 => nightLight:on")  -- Night hours
rule("door:open & sunrise..sunset => dayAlert()")        -- Daytime hours
```

### Log and Formatting Functions

Functions for logging and string formatting within rules.

| Function | Description | Example |
|----------|-------------|---------|
| `log(fmt, ...)` | Log formatted message | `log('Temperature: %d°C', temp)` |
| `log.color(fmt, ...)` | Log with CSS colour name as method — any valid CSS colour | `log.beige('Door opened')`, `log.red('Fault: %d', code)` |
| `fmt(...)` | Format string without logging | `message = fmt('Status: %s', status)` |
| `HM(t)` | Format time as "HH:MM" | `timeStr = HM(os.time())` |
| `HMS(t)` | Format time as "HH:MM:SS" | `timeStr = HMS(os.time())` |

**Examples:**
```lua
rule("sensor:temp => log('Temperature changed to %d°C', sensor:temp)")
rule("@08:00 => log('Good morning! Time is %s', HM(now))")
rule("alarm:breached => message = fmt('ALERT at %s', HMS(now))")
```

The inline `#C:color#` tag inside the format string sets the colour in the HC3 debug console:
```lua
rule("door:open => log('#C:orange#Front door opened at %s', HM(now))")
```
`log.color(fmt, ...)` is shorthand that prepends the tag automatically — `log.orange(...)` is equivalent to `log('#C:orange#...')`. Any CSS colour name works.

### Event Functions

Functions for posting, subscribing to, and managing events.

| Function | Description | Example |
|----------|-------------|---------|
| `post(event, time)` | Post event at specified time | `post(#alarmEvent, '@08:00')` — at 08:00; `post(#event, '+01:00')` — in 1 h |
| `cancel(ref)` | Cancel posted event | `cancel(timerRef)` |
| `subscribe(event)` | Subscribe to remote events | `subscribe(#remoteEvent)` |
| `publish(event)` | Publish event to remote systems | `publish(#statusUpdate)` |
| `remote(deviceId, event)` | Send event to specific QuickApp | `remote(123, #customEvent)` |

Note: remote events requires the other QA to be an EventRunner QA.

**Examples:**
```lua
rule("@sunset => timerRef = post(#lightsOff, '+01:00')")  -- Post event in 1 hour
rule("motion:breached => cancel(timerRef)")               -- Cancel scheduled event
rule("alarm:armed => remote(456, #securityAlert)")       -- Send to specific device
```

### Math Functions

Mathematical and statistical functions for calculations.

| Function | Description | Example |
|----------|-------------|---------|
| `sign(t)` | Return sign of number (-1, 0, 1) | `direction = sign(temperature - 20)` |
| `rnd(min, max)` | Random number in range | `delay = rnd(5, 15)` |
| `round(num)` | Round to nearest integer | `temp = round(sensor:temp)` |
| `sum(...)` | Sum of arguments or table elements | `total = sum(1, 2, 3, 4)` |
| `average(...)` | Average of arguments or table | `avg = average(temps)` |
| `size(t)` | Length of array | `count = size(deviceList)` |
| `min(...)` | Minimum value | `lowest = min(temperatures)` |
| `max(...)` | Maximum value | `highest = max(temperatures)` |
| `sort(t)` | Sort table in place | `sort(values)` |
| `osdate(t)` | Same as os.date | `dateStr = osdate('%Y-%m-%d')` |
| `ostime(t)` | Same as os.time | `timestamp = ostime()` |
| `nextDST()` | Returns epoch time of next Daylight Saving Time change | `post(#restart, nextDST())` |

**Examples:**
```lua
rule("sensors:temp => avgTemp = average(sensors:temp)")
rule("@08:00 => if rnd(1,10) > 5 then specialRoutine() end")
rule("temperatures:change => log('Range: %d to %d', min(temperatures), max(temperatures))")
```

### Global Variable Functions

Functions for managing Fibaro global variables.

| Function | Description | Example |
|----------|-------------|---------|
| `global(name)` | Create global variable, returns false if exists | `isNew = global('myVariable')` |
| `deleteglobal(name)` | Delete global variable | `deleteglobal('oldVariable')` |

**Examples:**
```lua
rule("if !global('systemStatus') then log('Creating systemStatus') end")
rule("@startup => systemStatus = 'running'")
rule("@shutdown => deleteglobal('temporaryFlag')")
```

### Lambda Functions

EventScript supports two syntaxes for creating anonymous functions (lambdas):

**Arrow syntax (concise):**
```lua
-- Single parameter
x -> x * 2

-- Multiple parameters
(x, y) -> x + y

-- Zero parameters
() -> 42
```

**Keyword syntax (Lua-style, for multi-statement bodies):**
```lua
function(x) return x * 2 end
function(x, y) return x + y end
```

Arrow lambdas take a single expression as their body. Use the `function ... end` form when you need multiple statements or explicit `return`.

**Examples:**
```lua
-- Immediately invoke a lambda
(x -> x * 2)(5)                         -- 10

-- Store in a local variable
local double = x -> x * 2
double(7)                               -- 14

-- Pass to higher-order functions
local evens = filter({1,2,3,4,5}, x -> x % 2 == 0)
local squares = map({1,2,3}, x -> x ^ 2)
local total = reduce({1,2,3,4}, (a,b) -> a + b, 0)
```

### List Comprehension

List comprehensions provide a concise expression syntax for building filtered and transformed arrays without explicit loops:

```lua
[expr for val in iter]                -- map: apply expr to every value (pairs)
[expr for val in iter if guard]       -- filter+map: only include elements where guard is true
[expr for key, val in iter]           -- expose both key and value
[expr for key, val in iter if guard]  -- key+val with filter
```

- `expr` — the value to collect for each element (may reference `val` and optionally `key`)
- `val` — loop variable, bound to each value in turn
- `key` — optional loop variable for the key (string or integer)
- `iter` — any table, iterated with `pairs` (works for both arrays and dictionaries)
- `if guard` — optional predicate; element is included only when `guard` is truthy

**Examples:**
```lua
-- Double every value in an array
[x * 2 for x in {1, 2, 3}]                        -- {2, 4, 6}

-- Keep only even numbers
[x for x in {1,2,3,4,5} if x % 2 == 0]           -- {2, 4}

-- Extract a property from each device in a list
local names = [d:name for d in devices]

-- Only names of devices that are online
local online = [d:name for d in devices if d:dead == false]

-- Temperatures above threshold, converted to strings
local msgs = [fmt("%.1f°", t) for t in temps if t > 25]

-- Two-var form: build "key:value" strings from a dictionary
local t = {a=1, b=2, c=3}
local pairs = [k++':'++tostring(v) for k, v in t]  -- {"a:1", "b:2", "c:3"} (order unspecified)

-- Two-var form with filter: collect keys whose value exceeds a threshold
local hot = [k for k, v in sensors if v > 25]
```

List comprehensions desugar to a `for … in pairs(iter)` loop with an accumulator array — they are equivalent to `map`/`filter` chains but often more readable:

```lua
-- These two are equivalent:
[x * 2 for x in t if x > 0]
map(filter(t, x -> x > 0), x -> x * 2)
```

> **Note:** Iteration uses `pairs`, so the order of results for dictionary tables is unspecified. For arrays (`{1,2,3}`), Lua's `pairs` visits integer keys in ascending order in practice, but `ipairs`-style order is not guaranteed.

### Table Functions

Utility functions for working with tables and arrays.

| Function | Signature | Description |
|----------|-----------|-------------|
| `adde(t, v)` | `adde(table, value)` | Append value to end of table |
| `remove(t, v)` | `remove(table, value)` | Remove first occurrence of value |
| `sort(t)` | `sort(table)` | Sort table in-place, returns table |
| `size(t)` | `size(table)` | Return number of elements (`#t`) |
| `map(t, f)` | `map(table, func)` | Return new table with `f` applied to each element |
| `filter(t, f)` | `filter(table, pred)` | Return new table of elements where `pred(v)` is true |
| `reduce(t, f, init)` | `reduce(table, func, initial)` | Fold table left using `func(acc, v)`, starting from `init` |
| `sum(t)` | `sum(table)` | Return sum of all elements |

**Examples:**
```lua
rule("motion:breached => adde(motionLog, now)")
rule("device:offline => remove(activeDevices, device:id)")

-- map: double every value
local doubled = map({1, 2, 3}, x -> x * 2)    -- {2, 4, 6}

-- filter: keep only values above a threshold
local hot = filter(temps, x -> x > 25)         -- elements > 25

-- reduce: compute a total
local total = reduce({10, 20, 30}, (a,b) -> a + b, 0)  -- 60

-- chain: sum of squares of even numbers
local result = sum(map(filter({1,2,3,4,5}, x -> x % 2 == 0), x -> x ^ 2))  -- 20
```

### Rule Functions

Functions for controlling rule execution.

| Function | Description | Example |
|----------|-------------|---------|
| `enable(rule)` | Enable rule by ID or object | `enable(nightModeRule)` |
| `disable(rule)` | Disable rule by ID or object | `disable(dayModeRule)` |

**Examples:**
```lua
rule("@sunset => enable(nightRules); disable(dayRules)")
rule("$vacationMode == true => disable(normalRoutines)")
rule("$maintenanceMode == false => enable(allRules)")
```

## Property Functions

Property functions use the syntax `<ID>:<property>` for reading and `<ID>:<property> = <value>` for writing.

### Device Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | Trigger | Device value property |
| `state` | Trigger | Device state property |
| `bat` | Trigger | Battery level (0-100) |
| `power` | Trigger | Power consumption |
| `isDead` | Trigger | Device dead status |
| `isOn` | Trigger | True if device/any in list is on |
| `isOff` | Trigger | True if device is off/all in list are off |
| `isAllOn` | Trigger | True if all devices in list are on |
| `isAnyOff` | Trigger | True if any device in list is off |
| `last` | Trigger | Time since last breach/trigger |
| `safe` | Trigger | True if device is safe |
| `breached` | Trigger | True if device is breached |
| `isOpen` | Trigger | True if device is open |
| `isClosed` | Trigger | True if device is closed |
| `lux` | Trigger | Light sensor value |
| `volume` | Trigger | Audio volume level |
| `position` | Trigger | Device position (blinds, etc.) |
| `temp` | Trigger | Temperature value |
| `scene` | Trigger | Scene activation event value |
| `central` | Trigger | Central scene event, {keyId=.., keyAttribute=...} |
| `key` | Trigger | Central scene event, "\<keyId>:\<keyAttribute>" |

### Device Control Actions

| Property | Type | Description |
|----------|------|-------------|
| `on` | Action | Turn device on |
| `off` | Action | Turn device off |
| `toggle` | Action | Toggle device state |
| `play` | Action | Start media playback |
| `pause` | Action | Pause media playback |
| `open` | Action | Open device (blinds, locks) |
| `close` | Action | Close device |
| `stop` | Action | Stop device operation |
| `secure` | Action | Secure device (locks) |
| `unsecure` | Action | Unsecure device |
| `wake` | Action | Wake up dead Z-Wave device |
| `levelIncrease` | Action | Start level increase |
| `levelDecrease` | Action | Start level decrease |
| `levelStop` | Action | Stop level change |

### Device Assignment Properties

| Property | Description |
|----------|-------------|
| `value = <val>` | Set device value |
| `state = <val>` | Set device state |
| `R = <val>` | Set red color component |
| `G = <val>` | Set green color component |
| `B = <val>` | Set blue color component |
| `W = <val>` | Set white color component |
| `color = <rgb>` | Set RGB color values |
| `volume = <val>` | Set audio volume |
| `position = <val>` | Set device position |
| `power = <val>` | Set power level |
| `targetLevel = <val>` | Set target dimmer level |
| `interval = <val>` | Set interval value |
| `mode = <val>` | Set device mode |
| `mute = <bool>` | Set mute state |
| `dim = <table>` | Gradually dim a multilevel device (see [Dim Light Support](#dim-light-support) below) |
| `msg = <text>` | Send push message |
| `email = <text>` | Send email notification |

#### Dim Light Support

`device:dim = {sec, dir, step, curve, start, stop}` smoothly dims a multilevel device over time. The value is a positional table matching the parameters of `er.dimLight(id, sec, dir, step, curve, start, stop)`:

| Position | Parameter | Default | Description |
|----------|-----------|---------|-------------|
| 1 | `sec` | required | Duration in seconds |
| 2 | `dir` | `'up'` | Direction: `'up'` or `'down'` |
| 3 | `step` | `1` | Step size per tick |
| 4 | `curve` | `'linear'` | Easing curve: `'linear'`, `'inQuad'`, `'inOutQuad'`, `'inExpo'`, `'outExpo'`, `'inOutExpo'`, `'outInExpo'` |
| 5 | `start` | `0` | Start brightness level (0–99) |
| 6 | `stop` | `99` | End brightness level (0–99) |

Dimming is stopped automatically if the device level is changed externally during the dim sequence.

**Examples:**
```lua
rule("motionSensor:safe => floorLamp:dim = {30, 'down'}")
-- Fade out over 30 seconds

rule("@07:00 => bedroomLight:dim = {120, 'up', 1, 'inOutExpo', 0, 80}")
-- Gentle sunrise fade to 80% over 2 minutes
```

### Partition Properties

| Property | Type | Description |
|----------|------|-------------|
| `armed` | Trigger | True if partition is armed |
| `isArmed` | Trigger | True if partition is armed |
| `isDisarmed` | Trigger | True if partition is disarmed |
| `isAllArmed` | Trigger | True if all partitions are armed |
| `isAnyDisarmed` | Trigger | True if any partition is disarmed |
| `isAlarmBreached` | Trigger | True if partition is breached |
| `isAlarmSafe` | Trigger | True if partition is safe |
| `isAllAlarmBreached` | Trigger | True if all partitions breached |
| `isAnyAlarmSafe` | Trigger | True if any partition is safe |
| `tryArm` | Action | Attempt to arm partition |
| `armed = <bool>` | Action | Arm or disarm partition |

### Thermostat Properties

| Property | Type | Description |
|----------|------|-------------|
| `thermostatMode` | Trigger/Action | Thermostat operating mode |
| `thermostatModeFuture` | Trigger | Future thermostat mode |
| `thermostatFanMode` | Trigger/Action | Fan operating mode |
| `thermostatFanOff` | Trigger | Fan off status |
| `heatingThermostatSetpoint` | Trigger/Action | Heating setpoint |
| `coolingThermostatSetpoint` | Trigger/Action | Cooling setpoint |
| `heatingThermostatSetpointCapabilitiesMax` | Trigger | Max heating setpoint |
| `heatingThermostatSetpointCapabilitiesMin` | Trigger | Min heating setpoint |
| `coolingThermostatSetpointCapabilitiesMax` | Trigger | Max cooling setpoint |
| `coolingThermostatSetpointCapabilitiesMin` | Trigger | Min cooling setpoint |
| `thermostatSetpoint = <val>` | Action | Set thermostat setpoint |

### Scene Properties

| Property | Type | Description |
|----------|------|-------------|
| `start` | Action | Start/execute scene |
| `kill` | Action | Stop scene execution |

### Information Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | Info | Device name |
| `roomName` | Info | Room name containing device |
| `HTname` | Info | HomeTable variable name |
| `profile` | Info | Current active profile |
| `access` | Trigger | Access control event |
| `central` | Trigger | Central scene event |
| `time` | Trigger/Action | Device time property |
| `manual` | Trigger | Manual operation status |
| `trigger` | Trigger | Generic trigger property |

### List Operations

| Operation | Description |
|-----------|-------------|
| `average` | Average of numbers in list |
| `sum` | Sum of values in list |
| `allTrue` | True if all values are true |
| `someTrue` | True if at least one value is true |
| `allFalse` | True if all values are false |
| `someFalse` | True if at least one value is false |
| `mostlyTrue` | True if majority of values are true |
| `mostlyFalse` | True if majority of values are false |

### Weather Object

A predefined `weather` object is available in scripts and rules for reading current weather data from the HC3. It supports both property reads and property-change triggers.

| Property | Trigger event | Description |
|----------|---------------|-------------|
| `weather:temp` | `{type='weather', property='Temperature'}` | Outdoor temperature |
| `weather:humidity` | `{type='weather', property='Humidity'}` | Outdoor humidity |
| `weather:wind` | `{type='weather', property='Wind'}` | Wind speed |
| `weather:condition` | `{type='weather', property='WeatherCondition'}` | Weather condition string |

**Examples:**
```lua
rule("weather:temp < 0 & @06:00 => carHeater:on")
rule("weather:condition => log('Weather changed to: %s', weather:condition)")
rule("weather:humidity > 80 => log('High humidity: %d%%', weather:humidity)")
```
| `bin` | Convert to binary (1 for truthy, 0 for falsy) |
| `leaf` | Extract leaf nodes from nested table |

### HTTP Functions

Asynchronous HTTP helper functions available inside rules and scripts. Each call suspends the current rule until the response arrives (similar to `wait()`) without blocking other rules.

| Function | Returns | Description |
|----------|---------|-------------|
| `http.get(url[, opts[, default]])` | `result, status` | HTTP GET |
| `http.put(url[, opts[, data[, default]]])` | `result, status` | HTTP PUT |
| `http.post(url[, opts[, data[, default]]])` | `result, status` | HTTP POST |
| `http.delete(url[, opts[, default]])` | `result, status` | HTTP DELETE |

`result` is the parsed JSON response body (or `default` on error). `status` is the HTTP status code (number).

The optional `opts` table supports:
| Key | Description |
|-----|-------------|
| `timeout` | Request timeout in seconds (default 30) |
| `user` / `pwd` | HTTP Basic Auth credentials |
| `headers` | Table of additional request headers |

**Examples:**
```lua
rule("@08:00 =>\n  local data, status = http.get('http://192.168.1.100/api/status')\n  if status == 200 then log('Status: %s', data.state) end")

rule("sensor:temp =>\n  http.post('http://my-logger/api/data',\n    {user='admin', pwd='secret'},\n    {sensor=sensor:id, value=sensor:temp})")
```

## Named Scenes

A **named scene** groups a set of device property assignments under a name. Scenes are declared as statements (using the soft keyword `scene`) and activated or deactivated via the property syntax.

### Declaring a scene

**Short form** — all entries are treated as the *activate* body:

```lua
scene cozy = { light1:value=80, light2:level=50, blind:position=30 }
```

**Long form** — explicit `activate` and/or `deactivate` subsections (order is irrelevant):

```lua
scene movienight = {
  activate:   { projector:on, lights:value=10, blind:position=0 },
  deactivate: { projector:off, lights:value=100, blind:position=100 }
}
```

An activate-only scene has no `deactivate` body; calling `:deactivate` on it is a runtime error that disables the rule.

### Entry value semantics

Entry values follow these evaluation rules:

- **Literals** (`42`, `true`, `"closed"`, etc.) are stored directly at declaration time.
- **Expressions** (variable references, arithmetic, function calls) are wrapped in a zero-argument lambda and **re-evaluated each time the scene is activated/deactivated**. This means the scene always uses the current value of any variables it references.

```lua
scene dynscene = {
  activate:   { dimmer:value=targetLevel },   -- re-reads targetLevel on every activate
  deactivate: { dimmer:value=0 }
}
```

### Using a scene

Activate or deactivate a scene using the property syntax inside a rule action:

```lua
rule("@sunset => movienight:activate")
rule("@midnight => movienight:deactivate")

-- Conditional scene switch:
rule("button:pressed => if isMovieTime then movienight:activate else cozy:activate end")
```

Scenes are standard `PropObject`-derived values; they can be stored in variables, passed to functions, and used anywhere a property object is valid.

```lua
scene garden = {
  activate:   { porch:on, path:value=60 },
  deactivate: { porch:off, path:off }
}

local myScene = garden      -- scene object can be stored in a variable
rule("@sunset => myScene:activate")
rule("@sunrise => myScene:deactivate")
```

### Summary table

| Syntax | Description |
|--------|-------------|
| `scene name = { obj:prop=expr, ... }` | Short form: activate-only scene |
| `scene name = { activate: { ... }, deactivate: { ... } }` | Long form: separate activate/deactivate bodies |
| `name:activate` | Run the activate body |
| `name:deactivate` | Run the deactivate body (runtime error if none defined) |

---

## Extending the Property System

### Adding Custom Device Properties (`er.addStdProp`)

`er.addStdProp(name, def)` registers a new property name that can then be used with the `device:name` syntax on any device.

`def` is a table with the following fields:

| Field | Required | Description |
|-------|----------|-------------|
| `get` | no | `function(prop, id, event)` – returns the property value |
| `set` | no | `function(prop, id, value, event)` – sets the property value |
| `trigger` | no | `{type=..., property=...}` – HC3 event that triggers this property |
| `reduce` | no | Function or `table.mapF` for list aggregation |
| `setCmd` | no | Alternative fibaro action command name used by the default `set` handler |

**Example:**
```lua
er.addStdProp("myProp", {
  trigger = { type = 'device', property = 'myProp' },
  get     = function(prop, id, event) return fibaro.getValue(id, "myProp") end,
  set     = function(prop, id, value, event) fibaro.call(id, "setMyProp", value) end,
})

-- Use like any built-in property:
rule("device:myProp > 50 => log('myProp is %d', device:myProp)")
```

### Defining Custom Property Classes (`er.definePropClass`)

`er.definePropClass(name)` creates a new class derived from `PropObject` that can be used with the `obj:property` syntax just like device IDs. Use this to wrap non-device data sources (APIs, sensors, services) as first-class property objects.

After calling `er.definePropClass("MyClass")`, the new class has four empty tables to fill in:

| Table | Purpose |
|-------|---------|
| `MyClass.getProp[prop]` | `function(prop, env)` – getter called when reading `obj:prop` |
| `MyClass.setProp[prop]` | `function(prop, env, value)` – setter called when assigning `obj:prop = value` |
| `MyClass.trigger[prop]` | `function(prop)` – returns HC3 event `{type=..., property=...}` that triggers on `obj:prop` changes |
| `MyClass.map[prop]` | Optional reduce/map function for list aggregation |

**Example — defining a custom class (how the built-in `weather` object is created):**
```lua
er.definePropClass("Weather")
function Weather:__init() PropObject.__init(self) end

function Weather.getProp.temp(prop, env)      return api.get("/weather").Temperature end
function Weather.getProp.humidity(prop, env)  return api.get("/weather").Humidity end
function Weather.getProp.wind(prop, env)      return api.get("/weather").Wind end
function Weather.getProp.condition(prop, env) return api.get("/weather").WeatherCondition end

function Weather.trigger.temp(prop)      return {type='weather', property='Temperature'} end
function Weather.trigger.humidity(prop)  return {type='weather', property='Humidity'} end
function Weather.trigger.wind(prop)      return {type='weather', property='Wind'} end
function Weather.trigger.condition(prop) return {type='weather', property='WeatherCondition'} end

-- Expose as a script variable:
var.weather = Weather()
```

Once defined, the object is used like a device:
```lua
rule("weather:temp < 0 => carHeater:on")
rule("weather:condition => log('Weather: %s', weather:condition)")
```

## Examples

### Basic Device Control
```lua
rule("@08:00 => livingRoomLights:on")           -- Morning lights
rule("motionSensor:breached => hallwayLight:on") -- Motion activation
rule("@sunset => {porch,garden,driveway}:on")   -- Evening outdoor lights
```

### Conditional Logic
```lua
rule("door:isOpen & @sunset => securityLight:on")      -- Security at sunset
rule("trueFor(00:10, house:isAllOff) => alarm:arm")    -- Auto-arm when quiet
rule("luxSensor:value < 100 & motion:breached => lights:on") -- Smart lighting
```

### Time-based Automation
```lua
rule("@{07:00,19:00} => thermostat:mode='auto'")        -- Twice daily schedule
rule("22:00..06:00 & motion:breached => nightLight:on") -- Night mode
rule("@@00:30 => hvac:refresh")                         -- Regular maintenance
```

### List Operations
```lua
rule("temperatureSensors:average > 25 => fan:on")       -- Climate control
rule("{sensor1,sensor2,sensor3}:someTrue => alert:on")  -- Multi-sensor alert
rule("allLights:isAnyOff => log('Some lights are off')") -- Status monitoring
```

### Advanced Scenarios
```lua
-- Vacation mode
rule("$vacationMode == true & motion:breached => securityAlert")

-- Energy saving
rule("trueFor(01:00, room:isAllOff) => hvac:targetLevel=18")

-- Weather-based automation
rule("weatherStation:temp < 0 & @06:00 => carHeater:on")
```

## Rule Modifiers

Modifiers are optional keywords placed between the condition and `=>`. They change *when* or *how many times* the action fires.

```
condition [modifier...] => action
```

| Modifier | Syntax | Effect |
|----------|--------|--------|
| `single` | `cond single =>` | Cancel all pending timers/waits from the current run and start fresh when condition re-fires |
| `since` | `cond since duration =>` | Condition must stay true for `duration` seconds first (alias for `trueFor`) |
| `debounce` | `cond debounce duration =>` | Wait `duration` s after last true; restart timer if fires again (implies `single`) |
| `cooldown` | `cond cooldown duration =>` | After action completes, ignore re-triggers for `duration` seconds |
| `every` | `cond every n =>` | Fire only on every `n`-th true evaluation |
| `first_in` | `cond first_in T1..T2 =>` | Fire only the first time the trigger is true within the time window `T1..T2`; resets at window end |

**Examples:**
```lua
rule("doorbell:pressed single => wait(0.5); chime:play")
-- Re-starts chime if pressed again mid-play (0.5 = 500 ms).

rule("motion:breached since 00:02 => alarm:on")
-- Only triggers after 2 continuous minutes of motion.

rule("search:keypress debounce 0.5 => searchAPI(query)")
-- Waits 500 ms of silence before calling search.

rule("motion:breached cooldown 00:05 => notify('Motion detected')")
-- At most one notification per 5 minutes.

rule("tempSensor:value every 4 => log('Temp: %d', tempSensor:value)")
-- Logs on every 4th temperature change.

-- first_in: play radio the first time sensor is breached in the morning window
rule("sensor:breached first_in 07:00..08:00 => radio:play")

-- Modifiers compose:
rule("button:pressed single cooldown 2 => wait(0.1); light:toggle")
```

## Reserved Keywords

The following identifiers are reserved by the EventScript language and cannot be used as variable names, function names, or after `.` in a property access. If a device or object has a method whose name clashes (e.g. `obj.single()`), use bracket notation instead: `obj["single"]()`.

### Language control keywords

`if`, `then`, `else`, `elseif`, `end`, `while`, `do`, `loop`, `repeat`, `until`, `return`, `break`, `nil`, `true`, `false`, `for`, `in`, `local`, `function`, `not`, `and`, `or`, `case`

### Rule modifier keywords

`single`, `since`, `debounce`, `cooldown`, `every`, `first_in`

**Workaround for clashing names:** Use bracket-index syntax to access any method or property whose name is a keyword:

```lua
-- Wrong — 'single' is a reserved keyword:
-- obj.single()

-- Correct:
obj["single"]()
```

## BREAK — stop rule dispatch early

When multiple rules share the same trigger, EventRunner fires them all in registration order. A rule action can `return BREAK` to stop processing further rules for that trigger event:

```lua
er.triggerVars.a = 0
rule("a == 1 => log('OK1'); return BREAK")  -- fires, then stops
rule("a == 1 => log('OK2')")                -- never reached
rule("a = 1")                               -- sets a → fires the two rules above
```

`BREAK` is a sentinel value (`'%BREAK%'`) exposed via `er.defglobals.BREAK`. Rules that share a *different* trigger are unaffected.

> **Important:** `BREAK` only works in **synchronous** rule actions. When an action contains `wait()`, the event engine has already advanced past subsequent rules before the wait completes.

## Rule management functions

Defining a rule returns a rule object with methods for managing and controlling the rule:

```lua
local r = rule("triggerExpression => actions")

r.disable() -- disables the rule and cancels all its pending timers
r.enable()  -- re-enables the rule (daily/interval rules resume)
r.start()   -- trigger the rule manually, bypassing the condition
r.info()    -- logs current state to console
```

### Rule Groups

Any rule can be assigned to a named group by passing `group` in the opts table:

```lua
rule("motion:breached => light:on",  {group="bedroom"})
rule("@23:00 => light:off",          {group="bedroom"})
rule("door:isOpen => alarm:on",      {group="security"})
```

All rules in a group can then be enabled or disabled together — either from outside, using the rule object returned by `er.eval`, or from inside a rule action using the built-in `enable`/`disable` functions:

```lua
-- From outside (Lua scope):
for _, r in ipairs(er.getGroup("bedroom")) do r.disable() end

-- From inside a rule action:
rule("sleepButton:pressed => disable('bedroom')")
rule("wakeButton:pressed  => enable('bedroom')")

-- enable/disable also accept a rule object or numeric rule ID:
rule("button:pressed => disable(r)")
rule("button:pressed => disable(1)")  -- disable RULE1
```

​
A rule has a life-cycle, or states, that it passes through.
1. Defined, when a rule is defined/created.
2. When a rule is started/triggered
3. If the trigger expression (condition) of the rule succeeded or failed, if succeeded the action will run
4. Optionally, the rule can wait, be suspended, and later woken up. Typically with the wait(time) command.
5. The action of the rule can produce a result
  
When a rule is defined and triggered there are logs created in the console for the above states. We can tailor them to our own look&feel.
```lua
er.opts = {
    started = boolean/function, -- true => system start log, alt. user function(rule,env,trigger)
    check = boolean/function,   -- true => system check log, alt. user function(rule,env,cond result)
    result = boolean/function,  -- true => system result log, alt. user function(rule,result)
    triggers = boolean,         -- list triggers when rule defined
    waiting = boolean/function, -- true => system waiting log, alt. user function(rule,env,time)
    waited = boolean/function,  -- true => system waited log, alt. user function(rule,env,time)
    defined = boolean/function,  -- true => log rule defined, alt. user function(rule)
    ruleDefPrefix = "✅",       -- prefix string for rule defined result
    triggerListPrefix = "⚡",    -- prefix string for listed rule triggers
    dailyListPrefix = "🕒",     -- prefix string for listed rule dailys
    startPrefix = "🎬",         -- prefix string for rule started/triggered
    successPrefix = "👍",       -- prefix string for rule check/success
    failPrefix = "👎",          -- prefix string for rule check/fail
    resultPrefix = "📋",        -- prefix string for rule result
    errorPrefix = "❌",         -- prefix string for rule compile error
    waitPrefix = "💤",          -- prefix string for rule waiting/sleep notification
    waitedPrefix = "⏰",        -- prefix string for rule waited/awake notification
} 
```
The prefix strings shown are the defaults, and boolean/functions are set to false as default.

If we turn on all flags we get
```lua
  rule("#foo => wait(10); return 77")
  rule("post(#foo)")
```
```bash
[04.09.2025][08:12:58][DEBUG  ][ER65555]: Rule 1 triggers: -- Listing trigger, opts.triggers = true
[04.09.2025][08:12:58][DEBUG  ][ER65555]: ⚡ #foo{}         -- Event trigger, opts.triggerListPrefix = "⚡"
[04.09.2025][08:12:58][DEBUG  ][ER65555]: ✅ [Rule:1] #foo => wait(10); return 77 -- opts.ruleDefPrefix = "✅"
[04.09.2025][08:12:58][DEBUG  ][ER65555]: =========== Load time: 0.010s ============
[04.09.2025][08:12:59][DEBUG  ][ER65555]: 🎬 [Rule:1]: #foo{}  -- opts.started = true, opts.startPrefix = "🎬"
[04.09.2025][08:12:59][DEBUG  ][ER65555]: 👍 [Rule:1]          -- opts.check = true, opts.successPrefix = "👍"
[04.09.2025][08:12:59][DEBUG  ][ER65555]: 💤 [Rule:1]: ⏰08:13:09 -- opts.waiting = true, opts.waitPrefix = "💤"
[04.09.2025][08:13:09][DEBUG  ][ER65555]: ⏰ [Rule:1]: awake      -- opts.waited = true, opts.waitedPrefix = "⏰"
[04.09.2025][08:13:09][DEBUG  ][ER65555]: 📋 [Rule:1]: 77         -- opts.result = true, opts.resultPrefix = "📋"
```
  
To get a reasonable log we start in main by setting some of the flags.
```lua
er.opts = { started = true, check = true, triggers = true }
```
Then we get the triggers listed for a defined rule - always good to see if it will react to the events we had in mind.
We get a log when the rule is started and it show the event that triggered the rule
We get a log with thumbs up/down depending how the rule condition went.
  
er.pts are defined globally and are applied to all defined rules. We can override opts by giving an opts argument to rule(str,opts)

The options for the rule will be the global er.opts override with the opts we give for the rule.
```lua
rule("@sunset => lamp:on",{check=false})
```
More advanced, we can provide a log function for the rule logs.
An example. We can ignore the start message, and instead only log if the check/success of the rule is true.
```lua
er.opts = { started = true, check = true, result = false, triggers=true, }

local function check(rule, env, res)
  if res then print(string.format("%s %s",rule.successPrefix,env.trigger)) end
end

rule("#foo => wait(10); return 77",{triggers=true,started=false,check=check}) -- no start msg, and custom check
rule("post(#foo)")
```
```bash
[04.09.2025][08:30:42][DEBUG  ][ER65555]: Rule 1 triggers:  -- opts.triggers = true
[04.09.2025][08:30:42][DEBUG  ][ER65555]: ⚡ #foo{}
[04.09.2025][08:30:42][DEBUG  ][ER65555]: ✅ [Rule:1] #foo => return 77
[04.09.2025][08:30:42][DEBUG  ][ER65555]: =========== Load time: 0.011s ============
[04.09.2025][08:30:42][DEBUG  ][ER65555]: 👍 #foo{} -- No start message, only our own check with success and trigger
```

## Best Practices

1. **Use meaningful device names** in your HomeTable variables
2. **Group related devices** in lists for easier management
3. **Combine time guards** with device triggers for smarter automation
4. **Use trueFor()** to avoid false triggers from brief state changes
5. **Test rules thoroughly** before deploying to production
6. **Document complex rules** with comments in your main function
7. **Use trigger variables** for inter-rule communication
8. **Leverage list operations** for aggregated device control
9. **Turn on logging flags** during development with `er.opts = { started=true, check=true, triggers=true }` and turn them off for production


