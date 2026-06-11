--%%name:expr_functions
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- Built-in math functions
  test_expr(er, "return math.abs(-5)",       5,      "math.abs")
  test_expr(er, "return math.max(3, 7, 2)",  7,      "math.max")
  test_expr(er, "return math.min(3, 7, 2)",  2,      "math.min")
  test_expr(er, "return math.floor(3.9)",    3,      "math.floor")

  -- Built-in rnd
  local v = er.eval("return rnd(1, 100)")
  assert_truthy(type(v) == "number" and v >= 1 and v <= 100, "rnd(1,100) in range")

  -- String concatenation (++)
  test_expr(er, 'return "hello" ++ " world"', "hello world", "string concat (++)")

  -- log function returns its formatted string
  local s = er.eval("return log('hello %d', 42)")
  assert_truthy(type(s) == "string" and s:match("hello 42"), "log returns formatted string")

  -- json.encode
  test_expr(er, "return json.encode('hello')", '"hello"', "json.encode string")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
