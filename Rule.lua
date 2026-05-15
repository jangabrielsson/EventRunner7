fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
local vm = ER.csp

local _VERSION = "0.1.0"
fibaro.EventRunnerVersion = _VERSION

local fmt = string.format
local catchValue = math.huge

ER.ruleFail = 'fibaro.ER.conditionFail' -- special value returned by rules when condition is not met; not an error
local ruleRunner, resumeRunner, sourceTrigger
local RULEIDX = 0
local DAILYID = 1
local rules = {}
ER._triggerVars = {}

local function isRule(obj) return type(obj) == 'table' and obj.type == 'RULE' end
local function getRule(rule) 
  return isRule(rule) and rule or rules[tonumber(rule) or 0]
end

local dfltPrefix = { -- This is the defaults opts table. A mix of flags and log prefixes that the user can customize.
  started = false,  -- true => system start log, alt. user function(rule,env,trigger)
  check = true,    -- true => system check log, alt. user function(rule,env,cond result)
  result = false,  -- true => system result log, alt. user function(rule,result)
  triggers = true, -- true => list triggers when rule defined, alt. user function(rule)
  waiting = false, -- true => system waiting log, alt. user function(rule,env,time)
  waited = false,  -- true => system waited log, alt. user function(rule,env,time)
  defined = true, -- true => log rule defined, alt. user function(rule)
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
-- Every execution context (rule or expression) exposes ctx:log(level, prefix, ...)
-- so callers never need to branch on "is this a rule or an expression?".
local VERBOSITY = { silent = 0, normal = 1, verbose = 2 }

-- makeExprCtx: wraps a plain opts table as a context for bare expression eval.
-- Expressions are always fully logged (no verbosity gate) and have no rule prefix.
local function makeExprCtx(opts)
  local ctx = { isRule = false, opts = opts, onDone = opts.onDone }
  function ctx:log(_level, prefix, ...) print(prefix, ...) end
  return ctx
end

local function trimErr(str)
  return str:match("^#(.+)") or str:match("%d+: #(.*)$") or str
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
local function compRule(r, opts, src)
  local head = r[2]               -- the condition part (scan for triggers)
  opts = opts or {}

  RULEIDX = RULEIDX + 1
  local rule = { type='RULE', isRule = true, id = RULEIDX, verbosity = opts.verbosity or "normal", src = src, opts = opts }
  rules[RULEIDX] = rule
  setmetatable(rule, {
    __tostring = function(self) return "RULE" .. tostring(self.id) end
  })
  function rule:log(minLevel, prefix, a1,...)
    local level = VERBOSITY[self.verbosity or "normal"] or 1
    local min   = VERBOSITY[minLevel] or 1
    if level < min then return end
    if prefix == self.opts.errorPrefix and self.src then
      a1 = trimErr(a1 or "")
      print(prefix, tostring(self)..":", a1,..., "\n  src: "..self.src)
    else
      print(prefix, tostring(self)..":", a1,...)
    end
  end
  
  local trs = { triggers = {}, dailys = {}, between = {}, interval = nil }
  scanHead(head, trs)             -- scanHead may modify ast...
  local fun  = ER.csp.compile(r, r._srcmap)  -- compile rule action into CSP (with srcmap if available)
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
      event = {ev.event and setmetatable(ev.event, ER.EventMT) or nil}, 
      _evKey = {key}, 
      post = {postR}, 
      cancel = {cancelR},
      setTimeout = {setTimeoutR},
      enable = {function(id) rule.enable(id) end},
      disable = {function(id) rule.disable(id) end},
    }
    for k,v in pairs(ev.p or {}) do vars[k] = {v} end
    return vars
  end
  
  -- All triggers are subscribed to
  for key, event in pairs(trs.triggers) do
    setmetatable(event, ER.EventMT)
    local recalcDaily = event._recalc
    event._recalc = nil
    sourceTrigger:subscribe(event, function(ev)
      if rule._disabled then return end
      if recalcDaily then 
        rule:log("silent", opts.dailyListPrefix, "Recalculating Daily timers")
        for _,r in pairs(rules) do r:setupDaily() end
        return
      end
      if opts.started then rule:log("normal", opts.startPrefix, ev.event) end
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
      rule:log("verbose", opts.startPrefix, "(interval)")
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
        if not rule._disabled then postR(intervalEvent) end
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
        if rule._disabled then return end
        rule:log("verbose", opts.startPrefix,tostring(subev))
        ruleRunner(rule.fun, rule, {
          vars = mkEvVars('DAILY',ev)})
        end
      )
      rule.dailys[t] = subev
    end
  end
  
  local dtimers = {}
  function rule:setupDaily(catch)
    if next(rule.dailys) == nil then return end
    for _, t in pairs(dtimers) do cancelR(t) end
    dtimers = {}
    local now,midnight= os.time(), ER.midnight()
    local ts = {}
    for tr,subev in pairs(rule.dailys) do ts[tr()] = subev end
    for t,subev in pairs(ts) do
      if t < ER.D2024 then t = t + midnight end
      -- if time has already passed for today, skip
      if t >= now then
        rule:log("verbose", opts.dailyListPrefix,"Daily trigger scheduled fo".."r "..ER.timeStr(t))
        dtimers[#dtimers+1] = postR(subev,t-now)
      elseif catch then -- unless we are in catch mode..
        rule:log("verbose", opts.dailyListPrefix,"Daily trigger "..ER.timeStr(t).." missed, catching now")
        postR(subev,0)
      end
    end
  end
  
  rule:setupDaily(trs.hasCatch and true)
  
  -- rule:run() lets the user fire the rule manually from code.
  function rule:run(event)
    self:log("verbose", self.opts.startPrefix, "(manual)")
    ruleRunner(self.fun, self, {vars=mkEvVars("MANUAL",{event=event})})
  end

  function rule:dumpTriggers(pref)
    for _, tr in pairs(trs.triggers) do
      local a = getmetatable(tr)
      print(pref or "  ", self.opts.triggerListPrefix, tr)
    end
    for t,_ in pairs(rule.dailys) do
      print(pref or "  ", self.opts.dailyListPrefix, ER.timeStr(t()))
    end
  end

  function rule.start(event) rule:run(event) return rule end
  function rule.disable(id) 
    if id == nil then rule._disabled = true 
    else 
      local r = getRule(id)
      if r then r.disable() end
    end
    return rule
  end
  function rule.enable(id) 
    if id == nil then rule._disabled = nil 
    else 
      local r = getRule(id)
      if r then r.enable() end
    end
    return rule
  end
  function rule.info() 
    print(tostring(rule)..":", rule.src)
    rule:dumpTriggers("  ")
    return rule
  end

  if opts.defined then
    rule:log("normal", rule.opts.ruleDefPrefix, "registered:")
    if opts.triggers and (VERBOSITY[rule.verbosity or "normal"] or 1) >= 1 then
      rule:dumpTriggers("- ")
    end
  end
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
local stdHOPS = {
  "RETURN", "NOT", "AND", "OR", "CALL","ADD", 
  "SUB", "MUL", "DIV", "MOD", "POW", "EQ", "LT", "LTE", "GT", "GTE","NOW"
}
local HOPS = {}
for _,op in ipairs(stdHOPS) do HOPS[op] = stdScan end

function HOPS.GETPROP(ast,trs)
  local obj = exprFun(ast[2])()
  local key = ast[3]
  if type(obj) ~= 'table' then obj = {obj} end
  for _,o in pairs(obj) do
    local gp = ER.resolvePropObject(o)
    if not gp:hasGetProp(key) then
      error("GETPROP: no such property "..tostring(key).."' for object "..tostring(gp))
    end
    local trigger = gp:getTrigger(o,key)
    local id = trigger.property or trigger.name or trigger.type
    trs.triggers[id..tostring(gp)] = trigger
  end
end

function HOPS.BETW(ast,trs)
  local a,afun = exprFun(ast[2])()
  local b,bfun = exprFun({"ADD",ast[3],1})()
  assert(type(a) == "number" and type(b) == "number", "BETW operands must be numbers")
  table.insert(trs.between, afun)
  table.insert(trs.between, bfun)
  trs._recalc = true
  scanHead(ast[2], trs)
  scanHead(ast[3], trs)
  trs._recalc = nil
end

function HOPS.DAILY(ast,trs)
  local times = ast[2]
  trs._recalc = true
  if type(times) == 'table' and times[1] == 'MAKETABLE' then 
    times = {}
    for i=3,#ast[2],2 do times[#times+1] = ast[2][i] scanHead(ast[2][i], trs) end
  else scanHead(times, trs) times = {times} end
  trs._recalc = nil
  for i,e in ipairs(times) do
    local v,afun = exprFun(e)()
    if v == catchValue then trs.hasCatch = true
    else
      assert(type(v) == "number", "DAILY operand must be a number")
      table.insert(trs.dailys, afun)
    end
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
    trs.triggers["GLOB:"..name] = {
      type='global-variable', name = name, _recalc = trs._recalc
    }
  elseif ast[2] == "QV" then
    trs.triggers["QUICK:"..name] = {
      type='quickvar', name = name, _recalc = trs._recalc
    }
  end
end

function HOPS.INDEX(ast,trs)
  scanHead(ast[2],trs) -- scan index operands for triggers (e.g. $G_foo[1])
  scanHead(ast[3],trs) -- scan index operands for triggers (e.g. $G_foo['bar'])
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
-- Every execution context (rule or exprCtx) exposes:
--   ctx.isRule       -- true for rules, false for expressions
--   ctx.opts         -- merged options table
--   ctx.onDone       -- optional completion callback
--   ctx:log(level, prefix, ...)  -- verbosity-gated print
--
-- yield handlers receive (continuationFn, ctx, cb, ...yieldArgs)
local yieldHandlers = {
  sleep = function(cf, ctx, cb, ms)
    local o = ctx.opts
    ms = math.floor(ms*1000+0.5)
    if o.waiting then
      ctx:log("normal", o.waitPrefix, fmt("sleeping %dms", ms))
    end
    setTimeout(function()
      if o.waited then
        ctx:log("normal", o.waitedPrefix, fmt("woke after %dms", ms))
      end
      local ok, err = pcall(function()
        resumeRunner(table.pack(ER.csp.resume(cf, ms)), ctx, cb)
      end)
      if not ok then
        ctx:log("normal", o.errorPrefix, err)
      end
    end, ms)
  end,
  asyncFun = function(cf, ctx, cb, fun, ...)
    local timedOut,timeref = false,nil
    local o = ctx.opts
    if o.waiting then
      ctx:log("normal", o.waitPrefix, fmt("calling async func".."tion %s", tostring(fun)))
    end
    local fcb = setmetatable({cf=cf, ctx=ctx}, {
      __call = function(self,...)
        if timeref then timeref = clearTimeout(timeref) end
        if timedOut then return end
        if o.waited then
          ctx:log("normal", o.waitedPrefix, fmt("back from async func %s", tostring(fun)))
        end
        local args = table.pack(...)
        local ok, err = pcall(function()
          resumeRunner(table.pack(ER.csp.resume(cf, table.unpack(args, 1, args.n))), ctx, cb)
        end)
        if not ok then
          ctx:log("normal", o.errorPrefix, err)
        end
      end
    })
    local res = {pcall(fun, fcb, ...)}
    local timeout = tonumber(res[2]) or 3000
    if res[1] then
      -- Async, wait for callback or timeout
      if timeout >= 0 then
        timeref = setTimeout(function()
          timeref = nil
          timedOut = true
          ctx:log("verbose", o.errorPrefix, fmt("Async func".."tion %s timed out after %dms", tostring(fun), timeout))
          local ok, err = pcall(function()
            resumeRunner(table.pack(ER.csp.resume(cf, false)), ctx, cb)
          end)
          if not ok then
            ctx:log("normal", o.errorPrefix, err)
          end
        end, timeout)
      end -- -1 means sync, func called cb directly so no timeout needed
    else
      ctx:log("normal", o.errorPrefix, fmt("Async func".."tion error: %s", tostring(res[2])))
      timedOut = true
      return cb() -- resume with no result on error
    end
  end,
}

function resumeRunner(res, ctx, cb)
  if res[1] == 'suspended' then
    local cf, tag = res[2], res[3]
    local h = yieldHandlers[tag]
    if h then
      return h(cf, ctx, cb, table.unpack(res, 4))
    else
      error("no yield handler for tag: " .. tostring(tag))
    end
  end
  cb(table.unpack(res, 2))
end

local function beautifyArgs(args, res) -- recursively convert args to more readable forms for logging
  res = res or {}
  for i=1,args.n or #args do 
    local obj = args[i]
    local tstr = (getmetatable(obj) or {}).__tostring
    if tstr then res[i] = (type(tstr) == 'function') and tstr(obj) or tstr -- honor __tostring if it exists
    elseif type(obj) == 'table' then -- json enoce tables
      res[i] = json.encode(beautifyArgs(table.pack(table.unpack(obj)), {}))
    else res[i] = tostring(obj) end
  end
  return res
end

-- ruleRunner(f, ctx, perInvokeOpts)
--   ctx            = rule object (ctx.isRule=true) or makeExprCtx() result
--   perInvokeOpts  = {vars=mkEvVars(...)} for trigger callbacks; nil for expressions
function ruleRunner(f, ctx, perInvokeOpts)
  local synced   = false
  local syncVals = nil
  -- Build evalOpts: per-invocation overrides inherit from ctx.opts
  local evalOpts = perInvokeOpts or {}
  setmetatable(evalOpts, {__index = ctx.opts})
  evalOpts.rule = ctx   -- CSP / ScriptFuns code that needs opts.rule gets the ctx

  local function onDone(...)
    if ctx.onDone then ctx.onDone(...) end
    if synced then
      -- completed asynchronously after ruleRunner already returned nil
      ctx:log("verbose", evalOpts.successPrefix, ...)
    else
      syncVals = table.pack(...)
    end
  end

  local ok, err = pcall(function()
    evalOpts.vars = evalOpts.vars or {}
    evalOpts.vars._opts = {evalOpts}
    resumeRunner(table.pack(ER.csp.eval(f, evalOpts)), ctx, onDone)
  end)
  synced = true

  if not ok then
    if ctx.isRule then
      ctx:log("silent", evalOpts.errorPrefix, err)
      ctx:log("silent", evalOpts.errorPrefix, "Disabled")
      ctx.disable()
      return nil
    else
      error(err, 2)  -- re-throw: outer eval's pcall catches it
    end
  end

  if syncVals then
    return table.unpack(syncVals, 1, syncVals.n)
  else
    -- expression/rule suspended: nil returned to caller
    ctx:log("verbose", evalOpts.waitPrefix, "<suspended>")
    return nil
  end
end

-- eval(src) compiles and runs EventScript source.
--   Rule form  ("cond => action"): registers the rule, returns the rule object.
--   Sync expr  ("1+2"):            returns the value(s) and logs 📋.
--   Async expr ("wait(n); ..."):   returns nil, logs 💤; logs 📋 when done.
local function eval(src,opts)
  opts = opts or {}
  setmetatable(ER.er.opts, {__index = dfltPrefix}) -- override default options with provided ones, need to do it here as user may have reassigned ER.er.opts
  setmetatable(opts, {__index = ER.er.opts})       -- inherit default options
  opts.src = src  -- store source text for runtime error enrichment
  local ast    = ER.parse(src)           -- parse error propagates immediately
  local isRule = (ast[1] == 'RULE')
  local result
  
  local ok, err = pcall(function()
    if isRule then
      local rule_csp = ER.compileRuleBody(ast)
      result = table.pack(compRule(rule_csp, opts, src))
    else
      local tree, srcmap = ER.compileASTWithMap(ast)
      local code = ER.csp.compile(tree, srcmap)
      result = table.pack(ruleRunner(code, makeExprCtx(opts)))
    end
  end)
  
  if not ok then
    print(opts.errorPrefix, trimErr(err))
    --error(err) -- we already printed this... re-throwing would cause double printing if eval is called from another eval's pcall, so just return nil on error.
  end
  
  -- For bare expressions: log the sync result if we got one.
  -- Async (nil return) was already logged 💤 by ruleRunner.
  -- Rule form: compRule already logged ✅ with trigger list.
  if not isRule and result and result[1] ~= nil then
    if not (opts.verbosity == "silent") and opts.result then 
      print(opts.resultPrefix, table.unpack(beautifyArgs(result), 1, result.n))
    end
  end
  
  return result and table.unpack(result, 1, result.n)
end

local function ruleGuard(success)
  local cspCtx = ER._ctx
  local opts = cspCtx:getOpts()
  local _,event = cspCtx:getVar('event')
  event = event and setmetatable(event, ER.EventMT) or ""
  if opts.check then
    local ctx = opts.rule  -- the execution context (rule or exprCtx)
    local prefix = success and opts.successPrefix or opts.failPrefix
    ctx:log("normal", prefix, event)
  end
  return success
end

function fibaro.EventRunner(cb)
  local er = {eval = eval, now = ER.now}

  vm.defGlobal("_ruleCondition", ruleGuard)
  vm.defGlobal('catch', catchValue)
  
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
      assert(type(v) == 'fun'..'ction', "Only func".."tions can be assigned to async")
      ER.ASYNCFUNS[v] = true
      vm.defGlobal(k,v)
    end
  })
  ER.async = er.async
  
  ER.setupFuns()
  setupGlobalVariables()
  
  sourceTrigger = SourceTrigger()
  ER.sourceTrigger = sourceTrigger
  er.sourceTrigger = sourceTrigger  
  er.globals = ER.globals
  er.defglobals = ER.defglobals
  er.variables = er.defglobals -- backward compatibility, will be removed in future
  
  midnightLoop()
  
  er.definePropClass = ER.definePropClass
  er.PropObject = ER.PropObject
  er.addStdProp = ER.addStdProp
  er.propertyFuns = ER.propertyFuns
  er.loadSimDevice = ER.loadSimDevice
  er.createSimGlobal = ER.defineSimGlobalVariable
  er.loadPluaDevice = ER.loadPluaDevice
  ER.isRule = isRule
  ER.getRule = getRule

  er.opts = {} -- default options
  ER.er = er

  for _,hook in ipairs(ER.onInitHooks or {}) do hook(er) end
  
  ER.devices = ER.deviceManager()

  setmetatable(er,{
    __tostring = function() return fmt("EventRunner6 v%s",_VERSION) end,
  })
  setTimeout(function() 
    sourceTrigger:run()
    cb(er) 
  end, 500)
end