--%%name:rule_device_triggers
--%%include:../../EventRunner.inc
--%%file:../../src/Sim.lua,sim
--%%file:../../src/Setup.lua,stdfuns
--%%file:../../test/harness.lua,harness
--%%mode:offline

local function main(er)
  local sw  = er.loadSimDevice("binarySwitch")
  local dim = er.loadSimDevice("multilevelSwitch")
  local sens = er.loadSimDevice("motionSensor")

  er.defvars({ sw = sw, dim = dim, sens = sens })
  er.triggerVars.step = 0

  -- ── Device property change triggers rule ────────────────────────────────

  -- Step 0: setup.  When sw turns on, advance to step 1.
  er.eval("sw:isOn => step = 1")
  -- When step 1 fires, advance to step 2.
  er.eval("step == 1 => step = 2")
  -- When step 2 fires, turn sw off.
  er.eval("step == 2 => sw:off")
  -- When sw turns off, advance to step 3.
  er.eval("sw:isOff => step = 3")
  -- When step 3 fires, set dimmer and advance.
  er.eval("step == 3 => dim:value = 77; step = 4")
  -- When dim value changes (>50), advance.
  er.eval("dim:value > 50 => step = 5")
  -- When step 5 fires, trigger sensor.
  er.eval("step == 5 => sens:value = true")
  -- When sensor breached, advance to step 6.
  er.eval("sens:breached => step = 6")
  -- Step 6: final assertion — all triggers fired in chain.
  er.eval("step == 6 => return 'all_triggered'", { group = "device_test" })

  -- Kick off the chain: turn sw on.
  local kickoff = er.eval("sw:on", { result = true })

  -- The final rule re-evaluates on every step change; assert only when the
  -- chain actually completes with the final value.
  local final_done = false
  local fr = er.eval("step == 6 => return 'final'")
  fr.onDone = function(v)
    if v == 'final' and not final_done then
      final_done = true
      assert_truthy(true, "device trigger chain: sw→step1→step2→sw:off→step3→dim→step5→sens→step6")
      done()
    end
  end

  -- Safety: fail if the chain never completes.
  setTimeout(function()
    if not final_done then
      assert_truthy(false, "device trigger chain never completed")
      done()
    end
  end, 60000)
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
