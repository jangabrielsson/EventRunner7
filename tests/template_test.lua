--%%name:Template tests
-- Tests for the Templates module.
-- Exercises template validation, rule string generation, and edge cases
-- by calling Templates.apply() with a mock er.eval().

-- Templates.lua expects MODULE and fibaro globals to exist
MODULE = MODULE or {}
fibaro = fibaro or {}
fibaro.ER = fibaro.ER or {}

-- Load the module directly
local Templates = dofile("Templates.lua")
assert(Templates, "Failed to load Templates module")

-- Capture er.eval() calls
local captured = {}

local function mockEval(ruleStr, opts)
  captured[#captured+1] = { rule = ruleStr, opts = opts or {} }
  return { id = #captured, rule = ruleStr, opts = opts }
end

local function resetCapture()
  captured = {}
end

local er = { eval = mockEval }

local function main()
  print("=== Template Tests ===\n")

  local passed, failed = 0, 0

  local function assertEq(actual, expected, msg)
    if actual == expected then
      passed = passed + 1
    else
      failed = failed + 1
      print(string.format("FAIL: %s", msg or ""))
      print(string.format("  expected: %s", tostring(expected)))
      print(string.format("  actual:   %s", tostring(actual)))
    end
  end

  local function assertMatch(actual, pattern, msg)
    if type(actual) == "string" and actual:match(pattern) then
      passed = passed + 1
    else
      failed = failed + 1
      print(string.format("FAIL: %s", msg or ""))
      print(string.format("  pattern: %s", pattern))
      print(string.format("  actual:  %s", tostring(actual)))
    end
  end

  -- Test 1: motionLight (basic)
  resetCapture()
  Templates.apply(er, "motionLight", { sensor = "kitchen.motion", light = "kitchen.light" })
  assertEq(captured[1].rule, "kitchen.motion:breached => kitchen.light:on", "motionLight basic")

  -- Test 2: motionLight with offDelay and modifier
  resetCapture()
  Templates.apply(er, "motionLight", {
    sensor = 77, light = 54,
    offDelay = "00:05", modifier = "single",
  })
  assertEq(captured[1].rule, "77:breached single => 54:on; wait(00:05); 54:off", "motionLight +offDelay")

  -- Test 3: motionLight with timeGuard=night and brightness
  resetCapture()
  Templates.apply(er, "motionLight", {
    sensor = "hall.motion", light = "hall.light",
    timeGuard = "night", brightness = 80,
  })
  assertEq(captured[1].rule,
    "hall.motion:breached & sunset..sunrise => hall.light:value = 80",
    "motionLight night+dim")

  -- Test 4: motionLight with group
  resetCapture()
  Templates.apply(er, "motionLight", {
    sensor = "kitchen.motion", light = "kitchen.light",
    group = "hallway",
  })
  assertEq(captured[1].opts.group, "hallway", "motionLight group")

  -- Test 5: thresholdControl
  resetCapture()
  Templates.apply(er, "thresholdControl", {
    sensor = "livingroom.temp", actuator = "livingroom.fan",
    onAbove = 28, offBelow = 22,
  })
  assertEq(captured[1].rule, "livingroom.temp:value > 28 => livingroom.fan:on", "thresholdControl on")
  assertEq(captured[2].rule, "livingroom.temp:value < 22 => livingroom.fan:off", "thresholdControl off")

  -- Test 6: thresholdControl with holdTime + cooldown
  resetCapture()
  Templates.apply(er, "thresholdControl", {
    sensor = 89, actuator = 92,
    onAbove = 30, offBelow = 18,
    holdTime = "00:05", cooldown = "00:30",
  })
  assertEq(captured[1].rule, "89:value > 30 since 00:05 cooldown 00:30 => 92:on", "thresholdControl +mods")

  -- Test 7: scheduledDevice
  resetCapture()
  Templates.apply(er, "scheduledDevice", {
    time = "23:00", device = "allLights", action = "off",
    days = "mon-thu",
  })
  assertEq(captured[1].rule, "@23:00 & wday('mon-thu') => allLights:off", "scheduledDevice weekdays")

  -- Test 8: scheduledDevice with catchup
  resetCapture()
  Templates.apply(er, "scheduledDevice", {
    time = "08:00", device = "bedroom.light", action = "value=80",
    catchup = true, days = "weekdays",
  })
  assertEq(captured[1].rule, "@{08:00,catch} & wday('mon-fri') => bedroom.light:value = 80", "scheduledDevice catchup")

  -- Test 9: scheduledDevice with @ prefix
  resetCapture()
  Templates.apply(er, "scheduledDevice", {
    time = "@sunset", device = "outdoor.light", action = "on",
  })
  assertEq(captured[1].rule, "@sunset => outdoor.light:on", "scheduledDevice @sunset")

  -- Test 10: openAlert
  resetCapture()
  Templates.apply(er, "openAlert", {
    sensor = "front.door", timeout = "00:05",
  })
  assertMatch(captured[1].rule, "trueFor%(00:05,front%.door:breached%) => log%('front%.door open for 00:05'%)", "openAlert basic")

  -- Test 11: openAlert with custom message + repeat
  resetCapture()
  Templates.apply(er, "openAlert", {
    sensor = "garage.door", timeout = "00:10",
    message = "Garage open!", repeatAlert = true, repeatMax = 5,
  })
  assertMatch(captured[1].rule, "trueFor%(00:10,garage%.door:breached%) => log%('Garage open!'%); again%(5%)", "openAlert +repeat")

  -- Test 12: scheduledScene
  resetCapture()
  Templates.apply(er, "scheduledScene", {
    scene = "morningLights", time = "07:00", days = "mon-fri",
  })
  assertEq(captured[1].rule, "@07:00 & wday('mon-fri') => morningLights:activate", "scheduledScene")

  -- Test 13: sunDevice
  resetCapture()
  Templates.apply(er, "sunDevice", {
    event = "sunset", device = "outdoorLights", action = "on",
  })
  assertEq(captured[1].rule, "@sunset => outdoorLights:on", "sunDevice basic")

  -- Test 14: sunDevice with offset
  resetCapture()
  Templates.apply(er, "sunDevice", {
    event = "sunset", offset = "-00:30",
    device = "blinds", action = "value=0",
  })
  assertEq(captured[1].rule, "@sunset-00:30 => blinds:value = 0", "sunDevice offset")

  -- Test 15: buttonScene (single click)
  resetCapture()
  Templates.apply(er, "buttonScene", {
    button = "remote", trigger = "single", scene = "goodnight",
  })
  assertEq(captured[1].rule, "remote:scene == S1.single => goodnight:activate", "buttonScene single")

  -- Test 16: buttonScene (keyId)
  resetCapture()
  Templates.apply(er, "buttonScene", {
    button = "remote", trigger = "keyId=2", scene = "allOff",
  })
  assertEq(captured[1].rule, "remote:central.keyId == 2 => allOff:activate", "buttonScene keyId")

  -- Test 17: buttonScene (raw expression + deactivate)
  resetCapture()
  Templates.apply(er, "buttonScene", {
    button = "switch", trigger = "scene==S1.double", scene = "movie",
    action = "deactivate",
  })
  assertEq(captured[1].rule, "switch:scene==S1.double => movie:deactivate", "buttonScene raw+deactivate")

  -- Test 18: autoOff
  resetCapture()
  Templates.apply(er, "autoOff", {
    trigger = "hall.motion:breached", device = "hall.light", delay = "00:05",
  })
  assertEq(captured[1].rule,
    "hall.motion:breached single => hall.light:on; wait(00:05); hall.light:off",
    "autoOff basic")

  -- Test 19: autoOff with dim + no single
  resetCapture()
  Templates.apply(er, "autoOff", {
    trigger = "bedroom.motion:breached & 22:00..06:00",
    device = "bedroom.light", delay = "00:02",
    onAction = "value=30", modifier = "none",
  })
  assertEq(captured[1].rule,
    "bedroom.motion:breached & 22:00..06:00 => bedroom.light:value = 30; wait(00:02); bedroom.light:off",
    "autoOff dim+no-single")

  -- Test 20: vacationMode
  resetCapture()
  Templates.apply(er, "vacationMode", {
    variable = "$Vacation", groups = { "lighting", "climate" },
  })
  assertEq(captured[1].rule, "$Vacation == true => disable('lighting'); disable('climate')", "vacationMode disable")
  assertEq(captured[2].rule, "$Vacation == false => enable('lighting'); enable('climate')", "vacationMode enable")
  assertEq(captured[3].rule, "$Vacation ~= true => enable('lighting'); enable('climate')", "vacationMode startup")

  -- Test 21: vacationMode inverted
  resetCapture()
  Templates.apply(er, "vacationMode", {
    variable = "HomeMode", groups = "bedroom", invert = true,
  })
  assertEq(captured[1].rule, "$HomeMode == false => disable('bedroom')", "vacationMode inverted")

  -- Test 22: nightMode
  resetCapture()
  Templates.apply(er, "nightMode", {
    time = "23:00", days = "mon-thu",
    lights = "allLights", security = true,
  })
  assertEq(captured[1].rule, "@23:00 & wday('mon-thu') => allLights:off; 0:arm", "nightMode lights+security")

  -- Test 23: nightMode thermostat only
  resetCapture()
  Templates.apply(er, "nightMode", {
    time = "00:00",
    thermostat = { device = "livingroom.thermo", setpoint = 18 },
  })
  assertEq(captured[1].rule, "@00:00 => livingroom.thermo:setpoint = 18", "nightMode thermostat")

  -- Test 24: morningRoutine full
  resetCapture()
  Templates.apply(er, "morningRoutine", {
    time = "07:00", days = "weekends",
    lights = "bedroom.light", brightness = 80,
    security = 2,
    thermostat = { device = "livingroom.thermo", setpoint = 21 },
  })
  assertEq(captured[1].rule,
    "@07:00 & wday('sat-sun') => bedroom.light:value = 80; 2:disarm; livingroom.thermo:setpoint = 21",
    "morningRoutine full")

  -- Test 25: device list reference
  resetCapture()
  Templates.apply(er, "motionLight", {
    sensor = 77,
    light = { 54, 91, 67 },
  })
  assertEq(captured[1].rule, "77:breached => {54,91,67}:on", "device list ref")

  -- Test 26: validation - missing required param
  local ok, err = pcall(Templates.apply, er, "motionLight", { sensor = "x" })
  assertEq(ok, false, "validation: missing required")
  assertMatch(err, "missing required parameter 'light'", "validation error message")

  -- Test 27: validation - unknown template
  local ok2, err2 = pcall(Templates.apply, er, "nonexistent", {})
  assertEq(ok2, false, "validation: unknown template")
  assertMatch(err2, "Unknown template", "unknown template error")

  -- Test 28: validation - bad params type
  local ok3, err3 = pcall(Templates.apply, er, "motionLight", "not a table")
  assertEq(ok3, false, "validation: bad params type")

  -- Test 29: templateList
  local names = Templates.list()
  assertEq(type(names), "table", "list returns table")
  assertEq(#names >= 12, true, "list has 12+ templates")

  -- Test 30: templateDescribe
  local schema = Templates.describe("motionLight")
  assertEq(schema.required[1], "sensor", "describe returns schema")

  -- Test 31: custom template registration
  Templates.register("_testCustom", {
    description = "Custom test",
    required = { "name" },
    defaults = { val = 42 },
  }, function(er2, p)
    er2.eval(p.name .. " => log('" .. p.val .. "')", {})
  end)
  resetCapture()
  Templates.apply(er, "_testCustom", { name = "testTrigger" })
  assertEq(captured[1].rule, "testTrigger => log('42')", "custom template")

  -- Test 32: groupToggle
  resetCapture()
  Templates.apply(er, "groupToggle", {
    trigger = "button:scene == S1.single",
    group = "bedroom", action = "disable",
  })
  assertEq(captured[1].rule, "button:scene == S1.single => disable('bedroom')", "groupToggle")

  -- Test 33: presenceSim
  resetCapture()
  Templates.apply(er, "presenceSim", {
    lights = { "livingroom.light", "kitchen.light" },
    startTime = "18:00", endTime = "22:00",
    activeDays = "mon-fri", interval = "00:20",
  })
  assertEq(#captured, 3, "presenceSim 3 rules")
  assertEq(captured[1].rule, "@18:00 & wday('mon-fri') => post(#_presenceSimTick)", "presenceSim start")

  -- Test 34: thresholdControl with custom property
  resetCapture()
  Templates.apply(er, "thresholdControl", {
    sensor = "livingroom.lux", property = "lux",
    actuator = "livingroom.blinds",
    onAbove = 20000, offBelow = 5000,
  })
  assertEq(captured[1].rule, "livingroom.lux:lux > 20000 => livingroom.blinds:on", "thresholdControl lux")

  -- Test 35: day filter shortcuts
  resetCapture()
  Templates.apply(er, "scheduledDevice", {
    time = "12:00", device = "light", action = "on",
    days = "weekends",
  })
  assertEq(captured[1].rule, "@12:00 & wday('sat-sun') => light:on", "day filter weekends")

  -- Summary
  print(string.format("\n=== Results: %d passed, %d failed ===", passed, failed))
  if failed > 0 then
    error(string.format("%d test(s) failed", failed))
  end
end

local ok, err = pcall(main)
if not ok then
  print("TEST SUITE FAILED: " .. tostring(err))
  os.exit(1)
end
print("All template tests passed.")
