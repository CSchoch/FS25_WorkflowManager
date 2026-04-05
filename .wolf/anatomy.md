# anatomy.md

> Auto-maintained by OpenWolf. Last scanned: 2026-04-05T21:01:48.147Z
> Files: 134 tracked | Anatomy hits: 0 | Misses: 0

## ./

- `.gitignore` — Git ignore rules (~39 tok)
- `CLAUDE.md` — OpenWolf (~6190 tok)
- `create_release.bat` (~285 tok)
- `create_release.ps1` (~254 tok)
- `modDesc.xml` (~900 tok)
- `modIcon.dds` (~68802 tok)

## .claude/

- `settings.json` (~441 tok)
- `settings.local.json` (~225 tok)

## .claude/rules/

- `openwolf.md` (~313 tok)

## .github/ISSUE_TEMPLATE/

- `bug_report.yml` (~912 tok)
- `feature_request.yml` (~785 tok)

## .github/workflows/

- `deploy-docs.yml` — CI: Deploy Documentation to GitHub Pages (~549 tok)

## docs/

- `API_Analysis.md` — AutoDrive & Courseplay API Analysis (~1991 tok)
- `QueueSystemConcept.md` — Queue System Concept - FS25 Workflow Manager (~1530 tok)

## src/

- `DevConfig.lua` — isDevMode, isDebugLogging, shouldLogAPICalls, shouldLogStateChanges + 2 more (~1144 tok)
- `WorkflowExecutor.lua` — init, onADDestinationReached, onADFinishedEvent, startWorkflow + 3 more (~15933 tok)
- `WorkflowManager.lua` — init, loadDialogs, Callback, showTextInputDialog + 2 more (~12707 tok)
- `WorkflowManagerSpec.lua` — prerequisitesPresent, registerEventListeners, onLoad, onPostLoad + 10 more (~3875 tok)
- `WorkflowStorage.lua` — init, getXmlPath, saveWorkflows, loadWorkflows (~1955 tok)

## src/gui/

- `WMEditorDialog.lua` — new, onCreate, onOpen, onClose + 16 more (~4827 tok)
- `WMHud.lua` — ensureOverlays, createIconOverlays, updateOverlayPositions, init + 7 more (~6709 tok)
- `WMHudElements.lua` — new, mouseEvent, setHovered, getIsHovered + 20 more (~2377 tok)
- `WMMainDialog.lua` — new, onCreate, onOpen, onClose + 18 more (~3080 tok)
- `WMStepDialog.lua` — new, onCreate, onOpen, onClose + 13 more (~6395 tok)
- `WMTextInputDialog.lua` — new, onCreate, onOpen, onClose + 8 more (~786 tok)
- `WorkflowEditorGUI.lua` — init, openWorkflow, close, saveAndClose + 8 more (~17435 tok)
- `WorkflowManagerGUI.lua` — init, loadXmlGui, show, hide + 16 more (~7020 tok)
- `WorkflowManagerMenuFrame.lua` — new, onCreate, onFrameOpen, onFrameClose + 14 more (~2875 tok)

## src/integration/

- `AutoDriveIntegration.lua` — init, completeInitialization, update, checkAvailability + 10 more (~8749 tok)
- `CourseplayCoursesLoader.lua` — init, getCourseplayObject, scanCourses, logCourseplayStructure + 3 more (~5026 tok)
- `CourseplayIntegration.lua` — init, completeInitialization, update, checkAvailability + 6 more (~7932 tok)
- `CourseplayVehiclesLoader.lua` — init, scanVehicles, getVehiclesFromCourseplayAPI, getVehiclesFromMission + 12 more (~3184 tok)

## src/network/

- `WMNetworkEvents.lua` — emptyNew, new, writeStream, readStream + 6 more (~1762 tok)

## src/utils/

- `DebugUtil.lua` — init, update, draw, dumpTable + 6 more (~2153 tok)
- `EventHandler.lua` — init, Callback, to, addEventListener + 6 more (~1021 tok)
- `Logger.lua` — formatMessage, debug, info, warning + 8 more (~1356 tok)

## testdata/

- `sample_workflows.xml` (~671 tok)

## tests/

- `.busted` (~99 tok)
- `README.md` — Project documentation (~680 tok)
- `run_executor_spec.lua` — describe, it, before_each, after_each, setup (~1275 tok)
- `run_tests.lua` — local, assert, describe, it + 2 more (~1972 tok)

## tests/fixtures/

- `workflows.lua` — createSimpleWorkflow, createHarvestWorkflow, createBaleWorkflow, createEmptyWorkflow + 6 more (~1492 tok)

## tests/mocks/

- `game_globals.lua` — getDate, addModEventListener (~2663 tok)
- `init.lua` — setupPackagePath, to, resetMocks, loadSource (~902 tok)
- `vehicle.lua` — createValid, createADOnly, createCPOnly, createBasic + 3 more (~1233 tok)
- `XMLFile.lua` — with, createProxy, parsePath, getNestedPath + 22 more (~2566 tok)

## tests/specs/

- `EventHandler_spec.lua` — Declares gracefully (~3017 tok)
- `Logger_spec.lua` — capturingPrint (~3741 tok)
- `WMHud_spec.lua` — makeVehicle (~2098 tok)
- `WorkflowExecutor_spec.lua` — makeVehicle, activeData, makeWorkflow (~14668 tok)
- `WorkflowManager_spec.lua` — Declares constants (~9862 tok)
- `WorkflowStorage_spec.lua` (~3875 tok)

## textures/

- `icon_next.dds` (~1127 tok)
- `icon_pause.dds` (~1127 tok)
- `icon_play.dds` (~1127 tok)
- `icon_prev.dds` (~1127 tok)
- `icon_stop.dds` (~1127 tok)
- `white.dds` (~36 tok)

## tools/

- `png_to_dds.py` — has_alpha, convert_with_texconv, convert_with_pillow, main (~926 tok)

## translations/

- `translation_de.xml` (~2385 tok)
- `translation_en.xml` (~2283 tok)

## website/

- `.gitignore` — Git ignore rules (~68 tok)
- `build.bat` (~22 tok)
- `docusaurus.config.ts` — Declares config (~978 tok)
- `package-lock.json` — npm lock file (~201292 tok)
- `package.json` — Node.js package manifest (~342 tok)
- `README.md` — Project documentation (~204 tok)
- `sidebars.ts` — Declares sidebars (~247 tok)
- `start.bat` (~21 tok)
- `tsconfig.json` — TypeScript configuration (~64 tok)

## website/.docusaurus/

- `client-manifest.json` (~2104 tok)
- `client-modules.js` (~243 tok)
- `codeTranslations.json` (~1 tok)
- `docusaurus.config.mjs` (~2430 tok)
- `DONT-EDIT-THIS-FOLDER` (~70 tok)
- `globalData.json` (~935 tok)
- `i18n.json` (~108 tok)
- `registry.js` (~1347 tok)
- `routes.js` (~1377 tok)
- `routesChunkNames.json` (~603 tok)
- `site-metadata.json` (~268 tok)
- `site-storage.json` (~14 tok)

## website/.docusaurus/docusaurus-plugin-content-docs/default/

- `__mdx-loader-dependency.json` — ","**/*.test.{js,jsx,ts,tsx}","**/__tests__/**"],"sidebarCollapsible":true,"sidebarCollapsed":true,"docsRootComponent":"@theme/DocsRoot","docVersio... (~500 tok)
- `__plugin.json` (~19 tok)
- `site-docs-api-autodrive-md-2e2.json` (~262 tok)
- `site-docs-api-courseplay-md-d7a.json` (~263 tok)
- `site-docs-api-xml-format-md-707.json` (~275 tok)
- `site-docs-faq-md-048.json` (~205 tok)
- `site-docs-getting-started-md-d58.json` (~252 tok)
- `site-docs-installation-md-3b8.json` (~232 tok)
- `site-docs-intro-md-0e3.json` (~252 tok)
- `site-docs-troubleshooting-md-9d9.json` (~208 tok)
- `site-docs-ui-editor-dialog-md-a9f.json` (~248 tok)
- `site-docs-ui-hud-controls-md-1a0.json` (~250 tok)
- `site-docs-ui-main-dialog-md-4ae.json` (~250 tok)
- `site-docs-workflows-creating-workflows-md-31b.json` (~288 tok)
- `site-docs-workflows-executing-workflows-md-978.json` (~284 tok)
- `site-docs-workflows-linked-workflows-md-c2f.json` (~303 tok)
- `site-docs-workflows-step-types-md-293.json` (~276 tok)

## website/.docusaurus/docusaurus-plugin-content-docs/default/p/

- `ls-25-workflow-manager-docs-f7b.json` (~1615 tok)

## website/.docusaurus/docusaurus-plugin-content-pages/default/

- `__plugin.json` (~19 tok)

## website/.docusaurus/docusaurus-plugin-css-cascade-layers/default/

- `__plugin.json` (~21 tok)
- `layers.css` — Styles: 1 rules, 1 layers (~73 tok)

## website/.docusaurus/docusaurus-plugin-debug/default/

- `__plugin.json` (~17 tok)

## website/.docusaurus/docusaurus-plugin-debug/default/p/

- `ls-25-workflow-manager-docusaurus-debug-content-510.json` (~3879 tok)

## website/docs/

- `faq.md` — Frequently Asked Questions (~1267 tok)
- `getting-started.md` — Getting Started (~875 tok)
- `installation.md` — Installation (~621 tok)
- `intro.md` — FS25 Workflow Manager (~666 tok)
- `troubleshooting.md` — Troubleshooting (~1564 tok)

## website/docs/api/

- `autodrive.md` — AutoDrive Reference (~802 tok)
- `courseplay.md` — Courseplay Reference (~827 tok)
- `xml-format.md` — XML Format (~1654 tok)

## website/docs/ui/

- `editor-dialog.md` — Editor Dialog (~1507 tok)
- `hud-controls.md` — HUD Controls (~1229 tok)
- `main-dialog.md` — Main Dialog (~958 tok)

## website/docs/workflows/

- `creating-workflows.md` — Creating Workflows (~981 tok)
- `executing-workflows.md` — Executing Workflows (~1194 tok)
- `linked-workflows.md` — Linked Workflows (~2028 tok)
- `step-types.md` — Step Types (~1099 tok)

## website/src/components/HomepageFeatures/

- `index.tsx` — FeatureList (~505 tok)
- `styles.module.css` — Styles: 2 rules (~43 tok)

## website/src/css/

- `custom.css` — FS25 Workflow Manager - Custom Styles (~396 tok)

## website/src/pages/

- `index.module.css` — CSS files with the .module.css suffix will be treated as CSS modules (~111 tok)
- `index.tsx` — HomepageHeader (~387 tok)

## website/static/

- `.nojekyll` (~0 tok)

## xml/gui/

- `guiProfiles.xml` (~1148 tok)
- `TextInputDialog.xml` (~473 tok)
- `WMEditorDialog.xml` (~1627 tok)
- `WMMainDialog.xml` (~972 tok)
- `WMStepDialog.xml` (~2254 tok)
- `WorkflowEditorGUI.xml` — Declares selection (~2924 tok)
- `WorkflowManagerGUI.xml` (~1734 tok)
- `WorkflowManagerMenuFrame.xml` (~574 tok)
