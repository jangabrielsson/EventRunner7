--%%name:HVACSystemHeat
--%%type:com.fibaro.hvacSystemHeat
--%%description:"HVAC system heat template"
--%%desktop:true

-- Thermostat heat should handle actions: setThermostatMode, setHeatingThermostatSetpoint
-- Properties that should be updated:
-- * supportedThermostatModes - array of modes supported by the thermostat eg. {"Off", "Heat"}
-- * thermostatMode - current mode of the thermostat
-- * heatingThermostatSetpoint - set point for heating, supported units: "C" - Celsius, "F" - Fahrenheit

-- handle action for mode change 
class "Sim_hvacSystemHeat"(SimQuickApp)
local QuickApp = Sim_hvacSystemHeat
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_hvacSystemHeat:"..id end

function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)
end

-- handle action for setting set point for heating
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end

function QuickApp:onInit()
    self:debug(self.name,self.id)

    -- set supported modes for thermostat
    self:updateProperty("supportedThermostatModes", {"Off", "Heat"})

    -- setup default values
    self:updateProperty("thermostatMode", "Heat")
    self:setHeatingThermostatSetpoint(21)
end 