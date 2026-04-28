--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:$fibaro.lib.speed,speed
--%%file:tests/testfuns.lua,test
--%%time:2026/03/15 12:00:00

local function main(er) ER = er
  local rule, test = er.eval, er.test
  local function loadDevice(name) return er.loadDevice(name) end

  -- api.post("/globalVariables",{name = "G_foo",value = "66"})
  -- er.defglobals.light1 = loadDevice("binarySwitch")
  -- er.defglobals.motion1 = loadDevice("motionSensor")
  -- er.defglobals.door1 = loadDevice("doorSensor")
  -- er.defglobals.window1 = loadDevice("windowSensor")
  -- er.defglobals.window2 = loadDevice("windowSensor")
  -- er.defglobals.fire1 = loadDevice("fireDetector")

  -- test("return 5+5",{10})
  -- test("return 5+5*2",{15})
  -- test("return 5+5*-2",{-5})

  -- test("if true then return 5 end",{5})
  -- test("if false then return 5 end",{nil})
  -- test("if true then return 5 else return 6 end",{5})
  -- test("if false then return 5 else return 6 end",{6})
  -- test("if false then return 5 elseif true then return 6 else return 7 end",{6})
  -- test("if false then return 5 elseif false then return 6 else return 7 end",{7})
  -- test("local a,i=0,0; while i < 5 do a=a+i; i=i+1 end; return a",{10})
  -- test("local a,i=0,0; repeat  a=a+i; i=i+1 until i >= 5; return a",{10})
  -- test("local a=0; for i=1,5 do a=a+i end; return a",{15})
  -- test("local a=0; for i=1,5,2 do a=a+i end; return a",{9})
  -- --test("local a=0; for x,v in ipairs({1,2,3}) do a=a+v end; return a",{6})
  -- --test("local a=0; for x,v in pairs({a=1,b=2,c=3}) do a=a+v end; return a",{6})

  -- test("return HM(now)",{os.date("%H:%M")})
  -- test("return HMS(now)",{os.date("%H:%M:%S")})
  -- test("return sign(0)",{1})
  -- test("return sign(-5)",{-1})
  -- test("return sign(5)",{1})
  -- test("return round(1.4)",{1})
  -- test("return round(1.5)",{2})
  -- test("return sum(1,2,3)",{6})
  -- test("return sum({1,2,3})",{6})
  -- test("return average(1,2,3)",{2})
  -- test("return average({1,2,3})",{2})
  -- test("return size({1,2,3,4})",{4})
  -- test("return size({})",{0})
  -- test("return min(5,3,8)",{3})
  -- test("return min({5,3,8})",{3})
  -- test("return max(5,3,8)",{8})
  -- test("return max({5,3,8})",{8})
  -- test("return fmt('%02d:%02d',10,5)",{"10:05"})
  -- test("return sort({5,2,3})",{{2,3,5}})
  -- test("return osdate('%Y-%m-%d',ostime{year=2024,month=3,day=15})",{"2024-03-15"})
  -- test("return osdate('%H:%M:%S',ostime{year=2024,month=3,day=15,hour=12,sec=30})",{"12:00:30"})
  -- test("return ostime()",{os.time()})
  -- test("return $G_foo",{"66"})


  -- test("local a={6}; return a",{{6}})
  -- test("local a={b=6}; return a.b",{6})
  --test("local a={b=6}; a.b=7; return a",{{7}})

  -- test("return now..now+1",{true})
  -- test("return sunrise..sunset",{true})
  -- test("return sunset..sunrise",{false}) -- It's 12 o'clock
  -- test("return now+1..now+2",{false})
  -- test("return now..now",{true})

  function er.async.testa(cb,x,y) setTimeout(function() cb(x+y) end,2000) end
  test("return testa(5,7)",{12})

  test("return now",{ER.now()})
  test("local a = ostime(); wait(4000); return ostime()-a",{4})

  -- test("light1:isOn => return 99","light1:on",{99})
  -- test("motion1:breached => return 42","motion1:value=true",{42})
  -- test("#foo => return 66,77","post(#foo)",{66,77})
  -- test("@{15:00,16:00} => return 88",nil,{88},2)
end


function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  local t = os.time()
  fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    fibaro.EventRunner(main)
  end)
end