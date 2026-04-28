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

  test("#foo => return 66,77","post(#foo)",{66,77})
  test("@{15:00,16:00} => return 88",nil,{88})
end


function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  local t = os.time()
  fibaro.speedTime(1*24,function()
    fibaro.EventRunner(main)
  end,function() print("End of speedTime",(os.time()-t)/3600) end)
end