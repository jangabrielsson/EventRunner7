--%%name:rule_midnight_loop
--%%include:../../EventRunner.inc
--%%file:../../test/speed.lua,speed
--%%file:../../test/harness.lua,harness
--%%mode:offline
--%%time:2026/11/10 23:59:59

-- Regression: the midnight loop must survive rules that have no setupDaily
-- method. After the compRule lifecycle refactor, interval-only rules lost
-- their no-op setupDaily (setupDailys is skipped when an interval trigger
-- is present), so the first midnight after boot crashed the loop's timer
-- handler ("attempt to call a nil value (method 'setupDaily')" at
-- rule.lua:165), killing daily re-arming permanently — user-reported:
-- daily rules stop triggering, error logged at 00:00:01.
--
-- Boot is pinned to 23:59:59 so the 23:59:57 daily has already passed and
-- is NOT armed at boot: it can only fire at 23:59:57 the NEXT day, and only
-- if the midnight loop survived. The interval rule is registered first so
-- that, without the fix, the loop crashes on it before reaching the daily.

local function main(er)
  er.triggerVars.daily_count = 0
  er.triggerVars.interval_ticks = 0

  -- interval rule first: pre-fix this is the first rule the midnight loop
  -- reaches, and the crash aborts the loop before the daily rule below is
  -- re-armed for the new day.
  er.eval("@@00:00:10 => interval_ticks = interval_ticks + 1")

  -- the user's daily pattern: time trigger posting an event rule
  er.eval("@23:59:57 => post(#resetConsumptions)")
  er.eval([==[#resetConsumptions => daily_count = daily_count + 1]==])

  -- Assert just after the next day's daily trigger (+24h - 1s = 23:59:58).
  setTimeout(function()
    assert_truthy(er.triggerVars.daily_count == 1,
      "daily re-armed by midnight loop despite interval rule (count=" ..
      er.triggerVars.daily_count .. ")")
    done()
  end, 86399 * 1000)
end

function QuickApp:onInit() fibaro.speedTime(4, function() fibaro.EventRunner(main) end) end
