--%%name:CODetector
--%%type:com.fibaro.coDetector
--%%description:"My description"
--%%desktop:true
class "Sim_coDetector"(SimQuickApp)
local QuickApp = Sim_coDetector
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_coDetector:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end

-- Carbon monoxide detector type has no actions to handle
-- To update carbon monoxide detector state, update property "value" with boolean
-- Eg. self:updateProperty("value", true) will indicate that carbon monoxide was detected 

function QuickApp:breached(state)
    self:debug("carbon monoxide detector breached: " .. tostring(state))
    self:updateProperty("value", state)
end