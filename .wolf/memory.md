# Memory

> Chronological action log. Hooks and AI append to this file automatically.
> Old sessions are consolidated by the daemon weekly.

| 2026-04-10 | Added dummy AD hold for support vehicle idle state + fixed justStoppedAD not cleared in resetStepTrackingState | WorkflowExecutor.lua | 106/106 tests pass |

## Session: 2026-04-05 23:05

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-04-05 23:34

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 00:03 | Created ../../../../../.claude/plans/twinkling-marinating-wind.md | — | ~3646 |
| 00:13 | Created ../../../../../.claude/plans/twinkling-marinating-wind.md | — | ~4415 |
| 00:19 | Created src/WorkflowStorage.lua | — | ~3097 |
| 00:20 | Created tests/specs/WorkflowStorage_spec.lua | — | ~6279 |
| 00:22 | Created tests/run_storage_spec.lua | — | ~1245 |
| 00:23 | Edited tests/specs/WorkflowStorage_spec.lua | modified saveOldFormat() | ~142 |
| 00:23 | Edited tests/specs/WorkflowStorage_spec.lua | 5→6 lines | ~88 |
| 00:24 | Edited tests/specs/WorkflowStorage_spec.lua | 7→11 lines | ~145 |
| 00:25 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~179 |
| 00:25 | Edited src/WorkflowManager.lua | 8→9 lines | ~89 |
| 00:25 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~535 |
| 00:26 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~150 |
| 00:26 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~499 |
| 00:26 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~526 |
| 00:26 | Edited src/network/WMNetworkEvents.lua | modified WMCommandEvent() | ~515 |
| 00:27 | Edited src/WorkflowManager.lua | 15→18 lines | ~138 |
| 00:27 | Edited tests/specs/WorkflowManager_spec.lua | 16→16 lines | ~153 |
| 00:27 | Edited tests/specs/WorkflowManager_spec.lua | expanded (+33 lines) | ~568 |
| 00:27 | Edited tests/specs/WorkflowManager_spec.lua | 7→7 lines | ~125 |
| 00:27 | Edited tests/specs/WorkflowManager_spec.lua | 9→13 lines | ~189 |
| 00:28 | Edited tests/specs/WorkflowManager_spec.lua | reduced (-93 lines) | ~856 |
| 00:28 | Edited tests/specs/WorkflowManager_spec.lua | expanded (+8 lines) | ~890 |
| 00:28 | Edited tests/specs/WorkflowManager_spec.lua | removed 65 lines | ~20 |

## Session: 2026-04-06 07:23

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 07:28 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~108 |
| 07:28 | Edited src/WorkflowExecutor.lua | 30→27 lines | ~328 |
| 07:28 | Edited src/WorkflowExecutor.lua | 9→9 lines | ~126 |
| 07:28 | Edited src/WorkflowExecutor.lua | getActiveVehiclesForWorkflow() → getSupportActiveDataListForWorkflow() | ~172 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~1034 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~168 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~133 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~87 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~109 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~189 |
| 07:30 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~881 |
| 07:30 | Edited src/WorkflowExecutor.lua | getActiveVehiclesForWorkflow() → getSupportActiveDataListForWorkflow() | ~111 |
| 07:30 | Edited src/WorkflowExecutor.lua | modified info() | ~318 |
| 07:31 | Edited src/WorkflowExecutor.lua | 20→20 lines | ~304 |
| 07:31 | Edited src/WorkflowExecutor.lua | 19→19 lines | ~286 |
| 07:31 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~764 |
| 07:31 | Edited src/WorkflowExecutor.lua | removed 18 lines | ~1 |
| 07:31 | Edited src/WorkflowExecutor.lua | 41→43 lines | ~392 |
| 07:32 | Edited src/WorkflowExecutor.lua | 46→48 lines | ~432 |
| 07:33 | Edited tests/specs/WorkflowExecutor_spec.lua | 12→11 lines | ~122 |
| 07:33 | Edited tests/specs/WorkflowExecutor_spec.lua | modified makeWorkflow() | ~363 |
| 07:34 | Edited tests/specs/WorkflowExecutor_spec.lua | modified makeMainSupportPair() | ~3547 |
| 07:35 | Edited tests/specs/WorkflowExecutor_spec.lua | 4→2 lines | ~48 |
| 07:35 | Edited tests/specs/WorkflowExecutor_spec.lua | 2→1 lines | ~12 |
| 07:35 | Edited tests/specs/WorkflowExecutor_spec.lua | removed 21 lines | ~12 |
| 07:49 | Edited tests/specs/WorkflowExecutor_spec.lua | removed 38 lines | ~19 |
| 07:49 | Edited src/WorkflowExecutor.lua | 2→2 lines | ~27 |
| 07:49 | Edited src/WorkflowExecutor.lua | expanded (+12 lines) | ~252 |
| 07:49 | Edited src/WorkflowExecutor.lua | expanded (+10 lines) | ~199 |
| 07:50 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+6 lines) | ~282 |
| 07:50 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+11 lines) | ~231 |
| 07:51 | Phase 3 WorkflowExecutor rewrite — hierarchical support (isMainVehicle, currentSupportStep, onMainStepChanged) | src/WorkflowExecutor.lua, tests/specs/WorkflowExecutor_spec.lua | 106/106 tests passing | ~12000 tok |
| 07:51 | Edited CLAUDE.md | refinement() → steps() | ~80 |
| 07:52 | Edited CLAUDE.md | 42→45 lines | ~566 |
| 07:52 | Edited CLAUDE.md | 18→21 lines | ~279 |
| 07:52 | Edited CLAUDE.md | 4→3 lines | ~198 |
| 07:52 | Edited CLAUDE.md | 15→12 lines | ~325 |
| 07:53 | Session end: 36 writes across 3 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua, CLAUDE.md) | 3 reads | ~47928 tok |

## Session: 2026-04-06 07:57

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 08:00 | Edited src/gui/WMMainDialog.lua | getText() → hasSupportSteps() | ~99 |
| 08:01 | Edited src/gui/WMStepDialog.lua | 12→8 lines | ~48 |
| 08:01 | Edited src/gui/WMStepDialog.lua | modified Callback() | ~213 |
| 08:01 | Edited src/gui/WMStepDialog.lua | reduced (-9 lines) | ~24 |
| 08:01 | Edited src/gui/WMStepDialog.lua | 13→8 lines | ~67 |
| 08:01 | Edited src/gui/WMStepDialog.lua | removed 10 lines | ~5 |
| 08:01 | Edited src/gui/WMEditorDialog.lua | 4→1 lines | ~7 |
| 08:01 | Edited src/gui/WMEditorDialog.lua | removed 70 lines | ~7 |
| 08:01 | Edited src/gui/WMEditorDialog.lua | 9→6 lines | ~75 |
| 08:02 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~442 |
| 21:10 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~611 |
| 21:11 | Created xml/gui/WMEditorDialog.xml | — | ~1472 |
| 21:11 | Edited src/gui/WMHud.lua | 2→2 lines | ~26 |
| 21:11 | Edited src/gui/WMHud.lua | modified renderText() | ~340 |
| 21:11 | Created src/gui/WMModeSelectDialog.lua | — | ~537 |
| 21:11 | Created xml/gui/WMModeSelectDialog.xml | — | ~427 |
| 21:12 | Edited src/WorkflowManager.lua | 4→5 lines | ~98 |
| 21:12 | Edited src/WorkflowManager.lua | expanded (+13 lines) | ~260 |
| 21:12 | Edited src/WorkflowManager.lua | modified Callback() | ~134 |
| 21:12 | Edited translations/translation_en.xml | reduced (-6 lines) | ~208 |
| 21:12 | Edited translations/translation_de.xml | expanded (+13 lines) | ~293 |
| 21:13 | Phase 4 GUI complete: WMModeSelectDialog, support step editing in editor, HUD support status, linkRole/syncGroup UI removed | 9 files | 106/106 tests passing | ~22000 tok |
| 21:13 | Session end: 21 writes across 10 files (WMMainDialog.lua, WMStepDialog.lua, WMEditorDialog.lua, WMEditorDialog.xml, WMHud.lua) | 8 reads | ~18590 tok |
| 21:51 | Created src/gui/WMEditorDialog.lua | — | ~5297 |
| 21:51 | Edited xml/gui/WMEditorDialog.xml | 6→5 lines | ~131 |
| 21:51 | Edited translations/translation_en.xml | 2→3 lines | ~80 |
| 21:52 | Edited translations/translation_de.xml | 2→3 lines | ~91 |
| 21:52 | Session end: 25 writes across 10 files (WMMainDialog.lua, WMStepDialog.lua, WMEditorDialog.lua, WMEditorDialog.xml, WMHud.lua) | 8 reads | ~29155 tok |
| 22:08 | Edited src/gui/WMEditorDialog.lua | 20→20 lines | ~197 |
| 22:08 | Session end: 26 writes across 10 files (WMMainDialog.lua, WMStepDialog.lua, WMEditorDialog.lua, WMEditorDialog.xml, WMHud.lua) | 8 reads | ~29366 tok |
| 22:14 | Edited src/gui/WMEditorDialog.lua | 5→5 lines | ~47 |
| 22:14 | Edited src/gui/WMHud.lua | expanded (+18 lines) | ~428 |
| 22:14 | Session end: 28 writes across 10 files (WMMainDialog.lua, WMStepDialog.lua, WMEditorDialog.lua, WMEditorDialog.xml, WMHud.lua) | 8 reads | ~36257 tok |
| 10:42 | Edited src/WorkflowManagerSpec.lua | 7→11 lines | ~177 |
| 10:42 | Edited src/WorkflowManagerSpec.lua | 7→12 lines | ~195 |
| 10:42 | Edited src/WorkflowManagerSpec.lua | expanded (+10 lines) | ~339 |
| 10:42 | Edited src/WorkflowManagerSpec.lua | 10→13 lines | ~179 |
| 10:42 | Edited src/WorkflowManagerSpec.lua | 18→23 lines | ~269 |
| 10:42 | Edited src/network/WMNetworkEvents.lua | 11→15 lines | ~164 |
| 10:42 | Edited src/network/WMNetworkEvents.lua | modified WMStateSyncEvent() | ~265 |
| 10:42 | Edited src/network/WMNetworkEvents.lua | 4→6 lines | ~95 |
| 10:43 | Edited src/WorkflowExecutor.lua | 10→15 lines | ~205 |
| 10:43 | Session end: 37 writes across 13 files (WMMainDialog.lua, WMStepDialog.lua, WMEditorDialog.lua, WMEditorDialog.xml, WMHud.lua) | 10 reads | ~54883 tok |
| 12:28 | Created website/docs/workflows/linked-workflows.md | — | ~2005 |

## Session: 2026-04-07 12:30

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 12:31 | Created website/docs/ui/editor-dialog.md | — | ~1611 |
| 12:32 | Created website/docs/ui/hud-controls.md | — | ~1527 |
| 12:32 | Created website/docs/workflows/executing-workflows.md | — | ~1804 |
| 12:33 | Created website/docs/workflows/creating-workflows.md | — | ~1733 |
| 12:33 | Created website/docs/api/xml-format.md | — | ~1974 |
| 12:34 | Updated 5 Docusaurus docs for hierarchical support steps | website/docs/ui/editor-dialog.md, hud-controls.md, workflows/executing-workflows.md, creating-workflows.md, api/xml-format.md | Removed syncGroup/linkRole/linkedWorkflowId references; added N.M numbering, role dialog, nested support sub-step docs | ~3000 |
| 12:34 | Session end: 5 writes across 5 files (editor-dialog.md, hud-controls.md, executing-workflows.md, creating-workflows.md, xml-format.md) | 5 reads | ~9266 tok |

## Session: 2026-04-07 22:11

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 23:10 | Edited src/WorkflowExecutor.lua | 10→11 lines | ~193 |
| 23:10 | Edited src/WorkflowExecutor.lua | modified info() | ~160 |
| 23:10 | Edited src/WorkflowExecutor.lua | 4→5 lines | ~77 |
| 23:11 | Fix support vehicle restart loop after last sub-step | WorkflowExecutor.lua | waitingForMainStepIndex tracks which step triggered idle; idle poll only restarts when main step changes | ~500 tok |
| 23:12 | Session end: 3 writes across 1 files (WorkflowExecutor.lua) | 1 reads | ~17147 tok |

## Session: 2026-04-07 23:19

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 23:21 | Edited xml/gui/WMModeSelectDialog.xml | inline fix | ~16 |
| 23:21 | Edited xml/gui/WMModeSelectDialog.xml | "500px 50px" → "660px 50px" | ~10 |
| 07:00 | Fixed WMModeSelectDialog button overflow: dialog 540px→700px, height 220px→240px, desc width 500px→660px | xml/gui/WMModeSelectDialog.xml | fixed | ~20 |
| 23:21 | Session end: 2 writes across 1 files (WMModeSelectDialog.xml) | 4 reads | ~2431 tok |
| 23:32 | Edited translations/translation_en.xml | 2→2 lines | ~36 |
| 23:32 | Edited translations/translation_de.xml | 2→2 lines | ~36 |
| 23:32 | Session end: 4 writes across 3 files (WMModeSelectDialog.xml, translation_en.xml, translation_de.xml) | 6 reads | ~7075 tok |
| 23:40 | Session end: 4 writes across 3 files (WMModeSelectDialog.xml, translation_en.xml, translation_de.xml) | 6 reads | ~7075 tok |

## Session: 2026-04-08 11:12

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-04-08 11:13

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 11:19 | Edited xml/gui/WMEditorDialog.xml | 9→10 lines | ~322 |
| 11:19 | Edited xml/gui/WMEditorDialog.xml | — | ~0 |
| 11:20 | Edited src/gui/WMEditorDialog.lua | — | ~0 |
| 11:20 | Remove support step counter text and fix button overlap | WMEditorDialog.xml, WMEditorDialog.lua | Removed supportStepInfo row; moved addSupportStepButton into header buttons row | ~300 |
| 11:20 | Session end: 3 writes across 2 files (WMEditorDialog.xml, WMEditorDialog.lua) | 2 reads | ~345 tok |
| 11:26 | Edited xml/gui/WMEditorDialog.xml | inline fix | ~16 |
| 11:26 | Edited xml/gui/WMEditorDialog.xml | 4→4 lines | ~102 |
| 11:26 | Edited xml/gui/WMEditorDialog.xml | 2→2 lines | ~31 |
| 11:26 | Edited xml/gui/WMEditorDialog.xml | 26→26 lines | ~473 |
| 11:26 | Session end: 7 writes across 2 files (WMEditorDialog.xml, WMEditorDialog.lua) | 2 reads | ~2388 tok |
| 13:05 | Edited xml/gui/WMEditorDialog.xml | 2→1 lines | ~43 |
| 13:05 | Edited xml/gui/WMEditorDialog.xml | 2→1 lines | ~26 |
| 13:05 | Edited xml/gui/WMEditorDialog.xml | 2→1 lines | ~26 |
| 13:05 | Edited src/gui/WMEditorDialog.lua | — | ~0 |
| 13:05 | Edited src/gui/WMEditorDialog.lua | removed 6 lines | ~1 |
| 13:05 | Session end: 12 writes across 2 files (WMEditorDialog.xml, WMEditorDialog.lua) | 2 reads | ~2491 tok |
| 13:06 | Edited xml/gui/WMEditorDialog.xml | 1→2 lines | ~90 |
| 13:06 | Edited src/gui/WMEditorDialog.lua | 2→7 lines | ~57 |
| 13:06 | Session end: 14 writes across 2 files (WMEditorDialog.xml, WMEditorDialog.lua) | 2 reads | ~2648 tok |
| 13:07 | Session end: 14 writes across 2 files (WMEditorDialog.xml, WMEditorDialog.lua) | 2 reads | ~2648 tok |
| 14:03 | Edited xml/gui/WMStepDialog.xml | removed 12 lines | ~1 |
| 14:03 | Session end: 15 writes across 3 files (WMEditorDialog.xml, WMEditorDialog.lua, WMStepDialog.xml) | 3 reads | ~2649 tok |
| 15:02 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~135 |
| 15:02 | Session end: 16 writes across 3 files (WMEditorDialog.xml, WMEditorDialog.lua, WMStepDialog.xml) | 3 reads | ~2794 tok |

## Session: 2026-04-08 15:11

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 15:22 | Created ../../../../../.claude/plans/sprightly-jingling-frog.md | — | ~2253 |
| 15:31 | Session end: 1 writes across 1 files (sprightly-jingling-frog.md) | 13 reads | ~9517 tok |
| 15:31 | Session end: 1 writes across 1 files (sprightly-jingling-frog.md) | 13 reads | ~9517 tok |
| 15:41 | Session end: 1 writes across 1 files (sprightly-jingling-frog.md) | 13 reads | ~9517 tok |
| 15:41 | Edited ../../../../../.claude/plans/sprightly-jingling-frog.md | removed 7 lines | ~1 |
| 15:41 | Edited ../../../../../.claude/plans/sprightly-jingling-frog.md | removed 7 lines | ~2 |
| 15:41 | Edited ../../../../../.claude/plans/sprightly-jingling-frog.md | 4→3 lines | ~63 |
| 15:46 | Edited xml/gui/guiProfiles.xml | "0.7 0.7 0.7 1" → "0.85 0.85 0.85 1" | ~12 |
| 15:47 | Edited xml/gui/WMEditorDialog.xml | 35→37 lines | ~803 |
| 15:47 | Edited src/gui/WMEditorDialog.lua | 30→28 lines | ~322 |
| 15:47 | Edited src/gui/WMMainDialog.lua | count() → setColor() | ~563 |
| 15:48 | Edited xml/gui/WMStepDialog.xml | expanded (+26 lines) | ~1791 |
| 15:48 | Edited xml/gui/WMStepDialog.xml | inline fix | ~16 |
| 15:48 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~356 |
| 15:49 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~1333 |
| 15:49 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~100 |
| 15:49 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~111 |
| 15:49 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~104 |
| 15:49 | Edited src/gui/WMStepDialog.lua | expanded (+12 lines) | ~508 |
| 15:50 | Edited src/gui/WMHud.lua | expanded (+8 lines) | ~135 |
| 15:50 | Edited src/gui/WMHud.lua | expanded (+12 lines) | ~215 |
| 15:50 | Edited src/gui/WMHud.lua | modified WMHud() | ~139 |
| 15:50 | Edited src/gui/WMHud.lua | modified WMHud() | ~217 |
| 15:50 | Edited src/gui/WMHud.lua | modified WMHud() | ~77 |
| 15:51 | Edited src/gui/WMHud.lua | modified WMHud() | ~2743 |
| 15:52 | Edited translations/translation_en.xml | expanded (+6 lines) | ~136 |
| 15:52 | Edited translations/translation_de.xml | expanded (+6 lines) | ~145 |

| 15:58 | UI improvement pass: column contrast, editor column reorder (Type→Action→Target), support step '└' prefix, main dialog status color, step dialog selected labels + clear buttons + auto-select, HUD vehicle name header + full type names + progress bar + support badge + button tooltips + auto-hide timer | WMHud.lua WMMainDialog.lua WMEditorDialog.lua WMEditorDialog.xml WMStepDialog.lua WMStepDialog.xml guiProfiles.xml translations | 106 tests pass | ~4000 |
| 15:58 | Session end: 24 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~21437 tok |
| 16:02 | Edited src/gui/WMMainDialog.lua | setColor() → setTextColor() | ~119 |
| 16:02 | Session end: 25 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~21565 tok |
| 22:14 | Edited xml/gui/WMStepDialog.xml | inline fix | ~26 |
| 22:14 | Session end: 26 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~21593 tok |
| 22:19 | Edited xml/gui/WMStepDialog.xml | — | ~0 |
| 22:19 | Session end: 27 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~21593 tok |
| 22:26 | Edited src/gui/WMHud.lua | removed 5 lines | ~5 |
| 22:27 | Edited src/gui/WMHud.lua | removed 13 lines | ~8 |
| 22:27 | Edited src/gui/WMHud.lua | — | ~0 |
| 22:27 | Edited src/gui/WMHud.lua | removed 9 lines | ~8 |
| 22:27 | Edited src/gui/WMHud.lua | removed 18 lines | ~6 |
| 22:27 | Edited src/gui/WMHud.lua | 6→3 lines | ~38 |
| 22:27 | Edited src/gui/WMHud.lua | 15→13 lines | ~182 |
| 22:27 | Edited src/gui/WMHud.lua | 2→2 lines | ~16 |
| 22:27 | Session end: 35 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~21873 tok |
| 22:38 | Edited xml/gui/WMEditorDialog.xml | 6→4 lines | ~176 |
| 22:38 | Session end: 36 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~22061 tok |
| 22:41 | Edited src/gui/WMHud.lua | 3→4 lines | ~58 |
| 22:41 | Edited src/gui/WMHud.lua | 9→13 lines | ~155 |
| 22:41 | Edited src/gui/WMHud.lua | 2→6 lines | ~70 |
| 22:41 | Session end: 39 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~22363 tok |
| 22:47 | Edited src/gui/WMHud.lua | reduced (-7 lines) | ~162 |
| 22:47 | Session end: 40 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~22537 tok |
| 22:50 | Edited xml/gui/WMEditorDialog.xml | 7→7 lines | ~171 |
| 22:50 | Session end: 41 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~22728 tok |
| 22:56 | Edited xml/gui/WMEditorDialog.xml | 7→9 lines | ~204 |
| 22:56 | Session end: 42 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~22947 tok |
| 22:59 | Edited xml/gui/WMMainDialog.xml | 5→7 lines | ~130 |
| 22:59 | Session end: 43 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~23086 tok |
| 23:02 | Created xml/gui/WMStepDialog.xml | — | ~2349 |
| 23:03 | Session end: 44 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~25967 tok |
| 23:07 | Created xml/gui/WMStepDialog.xml | — | ~2358 |
| 23:07 | Session end: 45 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~28493 tok |
| 23:11 | Edited xml/gui/WMStepDialog.xml | 8→10 lines | ~208 |
| 23:11 | Edited xml/gui/WMStepDialog.xml | 7→9 lines | ~212 |
| 23:11 | Edited xml/gui/WMStepDialog.xml | 7→9 lines | ~202 |
| 23:11 | Session end: 48 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~29160 tok |
| 23:20 | Edited xml/gui/WMStepDialog.xml | 10→7 lines | ~137 |
| 23:20 | Edited xml/gui/WMStepDialog.xml | 9→6 lines | ~139 |
| 23:21 | Edited xml/gui/WMStepDialog.xml | 9→6 lines | ~131 |
| 23:21 | Edited src/gui/WMStepDialog.lua | — | ~0 |
| 23:21 | Session end: 52 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~29596 tok |
| 23:28 | Edited xml/gui/WMStepDialog.xml | 7→10 lines | ~186 |
| 23:28 | Edited xml/gui/WMStepDialog.xml | 6→9 lines | ~187 |
| 23:28 | Edited xml/gui/WMStepDialog.xml | 6→9 lines | ~178 |
| 23:28 | Session end: 55 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~30185 tok |
| 23:33 | Edited xml/gui/WMStepDialog.xml | "460px 120px" → "500px 120px" | ~5 |

## Session: 2026-04-08 23:35

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 23:40 | Edited xml/gui/WMStepDialog.xml | 19→14 lines | ~223 |
| 23:41 | Edited xml/gui/WMStepDialog.xml | 19→14 lines | ~229 |
| 23:41 | Edited xml/gui/WMStepDialog.xml | 19→14 lines | ~226 |
| 23:41 | Removed sliders from Step Dialog lists; SmoothList now 500px full-width (no inner wrapper) | xml/gui/WMStepDialog.xml | lists match dropdown width | ~200 |
| 23:41 | Session end: 3 writes across 1 files (WMStepDialog.xml) | 2 reads | ~4182 tok |
| 23:45 | Edited xml/gui/WMStepDialog.xml | 14→17 lines | ~295 |
| 23:45 | Edited xml/gui/WMStepDialog.xml | 14→17 lines | ~282 |
| 23:46 | Edited xml/gui/WMStepDialog.xml | 14→17 lines | ~278 |
| 23:46 | Re-added sliders to Step Dialog lists; 3-child wm_hBox with 200px spacer for aligned left edge | xml/gui/WMStepDialog.xml | sliders back, list width preserved at 500px | ~150 |
| 23:46 | Session end: 6 writes across 1 files (WMStepDialog.xml) | 2 reads | ~5098 tok |
| 23:48 | Edited xml/gui/WMStepDialog.xml | 17→19 lines | ~331 |
| 23:48 | Edited xml/gui/WMStepDialog.xml | 17→19 lines | ~331 |
| 23:48 | Edited xml/gui/WMStepDialog.xml | 17→19 lines | ~327 |
| 23:49 | Session end: 9 writes across 1 files (WMStepDialog.xml) | 2 reads | ~6158 tok |
| 23:52 | Edited src/gui/WMHud.lua | 4→4 lines | ~68 |
| 23:52 | Edited src/gui/WMHud.lua | hide() → draw() | ~27 |
| 23:52 | Edited src/gui/WMHud.lua | expanded (+7 lines) | ~221 |
| 23:52 | Fixed auto-hide HUD: update(dt) was never called; switched to g_currentMission.time absolute timestamp checked in draw() | src/gui/WMHud.lua | auto-hide now works | ~100 |
| 23:53 | Session end: 12 writes across 2 files (WMStepDialog.xml, WMHud.lua) | 3 reads | ~13929 tok |
| 23:56 | Edited src/WorkflowManager.lua | hide() → draw() | ~60 |
| 23:56 | Edited src/gui/WMHud.lua | draw() → hide() | ~74 |
| 23:56 | Edited src/gui/WMHud.lua | reduced (-16 lines) | ~52 |
| 23:56 | Edited src/gui/WMHud.lua | 4→2 lines | ~39 |
| 23:56 | Fixed auto-hide: checkAndHideHUD() was immediately hiding HUD; now sets autoHideAt timer instead; update(dt) fires hide after 3s | WorkflowManager.lua, WMHud.lua | auto-hide works | ~120 |
| 23:56 | Session end: 16 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 4 reads | ~14169 tok |
| 00:03 | Edited src/WorkflowManager.lua | 5→8 lines | ~144 |
| 00:03 | Edited src/gui/WMHud.lua | modified WMHud() | ~120 |
| 00:03 | Session end: 18 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 6 reads | ~27389 tok |
| 00:06 | Session end: 18 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 6 reads | ~27389 tok |
| 00:08 | Edited src/WorkflowManager.lua | update() → set() | ~347 |
| 00:08 | Session end: 19 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 6 reads | ~27846 tok |
| 00:14 | Edited src/gui/WMHud.lua | modified WMHud() | ~225 |
| 00:14 | Edited src/gui/WMHud.lua | — | ~0 |
| 00:14 | Edited src/WorkflowManager.lua | removed 28 lines | ~38 |
| 00:14 | Rearchitected HUD auto-hide: update(dt) polls workflow state every frame; show/hide/timer all in one place | WMHud.lua, WorkflowManager.lua | all vehicle-switch cases handled correctly | ~100 |
| 00:14 | Session end: 22 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 6 reads | ~28127 tok |
| 00:19 | Edited src/gui/WMHud.lua | modified WMHud() | ~252 |
| 00:19 | Session end: 23 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 6 reads | ~28397 tok |
| 00:25 | Edited src/WorkflowManagerSpec.lua | expanded (+8 lines) | ~109 |
| 00:25 | Edited src/gui/WMHud.lua | 5→4 lines | ~41 |
| 00:25 | HUD re-show on vehicle switch: added WMHud:show() to onRegisterActionEvents when wmExecution present | WorkflowManagerSpec.lua | HUD shows when entering vehicle with active workflow | ~80 |
| 00:25 | Session end: 25 writes across 4 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua, WorkflowManagerSpec.lua) | 7 reads | ~28329 tok |
| 00:28 | HUD auto-hide/show fully working: hide after 3s on workflow end, re-show on vehicle enter with active workflow | WMHud.lua, WorkflowManagerSpec.lua | confirmed working | ~50 |
| 00:28 | Session end: 25 writes across 4 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua, WorkflowManagerSpec.lua) | 7 reads | ~28329 tok |

## Session: 2026-04-08 00:30

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 00:38 | Edited src/WorkflowManager.lua | 10→8 lines | ~83 |

| 00:00 | bug-046: support vehicle not starting — mode dialog callback re-queried getCurrentVehicle() instead of using closure vehicle | src/WorkflowManager.lua | fixed | ~200 |
| 00:38 | Session end: 1 writes across 1 files (WorkflowManager.lua) | 2 reads | ~12882 tok |
| 00:44 | Session end: 1 writes across 1 files (WorkflowManager.lua) | 4 reads | ~12838 tok |
| 00:56 | Session end: 1 writes across 1 files (WorkflowManager.lua) | 5 reads | ~12838 tok |
| 00:58 | Session end: 1 writes across 1 files (WorkflowManager.lua) | 5 reads | ~12838 tok |

## Session: 2026-04-08 00:59

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-04-09 13:08

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 13:11 | Edited src/gui/WMEditorDialog.lua | 3→3 lines | ~42 |

| 13:11 | fix: support sub-step numbers missing in editor step list | WMEditorDialog.lua:191 | stepNum now shows └N instead of just └ | ~50 |
| 13:11 | Session end: 1 writes across 1 files (WMEditorDialog.lua) | 1 reads | ~5239 tok |
| 13:16 | Edited src/gui/WMEditorDialog.lua | "\226\148\148" → "." | ~35 |
| 13:16 | Session end: 2 writes across 1 files (WMEditorDialog.lua) | 1 reads | ~5277 tok |
| 00:22 | Edited CLAUDE.md | 1→2 lines | ~93 |
| 00:22 | Edited CLAUDE.md | inline fix | ~8 |
| 00:22 | update CLAUDE.md + docs for N.M sub-step numbering | CLAUDE.md | completed | ~50 |
| 00:22 | Session end: 4 writes across 2 files (WMEditorDialog.lua, CLAUDE.md) | 5 reads | ~5384 tok |
| 00:29 | Edited CLAUDE.md | modified Support() | ~504 |
| 00:29 | Edited CLAUDE.md | inline fix | ~84 |
| 00:29 | cleanup CLAUDE.md from 2nd-to-last commit (2ac1983) — added 11 completed items for UI polish | CLAUDE.md | completed | ~200 |
| 00:30 | Session end: 6 writes across 2 files (WMEditorDialog.lua, CLAUDE.md) | 5 reads | ~12341 tok |

## Session: 2026-04-09 00:31

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 00:35 | Edited website/docs/intro.md | inline fix | ~50 |
| 00:35 | Edited website/docs/intro.md | inline fix | ~31 |
| 00:35 | Edited website/docs/ui/main-dialog.md | 14→14 lines | ~193 |
| 00:35 | Edited website/docs/ui/main-dialog.md | name() → progress() | ~123 |
| 00:35 | Edited website/docs/ui/main-dialog.md | removed 19 lines | ~5 |
| 00:36 | Edited website/docs/ui/hud-controls.md | 48→48 lines | ~556 |
| 00:36 | Edited website/docs/ui/hud-controls.md | type() → step() | ~137 |
| 00:36 | Edited website/docs/faq.md | 3→3 lines | ~64 |
| 00:36 | Edited website/docs/faq.md | 25→21 lines | ~292 |
| 00:37 | Edited website/docs/troubleshooting.md | 5→5 lines | ~190 |

## Session: 2026-04-10

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| -- | Updated Docusaurus docs to match current implementation | intro.md, main-dialog.md, hud-controls.md, faq.md, troubleshooting.md | Removed old Link/Unlink system refs; updated HUD header/step/badge format; replaced old FAQ linked-workflows section; fixed broken anchor in troubleshooting | ~8000 |
| 00:37 | Session end: 10 writes across 5 files (intro.md, main-dialog.md, hud-controls.md, faq.md, troubleshooting.md) | 11 reads | ~1760 tok |
| 00:45 | Edited website/docs/ui/main-dialog.md | removed 18 lines | ~19 |
| 00:45 | Edited website/docs/ui/editor-dialog.md | removed 21 lines | ~14 |
| 00:46 | Edited website/docs/ui/editor-dialog.md | removed 23 lines | ~39 |
| 00:46 | Edited website/docs/ui/hud-controls.md | reduced (-9 lines) | ~34 |
| 00:46 | Edited website/docs/ui/hud-controls.md | reduced (-8 lines) | ~38 |
| 00:46 | Edited website/docs/ui/hud-controls.md | reduced (-10 lines) | ~75 |
| 00:46 | Edited website/docs/workflows/linked-workflows.md | reduced (-9 lines) | ~23 |
| 00:46 | Edited website/docs/workflows/linked-workflows.md | reduced (-9 lines) | ~25 |
| 00:46 | Edited website/docs/workflows/linked-workflows.md | reduced (-9 lines) | ~28 |
| 00:46 | Edited website/docs/workflows/linked-workflows.md | reduced (-8 lines) | ~36 |
| 00:47 | Session end: 20 writes across 7 files (intro.md, main-dialog.md, hud-controls.md, faq.md, troubleshooting.md) | 11 reads | ~5013 tok |
| 13:01 | Created docs/SCREENSHOTS.md | — | ~1332 |
| 13:02 | Session end: 21 writes across 8 files (intro.md, main-dialog.md, hud-controls.md, faq.md, troubleshooting.md) | 11 reads | ~6441 tok |

## Session: 2026-04-10 21:29

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 21:55 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~234 |
| 21:55 | Edited src/WorkflowExecutor.lua | 8→9 lines | ~154 |
| 21:55 | Edited src/WorkflowExecutor.lua | 6→7 lines | ~82 |
| 21:55 | Edited src/WorkflowExecutor.lua | 7→8 lines | ~126 |
| 21:55 | Edited src/WorkflowExecutor.lua | expanded (+6 lines) | ~146 |
| 21:55 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~462 |
| 21:57 | Edited src/WorkflowExecutor.lua | modified info() | ~451 |
| 21:58 | Session end: 7 writes across 1 files (WorkflowExecutor.lua) | 2 reads | ~19165 tok |
| 21:59 | Edited CLAUDE.md | expanded (+12 lines) | ~514 |
| 21:59 | Edited CLAUDE.md | 3→5 lines | ~323 |
| 21:59 | Edited CLAUDE.md | idles() → hold() | ~90 |
| 21:59 | Edited CLAUDE.md | 1→2 lines | ~52 |
| 21:59 | Edited CLAUDE.md | 4→4 lines | ~78 |
| 21:59 | Edited CLAUDE.md | inline fix | ~42 |
| 21:59 | Session end: 13 writes across 2 files (WorkflowExecutor.lua, CLAUDE.md) | 3 reads | ~27092 tok |
| 22:01 | Edited src/integration/AutoDriveIntegration.lua | 6→11 lines | ~91 |
| 22:02 | Session end: 14 writes across 3 files (WorkflowExecutor.lua, CLAUDE.md, AutoDriveIntegration.lua) | 3 reads | ~27189 tok |
| 22:03 | Edited CLAUDE.md | reduced (-19 lines) | ~60 |
| 22:03 | Edited CLAUDE.md | reduced (-25 lines) | ~87 |
| 22:03 | Edited CLAUDE.md | reduced (-23 lines) | ~141 |
| 22:04 | Edited CLAUDE.md | removed 40 lines | ~207 |
| 22:04 | Edited CLAUDE.md | 14→9 lines | ~198 |
| 22:04 | Edited CLAUDE.md | reduced (-10 lines) | ~94 |
| 22:04 | Session end: 20 writes across 3 files (WorkflowExecutor.lua, CLAUDE.md, AutoDriveIntegration.lua) | 3 reads | ~26212 tok |
