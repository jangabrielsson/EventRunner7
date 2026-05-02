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
-- We alway start at 2026/04/28 12:00:00
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
      door1 = loadDevice("doorSensor"),
    },
    livingRoom = {
      window1 = loadDevice("windowSensor"),
      window2 = loadDevice("windowSensor"),
      fire1 = loadDevice("fireDetector"),
    }
  }
  -- populate variables with the HomeTable so we can access devices as kitchen.lamp1 etc in rules, and also kitchenLamps later on.
  for k,v in pairs(HT) do variables[k] = v end


  rule("kitchenLamps = {kitchen.lamp1,kitchen.lamp2}")
  --fibaro.debugFlags.sourceTrigger = true

  rule("once({kitchen.lamp1,kitchen.lamp2}:isOn) => log('On')")
  rule("once({kitchen.lamp1,kitchen.lamp2}:isOff) => log('Off')")
  rule("wait(0); kitchen.lamp1:on")
  rule("wait(10); kitchen.lamp1:off")
  rule("wait(20); kitchenLamps:on")
  rule("wait(40); kitchenLamps:off")
  rule("wait(60); kitchenLamps:on")
  rule("wait(80); kitchenLamps:off")
end

function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
    fibaro.EventRunner(main)
end