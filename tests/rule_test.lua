--%%name:Rule test
--%%headers:EventRunner.inc
--%%offline:true

local function EV(name, body)
  body = body or {}
  body.type=name
  return body
end

local function main(er)
  local dev1 = fibaro.ER.loadSimDev("binarySwitch")
  fibaro.ER.csp.defGlobal("dev1", dev1)

  local eval = er.eval

  print(eval("dev1:isOn & 10:00..23:00 => wait(2); print(88); return 4+4,77"):run())
  eval("return dev1:on")  
end

function QuickApp:onInit()
  fibaro.EventRunner(main) -- initialies the EventRunner and runs main(er) where er is the EventRunner instance
end
