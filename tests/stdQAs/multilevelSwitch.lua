--%%name:MultilevelSwitch
--%%type:com.fibaro.multilevelSwitch
--%%description:"Multilevel switch template"
--%%desktop:true

-- Multilevel switch type should handle actions: turnOn, turnOff, setValue
-- To update multilevel switch state, update property "value" with integer 0-99
class "Sim_multilevelSwitch"(SimQuickApp)
local QuickApp = Sim_multilevelSwitch
function QuickApp:__init(id) SimQuickApp.__init(self, id) self.tag="Sim_multilevelSwitch:"..id end

function QuickApp:turnOn()
    self:debug("multilevel switch turned on")
    self:updateProperty("value", 99)
end

function QuickApp:turnOff()
    self:debug("multilevel switch turned off")
    self:updateProperty("value", 0)    
end

-- Value is type of integer (0-99)
function QuickApp:setValue(value)
    self:debug("multilevel switch set to: " .. tostring(value))
    self:updateProperty("value", value)    
end

function QuickApp:onInit()
    self:debug(self.name,self.id)
end 