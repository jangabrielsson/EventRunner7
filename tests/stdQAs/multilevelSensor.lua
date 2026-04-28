--%%name:MultilevelSensor
--%%type:com.fibaro.multilevelSensor
--%%description:"My description"
--%%desktop:true

-- Multilevel sensor type have no actions to handle
-- To update multilevel sensor state, update property "value" with integer
-- Eg. self:updateProperty("value", 37.21) 

-- To set unit of the sensor, update property "unit". You can set it on QuickApp initialization
-- Eg. 
-- function QuickApp:onInit()
--     self:updateProperty("unit", "KB")
-- end 

class "Sim_multilevelSensor"(SimQuickApp)
local QuickApp = Sim_multilevelSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_multilevelSensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end 