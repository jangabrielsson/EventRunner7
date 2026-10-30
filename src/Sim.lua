--[[
Provides fake devices to test ER with
--]]

fibaro.debugFlags = fibaro.debugFlags or {} 
fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
local debugFlags = fibaro.debugFlags

SimQuickApp = {}
class "SimQuickApp"
function SimQuickApp:__init(id)
  self.id = id
  self.props = {}
end
function SimQuickApp:updateProperty(prop, value)
  local old = self.props[prop]
  self.props[prop] = value
  if old ~= value then
    ER.sourceTrigger:post({type='device', id=self.id, property=prop, value=value})
  end
end
function SimQuickApp:setValue(value) self:updateProperty('value', value) end
function SimQuickApp:debug(...)
  fibaro.debug(self.tag,...)
end


ER.simDevices = ER.simDevices or {}
local simDevices = ER.simDevices
local loadedDeviceClasses = {}
local loadedDevices = {}
local idCounter = 10000

local oldCall,oldGet = fibaro.call,fibaro.get
local oldGetGV, oldSetGV = fibaro.getGlobalVariable, fibaro.setGlobalVariable
local old__fibaro_get_global_variable = __fibaro_get_global_variable

fibaro.get = function(id, prop)
  if loadedDevices[id] then
    return loadedDevices[id].props[prop],os.time()
  else
    return oldGet(id, prop)
  end
end
fibaro.call = function(id, action, ...)
  if loadedDevices[id] then
    local device = loadedDevices[id]
    if type(device[action]) == 'function' then
      return device[action](device, ...)
    else
      error("Device "..id.." does not have action "..action)
    end
  else
    return oldCall(id, action, ...)
  end
end

local simGVs = {}
function ER.defineSimGlobalVariable(name, initialValue)
  simGVs[name] = {value = initialValue, modified = os.time()}
end
function fibaro.getGlobalVariable(name)
  if simGVs[name] ~= nil then return simGVs[name].value, simGVs[name].modified end
  return oldGetGV(name)
end
function __fibaro_get_global_variable(name)  
  return simGVs[name] or old__fibaro_get_global_variable(name) 
end
function fibaro.setGlobalVariable(name, value) 
  assert(type(value) == 'string', "Global variable name must be a string")
  if simGVs[name] ~= nil then 
    if simGVs[name].value ~= value then
      simGVs[name].value = value
      simGVs[name].modified = os.time()
      ER.sourceTrigger:post({type='global-variable', name=name, value=value})
    end
    return value
  end
  return oldSetGV(name, value)
end

function ER.loadSimDevice(name,id)
  if not id then id = idCounter idCounter = idCounter + 1 end
  if not loadedDeviceClasses[name] then
    if io and not _G["Sim_"..name] then
      loadedDeviceClasses[name] = true
      local f = io.open("tests/stdQAs/"..name..".lua", "r")
      if f then
        local code = f:read("*a")
        load(code, "@"..name..".lua", "t", _G)()
        f:close()
      end
    end
  end
  local device = _G["Sim_"..name](id)
  loadedDevices[id] = device
  simDevices[id] = device
  assert(device, "Failed to load device "..name)
  return device.id
end

-- Load a standalone QuickApp file as a device in the emulator.
-- flua's replacement for plua's fibaro.plua.lib.loadQAString device loading:
-- the file is installed and booted as a real QA (its own --%% header is
-- parsed, --%%mode:offline keeps it on the simulated HC3) and its device id
-- is returned. The QA must be self-contained — flua runs each QA in its
-- own Lua environment, so it cannot see this QA's globals.
function ER.loadDevice(path)
  local qaId, err = _FLUA.loadQAfromFile(path, {"mode:offline"})
  assert(qaId, err)
  simDevices[qaId] = true
  return qaId
end
