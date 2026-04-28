--%%name:BinarySensor
--%%type:com.fibaro.binarySensor
--%%description:"My description"
--%%desktop:true
class "Sim_binarySensor"(SimQuickApp)
local QuickApp = Sim_binarySensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_binarySensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end

-- Binary sensor type have no actions to handle
-- To update binary sensor state, update property "value" with boolean
-- Eg. self:updateProperty("value", true) will set sensor to breached state 

function QuickApp:breached(state)
    self:debug("binary sensor breached: " .. tostring(state))
    self:updateProperty("value", state)
end