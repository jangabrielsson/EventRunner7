--%%name:rule_modifier_single
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- Without 'single': second trigger while waiting is ignored, action runs once
  er.triggerVars.s1 = 0
  test_rule(er, "s1 == 1 => wait(10); return 1",
    function(er, rule)
      er.triggerVars.s1 = 1
      rule:run()
      -- Fire again while first run is still in wait(10)
      -- Without single, this second trigger is blocked
      er.triggerVars.s1 = 1
      rule:run()
    end,
    1,
    "no single: second trigger blocked")

  -- With 'single': second trigger cancels pending wait, restarts timer
  er.triggerVars.s2 = 0
  test_rule(er, "s2 == 1 single => wait(10); return 2",
    function(er, rule)
      er.triggerVars.s2 = 1
      rule:run()
      er.triggerVars.s2 = 1
      rule:run()
    end,
    2,
    "single: second trigger restarts")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
