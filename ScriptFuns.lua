ER = ER or {}
ER._funs = ER._funs or {}

local devs = {}
local function defineDevice(id)
  local props = {}
  devs[id] = setmetatable({}, {
    __index    = function(t,k)   return props[k] end,
    __newindex = function(t,k,v) props[k] = v   end,
  })
end

local function getProp(obj, key)
  assert(devs[obj], "getProp: no such device '"..tostring(obj).."'")
  return devs[obj][key]
end

local function setProp(obj, key, value)
  assert(devs[obj], "setProp: no such device '"..tostring(obj).."'")
  devs[obj][key] = value
end

ER._funs.getProp = getProp
ER._funs.setProp = setProp
ER._funs.defineTestDevice = defineDevice