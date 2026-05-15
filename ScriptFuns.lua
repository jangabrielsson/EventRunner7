fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
local fmt = string.format


local function getProp(obj, key, ctx)
  local found,event = ctx:getVar('event')
  if ER.propFilters[key] then
    if type(obj) ~= 'table' then obj = {obj} end
    return ER.propFilters[key](obj)
  end
  if type(obj) == 'table' then
    assert(obj[1], "#invalid property access on table without objects :"..tostring(key))
    local fobj = ER.resolvePropObject(obj[1])
    if not fobj:hasGetProp(key) then error("#no such property :"..tostring(key).." (get)") end
    local reduce = fobj:hasReduce(key)
    if not reduce then 
      return table.map(function(o) 
        o = ER.resolvePropObject(o)
        if not o:hasGetProp(key) then error("#no such property :"..tostring(key).." (get)") end
        return o:_getProp(key, event)
      end, obj)
    end
    return reduce(function(o) 
        o = ER.resolvePropObject(o)
        if not o:hasGetProp(key) then error("#no such property :"..tostring(key).." (get)") end
        return o:_getProp(key, event)
      end, obj)
  end
  obj = ER.resolvePropObject(obj)
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
  obj = ER.resolvePropObject(obj)
  assert(obj:hasSetProp(key), "no such property :"..tostring(key).." (set)")
  --obj = ER.resolvePropObject(obj)
  obj:_setProp(key, value, event)
  return true
end

local function setupFuns()
  local vm = ER.csp
  local sourceTrigger = ER.sourceTrigger

  ER.globals = setmetatable({},{
    __index    = function(t,k)   return vm.getGlobal(k) end,
    __newindex = function(t,k,v) vm.setGlobal(k,v) end
  })
  ER.defglobals = setmetatable({},{
    __index    = function(t,k)   return vm.getGlobal(k) end,
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
    str = str:gsub("(#C:)(.-)(#)",function(_,c) color=c return "" end)
    if color then str=string.format("<font color='%s'>%s</font>",color,str) end
    return str
  end
  
  function builtin.log(...) -- printable tables and #C:color# tag
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
  function builtin.osdate(a,b) return os.date(a,b) end
  function builtin.ostime(t) return os.time(t) end
  
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
  function builtin.remove(t,v) 
    for i=#t,1,-1 do if t[i]==v then table.remove(t,i) end end 
    return t
  end
  
  function builtin.enable(rule)
    assert(ER.isRule(rule) or type(rule) == "number", "argument to enable must be a rule/id")
    ER.getRule(rule).enable()
  end
  function builtin.disable(rule) 
    assert(ER.isRule(rule) or type(rule) == "number", "argument to disable must be a rule/id")
    ER.getRule(rule).disable()
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

  function async.once(cb,expr)
    local once = cb.rule.once
    if expr then
      if not once then 
        cb.rule.once = true
        cb(true)
      else cb(false) 
      end
    else  cb.rule.once = nil; cb(false) end
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
        env.setTimeout[1](function() cb.rule:run(trueFor.trigger) end, 0)
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

end

ER.setupFuns = setupFuns
ER.getProp = getProp
ER.setProp = setProp