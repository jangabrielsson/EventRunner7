--%%name:Parser unit tests
--%%offline:true

--%%headers:EventRunner.inc

local ER = fibaro.ER
local parse = ER.parse

-- ── helpers ──────────────────────────────────────────────────────────────

local passed, failed = 0, 0

-- Deep-equal comparison for AST tables
local function eq(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= 'table' then return a == b end
  if #a ~= #b then return false end
  for i = 1, #a do
    if not eq(a[i], b[i]) then return false end
  end
  return true
end

local function pp(t, depth)
  depth = depth or 0
  if type(t) ~= 'table' then return tostring(t) end
  local parts = {}
  for _, v in ipairs(t) do
    parts[#parts+1] = pp(v, depth+1)
  end
  return "{"..table.concat(parts, ", ").."}"
end

-- Unwrap SCRIPT > BLOCK > single stat
local function unwrap(ast)
  -- ast = {'SCRIPT', {'BLOCK', stat}}
  if ast[1] == 'SCRIPT' and ast[2] and ast[2][1] == 'BLOCK' then
    local block = ast[2]
    if #block == 2 then return block[2] end   -- single statement
    if #block == 1 then return block end       -- empty block
    return block                               -- multiple statements
  end
  return ast
end

local function check(label, src, expected)
  local ok, result = pcall(parse, src)
  if not ok then
    print(string.format("FAIL  %s\n      parse error: %s", label, result))
    failed = failed + 1
    return
  end
  local got = unwrap(result)
  if eq(got, expected) then
    print(string.format("pass  %s", label))
    passed = passed + 1
  else
    print(string.format("FAIL  %s", label))
    print(string.format("      expected: %s", pp(expected)))
    print(string.format("      got:      %s", pp(got)))
    failed = failed + 1
  end
end

local function checkErr(label, src)
  local ok, err = pcall(parse, src)
  if not ok then
    print(string.format("pass  %s  (error: %s)", label, err:match("[^\n]+") or err))
    passed = passed + 1
  else
    print(string.format("FAIL  %s  (expected parse error, got %s)", label, pp(unwrap(ok))))
    failed = failed + 1
  end
end

local function section(name)
  print("\n── "..name.." "..string.rep("─", 50 - #name))
end

-- ── literals ─────────────────────────────────────────────────────────────
section("Literals")

check("number",      "x = 42",      {'ASSIGN', {{'NAME','x'}}, {{'NUMBER',42}}})
check("string",      'x = "hi"',    {'ASSIGN', {{'NAME','x'}}, {{'STRING','hi'}}})
check("true",        "x = true",    {'ASSIGN', {{'NAME','x'}}, {{'BOOL',true}}})
check("false",       "x = false",   {'ASSIGN', {{'NAME','x'}}, {{'BOOL',false}}})
check("nil",         "x = nil",     {'ASSIGN', {{'NAME','x'}}, {{'NIL'}}})

-- ── arithmetic ───────────────────────────────────────────────────────────
section("Arithmetic")

check("add",        "x = a + b",    {'ASSIGN', {{'NAME','x'}}, {{'ADD',{'NAME','a'},{'NAME','b'}}}})
check("sub",        "x = a - b",    {'ASSIGN', {{'NAME','x'}}, {{'SUB',{'NAME','a'},{'NAME','b'}}}})
check("mul",        "x = a * b",    {'ASSIGN', {{'NAME','x'}}, {{'MUL',{'NAME','a'},{'NAME','b'}}}})
check("div",        "x = a / b",    {'ASSIGN', {{'NAME','x'}}, {{'DIV',{'NAME','a'},{'NAME','b'}}}})
check("neg",        "x = -a",       {'ASSIGN', {{'NAME','x'}}, {{'NEG',{'NAME','a'}}}})
check("precedence", "x = a + b * c",
  {'ASSIGN', {{'NAME','x'}}, {{'ADD',{'NAME','a'},{'MUL',{'NAME','b'},{'NAME','c'}}}}})
check("parens",     "x = (a + b) * c",
  {'ASSIGN', {{'NAME','x'}}, {{'MUL',{'PAREN',{'ADD',{'NAME','a'},{'NAME','b'}}},{'NAME','c'}}}})

-- ── comparison & logic ───────────────────────────────────────────────────
section("Comparison & logic")

check("eq",   "x = a == b",  {'ASSIGN', {{'NAME','x'}}, {{'EQ', {'NAME','a'},{'NAME','b'}}}})
check("neq",  "x = a ~= b",  {'ASSIGN', {{'NAME','x'}}, {{'NEQ',{'NAME','a'},{'NAME','b'}}}})
check("lt",   "x = a < b",   {'ASSIGN', {{'NAME','x'}}, {{'LT', {'NAME','a'},{'NAME','b'}}}})
check("lte",  "x = a <= b",  {'ASSIGN', {{'NAME','x'}}, {{'LTE',{'NAME','a'},{'NAME','b'}}}})
check("gt",   "x = a > b",   {'ASSIGN', {{'NAME','x'}}, {{'GT', {'NAME','a'},{'NAME','b'}}}})
check("gte",  "x = a >= b",  {'ASSIGN', {{'NAME','x'}}, {{'GTE',{'NAME','a'},{'NAME','b'}}}})
check("and",  "x = a & b",   {'ASSIGN', {{'NAME','x'}}, {{'AND',{'NAME','a'},{'NAME','b'}}}})
check("or",   "x = a | b",   {'ASSIGN', {{'NAME','x'}}, {{'OR', {'NAME','a'},{'NAME','b'}}}})
check("not",  "x = !a",      {'ASSIGN', {{'NAME','x'}}, {{'NOT',{'NAME','a'}}}})

-- ── calls & access ───────────────────────────────────────────────────────
section("Calls & access")

check("call no args",   "f()",       {'CALL',{'NAME','f'}})
check("call one arg",   "f(x)",      {'CALL',{'NAME','f'},{'NAME','x'}})
check("call two args",  "f(x, y)",   {'CALL',{'NAME','f'},{'NAME','x'},{'NAME','y'}})
check("method call",    "a:m()",     {'METHODCALL',{'NAME','a'},'m'})
check("method + arg",   "a:m(1)",    {'METHODCALL',{'NAME','a'},'m',{'NUMBER',1}})
check("field access",   "x = a.b",   {'ASSIGN',{{'NAME','x'}},{{'FIELD',{'NAME','a'},'b'}}})
check("index access",   "x = a[2]",  {'ASSIGN',{{'NAME','x'}},{{'INDEX',{'NAME','a'},{'NUMBER',2}}}})
check("chained .field", "x = a.b.c", {'ASSIGN',{{'NAME','x'}},{{'FIELD',{'FIELD',{'NAME','a'},'b'},'c'}}})
check("getprop",        "x = a:b",   {'ASSIGN',{{'NAME','x'}},{{'GETPROP',{'NAME','a'},'b'}}})

-- ── assignment ───────────────────────────────────────────────────────────
section("Assignment")

check("simple assign",   "x = 1",       {'ASSIGN',{{'NAME','x'}},{{'NUMBER',1}}})
check("multi assign",    "x, y = 1, 2", {'ASSIGN',{{'NAME','x'},{'NAME','y'}},{{'NUMBER',1},{'NUMBER',2}}})
check("field assign",    "a.b = 1",     {'ASSIGN',{{'FIELD',{'NAME','a'},'b'}},{{'NUMBER',1}}})
check("index assign",    "a[0] = 1",    {'ASSIGN',{{'INDEX',{'NAME','a'},{'NUMBER',0}}},{{'NUMBER',1}}})
check("setprop",         "a:b = 1",     {'SETPROP',{'NAME','a'},'b',{'NUMBER',1}})

-- ── local ────────────────────────────────────────────────────────────────
section("Local declarations")

check("local no val",    "local x",         {'LOCAL',{'x'},nil})
check("local with val",  "local x = 5",     {'LOCAL',{'x'},{{'NUMBER',5}}})
check("local multi",     "local a, b = 1, 2", {'LOCAL',{'a','b'},{{'NUMBER',1},{'NUMBER',2}}})

-- ── control flow ─────────────────────────────────────────────────────────
section("Control flow")

check("if then end",
  "if x then y = 1 end",
  {'IF', {'NAME','x'}, {'BLOCK',{'ASSIGN',{{'NAME','y'}},{{'NUMBER',1}}}}, {}, nil})

check("if then else end",
  "if x then y = 1 else y = 0 end",
  {'IF', {'NAME','x'},
    {'BLOCK', {'ASSIGN',{{'NAME','y'}},{{'NUMBER',1}}}},
    {},
    {'BLOCK', {'ASSIGN',{{'NAME','y'}},{{'NUMBER',0}}}}})

check("while",
  "while i < 10 do i = i + 1 end",
  {'WHILE', {'LT',{'NAME','i'},{'NUMBER',10}},
    {'BLOCK', {'ASSIGN',{{'NAME','i'}},{{'ADD',{'NAME','i'},{'NUMBER',1}}}}}})

check("repeat until",
  "repeat i = i + 1 until i > 5",
  {'REPEAT',
    {'BLOCK', {'ASSIGN',{{'NAME','i'}},{{'ADD',{'NAME','i'},{'NUMBER',1}}}}},
    {'GT',{'NAME','i'},{'NUMBER',5}}})

check("numeric for",
  "for i = 1, 10 do end",
  {'FOR_NUM','i',{'NUMBER',1},{'NUMBER',10},nil,{'BLOCK'}})

check("numeric for with step",
  "for i = 0, 10, 2 do end",
  {'FOR_NUM','i',{'NUMBER',0},{'NUMBER',10},{'NUMBER',2},{'BLOCK'}})

check("generic for",
  "for k, v in pairs(t) do end",
  {'FOR_IN',{'k','v'},{{'CALL',{'NAME','pairs'},{'NAME','t'}}},{'BLOCK'}})

check("do block",
  "do x = 1 end",
  {'DO', {'BLOCK', {'ASSIGN',{{'NAME','x'}},{{'NUMBER',1}}}}})

-- ── return & break ───────────────────────────────────────────────────────
section("Return & break")

check("return void",  "return",       {'RETURN', nil})
check("return val",   "return x",     {'RETURN', {'NAME','x'}})
check("return multi", "return x, y",  {'RETURN', {'NAME','x'},{'NAME','y'}})
check("break",        "while true do break end",
  {'WHILE', {'BOOL',true}, {'BLOCK', {'BREAK'}}})

-- ── function ─────────────────────────────────────────────────────────────
section("Function expressions")

check("func no params", "f = function() end",
  {'ASSIGN', {{'NAME','f'}}, {{'FUNCTION',{},{'BLOCK'}}}})

check("func with params", "f = function(a, b) return a end",
  {'ASSIGN', {{'NAME','f'}},
    {{'FUNCTION', {'a','b'}, {'BLOCK', {'RETURN',{'NAME','a'}}}}}})

-- ── table constructor ─────────────────────────────────────────────────────
section("Table constructors")

check("empty table",  "x = {}",       {'ASSIGN',{{'NAME','x'}},{{'TABLE'}}})
check("array table",  "x = {1, 2}",   {'ASSIGN',{{'NAME','x'}},{{'TABLE',{'TFIELD_VAL',{'NUMBER',1}},{'TFIELD_VAL',{'NUMBER',2}}}}})
check("named field",  'x = {a=1}',    {'ASSIGN',{{'NAME','x'}},{{'TABLE',{'TFIELD_NAME','a',{'NUMBER',1}}}}})
check("expr field",   'x = {[0]=1}',  {'ASSIGN',{{'NAME','x'}},{{'TABLE',{'TFIELD_EXPR',{'NUMBER',0},{'NUMBER',1}}}}})

-- ── block with multiple stats ─────────────────────────────────────────────
section("Multi-statement block")

do
  local ast = parse("x = 1 y = 2")
  local block = ast[2]  -- BLOCK
  if block[1] == 'BLOCK' and #block == 3 then
    print("pass  two statements in block")
    passed = passed + 1
  else
    print("FAIL  two statements in block: "..pp(block))
    failed = failed + 1
  end
end

-- ── $ prefixed variables ─────────────────────────────────────────────────
section("$ prefixed variables")

-- as rvalues
check("$var read",   "x = $foo",   {'ASSIGN',{{'NAME','x'}},{{'GV','foo'}}})
check("$$var read",  "x = $$foo",  {'ASSIGN',{{'NAME','x'}},{{'QV','foo'}}})
check("$$$var read", "x = $$$foo", {'ASSIGN',{{'NAME','x'}},{{'PV','foo'}}})

-- as lvalues (assignment targets)
check("$var assign",   "$foo = 1",   {'ASSIGN',{{'GV','foo'}},{{'NUMBER',1}}})
check("$$var assign",  "$$foo = 1",  {'ASSIGN',{{'QV','foo'}},{{'NUMBER',1}}})
check("$$$var assign", "$$$foo = 1", {'ASSIGN',{{'PV','foo'}},{{'NUMBER',1}}})

-- in expressions
check("$var in expr", "x = $a + $b",
  {'ASSIGN',{{'NAME','x'}},{{'ADD',{'GV','a'},{'GV','b'}}}})
check("$var as arg",  "f($x)",  {'CALL',{'NAME','f'},{'GV','x'}})

-- ── time unary operators ─────────────────────────────────────────────────
-- t/  = today-at (absolute time today)
-- n/  = next occurrence of that time
-- +/  = offset from now
-- The tokenizer converts HH:MM to a number, so these receive a number operand.
section("Time unary operators")

check("t/ today",    "x = t/600",   {'ASSIGN',{{'NAME','x'}},{{'TODAY',   {'NUMBER',600}}}})
check("n/ nexttime", "x = n/600",   {'ASSIGN',{{'NAME','x'}},{{'NEXTTIME',{'NUMBER',600}}}})
check("+/ plustime", "x = +/600",   {'ASSIGN',{{'NAME','x'}},{{'PLUSTIME',{'NUMBER',600}}}})

check("t/ in condition", "if t/600 > now then end",
  {'IF', {'GT',{'TODAY',{'NUMBER',600}},{'NOW'}}, {'BLOCK'}, {}, nil})

check("t/ as arg", "f(t/600, n/900)",
  {'CALL',{'NAME','f'},{'TODAY',{'NUMBER',600}},{'NEXTTIME',{'NUMBER',900}}})

-- ── error cases ───────────────────────────────────────────────────────────
section("Error cases")

checkErr("missing 'end'",       "if x then y = 1")
checkErr("missing 'then'",      "if x y = 1 end")
checkErr("unexpected token",    "= x")

-- ── summary ───────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed  (%d total)", passed, failed, passed+failed))
