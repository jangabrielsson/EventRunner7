--%%name:Door alert
--%%include:../EventRunner.inc
--%%file:../src/Sim.lua,sim
--%%file:../src/Setup.lua,stdfuns
--%%mode:offline
--%%time:2026/06/12 12:00:00

-- EventRunner7 example: variables, since/debounce, and errors.
--
--   Run:    flua --api local --step examples/door-alert.lua
--   Watch:  the demo opens the door for a long time (since fires), bangs
--           the keypad (debounce collapses it), and a broken rule shows
--           the friendly error format + auto-disable.

local function main(er)
  local rule = er.eval

  local door = er.loadSimDevice("doorSensor")
  er.defvars({ door = door })

  er.opts = { result = true, check = true }

  -- 1. 'since': only alert when the door has been open for a CONTINUOUS
  --    2 minutes (a draft won't trigger it).
  rule("door:isOpen since 2min => log('Door open for 2 minutes!')")

  -- 2. 'debounce': wait for 5 s of silence after the LAST keypress.
  er.triggerVars.keypress = 0
  rule("keypress == 1 debounce 5s => log('Keypad settled')")

  -- 3. A rule with a bug: 'temperatur' is misspelled. When it fires, the
  --    error names the variable, points at the position, and disables the
  --    rule (disableOnError default) so it doesn't spam the log.
  rule("door:isOpen => log('Inside temp: %d', temperatur)")

  -- ── Demo driver ─────────────────────────────────────────────────────────
  local function open() fibaro.call(door, 'breached', true) end
  local function close() fibaro.call(door, 'breached', false) end

  open()                                    -- starts the since window
  setTimeout(close, 60000)                  -- closed after 1 min: no alert
  setTimeout(open, 120000)                  -- open again at +2min
  setTimeout(function()
    -- keypad banging: 3 presses in a row — only the last one counts
    er.triggerVars.keypress = 1
    er.triggerVars.keypress = 1
    er.triggerVars.keypress = 1
  end, 130000)
end

function QuickApp:onInit() fibaro.EventRunner(main) end
