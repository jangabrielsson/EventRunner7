-- BEGIN: alarmPartition.lua
do
class "Sim_alarmPartition"(SimQuickApp)
local QuickApp = Sim_alarmPartition
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_alarmPartition:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:arm()
    self:debug("alarm partition armed")
    self:updateProperty("armed", true)
end
function QuickApp:disarm()
    self:debug("alarm partition disarmed")
    self:updateProperty("armed", false)    
end 
function QuickApp:breached(state)
    self:debug("alarm partition breached: " .. tostring(state))
    self:updateProperty("alarm", state)    
end 
end
-- END: alarmPartition.lua

-- BEGIN: binarySensor.lua
do
class "Sim_binarySensor"(SimQuickApp)
local QuickApp = Sim_binarySensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_binarySensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:breached(state)
    self:debug("binary sensor breached: " .. tostring(state))
    self:updateProperty("value", state)
end
end
-- END: binarySensor.lua

-- BEGIN: binarySwitch.lua
do
class "Sim_binarySwitch"(SimQuickApp)
local QuickApp = Sim_binarySwitch
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_binarySwitch:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:turnOn()
    self:debug("binary switch turned on")
    self:updateProperty("value", true)
end
function QuickApp:turnOff()
    self:debug("binary switch turned off")
    self:updateProperty("value", false)    
end 
end
-- END: binarySwitch.lua

-- BEGIN: coDetector.lua
do
class "Sim_coDetector"(SimQuickApp)
local QuickApp = Sim_coDetector
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_coDetector:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:breached(state)
    self:debug("carbon monoxide detector breached: " .. tostring(state))
    self:updateProperty("value", state)
end
end
-- END: coDetector.lua

-- BEGIN: colorController.lua
do
class "Sim_colorController"(SimQuickApp)
local QuickApp = Sim_colorController
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_colorController:"..id end
function QuickApp:turnOn()
    self:debug("color controller turned on")
    self:updateProperty("value", 99)
end
function QuickApp:turnOff()
    self:debug("color controller turned off")
    self:updateProperty("value", 0)    
end
function QuickApp:setValue(value)
    self:debug("color controller value set to: ", value)
    self:updateProperty("value", value)    
end
function QuickApp:setColor(r,g,b,w)
    local color = string.format("%d,%d,%d,%d", r or 0, g or 0, b or 0, w or 0) 
    self:debug("color controller color set to: ", color)
    self:updateProperty("color", color)
    self:setColorComponents({red=r, green=g, blue=b, white=w})
end
function QuickApp:setColorComponents(colorComponents)
    local cc = self.properties.colorComponents
    local isColorChanged = false
    for k,v in pairs(colorComponents) do
        if cc[k] and cc[k] ~= v then
            cc[k] = v
            isColorChanged = true
        end
    end
    if isColorChanged == true then
        self:updateProperty("colorComponents", cc)
        self:setColor(cc["red"], cc["green"], cc["blue"], cc["white"])
    end
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:updateProperty("colorComponents", {red=0, green=0, blue=0, warmWhite=0})
end 
end
-- END: colorController.lua

-- BEGIN: deviceController.lua
do
class "Sim_deviceController"(SimQuickApp)
local QuickApp = Sim_deviceController
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_deviceController:"..id end
MyBinarySwitch = {}
class 'MyBinarySwitch'(QuickAppChild)
function MyBinarySwitch:__init(device)
    QuickAppChild.__init(self, device) 
    self:debug("MyBinarySwitch init")   
end
function MyBinarySwitch:turnOn()
    self:debug("child", self.id, "turned on")
    self:updateProperty("value", true)
end
function MyBinarySwitch:turnOff()
    self:debug("child", self.id, "turned off")
    self:updateProperty("value", false)
end 
function QuickApp:onInit()
    self:debug("QuickApp:onInit")
    self:initChildDevices({
        ["com.fibaro.binarySwitch"] = MyBinarySwitch,
    })
    self:debug("Child devices:")
    for id,device in pairs(self.childDevices) do
        self:debug("[", id, "]", device.name, ", type of: ", device.type)
    end
end
function QuickApp:createChild()
    local child = self:createChildDevice({
        name = "child",
        type = "com.fibaro.binarySwitch",
    }, MyBinarySwitch)
    self:trace("Child device created: ", child.id)
end

end
-- END: deviceController.lua

-- BEGIN: doorSensor.lua
do
class "Sim_doorSensor"(SimQuickApp)
local QuickApp = Sim_doorSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_doorSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:breached(state)
    self:debug("door sensor breached: " .. tostring(state))
    self:updateProperty("value", state)
end
end
-- END: doorSensor.lua

-- BEGIN: energyMeter.lua
do
class "Sim_energyMeter"(SimQuickApp)
local QuickApp = Sim_energyMeter
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_energyMeter:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:updateEnergy(value)
    self:debug("energy meter update: " .. tostring(value))
    self:updateProperty("value", value)
end
end
-- END: energyMeter.lua

-- BEGIN: fireDetector.lua
do
class "Sim_fireDetector"(SimQuickApp)
local QuickApp = Sim_fireDetector
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_fireDetector:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:breached(state)
    self:debug("fire detector breached: " .. tostring(state))
    self:updateProperty("value", state)
end
end
-- END: fireDetector.lua

-- BEGIN: floodSensor.lua
do
class "Sim_floodSensor"(SimQuickApp)
local QuickApp = Sim_floodSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_floodSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end 
function QuickApp:breached(state)
    self:debug("flood sensor breached: " .. tostring(state))
    self:updateProperty("value", state)
end
end
-- END: floodSensor.lua

-- BEGIN: genericDevice.lua
do
class "Sim_genericDevice"(SimQuickApp)
local QuickApp = Sim_genericDevice
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_genericDevice:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end 
end
-- END: genericDevice.lua

-- BEGIN: heatDetector.lua
do
class "Sim_heatDetector"(SimQuickApp)
local QuickApp = Sim_heatDetector
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_heatDetector:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:breached(state)
    self:debug("heat detector breached: " .. tostring(state))
    self:updateProperty("value", state)
end
end
-- END: heatDetector.lua

-- BEGIN: humiditySensor.lua
do
class "Sim_humiditySensor"(SimQuickApp)
local QuickApp = Sim_humiditySensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_humiditySensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end

end
-- END: humiditySensor.lua

-- BEGIN: hvacSystemAuto.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:updateProperty("supportedThermostatModes", {"Auto", "Off", "Heat", "Cool"})
    self:updateProperty("thermostatMode", "Auto")
    self:setCoolingThermostatSetpoint(23)
    self:setHeatingThermostatSetpoint(20)
end

end
-- END: hvacSystemAuto.lua

-- BEGIN: hvacSystemCool.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:updateProperty("supportedThermostatModes", {"Off", "Cool"})
    self:updateProperty("thermostatMode", "Cool")
    self:setCoolingThermostatSetpoint(23)
end 
end
-- END: hvacSystemCool.lua

-- BEGIN: hvacSystemHeat.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:updateProperty("supportedThermostatModes", {"Off", "Heat"})
    self:updateProperty("thermostatMode", "Heat")
    self:setHeatingThermostatSetpoint(21)
end 
end
-- END: hvacSystemHeat.lua

-- BEGIN: hvacSystemHeatCool.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:updateProperty("supportedThermostatModes", {"Off", "Heat", "Cool", "Auto"})
    self:updateProperty("thermostatMode", "Auto")
    self:setHeatingThermostatSetpoint(21)
    self:setCoolingThermostatSetpoint(23)
end 
end
-- END: hvacSystemHeatCool.lua

-- BEGIN: lightSensor.lua
do
class "Sim_lightSensor"(SimQuickApp)
local QuickApp = Sim_lightSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_lightSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end 
end
-- END: lightSensor.lua

-- BEGIN: motionSensor.lua
do
class "Sim_motionSensor"(SimQuickApp)
local QuickApp = Sim_motionSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_motionSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end

end
-- END: motionSensor.lua

-- BEGIN: multilevelSensor.lua
do
class "Sim_multilevelSensor"(SimQuickApp)
local QuickApp = Sim_multilevelSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_multilevelSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end 
end
-- END: multilevelSensor.lua

-- BEGIN: multilevelSwitch.lua
do
class "Sim_multilevelSwitch"(SimQuickApp)
local QuickApp = Sim_multilevelSwitch
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_multilevelSwitch:"..id end
function QuickApp:turnOn()
    self:debug("multilevel switch turned on")
    self:updateProperty("value", 99)
end
function QuickApp:turnOff()
    self:debug("multilevel switch turned off")
    self:updateProperty("value", 0)    
end
function QuickApp:setValue(value)
    self:debug("multilevel switch set to: " .. tostring(value))
    self:updateProperty("value", value)    
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end 
end
-- END: multilevelSwitch.lua

-- BEGIN: player.lua
do
class "Sim_player"(SimQuickApp)
local QuickApp = Sim_player
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_player:"..id end
function QuickApp:play()
    self:debug("handle play")
end
function QuickApp:pause()
    self:debug("handle pause")
end
function QuickApp:stop()
    self:debug("handle stop")
end
function QuickApp:next()
    self:debug("handle next")
end
function QuickApp:prev()
    self:debug("handle prev")
end
function QuickApp:setVolume(volume)
    self:debug("setting volume to:", volume)
    self:updateProperty("volume", volume)
end
function QuickApp:setMute(mute)
    if mute == 0 then 
        self:debug("setting mute to:", false)
        self:updateProperty("mute", false)
    else
        self:debug("setting mute to:", true)
        self:updateProperty("mute", true)
    end
end 
function QuickApp:onInit()
    self:debug(self.name,self.id)
end

end
-- END: player.lua

-- BEGIN: powerMeter.lua
do
class "Sim_powerMeter"(SimQuickApp)
local QuickApp = Sim_powerMeter
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_powerMeter:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:updateValue(value)
    self:debug("power meter update value: " .. tostring(value))
    self:updateProperty("value", value)
end
function QuickApp:updateRateType(rateType)
    self:debug("power meter update rate type: " .. tostring(rateType))
    self:updateProperty("rateType", rateType)
end
end
-- END: powerMeter.lua

-- BEGIN: rainDetector.lua
do
class "Sim_rainDetector"(SimQuickApp)
local QuickApp = Sim_rainDetector
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_rainDetector:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:breached(state)
    self:debug("rain detector breached: " .. tostring(state))
    self:updateProperty("value", state)
end
end
-- END: rainDetector.lua

-- BEGIN: rainSensor.lua
do
class "Sim_rainSensor"(SimQuickApp)
local QuickApp = Sim_rainSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_rainSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:updateRainValue(value)
    self:setVariable("value",value)
end

end
-- END: rainSensor.lua

-- BEGIN: remoteController.lua
do
class "Sim_remoteController"(SimQuickApp)
local QuickApp = Sim_remoteController
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_remoteController:"..id end
function QuickApp:emitCentralSceneEvent(keyId, keyAttribute)
    if keyAttribute == nil then
        keyAttribute = "Pressed"
    end
    local eventData = {
        type = "centralSceneEvent",
        source = self.id,
        data = {
            keyAttribute = keyAttribute,
            keyId = keyId
        }
    }
    api.post("/plugins/publishEvent", eventData)
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:updateProperty("centralSceneSupport",  {
        { keyAttributes = { "Pressed","Released","HeldDown","Pressed2","Pressed3" }, keyId = 1 },
        { keyAttributes = { "Pressed","Released","HeldDown","Pressed2","Pressed3" }, keyId = 2 },
        { keyAttributes = { "Pressed","Released","HeldDown","Pressed2","Pressed3" }, keyId = 3 },
        { keyAttributes = { "Pressed","Released","HeldDown","Pressed2","Pressed3" }, keyId = 4 },
        { keyAttributes = { "Pressed","Released","HeldDown","Pressed2","Pressed3" }, keyId = 5 },
        { keyAttributes = { "Pressed","Released","HeldDown","Pressed2","Pressed3" }, keyId = 6 },
    })
end 
end
-- END: remoteController.lua

-- BEGIN: smokeSensor.lua
do
class "Sim_smokeSensor"(SimQuickApp)
local QuickApp = Sim_smokeSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_smokeSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
end
-- END: smokeSensor.lua

-- BEGIN: temperatureSensor.lua
do
class "Sim_temperatureSensor"(SimQuickApp)
local QuickApp = Sim_temperatureSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_temperatureSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end

end
-- END: temperatureSensor.lua

-- BEGIN: thermostat.lua
do
class "Sim_thermostat"(SimQuickApp)
local QuickApp = Sim_thermostat
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_thermostat:"..id end
function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:updateTemperature(value)
    self:updateProperty("temperature", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:updateProperty("supportedThermostatModes", {"Off", "Heat", "Cool", "Auto"})
    self:updateProperty("thermostatMode", "Auto")
    self:setHeatingThermostatSetpoint(21)
    self:setCoolingThermostatSetpoint(23)
    self:updateTemperature(22)
end 
end
-- END: thermostat.lua

-- BEGIN: thermostatCool.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:updateTemperature(value)
    self:updateProperty("temperature", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:updateProperty("supportedThermostatModes", {"Off", "Cool"})
    self:updateProperty("thermostatMode", "Cool")
    self:setCoolingThermostatSetpoint(23)
    self:updateTemperature(24)
end 
end
-- END: thermostatCool.lua

-- BEGIN: thermostatHeat.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:updateTemperature(value)
    self:updateProperty("temperature", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:updateProperty("supportedThermostatModes", {"Off", "Heat"})
    self:updateProperty("thermostatMode", "Heat")
    self:setHeatingThermostatSetpoint(21)
    self:updateTemperature(20)
end 
end
-- END: thermostatHeat.lua

-- BEGIN: thermostatHeatCool.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:updateTemperature(value)
    self:updateProperty("temperature", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:updateProperty("supportedThermostatModes", {"Off", "Heat", "Cool", "Auto"})
    self:updateProperty("thermostatMode", "Auto")
    self:setHeatingThermostatSetpoint(21)
    self:setCoolingThermostatSetpoint(23)
    self:updateTemperature(22)
end 
end
-- END: thermostatHeatCool.lua

-- BEGIN: thermostatSetpoint.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:updateTemperature(value)
    self:updateProperty("temperature", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:setHeatingThermostatSetpoint(21)
    self:setCoolingThermostatSetpoint(23)
    self:updateTemperature(22)
end 
end
-- END: thermostatSetpoint.lua

-- BEGIN: thermostatSetpointCool.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:updateTemperature(value)
    self:updateProperty("temperature", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:setCoolingThermostatSetpoint(23)
    self:updateTemperature(24)
end 
end
-- END: thermostatSetpointCool.lua

-- BEGIN: thermostatSetpointHeat.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:updateTemperature(value)
    self:updateProperty("temperature", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:setHeatingThermostatSetpoint(21)
    self:updateTemperature(20)
end 
end
-- END: thermostatSetpointHeat.lua

-- BEGIN: thermostatSetpointHeatCool.lua
do
local QuickApp = fibaro.SimQuickApp or QuickApp
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end
function QuickApp:updateTemperature(value)
    self:updateProperty("temperature", { value= value, unit= "C" })
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
    self:setHeatingThermostatSetpoint(21)
    self:setCoolingThermostatSetpoint(23)
    self:updateTemperature(22)
end 
end
-- END: thermostatSetpointHeatCool.lua

-- BEGIN: waterLeakSensor.lua
do
class "Sim_waterLeakSensor"(SimQuickApp)
local QuickApp = Sim_waterLeakSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_waterLeakSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end 
end
-- END: waterLeakSensor.lua

-- BEGIN: weather.lua
do
class "Sim_weather"(SimQuickApp)
local QuickApp = Sim_weather
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_weather:"..id end
function QuickApp:setCondition(condition)
    local conditionCodes = { 
        unknown = 3200,
        clear = 32,
        rain = 40,
        snow = 38,
        storm = 4,
        cloudy = 30,
        partlyCloudy = 30,
        fog = 20,
    }
    local conditionCode = conditionCodes[condition]
    if conditionCode then
        self:updateProperty("ConditionCode", conditionCode)
        self:updateProperty("WeatherCondition", condition)
    end
end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end 
end
-- END: weather.lua

-- BEGIN: windSensor.lua
do
class "Sim_windSensor"(SimQuickApp)
local QuickApp = Sim_windSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_windSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:updateWind(value)
    self:debug("wind sensor update: " .. tostring(value))
    self:updateProperty("value", value)
end
end
-- END: windSensor.lua

-- BEGIN: windowCovering.lua
do
class "Sim_windowCovering"(SimQuickApp)
local QuickApp = Sim_windowCovering
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_windowCovering:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end 
end
-- END: windowCovering.lua

-- BEGIN: windowSensor.lua
do
class "Sim_windowSensor"(SimQuickApp)
local QuickApp = Sim_windowSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_windowSensor:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end
function QuickApp:breached(state)
    self:debug("window sensor breached: " .. tostring(state))
    self:updateProperty("value", state)
end
end
-- END: windowSensor.lua

