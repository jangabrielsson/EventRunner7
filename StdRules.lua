MODULE = MODULE or {}

local function setup(er)
   -- print("HELLO")
end

MODULE[#MODULE+1] = {name="StdRules", prio=1000,code=setup}