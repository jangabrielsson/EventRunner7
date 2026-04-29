fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
local vm = ER.csp
fibaro.EventRunnerVersion = "0.1.0"

local fmt = string.format

ER.ruleFail = 'fibaro.ER.conditionFail' -- special value returned by rules when condition is not met; not an error
local ruleRunner, resumeRunner, sourceTrigger
local RULEIDX = 0
local DAILYID = 1
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

local function shouldLog(rule, minLevel)
  if rule == nil then return true end
  local level = VERBOSITY[rule.verbosity or "normal"] or 1
  local min   = VERBOSITY[minLevel] or 1
  return level >= min
end

local function logRule(rule, minLevel, prefix, ...)
  if rule ~= nil then
    if not shouldLog(rule, minLevel) then return end
    print(prefix, tostring(rule), ...)
  else
    print(prefix, ...)
  end
end


ER.D2024 = os.time({year=2024, month=1, day=1})

local function setupGlobalVariables()
  local var = ER.defglobals
  var.sunrise, var.sunset,var.dawn,var.dusk = ER.sunCalc()
  var.midnight, var.vnum = ER.midnight(), tonumber(os.date("%V"))
end

local function midnightLoop(er)
  local dt = os.date("*t") 
  local midnight = os.time{year=dt.year, month=dt.month, day=dt.day+1, hour=0, min=0, sec=0}
  local function loop()
    setupGlobalVariables()
    for _,r in pairs(rules) do
      r:setupDaily()
      r.once = nil -- clear once flag every midnight
    end
    local dt = os.date("*t")
    midnight = os.time{year=dt.year, month=dt.month, day=dt.day+1, hour=0, min=0, sec=0}
    setTimeout(loop, (midnight-os.time())*1000)
  end
  setTimeout(loop, (midnight-os.time())*1000)
end

---------------------- Create rule ---------------------------------
local function compRule(r)
  local head = r[2]               -- the condition part (scan for triggers)
  local _,opts = ER._ctx:getVar('_opts')
  opts = opts or {}
  
  RULEIDX = RULEIDX + 1
  local rule = { id = RULEIDX, verbosity = opts.verbosity or "normal" }
  rules[RULEIDX] = rule
  
  local trs = { triggers = {}, dailys = {}, between = {}, interval = nil }
  scanHead(head, trs)             -- scanHead may modify ast...
  local fun  = ER.csp.compile(r)  -- compile rule action into CSP
  rule.fun = fun
  rule.timers = {}
  
  function postR(ev,time)
    local ref,t
    ref,t = sourceTrigger:post(ev,time,nil,function(ref)
      rule.timers[ref] = nil
    end)
    if ref then rule.timers[ref] = t end
    return ref
  end
  function setTimeoutR(fun,time)
    local ref
    ref = setTimeout(function() 
      rule.timers[ref] = nil
      fun()
    end, time)
    rule.timers[ref] = time
    return ref
  end
  function cancelR(ref)
    rule.timers[ref]=nil
    return sourceTrigger:cancel(ref)
  end
  
  local function mkEvVars(key,ev)
    local vars = {
      event = ev.event and setmetatable(ev.event, ER.EventMT) or nil, 
      _evKey = key, 
      post = postR, 
      cancel = cancelR,
      setTimeout = setTimeoutR,
    }
    for k,v in pairs(ev.p or {}) do vars[k] = v end
    return vars
  end
  
  -- All triggers are subscribed to
  for key, event in pairs(trs.triggers) do
    setmetatable(event, ER.EventMT)
    sourceTrigger:subscribe(event, function(ev)
      logRule(rule, "verbose", dfltPrefix.startPrefix)
      ruleRunner(rule.fun, rule, {
        vars = mkEvVars(key,ev)})
      end
    )
  end
  
  
  local skipDailys = false
  local intervalTimer
  local intervalEvent = {type='INTERVAL', id=rule.id}
  if trs.interval then
    sourceTrigger:subscribe(intervalEvent, function(ev)
      logRule(rule, "verbose", dfltPrefix.startPrefix, "(interval)")
      ruleRunner(rule.fun, rule, {
        vars = mkEvVars('INTERVAL',{event=intervalEvent})})
      end
    )
    skipDailys = true
  end
  
  function rule:setupInterval()
    if intervalTimer then cancelR(intervalTimer); intervalTimer = nil end
    if trs.interval then
      local value = trs.interval()
      if type(value) ~= 'number' then error("Invalid interval time: "..tostring(value)) end
      local delay = 0
      if value < 0 then value=-value delay = (os.time() // value + 1)*value - os.time() end
      local nextTime = os.time() + delay
      local function loop()
        postR(intervalEvent)
        nextTime = nextTime + value
        intervalTimer = setTimeoutR(loop, (nextTime-os.time())*1000)
      end
      intervalTimer = setTimeoutR(loop, (nextTime-os.time())*1000)
    end
  end
  rule:setupInterval()
  
  rule.dailys = {}
  if not skipDailys then
    local dailys = trs.dailys -- @daily inhibits between
    if next(trs.dailys) == nil then dailys = trs.between end
    
    for _, t in ipairs(dailys) do
      local subev = setmetatable({type='DAILY', id=rule.id, subid=DAILYID}, ER.EventMT)
      DAILYID = DAILYID + 1
      sourceTrigger:subscribe(subev, function(ev)
        logRule(rule, "verbose", dfltPrefix.startPrefix,tostring(ev))
        ruleRunner(rule.fun, rule, {
          vars = mkEvVars('DAILY',ev)})
        end
      )
      rule.dailys[t] = subev
    end
  end
  
  function rule:setupDaily()
    if next(rule.dailys) == nil then return end
    local now,midnight= os.time(), ER.midnight()
    local ts = {}
    for tr,subev in pairs(rule.dailys) do ts[tr()] = subev end
    for t,subev in pairs(ts) do
      if t < ER.D2024 then t = t + midnight end
      logRule(rule, "verbose", dfltPrefix.dailyListPrefix,"Daily trigger scheduled for "..ER.timeStr(t))
      postR(subev,t-now)
    end
  end
  rule:setupDaily()
  
  -- rule:run() lets the user fire the rule manually from code.
  function rule:run(event)
    logRule(self, "verbose", dfltPrefix.startPrefix, "(manual)")
    ruleRunner(self.fun, self, {vars=mkEvVars("MANUAL",{event=event})})
  end
  
  function rule:dumpTriggers(pref)
    for _, tr in pairs(trs.triggers) do
      local a = getmetatable(tr)
      print(pref or "  ", dfltPrefix.triggerListPrefix, tr)
    end
    for t,_ in pairs(rule.dailys) do
      print(pref or "  ", dfltPrefix.dailyListPrefix, ER.timeStr(t()))
    end
  end
  
  setmetatable(rule, {
    __tostring = function(self) return "RULE" .. tostring(self.id) end
  })
  
  logRule(rule,"normal",dfltPrefix.ruleDefPrefix, "registered:")
  if shouldLog(rule, "normal") then rule:dumpTriggers("- ") end
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
  table.insert(trs.between, afun)
  table.insert(trs.between, bfun)
end

function HOPS.DAILY(ast,trs)
  local times = ast[2]
  if type(times) == 'table' and times[1] == 'MAKETABLE' then 
    times = {}
    for i=3,#ast[2],2 do times[#times+1] = ast[2][i] end
  else times = {times} end
  
  for _,e in ipairs(times) do
    local v,afun = exprFun(e)()
    assert(type(v) == "number", "DAILY operand must be a number")
    table.insert(trs.dailys, afun)
  end
end

function HOPS.INTERV(ast,trs)
  local a,afun = exprFun(ast[2])()
  assert(type(a) == "number", "INTERV operands must be number")
  assert(trs.interval == nil, "only one INTERVAL condition allowed per rule")
  trs.interval = afun
end

function HOPS.GETVAR(ast,trs)
  local name = ast[3]
  if ast[2] == "GV" then
    trs.triggers["GLOB:"..name] = {type='global-variable', name = name}
    trs.haveVar = true
  elseif ast[2] == "QV" then
    trs.triggers["QUICK:"..name] = {type='quickvar', name = name}
    trs.haveVar = true
  end
end

function HOPS.GET(ast,trs)
  local name = ast[2]
  if ER._triggerVars[name] then
    trs.triggers["TRIG:"..name] = {type='trigger-variable', name = name}
    trs.haveVar = true
  end
end

local EVID = 1
function HOPS.MAKETABLE(ast,trs)
  local tab = exprFun(ast)()
  if type(tab)=='table' and type(tab.type)=='string' then
    local id = "EV:"..EVID
    EVID = EVID + 1
    local c_ast = {}
    for i,v in ipairs(ast) do c_ast[i] = v; ast[i] = nil end
    ast[1] = "CFUN"
    ast[2] = function(cont,ctx,id,tab)
      local exist,evKey = ctx:getVar('_evKey')
      return cont(exist and evKey == id and tab or false)
    end
    ast[3] = id
    ast[4] = c_ast
    trs.triggers[id] = tab
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
    local opts = cf.ctx.opts or {}
    logRule(rule or opts, "verbose", dfltPrefix.waitPrefix, fmt("sleeping %dms", ms))
    setTimeout(function()
      logRule(rule or opts, "verbose", dfltPrefix.waitedPrefix, fmt("woke after %dms", ms))
      local ok, err = pcall(resumeRunner, table.pack(ER.csp.resume(cf, ms)), rule, cb)
      if not ok then
        logRule(rule or opts, "normal", dfltPrefix.errorPrefix, err)
      end
    end, ms)
  end,
  asyncFun = function(cf, rule, cb, fun, ...)
    local timedOut,timeref = false,nil
    local opts = cf.ctx.opts or {}
    logRule(rule or opts, "verbose", dfltPrefix.waitPrefix, fmt("calling async function %s", tostring(fun)))
    local fcb = setmetatable({cf=cf,rule=rule}, {
      __call = function(self,...) 
        if timeref then timeref = clearTimeout(timeref) end
        if timedOut then return end
        logRule(rule or opts, "verbose", dfltPrefix.waitedPrefix, fmt("back from async func %s", tostring(fun)))
        local ok, err = pcall(resumeRunner, table.pack(ER.csp.resume(cf, ...)), rule, cb)
        if not ok then
          logRule(rule or opts, "normal", dfltPrefix.errorPrefix, err)
        end
      end
    }) 
    local res = {pcall(fun, fcb, ...)}
    local timeout = tonumber(res[2]) or 3000
    if res[1] then
      if timeout >= 0 then -- Async, wait for callback or timeout
        timeref = setTimeout(function() 
          timeref = nil
          timedOut = true
          logRule(rule or opts, "verbose", dfltPrefix.errorPrefix, fmt("Async function %s timed out after %dms", tostring(fun), timeout))
          local ok, err = pcall(resumeRunner, table.pack(ER.csp.resume(cf, false)), rule, cb)
          if not ok then
            logRule(rule or opts, "normal", dfltPrefix.errorPrefix, err)
          end
        end, timeout)
      end -- -1 means sync, func called cb directlyso no timeout needed
    else
      logRule(rule, "normal", dfltPrefix.errorPrefix, fmt("Async function error: %s", tostring(res[2])))
      timedOut = true
      return cb() -- resume with no result on error
    end
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
function ruleRunner(f, rule, opts)
  local synced   = false
  local syncVals = nil
  opts = opts or {}
  opts.rule = rule
  
  local function onDone(...)
    if synced then
      -- completed asynchronously (after caller already returned nil)
      if rule or opts then
        logRule(rule or opts, "verbose", dfltPrefix.successPrefix, ...)
        if (rule or opts) and (rule or opts).onDone then (rule or opts).onDone(...) end
      elseif opts.onDone then
        opts.onDone(...)
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
    opts.vars = opts.vars or {}
    opts.vars._opts = opts
    resumeRunner(table.pack(ER.csp.eval(f,opts)), rule, onDone)
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
    logRule(rule or opts, "verbose", dfltPrefix.waitPrefix, "<suspended>")
    return nil
  end
end

-- eval(src) compiles and runs EventScript source.
--   Rule form  ("cond => action"): registers the rule, returns the rule object.
--   Sync expr  ("1+2"):            returns the value(s) and logs 📋.
--   Async expr ("wait(n); ..."):   returns nil, logs 💤; logs 📋 when done.
local function eval(src,opts)
  opts = opts or {}
  local ast    = ER.parse(src)           -- parse error propagates immediately
  local isRule = (ast[1] == 'RULE')
  local result
  
  local ok, err = pcall(function()
    local tree = ER.compileAST(ast)
    local code = ER.csp.compile(tree)
    ER._ruleSrc = src
    ER._ruleCmp = tree
    result = table.pack(ruleRunner(code,nil,opts))  -- rule=nil → bare eval
  end)
  
  if not ok then
    print(dfltPrefix.errorPrefix, err)
    error(err)
  end
  
  -- For bare expressions: log the sync result if we got one.
  -- Async (nil return) was already logged 💤 by ruleRunner.
  -- Rule form: compRule already logged ✅ with trigger list.
  if not isRule and result and result[1] ~= nil then
    if not (opts.verbosity == "silent") then 
      print(dfltPrefix.resultPrefix, table.unpack(result, 1, result.n))
    end
  end
  
  return result and table.unpack(result, 1, result.n)
end

function fibaro.EventRunner(cb)
  local er = {eval = eval, now = ER.now}
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

  ER.ASYNCFUNS = ER.ASYNCFUNS or {}
  er.async = setmetatable({}, {
    __newindex = function(t, k, v) 
      assert(type(v) == 'function', "Only functions can be assigned to async")
      ER.ASYNCFUNS[v] = true
      vm.defGlobal(k,v)
    end
  })
  ER.async = er.async

  ER.setupProps()
  ER.setupFuns()
  setupGlobalVariables()
  
  sourceTrigger = SourceTrigger()
  ER.sourceTrigger = sourceTrigger
  er.globals = ER.globals
  er.defglobals = ER.defglobals
  
  midnightLoop()
  
  if fibaro.plua then
    er.loadDevice = ER.loadDevice
  end

  for _,hook in ipairs(ER.onInitHooks or {}) do hook(er) end
  
  setTimeout(function() 
    sourceTrigger:run()
    cb(er) 
  end, 500)
end