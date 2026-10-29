--%%name:rule_when_sugar
--%%include:../../EventRunner.inc
--%%file:../../test/harness.lua,harness
--%%mode:offline

-- 'when cond then action' is sugar for 'cond => action', including modifiers
-- and duration literals. 'when' remains usable as a plain variable name.

local function main(er)
  er.triggerVars.d = 0

  test_rule(er, "when d == 1 then return 42",
    function(er2, rule) er.triggerVars.d = 1; rule:run() end,
    42,
    "when..then registers and fires")

  test_rule(er, "when d == 2 since 30s then return 43",
    function(er2, rule) er.triggerVars.d = 2; rule:run() end,
    43,
    "when..then with modifier and duration literal")

  -- 'when' is not reserved: it still works as a variable name
  test_expr(er, "when = 5; return when", 5,
    "'when' still usable as a variable")

  done()
end

function QuickApp:onInit() fibaro.EventRunner(main) end
