
local funs  = {}
function funs.turnOn(id) return fibaro.call(id,"turnOn") end
function funs.turnOff(id) return fibaro.call(id,"turnOff") end
function funs.setValue(id,val) return fibaro.call(id,"setValue",val) end
function funs.toggle(id) return fibaro.call(id,"toggle") end

local _scan = nil
local _scans = {}

local function DEV(id)
  local dev = api.get("/devices/"..id)
  assert(dev, "No such device: "..tostring(id))
  local props = dev.properties
  local actions = dev.actions
  return setmetatable({id},{
    __tostring = function(self)
      return "DEV("..tostring(self[1])..")"
    end,
    __index = function(self,k)
      if actions[k] and funs[k] then
        if _scan ~= nil then
          error("Cannot scan for actions: "..tostring(k))
        end
        return function(...) return funs[k](id, ...) end
      elseif props[k]~=nil then
        if _scan~=nil then
          _scans[k..id] = true
          return _scan
        end
        return fibaro.getValue(id, k)
      end
      error("No such property: "..tostring(k))
    end
  })
end

local RULES = {}
local rule = setmetatable({},{
  __index = function(self,k)
    if RULES[k] then
      return RULES[k]
    else
      local r = {name=k}
      RULES[k] = r
      setmetatable(r,{
        __tostring = function(self)
          return "RULE("..tostring(self.name)..")"
        end
      })
      return r
    end
  end
})

function rule.x.cond()
  return DEV(399).value > 0 and DEV(399).value == 0
end
function rule.x.action()
  DEV(399).turnOn()
end

print(rule.x)

local function scan(rule)
  _scans = {}
  local testVals = {1,0,true,false}
  for _,v in ipairs(testVals) do
    _scan = v
    pcall(function() rule.cond() end)
  end
  for k,_ in pairs(_scans) do
    print("Scanned: "..k)
  end
end

scan(rule.x)