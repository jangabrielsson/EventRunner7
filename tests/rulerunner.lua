--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%file:../src/Tokenizer.lua,tokenizer
--%%file:../src/Parser.lua,parser
--%%file:../src/CSP.lua,csp
--%%file:../src/Utils.lua,utils
--%%file:../src/Props.lua,props
--%%file:../src/Compiler.lua,compiler
--%%file:../src/ScriptFuns.lua,scriptfuns
--%%file:../src/Rule.lua,rule
--%%file:../src/Templates.lua,templates
--%%file:../src/Setup.lua,stdfuns
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