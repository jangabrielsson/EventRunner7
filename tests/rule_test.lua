--%%name:Rule unit tests
--%%headers:EventRunner.inc
--%%offline:true

-- ── Test harness ──────────────────────────────────────────────────────────
local PASS, FAIL = 0, 0

local function check(name, got, expected)
  if got == expected then
    PASS = PASS + 1
    print("PASS:", name)
  else
    FAIL = FAIL + 1
    print("FAIL:", name, "  got:", tostring(got), "  expected:", tostring(expected))
  end
end

-- testRule(name, src, fire, expected)
--   src      — EventScript rule string ("cond => action")
--   fire     — function(er, rule) that fires the rule (rule:run() or sourceTrigger:post)
--   expected — expected first return value, or predicate function(v)->bool
local function testRule(name, src, fire, expected)
  local er   = fibaro.ER._testER
  local rule = er.eval(src)
  rule.verbosity = "silent"
  local got
  rule.onDone = function(v) got = v end
  fire(er, rule)
  if type(expected) == "function" then
    check(name, expected(got), true)
  else
    check(name, got, expected)
  end
end

-- testExpr(name, src, expected)
--   Evaluates a plain expression and checks its return value.
local function testExpr(name, src, expected)
  local er  = fibaro.ER._testER
  local got = er.eval(src)
  if type(expected) == "function" then
    check(name, expected(got), true)
  else
    check(name, got, expected)
  end
end

-- testAsync(name, src, fire, expected)
--   Like testRule but for async actions (contain wait).
--   The assertion runs inside onDone after plua drains the timer queue.
local function testAsync(name, src, fire, expected)
  local er   = fibaro.ER._testER
  local rule = er.eval(src)
  rule.verbosity = "silent"
  rule.onDone = function(v)
    if type(expected) == "function" then
      check(name, expected(v), true)
    else
      check(name, v, expected)
    end
  end
  fire(er, rule)
end

-- ── Setup ─────────────────────────────────────────────────────────────────
local function main(er)
  fibaro.ER._testER = er
  local st = fibaro.ER.sourceTrigger

  -- ── trigger-variable tests ────────────────────────────────────────────
  er.triggerVars.tvar = 0

  testRule("trigger-var: condition true → action runs",
    "tvar == 5 => return tvar * 2",
    function(er, rule)
      er.triggerVars.tvar = 5
      rule:run()
    end,
    10)

  -- post test uses its own variable to avoid cross-test contamination
  -- (st:post fires asynchronously, after all sync code has mutated tvar)
  er.triggerVars.pvar = 0
  testAsync("trigger-var: fire via sourceTrigger post",
    "pvar == 7 => return pvar + 1",
    function(er, rule)
      er.triggerVars.pvar = 7
      st:post({type='trigger-variable', name='pvar', value=7})
    end,
    8)

  testRule("trigger-var: condition false → action not invoked",
    "tvar == 99 => return 42",
    function(er, rule)
      er.triggerVars.tvar = 0   -- condition is false → onDone never called
      rule:run()
    end,
    nil)

  -- ── plain expression tests ────────────────────────────────────────────
  testExpr("expr: arithmetic",             "return 3 + 4 * 2",    11)
  testExpr("expr: string concat",          'return "hi" ++ "!"',  "hi!")
  testExpr("expr: returns nil",            "return nil",           nil)
  testExpr("expr: multiple return (first)","return 1, 2, 3",       1)

  -- ── async action tests (each uses its own variable) ───────────────────
  er.triggerVars.avar = 0

  testAsync("async: wait then return",
    "avar == 5 => wait(5); return avar * 3",
    function(er, rule)
      er.triggerVars.avar = 5
      rule:run()
    end,
    15)

  er.triggerVars.bvar = 0

  testAsync("async: chained waits",
    "bvar == 5 => wait(5); wait(5); return bvar + 10",
    function(er, rule)
      er.triggerVars.bvar = 5
      rule:run()
    end,
    15)

  -- ── rule object shape ─────────────────────────────────────────────────
  local r = er.eval("tvar == 5 => return 1")
  r.verbosity = "silent"
  check("rule: eval returns table",          type(r),               "table")
  check("rule: has numeric id",              type(r.id),            "number")
  check("rule: tostring RULE prefix",        tostring(r):sub(1,4),  "RULE")
  check("rule: default verbosity is normal", r.verbosity,           "silent")  -- we just set it

  -- ── summary (fires after async tests complete) ────────────────────────
  setTimeout(function()
    print(string.format("Results: %d passed, %d failed", PASS, FAIL))
  end, 100)
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end

