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

  -- Variables as operands
  test_expr(er, "x = 5; y = 3; return x + y", 8,     "var add: x+y")
  test_expr(er, "x = 10; y = 4; return x - y", 6,    "var sub: x-y")
  test_expr(er, "x = 6; y = 7; return x * y", 42,    "var mul: x*y")
  test_expr(er, "x = 20; y = 4; return x / y", 5,    "var div: x/y")
  test_expr(er, "x = 17; y = 5; return x % y", 2,    "var mod: x%y")
  test_expr(er, "x = 2; y = 3; return x ^ y", 8,     "var pow: x^y")

  -- Compound assignment with variables
  test_expr(er, "x = 5; x += 3; return x", 8,        "compound add: x+=3")
  test_expr(er, "x = 10; x -= 4; return x", 6,       "compound sub: x-=4")
  test_expr(er, "x = 3; x *= 5; return x", 15,       "compound mul: x*=5")
  test_expr(er, "x = 20; x /= 4; return x", 5,       "compound div: x/=4")

  -- Chained operations with variables
  test_expr(er, "a = 2; b = 3; c = 4; return a + b * c", 14, "var precedence: a+b*c")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
