--%%name:rule_since_single
--%%include:../../EventRunner.inc
--%%file:../../test/harness.lua,harness
--%%mode:offline

-- Regression: single + since used to wedge. killTimers cancelled the pending
-- trueFor timer but left trueFor.ref set, so every later evaluation saw a
-- non-nil ref and the condition could never become true again.
-- Re-triggering must restart the since window, not wedge it.

local function main(er)
  er.triggerVars.d = 0

  -- Re-trigger while the since window is pending: single cancels the old
  -- window; the fresh evaluation must start a new window and eventually fire.
  test_rule(er, "d == 1 single since 3 => return 42",
    function(er, rule)
      er.triggerVars.d = 1
      rule:run()  -- starts since window (3s timer)
      rule:run()  -- single: cancels pending window, must restart fresh
    end,
    42,
    "single + since: re-trigger restarts the window")

  -- Same wedge via terminate(): cancels timers; next run must recover.
  test_rule(er, "d == 1 since 3 => return 43",
    function(er, rule)
      er.triggerVars.d = 1
      rule:run()
      rule:terminate()
      rule:run()
    end,
    43,
    "terminate + since: next run restarts the window")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
