--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
-- %%offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:$fibaro.lib.speed,speed

local function main(er)
  local rule,var = er.rule,er.variables
  er.opts = { started = true, check = true, result = false, triggers=true}

  var.x = 9
  rule("@@00:00:05 => log('tick')")
end


function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.EventRunner(main)
end