--%%name:expr_errors
--%%headers:EventRunner.inc
--%%file:src/Sim.lua,sim
--%%file:test/harness.lua,harness
--%%offline:true

local ER             = fibaro.ER
local parse          = ER.parse
local compileAST     = ER.compileAST
local compileASTWithMap = ER.compileASTWithMap
local vm             = ER.csp

local function dehtml(s)
  s = s:gsub("</br>", "\n")
  s = s:gsub("&nbsp;", " ")
  return s
end

local function main(er)

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
    "Undefined variable",
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
    "log('ok') => return 1",
    "Rule has no triggers")

  testRuleError("first_in time_window",
    "46:value first_in 'a' => return 1",
    "'first_in' requires a time window")

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
    false)

  testError("throw with table value",
    "throw({code=42, msg='oops'})",
    "code",
    false)

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
