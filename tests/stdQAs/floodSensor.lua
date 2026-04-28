--%%name:FloodSensor
--%%type:com.fibaro.floodSensor
--%%description:"Flood sensor template"
--%%desktop:true

-- Flood sensor type have no actions to handle
-- To update flood sensor state, update property "value" with boolean
-- Eg. self:updateProperty("value", true) will indicate that flood was detected 
class "Sim_floodSensor"(SimQuickApp)
local QuickApp = Sim_floodSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_floodSensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end 

function QuickApp:breached(state)
    self:debug("flood sensor breached: " .. tostring(state))
    self:updateProperty("value", state)
end