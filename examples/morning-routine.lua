--%%name:Morning routine
--%%include:../EventRunner.inc
--%%file:../src/Sim.lua,sim
--%%file:../src/Setup.lua,stdfuns
--%%mode:offline
--%%time:2026/06/12 06:55:00

-- EventRunner7 example: time-based rules.
--
--   Run:    flua --api local --step examples/morning-routine.lua
--   The virtual clock starts at 06:55 and --step fast-forwards through the
--   scheduled times, so you see the morning unfold in the log.

local function main(er)
  local rule = er.eval
  er.opts = { result = true }

  -- 1. A daily rule: fires once a day at 07:00.
  --    @ means "at this time every day" (HH:MM).
  rule("@07:00 => log('Good morning!')")

  -- 2. Only on workdays: date(...) is true inside the given day range.
  --    (2026-06-12 is a Friday.)
  rule("@07:00 & date('* * * mon-fri') => log('Time to get up (workday)')")

  -- 3. Repeating every hour, aligned to the clock: @@-01:00
  rule("@@-01:00 => log('Hourly chime')")

  -- 4. A window guard with a daily: 'first_in' fires only the FIRST time
  --    in the window (07:00..08:00), then resets for the next day.
  er.triggerVars.d = 0
  rule("d == 1 first_in 07:00..08:00 => log('First wake-up event')")

  -- Demo: trigger d once inside the window, and once more — only the
  -- first one passes.
  setTimeout(function() er.triggerVars.d = 1 end, 5 * 60000)   -- 07:00
  setTimeout(function() er.triggerVars.d = 1 end, 20 * 60000)  -- 07:15, ignored

  -- End the demo — the hourly chime never stops on its own.
  setTimeout(function() os.exit(0) end, 75 * 60000)
end

function QuickApp:onInit() fibaro.EventRunner(main) end
