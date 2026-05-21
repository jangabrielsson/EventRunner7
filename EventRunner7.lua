--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
-- %%offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:$fibaro.lib.speed,speed
--%%u:{label='info', text='EventRunnner 6'}

local function main(er)
  local rule,var = er.eval,er.variables
  er.opts = { started = true, check = true, result = false, triggers=true}

  var.x = 9
  var.y = "x"
  --rule("y += 8")
  -- rule("@@00:00:05 => return h + 9")
  --rule("return x.k")
  --rule("@@00:05 => $KLKL = 5")
  --rule("@@00:00:05 => log('tick')")
end


function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(str)
  self:updateView('info','text',str)
  fibaro.EventRunner(main)
end