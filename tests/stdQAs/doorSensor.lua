--%%name:DoorSensor
--%%type:com.fibaro.doorSensor
--%%description:"My description"
--%%desktop:true

-- Door sensor type have no actions to handle
-- To update door sensor state, update property "value" with boolean
-- Eg. self:updateProperty("value", true) will set sensor to breached state 
class "Sim_doorSensor"(SimQuickApp)
local QuickApp = Sim_doorSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_doorSensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end

function QuickApp:breached(state)
    self:debug("door sensor breached: " .. tostring(state))
    self:updateProperty("value", state)
end