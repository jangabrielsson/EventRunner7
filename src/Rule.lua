fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
local vm

local _VERSION = "0.2.0"
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

-- hintErr(err): friendly-message translation for common runtime errors.
-- Maps raw Lua/CSP jargon to guidance that saves a support round-trip.
-- Only the message part is rewritten; any source annotation stays.
local function hintErr(err)
  local name = err:match("^#?Undefined variable: '([^']+)'")
  if name then
    return err:gsub("^#?Undefined variable: '[^']+'",
      fmt("Variable '%s' is not defined — misspelled, or forgot to define it? (er.triggerVars.%s, er.defglobals.%s, or a rule assignment)", name, name, name))
  end
  local hints = {
    {"attempt to index a nil value", "a value is nil where a table/device was expected — check the variable or device ID here"},
    {"attempt to call a nil value", "a function is nil where a call was made — is it defined? (er.defglobals, er.async)"},
    {"attempt to perform arithmetic on a nil value", "a value in the arithmetic is nil — check the variable or device property here"},
    {"attempt to concatenate a table value", "tried to concatenate a table as a string — pick the right field, or use tostring()"},
    {"attempt to compare a nil value", "a value in the comparison is nil — check the variable or device property here"},
  }
  for _, h in ipairs(hints) do
    if err:find(h[1], 1, true) then
      return err .. " — " .. h[2]
    end
  end
  return err
end

-- fmtErr(err, src): normalize an error for logging. CSP-enriched runtime
-- errors already carry a source annotation ("</br>" + line/col/caret); plain
-- messages (registration, internal) get the source appended.
local function fmtErr(err, src)
  err = trimErr(err or "")
  if src and not err:find("</br>") then
    err = err .. "</br>  src: " .. src
  end
  return err
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

-- makeLogger(obj, nameFn) installs obj:log(minLevel, prefix, ...) with
-- verbosity gating (rule.verbosity field, falling back to opts.verbosity)
-- and error-log enrichment (trimErr + src annotation) when prefix is the
-- error prefix. nameFn, when given, returns the name to prefix the output
-- with (rule name); expression contexts log without a name. Non-error args
-- are passed through as-is (they may be tables — events, etc.).
local function makeLogger(obj, nameFn)
  function obj:log(minLevel, prefix, a1, ...)
    local level = VERBOSITY[self.verbosity or self.opts.verbosity or "normal"] or 1
    local min   = VERBOSITY[minLevel] or 1
    if level < min then return end
    local name = nameFn and nameFn(self)
    if prefix == self.opts.errorPrefix and self.opts.src then
      a1 = fmtErr(a1, self.opts.src)   -- normalized; annotation added when missing
      if name then printErr(prefix, name..": "..a1, ...)
      else printErr(prefix, a1, ...) end
    else
      if name then print(prefix, name..":", a1, ...) else print(prefix, a1, ...) end
    end
  end
  return obj
end

-- makeExprCtx: wraps a plain opts table as a context for bare expression eval.
local function makeExprCtx(opts)
  local ctx = { isRule = false, opts = opts, onDone = opts.onDone }
  return makeLogger(ctx, nil)
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
  -- Under flua, mark the loop timer as housekeeping so it does not count
  -- as pending work: a test QA is considered idle once real rules/timers
  -- drain, so --run-for's exit-when-idle terminates instead of spinning to
  -- the wall cap. Inert on the HC3 (_FLUA is nil) and on older flua.
  local loopFn
  local function loop()
    setupGlobalVariables()
    for _,r in pairs(rules) do
      r:setupDaily()
      r.once = nil -- clear once flag every midnight
    end
    local dt = os.date("*t")
    midnight = os.time{year=dt.year, month=dt.month, day=dt.day+1, hour=0, min=0, sec=0}
    setTimeout(loopFn, (midnight-os.time())*1000)
  end
  -- Under flua, mark the loop as housekeeping so it does not count as
  -- pending work: a test QA is considered idle once real rules/timers
  -- drain, so --run-for's exit-when-idle terminates instead of spinning to
  -- the wall cap. Inert on the HC3 and on flua without the API.
  loopFn = (_FLUA and _FLUA.background and _FLUA.background(loop)) or loop
  setTimeout(loopFn, (midnight-os.time())*1000)
end

---------------------- Create rule ---------------------------------
-- ── Rule lifecycle, split out of the former compRule god-function ──
-- newRule: create the rule object and register it (registry, name, group).
local function newRule(opts, src)
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
  rule._mstate = {}             -- runtime modifier state (once, cool_down, every_other)
  rule.gen = 0                  -- run generation: bumped by killTimers so superseded
                                -- async continuations can be discarded on resume
  rule.failCount = 0            -- consecutive errored runs (disableOnError policy)
  rule.active = 0               -- runs currently suspended (in-flight)
  rule.subs = {}                -- trigger subscriptions (for recompile)
  rule.dailys = {}              -- daily subevents (filled by setupDailys;
                                -- interval-only rules keep it empty)
  makeLogger(rule, tostring)    -- rule name prefixes log output
  return rule
end

-- attachRun: timer registry, cancellation, and the run entry point.
local function attachRun(rule)
  rule.timers = {}

  function rule.postR(ev,time)
    local ref,t
    ref,t = sourceTrigger:post(ev,time,nil,function(ref)
      rule.timers[ref] = nil
    end)
    if ref then rule.timers[ref] = t end
    return ref
  end
  function rule.setTimeoutR(fun,time)
    local ref
    ref = setTimeout(function()
      rule.timers[ref] = nil
      fun()
    end, time)
    rule.timers[ref] = time
    return ref
  end
  function rule.cancelR(ref)
    rule.timers[ref]=nil
    return sourceTrigger:cancel(ref)
  end

  function rule.killTimers()
    local old = rule.timers
    rule.timers = {}
    -- Pending since-timer state is cancelled with its timer: the next
    -- condition evaluation starts a fresh window instead of seeing a
    -- stale trueFor.ref and wedging (single + since bug).
    rule.trueFor = nil
    -- Bump the run generation: callbacks from the superseded run's
    -- in-flight async functions are discarded when they arrive.
    rule.gen = rule.gen + 1
    rule.active = 0    -- all suspended runs are dead once their timers are
                       -- cancelled (single: the new run re-counts itself)
    for ref in pairs(old) do
      clearTimeout(ref)          -- cancel raw setTimeout timers (wait/sleep/async watchdogs)
      sourceTrigger:cancel(ref)  -- cancel event-queue posts (postR)
    end
  end

  -- subscribe: keep the subscription object so recompile can unsubscribe.
  function rule.subscribe(event, handler)
    local sub = sourceTrigger:subscribe(event, handler)
    rule.subs[#rule.subs + 1] = sub
    return sub
  end

  function rule.runRule(...)
    if rule.modifiers.single then rule.killTimers() end
    rule.stats.runs = rule.stats.runs + 1
    rule.active = rule.active + 1
    return ruleRunner(rule.fun, rule, ...)
  end
end

-- mkEvVars: the per-invocation variable environment exposed to the CSP VM.
local function mkEvVars(rule, key, ev)
  local vars = {
    event = {ev.event and setmetatable(ev.event, ER.EventMT) or nil},
    _evKey = {key},
    post = {rule.postR},
    cancel = {rule.cancelR},
    setTimeout = {rule.setTimeoutR},
    enable = {function(arg) ER.enable(arg or rule,true) end},
    disable = {function(arg) ER.enable(arg or rule,false) end},
  }
  vars.env = { event = vars.event }
  for k,v in pairs(ev.p or {}) do vars[k] = {v} end
  return vars
end

-- setupTriggers: subscribe the scanned device/variable/custom triggers.
local function setupTriggers(rule, trs, opts)
  for key, event in pairs(trs.triggers) do
    setmetatable(event, ER.EventMT)
    local recalcDaily = event._recalc
    event._recalc = nil
    rule.subscribe(event, function(ev)
      if rule._disabled then return end
      if recalcDaily then
        rule:log("silent", opts.dailyListPrefix, "Recalculating Daily timers")
        for _,r in pairs(rules) do
          if r.setupDaily then r:setupDaily() end  -- interval-only rules have none
        end
        return
      end
      if opts.started then rule:log("normal", opts.startPrefix, ev.event) end
      return rule.runRule({ vars = mkEvVars(rule, key, ev) })
    end)
  end
end

-- setupInterval: interval triggers; returns true if the rule has one
-- (an interval suppresses daily scheduling).
local function setupInterval(rule, trs, opts)
  if not trs.interval then return false end
  local intervalEvent = {type='INTERVAL', id=rule.id}
  rule.subscribe(intervalEvent, function(ev)
    rule:log("verbose", opts.startPrefix, "(interval)")
    rule.runRule({ vars = mkEvVars(rule, 'INTERVAL', {event=intervalEvent}) })
  end)

  function rule:setupInterval()
    if rule._intervalTimer then rule.cancelR(rule._intervalTimer); rule._intervalTimer = nil end
    if trs.interval then
      local value = trs.interval()
      if type(value) ~= 'number' then error("Invalid interval time: "..tostring(value)) end
      local delay = 0
      if value < 0 then value=-value delay = (os.time() // value + 1)*value - os.time() end
      local nextTime = os.time() + delay
      local function loop()
        if not rule._disabled then rule.postR(intervalEvent) end
        nextTime = nextTime + value
        -- Untracked: the scheduler timer is not a run timer — single's
        -- killTimers must not cancel it. disable()/terminate()/recompile()
        -- cancel it explicitly via rule._intervalTimer.
        rule._intervalTimer = setTimeout(loop, (nextTime-os.time())*1000)
      end
      rule._intervalTimer = setTimeout(loop, (nextTime-os.time())*1000)
    end
  end
  if not rule._disabled then rule:setupInterval() end
  return true
end

-- setupDailys: daily/between time triggers + rule:setupDaily scheduling.
local function setupDailys(rule, trs, opts)
  local dailys = trs.dailys -- @daily inhibits between
  if next(trs.dailys) == nil then dailys = trs.between end

  for _, t in ipairs(dailys) do
    local subev = setmetatable({type='DAILY', id=rule.id, subid=DAILYID}, ER.EventMT)
    DAILYID = DAILYID + 1
    rule.subscribe(subev, function(ev)
      if rule._disabled then return end
      rule:log("verbose", opts.startPrefix, tostring(subev))
      rule.runRule({ vars = mkEvVars(rule, 'DAILY', ev) })
    end)    rule.dailys[t] = subev
  end

  local dtimers = {}
  function rule:setupDaily(catch)
    if next(rule.dailys) == nil then return end
    for _, t in pairs(dtimers) do rule.cancelR(t) end
    dtimers = {}
    local now = vm.host.ostime()
    local midnight = ER.midnight()
    local ts = {}
    for tr,subev in pairs(rule.dailys) do ts[tr()] = subev end
    for t0,subev in pairs(ts) do
      local t = t0
      if t < ER.D2024 then t = t + midnight end
      -- if time has already passed for today, skip
      if t >= now then
        rule:log("verbose", opts.dailyListPrefix,"Daily trigger scheduled for "..ER.timeStr(t))
        dtimers[#dtimers+1] = rule.postR(subev,t-now)
      elseif catch then -- unless we are in catch mode..
        rule:log("verbose", opts.dailyListPrefix,"Daily trigger "..ER.timeStr(t).." missed, catching now")
        rule.postR(subev,0)
      end
    end
  end

  rule:setupDaily(trs.hasCatch and true)
end

-- defineRuleAPI: the public rule object surface.
local function defineRuleAPI(rule, trs, opts)
  -- rule:run() lets the user fire the rule manually from code.
  function rule:run(event)
    self:log("verbose", self.opts.startPrefix, "(manual)")
    rule.runRule({vars=mkEvVars(rule, "MANUAL", {event=event})})
  end

  function rule:dumpTriggers(pref)
    for _, tr in pairs(trs.triggers) do
      print(pref or "  ", self.opts.triggerListPrefix, tr)
    end
    for t,_ in pairs(rule.dailys) do
      print(pref or "  ", self.opts.dailyListPrefix, ER.timeStr(t()))
    end
  end

  -- Lifecycle: 'enabled' ↔ 'disabled' (terminate cancels pending activity,
  -- see killTimers; in-flight runs are counted in rule.active).
  function rule:state()
    if self._disabled then return 'disabled' end
    return 'enabled'
  end
  function rule.start(event) rule:run(event) return rule end
  function rule.disable(id)
    rule._disabled = true
    -- Stop the interval scheduler: a disabled rule should not consume
    -- timers. Alignment is recomputed on enable.
    if rule._intervalTimer then rule.cancelR(rule._intervalTimer); rule._intervalTimer = nil end
    return rule
  end
  function rule.enable()
    rule._disabled = nil
    rule.failCount = 0
    -- Restart the interval scheduler: clock-aligned intervals resume at
    -- the next boundary; relative intervals restart from enable time.
    if rule.setupInterval then rule:setupInterval() end
    return rule
  end
  function rule.terminate()
    rule.killTimers()
    -- the interval scheduler timer is untracked; cancel it explicitly
    if rule._intervalTimer then rule.cancelR(rule._intervalTimer); rule._intervalTimer = nil end
    return rule
  end

  -- recompile: rebind the rule in place from its source. Names/IDs in the
  -- condition are resolved at compile time, so changing a global (e.g. dID)
  -- does not affect a registered rule until it is recompiled — or the QA
  -- restarts / er.reset() re-registers everything.
  function rule:recompile()
    -- Rebuild everything from the stored source BEFORE touching the live
    -- rule, so a broken source leaves the old binding running.
    local ast = ER.parse(self.src)
    if ast[1] ~= 'RULE' then
      error("recompile: source is not a rule: " .. self.src, 0)
    end
    local csp = ER.compileRuleBody(ast)
    local trs = { triggers = {}, dailys = {}, between = {}, interval = nil }
    scanHead(csp[2], trs)
    if not(next(trs.triggers) or next(trs.dailys) or next(trs.between) or trs.interval) then
      error("Rule has no triggers: " .. self.src, 0)
    end
    local fun = ER.csp.compile(csp, csp._srcmap)

    -- Teardown: cancel all timers (the interval timer is tracked now, so
    -- this stops it too), drop subscriptions, reset modifier state and
    -- stats. The rule object keeps its identity — id, name, and references
    -- stay valid.
    self.killTimers()
    if self._intervalTimer then self.cancelR(self._intervalTimer); self._intervalTimer = nil end
    for _, sub in ipairs(self.subs) do sourceTrigger:unsubscribe(sub) end
    self.subs = {}
    self._mstate = {}
    self.trueFor = nil
    self.failCount = 0
    self.stats = { runs = 0, successes = 0, failures = 0 }

    -- Commit the new binding
    self.fun = fun
    self.modifiers = csp._modifiers or {}
    setupTriggers(self, trs, self.opts)
    if not setupInterval(self, trs, self.opts) then
      setupDailys(self, trs, self.opts)
    end
    self:log("verbose", self.opts.ruleDefPrefix, "recompiled:", self.src // cfg.ruleLen)
    return self
  end

  function rule.info()
    print(tostring(rule)..":", rule.src)
    rule:dumpTriggers("  ")
    return rule
  end
end

local function compRule(r, opts, src)
  local head = r[2]               -- the condition part (scan for triggers)
  opts = opts or {}
  local rule = newRule(opts, src)
  rule.modifiers = r._modifiers or {}  -- raw modifier flags (single, debounce, etc.)
  attachRun(rule)

  local trs = { triggers = {}, dailys = {}, between = {}, interval = nil }
  trs.src = src
  trs.srcmap = r._srcmap  -- positions for scanHead error annotations
  scanHead(head, trs)
  -- sanity check that scanHead found something triggerable
  if not(next(trs.triggers) or next(trs.dailys) or next(trs.between) or trs.interval) then
    rules[rule.id], namedRules[rule.name] = nil, nil -- remove rule from registry
    error("Rule has no triggers: " .. src)
  end 
  rule.fun = ER.csp.compile(r, r._srcmap)  -- compile rule into CSP (with srcmap if available)

  setupTriggers(rule, trs, opts)
  if not setupInterval(rule, trs, opts) then
    setupDailys(rule, trs, opts)
  end
  defineRuleAPI(rule, trs, opts)

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
  "RETURN", "NOT", "AND", "OR","ADD","CFUN","CONST",
  "SUB", "MUL", "DIV", "MOD", "POW", "EQ", "LT", "LTE", "GT", "GTE","NOW","NEG"
}
local HOPS = {}
for _,op in ipairs(stdHOPS) do HOPS[op] = stdScan end

-- ── Typo suggestions ──────────────────────────────────────────────────────
local function levenshtein(a, b)
  local dp = {}
  for i = 0, #a do dp[i] = {[0] = i} end
  for j = 0, #b do dp[0][j] = j end
  for i = 1, #a do
    for j = 1, #b do
      local cost = a:sub(i,i) == b:sub(j,j) and 0 or 1
      dp[i][j] = math.min(dp[i-1][j]+1, dp[i][j-1]+1, dp[i-1][j-1]+cost)
    end
  end
  return dp[#a][#b]
end

-- suggest(name, candidates): closest candidate within distance 2, else nil.
local function suggest(name, candidates)
  local best, bestD = nil, 3
  for _, c in ipairs(candidates) do
    local d = levenshtein(name, c)
    if d < bestD then best, bestD = c, d end
  end
  return bestD <= 2 and best or nil
end

-- _propSuggest(obj, key): " — did you mean 'x'?" for a prop-object key typo.
function ER._propSuggest(obj, key)
  local props = {}
  for p in pairs(obj.getProp or {}) do props[#props+1] = p end
  local s = suggest(tostring(key), props)
  return s and (" — did you mean '"..s.."'?") or ""
end

-- posAt(trs, node): source annotation for a compiled node, when the srcmap
-- still has a position entry (compRule sets trs.src/trs.srcmap before the
-- scan; the srcmap is consumed by csp.compile afterwards).
local function posAt(trs, node)
  local sp = trs.srcmap and node and trs.srcmap[node]
  if sp and trs.src then return ER.sourceAnnotation(trs.src, sp.pos, sp.len) end
  return ""
end

-- Head-purity whitelist: bare-name functions allowed to be CALLed in a rule
-- condition. The trigger scanner evaluates fragments of the condition at
-- registration time; a side-effecting function could run once there and
-- never again — the rule would appear to work and fail mysteriously later.
-- Any bare-name CALL not listed here is a registration error.
--   • condition modifiers — injected into the head by the parser's
--     since/cooldown/every/first_in rewrites (once() written by hand)
--   • pure builtins
--   • log — side-effecting by design, but returns its args; sanctioned as a
--     debug probe for head expressions
-- Indexed/field calls (math.floor(x), obj:fn(x)) and inline lambdas are not
-- classified: their target is visible inline code (mirrors the compiler's
-- intrinsic policy, which also only intercepts bare names). Users can
-- whitelist their own pure helpers: ER._headFuns.myFun = true
ER._headFuns = {
  trueFor = true, first_in_win = true, once = true, cool_down = true, every_other = true,
  fmt = true, HM = true, HMS = true, sign = true, rnd = true, round = true,
  sum = true, average = true, size = true, min = true, max = true,
  map = true, filter = true, reduce = true, log = true,
  osdate = true, ostime = true, nexttime = true, sunnext = true, global = true,
  date = true, day = true, month = true, wday = true, nextDST = true,
}

-- Known side-effecting builtins — special guidance when used in a head.
ER._impureFuns = {
  post = "posts events", cancel = "cancels timers", publish = "publishes events",
  subscribe = "registers handlers", remote = "calls remote devices",
  enable = "changes rule state", disable = "changes rule state",
  setGlobal = "writes a global variable", deleteglobal = "deletes a global",
  wait = "suspends the run", listglobals = "queries the API",
  historyOn = "changes rule state", historyOff = "changes rule state",
  watchOn = "changes rule state", watchOff = "changes rule state",
  showHistory = "prints", info = "prints", sort = "sorts its argument in place",
  adde = "modifies a table", addf = "modifies a table", remove = "modifies a table",
}

function HOPS.CALL(ast,trs)
  local f = ast[2]
  if f and type(f) == 'table' and f[1] == 'GET' and not ER._headFuns[f[2]] then
    local name = tostring(f[2])
    local hint = ""
    if ER._impureFuns[name] then
      hint = " — "..name.."() "..ER._impureFuns[name].."; move it into the action"
    else
      local names = {}
      for n in pairs(ER._headFuns) do names[#names+1] = n end
      local s = suggest(name, names)
      if s then hint = " — did you mean '"..s.."'?" end
    end
    error("Head function '"..name.."' is not allowed in a rule condition (side effects would run during trigger scanning)"..hint..". If it is side-effect free, whitelist it with ER._headFuns."..name.." = true"..posAt(trs, ast[2] or ast), 0)
  end
  stdScan(ast,trs)
end

-- Modifier gates compile into YIELD nodes; only the since gate suspends.
function HOPS.YIELD(ast,trs)
  if ast[2] ~= 'sinceGate' then
    error("Yield '"..tostring(ast[2]).."' is not allowed in a rule condition"..posAt(trs, ast))
  end
  stdScan(ast,trs) -- scan the duration and the wrapped condition for triggers
end

function HOPS.GETPROP(ast,trs)
  local obj = exprFun(ast[2])()
  local key = ast[3]
  if type(obj) ~= 'table' then obj = {obj} end
  for _,o in pairs(obj) do
    local gp = ER.resolvePropObject(o,key)
    assert(gp, "GETPROP: cannot resolve object: "..tostring(o))
    if not gp:hasGetProp(key) then
      error("GETPROP: no such property "..tostring(key).."' for object "..tostring(gp)..ER._propSuggest(gp, key)..posAt(trs, ast))
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
  assert(op, "scanHead: op '" .. tostring(ast[1]) .. "' is not allowed in a rule condition"..posAt(trs, ast))
  return op(ast,trs)
end

-------------------- Run rule ---------------------------------
-- Every execution context (rule or exprCtx) exposes:
--   ctx.isRule       -- true for rules, false for expressions
--   ctx.opts         -- merged options table
--   ctx.onDone       -- optional completion callback
--   ctx:log(level, prefix, ...)  -- verbosity-gated print
--
-- ── Modifier gates (first-class) ──────────────────────────────────────────
-- The CFUN gates receive the VM ctx and read rule/env through ctx:getOpts().
-- State lives in one home per gate: rule._mstate (cool_down, every_other,
-- once) or rule.trueFor (since). The public async functions in ScriptFuns
-- (trueFor, cool_down, every_other, first_in_win, once) delegate to these
-- cores, so user-written conditions share the modifier logic.

-- coolDown(rule, condval, T): fire only if >= T since last fire.
function ER._coolDown(rule, condval, T)
  if not condval then return false end  -- preserve AND short-circuit semantics
  local mstate = rule._mstate
  local state = mstate.cool_down or {}
  mstate.cool_down = state
  local now = os.time()
  if not state.lastFired or (now - state.lastFired) >= T then
    state.lastFired = now
    return true
  end
  return false
end

-- everyOther(rule, condval, N): fire only on every Nth true evaluation.
function ER._everyOther(rule, condval, N)
  if not condval then return false end
  local mstate = rule._mstate
  local state = mstate.every_other or {count=0}
  mstate.every_other = state
  state.count = state.count + 1
  if state.count % N == 0 then return true end
  return false
end

-- firstInWin(rule, env, condval, inWindow, stopVal): once() with a proactive
-- reset at the window end, so the rule can fire again in the NEXT occurrence
-- of the window. stopVal is seconds-since-midnight (<86400) or an epoch
-- timestamp (>=86400).
function ER._firstInWin(rule, env, condval, inWindow, stopVal)
  if not condval then return false end
  local mstate = rule._mstate
  if inWindow then
    if not mstate.once then
      mstate.once = true
      local msEnd
      if stopVal >= 86400 then  -- epoch timestamp
        msEnd = (stopVal - os.time()) * 1000
      else                      -- seconds since midnight
        local now_secs = os.time() - ER.midnight()
        local stop_adj = stopVal >= now_secs and stopVal or stopVal + 86400
        msEnd = (stop_adj - now_secs) * 1000
      end
      if msEnd > 0 then
        if mstate.once_timer then clearTimeout(mstate.once_timer) end
        mstate.once_timer = env.setTimeout(function()
          mstate.once = nil
          mstate.once_timer = nil
        end, msEnd)
      end
      return true
    end
    return false
  end
  -- Outside window: cancel any pending reset and clear the flag
  if mstate.once_timer then
    env.cancel(mstate.once_timer)
    mstate.once_timer = nil
  end
  mstate.once = nil
  return false
end

-- sinceGate(env, rule, time, condval, resume) → 'suspended' | 'resumed'
-- Continuously-true gate: arms a window timer on the first true evaluation
-- and resumes true when it fires; cancels it when the condition turns false.
function ER._sinceGate(env, rule, time, condval, resume)
  local state = rule.trueFor or {}
  rule.trueFor = state
  if condval then
    -- A ref whose timer is no longer registered was cancelled out from
    -- under us (single/terminate killTimers): start a fresh window
    -- instead of wedging with a stale ref.
    local pending = state.ref and (not rule.timers or rule.timers[state.ref])
    if not pending then
      state.ref = nil
      state.trigger = env.event
      state.ref = env.setTimeout(function()
        state.ref = nil
        resume(true)
      end, time*1000)
      return 'suspended'
    end
    resume(false)  -- already true and we have a live timer waiting
  elseif state.ref then
    env.cancel(state.ref)
    state.ref = nil
    resume(false)
  else
    resume(false)
  end
  return 'resumed'
end

-- CFUN gate wrappers: (cont, ctx, ...) — rule/env from ctx:getOpts().
function ER.coolDownGate(cont, ctx, condval, T)
  return cont(ER._coolDown(ctx:getOpts().rule, condval, T))
end
function ER.everyOtherGate(cont, ctx, condval, N)
  return cont(ER._everyOther(ctx:getOpts().rule, condval, N))
end
function ER.firstInWinGate(cont, ctx, condval, inWindow, stopVal)
  local opts = ctx:getOpts()
  return cont(ER._firstInWin(opts.rule, opts.env, condval, inWindow, stopVal))
end

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
        if ctx.isRule then ruleError(ctx, err) else ctx:log("normal", o.errorPrefix, err) end
      end
    end, ms)
    if ctx.timers then ctx.timers[ref] = ms end  -- track so single can cancel
  end,
  asyncFun = function(cf, ctx, cb, fun, ...)
    local timedOut,timeref = false,nil
    local o = ctx.opts
    local env = cf.ctx.opts and cf.ctx.opts.env
    if o.waiting then
      ctx:log("normal", o.waitPrefix, fmt("calling async func".."tion %s", tostring(fun)))
    end
    local fcb = setmetatable({cf=cf, ctx=ctx, env=env}, {
      __call = function(self,...)
        if timeref then
          if ctx.timers then ctx.timers[timeref] = nil end
          timeref = clearTimeout(timeref)
        end
        if timedOut then return end
        -- Discard callbacks from superseded runs: single/terminate cancelled
        -- this run's watchdog (and bumped ctx.gen), so a new run owns the
        -- rule now. Non-rule contexts have no gen and always resume.
        if ctx.gen and cf.ctx.opts.gen and ctx.gen ~= cf.ctx.opts.gen then return end
        if o.waited then
          ctx:log("normal", o.waitedPrefix, fmt("back from async func %s", tostring(fun)))
        end
        local args = table.pack(...)
        local ok, err = pcall(function()
          resumeRunner(table.pack(ER.csp.resume(cf, table.unpack(args, 1, args.n))), ctx, cb)
        end)
        if not ok then
          if ctx.isRule then ruleError(ctx, err) else ctx:log("normal", o.errorPrefix, err) end
        end
      end
    })
    local res = {pcall(fun, fcb, ...)}
    -- Async function protocol — fun(cb, ...) returns:
    --   true, timeout  → async; watchdog resumes cb(false) after timeout ms
    --                    (nil timeout defaults to 3000 ms)
    --   true, -1      → sync: fun already called cb, no watchdog
    --   true, false   → async, no watchdog: fun owns its timers and
    --                    promises to call cb
    --   false, err    → error: resume with no result
    local timeout = res[2]
    if res[1] then
      -- Async, wait for callback or timeout
      if timeout ~= false then
        timeout = tonumber(timeout) or 3000
        if timeout >= 0 then
          timeref = setTimeout(function()
            if ctx.timers then ctx.timers[timeref] = nil end
            timeref = nil
            timedOut = true
            ctx:log("normal", o.errorPrefix, fmt("Async func".."tion %s timed out after %dms", tostring(fun), timeout))
            local ok, err = pcall(function()
              resumeRunner(table.pack(ER.csp.resume(cf, false)), ctx, cb)
            end)
            if not ok then
              if ctx.isRule then ruleError(ctx, err) else ctx:log("normal", o.errorPrefix, err) end
            end
          end, timeout)
          if ctx.timers then ctx.timers[timeref] = timeout end  -- track so single/terminate can cancel
        end
      end -- -1: sync, cb already called; false: no watchdog
    else
      ctx:log("normal", o.errorPrefix, fmt("Async func".."tion error: %s", tostring(res[2])))
      timedOut = true
      return cb() -- resume with no result on error
    end
  end,
  sinceGate = function(cf, ctx, cb, time, condval)
    local env = cf.ctx.opts and cf.ctx.opts.env
    local resume = function(val)
      local ok, err = pcall(function()
        resumeRunner(table.pack(ER.csp.resume(cf, val)), ctx, cb)
      end)
      if not ok then
        if ctx.isRule then ruleError(ctx, err) else ctx:log("normal", ctx.opts.errorPrefix, err) end
      end
    end
    ER._sinceGate(env, ctx, time, condval, resume)
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

-- Apply the disableOnError policy to a runtime error that aborted a rule
-- evaluation:
--   true (default)  → disable immediately (backward compatible)
--   false           → never disable; keep running, just log
--   N (number)      → disable after N consecutive errored runs; any clean
--                     completion (condition false, or the action finishes)
--                     resets the counter
local function ruleError(ctx, err)
  ctx:log("silent", ctx.opts.errorPrefix, err)
  local policy = ctx.opts.disableOnError
  if policy == false then return end
  if policy == nil or policy == true or type(policy) ~= 'number' then
    ctx:log("silent", ctx.opts.errorPrefix, "Disabled")
    ctx.disable()
    return
  end
  local n = (ctx.failCount or 0) + 1
  ctx.failCount = n
  if n >= policy then
    ctx:log("silent", ctx.opts.errorPrefix, fmt("Disabled after %d consecutive errors", n))
    ctx.disable()
  else
    ctx:log("silent", ctx.opts.errorPrefix, fmt("%d consecutive error(s) — disables at %d", n, policy))
  end
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
  evalOpts.gen = ctx.gen or 0  -- snapshot of the run generation at suspension

  local function onDone(...)
    -- Clean completion (condition false, or the action finished) resets the
    -- disableOnError error streak, and drops the in-flight run counter.
    if ctx.isRule then
      if ctx.failCount then ctx.failCount = 0 end
      if ctx.active then ctx.active = ctx.active - 1 end
    end
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
    -- ExecutionEnv for async functions: unbox the invocation vars once
    -- here, so modifier functions (trueFor, cool_down, ...) never dig into
    -- continuation snapshots or the VM's boxed var frames.
    local vars = evalOpts.vars
    evalOpts.env = {
      rule      = ctx,
      event     = vars.event and vars.event[1] or nil,
      _evKey    = vars._evKey and vars._evKey[1] or nil,
      setTimeout = vars.setTimeout and vars.setTimeout[1],
      cancel    = vars.cancel and vars.cancel[1],
      post      = vars.post and vars.post[1],
    }
    resumeRunner(table.pack(ER.csp.eval(f, evalOpts)), ctx, onDone)
  end)
  synced = true

  if not ok then
    if ctx.isRule then
      if ctx.active then ctx.active = ctx.active - 1 end -- aborted run
      ruleError(ctx, err)
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
--   Failure: returns (nil, errmsg) — so callers can distinguish a failed
--   eval from an async/suspended one (which returns plain nil).
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
        printErr(opts.errorPrefix, fmtErr(err, src))
        return nil, fmtErr(err, nil)  -- explicit failure status (hinted)
      end
      error(err, 0)
    end
  end
  local isRule = (ast[1] == 'RULE')
  local result
  local errmsg

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
    if opts.throw then error(err, 0) end
    printErr(opts.errorPrefix, fmtErr(err, src))
    errmsg = fmtErr(err, nil)
  end

  -- For bare expressions: log the sync result if we got one.
  -- Async (nil return) was already logged 💤 by ruleRunner.
  -- Rule form: compRule already logged ✅ with trigger list.
  if not isRule and result and result[1] ~= nil then
    if not (opts.verbosity == "silent") and opts.result then
      print(opts.resultPrefix, table.unpack(beautifyArgs(result), 1, result.n))
    end
  end

  if errmsg then return nil, errmsg end
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
  function vm.host.formatSource(src, pos, len) return ER.sourceAnnotation(src, pos, len) end
  function vm.host.hintError(msg) return hintErr(msg) end
  function vm.host.formatError(v)  -- non-string error values (thrown tables etc.)
    if type(v) == 'table' then return json.encode(v) end
    return tostring(v)
  end
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
  er.loadDevice = ER.loadDevice
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