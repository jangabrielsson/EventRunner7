--%%name:Test ground
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:$fibaro.lib.speed,speed
--%%file:tests/testfuns.lua,test
--%%file:Sim.lua,sim
--%%time:2026/04/28 10:10:00

-- Scratch pad for testing new feature. Actual test suite to go into
-- eventrunner_test.lua once we have a stable set of features to test.

local function main(er) ER = er
  local rule, test = er.eval, er.test
  local function loadDevice(name) return er.loadSimDevice(name) end

  er.createSimGlobal("G_foo","15:00")
  er.createSimGlobal("G_bar","66")
  er.createSimGlobal("TimeGV","13:00")
  er.defglobals.light1 = loadDevice("binarySwitch")
  er.defglobals.light2 = loadDevice("binarySwitch")
  er.defglobals.motion1 = loadDevice("motionSensor")
  er.defglobals.door1 = loadDevice("doorSensor")
  er.defglobals.window1 = loadDevice("windowSensor")
  er.defglobals.window2 = loadDevice("windowSensor")
  er.defglobals.fire1 = loadDevice("fireDetector")
  er.defglobals.temp1 = loadDevice("temperatureSensor")
  er.defglobals.temp2 = loadDevice("temperatureSensor")
  er.defglobals.temp3 = loadDevice("temperatureSensor")

  --fibaro.debugFlags.sourceTrigger = true
  
  -- rule("temp1:value = 10; temp2:value = 20; temp3:value = 30")

  -- er.definePropClass("MyDevice")
  -- local MyDevice = {}
  -- function MyDevice:__init() self.value = 21; er.PropObject.__init(self) end
  -- function MyDevice.getProp:temp(_) return self.value end
  -- function MyDevice.setProp:temp(_, value) 
  --   self.value = value 
  --   er.sourceTrigger:post({type='device', id=tostring(self), property='value', value=value} )  
  --   return true
  -- end
  -- function MyDevice.trigger:temp() return {type='device', id=tostring(self), property='value'} end
  -- function MyDevice.map.temp(fun,list) 
  --   local sum = 0
  --   for _,v in ipairs(list) do sum = sum + fun(v) end
  --   return sum
  -- end
  -- er.defglobals.mydev = MyDevice()

  --rule("temps = { mydev, temp1, temp2, temp3}")
  -- rule("mydev:temp > 41 => wait(2); log('OK')")
  -- rule("mydev:temp = 42",{result=true})
  --rule("json.encode(temps:temp)")

  -- rule("@10:00 => log('tick')",{group='morning', verbosity='verbose'})
  -- rule("disable('morning')")

--   er.createSimGlobal("Weer_Bewolking","Zwaar_Bewolkt")
--   er.createSimGlobal("Gordijn_Licht","Ochtöend")
--   er.createSimGlobal("Gordijn_Bewolking","")
--   local var = er.variables
--   var.Gordijn_Bewolking = "fopp"

-- rule([[@{05:00, catch} & now < 09:30 & $Gordijn_Licht == 'Ochtend' & Gordijn_Bewolking ~= 'Ochtend' =>
--         log.byzantine('gordijn_Bewolking_Ochtend = Vertraagd wordt ingesteld - 54-n');
--         log.limegreen('$Weer_Bewolking is %s',$Weer_Bewolking);case
--     || $Weer_Bewolking == 'Onbewolkt' >> 
--         post(#gordijn_Bewolking_Ochtend,+/00:01);
--         log.magenta('gordijn_Bewolking_Ochtend - vertraagd');
--         log.pink('$Gordijn_Bewolking = Ochtend');
--         log('54-N2');
-- wait(0)
--     || $Weer_Bewolking == 'Geen_Bewolking' >> 
--         post(#gordijn_Bewolking_Ochtend,+/00:01);
--         log.magenta('gordijn_Bewolking_Ochtend - vertraagd');
--         log.pink('$Gordijn_Bewolking = Ochtend');
--         log('54-N4');
-- wait(0)
-- 	|| $Weer_Bewolking == 'Licht_Bewolkt' >> 
--         post(#gordijn_Bewolking_Ochtend,+/00:05);
--         log.magenta('gordijn_Bewolking_Ochtend - vertraagd');
--         log.pink('$Gordijn_Bewolking = Ochtend');
--         log('54-N6');
-- wait(0)
-- 	|| $Weer_Bewolking == 'Half_Bewolkt' >> 
--         post(#gordijn_Bewolking_Ochtend,+/00:10);
--         log.magenta('gordijn_Bewolking_Ochtend - vertraagd');
--         log.pink('$Gordijn_Bewolking = Ochtend');
--         log('54-N8');
-- wait(0)
--     || $Weer_Bewolking == 'Geheel_Bewolkt' >>  
--         post(#gordijn_Bewolking_Ochtend,+/00:12);
--         log.magenta('gordijn_Bewolking_Ochtend - vertraagd');
--         log.pink('$Gordijn_Bewolking = Ochtend');
--         log('54-N10');
-- wait(0) 
--     || $Weer_Bewolking == 'Zwaar_Bewolkt' >> 
--         post(#gordijn_Bewolking_Ochtend,+/00:14);
--         log.magenta('gordijn_Bewolking_Ochtend - vertraagd');
--         log.pink('$Gordijn_Bewolking = Ochtend');
--         log('54-N12');
-- wait(0)
-- end
-- ]])

   rule("#foo{fun='$f'} => log('got fun: %s', f())", {result=true})
   rule("a = () -> 77; post(#foo{fun=a})",{result=true})

end


function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    fibaro.EventRunner(main)
  end)
end