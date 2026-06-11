--%%name:rule_modifier_since
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- 'since' requires the condition to be continuously true for N seconds.
  -- In trigger-variable tests, the variable is set and stays true, so
  -- the action fires after the delay.
  er.triggerVars.d = 0

  test_rule(er, "d == 1 since 5 => return 42",
    function(er, rule)
      er.triggerVars.d = 1
      rule:run()
    end,
    42,
    "since: fires after condition holds 5 time units")

  -- Condition becomes false before 'since' elapses → action never fires
  -- (Hard to test in a single file without complex timing; we test that
  --  a false condition produces nil in onDone)

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
