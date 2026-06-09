------------ENDOFHEADERS ------------
local newmain = [[
--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%file:Setup.lua,stdfuns
--%%file:tests/plua_rules.lua,pl
--%%u:{label='info', text='EventRunnner 7'}
--%%debug:true

function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(string.format("<font color='green'>%s</font>",str))
  self:updateView('info','text',str)
  print("OKOK",main)
  fibaro.EventRunner(main)
end
]]

local f = io.open("dist/EventRunner7.fqa")
local fqa = f:read("*a")
f:close()
fqa = json.decode(fqa)
for _,f in ipairs(fqa.files) do
  if f.name == 'main' then
   f.content = newmain
  end
end
fibaro.plua.lib.loadFQA(fqa)
