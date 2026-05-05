--%%name:EventRunnerTest
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%offline:true
--%%file:$fibaro.lib.speed,speed
--%%file:Sim.lua,sim
--%%file:tests/testfuns.lua,test
--%%time:2026/04/28 12:00:00

-- testsuit for EventScript 
-- runs in real time so beware of time triggers far off in the future.
-- We always start at 2026/04/28 12:00:00
-- Loads a set of plua devices (QAs) to test with and test against. These are not compatible with speedTime.
-- Focus for this testsuit is to test the integration of EventScript with devices and resources. Standard EventScript features are tested in eventrunner_test.lua which runs with speedTime.

local function main(er) ER = er
  local rule, variables, test = er.eval, er.variables, er.test
  local function loadDevice(name) return er.loadPluaDevice(name) end

  -- Set up a HomeTable, devices we have in the home
  local HT = {
    kitchen = { 
      lamp1 = loadDevice("binarySwitch"),
      lamp2 = loadDevice("binarySwitch"),
      lamp3 = loadDevice("multilevelSwitch"),
    },
    hall = {
      motion1 = loadDevice("motionSensor"),
      motion2 = loadDevice("motionSensor"),
      motion3 = loadDevice("motionSensor"),
      door1 = loadDevice("doorSensor"),
      lamp1 = loadDevice("multilevelSwitch"),
      lamp2 = loadDevice("multilevelSwitch"),
    },
    livingRoom = {
      window1 = loadDevice("windowSensor"),
      window2 = loadDevice("windowSensor"),
      window3 = loadDevice("windowSensor"),
      fire1 = loadDevice("fireDetector"),
      dimmer = loadDevice("multilevelSwitch"),
    },
    bedroom = {
      flood1 = loadDevice("floodSensor"),
      smoke1 = loadDevice("smokeSensor"),
      temp1  = loadDevice("temperatureSensor"),
      humid1 = loadDevice("humiditySensor"),
      --blind1 = loadDevice("windowCovering"), -- not implemented yet
      blind1 = loadDevice("multilevelSwitch"), -- using multilevelSwitch as a stand in for windowCovering until we implement that
    },
    security = {
      alarm1 = loadDevice("alarmPartition"),
      remote1 = loadDevice("remoteController"),
    },
    climate = {
      thermo1 = loadDevice("hvacSystemAuto"),
    },
    entertainment = {
      player1 = loadDevice("player"),
      light1  = loadDevice("colorController"),
    },
    outdoor = {
      energy1 = loadDevice("energyMeter"),
    },
  }

  -- populate variables with the HomeTable so we can access devices as kitchen.lamp1 etc in rules, and also kitchenLamps later on.
  for k,v in pairs(HT) do variables[k] = v end
  --fibaro.debugFlags.refreshEvents = true

  local function createGlobal(name,value)
    api.post("/globalVariables", {name=name, value=value})
  end
  rule("kitchenLamps = {kitchen.lamp1,kitchen.lamp2}") -- test creating a variable with a table of devices, and that it works in rules

  local checks, nChecks = {},24
  function variables.check(n)
    if checks[n] then print("❌  Check "..n.." already checked") return end
    checks[n] = true
    local done = true
    print("✅",n,"done")
    for i=1,nChecks do if not checks[i] then done = false; break end end
    if done then print("✅ All "..nChecks.." checks passed, test complete") end
  end

  -- check(1): kitchenLamps:isOn  — lamp1 turns on
  -- check(2): kitchenLamps:isOff — lamp1 turns back off
  -- NOTE: kitchen.lamp1 starts off, lamp2 starts off.
  -- After this group, lamp1=off, lamp2=off.
  rule("once(kitchenLamps:isOn) => check(1)")
  rule("once(kitchenLamps:isOff) => check(2)")
  rule("wait(0); kitchen.lamp1:on")
  rule("wait(0.5); kitchen.lamp1:off")

  -- check(3): once({hall.motion1,hall.motion2}:breached) — use once() so later motion triggers don't re-fire
  -- check(4): trueFor safe on both motions
  -- hall.lamp starts off; motion1/2 start safe.
  rule("once({hall.motion1,hall.motion2}:breached) => hall.motion2:value=false; check(3)")
  rule("trueFor(00:00:02,{hall.motion1,hall.motion2}:safe) => hall.lamp1:off; check(4)")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 1: binarySwitch — isOn / isOff
  -- Uses kitchen.lamp2 (starts off). After group: lamp2=off.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(5): binarySwitch:isOn
  rule("once(kitchen.lamp3:isOn) => check(5)")
  rule("wait(0.1); kitchen.lamp3:on")

  -- check(6): binarySwitch:isOff
  rule("once(kitchen.lamp3:isOff) => check(6)")
  rule("wait(0.5); kitchen.lamp3:off")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 2: multilevelSwitch — on / off
  -- Uses hall.lamp (starts off). After group: hall.lamp=off.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(7): multilevelSwitch:isOn at value 99
  rule("once(hall.lamp2:isOn) => check(7)")
  rule("wait(1.0); hall.lamp2:on")

  -- check(8): multilevelSwitch:isOff at value 0
  rule("once(hall.lamp2:isOff) => check(8)")
  rule("wait(1.1); hall.lamp2:off")

  -- (not checked) set dimmer to 75 via :value assignment on a separate dimmer device
  rule("wait(1.2); livingRoom.dimmer:value = 75")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 3: doorSensor — breached / isClosed
  -- Uses hall.door1 (starts false/closed). After group: door1=false.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(9): doorSensor:breached (value=true)
  rule("once(hall.door1:breached) => check(9)")
  rule("wait(2.0); hall.door1:value = true")

  -- check(10): doorSensor:isClosed (value=false)
  rule("once(hall.door1:isClosed) => check(10)")
  rule("wait(2.1); hall.door1:value = false")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 4: windowSensor — breached / safe
  -- Uses livingRoom.window1 (starts false/safe). After group: window1=false.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(11): windowSensor:breached
  rule("once(livingRoom.window3:breached) => check(11)")
  rule("wait(3.0); livingRoom.window3:value = true")

  -- check(12): windowSensor:safe
  rule("once(livingRoom.window3:safe) => check(12)")
  rule("wait(3.1); livingRoom.window3:value = false")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 5: motionSensor — breached / safe
  -- Uses hall.motion1 (starts false/safe). After group: motion1=false.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(13): motionSensor:breached — also fires check(3) rule, but that uses once() so no double-fire
  rule("once(hall.motion3:breached) => check(13)")
  rule("wait(1.0); hall.motion3:value = true")

  -- check(14): motionSensor:safe — motion1 back to safe; triggers trueFor in check(4) countdown
  rule("once(hall.motion3:safe) => check(14)")
  rule("wait(1.4); hall.motion3:value = false")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 6: floodSensor — breached / safe
  -- Uses bedroom.flood1 (starts false). After group: flood1=false.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(15): floodSensor:breached
  rule("once(bedroom.flood1:breached) => check(15)")
  rule("wait(5.0); bedroom.flood1:value = true")

  -- check(16): floodSensor:safe
  rule("once(bedroom.flood1:safe) => check(16)")
  rule("wait(5.1); bedroom.flood1:value = false")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 7: smokeSensor — value true
  -- Uses bedroom.smoke1 (starts false). After group: smoke1=true (left on).
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(17): smokeSensor value becomes true
  rule("once(bedroom.smoke1:value == true) => check(17)")
  rule("wait(6.0); bedroom.smoke1:value = true")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 8: temperatureSensor — temp rises above threshold
  -- Uses bedroom.temp1 (starts nil). After group: temp1={value=25,unit='C'}.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(18): temp > 24
  rule([[once(bedroom.temp1:temp > 24) => check(18)]])
  rule("wait(7.0); bedroom.temp1:value = {value=25, unit='C'}")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 9: humiditySensor — value rises above threshold
  -- Uses bedroom.humid1 (starts nil). After group: humid1=90.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(19): humidity > 80
  rule([[once(bedroom.humid1:value > 80) => check(19)]])
  rule("wait(8.0); bedroom.humid1:value = 90")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 10: colorController — isOn
  -- Uses entertainment.light1 (starts off). After group: light1=off.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(20): colorController:isOn
  rule("once(entertainment.light1:isOn) & entertainment.light1:value ~= 75 => check(20)")
  rule("wait(9.0); entertainment.light1:on")

  -- (not checked) turn off again and set a brightness value
  rule("wait(9.1); entertainment.light1:off")
  rule("wait(9.2); entertainment.light1:value = 75")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 11: player — volume rises above threshold
  -- Uses entertainment.player1 (starts nil volume). After group: volume=80.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(21): player volume > 50
  rule([[once(entertainment.player1:volume > 50) => check(21)]])
  rule("wait(10.0); entertainment.player1:volume = 80")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 12: energyMeter — value rises above threshold
  -- Uses outdoor.energy1 (starts nil). After group: energy1=226.
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(22): energy value > 200
  rule([[once(outdoor.energy1:value > 200) => check(22)]])
  rule("wait(11.0); outdoor.energy1:value = 226.137")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 13: window set — any window in set breached
  -- Uses livingRoom.window2 (starts false; window1 already safe from group 4).
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(23): any window in set breached — use window2 so window1 rule (group 4) is already once()'d
  rule("once({livingRoom.window1,livingRoom.window2}:breached) => check(23)")
  rule("wait(12.0); livingRoom.window2:value = true")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 14: trueFor — sustained breach fires rule
  -- Uses hall.motion2 (starts false; distinct from motion1 used in groups 3/5).
  -- motion2 is set true at 13.0s; trueFor(2s) fires ~15s → check(24).
  -- ────────────────────────────────────────────────────────────────────────────

  -- check(24): motion2 breached for 2 seconds
  rule([[trueFor(00:00:02,hall.motion2:breached) => check(24)]])
  rule("wait(13.0); hall.motion2:value = true")

end

function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
    fibaro.EventRunner(main)
end