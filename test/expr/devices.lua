--%%name:expr_devices
--%%headers:EventRunner.inc
--%%file:src/Sim.lua,sim
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- Load simulated devices.  Each returns a device ID stored in a global
  -- so EventScript expressions can reference them by name.
  local sw1 = er.loadSimDevice("binarySwitch")
  local sw2 = er.loadSimDevice("binarySwitch")
  local sw3 = er.loadSimDevice("binarySwitch")
  local dim = er.loadSimDevice("multilevelSwitch")
  local sensor = er.loadSimDevice("motionSensor")
  local temp  = er.loadSimDevice("temperatureSensor")
  local temp2 = er.loadSimDevice("temperatureSensor")
  local temp3 = er.loadSimDevice("temperatureSensor")

  er.defvars({
    sw1 = sw1, sw2 = sw2, sw3 = sw3, dim = dim,
    sensor = sensor, temp = temp, temp2 = temp2, temp3 = temp3,
    switches = { sw1, sw2, sw3 },
    temps    = { temp, temp2, temp3 },
  })

  -- ── Binary switch: on/off/toggle ────────────────────────────────────────

  test_expr(er, "sw1:on; return sw1:isOn",    true,  "switch: on → isOn")
  test_expr(er, "sw1:off; return sw1:isOff",  true,  "switch: off → isOff")
  test_expr(er, "sw1:on; return sw1:value",   1,     "switch: on → value=1")
  test_expr(er, "sw1:off; return sw1:value",  0,     "switch: off → value=0")

  -- toggle
  test_expr(er, "sw1:off; sw1:toggle; return sw1:isOn",  true,  "switch: toggle off→on")
  test_expr(er, "sw1:toggle; return sw1:isOff",          true,  "switch: toggle on→off")

  -- ── Multilevel switch: value ────────────────────────────────────────────

  test_expr(er, "dim:value = 42; return dim:value",   42,   "dimmer: set/get value")
  test_expr(er, "dim:value = 0; return dim:value",    0,    "dimmer: value=0")
  test_expr(er, "dim:value = 100; return dim:value",  100,  "dimmer: value=100")
  test_expr(er, "dim:value = 3 + 7; return dim:value", 10,  "dimmer: expr value")

  -- ── Sensor properties ──────────────────────────────────────────────────

  test_expr(er, "sensor:value = true; return sensor:breached", true,  "sensor: breached=true")
  test_expr(er, "sensor:value = false; return sensor:safe",    true,  "sensor: safe=true")
  test_expr(er, "sensor:value = true; return sensor:isOn",    true,  "sensor: isOn alias")

  -- ── Temperature sensor ─────────────────────────────────────────────────

  test_expr(er, "temp:value = 25; return temp:temp",    25,   "temp sensor: set/get")
  test_expr(er, "temp:value = 30; return temp:value",   30,   "temp sensor: value alias")
  test_expr(er, "temp:value = 22; return temp:value",   22,   "temp sensor: update")

  -- ── Two devices independent ─────────────────────────────────────────────

  test_expr(er, "sw1:on; sw2:off; return sw1:isOn & sw2:isOff", true, "two switches independent")

  -- ── Device in expression ────────────────────────────────────────────────

  test_expr(er, "dim:value = 10; dim:value = dim:value + 5; return dim:value", 15, "dimmer: read-modify-write")

  -- ── Conditional with device state ───────────────────────────────────────

  test_expr(er, "sw1:on; if sw1:isOn then return 'yes' else return 'no' end", "yes", "if device state")

  -- ── List operations: boolean aggregates ────────────────────────────────

  -- allTrue: all switches on
  test_expr(er, "sw1:on; sw2:on; sw3:on; return switches:allTrue",  true,  "list: allTrue (all on)")
  test_expr(er, "sw1:off; return switches:allTrue",                  false, "list: allTrue fails if one off")

  -- allFalse
  test_expr(er, "sw1:off; sw2:off; sw3:off; return switches:allFalse", true, "list: allFalse (all off)")
  test_expr(er, "sw1:on; return switches:allFalse",                    false,"list: allFalse fails if one on")

  -- someTrue
  test_expr(er, "sw1:off; sw2:off; sw3:on; return switches:someTrue",  true, "list: someTrue (one on)")
  test_expr(er, "sw1:off; sw2:off; sw3:off; return switches:someTrue", false,"list: someTrue none on")

  -- someFalse
  test_expr(er, "sw1:on; sw2:on; sw3:off; return switches:someFalse",  true, "list: someFalse (one off)")
  test_expr(er, "sw1:on; sw2:on; sw3:on; return switches:someFalse",   false,"list: someFalse none off")

  -- mostlyTrue: majority on
  test_expr(er, "sw1:on; sw2:on; sw3:off; return switches:mostlyTrue",  true, "list: mostlyTrue (2 of 3)")

  -- mostlyFalse: majority off
  test_expr(er, "sw1:off; sw2:off; sw3:on; return switches:mostlyFalse", true, "list: mostlyFalse (2 of 3)")

  -- ── List operations: numeric aggregates ────────────────────────────────

  test_expr(er, "temp:value = 10; temp2:value = 20; temp3:value = 30; return temps:sum",     60, "list: sum (10+20+30)")
  test_expr(er, "return temps:average",                                                      20, "list: average (60/3)")

  -- ── List control actions ──────────────────────────────────────────────────

  -- Apply action to all devices in list
  test_expr(er, "switches:on; return switches:allTrue",   true,  "list action: all on")
  test_expr(er, "switches:off; return switches:allFalse", true,  "list action: all off")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
