--%%name:rule_trigger_var
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  er.triggerVars.t = 0

  test_rule(er, "t == 5 => return t * 2",
    function(er, rule)
      er.triggerVars.t = 5
      rule:run()
    end,
    10,
    "trigger var: condition true -> action returns 10")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
