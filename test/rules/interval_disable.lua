--%%name:rule_interval_disable
--%%include:../../EventRunner.inc
--%%file:../../test/speed.lua,speed
--%%file:../../test/harness.lua,harness
--%%mode:offline
--%%time:2026/06/12 07:00:00

-- disable() stops the interval scheduler; enable() restarts it.
-- Clock-aligned intervals resume at the next boundary; relative intervals
-- restart from enable time.

local function main(er)
  er.triggerVars.n = 0
  local r = er.eval("@@00:05 => n = n + 1")  -- fires immediately (07:00), then 07:05, 07:10, ...

  setTimeout(function()
    assert_eq(er.triggerVars.n, 3, "fired three times before disable")
    r.disable()                               -- 07:11
  end, 11 * 60000)

  setTimeout(function()
    assert_eq(er.triggerVars.n, 3, "no fires while disabled")
    r.enable()                                -- 07:16
  end, 16 * 60000)

  setTimeout(function()
    assert_truthy(er.triggerVars.n >= 4,
      "fires again after enable (count=" .. er.triggerVars.n .. ")")
    done()
  end, 26 * 60000)
end

function QuickApp:onInit() fibaro.speedTime(4, function() fibaro.EventRunner(main) end) end
