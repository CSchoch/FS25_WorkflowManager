# FS25 Workflow Manager

## OpenWolf

@.wolf/OPENWOLF.md

This project uses OpenWolf for context management. Read and follow .wolf/OPENWOLF.md every session. Check .wolf/cerebrum.md before generating code. Check .wolf/anatomy.md before reading files.

**Do NOT edit `.wolf/anatomy.md` manually.** It is maintained automatically by OpenWolf hooks. Attempting to edit it will error.

## Project Overview

A mod for Farming Simulator 25 that combines AutoDrive and Courseplay to create automated workflows. The mod allows multiple fields to be processed sequentially by using AutoDrive for transport between fields and Courseplay for the actual field work.

## Technical Stack

- **Language**: Lua (FS25-compatible)
- **Integration**: AutoDrive API, Courseplay API
- **UI Framework**: FS25 GUI system
- **Data Storage**: XML (workflow definitions in savegame folder; runtime state in vehicle XML)
- **Mod Structure**: Standard FS25 ModDesc.xml

## Standing Requirements

After every code change:
1. Update CLAUDE.md with new patterns/constraints
2. Run tests: `"C:\Program Files (x86)\Lua\5.1\lua.exe" tests/run_tests.lua`
3. Add test cases for new functionality

## Architecture

### Main Components

1. **WorkflowManager** (Core) - Manages all workflows, loads/saves from XML, coordinates execution
2. **WorkflowExecutor** - Executes workflows, switches between AD/CP, monitors progress
3. **WorkflowStorage** - XML read/write for workflow definitions (no runtime state)
4. **GUI Layer** - Main dialog, editor, step dialog, HUD, ESC menu integration
5. **Integration Layer** - AD/CP API wrappers, course loader, vehicle loader

### Data Structure

**Workflow definition** (immutable template, stored in XML):
- `id`, `name`, `createdAt`, `steps[]` array — no runtime state
- Optional `adSettings = {unloadFillLevel?, pipeOffset?, preCallLevel?}` — per-workflow AD overrides (nil = keep AD's own value); applied to vehicle on workflow start and auto-resume
- Each step: `{type="autodrive"|"courseplay", target, action, unloadTarget?, fillType?, support[]?}`
- Support array contains sub-steps with same structure (no nesting deeper)

**Runtime state** (per-vehicle, stored on `vehicle.spec_workflowManagerSpec.wmExecution`):
- Core: `workflow`, `vehicle`, `status`, `currentStep`, `isMainVehicle`, `currentSupportStep`
- Idle support: `waitingForMainStep`, `waitingForMainStepIndex`, `dummyHelperActive`, `lastADTarget`
- Transitions: `justStoppedAD`, `pendingADStart/Retries`, `pendingCPStart/Retries`, `cpToCpTransition`
- State: `waitingForCompletion`, `pausedTrackingState`, `autoResumeUntil`
- Handoffs: `willHandoffToCP`, `cpHandedOffToAD`, `cpWasRunning`

`WMExecutor.activeVehicles` is a lightweight `{[vehicle] = true}` set used for update-loop iteration.

#### AutoDrive Actions/Modes

| Action           | Mode                      | Targets | Description                              |
| ---------------- | ------------------------- | ------- | ---------------------------------------- |
| `drive`          | MODE_DRIVETO (1)          | 1       | Simple point-to-point navigation         |
| `unload`         | MODE_UNLOAD (5)           | 2       | Unload combine                           |
| `pickup_deliver` | MODE_PICKUPANDDELIVER (2) | 2       | Load at target, deliver to unloadTarget  |
| `deliver`        | MODE_DELIVERTO (3)        | 1       | Start at target, deliver to unloadTarget |
| `load`           | MODE_LOAD (4)             | 2       | Load at target, return to unloadTarget   |

#### Courseplay Actions

| Action         | Description                                         |
| -------------- | --------------------------------------------------- |
| `fieldwork`    | Field work (harvesting, cultivating, seeding, etc.) |
| `bale_collect` | Load/wrap bales                                     |

### XML Structure (Savegame)

Workflow **definitions** (hierarchical support sub-steps):

```xml
<?xml version="1.0" encoding="utf-8"?>
<WorkflowManager>
    <workflows>
        <workflow id="wf_001" name="Combine Harvest">
            <adSettings unloadFillLevel="0.9" pipeOffset="0.5" preCallLevel="0.8"/>
            <step type="autodrive" target="Route_Field1" action="drive"/>
            <step type="courseplay" target="Field1_Harvest" action="fieldwork">
                <support type="autodrive" target="Field1" action="unload" unloadTarget="Silo"/>
                <support type="autodrive" target="Silo" action="deliver"/>
            </step>
            <step type="autodrive" target="Route_Field2" action="drive"/>
            <step type="courseplay" target="Field2_Harvest" action="fieldwork">
                <support type="autodrive" target="Field2" action="unload" unloadTarget="Silo"/>
                <support type="autodrive" target="Silo" action="deliver"/>
            </step>
        </workflow>
    </workflows>
</WorkflowManager>
```

`<adSettings>` is optional — omitted entirely when all three fields are nil.

Old savegames with `linkRole`/`linkedWorkflowId`/`syncGroup` are migrated transparently on first load.

Vehicle workflow **runtime state** (stored in vehicle savegame XML via `WorkflowManagerSpec`):

```xml
<vehicles>
    <vehicle ...>
        <FS25_WorkflowManager>
            <workflowManagerSpec workflowId="workflow_001" currentStep="3"/>
        </FS25_WorkflowManager>
    </vehicle>
</vehicles>
```

On `onPostLoad`, this state is restored as `status = "paused"` with a 10-second auto-resume window.

## Development Roadmap

### Completed

**Milestones 1–7:** Core (WorkflowManager, Executor, XML storage), GUI (main dialog, editor, HUD, ESC menu), Vehicle selection, AD/CP integration, Searchable dropdowns

**Recent:** Multi-field workflows, hierarchical support steps, per-vehicle runtime state with savegame persistence, auto-resume after load, draggable HUD, reactive HUD show/hide, HUD badges/tooltips, step editor UX (selected-value rows, auto-select), support vehicle dummy AD hold to prevent staling, `justStoppedAD` fix for idle transitions, per-workflow AD settings (unloadFillLevel, pipeOffset, preCallLevel) accessible from main dialog via "AD/CP Einstellungen" button, fixed pcall arg-order bug in `applyWorkflowSettings`, fixed preCallLevel unit mismatch (now stored as 0.0–1.0 fraction), settings re-applied after `StartDriving`

**Other:** Courseplay resume at nearest waypoint, release build support (DevConfig stub), DDS textures, old linked-workflow migration, multiple simultaneous support vehicles, sub-step editor numbering (N.M format), mode dialog vehicle reference fix

### Milestone 8: GUI Refinement

- [ ] F1 ingame help menu overlays the GUI
- [ ] Relocate double-click-to-edit hint to the bottom
- [ ] Editor dialog X button to close in top right corner

### Milestone 9: Folder View

- [ ] Show folders in dropdowns (collapsed by default)
- [ ] For AD Targets and CP Courses
- [ ] Collapse all / Expand all buttons

### Milestone 10: Polish

- [ ] Error handling improvements
- [ ] Performance optimization

### Milestone 11: Phase 2 Features

- [ ] Queue system for multiple vehicles
- [ ] Advanced conditions
- [ ] Add further CP settings for multiple vehicle courses

## API Integration

### AutoDrive

Key functions from `ExternalInterface.lua`, `Specialization.lua` and `GraphManager.lua`:

- **Start route**: `AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)`
- **Stop route**: `vehicle:stopAutoDrive()` - proper stop with braking, cruise control off, module resets
- **Pause route**: `AutoDrive:HoldDriving(vehicle)`
- **Get destinations**: `AutoDrive:GetAvailableDestinations()` - returns `{markerID = {name, x, y, z, id}}`
- **Check active**: `vehicle.ad.stateModule:isActive()`
- **Mode constants**: `MODE_DRIVETO=1`, `MODE_PICKUPANDDELIVER=2`, `MODE_DELIVERTO=3`, etc.

**Per-workflow settings** (`ADIntegration:applyWorkflowSettings(vehicle, adSettings)`):
- Reads `vehicle.ad.settings[name].values` to find the nearest valid index, then calls `AD.setSettingState(name, idx, vehicle)`
- `AutoDrive.setSettingState` is a **static function** (dot notation, not colon) — pcall must be `pcall(AD.setSettingState, settingName, idx, vehicle)`. Passing `AD` as the first arg shifts all parameters and silently does nothing.
- Called in `WMExecutor:startWorkflow()`, again inside `startAutoDriveStep()` after `StartDriving` succeeds (AD's route-start can overwrite settings), and on auto-resume after savegame load
- Settings: `unloadFillLevel` (0.0–1.0), `pipeOffset` (-5.0–5.0 m), `preCallLevel` (0.0–1.0 fraction; UI shows 0–100%, stored ÷100)
- All three settings are fractions 0.0–1.0 internally — AD's `.values` arrays confirm this
- Nil fields are skipped — AD keeps its own value

**AD -> CP Handoff**:

- `vehicle.ad.stateModule:setStartHelper(true)` - tells AD to start helper on completion
- Pre-load CP course before starting AD, AD handles the switch automatically

**Destination Groups/Folders**:

- `ADGraphManager:getMapMarkers()` - returns all markers with group info
- Markers in "All" group shown without prefix, others as `"Group/Name"`

### Courseplay

Key functions from `CpAIWorker.lua` and `CpAIFieldWorker.lua`:

- **Check available**: `g_Courseplay ~= nil`
- **Start field work**: `vehicle:startCpAtLastWp()` or `vehicle:startCpAtFirstWp()`
- **Resume at nearest wp**: `vehicle:cpStartStopDriver(false)` (used when restoring from save)
- **Stop**: `vehicle:stopCurrentAIJob(AIMessageSuccessStoppedByUser.new())`
- **Check active**: `vehicle:getIsCpActive()`
- **Has course**: `vehicle:hasCpCourse()`
- **Load course**: `vehicle:appendLoadedCpCourse(entity)`

**Important**: Access globals via `FS25_AutoDrive.AutoDrive` and `FS25_Courseplay.g_Courseplay`

Full API documentation: `docs/API_Analysis.md`

## File Structure

```
FS25_WorkflowManager/
├── modDesc.xml
├── icon_WorkflowManager.dds           # Mod icon (256x256 DDS, BC1_UNORM)
├── CLAUDE.md
├── _art/                              # Source art assets (not shipped in release)
│   ├── icon_WorkflowManager.png       # Mod icon source PNG
│   ├── icon_WorkflowManagerLarge.png  # High-res mod icon source
│   └── textures/                      # HUD button source PNGs → regenerate DDS with tools/png_to_dds.py
│       ├── white.png
│       ├── icon_prev.png
│       ├── icon_pause.png
│       ├── icon_play.png
│       ├── icon_stop.png
│       └── icon_next.png
├── .vscode/                           # VS Code workspace config
├── src/
│   ├── DevConfig.lua                  # Development configuration
│   ├── WorkflowManager.lua            # Main class & entry point
│   ├── WorkflowManagerSpec.lua        # Vehicle specialization (runtime state, save/load)
│   ├── WorkflowExecutor.lua           # Execution engine (per-vehicle activeVehicles set)
│   ├── WorkflowStorage.lua            # XML read/write for workflow definitions only
│   ├── gui/
│   │   ├── WMMainDialog.lua           # Main dialog (workflow list, 2-column: name + steps)
│   │   ├── WMEditorDialog.lua         # Workflow editor dialog
│   │   ├── WMStepDialog.lua           # Step add/edit dialog with searchable lists
│   │   ├── WMTextInputDialog.lua      # Text input overlay dialog
│   │   ├── WMModeSelectDialog.lua     # Role selection dialog (Main/Support) when starting a workflow with support steps
│   │   ├── WMADSettingsDialog.lua     # Per-workflow AD/CP settings dialog (unloadFillLevel, pipeOffset, preCallLevel)
│   │   ├── WMHud.lua                  # In-vehicle HUD with icon buttons (draggable)
│   │   ├── WMHudElements.lua          # HUD element classes
│   │   ├── WorkflowManagerGUI.lua     # GUI manager / controller
│   │   ├── WorkflowEditorGUI.lua      # Editor GUI controller
│   │   └── WorkflowManagerMenuFrame.lua # ESC menu integration
│   ├── integration/
│   │   ├── AutoDriveIntegration.lua   # AD API wrapper
│   │   ├── CourseplayIntegration.lua  # CP API wrapper (startAtNearest support)
│   │   ├── CourseplayCoursesLoader.lua # CP saved courses loader
│   │   └── CourseplayVehiclesLoader.lua # Vehicle loader (AD+CP filter)
│   └── utils/
│       ├── Logger.lua                 # Logging utility
│       ├── EventHandler.lua           # Event system
│       └── DebugUtil.lua              # Debug utilities
├── translations/
│   ├── translation_en.xml
│   └── translation_de.xml
├── textures/
│   ├── white.dds                      # generated DDS; used by createImageOverlay overlays
│   ├── icon_prev.dds                  # HUD button: Previous step (<<) — BC3+mips, used at runtime
│   ├── icon_pause.dds                 # HUD button: Pause (||)
│   ├── icon_play.dds                  # HUD button: Resume (>)
│   ├── icon_stop.dds                  # HUD button: Stop ([])
│   └── icon_next.dds                  # HUD button: Next step (>>)
├── tools/
│   └── png_to_dds.py                  # Converts _art/textures/*.png + _art/*.png to DDS
├── testdata/
│   └── sample_workflows.xml           # Test workflow data
├── docs/
│   ├── API_Analysis.md                # AD/CP API documentation
│   ├── LinkedWorkflowPairsConcept.md  # Linked workflows design doc
│   └── QueueSystemConcept.md          # Queue system design doc
├── website/                           # Docusaurus documentation site
│   ├── docs/                          # User-facing documentation (markdown)
│   ├── src/                           # Site components
│   ├── docusaurus.config.ts           # Site configuration
│   └── package.json                   # Dependencies
└── xml/gui/
    ├── guiProfiles.xml                # Custom GUI profiles
    ├── WMMainDialog.xml               # Main dialog layout (1100px wide, 2 columns: name + steps, AD Settings button)
    ├── WMEditorDialog.xml             # Editor dialog layout
    ├── WMStepDialog.xml               # Step dialog layout
    ├── WMModeSelectDialog.xml         # Role selection dialog layout (Main/Support)
    ├── WMADSettingsDialog.xml         # AD/CP settings dialog layout (660×440px)
    ├── TextInputDialog.xml            # Text input dialog layout
    ├── WorkflowManagerGUI.xml         # Main GUI layout
    └── WorkflowManagerMenuFrame.xml   # ESC menu integration
```

## Key Implementation Notes

### Vehicle Detection

- Vehicles are NOT stored with workflows (definitions are immutable templates)
- When starting a workflow, uses `g_currentMission.controlledVehicle`
- Vehicle must have both AutoDrive AND Courseplay support
- Validation via `WorkflowManager.isVehicleValid()`
- Prevents starting a new workflow on a vehicle already running one (`isWorkflowActiveOnVehicle`)

### Per-Vehicle Runtime State

- All mutable execution state lives on `vehicle.spec_workflowManagerSpec.wmExecution` (`activeData`)
- `WMExecutor.activeVehicles` is `{[vehicle]=true}` — a lightweight set for update-loop iteration
- GUI components query `WorkflowManager:getVehicleWorkflowState(vehicle)` for current vehicle's state
- Workflow definitions only contain `id`, `name`, `steps`, `createdAt`, `adSettings` — never `status` or `currentStep`

### Vehicle Savegame Persistence

- `WorkflowManagerSpec.saveToXMLFile` saves `workflowId` + `currentStep` into the vehicle's XML
- `WorkflowManagerSpec.onPostLoad` restores state as `status = "paused"` with `autoResumeUntil = g_currentMission.time + 10000`
- The 10-second window lets AD/CP re-initialize; the update loop auto-resumes once they are active
- XML schema keys registered in `WorkflowManagerSpec.initSpecialization()`
- On vehicle delete, `onDelete` stops the workflow to prevent dangling state

### CP<->AD Cyclic Handoff

- When CP finishes and starts AD internally (e.g., for unloading), executor waits for AD
- When AD finishes and restarts CP, executor continues monitoring CP
- Step only completes when BOTH CP and AD are not running

### Manual Step Switching (Prev/Next)

- Uses `vehicle:stopAutoDrive()` for proper AD stopping (handles braking, cruise control, module resets)
- AD->AD transitions use deferred start: waits ~1 second for AD to fully reset before starting new route
- AD->CP transitions also defer CP start until AD is fully stopped
- Tracked via `justStoppedAD` flag and `pendingADStart`/`pendingCPStart` in update loop
- `justStoppedAD` is cleared by `resetStepTrackingState` — do not let it survive across idle transitions
- HUD calls `WMExecutor:goToPreviousStep(vehicle)` / `goToNextStep(vehicle)` (vehicle reference, not workflow)

### Courseplay Resume

- Normal start: `vehicle:startCpAtLastWp()` or `vehicle:startCpAtFirstWp()`
- Resume from save: `vehicle:cpStartStopDriver(false)` to start at nearest waypoint
- Controlled via `startAtNearest` parameter in `CPIntegration:startFieldWork()`

### Hierarchical Support Steps

- Each main step has `step.support = {}` array of sub-steps
- Mode dialog (Main/Support) on workflow start with support steps
- `isMainVehicle` bool determines execution path; support vehicles use `currentSupportStep` (1-based index in current main's support array)
- Support loops sub-steps; when main advances, `onMainStepChanged` resets support to sub-step 1
- No sub-steps? Support enters `waitingForMainStep`, calls `startDummyADHold()` which sets `vehicle.ad.stateModule:setActive(true)` directly (pcall-guarded, no real route) to keep AD's subsystem alive. Deactivated with `setActive(false)` on pause or when real work starts. **Never use `startRoute + HoldDriving` as a dummy** — `ADDrivePathModule.PAUSE_TIMEOUT = 3000ms` causes it to auto-resume and drive.
- Pause/stop from main propagates to all support via `getSupportActiveDataListForWorkflow`
- Helpers: `getMainActiveDataForWorkflow()`, `getSupportActiveDataListForWorkflow()`, `getCurrentStep(activeData)`

### Draggable HUD

- HUD header acts as a drag handle: clicking and dragging repositions the entire panel
- State tracked via `WMHud.isDragging`, `dragOffsetX`, `dragOffsetY`
- Position clamped to screen bounds; header color changes while dragging for visual feedback

### Fill Types

- Fill type dropdowns use `{name = "WHEAT", title = "Wheat"}` pairs
- `name` is the internal FS25 fill type ID used in step XML; `title` is the localized display name
- Sourced via `ADIntegration:getAvailableFillTypes()`

### GUI Input

- Works both when walking and in a vehicle
- Uses vehicle specialization (`WorkflowManagerSpec`) for in-vehicle input
- Uses `PlayerInputComponent.registerGlobalPlayerActionEvents` for global input

### Data Caching

- AD destinations and CP courses loaded once when GUI opens
- Cache cleared on GUI close to avoid conflicts with CP internal state

### HUD Icons

- 32x32 DDS icons (BC3_UNORM + full mip chain) with white shapes on transparent background
- HUD icon overlays use DDS — eliminates "raw format" / CPU mip-generation warnings at load time
- `createImageOverlay` overlays also use DDS; `white.dds` is R8G8B8A8_UNORM (1×1 too small for block compression)
- World/model textures use DDS: with alpha → BC3/DXT5; fully opaque → BC1/DXT1
- Source PNGs live in `_art/textures/`; regenerate DDS with `tools/png_to_dds.py`
- Color-tinted at runtime: normal (white), hover (cyan), disabled (gray), active (green)
- Hover tracking for visual feedback on mouse-over

## Running Tests

```bash
"C:\Program Files (x86)\Lua\5.1\lua.exe" tests/run_executor_spec.lua  # Executor spec
"C:\Program Files (x86)\Lua\5.1\lua.exe" tests/run_storage_spec.lua   # Storage spec
"C:\Program Files (x86)\Lua\5.1\lua.exe" tests/run_wm_spec.lua        # WorkflowManager spec
"C:\Program Files (x86)\Lua\5.1\lua.exe" tests/run_tests.lua          # All tests
```

- `tests/mocks/` — game globals, XMLFile, vehicle factory stubs
- `tests/specs/` — one spec per module
- `tests/fixtures/` — shared workflow test data

## Resources

- FS25 Modding Documentation: https://gdn.giants-software.com/
- AutoDrive source: `FS25_AutoDrive`
- Courseplay source: `FS25_Courseplay`
- FS25 Forum: https://forum.giants-software.com/

---

**Status**: Phases 1-4 IN PROGRESS — Core, executor, GUI layer all functional. Recent: AD/CP Settings button on main dialog, fixed AD settings not applying (pcall arg order + preCallLevel unit mismatch + re-apply after StartDriving). Milestone 8 items (F1 overlay, hint relocation, X button) remain open.
**Last updated**: 2026-05-05

## Screenshots Needed

Screenshots for the Docusaurus documentation site (`website/static/img/screenshots/`). Take these in-game and save them at the listed paths:

| File                         | What to show                                                                                                                | Used in                                                                        | Status                              |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ----------------------------------- |
| `main-dialog.png`            | Main dialog (1100px wide) showing button row with **AD/CP Settings** button and 2–3 workflows in the list                  | `ui/main-dialog.md`, `workflows/creating-workflows.md`                         | **Retake needed** (dialog resized)  |
| `ad-settings-dialog.png`     | AD/CP Settings dialog open with example values in all three fields (Unload Fill Level, Pipe Offset, Pre-Call Level)         | `ui/main-dialog.md`                                                            | **New — not yet taken**             |
| `editor-dialog.png`          | Editor dialog open for a workflow with 3–5 steps visible, including a mix of AutoDrive and Courseplay rows                  | `ui/editor-dialog.md`                                                          | Exists                              |
| `step-dialog-autodrive.png`  | Step dialog open with **AutoDrive** selected, showing Target, Action, Unload Target, and Fill Type fields                   | `ui/editor-dialog.md`, `workflows/step-types.md`                               | Exists                              |
| `step-dialog-courseplay.png` | Step dialog open with **Courseplay** selected, showing the course dropdown and Action field                                 | `ui/editor-dialog.md`, `workflows/step-types.md`                               | Exists                              |
| `hud-running.png`            | In-vehicle HUD overlay while a workflow is actively running, showing workflow name, step counter, and the 4 control buttons | `ui/hud-controls.md`, `workflows/executing-workflows.md`, `getting-started.md` | Exists                              |

## Todo

### Critical (Ship Blockers)

- [ ] **Fix duplicate `KEY_d` binding** in `modDesc.xml:67-81` — both `WM_GUI_DELETE` and `WM_GUI_MOVE_DOWN` are bound to `KEY_d`, causing both actions to fire simultaneously

### Low Priority

- [ ] **Remove `or true` dead code** in `WorkflowExecutor.lua` — `if not CPIntegration:hasCourse(vehicle) or true then` makes the CP check permanently dead
- [ ] **Remove unused action declarations** in `modDesc.xml` — `WM_START_WORKFLOW` and `WM_STOP_WORKFLOW` are declared but have no bindings and no references in source code
