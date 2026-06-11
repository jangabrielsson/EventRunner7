--%%name:expr_arithmetic
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  test_expr(er, "return 3 + 4",           7,         "addition")
  test_expr(er, "return 10 - 3",          7,         "subtraction")
  test_expr(er, "return 3 * 4",           12,        "multiplication")
  test_expr(er, "return 20 / 5",          4,         "division (returns float)")
  test_expr(er, "return 10 % 3",          1,         "modulo")
  test_expr(er, "return 2 ^ 3",           8,         "exponentiation (2^3 = 8)")
  test_expr(er, "return -5",              -5,        "unary negation")
  test_expr(er, "return 2 + 3 * 4",       14,        "operator precedence (* before +)")
  test_expr(er, "return (2 + 3) * 4",     20,        "parentheses override precedence")
  test_expr(er, "return 10 / 2 + 3",      8,         "left-assoc: / before +")
  test_expr(er, "return 2 ^ 3 ^ 2",       512,       "right-assoc: exponentiation (2^(3^2) = 512)")
  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
