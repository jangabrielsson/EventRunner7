--%%name:rule_head_purity
--%%include:../../EventRunner.inc
--%%file:../../test/harness.lua,harness
--%%mode:offline

-- Head-purity whitelist: rule conditions may only CALL whitelisted functions
-- (pure builtins + condition modifiers). Anything else errors at registration.

local function main(er)
  er.triggerVars.x = 0

  -- Side-effecting builtin in a head → registration error
  local ok, err = pcall(function() er.eval("setGlobal('y',1) & x == 5 => log('x')", {throw=true}) end)
  assert_truthy(not ok, "head: setGlobal errors")
  assert_match(err or "", "Head function 'setGlobal'", "head: setGlobal error message")

  -- Unknown user function in a head → registration error
  ok, err = pcall(function() er.eval("myFun(x) == 5 => log('x')", {throw=true}) end)
  assert_truthy(not ok, "head: unknown fun errors")
  assert_match(err or "", "Head function 'myFun'", "head: unknown fun error message")

  -- Condition modifiers (parser-injected) are whitelisted
  assert_truthy(er.eval("x == 5 since 3 => log('x')") ~= nil, "head: since registers")
  assert_truthy(er.eval("x == 5 cooldown 3 => log('x')") ~= nil, "head: cooldown registers")
  assert_truthy(er.eval("x == 5 every 3 => log('x')") ~= nil, "head: every registers")
  assert_truthy(er.eval("once(x == 5) => log('x')") ~= nil, "head: once registers")

  -- Pure builtins are whitelisted
  assert_truthy(er.eval("rnd(1,2) == 1 & x == 5 => log('x')") ~= nil, "head: rnd registers")
  assert_truthy(er.eval("date('* * * * mon') & x == 5 => log('x')") ~= nil, "head: date registers")
  assert_truthy(er.eval("log('dbg') & x == 5 => log('x')") ~= nil, "head: log registers (debug probe)")

  -- Indexed calls (visible inline code) pass through unclassified
  assert_truthy(er.eval("math.floor(x) == 5 => log('x')") ~= nil, "head: indexed call registers")

  -- User whitelist extension
  fibaro.ER._headFuns.myFun = true
  assert_truthy(er.eval("myFun(x) == 5 => log('x')") ~= nil, "head: whitelisted user fun registers")

  done()
end

function QuickApp:onInit() fibaro.EventRunner(main) end
