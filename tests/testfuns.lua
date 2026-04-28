fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER
ER.onInitHooks = ER.onInitHooks or {}
local er

local numberOfTests = 0
local failures = 0

local function checkDone() 
  if numberOfTests == 0 then
    print("All tests done")
    if failures > 0 then
      print("❌ "..failures.." tests failed")
    end
  end
end

local function testRule(str,tr,val,ntest) 
  ntest = ntest or 1
  numberOfTests = numberOfTests + ntest
  local r = er.eval(str,{verbosity="silent"})
  r.onDone = function(...) 
    local v = {...}
    if table.equal(v,val) then
      print("✅ ",str)
    else
      print("❌ ",str," expected ",table.unpack(val)," got ",table.unpack(v))
      failures = failures + 1
    end
    numberOfTests = numberOfTests - 1
    checkDone()
  end
  if tr then er.eval(tr,{verbosity="silent"}) end
end

local function testExpr(str,val) 
  ntest = ntest or 1
  numberOfTests = numberOfTests + ntest
  local function done(...) 
      local v = {...}
      if table.equal(v,val) then
        print("✅ ",str)
      else
        print("❌ ",str," expected ",table.unpack(val)," got ",table.unpack(v))
        failures = failures + 1
      end
      setTimeout(function() numberOfTests = numberOfTests - 1 checkDone() end,0)
  end
  local opts = {verbosity="silent", onDone = done}
  setmetatable(opts, { __tostring = function() return str end })
  local v = {er.eval(str,opts)}
  if #v > 0 then done(table.unpack(v)) end
end

local function test(str,...)
  if str:match("=>") then return testRule(str,...)
  else return testExpr(str,...)
  end
end

table.insert(ER.onInitHooks,function(_er) 
  er = _er 
  er.test = test
end)