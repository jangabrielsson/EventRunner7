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
    },
    hall = {
      motion1 = loadDevice("motionSensor"),
      motion2 = loadDevice("motionSensor"),
      door1 = loadDevice("doorSensor"),
      lamp = loadDevice("multilevelSwitch"),
    },
    livingRoom = {
      window1 = loadDevice("windowSensor"),
      window2 = loadDevice("windowSensor"),
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

  local dev = api.get("/devices/5560")
  -- populate variables with the HomeTable so we can access devices as kitchen.lamp1 etc in rules, and also kitchenLamps later on.
  for k,v in pairs(HT) do variables[k] = v end
  --fibaro.debugFlags.refreshEvents = true

  local function createGlobal(name,value)
    api.post("/globalVariables", {name=name, value=value})
  end
  rule("kitchenLamps = {kitchen.lamp1,kitchen.lamp2}") -- test creating a variable with a table of devices, and that it works in rules

  local checks, nChecks = {},2
  function variables.check(n)
    if checks[n] then print("❌  Check "..n.." already checked") end
    checks[n] = true
    for i=1,nChecks do if not checks[i] then return end end
    print("✅ All checks passed, test complete")
  end

  -- Test rules with device sets and properties. These should trigger in sequence as the lamps are turned on and off.
  rule("once(kitchenLamps:isOn) => check(1)")
  rule("once(kitchenLamps:isOff) => check(2)")
  rule("wait(0); kitchen.lamp1:on")
  rule("wait(0.1); kitchen.lamp1:off")

  -- Turn on lamp when motion is detected.
  rule("{hall.motion1,hall.motion2}:breached => hall.lamp:on; check(3)")
  -- and turn off when safe for 5min
  rule("trueFor(00:05,{hall.motion1,hall.motion2}:safe) => hall.lamp:off; check(4)")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 1: binarySwitch — value, isOn, isOff, on/off actions
  -- ────────────────────────────────────────────────────────────────────────────

  -- Turn the switch on and verify :isOn triggers
  rule("once(kitchen.lamp2:isOn) => log('PASS binarySwitch:isOn triggered')")
  rule("wait(0.2); kitchen.lamp2:on")

  -- Turn the switch off and verify :isOff triggers
  rule("once(kitchen.lamp2:isOff) => log('PASS binarySwitch:isOff triggered')")
  rule("wait(0.3); kitchen.lamp2:off")

  -- :value property read in expression
  rule("wait(0.4); kitchen.lamp2:on")
  rule("wait(0.5); if kitchen.lamp2:value == true then log('PASS binarySwitch:value == true') end")

  -- :isAllOn — true only when every device in the set is on
  rule("kitchenLamps:isAllOn => log('PASS kitchenLamps:isAllOn')")
  rule("wait(0.6); kitchen.lamp1:on; kitchen.lamp2:on")

  -- :isAnyOff — triggers when at least one lamp goes off
  rule("kitchenLamps:isAnyOff => log('PASS kitchenLamps:isAnyOff')")
  rule("wait(0.7); kitchen.lamp2:off")

  -- :toggle — should flip from off to on
  rule("once(kitchen.lamp2:isOn) => log('PASS binarySwitch:toggle worked')")  -- already on; toggle expected on lamp2 which is off
  rule("wait(0.8); kitchen.lamp2:toggle")  -- lamp2 is off, toggles to on

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 2: multilevelSwitch — value, setValue, on/off
  -- ────────────────────────────────────────────────────────────────────────────

  -- Set dimmer to 50% and read back :value
  rule([[hall.lamp:value > 40 => log('PASS multilevelSwitch value > 40')]])
  rule("hall.lamp:value = 50")

  -- Turn dimmer fully on (value = 99)
  rule("once(hall.lamp:isOn) => log('PASS multilevelSwitch:isOn at 99')")
  rule("wait(1.1); hall.lamp:on")

  -- Turn dimmer fully off (value = 0)
  rule("once(hall.lamp:isOff) => log('PASS multilevelSwitch:isOff at 0')")
  rule("wait(1.2); hall.lamp:off")

  -- livingRoom dimmer to 75
  rule([[livingRoom.dimmer:value > 70 => log('PASS dimmer value > 70')]])
  rule("wait(1.3); livingRoom.dimmer:value = 75")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 3: doorSensor — breached / isClosed / isOpen
  -- ────────────────────────────────────────────────────────────────────────────

  rule("hall.door1:breached => log('PASS doorSensor:breached')")
  rule("wait(2.0); hall.door1:value = true")

  -- isClosed / isOpen aliases for door value
  rule("hall.door1:isOpen => log('PASS doorSensor:isOpen')")
  rule("hall.door1:isClosed => log('PASS doorSensor:isClosed')")
  rule("wait(2.1); hall.door1:value = false")  -- close the door (should fire isClosed next event)

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 4: windowSensor — breached / safe
  -- ────────────────────────────────────────────────────────────────────────────

  rule("livingRoom.window1:breached => log('PASS windowSensor:breached')")
  rule("livingRoom.window1:safe    => log('PASS windowSensor:safe')")
  rule("wait(3.0); livingRoom.window1:value = true")   -- breach
  rule("wait(3.1); livingRoom.window1:value = false")  -- safe

  -- multiple windows — any breach in a set
  rule("{livingRoom.window1,livingRoom.window2}:breached => log('PASS window set any:breached')")
  rule("wait(3.2); livingRoom.window2:value = true")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 5: motionSensor — breached / safe
  -- ────────────────────────────────────────────────────────────────────────────

  rule("hall.motion1:breached => log('PASS motionSensor:breached')")
  rule("wait(4.0); hall.motion1:value = true")

  rule("hall.motion1:safe => log('PASS motionSensor:safe')")
  rule("wait(4.1); hall.motion1:value = false")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 6: floodSensor — value/breached
  -- ────────────────────────────────────────────────────────────────────────────

  rule("bedroom.flood1:breached => log('PASS floodSensor:breached')")
  rule("wait(5.0); bedroom.flood1:value = true")

  rule("bedroom.flood1:safe => log('PASS floodSensor:safe')")
  rule("wait(5.1); bedroom.flood1:value = false")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 7: smokeSensor — value
  -- ────────────────────────────────────────────────────────────────────────────

  rule("bedroom.smoke1:value == true => log('PASS smokeSensor:value true')")
  rule("wait(6.0); bedroom.smoke1:value = true")

  rule("bedroom.smoke1:value == false => log('PASS smokeSensor:value false')")
  rule("wait(6.1); bedroom.smoke1:value = false")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 8: temperatureSensor — temp / value
  -- ────────────────────────────────────────────────────────────────────────────

  -- Note: HC3 temperatureSensor stores value as {value=n, unit="C"}; :temp reads .value
  rule([[bedroom.temp1:temp > 24 => log('PASS temperatureSensor:temp > 24')]])
  rule("wait(7.0); bedroom.temp1:value = {value=25, unit='C'}")

  rule([[bedroom.temp1:temp < 10 => log('PASS temperatureSensor:temp < 10')]])
  rule("wait(7.1); bedroom.temp1:value = {value=5, unit='C'}")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 9: humiditySensor — value
  -- ────────────────────────────────────────────────────────────────────────────

  rule([[bedroom.humid1:value > 80 => log('PASS humiditySensor:value > 80')]])
  rule("wait(8.0); bedroom.humid1:value = 90")

  rule([[bedroom.humid1:value < 50 => log('PASS humiditySensor:value < 50')]])
  rule("wait(8.1); bedroom.humid1:value = 40")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 10: alarmPartition — armed / isArmed / isDisarmed
  -- ────────────────────────────────────────────────────────────────────────────

  -- alarmPartition uses fibaro alarm API; these may not work fully offline
  -- but the rule parsing + action dispatch should be exercised
  rule("security.alarm1:isArmed   => log('PASS alarmPartition:isArmed')")
  rule("security.alarm1:isDisarmed => log('PASS alarmPartition:isDisarmed')")
  rule("wait(9.0); security.alarm1:armed = true")
  rule("wait(9.1); security.alarm1:armed = false")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 11: remoteController — central scene / key events
  -- ────────────────────────────────────────────────────────────────────────────

  -- central scene event: keyId=1, keyAttribute="Pressed"
  rule([[security.remote1:central.keyId == 1 => log('PASS remoteController central keyId 1')]])
  rule([[security.remote1:key == '1:Pressed' => log('PASS remoteController key 1:Pressed')]])
  rule("wait(10.0); security.remote1:simKey = {keyId=1, keyAttribute='Pressed'}")

  -- second button press
  rule([[security.remote1:central.keyId == 2 => log('PASS remoteController central keyId 2')]])
  rule("wait(10.1); security.remote1:simKey = {keyId=2, keyAttribute='Pressed'}")

  -- HeldDown attribute
  rule([[security.remote1:key == '1:HeldDown' => log('PASS remoteController key 1:HeldDown')]])
  rule("wait(10.2); security.remote1:simKey = {keyId=1, keyAttribute='HeldDown'}")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 12: colorController — value / color / on / off / setValue / setColor
  -- ────────────────────────────────────────────────────────────────────────────

  rule("once(entertainment.light1:isOn) => log('PASS colorController:isOn')")
  rule("wait(11.0); entertainment.light1:on")

  rule("once(entertainment.light1:isOff) => log('PASS colorController:isOff')")
  rule("wait(11.1); entertainment.light1:off")

  rule([[entertainment.light1:value > 60 => log('PASS colorController:value > 60')]])
  rule("wait(11.2); entertainment.light1:value = 75")

  -- setColor: r=200 g=10 b=100 w=255 — value stored as "r,g,b,w" string
  rule([[entertainment.light1:value > 0 => log('PASS colorController:setColor triggered value update')]])
  rule("wait(11.3); entertainment.light1:color = {200,10,100,255}")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 13: player — volume / play / pause / setVolume
  -- ────────────────────────────────────────────────────────────────────────────

  rule([[entertainment.player1:volume > 50 => log('PASS player:volume > 50')]])
  rule("wait(12.0); entertainment.player1:volume = 80")

  rule([[entertainment.player1:volume < 30 => log('PASS player:volume < 30')]])
  rule("wait(12.1); entertainment.player1:volume = 20")

  -- play / pause actions just dispatch (player sim does not update a state property)
  rule("wait(12.2); entertainment.player1:play")
  rule("wait(12.3); entertainment.player1:pause")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 14: energyMeter — value (kWh)
  -- ────────────────────────────────────────────────────────────────────────────

  rule([[outdoor.energy1:value > 200 => log('PASS energyMeter:value > 200')]])
  rule("wait(13.0); outdoor.energy1:value = 226.137")

  rule([[outdoor.energy1:power > 0 => log('PASS energyMeter:power > 0')]])
  rule("wait(13.1); outdoor.energy1:value = 250")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 15: device sets — mixed property conditions
  -- ────────────────────────────────────────────────────────────────────────────

  -- Trigger when any sensor in a set is breached
  rule("allBreachSensors = {bedroom.flood1, hall.motion2, livingRoom.window2}")
  rule("allBreachSensors:breached => log('PASS mixed sensor set any:breached')")
  rule("wait(14.0); hall.motion2:value = true")

  -- Action on a set of switches: turn all off at once
  rule("wait(14.1); {kitchen.lamp1,kitchen.lamp2}:off")
  rule("once({kitchen.lamp1,kitchen.lamp2}:isOff) => log('PASS set :off action both off')")

  -- once() guard — should only fire once across repeated triggers
  local onceCount = 0
  function variables.countOnce() onceCount = onceCount + 1; if onceCount > 1 then print('❌ once() fired more than once') else print('PASS once() fired exactly once') end end
  rule("once(livingRoom.window1:breached) => countOnce()")
  rule("wait(14.2); livingRoom.window1:value = true")
  rule("wait(14.3); livingRoom.window1:value = false")
  rule("wait(14.4); livingRoom.window1:value = true")  -- should NOT fire countOnce() again

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 16: :last — time since last value change
  -- ────────────────────────────────────────────────────────────────────────────

  -- :last returns seconds since last property change; after a fresh set it should be near 0
  rule("wait(15.0); hall.door1:value = true")
  rule([[wait(15.1); if hall.door1:last < 5 then log('PASS :last < 5 seconds after update') end]])

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 17: global variable triggers
  -- ────────────────────────────────────────────────────────────────────────────

  createGlobal("alarmMode", "off")

  -- rule([[#alarmMode == 'night' => log('PASS globalVar alarmMode == night')]])
  -- rule("wait(16.0); #alarmMode = 'night'")

  -- rule([[#alarmMode == 'off' => log('PASS globalVar alarmMode == off')]])
  -- rule("wait(16.1); #alarmMode = 'off'")

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 18: trueFor with sensor condition
  -- ────────────────────────────────────────────────────────────────────────────

  -- waitFor(duration, condition) — fires when condition has been true for duration
  -- Using a very short duration (0.5s) so the test completes without speedTime
  rule("wait(17.0); bedroom.temp1:value = {value=30, unit='C'}")
  rule([[trueFor(00:00:01,bedroom.temp1:temp > 28) => log('PASS trueFor temp > 28 for 1s')]])

  -- ────────────────────────────────────────────────────────────────────────────
  -- TEST GROUP 19: trueFor with short sensor condition
  -- ────────────────────────────────────────────────────────────────────────────

  rule("wait(18.0); hall.motion2:value = true")
  rule([[trueFor(00:00:01,hall.motion2:breached) => log('PASS trueFor motion2:breached for 1s')]])

end

function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
    fibaro.EventRunner(main)
end