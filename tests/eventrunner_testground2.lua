--%%name:Test ground
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%% offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:Setup.lua,stdfuns
--%%file:$fibaro.lib.speed,speed
--%%file:tests/testfuns.lua,test
--%%file:Sim.lua,sim
--%% time:2026/04/28 12:00:00

-- Scratch pad for testing new feature. Actual test suite to go into
-- eventrunner_test.lua once we have a stable set of features to test.


local function main(er) ER = er
  local rule, var, tvar, test = er.eval, er.variables, er.triggerVars, er.test
  local function loadDevice(name) return er.loadSimDevice(name) end

  local HT = {
    motion = loadDevice("motionSensor"),
    light  = loadDevice("multilevelSwitch"),
  }

  er.defvars(HT)

  -- rule("t0=now")
  -- rule("motion:breached single => light:on; wait(00:05); light:off; log('T:%s',HMS(now-t0))")

  -- rule("motion:value=true; wait(00:02); motion:value=false; wait(1); motion:value=true")

  rule("@now+1 & wday('last') => log('tick')")

end

function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    setTimeout(function() fibaro.EventRunner(main) end, 100)
  end)
end