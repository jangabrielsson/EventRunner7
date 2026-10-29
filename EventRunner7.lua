--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%include:EventRunner.inc
--%%file:src/Setup.lua,stdfuns
--%%u:{label='info', text='EventRunnner 7'}
--%%u:{button='refresh', text='🔄 Rules'}
--%%u:{label='status', text='Loading rules...'}

local function main(er, qa)
  local rule,var = er.eval,er.variables
  er.opts = { started = true, check = true, result = true, triggers=true }

  rule("@@00:00:05 => log[({'red','green','yellow'})[rnd(1,3)]]('tick!')",{check=false})

  -- Rule status in the UI: refreshed after boot, on button press, and on
  -- rule errors/completions (ER._statusHook).
  local function refreshStatus()
    qa:updateView('status','text', fibaro.ER.ruleStatusText())
  end
  fibaro.ER._statusHook = refreshStatus
  setTimeout(refreshStatus, 1000)
end

function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(string.format("<font color='green'>%s</font>",str))
  self:updateView('info','text',str)
  fibaro.EventRunner(function(er) main(er, self) end)
end

function QuickApp:UIEvent(element, eventType, value)
  if element == 'refresh' and eventType == 'onReleased' then
    self:updateView('status','text', fibaro.ER.ruleStatusText())
  end
end
