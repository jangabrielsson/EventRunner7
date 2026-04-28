--%%name:EnergyMeter
--%%type:com.fibaro.energyMeter
--%%description:"My description"
--%%desktop:true
class "Sim_energyMeter"(SimQuickApp)
local QuickApp = Sim_energyMeter
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_energyMeter:"..id end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end

-- Energy meter type have no actions to handle
-- To update energy consumption, update property "value" with appropriate floating point number
-- Reported value must be in kWh
-- Eg. 
-- self:updateProperty("value", 226.137) 

function QuickApp:updateEnergy(value)
    self:debug("energy meter update: " .. tostring(value))
    self:updateProperty("value", value)
end