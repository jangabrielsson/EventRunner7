--%%name:Modifier unit tests
--%%headers:EventRunner.inc
--%%offline:true

local PASS, FAIL = 0, 0
local COND_FAIL = 'fibaro.ER.conditionFail'

local function check(name, got, expected)
  if got == expected then
    PASS = PASS + 1
    print("PASS:", name)
  else
    FAIL = FAIL + 1
    print("FAIL:", name, "  got:", tostring(got), "  expected:", tostring(expected))
  end
end

local function main(er)
  fibaro.ER._testER = er

  local function runRule(rule)
    local got
    rule.onDone = function(v) got = v end
    rule:run()
    return got
  end

  -- ── cooldown modifier ──────────────────────────────────────────────────
  er.triggerVars.tcd = 0
  local r1 = er.eval("tcd > 0 cooldown 60 => return 1")
  r1.verbosity = "silent"
  er.triggerVars.tcd = 5
  check("cooldown: first run fires",       runRule(r1), 1)
  check("cooldown: second run suppressed", runRule(r1), COND_FAIL)

  -- ── every modifier ────────────────────────────────────────────────────
  er.triggerVars.tev = 0
  local r2 = er.eval("tev > 0 every 3 => return 1")
  r2.verbosity = "silent"
  er.triggerVars.tev = 1
  check("every: silent on 1st", runRule(r2), COND_FAIL)
  check("every: silent on 2nd", runRule(r2), COND_FAIL)
  check("every: fires on 3rd",  runRule(r2), 1)
  check("every: silent on 4th", runRule(r2), COND_FAIL)
  check("every: silent on 5th", runRule(r2), COND_FAIL)
  check("every: fires on 6th",  runRule(r2), 1)

  -- ── restart modifier ──────────────────────────────────────────────────
  er.triggerVars.trs = 0
  local r3 = er.eval("trs > 0 restart => return 1")
  r3.verbosity = "silent"
  er.triggerVars.trs = 1
  check("restart: compiles and runs", runRule(r3), 1)

  -- ── since modifier (trueFor sugar) ────────────────────────────────────
  er.triggerVars.tsi = 0
  local r4 = er.eval("tsi > 0 since 5 => return 1")
  r4.verbosity = "silent"
  -- condition false → trueFor never fires → nil
  check("since: condition false, no fire", runRule(r4), COND_FAIL)

  -- ── debounce modifier (restart + wait sugar) ──────────────────────────
  er.triggerVars.tdb = 0
  local r5 = er.eval("tdb > 0 debounce 0.1 => return 1")
  r5.verbosity = "silent"
  er.triggerVars.tdb = 1
  -- debounce inserts wait(0.1) before action body, so synchronous run returns nil
  check("debounce: async wait → nil on sync run", runRule(r5), nil)

  -- ── cool_down() direct in expression ──────────────────────────────────
  er.triggerVars.tc6 = 0
  local r6 = er.eval("tc6 > 0 and cool_down(60) => return 1")
  r6.verbosity = "silent"
  er.triggerVars.tc6 = 1
  check("cool_down direct: first fires",       runRule(r6), 1)
  check("cool_down direct: second suppressed", runRule(r6), COND_FAIL)

  -- ── every_other() direct in expression ────────────────────────────────
  er.triggerVars.te7 = 0
  local r7 = er.eval("te7 > 0 and every_other(2) => return 1")
  r7.verbosity = "silent"
  er.triggerVars.te7 = 1
  check("every_other direct: silent on 1st", runRule(r7), COND_FAIL)
  check("every_other direct: fires on 2nd",  runRule(r7), 1)
  check("every_other direct: silent on 3rd", runRule(r7), COND_FAIL)
  check("every_other direct: fires on 4th",  runRule(r7), 1)

  print(string.format("\n=========== Results: %d passed, %d failed ===========", PASS, FAIL))
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
