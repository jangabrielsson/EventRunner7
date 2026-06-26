# Changelog

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

