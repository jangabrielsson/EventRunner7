--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%file:Setup.lua,stdfuns
-- %%offline:true
--%%save:dist/EventRunner7.fqa
--%%u:{label='info', text='EventRunnner 7'}

local function main(er)
  local rule,var = er.eval,er.variables
  er.opts = { started = true, check = true, result = false, triggers=true}

  rule("@@00:00:05 => log('tick')",{check=false})

  er.addStdProp("onIfOff",{
  trigger = {type='device', property='value'},
   get = function(_,id)
      local value = fibaro.getValue(id,'value')
      if type(value)=='boolean' then value = value and 1 or 0 end
      if value == 0 then fibaro.call(id,"turnOn") end
    end,
    reduce = table.mapF
})
end
function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(string.format("<font color='green'>%s</font>",str))
  self:updateView('info','text',str)
  fibaro.EventRunner(main)
end