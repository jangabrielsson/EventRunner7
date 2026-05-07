--%%name:Test ground
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:$fibaro.lib.speed,speed
--%%file:tests/testfuns.lua,test
--%%file:Sim.lua,sim
--%%time:2026/04/28 12:00:00

-- Scratch pad for testing new feature. Actual test suite to go into
-- eventrunner_test.lua once we have a stable set of features to test.

local function main(er) ER = er
  local rule, test = er.eval, er.test
  local function loadDevice(name) return er.loadSimDevice(name) end

  er.createSimGlobal("G_foo","15:00")
  er.createSimGlobal("G_bar","66")
  er.createSimGlobal("TimeGV","13:00")
  er.defglobals.light1 = loadDevice("binarySwitch")
  er.defglobals.light2 = loadDevice("binarySwitch")
  er.defglobals.motion1 = loadDevice("motionSensor")
  er.defglobals.door1 = loadDevice("doorSensor")
  er.defglobals.window1 = loadDevice("windowSensor")
  er.defglobals.window2 = loadDevice("windowSensor")
  er.defglobals.fire1 = loadDevice("fireDetector")
  er.defglobals.temp1 = loadDevice("temperatureSensor")
  er.defglobals.temp2 = loadDevice("temperatureSensor")
  er.defglobals.temp3 = loadDevice("temperatureSensor")
  
  rule("temp1:value = 10; temp2:value = 20; temp3:value = 30")

  er.definePropClass("MyDevice")
  function MyDevice:__init() self.value = 21; er.PropObject.__init(self) end
  function MyDevice.getProp:temp() return self.value end
  function MyDevice.setProp:temp(prop, value) self.value = value return true end
  function MyDevice.map.temp(fun,list) 
    local sum = 0
    for _,v in ipairs(list) do sum = sum + fun(v) end
    return sum
  end
  er.defglobals.mydev = MyDevice()

  rule("temps = { mydev, temp1, temp2, temp3}")
  rule("json.encode(temps:temp)")
end


function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    fibaro.EventRunner(main)
  end)
end