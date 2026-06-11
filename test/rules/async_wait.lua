--%%name:rule_async_wait
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  er.triggerVars.a = 0

  test_rule(er, "a == 5 => wait(5); return a * 3",
    function(er, rule)
      er.triggerVars.a = 5
      rule:run()
    end,
    15,
    "async: wait(5) then return a*3")

  er.triggerVars.b = 0

  test_rule(er, "b == 5 => wait(5); wait(5); return b + 10",
    function(er, rule)
      er.triggerVars.b = 5
      rule:run()
    end,
    15,
    "async: chained waits")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
