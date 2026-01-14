# LS25 Workflow Manager – Development Documentation

## Project Overview

A mod for Farming Simulator 25 that combines AutoDrive and Courseplay to create automated workflows. The mod allows multiple fields to be processed sequentially by using AutoDrive for transport between fields and Courseplay for the actual field work.

## Project Goals

### Phase 1: Core Functionality (MVP)

* Linking AutoDrive routes with Courseplay courses
* Simple workflow: Field 1 → Field 2
* GUI for workflow creation (tabular view)
* Storage of workflows in XML (per savegame)
* Automatic switching between AutoDrive and Courseplay

### Phase 2: Advanced Features

* Queue system for multiple vehicles
* Support for more than 2 fields per workflow
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

1. **WorkflowManager** (Core)

   * Manages all workflows
   * Loads/saves workflows from/to XML
   * Coordinates execution

2. **WorkflowExecutor**

   * Executes individual workflows
   * Switches between AutoDrive and Courseplay
   * Monitors progress

3. **WorkflowGUI**

   * Tabular view of workflow steps
   * Create/edit/delete workflows
   * Assign vehicles to workflows

4. **IntegrationLayer**

   * AutoDrive integration (start/stop routes)
   * Courseplay integration (start/stop courses)
   * Event handling between the mods

### Data Structure

```lua
Workflow = {
    id = "workflow_001",
    name = "Harvest wheat – fields 1–2",
    vehicle = vehicleId,
    steps = {
        {
            type = "autodrive",  -- "autodrive" or "courseplay"
            target = "Route_Field1",  -- AutoDrive route or Courseplay course
            action = "drive"
        },
        {
            type = "courseplay",
            target = "Field1_Harvest",
            action = "harvest"
        },
        {
            type = "autodrive",
            target = "Route_Field2",
            action = "drive"
        },
        {
            type = "courseplay",
            target = "Field2_Harvest",
            action = "harvest"
        }
    },
    currentStep = 1,
    status = "ready"  -- "ready", "running", "paused", "completed"
}
```

### XML Structure (Savegame)

```xml
<?xml version="1.0" encoding="utf-8"?>
<WorkflowManager>
    <workflows>
        <workflow id="workflow_001" name="Harvest wheat – fields 1–2" vehicle="vehicle_123" currentStep="1" status="ready">
            <step type="autodrive" target="Route_Field1" action="drive"/>
            <step type="courseplay" target="Field1_Harvest" action="harvest"/>
            <step type="autodrive" target="Route_Field2" action="drive"/>
            <step type="courseplay" target="Field2_Harvest" action="harvest"/>
        </workflow>
    </workflows>
</WorkflowManager>
```

## GUI Concept

### Main Tabular View

```
┌─────────────────────────────────────────────────────────────────┐
│ Workflow Manager                                         [X]     │
├─────────────────────────────────────────────────────────────────┤
│ [New] [Edit] [Delete] [Start] [Stop]                            │
├─────────────────────────────────────────────────────────────────┤
│ Workflow Name          │ Vehicle       │ Steps │ Status          │
├────────────────────────┼───────────────┼───────┼─────────────────┤
│ Harvest wheat 1–2      │ Combine       │ 4     │ Ready           │
│ Harvest corn 3–5       │ Forage harv.  │ 6     │ Running (2/6)   │
│ Spread slurry          │ Tractor 1     │ 8     │ Paused          │
└─────────────────────────────────────────────────────────────────┘
```

### Workflow Editor (Detail View)

```
┌─────────────────────────────────────────────────────────────────┐
│ Edit workflow: Harvest wheat 1–2                          [X]    │
├─────────────────────────────────────────────────────────────────┤
│ Name: [Harvest wheat 1–2____________________________]           │
│ Vehicle: [Combine XL ▼]                                         │
├─────────────────────────────────────────────────────────────────┤
│ Steps:                      [▲] [▼] [+] [-]                     │
├─────────────────────────────────────────────────────────────────┤
│ # │ Type       │ Target                │ Action                 │
├───┼────────────┼───────────────────────┼────────────────────────┤
│ 1 │ AutoDrive  │ Route_Field1          │ Drive                  │
│ 2 │ Courseplay │ Field1_Harvest        │ Harvest                │
│ 3 │ AutoDrive  │ Route_Field2          │ Drive                  │
│ 4 │ Courseplay │ Field2_Harvest        │ Harvest                │
├─────────────────────────────────────────────────────────────────┤
│                              [Save] [Cancel]                    │
└─────────────────────────────────────────────────────────────────┘
```

## Development Roadmap

### Milestone 1: Project Setup

* [x] Create ModDesc.xml
* [x] Set up basic Lua file structure
* [x] Set up development environment
* [x] Analyze AutoDrive & Courseplay APIs

### Milestone 2: Core Functionality

* [x] Implement WorkflowManager
* [x] Implement XML read/write
* [x] Implement basic WorkflowExecutor
* [x] Integrate AutoDrive (start/stop)
* [x] Integrate Courseplay (start/stop)

### Milestone 3: Basic GUI

* [x] Main window with workflow list
* [x] Workflow editor (detail view)
* [x] Add/remove steps
* [x] Start/stop workflows

### Milestone 4: Testing & Refinement

* [ ] In-game testing (Field 1 → Field 2)
* [ ] Implement error handling
* [ ] Performance optimization
* [ ] Documentation

### Milestone 5: Phase 2 Features

* [ ] Queue system
* [ ] Support for 3+ fields
* [ ] Advanced conditions
* [ ] Improve master-detail UI

## API Integration

### AutoDrive (Analyzed)

Key functions from `ExternalInterface.lua`:

* **Start route**: `AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)`
* **Pause route**: `AutoDrive:HoldDriving(vehicle)`
* **Get destinations**: `AutoDrive:GetAvailableDestinations()` - returns `{markerID = {name, x, y, z, id}}`
* **Check active**: `vehicle.ad.stateModule:isActive()`
* **Completion callback**: Pass callback to `StartDriving()` or use `registerDestinationListener()`
* **Mode constants**: `MODE_DRIVETO=1`, `MODE_PICKUPANDDELIVER=2`, `MODE_DELIVERTO=3`, etc.

### Courseplay (Analyzed)

Key functions from `CpAIWorker.lua` and `CpAIFieldWorker.lua`:

* **Check available**: `g_Courseplay ~= nil`
* **Start field work**: `vehicle:startCpAtLastWp()` or `vehicle:startCpAtFirstWp()`
* **Toggle start/stop**: `vehicle:cpStartStopDriver(isStartedByHud)`
* **Stop**: `vehicle:stopCurrentAIJob(AIMessageSuccessStoppedByUser.new())`
* **Check active**: `vehicle:getIsCpActive()`
* **Check field work**: `vehicle:getIsCpFieldWorkActive()`
* **Has course**: `vehicle:hasCpCourse()`
* **Completion**: Listen for `onCpFinished` event or poll `getIsCpActive()`
* **Harvester status**: `getIsCpHarvesterWaitingForUnload()`, `getIsCpHarvesterManeuvering()`

Full API documentation: `docs/API_Analysis.md`

## File Structure

```
FS25_WorkflowManager/
├── modDesc.xml                      # ✓ Created
├── modIcon.dds                      # TODO: Create icon
├── README.md
├── CLAUDE.md                        # ✓ This documentation file
├── .vscode/                         # ✓ VS Code workspace config
│   ├── settings.json                # ✓ Lua globals, file associations
│   ├── launch.json                  # ✓ Debug info
│   └── tasks.json                   # ✓ Log viewing, XML validation
├── src/
│   ├── DevConfig.lua                # ✓ Development configuration
│   ├── WorkflowManager.lua          # ✓ Main class & entry point
│   ├── WorkflowExecutor.lua         # ✓ Execution engine
│   ├── WorkflowStorage.lua          # ✓ XML read/write
│   ├── gui/
│   │   ├── WorkflowManagerGUI.lua   # ✓ Main GUI (draw-based)
│   │   ├── WorkflowEditorGUI.lua    # ✓ Editor GUI (draw-based)
│   │   ├── WorkflowManagerMenuFrame.lua # ✓ ESC menu integration
│   │   └── elements/                # UI components (future)
│   ├── integration/
│   │   ├── AutoDriveIntegration.lua # ✓ AD API wrapper (with retry logic)
│   │   └── CourseplayIntegration.lua # ✓ CP API wrapper (with retry logic)
│   └── utils/
│       ├── Logger.lua               # ✓ Logging utility (dev mode aware)
│       ├── EventHandler.lua         # ✓ Event system
│       └── DebugUtil.lua            # ✓ Debug utilities & overlay
├── translations/
│   ├── translation_en.xml           # ✓ English translations
│   └── translation_de.xml           # ✓ German translations
├── textures/
│   └── white.png                    # ✓ 1x1 white pixel for GUI backgrounds
├── testdata/
│   └── sample_workflows.xml         # ✓ Test workflow examples
├── docs/
│   └── API_Analysis.md              # ✓ AD/CP API documentation
└── xml/
    └── gui/
        ├── WorkflowManagerGUI.xml   # ✓ Main GUI layout
        ├── WorkflowEditorGUI.xml    # ✓ Editor GUI layout
        └── WorkflowManagerMenuFrame.xml # ✓ ESC menu frame layout
```

## Development Notes

### Key Considerations

1. **Event synchronization**: How do we reliably detect when AutoDrive/Courseplay has finished?
2. **Error handling**: What happens if a step fails?
3. **Vehicle state**: How do we ensure the vehicle is in the correct state?
4. **Savegame compatibility**: Workflows must be correctly restored when loading a savegame

### Next Steps

1. ~~Create ModDesc.xml template~~ ✓
2. ~~Implement basic WorkflowManager class~~ ✓
3. ~~Create simple GUI for workflow list~~ ✓
4. ~~Analyze AutoDrive and Courseplay scripts for actual API calls~~ ✓
5. Create modIcon.dds (64x64 icon)
6. ~~Create XML GUI layouts for proper FS25 GUI integration~~ ✓
7. Test in-game loading and basic functionality
8. ~~Refine integration with actual AD/CP API methods~~ ✓
9. In-game testing with Field 1 → Field 2 workflow
10. Implement error handling and edge cases

## Resources

* LS25 Modding Documentation: [https://gdn.giants-software.com/](https://gdn.giants-software.com/)
* AutoDrive GitHub: [[https://github.com/Stephan-S/FS25_AutoDrive](https://github.com/Stephan-S/FS25_AutoDrive)]
* Courseplay GitHub: [https://github.com/Courseplay/Courseplay_FS25](https://github.com/Courseplay/Courseplay_FS25)
* LS25 Forum: [https://forum.giants-software.com/](https://forum.giants-software.com/)

## Contact & Collaboration

This project is being developed in collaboration with Claude Code.
All AutoDrive and Courseplay scripts will be provided for analysis.

---

**Status**: Phase 1 – Milestone 4 IN PROGRESS (Testing & Debugging)
**Last updated**: 2026-01-14

## Implementation Progress

### Completed
- modDesc.xml with FS25 descVersion 105
- Full Lua file structure with 13 core modules
- Translation files (EN/DE)
- Input action bindings (Alt+W, F9, Ctrl+Alt+W, Shift+Alt+W)
- Development environment:
  - VS Code workspace configuration (settings, tasks, launch)
  - DevConfig.lua for debug/release mode switching
  - DebugUtil.lua with FPS counter, state logging, debug overlay
  - Enhanced Logger with API call and state change tracking
  - Sample test workflows XML for development testing
- **API Analysis Complete (2026-01-13)**:
  - AutoDrive ExternalInterface.lua fully analyzed
  - Courseplay CpAIWorker, CpAIFieldWorker, CpCourseManager analyzed
  - Integration code updated with correct API calls
  - Full documentation in docs/API_Analysis.md
- **Milestone 2: Core Functionality (2026-01-13)**:
  - WorkflowManager: Create, delete, assign vehicles, start/stop/pause/resume
  - WorkflowStorage: XML save/load with savegame integration, import/export
  - WorkflowExecutor: Step execution state machine, AD/CP completion detection
  - AutoDrive Integration: StartDriving with callback, HoldDriving, route management
  - Courseplay Integration: startCpAtLastWp/FirstWp, freeze/unfreeze, status polling
  - EventHandler: Event subscription system for workflow state changes

- **Milestone 3: Basic GUI (2026-01-13)**:
  - WorkflowManagerGUI: Main window with workflow list, toolbar buttons, keyboard navigation
  - WorkflowEditorGUI: Workflow editor with name/vehicle editing, step management
  - XML GUI layouts created (WorkflowManagerGUI.xml, WorkflowEditorGUI.xml)
  - Translation files updated with all GUI text keys (EN/DE)
  - Input handling: keyboard shortcuts (N=New, S=Start, P=Pause, X=Stop, ESC=Close)
  - Step management: Add/Remove steps, Move up/down, Visual step list
  - Vehicle assignment with cycling through available vehicles

- **Milestone 4 Progress (2026-01-13 to 2026-01-14)**:
  - **Mouse Click Handling**: Added full mouse event handling to draw-based GUIs
    - Mouse position tracking (mouseX, mouseY)
    - Button area registration and hit detection
    - Click handlers for all toolbar and editor buttons
  - **ESC Menu Integration**: Added TabbedMenuFrameElement for InGameMenu
    - WorkflowManagerMenuFrame.lua: Page class for ESC menu
    - WorkflowManagerMenuFrame.xml: XML layout for menu frame
    - Automatic page registration to g_inGameMenu after map load
  - **Global Input Action Fix**: Changed to PlayerInputComponent hook pattern
    - Hooks PlayerInputComponent.registerGlobalPlayerActionEvents (like Courseplay)
    - This is the proper way to register inputs for non-vehicle mods in FS25
    - Manual F9 key detection fallback in update loop for debugging
  - **AD/CP Detection Improvements**:
    - Added retry logic (10 attempts, 1 second intervals)
    - Added g_modManager:getModByName() check
    - Added g_currentMission attachment check
    - Enhanced logging for first 3 attempts
  - **Translation Fixes**: Added missing input_ prefixed keys for German
  - **GUI Overlay Fix (2026-01-14)**: Fixed "glass background with random icons" issue
    - Root cause: `createImageOverlay(g_baseUIFilename)` rendered entire UI texture atlas
    - Solution: Created `textures/white.png` (1x1 white pixel) for solid color rendering
    - Updated WorkflowManagerGUI.lua and WorkflowEditorGUI.lua to load mod-local texture
    - Changed background rendering to fully opaque (alpha=1.0) with two-pass rendering
    - First pass: solid dark color (0.05, 0.05, 0.08), second pass: slight depth overlay
  - **ModIcon Fix (2026-01-14)**: Commented out iconFilename in modDesc.xml
    - Prevents "Missing dds file" errors in ESC menu
    - Game uses default icon until custom modIcon.dds is created

### In Progress
- Milestone 4: Testing & Refinement
  - Debugging AD/CP global detection (mods load but globals not found)
  - Debugging input action callback not firing
  - Testing ESC menu integration

### Known Issues Being Debugged
1. **AD/CP Globals Not Found**: AutoDrive and Courseplay mods are loaded but their globals (AutoDrive, g_Courseplay, etc.) are not detected after 10 retry attempts. Need to verify correct global names in FS25.
2. **Input Action Callback**: WM_TOGGLE_GUI action registers successfully but callback never fires. Added PlayerInputComponent hook and manual F9 detection as workarounds.

### Fixed Issues
1. **~~Glass Background with Random Icons~~** (Fixed 2026-01-14): GUI overlay was rendering entire UI texture atlas. Fixed by creating `textures/white.png` (1x1 white pixel) and using fully opaque two-pass rendering.
2. **~~Missing modIcon.dds Errors~~** (Fixed 2026-01-14): Commented out iconFilename reference in modDesc.xml.

### Pending
- modIcon.dds creation
- In-game testing with actual AutoDrive and Courseplay
- Performance optimization
- Error handling improvements

## Debugging Guide

### Log Messages to Watch For
```
[WorkflowManager] Menu frame loaded successfully
[WorkflowManager] Adding Workflow Manager page to InGameMenu
[WorkflowManager] Hooked PlayerInputComponent.registerGlobalPlayerActionEvents
[WorkflowManager] Registered global input action WM_TOGGLE_GUI
[WorkflowManager] Created overlay from mod texture: .../textures/white.png (ID: ...)
[WorkflowManager] AutoDrive check #1: AutoDrive=... modLoaded=...
[WorkflowManager] Courseplay check #1: g_Courseplay=... modLoaded=...
[WorkflowManager] F9 key detected via manual check!
[WorkflowManager] onToggleGUI called!
```

### Testing Checklist
- [ ] Full game restart (not just map reload)
- [ ] Check log for menu frame loading
- [ ] Press ESC and look for Workflow Manager tab (no more modIcon.dds errors)
- [ ] Press Alt+W or F9 to toggle GUI
- [x] Verify GUI has solid dark background (not glass with random icons) ✓ Fixed
- [ ] Check if AD/CP detection shows "modLoaded=true"
- [ ] Verify button clicks work in draw-based GUI
