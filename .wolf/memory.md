# Memory

> Chronological action log. Hooks and AI append to this file automatically.
> Old sessions are consolidated by the daemon weekly.
| 14:36 | Free follower when leader switches to different workflow | WorkflowExecutor.lua, WorkflowExecutor_spec.lua | 340/340 tests pass | ~200 tok |
| session | Fix setStartHelper reset by AD StartDriving — moved setStartCPOnCompletion to after startRoute | WorkflowExecutor.lua, WorkflowExecutor_spec.lua | 364/364 tests pass | ~300 tok |
| 2026-06-08 | Fix 3 bugs from live log: boolean crash at sync line 1057 (or nil guard), goTo*Step not resetting WAITING_FOR_LEADER, CP refill cycle broken (re-intro setStartHelper + cpHandedOffWait grace) | WorkflowExecutor.lua | 363/363 tests pass | ~600 tok |
| 20:11 | Fix stack overflow in WMStepDialog: suppressListCallbacks â†’ isFiltering (guard/flag mismatch) | WMStepDialog.lua | 359/359 tests pass | ~150 tok |
| 20:35 | Change sync condition from > (past) to >= (reached): follower starts when leader is ON its sync step | WorkflowExecutor.lua, WorkflowExecutor_spec.lua | 359/359 tests pass | ~200 tok |
| session | Added per-step sync control (isSyncTarget/isSyncSource): storage, executor, step dialog, XML, translations, 61 new tests â†’ 357/357 pass | WorkflowStorage.lua, WorkflowExecutor.lua, WMStepDialog.lua, WMStepDialog.xml, translation_*.xml, specs | all tests pass | ~4000 tok |
| session | Updated website docs for per-step sync control | website/docs/workflows/queue-system.md, step-types.md, faq.md | docs updated | ~500 tok |
| session | Follower waiting for leader now activates dummy AD hold (same as support waiting for main) | WorkflowExecutor.lua | 359/359 tests pass | ~300 tok |
| session | Added 3 tests for follower dummy AD hold; fixed VehicleMock Lua 5.1 upvalue bug (local vehicle declared before table) | tests/mocks/vehicle.lua, WorkflowExecutor_spec.lua | 362/362 tests pass | ~400 tok |

| 00:00 | Fixed multi-select fill type in WMStepDialog (selectedFillTypes array, toggle on click, checkmark display) | src/gui/WMStepDialog.lua | 332 tests pass | ~4k |
| 00:00 | Fixed mouseEvent stack overflow â€” isFiltering guard around reloadData() in onFillTypeListSelectionChanged | src/gui/WMStepDialog.lua | crash resolved | ~1k |
| 00:00 | Click=single-select, Ctrl+click=multi-select, green text highlight for selected fill types | src/gui/WMStepDialog.lua | 332 tests pass | ~2k |

| 02:40 | Fixed Docusaurus build â€” installed @docusaurus/faster | website/package.json | success | ~200 |

| 2026-04-10 | Added dummy AD hold for support vehicle idle state + fixed justStoppedAD not cleared in resetStepTrackingState | WorkflowExecutor.lua | 106/106 tests pass |
| 2026-04-29 | Support vehicle no longer paused/resumed when main pauses/resumes â€” support runs independently | WorkflowExecutor.lua, WorkflowExecutor_spec.lua | 109/109 tests pass |
| 2026-05-20 | Extracted website/ into sibling git repo FS25_WorkflowManager-docs; re-added as git subtree --squash | website/ (subtree), ../FS25_WorkflowManager-docs | 296/296 tests pass |
| 2026-05-21 | Fixed 2 failing fillTypeâ†’fillTypes tests; added 4 fillTypes tests (multi, nil, support sub-step, legacy migration) + 5 leader/follower executor tests | WorkflowStorage_spec.lua, WorkflowExecutor_spec.lua | 332/332 tests pass |

## Session: 2026-04-05 23:05

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-04-05 23:34

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 00:03 | Created ../../../../../.claude/plans/twinkling-marinating-wind.md | â€” | ~3646 |
| 00:13 | Created ../../../../../.claude/plans/twinkling-marinating-wind.md | â€” | ~4415 |
| 00:19 | Created src/WorkflowStorage.lua | â€” | ~3097 |
| 00:20 | Created tests/specs/WorkflowStorage_spec.lua | â€” | ~6279 |
| 00:22 | Created tests/run_storage_spec.lua | â€” | ~1245 |
| 00:23 | Edited tests/specs/WorkflowStorage_spec.lua | modified saveOldFormat() | ~142 |
| 00:23 | Edited tests/specs/WorkflowStorage_spec.lua | 5â†’6 lines | ~88 |
| 00:24 | Edited tests/specs/WorkflowStorage_spec.lua | 7â†’11 lines | ~145 |
| 00:25 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~179 |
| 00:25 | Edited src/WorkflowManager.lua | 8â†’9 lines | ~89 |
| 00:25 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~535 |
| 00:26 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~150 |
| 00:26 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~499 |
| 00:26 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~526 |
| 00:26 | Edited src/network/WMNetworkEvents.lua | modified WMCommandEvent() | ~515 |
| 00:27 | Edited src/WorkflowManager.lua | 15â†’18 lines | ~138 |
| 00:27 | Edited tests/specs/WorkflowManager_spec.lua | 16â†’16 lines | ~153 |
| 00:27 | Edited tests/specs/WorkflowManager_spec.lua | expanded (+33 lines) | ~568 |
| 00:27 | Edited tests/specs/WorkflowManager_spec.lua | 7â†’7 lines | ~125 |
| 00:27 | Edited tests/specs/WorkflowManager_spec.lua | 9â†’13 lines | ~189 |
| 00:28 | Edited tests/specs/WorkflowManager_spec.lua | reduced (-93 lines) | ~856 |
| 00:28 | Edited tests/specs/WorkflowManager_spec.lua | expanded (+8 lines) | ~890 |
| 00:28 | Edited tests/specs/WorkflowManager_spec.lua | removed 65 lines | ~20 |

## Session: 2026-04-06 07:23

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 07:28 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~108 |
| 07:28 | Edited src/WorkflowExecutor.lua | 30â†’27 lines | ~328 |
| 07:28 | Edited src/WorkflowExecutor.lua | 9â†’9 lines | ~126 |
| 07:28 | Edited src/WorkflowExecutor.lua | getActiveVehiclesForWorkflow() â†’ getSupportActiveDataListForWorkflow() | ~172 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~1034 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~168 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~133 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~87 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~109 |
| 07:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~189 |
| 07:30 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~881 |
| 07:30 | Edited src/WorkflowExecutor.lua | getActiveVehiclesForWorkflow() â†’ getSupportActiveDataListForWorkflow() | ~111 |
| 07:30 | Edited src/WorkflowExecutor.lua | modified info() | ~318 |
| 07:31 | Edited src/WorkflowExecutor.lua | 20â†’20 lines | ~304 |
| 07:31 | Edited src/WorkflowExecutor.lua | 19â†’19 lines | ~286 |
| 07:31 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~764 |
| 07:31 | Edited src/WorkflowExecutor.lua | removed 18 lines | ~1 |
| 07:31 | Edited src/WorkflowExecutor.lua | 41â†’43 lines | ~392 |
| 07:32 | Edited src/WorkflowExecutor.lua | 46â†’48 lines | ~432 |
| 07:33 | Edited tests/specs/WorkflowExecutor_spec.lua | 12â†’11 lines | ~122 |
| 07:33 | Edited tests/specs/WorkflowExecutor_spec.lua | modified makeWorkflow() | ~363 |
| 07:34 | Edited tests/specs/WorkflowExecutor_spec.lua | modified makeMainSupportPair() | ~3547 |
| 07:35 | Edited tests/specs/WorkflowExecutor_spec.lua | 4â†’2 lines | ~48 |
| 07:35 | Edited tests/specs/WorkflowExecutor_spec.lua | 2â†’1 lines | ~12 |
| 07:35 | Edited tests/specs/WorkflowExecutor_spec.lua | removed 21 lines | ~12 |
| 07:49 | Edited tests/specs/WorkflowExecutor_spec.lua | removed 38 lines | ~19 |
| 07:49 | Edited src/WorkflowExecutor.lua | 2â†’2 lines | ~27 |
| 07:49 | Edited src/WorkflowExecutor.lua | expanded (+12 lines) | ~252 |
| 07:49 | Edited src/WorkflowExecutor.lua | expanded (+10 lines) | ~199 |
| 07:50 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+6 lines) | ~282 |
| 07:50 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+11 lines) | ~231 |
| 07:51 | Phase 3 WorkflowExecutor rewrite â€” hierarchical support (isMainVehicle, currentSupportStep, onMainStepChanged) | src/WorkflowExecutor.lua, tests/specs/WorkflowExecutor_spec.lua | 106/106 tests passing | ~12000 tok |
| 07:51 | Edited CLAUDE.md | refinement() â†’ steps() | ~80 |
| 07:52 | Edited CLAUDE.md | 42â†’45 lines | ~566 |
| 07:52 | Edited CLAUDE.md | 18â†’21 lines | ~279 |
| 07:52 | Edited CLAUDE.md | 4â†’3 lines | ~198 |
| 07:52 | Edited CLAUDE.md | 15â†’12 lines | ~325 |
| 07:53 | Session end: 36 writes across 3 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua, CLAUDE.md) | 3 reads | ~47928 tok |

## Session: 2026-04-06 07:57

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 08:00 | Edited src/gui/WMMainDialog.lua | getText() â†’ hasSupportSteps() | ~99 |
| 08:01 | Edited src/gui/WMStepDialog.lua | 12â†’8 lines | ~48 |
| 08:01 | Edited src/gui/WMStepDialog.lua | modified Callback() | ~213 |
| 08:01 | Edited src/gui/WMStepDialog.lua | reduced (-9 lines) | ~24 |
| 08:01 | Edited src/gui/WMStepDialog.lua | 13â†’8 lines | ~67 |
| 08:01 | Edited src/gui/WMStepDialog.lua | removed 10 lines | ~5 |
| 08:01 | Edited src/gui/WMEditorDialog.lua | 4â†’1 lines | ~7 |
| 08:01 | Edited src/gui/WMEditorDialog.lua | removed 70 lines | ~7 |
| 08:01 | Edited src/gui/WMEditorDialog.lua | 9â†’6 lines | ~75 |
| 08:02 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~442 |
| 21:10 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~611 |
| 21:11 | Created xml/gui/WMEditorDialog.xml | â€” | ~1472 |
| 21:11 | Edited src/gui/WMHud.lua | 2â†’2 lines | ~26 |
| 21:11 | Edited src/gui/WMHud.lua | modified renderText() | ~340 |
| 21:11 | Created src/gui/WMModeSelectDialog.lua | â€” | ~537 |
| 21:11 | Created xml/gui/WMModeSelectDialog.xml | â€” | ~427 |
| 21:12 | Edited src/WorkflowManager.lua | 4â†’5 lines | ~98 |
| 21:12 | Edited src/WorkflowManager.lua | expanded (+13 lines) | ~260 |
| 21:12 | Edited src/WorkflowManager.lua | modified Callback() | ~134 |
| 21:12 | Edited translations/translation_en.xml | reduced (-6 lines) | ~208 |
| 21:12 | Edited translations/translation_de.xml | expanded (+13 lines) | ~293 |
| 21:13 | Phase 4 GUI complete: WMModeSelectDialog, support step editing in editor, HUD support status, linkRole/syncGroup UI removed | 9 files | 106/106 tests passing | ~22000 tok |
| 21:13 | Session end: 21 writes across 10 files (WMMainDialog.lua, WMStepDialog.lua, WMEditorDialog.lua, WMEditorDialog.xml, WMHud.lua) | 8 reads | ~18590 tok |
| 21:51 | Created src/gui/WMEditorDialog.lua | â€” | ~5297 |
| 21:51 | Edited xml/gui/WMEditorDialog.xml | 6â†’5 lines | ~131 |
| 21:51 | Edited translations/translation_en.xml | 2â†’3 lines | ~80 |
| 21:52 | Edited translations/translation_de.xml | 2â†’3 lines | ~91 |
| 21:52 | Session end: 25 writes across 10 files (WMMainDialog.lua, WMStepDialog.lua, WMEditorDialog.lua, WMEditorDialog.xml, WMHud.lua) | 8 reads | ~29155 tok |
| 22:08 | Edited src/gui/WMEditorDialog.lua | 20â†’20 lines | ~197 |
| 22:08 | Session end: 26 writes across 10 files (WMMainDialog.lua, WMStepDialog.lua, WMEditorDialog.lua, WMEditorDialog.xml, WMHud.lua) | 8 reads | ~29366 tok |
| 22:14 | Edited src/gui/WMEditorDialog.lua | 5â†’5 lines | ~47 |
| 22:14 | Edited src/gui/WMHud.lua | expanded (+18 lines) | ~428 |
| 22:14 | Session end: 28 writes across 10 files (WMMainDialog.lua, WMStepDialog.lua, WMEditorDialog.lua, WMEditorDialog.xml, WMHud.lua) | 8 reads | ~36257 tok |
| 10:42 | Edited src/WorkflowManagerSpec.lua | 7â†’11 lines | ~177 |
| 10:42 | Edited src/WorkflowManagerSpec.lua | 7â†’12 lines | ~195 |
| 10:42 | Edited src/WorkflowManagerSpec.lua | expanded (+10 lines) | ~339 |
| 10:42 | Edited src/WorkflowManagerSpec.lua | 10â†’13 lines | ~179 |
| 10:42 | Edited src/WorkflowManagerSpec.lua | 18â†’23 lines | ~269 |
| 10:42 | Edited src/network/WMNetworkEvents.lua | 11â†’15 lines | ~164 |
| 10:42 | Edited src/network/WMNetworkEvents.lua | modified WMStateSyncEvent() | ~265 |
| 10:42 | Edited src/network/WMNetworkEvents.lua | 4â†’6 lines | ~95 |
| 10:43 | Edited src/WorkflowExecutor.lua | 10â†’15 lines | ~205 |
| 10:43 | Session end: 37 writes across 13 files (WMMainDialog.lua, WMStepDialog.lua, WMEditorDialog.lua, WMEditorDialog.xml, WMHud.lua) | 10 reads | ~54883 tok |
| 12:28 | Created website/docs/workflows/linked-workflows.md | â€” | ~2005 |

## Session: 2026-04-07 12:30

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 12:31 | Created website/docs/ui/editor-dialog.md | â€” | ~1611 |
| 12:32 | Created website/docs/ui/hud-controls.md | â€” | ~1527 |
| 12:32 | Created website/docs/workflows/executing-workflows.md | â€” | ~1804 |
| 12:33 | Created website/docs/workflows/creating-workflows.md | â€” | ~1733 |
| 12:33 | Created website/docs/api/xml-format.md | â€” | ~1974 |
| 12:34 | Updated 5 Docusaurus docs for hierarchical support steps | website/docs/ui/editor-dialog.md, hud-controls.md, workflows/executing-workflows.md, creating-workflows.md, api/xml-format.md | Removed syncGroup/linkRole/linkedWorkflowId references; added N.M numbering, role dialog, nested support sub-step docs | ~3000 |
| 12:34 | Session end: 5 writes across 5 files (editor-dialog.md, hud-controls.md, executing-workflows.md, creating-workflows.md, xml-format.md) | 5 reads | ~9266 tok |

## Session: 2026-04-07 22:11

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 23:10 | Edited src/WorkflowExecutor.lua | 10â†’11 lines | ~193 |
| 23:10 | Edited src/WorkflowExecutor.lua | modified info() | ~160 |
| 23:10 | Edited src/WorkflowExecutor.lua | 4â†’5 lines | ~77 |
| 23:11 | Fix support vehicle restart loop after last sub-step | WorkflowExecutor.lua | waitingForMainStepIndex tracks which step triggered idle; idle poll only restarts when main step changes | ~500 tok |
| 23:12 | Session end: 3 writes across 1 files (WorkflowExecutor.lua) | 1 reads | ~17147 tok |

## Session: 2026-04-07 23:19

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 23:21 | Edited xml/gui/WMModeSelectDialog.xml | inline fix | ~16 |
| 23:21 | Edited xml/gui/WMModeSelectDialog.xml | "500px 50px" â†’ "660px 50px" | ~10 |
| 07:00 | Fixed WMModeSelectDialog button overflow: dialog 540pxâ†’700px, height 220pxâ†’240px, desc width 500pxâ†’660px | xml/gui/WMModeSelectDialog.xml | fixed | ~20 |
| 23:21 | Session end: 2 writes across 1 files (WMModeSelectDialog.xml) | 4 reads | ~2431 tok |
| 23:32 | Edited translations/translation_en.xml | 2â†’2 lines | ~36 |
| 23:32 | Edited translations/translation_de.xml | 2â†’2 lines | ~36 |
| 23:32 | Session end: 4 writes across 3 files (WMModeSelectDialog.xml, translation_en.xml, translation_de.xml) | 6 reads | ~7075 tok |
| 23:40 | Session end: 4 writes across 3 files (WMModeSelectDialog.xml, translation_en.xml, translation_de.xml) | 6 reads | ~7075 tok |

## Session: 2026-04-08 11:12

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-04-08 11:13

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 11:19 | Edited xml/gui/WMEditorDialog.xml | 9â†’10 lines | ~322 |
| 11:19 | Edited xml/gui/WMEditorDialog.xml | â€” | ~0 |
| 11:20 | Edited src/gui/WMEditorDialog.lua | â€” | ~0 |
| 11:20 | Remove support step counter text and fix button overlap | WMEditorDialog.xml, WMEditorDialog.lua | Removed supportStepInfo row; moved addSupportStepButton into header buttons row | ~300 |
| 11:20 | Session end: 3 writes across 2 files (WMEditorDialog.xml, WMEditorDialog.lua) | 2 reads | ~345 tok |
| 11:26 | Edited xml/gui/WMEditorDialog.xml | inline fix | ~16 |
| 11:26 | Edited xml/gui/WMEditorDialog.xml | 4â†’4 lines | ~102 |
| 11:26 | Edited xml/gui/WMEditorDialog.xml | 2â†’2 lines | ~31 |
| 11:26 | Edited xml/gui/WMEditorDialog.xml | 26â†’26 lines | ~473 |
| 11:26 | Session end: 7 writes across 2 files (WMEditorDialog.xml, WMEditorDialog.lua) | 2 reads | ~2388 tok |
| 13:05 | Edited xml/gui/WMEditorDialog.xml | 2â†’1 lines | ~43 |
| 13:05 | Edited xml/gui/WMEditorDialog.xml | 2â†’1 lines | ~26 |
| 13:05 | Edited xml/gui/WMEditorDialog.xml | 2â†’1 lines | ~26 |
| 13:05 | Edited src/gui/WMEditorDialog.lua | â€” | ~0 |
| 13:05 | Edited src/gui/WMEditorDialog.lua | removed 6 lines | ~1 |
| 13:05 | Session end: 12 writes across 2 files (WMEditorDialog.xml, WMEditorDialog.lua) | 2 reads | ~2491 tok |
| 13:06 | Edited xml/gui/WMEditorDialog.xml | 1â†’2 lines | ~90 |
| 13:06 | Edited src/gui/WMEditorDialog.lua | 2â†’7 lines | ~57 |
| 13:06 | Session end: 14 writes across 2 files (WMEditorDialog.xml, WMEditorDialog.lua) | 2 reads | ~2648 tok |
| 13:07 | Session end: 14 writes across 2 files (WMEditorDialog.xml, WMEditorDialog.lua) | 2 reads | ~2648 tok |
| 14:03 | Edited xml/gui/WMStepDialog.xml | removed 12 lines | ~1 |
| 14:03 | Session end: 15 writes across 3 files (WMEditorDialog.xml, WMEditorDialog.lua, WMStepDialog.xml) | 3 reads | ~2649 tok |
| 15:02 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~135 |
| 15:02 | Session end: 16 writes across 3 files (WMEditorDialog.xml, WMEditorDialog.lua, WMStepDialog.xml) | 3 reads | ~2794 tok |

## Session: 2026-04-08 15:11

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 15:22 | Created ../../../../../.claude/plans/sprightly-jingling-frog.md | â€” | ~2253 |
| 15:31 | Session end: 1 writes across 1 files (sprightly-jingling-frog.md) | 13 reads | ~9517 tok |
| 15:31 | Session end: 1 writes across 1 files (sprightly-jingling-frog.md) | 13 reads | ~9517 tok |
| 15:41 | Session end: 1 writes across 1 files (sprightly-jingling-frog.md) | 13 reads | ~9517 tok |
| 15:41 | Edited ../../../../../.claude/plans/sprightly-jingling-frog.md | removed 7 lines | ~1 |
| 15:41 | Edited ../../../../../.claude/plans/sprightly-jingling-frog.md | removed 7 lines | ~2 |
| 15:41 | Edited ../../../../../.claude/plans/sprightly-jingling-frog.md | 4â†’3 lines | ~63 |
| 15:46 | Edited xml/gui/guiProfiles.xml | "0.7 0.7 0.7 1" â†’ "0.85 0.85 0.85 1" | ~12 |
| 15:47 | Edited xml/gui/WMEditorDialog.xml | 35â†’37 lines | ~803 |
| 15:47 | Edited src/gui/WMEditorDialog.lua | 30â†’28 lines | ~322 |
| 15:47 | Edited src/gui/WMMainDialog.lua | count() â†’ setColor() | ~563 |
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

| 15:58 | UI improvement pass: column contrast, editor column reorder (Typeâ†’Actionâ†’Target), support step 'â””' prefix, main dialog status color, step dialog selected labels + clear buttons + auto-select, HUD vehicle name header + full type names + progress bar + support badge + button tooltips + auto-hide timer | WMHud.lua WMMainDialog.lua WMEditorDialog.lua WMEditorDialog.xml WMStepDialog.lua WMStepDialog.xml guiProfiles.xml translations | 106 tests pass | ~4000 |
| 15:58 | Session end: 24 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~21437 tok |
| 16:02 | Edited src/gui/WMMainDialog.lua | setColor() â†’ setTextColor() | ~119 |
| 16:02 | Session end: 25 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~21565 tok |
| 22:14 | Edited xml/gui/WMStepDialog.xml | inline fix | ~26 |
| 22:14 | Session end: 26 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~21593 tok |
| 22:19 | Edited xml/gui/WMStepDialog.xml | â€” | ~0 |
| 22:19 | Session end: 27 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~21593 tok |
| 22:26 | Edited src/gui/WMHud.lua | removed 5 lines | ~5 |
| 22:27 | Edited src/gui/WMHud.lua | removed 13 lines | ~8 |
| 22:27 | Edited src/gui/WMHud.lua | â€” | ~0 |
| 22:27 | Edited src/gui/WMHud.lua | removed 9 lines | ~8 |
| 22:27 | Edited src/gui/WMHud.lua | removed 18 lines | ~6 |
| 22:27 | Edited src/gui/WMHud.lua | 6â†’3 lines | ~38 |
| 22:27 | Edited src/gui/WMHud.lua | 15â†’13 lines | ~182 |
| 22:27 | Edited src/gui/WMHud.lua | 2â†’2 lines | ~16 |
| 22:27 | Session end: 35 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~21873 tok |
| 22:38 | Edited xml/gui/WMEditorDialog.xml | 6â†’4 lines | ~176 |
| 22:38 | Session end: 36 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~22061 tok |
| 22:41 | Edited src/gui/WMHud.lua | 3â†’4 lines | ~58 |
| 22:41 | Edited src/gui/WMHud.lua | 9â†’13 lines | ~155 |
| 22:41 | Edited src/gui/WMHud.lua | 2â†’6 lines | ~70 |
| 22:41 | Session end: 39 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~22363 tok |
| 22:47 | Edited src/gui/WMHud.lua | reduced (-7 lines) | ~162 |
| 22:47 | Session end: 40 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~22537 tok |
| 22:50 | Edited xml/gui/WMEditorDialog.xml | 7â†’7 lines | ~171 |
| 22:50 | Session end: 41 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~22728 tok |
| 22:56 | Edited xml/gui/WMEditorDialog.xml | 7â†’9 lines | ~204 |
| 22:56 | Session end: 42 writes across 10 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~22947 tok |
| 22:59 | Edited xml/gui/WMMainDialog.xml | 5â†’7 lines | ~130 |
| 22:59 | Session end: 43 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~23086 tok |
| 23:02 | Created xml/gui/WMStepDialog.xml | â€” | ~2349 |
| 23:03 | Session end: 44 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~25967 tok |
| 23:07 | Created xml/gui/WMStepDialog.xml | â€” | ~2358 |
| 23:07 | Session end: 45 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~28493 tok |
| 23:11 | Edited xml/gui/WMStepDialog.xml | 8â†’10 lines | ~208 |
| 23:11 | Edited xml/gui/WMStepDialog.xml | 7â†’9 lines | ~212 |
| 23:11 | Edited xml/gui/WMStepDialog.xml | 7â†’9 lines | ~202 |
| 23:11 | Session end: 48 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~29160 tok |
| 23:20 | Edited xml/gui/WMStepDialog.xml | 10â†’7 lines | ~137 |
| 23:20 | Edited xml/gui/WMStepDialog.xml | 9â†’6 lines | ~139 |
| 23:21 | Edited xml/gui/WMStepDialog.xml | 9â†’6 lines | ~131 |
| 23:21 | Edited src/gui/WMStepDialog.lua | â€” | ~0 |
| 23:21 | Session end: 52 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~29596 tok |
| 23:28 | Edited xml/gui/WMStepDialog.xml | 7â†’10 lines | ~186 |
| 23:28 | Edited xml/gui/WMStepDialog.xml | 6â†’9 lines | ~187 |
| 23:28 | Edited xml/gui/WMStepDialog.xml | 6â†’9 lines | ~178 |
| 23:28 | Session end: 55 writes across 11 files (sprightly-jingling-frog.md, guiProfiles.xml, WMEditorDialog.xml, WMEditorDialog.lua, WMMainDialog.lua) | 15 reads | ~30185 tok |
| 23:33 | Edited xml/gui/WMStepDialog.xml | "460px 120px" â†’ "500px 120px" | ~5 |

## Session: 2026-04-08 23:35

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 23:40 | Edited xml/gui/WMStepDialog.xml | 19â†’14 lines | ~223 |
| 23:41 | Edited xml/gui/WMStepDialog.xml | 19â†’14 lines | ~229 |
| 23:41 | Edited xml/gui/WMStepDialog.xml | 19â†’14 lines | ~226 |
| 23:41 | Removed sliders from Step Dialog lists; SmoothList now 500px full-width (no inner wrapper) | xml/gui/WMStepDialog.xml | lists match dropdown width | ~200 |
| 23:41 | Session end: 3 writes across 1 files (WMStepDialog.xml) | 2 reads | ~4182 tok |
| 23:45 | Edited xml/gui/WMStepDialog.xml | 14â†’17 lines | ~295 |
| 23:45 | Edited xml/gui/WMStepDialog.xml | 14â†’17 lines | ~282 |
| 23:46 | Edited xml/gui/WMStepDialog.xml | 14â†’17 lines | ~278 |
| 23:46 | Re-added sliders to Step Dialog lists; 3-child wm_hBox with 200px spacer for aligned left edge | xml/gui/WMStepDialog.xml | sliders back, list width preserved at 500px | ~150 |
| 23:46 | Session end: 6 writes across 1 files (WMStepDialog.xml) | 2 reads | ~5098 tok |
| 23:48 | Edited xml/gui/WMStepDialog.xml | 17â†’19 lines | ~331 |
| 23:48 | Edited xml/gui/WMStepDialog.xml | 17â†’19 lines | ~331 |
| 23:48 | Edited xml/gui/WMStepDialog.xml | 17â†’19 lines | ~327 |
| 23:49 | Session end: 9 writes across 1 files (WMStepDialog.xml) | 2 reads | ~6158 tok |
| 23:52 | Edited src/gui/WMHud.lua | 4â†’4 lines | ~68 |
| 23:52 | Edited src/gui/WMHud.lua | hide() â†’ draw() | ~27 |
| 23:52 | Edited src/gui/WMHud.lua | expanded (+7 lines) | ~221 |
| 23:52 | Fixed auto-hide HUD: update(dt) was never called; switched to g_currentMission.time absolute timestamp checked in draw() | src/gui/WMHud.lua | auto-hide now works | ~100 |
| 23:53 | Session end: 12 writes across 2 files (WMStepDialog.xml, WMHud.lua) | 3 reads | ~13929 tok |
| 23:56 | Edited src/WorkflowManager.lua | hide() â†’ draw() | ~60 |
| 23:56 | Edited src/gui/WMHud.lua | draw() â†’ hide() | ~74 |
| 23:56 | Edited src/gui/WMHud.lua | reduced (-16 lines) | ~52 |
| 23:56 | Edited src/gui/WMHud.lua | 4â†’2 lines | ~39 |
| 23:56 | Fixed auto-hide: checkAndHideHUD() was immediately hiding HUD; now sets autoHideAt timer instead; update(dt) fires hide after 3s | WorkflowManager.lua, WMHud.lua | auto-hide works | ~120 |
| 23:56 | Session end: 16 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 4 reads | ~14169 tok |
| 00:03 | Edited src/WorkflowManager.lua | 5â†’8 lines | ~144 |
| 00:03 | Edited src/gui/WMHud.lua | modified WMHud() | ~120 |
| 00:03 | Session end: 18 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 6 reads | ~27389 tok |
| 00:06 | Session end: 18 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 6 reads | ~27389 tok |
| 00:08 | Edited src/WorkflowManager.lua | update() â†’ set() | ~347 |
| 00:08 | Session end: 19 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 6 reads | ~27846 tok |
| 00:14 | Edited src/gui/WMHud.lua | modified WMHud() | ~225 |
| 00:14 | Edited src/gui/WMHud.lua | â€” | ~0 |
| 00:14 | Edited src/WorkflowManager.lua | removed 28 lines | ~38 |
| 00:14 | Rearchitected HUD auto-hide: update(dt) polls workflow state every frame; show/hide/timer all in one place | WMHud.lua, WorkflowManager.lua | all vehicle-switch cases handled correctly | ~100 |
| 00:14 | Session end: 22 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 6 reads | ~28127 tok |
| 00:19 | Edited src/gui/WMHud.lua | modified WMHud() | ~252 |
| 00:19 | Session end: 23 writes across 3 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua) | 6 reads | ~28397 tok |
| 00:25 | Edited src/WorkflowManagerSpec.lua | expanded (+8 lines) | ~109 |
| 00:25 | Edited src/gui/WMHud.lua | 5â†’4 lines | ~41 |
| 00:25 | HUD re-show on vehicle switch: added WMHud:show() to onRegisterActionEvents when wmExecution present | WorkflowManagerSpec.lua | HUD shows when entering vehicle with active workflow | ~80 |
| 00:25 | Session end: 25 writes across 4 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua, WorkflowManagerSpec.lua) | 7 reads | ~28329 tok |
| 00:28 | HUD auto-hide/show fully working: hide after 3s on workflow end, re-show on vehicle enter with active workflow | WMHud.lua, WorkflowManagerSpec.lua | confirmed working | ~50 |
| 00:28 | Session end: 25 writes across 4 files (WMStepDialog.xml, WMHud.lua, WorkflowManager.lua, WorkflowManagerSpec.lua) | 7 reads | ~28329 tok |

## Session: 2026-04-08 00:30

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 00:38 | Edited src/WorkflowManager.lua | 10â†’8 lines | ~83 |

| 00:00 | bug-046: support vehicle not starting â€” mode dialog callback re-queried getCurrentVehicle() instead of using closure vehicle | src/WorkflowManager.lua | fixed | ~200 |
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
| 13:11 | Edited src/gui/WMEditorDialog.lua | 3â†’3 lines | ~42 |

| 13:11 | fix: support sub-step numbers missing in editor step list | WMEditorDialog.lua:191 | stepNum now shows â””N instead of just â”” | ~50 |
| 13:11 | Session end: 1 writes across 1 files (WMEditorDialog.lua) | 1 reads | ~5239 tok |
| 13:16 | Edited src/gui/WMEditorDialog.lua | "\226\148\148" â†’ "." | ~35 |
| 13:16 | Session end: 2 writes across 1 files (WMEditorDialog.lua) | 1 reads | ~5277 tok |
| 00:22 | Edited CLAUDE.md | 1â†’2 lines | ~93 |
| 00:22 | Edited CLAUDE.md | inline fix | ~8 |
| 00:22 | update CLAUDE.md + docs for N.M sub-step numbering | CLAUDE.md | completed | ~50 |
| 00:22 | Session end: 4 writes across 2 files (WMEditorDialog.lua, CLAUDE.md) | 5 reads | ~5384 tok |
| 00:29 | Edited CLAUDE.md | modified Support() | ~504 |
| 00:29 | Edited CLAUDE.md | inline fix | ~84 |
| 00:29 | cleanup CLAUDE.md from 2nd-to-last commit (2ac1983) â€” added 11 completed items for UI polish | CLAUDE.md | completed | ~200 |
| 00:30 | Session end: 6 writes across 2 files (WMEditorDialog.lua, CLAUDE.md) | 5 reads | ~12341 tok |

## Session: 2026-04-09 00:31

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 00:35 | Edited website/docs/intro.md | inline fix | ~50 |
| 00:35 | Edited website/docs/intro.md | inline fix | ~31 |
| 00:35 | Edited website/docs/ui/main-dialog.md | 14â†’14 lines | ~193 |
| 00:35 | Edited website/docs/ui/main-dialog.md | name() â†’ progress() | ~123 |
| 00:35 | Edited website/docs/ui/main-dialog.md | removed 19 lines | ~5 |
| 00:36 | Edited website/docs/ui/hud-controls.md | 48â†’48 lines | ~556 |
| 00:36 | Edited website/docs/ui/hud-controls.md | type() â†’ step() | ~137 |
| 00:36 | Edited website/docs/faq.md | 3â†’3 lines | ~64 |
| 00:36 | Edited website/docs/faq.md | 25â†’21 lines | ~292 |
| 00:37 | Edited website/docs/troubleshooting.md | 5â†’5 lines | ~190 |

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
| 13:01 | Created docs/SCREENSHOTS.md | â€” | ~1332 |
| 13:02 | Session end: 21 writes across 8 files (intro.md, main-dialog.md, hud-controls.md, faq.md, troubleshooting.md) | 11 reads | ~6441 tok |

## Session: 2026-04-10 21:29

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 21:55 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~234 |
| 21:55 | Edited src/WorkflowExecutor.lua | 8â†’9 lines | ~154 |
| 21:55 | Edited src/WorkflowExecutor.lua | 6â†’7 lines | ~82 |
| 21:55 | Edited src/WorkflowExecutor.lua | 7â†’8 lines | ~126 |
| 21:55 | Edited src/WorkflowExecutor.lua | expanded (+6 lines) | ~146 |
| 21:55 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~462 |
| 21:57 | Edited src/WorkflowExecutor.lua | modified info() | ~451 |
| 21:58 | Session end: 7 writes across 1 files (WorkflowExecutor.lua) | 2 reads | ~19165 tok |
| 21:59 | Edited CLAUDE.md | expanded (+12 lines) | ~514 |
| 21:59 | Edited CLAUDE.md | 3â†’5 lines | ~323 |
| 21:59 | Edited CLAUDE.md | idles() â†’ hold() | ~90 |
| 21:59 | Edited CLAUDE.md | 1â†’2 lines | ~52 |
| 21:59 | Edited CLAUDE.md | 4â†’4 lines | ~78 |
| 21:59 | Edited CLAUDE.md | inline fix | ~42 |
| 21:59 | Session end: 13 writes across 2 files (WorkflowExecutor.lua, CLAUDE.md) | 3 reads | ~27092 tok |
| 22:01 | Edited src/integration/AutoDriveIntegration.lua | 6â†’11 lines | ~91 |
| 22:02 | Session end: 14 writes across 3 files (WorkflowExecutor.lua, CLAUDE.md, AutoDriveIntegration.lua) | 3 reads | ~27189 tok |
| 22:03 | Edited CLAUDE.md | reduced (-19 lines) | ~60 |
| 22:03 | Edited CLAUDE.md | reduced (-25 lines) | ~87 |
| 22:03 | Edited CLAUDE.md | reduced (-23 lines) | ~141 |
| 22:04 | Edited CLAUDE.md | removed 40 lines | ~207 |
| 22:04 | Edited CLAUDE.md | 14â†’9 lines | ~198 |
| 22:04 | Edited CLAUDE.md | reduced (-10 lines) | ~94 |
| 22:04 | Session end: 20 writes across 3 files (WorkflowExecutor.lua, CLAUDE.md, AutoDriveIntegration.lua) | 3 reads | ~26212 tok |
| 22:08 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~96 |
| 22:08 | Edited src/WorkflowExecutor.lua | expanded (+7 lines) | ~125 |
| 22:08 | Edited src/WorkflowExecutor.lua | expanded (+6 lines) | ~150 |
| 22:09 | Edited src/WorkflowExecutor.lua | 8â†’8 lines | ~173 |
| 22:11 | Session end: 24 writes across 3 files (WorkflowExecutor.lua, CLAUDE.md, AutoDriveIntegration.lua) | 3 reads | ~26947 tok |
| 22:24 | Session end: 24 writes across 3 files (WorkflowExecutor.lua, CLAUDE.md, AutoDriveIntegration.lua) | 3 reads | ~26947 tok |
| 22:29 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~353 |
| 22:30 | Edited src/WorkflowExecutor.lua | expanded (+14 lines) | ~250 |
| 22:30 | Edited src/WorkflowExecutor.lua | 6â†’8 lines | ~101 |
| 22:30 | Edited src/WorkflowExecutor.lua | 14â†’11 lines | ~104 |
| 22:30 | Edited src/WorkflowExecutor.lua | removed 8 lines | ~7 |
| 22:31 | Edited CLAUDE.md | inline fix | ~108 |
| 22:31 | Session end: 30 writes across 3 files (WorkflowExecutor.lua, CLAUDE.md, AutoDriveIntegration.lua) | 3 reads | ~28021 tok |
| 22:51 | Session end: 30 writes across 3 files (WorkflowExecutor.lua, CLAUDE.md, AutoDriveIntegration.lua) | 3 reads | ~28021 tok |

## Session: 2026-04-11 22:57

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 22:57 | Edited src/WorkflowExecutor.lua | 11â†’12 lines | ~138 |
| 22:58 | Edited src/WorkflowExecutor.lua | 12â†’16 lines | ~192 |

| 00:00 | Fixed: can't control vehicle after pausing with dummy helper active â€” moved setActive(false) before pauseCurrentStep, skip pauseCurrentStep when wasDummy=true | WorkflowExecutor.lua | bug-059 | ~120 |
| 22:58 | Session end: 2 writes across 1 files (WorkflowExecutor.lua) | 1 reads | ~18017 tok |
| 23:45 | Session end: 2 writes across 1 files (WorkflowExecutor.lua) | 1 reads | ~18017 tok |

## Session: 2026-04-12 21:41

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 21:48 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~245 |
| 21:48 | Edited src/WorkflowExecutor.lua | expanded (+7 lines) | ~156 |
| 21:49 | Fixed: paused support vehicle starts anyway when main advances step | WorkflowExecutor.lua | onMainStepChanged now checks pause state; pendingExecuteOnResume flag defers executeCurrentStep to resume | ~200 tok |
| 21:50 | Session end: 2 writes across 1 files (WorkflowExecutor.lua) | 1 reads | ~18388 tok |
| 21:55 | Session end: 2 writes across 1 files (WorkflowExecutor.lua) | 1 reads | ~18388 tok |
| 21:57 | Edited src/WorkflowExecutor.lua | 4â†’5 lines | ~52 |
| 21:57 | Edited src/WorkflowManager.lua | removed 9 lines | ~17 |
| 21:58 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+52 lines) | ~834 |
| 22:05 | Fix 1: pendingExecuteOnResume added to resetStepTrackingState | WorkflowExecutor.lua | prevents stale flag surviving prev/next while paused | ~50 tok |
| 22:05 | Fix 3: removed dead startWorkflowWithRole | WorkflowManager.lua | method was never called | ~20 tok |
| 22:05 | Fix 4: added 3 tests for paused support + step change | WorkflowExecutor_spec.lua | 109 passing | ~100 tok |
| 21:58 | Session end: 5 writes across 3 files (WorkflowExecutor.lua, WorkflowManager.lua, WorkflowExecutor_spec.lua) | 3 reads | ~32104 tok |
| 22:12 | Edited src/WorkflowExecutor.lua | 19â†’22 lines | ~194 |
| 22:12 | Edited src/WorkflowExecutor.lua | 17â†’20 lines | ~182 |
| 22:13 | Edited src/network/WMNetworkEvents.lua | 15â†’17 lines | ~205 |
| 22:13 | Edited src/network/WMNetworkEvents.lua | modified WMStateSyncEvent() | ~248 |
| 22:13 | Edited src/network/WMNetworkEvents.lua | 6â†’7 lines | ~114 |
| 22:13 | Edited src/WorkflowManagerSpec.lua | 3â†’4 lines | ~82 |
| 22:13 | Edited src/WorkflowManagerSpec.lua | 3â†’4 lines | ~64 |
| 22:13 | Edited src/WorkflowManagerSpec.lua | 7â†’8 lines | ~82 |
| 22:13 | Session end: 13 writes across 5 files (WorkflowExecutor.lua, WorkflowManager.lua, WorkflowExecutor_spec.lua, WMNetworkEvents.lua, WorkflowManagerSpec.lua) | 5 reads | ~37750 tok |
| 22:55 | Created modDesc.xml | â€” | ~1644 |
| 22:18 | Updated modDesc.xml: descriptions, changelog v1.0/v1.1, removed dead actions | modDesc.xml | ~100 tok |
| 22:55 | Session end: 14 writes across 6 files (WorkflowExecutor.lua, WorkflowManager.lua, WorkflowExecutor_spec.lua, WMNetworkEvents.lua, WorkflowManagerSpec.lua) | 7 reads | ~42100 tok |
| 22:59 | Edited modDesc.xml | reduced (-13 lines) | ~379 |
| 22:59 | Edited modDesc.xml | reduced (-13 lines) | ~411 |
| 22:59 | Session end: 16 writes across 6 files (WorkflowExecutor.lua, WorkflowManager.lua, WorkflowExecutor_spec.lua, WMNetworkEvents.lua, WorkflowManagerSpec.lua) | 7 reads | ~42946 tok |
| 23:01 | Edited modDesc.xml | expanded (+21 lines) | ~714 |
| 23:02 | Edited modDesc.xml | Aufgaben() â†’ Schritt() | ~760 |
| 23:02 | Session end: 18 writes across 6 files (WorkflowExecutor.lua, WorkflowManager.lua, WorkflowExecutor_spec.lua, WMNetworkEvents.lua, WorkflowManagerSpec.lua) | 7 reads | ~45852 tok |

## Session: 2026-04-29 22:20

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-04-29 22:21

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 22:26 | Edited src/WorkflowExecutor.lua | removed 14 lines | ~6 |
| 22:26 | Edited src/WorkflowExecutor.lua | removed 15 lines | ~6 |
| 22:27 | Edited tests/specs/WorkflowExecutor_spec.lua | 29â†’29 lines | ~354 |
| 22:27 | Session end: 3 writes across 2 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua) | 2 reads | ~31627 tok |

## Session: 2026-04-30 08:45

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-04-30 23:24

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 23:51 | Created ../../../../../.claude/plans/id-like-to-set-refactored-plum.md | â€” | ~1783 |
| 23:59 | Created ../../../../../.claude/plans/id-like-to-set-refactored-plum.md | â€” | ~1900 |
| 07:04 | Created src/gui/WMADSettingsDialog.lua | â€” | ~616 |
| 07:04 | Created xml/gui/WMADSettingsDialog.xml | â€” | ~854 |
| 07:05 | Edited src/WorkflowStorage.lua | expanded (+9 lines) | ~211 |
| 07:05 | Edited src/WorkflowStorage.lua | 8â†’8 lines | ~162 |
| 07:05 | Edited src/WorkflowStorage.lua | expanded (+7 lines) | ~242 |
| 07:06 | Edited src/integration/AutoDriveIntegration.lua | modified ADIntegration() | ~505 |
| 07:06 | Edited src/WorkflowExecutor.lua | 10â†’13 lines | ~119 |
| 07:06 | Edited src/WorkflowExecutor.lua | 4â†’7 lines | ~110 |
| 07:06 | Edited src/WorkflowManager.lua | 5â†’6 lines | ~120 |
| 07:06 | Edited src/WorkflowManager.lua | expanded (+13 lines) | ~276 |
| 07:06 | Edited src/WorkflowManager.lua | modified Called() | ~135 |
| 07:07 | Edited src/WorkflowManager.lua | 3â†’6 lines | ~52 |
| 07:07 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~125 |
| 07:07 | Edited xml/gui/WMEditorDialog.xml | 10â†’11 lines | ~370 |
| 07:07 | Edited translations/translation_en.xml | expanded (+10 lines) | ~211 |
| 07:07 | Edited translations/translation_de.xml | expanded (+10 lines) | ~222 |
| 23:16 | Edited tests/mocks/game_globals.lua | 2â†’3 lines | ~31 |
| 23:17 | Added per-workflow AD/CP settings feature | WMADSettingsDialog.lua, WMADSettingsDialog.xml, WorkflowStorage.lua, AutoDriveIntegration.lua, WorkflowExecutor.lua, WorkflowManager.lua, WMEditorDialog.lua, WMEditorDialog.xml, translations | 192/192 tests pass | ~3500 |
| 23:18 | Session end: 19 writes across 12 files (id-like-to-set-refactored-plum.md, WMADSettingsDialog.lua, WMADSettingsDialog.xml, WorkflowStorage.lua, AutoDriveIntegration.lua) | 20 reads | ~8620 tok |
| 23:19 | Session end: 19 writes across 12 files (id-like-to-set-refactored-plum.md, WMADSettingsDialog.lua, WMADSettingsDialog.xml, WorkflowStorage.lua, AutoDriveIntegration.lua) | 20 reads | ~8620 tok |
| 23:21 | Session end: 19 writes across 12 files (id-like-to-set-refactored-plum.md, WMADSettingsDialog.lua, WMADSettingsDialog.xml, WorkflowStorage.lua, AutoDriveIntegration.lua) | 20 reads | ~8620 tok |
| 23:23 | Edited CLAUDE.md | 5â†’7 lines | ~95 |
| 23:23 | Edited CLAUDE.md | 4â†’5 lines | ~129 |
| 23:24 | Edited CLAUDE.md | 17â†’20 lines | ~285 |
| 23:24 | Edited CLAUDE.md | 2â†’3 lines | ~88 |
| 23:24 | Edited CLAUDE.md | 2â†’3 lines | ~62 |
| 23:24 | Edited CLAUDE.md | expanded (+6 lines) | ~123 |
| 23:24 | Edited CLAUDE.md | inline fix | ~32 |
| 23:24 | Edited CLAUDE.md | 2â†’2 lines | ~78 |
| 23:24 | Session end: 27 writes across 13 files (id-like-to-set-refactored-plum.md, WMADSettingsDialog.lua, WMADSettingsDialog.xml, WorkflowStorage.lua, AutoDriveIntegration.lua) | 21 reads | ~14742 tok |

## Session: 2026-05-02 23:25

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-04 21:24

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 21:33 | Edited src/gui/WMADSettingsDialog.lua | 11â†’13 lines | ~146 |
| 21:33 | Edited src/gui/WMADSettingsDialog.lua | 5â†’7 lines | ~87 |
| 21:34 | Created xml/gui/WMADSettingsDialog.xml | â€” | ~913 |
| 21:34 | Edited translations/translation_en.xml | 3â†’3 lines | ~61 |
| 21:34 | Edited translations/translation_de.xml | 3â†’3 lines | ~61 |
| 21:40 | Session end: 5 writes across 4 files (WMADSettingsDialog.lua, WMADSettingsDialog.xml, translation_en.xml, translation_de.xml) | 2 reads | ~2828 tok |

## Session: 2026-05-04 21:47

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-05

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| session | Moved AD/CP Settings button to WMMainDialog; added onClickADSettings handler with save; disabled when no selection | WMMainDialog.xml, WMMainDialog.lua | 192/192 tests pass | ~2000 |
| session | Fixed AD settings not applied on workflow start: apply after StartDriving in startAutoDriveStep | WorkflowExecutor.lua | bug fix | ~500 |
| 21:50 | Edited xml/gui/WMEditorDialog.xml | 22â†’22 lines | ~544 |
| 21:50 | Session end: 1 writes across 1 files (WMEditorDialog.xml) | 1 reads | ~2025 tok |

## Session: 2026-05-05 10:22

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-05 10:22

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 10:27 | Edited xml/gui/WMEditorDialog.xml | inline fix | ~16 |
| 10:27 | Edited xml/gui/WMEditorDialog.xml | expanded (+19 lines) | ~540 |
| 10:27 | Edited xml/gui/WMEditorDialog.xml | 6â†’6 lines | ~99 |
| 10:27 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~180 |
| 10:27 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~281 |
| 10:28 | Edited src/gui/WMEditorDialog.lua | removed 11 lines | ~7 |
| 10:28 | Edited src/WorkflowManager.lua | 2â†’1 lines | ~22 |
| 10:28 | Edited src/WorkflowManager.lua | removed 13 lines | ~1 |
| 10:28 | Edited src/WorkflowManager.lua | removed 13 lines | ~9 |
| 10:28 | Edited src/WorkflowManager.lua | 7â†’4 lines | ~28 |
| 10:28 | Edited src/WorkflowExecutor.lua | 10â†’12 lines | ~208 |
| 10:37 | Edited xml/gui/WMEditorDialog.xml | reduced (-20 lines) | ~175 |
| 10:37 | Edited xml/gui/WMEditorDialog.xml | inline fix | ~16 |
| 10:37 | Edited xml/gui/WMEditorDialog.xml | 6â†’6 lines | ~99 |
| 10:37 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~52 |
| 10:37 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~61 |
| 10:37 | Edited src/gui/WMEditorDialog.lua | modified WMEditorDialog() | ~112 |
| 10:37 | Edited src/WorkflowManager.lua | 1â†’2 lines | ~44 |
| 10:38 | Edited src/WorkflowManager.lua | expanded (+12 lines) | ~174 |
| 10:38 | Edited src/WorkflowManager.lua | modified Called() | ~135 |
| 10:38 | Edited src/WorkflowManager.lua | 4â†’7 lines | ~54 |
| 10:38 | Edited xml/gui/WMMainDialog.xml | 8â†’9 lines | ~286 |
| 10:39 | Edited src/gui/WMMainDialog.lua | modified WMMainDialog() | ~163 |
| 10:39 | Edited src/gui/WMMainDialog.lua | 6â†’8 lines | ~82 |
| 11:05 | Session end: 24 writes across 6 files (WMEditorDialog.xml, WMEditorDialog.lua, WorkflowManager.lua, WorkflowExecutor.lua, WMMainDialog.xml) | 13 reads | ~51335 tok |
| 11:41 | Edited src/integration/AutoDriveIntegration.lua | inline fix | ~22 |
| 11:41 | Edited src/gui/WMADSettingsDialog.lua | 3â†’4 lines | ~43 |
| 11:41 | Edited src/gui/WMADSettingsDialog.lua | 7â†’8 lines | ~112 |
| 11:52 | Edited CLAUDE.md | inline fix | ~35 |
| 11:52 | Session end: 28 writes across 9 files (WMEditorDialog.xml, WMEditorDialog.lua, WorkflowManager.lua, WorkflowExecutor.lua, WMMainDialog.xml) | 16 reads | ~56928 tok |

## Session: 2026-05-05 12:00

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 12:04 | Edited translations/translation_de.xml | inline fix | ~21 |
| 12:04 | Edited xml/gui/WMMainDialog.xml | inline fix | ~48 |
| 12:04 | Session end: 2 writes across 2 files (translation_de.xml, WMMainDialog.xml) | 3 reads | ~3854 tok |
| 12:36 | Edited translations/translation_de.xml | inline fix | ~22 |
| 12:36 | Edited xml/gui/WMMainDialog.xml | inline fix | ~16 |
| 12:36 | Edited xml/gui/WMMainDialog.xml | 32â†’32 lines | ~653 |
| 12:36 | Session end: 5 writes across 2 files (translation_de.xml, WMMainDialog.xml) | 3 reads | ~4595 tok |
| 13:31 | Created xml/gui/WMMainDialog.xml | â€” | ~987 |
| 13:31 | Session end: 6 writes across 2 files (translation_de.xml, WMMainDialog.xml) | 3 reads | ~5652 tok |

## Session: 2026-05-05 14:11

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 14:12 | Edited CLAUDE.md | inline fix | ~23 |
| 14:13 | Edited CLAUDE.md | 5â†’7 lines | ~243 |
| 14:13 | Edited CLAUDE.md | inline fix | ~170 |
| 14:13 | Edited CLAUDE.md | inline fix | ~32 |
| 14:13 | Edited CLAUDE.md | settings() â†’ applying() | ~89 |
| 14:13 | Session end: 5 writes across 1 files (CLAUDE.md) | 1 reads | ~5972 tok |

## Session: 2026-05-05 14:16

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 14:17 | Edited website/docs/ui/main-dialog.md | expanded (+9 lines) | ~134 |
| 14:17 | Edited website/docs/ui/main-dialog.md | expanded (+18 lines) | ~318 |
| 14:18 | Edited website/docs/workflows/creating-workflows.md | expanded (+17 lines) | ~231 |
| 14:18 | Edited website/docs/api/xml-format.md | expanded (+25 lines) | ~275 |
| 14:18 | Edited website/docs/api/xml-format.md | 12â†’13 lines | ~226 |
| 14:18 | Session end: 5 writes across 3 files (main-dialog.md, creating-workflows.md, xml-format.md) | 5 reads | ~1269 tok |
| 14:19 | Edited website/docs/ui/main-dialog.md | 5â†’7 lines | ~97 |
| 14:20 | Edited CLAUDE.md | 7â†’8 lines | ~593 |
| 14:20 | Session end: 7 writes across 4 files (main-dialog.md, creating-workflows.md, xml-format.md, CLAUDE.md) | 6 reads | ~7585 tok |

## Session: 2026-05-13 23:29

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-13 23:29

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 23:30 | Edited create_release.ps1 | inline fix | ~19 |
| 23:30 | Session end: 1 writes across 1 files (create_release.ps1) | 0 reads | ~20 tok |
| 23:51 | Edited modDesc.xml | 4â†’3 lines | ~16 |
| 23:51 | Session end: 2 writes across 2 files (create_release.ps1, modDesc.xml) | 1 reads | ~37 tok |
| 23:53 | Edited create_release.ps1 | inline fix | ~12 |
| 23:54 | Session end: 3 writes across 2 files (create_release.ps1, modDesc.xml) | 2 reads | ~310 tok |

## Session: 2026-05-13 00:24

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-13 00:24

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 00:27 | Edited tools/png_to_dds.py | 2â†’1 lines | ~23 |
| 00:27 | Edited tools/png_to_dds.py | 2â†’2 lines | ~44 |
| 00:27 | Edited tools/png_to_dds.py | "texconv (DXT5/DXT1 + mipm" â†’ "texconv (BC3/DXT5 + mipma" | ~27 |
| 00:27 | Edited tools/png_to_dds.py | removed 7 lines | ~7 |
| 00:28 | Edited CLAUDE.md | icons() â†’ DXT5() | ~65 |
| 00:28 | Session end: 5 writes across 2 files (png_to_dds.py, CLAUDE.md) | 4 reads | ~5883 tok |
| 00:31 | Created tools/png_to_dds.py | â€” | ~1084 |
| 00:31 | Edited tools/png_to_dds.py | removed 7 lines | ~1 |
| 00:31 | Session end: 7 writes across 2 files (png_to_dds.py, CLAUDE.md) | 4 reads | ~6968 tok |
| 00:36 | Created tools/png_to_dds.py | â€” | ~1038 |
| 00:36 | Edited CLAUDE.md | inline fix | ~27 |
| 00:36 | Session end: 9 writes across 2 files (png_to_dds.py, CLAUDE.md) | 4 reads | ~9081 tok |
| 00:40 | Created tools/png_to_dds.py | â€” | ~1435 |
| 00:41 | Session end: 10 writes across 2 files (png_to_dds.py, CLAUDE.md) | 4 reads | ~10516 tok |
| 00:47 | Edited src/gui/WMHud.lua | 6â†’6 lines | ~119 |
| 00:47 | Edited CLAUDE.md | 1â†’2 lines | ~46 |
| 00:47 | Session end: 12 writes across 3 files (png_to_dds.py, CLAUDE.md, WMHud.lua) | 6 reads | ~10692 tok |
| 00:49 | Session end: 12 writes across 3 files (png_to_dds.py, CLAUDE.md, WMHud.lua) | 6 reads | ~10692 tok |
| 00:51 | Session end: 12 writes across 3 files (png_to_dds.py, CLAUDE.md, WMHud.lua) | 6 reads | ~10692 tok |
| 00:53 | Edited create_release.ps1 | inline fix | ~9 |
| 00:53 | Edited tools/png_to_dds.py | inline fix | ~28 |
| 00:53 | Session end: 14 writes across 4 files (png_to_dds.py, CLAUDE.md, WMHud.lua, create_release.ps1) | 6 reads | ~10730 tok |
| 00:58 | Edited create_release.ps1 | added 2 condition(s) | ~156 |
| 00:59 | Session end: 15 writes across 4 files (png_to_dds.py, CLAUDE.md, WMHud.lua, create_release.ps1) | 8 reads | ~11159 tok |
| 01:03 | Edited tools/png_to_dds.py | modified convert_texconv() | ~133 |
| 01:03 | Edited tools/png_to_dds.py | 2â†’5 lines | ~83 |
| 01:03 | Edited tools/png_to_dds.py | 20â†’22 lines | ~197 |
| 01:03 | Session end: 18 writes across 4 files (png_to_dds.py, CLAUDE.md, WMHud.lua, create_release.ps1) | 8 reads | ~12073 tok |
| 01:07 | Edited tools/png_to_dds.py | 3â†’4 lines | ~93 |
| 01:07 | Session end: 19 writes across 4 files (png_to_dds.py, CLAUDE.md, WMHud.lua, create_release.ps1) | 8 reads | ~12166 tok |
| 01:15 | Session end: 19 writes across 4 files (png_to_dds.py, CLAUDE.md, WMHud.lua, create_release.ps1) | 8 reads | ~12166 tok |
| 01:20 | Created tools/png_to_dds.py | â€” | ~1108 |
| 01:21 | Session end: 20 writes across 4 files (png_to_dds.py, CLAUDE.md, WMHud.lua, create_release.ps1) | 8 reads | ~13274 tok |

## Session: 2026-05-13 01:23

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 01:34 | Edited src/WorkflowManager.lua | "textures/white.dds" â†’ "textures/white.png" | ~23 |
| 01:34 | Edited src/gui/WorkflowEditorGUI.lua | inline fix | ~5 |
| 01:34 | Edited src/gui/WorkflowManagerGUI.lua | "textures/white.dds" â†’ "textures/white.png" | ~20 |
| 01:36 | Edited create_release.ps1 | modified if() | ~48 |
| 01:37 | Edited CLAUDE.md | 7â†’8 lines | ~143 |
| 01:37 | Session end: 5 writes across 5 files (WorkflowManager.lua, WorkflowEditorGUI.lua, WorkflowManagerGUI.lua, create_release.ps1, CLAUDE.md) | 9 reads | ~19315 tok |

## Session: 2026-05-13 01:38

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 01:46 | Edited src/gui/WorkflowEditorGUI.lua | 6â†’6 lines | ~114 |
| 01:46 | Edited src/gui/WorkflowEditorGUI.lua | 3â†’3 lines | ~68 |
| 01:46 | Edited src/gui/WorkflowManagerGUI.lua | inline fix | ~27 |
| 01:46 | Session end: 3 writes across 2 files (WorkflowEditorGUI.lua, WorkflowManagerGUI.lua) | 2 reads | ~24678 tok |
| 01:58 | Edited src/gui/WMHud.lua | 6â†’5 lines | ~98 |
| 01:58 | Edited CLAUDE.md | 5â†’8 lines | ~174 |
| 01:58 | Edited CLAUDE.md | 2â†’4 lines | ~69 |
| 01:59 | Edited CLAUDE.md | 4â†’5 lines | ~124 |
| 01:59 | Session end: 7 writes across 4 files (WorkflowEditorGUI.lua, WorkflowManagerGUI.lua, WMHud.lua, CLAUDE.md) | 5 reads | ~39569 tok |
| 02:06 | Session end: 7 writes across 4 files (WorkflowEditorGUI.lua, WorkflowManagerGUI.lua, WMHud.lua, CLAUDE.md) | 6 reads | ~39569 tok |
| 02:09 | Edited CLAUDE.md | source() â†’ DDS() | ~56 |
| 02:09 | Session end: 8 writes across 4 files (WorkflowEditorGUI.lua, WorkflowManagerGUI.lua, WMHud.lua, CLAUDE.md) | 6 reads | ~39629 tok |
| 02:12 | Session end: 8 writes across 4 files (WorkflowEditorGUI.lua, WorkflowManagerGUI.lua, WMHud.lua, CLAUDE.md) | 6 reads | ~39629 tok |

## Session: 2026-05-14 02:18

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 02:20 | Edited CLAUDE.md | expanded (+10 lines) | ~149 |
| 02:20 | Edited CLAUDE.md | reduced (-6 lines) | ~124 |
| 02:20 | Edited CLAUDE.md | inline fix | ~24 |
| 02:20 | Edited CLAUDE.md | 2â†’1 lines | ~17 |
| 02:20 | Updated CLAUDE.md + anatomy.md file paths after last commit: modIcon.ddsâ†’icon_WorkflowManager.dds, textures PNGsâ†’_art/textures/, removed WorkflowEditorGUI.xml | CLAUDE.md, .wolf/anatomy.md | done | ~200 |
| 02:21 | Session end: 4 writes across 1 files (CLAUDE.md) | 2 reads | ~6251 tok |
| 02:21 | Session end: 4 writes across 1 files (CLAUDE.md) | 2 reads | ~6251 tok |

## Session: 2026-05-14 02:38

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-14 02:42

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 02:47 | Edited website/docs/ui/main-dialog.md | 8â†’13 lines | ~104 |
| 02:47 | Edited website/docs/ui/editor-dialog.md | 7â†’7 lines | ~38 |
| 02:47 | Edited website/docs/workflows/creating-workflows.md | inline fix | ~18 |
| 02:47 | Edited website/docs/workflows/creating-workflows.md | inline fix | ~10 |

|  | Fixed outdated keyboard shortcuts in Docusaurus UI docs | website/docs/ui/main-dialog.md, editor-dialog.md, workflows/creating-workflows.md | Corrected: Delete key was 'D'â†’Delete/R, editor shortcuts Backspace/+/- â†’ R/U/D per modDesc.xml bindings | ~200 tok |

| 14:30 | Fixed outdated keyboard shortcuts in Docusaurus UI docs | website/docs/ui/main-dialog.md, editor-dialog.md, workflows/creating-workflows.md | Corrected: delete key was Dâ†’Delete, editor shortcuts Backspace/+/- â†’ R/U/D per modDesc.xml bindings | ~200 tok |
| 02:48 | Session end: 4 writes across 3 files (main-dialog.md, editor-dialog.md, creating-workflows.md) | 14 reads | ~15548 tok |

## Session: 2026-05-14 02:49

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 02:51 | Edited CLAUDE.md | 3â†’3 lines | ~324 |
| 02:51 | Edited CLAUDE.md | 5â†’7 lines | ~116 |
| 02:51 | Edited CLAUDE.md | inline fix | ~51 |
| 02:51 | Edited CLAUDE.md | 10â†’5 lines | ~50 |
| 02:51 | Edited CLAUDE.md | applying() â†’ multiplayer() | ~88 |
| 02:51 | Edited CLAUDE.md | modified Host() | ~234 |
| 02:53 | Cleaned up CLAUDE.md: added network file, fixed support-pause note, removed completed todos, added multiplayer section, updated status/date | CLAUDE.md | done | ~800 |
| 02:53 | Session end: 6 writes across 1 files (CLAUDE.md) | 4 reads | ~24655 tok |

## Session: 2026-05-14 02:54

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 02:56 | Edited src/WorkflowExecutor.lua | reduced (-10 lines) | ~98 |
| 02:56 | Edited src/WorkflowExecutor.lua | reduced (-9 lines) | ~78 |
| 02:56 | Edited src/WorkflowExecutor.lua | inline fix | ~14 |
| 02:57 | Edited CLAUDE.md | inline fix | ~39 |
| 02:57 | Edited CLAUDE.md | inline fix | ~43 |
| 02:59 | Edited tests/specs/WorkflowExecutor_spec.lua | 17â†’17 lines | ~250 |
| 02:59 | Removed stop propagation from mainâ†’support in stopWorkflow/onWorkflowCompleted; removed 'or true' dead code in startAutoDriveStep:608 | WorkflowExecutor.lua, tests/specs/WorkflowExecutor_spec.lua, CLAUDE.md | All 109 tests pass | ~350 |
| 02:59 | Session end: 6 writes across 3 files (WorkflowExecutor.lua, CLAUDE.md, WorkflowExecutor_spec.lua) | 6 reads | ~24551 tok |

## Session: 2026-05-14 03:00

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 03:09 | Edited tests/run_tests.lua | expanded (+12 lines) | ~338 |
| 03:10 | Edited tests/specs/WorkflowStorage_spec.lua | expanded (+64 lines) | ~935 |
| 03:10 | Edited tests/specs/WorkflowStorage_spec.lua | expanded (+27 lines) | ~415 |

| 01:10 | Fixed run_tests.lua global isolation bug (Logger_spec was overriding print+WMLogger); added WorkflowStorage_spec to full runner; added 5 adSettings tests; 266/266 pass | run_tests.lua, WorkflowStorage_spec.lua | all tests green |
| 03:11 | Session end: 3 writes across 2 files (run_tests.lua, WorkflowStorage_spec.lua) | 14 reads | ~35870 tok |
| 03:12 | Session end: 3 writes across 2 files (run_tests.lua, WorkflowStorage_spec.lua) | 14 reads | ~35870 tok |
| 03:13 | Session end: 3 writes across 2 files (run_tests.lua, WorkflowStorage_spec.lua) | 14 reads | ~35870 tok |
| 03:18 | Created tests/specs/WorkflowManagerSpec_spec.lua | â€” | ~6990 |
| 03:18 | Edited tests/run_tests.lua | 9â†’10 lines | ~88 |
| 03:18 | Session end: 5 writes across 3 files (run_tests.lua, WorkflowStorage_spec.lua, WorkflowManagerSpec_spec.lua) | 15 reads | ~43453 tok |
| 03:20 | Edited CLAUDE.md | modified once() | ~532 |
| 03:20 | Edited CLAUDE.md | 2â†’2 lines | ~118 |
| 03:20 | Session end: 7 writes across 4 files (run_tests.lua, WorkflowStorage_spec.lua, WorkflowManagerSpec_spec.lua, CLAUDE.md) | 16 reads | ~50309 tok |

## Session: 2026-05-14 03:20

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 22:15 | Edited modDesc.xml | 11â†’15 lines | ~203 |
| 22:15 | Edited modDesc.xml | 11â†’15 lines | ~226 |
| 22:15 | Edited modDesc.xml | 1.1 â†’ 1.2 | ~8 |
| 22:15 | Updated modDesc changelog to v1.2.0: support vehicles run independently when main pauses, per-workflow AD/CP settings | modDesc.xml | done | ~100 |
| 22:15 | Session end: 3 writes across 1 files (modDesc.xml) | 3 reads | ~2512 tok |

## Session: 2026-05-20 13:28

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-20 13:28

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-20 13:30

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 13:34 | Edited modDesc.xml | 2â†’3 lines | ~28 |
| 13:34 | Edited modDesc.xml | 4â†’7 lines | ~80 |
| 13:34 | Edited src/gui/WMMainDialog.lua | 3â†’4 lines | ~45 |
| 13:34 | Edited src/gui/WMMainDialog.lua | expanded (+8 lines) | ~210 |
| 13:34 | Edited src/gui/WMMainDialog.lua | modified WMMainDialog() | ~114 |
| 13:35 | Edited src/gui/WMMainDialog.lua | modified WMMainDialog() | ~62 |
| 13:35 | Session end: 6 writes across 2 files (modDesc.xml, WMMainDialog.lua) | 4 reads | ~6118 tok |

## Session: 2026-05-20 14:35

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-20 14:35

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 17:44 | Edited website/docs/workflows/linked-workflows.md | 9â†’11 lines | ~118 |
| 17:44 | Edited website/docs/ui/hud-controls.md | 5â†’5 lines | ~52 |
| 17:44 | Edited website/docs/ui/hud-controls.md | 5â†’5 lines | ~41 |
| 17:44 | Edited website/docs/faq.md | 3â†’3 lines | ~52 |

| 2026-05-20 | Fixed docs: pause/stop propagation documented as opposite of actual behavior â€” corrected in linked-workflows.md, hud-controls.md, faq.md | website/docs | 3 files updated |
| 17:44 | Session end: 4 writes across 3 files (linked-workflows.md, hud-controls.md, faq.md) | 16 reads | ~282 tok |

## Session: 2026-05-20 17:45

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 21:08 | Edited website/build.bat | 4â†’8 lines | ~49 |
| 21:08 | Edited website/start.bat | 4â†’8 lines | ~48 |
| 21:08 | Session end: 2 writes across 2 files (build.bat, start.bat) | 6 reads | ~103 tok |
| 21:20 | Session end: 2 writes across 2 files (build.bat, start.bat) | 6 reads | ~103 tok |
| 21:27 | Created ../FS25_WorkflowManager-docs/.github/workflows/deploy-docs.yml | â€” | ~484 |
| 21:27 | Created push-docs.bat | â€” | ~38 |
| 21:27 | Created pull-docs.bat | â€” | ~41 |
| 21:42 | Session end: 5 writes across 5 files (build.bat, start.bat, deploy-docs.yml, push-docs.bat, pull-docs.bat) | 7 reads | ~672 tok |

## Session: 2026-05-20 21:46

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-20 21:46

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-20 21:48

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 21:49 | Edited translations/translation_en.xml | 3â†’5 lines | ~92 |
| 21:49 | Edited translations/translation_de.xml | 3â†’5 lines | ~97 |
| 21:49 | Session end: 2 writes across 2 files (translation_en.xml, translation_de.xml) | 3 reads | ~203 tok |

## Session: 2026-05-20 22:29

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 22:29 | Edited website/build.bat | 4â†’5 lines | ~32 |
| 22:29 | Session end: 1 writes across 1 files (build.bat) | 2 reads | ~85 tok |
| 22:32 | Session end: 1 writes across 1 files (build.bat) | 2 reads | ~85 tok |
| 22:33 | Session end: 1 writes across 1 files (build.bat) | 3 reads | ~85 tok |
| 22:42 | Created CLAUDE.md | â€” | ~899 |
| 22:42 | Created Development.md | â€” | ~992 |
| 22:42 | Session end: 3 writes across 3 files (build.bat, CLAUDE.md, Development.md) | 5 reads | ~2111 tok |

## Session: 2026-05-20 22:51

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 22:52 | Edited modDesc.xml | 1â†’3 lines | ~28 |
| 22:52 | Edited modDesc.xml | 1â†’3 lines | ~29 |
| 22:53 | Session end: 2 writes across 1 files (modDesc.xml) | 2 reads | ~61 tok |

## Session: 2026-05-20 00:36

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 00:40 | Edited xml/gui/WMEditorDialog.xml | "DIALOG_WMEditorDialog" â†’ "MENU" | ~7 |
| 00:40 | Edited xml/gui/WMMainDialog.xml | "DIALOG_WMMainDialog" â†’ "MENU" | ~7 |
| 00:40 | Edited xml/gui/WMStepDialog.xml | "DIALOG_WMStepDialog" â†’ "MENU" | ~7 |
| 00:40 | Edited xml/gui/WMADSettingsDialog.xml | "DIALOG_WMADSettingsDialog" â†’ "MENU" | ~7 |
| 00:40 | Edited xml/gui/TextInputDialog.xml | "DIALOG_WMTextInputDialog" â†’ "MENU" | ~7 |
| 00:40 | Edited xml/gui/WMModeSelectDialog.xml | "DIALOG_WMModeSelectDialog" â†’ "MENU" | ~7 |
| 00:41 | Session end: 6 writes across 6 files (WMEditorDialog.xml, WMMainDialog.xml, WMStepDialog.xml, WMADSettingsDialog.xml, TextInputDialog.xml) | 13 reads | ~42 tok |
| 01:14 | Created ../../../../../.claude/plans/implement-milestone-11-tender-blum.md | â€” | ~2710 |
| 01:17 | Edited ../../../../../.claude/plans/implement-milestone-11-tender-blum.md | modified tests() | ~590 |
| 01:18 | Edited tests/fixtures/workflows.lua | 4â†’4 lines | ~116 |
| 01:18 | Edited tests/fixtures/workflows.lua | modified TestFixtures() | ~148 |
| 01:18 | Edited src/WorkflowStorage.lua | modified deepCopySupportStep() | ~184 |
| 01:19 | Edited src/WorkflowStorage.lua | inline fix | ~20 |
| 01:19 | Edited src/WorkflowStorage.lua | 23â†’23 lines | ~350 |
| 01:19 | Edited src/WorkflowStorage.lua | 10â†’11 lines | ~179 |
| 01:19 | Edited src/WorkflowStorage.lua | 7â†’8 lines | ~149 |
| 01:19 | Edited src/integration/AutoDriveIntegration.lua | modified ADIntegration() | ~234 |
| 01:20 | Edited src/integration/AutoDriveIntegration.lua | expanded (+7 lines) | ~275 |
| 01:20 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~85 |
| 01:20 | Edited src/WorkflowExecutor.lua | 7â†’8 lines | ~80 |
| 01:20 | Edited src/WorkflowExecutor.lua | 8â†’8 lines | ~147 |
| 01:20 | Edited src/WorkflowExecutor.lua | 7â†’7 lines | ~43 |
| 01:21 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~328 |
| 01:21 | Edited src/WorkflowManager.lua | 5â†’6 lines | ~73 |
| 01:21 | Edited src/WorkflowExecutor.lua | expanded (+19 lines) | ~380 |
| 01:22 | Edited src/WorkflowManager.lua | modified continueWithLeader() | ~420 |

## Session: 2026-05-20 01:24

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 01:25 | Edited src/WorkflowManager.lua | expanded (+13 lines) | ~289 |
| 01:25 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~244 |
| 01:25 | Edited src/WorkflowManager.lua | modified WorkflowManager() | ~600 |
| 01:25 | Session end: 3 writes across 1 files (WorkflowManager.lua) | 3 reads | ~14481 tok |

## Session: 2026-05-21 14:17

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 14:19 | Edited src/WorkflowManager.lua | 12â†’14 lines | ~184 |
| 14:22 | Created src/gui/WMLeaderVehicleSelectDialog.lua | â€” | ~1134 |
| 14:23 | Created xml/gui/WMLeaderVehicleSelectDialog.xml | â€” | ~779 |
| 14:23 | Edited translations/translation_en.xml | 2â†’7 lines | ~92 |
| 14:23 | Edited translations/translation_de.xml | 2â†’7 lines | ~93 |
| 14:23 | Edited src/WorkflowManager.lua | 2â†’3 lines | ~69 |
| 14:23 | Edited src/WorkflowManager.lua | 14â†’12 lines | ~150 |

| 14:25 | Implemented WMLeaderVehicleSelectDialog (Lua + XML) to fix loadSharedI3DFileFinished crash at WM.lua:256; class was referenced but missing | src/gui/WMLeaderVehicleSelectDialog.lua, xml/gui/WMLeaderVehicleSelectDialog.xml, WorkflowManager.lua | 294/296 tests pass | ~200 tok |
| 14:25 | Session end: 7 writes across 5 files (WorkflowManager.lua, WMLeaderVehicleSelectDialog.lua, WMLeaderVehicleSelectDialog.xml, translation_en.xml, translation_de.xml) | 13 reads | ~25146 tok |
| 15:20 | Created tests/specs/WMLeaderVehicleSelectDialog_spec.lua | â€” | ~2797 |
| 15:20 | Edited tests/run_tests.lua | 2â†’3 lines | ~24 |
| 15:34 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | 18â†’22 lines | ~195 |
| 15:42 | Session end: 10 writes across 7 files (WorkflowManager.lua, WMLeaderVehicleSelectDialog.lua, WMLeaderVehicleSelectDialog.xml, translation_en.xml, translation_de.xml) | 17 reads | ~28376 tok |

## Session: 2026-05-21 21:26

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 21:36 | Edited tests/specs/WorkflowStorage_spec.lua | 20â†’22 lines | ~254 |
| 21:36 | Edited tests/specs/WorkflowStorage_spec.lua | 2â†’2 lines | ~51 |
| 21:36 | Edited tests/specs/WorkflowStorage_spec.lua | 2â†’4 lines | ~63 |
| 21:36 | Edited tests/specs/WorkflowStorage_spec.lua | expanded (+60 lines) | ~851 |
| 21:37 | Edited tests/specs/WorkflowStorage_spec.lua | expanded (+21 lines) | ~442 |
| 21:37 | Edited tests/specs/WorkflowExecutor_spec.lua | 10â†’11 lines | ~138 |
| 21:38 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+67 lines) | ~987 |
| 21:39 | Session end: 7 writes across 2 files (WorkflowStorage_spec.lua, WorkflowExecutor_spec.lua) | 13 reads | ~31307 tok |

## Session: 2026-05-21 21:40

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 21:43 | Edited src/gui/WMStepDialog.lua | 19â†’18 lines | ~134 |
| 21:43 | Edited src/gui/WMStepDialog.lua | 15â†’15 lines | ~143 |
| 21:43 | Edited src/gui/WMStepDialog.lua | 4â†’3 lines | ~39 |
| 21:43 | Edited src/gui/WMStepDialog.lua | reduced (-13 lines) | ~54 |
| 21:44 | Edited src/gui/WMStepDialog.lua | 9â†’13 lines | ~147 |
| 21:44 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~270 |
| 21:44 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~35 |
| 21:44 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~199 |
| 21:44 | Edited src/gui/WMStepDialog.lua | reduced (-9 lines) | ~37 |
| 21:45 | Edited src/gui/WMStepDialog.lua | 7â†’7 lines | ~68 |
| 21:45 | Edited src/gui/WMStepDialog.lua | 7â†’7 lines | ~72 |
| 21:45 | Edited src/gui/WMStepDialog.lua | 3â†’3 lines | ~40 |
| 21:47 | Session end: 12 writes across 1 files (WMStepDialog.lua) | 7 reads | ~3781 tok |
| 22:26 | Edited src/gui/WMStepDialog.lua | 4â†’6 lines | ~40 |
| 22:34 | Session end: 13 writes across 1 files (WMStepDialog.lua) | 7 reads | ~3824 tok |
| 22:37 | Session end: 13 writes across 1 files (WMStepDialog.lua) | 7 reads | ~3824 tok |
| 22:46 | Edited src/gui/WMStepDialog.lua | 1â†’2 lines | ~28 |
| 22:47 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~112 |
| 22:47 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~268 |
| 22:47 | Edited src/gui/WMStepDialog.lua | 13â†’18 lines | ~199 |
| 22:54 | Session end: 17 writes across 1 files (WMStepDialog.lua) | 7 reads | ~4475 tok |
| 23:13 | Session end: 17 writes across 1 files (WMStepDialog.lua) | 7 reads | ~4475 tok |

## Session: 2026-05-21 23:13

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 23:16 | Created website/docs/workflows/queue-system.md | â€” | ~837 |
| 23:16 | Edited website/docs/workflows/step-types.md | 5â†’9 lines | ~165 |
| 23:16 | Edited website/docs/workflows/step-types.md | 8â†’8 lines | ~53 |
| 23:17 | Edited website/docs/faq.md | expanded (+9 lines) | ~253 |
| 23:17 | Edited website/sidebars.ts | 4â†’5 lines | ~53 |
| 23:17 | Docusaurus docs: added queue-system.md, updated step-types.md (multi-fill), faq.md, sidebars.ts | website/docs/workflows/, website/sidebars.ts | done | ~3k |
| 23:18 | Session end: 5 writes across 4 files (queue-system.md, step-types.md, faq.md, sidebars.ts) | 11 reads | ~14992 tok |
| 23:20 | Edited website/docs/workflows/queue-system.md | modified cycle() | ~334 |
| 23:20 | Session end: 6 writes across 4 files (queue-system.md, step-types.md, faq.md, sidebars.ts) | 11 reads | ~15350 tok |
| 23:21 | Edited website/docs/workflows/queue-system.md | 15â†’17 lines | ~253 |
| 23:21 | Session end: 7 writes across 4 files (queue-system.md, step-types.md, faq.md, sidebars.ts) | 11 reads | ~15621 tok |
| 23:23 | Edited Development.md | 3â†’4 lines | ~320 |
| 23:24 | Session end: 8 writes across 5 files (queue-system.md, step-types.md, faq.md, sidebars.ts, Development.md) | 11 reads | ~15963 tok |

## Session: 2026-05-21 23:24

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 23:38 | Edited src/gui/WMLeaderVehicleSelectDialog.lua | modified callback() | ~90 |
| 23:38 | Edited src/gui/WMLeaderVehicleSelectDialog.lua | modified WMLeaderVehicleSelectDialog() | ~34 |
| 23:38 | Edited src/WorkflowManager.lua | modified continueWithLeader() | ~80 |
| 23:39 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | 19â†’19 lines | ~157 |
| 23:39 | Edited src/WorkflowExecutor.lua | 7â†’8 lines | ~121 |
| 23:39 | Edited src/WorkflowExecutor.lua | 13â†’15 lines | ~266 |
| 23:39 | Edited src/integration/AutoDriveIntegration.lua | 7â†’11 lines | ~175 |
| 23:40 | Edited src/gui/WMHud.lua | 7â†’10 lines | ~153 |
| 23:40 | Edited translations/translation_en.xml | 2â†’3 lines | ~46 |
| 23:40 | Edited translations/translation_de.xml | 2â†’3 lines | ~48 |
| 07:54 | Fixed 4 review issues from QueueSystem branch: cancel-aborts-start, broadcastState on leader-wait enter/exit, toggleFillTypeSelection warning, HUD waiting_for_leader indicator | WMLeaderVehicleSelectDialog.lua, WorkflowManager.lua, WorkflowExecutor.lua, AutoDriveIntegration.lua, WMHud.lua, translations | 332/332 pass |
| 07:54 | Session end: 10 writes across 8 files (WMLeaderVehicleSelectDialog.lua, WorkflowManager.lua, WMLeaderVehicleSelectDialog_spec.lua, WorkflowExecutor.lua, AutoDriveIntegration.lua) | 11 reads | ~51689 tok |

## Session: 2026-05-26 14:07

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-26 14:26

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 21:34 | Edited src/gui/WMLeaderVehicleSelectDialog.lua | modified WMLeaderVehicleSelectDialog() | ~271 |
| 21:34 | Edited src/WorkflowManager.lua | expanded (+6 lines) | ~102 |
| 21:35 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | 54â†’59 lines | ~649 |
| 21:36 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | onOpen() â†’ buildVehicleList() | ~66 |
| 21:36 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | onOpen() â†’ buildVehicleList() | ~33 |
| 21:36 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | onOpen() â†’ buildVehicleList() | ~28 |
| 21:36 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | onOpen() â†’ buildVehicleList() | ~38 |
| 21:36 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | onOpen() â†’ buildVehicleList() | ~43 |
| 21:36 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | onOpen() â†’ buildVehicleList() | ~42 |
| 21:36 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | onOpen() â†’ buildVehicleList() | ~38 |
| 21:37 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | onOpen() â†’ buildVehicleList() | ~49 |
| 21:37 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | onOpen() â†’ buildVehicleList() | ~43 |
| 21:37 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | onOpen() â†’ buildVehicleList() | ~88 |
| 21:38 | fix: leader dialog opened+closed in onOpen broke inputs; pre-check via buildVehicleList before showDialog | WMLeaderVehicleSelectDialog.lua, WorkflowManager.lua, spec | 332 tests pass | ~6k |
| 21:38 | Session end: 13 writes across 3 files (WMLeaderVehicleSelectDialog.lua, WorkflowManager.lua, WMLeaderVehicleSelectDialog_spec.lua) | 6 reads | ~19294 tok |
| 22:42 | Edited tests/specs/WMLeaderVehicleSelectDialog_spec.lua | modified Regression() | ~191 |
| 22:42 | Edited tests/specs/WorkflowManager_spec.lua | expanded (+15 lines) | ~234 |
| 22:43 | Edited tests/specs/WorkflowManager_spec.lua | modified Regression() | ~606 |
| 22:43 | Edited tests/specs/WorkflowManager_spec.lua | inline fix | ~22 |
| 22:43 | test: regression tests for bug-038 (leader dialog open+close broke inputs) | WMLeaderVehicleSelectDialog_spec.lua, WorkflowManager_spec.lua | 336 tests pass | ~3k |
| 22:43 | Session end: 17 writes across 4 files (WMLeaderVehicleSelectDialog.lua, WorkflowManager.lua, WMLeaderVehicleSelectDialog_spec.lua, WorkflowManager_spec.lua) | 7 reads | ~20421 tok |

## Session: 2026-06-01 22:06

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 22:13 | Created ../../../../../.claude/plans/foamy-crafting-oasis.md | â€” | ~1172 |
| 22:24 | Edited src/WorkflowManagerSpec.lua | 3â†’5 lines | ~96 |
| 22:24 | Edited src/WorkflowManagerSpec.lua | expanded (+11 lines) | ~159 |
| 22:24 | Edited src/WorkflowManagerSpec.lua | expanded (+8 lines) | ~271 |
| 22:24 | Edited src/WorkflowManager.lua | modified startAsMain() | ~289 |
| 22:25 | Edited src/WorkflowManager.lua | modified Called() | ~153 |
| 22:25 | Save/restore leaderVehicle, fix dialog order (mode select first) | WorkflowManagerSpec.lua, WorkflowManager.lua | All 336 tests pass | ~3k |
| 22:25 | Session end: 6 writes across 3 files (foamy-crafting-oasis.md, WorkflowManagerSpec.lua, WorkflowManager.lua) | 6 reads | ~17101 tok |
| 22:28 | Edited tests/specs/WorkflowManagerSpec_spec.lua | expanded (+69 lines) | ~1119 |
| 22:29 | Session end: 7 writes across 4 files (foamy-crafting-oasis.md, WorkflowManagerSpec.lua, WorkflowManager.lua, WorkflowManagerSpec_spec.lua) | 7 reads | ~18299 tok |

## Session: 2026-06-02 14:28

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-06-02 14:31

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 14:34 | Edited src/WorkflowExecutor.lua | 5â†’5 lines | ~104 |
| 14:34 | Edited src/WorkflowExecutor.lua | 8â†’8 lines | ~176 |
| 14:35 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+20 lines) | ~453 |
| 14:36 | Session end: 3 writes across 2 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua) | 6 reads | ~46795 tok |
| 15:31 | Session end: 3 writes across 2 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua) | 6 reads | ~46795 tok |
| 15:35 | Edited src/WorkflowExecutor.lua | 5â†’5 lines | ~78 |
| 15:35 | Edited src/WorkflowExecutor.lua | 8â†’8 lines | ~147 |
| 15:35 | Edited tests/specs/WorkflowExecutor_spec.lua | removed 20 lines | ~3 |
| 15:36 | Session end: 6 writes across 2 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua) | 6 reads | ~47039 tok |
| 16:27 | Edited src/WorkflowExecutor.lua | 2â†’3 lines | ~51 |
| 16:28 | Edited src/WorkflowExecutor.lua | 17â†’22 lines | ~369 |
| 16:28 | Edited src/WorkflowExecutor.lua | 12â†’17 lines | ~366 |
| 16:28 | Edited src/WorkflowManagerSpec.lua | 12â†’16 lines | ~238 |
| 16:28 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+20 lines) | ~314 |
| 16:29 | Session end: 11 writes across 3 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua, WorkflowManagerSpec.lua) | 7 reads | ~53160 tok |
| 16:30 | Session end: 11 writes across 3 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua, WorkflowManagerSpec.lua) | 7 reads | ~53160 tok |

## Session: 2026-06-02 16:31

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 01:13 | Edited src/WorkflowExecutor.lua | 2â†’7 lines | ~110 |
| 01:14 | Edited src/WorkflowExecutor.lua | 17â†’21 lines | ~393 |
| 01:14 | Edited src/WorkflowExecutor.lua | expanded (+6 lines) | ~547 |
| 01:14 | Edited src/WorkflowManagerSpec.lua | expanded (+6 lines) | ~231 |
| 01:14 | Edited src/WorkflowManagerSpec.lua | expanded (+8 lines) | ~206 |
| 01:16 | Session end: 5 writes across 2 files (WorkflowExecutor.lua, WorkflowManagerSpec.lua) | 5 reads | ~24892 tok |
| 01:35 | Edited src/WorkflowManagerSpec.lua | 4â†’8 lines | ~157 |
| 01:38 | Session end: 6 writes across 2 files (WorkflowExecutor.lua, WorkflowManagerSpec.lua) | 5 reads | ~25596 tok |
| 01:50 | Edited src/WorkflowManagerSpec.lua | and() â†’ pairs() | ~575 |
| 01:50 | Edited src/WorkflowManagerSpec.lua | reduced (-6 lines) | ~217 |
| 01:50 | Edited src/WorkflowManagerSpec.lua | vehicles() â†’ vehicle() | ~36 |
| 01:51 | Edited src/WorkflowExecutor.lua | expanded (+16 lines) | ~297 |
| 01:51 | Edited src/WorkflowExecutor.lua | expanded (+17 lines) | ~334 |
| 01:51 | Edited src/WorkflowExecutor.lua | 16â†’16 lines | ~292 |
| 01:52 | Edited tests/specs/WorkflowManagerSpec_spec.lua | expanded (+10 lines) | ~930 |
| 01:53 | Session end: 13 writes across 3 files (WorkflowExecutor.lua, WorkflowManagerSpec.lua, WorkflowManagerSpec_spec.lua) | 8 reads | ~37664 tok |

## Session: 2026-06-06 07:34

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-06-06 07:35

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 07:51 | Created ../../../../../.claude/plans/what-was-te-idea-hidden-karp.md | â€” | ~1074 |
| 08:25 | Created ../../../../../.claude/plans/what-was-te-idea-hidden-karp.md | â€” | ~2029 |
| 08:28 | Created ../../../../../.claude/plans/what-was-te-idea-hidden-karp.md | â€” | ~2024 |
| 08:29 | Edited ../../../../../.claude/plans/what-was-te-idea-hidden-karp.md | modified Default() | ~493 |
| 08:38 | Edited src/WorkflowStorage.lua | expanded (+8 lines) | ~196 |
| 08:38 | Edited src/WorkflowStorage.lua | 11â†’14 lines | ~244 |
| 08:39 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~477 |
| 08:39 | Edited src/WorkflowExecutor.lua | 7â†’9 lines | ~123 |
| 08:39 | Edited src/WorkflowExecutor.lua | expanded (+10 lines) | ~573 |
| 08:39 | Edited src/WorkflowExecutor.lua | expanded (+9 lines) | ~729 |
| 08:40 | Edited translations/translation_en.xml | 2â†’4 lines | ~73 |
| 08:40 | Edited translations/translation_de.xml | 2â†’4 lines | ~81 |
| 08:40 | Edited src/gui/WMStepDialog.lua | 7â†’9 lines | ~80 |
| 08:40 | Edited src/gui/WMStepDialog.lua | expanded (+12 lines) | ~178 |
| 08:40 | Edited src/gui/WMStepDialog.lua | 15â†’19 lines | ~190 |
| 08:40 | Edited src/gui/WMStepDialog.lua | 11â†’15 lines | ~156 |
| 08:40 | Edited src/gui/WMStepDialog.lua | 7â†’10 lines | ~59 |
| 08:41 | Edited src/gui/WMStepDialog.lua | modified WMStepDialog() | ~262 |
| 08:41 | Edited xml/gui/WMStepDialog.xml | inline fix | ~16 |
| 08:41 | Edited xml/gui/WMStepDialog.xml | expanded (+12 lines) | ~207 |
| 08:41 | Edited tests/specs/WorkflowStorage_spec.lua | expanded (+55 lines) | ~688 |
| 08:42 | Edited tests/specs/WorkflowStorage_spec.lua | expanded (+7 lines) | ~307 |
| 08:43 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+228 lines) | ~3544 |
| 08:44 | Edited tests/specs/WorkflowStorage_spec.lua | 20â†’20 lines | ~302 |
| 08:45 | Edited tests/specs/WorkflowStorage_spec.lua | modified hasKey() | ~445 |

## Session: 2026-06-06 08:49

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-06-06 08:55

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 08:57 | Edited website/docs/workflows/queue-system.md | modified steps() | ~813 |
| 08:57 | Edited website/docs/workflows/step-types.md | expanded (+11 lines) | ~192 |
| 08:57 | Edited website/docs/faq.md | 3â†’7 lines | ~228 |
| 08:57 | Edited website/docs/faq.md | 3â†’3 lines | ~72 |
| 08:57 | Session end: 4 writes across 3 files (queue-system.md, step-types.md, faq.md) | 3 reads | ~4105 tok |
| 09:01 | Session end: 4 writes across 3 files (queue-system.md, step-types.md, faq.md) | 3 reads | ~4105 tok |
| 09:14 | Edited src/gui/WMStepDialog.lua | 2â†’2 lines | ~36 |
| 09:14 | Edited src/gui/WMStepDialog.lua | inline fix | ~8 |
| 09:14 | Edited src/WorkflowManagerSpec.lua | expanded (+9 lines) | ~319 |
| 09:14 | Edited src/WorkflowManagerSpec.lua | expanded (+20 lines) | ~536 |
| 09:14 | Edited src/WorkflowManager.lua | server() â†’ info() | ~111 |
| 09:14 | Edited src/WorkflowExecutor.lua | 3â†’6 lines | ~127 |
| 09:15 | Edited src/WorkflowExecutor.lua | 1â†’3 lines | ~74 |
| 09:15 | Edited tests/specs/WorkflowManagerSpec_spec.lua | 11â†’12 lines | ~208 |
| 09:15 | Edited tests/specs/WorkflowManagerSpec_spec.lua | 17â†’18 lines | ~190 |
| 09:15 | Edited tests/specs/WorkflowManagerSpec_spec.lua | 12â†’13 lines | ~118 |
| 09:16 | Edited tests/specs/WorkflowManagerSpec_spec.lua | expanded (+62 lines) | ~1107 |
| 09:16 | Fixed 5 review issues: leader workflow ID in onWriteStream/onReadStream (+2 tests), clarified duplicate pendingLeader comments, MP client log, renamed isFilteringâ†’suppressListCallbacks | WorkflowManagerSpec.lua, WorkflowExecutor.lua, WorkflowManager.lua, WMStepDialog.lua, WorkflowManagerSpec_spec.lua | 359/359 pass | ~2k tok |
| 09:17 | Session end: 15 writes across 8 files (queue-system.md, step-types.md, faq.md, WMStepDialog.lua, WorkflowManagerSpec.lua) | 8 reads | ~62017 tok |
| 20:09 | Edited src/gui/WMStepDialog.lua | 2â†’2 lines | ~33 |
| 20:09 | Edited src/gui/WMStepDialog.lua | inline fix | ~7 |
| 20:09 | Edited src/gui/WMStepDialog.lua | inline fix | ~7 |
| 20:12 | Session end: 18 writes across 8 files (queue-system.md, step-types.md, faq.md, WMStepDialog.lua, WorkflowManagerSpec.lua) | 9 reads | ~69802 tok |
| 21:08 | Session end: 18 writes across 8 files (queue-system.md, step-types.md, faq.md, WMStepDialog.lua, WorkflowManagerSpec.lua) | 9 reads | ~69802 tok |
| 21:57 | Edited src/WorkflowExecutor.lua | 3â†’3 lines | ~56 |
| 21:57 | Edited src/WorkflowExecutor.lua | 2â†’2 lines | ~48 |
| 21:57 | Edited src/WorkflowExecutor.lua | inline fix | ~22 |
| 22:01 | Edited tests/specs/WorkflowExecutor_spec.lua | 9â†’9 lines | ~150 |
| 22:02 | Edited tests/specs/WorkflowExecutor_spec.lua | 16â†’18 lines | ~276 |
| 22:02 | Edited tests/specs/WorkflowExecutor_spec.lua | 10â†’14 lines | ~216 |
| 22:02 | Edited tests/specs/WorkflowExecutor_spec.lua | 9â†’13 lines | ~231 |
| 22:02 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+6 lines) | ~418 |
| 22:02 | Edited tests/specs/WorkflowExecutor_spec.lua | 7â†’5 lines | ~75 |
| 22:02 | Edited tests/specs/WorkflowExecutor_spec.lua | waits() â†’ freely() | ~49 |
| 22:03 | Session end: 28 writes across 9 files (queue-system.md, step-types.md, faq.md, WMStepDialog.lua, WorkflowManagerSpec.lua) | 11 reads | ~109507 tok |

## Session: 2026-06-06 22:35

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 22:42 | Edited src/WorkflowExecutor.lua | 5→9 lines | ~154 |
| 22:42 | Edited src/WorkflowExecutor.lua | 7→8 lines | ~140 |
| 22:42 | Edited src/WorkflowExecutor.lua | 5→6 lines | ~96 |
| 22:42 | Edited src/WorkflowExecutor.lua | 8→9 lines | ~186 |
| 22:43 | Session end: 4 writes across 1 files (WorkflowExecutor.lua) | 1 reads | ~20956 tok |
| 23:14 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+57 lines) | ~1190 |
| 23:30 | Edited tests/mocks/vehicle.lua | modified VehicleMock() | ~51 |
| 23:30 | Edited tests/mocks/vehicle.lua | modified VehicleMock() | ~52 |
| 23:32 | Session end: 7 writes across 3 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua, vehicle.lua) | 4 reads | ~40472 tok |

## Session: 2026-06-07 20:28

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-06-07 20:31

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-06-07 20:31

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 22:37 | Edited src/gui/WMHud.lua | 24→24 lines | ~330 |
| 22:42 | fix HUD status priority: check WAITING_FOR_LEADER before adRunning/cpRunning | src/gui/WMHud.lua | tests pass (362/362) | ~300 |
| 22:48 | fix HUD status priority: check WAITING_FOR_LEADER before adRunning/cpRunning | src/gui/WMHud.lua | tests pass (362/362) | ~300 |
| 22:48 | Session end: 1 writes across 1 files (WMHud.lua) | 1 reads | ~7801 tok |
| 22:50 | Edited src/gui/WMHud.lua | 20→25 lines | ~349 |
| 22:51 | Session end: 2 writes across 1 files (WMHud.lua) | 1 reads | ~8175 tok |

## Session: 2026-06-08 10:53

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 11:05 | Edited src/WorkflowExecutor.lua | 45→42 lines | ~553 |
| 11:06 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+46 lines) | ~616 |
| 11:06 | Edited tests/specs/WorkflowExecutor_spec.lua | 2→2 lines | ~55 |
| 11:06 | Edited tests/specs/WorkflowExecutor_spec.lua | 2→2 lines | ~40 |
| 11:17 | Session end: 4 writes across 2 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua) | 5 reads | ~50088 tok |
| 13:54 | Edited src/WorkflowExecutor.lua | 15→15 lines | ~183 |
| 13:55 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+16 lines) | ~341 |
| 13:55 | Session end: 6 writes across 2 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua) | 5 reads | ~51155 tok |
| 14:16 | Session end: 6 writes across 2 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua) | 5 reads | ~51155 tok |
| 14:19 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~253 |
| 14:19 | Edited src/WorkflowExecutor.lua | modified notifySupport() | ~173 |
| 14:19 | Edited src/WorkflowExecutor.lua | modified WMExecutor() | ~184 |
| 14:19 | Edited src/WorkflowExecutor.lua | 7→6 lines | ~71 |
| 14:19 | Edited src/WorkflowExecutor.lua | 4→3 lines | ~70 |
| 14:20 | Edited src/WorkflowExecutor.lua | 6→4 lines | ~42 |
| 14:20 | Edited src/WorkflowExecutor.lua | reduced (-20 lines) | ~207 |
| 14:20 | Edited src/WorkflowExecutor.lua | 4→1 lines | ~15 |
| 14:20 | Edited tests/specs/WorkflowExecutor_spec.lua | reduced (-20 lines) | ~475 |
| 14:21 | Edited tests/specs/WorkflowExecutor_spec.lua | 22→18 lines | ~214 |
| 14:25 | Edited tests/specs/WorkflowExecutor_spec.lua | removed 14 lines | ~23 |
| 14:26 | Session end: 17 writes across 2 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua) | 5 reads | ~53152 tok |
| 14:53 | Edited src/WorkflowExecutor.lua | 4→3 lines | ~31 |
| 14:53 | Edited tests/specs/WorkflowExecutor_spec.lua | 6→5 lines | ~59 |
| 14:53 | Edited tests/specs/WorkflowExecutor_spec.lua | 3→2 lines | ~24 |
| 14:59 | Session end: 20 writes across 2 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua) | 5 reads | ~52059 tok |

## Session: 2026-06-08 16:18

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 16:19 | Edited src/WorkflowExecutor.lua | 5→5 lines | ~126 |
| 16:19 | Edited src/WorkflowExecutor.lua | 23→23 lines | ~246 |
| 16:19 | Edited src/WorkflowExecutor.lua | 23→23 lines | ~244 |
| 16:19 | Edited src/WorkflowExecutor.lua | 12→14 lines | ~182 |
| 16:19 | Edited src/WorkflowExecutor.lua | 14→16 lines | ~219 |
| 16:20 | Edited src/WorkflowExecutor.lua | expanded (+7 lines) | ~474 |
| 16:20 | Edited src/WorkflowExecutor.lua | 7→8 lines | ~84 |
| 16:24 | Session end: 7 writes across 1 files (WorkflowExecutor.lua) | 1 reads | ~21133 tok |
| 18:32 | Edited tests/specs/WorkflowExecutor_spec.lua | 23→25 lines | ~293 |
| 18:32 | Edited tests/specs/WorkflowExecutor_spec.lua | expanded (+102 lines) | ~1396 |
| 18:33 | Edited tests/specs/WorkflowExecutor_spec.lua | 3→3 lines | ~40 |
| 18:33 | Edited tests/specs/WorkflowExecutor_spec.lua | 3→3 lines | ~27 |
| 18:34 | Edited tests/specs/WorkflowExecutor_spec.lua | 10→13 lines | ~214 |
| 18:44 | Session end: 12 writes across 2 files (WorkflowExecutor.lua, WorkflowExecutor_spec.lua) | 3 reads | ~43755 tok |

## Session: 2026-06-08 22:27

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
