# EventRunner7

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.1.7-blue.svg)](.version)

<a href="https://www.buymeacoffee.com/rywnwpdvvni" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

EventRunner7 is a powerful rule-based automation framework for Fibaro Home Center 3 (HC3). It provides an expressive domain-specific language (**EventScript**) for writing complex automation rules with advanced event handling, scheduling, rule modifiers, and named scenes.

> Successor to [EventRunner6](https://github.com/jangabrielsson/EventRunner6) — fully backward-compatible rule syntax with new features.

---

## Features

- **Intuitive Rule Syntax** — write rules as `condition => action` one-liners or multi-line blocks
- **Rich Trigger System** — time (`@HH:MM`), interval (`@@HH:MM`), device properties, global variables, custom events (`#name`)
- **Rule Modifiers** — `restart`, `since`, `debounce`, `cooldown`, `every` for precise firing control
- **Rule Groups** — tag rules with `{group="name"}` and enable/disable the whole group at once
- **Rule Groups** — tag rules with `{group="name"}` and enable/disable the whole group at once
- **Async Actions** — `wait(ms)` suspends mid-action without blocking other rules
- **Event Scheduling** — post events with relative (`+/HH:MM`) or absolute (`n/HH:MM`) times
- **Device Collections** — apply actions to lists of devices; aggregate with `:average`, `:someTrue`, etc.
- **Custom Property Classes** — wrap any data source (API, sensor, service) as a first-class `obj:prop`
- **Comprehensive Logging** — configurable per-rule verbosity flags and custom log functions
- **Local Development** — run and debug offline with [plua](https://pypi.org/project/plua/)

---

## Quick Start

### Installation

1. Download `dist/EventRunner7.fqa` from this repository
2. Import the `.fqa` file into your Fibaro HC3
3. Place the QuickApp in your desired room
4. Edit the `main` function to add your rules

### Minimal QuickApp

```lua
--%%name:EventRunner7
--%%type:com.fibaro.deviceController

local function main(er)
  local rule, var = er.eval, er.variables
  er.opts = { started = true, check = true, triggers = true }

  var.HT = {
    kitchen = { light = 54, motion = 77 },
    living  = { light = 60 },
  }

  rule("HT.kitchen.motion:breached => HT.kitchen.light:on")
  rule("@sunset => HT.living.light:on")
  rule("@@00:05 => log('heartbeat')", {check=false})
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
```

---

## Rule Syntax

### Basic Structure

```
condition [modifier...] => action
```

Rules are registered with `rule(str)` (alias for `er.eval`). Each registration returns a rule object and logs its trigger list at startup.

### Time Triggers

```lua
rule("@08:00 => log('Good morning!')")           -- exact time
rule("@{07:00,19:00} => securityCheck()")        -- multiple times
rule("@sunset => outdoorLights:on")              -- sun events
rule("@sunrise-00:30 => blinds:open")            -- offset from sun
rule("@{08:00,catch} => morningLight:on")        -- catch missed fires on restart
rule("@@00:05 => temperatureCheck()")            -- every 5 minutes
rule("@@-01:00 => log('top of the hour')")       -- clock-aligned interval
```

### Device Triggers

```lua
rule("motionSensor:breached => hallLight:on")
rule("frontDoor:isOpen => log('Door opened!')")
rule("tempSensor:value > 25 => fan:on")
rule("{door1,door2,window1}:breached => alert()")
rule("sensors:value:average > 25 => hvac:on")   -- list aggregate
```

### Time Guards

```lua
rule("motion:breached & 22:00..06:00 => nightLight:on")
rule("@07:30 & wday('mon-fri') => log('Weekday morning')")
rule("trueFor(00:10, !motion:breached) => light:off")
```

### Rule Modifiers

Modifiers go between the condition and `=>`:

| Modifier | Effect |
|----------|--------|
| `restart` | Cancel current run and restart if condition re-fires |
| `since T` | Condition must stay true for T seconds first (alias for `trueFor`) |
| `debounce T` | Wait T s of silence; reset timer on each re-fire (implies `restart`) |
| `cooldown T` | Suppress re-triggering for T s after action completes |
| `every N` | Fire only on every N-th true evaluation |

```lua
rule("doorbell:pressed restart => wait(500); chime:play")
rule("motion:breached since 00:02 => alarm:on")
rule("keypress debounce 0.5 => searchAPI(query)")
rule("motion:breached cooldown 00:05 => notify('Motion!')")
rule("sensor:value every 4 => log('val: %d', sensor:value)")

-- Modifiers compose:
rule("button:pressed restart cooldown 2 => wait(100); light:toggle")
```

### Custom Events

```lua
rule("@sunset => post(#eveningRoutine)")
rule("#eveningRoutine => outdoorLights:on; securitySystem:arm")

-- With parameters and pattern matching:
rule("temp:value > 25 => post(#alert{level='high'})")
rule("#alert{level='high'} => fan:on")
rule("#alert{level='$lvl'} => log('Alert level: %s', lvl)")

-- Scheduled events:
rule("motion:breached => post(#autoOff, +/00:05)")   -- 5 min later
rule("@08:00 => post(#cleanup, n/10:00)")             -- next 10:00
```

### Rule Groups

Tag rules with a group name and control them collectively:

```lua
rule("motion:breached => light:on",  {group="bedroom"})
rule("@23:00 => light:off",          {group="bedroom"})

-- Disable/enable an entire group from another rule:
rule("sleepButton:pressed => disable('bedroom')")
rule("wakeButton:pressed  => enable('bedroom')")

-- Also accepts a rule object or numeric id:
rule("button:pressed => disable(r)")
```

### Named Scenes

Group device property assignments under a name and activate/deactivate as a unit:

```lua
-- Short form: activate-only
scene cozy = { lamp1:value=80, lamp2:level=40, blind:position=50 }

-- Long form: separate activate + deactivate bodies
scene movienight = {
  activate:   { projector:on, lights:value=10, blind:position=0 },
  deactivate: { projector:off, lights:value=100, blind:position=100 }
}

rule("@sunset => cozy:activate")
rule("button:pressed => movienight:activate")
rule("@midnight => movienight:deactivate")
```

Non-literal values in scene entries are **re-evaluated at activation time**:

```lua
scene dynscene = {
  activate:   { dimmer:value=targetLevel },   -- reads targetLevel when activated
  deactivate: { dimmer:value=0 }
}
```

### Async Actions

```lua
rule([[motion:breached =>
  hallLight:on;
  wait(300000);             -- suspend 5 minutes; other rules keep running
  if !motion:breached then hallLight:off end
]])
```

### Variables

```lua
er.variables.threshold = 25
er.variables.HT = { kitchen = { light = 54, motion = 77 } }

rule("tempSensor:value > threshold => fan:on")
rule("@sunset => HT.kitchen.light:on")
```

Trigger variables fire rules when written to:

```lua
er.triggerVariables.homeOccupied = false
rule("homeOccupied == true => log('Someone home!')")
rule("@sunset => homeOccupied = true")
```

---

## Logging & Verbosity

```lua
er.opts = {
  defined  = true,    -- ✅ log rule defined on registration
  triggers = true,    -- ⚡ list triggers when rule is defined
  check    = true,    -- 👍/👎 log condition result on each firing
  started  = false,   -- 🎬 log when a rule fires (trigger + env)
  result   = false,   -- 📋 log action return value
  waiting  = false,   -- 💤 log when wait() suspends
  waited   = false,   -- ⏰ log when wait() resumes
}

-- Per-rule override:
rule("@sunset => lamp:on", {check=false})

-- Custom log function:
er.opts.check = function(rule, env, ok)
  if ok then print(string.format("✓ %s fired", rule)) end
end
```

---

## Project Structure

```
EventRunner7.lua          # Main QuickApp entry point
EventRunner.inc           # QuickApp header file (included via --%%headers)
Setup.lua                 # Engine initialisation and boot
Rule.lua                  # Core rule lifecycle engine
Compiler.lua              # EventScript AST → CSP instruction tree compiler
Parser.lua                # EventScript tokenizer + parser
CSP.lua                   # Continuation-passing style VM (runtime evaluator)
Tokenizer.lua             # Tokenizer / lexer
Props.lua                 # Device property definitions and triggers
ScriptFuns.lua            # Built-in functions, Scene PropClass
Utils.lua                 # Utility functions and time helpers
Sim.lua                   # Simulation support for offline testing
dist/
  EventRunner7.fqa        # Compiled QuickApp package (ready to import to HC3)
docs/
  EventScript.md          # Full EventScript language reference
  RULES.md                # Rule engine API reference (eval, rule object, opts, etc.)
  Grammar.txt             # Formal grammar for EventScript
  Tutorial.md             # Step-by-step tutorial
  Recipes.md              # Common automation recipes
tests/                    # Unit and integration tests
```

---

## Local Development with plua

[plua](https://pypi.org/project/plua/) lets you run and debug EventRunner7 QuickApps locally without a physical HC3.

### Install

```bash
pip install plua
```

### Run a QuickApp

```bash
plua --fibaro --nodebugger EventRunner7.lua           # run until idle
plua --fibaro --run-for 0 EventRunner7.lua            # run forever (Ctrl+C)
plua --fibaro --run-for 30 EventRunner7.lua           # run for 30 seconds
```

### VS Code Debug (F5)

Add to `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [{
    "name": "Plua: EventRunner7",
    "type": "luaMobDebug",
    "request": "launch",
    "workingDirectory": "${workspaceFolder}",
    "sourceBasePath": "${workspaceFolder}",
    "listenPort": 8172,
    "stopOnEntry": false,
    "interpreter": "plua",
    "arguments": ["--fibaro", "--run-for", "0", "${relativeFile}"]
  }]
}
```

Requires the **LuaMobDebug** VS Code extension.

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/EventScript.md](docs/EventScript.md) | Full language reference: triggers, expressions, functions, operators |
| [docs/RULES.md](docs/RULES.md) | Rule engine API: `eval()`, rule object, modifiers, verbosity, lifecycle |
| [docs/Tutorial.md](docs/Tutorial.md) | Step-by-step introduction for new users |
| [docs/Recipes.md](docs/Recipes.md) | Ready-to-use automation recipes |
| [docs/Grammar.txt](docs/Grammar.txt) | Formal BNF grammar for EventScript |
| [CHANGELOG.md](CHANGELOG.md) | Release history |

---

## License

MIT — see [LICENSE](LICENSE) for details.

## Author

**Jan Gabrielsson** — initial work and ongoing development

## Acknowledgments

- Fibaro community for feedback and testing
- Contributors across the EventRunner framework evolution (v1 → v7)
