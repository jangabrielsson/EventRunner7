--%%name:ThermostatSetpoint
--%%type:com.fibaro.thermostatSetpoint
--%%description:"Thermostat setpoint template"
--%%desktop:true
class "Sim_thermostatSetpoint"(SimQuickApp)
local QuickApp = Sim_thermostatSetpoint
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_thermostatSetpoint:"..id end

-- Thermostat setpoint should handle actions: setHeatingThermostatSetpoint, setCoolingThermostatSetpoint
-- Properties that should be updated:
-- * heatingThermostatSetpoint - set point for heating, supported units: "C" - Celsius, "F" - Fahrenheit
-- * coolingThermostatSetpoint - set point for cooling, supported units: "C" - Celsius, "F" - Fahrenheit
-- * temperature - current temperature, supported units: "C" - Celsius, "F" - Fahrenheit

-- handle action for setting set point for heating
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", { value= value, unit= "C" })
end

-- handle action for setting set point for cooling
function QuickApp:setCoolingThermostatSetpoint(value) 
    self:updateProperty("coolingThermostatSetpoint", { value= value, unit= "C" })
end

-- Update current temperature
function QuickApp:updateTemperature(value)
    self:updateProperty("temperature", { value= value, unit= "C" })
end

function QuickApp:onInit()
    self:debug(self.name,self.id)

    -- setup default values
    self:setHeatingThermostatSetpoint(21)
    self:setCoolingThermostatSetpoint(23)
    self:updateTemperature(22)
end 