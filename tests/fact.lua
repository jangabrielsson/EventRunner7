--%%name:EventRunnerTest
--%%type:com.fibaro.deviceController
--%%include:../EventRunner.inc
--%%mode:offline
--%%file:../src/Sim.lua,sim
--%%file:../tests/testfuns.lua,test
--%%time:2026/04/28 12:00:00

local function main(er) ER = er
  local rule, variables, test = er.eval, er.variables, er.test
  local function loadDevice(name) return er.loadSimDevice(name) end

  rule([[fact = function(n,f)
    if n == 0 then return 1 end
    return n * f(n-1,f)
  end]])
  rule([[t0 = os.clock(); b = fact(20,fact); log(os.clock()-t0)]])

  local function fact(n)
    if n == 0 then return 1 end
    return n * fact(n-1)
  end
  local t0 = os.clock()
  local b = fact(20)
  print(0.012349 / (os.clock()-t0))
end

function QuickApp:onInit()
  -- local profile = require("tests/profile")
  -- profile.start()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.EventRunner(main)
  os.exit(0)  -- benchmarks print during boot; ER's midnight loop would otherwise keep the run alive
  --setTimeout(function() 
  --  profile.stop()
    -- report for the top 10 functions, sorted by execution time
  --  print(profile.report(20))
  -- end, 20*1000) -- stop the test after 20 seconds of real time, which should be enough for all the rules to have triggered
end