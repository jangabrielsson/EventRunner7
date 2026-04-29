--%%name:Test ground
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:$fibaro.lib.speed,speed
--%%file:tests/testfuns.lua,test
--%%time:2026/04/28 12:00:00

local function main(er) ER = er
  local rule, test = er.eval, er.test
  local function loadDevice(name) return er.loadDevice(name) end

  --api.post("/globalVariables",{name = "G_foo",value = "66"})
  er.defglobals.light1 = loadDevice("binarySwitch")
  er.defglobals.light2 = loadDevice("binarySwitch")
  er.defglobals.motion1 = loadDevice("motionSensor")
  er.defglobals.door1 = loadDevice("doorSensor")
  er.defglobals.window1 = loadDevice("windowSensor")
  er.defglobals.window2 = loadDevice("windowSensor")
  er.defglobals.fire1 = loadDevice("fireDetector")

  fibaro.debugFlags.post = true
  test("#bar1{a=5,b='$x>79'} => return x","post(#bar1{a=5,b=88})",{88})
  test([[#bar1{a=5,b='$x==abc'} => return x]],"post(#bar1{a=5,b='abc'})",{'abc'})
  test([[#bar1{a=5,b='$x<>Atfrb'} => return x]],"post(#bar1{a=5,b='tfr'})",{'tfr'})
end


function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  local t = os.time()
  fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    fibaro.EventRunner(main)
  end)
end