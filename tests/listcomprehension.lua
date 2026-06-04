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
  --rule("return [{x.id,x.id:bat} for x in api.get('/devices') if !x.id:isDead & x.id:bat]", {result=true})
  --rule("a = 1; b = 2; return a,b",{result=true})
  function range(x) local r = {} for i=1,x do table.insert(r,i) end return r end
  rule("return [x for x in range(11) if x%2==0]", {result=true})
end

function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.EventRunner(main)
end