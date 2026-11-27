--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%mode:offline
--%%include:EventRunner.inc
--%%file:src/Setup.lua,stdfuns
--%%u:{label='info', text='EventRunnner 7'}
--%%u:{button='refresh', text='🔄 Rules', onReleased='refreshRules'}
--%%u:{label='status', text='Loading rules...'}

-- The UI handler (QuickApp:refreshRules) and the auto-refresh hook live in
-- src/Rule.lua, so the QA Updater can ship them; only the %%u rows stay
-- here (flua and the HC3 read UI directives from the main file's header).

local function main(er)
  local rule,var = er.eval,er.variables
  er.opts = { started = true, check = true, result = true, triggers=true }

  rule("@@00:00:05 => log[({'red','green','yellow'})[rnd(1,3)]]('tick!')",{check=false})

  HT = { kitchen = {lamp = 99 }}
  HT = er.protectTable(HT,"HT") -- throws error when accessing undefined key
  for k,v in pairs(HT) do var[k] = v end
  rule("@now+1 => log('Kitchen sensor ID: %s', kitchen.sensor)")
end

function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(string.format("<font color='green'>%s</font>",str))
  self:updateView('info','text',str)
  fibaro.EventRunner(main)
end
