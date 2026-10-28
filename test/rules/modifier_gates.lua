--%%name:rule_modifier_gates
--%%include:../../EventRunner.inc
--%%file:../../test/harness.lua,harness
--%%mode:offline
--%%time:2026/06/12 07:30:00

-- Behavioral tests for the first-class modifier gates: they must actually
-- suspend/suppress, not just return the right value when they fire.

local function main(er)
  er.triggerVars.d = 0

  local remaining = 3  -- since completion, first_in reset, sync block
  local function finish_one()
    remaining = remaining - 1
    if remaining == 0 then done() end
  end

  -- since: suspends while the window is pending, then fires
  local rs = er.eval("d == 1 since 2 => return 42")
  rs.onDone = function(v)
    assert_eq(v, 42, "since: fires after the window")
    finish_one()
  end
  er.triggerVars.d = 1
  rs:run()
  assert_eq(rs.active, 1, "since: suspended while the window is pending")

  -- cooldown: suppresses immediate re-triggers
  local fires = 0
  local rc = er.eval("d == 1 cooldown 5 => return 43")
  rc.onDone = function(v) if v == 43 then fires = fires + 1 end end
  rc:run()  -- fires
  rc:run()  -- suppressed
  rc:run()  -- suppressed
  assert_eq(fires, 1, "cooldown: fires once within the cooldown window")

  -- every: fires only on the Nth trigger
  local ecount = 0
  local re = er.eval("d == 1 every 3 => return 44")
  re.onDone = function(v) if v == 44 then ecount = ecount + 1 end end
  re:run(); re:run()  -- 1st, 2nd: suppressed
  assert_eq(ecount, 0, "every: suppressed before N")
  re:run()  -- 3rd: fires
  assert_eq(ecount, 1, "every: fires on Nth trigger")
  re:run(); re:run(); re:run()  -- 4th..6th → 6th fires
  assert_eq(ecount, 2, "every: fires again after another N")

  -- first_in: fires once per window, resets at window end
  local fcount = 0
  local rf = er.eval("d == 1 first_in 07:00..08:00 => return 45")
  rf.onDone = function(v) if v == 45 then fcount = fcount + 1 end end
  rf:run()  -- in window (07:30): fires
  rf:run()  -- suppressed by the once flag
  assert_eq(fcount, 1, "first_in: fires once in the window")
  assert_truthy(rf._mstate.once, "first_in: once flag set")
  setTimeout(function()
    assert_truthy(rf._mstate.once == nil, "first_in: reset at window end")
    finish_one()
  end, 31 * 60000)  -- 08:01, after the 08:00 reset timer

  finish_one()  -- sync block done
end

function QuickApp:onInit() fibaro.EventRunner(main) end
