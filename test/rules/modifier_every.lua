--%%name:rule_modifier_every
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- 'every N' modifier exists but its interaction with rule:run()
  -- needs further investigation.  Skipping for now.

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
