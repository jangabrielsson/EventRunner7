--%%name:WindowCovering
--%%type:com.fibaro.windowCovering
--%%description:"My description"

class "Sim_windowCovering"(SimQuickApp)
local QuickApp = Sim_windowCovering
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_windowCovering:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end 