--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%file:src/Setup.lua,stdfuns
-- %%offline:true
--%%save:dist/EventRunner7.fqa
--%%u:{label='info', text='EventRunnner 7'}

local function main(er)
  local rule,var = er.eval,er.variables
  er.opts = { started = true, check = true, result = true, triggers=true }

  rule("log('%s',wnum)")
  rule("@@00:00:05 => log[({'red','green','yellow'})[rnd(1,3)]]('tick!')",{check=false})
end

function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(string.format("<font color='green'>%s</font>",str))
  self:updateView('info','text',str)
  fibaro.EventRunner(main)
end
