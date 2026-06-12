--%%name:rule_time_triggers
--%%headers:EventRunner.inc
--%%file:$fibaro.lib.speed,speed
--%%file:test/harness.lua,harness
--%%offline:true
--%%time:2026/06/12 07:00:00

local function main(er)
  er.triggerVars.daily_fired = false
  er.triggerVars.interval_count = 0
  er.triggerVars.multi_fired = 0

  -- @ daily trigger: fire at 08:00
  er.eval("@08:00 => daily_fired = true")

  -- @@ interval trigger: fire every 5 minutes
  er.eval("@@00:05 => interval_count = interval_count + 1")

  -- @@ clock-aligned interval
  er.eval("@@-01:00 => multi_fired = multi_fired + 1")

  -- Assertions deferred until after speedTime advances past the triggers.
  -- setTimeout uses simulated time when wrapped by speedTime.
  setTimeout(function()
    assert_truthy(er.triggerVars.daily_fired, "@ daily: fired at 08:00")
    assert_truthy(er.triggerVars.interval_count >= 20,
      "@@ interval: fired repeatedly (count=" .. er.triggerVars.interval_count .. ")")
    assert_truthy(er.triggerVars.multi_fired >= 2,
      "@@- clock-aligned: fired at 08:00 and 09:00 (count=" .. er.triggerVars.multi_fired .. ")")
    done()
  end, 3 * 3600 * 1000)  -- 3 hours simulated
end

function QuickApp:onInit()
  -- speedTime wraps EventRunner boot so rules fire during simulation
  fibaro.speedTime(4, function()
    fibaro.EventRunner(main)
  end)
end
