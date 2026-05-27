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

  rule([[#keuken_Apparatuur_Aan => 
        for _,id in pairs(keuken_apparatuur) do id:on; wait(00:00:02) end;
            log.yellow('keuken_apparatuur = Aan');
            log('19-A');
        wait(0)
            ]])
end

function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(string.format("<font color='green'>%s</font>",str))
  self:updateView('info','text',str)
  fibaro.EventRunner(main)
end