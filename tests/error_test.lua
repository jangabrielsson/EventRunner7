--%%name:Error handling unit tests
--%%offline:true

--%%file:Tokenizer.lua,tokenizer
--%%file:Parser.lua,parser
--%%file:Utils.lua,utils
--%%file:CSP.lua,csp
--%%file:Props.lua,props
--%%file:Compiler.lua,compiler
--%%file:ScriptFuns.lua,scriptfuns
--%%file:Rule.lua,rule
--%%file:Sim.lua,sim

local ER             = fibaro.ER
local parse          = ER.parse
local compileAST     = ER.compileAST
local compileASTWithMap = ER.compileASTWithMap
local vm             = ER.csp

local function main()

  -- ── Test harness ──────────────────────────────────────────────────────────

  local passed, failed = 0, 0

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
    if ok then
      failed = failed + 1
      print("FAIL (no error): " .. name)
    elseif not msg:find(pattern) then
      failed = failed + 1
      print("FAIL (wrong msg): " .. name .. "\n  pattern : " .. pattern .. "\n  got     : " .. msg)
    elseif expect_cursor and not msg:find("%^") then
      failed = failed + 1
      print("FAIL (no cursor): " .. name .. "\n  msg: " .. msg)
    else
      passed = passed + 1
      print("PASS: " .. name)
    end
  end

  -- Expect a parse error (before compilation even starts).
  local function testParseError(name, src, pattern)
    local ok, err = pcall(parse, src)
    local msg = tostring(err)
    if ok then
      failed = failed + 1
      print("FAIL (no parse error): " .. name)
    elseif not msg:find(pattern) then
      failed = failed + 1
      print("FAIL (wrong parse msg): " .. name .. "\n  pattern : " .. pattern .. "\n  got     : " .. msg)
    else
      passed = passed + 1
      print("PASS: " .. name)
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

  -- ── Runtime errors — cursor placement ────────────────────────────────────
  -- These check that the ^ appears under the right token, not just anywhere.

  -- Cursor should land on `nil` (the bad operand), not on `/`
  do
    local src = "return 7 / nil"
    local ok, err = pcall(function()
      local ast        = parse(src)
      local tree, smap = compileASTWithMap(ast)
      local code       = vm.compile(tree, smap)
      vm.eval(code, { src = src })
    end)
    local msg = tostring(err)
    -- The marker line must start with spaces then ^ roughly at column 12 (the 'n' of nil)
    local marker = msg:match("\n([%s%^]+)$") or msg:match("\n([%s%^]+)\n?$")
    local col = marker and (marker:find("%^") or 0) or 0
    if not ok and col >= 11 then
      passed = passed + 1
      print("PASS: cursor on nil operand (col " .. col .. ")")
    elseif not ok then
      failed = failed + 1
      print("FAIL: cursor position wrong for nil operand (col=" .. col .. ")\n  " .. msg)
    else
      failed = failed + 1
      print("FAIL: expected error for 'return 7 / nil'")
    end
  end

  -- ── User throw (throw is a ScriptFuns global, not a keyword) ──────────────

  testError("user throw propagates",
    "throw('boom')",
    "boom",
    false)

  testError("throw with table value",
    "throw({code=42, msg='oops'})",
    "code",
    false)

  -- ── Summary ───────────────────────────────────────────────────────────────

  print(string.format("\n%d passed, %d failed", passed, failed))

end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
