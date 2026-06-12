MODULE = MODULE or {}
local function module(ER)
  local fmt = string.format
  
  
  local function getProp(obj, key, ctx)
    local found,event = ctx:getVar('event')
    if ER.propFilters[key] then
      if type(obj) ~= 'table' then obj = {obj} end
      return ER.propFilters[key](obj)
    end
    if type(obj) == 'table' then
      assert(obj[1], "#invalid property access on table without objects :"..tostring(key))
      local fobj = ER.resolvePropObject(obj[1],key)
      if not fobj:hasGetProp(key) then error("#no such property :"..tostring(key).." (get)") end
      local reduce = fobj:hasReduce(key)
      if not reduce then 
        return table.map(function(o) 
          o = ER.resolvePropObject(o,key)
          if not o:hasGetProp(key) then error("#no such property :"..tostring(key).." (get)") end
          return o:_getProp(key, event)
        end, obj)
      end
      return reduce(function(o) 
        o = ER.resolvePropObject(o,key)
        if not o:hasGetProp(key) then error("#no such property :"..tostring(key).." (get)") end
        return o:_getProp(key, event)
      end, obj)
    end
    obj = ER.resolvePropObject(obj,key)
    assert(obj,"No object found for property access :"..tostring(key))
    assert(obj:hasGetProp(key), "no such property :"..tostring(key).." (get)")
    return obj:_getProp(key, event)
  end
  
  local function setProp(obj, key, value, ctx)
    local found,event = ctx:getVar('event')
    if type(obj) == "table" then
      for _,obj in ipairs(obj) do
        setProp(obj, key, value, ctx)
      end
      return true
    end
    obj = ER.resolvePropObject(obj,key)
    assert(obj,"No object found for property access :"..tostring(key))
    assert(obj:hasSetProp(key), "no such property :"..tostring(key).." (set)")
    --obj = ER.resolvePropObject(obj,key)
    obj:_setProp(key, value, event)
    return true
  end
  
  local function setupFuns()
    local vm = ER.csp
    local sourceTrigger = ER.sourceTrigger
    
    ER.globals = setmetatable({},{
      __index    = function(t,k)   return vm.lookupGlobal(k) end,
      __newindex = function(t,k,v) vm.setGlobal(k,v) end
    })
    ER.defglobals = setmetatable({},{
      __index    = function(t,k)   return vm.lookupGlobal(k) end,
      __newindex = function(t,k,v) vm.defGlobal(k,v) end
    })
    local builtin = ER.defglobals
    
    builtin.math = math
    builtin.table = table
    builtin.string = string
    builtin.json = json
    builtin.fibaro = fibaro
    builtin.api = api
    builtin.quickApp = quickApp
    
    local function detag(str)
      local color
      str = str:gsub("(#C:)(.-)(#)",function(_,c) color=c return "" end)
      if color then str=string.format("<font color='%s'>%s</font>",color,str) end
      return str
    end
    
    local function rawLog(...) -- printable tables and #C:color# tag
      local args,n = {...},0
      for i=1,#args do 
        local a = args[i]
        local typ = type(a)
        n = n+1
        if typ == 'string' then args[i] = detag(a)
        elseif typ == 'table' or typ == 'userdata' then 
          local mt = getmetatable(a)
          if mt and mt.__tostring then args[i] = tostring(a)
          else args[i] = json.encodeFast(a) end
        end
      end
      local msg = ""
      if n == 1 then msg = args[1] elseif n > 1 then msg = string.format(table.unpack(args)) end
      print(msg)
      return msg
    end
    
    -- log(...)           plain log, supports #C:color# tag in format string
    -- log.colorname(...) wraps first string arg in #C:colorname# automatically
    -- log.beige "msg"    string-shorthand works too (single arg, no parens)
    builtin.log = setmetatable({}, {
      __call  = function(_, ...) return rawLog(...) end,
      __index = function(_, color)
        return function(fmt, ...)
          if type(fmt) == 'string' then fmt = '#C:'..color..'#'..fmt end
          return rawLog(fmt, ...)
        end
      end,
    })
    
    function builtin.post(ev,time) return (ER.sourceTrigger:post(ev,time)) end
    function builtin.cancel(ref) return ER.sourceTrigger:cancel(ref) end
    function builtin.fmt(...) return string.format(...) end
    function builtin.HM(t) return os.date("%H:%M",t < os.time()-8760*3600 and t+ER.midnight() or t) end
    function builtin.HMS(t) return os.date("%H:%M:%S",t < os.time()-8760*3600 and t+ER.midnight() or t) end
    function builtin.sign(t) return t < 0 and -1 or 1 end
    function builtin.rnd(min,max) return math.random(min,max)end
    function builtin.round(num) return math.floor(num+0.5) end
    local function sum(...) 
      local args = {...}
      if #args == 1 and type(args[1]) == "table" then args = args[1] end
      local s = 0 for i=1,#args do s = s + args[i] end
      return s
    end
    builtin.sum = sum
    function builtin.average(f,...) 
      local s = sum(f,...) return s / (type(f)=='table' and #f or select("#", ...)+1)
    end
    function builtin.size(t) return #t end
    function builtin.min(...) 
      local args = {...}
      if #args == 1 and type(args[1]) == "table" then args = args[1] end
      return math.min(table.unpack(args))
    end
    function builtin.max(...) 
      local args = {...}
      if #args == 1 and type(args[1]) == "table" then args = args[1] end
      return math.max(table.unpack(args))
    end
    function builtin.sort(t) table.sort(t) return t end
    function builtin.map(t, f) local r={} for i,v in ipairs(t) do r[i]=f(v) end return r end
    function builtin.filter(t, f) local r={} for _,v in ipairs(t) do if f(v) then r[#r+1]=v end end return r end
    function builtin.reduce(t, f, acc) for _,v in ipairs(t) do acc=f(acc,v) end return acc end
    function builtin.osdate(a,b) return os.date(a,b) end
    function builtin.ostime(t) return os.time(t) end
    function builtin.nexttime(m,n) local t1 = m+n; return t1 > os.time() and t1 or t1+86400 end
    
    function builtin.global(name)
      local s = fibaro.getGlobalVariable(name)     
      local a,b = api.post("/globalVariables/",{name=name,value = ""})
      return s == nil,(s == nil and fmt("'%s' created",name) or fmt("'%s' exists",name))
    end
    
    function builtin.listglobals() return api.get("/globalVariables") end
    function builtin.deleteglobal(name) api.delete("/globalVariables/"..name) end
    
    fibaro.ER_subscriptionVar = "ER_subscription"
    local ersf = false
    local function setupERsubscription()
      if ersf then return end ersf = true
      api.post("/globalVariables",{
        name=fibaro.ER_subscriptionVar, value='{"type":"."}'
      })
      ER.sourceTrigger:subscribe({type='global-variable', name=fibaro.ER_subscriptionVar},
      function(ev) 
        local stat,event = pcall(json.decode, ev.event.value)
        if stat and ER.isEvent(event) and event._published then
          ER.sourceTrigger:post(event)
        end
      end)
    end
    
    function builtin.subscribe(event) 
      assert(ER.isEvent(event), "argument to subscribe must be an event")
      setupERsubscription()
      local sevent = table.copy(event)
      sevent._from = "$_<>"..plugin.mainDeviceId
      sevent._published = true
      ER.sourceTrigger:subscribe(sevent,function(ev) 
        local event = ev.event
        ER.sourceTrigger:post(event.value)
      end)
    end
    function builtin.publish(event)
      assert(ER.isEvent(event), "argument to publish must be an event")
      setupERsubscription()
      local pevent = table.copy(event)
      pevent._from = plugin.mainDeviceId
      pevent._published = true
      fibaro.setGlobalVariable(fibaro.ER_subscriptionVar, json.encode(pevent))
    end
    
    function builtin.remote(deviceId,event) 
      assert(ER.isEvent(event), "argument to remote must be an event")
      ER.sourceTrigger:postRemote(deviceId,event)
    end
    
    function builtin.adde(t,v) table.insert(t,v) return t end
    function builtin.addf(t,v) table.insert(t,1,v) return t end
    function builtin.remove(t,v) 
      for i=#t,1,-1 do if t[i]==v then table.remove(t,i) end end 
      return t
    end
    
    function ER.enable(arg,state)
      local action = state and 'enable' or 'disable'
      local emoji = state and '✅' or '❌'
      if type(arg) == "string" then 
        local rules = ER.getGroup(arg)
        assert(rules, "no such group: "..arg)
        for _,r in ipairs(rules) do 
          r:log("verbose", emoji, action.."d")
          r[action]()
        end
        return
      elseif type(arg) == "number" then arg = ER.getRule(arg) end
      assert(ER.isRule(arg), "argument to disable must be a rule, group name, or rule ID")
      arg[action]()
      arg:log("verbose", emoji, action.."d")
    end
    
    function builtin.enable(rule) ER.enable(rule,true) end
    function builtin.disable(rule) ER.enable(rule,false) end
    
    function builtin.historyOn(rule, size)
      local r = ER.getRule(rule)
      assert(r, "historyOn: no such rule: "..tostring(rule))
      r.historySize = size or r.historySize
      r.historyOn = true
      r.history = {}
    end
    
    function builtin.historyOff(rule)
      local r = ER.getRule(rule)
      assert(r, "historyOff: no such rule: "..tostring(rule))
      r.historyOn = false
    end
    
    function builtin.watchOn(rule)
      local r = ER.getRule(rule)
      assert(r, "watchOn: no such rule: "..tostring(rule))
      r.watchOn = true
    end
    
    function builtin.watchOff(rule)
      local r = ER.getRule(rule)
      assert(r, "watchOff: no such rule: "..tostring(rule))
      r.watchOn = false
    end
    
    function builtin.watchOnAll()
      for _, r in pairs(ER.namedRules) do r.watchOn = true end
    end
    
    function builtin.watchOffAll()
      for _, r in pairs(ER.namedRules) do r.watchOn = false end
    end
    
    function builtin.historyOnAll(size)
      for _, r in pairs(ER.namedRules) do
        r.historySize = size or r.historySize
        r.historyOn = true
        r.history = {}
      end
    end
    
    function builtin.historyOffAll()
      for _, r in pairs(ER.namedRules) do
        r.historyOn = false
      end
    end
    
    function builtin.showHistory(rule)
      local r = ER.getRule(rule)
      assert(r, "showHistory: no such rule: "..tostring(rule))
      if not r.history or #r.history == 0 then
        print(fmt("📋 [%s] No history recorded", r.name))
        return
      end
      print(fmt("📋 [%s] Last %d invocations:", r.name, #r.history))
      for _, e in ipairs(r.history) do
        local ts = os.date("%H:%M:%S", e.time)
        local res = e.result and "✅ PASS" or "❌ FAIL"
        print(fmt("  %s  %s  %s", ts, res, e.trigger))
      end
    end
    
    function builtin.info(rule)
      local r = ER.getRule(rule)
      assert(r, "info: no such rule: "..tostring(rule))
      local src = r.src and (r.src:len() > 80 and r.src:sub(1,77).."..." or r.src) or "n/a"
      print(fmt("ℹ️  [%s] (id=%d)", r.name, r.id))
      print(fmt("   src:     %s", src))
      print(fmt("   status:  %s", r._disabled and "❌ disabled" or "✅ enabled"))
      if r.opts.group then
        print(fmt("   group:   %s", r.opts.group))
      end
      -- triggers
      print("   triggers:")
      r:dumpTriggers("  ")
      -- modifier flags (compile-time)
      local mods = {}
      if r.modifiers.single   then mods[#mods+1] = "single" end
      if r.modifiers.debounce then mods[#mods+1] = fmt("debounce(%s)", r.modifiers.debounce) end
      if #mods > 0 then print(fmt("   modifiers: %s", table.concat(mods, ", "))) end
      -- modifier runtime state
      local ms = r._mstate
      if ms.once      ~= nil then print(fmt("   once:      %s", ms.once and "locked" or "open")) end
      if ms.cool_down ~= nil then
        local cd = ms.cool_down
        print(fmt("   cooldown:  last fired %s", cd.lastFired and os.date("%H:%M:%S", cd.lastFired) or "never"))
      end
      if ms.every_other ~= nil then print(fmt("   every:     count=%d", ms.every_other.count)) end
      if r.trueFor and r.trueFor.ref then
        print(fmt("   trueFor:   waiting (triggered by %s)", tostring(r.trueFor.trigger)))
      end
      -- active timers
      local tc = 0; for _ in pairs(r.timers) do tc = tc + 1 end
      if tc > 0 then print(fmt("   timers:    %d active", tc)) end
      -- history
      print(fmt("   history:   %s (size=%d, entries=%d)",
      r.historyOn and "recording" or "off", r.historySize, #r.history))
      return r
    end
    
    local async = ER.async
    
    function async.trueFor(cb,time,expr)
      local opts = cb.cf.ctx.opts
      local env = cb.cf.ctx.var_env[1]
      local trueFor = opts.rule.trueFor or {}
      opts.rule.trueFor = trueFor
      if expr then -- test is true
        if not trueFor.ref then -- new, start timer
          trueFor.trigger = env.event
          trueFor.ref = env.setTimeout[1](function() 
            trueFor.ref = nil; cb(true) 
          end, time*1000)
          return 3600*24*30--math.huge
        else -- already true and we have timer waiting
          cb(false) -- do nothing
        end
      elseif trueFor.ref then -- test is false, and we have timer
        env.cancel[1](trueFor.ref)
        trueFor.ref = nil
        cb(false)
      else
        cb(false) -- do nothing
      end
      return -1 -- not async...
    end
    
    -- first_in_win: like once() but proactively resets at the window end time
    -- so the rule can fire again in the NEXT occurrence of the window.
    -- stopVal is seconds-since-midnight (< 86400) or an epoch timestamp (>= 86400).
    function async.first_in_win(cb, inWindow, stopVal)
      local opts = cb.cf.ctx.opts
      local rule = opts and opts.rule
      local mstate = rule and rule._mstate or cb.ctx
      if inWindow then
        if not mstate.once then
          mstate.once = true
          -- Schedule a reset at the end of the window
          local msEnd
          if stopVal >= 86400 then  -- epoch timestamp
            msEnd = (stopVal - os.time()) * 1000
          else                      -- seconds since midnight
            local now_secs = os.time() - ER.midnight()
            local stop_adj = stopVal >= now_secs and stopVal or stopVal + 86400
            msEnd = (stop_adj - now_secs) * 1000
          end
          if msEnd > 0 and rule then
            if mstate.once_timer then clearTimeout(mstate.once_timer) end
            local ref
            ref = setTimeout(function()
              mstate.once = nil
              mstate.once_timer = nil
              if rule.timers then rule.timers[ref] = nil end
            end, msEnd)
            mstate.once_timer = ref
            if rule.timers then rule.timers[ref] = msEnd end
          end
          cb(true)
        else cb(false) end
      else
        -- Outside window: cancel any pending reset and clear the flag
        if mstate.once_timer then
          clearTimeout(mstate.once_timer)
          if rule and rule.timers then rule.timers[mstate.once_timer] = nil end
          mstate.once_timer = nil
        end
        mstate.once = nil
        cb(false)
      end
      return -1 -- not async
    end
    
    function async.once(cb, expr)
      -- Backwards-compatible wrapper: resets at midnight (00:00 = stopVal 0)
      return async.first_in_win(cb, expr, 0)
    end
    
    function async.cool_down(cb, T)
      local opts = cb.cf.ctx.opts
      local rule = opts and opts.rule
      local mstate = rule and rule._mstate or cb.ctx
      local state = mstate.cool_down or {}
      mstate.cool_down = state
      local now = os.time()
      if not state.lastFired or (now - state.lastFired) >= T then
        state.lastFired = now
        cb(true)
      else
        cb(false)
      end
      return -1 -- not async
    end
    
    function async.every_other(cb, N)
      local opts = cb.cf.ctx.opts
      local rule = opts and opts.rule
      local mstate = rule and rule._mstate or cb.ctx
      local state = mstate.every_other or {count=0}
      mstate.every_other = state
      state.count = state.count + 1
      if state.count % N == 0 then
        cb(true)
      else
        cb(false)
      end
      return -1 -- not async
    end
    
    function async.again(cb,n)
      local opts = cb.cf.ctx.opts
      local env = cb.cf.ctx.var_env[1]
      local trueFor = opts.rule.trueFor or {}
      if trueFor then
        if trueFor.again and trueFor.again == 0 then trueFor.again = nil return cb(0) end 
        if trueFor.again == nil then trueFor.again,trueFor.againN = n,n end-- reset
        trueFor.again = trueFor.again - 1
        if trueFor.trigger and  trueFor.again > 0 then 
          env.setTimeout[1](function() cb.ctx:run(trueFor.trigger) end, 0)
          cb(trueFor.againN - trueFor.again)
        else trueFor.again = nil cb(trueFor.againN) end
      else cb(0) end
      return -1 -- not async...
    end
    
    local function makeDateFun(str,cache)
      if cache[str] then return cache[str] end
      local f = ER.dateTest(str)
      cache[str] = f
      return f
    end
    
    local cache = { date={}, day = {}, month={}, wday={} }
    builtin.date = function(s) return (cache.date[s] or makeDateFun(s,cache.date))() end               -- min,hour,days,month,wday
    builtin.day = function(s) return (cache.day[s] or makeDateFun("* * "..s,cache.day))() end          -- day('1-31'), day('1,3,5')
    builtin.month = function(s) return (cache.month[s] or makeDateFun("* * * "..s,cache.month))() end  -- month('jan-feb'), month('jan,mar,jun')
    builtin.wday = function(s) return (cache.wday[s] or makeDateFun("* * * * "..s,cache.wday))() end   -- wday('fri-sat'), wday('mon,tue,wed')
    
    builtin.S1 = {click = "16", double = "14", tripple = "15", hold = "12", release = "13"}
    builtin.S2 = {click = "26", double = "24", tripple = "25", hold = "22", release = "23"}
    
    function builtin.nextDST()
      local d0 = os.date("*t")
      local t0 = os.time({year=d0.year, month=d0.month, day=1, hour=0})
      local h = d0.hour
      repeat  t0 = t0 + 3600*24*30; d0 = os.date("*t",t0) until d0.hour ~= h
      t0 = t0 - 3600*24*30; d0 = os.date("*t",t0)
      repeat h = d0.hour; t0 = t0 + 3600*24; d0 = os.date("*t",t0) until d0.hour ~= h
      t0 = t0 - 3600*24; d0 = os.date("*t",t0)
      repeat h = d0.hour; t0 = t0 + 3600; d0 = os.date("*t",t0) until d0.hour ~= (h+1) % 24
      if d0.month > 7 then t0 = t0 + 3600 end
      return t0
    end
    
    -- Named Scene PropClass ---------------------------------------------------
    Scene = {}
    local LFUN = "func".."tion"
    ER.definePropClass("Scene")
    function Scene:__init()
      PropObject.__init(self)
    end
    Scene.getProp.activate = function(self, _prop)
      for _, e in ipairs(self._activate) do
        local val = type(e[3]) == LFUN and e[3]() or e[3]
        ER.resolvePropObject(e[1],_prop):_setProp(e[2], val)
      end
    end
    Scene.getProp.deactivate = function(self, _prop)
      assert(self._deactivate, "#Scene has no deactivate body")
      for _, e in ipairs(self._deactivate) do
        local val = type(e[3]) == LFUN and e[3]() or e[3]
        ER.resolvePropObject(e[1],_prop):_setProp(e[2], val)
      end
    end
    builtin.Scene = function(entries)
      local s = Scene()
      s._activate   = entries.activate
      s._deactivate = entries.deactivate
      return s
    end
    
  end
  
  ER.setupFuns = setupFuns
  ER.getProp = getProp
  ER.setProp = setProp
  
end

MODULE[#MODULE+1] = { name = "ScriptFuns", sys = true, code = module }