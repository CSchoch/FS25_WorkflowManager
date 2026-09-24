# anatomy.md

> Auto-maintained by OpenWolf. Last scanned: 2026-09-24T07:09:00.446Z
> Files: 99 tracked | Anatomy hits: 0 | Misses: 0

## ../../../../../.claude/plans/

- `id-like-a-wm-lucky-minsky.md` — New Workflow Steps: "Refuel" and "Repair" (~3858 tok)
- `id-like-workflow-manager-cryptic-wave.md` — Per-step seed type for the sowing machine (~2904 tok)
- `idempotent-zooming-wadler.md` — Add a "Courseplay auto resume" option to the game settings (~2559 tok)
- `is-it-possible-to-recursive-forest.md` — Resume Courseplay at the last waypoint after savegame load (~2620 tok)
- `there-was-again-an-delegated-kay.md` — Fix: leader-follower reference lost across save/load (stale XML vehicle index) (~1513 tok)

## ../../../../../.claude/projects/c--Users-Chef-Documents-My-Games-FarmingSimulator2025-mods-FS25-WorkflowManager/memory/

- `feedback_ask_before_choosing_keybindings.md` (~268 tok)
- `MEMORY.md` — FS25 WorkflowManager - Session Memory (~1355 tok)
- `project_leader_uniqueid_fix.md` (~531 tok)
- `project_queuesystem_review_fixes.md` (~585 tok)
- `project_wm_keybinding_audit.md` — Declares bodies (~613 tok)

## ../../../../../AppData/Local/Temp/claude/c--Users-Chef-Documents-My-Games-FarmingSimulator2025-mods-FS25-WorkflowManager/0e008aae-1437-47ea-92bf-f55f7ab67d82/scratchpad/

- `webeditor_smoke.js` — Declares errors (~1179 tok)

## ../../../../../AppData/Local/Temp/claude/c--Users-Chef-Documents-My-Games-FarmingSimulator2025-mods-FS25-WorkflowManager/1037a215-6a2c-40b9-a327-f060402d1506/scratchpad/

- `csscheck.js` — Declares fs (~289 tok)
- `wecheck.js` — fs: textContent, parseXml, matchesSimple + 4 more (~3870 tok)

## ../../../../../AppData/Local/Temp/claude/c--Users-Chef-Documents-My-Games-FarmingSimulator2025-mods-FS25-WorkflowManager/44e09300-6189-4e50-8b16-e5ae9eec80d1/scratchpad/

- `webeditor_check.js` — Smoke-check the webeditor's migration + support-step type logic in a bare VM (~1310 tok)

## ../../../../../AppData/Local/Temp/claude/c--Users-Chef-Documents-My-Games-FarmingSimulator2025-mods-FS25-WorkflowManager/c5441a8e-ad2a-4aec-8364-7f3ff2ddaa3f/scratchpad/

- `append_buglog.py` — add (~2318 tok)

## ../../../../../AppData/Local/Temp/claude/c--Users-Chef-Documents-My-Games-FarmingSimulator2025-mods-FS25-WorkflowManager/cf0cd88e-1fb2-4e57-8d56-7a5d7bf9a788/scratchpad/shot/

- `seed.js` — Screenshot fixture only — seeds the web editor with a representative English workflow (~594 tok)

## ../../../../../AppData/Local/Temp/claude/c--Users-Chef-Documents-My-Games-FarmingSimulator2025-mods-FS25-WorkflowManager/e5a90252-f238-4c13-964c-df2cbdb9b392/scratchpad/

- `we_settings_check.js` — Headless check: webeditor round-trips <settings><general courseplayAutoResume/>. (~1729 tok)

## ../../../tmp/claude-0/-home-user-FS25-WorkflowManager/442c8c76-f882-5833-bcbb-d59df923d2a5/scratchpad/


## ../FS25_WorkflowManager-docs/.github/workflows/


## ./

- `CLAUDE.md` — FS25 Workflow Manager (~3214 tok)
- `Development.md` — FS25 Workflow Manager — Development (~1758 tok)
- `modDesc.xml` — Declares per (~3573 tok)

## .claude/


## .claude/rules/


## .github/ISSUE_TEMPLATE/


## .github/workflows/


## _art/


## _art/textures/


## docs/

- `API_Analysis.md` — AutoDrive & Courseplay API Analysis (~2128 tok)
- `MultiplayerConcept.md` — Multiplayer Concept (~8782 tok)
- `SCREENSHOTS.md` — Screenshot Guide (Developer Reference) (~2633 tok)

## src/

- `WMSettings.lua` — reset, isCourseplayAutoResumeEnabled (~356 tok)
- `WorkflowExecutor.lua` — init, startWorkflow, stopWorkflow, buildSyncMaps, refreshLeaderLink (~22551 tok)
- `WorkflowManager.lua` — getStepTypeLabel, isMarkerStepType, isTargetlessStepType, isAutoDriveTrackedStepType, getStepTypeSho (~12766 tok)
- `WorkflowManagerSpec.lua` — prerequisitesPresent, registerEventListeners, onLoad, onPostLoad, saveToXMLFile (~7954 tok)
- `WorkflowStorage.lua` — deepCopySupportStep, isTargetlessStepType, parseFillTypes, init, getXmlPath (~5398 tok)

## src/dev/

- `WMConsoleCommands.lua` — -@class WMConsoleCommands (~2833 tok)

## src/gui/

- `WMADSettingsDialog.lua` — new, onCreate, onOpen, onClose, Called (~755 tok)
- `WMEditorDialog.lua` — deepCopy, new, onCreate, onOpen, onClose (~6738 tok)
- `WMGameSettings.lua` — updateFocusIds, getSettingsPage, ensureMenuInjected, refreshMenuState, onCpAutoResumeChanged (~2227 tok)
- `WMHud.lua` — ensureOverlays, createIconOverlays, updateOverlayPositions, init, show (~9568 tok)
- `WMLeaderVehicleSelectDialog.lua` — new, onCreate, buildVehicleList, onOpen, onClose (~1169 tok)
- `WMMainDialog.lua` — new, onCreate, onOpen, onClose, refreshWorkflowList (~3813 tok)
- `WMModeSelectDialog.lua` — new, onCreate, onOpen, onClose, Called (~577 tok)
- `WMStepDialog.lua` — new, onCreate, onOpen, onClose, keyEvent (~9124 tok)
- `WMTextInputDialog.lua` — new, onCreate, onOpen, onClose, setTitle (~805 tok)

## src/integration/

- `AutoDriveIntegration.lua` — init, completeInitialization, update, checkAvailability, getDestinations (~11594 tok)
- `CourseplayCoursesLoader.lua` — init, getCourseplayObject, scanCourses, logCourseplayStructure, extractCoursesFromStorage (~5496 tok)
- `CourseplayIntegration.lua` — init, completeInitialization, update, checkAvailability, hasSpec (~9928 tok)

## src/network/


## src/utils/

- `DebugUtil.lua` — init, update, draw, dumpTable, dumpTableRecursive (~2081 tok)
- `EventHandler.lua` — init, Callback, to, addEventListener, removeEventListener (~1004 tok)

## testdata/


## tests/

- `run_tests.lua` — local, assert, describe, it, before_each (~2284 tok)

## tests/fixtures/


## tests/mocks/

- `game_globals.lua` — getDate, addModEventListener, NetworkUtil, NetworkUtil (~3073 tok)
- `init.lua` — setupPackagePath, to, resetMocks, loadSource (~983 tok)

## tests/specs/

- `AutoDriveIntegration_spec.lua` — makeImplement, makeVehicle (~4979 tok)
- `CourseplayCoursesLoader_spec.lua` — file, folder, view, makeFileSystem, contains (~1901 tok)
- `CourseplayIntegration_spec.lua` — file, folder, view, makeStorage, makeVehicle (~6954 tok)
- `EventHandler_spec.lua` — Declares gracefully (~2992 tok)
- `ModDescInputBindings_spec.lua` (~471 tok)
- `WMConsoleCommands_spec.lua` — captureOutput, makeVehicle (~1391 tok)
- `WMEditorDialog_spec.lua` — makeWorkflow, makeDialog (~5980 tok)
- `WMGameSettings_spec.lua` — setText, setDisabled, setIsChecked, setCallback, invalidateLayout (~4230 tok)
- `WMHud_spec.lua` — makeVehicle (~4253 tok)
- `WMLeaderVehicleSelectDialog_spec.lua` — makeVehicle, makeList, makeButton (~3207 tok)
- `WMMainDialog_spec.lua` — makeDialog, makeStartDialog (~2443 tok)
- `WMModeSelectDialog_spec.lua` — makeDialog, makeBoundDialog, role tri-state + Run-as-Support hotkey (~1400 tok)
- `WMSettings_spec.lua` (~408 tok)
- `WMStepDialog_spec.lua` — makeDialog, makeStubDialog, confirm (~5978 tok)
- `WorkflowExecutor_spec.lua` — makeVehicle, activeData, makeWorkflow, makeWorkflowWithSupport, makeLeaderWF (~35163 tok)
- `WorkflowManager_spec.lua` — Declares constants (~9653 tok)
- `WorkflowManagerADRequirement_spec.lua` — Loads the real WorkflowManager.lua with `source` neutered; tests workflowNeedsAutoDrive / isVehicleValid (AutoDrive optional for CP-only workflows) (~1400 tok)
- `WorkflowManagerLifecycle_spec.lua` — loadModule, wasSourced, activeVehicle (~1646 tok)
- `WorkflowManagerSpec_spec.lua` — makeVehicle, makeSavegameXML (~12595 tok)
- `WorkflowStorage_spec.lua` — hasFormatVersion (~10819 tok)

## textures/


## tools/


## translations/

- `translation_de.xml` (~3086 tok)
- `translation_en.xml` (~2782 tok)

## webeditor/

- `app.js` — Declares STEP_AUTODRIVE (~21216 tok)
- `index.html` — FS25 Workflow Manager — Web Editor (~4074 tok)
- `README.md` — Project documentation (~676 tok)
- `style.css` — Styles: 99 rules, 46 vars (~6454 tok)

## webeditor/.github/workflows/

- `deploy-webeditor.yml` — CI: Deploy Web Editor to GitHub Pages (~175 tok)

## website/

- `docusaurus.config.ts` — Declares config (~1054 tok)
- `package.json` — Node.js package manifest (~355 tok)
- `README.md` — Project documentation (~220 tok)
- `sidebars.ts` — Declares sidebars (~307 tok)

## website/.docusaurus/


## website/.docusaurus/docusaurus-plugin-content-docs/default/


## website/.docusaurus/docusaurus-plugin-content-docs/default/p/


## website/.docusaurus/docusaurus-plugin-content-pages/default/


## website/.docusaurus/docusaurus-plugin-css-cascade-layers/default/


## website/.docusaurus/docusaurus-plugin-debug/default/


## website/.docusaurus/docusaurus-plugin-debug/default/p/


## website/docs/

- `faq.md` — Frequently Asked Questions (~1856 tok)
- `getting-started.md` — Getting Started (~977 tok)
- `installation.md` — Installation (~732 tok)
- `intro.md` — FS25 Workflow Manager (~901 tok)
- `troubleshooting.md` — Troubleshooting (~2607 tok)
- `web-editor.md` — Web Editor (~1063 tok)

## website/docs/api/

- `console-commands.md` — Console Commands (~1477 tok)
- `xml-format.md` — XML Format (~2395 tok)

## website/docs/ui/

- `ad-settings-dialog.md` — AD/CP Settings Dialog (~503 tok)
- `editor-dialog.md` — Editor Dialog (~1219 tok)
- `hud-controls.md` — HUD Controls (~1694 tok)
- `leader-select-dialog.md` — Leader Vehicle Select Dialog (~629 tok)
- `main-dialog.md` — Main Dialog (~1085 tok)
- `mode-dialog.md` — Mode Select Dialog (~604 tok)
- `step-dialog.md` — Step Dialog (~1381 tok)

## website/docs/workflows/

- `creating-workflows.md` — Creating Workflows (~1963 tok)
- `executing-workflows.md` — Executing Workflows (~2083 tok)
- `linked-workflows.md` — Multi-Vehicle Workflows (~1706 tok)
- `queue-system.md` — Queue System (~1325 tok)
- `step-types.md` — Step Types (~2633 tok)

## website/src/components/HomepageFeatures/


## website/src/css/


## website/src/pages/


## website/static/


## xml/gui/

- `WMGameSettings.xml` (~306 tok)
- `WMStepDialog.xml` — dropdown: Section (~2586 tok)
