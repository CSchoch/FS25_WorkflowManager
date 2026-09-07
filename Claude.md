# FS25 Workflow Manager

## OpenWolf

@.wolf/OPENWOLF.md

Read and follow `.wolf/OPENWOLF.md` every session. Check `.wolf/cerebrum.md` before generating code. Check `.wolf/anatomy.md` before reading files.

**Do NOT edit `.wolf/anatomy.md` manually.** It is maintained automatically by OpenWolf hooks.

## Project Overview

Lua mod for Farming Simulator 25. Combines AutoDrive (AD) and Courseplay (CP) to execute automated multi-field workflows: AD handles transport, CP handles field work. Supports multiple vehicles, hierarchical support steps, and multiplayer.

## Technical Stack

- **Language**: Lua (FS25-compatible)
- **Integration**: AutoDrive API, Courseplay API
- **UI**: FS25 GUI system (XML layouts in `xml/gui/`)
- **Storage**: XML — workflow definitions in savegame folder; runtime state on `vehicle.spec_workflowManagerSpec.wmExecution`
- **Mod Structure**: Standard FS25 ModDesc.xml

## Standing Requirements

After every code change:
1. Run tests: `& "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\run_tests.lua`
2. Add test cases for new functionality

## Key Architecture Facts

- **Workflow definitions** are immutable templates (`id`, `name`, `steps[]`, `adSettings`). No runtime state.
- **Runtime state** lives entirely on `vehicle.spec_workflowManagerSpec.wmExecution` (`activeData`).
- **Server-authoritative**: `WMExecutor.update()` is guarded `if g_server == nil then return end`. All client commands route through `WorkflowManager:sendCommand()`.
- **AD globals**: `FS25_AutoDrive.AutoDrive` — `AD.setSettingState` is a **static function** (dot notation, not colon). `pcall(AD.setSettingState, name, idx, vehicle)` — passing `AD` as first arg shifts all params and silently does nothing.
- **CP globals**: `FS25_Courseplay.g_Courseplay`
- Full API docs: `docs/API_Analysis.md`

## Running Tests

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\run_tests.lua
```

Individual runners: `tests\run_executor_spec.lua`, `tests\run_storage_spec.lua`, `tests\run_wm_spec.lua`

| Spec file | Covers |
| --- | --- |
| `EventHandler_spec.lua` | WMEventHandler (subscribe, fire, remove) |
| `Logger_spec.lua` | WMLogger (levels, formatting, api/event/state helpers) |
| `WMSettings_spec.lua` | WMSettings defaults, reset, Courseplay auto-resume accessor |
| `WorkflowStorage_spec.lua` | WMStorage save/load, adSettings, mod options, old-format migration |
| `WorkflowManager_spec.lua` | CRUD, vehicle validation, network command dispatch |
| `WorkflowExecutor_spec.lua` | Full state machine: start/stop/pause/resume/step nav, support vehicles, MP roles |
| `AutoDriveIntegration_spec.lua` | AD destinations, park/refuel/repair route resolution |
| `WorkflowManagerSpec_spec.lua` | Vehicle spec: onLoad, onPostLoad, saveToXMLFile, onWriteStream/onReadStream, onDelete |
| `WMHud_spec.lua` | HUD button handlers, vehicle targeting |
| `WMLeaderVehicleSelectDialog_spec.lua` | Leader candidate list building |
| `WMStepDialog_spec.lua` | Step type/action branching, confirm payloads, support-step type restrictions |
| `WMEditorDialog_spec.lua` | Edit-buffer contract: Save commits to the live workflow, Cancel discards; new-workflow registration |
| `WMMainDialog_spec.lua` | New/Edit entry points: New hands the editor an unregistered workflow |
| `CourseplayIntegration_spec.lua` | Course entry resolution from the root view, legacy-name fallback, folder navigation, seed type selection |
| `CourseplayCoursesLoader_spec.lua` | Course enumeration from the root view, root-relative names |
| `WMConsoleCommands_spec.lua` | Console command registration/removal; wmPrintState reports the executor's real sync gate |
| `WMGameSettings_spec.lua` | Settings-row injection: clones the vanilla row/header, focus ids, controls list, MP read-only, hook-once, delete |

**Courseplay resume after savegame load:** Courseplay never auto-resumes — it overwrites the
base-game `AIFieldWorker#isActive` to `false` at save time on purpose. It also only writes its own
`#rememberedWpIx` when a job stops *cleanly* (`AIDriveStrategyFieldWorkCourse:delete()`), never
mid-drive, so after a load that index is typically nil and `startCpAtLastWp()` silently falls back
to **waypoint 1** — re-driving the whole field. WM therefore captures the waypoint itself in
`WorkflowManagerSpec:saveToXMLFile` (`#cpWasRunning` / `#cpResumeWaypoint`, read from the live
strategy via `CPIntegration:getResumeWaypointIx`) and re-issues the start in
`WMExecutor:resumeCourseplayAfterLoad` once the 10 s `autoResumeUntil` window expires. The seed
must happen **after** any course load (loading a course clears CP's remembered index) — see the
ordering in `startCourseplayStep`. With no recorded waypoint the workflow deliberately stays
PAUSED rather than restarting from scratch.

Current total: **731**. New spec files must be added to the `testFiles` list in `tests/run_tests.lua`
or they will not run.

**Mod options (game settings):** `WMSettings` holds the player-facing options; `WMGameSettings`
appends rows to the base game's **General** settings list on the first
`InGameMenuSettingsFrame:onFrameOpen`. The rows are **clones of the vanilla ones** — page is
`g_gui.screenControllers[InGameMenu].pageSettings`, layout is `page.generalSettingsLayout`, the
row prefab is `page.checkWoodHarvesterAutoCutBox` and the header prefab is the layout element
named `sectionHeader` — so there is no GUI XML of our own. Values are persisted per savegame by
`WMStorage` under `WorkflowManager.settings.general`, so in multiplayer the server's savegame is
authoritative and the control is disabled for clients (`g_server == nil`).
`courseplayAutoResume` gates **only** the automatic post-load Courseplay restart in
`WMExecutor:update`; the manual Resume path must keep calling `resumeCourseplayAfterLoad` or it
falls through to the monitor branch and marks the field work complete.

**Courseplay course paths:** course names are stored as **root-relative** paths
(`"Farm1/Field A"`). Both enumeration (`CPCoursesLoader:extractCoursesFromFileSystem`) and lookup
(`CPIntegration:findCourseEntry`) must start from `rootDirectoryView`. Never use
`currentDirectoryView` as the primary — it follows Courseplay's own GUI navigation, so it hides
courses outside the open folder and makes names resolve differently at author time vs. run time.

The real root view sits one level *above* Courseplay's `Singleplayer` folder, so names enumerated
today read `Singleplayer/F34/Kalken`. Workflows authored before the root-view fix stored
`F34/Kalken`. `findCourseEntry` therefore falls back to a **path-suffix** match on the collected
candidates — matching by base name alone silently loaded `F09/Kalken` for a step asking for
`F34/Kalken`.

**Per-step seed type:** a Courseplay field-work step can carry `seedFruitType` (a fruit type
*name*, e.g. `"WHEAT"`, stored as `#seedFruitType`). Courseplay has **no** seed API — the seed
lives on the base-game `SowingMachine` specialization of the attached implement, so
`CPIntegration:applySeedFruitType` walks `vehicle:getChildVehicles()` looking for
`spec_sowingMachine` and calls `implement:setSeedFruitType(fruitTypeIndex)`. That setter is a
**silent no-op** for a fruit missing from `spec.seeds`, so membership is checked first; it also
fires `SetSeedIndexEvent` itself, so the server-side call syncs to clients with no WM event.
Semantics: no seeder attached → skip silently; seeder attached but none can sow the fruit →
`handleStepError`; seeder present but `getIsSeedChangeAllowed()` false (mission-locked) → warn
and continue. Applied at the very top of `WMExecutor:startCourseplayStep`, before the
already-running early-out and before any course load.

**Workflow lifecycle:** `WorkflowManager:buildWorkflow(name)` returns an *unregistered* workflow;
`registerWorkflow(wf)` adds it to the list (idempotent by id); `createWorkflow(name)` is both at once.
The editor's New flow deliberately uses `buildWorkflow` and defers registration to Save, so Cancel
leaves no trace — do not "simplify" it back to `createWorkflow`.

**Test framework note**: `run_tests.lua` snapshots and restores **all of `_G`** around every spec file — globals a spec adds are removed, globals it replaces are restored. Every spec must therefore own its stubs (never rely on a module or stub leaked by an earlier spec file). Loading real modules via `dofile` in `setup()` is fine; mutating the *insides* of a shared mock table still leaks, so restore those in the spec itself.

## Resources

- FS25 Modding Documentation: https://gdn.giants-software.com/
- AutoDrive source: `FS25_AutoDrive`
- Courseplay source: `FS25_Courseplay`

---

**Status**: Milestones 1–7 complete. Milestone 8 open (F1 overlay, hint relocation, editor X button).
See `Development.md` for roadmap and screenshot tasks.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**Last updated**: 2026-05-20
