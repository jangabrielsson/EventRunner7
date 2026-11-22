--%%name:HVACSystemCool
--%%type:com.fibaro.hvacSystemCool
--%%description:"HVAC system cool template"
--%%desktop:true

-- Thermostat cool should handle actions: setThermostatMode, setCoolingThermostatSetpoint
-- Properties that should be updated:
-- * supportedThermostatModes - array of modes supported by the thermostat eg. {"Off", "Cool"}
-- * thermostatMode - current mode of the thermostat
-- * coolingThermostatSetpoint - set point for cooling, supported units: "C" - Celsius, "F" - Fahrenheit

-- handle action for mode change 
class "Sim_hvacSystemCool"(SimQuickApp)
local QuickApp = Sim_hvacSystemCool
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_hvacSystemCool:"..id end

function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end

-- handle action for setting set point for cooling
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end

function QuickApp:onInit()
    self:debug(self.name,self.id)

    -- set supported modes for thermostat
    self:updateProperty("supportedThermostatModes", {"Off", "Cool"})

    -- setup default values
    self:updateProperty("thermostatMode", "Cool")
    self:setCoolingThermostatSetpoint(23)
end 