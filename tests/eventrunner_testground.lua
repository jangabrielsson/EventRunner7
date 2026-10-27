--%%name:Test ground
--%%type:com.fibaro.deviceController
--%%include:../EventRunner.inc
--%%mode:offline
--%%file:../tests/testfuns.lua,test
--%%file:../src/Sim.lua,sim
--%%time:2026/04/28 10:10:00

-- Scratch pad for testing new feature. Actual test suite to go into
-- eventrunner_test.lua once we have a stable set of features to test.

local function main(er) ER = er
  local rule, var, tvar, test = er.eval, er.variables, er.triggerVars, er.test
  local function loadDevice(name) return er.loadSimDevice(name) end

  -- tvar.x = 0

  -- rule("x single => wait(2); log('hup')")

  -- rule([[
  --    x=1; wait(1);
  --    x=2
  -- ]])
  rule("#foo => log('foo')")
  rule("post(#foo)")

end


function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.EventRunner(main)
end