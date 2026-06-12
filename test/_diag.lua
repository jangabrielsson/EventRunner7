--%%name:ir_version_check
--%%headers:EventRunner.inc
--%%offline:true

local function main(er)
  local vm = fibaro.ER.csp
  assert(vm.irVersion == 1, "Expected irVersion 1, got " .. tostring(vm.irVersion))
  print("irVersion: " .. vm.irVersion)
  os.exit(0)
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
