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

  -- rule("@@00:00:05 => log('tick')",{check=false})

rule([[ @23:30+rnd(-00:15,00:15) & $Locatie_Bewoners == 'Afwezig' => log('tick')]],{check=false})
end

function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(string.format("<font color='green'>%s</font>",str))
  self:updateView('info','text',str)
  fibaro.EventRunner(main)
end