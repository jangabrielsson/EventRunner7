--%%name:expr_tables
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- Array creation and indexing
  test_expr(er, "return {10, 20, 30}[1]",    10,   "array index [1]")
  test_expr(er, "return {10, 20, 30}[2]",    20,   "array index [2]")
  test_expr(er, "return {10, 20, 30}[3]",    30,   "array index [3]")
  -- # is the event prefix in EventScript (#eventName), not the length
  -- operator.  Use the Lua-level `#` via `er.variables` instead.
  -- test_expr(er, "local t = {1,2,3}; return #t", 3, "array length (skipped: # is event prefix)")

  -- Dictionary
  test_expr(er, "return {a=1, b=2}.a",       1,    "dict dot access")
  test_expr(er, "return {a=1, b=2}.b",       2,    "dict dot access 2")
  test_expr(er, "return {a=1, b=2}['b']",    2,    "dict bracket access (string key)")
  test_expr(er, "local t = {}; t.x = 5; return t.x", 5, "dict set then get")

  -- Nested
  test_expr(er, "return {a={b=3}}.a.b",      3,    "nested dot access")

  -- Mixed tables (array + dict) have implementation-defined behavior
  -- in EventScript; skip for now.

  -- Table update
  test_expr(er, "local t = {x=1}; t.x = 99; return t.x", 99, "update field")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
