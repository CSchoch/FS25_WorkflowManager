# FS25 Workflow Manager

## Project Overview

A mod for Farming Simulator 25 that combines AutoDrive and Courseplay to create automated workflows. The mod allows multiple fields to be processed sequentially by using AutoDrive for transport between fields and Courseplay for the actual field work.

## Technical Stack

* **Language**: Lua (FS25-compatible)
* **Integration**: AutoDrive API, Courseplay API
* **UI Framework**: FS25 GUI system
* **Data Storage**: XML (workflow definitions in savegame folder; runtime state in vehicle XML)
* **Mod Structure**: Standard FS25 ModDesc.xml

## Architecture

### Main Components

1. **WorkflowManager** (Core) - Manages all workflows, loads/saves from XML, coordinates execution
2. **WorkflowExecutor** - Executes workflows, switches between AD/CP, monitors progress
3. **WorkflowStorage** - XML read/write for workflow definitions (no runtime state)
4. **GUI Layer** - Main dialog, editor, step dialog, HUD, ESC menu integration
5. **Integration Layer** - AD/CP API wrappers, course loader, vehicle loader

### Data Structure

**Workflow definition** (immutable template, stored in XML):
```lua
Workflow = {
    id = "workflow_001",
    name = "Harvest wheat - fields 1-2",
    -- currentStep and status are NOT stored here; they are per-vehicle runtime state
    linkedWorkflowId = nil,   -- ID of the linked partner workflow (nil if unlinked)
    linkRole = nil,           -- "main" or "support" (nil if unlinked)
    steps = {
        {
            type = "autodrive",  -- "autodrive" or "courseplay"
            target = "Route_Field1",  -- AutoDrive destination or Courseplay course
            action = "drive",  -- AutoDrive: drive, pickup_deliver, deliver, load, unload
            unloadTarget = "Silo",  -- Second destination for pickup_deliver mode (optional)
            fillType = "WHEAT",  -- Fill type for cargo filtering (optional)
            syncGroup = 1        -- Integer for sync coordination (nil if not linked)
        },
        {
            type = "courseplay",
            target = "Field1_Harvest",
            action = "fieldwork",  -- Courseplay: fieldwork, bale_collect
            syncGroup = 1
        }
    },
    createdAt = "2026-02-28 10:00:00"
}
```

**Runtime state** (per-vehicle, stored on `vehicle.spec_workflowManagerSpec.wmExecution`):
```lua
activeData = {
    workflow = <workflow reference>,  -- pointer to immutable template
    vehicle = <vehicle reference>,
    status = "ready",  -- "ready", "running", "paused", "completed"
    currentStep = 1,
    waitingForCompletion = false,
    autoResumeUntil = nil,       -- timestamp: auto-resume window after game load
    syncOverridden = false,      -- true when user manually switched steps on support workflow
    pausedTrackingState = nil,   -- saved AD/CP state flags when pausing mid-step
    -- plus internal tracking flags (justStoppedAD, pendingADStart, pendingCPStart, etc.)
}
```

`WMExecutor.activeVehicles` is a lightweight `{[vehicle] = true}` set used for update-loop iteration.

#### AutoDrive Actions/Modes

| Action           | Mode                      | Targets | Description                                |
| ---------------- | ------------------------- | ------- | ------------------------------------------ |
| `drive`          | MODE_DRIVETO (1)          | 1       | Simple point-to-point navigation           |
| `unload`         | MODE_UNLOAD (5)           | 2       | Unload combine                             |
| `pickup_deliver` | MODE_PICKUPANDDELIVER (2) | 2       | Load at target, deliver to unloadTarget    |
| `deliver`        | MODE_DELIVERTO (3)        | 1       | Start at target, deliver to unloadTarget   |
| `load`           | MODE_LOAD (4)             | 2       | Load at target, return to unloadTarget     |

#### Courseplay Actions

| Action         | Description                                         |
| -------------- | --------------------------------------------------- |
| `fieldwork`    | Field work (harvesting, cultivating, seeding, etc.) |
| `bale_collect` | Load/wrap bales                                     |

### XML Structure (Savegame)

Workflow **definitions** (with linked workflow support):
```xml
<?xml version="1.0" encoding="utf-8"?>
<WorkflowManager>
    <workflows>
        <workflow id="wf_001" name="Combine Harvest" linkedWorkflowId="wf_002" linkRole="main">
            <step type="autodrive" target="Route_Field1" action="drive" syncGroup="1"/>
            <step type="courseplay" target="Field1_Harvest" action="fieldwork" syncGroup="1"/>
            <step type="autodrive" target="Route_Field2" action="drive" syncGroup="2"/>
            <step type="courseplay" target="Field2_Harvest" action="fieldwork" syncGroup="2"/>
        </workflow>
        <workflow id="wf_002" name="Unloader Support" linkedWorkflowId="wf_001" linkRole="support">
            <step type="autodrive" target="Field1" action="unload" unloadTarget="Silo" syncGroup="1"/>
            <step type="autodrive" target="Field2" action="unload" unloadTarget="Silo" syncGroup="2"/>
        </workflow>
    </workflows>
</WorkflowManager>
```

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

* **Milestone 1**: Project Setup - ModDesc.xml, Lua structure, API analysis
* **Milestone 2**: Core Functionality - WorkflowManager, XML storage, Executor, AD/CP integration
* **Milestone 3**: Basic GUI - Main window, workflow editor, step management
* **Milestone 4**: Vehicle Selection - Runtime vehicle detection (uses current vehicle when starting)
* **Milestone 5**: Player UI - In-vehicle HUD with workflow controls (pause/resume, stop, prev/next steps)
* **Milestone 6**: Logo & Icons - Mod icon (modIcon.png) and HUD button icons with hover effects
* **Milestone 7**: Search - Searchable dropdowns in step dialog for AD targets and CP courses
* Multi-field workflows (more than 2 fields per workflow)
* Vehicle hint removed from GUI
* Delete confirmation, delete shortcut, scrollbar, step editor descriptions fixed
* Fill type dropdown shows localized names (title) instead of internal IDs
* **Per-vehicle runtime state** - Workflow definitions are immutable; `currentStep`/`status` live on the vehicle spec (`wmExecution`). `WMExecutor.activeVehicles` replaces `activeWorkflows`
* **Vehicle savegame persistence** - Active workflow and current step are saved/restored via `WorkflowManagerSpec.saveToXMLFile` / `onPostLoad`; restored as paused so player can resume
* **Auto-resume after load** - 10-second window (`autoResumeUntil`) for AD/CP to re-initialize before WM resumes the workflow automatically
* **Courseplay resume at nearest waypoint** - `CPIntegration:startFieldWork()` accepts `startAtNearest` flag; uses `cpStartStopDriver` to resume at the closest waypoint
* **Main dialog simplification** - Removed Status column; list shows only Name + Steps; removed Resume/reset flow (Start always starts fresh on current vehicle)
* **HUD icon scaling fix** - `getNormalizedScreenValues(24, 24)` now correctly captures both X and Y return values so icons render as squares on all aspect ratios
* **Draggable HUD** - HUD panel can be repositioned by dragging the header; position clamped to screen bounds
* **Linked workflow pairs** - Link two workflows as main/support for coordinated multi-vehicle operations (e.g., Combine + Unloader). Full sync group system, auto-group assignment, pause/resume/stop propagation, late-start sync, support auto-looping, and HUD status line for linked partner
* **Linked workflow GUI** - Link/Unlink buttons in main dialog; sync group column + Auto Groups button in editor; sync group field in step dialog (visible only when linked)

### Milestone 8: GUI Refinement
* [ ] F1 ingame help menu overlays the GUI
* [ ] Relocate double-click-to-edit hint to the bottom
* [ ] Editor dialog X button to close in top right corner
* [ ] Fix Warning (performance): Texture .../textures/white.png raw format

### Milestone 9: Folder View
* [ ] Show folders in dropdowns (collapsed by default)
* [ ] For AD Targets and CP Courses
* [ ] Collapse all / Expand all buttons

### Milestone 10: Polish
* [ ] Error handling improvements
* [ ] Performance optimization

### Milestone 11: Phase 2 Features
* [ ] Queue system for multiple vehicles
* [ ] Advanced conditions
* [ ] Add further CP settings for multiple vehicle courses

## API Integration

### AutoDrive

Key functions from `ExternalInterface.lua`, `Specialization.lua` and `GraphManager.lua`:

* **Start route**: `AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)`
* **Stop route**: `vehicle:stopAutoDrive()` - proper stop with braking, cruise control off, module resets
* **Pause route**: `AutoDrive:HoldDriving(vehicle)`
* **Get destinations**: `AutoDrive:GetAvailableDestinations()` - returns `{markerID = {name, x, y, z, id}}`
* **Check active**: `vehicle.ad.stateModule:isActive()`
* **Mode constants**: `MODE_DRIVETO=1`, `MODE_PICKUPANDDELIVER=2`, `MODE_DELIVERTO=3`, etc.

**AD -> CP Handoff**:
* `vehicle.ad.stateModule:setStartHelper(true)` - tells AD to start helper on completion
* Pre-load CP course before starting AD, AD handles the switch automatically

**Destination Groups/Folders**:
* `ADGraphManager:getMapMarkers()` - returns all markers with group info
* Markers in "All" group shown without prefix, others as `"Group/Name"`

### Courseplay

Key functions from `CpAIWorker.lua` and `CpAIFieldWorker.lua`:

* **Check available**: `g_Courseplay ~= nil`
* **Start field work**: `vehicle:startCpAtLastWp()` or `vehicle:startCpAtFirstWp()`
* **Resume at nearest wp**: `vehicle:cpStartStopDriver(false)` (used when restoring from save)
* **Stop**: `vehicle:stopCurrentAIJob(AIMessageSuccessStoppedByUser.new())`
* **Check active**: `vehicle:getIsCpActive()`
* **Has course**: `vehicle:hasCpCourse()`
* **Load course**: `vehicle:appendLoadedCpCourse(entity)`

**Important**: Access globals via `FS25_AutoDrive.AutoDrive` and `FS25_Courseplay.g_Courseplay`

Full API documentation: `docs/API_Analysis.md`

## File Structure

```
FS25_WorkflowManager/
├── modDesc.xml
├── modIcon.png                        # Mod icon (256x256)
├── CLAUDE.md
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
│   ├── white.png                      # 1x1 white pixel for GUI backgrounds
│   ├── icon_prev.png                  # HUD button: Previous step (<<)
│   ├── icon_pause.png                 # HUD button: Pause (||)
│   ├── icon_play.png                  # HUD button: Resume (>)
│   ├── icon_stop.png                  # HUD button: Stop ([])
│   └── icon_next.png                  # HUD button: Next step (>>)
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
    ├── WMMainDialog.xml               # Main dialog layout (2 columns: name + steps)
    ├── WMEditorDialog.xml             # Editor dialog layout
    ├── WMStepDialog.xml               # Step dialog layout
    ├── TextInputDialog.xml            # Text input dialog layout
    ├── WorkflowManagerGUI.xml         # Main GUI layout
    ├── WorkflowEditorGUI.xml          # Editor GUI layout
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
- Workflow definitions only contain `id`, `name`, `steps`, `createdAt`, `linkedWorkflowId`, `linkRole` — never `status` or `currentStep`

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
- HUD calls `WMExecutor:goToPreviousStep(vehicle)` / `goToNextStep(vehicle)` (vehicle reference, not workflow)

### Courseplay Resume
- Normal start: `vehicle:startCpAtLastWp()` or `vehicle:startCpAtFirstWp()`
- Resume from save: `vehicle:cpStartStopDriver(false)` to start at nearest waypoint
- Controlled via `startAtNearest` parameter in `CPIntegration:startFieldWork()`

### Linked Workflow Pairs
- Two workflows can be linked as `main` (drives sync) and `support` (follows main)
- Methods: `WorkflowManager:linkWorkflows(mainId, supportId)`, `unlinkWorkflow(id)`, `getLinkedWorkflow(workflow)`, `autoAssignSyncGroups(workflowId)`
- When the main workflow is paused/resumed/stopped, the linked support workflow is automatically propagated
- When the main workflow completes, the support is stopped
- Late start: if support starts after main is already running, it syncs to main's current sync group

### Sync Groups (Linked Workflows)
- Each step has an optional `syncGroup` integer; steps with the same group across linked workflows are coordinated
- The support workflow loops its current step while the main remains in the same sync group
- When the main advances to a new sync group, `WMExecutor:onSyncGroupTransition()` stops the support's current step and jumps it to the matching group
- **Auto Groups**: `autoAssignSyncGroups()` increments group after each CP step for main; assigns sequential groups for support
- `syncOverridden = true` on `activeData` when user manually switches steps on a support workflow; cleared on next main group transition

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
- 32x32 PNG icons with white shapes on transparent background
- Color-tinted at runtime: normal (white), hover (cyan), disabled (gray), active (green)
- Hover tracking for visual feedback on mouse-over

## Resources

* FS25 Modding Documentation: https://gdn.giants-software.com/
* AutoDrive source: `FS25_AutoDrive`
* Courseplay source: `FS25_Courseplay`
* FS25 Forum: https://forum.giants-software.com/

---

**Status**: Phase 1 COMPLETE - Linked workflows implemented; working on GUI refinement (Milestone 8)
**Last updated**: 2026-03-07
## Screenshots Needed

Screenshots for the Docusaurus documentation site (`website/static/img/screenshots/`). Take these in-game and save them at the listed paths:

| File | Where to take it | Used in |
|------|-----------------|---------|
| `esc-menu.png` | In-game ESC pause menu showing **Workflow Manager** as a clickable menu entry | `website/docs/installation.md` — Verifying Installation step |

---

**Status**: Phase 1 COMPLETE - Working on GUI refinement (Milestone 8)
**Last updated**: 2026-02-28
