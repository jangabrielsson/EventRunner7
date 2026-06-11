-- test/harness.lua — Shared test utilities for the regression suite.
--
-- Each test file is a standalone QuickApp that runs one test and calls
-- os.exit(0) on success or os.exit(1) on failure.  Separate files per
-- test case ensure rules never interfere between tests.
--
-- Assertion output is written to stdout AND to a log file derived from
-- the QuickApp name (--%%name:expr_arithmetic → test/results/expr_arithmetic.log).
--
-- Usage in a test file:
--   --%%headers:EventRunner.inc
--   --%%file:test/harness.lua,harness
--
--   local function main(er)
--     local got = er.eval("return 3 + 4")
--     assert_eq(got, 7, "3+4")
--     done()   -- schedules os.exit(0) after timer drain
--   end
--
--   function QuickApp:onInit() fibaro.EventRunner(main) end

local PASS, FAIL = 0, 0
local pending = 0
local log_file = nil

-- ── Logging ────────────────────────────────────────────────────────────────

local function log_open()
  if log_file then return end
  local tag = rawget(_G, "__TAG") or "unknown_test"
  -- Strip trailing device ID that plua appends ("EXPR_ARITHMETIC5555" → "EXPR_ARITHMETIC")
  local name = tag:match("^(.-)%d+$") or tag
  local path = "test/results/" .. name:lower() .. ".log"
  log_file = io.open(path, "w")
  -- If test/results/ doesn't exist the open fails silently; the runner
  -- script creates it before running tests.
  if log_file then
    log_file:write("=== " .. tag .. " ===\n\n")
  end
end

local function log_write(line)
  log_open()
  print(line)
  if log_file then log_file:write(line .. "\n") end
end

local function log_summary()
  local summary
  if FAIL > 0 then
    summary = string.format("\n  %d passed, %d FAILED", PASS, FAIL)
  else
    summary = string.format("\n  %d passed", PASS)
  end
  print(summary)
  if log_file then
    log_file:write(summary .. "\n")
    log_file:close()
  end
end

-- ── Assertions ─────────────────────────────────────────────────────────────

function assert_eq(actual, expected, msg)
  if actual == expected then
    PASS = PASS + 1
    log_write("  PASS: " .. (msg or "(no description)"))
  else
    FAIL = FAIL + 1
    log_write("  FAIL: " .. (msg or "(no description)"))
    log_write("    expected: " .. tostring(expected))
    log_write("    got:      " .. tostring(actual))
  end
end

function assert_neq(actual, unexpected, msg)
  if actual ~= unexpected then
    PASS = PASS + 1
    log_write("  PASS: " .. (msg or "(no description)"))
  else
    FAIL = FAIL + 1
    log_write("  FAIL: " .. (msg or "(no description)"))
    log_write("    expected not: " .. tostring(unexpected))
    log_write("    got:          " .. tostring(actual))
  end
end

function assert_truthy(value, msg)
  if value then
    PASS = PASS + 1
    log_write("  PASS: " .. (msg or "(no description)"))
  else
    FAIL = FAIL + 1
    log_write("  FAIL: " .. (msg or "(no description)"))
    log_write("    expected truthy, got: " .. tostring(value))
  end
end

function assert_match(str, pattern, msg)
  if type(str) == "string" and str:match(pattern) then
    PASS = PASS + 1
    log_write("  PASS: " .. (msg or "(no description)"))
  else
    FAIL = FAIL + 1
    log_write("  FAIL: " .. (msg or "(no description)"))
    log_write("    pattern: " .. tostring(pattern))
    log_write("    string:  " .. tostring(str))
  end
end

-- ── Test helpers ───────────────────────────────────────────────────────────

-- Evaluate a synchronous expression and assert its return value.
-- src is full EventScript: "return 3 + 4", "x = 5; return x", etc.
function test_expr(er, src, expected, msg)
  local got = er.eval(src)
  assert_eq(got, expected, msg or src)
end

-- Register a rule, trigger it, and assert the action's return value.
-- fire_fn(er, rule) is called after registration to trigger the rule.
-- The assertion runs inside rule.onDone after the action completes.
function test_rule(er, src, fire_fn, expected, msg)
  pending = pending + 1
  local rule = er.eval(src)
  rule.verbosity = "silent"
  rule.onDone = function(v)
    if type(expected) == "function" then
      assert_truthy(expected(v), msg or src)
    else
      assert_eq(v, expected, msg or src)
    end
    pending = pending - 1
    if pending == 0 then
      schedule_exit()
    end
  end
  fire_fn(er, rule)
end

-- Register an async rule (contains wait()), trigger it, assert on completion.
-- Same as test_rule but the assertion already runs inside onDone after timers drain.
test_async = test_rule  -- identical pattern: onDone fires after all waits resolve

-- ── Termination ────────────────────────────────────────────────────────────

local exit_scheduled = false

function schedule_exit()
  if exit_scheduled then return end
  exit_scheduled = true
  -- Brief delay lets plua drain any pending timers before exit.
  setTimeout(function()
    log_summary()
    os.exit(FAIL > 0 and 1 or 0)
  end, 50)
end

-- Call at the end of every test file.  For expression tests (synchronous),
-- this schedules immediate exit.  For rule tests, done() is called inside
-- the last onDone callback, after all async actions complete.
function done()
  if pending == 0 then
    schedule_exit()
  end
  -- else: test_rule will call schedule_exit when pending drops to 0
end
