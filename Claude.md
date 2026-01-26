# LS25 Workflow Manager – Development Documentation

## Project Overview

A mod for Farming Simulator 25 that combines AutoDrive and Courseplay to create automated workflows. The mod allows multiple fields to be processed sequentially by using AutoDrive for transport between fields and Courseplay for the actual field work.

## Project Goals

### Phase 1: Core Functionality (MVP) - COMPLETE

* Linking AutoDrive routes with Courseplay courses
* Simple workflow: Field 1 → Field 2
* GUI for workflow creation (tabular view)
* Storage of workflows in XML (per savegame)
* Automatic switching between AutoDrive and Courseplay

### Phase 2: Advanced Features

* Queue system for multiple vehicles
* Support for more than 2 fields per workflow (DONE)
* Advanced workflow options (conditions, pauses, etc.)
* Master-detail UI for more complex workflows

## Technical Stack

* **Language**: Lua (LS25-compatible)
* **Integration**: AutoDrive API, Courseplay API
* **UI Framework**: LS25 GUI system
* **Data Storage**: XML (in the savegame folder)
* **Mod Structure**: Standard LS25 ModDesc.xml

## Architecture Concept

### Main Components

1. **WorkflowManager** (Core) - Manages all workflows, loads/saves from XML, coordinates execution
2. **WorkflowExecutor** - Executes workflows, switches between AD/CP, monitors progress
3. **WorkflowGUI** - Tabular view for workflow management
4. **IntegrationLayer** - AD/CP API wrappers with event handling

### Data Structure

```lua
Workflow = {
    id = "workflow_001",
    name = "Harvest wheat – fields 1–2",
    -- Vehicle detected at runtime via g_currentMission.controlledVehicle
    steps = {
        {
            type = "autodrive",  -- "autodrive" or "courseplay"
            target = "Route_Field1",  -- AutoDrive destination or Courseplay course
            action = "drive",  -- AutoDrive: drive, pickup_deliver, deliver, load, unload
            unloadTarget = "Silo",  -- Second destination for pickup_deliver mode (optional)
            fillType = "WHEAT"  -- Fill type for cargo filtering (optional)
        },
        {
            type = "courseplay",
            target = "Field1_Harvest",
            action = "fieldwork"  -- Courseplay: fieldwork, bale_collect
        }
    },
    currentStep = 1,
    status = "ready"  -- "ready", "running", "paused", "completed"
}
```

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

```xml
<?xml version="1.0" encoding="utf-8"?>
<WorkflowManager>
    <workflows>
        <workflow id="workflow_001" name="Harvest wheat – fields 1–2" currentStep="1" status="ready">
            <step type="autodrive" target="Route_Field1" action="drive"/>
            <step type="courseplay" target="Field1_Harvest" action="fieldwork"/>
            <step type="autodrive" target="Farm/Silo" action="pickup_deliver" unloadTarget="Sell/BGA" fillType="WHEAT"/>
        </workflow>
    </workflows>
</WorkflowManager>
```

## Development Roadmap

### Completed Milestones

* **Milestone 1**: Project Setup - ModDesc.xml, Lua structure, API analysis
* **Milestone 2**: Core Functionality - WorkflowManager, XML storage, Executor, AD/CP integration
* **Milestone 3**: Basic GUI - Main window, workflow editor, step management
* **Milestone 4**: Vehicle Selection - Runtime vehicle detection (uses current vehicle when starting)

### Milestone 5: Player UI
* [ ] Create an ui for the payer in the Vehicle like Courseplay has it
* [ ] Function Pause (Workflow)
* [ ] Function Resume (Workflow)
* [ ] Function Stop (Workflow)
* [ ] Function Previous (Workflow step)
* [ ] Function Next (Workflow step)

### Milestone 6: Logo
* [ ] Create a nice logo
* [ ] Convert to proper format

### Milestone 7: Refinement
* [ ] The ingame help menu F1 overlays the gui
* [ ] Edit workflow name is possible in edit workflow gui without opening a separate overlay
* [ ] Relocate double click to edit hint in edit workflow gui to the bottom
* [ ] Edit workflow gui has an X to close in the top right corner which works
* [ ] Do not show vehicle hint in gui
* [x] Edit step GUI looks different from the others (Header) - DONE: Consistent 900px dialog width
* [ ] Fix Warning (performance): Texture .../textures/white.png raw format

### Milestone 9: Folder view
* [ ] Show folders in dropdowns (collapsed by default)
* [ ] For AD Targets and CP Courses
* [ ] Collapse all / Expand all buttons

### Milestone 10: Search
* [x] Search in dropdowns (typing while open) - DONE: Filter input fields in WMStepDialog
* [x] Dropdown content shrinks according to input - DONE: Lists filter based on search text

### Milestone 11: Refinement
* [ ] Implement error handling
* [ ] Performance optimization
* [ ] Documentation

### Milestone 12: Phase 2 Features
* [ ] Queue system
* [ ] Advanced conditions
* [ ] Improve master-detail UI

## API Integration

### AutoDrive

Key functions from `ExternalInterface.lua` and `GraphManager.lua`:

* **Start route**: `AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)`
* **Pause route**: `AutoDrive:HoldDriving(vehicle)`
* **Get destinations**: `AutoDrive:GetAvailableDestinations()` - returns `{markerID = {name, x, y, z, id}}`
* **Check active**: `vehicle.ad.stateModule:isActive()`
* **Mode constants**: `MODE_DRIVETO=1`, `MODE_PICKUPANDDELIVER=2`, `MODE_DELIVERTO=3`, etc.

**AD → CP Handoff**:
* `vehicle.ad.stateModule:setStartHelper(true)` - tells AD to start helper on completion
* Pre-load CP course before starting AD, AD handles the switch automatically

**Destination Groups/Folders**:
* `ADGraphManager:getMapMarkers()` - returns all markers with group info
* Markers in "All" group shown without prefix, others as `"Group/Name"`

### Courseplay

Key functions from `CpAIWorker.lua` and `CpAIFieldWorker.lua`:

* **Check available**: `g_Courseplay ~= nil`
* **Start field work**: `vehicle:startCpAtLastWp()` or `vehicle:startCpAtFirstWp()`
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
├── modIcon.dds                      # TODO: Create icon
├── CLAUDE.md
├── .vscode/                         # VS Code workspace config
├── src/
│   ├── DevConfig.lua                # Development configuration
│   ├── WorkflowManager.lua          # Main class & entry point
│   ├── WorkflowManagerSpec.lua      # Vehicle specialization (for in-vehicle input)
│   ├── WorkflowExecutor.lua         # Execution engine
│   ├── WorkflowStorage.lua          # XML read/write
│   ├── gui/
│   │   ├── WMMainDialog.lua         # Main dialog (workflow list)
│   │   ├── WMEditorDialog.lua       # Workflow editor dialog
│   │   ├── WMStepDialog.lua         # Step add/edit dialog with searchable lists
│   │   └── WorkflowManagerMenuFrame.lua # ESC menu integration
│   ├── integration/
│   │   ├── AutoDriveIntegration.lua # AD API wrapper
│   │   ├── CourseplayIntegration.lua # CP API wrapper
│   │   ├── CourseplayCoursesLoader.lua # CP saved courses loader
│   │   └── CourseplayVehiclesLoader.lua # Vehicle loader (AD+CP filter)
│   └── utils/
│       ├── Logger.lua               # Logging utility
│       ├── EventHandler.lua         # Event system
│       └── DebugUtil.lua            # Debug utilities
├── translations/
│   ├── translation_en.xml
│   └── translation_de.xml
├── textures/
│   └── white.png                    # 1x1 white pixel for GUI backgrounds
├── docs/
│   └── API_Analysis.md              # AD/CP API documentation
└── xml/gui/
    ├── guiProfiles.xml              # Custom GUI profiles
    ├── WMMainDialog.xml             # Main dialog layout
    ├── WMEditorDialog.xml           # Editor dialog layout
    ├── WMStepDialog.xml             # Step dialog layout
    └── WorkflowManagerMenuFrame.xml # ESC menu integration
```

## Key Implementation Notes

### Vehicle Detection
- Vehicles are NOT stored with workflows
- When starting a workflow, uses `g_currentMission.controlledVehicle`
- Vehicle must have both AutoDrive AND Courseplay support
- Validation via `WorkflowManager.isVehicleValid()`

### CP↔AD Cyclic Handoff
- When CP finishes and starts AD internally (e.g., for unloading), executor waits for AD
- When AD finishes and restarts CP, executor continues monitoring CP
- Step only completes when BOTH CP and AD are not running

### GUI Input
- Works both when walking and in a vehicle
- Uses vehicle specialization (`WorkflowManagerSpec`) for in-vehicle input
- Uses `PlayerInputComponent.registerGlobalPlayerActionEvents` for global input

### Data Caching
- AD destinations and CP courses loaded once when GUI opens
- Cache cleared on GUI close to avoid conflicts with CP internal state

## Resources

* LS25 Modding Documentation: https://gdn.giants-software.com/
* AutoDrive source: `FS25_AutoDrive`
* Courseplay source: `FS25_Courseplay`
* LS25 Forum: https://forum.giants-software.com/

---

**Status**: Phase 1 COMPLETE – Ready for Phase 2
**Last updated**: 2026-01-25
