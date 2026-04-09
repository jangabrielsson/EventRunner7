--%%name:Expression compiler unit tests
--%%offline:true

--%%file:Tokenizer.lua,tokenizer
--%%file:Parser.lua,parser
--%%file:CSP.lua,csp
--%%file:Compiler.lua,compiler
--%%file:ScriptFuns.lua,scriptfuns

local parse      = ER._tools.parse
local compileAST = ER._tools.compileAST
local vm         = fibaro.CONT

-- Seed globals available inside compiled EventScript
vm.defGlobal('print',    print)
vm.defGlobal('tostring', tostring)
vm.defGlobal('tonumber', tonumber)
vm.defGlobal('math',     math)
vm.defGlobal('getProp',  ER._funs.getProp)
vm.defGlobal('setProp',  ER._funs.setProp)

-- ── Test harness ──────────────────────────────────────────────────────────

local passed, failed = 0, 0

local function eq(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) == 'table' then
    for k, v in pairs(a) do if not eq(v, b[k]) then return false end end
    for k, v in pairs(b) do if not eq(a[k], v) then return false end end
    return true
  end
  return a == b
end

local function test(name, src, expected)
  local ok, result = pcall(function()
    local ast    = parse(src)
    local csp    = compileAST(ast)
    local code   = vm.compile(csp)
    local status, val = vm.eval(code)
    assert(status == 'ok', "eval status: " .. tostring(status))
    return val
  end)
  if ok and eq(result, expected) then
    passed = passed + 1
    print("PASS: " .. name)
  elseif ok then
    failed = failed + 1
    print("FAIL: " .. name
      .. "  expected=" .. tostring(expected)
      .. "  got="      .. tostring(result))
  else
    failed = failed + 1
    print("ERROR: " .. name .. "  " .. tostring(result))
  end
end

-- ── Literals ──────────────────────────────────────────────────────────────

test("string literal",    'return "hello"',  "hello")
test("integer literal",   'return 42',        42)
test("float literal",     'return 3.14',      3.14)
test("true literal",      'return true',      true)
test("false literal",     'return false',     false)
test("nil literal",       'return nil',       nil)

-- ── Arithmetic ────────────────────────────────────────────────────────────

test("addition",          'return 2 + 3',     5)
test("subtraction",       'return 10 - 4',    6)
test("multiplication",    'return 3 * 4',     12)
test("division",          'return 10 / 4',    2.5)
test("mul before add",    'return 2 + 3 * 4', 14)
test("parens override",   'return (2+3) * 4', 20)
test("unary minus",       'return -5',        -5)
test("unary minus expr",  'return -(2+3)',    -5)

-- ── Comparison ────────────────────────────────────────────────────────────

test("eq true",           'return 5 == 5',    true)
test("eq false",          'return 5 == 6',    false)
test("neq true",          'return 5 ~= 6',    true)
test("neq false",         'return 5 ~= 5',    false)
test("lt true",           'return 3 < 5',     true)
test("lt false",          'return 5 < 3',     false)
test("lte equal",         'return 5 <= 5',    true)
test("gt true",           'return 7 > 3',     true)
test("gte false",         'return 3 >= 4',    false)

-- ── Logical ───────────────────────────────────────────────────────────────

test("not true",          'return !true',       false)
test("not false",         'return !false',      true)
test("and tt",            'return true & true', true)
test("and tf",            'return true & false',false)
test("or ft",             'return false | true',true)
test("or ff",             'return false | false',false)

-- ── String concatenation ──────────────────────────────────────────────────

test("concat",            'return "hello" ++ " world"', "hello world")
test("concat number",     'return "val=" ++ 42',         "val=42")

-- ── Local variables ───────────────────────────────────────────────────────

test("single local",      'local x = 10  return x',                    10)
test("local arithmetic",  'local x = 3   return x * 4',                12)
test("two locals",        'local x = 3   local y = 4  return x + y',   7)
test("multi-local decl",  'local x, y = 3, 4  return x + y',           7)
test("local assign",      'local x = 1   x = x + 1  return x',         2)
test("local uninit",      'local x  return x',                          nil)

-- ── If / else ─────────────────────────────────────────────────────────────

test("if true branch",
  'local x = 10  if x > 5 then return "big" else return "small" end',
  "big")

test("if false branch",
  'local x = 2  if x > 5 then return "big" else return "small" end',
  "small")

test("if no else nil",
  'if false then return 1 end  return nil',
  nil)

test("elseif chain",
  'local x = 5  if x > 10 then return "high" elseif x > 3 then return "mid" else return "low" end',
  "mid")

-- ── While loop ────────────────────────────────────────────────────────────

test("while loop",
  'local i = 0  local s = 0  while i < 5 do  i = i + 1  s = s + i  end  return s',
  15)   -- 1+2+3+4+5

-- ── Function calls ────────────────────────────────────────────────────────

vm.defGlobal('add', function(a, b) return a + b end)
vm.defGlobal('greet', function(name) return "hi " .. name end)

test("call global fn no arg",   'return tostring(42)',               "42")
test("call global fn string",   'return tonumber("99")',              99)
test("call user global",        'return add(3, 4)',                   7)
test("call with expr args",     'return add(2+1, 4+1)',               8)
test("call result in expr",     'local x = tonumber("10")  return x + 5', 15)
test("call in condition",       'if tonumber("1") == 1 then return "ok" end  return "no"', "ok")
test("call string arg",         'return greet("world")',              "hi world")
test("fn stored in local",      'local f = tostring  return f(123)',  "123")

-- ── Field access ──────────────────────────────────────────────────────────

test("field access",            'return math.pi > 3',                true)
test("field fn call",           'return math.abs(-7)',               7)
test("field fn two args",       'return math.max(3, 7)',             7)
test("field fn min",            'return math.min(10, 4)',            4)
test("chained field",           'return math.huge > 1000000',        true)
test("field result in expr",    'return math.abs(-3) + math.abs(-4)', 7)

-- ── SETPROP / GETPROP  (88:key = val / 88:key) ───────────────────────────
ER._funs.defineTestDevice(88)  -- make device 88 available for testing
ER._funs.defineTestDevice(99)  -- make device 99 available for testing

test("setprop returns value",
  '88:value = 42  return 88:value',
  42)

test("getprop after set",
  '88:score = 100  return 88:score',
  100)

test("setprop expression value",
  '88:x = 3 + 4  return 88:x',
  7)

test("setprop overwrites",
  '88:a = 1  88:a = 2  return 88:a',
  2)

test("multiple keys independent",
  '88:x = 10  88:y = 20  return 88:x + 88:y',
  30)

test("two devices independent",
  '88:v = 5  99:v = 6  return 88:v + 99:v',
  11)

test("device id from local",
  'local d = 88  d:level = 77  return d:level',
  77)

test("setprop in condition",
  '88:on = true  if 88:on then return "yes" else return "no" end',
  "yes")

-- ── Table constructors ────────────────────────────────────────────────────

test("empty table",
  'local t = {}  return t',
  {})

test("named fields",
  'local t = {x=1, y=2}  return t.x + t.y',
  3)

test("positional fields",
  'local t = {10, 20, 30}  return t[1] + t[3]',
  40)

test("mixed fields",
  'local t = {a=5, 99}  return t.a + t[1]',
  104)

test("expr key",
  'local k = "foo"  local t = {[k]=42}  return t.foo',
  42)

test("nested table",
  'local t = {inner={v=7}}  return t.inner.v',
  7)

-- ── Event shorthand  #Name  /  #Name{fields} ─────────────────────────────

test("bare event type",
  'local e = #myEvent  return e.type',
  "myEvent")

test("event with fields",
  'local e = #doorOpen{id=88, state=true}  return e.type',
  "doorOpen")

test("event field access",
  'local e = #tempAlert{value=23}  return e.value',
  23)

test("event type equality",
  'local e = #lightOn  return e.type == "lightOn"',
  true)

test("event multi-field",
  'local e = #move{x=3, y=4}  return e.x + e.y',
  7)

test("event overrides type",
  -- type is always the first field; named fields after cannot shadow it
  'local e = #foo{a=1}  return e.type ++ ":" ++ tostring(e.a)',
  "foo:1")

-- ── Summary ───────────────────────────────────────────────────────────────

print(string.format("\n%d passed, %d failed", passed, failed))