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
  fibaro.debugFlags.sourceTrigger = true

  local function createGlobal(name,value)
    api.post("/globalVariables", {name=name, value=value})
  end

  local checks, nChecks = {},10
  function variables.check(n)
    if checks[n] then print("❌  Check "..n.." already checked") return end
    checks[n] = true
    local done = true
    print("✅",n,"done")
    for i=1,nChecks do if not checks[i] then done = false; break end end
    if done then print("✅ All "..nChecks.." checks passed, test complete") end
  end

  rule("kitchenLamps = {kitchen.lamp1,kitchen.lamp2}") -- test creating a variable with a table of devices, and that it works in rules

  rule("kitchen.lamp1:value = false")
  rule("kitchen.lamp1:value => check(1)") -- test that the rule is triggered by the change to lamp1
  rule("kitchen.lamp1:value = true")
  
  rule("kitchen.lamp1:state = false")
  rule("kitchen.lamp1:state => check(2)") -- test that the rule is triggered by the change to lamp1
  rule("kitchen.lamp1:state = true")

  rule("kitchen.lamp1:bat => check(3)") -- test that the rule is triggered by the change to lamp1
  rule("kitchen.lamp1:prop = {'batteryLevel', 50}")

  rule("kitchen.lamp1:isDead => check(4)") -- test that the rule is triggered by the change to lamp1
  rule("kitchen.lamp1:prop = {'dead', true}")

  rule("!{kitchen.lamp1,kitchen.lamp2}:isDead => check(5)") -- test :isDead reduces to false if all of the devices in the list are dead
  rule("wait(2); kitchen.lamp1:prop = {'dead', false}")

  rule("hall.lamp1:isOn => hall.lamp1:off; check(6)") 
  rule("hall.lamp1:isOff => check(7)") 
  rule("{hall.lamp1,hall.lamp2}:isOn =>  check(8)") -- reduce behaviour, when lamp1 turns on.
  rule("hall.lamp1:on")

  rule("security.remote1:central.keyId == 3 => check(9)") -- test that we can trigger on remote controller events
  rule("security.remote1:key.id==2 => check(10)") -- test that we can trigger on remote controller events
  rule("security.remote1:simKey = {keyId=3,keyAttribute='Pressed'}")
  rule("security.remote1:simKey = {keyId=2,keyAttribute='Pressed'}")

end

function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
    fibaro.EventRunner(main)
end