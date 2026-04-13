fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
local vm = ER.csp

local ruleRunner, resumeRunner, sourceTrigger
local RULEIDX = 0
local rules = {}
ER._triggerVars = {}

local dfltPrefix = {
  warningPrefix = "⚠️",
  ruleDefPrefix = "✅",
  triggerListPrefix = "⚡",
  dailyListPrefix = "🕒",
  startPrefix = "🎬",
  stopPrefix = "🛑",
  successPrefix = "👍",
  failPrefix = "👎",
  resultPrefix = "📋",
  errorPrefix = "❌",
  waitPrefix = "💤",
  waitedPrefix = "⏰",
}

-- ── Logging helpers ───────────────────────────────────────────────────────
-- Verbosity levels: silent (0) < normal (1) < verbose (2).
-- rule = nil  → bare expression context: always logs, no rule prefix.
-- rule = obj  → rule-triggered context: respects rule.verbosity.
local VERBOSITY = { silent = 0, normal = 1, verbose = 2 }

local function logRule(rule, minLevel, prefix, ...)
  if rule ~= nil then
    local level = VERBOSITY[rule.verbosity or "normal"] or 1
    local min   = VERBOSITY[minLevel] or 1
    if level < min then return end
    print(prefix, tostring(rule), ...)
  else
    print(prefix, ...)
  end
end

---------------------- Create rule ---------------------------------
local function compRule(r)
  local fun  = ER.csp.compile(r)  -- compile rule action into CSP
  local head = r[2]               -- the condition part (scan for triggers)

  RULEIDX = RULEIDX + 1
  local rule = { fun = fun, id = RULEIDX, verbosity = "normal" }
  rules[RULEIDX] = rule

  local trs = { triggers = {}, dailys = {}, intervals = nil }
  scanHead(head, trs)
  for _, tr in pairs(trs.triggers) do
    setmetatable(tr, ER.EventMT)
    sourceTrigger:subscribe(tr, function(ev)
      logRule(rule, "verbose", dfltPrefix.startPrefix)
      ruleRunner(rule.fun, rule)
    end)
  end

  -- rule:run() lets the user fire the rule manually from code.
  function rule:run()
    logRule(self, "verbose", dfltPrefix.startPrefix, "(manual)")
    ruleRunner(self.fun, self)
  end

  function rule:dumpTriggers()
    print(dfltPrefix.ruleDefPrefix, tostring(self), "registered:")
    for _, tr in pairs(trs.triggers) do
      print("  ", dfltPrefix.triggerListPrefix, tr)
    end
    for _, t in ipairs(trs.dailys) do
      print("  ", dfltPrefix.dailyListPrefix, ER.timeStr(t()))
    end
  end

  setmetatable(rule, {
    __tostring = function(self) return "RULE" .. tostring(self.id) end
  })

  rule:dumpTriggers()
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
  local gf = ER.getProps[key]
  assert(gf, "GETPROP: no such property '"..tostring(key).."'")
  trs.triggers[key..obj] = {type='device', id = obj, property = gf[3]}
end

function HOPS.BETW(ast,trs)
  local a,afun = exprFun(ast[2])()
  local b,bfun = exprFun({"ADD",ast[3],1})()
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

function HOPS.GETVAR(ast,trs)
  local name = ast[3]
  if ast[2] == "GV" then
    trs.triggers["GLOB:"..name] = {type='global-variable', name = name}
  elseif ast[2] == "QV" then
    trs.triggers["QUICK:"..name] = {type='quickvar', name = name}
  end
end

function HOPS.GET(ast,trs)
  local name = ast[2]
  if ER._triggerVars[name] then
    trs.triggers["TRIG:"..name] = {type='trigger-variable', name = name}
  end
end

function scanHead(ast,trs)
  if type(ast) ~= 'table' then return end
  local op = HOPS[ast[1]]
  assert(op, "scanHead: missing op in AST node: " .. tostring(ast[1]))
  return op(ast,trs)
end

-------------------- Run rule ---------------------------------
-- yield handlers receive (continuationFn, rule, cb, ...yieldArgs)
-- rule = nil for bare expressions, rule object for triggered rules.
local yieldHandlers = {
  sleep = function(cf, rule, cb, ms)
    logRule(rule, "verbose", dfltPrefix.waitPrefix, string.format("sleeping %dms", ms))
    setTimeout(function()
      logRule(rule, "verbose", dfltPrefix.waitedPrefix, string.format("woke after %dms", ms))
      local ok, err = pcall(resumeRunner, table.pack(ER.csp.resume(cf, ms)), rule, cb)
      if not ok then
        if rule then logRule(rule, "normal", dfltPrefix.errorPrefix, err)
        else print(dfltPrefix.errorPrefix, err) end
      end
    end, ms)
  end,
}

function resumeRunner(res, rule, cb)
  if res[1] == 'suspended' then
    local cf, tag = res[2], res[3]
    local h = yieldHandlers[tag]
    if h then
      return h(cf, rule, cb, table.unpack(res, 4))
    else
      error("no yield handler for tag: " .. tostring(tag))
    end
  end
  cb(table.unpack(res, 2))
end

-- ruleRunner(f)       → bare eval: always logs, returns value(s) or nil
-- ruleRunner(f, rule) → triggered action: logs per rule.verbosity
function ruleRunner(f, rule)
  local synced   = false
  local syncVals = nil

  local function onDone(...)
    if synced then
      -- completed asynchronously (after caller already returned nil)
      if rule then
        logRule(rule, "verbose", dfltPrefix.successPrefix, ...)
        if rule.onDone then rule.onDone(...) end
      else
        local n = select('#', ...)
        if n > 0 then print(dfltPrefix.resultPrefix, ...) end
      end
    else
      syncVals = table.pack(...)
      -- sync completion: call hook immediately (before ruleRunner returns)
      if rule and rule.onDone then rule.onDone(...) end
    end
  end

  local ok, err = pcall(function()
    resumeRunner(table.pack(ER.csp.eval(f)), rule, onDone)
  end)
  synced = true

  if not ok then
    if rule then
      logRule(rule, "normal", dfltPrefix.errorPrefix, err)
      return nil
    else
      error(err, 0)  -- re-throw: outer eval's pcall catches it
    end
  end

  if syncVals then
    return table.unpack(syncVals, 1, syncVals.n)
  else
    -- expression suspended: nil is returned to caller
    logRule(rule, "verbose", dfltPrefix.waitPrefix, "<suspended>")
    return nil
  end
end

-- eval(src) compiles and runs EventScript source.
--   Rule form  ("cond => action"): registers the rule, returns the rule object.
--   Sync expr  ("1+2"):            returns the value(s) and logs 📋.
--   Async expr ("wait(n); ..."):   returns nil, logs 💤; logs 📋 when done.
local function eval(src)
  local ast    = ER.parse(src)           -- parse error propagates immediately
  local isRule = (ast[1] == 'RULE')
  local result

  local ok, err = pcall(function()
    local tree = ER.compileAST(ast)
    local code = ER.csp.compile(tree)
    ER._ruleSrc = src
    ER._ruleCmp = tree
    result = table.pack(ruleRunner(code))  -- rule=nil → bare eval
  end)

  if not ok then
    print(dfltPrefix.errorPrefix, err)
    error(err)
  end

  -- For bare expressions: log the sync result if we got one.
  -- Async (nil return) was already logged 💤 by ruleRunner.
  -- Rule form: compRule already logged ✅ with trigger list.
  if not isRule and result and result[1] ~= nil then
    print(dfltPrefix.resultPrefix, table.unpack(result, 1, result.n))
  end

  return result and table.unpack(result, 1, result.n)
end

function fibaro.EventRunner(cb)
  local er = {eval = eval}
  vm.defGlobal('print',    print)
  vm.defGlobal('tostring', tostring)
  vm.defGlobal('tonumber', tonumber)
  vm.defGlobal('math',     math)
  ER.csp.defGlobal("compRule", compRule) 

  er.triggerVars = setmetatable({}, {
    __index = function(t, k) return vm.getGlobal(k) end,
    __newindex = function(t, k, v) 
      ER._triggerVars[k] = true 
      vm.defGlobal(k, v)
    end
  })

  ER.setupProps()

  sourceTrigger = SourceTrigger()
  ER.sourceTrigger = sourceTrigger

  setTimeout(function() 
    sourceTrigger:run()
    cb(er) 
  end, 500)
end