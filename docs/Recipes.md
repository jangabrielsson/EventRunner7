# Home Automation Recipes

## Table of Contents

- [Home Automation Recipes](#home-automation-recipes)
  - [Table of Contents](#table-of-contents)
  - [Light triggering](#light-triggering)
    - [Turn on lights when motion is detected between sunset and sunrise](#turn-on-lights-when-motion-is-detected-between-sunset-and-sunrise)
    - [Turn on lights when motion is detected and fibaro global variable 'Vacation' is not true](#turn-on-lights-when-motion-is-detected-and-fibaro-global-variable-vacation-is-not-true)
    - [Turn on lights when scene activation event from switch](#turn-on-lights-when-scene-activation-event-from-switch)
    - [Turn on lights when key 2 is pressed on remote control](#turn-on-lights-when-key-2-is-pressed-on-remote-control)
  - [Scheduling](#scheduling)
    - [Set a global variable with day state](#set-a-global-variable-with-day-state)
    - [Turn off all lights at midnight](#turn-off-all-lights-at-midnight)
    - [Turn off all lights at 23 on weekdays and midnight on weekends](#turn-off-all-lights-at-23-on-weekdays-and-midnight-on-weekends)
    - [Turn off lights on Earth Hour](#turn-off-lights-on-earth-hour)
    - [Restart EventRunner at Daylight Time Savings](#restart-eventrunner-at-daylight-time-savings)
  - [Security routines](#security-routines)
    - [Arm security system at night](#arm-security-system-at-night)
    - [Disarm security system in the morning](#disarm-security-system-in-the-morning)
  - [Climate control](#climate-control)
    - [Turn on fan if temperature is high](#turn-on-fan-if-temperature-is-high)
    - [Turn on fan if temperature is high for more than 5 min, and off when low for 5min](#turn-on-fan-if-temperature-is-high-for-more-than-5-min-and-off-when-low-for-5min)
  - [Notification examples](#notification-examples)
    - [Send notification if door is left open for more than 5 minutes](#send-notification-if-door-is-left-open-for-more-than-5-minutes)
    - [Notification on last Monday in week](#notification-on-last-monday-in-week)
  - [Rule modifiers](#rule-modifiers)
    - [Extend a motion light with single](#extend-a-motion-light-with-single)
    - [Ignore rapid re-triggers with debounce](#ignore-rapid-re-triggers-with-debounce)
    - [Condition must hold for N seconds (since)](#condition-must-hold-for-n-seconds-since)
    - [Suppress repeat notifications with cooldown](#suppress-repeat-notifications-with-cooldown)
    - [Act only on every Nth trigger](#act-only-on-every-nth-trigger)
  - [Named scenes](#named-scenes)
    - [Simple activate-only scene](#simple-activate-only-scene)
    - [Scene with activate and deactivate](#scene-with-activate-and-deactivate)
    - [Triggering scenes from rules](#triggering-scenes-from-rules)
  - [Rule groups](#rule-groups)
    - [Group bedroom rules and toggle as a unit](#group-bedroom-rules-and-toggle-as-a-unit)
    - [Vacation mode: disable non-essential rules](#vacation-mode-disable-non-essential-rules)

## Light triggering

### Turn on lights when motion is detected between sunset and sunrise

```lua
rule([[motion:breached & sunset..sunrise =>
  hallwayLight:on;
  log('Hallway light turned on due to motion')
]])
```

### Turn on lights when motion is detected and fibaro global variable 'Vacation' is not true

```lua
rule([[motion:breached & !$Vacation =>
  hallwayLight:on;
  log('Hallway light turned on due to motion')
]])
```

### Turn on lights when scene activation event from switch

```lua
rule([[switch:scene == S1.double => -- double click
  hallwayLight:on;
  log('Double click switch, Hallway light turned on')
]])
```

### Turn on lights when key 2 is pressed on remote control

```lua
rule([[remote:central.keyId == 2 =>
  hallwayLight:on;
  log('Remote key 2, Hallway light turned on')
]])
```


## Scheduling

### Set a global variable with day state

```lua
rule("@00:00 => weekDay = wday('mon-fri')").start()
rule("@00:00 => weekEnd = wday('sat-sun')").start()

rule("weekDay & 07:00..07:30 => $HomeState='WakeUp'").start()
rule("weekDay & 07:30..11:00 => $HomeState='Morning'").start()
rule("weekDay & 11:00..13:00 => $HomeState='Lunch'").start()
rule("weekDay & 13:00..18:30 => $HomeState='Afternoon')").start()
rule("weekDay & 18:30..20:00 => $HomeState='Dinner'").start()
rule("weekDay & 20:00..23:00 => $HomeState='Evening'").start()
rule("weekDay & 23:00..07:00 => $HomeState='Night'").start()

rule("weekEnd & 08:00..09:00 => $HomeState='WakeUp'").start()
rule("weekEnd & 09:00..12:00 => $HomeState='Morning'").start()
rule("weekEnd & 12:00..14:00 => $HomeState='Lunch'").start()
rule("weekEnd & 14:00..19:00 => $HomeState='Afternoon'").start()
rule("weekEnd & 19:00..20:00 => $HomeState='Dinner'").start()
rule("weekEnd & 20:00..24:00 => $HomeState='Evening'").start()
rule("weekEnd & 24:00..08:00 => $HomeState='Night'").start()

rule("@dawn+00:15 => $isDark=false")
rule("@dusk-00:15 => $isDark=true")
```
The 07:00..07:30 rule will trigger at 07:00 and 07:00:01 and check the condition. If the current time is between (inclusive) 07:00..07:30 we will set the global variable 'HomeState' to 'Wakeup'. The .start() added to the rule makes it run at startup, setting the variable correctly if it's between the times specified. Why the rule triggers on 07:00:01 is a technicality, needed if we negate the test, and usually nothing to be concerned of as it normally will be false anyway.

WIth these variables a rule to turn on light if dark wakeup could be
```lua
rule("$HomeState=='WakeUp' & isDark => bedroomLight:on")
```

### Turn off all lights at midnight

```lua
rule([[@00:00 =>
  allLights:off;
  log('All lights turned off at midnight')
]])
```

### Turn off all lights at 23 on weekdays and midnight on weekends

```lua
rule([[@23:00 & wday('mon-thu') =>
  allLights:off;
  log('All lights turned off at 23:00')
]])

rule([[@00:00 & wday('fri-sun') =>
  allLights:off;
  log('All lights turned off at midnight')
]])
```

### Turn off lights on Earth Hour

Rules without `=>` run their expression once at startup as a fire-and-forget statement:

```lua
rule("earthLight = {kitchen.lamp, bedroom.lamp}")
rule("log('Earth light IDs: %s',json.encodeFast(earthLight))")
rule("earthLight:on")

rule([[earthDates={
    2025/03/29/20:30,
    2026/03/28/20:30,
    2027/03/27/20:30
}]])

rule([[for _,t in ipairs(earthDates) do 
      if t > os.time() then
        print('Earth hour date:',os.date('%c',t));
        post(#earthHour,t)
      end
    end
]])

rule([[#earthHour =>
  local state = {};
  log('Earth hour started');
  for _,id in ipairs(earthLight) do state[id] = id:value end;
  earthLight:off;
  wait(01:00);
  log('Earth hour ended');
  for id,val in pairs(state) do id:value=val end
]])
```

### Restart EventRunner at Daylight Time Savings

```lua
rule("post(#restart,nextDST())")     -- post event at next daylight savings time
rule("#restart => plugin.restart()") -- Restart QA when DST hour jumps.
```
This because rules like
```lua
rule("@15:00 => ...")
```
will be off an hour at DST day. The reason is that the time is calculated every midnight, and this is calculated as 15*3600 seconds after midnight. But at DST the real 15:00 jumps an hour forward or backward. It actually goes for all setTimeout set by the system, if the delay is calculated to run on an absolute time.
So, the simplest approach is to just restart the QA at DST. All rules start up again and all timers are set with the new right time...

## Security routines

### Arm security system at night

```lua
rule([[@23:00 =>
  securitySystem:arm;
  log('Security system armed for the night')
]])
```

### Disarm security system in the morning

```lua
rule([[@06:00 =>
  securitySystem:disarm;
  log('Security system disarmed for the day')
]])
```

## Climate control

### Turn on fan if temperature is high

```lua
rule([[temp:value > 28 =>
  fan:on;
  log('Fan turned on due to high temperature')
]])
```

### Turn on fan if temperature is high for more than 5 min, and off when low for 5min

```lua
rule([[trueFor(00:05,temp:value > 28) =>
  fan:on;
  log('Fan turned on due to high temperature')
]])

rule([[trueFor(00:05,temp:value < 20) =>
  fan:off;
  log('Fan turned off due to low temperature')
]])
```

The same logic written with the `since` modifier (cleaner syntax, identical behaviour):

```lua
rule("temp:value > 28 since 00:05 => fan:on")
rule("temp:value < 20 since 00:05 => fan:off")
```

## Notification examples

### Send notification if door is left open for more than 5 minutes

```lua
rule("user = 456") -- Id of user that should be pushed to
rule([[trueFor(00:05,door:open) =>
  user:msg = log('Door open for %s minutes', 5*again(10))
]])
-- again(10) lets the trueFor re-arm and fire up to 10 more times (every 5 min),
-- so the log text counts up: 5, 10, 15 ... minutes. Remove again() to fire only once.
```

### Notification on last Monday in week

```lua
rule([[@18:00 & day('lastw-last') & wday('mon') =>
  user:msg = log('Last Monday in week, put out the trash')
]])
```

---

## Rule modifiers

Modifiers are placed between the condition and `=>` and adjust *when* and *how* the action fires.

### Extend a motion light with single

Without `single`, a second motion event arrives while the light-off wait is already pending — the new run is blocked by the ongoing wait. With `single`, the pending wait is cancelled and the timer restarts from zero:

```lua
rule([[motion:breached single =>
  hallwayLight:on;
  wait(00:05);
  hallwayLight:off
]])
```

Every new motion event extends the on-period by another 5 minutes.

### Ignore rapid re-triggers with debounce

`debounce T` waits for T seconds of silence before running the action (implies `single`). Useful for sensors that fire multiple events in quick succession:

```lua
-- Door bell: wait for 3 s of silence before notifying
rule("doorBell:breached debounce 00:03 => user:msg='Door bell!'")

-- Motion: only act after motion stops arriving for 10 s
rule([[motion:breached debounce 00:10 =>
  log('Motion settled, starting timer');
  wait(00:05);
  hallwayLight:off
]])
```

### Condition must hold for N seconds (since)

`since T` is a short form of `trueFor(T, condition)`. The action only runs after the condition has been continuously true for T:

```lua
rule("temp:value > 28 since 00:05 => fan:on")
rule("temp:value < 20 since 00:05 => fan:off")

-- Alert if flood sensor stays triggered for more than 30 s (avoids false positives)
rule("flood:breached since 00:00:30 => user:msg='Flood detected!'")
```

### Suppress repeat notifications with cooldown

`cooldown T` prevents the action from firing again within T seconds of the last run:

```lua
-- At most one push per hour even if the door keeps opening and closing
rule("door:open cooldown 01:00 => user:msg='Front door opened'")

-- Temperature alert at most once every 30 minutes
rule("temp:value > 30 cooldown 00:30 => user:msg='High temperature!'")
```

### Act only on every Nth trigger

`every N` runs the action only on every Nth evaluation of the condition:

```lua
-- Log only every 5th motion event (reduce noise)
rule("motion:breached every 5 => log('Motion event #5 reached')")

-- Reminder sent on 3rd consecutive door opening
rule("door:open every 3 => user:msg='Door opened 3 times'")
```

---

## Named scenes

A **scene** groups a set of device property assignments under a name. It can be activated (and optionally deactivated) as a single unit.

### Simple activate-only scene

```lua
-- Define the scene (runs once at startup as a statement)
rule([[scene morningLights = {
  kitchenLight:value  = 80,
  hallwayLight:value  = 60,
  bedroomLight:value  = 20
}]])

-- Activate it from a rule
rule("@07:00 & wday('mon-fri') => morningLights:activate")
```

### Scene with activate and deactivate

Use the long form with `activate:` and `deactivate:` blocks when you need to restore state:

```lua
rule([[scene movieMode = {
  activate: {
    livingRoomLight:value = 15,
    tvBacklight:on,
    blinds:value          = 0
  },
  deactivate: {
    livingRoomLight:value = 80,
    tvBacklight:off,
    blinds:value          = 100
  }
}]])

rule("tvRemote:scene == S1.single => movieMode:activate")
rule("tvRemote:scene == S1.double => movieMode:deactivate")
```

### Triggering scenes from rules

Scenes are ordinary named values — you can pass them as variables, store them in a table, or select between them at runtime:

```lua
rule("scene day   = { livingRoomLight:value = 80, hallwayLight:on }")
rule("scene night = { livingRoomLight:value = 20, hallwayLight:off }")

-- Select scene based on time of day
rule([[activeScene = day]])  -- set Lua variable at startup
rule([[sunset:breached  => activeScene = night; activeScene:activate]])
rule([[sunrise:breached => activeScene = day;   activeScene:activate]])
```

---

## Rule groups

Tag rules at registration time with `{group="name"}` and enable or disable the whole group from a single rule action.

### Group bedroom rules and toggle as a unit

```lua
rule("motion:breached sunset..sunrise => bedroomLight:on",  {group="bedroom"})
rule("motion:safe   since 00:05       => bedroomLight:off", {group="bedroom"})
rule("@23:30                          => bedroomLight:off", {group="bedroom"})

-- Sleep button disables all bedroom automation for the night
rule("sleepButton:scene == S1.single => disable('bedroom')")
-- Wake button re-enables it
rule("alarmButton:scene == S1.single => enable('bedroom')")
```

### Vacation mode: disable non-essential rules

```lua
-- Assign rules to groups
rule("motion:breached sunset..sunrise => hallwayLight:on", {group="lighting"})
rule("motion:safe   since 00:05       => hallwayLight:off", {group="lighting"})
rule("temp:value > 28 since 00:05 => fan:on",  {group="climate"})
rule("temp:value < 20 since 00:05 => fan:off", {group="climate"})

-- Toggle via a global variable
rule([[$Vacation == true =>
  disable('lighting');
  disable('climate');
  log('Vacation mode: non-essential rules disabled')
]])
rule([[$Vacation == false =>
  enable('lighting');
  enable('climate');
  log('Vacation mode off: rules re-enabled')
]])
```
