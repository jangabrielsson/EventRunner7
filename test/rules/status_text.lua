--%%name:rule_status_text
--%%include:../../EventRunner.inc
--%%file:../../test/harness.lua,harness
--%%mode:offline

-- ER.ruleStatusText(): one-line-per-rule summary for the QA UI status view.

local function main(er)
  er.triggerVars.d = 0

  local ok = er.eval("d == 1 => return 42")
  local bad = er.eval("d == 2 => throw('boom')")
  er.triggerVars.d = 2
  bad:run()  -- errors, disables (default policy), records lastError

  local txt = fibaro.ER.ruleStatusText()
  assert_match(txt, "RULE1 ✅", "status: ok rule listed")
  assert_match(txt, "❌ disabled", "status: errored rule disabled")
  assert_match(txt, "boom", "status: last error shown")
  assert_match(txt, "⚡ d →", "status: trigger source span shown")

  -- the status hook fires on rule completion (live UI updates)
  local hooked = 0
  fibaro.ER._statusHook = function() hooked = hooked + 1 end
  er.triggerVars.d = 1
  ok:run()  -- completes → onDone → hook
  assert_truthy(hooked > 0, "status hook fires on rule completion")

  done()
end

function QuickApp:onInit() fibaro.EventRunner(main) end
