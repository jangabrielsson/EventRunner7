# Graph Report - .  (2026-05-21)

## Corpus Check
- 138 files · ~96,127 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 799 nodes · 983 edges · 95 communities (90 shown, 5 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 76 edges (avg confidence: 0.76)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 73|Community 73]]
- [[_COMMUNITY_Community 74|Community 74]]
- [[_COMMUNITY_Community 75|Community 75]]
- [[_COMMUNITY_Community 76|Community 76]]
- [[_COMMUNITY_Community 77|Community 77]]
- [[_COMMUNITY_Community 78|Community 78]]
- [[_COMMUNITY_Community 79|Community 79]]
- [[_COMMUNITY_Community 89|Community 89]]
- [[_COMMUNITY_Community 91|Community 91]]
- [[_COMMUNITY_Community 92|Community 92]]

## God Nodes (most connected - your core abstractions)
1. `compile()` - 38 edges
2. `TR()` - 35 edges
3. `PRINT()` - 22 edges
4. `trace()` - 19 edges
5. `BINOP()` - 15 edges
6. `fibaro.EventRunner()` - 13 edges
7. `evalArgs()` - 11 edges
8. `generate_skeleton()` - 10 edges
9. `eval()` - 9 edges
10. `EventRunner.inc (Module Bundle Header)` - 9 edges

## Surprising Connections (you probably didn't know these)
- `test()` --calls--> `PRINT()`  [INFERRED]
  tests/case_test.lua → CSP.lua
- `eval()` --calls--> `ER.compileRuleBody()`  [INFERRED]
  Rule.lua → Compiler.lua
- `eval()` --calls--> `ER.compileASTWithMap()`  [INFERRED]
  Rule.lua → Compiler.lua
- `eval()` --calls--> `PRINT()`  [INFERRED]
  Rule.lua → CSP.lua
- `QuickApp:onInit()` --calls--> `fibaro.EventRunner()`  [INFERRED]
  EventRunner7.lua → Rule.lua

## Hyperedges (group relationships)
- **EventScript Compilation Pipeline** —  [INFERRED]
- **EventRunner Documentation Suite** —  [INFERRED]

## Communities (95 total, 5 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.00
Nodes (57): ADD(), AND(), BETW(), BINOP(), BREAK(), CALL(), CFUN(), chain_to_list() (+49 more)

### Community 1 - "Community 1"
Cohesion: 0.00
Nodes (20): arm(), BN(), CALL(), collect(), filters.allFalse(), filters.allTrue(), filters.average(), filters.bin() (+12 more)

### Community 2 - "Community 2"
Cohesion: 0.00
Nodes (27): QuickApp:onInit(), makeParser(), parse(), fibaro.EventRunner(), midnightLoop(), setupGlobalVariables(), ER.loadSimDevice(), setTimeout() (+19 more)

### Community 5 - "Community 5"
Cohesion: 0.00
Nodes (21): compAssign(), compBinop(), compBlock(), compCall(), compDo(), compFor(), compForIn(), compIf() (+13 more)

### Community 6 - "Community 6"
Cohesion: 0.00
Nodes (23): checkProgn(), PRINT(), _file_content(), _line_count(), main(), print_report(), validate_tour(), check() (+15 more)

### Community 7 - "Community 7"
Cohesion: 0.00
Nodes (27): CSP.lua (Trampoline VM), EventRunner7 (Automation Engine), EventScript (Rule Language), Fibaro HC3 (Smart Home Controller), plua (Local HC3 Emulator), QuickApp (Fibaro App Unit), Rule System (condition => action), .github/copilot-instructions.md (Workspace AI Instructions) (+19 more)

### Community 8 - "Community 8"
Cohesion: 0.00
Nodes (19): ER.compileASTWithMap(), beautifyArgs(), compRule(), eval(), exprFun(), getRule(), HOPS.BETW(), HOPS.DAILY() (+11 more)

### Community 9 - "Community 9"
Cohesion: 0.00
Nodes (16): chat.tools.terminal.autoApprove, plua, git.confirmSync, git.enableSmartCommit, git.inputValidation, git.inputValidationLength, git.inputValidationSubjectLength, git.useEditorAsCommitInput (+8 more)

### Community 10 - "Community 10"
Cohesion: 0.00
Nodes (8): __fibaro_get_global_variable(), fibaro.getGlobalVariable(), fibaro.setGlobalVariable(), between(), ER.getVar(), ER.setVar(), marshallFrom(), toSeconds()

### Community 11 - "Community 11"
Cohesion: 0.00
Nodes (13): _extract_external_links(), _extract_paths_from_text(), generate_skeleton(), _is_structure_section(), main(), _make_content_step(), _make_dir_step(), _make_file_step() (+5 more)

### Community 12 - "Community 12"
Cohesion: 0.00
Nodes (13): description, type, description, type, properties, description, type, directory (+5 more)

### Community 13 - "Community 13"
Cohesion: 0.00
Nodes (11): description, type, properties, nextTour, when, required, $schema, title (+3 more)

### Community 14 - "Community 14"
Cohesion: 0.00
Nodes (10): author, name, url, description, homepage, keywords, license, name (+2 more)

### Community 17 - "Community 17"
Cohesion: 0.00
Nodes (6): getProp(), table.map(), table.mapAnd(), table.mapF(), table.mapOr(), table.maxn()

### Community 18 - "Community 18"
Cohesion: 0.00
Nodes (7): description, name, owner, name, url, plugins, $schema

### Community 20 - "Community 20"
Cohesion: 0.00
Nodes (7): default, description, examples, items, type, type, commands

### Community 21 - "Community 21"
Cohesion: 0.00
Nodes (7): end, selection, start, description, properties, required, type

### Community 24 - "Community 24"
Cohesion: 0.00
Nodes (7): getTimezone(), hm2sec(), midnight(), now(), sunCalc(), sunturnTime(), toTime()

### Community 25 - "Community 25"
Cohesion: 0.00
Nodes (4): err(), info(), ok(), warn()

### Community 26 - "Community 26"
Cohesion: 0.00
Nodes (4): err(), info(), ok(), warn()

### Community 32 - "Community 32"
Cohesion: 0.00
Nodes (6): required, steps, default, description, items, type

### Community 73 - "Community 73"
Cohesion: 0.00
Nodes (3): description, type, description

### Community 74 - "Community 74"
Cohesion: 0.00
Nodes (3): description, type, isPrimary

### Community 75 - "Community 75"
Cohesion: 0.00
Nodes (3): description, type, pattern

### Community 76 - "Community 76"
Cohesion: 0.00
Nodes (3): stepMarker, description, type

### Community 77 - "Community 77"
Cohesion: 0.00
Nodes (3): title, description, type

### Community 78 - "Community 78"
Cohesion: 0.00
Nodes (3): view, description, type

### Community 79 - "Community 79"
Cohesion: 0.00
Nodes (3): ref, description, type

## Knowledge Gaps
- **74 isolated node(s):** `$schema`, `title`, `type`, `required`, `type` (+69 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.