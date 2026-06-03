--%%name:EventRunnerTest
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%% offline:true
--%%file:$fibaro.lib.speed,speed
--%%file:Sim.lua,sim
--%%file:tests/testfuns.lua,test
--%%time:2026/04/28 07:59:58

local function main(er) ER = er
  local rule, var, test = er.eval, er.variables, er.test

  local HT = {
    kitchen = {
      light1 = 1,
      light2 = 20,
    },
    living_room = {
      light1 = 2,
      light2 = 22,
    },
  }

  var.HT = HT

  tt = {
    {x=1,y=10},
    {x=2,y=20},
  }
  rule("return [{x.x,x.y} for x in tt ],nil,77", {result=true})
  --rule("a = 1; b = 2; return a,b",{result=true})

end

function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.EventRunner(main)
end