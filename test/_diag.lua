--%%name:catchup_diag
--%%headers:EventRunner.inc
--%%file:$fibaro.lib.speed,speed
--%%offline:true
--%%time:2026/06/12 09:00:00

local function main(er)
  -- Print diagnostics to understand catchup
  local out = io.open("_catchup_diag.txt", "w")
  local function log(msg)
    if out then out:write(msg .. "\n") end
  end

  local now_es = er.eval("return now")
  local ostime = fibaro.ER.csp.host.ostime()
  local midnight = fibaro.ER.midnight()
  log(string.format("now (ES)        = %d  (%s)", now_es, os.date("%H:%M:%S", midnight + now_es)))
  log(string.format("ostime (host)   = %d  (%s)", ostime, os.date("%H:%M:%S", ostime)))
  log(string.format("midnight (ER)   = %d  (%s)", midnight, os.date("%H:%M:%S", midnight)))
  log(string.format("os.time()       = %d  (%s)", os.time(), os.date("%H:%M:%S", os.time())))
  log(string.format("08:00 epoch     = %d  (%s)", midnight + 28800, os.date("%H:%M:%S", midnight + 28800)))

  if out then out:close() end
  os.exit(0)
end

function QuickApp:onInit()
  fibaro.speedTime(0.5, function()
    fibaro.EventRunner(main)
  end)
end
