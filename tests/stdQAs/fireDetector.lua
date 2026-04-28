--%%name:FireDetector
--%%type:com.fibaro.fireDetector
--%%description:"My description"
--%%desktop:true

-- Fire detector type has no actions to handle
-- To update fire detector state, update property "value" with boolean
-- Eg. self:updateProperty("value", true) will indicate that fire was detected 
class "Sim_fireDetector"(SimQuickApp)
local QuickApp = Sim_fireDetector
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_fireDetector:"..id end
function QuickApp:onInit()
    self:debug(self.name,self.id)
end

function QuickApp:breached(state)
    self:debug("fire detector breached: " .. tostring(state))
    self:updateProperty("value", state)
end