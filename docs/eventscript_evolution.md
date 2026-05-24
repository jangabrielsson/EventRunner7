# EventScript Evolution — Language Improvement Ideas

This document captures design ideas for making EventScript a more expressive and ergonomic home automation language. These are starting points for deeper discussion, not final proposals.

---

## What EventScript already does exceptionally well

The language has a strong core: reactive triggers, time arithmetic, `wait()` for sequential async, event pattern matching with constraints, device groups, the `..` range operator, and a clean 4-tier variable scope (`var`, `$global`, `$$qavar`, `$$$persistent`). Most home automation DSLs don't get this far.

---

## Proposed Improvements

### 1. First-class debounce / cooldown

The most common HA pattern — "lights stay on while motion continues" — currently requires 8+ lines of cancel/post boilerplate. A rule modifier would collapse it:

```lua
-- debounce: action runs only after condition has been stable for N time
rule("motion:breached debounce 00:05 => lights:on")

-- cooldown: rule can only fire once every N time, no matter how many triggers
rule("doorbell:value cooldown 00:01 => notify('Doorbell!')")
```

Both map directly onto the existing cancel/post/timer machinery but remove the biggest friction point for new users.

---

### 2. `since` — sustained-condition trigger

`trueFor()` exists but requires wrapping an expression. A keyword reads more naturally for the typical "fan on if temp has been high for 5 minutes" case:

```lua
rule("tempSensor:value > 28 since 00:05 => fan:on")
rule("tempSensor:value < 22 since 00:05 => fan:off")
```

---

### 3. Named scenes

Device groups already exist. A `scene` declaration would make intent clearer and allow activation/deactivation as a first-class action:

```lua
rule("scene cozy = { light1:value=30, light2:value=50, blinds:position=40 }")
rule("scene bright = { light1:value=100, light2:value=100 }")

rule("@20:00 => cozy:activate")
rule("switch:scene == S1.double => bright:activate")
```

Internally each scene is just a named batch setprop, but the abstraction is very natural for HA.

---

### 4. Rule groups — enable/disable sets atomically

Currently there's no way to disable a set of rules together. The most wanted HA pattern is "vacation mode turns off all motion rules":

```lua
rule("motion:breached => lights:on", {group="home"})
rule("@23:00 => lights:off",         {group="home"})
rule("@sunrise => blinds:open",      {group="home"})

rule("$Vacation == true  => group('home'):disable")
rule("$Vacation == false => group('home'):enable")
```

The `{group=...}` option fits the existing opts 2nd-arg pattern.

---

### 5. `every N` — event counting

Fairly common: ring notification only on the 3rd ring, log every 10th trigger:

```lua
rule("doorbell:value every 3 => notify('3rd ring!')")
rule("@@00:01 every 60 => log('hourly ping')")   -- every 60th minute-tick
```

---

### 6. Derived/computed variables

Currently `avgTemp` requires a rule that fires on each sensor and recomputes. A reactive computed binding would be cleaner:

```lua
-- automatically recomputes when any source changes, triggers rules that watch avgTemp
avgTemp := avg({sensor1, sensor2, sensor3}:value)
```

The `:=` assignment-operator distinction makes the reactivity explicit.

---

### 7. `push` / `sms` as built-in notification actions

Currently notification requires a Lua HC3 API call. Given notifications are the #1 HA action after device control, first-class syntax makes sense:

```lua
rule("doorSensor:isOpen & 23:00..06:00 => push('Door open at night!')")
rule("$alarm == 'breach' => sms(phoneNumber, 'Alarm triggered!')")
```

---

### 8. `when ... then` multi-step saga

`wait()` already does sequential async, but complex multi-step flows can be hard to read. A pipeline syntax could help:

```lua
rule([[doorbell:value =>
  lights:on;
  when #guest_confirmed then
    unlock:door;
    wait(00:10);
    lock:door
  end
]])
```

This is the highest-complexity addition and lowest priority — `wait()` + events already covers this adequately.

---

## What to probably NOT add

- **Typed event schemas** — useful for tooling but adds ceremony that conflicts with the dynamic Lua spirit
- **Presence/occupancy built-ins** — too system-specific; better handled via custom property classes (which already exist)
- **Regex device name matching** — rare need, and the group `{d1,d2,...}` syntax handles the practical cases

---

## Priority Order

If picking three that give the most return for rule writers:

1. **`debounce` / `cooldown` modifiers** — eliminates the most common boilerplate
2. **`since` sustained trigger** — very common HA pattern, currently clunky with `trueFor()`
3. **Named scenes** — high expressiveness gain, maps directly to existing setprop machinery

---

## Open Questions (for further discussion)

- For `debounce`: should it reset on re-trigger (classic debounce) or use a leading-edge variant?
- For `since`: how does it interact with `wait()` inside the action — does the "since" clock pause?
- For scenes: can scenes reference other scenes (scene composition)?
- For rule groups: can a rule belong to multiple groups?
- For derived variables: what's the update order when multiple sources change simultaneously?
- For `every N`: should the counter reset when the rule is disabled/re-enabled?
