<p align="center">
    <img src="https://raw.githubusercontent.com/jangabrielsson/EventRunner6/main/doc/logo.png" alt="EventRunner6 Logo" width="320"/>
</p>

# EventRunner7

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.1.41-blue.svg)](.version)

<a href="https://www.buymeacoffee.com/rywnwpdvvni" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

EventRunner7 is a rule-based automation framework for Fibaro Home Center 3 (HC3). It provides an expressive domain-specific language (**EventScript**) for writing automation rules with event handling, scheduling, rule modifiers, and named scenes.

> Successor to [EventRunner6](https://github.com/jangabrielsson/EventRunner6) — fully backward-compatible rule syntax.

---

## Features

- **Intuitive Rule Syntax** — write rules as `condition => action` one-liners or multi-line blocks
- **Rich Trigger System** — time (`@HH:MM`), interval (`@@HH:MM`), device properties, global variables, custom events (`#name`)
- **Rule Modifiers** — `single`, `since`, `debounce`, `cooldown`, `every` for precise firing control
- **Rule Groups** — tag rules with `{group="name"}` and enable/disable the whole group at once
- **Async Actions** — `wait(sec)` suspends mid-action without blocking other rules
- **Event Scheduling** — post events with relative (`+/HH:MM`) or absolute (`n/HH:MM`) times
- **High-Level Templates** — parameterized patterns for common use cases (motion → light, thermostat control, etc.)
- **Device Collections** — apply actions to lists of devices; aggregate with `:average`, `:someTrue`
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

  er.defvars(var.HT)

  rule("kitchen.motion:breached => kitchen.light:on")
  rule("@sunset => living.light:on")
  rule("@@00:05 => log('heartbeat')", {check=false})
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
```

### Using Templates (no coding required)

```lua
er.template("motionLight", {
  sensor = "kitchen.motion",
  light = "kitchen.light",
  offDelay = "00:05",
  timeGuard = "night",
})

er.template("scheduledDevice", {
  time = "23:00", device = "allLights", action = "off",
})
```

See [docs/Templates.md](docs/Templates.md) for all 13 built-in templates.

---

## Project Structure

```
src/
  Tokenizer.lua             # Lexer / tokenizer
  Parser.lua                # Recursive descent parser
  Compiler.lua              # EventScript AST → CSP instruction tree
  CSP.lua                   # Continuation-passing style VM (runtime evaluator)
  Rule.lua                  # Core rule lifecycle engine + trigger scanning
  ScriptFuns.lua            # Built-in functions
  Props.lua                 # Device property definitions and triggers
  Utils.lua                 # Utilities (JSON, time, alarm, HTTP)
  Setup.lua                 # Engine initialisation and standard rules
  Templates.lua             # High-level parameterized templates
  Sim.lua                   # Simulation support for offline testing
EventRunner7.lua            # Main QuickApp entry point
EventRunner.inc             # Module include manifest
dist/
  EventRunner7.fqa          # Compiled QuickApp package (ready to import to HC3)
test/
  run-tests.sh              # Regression test runner
  harness.lua               # Shared test utilities
  expr/                     # Expression tests (synchronous)
  rules/                    # Rule tests (async, isolated)
docs/
  EventScript.md            # Full language reference
  RULES.md                  # Rule engine API
  Tutorial.md               # Step-by-step introduction
  Recipes.md                # Ready-to-use automation recipes
  Templates.md              # Template reference
  Grammar.txt               # Formal BNF grammar
  ARCHITECTURE.md           # Pipeline design and module overview
  CSP_README.md             # CSP IR contract
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/EventScript.md](docs/EventScript.md) | Full language reference: triggers, expressions, functions, operators |
| [docs/RULES.md](docs/RULES.md) | Rule engine API: `eval()`, rule object, modifiers, verbosity, lifecycle |
| [docs/Tutorial.md](docs/Tutorial.md) | Step-by-step introduction for new users |
| [docs/Recipes.md](docs/Recipes.md) | Ready-to-use automation recipes |
| [docs/Templates.md](docs/Templates.md) | High-level parameterized templates |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Pipeline design and module overview |
| [docs/Grammar.txt](docs/Grammar.txt) | Formal BNF grammar for EventScript |
| [docs/CSP_README.md](docs/CSP_README.md) | CSP IR contract for language frontends |
| [CHANGELOG.md](CHANGELOG.md) | Release history |

---

## Local Development with plua

```bash
pip install plua
plua --fibaro EventRunner7.lua            # run until idle
plua --fibaro --run-for 30 EventRunner7.lua  # run for 30 seconds
```

Run the test suite:
```bash
./test/run-tests.sh          # all tests
./test/run-tests.sh expr     # expression tests only
./test/run-tests.sh -v       # verbose output
```

---

## License

MIT — see [LICENSE](LICENSE) for details.

## Author

**Jan Gabrielsson** — initial work and ongoing development

## Acknowledgments

- Fibaro community for feedback and testing
- Contributors across the EventRunner framework evolution (v1 → v7)
