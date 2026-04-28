--%%name:WaterLeakSensor
--%%type:com.fibaro.waterLeakSensor
--%%description:"My description"
--%%desktop:true
class "Sim_waterLeakSensor"(SimQuickApp)
local QuickApp = Sim_waterLeakSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_waterLeakSensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end 