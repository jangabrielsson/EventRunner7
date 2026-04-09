--%%name:Rule
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
vm.defGlobal('getProp',  ER._funs.getProp)
vm.defGlobal('setProp',  ER._funs.setProp)

---------------------
ER._funs.defineTestDevice(88)  -- make device 88 available for testing
ER._funs.defineTestDevice(99)  -- make device 99 available for testing

local scanHead

local function eval(csp)
    local code   = vm.compile(csp)
    local status, val = vm.eval(code)
    if status == 'ok' then return val
    else error("eval error: " .. tostring(val)) end
end

local function test(src)
  local ok, result = pcall(function()
    local ast    = parse(src)
    local csp    = compileAST(ast)
    print(json.encodeFormated(csp))
    local trs = {triggers={},dailys=nil,intervals=nil,globals={}}
    scanHead(csp,trs)
    for i, t in ipairs(trs.triggers) do
      print("TRIGGER:", t.type, t.id, t.property)
    end
  end)
  print(ok,result)
end

local function stdScan(ast,trs)
  for i=2,#ast do scanHead(ast[i],trs) end
end

local stdHOPS = {"RETURN", "AND", "OR", "CALL","ADD", "SUB", "MUL", "DIV", "MOD", "POW", "EQ", "LT", "LTE", "GT", "GTE"}
local HOPS = {}
for _,op in ipairs(stdHOPS) do HOPS[op] = stdScan end
function HOPS.GETPROP(ast,trs)
  local obj = eval(ast[2])
  local key = ast[3]
  table.insert(trs.triggers, {type='device', id = obj, property = key})
end
function HOPS.BETW(ast,trs)
  local a,b = eval(ast[2]), eval(ast[3])
  table.insert(trs.dailys, {type='device', id = obj, property = key})
end

function scanHead(ast,trs)
  if type(ast) ~= 'table' then return end
  local op = HOPS[ast[1]]
  assert(op, "scanHead: missing op in AST node: " .. tostring(ast[1]))
  return op(ast,trs)
end

test("return 10:00..11:00")