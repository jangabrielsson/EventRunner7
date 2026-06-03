# EventScript Tutorial: Home Automation for Beginners

Welcome to EventScript! This tutorial will teach you how to create powerful
home automation rules using EventRunner7's intuitive rule-based language.
We'll start with the basics and work our way up to advanced automation
scenarios.

## Table of Contents

- [Before You Start](#before-you-start)
- [A Quick Orientation: Lua and EventScript](#a-quick-orientation-lua-and-eventscript)
- [Getting Started](#getting-started)
- [Your First Rules](#your-first-rules)
- [Setting up a Home Table](#setting-up-a-home-table)
- [Working with Variables](#working-with-variables)
- [Types of Rules](#types-of-rules)
  - [Time-based Rules](#time-based-rules)
  - [Interval Rules](#interval-rules)
  - [Device-triggered Rules](#device-triggered-rules)
- [Structuring Rules with Events](#structuring-rules-with-events)
  - [Simple Events](#simple-events)
  - [Events with Parameters](#events-with-parameters)
  - [Pattern Matching with Variables](#pattern-matching-with-variables)
  - [Cancelling Scheduled Events](#cancelling-scheduled-events)
  - [Complex Event Sequences](#complex-event-sequences)
- [Trigger Variables](#trigger-variables)
- [Basic Functionality](#basic-functionality)
  - [Working with Remotes](#working-with-remotes)
  - [Working with Alarms](#working-with-alarms)
- [Common Home Automation Patterns](#common-home-automation-patterns)
  - [Morning Routine](#morning-routine)
  - [Security System](#security-system)
  - [Energy Saving](#energy-saving)
  - [Vacation Mode](#vacation-mode)
  - [Weather-based Automation](#weather-based-automation)
- [Putting It All Together](#putting-it-all-together)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Quick Reference: 10 Essential Patterns](#quick-reference-10-essential-patterns)
- [Glossary](#glossary)

---

## Before You Start

To follow this tutorial you need:

- **EventRunner7 installed** on your Fibaro HC3. See the
  [README](https://github.com/jangabrielsson/EventRunner7) for installation
  instructions — download the `.fqa` file and import it as a QuickApp.
- **At least one device ID** from your Fibaro dashboard (a light bulb,
  motion sensor, or door sensor). You'll find device IDs in the HC3 web
  interface under Devices → select a device → the number in the URL or
  panel header.
- **The HC3 debug console open** so you can see `log()` output. In the HC3
  web interface: open your EventRunner QuickApp, switch to the Debug tab
  (the bug icon), and click "Start". You'll see rule logs appear here.

> **Tip:** Throughout the tutorial, replace example device IDs (like `54`,
> `77`) with your own. Use the debug console to verify rules are firing.

---

## A Quick Orientation: Lua and EventScript

Your QuickApp file mixes **two languages** — this is the most important
concept to understand before you start:

```
┌─────────────────────────────────────────────┐
│  Lua code (outside rule("..."))             │
│  - Defines functions                        │
│  - Sets up variables and the Home Table      │
│  - Initialises EventRunner                  │
│                                             │
│  rule("  EventScript (inside the string)  " │
│  rule("  - Triggers and actions            " │
│  rule("  - Device control, logging         " │
│                                             │
└─────────────────────────────────────────────┘
```

Think of it as: **Lua builds the stage; EventScript runs the show.**

- **Outside `rule("...")`** you write Lua — `function`, `local`, `if`,
  `er.defvars(HT)`. These run once when EventRunner starts.
- **Inside `rule("...")`** you write EventScript — `@08:00`, `motion:breached`,
  `light:on`, `wait(5)`. These define automation rules that run whenever
  their triggers fire.

This is why you'll see Lua patterns like `function main(er) ... end` and
EventScript patterns like `rule("@sunset => lights:off")` in the same file.

---

## Getting Started

Every EventRunner QuickApp has the same skeleton. Create a new QuickApp
(or edit your existing one) and replace the `main` function:

```lua
--%%name:EventRunner7
--%%type:com.fibaro.deviceController

local function main(er)
  local rule = er.eval          -- rule() is an alias for er.eval
  local var = er.variables      -- shared variables, accessible across all rules

  -- Your rules go here
  rule("@08:00 => log('Good morning!')")
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
```

Deploy this QuickApp and check the debug console. At 08:00 you'll see
"Good morning!" appear.

Let's break down the key parts:

| Part | What it does |
|------|-------------|
| `rule` / `er.eval` | Registers an automation rule |
| `var` / `er.variables` | Table for storing variables accessible across all rules |
| `fibaro.EventRunner(main)` | Initialises EventRunner and calls `main(er)` after startup |

> **Note:** From here on, code examples show only the body of the `main`
> function for brevity. The `function QuickApp:onInit() ... end` skeleton
> and `--%%` header lines are assumed. When you copy examples, paste them
> inside `main(er)`.

---

## Your First Rules

Let's start with simple rules. The basic pattern is:

```
rule("trigger => action")
```

`=>` means **"when the left side is true, do the right side."**

```lua
local rule, var = er.eval, er.variables

-- Log a message every morning
rule("@08:00 => log('Good morning! Time to wake up')")

-- Log a message every night
rule("@23:00 => log('Good night! Time for bed')")

-- Log the current time every hour
rule("@@01:00 => log('The time is now %s', HM(now))")
```

**Try this:**
- Change `@23:00` to a short interval like `@@00:00:30` so you can see it
  fire quickly, then change it back.
- Add a rule for sunset: `rule("@sunset => log('Sunset!')")`.
- Add a multi-time trigger: `@{09:00,12:00,18:00} => log('Check-in')`.

---

## Setting up a Home Table

Typing device IDs like `54`, `77`, `101` in every rule becomes unreadable
fast. A **Home Table** (HT) lets you name your devices once and use
meaningful names everywhere.

```lua
local rule, var = er.eval, er.variables

-- Define your home structure — replace these IDs with your own!
local HT = {
  kitchen = {
    sensor = { motion = 77, door = 99, temp = 101 },
    light  = { ceiling = 54, underCabinet = 78 }
  },
  livingroom = {
    sensor = { motion = 88, lux = 89 },
    light  = { ceiling = 91, floorLamp = 92 }
  },
  bedroom = {
    sensor = { motion = 65 },
    light  = { ceiling = 67, bedside = 68 }
  }
}

-- Make all HT names available in rules
er.defvars(HT)

-- Now your rules read like natural language!
rule("kitchen.sensor.motion:breached => kitchen.light.ceiling:on")
rule("livingroom.sensor.lux:value < 100 => livingroom.light.ceiling:on")
rule("@23:00 => bedroom.light.bedside:on; wait(10); bedroom.light:off")
```

`er.defvars(HT)` copies every key from your Home Table into the variable
environment — so `kitchen.sensor.motion` resolves to device ID `77`, and
`kitchen.sensor.motion:breached` reads that device's breached property.

> **Where do the numbers come from?** Open your HC3 web interface →
> Devices → select a device. The device ID is shown in the panel header or
> the URL. Replace `77`, `54`, etc. with your own IDs.

> **Note:** In Lua code outside `rule("...")` strings (like building
> convenience lists), you still use the local `HT` table directly
> (`HT.kitchen.light.ceiling`). The `er.defvars()` shortcut applies only
> inside EventScript rules.

**Try this:**
- Add your own room with a light and a sensor.
- Create a list of all lights:
  `var.allLights = {HT.kitchen.light.ceiling, HT.livingroom.light.ceiling}`
  and turn them all off with `rule("@23:00 => allLights:off")`.

From here on, **every example drops the `HT.` prefix in rules.** The
result reads like natural language:
`kitchen.sensor.motion:breached => kitchen.light.ceiling:on`.

---

## Working with Variables

Variables let you store values and share data between rules.

There are two kinds — this distinction matters:

| Variable type | Example | Changes trigger rules? | Use for |
|--------------|---------|----------------------|---------|
| Regular variable | `var.homeMode = "normal"` | No | Storing state, config, counts |
| Trigger variable | `triggerVar.homeOccupied = false` | **Yes** — rules watching the name fire | Inter-rule signals, mode changes |

```lua
local rule, var, triggerVar = er.eval, er.variables, er.triggerVariables

-- Regular variables — change silently
var.homeMode = "normal"
var.motionCount = 0

-- Trigger variables — fire rules when changed
triggerVar.homeOccupied = false
triggerVar.nightMode = false

-- Rules that react to trigger variable changes
rule("homeOccupied == true => log('Someone is home!')")
rule("nightMode == true => livingroom.light.ceiling:off")

-- Set them from other rules
rule("@sunset => homeOccupied = true")
rule("@23:00 => nightMode = true")
rule("kitchen.sensor.motion:breached => motionCount += 1")
```

> **Defining functions on `var`:** When you write `function var.myFun(x, y)
> return x + y end`, the function becomes accessible as `myFun(...)` inside
> rules. Defining on `var` makes it visible to EventScript.

---

## Types of Rules

### Time-based Rules

Time-based rules run at specific times of the day:

```lua
-- Single time
rule("@08:00 => log('Time for breakfast')")

-- Multiple times
rule("@{07:00,12:00,18:00} => log('Meal time!')")

-- Sunset/sunrise
rule("@sunset => livingroom.light.ceiling:on")
rule("@sunrise => livingroom.light.ceiling:off")

-- Offset from sun events
rule("@sunset-00:30 => livingroom.blinds:close")  -- 30 min before sunset

-- Time ranges as guards — the rule only fires within this window
rule("kitchen.sensor.motion:breached & 22:00..06:00 => kitchen.light.ceiling:on")

-- Catch-up: if ER restarts after the scheduled time, run immediately
rule("@{08:00,catch} => bedroom.light.ceiling:on")
```

Time rules specify times from 00:00 to 24:00. To restrict to specific days
or months, add a guard (see [Best Practices](#best-practices)).

**Try this:**
- Add a weekday guard: `@07:30 & wday('mon-fri') => log('Weekday wake-up')`.
- Schedule two times in one rule: `@{07:00,19:00} => log('Twice a day')`.

### Interval Rules

Interval rules run repeatedly at fixed intervals:

```lua
-- Every 5 minutes
rule("@@00:05 => log('5 minute check')")

-- Every hour, aligned to the clock (fires at HH:00)
rule("@@-01:00 => log('Hourly report at %s', HM(now))")

-- Every 30 seconds
rule("@@00:00:30 => temperatureCheck()")
```

**Try this:**
- Switch to aligned hourly: `@@-01:00 => log('Top of the hour')` and
  notice it fires exactly at HH:00, not when EventRunner started.
- Use a short test interval: `@@00:00:10 => log('10s test')` and remove
  after verifying.

### Device-triggered Rules

These rules respond to changes in your smart devices:

```lua
-- Motion sensor triggers light
rule("kitchen.sensor.motion:breached => kitchen.light.ceiling:on")

-- Door sensor triggers alert
rule("kitchen.sensor.door:isOpen => log('Kitchen door opened!')")

-- Temperature sensor triggers fan
rule("livingroom.sensor.temp:value > 25 => livingroom.fan:on")

-- Multiple devices trigger together
rule("{kitchen.sensor.door, livingroom.sensor.motion}:breached => log('Activity!')")
```

**Try this:**
- Combine with a time guard:
  `kitchen.sensor.motion:breached & 22:00..06:00 => bedroom.light.ceiling:on`.
- Trigger on a numeric threshold:
  `livingroom.sensor.temp:value >= 26 => livingroom.fan:on`.

---

## Structuring Rules with Events

Custom events let you break complex logic into manageable pieces. Think of
them as subroutines: **post** an event from one rule, **handle** it in
another.

### Simple Events

The simplest pattern: post a named event and react to it.

```lua
-- Post an event
rule("@sunset => post(#eveningRoutine)")
rule("kitchen.sensor.motion:breached & 22:00..06:00 => post(#nightMode)")

-- Handle it in another rule (acts like a subroutine)
rule([[#eveningRoutine =>
  livingroom.light.ceiling:on;
  log('Evening routine activated')
]])

rule([[#nightMode =>
  bedroom.light.ceiling:on;
  wait(5);
  bedroom.light.ceiling:off
]])
```

> **`[[...]]`** is Lua's way of writing multi-line strings — it lets you
> spread a rule across multiple lines for readability.

Events can also be scheduled for later:

```lua
-- Post with a relative delay (+ prefix)
rule("@sunset => post(#lightsOff, +/01:30)")     -- 1 hour 30 min later

-- Post at a specific time today
rule("@08:00 => post(#reminder, t/12:00)")       -- At 12:00 today

-- Post at a specific date and time
rule("livingroom.sensor.motion:breached => post(#vacation, 2026/12/24/18:00)")
```

**Try this:**
- Post an event from a device trigger and handle it separately.
- Chain an event with a delay:
  `post(#followUp, +/00:15)` in one rule, handle `#followUp` in another.

### Events with Parameters

Events can carry data — like a function call with arguments.

```lua
-- Post events with parameters
rule("livingroom.sensor.temp:value > 25 =>
  post(#temperatureAlert{level='high', temp=livingroom.sensor.temp:value})")

rule("livingroom.sensor.temp:value < 15 =>
  post(#temperatureAlert{level='low', temp=livingroom.sensor.temp:value})")

-- Handle specific parameter values
rule([[#temperatureAlert{level='high'} =>
  livingroom.fan:on;
  log('High temperature alert: %d°C', temp)
]])

rule([[#temperatureAlert{level='low'} =>
  livingroom.heater:on;
  log('Low temperature alert: %d°C', temp)
]])

-- Catch-all: handle any #temperatureAlert regardless of parameters
rule("#temperatureAlert => log('Temperature event received')")
```

**Try this:**
- Create a `#motionDetected{room='kitchen'}` event and handle it differently
  from `#motionDetected{room='bedroom'}`.

### Pattern Matching with Variables

Event parameters can use `$variable` patterns to **capture** values. The
captured value becomes a local variable in the rule.

```lua
-- Post events with actual values
rule("kitchen.sensor.door:isOpen =>
  post(#doorEvent{door='kitchen', time=HM(now)})")

rule("bedroom.sensor.door:isOpen =>
  post(#doorEvent{door='bedroom', time=HM(now)})")

-- $room captures the door name — any value matches
rule([[#doorEvent{door='$room'} =>
  log('Door opened: %s at %s', room, time)
]])
-- If kitchen door opens: logs "Door opened: kitchen at 08:15"

-- Constraint patterns — match only when the condition is true
rule([[#temperatureAlert{temp='$t>30'} =>
  log('Extreme heat: %d°C', t)
]])
-- Only fires when temp > 30; t is bound to the actual value
```

Available constraint operators: `$var>value`, `$var<value`, `$var>=value`,
`$var<=value`, `$var==value`, `$var~=value`, `$var<>pattern` (string match).

**Try this:**
- Post `#testEvent{x=42}` and handle it with `#testEvent{x='$v'}` —
  verify `v` is `42`.
- Add a constraint: `#testEvent{x='$v>50'}` and verify it does NOT match
  when `x=42`.

### Cancelling Scheduled Events

You can cancel a scheduled event using the reference returned by `post()`.

```lua
-- Each motion resets the auto-off countdown
rule([[livingroom.sensor.motion:breached =>
  cancel(lightTimer);                            -- safe if nil or already expired
  lightTimer = post(#autoOff, +/00:10);          -- 10-minute countdown
  livingroom.light.ceiling:on
]])

rule([[#autoOff =>
  if !livingroom.sensor.motion:breached then
    livingroom.light.ceiling:off;
    log('Auto-turned off living room light')
  else
    log('Motion still detected, keeping light on')
  end
]])
```

### Complex Event Sequences

For multi-step automations, chain events together:

```lua
-- Multi-step bedtime sequence
rule("@23:00 => post(#bedtimeSequence{step='start'})")

rule([[#bedtimeSequence{step='start'} =>
  log('Starting bedtime routine...');
  livingroom.light.ceiling:off;
  post(#bedtimeSequence{step='bedroom'}, +/00:01)
]])

rule([[#bedtimeSequence{step='bedroom'} =>
  bedroom.light.bedside:on;
  wait(10);
  bedroom.light.ceiling:off;
  post(#bedtimeSequence{step='arm'}, +/00:02)
]])

rule([[#bedtimeSequence{step='arm'} =>
  log('Good night!')
  -- arm security system here
]])
```

**Try this:**
- Create a 3-step morning sequence: lights on → coffee maker on → log ready.
- Add a step that calls itself conditionally (loop with a counter).

---

## Trigger Variables

We introduced trigger variables in [Working with Variables](#working-with-variables).
Here's a more complete example:

```lua
local rule, var, triggerVar = er.eval, er.variables, er.triggerVariables

-- Define trigger variables
triggerVar.homeOccupied = false
triggerVar.guestMode = false

-- Rules that react to changes
rule("homeOccupied == true =>
  homeOccupied = false;
  log('Someone arrived home!')
")

rule("guestMode == true =>
  enable(guestLights);
  disable(normalRoutines);
  log('Guest mode activated')
")

-- Set them from device rules
rule("kitchen.sensor.motion:breached => homeOccupied = true")
rule("@sunset & wday('fri') => guestMode = true")
```

The key difference from regular `var`:
- Assigning to a trigger variable (`homeOccupied = true`) **fires any rule**
  that watches that variable name in its trigger expression.
- Assigning to a regular variable (`var.homeMode = "away"`) does not.

---

## Basic Functionality

### Working with Remotes

Remote controls emit `centralSceneEvent` signals when buttons are pressed:

```lua
-- Define your remote in the Home Table
local HT = {
  remotes = {
    bedroom = 123,   -- replace with your remote's device ID
    kitchen = 124
  },
  bedroom  = { light = { ceiling = 67 }, fan = 201 },
  kitchen  = { light = { ceiling = 54 } }
}
er.defvars(HT)

-- React to specific key presses
rule([[remotes.bedroom:key == '1:Pressed'  => bedroom.light.ceiling:on]])
rule([[remotes.bedroom:key == '1:Hold'     => bedroom.light.ceiling:off]])
rule([[remotes.bedroom:key == '2:Pressed2' => bedroom.fan:toggle]])  -- double-click
```

Key attributes: `'Pressed'`, `'Hold'`, `'Release'`, `'Pressed2'` (double-click),
`'Pressed3'` (triple-click).

### Working with Alarms

The HC3 alarm system uses partitions (numbered 0, 1, 2...). Partition `0`
is typically the whole house.

```lua
-- Query alarm state
rule([[@08:00 =>
  if 0:isArmed then
    log('House alarm is armed')
  else
    log('House alarm is disarmed')
  end
]])

-- Arm/disarm
rule("@23:00 => 0:tryArm")          -- Try to arm (handles breached devices)
rule("@07:00 => 0:armed = false")   -- Disarm

-- React to breaches
rule([[0:isAlarmBreached =>
  log('SECURITY ALERT: House alarm breached!');
  security.siren:on
]])
```

---

## Common Home Automation Patterns

### Morning Routine

```lua
rule("@07:00 & wday('mon-fri') =>
  kitchen.light.ceiling:on;
  kitchen.appliances.coffeeMaker:on;
  log('Good morning! Coffee is brewing')
")
```

### Security System

```lua
-- Motion during night hours
rule([[livingroom.sensor.motion:breached & 23:00..06:00 =>
  if !0:isArmed then
    livingroom.light.ceiling:on;
    post(#lightsOff, +/00:02)
  else
    log('SECURITY ALERT: Motion detected!')
  end
]])

rule("#lightsOff => livingroom.light.ceiling:off")
```

### Energy Saving

```lua
-- Turn off entertainment when no motion for 30 minutes
rule([[trueFor(00:30, !livingroom.sensor.motion:breached) =>
  livingroom.entertainment.tv:off;
  log('Entertainment turned off — no activity')
]])

-- Temperature-based fan control
rule("livingroom.sensor.temp:value > 25 => livingroom.fan:on")
rule("livingroom.sensor.temp:value < 22 => livingroom.fan:off")
```

### Vacation Mode

```lua
triggerVar.vacationMode = false

rule([[vacationMode == true =>
  log('Vacation mode activated');
  enable(vacationLights);
  disable(normalRoutines)
]])

-- Random lights in the evening
rule([[vacationMode & @{19:00,20:30,22:00} =>
  if rnd(1,10) > 5 then
    livingroom.light.ceiling:on;
    post(#vacationLightsOff, fmt('+00:%02d', rnd(30,90)))
  end
]])

rule("#vacationLightsOff => livingroom.light.ceiling:off")
```

### Weather-based Automation

```lua
-- Close blinds when hot and sunny
rule([[weather:temp > 28 & weather:condition == 'sunny' =>
  livingroom.blinds:close;
  log('Closing blinds — hot and sunny')
]])

-- Outdoor heater when cold
rule([[weather:temp < 5 & @{17:00,18:00,19:00} =>
  patio.heater:on;
  post(#heaterOff, +/02:00)
]])

rule("#heaterOff => patio.heater:off")
```

---

## Putting It All Together

Here's a complete, working `main()` function that ties together motion
lighting, time-based routines, and an auto-off pattern. Copy this, replace
the device IDs with your own, and deploy:

```lua
local function main(er)
  local rule, var, triggerVar = er.eval, er.variables, er.triggerVariables

  -- ── Logging: see rule triggers, conditions, and results ──────────────────
  er.opts = { started = true, check = true, triggers = true }

  -- ── Home Table — replace these IDs with your own! ────────────────────────
  local HT = {
    kitchen = {
      sensor = { motion = 77, door = 99 },
      light  = { ceiling = 54, underCabinet = 78 }
    },
    livingroom = {
      sensor = { motion = 88, lux = 89 },
      light  = { ceiling = 91, floorLamp = 92 }
    },
    bedroom = {
      sensor = { motion = 65 },
      light  = { ceiling = 67, bedside = 68 }
    }
  }
  er.defvars(HT)

  -- Convenience lists (Lua code — uses the local HT table)
  var.allLights = {
    HT.kitchen.light.ceiling, HT.kitchen.light.underCabinet,
    HT.livingroom.light.ceiling, HT.livingroom.light.floorLamp,
    HT.bedroom.light.ceiling, HT.bedroom.light.bedside
  }

  -- ── Motion → Light ──────────────────────────────────────────────────────
  -- Kitchen: motion turns on light, auto-off after 5 min of no motion
  rule([[kitchen.sensor.motion:breached =>
    cancel(kitchenTimer);
    kitchenTimer = post(#kitchenAutoOff, +/00:05);
    kitchen.light.ceiling:on
  ]])

  rule([[#kitchenAutoOff =>
    if !kitchen.sensor.motion:breached then
      kitchen.light.ceiling:off
    end
  ]])

  -- Living room: motion + low light
  rule([[livingroom.sensor.motion:breached & livingroom.sensor.lux:value < 100 =>
    livingroom.light.ceiling:on
  ]])

  rule([[trueFor(00:10, !livingroom.sensor.motion:breached) =>
    livingroom.light.ceiling:off;
    livingroom.light.floorLamp:off
  ]])

  -- ── Time-based routines ─────────────────────────────────────────────────
  -- Morning (weekdays)
  rule([[@{07:00,catch} & wday('mon-fri') =>
    kitchen.light.ceiling:on;
    log('Good morning!')
  ]])

  -- Evening (sunset)
  rule([[@{sunset,catch} =>
    livingroom.light.floorLamp:on;
    log('Good evening!')
  ]])

  -- Bedtime
  rule([[@{23:00,catch} =>
    post(#bedtime)
  ]])

  rule([[#bedtime =>
    bedroom.light.bedside:on;
    wait(10);
    bedroom.light.ceiling:off;
    livingroom.light:off;
    kitchen.light:off;
    log('Good night!')
  ]])

  -- ── Door alert ──────────────────────────────────────────────────────────
  rule([[kitchen.sensor.door:isOpen =>
    log.orange('Kitchen door opened at %s', HM(now))
  ]])

  -- ── Status check every hour ─────────────────────────────────────────────
  rule([[@@-01:00 =>
    log('── Status check ──');
    log('Kitchen motion: %s', kitchen.sensor.motion:breached and 'yes' or 'no');
    log('Living room lux: %d', livingroom.sensor.lux:value)
  ]])
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
```

This gives you:
- Motion-triggered lights that auto-off (kitchen, living room)
- Morning, sunset, and bedtime routines
- Door-open alerts
- Hourly status logging

Start here and add your own rules one at a time.

---

## Best Practices

1. **Use meaningful names** in your Home Table:
   ```lua
   -- Good
   local HT = { kitchen = { light = { ceiling = 54 } } }

   -- Avoid
   local HT = { k = { l = { c = 54 } } }
   ```

2. **Group related devices** in lists:
   ```lua
   var.allLights = {HT.kitchen.light.ceiling, HT.livingroom.light.ceiling}
   rule("@23:00 => allLights:off")
   ```

3. **Use time guards** to narrow when rules fire:
   ```lua
   rule("kitchen.sensor.motion:breached & 22:00..06:00 => bedroom.light.ceiling:on")
   ```

4. **Use day and month guards** with daily triggers:
   ```lua
   rule("@sunset+00:01 & wday('mon-fri') & month('june-oct') => livingroom.light.ceiling:on")
   ```

5. **Avoid false triggers** with `trueFor()`:
   ```lua
   rule("trueFor(00:05, !kitchen.sensor.motion:breached) => kitchen.light.ceiling:off")
   ```

6. **Kick-start rules with `.start()`** when the trigger state may already
   be true at startup:
   ```lua
   rule("kitchen.sensor.motion:breached => kitchen.light.ceiling:off").start()
   ```

7. **Structure complex logic** with custom events:
   ```lua
   rule("@23:00 => post(#bedtimeRoutine)")
   rule("#bedtimeRoutine => livingroom.light:off; wait(10); 0:tryArm")
   ```

8. **Turn on logging during development**, turn off in production:
   ```lua
   er.opts = { started = true, check = true, triggers = true }
   ```

---

## Troubleshooting

### Common Issues

1. **Rule not triggering — check your syntax:**
   ```lua
   -- Wrong
   rule("motion:breach => lights:on")  -- Should be "breached"

   -- Correct
   rule("kitchen.sensor.motion:breached => kitchen.light.ceiling:on")
   ```

2. **Device not responding — verify device IDs:**
   ```lua
   -- Test with a numeric ID first
   rule("kitchen.sensor.motion:breached => 54:on")
   ```

3. **Time rules not working — check time format:**
   ```lua
   -- Wrong
   rule("@8:00 => lights:on")  -- Should be "08:00"

   -- Correct
   rule("@08:00 => lights:on")
   ```

4. **"Expected 'identifier', got 'restart'" error:**
   You used a reserved keyword as a name. Use bracket syntax instead:
   ```lua
   -- Wrong: 'restart' is a reserved keyword
   -- plugin.restart()

   -- Correct:
   plugin["restart"]()
   ```
   See the [full list of reserved keywords](EventScript.md#reserved-keywords).

### Debugging Tips

1. **Add logging** to trace rule execution:
   ```lua
   rule("kitchen.sensor.motion:breached => log('Motion detected!'); kitchen.light.ceiling:on")
   ```
   Use `log.color(fmt, ...)` for coloured output — any CSS colour name works:
   ```lua
   rule("kitchen.sensor.door:isOpen => log.orange('Door opened at %s', HM(now))")
   rule("0:isAlarmBreached => log.red('ALERT: Security breach!')")
   ```

2. **Test incrementally** — start simple and build up:
   ```lua
   -- Step 1: test the trigger
   rule("kitchen.sensor.motion:breached => log('Motion works!')")

   -- Step 2: add the action
   rule("kitchen.sensor.motion:breached => log('Motion!'); kitchen.light.ceiling:on")
   ```

3. **Test with numeric IDs first**, then switch to Home Table names:
   ```lua
   -- Test with ID
   rule("77:breached => 54:on")

   -- Then use Home Table
   rule("kitchen.sensor.motion:breached => kitchen.light.ceiling:on")
   ```

4. **Enable verbose logging** to see when rules wait and resume:
   ```lua
   er.opts = { started = true, check = true, triggers = true, waiting = true, waited = true }
   ```

---

## Quick Reference: 10 Essential Patterns

Now that you understand the building blocks, here are the most common
patterns for quick reference:

```lua
-- 1) Daily time
rule("@08:00 => kitchen.light.ceiling:on")

-- 2) Multiple times
rule("@{07:00,19:00} => securityCheck()")

-- 3) Aligned interval (on the hour)
rule("@@-01:00 => log('Top of the hour')")

-- 4) Time-guarded device trigger
rule("kitchen.sensor.motion:breached & 22:00..06:00 => bedroom.light.ceiling:on")

-- 5) Device property trigger
rule("kitchen.sensor.door:isOpen => log('Door opened')")

-- 6) Threshold trigger
rule("livingroom.sensor.temp:value >= 26 => livingroom.fan:on")

-- 7) Stay-true condition (no motion for 10 min)
rule("trueFor(00:10, !kitchen.sensor.motion:breached) => kitchen.light.ceiling:off")

-- 8) Post event with delay
rule("@sunset => post(#evening, +/00:15)")

-- 9) List aggregation (average of sensors)
rule("allTemps:value:average > 25 => livingroom.fan:on")

-- 10) Offset relative to sunset
rule("@sunset-00:30 => livingroom.blinds:close")
```

---

## Glossary

- **Trigger:** The left side of a rule (`trigger => action`). A pure
  expression that, when true, causes the action to run. Examples:
  `@08:00`, `kitchen.sensor.motion:breached`,
  `livingroom.sensor.temp:value > 25`.

- **Action:** The right side of a rule. One or more statements that perform
  side effects (device control, assignment, logging). Separate multiple
  statements with `;`.

- **Guard:** A condition that narrows when a trigger can fire, typically
  combined with `&` (AND). Examples: `wday('mon-fri')`, `22:00..06:00`,
  `livingroom.sensor.lux:value < 100`.

- **Event:** A custom signal you can post and handle using `#name`. Post
  with `post(#name[, when])` and react with `rule("#name => ...")`.

- **Home Table (HT):** A Lua table that maps device IDs to meaningful
  names. Use `er.defvars(HT)` to make all names available in rules without
  any prefix.

- **Trigger variable:** A variable defined on `er.triggerVariables` —
  changing its value fires any rule that watches its name.

---

Congratulations! You now have the foundation to create powerful home
automation rules with EventScript. Start with simple rules and gradually
build more complex automations as you become comfortable with the language.

For detailed reference information, see the
[EventScript Language Documentation](EventScript.md).
