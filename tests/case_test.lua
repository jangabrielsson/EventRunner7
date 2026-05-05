--%%name:case statement smoke tests
--%%offline:true

--%%headers:EventRunner.inc

local ER = fibaro.ER
local parse      = ER.parse
local compileAST = ER.compileAST
local vm         = ER.csp

-- Smoke tests for the new 'case' statement (sugar for if-elseif chain)

local passed, failed = 0, 0

local function run(src)
  local ast    = parse(src)
  local csp    = compileAST(ast)
  local code   = vm.compile(csp)
  local status, val = vm.eval(code)
  assert(status == 'ok', "eval status: " .. tostring(status))
  return val
end

local function test(label, src, expected)
  local ok, result = pcall(run, src)
  if not ok then
    failed = failed + 1
    print("ERROR ["..label.."]: "..tostring(result))
  elseif result == expected then
    passed = passed + 1
    print("PASS  ["..label.."]")
  else
    failed = failed + 1
    print("FAIL  ["..label.."]: expected="..tostring(expected).." got="..tostring(result))
  end
end

-- ── Tests ─────────────────────────────────────────────────────────────────

test("branch1 fires", [[
x = 1
case
  || x == 1 >> return 'one'
  || x == 2 >> return 'two'
  || true   >> return 'other'
end
]], 'one')

test("branch2 fires", [[
x = 2
case
  || x == 1 >> return 'one'
  || x == 2 >> return 'two'
  || true   >> return 'other'
end
]], 'two')

test("else branch fires", [[
x = 99
case
  || x == 1 >> return 'one'
  || x == 2 >> return 'two'
  || true   >> return 'other'
end
]], 'other')

test("no branch matches returns nil", [[
x = 99; y = 0
case
  || x == 1 >> y = 1
  || x == 2 >> y = 2
end
return y
]], 0)

test("single branch matches", [[
x = 5
case
  || x > 3 >> return 'big'
end
]], 'big')

test("single branch no match", [[
x = 1
case
  || x > 3 >> return 'big'
end
]], nil)

test("empty case is no-op", [[
y = 42
case end
return y
]], 42)

test("block with side-effect", [[
x = 1; y = 0
case
  || x == 1 >> y = 10; return y
  || true   >> y = 20; return y
end
]], 10)

-- Equivalence: case == if-elseif-else
local case_src = [[
x = 2
case
  || x == 1 >> return 'one'
  || x == 2 >> return 'two'
  || true   >> return 'other'
end
]]
local if_src = [[
x = 2
if x == 1 then return 'one'
elseif x == 2 then return 'two'
else return 'other'
end
]]
local ok1, r1 = pcall(run, case_src)
local ok2, r2 = pcall(run, if_src)
if ok1 and ok2 and r1 == r2 then
  passed = passed + 1
  print("PASS  [case == if-elseif-else: both '"..tostring(r1).."']")
else
  failed = failed + 1
  print("FAIL  [case == if-elseif-else]: case="..tostring(r1).." if="..tostring(r2))
end

-- ── Summary ───────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed", passed, failed))

