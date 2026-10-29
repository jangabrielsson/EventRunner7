# EventRunner7 Examples

Runnable, heavily commented example QAs — a safe sandbox to learn the rule
language by breaking it. Everything runs **offline** in the flua simulator
with simulated devices; nothing touches a real controller.

## Running

```bash
flua --api local --step examples/motion-lights.lua
```

`--step` fast-forwards the virtual clock through timers and schedules, so a
morning that spans hours completes in an instant (this is also how the test
suite runs).

## The examples

| Example | What it demonstrates |
|---|---|
| `motion-lights.lua` | The classic rule: `when motion:breached then light:on; wait(2min); light:off` — device triggers, `when…then` sugar, duration literals (`2min`), time-window guards (`20:00..06:00`), the `cooldown` modifier, and trigger-variable counters. A demo driver breaches the sensor so you watch the rules fire. |
| `morning-routine.lua` | Time-based rules: daily `@07:00`, workday guard with `date('* * * mon-fri')`, clock-aligned `@@-01:00`, and `first_in` window behavior. |
| `door-alert.lua` | Variables and modifiers: `since 2min` (continuous condition), `debounce 5s` (silence after the last press), plus a deliberately broken rule so you can see the friendly error format — the variable is named, the position is marked, and the rule auto-disables. |

## After the examples

- `docs/RULES.md` — the rule system reference (modifiers, error policy, binding rules)
- `docs/EventScript.md` — the language reference
- `docs/Recipes.md` — copy-paste rule patterns
- `docs/Templates.md` — parameterized templates for the common patterns
