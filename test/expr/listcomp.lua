--%%name:expr_listcomp
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- Basic: map values
  test_expr(er,
    "local r = [x * 2 for x in {1,2,3}]; return json.encode(r)",
    "[2,4,6]",
    "listcomp: map (x*2)")

  -- With filter
  test_expr(er,
    "local r = [x for x in {1,2,3,4,5} if x > 2]; return json.encode(r)",
    "[3,4,5]",
    "listcomp: filter (x > 2)")

  -- ipairs/pairs iterator form is not supported in list comprehensions;
  -- only simple `for x in {table}` iteration works.

  -- Nested comprehension with function call
  test_expr(er,
    "local r = [x for x in {5,10,15,20} if x % 10 == 0]; return json.encode(r)",
    "[10,20]",
    "listcomp: filter mod 10")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
