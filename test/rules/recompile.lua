--%%name:rule_recompile
--%%include:../../EventRunner.inc
--%%file:../../src/Sim.lua,sim
--%%file:../../test/harness.lua,harness
--%%mode:offline

-- rule:recompile() rebinds the rule in place: names in the condition are
-- resolved at compile time, so after dID changes the rule keeps firing on
-- the OLD device until recompiled (or the QA restarts / er.reset()).

local function main(er)
  local sw1 = er.loadSimDevice("binarySwitch")   -- numeric sim id
  local sw2 = er.loadSimDevice("binarySwitch")   -- next id

  er.eval(string.format("dID = %d", sw1))
  local r = er.eval("dID:value => return dID")

  local results = {}
  r.onDone = function(v) results[#results + 1] = v end

  fibaro.call(sw1, 'setValue', true)  -- posts a device event → rule fires (async)

  setTimeout(function()
    assert_eq(#results, 1, "fires on the original device")
    assert_eq(results[1], sw1, "returns the compile-time-bound id")

    -- Rebind the global and recompile the rule in place
    er.eval(string.format("dID = %d", sw2.id))
    r:recompile()

    fibaro.call(sw1, 'setValue', false)  -- old device: subscription dropped
    fibaro.call(sw2, 'setValue', true)   -- new device: fires after recompile

    setTimeout(function()
      assert_eq(#results, 1, "old device no longer triggers")
      assert_eq(#results, 2, "recompiled rule fires on the new device")
      assert_eq(results[2], sw2.id, "returns the new bound id")
      done()
    end, 100)
  end, 100)
end

function QuickApp:onInit() fibaro.EventRunner(main) end
