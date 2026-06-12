--%%name:rule_global_vars
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- Create simulated global variable
  er.createSimGlobal("G_trigger", "0")

  -- Rule triggers on global variable change
  test_rule(er, "$G_trigger == '1' => return 'fired'",
    function(er2, rule)
      -- Change the global variable to trigger the rule
      er2.eval("$G_trigger = '1'")
    end,
    "fired",
    "gvar rule: triggers on change")

  -- Rule with condition on global variable
  er.createSimGlobal("G_mode", "home")
  test_rule(er, "$G_mode == 'away' => return 'away_mode'",
    function(er2, rule)
      er2.eval("$G_mode = 'away'")
    end,
    "away_mode",
    "gvar rule: condition match triggers")

  -- Rule that doesn't fire when condition is false
  test_rule(er, "$G_mode == 'sleep' => return 'never'",
    function(er2, rule)
      -- G_mode is 'away', not 'sleep', so rule should not fire
      er2.eval("$G_mode = 'away'")
    end,
    nil,
    "gvar rule: no match → no fire")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
