# test/run-tests.sh — plua vs flua

What changed in the regression runner (`test/run-tests.sh`) and the test
files it drives, and why, when the suite moved from plua to flua. The plua
version ran green with `plua --fibaro`; the flua version required the
changes below.

## 1. Invocation

```diff
- output=$(plua --fibaro --run-for "$TIMEOUT" "$test_file" 2>&1)
+ FLUA=(flua --api local --nogreet --color never --step --max-hours 24)
+ output=$("${FLUA[@]}" "$test_file" 2>&1)
```

- `plua --fibaro` → `flua --api local` (same role: HC3 emulator, offline).
- `--nogreet --color never` added so log output is greppable (plua output was
  plain by default).
- Per-test `--run-for 15` safety cap **removed**: flua's `--run-for` exits 0
  even when it kills a hung QA (verified), so keeping it would mask hangs as
  passes. Each test still `os.exit()`s via the harness; a hang now fails the
  CI job instead of silently passing.
- `--step --max-hours 24` added — replaces plua's in-QA time
  fast-forward (see #3; flua ≥ 0.1.92).

## 2. Header migration (mechanical, all 28 test files)

```diff
- --%%headers:EventRunner.inc
- --%%file:test/harness.lua,harness
- --%%offline:true
+ --%%include:../../EventRunner.inc
+ --%%file:../../test/harness.lua,harness
+ --%%mode:offline
```

- `--%%headers:EventRunner.inc` → `--%%include:../../EventRunner.inc`.
  On flua 0.1.90 `--%%headers:` was unknown (warned and ignored) and
  `--%%include` anchored its `--%%file` paths to the main QA, so the first
  cut needed a boot-time loader (`er-load.lua`) that walked up to the repo
  root and loaded every module the `.inc` lists. **flua 0.1.91 anchors
  include-declared paths to the include file's own directory**, so the
  include works directly at any depth and `er-load.lua` was deleted.
- Path depths: flua resolves `--%%file`/`--%%include` relative to the
  **declaring file** (plua resolved them cwd-relative). Files in
  `test/expr/` and `test/rules/` use `../../`; files directly in `tests/`
  or `test/` use `../`. Each file's depth is now correct relative to
  itself, and `flua --check` verifies every path (it caught a wrong-depth
  header in `test/_diag.lua` during the rewrite).
- `--%%offline:true` → `--%%mode:offline` (directive spelling).

## 3. Time fast-forward: plua `speedTime` → CLI `--step`

The rules tests that exercise `@`/`@@`/time triggers used plua's built-in
speed library:

```diff
- --%%file:$fibaro.lib.speed,speed     # plua built-in: fibaro.speedTime(hours, fn)
+ --%%file:../../test/speed.lua,speed  # stub: fn() runs, time driven by CLI
```

Behavior difference:

- plua's `fibaro.speedTime(hours, fn)` ran `fn` first, then **fast-forwarded
  the virtual clock deterministically**, firing timers in deadline order.
- flua has no in-QA speedTime. The replacement is the `test/speed.lua` stub
  (whose `speedTime(hours, fn)` just runs `fn()`) plus CLI flags:
  `--step --max-hours 24` (flua ≥ 0.1.92) advances the clock to each timer's
  deadline before its callback runs — the plua semantics, at CPU speed.
- `--instant` was tried first (looks like the natural "no waiting" mode) and
  **breaks ER**: it collapses the timer heap, so `@@` intervals never fire
  and `wait()` fires at the end of the run (reproduced; see
  `docs/flua-feedback.md` #3).
- `--speed 3600` was the interim replacement but its clock runs
  **continuously**, so virtual time passes while test code executes and
  exact-time assertions flake. Two test files were temporarily weakened to
  drift-agnostic assertions; with `--step` the original strict assertions
  were **restored** (`test/expr/time.lua` pins `^12:00$` again;
  `tests/eventrunner_test.lua` compares `ostime()` against `os.time()`, uses
  tight `now..now` windows, and asserts `wait(4)` is exactly 4).
- `test/expr/listcomp.lua`: flua's `json.encode` used to pad arrays with
  spaces (`[2, 4, 6]` vs plua/HC3 `[2,4,6]`), so the test temporarily
  normalized whitespace. flua 0.1.92 emits compact HC3-compatible JSON
  (verified), so the original strict string comparison is restored.
- Runtime: the full regression suite dropped from ~minutes (`--speed 3600`,
  one ~24 s real-time test per time-heavy file) to **~6 s**; the 24 h main
  suite from ~25 s to **0.24 s**.
- `tests/testfuns.lua` needed two counting fixes that `--step` exposed (the
  continuous-clock runs had masked them): `er.eval` calls `opts.onDone` for
  synchronous expressions *in addition to* returning the sync result, so
  every sync test counted twice and drained the completion counter early;
  and rule tests re-fire on every matching event, each decrementing the
  counter. `testExpr` now guards against double completion and `testRule`
  counts only the first `ntest` firings — without these, `os.exit(0)` fired
  at a premature "All tests done" and cut off ~18 async tests.

## 4. Harness (`test/harness.lua`)

Minimal changes — the harness worked as-is:

- Header comment updated (`--%%headers:` usage → `--%%include` usage).
- `log_open()`: unchanged logic; plua and flua both expose the QA name via
  `__TAG` with a trailing device id (`EXPR_ARITHMETIC5555`), which the
  harness strips. Comment only.
- `schedule_exit()`: unchanged (`setTimeout` drain then `os.exit`); the
  "lets plua drain" comment → "lets flua drain". Terminating is now more
  important, not less: flua QAs never self-exit, so a missing `os.exit`
  hangs until the CI timeout.

## 5. Runner script itself

- Flag handling, label printing, per-test log lookup, and the pass/fail
  summary are unchanged.
- `TIMEOUT=15` variable removed along with `--run-for` (see #1).
- The file was not executable; README documents `./test/run-tests.sh`, so
  `chmod +x` was applied.

## What still behaves differently (accepted, by design)

- The suite runs at CPU speed under `--step` (~6 s total, down from
  ~minutes with the interim `--speed 3600`), matching plua's deterministic
  fast-forward behavior instead of wall-clock pacing.
- `test/results/*.log` are git-tracked and change on every run (pre-existing
  in both plua and flua eras; not a flua difference).
