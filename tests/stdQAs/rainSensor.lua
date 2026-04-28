--%%name:RainSensor
--%%type:com.fibaro.rainSensor
--%%description:"My description"
--%%desktop:true
class "Sim_rainSensor"(SimQuickApp)
local QuickApp = Sim_rainSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_rainSensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end

function QuickApp:updateRainValue(value)
    self:setVariable("value",value)
end
