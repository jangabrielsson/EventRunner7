--%%name:rule_truefor
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- trueFor: condition must be continuously true for N seconds.
  -- When using trigger variables, setting the var = 1 makes it
  -- continuously true, so the action fires after the delay.
  er.triggerVars.tf = 0

  test_rule(er, "trueFor(5, tf == 1) => return 'done'",
    function(er, rule)
      er.triggerVars.tf = 1
      rule:run()
    end,
    "done",
    "trueFor: fires after condition holds")

  -- After triggering, changing the variable to 0 should cancel trueFor
  -- (not tested here — requires explicit timing control)

  -- Contract check: the async watchdog timeout trueFor returns must be
  -- >= the condition duration, or the watchdog fires first and kills the
  -- rule (regression: timeout was returned in seconds but read as ms,
  -- so durations > 43:12 always failed with conditionFail).
  local function fake_cb()
    return setmetatable({
      cf = { ctx = {
        opts = { rule = {} },
        var_env = {{
          event = {},
          setTimeout = { function() return {} end },
          cancel = { function() end },
        }},
      } },
    }, { __call = function() end })
  end
  local timeout = er.async.trueFor(fake_cb(), 3600, true)
  assert_truthy(type(timeout) == "number" and timeout >= 3600*1000,
    "trueFor watchdog timeout covers 1h condition")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
