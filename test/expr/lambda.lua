--%%name:expr_lambda
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- Arrow lambda, single param, immediately invoked
  test_expr(er, "return (x -> x * 2)(5)", 10,
    "arrow: single-param, invoked")

  -- Arrow lambda, zero param
  test_expr(er, "return (() -> 42)()", 42,
    "arrow: zero-param, invoked")

  -- Arrow lambda, multi param
  test_expr(er, "return ((x,y) -> x + y)(3, 7)", 10,
    "arrow: multi-param, invoked")

  -- Arrow lambda stored in variable
  test_expr(er, "local f = x -> x + 10; return f(5)", 15,
    "arrow: stored in local")

  -- Regular function, immediately invoked
  test_expr(er, "return (function(x) return x * 3 end)(4)", 12,
    "function: single-param, invoked")

  -- Regular function, multi param
  test_expr(er, "return (function(a, b) return a - b end)(10, 3)", 7,
    "function: multi-param, invoked")

  -- Regular function stored, then called (no 'local function' sugar in ES)
  test_expr(er, "local add = function(x,y) return x + y end; return add(3, 4)", 7,
    "function: stored, called")

  -- Lambda with map
  test_expr(er, "return sum(map({1,2,3}, x -> x * 2))", 12,
    "higher-order: map + lambda")

  -- Lambda with filter
  test_expr(er, "return size(filter({1,2,3,4,5}, x -> x > 3))", 2,
    "higher-order: filter + lambda")

  -- Lambda with reduce (two-param)
  test_expr(er, "return reduce({10,20,30}, (acc,v) -> acc + v, 0)", 60,
    "higher-order: reduce + lambda")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
