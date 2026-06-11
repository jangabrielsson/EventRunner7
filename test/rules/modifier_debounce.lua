--%%name:rule_modifier_debounce
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- 'debounce T' waits for T seconds of silence before firing.
  -- Multiple rapid triggers reset the timer; only the last one fires.
  er.triggerVars.db = 0

  test_rule(er, "db == 1 debounce 5 => return 'debounced'",
    function(er, rule)
      er.triggerVars.db = 1
      rule:run()   -- starts 5-unit debounce timer
      rule:run()   -- resets timer
      rule:run()   -- resets again — only this one fires after 5
    end,
    "debounced",
    "debounce: fires after last trigger")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
