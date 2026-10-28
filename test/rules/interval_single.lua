--%%name:rule_interval_single
--%%include:../../EventRunner.inc
--%%file:../../test/speed.lua,speed
--%%file:../../test/harness.lua,harness
--%%mode:offline
--%%time:2026/06/12 07:00:00

-- Regression: single's killTimers must not cancel the interval scheduler.
-- (It briefly was when the interval timer was tracked in rule.timers,
-- which killed interval+single rules after their first fire.)

local function main(er)
  er.triggerVars.n = 0
  er.eval("@@00:05 single => n = n + 1")

  setTimeout(function()
    assert_truthy(er.triggerVars.n >= 3,
      "interval keeps firing under single (count=" .. er.triggerVars.n .. ")")
    done()
  end, 20 * 60000)
end

function QuickApp:onInit() fibaro.speedTime(4, function() fibaro.EventRunner(main) end) end
