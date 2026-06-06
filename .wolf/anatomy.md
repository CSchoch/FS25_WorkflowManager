# anatomy.md

> Auto-maintained by OpenWolf. Last scanned: 2026-06-06T07:16:14.713Z
> Files: 41 tracked | Anatomy hits: 0 | Misses: 0

## ../../../../../.claude/plans/

- `foamy-crafting-oasis.md` — Plan: Leader Vehicle — Save Persistence, MP Sync, Dialog Order (~1099 tok)
- `implement-milestone-11-tender-blum.md` — Milestone 11 — Multiple Fill Types & Synchronized Follower (~2937 tok)
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

- `WorkflowExecutor.lua` — init, onADDestinationReached, onADFinishedEvent, startWorkflow, stopWorkflow (~20336 tok)
- `WorkflowManager.lua` — init, loadDialogs, Callback, showTextInputDialog, Called (~13674 tok)
- `WorkflowManagerSpec.lua` — prerequisitesPresent, registerEventListeners, onLoad, onPostLoad, saveToXMLFile (~5593 tok)
- `WorkflowStorage.lua` — deepCopySupportStep, parseFillTypes, init, getXmlPath, saveWorkflows (~3782 tok)

## src/gui/

- `WMHud.lua` — ensureOverlays, createIconOverlays, updateOverlayPositions, init, show (~7447 tok)
- `WMLeaderVehicleSelectDialog.lua` — new, onCreate, buildVehicleList, onOpen, onClose (~1149 tok)
- `WMStepDialog.lua` — new, onCreate, onOpen, onClose, keyEvent (~7736 tok)

## src/integration/

- `AutoDriveIntegration.lua` — init, completeInitialization, update, checkAvailability, getDestinations (~9398 tok)

## src/network/


## src/utils/


## testdata/


## tests/

- `run_tests.lua` — local, assert, describe, it, before_each (~2123 tok)

## tests/fixtures/

- `workflows.lua` — createSimpleWorkflow, createHarvestWorkflow, createBaleWorkflow, createEmptyWorkflow, createRunningW (~1504 tok)

## tests/mocks/


## tests/specs/

- `WMLeaderVehicleSelectDialog_spec.lua` — makeVehicle, makeList, makeButton (~3135 tok)
- `WorkflowExecutor_spec.lua` — makeVehicle, activeData, makeWorkflow, makeWorkflowWithSupport (~17718 tok)
- `WorkflowManager_spec.lua` — Declares constants (~9079 tok)
- `WorkflowManagerSpec_spec.lua` — makeVehicle, makeSavegameXML (~9030 tok)
- `WorkflowStorage_spec.lua` — hasKey (~9633 tok)

## textures/


## tools/


## translations/

- `translation_de.xml` (~2941 tok)
- `translation_en.xml` (~2503 tok)

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
- `WMStepDialog.xml` — dropdown: Section (~2639 tok)
