--%%name:LightSensor
--%%type:com.fibaro.lightSensor
--%%description:"My description"
--%%desktop:true
class "Sim_lightSensor"(SimQuickApp)
local QuickApp = Sim_lightSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_lightSensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end 