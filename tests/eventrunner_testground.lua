--%%name:Test ground
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:$fibaro.lib.speed,speed
--%%file:tests/testfuns.lua,test
--%%time:2026/04/28 12:00:00

local function main(er) ER = er
  local rule, test = er.eval, er.test
  local function loadDevice(name) return er.loadDevice(name) end

  er.createSimGlobal("G_foo","66")
  er.defglobals.light1 = loadDevice("binarySwitch")
  er.defglobals.light2 = loadDevice("binarySwitch")
  er.defglobals.motion1 = loadDevice("motionSensor")
  er.defglobals.door1 = loadDevice("doorSensor")
  er.defglobals.window1 = loadDevice("windowSensor")
  er.defglobals.window2 = loadDevice("windowSensor")
  er.defglobals.fire1 = loadDevice("fireDetector")

  function er.defglobals.mret(x) return x+1,x+2 end
   er.defglobals.pairs = pairs
   er.defglobals.ipairs = ipairs

  -- rule([[local f,t,k,v = fun()
  --     while true do
  --       k,v = f(t,k)
  --       if not k then break end
  --       print(k,v)
  --     end]])
  --  rule("local a,b,c,d; a,b=9,10; c,d=11,12")
  function er.variables.mret(start,stop) 
    local r={}; for i=start,stop do r[#r+1]=i end; return table.unpack(r)
  end
  --rule("local a=0; for x,v in ipairs({1,2,3}) do a=a+v end; return a")

  test("return $G_foo",{66})
  rule("$G_foo = 42")
  test("return $G_foo",{42})
  rule("$G_foo = {b=33}")
  test("return $G_foo.b",{33})
  rule("$G_foo = true")
  test("return $G_foo",{true})
  test("$G_foo.b == 77 => return 99","wait(100); $G_foo={b=77}",{99})
end


function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  --fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    fibaro.EventRunner(main)
  --end)
end