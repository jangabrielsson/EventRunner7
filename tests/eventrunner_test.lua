--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
-- %%offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:$fibaro.lib.speed,speed
--%%file:tests/testfuns.lua,test
--%%time:2026/03/15 12:00:00

local function main(er) ER = er
  local rule, test = er.eval, er.test

  test("#foo => return 66","post(#foo)",66)
end


function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.speedTime(4*24,function()
    fibaro.EventRunner(main)
  end)
end