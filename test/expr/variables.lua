--%%name:expr_variables
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- Assignment and retrieval
  test_expr(er, "x = 42; return x",        42,     "assign and read")
  test_expr(er, "x = 10; x = x + 5; return x", 15, "reassign after read")
  test_expr(er, "x = 3; y = x * 2; return y",  6,  "chain assignments")

  -- Compound assignment
  test_expr(er, "x = 10; x += 5; return x",  15,   "add-assign (+=)")
  test_expr(er, "x = 10; x -= 3; return x",  7,    "sub-assign (-=)")
  test_expr(er, "x = 4; x *= 3; return x",   12,   "mul-assign (*=)")
  test_expr(er, "x = 20; x /= 4; return x",  5,    "div-assign (/=)")

  -- Local vs global
  test_expr(er, "local x = 5; return x",     5,    "local variable")
  test_expr(er, "x = 1; local x = 2; return x", 2, "local shadows global")

  -- Coalesce operator
  test_expr(er, "return nil ?? 42",          42,   "coalesce nil -> value")
  test_expr(er, "return 7 ?? 42",            7,    "coalesce non-nil -> unchanged")
  test_expr(er, "x = nil; return x ?? 99",   99,   "coalesce nil variable")

  -- Multiple return values
  test_expr(er, "return 1, 2, 3",            1,    "multiple return (first value)")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
