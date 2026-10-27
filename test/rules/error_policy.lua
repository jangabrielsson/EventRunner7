--%%name:rule_error_policy
--%%include:../../EventRunner.inc
--%%file:../../test/harness.lua,harness
--%%mode:offline

-- disableOnError policy for runtime errors that abort a rule evaluation:
--   true (default) → disable immediately
--   N              → disable after N consecutive errored runs; clean
--                    completions (condition false, or the action finishes)
--                    reset the counter
--   false          → never disable; keep running, just log

local function main(er)
  er.triggerVars.d = 0

  -- Default: disable on first error
  local r1 = er.eval("d == 1 => throw('boom')")
  er.triggerVars.d = 1
  r1:run()
  assert_truthy(r1._disabled, "default: disables on first error")

  -- Threshold: disable on the 3rd consecutive error
  local r2 = er.eval("d == 2 => throw('boom')", {disableOnError = 3})
  er.triggerVars.d = 2
  r2:run(); assert_truthy(not r2._disabled, "threshold: live after 1st error")
  r2:run(); assert_truthy(not r2._disabled, "threshold: live after 2nd error")
  r2:run(); assert_truthy(r2._disabled, "threshold: disabled after 3rd consecutive error")

  -- Clean completions reset the counter
  local r3 = er.eval("d == 3 => throw('boom')", {disableOnError = 2})
  er.triggerVars.d = 3
  r3:run()                    -- streak = 1
  er.triggerVars.d = 0
  r3:run()                    -- condition false → clean → streak = 0
  er.triggerVars.d = 3
  r3:run()                    -- streak = 1 again
  assert_truthy(not r3._disabled, "reset: isolated failures never reach the threshold")

  -- Never disable
  local r4 = er.eval("d == 4 => throw('boom')", {disableOnError = false})
  er.triggerVars.d = 4
  r4:run(); r4:run(); r4:run()
  assert_truthy(not r4._disabled, "false: never disables")

  -- enable() resets the counter
  local r5 = er.eval("d == 5 => throw('boom')", {disableOnError = 2})
  er.triggerVars.d = 5
  r5:run()                    -- streak = 1
  r5:enable()                 -- resets streak
  r5:run()                    -- streak = 1 again, still live
  assert_truthy(not r5._disabled, "enable: resets the counter")

  -- eval returns explicit failure status: nil, errmsg
  local v, err = er.eval("1 +")
  assert_truthy(v == nil and type(err) == "string", "eval: returns nil, err on failure")

  done()
end

function QuickApp:onInit() fibaro.EventRunner(main) end
