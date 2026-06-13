--%%name:subst_diag
--%%headers:EventRunner.inc
--%%offline:true

local function main(er)
  -- Test the new substitution-based template
  er.triggerVars.motion = false
  er.triggerVars.light_on = false

  -- Register the demo template (should produce: "77:breached => 54:on; wait(00:05); 54:off")
  -- with timeGuard empty → no timeGuard block
  -- with modifier "single" → modifier block included
  -- with offDelay "00:05" → offDelay block included
  local r = er.template("_motionLight", {
    sensor = "77",
    light = "54",
    offDelay = "00:05",
    timeGuard = "",        -- empty → conditional block omitted
    modifier = "single",
  })

  -- Verify the rule was created and has triggers
  assert(r and r.id, "template returned rule object")

  -- Also test with brightness (should produce "77:breached => 54:value = 80")
  local r2 = er.template("_motionLight", {
    sensor = "kitchen.motion",
    light = "kitchen.light",
    brightness = "80",
    timeGuard = "",
    modifier = "",
    offDelay = "",
  })
  assert(r2 and r2.id, "template with brightness returned rule object")

  print("_motionLight template works")
  os.exit(0)
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
