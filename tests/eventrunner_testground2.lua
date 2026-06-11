--%%name:Test ground
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%% offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:src/Setup.lua,stdfuns
--%%file:$fibaro.lib.speed,speed
--%%file:tests/testfuns.lua,test
--%%file:src/Sim.lua,sim
-- %%time:2026/04/28 07:00:00

-- Scratch pad for testing new feature. Actual test suite to go into
-- eventrunner_test.lua once we have a stable set of features to test.


local function main(er) ER = er
  local rule, var, tvar, test = er.eval, er.variables, er.triggerVars, er.test
  local function loadDevice(name) return er.loadSimDevice(name) end

  local HT = {
    blinds_living_room = loadDevice("rollerShutter"),
    blind_Nr_4  = loadDevice("rollerShutter"),
    door_bow_tie = loadDevice("doorSensor"),
    appPhone = { alarm_Ring = loadDevice("binarySwitch") }
  }

  er.defvars(HT)

  --rule("@@00:00:10 => 4304:off")
  rule("4304:value ~= nil => log('%s, %s event',4304:manual ,4304:manual >= 0 & 'manual' or 'script')")
  rule("4304:toggle")
end
 
function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  --fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    setTimeout(function() fibaro.EventRunner(main) end, 100)
  --end)
end