--%%name:Test ground
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%% offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:Setup.lua,stdfuns
--%%file:$fibaro.lib.speed,speed
--%%file:tests/testfuns.lua,test
--%%file:Sim.lua,sim
--%%time:2026/04/28 07:00:00

-- Scratch pad for testing new feature. Actual test suite to go into
-- eventrunner_test.lua once we have a stable set of features to test.


local function main(er) ER = er
  local rule, var, tvar, test = er.eval, er.variables, er.triggerVars, er.test
  local function loadDevice(name) return er.loadSimDevice(name) end

  local HT = {
    blinds_living_room = loadDevice("rollerShutter"),
    blind_Nr_4  = loadDevice("rollerShutter"),
    door_bow_tie = loadDevice("doorSensor"),
  }

  var.HT = HT
  er.createSimGlobal("Present_Kai", "away")
  er.createSimGlobal("Present_Katharina", "away")
  rule("HT.blind_Nr_4:value=99")
  rule("HT.door_bow_tie:value=false")

  setTimeout(function()

rule("@22:00+rnd(-00:08,00:03) & ($Present_Kai=='away' & $Present_Katharina=='away' & HT.blind_Nr_4:isOpen & HT.door_bow_tie:safe) => log('X'); HT.blinds_living_room:close",{check=true, started=true})

  rule([[HT.door_bow_tie:value=true;
        wait(5);
        HT.door_bow_tie:value=false;
        
  ]])

  end, 1000)

end

function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    setTimeout(function() fibaro.EventRunner(main) end, 100)
  end)
end