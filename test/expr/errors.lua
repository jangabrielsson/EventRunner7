--%%name:expr_errors
--%%include:../../EventRunner.inc
--%%file:../../src/Sim.lua,sim
--%%file:../../test/harness.lua,harness
--%%mode:offline

local function dehtml(s)
  s = s:gsub("</br>", "\n")
  s = s:gsub("&nbsp;", " ")
  return s
end

local function main(er)
  -- Capture after EventRunner has initialized system modules
  local ER             = fibaro.ER
  local parse          = ER.parse
  local compileAST     = ER.compileAST
  local compileASTWithMap = ER.compileASTWithMap
  local vm             = ER.csp

  -- Expect an error whose message matches pattern.
  -- Also checks that the cursor marker (^) is present when expect_cursor=true.
  local function testError(name, src, pattern, expect_cursor)
    local ok, err = pcall(function()
      local ast        = parse(src)
      local tree, smap = compileASTWithMap(ast)
      local code       = vm.compile(tree, smap)
      vm.eval(code, { src = src })
    end)
    local msg = tostring(err)
    if not ok and msg:find(pattern) and (not expect_cursor or msg:find("%^")) then
      assert_truthy(true, name)
    else
      assert_truthy(false, name)
      if ok then
        print("  (no error thrown)")
      elseif not msg:find(pattern) then
        print("  pattern: " .. pattern)
        print("  got:     " .. msg)
      elseif expect_cursor and not msg:find("%^") then
        print("  (no cursor marker ^)")
        print("  msg: " .. msg)
      end
    end
  end

  -- Expect an error thrown during rule compilation (compRule/scanHead path).
  local function testRuleError(name, src, pattern)
    local ok, err = pcall(er.eval, src, {verbosity="silent", defined=false, triggers=false, throw=true})
    local msg = tostring(err)
    if not ok and msg:find(pattern) then
      assert_truthy(true, name)
    else
      assert_truthy(false, name)
      if ok then
        print("  (no error thrown)")
      else
        print("  pattern: " .. pattern)
        print("  got:     " .. msg)
      end
    end
  end

  -- Expect a parse error (before compilation starts).
  local function testParseError(name, src, pattern)
    local ok, err = pcall(parse, src)
    local msg = tostring(err)
    if not ok and msg:find(pattern) then
      assert_truthy(true, name)
    else
      assert_truthy(false, name)
      if ok then
        print("  (no parse error)")
      else
        print("  pattern: " .. pattern)
        print("  got:     " .. msg)
      end
    end
  end

  -- ── Parse errors ──────────────────────────────────────────────────────────

  testParseError("unexpected token",
    "return 1 +++ 2",
    "Expected identifier")

  testParseError("missing then",
    "if true return 1 end",
    "Expected 'then'")

  testParseError("missing end",
    "if true then return 1",
    "Expected 'end'")

  testParseError("missing do (while)",
    "while true return 1 end",
    "Expected 'do'")

  testParseError("unclosed string",
    'return "hello',
    "Unexpected character")

  -- ── Runtime errors — arithmetic / type ───────────────────────────────────

  testError("arith on nil (div)",
    "return 7 / nil",
    "attempt to perform",
    true)

  testError("arith on nil (add)",
    "return 1 + nil",
    "attempt to perform",
    true)

  testError("arith on nil (sub)",
    "return nil - 1",
    "attempt to perform",
    true)

  testError("arith on string",
    'return "a" - 1',
    "attempt to sub",
    true)

  testError("compare nil",
    "return nil < 1",
    "attempt to compare",
    true)

  -- ── Runtime errors — undefined identifiers ───────────────────────────────

  testError("undefined local var",
    "return fopp()",
    "Variable 'fopp' is not defined",
    true)

  testError("call non-function",
    "local x = 42  return x()",
    "attempt to call",
    true)

  testError("index nil",
    "local x = nil  return x.foo",
    "[Ii]ndex",
    true)

  -- ── Runtime errors — global / QA variables ───────────────────────────────

  testError("undefined global var ($)",
    "return $nonexistent_gv_xyz",
    "nonexistent_gv_xyz",
    true)

  testError("assign in condition",
    "x = 8 => return 1",
    "Did you mean '==' instead of '='%? Use '==' for equality",
    true)

  testError("time constant 1",
    "a = 1:00",
    "Time literals must be in HH:MM",
    false)

  testError("time constant 2",
    "a = 10:0",
    "Time literals must be in HH:MM",
    false)

  testRuleError("undefined device",
    "200000:value => return 1",
    "No such device")

  testRuleError("no triggers",
    "true => return 1",
    "Rule has no triggers")

  testRuleError("head function not allowed",
    "setGlobal('y',1) & x == 5 => return 1",
    "Head function 'setGlobal'")

  testRuleError("registration error position",
    "setGlobal('y',1) & x == 5 => return 1",
    " at line 1, col 1")

  testRuleError("head function typo suggestion",
    "fnt(x) == 5 => return 1",
    "did you mean 'fmt'")

  testRuleError("head function impure hint",
    "post(ev) & x == 5 => return 1",
    "move it into the action")

  local sw = er.loadSimDevice("binarySwitch")
  testRuleError("property typo suggestion",
    string.format("%d:valu => return 1", sw.id),
    "did you mean 'value'")

  testRuleError("first_in time_window",
    "46:value first_in 'a' => return 1",
    "'first_in' requires a time window")

  testRuleError("duplicate modifier",
    "x == 1 cooldown 3 cooldown 5 => return 1",
    "Duplicate 'cooldown'")

  testRuleError("single + first_in",
    "x == 1 single first_in 07:00..08:00 => return 1",
    "cannot be combined with 'first_in'")

  testRuleError("first_in + single (reversed)",
    "x == 1 first_in 07:00..08:00 single => return 1",
    "cannot be combined with 'first_in'")

  testRuleError("debounce + first_in",
    "x == 1 debounce 2 first_in 07:00..08:00 => return 1",
    "cannot be combined with 'first_in'")

  -- ── Runtime errors — cursor placement ────────────────────────────────────

  do
    local src = "return 7 / nil"
    local ok, err = pcall(function()
      local ast        = parse(src)
      local tree, smap = compileASTWithMap(ast)
      local code       = vm.compile(tree, smap)
      vm.eval(code, { src = src })
    end)
    local msg = dehtml(tostring(err))
    local marker = msg:match("\n([%s%^]+)$") or msg:match("\n([%s%^]+)\n?$")
    local col = marker and (marker:find("%^") or 0) or 0
    assert_truthy(not ok and col >= 11, "cursor on nil operand (col " .. col .. ")")
  end

  -- ── User throw ────────────────────────────────────────────────────────────

  testError("user throw propagates",
    "throw('boom')",
    "boom",
    true)

  testError("throw with table value",
    "throw({code=42, msg='oops'})",
    "code",
    true)

  -- ── Unified runtime error format ───────────────────────────────────────────

  do
    -- Runtime errors carry exactly one source annotation (position + caret),
    -- not a duplicated "src:" tail.
    local src = "return 1 + x"
    local ok, err = pcall(function()
      local tree, smap = compileASTWithMap(parse(src))
      vm.eval(vm.compile(tree, smap), { src = src })
    end)
    local msg = tostring(err)
    assert_truthy(not ok, "runtime error: undefined variable raises")
    assert_match(msg, "Variable 'x' is not defined", "runtime error: names the variable")
    assert_match(msg, " at line 1, col 12", "runtime error: position annotation")
    assert_truthy(not msg:find("</br>  src:"), "runtime error: no duplicated src tail")
  end

  -- ── Friendly-message hints ─────────────────────────────────────────────────

  testError("arithmetic nil hint",
    "return nil + 1",
    "a value in the arithmetic is nil",
    true)

  -- ── Cursor placement: nil field access ────────────────────────────────────

  do
    local src = "a.b:value"
    local ok, err = pcall(function()
      local ast        = parse(src)
      local tree, smap = compileASTWithMap(ast)
      local code       = vm.compile(tree, smap)
      vm.eval(code, { src = src, vars = {a = {b = nil}} })
    end)
    local msg = dehtml(tostring(err))
    local marker = msg:match("\n([%s%^]+)$") or msg:match("\n([%s%^]+)\n?$")
    local col = marker and (marker:find("%^") or 0) or 0
    assert_truthy(not ok and col >= 3, "cursor on nil field 'b' (col " .. col .. ")")
  end

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
