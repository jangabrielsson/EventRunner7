--%%name:Test ground
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%% offline:true

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
 
  rule("@{catch,10:27:40} => log('OK')",{verbosity='verbose'})
end
 
function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    setTimeout(function() fibaro.EventRunner(main) end, 100)
  end)
end