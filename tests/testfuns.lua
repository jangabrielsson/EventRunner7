fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
ER.onInitHooks = ER.onInitHooks or {}
local er

local function test(str,tr,val) 
  local r = er.eval(str,{verbosity="silent"})
  r.onDone = function(...) 
    local v = {...}
    if table.equal(v,val) then
      print("✅ ",str)
    else
      print("❌ ",str," expected ",val," got ",v)
    end
  end
  if tr then er.eval(tr,{verbosity="silent"}) end
end



table.insert(ER.onInitHooks,function(_er) 
  er = _er 
  er.test = test
end)