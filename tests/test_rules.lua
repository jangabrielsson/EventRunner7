--%%name:Rule unit tests
--%%headers:EventRunner.inc
--%%file:Sim.lua,sim
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
  tv.x = 0
  rule("x == 1 => post(#bar)")
  rule("x == 2 => post(#foo{x=2})")
  rule("x == 3 => post(#foo{x=5})")
  rule("x == 4 => done()")

  rule("#bar => x = 2")
  rule("#foo{x=2} => x = 3")
  rule("#foo{x='$_>4'} => x = 4")

  rule("x = 1")
end)

-- trigger variable condition
test("trigger variable condition", function(er, rule, vars, tv, er)
  er.opts = opts
  tv.x = 1
  rule("x > 6 => done()")
  rule("x = 7")
end)

-- GV trigger
test("GV trigger", function(er, rule, vars, tv, er)
  er.opts = opts
  er.createSimGlobal("x", "0")
  rule("$x == 8 => done()")
  rule("$x = 8")
end)

-- QVAR trigger -- don't work in speedTime
-- test("QVAR trigger", function(er, rule, vars, tv, er)
--   er.opts = opts
--   rule("$$x == 8 => done()")
--   rule("$$x = 8")
-- end)

-- InternalStorage var, don't work in speedTime
-- test("TVAR trigger", function(er, rule, vars, tv, er)
--   er.opts = opts
--   rule("$$$x == 8 => done()")
--   rule("$$$x = 8")
-- end)

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
  rule("x = 1; x = 2; x = 3")
end, {timeout=1000*5})

-- first_in: 
test("first_in", function(er, rule, vars, tv, er)
  er.opts = opts
  tv.y = false
  rule("timeA = now; timeB = now+01:00")
  rule("y==true first_in timeA..timeB => done()")
  rule("y=true; y=true")
end, {timeout=1000*5})

-- first_in with reset: 
test("first_in with reset", function(er, rule, vars, tv, er)
  er.opts = opts
  tv.x = 0
  tv.y = false
  rule("timeA = now; timeB = now+01:00")
  rule("y == true first_in timeA..timeB => x += 1")
  rule("x == 2 => done()")
  rule("y=true; wait(24:00:00); y=false; wait(1); y=true")
end, {timeout=1000*60*60*24+2*1000})

-- device props
-- :value
-- :state
-- :bat
-- :isDead
-- :safe
-- :breached
-- :temp
-- :key

test("props", function(er, rule, vars, tv, er)
  er.opts = opts
  local loadDevice = er.loadSimDevice
  tv.x = 0
  vars.light1_1 = loadDevice("binarySwitch")
  vars.light1_2 = loadDevice("binarySwitch")
  vars.dim1_1 = loadDevice("multilevelSwitch")
  vars.sensor1_1 = loadDevice("binarySensor")
  vars.sensor1_2 = loadDevice("binarySensor")
  vars.sensor1_3 = loadDevice("temperatureSensor")
  vars.remote = loadDevice("remoteController")

  rule("x == 1 => dim1_1:value = 51")
  rule("x == 2 => light1_1:on")
  rule("x == 3 => light1_2:state=true")
  rule("x == 4 => sensor1_1:value=true")
  rule("x == 5 => sensor1_2:prop = {'batteryLevel',51}")
  rule("x == 6 => sensor1_2:prop = {'dead',true}")
  rule("x == 7 => sensor1_2:value = false")
  rule("x == 8 => sensor1_3:temp = 25")
  rule("x == 9 => remote:simKey={keyId=2,keyAttribute='Pressed'}")
  rule("x == 10 => done()")

  rule("dim1_1:value > 50 => x = 2")
  rule("light1_1:isOn => x = 3")
  rule("light1_2:state => x = 4")
  rule("sensor1_1:breached => x = 5")
  rule("sensor1_2:bat > 50 => x = 6")
  rule("sensor1_2:isDead => x = 7")
  rule("sensor1_2:safe => x = 8")
  rule("sensor1_3:temp > 24 => x = 9")
  rule("remote:key == '2:Pressed' => x = 10")

  rule("x = 1")
end, {timeout=5*1000})

-- ── Boot ──────────────────────────────────────────────────────────────────────
function QuickApp:onInit()
  quickApp = self
  fibaro.ER.silent = true
  fibaro.speedTime(2*24,function() -- Run for 24 hours of simulated time
    fibaro.EventRunner(function(er) runTests(er, tests) end)
  end)
end

