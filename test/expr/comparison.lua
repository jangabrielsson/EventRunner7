--%%name:expr_comparison
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  test_expr(er, "return 5 == 5",          true,   "equal (==)")
  test_expr(er, "return 5 == 3",          false,  "not equal (==)")
  test_expr(er, "return 5 ~= 3",          true,   "not equal (~=)")
  test_expr(er, "return 5 ~= 5",          false,  "equal (~=)")
  test_expr(er, "return 5 != 3",          true,   "not equal (!=)")
  test_expr(er, "return 3 < 5",           true,   "less than (<)")
  test_expr(er, "return 5 < 3",           false,  "not less than (<)")
  test_expr(er, "return 5 > 3",           true,   "greater than (>)")
  test_expr(er, "return 3 > 5",           false,  "not greater than (>)")
  test_expr(er, "return 5 <= 5",          true,   "less or equal (<=)")
  test_expr(er, "return 5 <= 3",          false,  "not less or equal (<=)")
  test_expr(er, "return 5 >= 5",          true,   "greater or equal (>=)")
  test_expr(er, "return 3 >= 5",          false,  "not greater or equal (>=)")
  test_expr(er, 'return "abc" == "abc"',  true,   "string equal")
  test_expr(er, 'return "abc" ~= "def"',  true,   "string not equal")
  test_expr(er, "return nil == nil",      true,   "nil == nil")
  test_expr(er, "return nil ~= false",    true,   "nil ~= false")
  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
