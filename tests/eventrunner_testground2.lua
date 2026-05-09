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

fibaro.plua.lib.loadQAString([[
  function publish(pevent)
    pevent._from = plugin.mainDeviceId
    pevent._published = true
    fibaro.setGlobalVariable("ER_subscription", json.encode(pevent))
  end

    function QuickApp:onInit()
      self:debug("MyDevice class loaded")
      setTimeout(function()
        print("Publish")
        publish({type='foppa', value=42})
      end, 2000)
    end
  ]])


local function main(er) ER = er
  local rule, test = er.eval, er.test
  local function loadDevice(name) return er.loadSimDevice(name) end

  rule("subscribe(#foppa)")
  rule("#foppa => log('FOPPA!')")
end

function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  --fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    setTimeout(function() fibaro.EventRunner(main) end, 100)
  --end)
end