--%%name:Motion lights
--%%include:../EventRunner.inc
--%%file:../src/Sim.lua,sim
--%%file:../src/Setup.lua,stdfuns
--%%mode:offline
--%%time:2026/06/12 20:00:00

-- EventRunner7 example: the classic motion-light rule.
--
--   Run:    flua --api local --step examples/motion-lights.lua
--   Watch:  the demo driver at the bottom breaches the motion sensor a few
--           times, and you see the rules fire in the log.
--
-- The devices are simulated (Sim.lua) — nothing real is touched. Change
-- the rules and re-run: this is your sandbox.

local function main(er)
  local rule = er.eval

  -- Simulated devices: a motion sensor and a light.
  local motion = er.loadSimDevice("motionSensor")
  local light  = er.loadSimDevice("binarySwitch")
  er.defvars({ motion = motion, light = light })

  -- Show rule results in the log so you can see what happens.
  er.opts = { result = true }

  -- 1. The classic rule — 'when ... then ...' sugar:
  --    when motion is breached, turn the light on;
  --    when it's been safe for 2 minutes, turn it off again.
  rule("when motion:breached then light:on; wait(2min); light:off")

  -- 2. Only at night: a time window guard (20:00 to 06:00).
  --    & means AND. The condition is true when motion is breached AND
  --    the current time is inside the window.
  rule("when motion:breached & 20:00..06:00 then log('Night motion!')")

  -- 3. Don't spam: the cooldown modifier suppresses re-triggers for
  --    5 minutes after a fire.
  rule("when motion:breached cooldown 5min then log('Motion detected!')")

  -- 4. Counter with a trigger variable (defined in Lua, used in rules).
  er.triggerVars.breaches = 0
  rule("motion:breached => breaches = breaches + 1")
  rule("breaches == 3 => log('Third breach today!')")

  -- ── Demo driver ─────────────────────────────────────────────────────────
  -- Breach the sensor at t+0s, +3s and +10s. With --step the virtual clock
  -- fast-forwards, so the whole demo completes in an instant.
  local function breach() fibaro.call(motion, 'setValue', true) end
  local function safe()   fibaro.call(motion, 'setValue', false) end
  setTimeout(breach, 0)
  setTimeout(safe, 2000)
  setTimeout(breach, 3000)
  setTimeout(safe, 5000)
  setTimeout(breach, 10000)
end

function QuickApp:onInit() fibaro.EventRunner(main) end
