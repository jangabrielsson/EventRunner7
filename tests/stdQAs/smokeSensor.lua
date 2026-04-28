--%%name:SmokeSensor
--%%type:com.fibaro.smokeSensor
--%%description:"My description"
--%%desktop:true

class "Sim_smokeSensor"(SimQuickApp)
local QuickApp = Sim_smokeSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_smokeSensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end