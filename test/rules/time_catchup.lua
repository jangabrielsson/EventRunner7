--%%name:rule_time_catchup
--%%headers:EventRunner.inc
--%%file:$fibaro.lib.speed,speed
--%%file:test/harness.lua,harness
--%%offline:true
--%%time:2026/06/12 09:00:00

local function main(er)
  -- Booted at 09:00, past 08:00 trigger time
  assert_truthy(er.eval("return now") >= 32400, "booted at 09:00")

  -- catchup: should fire immediately
  er.triggerVars.caught = false
  er.eval("@{08:00,catch} => caught = true")

  -- no catch: should NOT fire (time already passed)
  er.triggerVars.not_caught = false
  er.eval("@08:00 => not_caught = true")

  setTimeout(function()
    assert_truthy(er.triggerVars.caught, "@{08:00,catch}: fired on catchup")
    assert_eq(er.triggerVars.not_caught, false, "@08:00 no catch: did NOT fire")
    done()
  end, 500)
end

function QuickApp:onInit()
  fibaro.speedTime(2, function()
    fibaro.EventRunner(main)
  end)
end
