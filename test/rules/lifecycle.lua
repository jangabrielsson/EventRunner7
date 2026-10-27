--%%name:rule_lifecycle
--%%include:../../EventRunner.inc
--%%file:../../test/harness.lua,harness
--%%mode:offline

-- Rule lifecycle: state() accessor and the active (in-flight runs) counter.

local function main(er)
  er.triggerVars.d = 0
  local r = er.eval("d == 1 => wait(0.5); return 42")

  assert_eq(r:state(), "enabled", "state: enabled after registration")

  -- Suspended run: active counts it
  er.triggerVars.d = 1
  r:run()
  assert_eq(r.active, 1, "active: 1 run suspended in wait")

  r.disable()
  assert_eq(r:state(), "disabled", "state: disabled")
  r.enable()
  assert_eq(r:state(), "enabled", "state: re-enabled")
  assert_eq(r.active, 1, "active: still 1 while suspended across disable/enable")

  -- The suspended run completes after the wait: active drops, onDone fires
  r.onDone = function(v)
    assert_eq(v, 42, "run completed with 42")
    assert_eq(r.active, 0, "active: back to 0 after completion")
    done()
  end
end

function QuickApp:onInit() fibaro.EventRunner(main) end
