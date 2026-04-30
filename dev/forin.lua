-- local function FORIN(vars,expr,body)
--   return FRAME(function(cont,env)
--     local kn,vn = table.unpack(vars)
--     env:pushVariable(kn,nil)
--     env:pushVariable(vn,nil)
--     expr(function(f,t,i)
--       local k,v = i,nil
--       local function loop()
--         k,v = f(t,k)
--         env:setVariable(kn,k)
--         env:setVariable(vn,v)
--         if not k then return cont(true) end
--         body(function() env:setTimeout(loop,0) end, env)
--       end
--       loop()
--     end,env)
--   end),{'forin',vars,expr,body}
-- end

local a = {'a','b','c'}
local b = {m='a',n='b',o='c'}

local fun = function() return pairs(b) end
local f,t,k,v = fun()
while true do
  k,v = f(t,k)
  kn,vn = k,v
  if not k then break end
  print(k,v)
end

local a = { 3,4,5,6 }
for i,v in ipairs(a) do
  if v == 5 then table.remove(a,i) 
  else print(i,v) end
end