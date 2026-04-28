--%%name:GenericDevice
--%%type:com.fibaro.genericDevice
--%%description:"My description"
--%%desktop:true

-- Generic device type have no default actions to handle 
class "Sim_genericDevice"(SimQuickApp)
local QuickApp = Sim_genericDevice
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_genericDevice:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end 