--%%name:rule_async_cancel
--%%include:../../EventRunner.inc
--%%file:../../test/harness.lua,harness
--%%mode:offline

-- single + async: re-triggering must cancel the old run's watchdog timer
-- (all timers tracked in rule.timers) and discard late callbacks from the
-- superseded run (run generation guard). Without the guard, the stale
-- callback resumes the old run and its result wins.

local cbs = {}

local function main(er)
  er.triggerVars.d = 0

  er.async.fetch = function(cb, v)
    cbs[#cbs + 1] = cb
    return true, 10000  -- async: watchdog 10s
  end

  test_rule(er, "d == 1 single => return fetch(1)",
    function(er, rule)
      er.triggerVars.d = 1
      rule:run()          -- run 1 suspends on fetch, watchdog armed
      local cb1 = cbs[1]
      rule:run()          -- single: cancels run 1 watchdog, bumps generation
      local cb2 = cbs[2]
      cb1(99)             -- stale callback from superseded run: must be discarded
      cb2(42)             -- current run's callback: resumes and returns 42
    end,
    42,
    "single + async: stale callback from superseded run is discarded")

  done()
end

function QuickApp:onInit() fibaro.EventRunner(main) end
