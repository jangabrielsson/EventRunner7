--%%name:expr_logical
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  test_expr(er, "return true & true",     true,   "AND: true & true")
  test_expr(er, "return true & false",    false,  "AND: true & false")
  test_expr(er, "return false & true",    false,  "AND: false & true")
  test_expr(er, "return false & false",   false,  "AND: false & false")
  test_expr(er, "return true | true",     true,   "OR: true | true")
  test_expr(er, "return true | false",    true,   "OR: true | false")
  test_expr(er, "return false | true",    true,   "OR: false | true")
  test_expr(er, "return false | false",   false,  "OR: false | false")
  test_expr(er, "return !true",           false,  "NOT: !true")
  test_expr(er, "return !false",          true,   "NOT: !false")
  test_expr(er, "return !!true",          true,   "NOT NOT: !!true")
  test_expr(er, "return !(5 > 3)",        false,  "NOT comparison: !(5>3)")
  test_expr(er, "return 5 > 3 & 2 < 4",   true,   "combined: comparison & comparison")
  test_expr(er, "return false | 5 > 3",   true,   "OR short-circuit: false | 5>3")
  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
