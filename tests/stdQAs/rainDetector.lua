--%%name:RainDetector
--%%type:com.fibaro.rainDetector
--%%description:My description
--%%desktop:true

-- Rain detector type has no actions to handle
-- To update rain detector state, update property "value" with boolean
-- Eg. self:updateProperty("value", true) will indicate that rain was detected 
class "Sim_rainDetector"(SimQuickApp)
local QuickApp = Sim_rainDetector
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_rainDetector:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end

function QuickApp:breached(state)
    self:debug("rain detector breached: " .. tostring(state))
    self:updateProperty("value", state)
end