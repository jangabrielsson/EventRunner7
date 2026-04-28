--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
-- %%offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:$fibaro.lib.speed,speed

local function main(er)
  local rule = er.eval

  -- rule([[print(8)]])


-- rule([[99:isOn =>
--     foo:on;
--     4262:value = 50;
--     log('#C:yellow#Eethoek - Aan');
--     wait(00:00:15);
--     4262:value = 100;
--     log('#C:yellow#Eethoek - value up naar 100');
--     wait(00:00:15);
--     4262:off;
--     log('#C:yellow#🔴🟠🟡🟢🔵🟣 Eethoek test 🔴🟠🟡🟢🔵🟣');
-- log('05-B');
--     wait(0)
-- ]])
  --fibaro.debugFlags.post = true
  -- rule("#foo => log('ping %s',event); post(#foo,5)")
  -- rule("post(#foo)")
  --rule("@sunset & sunset..sunrise => log('ping')")--.verbosity = 'verbose'
  --rule("@@00:00:05 => log('tick')")
  rule("@10:00 => log('tick %s',event)")
end


function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.speedTime(4*24,function()
    fibaro.EventRunner(main)
  end)
end