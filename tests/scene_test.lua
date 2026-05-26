--%%name:Named Scene unit tests
--%%headers:EventRunner.inc
--%%offline:true

local PASS, FAIL = 0, 0

local function check(name, got, expected)
  if got == expected then
    PASS = PASS + 1
    print("PASS:", name)
  else
    FAIL = FAIL + 1
    print("FAIL:", name, "  got:", tostring(got), "  expected:", tostring(expected))
  end
end

local function main(er)
  fibaro.ER._testER = er
  local ER = fibaro.ER

  -- ── Mock PropClass with recordable set ──────────────────────────────────
  MockDev = {}
  ER.definePropClass("MockDev")
  function MockDev:__init(name)
    PropObject.__init(self)
    self._name = name
    self._values = {}
  end
  MockDev.getProp.value   = function(self) return self._values.value end
  MockDev.setProp.value   = function(self, prop, val) self._values.value   = val end
  MockDev.getProp.level   = function(self) return self._values.level end
  MockDev.setProp.level   = function(self, prop, val) self._values.level   = val end
  MockDev.getProp.bright  = function(self) return self._values.bright end
  MockDev.setProp.bright  = function(self, prop, val) self._values.bright  = val end

  -- Expose mock devices as VM globals
  local d1 = MockDev("light1")
  local d2 = MockDev("light2")
  local d3 = MockDev("blind")
  ER.defglobals.light1 = d1
  ER.defglobals.light2 = d2
  ER.defglobals.blind  = d3

  local function runRule(rule)
    local got
    rule.onDone = function(v) got = v end
    rule:run()
    return got
  end

  -- ── Test 1: activate-only shorthand ────────────────────────────────────
  er.eval("scene cozy = { light1:value=30, light2:level=50 }")
  local r1 = er.eval("true => cozy:activate")
  r1.verbosity = "silent"
  runRule(r1)
  check("activate-only: light1.value set", d1._values.value, 30)
  check("activate-only: light2.level set", d2._values.level, 50)

  -- ── Test 2: activate + deactivate subsections ──────────────────────────
  d1._values = {}; d2._values = {}
  er.eval([[
    scene movienight = {
      activate:   { light1:value=10, light2:level=20 },
      deactivate: { light1:value=0,  light2:level=0  }
    }
  ]])
  local r2 = er.eval("true => movienight:activate")
  r2.verbosity = "silent"
  runRule(r2)
  check("subsections: activate light1.value", d1._values.value, 10)
  check("subsections: activate light2.level", d2._values.level, 20)

  d1._values = {}; d2._values = {}
  local r3 = er.eval("true => movienight:deactivate")
  r3.verbosity = "silent"
  runRule(r3)
  check("subsections: deactivate light1.value", d1._values.value, 0)
  check("subsections: deactivate light2.level", d2._values.level, 0)

  -- ── Test 3: deactivate on activate-only scene → runtime error ──────────
  er.eval("scene plain = { light1:value=99 }")
  local r4 = er.eval("true => plain:deactivate")
  r4.verbosity = "silent"
  runRule(r4)
  check("deactivate no-body: runtime error", r4._disabled, true)

  -- ── Test 4: expression thunk re-evaluates at activation time ───────────
  ER.defglobals.refLevel = 10
  er.eval("scene dynscene = { light1:bright=refLevel }")
  ER.globals.refLevel = 20    -- change value AFTER scene declaration
  local r5 = er.eval("true => dynscene:activate")
  r5.verbosity = "silent"
  d1._values = {}
  runRule(r5)
  check("thunk: re-evaluates refLevel at activation time", d1._values.bright, 20)

  -- Verify literal is NOT a thunk (directly stored, still correct)
  ER.defglobals.refLevel = 999  -- change again
  d1._values = {}
  er.eval("scene litscene = { light1:bright=42 }")
  local r6 = er.eval("true => litscene:activate")
  r6.verbosity = "silent"
  runRule(r6)
  check("literal: stored directly, not thunk", d1._values.bright, 42)

  -- ── Test 5: deactivate-only subsection order shouldn't matter ──────────
  d1._values = {}; d2._values = {}
  er.eval([[
    scene reversed = {
      deactivate: { light1:value=11 },
      activate:   { light1:value=22 }
    }
  ]])
  local r7 = er.eval("true => reversed:activate")
  r7.verbosity = "silent"
  runRule(r7)
  check("reversed order: activate runs correct block", d1._values.value, 22)

  print(string.format("\n=========== Results: %d passed, %d failed ===========", PASS, FAIL))
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
