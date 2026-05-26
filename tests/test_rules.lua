--%%name:Rule unit tests
--%%headers:EventRunner.inc
--%%file:tests/test_rule_runner.lua,test
--%%file:$fibaro.lib.speed,speed
--%%offline:true

local fmt = string.format

-- ── Test definitions ──────────────────────────────────────────────────────────
local tests = {}
local function test(name, fn, opts)
  tests[#tests+1] = {name=name, fn=fn, timeout=(opts or {}).timeout}
end

local opts = { 
  started = false, check = false, result = false, triggers=false, verbosity = 'silent' 
}

-- basic custom event
test("custom event triggers rule", function(er, rule, vars, tv, er)
  er.opts = opts
  rule("#foo => done()")
  rule("post(#foo)")
end)

-- trigger variable condition
test("trigger variable condition", function(er, rule, vars, tv, er)
  er.opts = opts
  tv.x = 1
  rule("x > 6 => done()")
  rule("x = 7")
end)

-- trueFor/since
test("trueFor/since", function(er, rule, vars, tv, er)
  er.opts = opts
  tv.x = 1
  rule("x > 6 since 00:05 => done()")
  rule("x = 7")
end, {timeout=1000*60*6})

-- cooldown
test("cooldown", function(er, rule, vars, tv, er)
  er.opts = opts
  tv.x = 1
  tv.y = 0
  rule("x > 6 cooldown 2 => y += 1")   -- 2s cooldown
  rule("x = 7; x = 8; wait(3); x = 9") -- wait(3s) > cooldown, so x=9 fires again
  rule("y >= 2 => done()")
end, {timeout=1000*5})

-- debounce: fires 2s after the LAST trigger (re-trigger restarts the wait)
test("debounce", function(er, rule, vars, tv, er)
  er.opts = opts
  tv.x = 1
  rule("x > 6 debounce 2 => done()")  -- done() fires 2s after last x>6 trigger
  rule("x = 7; x = 8; x = 9")        -- rapid triggers; only x=9 eventually settles
end, {timeout=1000*5})

-- every N: action fires only on every Nth trigger
test("every", function(er, rule, vars, tv, er)
  er.opts = opts
  tv.x = 0
  tv.y = 0
  rule("x > 0 every 3 => y += 1")                     -- fires on 3rd, 6th trigger
  rule("x = 1; x = 2; x = 3; x = 4; x = 5; x = 6")  -- 6 triggers → y=2
  rule("y >= 2 => done()")
end)

-- restart: re-trigger during action cancels and restarts it
test("restart", function(er, rule, vars, tv, er)
  er.opts = opts
  tv.x = 1
  -- triggers arrive every 1s; action needs 2s → each trigger restarts the wait
  -- only the final wait(2) (after x=3 with no further trigger) completes
  rule("x > 0 restart => wait(2); done()")
  rule("x = 1; wait(1); x = 2; wait(1); x = 3")
end, {timeout=1000*5})

-- ── Boot ──────────────────────────────────────────────────────────────────────
function QuickApp:onInit()
  fibaro.ER.silent = true
  fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    fibaro.EventRunner(function(er) runTests(er, tests) end)
  end)
end

