--%%name:expr_time
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true
--%%time:2026/04/28 12:00:00

local function main(er)
  -- Time arithmetic: add/subtract durations
  test_expr(er, "return 10:00 + 00:30", 37800,
    "time add: 10:00 + 00:30 = seconds(10.5h)")

  test_expr(er, "return 12:00 - 10:00", 7200,
    "time sub: 12:00 - 10:00 = 2h in seconds")

  -- Time comparisons
  test_expr(er, "return now > 10:00", true,
    "time compare: now(12:00) > 10:00")

  test_expr(er, "return 14:00 > now", true,
    "time compare: 14:00 > now(12:00)")

  -- now at frozen time ~12:00:00 (may drift 1-2s from --%%time: to eval)
  local n = er.eval("return now")
  assert_truthy(n >= 43200 and n <= 43205,
    "now: ~12:00:00 in range 43200-43205")

  -- HM formatting (use pattern match to ignore seconds drift)
  local hm = er.eval("return HM(now)")
  assert_match(hm, "^12:00$",
    "HM(now): format as HH:MM")

  -- HMS formatting (seconds may have drifted; check pattern)
  local hms = er.eval("return HMS(now)")
  assert_match(hms, "^12:00:%d%d$",
    "HMS(now): format as HH:MM:SS")

  -- wday: April 28 2026 is a Tuesday
  test_expr(er, "return wday('tue')", true,
    "wday: Tuesday")

  test_expr(er, "return wday('mon-fri')", true,
    "wday: weekday (Tue is in mon-fri)")

  test_expr(er, "return wday('sat-sun')", false,
    "wday: not weekend")

  -- Today time constant: t/HH:MM -> epoch for today at that time
  -- t/10:00 on April 28 2026 at 10:00
  local t1000 = er.eval("return t/10:00")
  assert_truthy(type(t1000) == "number" and t1000 > 1e9,
    "t/: returns epoch timestamp")

  -- Next time constant: n/HH:MM -> epoch for next occurrence
  -- n/10:00 when now is 12:00 -> tomorrow at 10:00
  local n1000 = er.eval("return n/10:00")
  assert_truthy(type(n1000) == "number" and n1000 > t1000,
    "n/: returns future epoch (tomorrow 10:00 > today 10:00)")

  -- Relative time: +/01:00 -> epoch 1 hour from now
  local plus1h = er.eval("return +/01:00")
  assert_truthy(type(plus1h) == "number" and plus1h > 1e9,
    "+/: returns epoch timestamp")

  -- uptime is nil in plua offline mode (no HC3 API); just verify it's a number or nil
  local up = er.eval("return uptime")
  assert_truthy(up == nil or (type(up) == "number" and up >= 0),
    "uptime: nil or non-negative")

  -- midnight (epoch of today at 00:00)
  local mid = er.eval("return midnight")
  assert_truthy(type(mid) == "number" and mid < t1000,
    "midnight: epoch before t/10:00")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
