--%%name:Lambda smoke test
--%%offline:true
--%%headers:EventRunner.inc

-- Smoke tests for arrow-lambda syntax (x -> expr) and map/filter/reduce builtins.
-- Call setupFuns via pcall — builtins registered before the async section are
-- available; the async section fails harmlessly because er.async isn't set up yet.

local ER = fibaro.ER
local vm = ER.csp
pcall(ER.setupFuns)

local parse      = ER.parse
local compileAST = ER.compileAST

local passed, failed = 0, 0

local function test(name, src, expected)
  local ok, result = pcall(function()
    local ast  = parse(src)
    local csp  = compileAST(ast)
    local code = vm.compile(csp)
    local _, val = vm.eval(code)
    return val
  end)
  if ok and result == expected then
    passed = passed + 1
    print("PASS: " .. name)
  elseif ok then
    failed = failed + 1
    print("FAIL: " .. name .. "  expected=" .. tostring(expected) .. "  got=" .. tostring(result))
  else
    failed = failed + 1
    print("ERROR: " .. name .. "  " .. tostring(result))
  end
end

-- ── Arrow-lambda syntax ───────────────────────────────────────────────────

-- single-param, immediately invoked
test("x -> expr, invoked",        "(x -> x * 2)(5)",                           10)
-- zero-param lambda
test("() -> expr, invoked",       "(() -> 42)()",                              42)
-- multi-param lambda
test("(x,y) -> expr, invoked",    "((x,y) -> x+y)(3, 7)",                     10)
-- lambda stored in a local
test("local f = x -> …",          "local f = x -> x + 10; f(5)",              15)
-- existing function syntax still works
test("function(x) return … end",  "(function(x) return x*3 end)(4)",           12)

-- ── map / filter / reduce builtins ────────────────────────────────────────

-- map: sum of doubled elements
test("map + lambda",              "sum(map({1,2,3}, x -> x * 2))",             12)
-- filter: count elements > 3
test("filter + lambda",           "size(filter({1,2,3,4,5}, x -> x > 3))",     2)
-- reduce: sum via two-param lambda
test("reduce + (a,b) -> lambda",  "reduce({1,2,3,4}, (a,b) -> a+b, 0)",       10)
-- reduce with three elements
test("reduce sum larger",         "reduce({10,20,30}, (acc,v) -> acc+v, 0)",   60)

-- ── summary ───────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed  (%d total)", passed, failed, passed+failed))
