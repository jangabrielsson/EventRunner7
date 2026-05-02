--%%name:EventRunnerTest
--%%type:com.fibaro.deviceController
--%%headers:EventRunner.inc
--%%offline:true
-- %%save:dist/EventRunner7.fqa
--%%file:$fibaro.lib.speed,speed
--%%file:Sim.lua,sim
--%%file:tests/testfuns.lua,test
--%%time:2026/04/28 12:00:00

-- testsuit for EventScript 
-- Runs in simulated time (speedTime) to allow testing of time based features without having to wait for real time to pass.
-- We alway start at 2026/04/28 12:00:00
-- Loads a set of simulated predefined devices (tests/stdQAs) and global variables to test against. This resources fires change event immediately when a property is changed and works with speedTime. If we used plua simulated devices/resources it would not work with speedTime as they use the plua internal time, and would arrrive after speedTime finish...

local function main(er) ER = er
  local rule, test = er.eval, er.test
  local function loadDevice(name) return er.loadSimDevice(name) end

  er.createSimGlobal("G_foo","66")
  er.createSimGlobal("G_bar","66")
  er.createSimGlobal("TimeGV","13:00")
  er.defglobals.light1 = loadDevice("binarySwitch")
  er.defglobals.light2 = loadDevice("binarySwitch")
  er.defglobals.light3 = loadDevice("binarySwitch")
  er.defglobals.motion1 = loadDevice("motionSensor")
  er.defglobals.door1 = loadDevice("doorSensor")
  er.defglobals.window1 = loadDevice("windowSensor")
  er.defglobals.window2 = loadDevice("windowSensor")
  er.defglobals.fire1 = loadDevice("fireDetector")

  -- Basic arithmentic and precedence
  test("return 5+5",{10})
  test("return 5+5*2",{15})
  test("return 5+5*-2",{-5})
  test("return -2+5*5",{-2+5*5})
  test("return 1+(5+5)*2",{1+(5+5)*2})
  test("return 10/2",{5})
  test("return $G_foo+1",{67})

  -- Control structures
  test("if true then return 5 end",{5})
  test("if false then return 5 end; return 6",{6})
  test("if true then return 5 else return 6 end",{5})
  test("if false then return 5 else return 6 end",{6})
  test("if false then return 5 elseif true then return 6 else return 7 end",{6})
  test("if false then return 5 elseif false then return 6 else return 7 end",{7})
  test("local a,i=0,0; while i < 5 do a=a+i; i=i+1 end; return a",{10})
  test("local a,i=0,0; repeat  a=a+i; i=i+1 until i >= 5; return a",{10})
  test("local a=0; for i=1,5 do a=a+i end; return a",{15})
  test("local a=0; for i=1,5,2 do a=a+i end; return a",{9})
  test("local a=0; for x,v in ipairs({1,2,3}) do a=a+v end; return a",{6})
  test("local a=0; for x,v in pairs({a=1,b=2,c=3}) do a=a+v end; return a",{6})

  -- Builtin functions
  test("return HM(now)",{os.date("%H:%M")})
  test("return HMS(now)",{os.date("%H:%M:%S")})
  test("return sign(0)",{1})
  test("return sign(-5)",{-1})
  test("return sign(5)",{1})
  test("return round(1.4)",{1})
  test("return round(1.5)",{2})
  test("return sum(1,2,3)",{6})
  test("return sum({1,2,3})",{6})
  test("return average(1,2,3)",{2})
  test("return average({1,2,3})",{2})
  test("return size({1,2,3,4})",{4})
  test("return size({})",{0})
  test("return min(5,3,8)",{3})
  test("return min({5,3,8})",{3})
  test("return max(5,3,8)",{8})
  test("return max({5,3,8})",{8})
  test("return fmt('%02d:%02d',10,5)",{"10:05"})
  test("return sort({5,2,3})",{{2,3,5}})
  test("return osdate('%Y-%m-%d',ostime{year=2024,month=3,day=15})",{"2024-03-15"})
  test("return osdate('%H:%M:%S',ostime{year=2024,month=3,day=15,hour=12,sec=30})",{"12:00:30"})
  test("return ostime()",{os.time()})

  -- Global variables
  test("return $G_foo",{66})
  rule("$G_foo = 42")
  test("return $G_foo",{42})
  rule("$G_foo = {b=33}")
  test("return $G_foo.b",{33})
  rule("$G_foo = true")
  test("return $G_foo",{true})
  -- Need a short wait before setting $G_foo to ensure the 3 first GV events generated when triggering the rule, $G_foo.b will not be 77. The rule will ignore those triggers instead of counting them as test failures, since the rule condition is not met. 
  test("$G_foo.b == 77 => return 99","wait(1); $G_foo={b=77}",{99})
  test("$G_bar[1].b == 77 => return 99","wait(1); $G_bar={{b=77}}",{99})


  -- Tables
  test("local a={6}; return a",{{6}})
  test("local a={b=6}; return a.b",{6})
  test("local a={b=6}; a.b=7; return a.b",{7})
  test("local a={6}; a[1]=7; return a",{{7}})

  -- Between operator
  test("return now..now+1",{true})
  test("return sunrise..sunset",{true})
  test("return sunset..sunrise",{false}) -- It's 12 o'clock
  test("return now+1..now+2",{false})
  test("return now..now",{true})

  -- Date functions
  test("return wday('tue')",{true})
  test("return wday('mon-wed')",{true})
  test("return wday('fri')",{false})
  test("return month('apr')",{true})
  test("return month('mar-jun')",{true})
  test("return month('oct')",{false})
  test("return day('28')",{true})
  test("return day('27-last')",{true})
  test("return day('15')",{false})
  test("return osdate('%c',nextDST())",{"Sun Oct 25 03:00:00 2026"})

  -- User defined async functions
  -- Defined async function gets callback, cb, as first argument.
  -- Default timeout is 3000ms, but can be overridden by returning a positive number from the async function. Return -1 to return sync.
  function er.async.testa(cb,x,y) 
    local cf = cb.cf
    setTimeout(function() cb(x+y) end,1000) 
  end
  test("@20:00 => local a = testa(5,7); return a+1",nil,{13})

  -- Trigger variables
  er.triggerVars.a1 = 0
  test("a1 == 1 => return 42","a1=1",{42})
  test("a1 == 2 => return 43","wait(1); a1=2",{43}) -- should trigger both rules. Need a short wait before setting a1 to ensure first rule's callback is run and will read a1 as 1, not 2

  -- now
  test("return now",{ER.now()})

  -- wait
  test("local a = ostime(); wait(4000); return ostime()-a",{4}) -- wait should be approximately 4 seconds

  -- Device property triggers
  test("light1:isOn => return 99","light1:on",{99})
  test("motion1:breached => return 42","motion1:value=true",{42})

  -- User event triggers
  test("#foo => return 66,77","post(#foo)",{66,77})
  test("#bar{a=5,b='$x'} => return x","post(#bar{a=5,b=88})",{88})
  test("#bar1{a=5,b='$x>79'} => return x","post(#bar1{a=5,b=88})",{88})
  test([[#bar1{a=5,b='$x==abc'} => return x]],"post(#bar1{a=5,b='abc'})",{'abc'})
  test([[#bar1{a=5,b='$x<>.*tfr$'} => return x]],"post(#bar1{a=5,b='AAtfr'})",{'AAtfr'}) -- lua match

  -- Multiple values
  function er.variables.mret(start,stop) 
    local r={}; for i=start,stop do r[#r+1]=i end; return table.unpack(r)
  end
  test("return {mret(3,5)}",{{3,4,5}})
  test("return {2,mret(3,5)}",{{2,3,4,5}})
  test("local a,b,c = mret(3,5); return a+b+c",{12})

  -- @Daily triggers
  test("@{15:00,16:00} => return 88",nil,{88},2)
  test("@(now+1) & now > 12:00 => return 44",nil,{44}) -- Donät want re-schedule at midnight
  test("@$TimeGV => return HM(now)","$TimeGV=17:00",{"17:00"}) -- TimeGV start as 13:00. The setting of TimeGV to 17:00 will reschedule the daily trigger.

  er.variables.icount = 0
  rule([[@@00:05 => 
     icount = icount+1; 
     if icount > 5 then disable() end;
     return 77
    ]],{77},6) -- Will succeed 6 times, then disable itself, so the 7th trigger will not cause a test failure since the rule is disabled

  -- trueFor
  test("trueFor(00:05,light2:isOn) => return 55","light2:on",{55})
  test("trueFor(00:05,light3:isOn) => log('again %s',again(5)); return 88","light3:on",{88},5) -- Will re-trigger 5 times.
end

function QuickApp:onInit()
  self:debug("EventRunner 7,","v"..fibaro.EventRunnerVersion)
  fibaro.speedTime(1*24,function() -- Run for 24 hours of simulated time
    fibaro.EventRunner(main)
  end)
end