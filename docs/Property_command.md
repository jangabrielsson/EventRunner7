# Property & Command Reference

Properties and commands are accessed using the colon syntax on a device ID (or a table of device IDs):

```lua
<device> :property          -- get
<device> :property = <val>  -- set
```

When `<device>` is a **table of IDs**, the get function is applied to each device and the results collected into a list. If the property has a **reduce** function, that list is collapsed to a single value (e.g. `true` if any light is on).

Columns in the tables below:

| Column | Meaning |
|--------|---------|
| **Get** | Can be used as a right-hand expression |
| **Set** | Can be used as a left-hand assignment |
| **Triggers** | Property change fires this trigger in rules |
| **Reduce** | How a list result is collapsed for a table of devices |

---

## Core Device Properties

| Property | Get | Set | Triggers | Reduce | Description |
|----------|:---:|:---:|----------|--------|-------------|
| `:value` | ✓ | ✓ | `device.value` | — | The primary value of the device. Set calls `setValue()`. |
| `:bat` | ✓ | — | `device.batteryLevel` | — | Battery level (0–100). |
| `:isDead` | ✓ | — | `device.dead` | — | `true` when the device is unreachable/dead. |
| `:state` | ✓ | ✓ | `device.state` | — | Device state string. Set via `updateProperty`. |
| `:prop` | — | ✓ | — | — | Generic property setter. Assign `{propertyName, value}` to call `updateProperty(name, value)` on the device. |

### `:value`
The most general-purpose property. Reading returns the raw value from the HC3 device. Writing calls `fibaro.call(id, "setValue", value)`.

```lua
fibaro.call(10, "setValue", 50)   -- equivalent to:
10:value = 50
local v = 10:value
```

### `:prop`
Low-level escape hatch for any property not in this table.

```lua
10:prop = {"someProperty", 42}   -- calls updateProperty("someProperty", 42)
```

---

## Boolean State Properties

These all read the device `value` property but interpret it as a boolean or return a boolean. When used on a table of devices the reduce function collapses the list.

| Property | Get | Set | Triggers | Reduce | Description |
|----------|:---:|:---:|----------|--------|-------------|
| `:isOn` | ✓ | — | `device.value` | `mapOr` — `true` if **any** device is on | `value > 0` |
| `:isOff` | ✓ | — | `device.value` | `mapAnd` — `true` if **all** devices are off | `value == 0` |
| `:isAllOn` | ✓ | — | `device.value` | `mapAnd` — `true` if **all** devices are on | Same get as `:isOn` |
| `:isAnyOff` | ✓ | — | `device.value` | `mapOr` — `true` if **any** device is off | Same get as `:isOff` |

**Aliases** (same behaviour, different names for readability):

| Alias | Maps to |
|-------|---------|
| `:isOpen` | `:isOn` |
| `:isClosed` | `:isOff` |
| `:breached` | `:isOn` |
| `:safe` | `:isOff` |
| `:lux` | `:value` |
| `:temp` | `:value` |

```lua
-- Single device
10:isOn => ...
20:isClosed => ...

-- Table of devices — reduce applied automatically
lights = {10, 11, 12}
lights:isOn => ...   -- true if any light is on
lights:isOff => ...  -- true if all lights are off
```

---

## Device Commands (Actions)

These are write-only commands that call a named method on the device. They have no trigger. When used on a table of devices, the command is sent to every device in the list (`mapF` — map over all, discard results).

| Property | Get | Set | Triggers | Reduce | HC3 Method |
|----------|:---:|:---:|----------|--------|------------|
| `:on` | ✓* | — | — | `mapF` | `turnOn()` |
| `:off` | ✓* | — | — | `mapF` | `turnOff()` |
| `:toggle` | ✓* | — | — | `mapF` | `toggle()` |
| `:open` | ✓* | — | — | `mapF` | `open()` |
| `:close` | ✓* | — | — | `mapF` | `close()` |
| `:stop` | ✓* | — | — | `mapF` | `stop()` |
| `:secure` | ✓* | — | — | `mapF` | `secure()` |
| `:unsecure` | ✓* | — | — | `mapF` | `unsecure()` |
| `:wake` | ✓* | — | — | `mapF` | `wakeUpDeadDevice()` |
| `:levelIncrease` | ✓* | — | — | `mapF` | `startLevelIncrease()` |
| `:levelDecrease` | ✓* | — | — | `mapF` | `startLevelDecrease()` |
| `:levelStop` | ✓* | — | — | `mapF` | `stopLevelChange()` |
| `:removeSchedule` | ✓* | — | — | `mapF` | `removeSchedule()` |
| `:setAllSchedules` | ✓* | — | — | `mapF` | `setAllSchedules()` |
| `:retryScheduleSynchronization` | ✓* | — | — | `mapF` | `retryScheduleSynchronization()` |

> \* These are technically read (get) in the CSP sense — the command fires when the expression is evaluated.

```lua
10:on          -- turns device 10 on
{10,11,12}:off -- turns all three off
```

---

## Dimming

| Property | Get | Set | Triggers | Description |
|----------|:---:|:---:|----------|-------------|
| `:dim` | — | ✓ | `device.value` | Dims a light. Assign a `{level, time}` table to call `dimLight(id, level, time)`. |

```lua
10:dim = {50, 2000}   -- dim to 50% over 2 seconds
```

---

## Position & Cover

| Property | Get | Set | Triggers | Description |
|----------|:---:|:---:|----------|-------------|
| `:position` | ✓ | ✓ | `device.position` | Current position (0–100). Set calls `setPosition()`. |
| `:positions` | — | ✓ | — | Sets available positions via `updateProperty("availablePositions", value)`. |

---

## Media / Player

| Property | Get | Set | Triggers | Description |
|----------|:---:|:---:|----------|-------------|
| `:play` | ✓ | — | — | Sends `play()` to the device. |
| `:pause` | ✓ | — | — | Sends `pause()` to the device. |
| `:volume` | ✓ | ✓ | `device.volume` | Current volume. Set calls `setVolume()`. |
| `:mute` | ✓ | ✓ | `device.mute` | Mute state. Set calls `setMute()`. |

---

## Security (door locks)

| Property | Get | Set | Triggers | Reduce | Description |
|----------|:---:|:---:|----------|--------|-------------|
| `:isSecure` | ✓ | — | `device.secured` | `mapAnd` — all secured | `true` when `secured` property is truthy. |
| `:isUnsecure` | ✓ | — | `device.secured` | `mapOr` — any unsecured | `true` when `secured` is falsy. |

---

## Event Properties

These get functions receive the triggering event `e` and extract relevant data. They have no meaningful value outside a triggered rule context.

### `:scene`
| Property | Get | Set | Triggers |
|----------|:---:|:---:|----------|
| `:scene` | ✓ | — | `device.sceneActivationEvent` |

Returns the `sceneId` from a scene activation event for the device, or `nil` if the event doesn't match.

### `:central`
| Property | Get | Set | Triggers |
|----------|:---:|:---:|----------|
| `:central` | ✓ | — | `device.centralSceneEvent` |

Returns the raw central scene event value table `{keyId, keyAttribute}` or `{}`.

### `:key`
| Property | Get | Set | Triggers |
|----------|:---:|:---:|----------|
| `:key` | ✓ | — | `device.centralSceneEvent` |

Like `:central` but also adds `.id` and `.attr` shorthand fields and a `__tostring` that renders as `"keyId:keyAttribute"`.

```lua
-- In a rule triggered by a remote:
20:key.attr == "Pressed" => ...
```

### `:access`
| Property | Get | Set | Triggers |
|----------|:---:|:---:|----------|
| `:access` | ✓ | — | `device.accessControlEvent` |

Returns the access control event value table or `{}`.

---

## Time & History

| Property | Get | Set | Triggers | Description |
|----------|:---:|:---:|----------|-------------|
| `:last` | ✓ | — | `device.value` | Seconds since the device's `value` last changed. |
| `:manual` | ✓ | — | `device.value` | Returns the last time the device was manually controlled (via `quickApp:lastManual(id)`). |
| `:time` | ✓ | ✓ | `device.time` | Device time property. Set calls `setTime()`. |
| `:trigger` | ✓ | — | `device.value` | Returns raw `value`. Useful as a rule trigger expression without caring about the value itself. |

---

## Power & Energy

| Property | Get | Set | Triggers | Description |
|----------|:---:|:---:|----------|-------------|
| `:power` | ✓ | ✓ | `device.power` | Current power draw in watts. Set calls `setPower()`. |

---

## Device Metadata

Read-only properties that query the HC3 API for device information.

| Property | Get | Triggers | Description |
|----------|:---:|----------|-------------|
| `:name` | ✓ | — | Device name from `fibaro.getName(id)`. |
| `:type` | ✓ | — | Device type string from the device info. Reduce: `mapF`. |
| `:parent` | ✓ | — | Parent device ID from the devices API. |
| `:roomName` | ✓ | — | Name of the room the device belongs to. |
| `:HTname` | ✓ | — | The Home Table (HT) variable name that points to this device ID, via `ER.reverseVar(id)`. |
| `:partition` | ✓ | — | The full alarm partition object for this partition ID (`api.get("/alarms/v1/partitions/{id}")`). |

---

## Scene Control

| Property | Get | Set | Triggers | Description |
|----------|:---:|:---:|----------|-------------|
| `:start` | ✓ | ✓ | — | **Get**: executes the scene (`fibaro.scene("execute", {id})`). **Set**: if value is an event table, posts it as a remote trigger to the scene QA. |
| `:kill` | ✓ | — | — | Kills a running scene (`fibaro.scene("kill", {id})`). |

---

## Profile

| Property | Get | Set | Description |
|----------|:---:|:---:|-------------|
| `:profile` | — | ✓ | Activates the profile with the given ID when set to a truthy value (`fibaro.profile("activateProfile", id)`). |

---

## Thermostat Properties

### Heating Setpoint

| Property | Get | Set | Triggers | Reduce | Description |
|----------|:---:|:---:|----------|--------|-------------|
| `:heatingThermostatSetpoint` | ✓ | ✓ | `device.heatingThermostatSetpoint` | `mapF` | Heating target temperature. Set calls `setHeatingThermostatSetpoint()`. |
| `:heatingThermostatSetpointCapabilitiesMax` | ✓ | — | `device.heatingThermostatSetpointCapabilitiesMax` | `mapF` | Maximum allowed heating setpoint. |
| `:heatingThermostatSetpointCapabilitiesMin` | ✓ | — | `device.heatingThermostatSetpointCapabilitiesMin` | `mapF` | Minimum allowed heating setpoint. |
| `:heatingThermostatSetpointFuture` | ✓ | — | `device.heatingThermostatSetpointFuture` | `mapF` | Scheduled future heating setpoint. |
| `:heatingThermostatSetpointStep` | ✓ | — | `device.heatingThermostatSetpointStep` | `mapF` | Setpoint adjustment granularity. |

### Cooling Setpoint

| Property | Get | Set | Triggers | Reduce | Description |
|----------|:---:|:---:|----------|--------|-------------|
| `:coolingThermostatSetpoint` | ✓ | ✓ | `device.coolingThermostatSetpoint` | `mapF` | Cooling target temperature. Set calls `setCoolingThermostatSetpoint()`. |
| `:coolingThermostatSetpointCapabilitiesMax` | ✓ | — | `device.coolingThermostatSetpointCapabilitiesMax` | `mapF` | Maximum allowed cooling setpoint. |
| `:coolingThermostatSetpointCapabilitiesMin` | ✓ | — | `device.coolingThermostatSetpointCapabilitiesMin` | `mapF` | Minimum allowed cooling setpoint. |
| `:coolingThermostatSetpointFuture` | ✓ | — | `device.coolingThermostatSetpointFuture` | `mapF` | Scheduled future cooling setpoint. |
| `:coolingThermostatSetpointStep` | ✓ | — | `device.coolingThermostatSetpointStep` | `mapF` | Setpoint adjustment granularity. |

### Fan & Mode

| Property | Get | Set | Triggers | Reduce | Description |
|----------|:---:|:---:|----------|--------|-------------|
| `:thermostatFanMode` | ✓ | ✓ | `device.thermostatFanMode` | `mapF` | Fan mode. Set calls `setThermostatFanMode()`. |
| `:thermostatFanOff` | ✓ | — | `device.thermostatFanOff` | `mapF` | Whether the fan is off. |
| `:thermostatMode` | ✓ | — | `device.thermostatMode` | `mapF` | Current thermostat operating mode. |
| `:thermostatModeFuture` | ✓ | — | `device.thermostatModeFuture` | `mapF` | Scheduled future thermostat mode. |

### Write-only Thermostat Commands

| Property | Set | Description |
|----------|:---:|-------------|
| `:targetLevel` | ✓ | Sets the target level via `setTargetLevel()`. |
| `:interval` | ✓ | Sets the interval via `setInterval()`. |
| `:mode` | ✓ | Sets the mode via `setMode()`. |
| `:setpointMode` | ✓ | Sets the setpoint mode via `setSetpointMode()`. |
| `:defaultPartyTime` | ✓ | Sets the default party time via `setDefaultPartyTime()`. |
| `:scheduleState` | ✓ | Sets the schedule state via `setScheduleState()`. |

---

## Alarm / Partition Properties

These apply to **alarm partition IDs** (not regular device IDs). Use `0` for the home-level arm state.

| Property | Get | Set | Triggers | Reduce | Description |
|----------|:---:|:---:|----------|--------|-------------|
| `:armed` | ✓ | ✓ | `alarm` | `mapOr` — any armed | `true` when armed. Set `true` to arm, `false` to disarm. |
| `:tryArm` | ✓ | — | `alarm` | — | Attempts to arm the partition; returns `true` on success. If sensors are breached, posts a `delayed` alarm event. |
| `:isArmed` | ✓ | — | `alarm` | `mapOr` — any armed | Reads `partition.armed` directly. |
| `:isAllArmed` | ✓ | — | `alarm` | `mapAnd` — all armed | `true` only when all partitions are armed. |
| `:isDisarmed` | ✓ | — | `alarm` | `mapAnd` — all disarmed | `true` only when all partitions are disarmed. |
| `:isAnyDisarmed` | ✓ | — | `alarm` | `mapOr` — any disarmed | `true` if any partition is disarmed. |
| `:isAlarmBreached` | ✓ | — | `alarm` | `mapOr` — any breached | `true` if any partition is breached. |
| `:isAllAlarmBreached` | ✓ | — | `alarm` | `mapAnd` — all breached | `true` only when all partitions are breached. |
| `:isAlarmSafe` | ✓ | — | `alarm` | `mapAnd` — all safe | `true` only when all partitions are safe (not breached). |
| `:isAnyAlarmSafe` | ✓ | — | `alarm` | `mapOr` — any safe | `true` if any partition is safe. |

```lua
-- Arm partition 1
1:armed = true

-- Check if home is safe
0:isArmed => print("Home is armed")
```

---

## Notifications

| Property | Get | Set | Description |
|----------|:---:|:---:|-------------|
| `:msg` | — | ✓ | Sends a push notification to the user with the given ID via `fibaro.alert()`. |
| `:email` | — | ✓ | Sends an email notification to the user. Assign a string value. |
| `:defemail` | — | ✓ | Sends a defined email notification via `sendDefinedEmailNotification()`. |
| `:simKey` | — | ✓ | Simulates a central scene key press. Assign `{keyId=N, keyAttribute="Pressed"}`. Useful for testing rules. |

```lua
-- Push notification to user 10
10:msg = "Motion detected in kitchen"

-- Simulate a key press from device 20 (for testing)
20:simKey = {keyId=1, keyAttribute="Pressed"}
```

---

## Reduce Functions Summary

When a property is read from a **table of device IDs**, the individual results are collected and passed through the property's reduce function:

| Reduce | Behaviour |
|--------|-----------|
| `mapOr` | Returns `true` if **any** value is truthy |
| `mapAnd` | Returns `true` if **all** values are truthy |
| `mapF` | Returns the list of results as-is (no collapse) |
| — (none) | The list is returned as-is |

```lua
lights = {10, 11, 12}

lights:isOn => print("Some lights are on") -- mapOr: true if any light is on


lights:isOff => print("All lights are off") -- mapAnd: true if ALL lights are off

for i,v in ipairs(lights:type) do  -- mapF: returns {"com.fibaro.binarySwitch", ...}
  print(i, v)
end
```
