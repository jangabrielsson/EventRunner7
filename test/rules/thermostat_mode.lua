--%%name:rule_thermostat_mode
--%%include:../../EventRunner.inc
--%%file:../../src/Sim.lua,sim
--%%file:../../src/Setup.lua,stdfuns
--%%file:../../test/harness.lua,harness
--%%mode:offline

-- Regression: thermostatMode is a writable property.
--   `id:thermostatMode = 'Off'` must call setThermostatMode() on the device
--   (previously it errored with "attempt to call a nil value (field 'set')"
--   because the property entry had no setter).
-- Also:
--   - read-only props fail the set with a clear "no such property (set)"
--     error instead of the cryptic nil-call
--   - write-only props fail the get with a clear "no such property (get)"
--     error instead of a nil-call on .get
--   - ER.loadSimDevice can load the hvac templates (they define Sim_ classes)
--     without poisoning the host QA's QuickApp class

local function main(er)
  -- Loads tests/stdQAs/thermostatHeatCool.lua via its Sim_ class.
  local thermo = er.loadSimDevice("thermostatHeatCool")
  local dim = er.loadSimDevice("multilevelSwitch")
  er.defvars({ thermo = thermo, dim = dim })
  er.triggerVars.step = 0

  -- The template must not leak methods onto the host QA's QuickApp class
  -- (the old `local QuickApp = fibaro.SimQuickApp or QuickApp` pattern
  -- redefined the host's onInit).
  assert_truthy(QuickApp.setThermostatMode == nil,
    "load: host QA class not poisoned by template")

  -- ── 1. thermostatMode is settable via setThermostatMode ─────────────────

  local r1 = er.eval("step == 1 => thermo:thermostatMode = 'Off'")
  er.triggerVars.step = 1
  r1:run()
  assert_truthy(not r1._disabled, "setter: rule stays enabled (no error)")
  assert_truthy(r1.lastError == nil, "setter: no rule error recorded")
  assert_eq(fibaro.get(thermo, "thermostatMode"), "Off",
    "setter: setThermostatMode called, device mode is 'Off'")

  -- ── 2. Read-only property fails with a clear error, not a nil-call ──────

  -- thermostatModeFuture is get-only (GETPROP entry, no setter).
  local r2 = er.eval("step == 2 => thermo:thermostatModeFuture = 'Auto'")
  er.triggerVars.step = 2
  r2:run()
  assert_truthy(r2._disabled, "read-only: rule disabled after error")
  assert_truthy(r2.lastError ~= nil, "read-only: error recorded")
  if r2.lastError then
    assert_truthy(r2.lastError:find("no such property :thermostatModeFuture", 1, true) ~= nil,
      "read-only: clear 'no such property (set)' message")
    assert_truthy(r2.lastError:find("attempt to call a nil value", 1, true) == nil,
      "read-only: no cryptic nil-call error")
  end

  -- ── 3. Write-only property fails the get with a clear error ─────────────

  -- dim is a set-only command (no getter): using it in a condition must
  -- fail at compile with a clear message, not a nil-call on .get.
  local v, err = er.eval("dim:dim == 5 => step = 1")
  assert_truthy(v == nil and type(err) == "string",
    "write-only: eval fails on get of set-only property")
  if type(err) == "string" then
    assert_truthy(err:find("no such property", 1, true) ~= nil,
      "write-only: clear 'no such property (get)' message")
    assert_truthy(err:find("attempt to call a nil value", 1, true) == nil,
      "write-only: no cryptic nil-call error")
  end

  done()
end

function QuickApp:onInit() fibaro.EventRunner(main) end
