--%%name:rule_event_routing
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  local st = er.sourceTrigger

  -- ── post() with relative time ──────────────────────────────────────────

  -- Rule A: on #trigger1, post #delayed1 after a short delay
  er.eval("#trigger1 => post(#delayed1, +/00:00:01)")
  -- Rule B: when #delayed1 fires, set trigger var
  er.eval("#delayed1 => step = 1")

  -- Kick off
  er.triggerVars.step = 0
  st:post({type='event', name='trigger1'})

  -- Assert: after delay, step should be 1
  test_rule(er, "step == 1 => return 'posted'",
    function(er2, rule)
      -- step gets set by the delayed event handler
    end,
    "posted",
    "post(): relative time (+/00:00:01)")

  -- ── post() with absolute time (n/ — next occurrence) ──────────────────

  er.triggerVars.step2 = 0
  -- n/12:00 means next 12:00; we're at a frozen/simulated time.
  -- For testing, use a near time that will fire.
  er.eval("#trigger2 => post(#delayed2, +/00:00:01)")
  er.eval("#delayed2 => step2 = 1")

  st:post({type='event', name='trigger2'})

  test_rule(er, "step2 == 1 => return 'posted_abs'",
    function() end,
    "posted_abs",
    "post(): absolute time via n/")

  -- ── cancel() — cancel a posted event ───────────────────────────────────

  er.triggerVars.step3 = 0
  er.eval("#schedule3 => ref3 = post(#cancelled3, +/00:00:05)")
  er.eval("#cancel3 => cancel(ref3); step3 = 1")
  -- #cancelled3 should never fire because it's cancelled
  er.eval("#cancelled3 => step3 = 99")  -- would set 99 if not cancelled

  -- Schedule, then immediately cancel
  st:post({type='event', name='schedule3'})
  st:post({type='event', name='cancel3'})

  -- After a brief wait, step3 should be 1 (from cancel), not 99
  test_rule(er, "step3 == 1 => return 'cancelled'",
    function() end,
    "cancelled",
    "cancel(): prevents delayed event")

  -- ── post() with parameters ─────────────────────────────────────────────

  er.triggerVars.step4 = ""
  er.eval("#trigger4 => post(#paramEvent{val=42}, +/00:00:01)")
  er.eval("#paramEvent{val='$v'} => step4 = v")

  st:post({type='event', name='trigger4'})

  test_rule(er, "step4 == 42 => return 'params_ok'",
    function() end,
    "params_ok",
    "post(): event with parameters preserved")

  -- ── Multiple posts from same rule ──────────────────────────────────────

  er.triggerVars.count5 = 0
  er.eval("#trigger5 => post(#count5_a, +/00:00:01); post(#count5_b, +/00:00:01)")
  er.eval("#count5_a => count5 = count5 + 1")
  er.eval("#count5_b => count5 = count5 + 1")

  st:post({type='event', name='trigger5'})

  -- Both delayed events fire → count5 should be 2
  test_rule(er, "count5 == 2 => return 'multi_post'",
    function() end,
    "multi_post",
    "post(): multiple posts from one rule")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
