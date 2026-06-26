fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
local vm

local _VERSION = "0.1.46"
fibaro.EventRunnerVersion = _VERSION

local fmt = string.format
local catchValue = math.huge
MODULE = MODULE or {}

ER.ruleFail = 'fibaro.ER.conditionFail' -- special value returned by rules when condition is not met; not an error
local ruleRunner, resumeRunner, sourceTrigger, scanHead
local RULEIDX = 0
local DAILYID = 1
local rules = {}
local groups = {} -- { [groupName] = {rule1, rule2, ...} }
local namedRules = {} -- { [name] = rule } — includes auto-names "RULE<id>"
ER._triggerVars = {}
local generation = 0  -- incremented on each bootEventRunner call; used to invalidate stale startup timers

local function isRule(obj) return type(obj) == 'table' and obj.type == 'RULE' end
local function getRule(rule)
  if isRule(rule) then return rule end
  if type(rule) == 'string' then return namedRules[rule] end
  return rules[tonumber(rule) or 0]
end
local function getRuleGoup(name) return groups[name] end

local dfltPrefix = { -- This is the defaults opts table. A mix of flags and log prefixes that the user can customize.
  started = false,  -- true => system start log, alt. user function(rule,env,trigger)
  check = true,    -- true|"success"|"failure"|{success=_,failure=_}|false => condition log
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

local cfg = { -- internal config, not user customizable
  ruleLen = 50,
}

-- ── Logging helpers ───────────────────────────────────────────────────────
-- Verbosity levels: silent (0) < normal (1) < verbose (2).
-- Every execution context (rule or expression) exposes ctx:log(level, prefix, ...)
-- so callers never need to branch on "is this a rule or an expression?".
local VERBOSITY = { silent = 0, normal = 1, verbose = 2 }
local function printErr(...) fibaro.error(__TAG,...) end
local function printWarn(...) fibaro.warning(__TAG,...) end

local function trimErr(str)
  return str:match("^#(.+)") or str:match("%d+: #(.*)$") or str
end

-- shouldLog(flag [, sub]) normalizes debug-flag values so users can filter by sub-event.
--   true            → log everything           (current boolean behavior)
--   false / nil     → log nothing
--   "success"       → only when sub == "success"
--   "failure"       → only when sub == "failure"
--   {success=true}  → only when sub == "success" (table form, same semantics)
local function shouldLog(flag, sub)
  if flag == true then return true end
  if flag == false or flag == nil then return false end
  if type(flag) == "string" then return flag == sub end
  if type(flag) == "table" then return flag[sub] == true end
  return false
end

-- makeExprCtx: wraps a plain opts table as a context for bare expression eval.
local function makeExprCtx(opts)
  local ctx = { isRule = false, opts = opts, onDone = opts.onDone }
  function ctx:log(minLevel, prefix, a1, ...)
    local level = VERBOSITY[self.opts.verbosity or "normal"] or 1
    local min   = VERBOSITY[minLevel] or 1
    if level < min then return end
    if prefix == self.opts.errorPrefix and self.opts.src then
      a1 = trimErr(a1 or "")
      printErr(prefix, a1, ..., "</br>  src: "..self.opts.src)
    else
      print(prefix, a1, ...)
    end
  end
  return ctx
end

ER.D2024 = os.time({year=2024, month=1, day=1}) -- Date before which all daily times are assumed to be (i.e. their date part is ignored and they are scheduled for the next occurrence of that time)

local function setupGlobalVariables()
  local var = ER.defglobals
  var.sunrise, var.sunset,var.dawn,var.dusk = ER.sunCalc()
  var.midnight, var.wnum = ER.midnight(), tonumber(os.date("%W"))+1
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
  rule.name = opts.name or ("RULE" .. RULEIDX)
  rules[RULEIDX] = rule
  namedRules[rule.name] = rule
  if opts.group then 
    assert(type(opts.group) == "string", "Group name must be a string")
    groups[opts.group] = groups[opts.group] or {} 
    groups[opts.group][#groups[opts.group]+1] = rule 
  end
  setmetatable(rule, {
    __tostring = function(self) return self.name end
  })
  rule.stats = { runs = 0, successes = 0, failures = 0 }
  rule.historyOn = false
  rule.historySize = opts.historySize or 10
  rule.history = {}
  rule.watchOn = false
  rule.modifiers = r._modifiers or {}  -- raw modifier flags (single, debounce, etc.)
  rule._mstate = {}             -- runtime modifier state (once, cool_down, every_other)
  function rule:log(minLevel, prefix, a1,...)
    local level = VERBOSITY[self.verbosity or "normal"] or 1
    local min   = VERBOSITY[minLevel] or 1
    if level < min then return end
    if prefix == self.opts.errorPrefix and self.src then
      a1 = trimErr(a1 or "")
      printErr(prefix, tostring(self)..":", a1,..., "</br>  src: "..self.src)
    else
      print(prefix, tostring(self)..":", a1,...)
    end
  end

  local modifiers = r._modifiers or {}
  local trs = { triggers = {}, dailys = {}, between = {}, interval = nil }
  scanHead(head, trs)             -- scanHead may modify ast...
  -- sanity check that scanHead found something triggerable
  if not(next(trs.triggers) or next(trs.dailys) or next(trs.between) or trs.interval) then
    rules[RULEIDX], namedRules[rule.name] = nil, nil -- remove rule from registry
    error("Rule has no triggers: " .. src)
  end 
  local fun  = ER.csp.compile(r, r._srcmap)  -- compile rule action into CSP (with srcmap if available)
  rule.fun = fun
  rule.timers = {}

  local function postR(ev,time)
    local ref,t
    ref,t = sourceTrigger:post(ev,time,nil,function(ref)
      rule.timers[ref] = nil
    end)
    if ref then rule.timers[ref] = t end
    return ref
  end
  local function setTimeoutR(fun,time)
    local ref
    ref = setTimeout(function()
      rule.timers[ref] = nil
      fun()
    end, time)
    rule.timers[ref] = time
    return ref
  end
  local function cancelR(ref)
    rule.timers[ref]=nil
    return sourceTrigger:cancel(ref)
  end

  local function runRule(...)
    if modifiers.single then
      local old = rule.timers
      rule.timers = {}
      for ref in pairs(old) do
        clearTimeout(ref)          -- cancel raw setTimeout timers (wait/sleep)
        sourceTrigger:cancel(ref)  -- cancel event-queue posts (postR)
      end
    end
    rule.stats.runs = rule.stats.runs + 1
    return ruleRunner(rule.fun, rule, ...)
  end

  local function mkEvVars(key,ev)
    local vars = {
      event = {ev.event and setmetatable(ev.event, ER.EventMT) or nil},
      _evKey = {key},
      post = {postR},
      cancel = {cancelR},
      setTimeout = {setTimeoutR},
      enable = {function(arg) ER.enable(arg or rule,true) end},
      disable = {function(arg) ER.enable(arg or rule,false) end},
    }
    vars.env = { event = vars.event }
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
      return runRule({
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
      runRule({
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
        intervalTimer = setTimeout(loop, (nextTime-os.time())*1000)
      end
      intervalTimer = setTimeout(loop, (nextTime-os.time())*1000)
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
        runRule({
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
    local now = vm.host.ostime()
    local midnight = ER.midnight() -- recomputed below, keep for structure
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
    runRule({vars=mkEvVars("MANUAL",{event=event})})
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
  function rule.disable(id) rule._disabled = true; return rule end
  function rule.enable() rule._disabled = nil; return rule end

  function rule.info()
    print(tostring(rule)..":", rule.src)
    rule:dumpTriggers("  ")
    return rule
  end

  if opts.defined then
    rule:log("normal", rule.opts.ruleDefPrefix, "registered:", rule.src // cfg.ruleLen)
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
  "RETURN", "NOT", "AND", "OR", "CALL","ADD","CFUN","CONST",
  "SUB", "MUL", "DIV", "MOD", "POW", "EQ", "LT", "LTE", "GT", "GTE","NOW","NEG"
}
local HOPS = {}
for _,op in ipairs(stdHOPS) do HOPS[op] = stdScan end

function HOPS.GETPROP(ast,trs)
  local obj = exprFun(ast[2])()
  local key = ast[3]
  if type(obj) ~= 'table' then obj = {obj} end
  for _,o in pairs(obj) do
    local gp = ER.resolvePropObject(o,key)
    assert(gp, "GETPROP: cannot resolve object: "..tostring(o))
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
function HOPS.TRIGGER_EVENT(ast,trs)
  local tab = ast[2]
  local id = ast[3]
  local tab = exprFun(tab)() -- evaluate
  trs.triggers[id] = tab
end

function HOPS.MAKETABLE(ast,trs) end -- table contains no triggers

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
  sleep = function(cf, ctx, cb, sec)
    local o = ctx.opts
    local ms = math.floor(sec*1000+0.5)
    if o.waiting then
      ctx:log("normal", o.waitPrefix, fmt("sleeping %dms", ms))
    end
    local ref
    ref = setTimeout(function()
      if ctx.timers then ctx.timers[ref] = nil end
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
    if ctx.timers then ctx.timers[ref] = ms end  -- track so single can cancel
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

local function beautifyArgs_aux(obj) -- recursively convert args to more readable forms for logging
    local t = type(obj)
    local tstr = (getmetatable(obj) or {}).__tostring
    if tstr then return (type(tstr) == 'function') and tstr(obj) or tstr -- honor __tostring if it exists
    elseif t == 'table' then 
      local res = {}
      for i=1,#obj do
        res[i] = beautifyArgs_aux(obj[i])
      end
      return res
    elseif t == 'number' or t == 'boolean' or t == 'string' then
      return obj
    elseif t == "nil" then
      return "nil"
    else
      return"<" .. tostring(t) .. ">"
    end
  end

local function beautifyArgs(args,res)
  res = res or {}
  for i=1,args.n or #args do
    res[i] = json.encode(beautifyArgs_aux(args[i]))
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
      if ctx.opts.result then
        ctx:log("normal", evalOpts.resultPrefix, ...)
      end
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
  local ast
  do
    local ok, err = pcall(function() ast = ER.parse(src) end)
    if not ok then
      if not opts.throw then
        printErr(opts.errorPrefix, trimErr(err), "</br>  src: "..src)
        return
      end
      error(err, 0)
    end
  end
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
    if not opts.throw then
      printErr(opts.errorPrefix, trimErr(err), "</br>  src: "..src)
    end
    if opts.throw then error(err, 0) end
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

function ER.ruleCondition(cont, ctx, success)
  local opts = ctx:getOpts()
  local _,event = ctx:getVar('event')
  event = event and setmetatable(event, ER.EventMT) or ""
  local sub = success and "success" or "failure"
  if shouldLog(opts.check, sub) then
    local ctx = opts.rule  -- the execution context (rule or exprCtx)
    local prefix = success and opts.successPrefix or opts.failPrefix
    ctx:log("normal", prefix, event)
  end
  local r = opts.rule
  r.stats[success and "successes" or "failures"] = r.stats[success and "successes" or "failures"] + 1
  if r and r.historyOn then
    local entry = { time=os.time(), trigger=tostring(event), result=success }
    table.insert(r.history, entry)
    if #r.history > (r.historySize or 10) then table.remove(r.history, 1) end
  end
  if r and r.watchOn then
    local ts = os.date("%H:%M:%S")
    local res = success and "✅ PASS" or "❌ FAIL"
    print(fmt("👁  [%s] %s  %s  %s", r.name, ts, res, tostring(event)))
  end
  return cont(success)
end

local function clearRules()
  for _, r in pairs(rules) do
    for ref in pairs(r.timers) do sourceTrigger:cancel(ref) end
  end
  rules = {}; groups = {}; namedRules = {}
  RULEIDX = 0; DAILYID = 1
  ER.ASYNCFUNS = {}; ER._triggerVars = {}
  vm.resetGlobals()
end

-- EventScript specific CSP functions
local function addCSPfuns()
  local TR = vm.expr.TR
  local trace, ca = vm.trace, vm.ca
  local ctx = vm.getCTX

  -- GETPROP(obj_expr, key) reads a device property via ER._funs.getProp.
  -- key is a plain string (not an expression).
  local function GETPROP(obj_expr, key)
    return function(cont)
      return obj_expr(TR(function(obj)
        trace("GETPROP", tostring(obj), key)
        return cont(ER.getProp(obj, key, ctx()))
      end))
    end
  end
  
  -- SETPROP(obj_expr, key, val_expr) writes a device property via ER._funs.setProp.
  -- key is a plain string (not an expression).
  local function SETPROP(obj_expr, key, val_expr)
    return function(cont)
      return obj_expr(TR(function(obj)
        return val_expr(TR(function(v)
          trace("SETPROP", tostring(obj), key, "=", tostring(v))
          ER.setProp(obj, key, v, ctx())
          return cont(v)
        end))
      end))
    end
  end
  
  -- GETVAR reads special vars.
  local function GETVAR(typ,name)
    return function(cont)
      return name(TR(function(n)
        local v = ER.getVar(typ,n)  -- errors propagate to eval()'s pcall
        return cont(v)
      end))
    end
  end
  
  -- SETVAR mutates special vars.
  local function SETVAR(typ, name, val_expr)
    return function(cont)
      return name(TR(function(n)
        return val_expr(TR(function(v)
          ER.setVar(typ, n, v)  -- errors propagate to eval()'s pcall
          return cont(v)
        end))
      end))
    end
  end
  
  -- DAILY is true if the rule was invoked by a DAILY event
  local function DAILY(a)
    return function(cont)
      return a(TR(function(v)
        trace("DAILY", v)
        local _,b = ctx():getVar('event')
        return cont((b or {}).type == 'DAILY')
      end))
    end
  end
  
  -- INTERV wraps a time value into an Interval event descriptor {type='Interval', interval=v}.
  local function INTERV(a)
    return function(cont)
      return a(TR(function(v)
        trace("INTERV", v)
        return cont({type='Interval', interval=v})
      end))
    end
  end

  local function TRIGGER_EVENT(tab_expr, id_expr)
    return function(cont)
      return tab_expr(TR(function(tab)
        return id_expr(TR(function(id)
          trace("TRIGGER_EVENT", id, "in", tostring(tab))
          local exist,evKey = ctx():getVar('_evKey')
          return cont(exist and evKey == id and tab or false)
        end))
      end))
    end
  end

  -- BETW checks whether the current time falls within [start, stop].
  -- Delegates to ER.betw which handles both epoch timestamps (arg > T2020)
  -- and seconds-since-midnight values, including midnight wrap-around.
  local function BETW(start_expr, stop_expr)
    return function(cont)
      return start_expr(TR(function(start)
        return stop_expr(TR(function(stop)
          trace("BETW", start, "..", stop)
          return cont(ER.betw(start, stop))
        end))
      end))
    end
  end
  
  vm.registerInstructions({
    GETPROP = {
      impl = GETPROP,
      compile = function(t) return GETPROP(ca(t[2]), t[3]) end
    },
    SETPROP = {
      impl = SETPROP,
      compile = function(t) return SETPROP(ca(t[2]), t[3], ca(t[4])) end
    },
    GETVAR = {
      impl = GETVAR,
      compile = function(t) return GETVAR(t[2], ca(t[3])) end
    },
    SETVAR = {
      impl = SETVAR,
      compile = function(t) return SETVAR(t[2], ca(t[3]), ca(t[4])) end
    },
    DAILY  = { impl = DAILY },   -- generic-arg: no special compiler needed
    INTERV = { impl = INTERV },
    TRIGGER_EVENT = { impl = TRIGGER_EVENT },
    BETW   = { impl = BETW },    -- or could stay core with _host.betw()
  })

  function vm.host.isAsync(f) return ER.ASYNCFUNS and ER.ASYNCFUNS[f] end
  function vm.host.onVarWrite(name, val) 
    if ER._triggerVars and ER._triggerVars[name] then
      ER.sourceTrigger:post({type='trigger-variable', name = name, value = val})
      trace("SET trigger var", name, "=", val)
    end
  end
  function vm.host.formatSource(src, pos, len) return ER.sourceMarker(src, pos, len) end
end

local function bootEventRunner(cb)
  local silent = ER.silent
  generation = generation + 1
  local gen = generation
  local color = ER.color
  local er = {eval = eval, now = ER.now}

  vm.defGlobal('catch', catchValue)

  er.triggerVars = setmetatable({}, {
    __index = function(t, k) return vm.lookupGlobal(k) end,
    __newindex = function(t, k, v)
      ER._triggerVars[k] = true
      vm.defGlobal(k, v)
    end
  })
  er.triggerVariables = er.triggerVars -- backward compatibility, will be removed in future

  ER.ASYNCFUNS = ER.ASYNCFUNS or {}
  function er.createAsyncFun(fun)
    ER.ASYNCFUNS[fun] = true
    return fun
  end

  er.async = setmetatable({}, {
    __index = function(t,k) return vm.lookupGlobal(k) end,
    __newindex = function(t, k, v)
      assert(type(v) == 'fun'..'ction', "Only func".."tions can be assigned to async")
      er.createAsyncFun(v)
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
  er.defglobals.BREAK = sourceTrigger.eventEngine.BREAK

  if not ER._midnightRunning then
    ER._midnightRunning = true
    midnightLoop()
  end

  addCSPfuns()

  er.post = function(...) return sourceTrigger:post(...) end
  er.cancel = function(...) return sourceTrigger:cancel(...) end
  er.definePropClass = ER.definePropClass
  er.PropObject = ER.PropObject
  er.addStdProp = ER.addStdProp
  er.propertyFuns = ER.propertyFuns
  er.loadSimDevice = ER.loadSimDevice
  er.createSimGlobal = ER.defineSimGlobalVariable
  er.loadPluaDevice = ER.loadPluaDevice
  er.base64encode = ER.base64encode
  ER.isRule = isRule
  ER.getRule = getRule
  ER.getGroup = getRuleGoup
  ER.namedRules = namedRules

  er.opts = {} -- default options
  er.reset = function(newMain) clearRules(); bootEventRunner(newMain or function() end) end
  ER.er = er

  for _,hook in ipairs(ER.onInitHooks or {}) do hook(er) end

  ER.devices = ER.deviceManager()

  setmetatable(er,{
    __tostring = function() return fmt("EventRunner7 v%s",_VERSION) end,
  })
  setTimeout(function()
    if gen ~= generation then return end
    sourceTrigger:run()

    local preModules,afterModules = {},{} -- Modules with negative prio are loaded before the main callback, others after. This allows modules to patch ER before rules are loaded.
    for _,m in ipairs(MODULE) do
      local prio = m.prio or 0
      if prio < 0 then table.insert(preModules, m) else table.insert(afterModules, m) end
    end
    table.sort(preModules, function(a,b) return (a.prio or 0) < (b.prio or 0) end)
    table.sort(afterModules, function(a,b) return (a.prio or 0) < (b.prio or 0) end)

    if not silent then print(color('green',"=========== Loading rules ================")) end

    local loadTime = os.clock()
    for i,m in ipairs(preModules) do m.code(er) if m.name==nil or m.name:sub(1,1) ~= "_" then 
      if not silent then print(fmt("Loaded module %s", m.name or i)) end
      end 
    end
    cb(er) -- User's main callback, where they typically define their rules, runs between preModules and afterModules to allow preModules to patch ER before rules are loaded, and afterModules to patch ER after rules are loaded.
    for i,m in ipairs(afterModules) do m.code(er) if m.name==nil or m.name:sub(1,1) ~= "_" then 
      if not silent then print(fmt("Loaded module %s", m.name or i)) end
      end
    end
    loadTime = os.clock() - loadTime

    if not silent then print(color('green', fmt("=========== Load time: %.3fs ============", loadTime))) end

  end, 500)
end

local function loadSysModules(...)
  local mods,names,ms = {...}, {}, {}
  for _,m in ipairs(MODULE) do if m.sys then names[m.name]=m.code else ms[#ms+1]=m end end
  MODULE = ms
  for _,name in ipairs(mods) do 
    --print("Loading sys module", name)
    names[name](ER)
  end
end

function fibaro.EventRunner(cb)
  loadSysModules("Utils","CSP","Tokenizer","Parser","Compiler","ScriptFuns","Props")
  vm = ER.csp
  if type(cb)=='function' then bootEventRunner(cb) -- new style
  else
    return setmetatable({start = function() bootEventRunner(function(er) cb:main(er) end) end}, { -- Backward comp. with ER6
      __tostring = function() return fmt("EventRunner7 v%s",_VERSION) end,
    })
  end
end