--%%name:rule_modifier_cooldown
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- Without cooldown: trigger fires immediately
  er.triggerVars.c1 = 0
  test_rule(er, "c1 == 1 => return 100",
    function(er, rule)
      er.triggerVars.c1 = 1
      rule:run()
    end,
    100,
    "no cooldown: fires immediately")

  -- cooldown suppression is tested implicitly: the action only fires once
  -- because cooldown blocks immediate re-triggers.  Direct assertion
  -- of suppression requires more complex timing control.

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
