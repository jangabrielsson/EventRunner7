--%%name:TemperatureSensor
--%%type:com.fibaro.temperatureSensor
--%%description:"My description"
--%%desktop:true
class "Sim_temperatureSensor"(SimQuickApp)
local QuickApp = Sim_temperatureSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_temperatureSensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end

-- Temperature sensor type have no actions to handle
-- To update temperature, update property "value" with floating point number, supported units: "C" - Celsius, "F" - Fahrenheit
-- Eg. self:updateProperty("value", { value= 18.12, unit= "C" }) 