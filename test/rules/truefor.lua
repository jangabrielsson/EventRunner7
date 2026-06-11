--%%name:rule_truefor
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- trueFor: condition must be continuously true for N seconds.
  -- When using trigger variables, setting the var = 1 makes it
  -- continuously true, so the action fires after the delay.
  er.triggerVars.tf = 0

  test_rule(er, "trueFor(5, tf == 1) => return 'done'",
    function(er, rule)
      er.triggerVars.tf = 1
      rule:run()
    end,
    "done",
    "trueFor: fires after condition holds")

  -- After triggering, changing the variable to 0 should cancel trueFor
  -- (not tested here — requires explicit timing control)

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
