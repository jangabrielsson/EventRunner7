# Changelog

## [v0.2.4] - 2026-10-30

## Changes in v0.2.4

- ✨ **Feature**: add release notes for v0.2.3 with forum post helper and styling
- 🐛 **Fix**: move the rules-status UI handler into Rule.lua for QA Updater compatibility
  - The QA Updater ships module files but not the user's main QA file, so the
  - handler and the auto-refresh hook now live in Rule.lua (QuickApp:refreshRules
  - + ER._statusHook via a self-action fibaro.call(plugin.mainDeviceId, ...),
  - the same dispatch postRemote uses). Only the %%u rows stay in the main
  - file — flua/HC3 read UI directives exclusively from the QA's own header,
  - so they cannot be moved (verified empirically: module %%u rows are
  - ignored). Existing installs keep their rows; the updater can now ship
  - future status-UI changes.


*Generated automatically from git commits*

## [v0.2.3] - 2026-10-30

## Changes in v0.2.3

- ✨ **Feature**: initialize SimQuickApp class for simulation functionality
- 🐛 **Fix**: ruleError was a global nil in yield handlers (user-reported)
  - The yieldHandlers closures (sleep/asyncFun/sinceGate resume paths)
  - referenced ruleError before its local declaration, so Lua bound it as a
  - global → 'attempt to call a nil value (global ruleError)' in timer
  - handlers whenever a resumed continuation threw (e.g. wait(0.1);
  - throw('boom')). Forward-declared the local before the table.
  - Regression test: wait+throw reaches the error policy (disables, records
  - lastError) instead of crashing the timer handler.
- ✨ **Feature**: add SKILL.md for plua to flua migration checklist and compatibility matrix


*Generated automatically from git commits*

## [v0.2.2] - 2026-10-29

## Changes in v0.2.2

- 🐛 **Fix**: wire the refresh button to QuickApp:refresh
  - the %%u row now declares onReleased='refresh' and the handler is a
  - QuickApp:refresh method (HC3 UI contract), replacing the UIEvent
  - dispatch function
- 📚 **Docs**: user-facing forum post for v0.2.1
  - friendlier than the commit-log changelog: what users see (talkative
  - errors with positions and did-you-mean, the Rules status view in the app
  - UI, when..then and duration-literal syntax, trigger lists in the user's
  - own words, example projects) and the list-filter fix


*Generated automatically from git commits*

## [v0.2.1] - 2026-10-29

## Changes in v0.2.1

- ✨ **Feature**: examples: three runnable, commented example QAs
  - motion-lights (the classic rule + window guards + cooldown + counters),
  - morning-routine (daily/weekday/hourly/first_in), door-alert (since/
  - debounce + the friendly error format demo). Each runs offline with
  - simulated devices and a demo driver; README explains how to run and
  - where to go next.
- 🧪 **Test**: strict runner + repair long-broken false-green tests
  - run-tests.sh now requires at least one PASS line: a test that dies in
  - main() and exits 0 on idle no longer passes. This exposed 9 false
  - greens, all repaired:
  - device_triggers/expr_devices: include Setup.lua (er.defvars); the
  - chain test asserts only on the final completion value
  - global_vars (expr+rules): include Sim.lua; expectations updated for
  - marshalled GV values (numbers/bools, not raw strings); condition-fail
  - sentinel is fibaro.ER.ruleFail, not a field
  - custom-event tests (events, event_routing, groups): post {type='X'}
  - — the '#X' syntax subscribes to {type='X'}, not {type='event',name='X'}
  - recompile: sim devices are numeric ids (no .id), setValue via fibaro.call
  - modifier_every stub removed — 'every' behavior is covered by
  - modifier_gates.lua
  - binarySwitch sim gains a toggle action (devices.lua uses it)
- 🐛 **Fix**: list filters (allTrue/allFalse/someTrue/...) operate on device values
  - The propFilters branch passed raw device ids to the filters, so any
  - list of ids was always all-truthy (allTrue always true). Now resolves
  - each element to its device value first — only falling back to the raw
  - element when the resolution is nil (false values must survive).
- ✨ **Feature**: rules-status view in the QA UI
  - ER.ruleStatusText(): one-line-per-rule summary (name, enabled/disabled,
  - in-flight count, last error, human-readable trigger list) joined with
  - </br> for HC3 labels
  - rules record rule.lastError on runtime errors (reset by enable()/
  - recompile()); ER._statusHook fires on completions and errors so the UI
  - can update live without ER knowing about UI
  - EventRunner7.lua: status label + 🔄 Rules button, refreshed at boot, on
  - button press, and via the hook; trigger dump refactored into
  - rule:triggerLines() shared by dumpTriggers/info()/the status view
  - Test: status_text (summary contents, hook on completion)
- ✨ **Feature**: when..then rule sugar and duration literals
  - 'when cond then action' parses as the same rule as 'cond => action',
  - with modifiers between (when d == 1 since 2min then ...). 'when' is
  - not reserved: the parser speculates and falls back, so 'when' still
  - works as a variable name. Modifier parsing refactored into
  - parseModifiers/mkRuleNode, shared by both rule forms.
  - duration literals in the tokenizer: 5s / 30sec / 5min / 2h / 2hr / 1d
  - → seconds (Lua patterns have no alternation — one rule per unit with
  - a %f[%A] boundary so '30mins' still fails cleanly)
  - docs: RULES.md and EventScript.md cover both
  - Tests: when_sugar (both forms, modifier+duration, 'when' as variable),
  - duration arithmetic in expr/time
- ✨ **Feature**: human-readable trigger descriptions in rule logs
  - scanHead stamps each trigger with the source span the user wrote
  - (trs.srcs), quoted instead of reverse-resolving ids — so lists,
  - ambiguous bindings and overlapping resource types all work
  - dumpTriggers/info()/startup logs now read:
  - '⚡ doorSensor:breached → #device{"id":42,...}',
  - '⚡ myLamps:isOn → #device{...}' (one span, several devices),
  - '🕒 @23:00 → 23:00:00'
  - parser spans fixed so GETPROP/BETW/DAILY/INTERV nodes cover the whole
  - expression (were: property name / operator token / nothing)
  - docs: '--' end-of-line comments documented in RULES.md and EventScript.md
- ✨ **Feature**: perf: flatten nested PROGNs at CSP compile time
  - compile() now expands nested PROGN children and collapses single-element
  - sequences — one trampoline hop per nesting level saved, and --trace dumps
  - are flat. Fixes the nested PROGNs the debounce action prefix introduced
  - (PROGN(YIELD, PROGN(...))) and any future manual wrappers; removes the
  - now-obsolete checkProgn debug hook.
  - Constant folding deliberately NOT done: negligible win on an event-driven
  - workload vs. real risk of coercion/subtle-semantics drift. Revisit only
  - with measurements (test/speed.lua).
- ✨ **Feature**: registration errors now carry a source position
  - scanHead errors (head-purity violations, unknown ops/yields, bad
  - properties) annotate with ' at line L, col C' + source + caret, using
  - the srcmap that is still alive during the scan (compRule sets
  - trs.src/trs.srcmap; csp.compile consumes it afterwards). Same shape as
  - parse and runtime errors.
  - Test: registration error position (col 1 of the offending call)
- ✨ **Feature**: did-you-mean suggestions in rule/registration errors
  - unknown head function: nearest whitelist match ('did you mean fmt?') or
  - specific guidance for known side-effecting builtins ('post() posts
  - events; move it into the action')
  - GETPROP no-such-property: nearest real property name, both at
  - registration (scanHead) and at runtime (getProp)
  - Tests: typo suggestion, impure-builtin hint, property typo (sim device)
- ✨ **Feature**: friendly-message translation for common runtime errors
  - vm.host.hintError hook: the CSP enrichment runs host translations, so
  - every path (rules, expressions, direct vm.eval) gets hinted messages
  - 'Undefined variable: x' → 'Variable x is not defined — misspelled, or
  - forgot to define it? (er.triggerVars.x, er.defglobals.x, or a rule
  - assignment)'
  - common 'attempt to ...' Lua errors get guidance appended (index nil,
  - call nil, arithmetic/compare nil, concatenate table)
  - eval returns the hinted message as its (nil, errmsg) status
  - Tests: updated undefined-var expectations; arithmetic-nil hint case
- ✨ **Feature**: unified runtime error format; throw() now works
  - one error shape everywhere: 'msg at line L, col C' + source line +
  - caret (ER.sourceAnnotation in Tokenizer; vm.host.formatSource uses it),
  - so parse and runtime errors read alike
  - the rule layer no longer appends a duplicated 'src:' tail: fmtErr adds
  - the source only when the message has no annotation (registration and
  - internal errors); CSP-enriched messages pass through verbatim
  - throw(value) compiles to the THROW instruction (was never wired up —
  - 'Undefined variable: throw'); non-string thrown values (tables) are
  - serialized via the new vm.host.formatError hook
  - async function timeout now logs at normal instead of verbose
  - Tests: errors.lua throw cases now assert the caret and genuinely match
  - the thrown value; new unified-format checks (names the variable, position
  - annotation, no duplicated src tail)
- ♻️ **Refactor**: comment out debug print statements in checkProgn function
- 📚 **Docs**: EventScript_debug — info() active line, registration failures, disableOnError
  - new section covers head-purity registration errors, eval's nil+err return
  - (and {throw=true}), and the disableOnError runtime error policy with
  - rule.enable() reset; info() samples note rule:state() and rule.active
- 📚 **Docs**: update ARCHITECTURE.md for the rule-layer rework
  - module line counts refreshed
  - rule lifecycle rewritten: structured modifiers + gate chain, execution
  - env + generation guard, lifecycle API (state/active/recompile), and the
  - disableOnError error policy
  - trigger scanning table: CALL whitelist + YIELD sinceGate; extension
  - points: ER._headFuns, disableOnError; links to docs/reviews/


*Generated automatically from git commits*

## [v0.2.0] - 2026-10-28

## Changes in v0.2.0

- ✨ **Feature**: release: add flua --check to the release gate (step 3.5)
- 📚 **Docs**: fix stale flua-feedback reference in run-tests-migration
- 📚 **Docs**: move flua feedback notes into docs/reviews/
- 📚 **Docs**: move evolution and test-migration notes into docs/reviews/
- 📚 **Docs**: move reviews into docs/reviews/
- 📚 **Docs**: close the rule-layer review — resolution summary
  - all eight findings implemented or accepted; records the follow-up work
  - (modifier combination enforcement, rule:recompile(), interval lifecycle,
  - async watchdog protocol, doc updates). Test net: 27 → 38.
- 🐛 **Fix**: interval scheduler survives single; stops on disable, restarts on enable
  - regression (from the recompile commit): the interval timer was tracked
  - in rule.timers, so single's killTimers cancelled the scheduler after
  - the first fire. It is untracked again; disable()/terminate()/recompile()
  - cancel it explicitly via rule._intervalTimer.
  - disable() stops the interval scheduler (a disabled rule consumes no
  - timers); enable() restarts it — clock-aligned intervals resume at the
  - next boundary, relative intervals restart from enable time.
  - fix a latent crash from the compRule split: rule.dailys was only set
  - for daily rules, so dumpTriggers errored at registration for
  - interval-only rules (eval returned nil while the scheduler kept
  - running — time_triggers masked it by never using the returned rule)
  - Tests: interval_single (regression), interval_disable (stop/restart)
- ✨ **Feature**: rule:recompile() rebinds a rule in place
  - subscriptions are now stored on the rule (rule.subs) and the interval
  - timer is tracked via rule.setTimeoutR, so terminate()/recompile() can
  - cancel it (terminate() previously did not stop interval rules)
  - recompile(): rebuilds parse/compile/scan from rule.src first (a broken
  - source leaves the old binding running), then tears down (killTimers,
  - unsubscribe, reset _mstate/trueFor/failCount/stats) and re-registers on
  - the same rule object
  - RULES.md: recompile documented in the binding section and the rule
  - object method list
  - Test: recompile — dID rebound from one sim device to another; old device
  - stops firing, new one fires
- 📚 **Docs**: EventScript modifier section — composition rule, cooldown timing note, rejected combinations
  - cooldown: counted from when the condition passed, not action completion
  - since: 'same logic as trueFor' instead of 'alias'
  - composing paragraph points to the RULES.md combination table and the
  - two parser-rejected combinations
- 📚 **Docs**: update AST_Format for the structured modifiers and gate chain
  - RULE modifier table: {single, debounce, modifiers=[{since/cooldown/every/first_in,...}]}
  - instead of parser desugaring
  - YIELD node: {'YIELD', tag, ...} — documents the sinceGate tag alongside sleep
  - rule compilation: IF(CFUN(_ruleCondition, gate_chain), ...) with the
  - per-gate compilation and state-home table
- ✨ **Feature**: parser rejects bad modifier combinations at registration
  - duplicate modifiers (cooldown 3 cooldown 5, since 5 since 10, ...)
  - error: gates share one state slot and behave unexpectedly
  - single + first_in errors (debounce implies single, so it is caught too):
  - single cancels the window-end reset timer and the once flag sticks
  - RULES.md combination table updated to 'registration error'.
  - Tests: four new cases in expr/errors.lua (duplicate, both orders of
  - single/first_in, debounce/first_in)
- 📚 **Docs**: modifier combination semantics table with flagged combinations
  - documents left-to-right gate composition and that single/debounce are
  - rule-level (position-independent)
  - flags: cooldown+every and first_in+every/cooldown as order-sensitive,
  - since+debounce and debounce+cooldown as surprising
  - not recommended (verified empirically): single+first_in (reset timer
  - cancelled by killTimers), duplicate modifiers sharing one state slot
  - (cooldown 3 cooldown 5 never fires; since 5 since 10 fires after 15s)
- ♻️ **Refactor**: first-class modifier pipeline replaces parser AST rewrites
  - Parser emits structured modifiers (node[4].modifiers) instead of
  - rewriting since/cooldown/every/first_in into function calls
  - Compiler builds an explicit gate chain: since → YIELD 'sinceGate',
  - cooldown/every/first_in → CFUN gates, debounce → wait(T) action prefix
  - Gate cores live in Rule.lua with state in one home (rule._mstate /
  - rule.trueFor); the public async functions (trueFor, cool_down,
  - every_other, first_in_win) delegate to the same cores
  - scanHead: HOPS.YIELD accepts only the sinceGate tag — wait/sleep in
  - a head now errors clearly instead of the generic op assert
  - Tests: modifier_gates — behavioral (since suspends, cooldown/every
  - suppress, first_in fires once per window and resets at window end)
- 🐛 **Fix**: since windows no longer carry a 30-day async watchdog
  - asyncFun protocol gains an explicit no-watchdog state: (true, false)
  - = async, function owns its timers and promises to call cb
  - (protocol documented at the handler)
  - trueFor returns (true, false): the since timer is the only timer, so
  - windows of any length (> 30 days) can no longer be resumed mid-window
  - killTimers resets rule.active: cancelled runs are dead
  - Test: since_long (31-day window: exactly one timer holding the full window)
- ♻️ **Refactor**: split compRule into lifecycle builders; add rule:state()
  - newRule, attachRun, mkEvVars, setupTriggers, setupInterval,
  - setupDailys, defineRuleAPI replace the compRule god-function
  - rule:state() accessor ('enabled'/'disabled') and rule.active
  - in-flight run counter (surfaced by info())
  - fix latent crash: daily-recalc loop now guards interval-only rules,
  - which never get a setupDaily method
  - Test: lifecycle
- ♻️ **Refactor**: share one logger between rules and expression contexts
  - makeLogger(obj, nameFn) installs obj:log with verbosity gating and
  - error-log enrichment; rule:log and makeExprCtx:log were duplicated.
  - Preserves rule.verbosity field gating and table-valued log args.
- ✨ **Feature**: configurable disableOnError policy for rule runtime errors
  - true (default): disable on first error (unchanged behavior)
  - N: disable after N consecutive errored runs; clean completions
  - (condition false, or action finishes) reset the counter
  - false: never disable, just log
  - rule.enable() re-enables and resets the counter
  - er.eval returns (nil, errmsg) on failure so callers can distinguish
  - failed from async/suspended (plain nil)
  - Test: error_policy (threshold, reset, never-disable, enable-reset, eval status)
- 📚 **Docs**: document rule-head binding, purity whitelist and daily dedup
- ✨ **Feature**: enforce rule-head purity and fix rule timer lifecycle
  - Head-purity whitelist:
  - ER._headFuns: side-effecting or unknown functions in rule conditions are
  - now registration errors; log() is the sanctioned debug exception
  - clear error messages for unknown head ops
  - Timer lifecycle fixes:
  - single/terminate no longer wedge pending 'since' windows (trueFor ref
  - validated against the timer registry; state reset in killTimers)
  - async watchdogs tracked in rule.timers so killTimers cancels them
  - run-generation guard discards callbacks from superseded runs
  - ExecutionEnv seam:
  - async functions receive cb.env (rule/event/setTimeout/cancel/post);
  - modifiers no longer reach into CSP snapshots and var frames
  - Tests: head_purity, since_single, async_cancel (errors.lua updated)
- ✨ **Feature**: chore: stop tracking __pycache__ under .github/skills
- ✨ **Feature**: chore: add .codewhale to .gitignore
- ✨ **Feature**: chore: stop tracking test run logs
- 📚 **Docs**: add flua migration feedback and runner notes
  - flua-feedback_from_eventrunner7.md records where flua behavior cost
  - time during the migration (path resolution, --instant/--speed
  - clock semantics, --run-for, json.encode) and their resolutions
  - across 0.1.91-0.1.97. run-tests-migration.md documents the runner
  - differences between plua and flua and the fixes they required.
- ♻️ **Refactor**: migrate from plua to flua
  - test QAs: --%%headers -> --%%include (declaring-file relative,
  - flua >= 0.1.91); the er-load.lua boot-loader workaround is gone
  - remove plua directives from EventRunner7.lua; $fibaro.lib.speed
  -> test/speed.lua stub with the CLI driving virtual time
  - runner on --step (plua speedTime semantics): deterministic clock,
  - strict time assertions restored, regression 28/28 in ~6 s
  - fix what the migration surfaced: hvacSystemAuto as a Sim_ class,
  - isDead set reduce, device-suite once()/trueFor choreography,
  - testfuns completion counting, compact json.encode expectations
  - mark ER's midnight loop as housekeeping (_FLUA.background) so
  --run-for exits when idle
  - er script: flua --step, no repo-root cwd dependency
  - skills, docs and .luarc.json updated for flua
- ✨ **Feature**: update documentation and scripts for flua integration
- ✨ **Feature**: switched to flua development tool feat: add HC3 REST API and Fibaro API support in Lua feat: implement global fibaro API methods for device management chore: configure Lua language server settings and diagnostics chore: update VSCode launch configurations for flua debugging chore: add task for uploading files to HC3 docs: create AGENTS.md for AI agent guidance in QuickApp development fix: correct EventRunner7 header and save directive fix: improve time handling in rule processing refactor: enhance utility functions for table manipulation
- ✨ **Feature**: Add Fibaro Lua annotations and EventRunner Agent documentation
  - Introduced a new Lua file with comprehensive annotations for the Fibaro API, detailing functions for device management, API calls, and logging.
  - Added a draft specification for the EventRunner Agent, outlining its purpose, architecture, components, and design principles for converting plain-English automation requests into validated EventRunner rules.
  - Created release notes for version 0.1.50, highlighting new features and download links.
  - Implemented a new HTTP client function in Setup.lua for asynchronous API calls to the Fibaro HC3, supporting GET, POST, PUT, and DELETE methods.


*Generated automatically from git commits*

## [v0.1.50] - 2026-08-14

## Changes in v0.1.50

- ✨ **Feature**: Add release notes for v0.1.49 and enhance trueFor watchdog timeout handling


*Generated automatically from git commits*

## [v0.1.49] - 2026-07-25

## Changes in v0.1.49

- ✨ **Feature**: Add release notes for v0.1.48 and enhance NodeRed integration
  - Created HTML release notes for version 0.1.48, detailing changes and download links.
  - Updated Rule.lua to improve timer management by introducing a separate killTimers function.
  - Changed variable name from 'vnum' to 'wnum' in Rule.lua for clarity.
  - Implemented functions in Setup.lua for NodeRed support, including asynchronous posting and IP address retrieval.
  - Added basic authorization and URL encoding functions in Utils.lua for improved HTTP request handling.


*Generated automatically from git commits*

## [v0.1.48] - 2026-06-30

## Changes in v0.1.48

- ✨ **Feature**: Add release notes for v0.1.47 and update Rule.lua for variable naming
  - Created HTML release notes for version 0.1.47, detailing changes and download links.
  - Updated Rule.lua to improve timer management by introducing a separate killTimers function.
  - Changed variable name from 'vnum' to 'wnum' in Rule.lua for clarity.


*Generated automatically from git commits*

## [v0.1.47] - 2026-06-26

## Changes in v0.1.47

- ✨ **Feature**: Add release notes for v0.1.46 and update Rule.lua for variable naming
  - Created release notes for EventRunner7 v0.1.46, detailing new features and fixes.
  - Updated Props.lua to set the push method to 'simplePush'.
  - Changed variable name from 'vnum' to 'wnum' in Rule.lua for clarity.


*Generated automatically from git commits*

## [v0.1.46] - 2026-06-26

## Changes in v0.1.46

- ✨ **Feature**: Add release notes for v0.1.45 and update Props.lua for push method
  - Created release notes for EventRunner7 v0.1.45, detailing new features and fixes.
  - Introduced sun-related functions in EventScript parser and compiler.
  - Added support for substitution templates with new format.
  - Updated Props.lua to set the push method to 'simplePush'.


*Generated automatically from git commits*

## [v0.1.45] - 2026-06-14

## Changes in v0.1.45

- 🐛 **Fix**: correct loop index for rule execution in event handling
- ✨ **Feature**: Enhance EventScript parser and compiler with sun-related functions
  - Added `SUNNEXT` function to the compiler for calculating the next sunrise/sunset time.
  - Updated the parser to recognize `sunrise`, `sunset`, `dawn`, and `dusk` as valid unary expressions.
  - Implemented `sunnext` function in ScriptFuns for calculating sunrise/sunset times with optional offsets.
  - Refactored time handling in Utils to support new sun-related time calculations.
  - Updated Tokenizer to include new keywords for sun-related functions.
  - Adjusted test ground to reflect changes in time handling and added tests for new features.
- ✨ **Feature**: introduce substitution templates with new format
  - Added support for substitution templates using {{var}} placeholders.
  - Implemented Templates.registerSimple() for easy registration of substitution-based templates.
  - Updated the motionLight template to be available in the new substitution format as _motionLight.
  - Enhanced documentation in Templates.md to explain the new template format and its usage.
  - Created a diagnostic test (_subst_diag) to validate the functionality of the new substitution templates.
- ✨ **Feature**: add release notes for v0.1.44 with forum post helper


*Generated automatically from git commits*

## [v0.1.44] - 2026-06-13

## Changes in v0.1.44

- 🐛 **Fix**: update paths for version files and release artifacts in project config
- ✨ **Feature**: add global variable handling tests for expressions and rules
- ✨ **Feature**: add catchup diagnostics and time handling improvements


*Generated automatically from git commits*

## [v0.1.43] - 2026-06-12

## Changes in v0.1.43

- ✨ **Feature**: Fix script execution for regression tests in create-release.sh
  - Changed the execution command for the regression tests from `./test/run-tests.sh` to `bash ./test/run-tests.sh` to ensure compatibility across different environments. This change prevents potential issues with script execution permissions and improves the reliability of the release process.
- ✨ **Feature**: add IR versioning and compatibility checks in CSP VM
- ✨ **Feature**: add regression tests step to release process
- ✨ **Feature**: Refactor code structure for improved readability and maintainability
- ✨ **Feature**: add variable operand tests and error handling tests
- ✨ **Feature**: add tests for case statement and table field addition
- ✨ **Feature**: Add regression tests and implement new rule functionalities
  - Introduced various expression tests covering arithmetic, comparison, control structures, functions, lambda expressions, list comprehensions, logical operations, tables, time handling, and variable manipulations.
  - Added rule tests for async waiting, cooldown modifiers, debounce functionality, single trigger handling, and custom events.
  - Enhanced test runner script to facilitate running tests with options for verbosity and cleaning old logs.
  - Updated paths for Lua files in tests to reflect new directory structure.
  - Ensured all new tests pass successfully, contributing to improved code coverage and reliability.


*Generated automatically from git commits*

## [v0.1.42] - 2026-06-12

## Changes in v0.1.42

- ✨ **Feature**: add IR versioning and compatibility checks in CSP VM
- ✨ **Feature**: add regression tests step to release process
- ✨ **Feature**: Refactor code structure for improved readability and maintainability
- ✨ **Feature**: add variable operand tests and error handling tests
- ✨ **Feature**: add tests for case statement and table field addition
- ✨ **Feature**: Add regression tests and implement new rule functionalities
  - Introduced various expression tests covering arithmetic, comparison, control structures, functions, lambda expressions, list comprehensions, logical operations, tables, time handling, and variable manipulations.
  - Added rule tests for async waiting, cooldown modifiers, debounce functionality, single trigger handling, and custom events.
  - Enhanced test runner script to facilitate running tests with options for verbosity and cleaning old logs.
  - Updated paths for Lua files in tests to reflect new directory structure.
  - Ensured all new tests pass successfully, contributing to improved code coverage and reliability.


*Generated automatically from git commits*

## [v0.1.41] - 2026-06-09

## Changes in v0.1.41

- ✨ **Feature**: Add release notes for v0.1.40 and new test files
  - Created HTML release notes for EventRunner7 v0.1.40 with styling and copy functionality.
  - Added a new Lua test file (plua.lua) to define the QuickApp initialization and update view.
  - Introduced a new Lua rules file (plua_rules.lua) for testing purposes with a simple logging rule.


*Generated automatically from git commits*

## [v0.1.40] - 2026-06-08

## Changes in v0.1.40

- ✨ **Feature**: add release v0.1.39 forum post helper with styling and copy functionality
- 🐛 **Fix**: comment out debug print statements in QuickApp functions


*Generated automatically from git commits*

## [v0.1.39] - 2026-06-08

## Changes in v0.1.39

- ✨ **Feature**: add forum post helper for release v0.1.38 with styling and copy functionality


*Generated automatically from git commits*

## [v0.1.38] - 2026-06-08

## Changes in v0.1.38

- ✨ **Feature**: Refactor code structure for improved readability and maintainability
- 🐛 **Fix**: correct async action wait time unit and enhance logging in Utils
- ✨ **Feature**: add forum post helper for release v0.1.37 with enhanced styling and copy functionality


*Generated automatically from git commits*

## [v0.1.37] - 2026-06-08

## Changes in v0.1.37

- ✨ **Feature**: enhance logging options for rule conditions with detailed filtering capabilities
- ✨ **Feature**: Add EventScript Templates documentation and unit tests
  - Introduced a comprehensive documentation for EventScript Templates, detailing usage, API reference, and template descriptions.
  - Added a new test suite for the Templates module, covering various scenarios including validation, rule generation, and edge cases.
  - Implemented mock evaluation for testing template application and capturing generated rules.
- ✨ **Feature**: add Sim_rollerShutter to Lua diagnostics globals and update tutorial structure for clarity
- ✨ **Feature**: Refactor code structure for improved readability and maintainability
- ✨ **Feature**: add forum post helper for release v0.1.36 and update list comprehension rule


*Generated automatically from git commits*

## [v0.1.36] - 2026-06-03

## Changes in v0.1.36

- ✨ **Feature**: enhance argument beautification in logging and update list comprehension test cases


*Generated automatically from git commits*

## [v0.1.35] - 2026-06-03

## Changes in v0.1.35

- ✨ **Feature**: implement list comprehension parsing and update related test case
- ✨ **Feature**: update skills path and enhance formatSource function return value
- 🐛 **Fix**: enhance comparison operations to handle custom string representations
- ✨ **Feature**: Refactor CSP documentation and update test scripts
  - Enhanced CSP README.md to clarify the IR contract, context model, and variable environment.
  - Added details on the execution context and variable lookup order.
  - Updated opcode taxonomy and core opcodes sections for better clarity.
  - Commented out profiling code in eventrunner_test.lua to disable profiling during tests.
  - Commented out variable initialization and rule definitions in eventrunner_testground.lua for cleaner test execution.
- ✨ **Feature**: add Daily event descriptor and test for factorial function


*Generated automatically from git commits*

## [v0.1.34] - 2026-05-29

## Changes in v0.1.34

- ✨ **Feature**: add environment variable to compRule function for event handling
- ✨ **Feature**: Add logo image to the documentation
- 📚 **Docs**: update list comprehension syntax and grammar explanations in EventScript documentation
- ✨ **Feature**: Add release notes for EventRunner7 v0.1.33 with download links and logging feature details


*Generated automatically from git commits*

## [v0.1.33] - 2026-05-29

## Changes in v0.1.33

- ✨ **Feature**: add error and warning logging functions; update tests for appPhone device


*Generated automatically from git commits*

## [v0.1.32] - 2026-05-29

## Changes in v0.1.32

- ✨ **Feature**: update DAILY function to check event type and add roller shutter simulation


*Generated automatically from git commits*

## [v0.1.31] - 2026-05-28

## Changes in v0.1.31

- ✨ **Feature**: Add release notes for EventRunner7 v0.1.30 with download links and documentation


*Generated automatically from git commits*

## [v0.1.30] - 2026-05-28

## Changes in v0.1.30

- ✨ **Feature**: Add release notes for EventRunner7 v0.1.29 and update test scripts
  - Created a new HTML file for the forum post of EventRunner7 v0.1.29, detailing changes, download links, and documentation.
  - Refactored the eventrunner_testground.lua script to simplify variable handling and removed commented-out code for clarity.
  - Updated eventrunner_testground2.lua to define devices more clearly and adjusted the simulation time handling.


*Generated automatically from git commits*

## [v0.1.29] - 2026-05-28

## Changes in v0.1.29

- ♻️ **Refactor**: rename 'restart' modifier to 'single' and update related documentation
- ✨ **Feature**: add list comprehension syntax to documentation and grammar; update test ground comments


*Generated automatically from git commits*

## [v0.1.28] - 2026-05-28

## Changes in v0.1.28

- 🐛 **Fix**: skip comments in tokenizer and adjust rule syntax in test ground
- 🐛 **Fix**: improve cursor positioning for nil field access and update error test cases
- ✨ **Feature**: Add release notes for v0.1.27 and update event runner test script
  - Created a new HTML file for release notes of EventRunner7 v0.1.27, including download links and a copy functionality for forum posts.
  - Updated the event runner test script to include new simulation globals and refined rules for lighting control based on occupancy and time of day.


*Generated automatically from git commits*

## [v0.1.27] - 2026-05-28

## Changes in v0.1.27

- ✨ **Feature**: Add release notes for EventRunner7 v0.1.26 with download links and copy functionality


*Generated automatically from git commits*

## [v0.1.26] - 2026-05-28

## Changes in v0.1.26

- ♻️ **Refactor**: clean up eventrunner_testground.lua and add post function in Setup.lua


*Generated automatically from git commits*

## [v0.1.25] - 2026-05-28

## Changes in v0.1.25

- ✨ **Feature**: Add release notes for EventRunner7 v0.1.24 in HTML format
  - Created a new HTML document for the release notes of version 0.1.24.
  - Included features, changes, download links, and documentation references.
  - Implemented a copy-to-clipboard button for easy sharing of the forum post.


*Generated automatically from git commits*

## [v0.1.24] - 2026-05-28

## Changes in v0.1.24

- ✨ **Feature**: Update time in eventrunner_testground.lua and correct Gordijn_Licht variable value
- ✨ **Feature**: Add release notes for v0.1.23, implement lambda functions in EventScript, and enhance tests
  - Created release notes for EventRunner7 v0.1.23 in HTML format.
  - Introduced Lambda Functions section in EventScript documentation, detailing syntax and examples.
  - Updated Grammar.txt to include lambda expressions in the language grammar.
  - Enhanced eventrunner_testground.lua with new simulation global variables and rules.
  - Added a new lambda_test.lua file for smoke testing arrow-lambda syntax and built-in functions (map, filter, reduce).


*Generated automatically from git commits*

## [v0.1.23] - 2026-05-28

## Changes in v0.1.23

- ✨ **Feature**: Add release notes for EventRunner7 v0.1.22 with forum post helper


*Generated automatically from git commits*

## [v0.1.22] - 2026-05-28

## Changes in v0.1.22

- ✨ **Feature**: Add release notes for EventRunner7 v0.1.21 with forum post helper


*Generated automatically from git commits*

## [v0.1.21] - 2026-05-28

## Changes in v0.1.21

- ✨ **Feature**: Add release notes for EventRunner7 v0.1.20 with forum post helper


*Generated automatically from git commits*

## [v0.1.20] - 2026-05-28

## Changes in v0.1.20

- ✨ **Feature**: Add release notes for EventRunner7 v0.1.19 with download links and documentation


*Generated automatically from git commits*

## [v0.1.19] - 2026-05-27

## Changes in v0.1.19

- ✨ **Feature**: Add release notes for EventRunner7 v0.1.18 with download links and documentation


*Generated automatically from git commits*

## [v0.1.18] - 2026-05-27

## Changes in v0.1.18

- ✨ **Feature**: Refactor code structure for improved readability and maintainability
- ✨ **Feature**: Add release notes for EventRunner7 v0.1.17 and update documentation with new features and reserved keywords


*Generated automatically from git commits*

## [v0.1.17] - 2026-05-27

## Changes in v0.1.17

- ✨ **Feature**: Add HTML release notes for EventRunner7 v0.1.16 with download links and copy-to-clipboard feature


*Generated automatically from git commits*

## [v0.1.16] - 2026-05-27

## Changes in v0.1.16

- ✨ **Feature**: Add release notes for EventRunner7 v0.1.15 with new features and documentation updates
  - Introduced logging functionality with color support in RULES.md
  - Added documentation for EventRunner7 features and release v0.1.14
  - Implemented a copy-to-clipboard feature for forum posts
  - Generated HTML release notes for easy sharing


*Generated automatically from git commits*

## [v0.1.15] - 2026-05-27

## Changes in v0.1.15

- ✨ **Feature**: Add logging functionality with color support to RULES.md
  - Introduced the `log` function for printing messages from rule actions.
  - Added examples for basic logging and formatted logging with temperature values.
  - Documented colored output using `#C:color#` tags for the HC3 debug log.
  - Introduced a shorthand method for colored logging using `log.color(...)` syntax.
  - Provided a list of valid CSS color names for use with the new logging feature.
- ✨ **Feature**: Add documentation for EventRunner7 features and release v0.1.14
  - Created forum posts for adding custom device properties, module system, and custom reactive objects.
  - Added HTML files for each topic with examples and usage instructions.
  - Implemented a copy-to-clipboard feature for easy sharing of forum posts.
  - Documented changes and enhancements in release v0.1.14, including error handling improvements.


*Generated automatically from git commits*

## [v0.1.14] - 2026-05-26

## Changes in v0.1.14

- ✨ **Feature**: Add release notes for version 0.1.13 and enhance error handling in tests
  - Created a new HTML file for the release notes of EventRunner7 v0.1.13, detailing new features and fixes.
  - Implemented a copy-to-clipboard functionality for easy sharing of the forum post.
  - Enhanced the error testing in `error_test.lua` to include checks for rule compilation errors and improved time constant validation.
  - Added a function to convert HTML entities to plain text for better error message readability.


*Generated automatically from git commits*

## [v0.1.13] - 2026-05-26

## Changes in v0.1.13

- ✨ **Feature**: Implement early rule processing termination with BREAK sentinel
- 🐛 **Fix**: Update wait time format in tests to HH:MM
- 🐛 **Fix**: Update wait time format in example rule to HH:MM
- ✨ **Feature**: Add error handling for logical operators and improve duration specifications in rules


*Generated automatically from git commits*

## [v0.1.12] - 2026-05-26

## Changes in v0.1.12

- ✨ **Feature**: Add error handling for time literals in HH:MM and HH:MM:SS format in Tokenizer
- ✨ **Feature**: Enhance rule handling with first_in_win functionality and update tests


*Generated automatically from git commits*

## [v0.1.11] - 2026-05-26

## Changes in v0.1.11

- ✨ **Feature**: Implement rule testing framework and add unit tests for rule conditions
- ✨ **Feature**: Add release notes for v0.1.10 and update project configuration script


*Generated automatically from git commits*

## [v0.1.10] - 2026-05-25

## Changes in v0.1.10

- ✨ **Feature**: Add 'first_in' modifier and enhance documentation
  - Introduced 'first_in' modifier for time window-based rule triggering.
  - Updated existing modifiers documentation for clarity and consistency.
  - Added new release notes for version 0.1.9, highlighting recent features.
  - Created comprehensive EventScript debug tooling documentation for better rule inspection and monitoring.
  - Implemented a custom artifact build process to fix quickAppVariables format for HC3 compatibility.


*Generated automatically from git commits*

## [v0.1.9] - 2026-05-25

## Changes in v0.1.9

- ✨ **Feature**: Add 'first_in' token type and corresponding parser logic
- ✨ **Feature**: Add Rule Groups feature and update version in documentation
- ✨ **Feature**: Add Rule Groups feature and update documentation


*Generated automatically from git commits*

## [v0.1.8] - 2026-05-24

## Changes in v0.1.8

- ✨ **Feature**: Add new features in v0.1.7: Rule Modifiers and Named Scenes
  - Introduced Rule Modifiers to enhance rule expressiveness, allowing for conditions to specify when and how often actions fire.
  - Added Named Scenes to group device property assignments, enabling easier management of device states.
  - Updated documentation to reflect new features, including detailed explanations and examples for Rule Modifiers and Named Scenes.
  - Created a new HTML page for a forum post preview to facilitate sharing of the new features with the community.
  - Commented out legacy test code in `eventrunner_testground.lua` for clarity and focus on new functionality.
- ✨ **Feature**: Add release notes for EventRunner7 v0.1.7 with new features and enhancements


*Generated automatically from git commits*

## [v0.1.7] - 2026-05-24

## Changes in v0.1.7

- ✨ **Feature**: Add support for rule modifiers and named scenes
  - Implemented rule modifiers: `restart`, `since`, `debounce`, `cooldown`, and `every` to enhance action firing control.
  - Introduced named scenes with `scene` keyword, allowing grouped device property assignments with activate/deactivate bodies.
  - Updated parser and compiler to handle new syntax for modifiers and scenes.
  - Enhanced documentation to include examples and explanations for new features.
  - Added unit tests for modifier functionality and named scene behavior to ensure reliability.
- ✨ **Feature**: Add skills-lock.json to define available skills with source and path information
- ✨ **Feature**: Enhance EventScript with new variable definition functions and add parameter constraints to documentation
- ✨ **Feature**: Add EventScript runner and profiling enhancements
  - Introduced a new script `er` for running EventScript rule expressions inline with options for execution time and raw mode.
  - Added a new Lua file `rulerunner.lua` to facilitate the execution of rules from standard input, enhancing the EventRunner functionality.
  - Updated `profile.lua` to include JIT support for performance profiling.
- ✨ **Feature**: Revamp EventScript rules presentation with Neon Cyber theme
  - Updated font styles to use Clash Display and Satoshi for a modern look.
  - Redesigned color scheme to a Neon Cyber theme with vibrant accents.
  - Enhanced layout and styling for slide elements, including borders and shadows.
  - Added new slides for File Structure, Logging Flags, Predefined Variables, Startup Event, Dim Light, Weather Object, HTTP Functions, Custom Properties, and Best Practices.
  - Improved code block styling for better readability and visual appeal.
  - Adjusted typography and spacing for a cleaner presentation.
- ✨ **Feature**: add post and cancel functions to event runner
- ✨ **Feature**: Update tutorial and release script references from EventRunner6 to EventRunner7
- ✨ **Feature**: Add release notes for EventRunner7 v0.1.6 with download links and documentation


*Generated automatically from git commits*

## [v0.1.6] - 2026-05-22

## Changes in v0.1.6

- ✨ **Feature**: chore: clean up empty code change sections in the changes log


*Generated automatically from git commits*

## [v0.1.5] - 2026-05-21

## Changes in v0.1.5

- ✨ **Feature**: Add HTML release notes for EventRunner7 v0.1.4 with download links and copy functionality


*Generated automatically from git commits*

## [v0.1.4] - 2026-05-21

## Changes in v0.1.4

- ✨ **Feature**: Add HTML release notes for EventRunner7 v0.1.3 with download links and copy functionality


*Generated automatically from git commits*

## [v0.1.3] - 2026-05-21

## Changes in v0.1.3

- ✨ **Feature**: chore: remove unused file reference and add release v0.1.2 forum post


*Generated automatically from git commits*

## [v0.1.2] - 2026-05-21

## Changes in v0.1.2

- ♻️ **Refactor**: change debug and print colors from orange to green for consistency
- ✨ **Feature**: add automated release creation and forum post generation scripts
  - Implemented create-release.sh for automated GitHub releases, including version bumping, changelog updates, and artifact generation.
  - Added forum-post-generator.sh to create HTML forum posts for release announcements.
  - Introduced project-config.sh for project-specific settings and configurations.
  - Developed setversion.sh to update version numbers in multiple files.


*Generated automatically from git commits*

## [v0.1.1] - 2026-05-21

## Changes in v0.1.1

- ✨ **Feature**: Refactor code structure for improved readability and maintainability
- ♻️ **Refactor**: comment out unused rule and initialize MODULE for better module management
- ✨ **Feature**: implement profiling functionality and enhance EventRunner initialization
- 📚 **Docs**: add clarification comment for ER.D2024 date handling
- ✨ **Feature**: enhance error messages with tagging for better debugging context
- ✨ **Feature**: implement ER.compileRuleBody for direct RULE node compilation
- ♻️ **Refactor**: rename parameter in NumberProp constructor for clarity feat: add ER.loadedSimDevices to track loaded simulation devices docs: add comprehensive documentation for the EventScript Rule System
- ✨ **Feature**: feat(tour): add scripts for generating and validating CodeTour skeletons
  - Introduced `generate_from_docs.py` to create a tour skeleton from documentation files (README, CONTRIBUTING, etc.), extracting relevant paths, sections, and links.
  - Added `validate_tour.py` to validate .tour files for JSON structure, required fields, existing file paths, and narrative consistency.
  - Created a new example tour file `external-contributor.tour` for external contributors, detailing the architecture and key components of the EventRunner7 codebase.
  - Updated `Rule.lua` and `Sim.lua` for improved logging and functionality.
  - Added comprehensive error handling tests in `error_test.lua` to ensure robust error reporting and cursor placement.
  - Modified `eventrunner_testground2.lua` to simplify test cases.
- ♻️ **Refactor**: improve variable handling and error propagation in CSP and Compiler modules
- ✨ **Feature**: enhance error handling and source position tracking in CSP compilation and parsing
- ✨ **Feature**: Refactor event handling and rule management
  - Updated the `comp.RULE` function to utilize a separate condition function for improved readability and maintainability.
  - Enhanced the `Props.lua` file by adding reduce functions for `isOn` and `isOff` properties.
  - Introduced new utility functions in `Rule.lua` for better rule management, including options for logging and rule state management.
  - Implemented subscription and publishing capabilities in `ScriptFuns.lua` for remote event handling.
  - Added a new documentation file detailing property and command references for better developer guidance.
  - Created a test ground script to facilitate testing of new features and event handling.
- ♻️ **Refactor**: remove unused setupProps function assignment in ScriptFuns.lua
- ✨ **Feature**: Add Props.lua and update EventRunner.inc to include it; refactor Rule.lua and ScriptFuns.lua for improved property handling
  - Introduced Props.lua to manage device properties and interactions.
  - Updated EventRunner.inc to include Props.lua.
  - Refactored Rule.lua to enhance the GETPROP functionality and trigger handling.
  - Cleaned up ScriptFuns.lua by removing redundant property setup functions and integrating property resolution.
  - Modified eventrunner_testground.lua to demonstrate the new property handling with MyDevice.
- ✨ **Feature**: chore: remove unused style preview files for EventRunner
- ✨ **Feature**: Add EventRunnerTest for integration testing of EventScript with devices
  - Created a new test file `eventrunner_plua_test2.lua` to validate the integration of EventScript with various device types in a real-time environment.
  - Set up a HomeTable with multiple devices including switches, sensors, and controllers.
  - Implemented checks to verify the functionality of rules triggered by device state changes.
  - Modified `eventrunner_testground.lua` to comment out a JSON encoding rule for clarity.
- ✨ **Feature**: enhance EventRunner with new property handling and filters; add temperature sensor support in tests
- ✨ **Feature**: implement 'case' statement syntax and corresponding parser updates; add smoke tests for case functionality
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: Refactor tests and enhance functionality
  - Added new tests for the null coalescing operator (??) in eventrunner_test.lua.
  - Updated conditions in tests to check for table types before accessing fields in eventrunner_test.lua.
  - Changed wait duration in eventrunner_test.lua from 4000ms to 4s for consistency.
  - Modified rule definition in eventrunner_testground.lua for clarity.
  - Improved test structure in expr_test.lua by consolidating test harness functions and ensuring consistent formatting.
  - Added missing tests for various expressions and control structures in expr_test.lua.
  - Updated parser_test.lua to reflect changes in the handling of time-related expressions.
  - Adjusted test.lua to reference the correct CSP module from the fibaro.ER namespace.
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: Enhance eventrunner_plua_test.lua with additional device tests and improved rule checks
  - Updated comments for clarity and consistency.
  - Added new devices including motion sensors, lamps, and various sensors in the home structure.
  - Implemented comprehensive tests for device properties and actions, including binary switches, multilevel switches, and various sensor types.
  - Introduced checks for rule triggers and added logging for successful test cases.
  - Enhanced the testing of global variables and conditions using trueFor.
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: enhance global variable handling in CSP and Parser; update EventRunner tests for improved syntax
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: Add merge script and new test files for EventRunner
  - Introduced `merge_stdqas.sh` script to consolidate Lua files in the `tests/stdQAs` directory into a single `stdQAs.lua` file, stripping comments and organizing content.
  - Added `eventrunner_plua_test.lua` to test EventScript integration with simulated devices, focusing on real-time execution.
  - Updated `eventrunner_test.lua` to utilize simulated devices and improve testing of time-based features.
  - Created `eventrunner_testground.lua` as a scratch pad for testing new features before integration into the main test suite.
  - Added `stdQAs.lua` containing definitions for various simulated devices, enhancing the testing framework.
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: enhance EventRunner with catch value handling; update test cases for daily triggers and logging
- ✨ **Feature**: enhance rule management with enable/disable functionality; improve daily trigger handling and add new test cases
- ✨ **Feature**: add simulation for global variables; enhance test coverage for variable assignments and triggers
- ✨ **Feature**: enhance variable handling in MAKETABLE and compile functions; add mret for multiple value returns in tests
- ✨ **Feature**: introduce LETS function for scoped variable binding; optimize rule compilation and enhance test coverage
- ✨ **Feature**: enhance async function handling; add 'once' method and improve for-in loop example
- ✨ **Feature**: add SETINDEX and SETFIELD functions; enhance compiler and event handling capabilities
- ✨ **Feature**: refactor event handling and improve test coverage; add new test ground for event triggers
- ✨ **Feature**: enhance device simulation and testing; improve error handling and logging in rules
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: enhance async function handling and testing; improve test utilities for better clarity and coverage
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: enhance async function handling and logging; update test utilities for improved clarity
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: Add QuickApps for HVAC systems, sensors, and devices
  - Implemented QuickApps for various HVAC systems including auto, cool, heat, and heat/cool modes with appropriate properties and actions.
  - Created QuickApps for light, motion, multilevel, rain, smoke, temperature, and wind sensors, each with initialization and property update methods.
  - Added QuickApps for player, power meter, remote controller, and weather, including methods for handling specific actions and updating properties.
  - Enhanced test functions to improve test reporting and handling of multiple test cases.
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: enhance logging functionality and verbosity handling; update tests for improved coverage
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: Add EventRunner7 test and utility functions for evaluation
  - Created a new test file `eventrunner_test.lua` to implement tests for EventRunner7.
  - Added a main function to handle the evaluation of rules and tests.
  - Introduced a new utility file `testfuns.lua` containing a testing function to validate rule outputs.
  - Integrated the testing function into the EventRunner environment for easier test execution.
  - Co-authored-by: Copilot <copilot@github.com>
- ✨ **Feature**: enhance rule handling and logging; add test device support and unit tests
- ✨ **Feature**: add GETVAR and SETVAR functions; enhance variable handling in CSP and Compiler
- ✨ **Feature**: Refactor Tokenizer and Utils; Add unit tests for expression and parser
  - Updated Tokenizer.lua to improve token handling and organization.
  - Refactored Utils.lua to enhance functionality and added timeStr utility.
  - Introduced rulecode.lua for testing rule evaluation and device simulation.
  - Added comprehensive unit tests for expression compilation in expr_test.lua.
  - Created parser_test.lua to validate parsing logic and AST generation.
  - Implemented rule_test.lua to verify rule execution and event handling.
  - Developed continuation test in test.lua to assess coroutine behavior and yield handling.
- ✨ **Feature**: implement DAILY and INTERV event descriptors, BETW function, and related parser updates
- ✨ **Feature**: Add unit tests for expression compiler and parser
  - Created `expr_test.lua` to test various expressions including literals, arithmetic operations, comparisons, logical operations, string concatenation, local variables, control flow, function calls, field access, and property access.
  - Implemented `parser_test.lua` to validate the parsing of literals, arithmetic operations, comparisons, function calls, assignments, local declarations, control flow, and error cases.
  - Updated `test.lua` to reference the new CSP file for continuity tests.
- ✨ **Feature**: add commit message examples and guidelines for HueV2 project
- ✨ **Feature**: create launch configuration for Lua debugging in VSCode
  - chore: add VSCode settings for Lua workspace and Git commit validation
- 📚 **Docs**: add README for cont.lua with detailed usage and expression reference
- ✨ **Feature**: implement continuation-passing VM in cont.lua for expression evaluation
- ♻️ **Refactor**: move item functions to old stuff/items.lua for organization
- 🧪 **Test**: add test script for continuation VM functionality and yield handling


*Generated automatically from git commits*

