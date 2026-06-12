--%%name:expr_global_vars
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- Create simulated global variables
  er.createSimGlobal("G_test", "hello")
  er.createSimGlobal("G_count", "0")
  er.createSimGlobal("G_flag", "false")

  -- Read global variable
  test_expr(er, "return $G_test", "hello", "gvar: read string")
  test_expr(er, "return $G_count", "0",     "gvar: read number string")

  -- Set global variable
  test_expr(er, "$G_count = '5'; return $G_count", "5", "gvar: set and read")
  test_expr(er, "$G_count = '10'; return $G_count", "10", "gvar: update")

  -- Comparison with global variable
  test_expr(er, "$G_count = '42'; return $G_count == '42'", true,  "gvar: compare equal")
  test_expr(er, "$G_count = '42'; return $G_count ~= '99'", true,  "gvar: compare not equal")

  -- Boolean-like comparison
  test_expr(er, "$G_flag = 'true'; return $G_flag == 'true'", true,  "gvar: boolean true")
  test_expr(er, "$G_flag = 'false'; return $G_flag == 'false'", true, "gvar: boolean false")

  -- Multiple global variables
  test_expr(er, "$G_test = 'a'; $G_count = '1'; return $G_test ++ $G_count", "a1", "gvar: concat two vars")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
