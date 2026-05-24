--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%file:Setup.lua,stdfuns
-- %%offline:true
--%%save:dist/EventRunner7.fqa
--%%u:{label='info', text='EventRunnner 7'}

local function main(_er)
  er = _er
  rule,var = er.eval,er.variables
  er.opts = { started = true, check = true, result = true, triggers=true}
  local stdin = io.open("/dev/stdin", "r")
  if stdin then
    for line in stdin:lines() do
      if line ~= "" then load(line,nil,"t",_G)() end
    end
  end
end

function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(string.format("<font color='green'>%s</font>",str))
  self:updateView('info','text',str)
  fibaro.EventRunner(main)
end