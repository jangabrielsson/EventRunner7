fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
local fmt = string.format

local function get(pd,id)
  return fibaro.get(id, pd.trigger.property)
end

local function set(pd,id,value)
  local prop = pd.trigger and pd.trigger.property
  if pd.setCmd then
     fibaro.call(id, pd.setCmd, value)
  else
     fibaro.call(id,"updateProperty", prop or pd.property, value)
  end
end

local function centralScene(_,id,e)
if e == nil then return {} end
  return e.type=='device' and e.property=='centralSceneEvent'and e.id==id and e.value or {} 
end

local function partition(id) return api.get("/alarms/v1/partitions/" .. id) or {} end

local function armState(id) 
  return id==0 and fibaro.getHomeArmState() or fibaro.getPartitionArmState(id)
end

local function arm(id,action)
  if action=='arm' then 
    local _,res = ER.alarmFuns.armPartition(id); return res == 200
  else
    local _,res = ER.alarmFuns.unarmPartition(id); return res == 200
  end
end

local function setAlarm(_,id,val) arm(id,val and 'arm' or 'disarm') return val end

local function tryArm(id)
  local data,res = ER.alarmFuns.tryArmPartition(id)
  if res ~= 200 then return false end
  if type(data) == 'table' then
    ER.sourceTrigger:post({type='alarm',id=id,action='tryArm',property='delayed',value=data})
  end
  return true
end

local function BN(x) 
  if type(x)=='boolean' then 
    return x and 1 or 0 
  else return tonumber(x) or 0 end 
end

local function GETPROP(name,reduce)
  return {
    trigger = {type='device', property=name},
    get = get,
    reduce = reduce,
  }
end

local function CALL(name,reduce,...)
  local args = {...}
  return {
    get = function(pd,id,_) return fibaro.call(id,name,table.unpack(args)) end,
    reduce = reduce,
  }
end

local keyMT = { __tostring = 
  function(t) 
    return string.format("%s:%s",t.keyId or '',t.keyAttribute or '') 
  end 
}

local propertyTable = {
  value = {
    trigger = {type='device', property='value'},
    set = set, get = get, setCmd = 'setValue',
  },
  bat = {
    trigger = {type='device', property='batteryLevel'},
    get = get,
  },
  isDead = {
    trigger = {type='device', property='dead'},
    get = get,
  },
  state = {
    trigger = {type='device', property='state'},
    set = set, get = get,
  },
  prop = {
    set = function(_, id, value)
      fibaro.call(id, "updateProperty", value[1], value[2])
    end,
  },
  isOn = {
    trigger = {type='device', property='value'},
    get = function(pd,id) return BN(get(pd,id))>0 end
  },
  isOff = {
    trigger = {type='device', property='value'},
    get = function(pd,id) return BN(get(pd,id))==0 end
  },
  isAllOn = {
    trigger = {type='device', property='value'},
    get = "isOn.get",
    reduce = table.mapAnd
  },
  isAnyOff = {
    trigger = {type='device', property='value'},
    get = "isOff.get",
    reduce = table.mapOr
  },
  last = {
    trigger = {type='device', property='value'},
    get = function(pd, id) 
      local _,t=fibaro.get(id,'value')
      return t and os.time()-t or 0
    end
  },
  parent = {
    get = function(pd,id) return api.get("/devices/"..id).parentId end
  },
  profile = {
    set = function(pd,id,val,_) 
      if val then fibaro.profile("activateProfile",id) end return val
    end
  },
  scene = {
    trigger = {type='device', property='sceneActivationEvent'},
    get = function(pd,id,e)
      if e==nil then return nil end 
      return e.type=='device' and e.property=='sceneActivationEvent' and e.id==id and e.value.sceneId or nil
    end
  },
  access = {
    trigger = {type='device', property='accessControlEvent'},
    get = function(pd,id,e)    
      if e == nil then return {} end 
      return e.type=='device' and e.property=='accessControlEvent' and e.id == id and e.value or {} 
    end
  },
  central = {
    trigger = {type='device', property='centralSceneEvent'},
    get = centralScene
  },
  key = {
    trigger = {type='device',  property='centralSceneEvent'},
    get = function(pd,id,e) 
      local se = centralScene(pd,id,e)
      se = se or {} se.id,se.attr = se.keyId,se.keyAttribute 
      return setmetatable(se or {},keyMT) 
    end
  },
  position = {
    trigger={type='device', property='position'},
    get = get, set = set, setCmd = 'setPosition',
  },
  positions = {
    property = 'availablePositions',
    set = set
  },
  volume   = {
    trigger={type='device', property='volume'},
    get = get, set = set, setCmd = 'setVolume',
  },
  mute   = {
    trigger={type='device', property='mute'},
    get = get, set = set, setCmd = 'setMute',
  },
  on       = CALL("turnOn", table.mapF),
  off      = CALL("turnOff", table.mapF),
  play     = CALL("play", table.mapF),
  pause    = CALL("pause", table.mapF),
  open     = CALL("open", table.mapF),
  close    = CALL("close", table.mapF),
  stop     = CALL("stop", table.mapF),
  secure   = CALL("secure", table.mapF),
  unsecure = CALL("unsecure", table.mapF),
  isSecure = {
    trigger = {type='device', property='secured'},
    get = "isOn.get",
    reduce = table.mapAnd,
  },
  isUnsecure = {
    trigger = {type='device', property='secured'},
    get = "isOff.get",
    reduce = table.mapOr,
  },
  name = {
    get = function(pd,id,_) return fibaro.getName(id) end,
  },
  partition = {
    get = function(pd,id,_) return partition(id) end
  },
  HTname = {
    get = function(pd,id,_) return ER.reverseVar(id) end
  },
  roomName = {
    get = function(pd,id,_) return fibaro.getRoomNameByDeviceID(id) end
  },
  trigger = {
    trigger = {type='device', property='value'},
    get = get
  },
  time = {
    trigger = {type='device', property='time'},
    get = get, set = set, setCmd = 'setTime',
  },
  power = {
    trigger = {type='device', property='power'},
    get = get, set = set, setCmd = 'setPower',
  },
  targetLevel = { set = set, setCmd = 'setTargetLevel' },
  interval    = { set = set, setCmd = 'setInterval' },
  mode        = { set = set, setCmd = 'setMode' },
  setpointMode     = { set = set, setCmd = 'setSetpointMode' },
  defaultPartyTime = { set = set, setCmd = 'setDefaultPartyTime' },
  scheduleState    = { set = set, setCmd = 'setScheduleState' },
  manual = {
    trigger = {type='device', property='value'},
    get = function(pd,id,_) return quickApp:lastManual(id) end,
  },
  start = {
    get = function(pd,id,_) return fibaro.scene("execute",{id}) end,
    set = function(pd,id,value) 
      if type(value)=='table' and value.type then 
        ER.sourceTrigger:postRemote(id,value) 
      end
    end
  },
  kill = {
    get = function(pd,id,_) return fibaro.scene("kill",{id}) end
  },
  toggle = {
    get = function(pd,id,_) return fibaro.call(id,"toggle") end,
    reduce = table.mapF,
  },
  wake            = CALL("wakeUpDeadDevice", table.mapF), -- get
  removeSchedule  = CALL("removeSchedule", table.mapF),
  retryScheduleSynchronization 
                  = CALL("retryScheduleSynchronization", table.mapF),
  setAllSchedules = CALL("setAllSchedules", table.mapF),
  levelIncrease   = CALL("startLevelIncrease", table.mapF),
  levelDecrease   = CALL("startLevelDecrease", table.mapF),
  levelStop       = CALL("stopLevelChange", table.mapF),
  type = {
    get = function(pd,id,_) return ER.getDeviceInfo(id).type end,
    reduce = table.mapF,
  },
  dim = {
    trigger = {type='device', property='value'},
    set = function(pd,id,value) ER.dimLight(id,table.unpack(value)) end,
  },
  msg = {
    set = function(pd,id,value) 
      fibaro.alert(fibaro._pushMethod,{id},value)
      return value 
    end,
  },
  defemail = {
    set = set,setCmd = 'sendDefinedEmailNotification'
  },
  email = {
    set = function(pd,id,value) 
      local _,_ = value:match("(.-):(.*)")
      fibaro.alert('email',{id},value) return value
    end,
  },
  simKey = {
    set = function(pd,id,value) 
      if type(value) ~= 'table' or not value.keyId or not value.keyAttribute then error("simKey expects a table with keyId and keyAttribute") end
      ER.sourceTrigger:post({type='device', id=id, property='centralSceneEvent', value={keyId=value.keyId,keyAttribute=value.keyAttribute}})
      return value
    end
  },

  -------------- Alarm -------------------------
  armed = {
    trigger = {type='alarm'},
    get = function(id) return  armState(id)=='armed' end,
    set = setAlarm,
    reduce = table.mapOr
  },
  tryArm={
    trigger = {type='alarm'},
    get = tryArm
  },
  isArmed = {
    trigger = {type='alarm'},
    get = function(id) return partition(id).armed end,
    reduce = table.mapOr
  },
  isAllArmed = {
    trigger = {type='alarm'},
    get = function(id) return partition(id).armed end,
    reduce = table.mapAnd
  },
  isDisarmed = {
    trigger = {type='alarm'},
    get = function(id) return partition(id).armed==false end,
    reduce = table.mapAnd
  },
  isAnyDisarmed = {
    trigger = {type='alarm'},
    get = function(id) return partition(id).armed==false end,
    reduce = table.mapOr
  },
  isAlarmBreached = {
    trigger = {type='alarm'},
    get = function(id) return partition(id).breached end,
    reduce = table.mapOr
  },
  isAlarmSafe = {
    trigger = {type='alarm'},
    get = function(id) return partition(id).breached==false end,
    reduce = table.mapAnd
  },
  isAllAlarmBreached = {
    trigger = {type='alarm'},
    get = function(id) return partition(id).breached end,
    reduce = table.mapAnd
  },
  isAnyAlarmSafe = {
    trigger = {type='alarm'},
    get = function(id) return partition(id).breached==false end,
    reduce = table.mapOr
  },

  ------------  Thermostat-------------------
  coolingThermostatSetpoint = {
    trigger = {type='device', property='coolingThermostatSetpoint'},
    get = get, set = set, setCmd = 'setCoolingThermostatSetpoint',
    reduce = table.mapF,
  },
  coolingThermostatSetpointCapabilitiesMax = 
    GETPROP("coolingThermostatSetpointCapabilitiesMax", table.mapF),
  coolingThermostatSetpointCapabilitiesMin = 
    GETPROP("coolingThermostatSetpointCapabilitiesMin", table.mapF),
  coolingThermostatSetpointFuture = 
    GETPROP("coolingThermostatSetpointFuture", table.mapF),
  coolingThermostatSetpointStep = 
    GETPROP("coolingThermostatSetpointStep", table.mapF),
  heatingThermostatSetpoint = {
    trigger = {type='device', property='heatingThermostatSetpoint'},
    get = get, set = set, setCmd = 'setHeatingThermostatSetpoint',
    reduce = table.mapF,
  },
  heatingThermostatSetpointCapabilitiesMax = 
    GETPROP("heatingThermostatSetpointCapabilitiesMax", table.mapF),
  heatingThermostatSetpointCapabilitiesMin = 
    GETPROP("heatingThermostatSetpointCapabilitiesMin", table.mapF),
  heatingThermostatSetpointFuture = 
    GETPROP("heatingThermostatSetpointFuture", table.mapF),
  heatingThermostatSetpointStep = 
    GETPROP("heatingThermostatSetpointStep", table.mapF),
  thermostatFanMode = {
    trigger = {type='device', property='thermostatFanMode'},
    set = set, get = get, setCmd = 'setThermostatFanMode',
     reduce = table.mapF,
  },
  thermostatFanOff = 
    GETPROP("thermostatFanOff", table.mapF),
  thermostatMode = 
    GETPROP("thermostatMode", table.mapF),
  thermostatModeFuture = 
    GETPROP("thermostatModeFuture", table.mapF),
}

local aliases = {
  isOpen = "isOn",
  isClosed = "isOff",
  breached = "isOn",
  safe = "isOff",
  lux = "value",
  temp = "value",
}

local filters = {}
local function NB(x) if type(x)=='number' then return x~=0 and true or false else return x end end
local function mapAnd(l) for _,v in ipairs(l) do if not NB(v) then return false end end return true end
local function mapOr(l) for _,v in ipairs(l) do if NB(v) then return true end end return false end
function filters.average(list) local s = 0; for _,v in ipairs(list) do s=s+BN(v) end return s/#list end
function filters.sum(list) local s = 0; for _,v in ipairs(list) do s=s+BN(v) end return s end
function filters.allFalse(list) return not mapOr(list) end
function filters.someFalse(list) return not mapAnd(list)  end
function filters.allTrue(list) return mapAnd(list) end
function filters.someTrue(list) return mapOr(list)  end
function filters.mostlyTrue(list) local s = 0; for _,v in ipairs(list) do s=s+(NB(v) and 1 or 0) end return s>#list/2 end
function filters.mostlyFalse(list) local s = 0; for _,v in ipairs(list) do s=s+(NB(v) and 0 or 1) end return s>#list/2 end
function filters.bin(list) local s={}; for _,v in ipairs(list) do s[#s+1]=NB(v) and 1 or 0 end return s end
function filters.id(list,ev) return ev and next(ev) and ev.id or list end -- If we called from rule trigger collector we return whole list
local function collect(t,m)
  if type(t)=='table' then
    for _,v in pairs(t) do collect(v,m) end
  else m[t]=true end
end
function filters.leaf(tree)
  local map,res = {},{}
  collect(tree,map)
  for e,_ in pairs(map) do res[#res+1]=e end
  return res 
end

------------------- User propObject -----------------------
PropObject = {}
class 'PropObject'
function PropObject:__init()
  self._isPropObject = true
  self.__str="PObj:"..tostring({}):match("(%d.*)")
end
function PropObject:hasGetProp(prop) return self.getProp[prop] end
function PropObject:hasSetProp(prop) return self.setProp[prop] end
function PropObject:isTrigger(prop) return self.trigger[prop] end
function PropObject:hasReduce(prop) return self.map[prop] end
function PropObject:_setProp(prop,value)
  local sp = self.setProp[prop]
  if not sp then return nil,"Unknown property: "..tostring(prop) end
  sp(self,prop,value)
  return true
end
function PropObject:_getProp(prop,env)
  local gp = self.getProp[prop]
  if not gp then return nil,"Unknown property: "..tostring(prop) end
  return gp(self,prop)
end
function PropObject:getTrigger(id,prop)
  local t = self.trigger[prop]
  return t and type(t) == "func".."tion" and t(self,id,prop) or type(t) == 'table' and t or nil
end
function PropObject:__tostring() return self.__str end

local function definePropClass(name)
  class(name)(PropObject)
  local cl = _G[name]
  cl.getProp,cl.setProp,cl.trigger,cl.map={},{},{},{}
end

local Props
NumberProp = {}

class 'NumberProp'(PropObject)
function NumberProp:__init(num)  
  PropObject.__init(self) 
  self.id = num 
  self.__str = tostring(self.id)
end
function NumberProp:_getProp(prop, event)
  local gp = self:hasGetProp(prop)
  if not gp then 
    error("Unknown property: "..tostring(prop))
  end
  return gp.get(gp, self.id, event)
end
function NumberProp:_setProp(prop,value, event)
  local sp = self:hasGetProp(prop)
  if not sp then
    error("Unknown property: "..tostring(prop))
  end
  return sp.set(sp, self.id, value, event)
end
function NumberProp:hasReduce(prop) 
  return propertyTable[prop] and propertyTable[prop].reduce
end
function NumberProp:hasGetProp(prop) 
  return propertyTable[prop] and propertyTable[prop]
end
function NumberProp:hasSetProp(prop)
  return propertyTable[prop] and propertyTable[prop]
end
function NumberProp:isTrigger(prop) 
  return propertyTable[prop] and propertyTable[prop].trigger or nil
end
function NumberProp:getTrigger(id, prop)
  local tr = table.copy(self:isTrigger(prop))
  tr.id = self.id
  return tr
end

local numObjects = {}

local function resolvePropObject(obj)
  if type(obj) == 'userdata' and obj._isPropObject then return obj
  elseif type(obj) == 'number' then -- Create a PropObject for this device id, or return the existing one if we've already created it
    local po = numObjects[obj] or NumberProp(obj)
    numObjects[obj] = po
    return po
  else return nil end
end

for prop,def in pairs(propertyTable) do def.property = prop end
for alias,def in pairs(aliases) do 
  propertyTable[alias] = propertyTable[def] 
end

----------------- Exports -----------------------

ER.propFilters = filters
ER.resolvePropObject = resolvePropObject
ER.PropObject = PropObject
ER.definePropClass = definePropClass