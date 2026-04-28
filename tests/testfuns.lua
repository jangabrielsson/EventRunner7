fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
ER.onInitHooks = ER.onInitHooks or {}
local er

local function test(str,tr,val) 
  local r = er.eval(str)
  r.onDone = function(v) 
    if v == val then
      print("Test passed: ",str)
    else
      print("Test failed: ",str," expected ",val," got ",v)
    end
  end
  er.eval(tr)
end



table.insert(ER.onInitHooks,function(_er) 
  er = _er 
  er.test = test
end)