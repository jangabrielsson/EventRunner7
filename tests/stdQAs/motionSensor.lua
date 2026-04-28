--%%name:MotionSensor
--%%type:com.fibaro.motionSensor
--%%description:"My description"
--%%desktop:true

class "Sim_motionSensor"(SimQuickApp)
local QuickApp = Sim_motionSensor
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_motionSensor:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end

-- Motion sensor type has no actions to handle
-- To update motion sensor state, update property "value" with boolean
-- Eg. self:updateProperty("value", true) will indicate that motion was detected 