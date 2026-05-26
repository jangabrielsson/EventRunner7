local fmt = string.format

-- ── Mini test runner ──────────────────────────────────────────────────────────
-- Each test function receives (er, rule, vars, triggerVars).
-- Call done()        from any rule action to mark the test passed.
-- Call testFail(msg) to fail immediately with a message.
-- A per-test timeout (default 3 s) counts as failure if done() isn't called.

function runTests(er, tests)
  local results = {}
  local i, timer, currentEr = 0, nil, er
  local runOne  -- forward-declared (finish references it)

  local function finish(status, msg)
    if timer then clearTimeout(timer); timer = nil end
    _G.done     = function() error("done() called more than once in test: " .. tests[i].name, 2) end
    _G.testFail = function() error("testFail() called after test already finished: " .. tests[i].name, 2) end
    local icons = {pass="✅", fail="❌", timeout="⏰"}
    local line = fmt("%s %s", icons[status], tests[i].name)
    if msg then line = line .. "  — " .. msg end
    print(line)
    results[#results+1] = {status = status}

    i = i + 1
    if i > #tests then
      local npass = 0
      for _,r in ipairs(results) do if r.status == "pass" then npass = npass + 1 end end
      print(fmt("─────────────────────\n%d/%d tests passed", npass, #results))
    else
      currentEr.reset(runOne)
    end
  end

  runOne = function(er2)
    currentEr = er2
    local t = tests[i]
    _G.done     = function()    finish("pass") end
    _G.testFail = function(msg) finish("fail", msg) end
    timer = setTimeout(function() finish("timeout") end, t.timeout or 3000)
    t.fn(er2, er2.eval, er2.variables, er2.triggerVars, er2)
  end

  i = 1
  runOne(er)
end
