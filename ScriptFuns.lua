fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
local fmt = string.format

local function armState(id) return id==0 and fibaro.getHomeArmState() or fibaro.getPartitionArmState(id) end
local function arm(id,action)
  if action=='arm' then 
    local _,res = ER.alarmFuns.armPartition(id); return res == 200
  else
    local _,res = ER.alarmFuns.unarmPartition(id); return res == 200
  end
end
local function tryArm(id)
  local data,res = ER.alarmFuns.tryArmPartition(id)
  if res ~= 200 then return false end
  if type(data) == 'table' then
    ER.sourceTrigger:post({type='alarm',id=id,action='tryArm',property='delayed',value=data})
  end
  return true
end

local getProps,setProps = {},{}
local function setupProps()
  
  local mapAnd,mapOr,mapF = table.mapAnd, table.mapOr, table.mapf
  local function BN(x) if type(x)=='boolean' then return x and 1 or 0 else return tonumber(x) or 0 end end
  local function get(id,prop) return fibaro.get(id,prop) end
  local function getnum(id,prop) return tonumber((fibaro.get(id,prop))) or nil end
  local function on(id,prop) return BN(fibaro.get(id,prop)) > 0 end
  local function off(id,prop) return BN(fibaro.get(id,prop)) == 0 end
  local function partition(id) return api.get("/alarms/v1/partitions/" .. id) or {} end
  local function call(id,cmd) fibaro.call(id,cmd); return true end
  local function toggle(id,prop) if on(id,prop) then fibaro.call(id,'turnOff') else fibaro.call(id,'turnOn') end return true end
  local function profile(id,_) return api.get("/profiles/"..id) end
  local function child(id,_) return quickApp.childDevices[id] end
  local function cce(id,_,e) 
    if e==nil then return {} end
    return e.type=='device' and e.property=='centralSceneEvent'and e.id==id and e.value or {} 
  end
  local function ace(id,_,e) 
    if e==nil then return {} end 
    return e.type=='device' and e.property=='accessControlEvent' and e.id==id and e.value or {} 
  end
  local function sae(id,_,e) 
    if e==nil then return nil end 
    return e.type=='device' and e.property=='sceneActivationEvent' and e.id==id and e.value.sceneId 
  end
  local function last(id,prop) 
    local _,t=fibaro.get(id,prop)
    local r = t and os.time()-t or 0
    return r 
  end
  
  getProps = {}
  getProps.value={
    'device',       -- event type
    get,            -- function to get the value
    'value',        -- property to get
    nil,            -- map function (optional)
    true            -- isTrigger (optional, default false)
  }
  getProps.state={'device',get,'state',nil,true}
  getProps.bat={'device',getnum,'batteryLevel',nil,true}
  getProps.power={'device',getnum,'power',nil,true}
  getProps.isDead={'device',get,'dead',mapOr,true}
  getProps.isOn={'device',on,'value',mapOr,true}
  getProps.isOff={'device',off,'value',mapAnd,true}
  getProps.isAllOn={'device',on,'value',mapAnd,true}
  getProps.isAnyOff={'device',off,'value',mapOr,true}
  getProps.last={'device',last,'value',nil,true}
  
  getProps.armed={'alarm',function(id) return  armState(id)=='armed' end,'armed',mapOr,true}
  getProps.tryArm={'alarm',tryArm,nil,'alarm',false}
  getProps.isArmed={'alarm',function(id) return partition(id).armed end,'armed',mapOr,true}             -- api.get("/alarms/v1/partitions/" .. id)
  getProps.isAllArmed={'alarm',function(id) return partition(id).armed end,'armed',mapAnd,true,true}    -- fibaro.getHomeArmState()
  getProps.isDisarmed={'alarm',function(id) return partition(id).armed==false end,'armed',mapAnd,true}  --  fibaro.getPartitionArmState(id)
  getProps.isAnyDisarmed={'alarm',function(id) return partition(id).armed==false end,'armed',mapOr,true,false} -- ER.alarmFuns.armPartition(id)
  getProps.isAlarmBreached={'alarm',function(id) return partition(id).breached end,'breached',mapOr,true}      -- ER.alarmFuns.unarmPartition(id)
  getProps.isAlarmSafe={'alarm',function(id) return partition(id).breached==false end,'breached',mapAnd,true}  -- ER.alarmFuns.tryArmPartition(id)
  getProps.isAllAlarmBreached={'alarm',function(id) return partition(id).breached end,'breached',mapAnd,true}
  getProps.isAnyAlarmSafe={'alarm',function(id) return partition(id).breached==false end,'breached',mapOr,true,false}
  
  getProps.child={'device',child,nil,nil,false}
  getProps.parent={'device',function(id) return api.get("/devices/"..id).parentId end,nil,nil,false}
  getProps.profile={'device',profile,nil,nil,false}
  getProps.scene={'device',sae,'sceneActivationEvent',nil,true}
  getProps.access={'device',ace,'accessControlEvent',nil,true}
  getProps.central={'device',cce,'centralSceneEvent',nil,true}
  local keyMT = { __tostring = function(t) return string.format("%s:%s",t.keyId or '',t.keyAttribute or '') end }
  getProps.key={'device',function(id,_,ev) local e = cce(id,_,ev); e = e or {} e.id,e.attr = e.keyId,e.keyAttribute return setmetatable(e or {},keyMT) end,'centralSceneEvent',nil,true}
  getProps.safe={'device',off,'value',mapAnd,true}
  getProps.breached={'device',on,'value',mapOr,true}
  getProps.isOpen={'device',on,'value',mapOr,true}
  getProps.isClosed={'device',off,'value',mapAnd,true}
  getProps.lux={'device',getnum,'value',nil,true}
  getProps.volume={'device',get,'volume',nil,true}
  getProps.position={'device',get,'position',nil,true}
  getProps.temp={'device',get,'value',nil,true}
  getProps.coolingThermostatSetpoint={'device',get,'coolingThermostatSetpoint',nil,true}
  getProps.coolingThermostatSetpointCapabilitiesMax={'device',get,'coolingThermostatSetpointCapabilitiesMax',nil,true}
  getProps.coolingThermostatSetpointCapabilitiesMin={'device',get,'coolingThermostatSetpointCapabilitiesMin',nil,true}
  getProps.coolingThermostatSetpointFuture={'device',get,'coolingThermostatSetpointFuture',nil,true}
  getProps.coolingThermostatSetpointStep={'device',get,'coolingThermostatSetpointStep',nil,true}
  getProps.heatingThermostatSetpoint={'device',get,'heatingThermostatSetpoint',nil,true}
  getProps.heatingThermostatSetpointCapabilitiesMax={'device',get,'heatingThermostatSetpointCapabilitiesMax',nil,true}
  getProps.heatingThermostatSetpointCapabilitiesMin={'device',get,'heatingThermostatSetpointCapabilitiesMin',nil,true}
  getProps.heatingThermostatSetpointFuture={'device',get,'heatingThermostatSetpointFuture',nil,true}
  getProps.heatingThermostatSetpointStep={'device',get,'heatingThermostatSetpointStep',nil,true}
  getProps.thermostatFanMode={'device',get,'thermostatFanMode',nil,true}
  getProps.thermostatFanOff={'device',get,'thermostatFanOff',nil,true}
  getProps.thermostatMode={'device',get,'thermostatMode',nil,true}
  getProps.thermostatModeFuture={'device',get,'thermostatModeFuture',nil,true}
  getProps.on={'device',call,'turnOn',mapF,true}
  getProps.off={'device',call,'turnOff',mapF,true}
  getProps.play={'device',call,'play',mapF,nil}
  getProps.pause={'device',call,'pause',mapF,nil}
  getProps.open={'device',call,'open',mapF,true}
  getProps.close={'device',call,'close',mapF,true}
  getProps.stop={'device',call,'stop',mapF,true}
  getProps.secure={'device',call,'secure',mapF,false}
  getProps.unsecure={'device',call,'unsecure',mapF,false}
  getProps.isSecure={'device',on,'secured',mapAnd,true}
  getProps.isUnsecure={'device',off,'secured',mapOr,true}
  getProps.name={'device',function(id) return fibaro.getName(id) end,nil,nil,false}
  getProps.partition={'alarm',function(id) return partition(id) end,nil,nil,false}
  getProps.HTname={'device',function(id) return ER.reverseVar(id) end,nil,nil,false}
  getProps.roomName={'device',function(id) return fibaro.getRoomNameByDeviceID(id) end,nil,nil,false}
  getProps.trigger={'device',function() return true end,'value',nil,true}
  getProps.time={'device',get,'time',nil,true}
  getProps.manual={'device',function(id) return quickApp:lastManual(id) end,'value',nil,true}
  getProps.start={'device',function(id) return fibaro.scene("execute",{id}) end,"",mapF,false}
  getProps.kill={'device',function(id) return fibaro.scene("kill",{id}) end,"",mapF,false}
  getProps.toggle={'device',toggle,'value',mapF,true}
  getProps.wake={'device',call,'wakeUpDeadDevice',mapF,true}
  getProps.removeSchedule={'device',call,'removeSchedule',mapF,true}
  getProps.retryScheduleSynchronization={'device',call,'retryScheduleSynchronization',mapF,true}
  getProps.setAllSchedules={'device',call,'setAllSchedules',mapF,true}
  getProps.levelIncrease={'device',call,'startLevelIncrease',mapF,nil}
  getProps.levelDecrease={'device',call,'startLevelDecrease',mapF,nil}
  getProps.levelStop={'device',call,'stopLevelChange',mapF,nil}
  getProps.type={'device',function(id) return ER.getDeviceInfo(id).type end,'type',mapF,nil}
  
  
  -- setProps helpers
  local function set(id,cmd,val) fibaro.call(id,cmd,val); return val end
  local function set2(id,cmd,val)
    assert(type(val)=='table' and #val>=3,"setColor expects a table with >=3 values")
    fibaro.call(id,cmd,table.unpack(val)); 
    return val 
  end
  local function setProfile(id,_,val) if val then fibaro.profile("activateProfile",id) end return val end
  local function setState(id,_,val) fibaro.call(id,"updateProperty","state",val); return val end
  local function setProp(id,cmd,val) fibaro.call(id,"updateProperty",cmd,val); return val end
  local function dim2(id,_,val) ER.utilities.dimLight(id,table.unpack(val)) end
  local function pushMsg(id,cmd,val) fibaro.alert(fibaro._pushMethod,{id},val); return val end
  local function setAlarm(id,cmd,val) arm(id,val and 'arm' or 'disarm') return val end
  --helpers.set, helpers.set2, helpers.setProfile, helpers.setState, helpers.setProps, helpers.dim2, helpers.pushMsg = set, set2, setProfile, setState, setProps, dim2, pushMsg
  
  setProps = {}
  setProps.R={set,'setR'} -- Don't think the RGBs are valid anymore...
  setProps.G={set,'setG'}
  setProps.B={set,'setB'}
  setProps.W={set,'setW'}
  setProps.value={set,'setValue'}
  setProps.state={setState,'setState'}
  setProps.prop={function(id,_,val) fibaro.call(id,"updateProperty",table.unpack(val)) end,'upDateProp'}
  
  setProps.armed={setAlarm,'setAlarm'}
  
  setProps.profile={setProfile,'setProfile'}
  setProps.time={set,'setTime'}
  setProps.power={set,'setPower'}
  setProps.targetLevel={set,'setTargetLevel'}
  setProps.interval={set,'setInterval'}
  setProps.mode={set,'setMode'}
  setProps.setpointMode={set,'setSetpointMode'}
  setProps.defaultPartyTime={set,'setDefaultPartyTime'}
  setProps.scheduleState={set,'setScheduleState'}
  setProps.color={set2,'setColor'}
  setProps.volume={set,'setVolume'}
  setProps.position={set,'setPosition'}
  setProps.positions={setProp,'availablePositions'}
  setProps.mute={set,'setMute'}
  setProps.thermostatSetpoint={set2,'setThermostatSetpoint'}
  setProps.thermostatMode={set,'setThermostatMode'}
  setProps.heatingThermostatSetpoint={set,'setHeatingThermostatSetpoint'}
  setProps.coolingThermostatSetpoint={set,'setCoolingThermostatSetpoint'}
  setProps.thermostatFanMode={set,'setThermostatFanMode'}
  setProps.schedule={set2,'setSchedule'}
  setProps.dim={dim2,'dim'}
  fibaro._pushMethod = 'push'
  setProps.msg={pushMsg,"push"}
  setProps.defemail={set,'sendDefinedEmailNotification'}
  setProps.btn={set,'pressButton'} -- ToDo: click button on QA?
  setProps.email={function(id,_,val) local _,_ = val:match("(.-):(.*)"); fibaro.alert('email',{id},val) return val end,""}
  setProps.start={function(id,_,val) 
    if type(val)=='table' and val.type then 
      ER.sourceTrigger:postRemote(id,val) return true
    else 
      fibaro.scene("execute",{id}) return true
    end
  end,""}
  setProps.simKey={function(id,_,val) 
    if type(val) ~= 'table' or not val.keyId or not val.keyAttribute then error("simKey expects a table with keyId and keyAttribute") end
    ER.sourceTrigger:post({type='device', id=id, property='centralSceneEvent', value={keyId=val.keyId,keyAttribute=val.keyAttribute}})
    return val
  end,""}
  
  ER.getProps = getProps
  ER.setProps = setProps
end

local function getProp(obj, key)
  local gf = getProps[key]
  assert(gf, "no such property :"..tostring(key).." (get)")
  if type(obj) == 'table' then
    local fun, prop = gf[2], gf[3]
    local reduce = gf[4] or table.map
    return reduce(function(e) return fun(e, prop) end, obj)
  end
  return gf[2](obj, gf[3])
end

local function setProp(obj, key, value)
  if type(obj) == "table" then
    for _,obj in ipairs(obj) do
      setProp(obj, key, value)
    end
    return true
  end
  local sf = setProps[key]
  assert(sf, "no such property :"..tostring(key).." (set)")
  sf[1](obj, sf[2], value)
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
  
  function builtin.subscribe(event) end
  function builtin.publish(event) end
  function builtin.remote(deviceId,event) end
  function builtin.adde(t,v) table.insert(t,v) return t end
  function builtin.remove(t,v) 
    for i=#t,1,-1 do if t[i]==v then table.remove(t,i) end end 
    return t
  end
  
  function builtin.enable(rule) end
  function builtin.disable(rule) end
  
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

ER.setupProps = setupProps
ER.setupFuns = setupFuns
ER.getProp = getProp
ER.setProp = setProp