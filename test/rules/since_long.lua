--%%name:rule_since_long
--%%include:../../EventRunner.inc
--%%file:../../test/harness.lua,harness
--%%mode:offline

-- Regression: 'since' windows longer than the old 30-day async watchdog used
-- to be resumed with false mid-window. trueFor now returns "no watchdog"
-- (protocol: true, false), so the since window timer is the only timer —
-- windows of any length are safe.

local WINDOW = 31 * 86400  -- 31 days in seconds (> the old 30-day watchdog)

local function main(er)
  er.triggerVars.d = 0
  local r = er.eval(string.format("d == 1 since %d => return 42", WINDOW))

  er.triggerVars.d = 1
  r:run()   -- condition true → since window timer armed, run suspends

  local n, stored = 0, nil
  for ref, ms in pairs(r.timers) do
    n = n + 1
    stored = ms
  end
  assert_eq(n, 1, "long since: exactly one timer (no watchdog)")
  assert_eq(stored, WINDOW * 1000, "long since: timer holds the full window")

  -- terminate kills the suspended run: active counter drops
  r.terminate()
  assert_eq(r.active, 0, "terminate: active counter reset")

  done()
end

function QuickApp:onInit() fibaro.EventRunner(main) end
