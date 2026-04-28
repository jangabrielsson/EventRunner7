--%%name:HumiditySensor
--%%type:com.fibaro.humiditySensor
--%%description:"My description"
--%%desktop:true
class "Sim_humiditySensor"(SimQuickApp)
local QuickApp = Sim_humiditySensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_humiditySensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end

-- Humidity sensor type have no actions to handle
-- To update humidity, update property "value" with floating point number
-- Eg. self:updateProperty("value", 90.28) 