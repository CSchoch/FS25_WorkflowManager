# anatomy.md

> Auto-maintained by OpenWolf. Last scanned: 2026-06-24T07:43:11.540Z
> Files: 52 tracked | Anatomy hits: 0 | Misses: 0

## ../../../../../.claude/plans/

- `add-function-to-log-parsed-yeti.md` — Plan: Add `wmPrintState` Developer Console Command (~687 tok)
- `foamy-crafting-oasis.md` — Plan: Leader Vehicle — Save Persistence, MP Sync, Dialog Order (~1099 tok)
- `i-think-we-should-drifting-hammock.md` — Plan: Replace Per-Step Sync Flags with "Wait for Leader" / "Unlock Follower" Step Types (~2785 tok)
- `implement-milestone-11-tender-blum.md` — Milestone 11 — Multiple Fill Types & Synchronized Follower (~2937 tok)
- `resilient-noodling-pudding.md` — Fix: Follower AD Auto-Start After Save/Reload (~960 tok)
- `what-was-te-idea-hidden-karp.md` — Plan: Per-Step Sync Checkboxes (Index-Based) (~2154 tok)

## ../FS25_WorkflowManager-docs/.github/workflows/

- `deploy-docs.yml` — CI: Deploy Documentation to GitHub Pages (~484 tok)

## ./

- `CLAUDE.md` — FS25 Workflow Manager (~842 tok)
- `Development.md` — FS25 Workflow Manager — Development (~1171 tok)
- `modDesc.xml` (~2263 tok)
- `pull-docs.bat` (~41 tok)
- `push-docs.bat` (~38 tok)

## .claude/


## .claude/rules/


## .github/ISSUE_TEMPLATE/


## .github/workflows/


## _art/


## _art/textures/


## docs/


## src/

- `WorkflowExecutor.lua` — init, onADDestinationReached, onADFinishedEvent, startWorkflow, stopWorkflow (~20008 tok)
- `WorkflowManager.lua` — getStepTypeLabel, isMarkerStepType, init, loadDialogs, Callback (~14056 tok)
- `WorkflowManagerSpec.lua` — prerequisitesPresent, registerEventListeners, onLoad, onPostLoad, saveToXMLFile (~7270 tok)
- `WorkflowStorage.lua` — deepCopySupportStep, isMarkerStepType, parseFillTypes, init, getXmlPath (~4632 tok)

## src/dev/

- `WMConsoleCommands.lua` — -@class WMConsoleCommands (~2685 tok)

## src/gui/

- `WMEditorDialog.lua` — new, onCreate, onOpen, onClose, setWorkflow (~5305 tok)
- `WMHud.lua` — ensureOverlays, createIconOverlays, updateOverlayPositions, init, show (~7640 tok)
- `WMLeaderVehicleSelectDialog.lua` — new, onCreate, buildVehicleList, onOpen, onClose (~1149 tok)
- `WMStepDialog.lua` — new, onCreate, onOpen, onClose, keyEvent (~7601 tok)
- `WorkflowEditorGUI.lua` — init, openWorkflow, close, saveAndClose, cancelAndClose (~17483 tok)

## src/integration/

- `AutoDriveIntegration.lua` — init, completeInitialization, update, checkAvailability, getDestinations (~9398 tok)

## src/network/


## src/utils/


## testdata/


## tests/

- `run_tests.lua` — local, assert, describe, it, before_each (~2135 tok)

## tests/fixtures/

- `workflows.lua` — createSimpleWorkflow, createHarvestWorkflow, createBaleWorkflow, createEmptyWorkflow, createRunningW (~1504 tok)

## tests/mocks/

- `game_globals.lua` — getDate, addModEventListener (~2765 tok)
- `init.lua` — setupPackagePath, to, resetMocks, loadSource (~996 tok)
- `vehicle.lua` — createValid, createADOnly, createCPOnly, createBasic, createNil (~1282 tok)

## tests/specs/

- `WMHud_spec.lua` — makeVehicle (~2098 tok)
- `WMLeaderVehicleSelectDialog_spec.lua` — makeVehicle, makeList, makeButton (~3135 tok)
- `WMStepDialog_spec.lua` — makeDialog, makeStubDialog, confirm (~2605 tok)
- `WorkflowExecutor_spec.lua` — makeVehicle, activeData, makeWorkflow, makeWorkflowWithSupport, makeLeaderWF (~23172 tok)
- `WorkflowManager_spec.lua` — Declares constants (~9570 tok)
- `WorkflowManagerSpec_spec.lua` — makeVehicle, makeSavegameXML (~11001 tok)
- `WorkflowStorage_spec.lua` — hasFormatVersion (~9832 tok)

## textures/


## tools/


## translations/

- `translation_de.xml` (~2969 tok)
- `translation_en.xml` (~2529 tok)

## website/

- `build.bat` (~33 tok)
- `sidebars.ts` — Declares sidebars (~257 tok)
- `start.bat` (~50 tok)

## website/.docusaurus/


## website/.docusaurus/docusaurus-plugin-content-docs/default/


## website/.docusaurus/docusaurus-plugin-content-docs/default/p/


## website/.docusaurus/docusaurus-plugin-content-pages/default/


## website/.docusaurus/docusaurus-plugin-css-cascade-layers/default/


## website/.docusaurus/docusaurus-plugin-debug/default/


## website/.docusaurus/docusaurus-plugin-debug/default/p/


## website/docs/

- `faq.md` — Frequently Asked Questions (~1508 tok)

## website/docs/api/


## website/docs/ui/

- `hud-controls.md` — HUD Controls (~1351 tok)

## website/docs/workflows/

- `linked-workflows.md` — Multi-Vehicle Workflows (~1640 tok)
- `queue-system.md` — Queue System (~1651 tok)
- `step-types.md` — Step Types (~1391 tok)

## website/src/components/HomepageFeatures/


## website/src/css/


## website/src/pages/


## website/static/


## xml/gui/

- `TextInputDialog.xml` (~436 tok)
- `WMADSettingsDialog.xml` (~925 tok)
- `WMEditorDialog.xml` (~1390 tok)
- `WMLeaderVehicleSelectDialog.xml` — SmoothList of active vehicles (name + workflow); Select / No Leader / Cancel buttons (~80 tok)
- `WMMainDialog.xml` (~999 tok)
- `WMModeSelectDialog.xml` (~429 tok)
- `WMStepDialog.xml` — dropdown: Section (~2471 tok)
