# EventScript Templates

A high-level parameterized template system for EventRunner7. Templates wrap
common home automation patterns into simple key-value configurations and
generate EventScript rules automatically. No coding required — just fill in
your device names and numbers.

## Table of Contents

- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [API Reference](#api-reference)
- [Template Reference](#template-reference)
  - [motionLight](#motionlight)
  - [thresholdControl](#thresholdcontrol)
  - [scheduledDevice](#scheduleddevice)
  - [openAlert](#openalert)
  - [scheduledScene](#scheduledscene)
  - [sunDevice](#sundevice)
  - [buttonScene](#buttonscene)
  - [autoOff](#autooff)
  - [vacationMode](#vacationmode)
  - [presenceSim](#presencesim)
  - [nightMode](#nightmode)
  - [morningRoutine](#morningroutine)
  - [groupToggle](#grouptoggle)
- [Device References](#device-references)
- [Writing Custom Templates](#writing-custom-templates)

## Quick Start

Templates are loaded automatically when you use EventRunner7 v0.1.36+.
Just call `er.template(...)` inside your `main(er)` function:

```lua
local function main(er)
  local rule, var = er.eval, er.variables

  -- Define your home
  var.HT = {
    kitchen = { motion = 77, light = 54 },
    livingroom = { motion = 88, light = 91, temp = 89, fan = 92 },
  }
  er.defvars(var.HT)

  -- Turn on kitchen light when motion detected, off after 5 minutes
  er.template("motionLight", {
    sensor = "kitchen.motion",
    light = "kitchen.light",
    offDelay = "00:05",
    timeGuard = "night",
  })

  -- Turn on fan if temperature exceeds 28°C, off below 22°C
  er.template("thresholdControl", {
    sensor = "livingroom.temp",
    actuator = "livingroom.fan",
    onAbove = 28,
    offBelow = 22,
    holdTime = "00:05",
  })

  -- Turn off all lights at 23:00 on weekdays
  er.template("scheduledDevice", {
    time = "23:00",
    days = "mon-thu",
    device = "allLights",
    action = "off",
  })
end
```

## How It Works

Each template is a pre-built pattern with named parameters. When you call
`er.template("name", {params...})`, it:

1. Validates your parameters
2. Builds an EventScript rule string (or multiple strings)
3. Registers them via `er.eval()` — same as writing `rule("...")`

The generated rules appear in the debug console with their triggers, just
like hand-written rules. You can inspect them by looking at the startup log.

Template rules can be combined with hand-written rules. Use templates for
the 90% of common patterns, and write EventScript directly for the remaining
10% of unique logic.

## API Reference

### er.template(name, params)

Generate and register rules from a single template. Returns the rule object
(or objects) from the underlying `er.eval()` call.

```lua
local r = er.template("motionLight", { sensor = "...", light = "..." })
r.verbosity = "verbose"  -- further configure the rule
```

### er.templates(list)

Batch-apply multiple templates at once. Each entry can use either form:

```lua
er.templates({
  { type = "motionLight", sensor = "kitchen.motion", light = "kitchen.light" },
  { "sunDevice", { event = "sunset", device = "outdoorLights", action = "on" } },
})
```

### er.templateList()

Returns a sorted list of all available template names.

```lua
for _, name in ipairs(er.templateList()) do
  print("Template:", name)
end
```

### er.templateDescribe(name)

Returns the schema for a template (description, required parameters, defaults).
Call without arguments to get all schemas.

```lua
local schema = er.templateDescribe("motionLight")
print(schema.description)
print("Required:", table.concat(schema.required, ", "))
```

## Template Reference

### motionLight

Turn on a light when motion is detected, with optional auto-off delay.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| sensor | device | yes | — | Motion sensor |
| light | device | yes | — | Light to control |
| offDelay | time | no | nil | Auto-off after delay (nil = stays on) |
| timeGuard | string | no | "always" | "always", "night", "day", or literal "HH:MM..HH:MM" |
| brightness | number | no | nil | Dim level 0-99 (nil = full on/off) |
| modifier | string | no | "none" | "none" or "single" |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Simple: motion → light on
er.template("motionLight", { sensor = "hallway.motion", light = "hallway.light" })

-- Night-only with auto-off and timer restart on re-trigger
er.template("motionLight", {
  sensor = "kitchen.motion",
  light = "kitchen.light",
  offDelay = "00:05",
  timeGuard = "night",
  modifier = "single",
})

-- Dim to 30% instead of full on
er.template("motionLight", {
  sensor = "bedroom.motion",
  light = "bedroom.light",
  brightness = 30,
  offDelay = "00:02",
})
```

**Generated rules:**

```
kitchen.motion:breached & sunset..sunrise single => kitchen.light:on; wait(00:05); kitchen.light:off
```

### thresholdControl

Turn a device on/off when a sensor crosses a threshold. Generates two rules:
one for the "on" threshold and one for the "off" threshold (hysteresis).

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| sensor | device | yes | — | Sensor device |
| actuator | device | yes | — | Device to control |
| onAbove | number | yes | — | Turn ON when sensor exceeds this value |
| offBelow | number | yes | — | Turn OFF when sensor drops below this value |
| property | string | no | "value" | Sensor property: "value", "temp", "lux", "humidity" |
| holdTime | time | no | nil | Condition must hold this long (since modifier) |
| cooldown | time | no | nil | Suppress re-triggering for this long |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Simple threshold: fan on above 28, off below 22
er.template("thresholdControl", {
  sensor = "livingroom.temp",
  actuator = "livingroom.fan",
  onAbove = 28,
  offBelow = 22,
})

-- With hysteresis: must hold for 5 minutes before acting
er.template("thresholdControl", {
  sensor = "livingroom.temp",
  actuator = "livingroom.fan",
  onAbove = 28,
  offBelow = 22,
  holdTime = "00:05",
  cooldown = "00:30",
})

-- Light sensor controlling blinds
er.template("thresholdControl", {
  sensor = "livingroom.lux",
  property = "lux",
  actuator = "livingroom.blinds",
  onAbove = 20000,   -- bright → close blinds
  offBelow = 5000,   -- dark → open blinds
})
```

**Generated rules:**

```
livingroom.temp:value > 28 since 00:05 cooldown 00:30 => livingroom.fan:on
livingroom.temp:value < 22 since 00:05 cooldown 00:30 => livingroom.fan:off
```

### scheduledDevice

Control a device at specific times.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| time | string | yes | — | Time or sun event: "08:00", "@sunset", "@sunrise-00:30" |
| device | device | yes | — | Device to control |
| action | string | yes | — | "on", "off", "toggle", or "value=N" |
| days | string | no | "always" | Day filter: "mon-fri", "weekdays", "weekends", or day pattern |
| catchup | boolean | no | false | Fire immediately on restart if time passed |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Turn off all lights at midnight every day
er.template("scheduledDevice", {
  time = "00:00",
  device = "allLights",
  action = "off",
})

-- Weekday wake-up: set light to 80% at 07:00
er.template("scheduledDevice", {
  time = "07:00",
  days = "mon-fri",
  device = "bedroom.light",
  action = "value=80",
  catchup = true,
})

-- Turn on outdoor lights at sunset
er.template("scheduledDevice", {
  time = "@sunset",
  device = "outdoorLights",
  action = "on",
})
```

**Generated rules:**

```
@07:00 & wday('mon-fri') => bedroom.light:value = 80
@{00:00,catch} => allLights:off
```

### openAlert

Alert when a door/window stays open longer than a timeout.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| sensor | device | yes | — | Door/window sensor |
| timeout | time | yes | — | How long open before alert |
| property | string | no | "breached" | Sensor property |
| message | string | no | auto | Custom log message |
| repeatAlert | boolean | no | false | Repeat alert periodically |
| repeatMax | number | no | 10 | Max repeats (with repeatAlert) |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Alert if front door stays open for 5 minutes
er.template("openAlert", {
  sensor = "front.door",
  timeout = "00:05",
})

-- Custom message with repeat every 5 min, up to 5 times
er.template("openAlert", {
  sensor = "garage.door",
  timeout = "00:10",
  message = "Garage door still open!",
  repeatAlert = true,
  repeatMax = 5,
})
```

**Generated rules:**

```
trueFor(00:05,front.door:breached) => log('front.door open for 00:05')
```

### scheduledScene

Activate or deactivate a named scene at scheduled times.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| scene | string | yes | — | Scene name |
| time | string | yes | — | Time or sun event |
| action | string | no | "activate" | "activate" or "deactivate" |
| days | string | no | "always" | Day filter |
| catchup | boolean | no | false | Fire immediately on restart |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Activate morning scene at 07:00 on weekdays
er.template("scheduledScene", {
  scene = "morningLights",
  time = "07:00",
  days = "mon-fri",
})

-- Deactivate movie mode at midnight
er.template("scheduledScene", {
  scene = "movieMode",
  time = "00:00",
  action = "deactivate",
})
```

**Generated rules:**

```
@07:00 & wday('mon-fri') => morningLights:activate
```

### sunDevice

Control a device relative to sunrise, sunset, dawn, or dusk.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| event | string | yes | — | "sunset", "sunrise", "dawn", or "dusk" |
| device | device | yes | — | Device to control |
| action | string | yes | — | "on", "off", "toggle", or "value=N" |
| offset | time | no | nil | Offset from event: "-00:30" or "+01:00" |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Turn on outdoor lights at sunset
er.template("sunDevice", {
  event = "sunset",
  device = "outdoorLights",
  action = "on",
})

-- Close blinds 30 minutes before sunset
er.template("sunDevice", {
  event = "sunset",
  offset = "-00:30",
  device = "livingroom.blinds",
  action = "value=0",
})

-- Open blinds at sunrise
er.template("sunDevice", {
  event = "sunrise",
  device = "bedroom.blinds",
  action = "value=100",
})
```

**Generated rules:**

```
@sunset-00:30 => livingroom.blinds:value = 0
```

### buttonScene

Map a button press or remote key to a scene activation.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| button | device | yes | — | Button/remote device |
| trigger | string | yes | — | "single", "double", "triple", "hold", "keyId=N", or raw "scene==S1.double" |
| scene | string | yes | — | Scene name |
| action | string | no | "activate" | "activate" or "deactivate" |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Single click on remote → activate goodnight scene
er.template("buttonScene", {
  button = "bedroom.remote",
  trigger = "single",
  scene = "goodnight",
})

-- Key 2 on remote → deactivate all-lights scene
er.template("buttonScene", {
  button = "livingroom.remote",
  trigger = "keyId=2",
  scene = "allLights",
  action = "deactivate",
})

-- Double click → movie mode
er.template("buttonScene", {
  button = "livingroom.switch",
  trigger = "double",
  scene = "movieMode",
})
```

**Generated rules:**

```
bedroom.remote:scene == S1.single => goodnight:activate
livingroom.remote:central.keyId == 2 => allLights:deactivate
```

### autoOff

When a trigger fires, turn on a device and auto-off after a delay.
The timer restarts on re-trigger when using the `single` modifier (default).

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| trigger | string | yes | — | EventScript trigger expression |
| device | device | yes | — | Device to control |
| delay | time | yes | — | Auto-off delay |
| onAction | string | no | "on" | What to turn on: "on" or "value=N" |
| modifier | string | no | "single" | "single" or "none" |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Motion triggers light, off after 5 min, timer restarts on new motion
er.template("autoOff", {
  trigger = "hallway.motion:breached",
  device = "hallway.light",
  delay = "00:05",
})

-- Button press → fan on for 30 minutes
er.template("autoOff", {
  trigger = "bathroom.button:scene == S1.single",
  device = "bathroom.fan",
  delay = "00:30",
  modifier = "none",  -- don't restart timer
})

-- Motion → dim to 50%
er.template("autoOff", {
  trigger = "bedroom.motion:breached & 22:00..06:00",
  device = "bedroom.light",
  delay = "00:02",
  onAction = "value=50",
})
```

**Generated rules:**

```
hallway.motion:breached single => hallway.light:on; wait(00:05); hallway.light:off
```

### vacationMode

Disable/enable rule groups based on a Fibaro global variable.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| variable | string | yes | — | Global variable name (with or without $ prefix) |
| groups | string or list | yes | — | Group name(s) to disable/enable |
| invert | boolean | no | false | Disable when false instead of true |
| group | string | no | nil | Rule group for these meta-rules |

**Examples:**

```lua
-- Disable lighting and climate groups when $Vacation is true
er.template("vacationMode", {
  variable = "$Vacation",
  groups = { "lighting", "climate" },
})

-- Disable bedroom rules when $NightMode is true
er.template("vacationMode", {
  variable = "NightMode",  -- $ prefix added automatically
  groups = "bedroom",
})
```

**Generated rules:**

```
$Vacation == true => disable('lighting'); disable('climate')
$Vacation == false => enable('lighting'); enable('climate')
$Vacation ~= true => enable('lighting'); enable('climate')  -- runs at startup
```

### presenceSim

Simulate presence by randomly toggling lights within a time window.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| lights | device or list | yes | — | Lights to toggle |
| startTime | time | no | "sunset-00:30" | When simulation starts |
| endTime | time | no | "23:00" | When simulation ends |
| activeDays | string | no | "all" | Days to run |
| interval | time | no | "00:30" | How often to toggle |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Toggle random lights every 30 min between sunset-30min and 23:00
er.template("presenceSim", {
  lights = { "livingroom.light", "bedroom.light", "kitchen.light" },
})

-- Evening-only weekdays, toggle every 20 min
er.template("presenceSim", {
  lights = { "livingroom.light", "hallway.light" },
  startTime = "18:00",
  endTime = "22:00",
  activeDays = "mon-fri",
  interval = "00:20",
})
```

**Generated rules:**

```
@sunset-00:30 & wday('mon-fri') => post(#_presenceSimTick)
#_presenceSimTick => local pick = {livingroom.light,hallway.light}[rnd(1,#{livingroom.light,hallway.light})]; pick:toggle; if 18:00..22:00 then post(#_presenceSimTick,+/00:20) end
@22:00 & wday('mon-fri') => {livingroom.light,hallway.light}:off
```

### nightMode

Set house to night state at a scheduled time: turn off lights, arm security,
set thermostat. At least one of `lights`, `security`, or `thermostat` must be
specified.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| time | string | yes | — | When to activate (e.g. "23:00") |
| lights | device or list | no | nil | Lights to turn off |
| security | number or true | no | nil | Partition ID to arm (true = all) |
| thermostat | table | no | nil | `{ device = ref, setpoint = N }` |
| days | string | no | "always" | Day filter |
| catchup | boolean | no | false | Catch missed fires |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Turn off lights and arm security at 23:00 on weekdays
er.template("nightMode", {
  time = "23:00",
  days = "mon-thu",
  lights = "allLights",
  security = true,
})

-- Set thermostat to 18°C and turn off living room lights at midnight
er.template("nightMode", {
  time = "00:00",
  lights = "livingroom.light",
  thermostat = { device = "livingroom.thermostat", setpoint = 18 },
})
```

**Generated rules:**

```
@23:00 & wday('mon-thu') => allLights:off; 0:arm
```

### morningRoutine

Wake-up routine: turn on lights, disarm security, set thermostat.
At least one of `lights`, `security`, or `thermostat` must be specified.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| time | string | yes | — | When to activate (e.g. "07:00") |
| lights | device or list | no | nil | Lights to turn on |
| brightness | number | no | 100 | Dim level for lights |
| security | number or true | no | nil | Partition ID to disarm (true = all) |
| thermostat | table | no | nil | `{ device = ref, setpoint = N }` |
| days | string | no | "always" | Day filter |
| catchup | boolean | no | false | Catch missed fires |
| group | string | no | nil | Rule group name |

**Examples:**

```lua
-- Weekday morning: lights at 80%, disarm security, thermostat to 21°C
er.template("morningRoutine", {
  time = "07:00",
  days = "mon-fri",
  lights = "bedroom.light",
  brightness = 80,
  security = true,
  thermostat = { device = "livingroom.thermostat", setpoint = 21 },
})
```

**Generated rules:**

```
@07:00 & wday('mon-fri') => bedroom.light:value = 80; 0:disarm; livingroom.thermostat:setpoint = 21
```

### groupToggle

Enable or disable a rule group based on a trigger condition. Simpler than
vacationMode when you just want one trigger → one group toggle.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| trigger | string | yes | — | EventScript trigger expression |
| group | string | yes | — | Group name |
| action | string | yes | — | "enable" or "disable" |
| target | string or number | no | nil | Specific rule within group (nil = whole group) |

**Examples:**

```lua
-- Disable bedroom rules when sleep button pressed
er.template("groupToggle", {
  trigger = "sleepButton:scene == S1.single",
  group = "bedroom",
  action = "disable",
})

-- Re-enable when wake button pressed
er.template("groupToggle", {
  trigger = "wakeButton:scene == S1.single",
  group = "bedroom",
  action = "enable",
})
```

## Device References

Templates accept device references in three forms:

| Form | Example | Meaning |
|------|---------|---------|
| Number | `77` | Raw Fibaro device ID |
| String | `"kitchen.motion"` | HomeTable path (must be defined via `er.defvars`) |
| String | `"allLights"` | Variable name pointing to a device or list |
| Table | `{66, 67, 68}` | List of device IDs |
| Table | `{"kitchen.light", "livingroom.light"}` | List of device names |

Use the HomeTable pattern for readable rule generation:

```lua
var.HT = {
  kitchen = { motion = 77, light = 54 },
}
er.defvars(var.HT)

er.template("motionLight", {
  sensor = "kitchen.motion",  -- resolves to 77
  light = "kitchen.light",    -- resolves to 54
})
```

## Writing Custom Templates

You can register your own templates with `Templates.register()`.
Do this before calling `er.template()` — typically at the top of `main(er)`:

```lua
local function main(er)
  local Templates = require("Templates")  -- or access via module namespace

  Templates.register("myCustomTemplate", {
    description = "Does something custom",
    required = { "device", "threshold" },
    defaults = { delay = "00:01", group = nil },
  }, function(er, params)
    -- params.device is guaranteed to exist; params.delay defaults to "00:01"
    local ruleStr = string.format("%s:value > %d => log('Threshold exceeded')",
      params.device, params.threshold)
    local opts = {}
    if params.group then opts.group = params.group end
    return er.eval(ruleStr, opts)
  end)

  -- Now use it
  er.template("myCustomTemplate", { device = "kitchen.temp", threshold = 30 })
end
```

The `generate` function receives the `er` instance and validated parameters.
It should call `er.eval()` and return the rule object(s).

---

*Generated rules appear in the debug console at startup with their triggers.
Set `er.opts.triggers = true` to see what each template generates.*
