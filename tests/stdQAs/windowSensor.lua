--%%name:WindowSensor
--%%type:com.fibaro.windowSensor
--%%description:"My description"
-- Window sensor type have no actions to handle
-- To update window sensor state, update property "value" with boolean
-- Eg. self:updateProperty("value", true) will set sensor to breached state 
class "Sim_windowSensor"(SimQuickApp)
local QuickApp = Sim_windowSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_windowSensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end

function QuickApp:breached(state)
    self:debug("window sensor breached: " .. tostring(state))
    self:updateProperty("value", state)
end