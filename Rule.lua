fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
local vm = ER.csp

local eval, resume 
local ruleRunner, resumeRunner, sourceTrigger
local RULEIDX = 0
local rules = {}

local dfltPrefix = {
  warningPrefix = "⚠️",
  ruleDefPrefix = "✅",
  triggerListPrefix = "⚡",
  dailyListPrefix = "🕒",
  startPrefix = "🎬", 
  stopPrefix = "🛑",
  successPrefix = "👍", -- 😀
  failPrefix = "👎", -- 🙁
  resultPrefix = "📋", 
  errorPrefix = "❌",
  waitPrefix = "💤", -- 😴
  waitedPrefix = "⏰", -- 🤗
}

---------------------- Create rule ---------------------------------
local function compRule(r)
  local fun = ER.csp.compile(r) -- compiles the rule into CSP code
  local head = r[2]  -- the trigger part of the rule

  RULEIDX = RULEIDX + 1
  local rule = {fun = fun, id = RULEIDX}
  rules[RULEIDX] = rule -- store the rule in a global table for later reference

  local trs = {triggers={},dailys={},intervals=nil}
  scanHead(head,trs)
  for _,tr in pairs(trs.triggers) do 
    setmetatable(tr,ER.EventMT) 
    sourceTrigger:subscribe(tr,rule.fun)
  end

  function rule:run(trigger)
    print("Running rule:", self.id, "triggered by:", trigger)
    return ruleRunner(self.fun)
  end

  function rule:dumpTriggers()
    print("Rule", self.id, "triggers:")
    for _,tr in pairs(trs.triggers) do
      print(" ", dfltPrefix.triggerListPrefix, tr)
    end
    for _,t in ipairs(trs.dailys) do
      print(" ", dfltPrefix.dailyListPrefix, ER.timeStr(t()))
    end
  end
  
  setmetatable(rule,{
    __tostring = function(self)
      return "RULE"..tostring(self.id)
    end
  })

  rule:dumpTriggers() -- dump triggers for debugging
  return rule
end

---------------------- Scan rule for triggers -----------------

local function exprFun(csp)
  return function()
    local code   = ER.csp.compile(csp)
    local status, val = ER.csp.eval(code)
    if status == 'ok' then 
      return val,function() return select(2,ER.csp.eval(code)) end
    else error("eval error: " .. tostring(val)) end
  end
end

local function stdScan(ast,trs)
  for i=2,#ast do scanHead(ast[i],trs) end
end

-- Std Head Ops: just scan their children
local stdHOPS = {"RETURN", "NOT", "AND", "OR", "CALL","ADD", "SUB", "MUL", "DIV", "MOD", "POW", "EQ", "LT", "LTE", "GT", "GTE"}
local HOPS = {}
for _,op in ipairs(stdHOPS) do HOPS[op] = stdScan end

function HOPS.GETPROP(ast,trs)
  local obj = exprFun(ast[2])()
  local key = ast[3]
  trs.triggers[key..obj] = {type='device', id = obj, property = key}
end

function HOPS.BETW(ast,trs)
  local a,afun = exprFun(ast[2])()
  local b,bfun = exprFun(ast[3])()
  assert(type(a) == "number" and type(b) == "number", "BETW operands must be numbers")
  table.insert(trs.dailys, afun)
  table.insert(trs.dailys, bfun)
end

function HOPS.DAILY(ast,trs)
  local a,afun = exprFun(ast[2])()
  assert(type(a) == "number", "DAILY operand must be a number")
  table.insert(trs.dailys, afun)
end

function HOPS.INTERV(ast,trs)
  local a,afun = exprFun(ast[2])()
  assert(type(a) == "number", "INTERV operands must be number")
  table.insert(trs.intervals, afun)
end

function HOPS.GV(ast,trs)
  trs.triggers["GLOB:"..ast[2]] = {type='global-variable', name = ast[2]}
end

function HOPS.QV(ast,trs)
  trs.triggers["QV:"..ast[2]] = {type='quickVar', name = ast[2]}
end

function HOPS.TVAR(ast,trs)
  trs.triggers["TVAR:"..ast[2]] = {type='triggerVar', name = ast[2]}
end

function scanHead(ast,trs)
  if type(ast) ~= 'table' then return end
  local op = HOPS[ast[1]]
  assert(op, "scanHead: missing op in AST node: " .. tostring(ast[1]))
  return op(ast,trs)
end

-------------------- Run rule ---------------------------------
local yieldHandlers = {
  sleep = function(cf,cb,ms)
    setTimeout(function()
      resumeRunner({resume(cf,ms)}, cb)
    end, ms)
  end,
}

function resumeRunner(res, cb)
  if res[1] == 'suspended' then
    local cf,tag = res[2],res[3]
    if yieldHandlers[tag] then
      return yieldHandlers[tag](cf,cb,table.unpack(res, 4, res.n))
    else
      error("no yield handler for tag: " .. tostring(tag))
    end
  end
  cb(table.unpack(res, 2, res.n))
end

function ruleRunner(f) 
  eval,resume = ER.csp.eval, ER.csp.resume
  local res = nil
  resumeRunner({eval(f)}, function(...)
    if res == true then
      print("RESULT:", ...)
    else res = {...} end
  end)
  if res ~= nil then 
    return table.unpack(res)
  else res = true end
  return "<suspended>"
end

local function eval(src)
  local res = {pcall(function()
    local ast    = ER.parse(src)
    local tree    = ER.compileAST(ast)
    local code   = ER.csp.compile(tree)
    ER._ruleSrc = src
    ER._ruleCmp = tree
    return ruleRunner(code)
  end)}
  if not res[1] then error("eval error: " .. tostring(res[2])) end
  return table.unpack(res, 2, res.n)
end

function fibaro.EventRunner(cb)
  local er = {eval = eval}
  vm.defGlobal('print',    print)
  vm.defGlobal('tostring', tostring)
  vm.defGlobal('tonumber', tonumber)
  vm.defGlobal('math',     math)
  ER.csp.defGlobal("compRule", compRule) 

  ER.setupProps()
  
  sourceTrigger = SourceTrigger()
  sourceTrigger:run()
  ER.sourceTrigger = sourceTrigger

  cb(er)
end