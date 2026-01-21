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
            target = "Route_Field1",  -- AutoDrive destination or Courseplay course
            action = "drive",  -- AutoDrive: drive, pickup_deliver, deliver, load, unload
            -- AutoDrive-specific parameters (optional):
            unloadTarget = "Silo",  -- Second destination for pickup_deliver mode
            fillType = "WHEAT"  -- Fill type for cargo filtering
        },
        {
            type = "courseplay",
            target = "Field1_Harvest",
            action = "fieldwork"  -- Courseplay: fieldwork, bale_collect
        },
        {
            type = "autodrive",
            target = "Farm/Silo",  -- Destination with group prefix
            action = "pickup_deliver",  -- Load at target, deliver to unloadTarget
            unloadTarget = "Sell/BGA",
            fillType = "SILAGE"
        },
        {
            type = "courseplay",
            target = "Field2_Harvest",
            action = "fieldwork"
        }
    },
    currentStep = 1,
    status = "ready"  -- "ready", "running", "paused", "completed"
}
```

#### AutoDrive Actions/Modes

| Action           | Mode                      | Targets | Description                                                   | First Target Label | Second Target Label | Fruit Selection |
| ---------------- | ------------------------- | ------- | ------------------------------------------------------------- | ------------------ | ------------------- | --------------- |
| `drive`          | MODE_DRIVETO (1)          | 1       | Simple point-to-point navigation                              | Target             | –                   | NO              |
| `unload`         | MODE_UNLOAD (5)           | 2       | Unload combine                                                | Unload             | Target              | NO              |
| `pickup_deliver` | MODE_PICKUPANDDELIVER (2) | 2       | Load at target (Pickup), deliver to unloadTarget (Deliver To) | Pickup             | Deliver To          | YES             |
| `deliver`        | MODE_DELIVERTO (3)        | 1       | Start at target, deliver to unloadTarget (Deliver To)         | Target             | –                   | NO              |
| `load`           | MODE_LOAD (4)             | 2       | Load at target (Load At), return to unloadTarget (Return To)  | Return To          | Load At             | YES             |

#### Courseplay Actions (FS25)

| Action         | Description                                         |
| -------------- | --------------------------------------------------- |
| `fieldwork`    | Field work (harvesting, cultivating, seeding, etc.) |
| `bale_collect` | Load/wrap bales                                     |

### XML Structure (Savegame)

```xml
<?xml version="1.0" encoding="utf-8"?>
<WorkflowManager>
    <workflows>
        <workflow id="workflow_001" name="Harvest wheat – fields 1–2" vehicle="vehicle_123" currentStep="1" status="ready">
            <step type="autodrive" target="Route_Field1" action="drive"/>
            <step type="courseplay" target="Field1_Harvest" action="fieldwork"/>
            <step type="autodrive" target="Farm/Silo" action="pickup_deliver" unloadTarget="Sell/BGA" fillType="WHEAT"/>
            <step type="courseplay" target="Field2_Harvest" action="fieldwork"/>
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

### Workflow Editor (Detail View) - Button-Based

```
┌──────────────────────────────────────────────────────────────────────┐
│ Edit Workflow                                                   [X]  │
├──────────────────────────────────────────────────────────────────────┤
│ Name:    [Harvest wheat 1–2________________________]                 │
│                                                                      │
│ Vehicle: [<] [      Combine XL      ] [>]  (1/5)                    │
│                                                                      │
│ Steps:   [+ Add] [- Remove] [Up] [Down]                             │
├──────────────────────────────────────────────────────────────────────┤
│ #  │ Type       │ Target              │ Action                       │
├────┼────────────┼─────────────────────┼──────────────────────────────┤
│ 1  │ AutoDrive  │ Route_Field1        │ drive                        │
│ 2  │ Courseplay │ Field1_Course       │ harvest                      │
│ 3  │ AutoDrive  │ Route_Field2        │ drive                        │
│ 4  │ Courseplay │ Field2_Course       │ harvest     ← selected       │
├──────────────────────────────────────────────────────────────────────┤
│              [Save]                    [Cancel]                      │
└──────────────────────────────────────────────────────────────────────┘

Add Step Dialog:
┌────────────────────────────────────────┐
│ Add Step                               │
├────────────────────────────────────────┤
│ Type:   [AutoDrive] [Courseplay]       │
│                                        │
│ Target: [<] [Route_Field1    ] [>]     │
│                                        │
│ Action: [<] [drive           ] [>]     │
├────────────────────────────────────────┤
│       [Add]          [Cancel]          │
└────────────────────────────────────────┘
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

### Milestone 4: Testing & Refinement ✓

* [x] In-game testing (Field 1 → Field 2)
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

Key functions from `ExternalInterface.lua` and `GraphManager.lua`:

* **Start route**: `AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)`
* **Pause route**: `AutoDrive:HoldDriving(vehicle)`
* **Get destinations**: `AutoDrive:GetAvailableDestinations()` - returns `{markerID = {name, x, y, z, id}}`
* **Check active**: `vehicle.ad.stateModule:isActive()`
* **Completion callback**: Pass callback to `StartDriving()` or use `registerDestinationListener()`
* **Mode constants**: `MODE_DRIVETO=1`, `MODE_PICKUPANDDELIVER=2`, `MODE_DELIVERTO=3`, etc.

**AutoDrive → Courseplay Handoff** (from `StateModule.lua` and `ExternalInterface.lua`):
* **Enable helper**: `vehicle.ad.stateModule:setStartHelper(true)` - tells AD to start helper on completion
* **Check helper type**: `vehicle.ad.stateModule:getUsedHelper()` - returns `ADStateModule.HELPER_CP` (1) if CP available
* **Helper constant**: `ADStateModule.HELPER_CP = 1` - Courseplay helper type
* **Start CP**: `AutoDrive:StartCP(vehicle)` - starts Courseplay from last waypoint
* **Restart CP**: `AutoDrive:RestartCP(vehicle)` - continues/restarts Courseplay course
* **Workflow Manager uses**: Pre-loads CP course, calls `setStartHelper(true)`, AD handles the switch automatically

**Destination Groups/Folders** (from `GraphManager.lua`):
* **Marker structure**: Each marker has `{id, markerIndex, name, group}` - `group` defaults to `"All"`
* **Get all groups**: `ADGraphManager:getGroups()` - returns `{groupName = groupID, ...}`
* **Get markers in group**: `ADGraphManager:getMapMarkersInGroup(groupName)` - returns markers in specific group
* **Get all markers**: `ADGraphManager:getMapMarkers()` - returns all markers with group info
* **Get waypoint**: `ADGraphManager:getWayPointById(markerID)` - returns `{x, y, z}` coordinates

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
│   │   ├── AutoDriveIntegration.lua # ✓ AD API wrapper (with retry logic, group/folder support)
│   │   ├── CourseplayIntegration.lua # ✓ CP API wrapper (with retry logic)
│   │   ├── CourseplayCoursesLoader.lua # ✓ CP saved courses loader (folder support)
│   │   └── CourseplayVehiclesLoader.lua # ✓ Vehicle loader (AD+CP filter)
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

1. Create modIcon.dds (64x64 icon)
2. Test in-game loading and basic functionality
3. In-game testing with Field 1 → Field 2 workflow
4. Implement error handling and edge cases

## Resources

* LS25 Modding Documentation: [https://gdn.giants-software.com/](https://gdn.giants-software.com/)
* AutoDrive source: `c:\Users\Chef\Documents\My Games\FarmingSimulator2025\mods\FS25_AutoDrive`
* Courseplay source: `c:\Users\Chef\Documents\My Games\FarmingSimulator2025\mods\FS25_Courseplay`
* Better Contracts source [FS25_BetterContracts](FS25_BetterContracts)
* LS25 Forum: [https://forum.giants-software.com/](https://forum.giants-software.com/)

## Contact & Collaboration

This project is being developed in collaboration with Claude Code.
All AutoDrive and Courseplay scripts will be provided for analysis.

---

**Status**: Phase 1 COMPLETE – Ready for Phase 2
**Last updated**: 2026-01-21

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
  - WorkflowManagerGUI: Main window with workflow list, toolbar buttons
  - WorkflowEditorGUI: Fully button-based workflow editor (rewritten 2026-01-15)
  - XML GUI layouts created (WorkflowManagerGUI.xml, WorkflowEditorGUI.xml)
  - Translation files updated with all GUI text keys (EN/DE)
  - All interactions are mouse-based (no keyboard shortcuts required)
  - Step management: Add/Remove steps, Move up/down via buttons
  - Vehicle assignment with < > navigation buttons

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
  - **GUI Overlay Fix (2026-01-14)**: Fixed "glass background with random icons" issue for main GUI
    - Root cause: `createImageOverlay(g_baseUIFilename)` rendered entire UI texture atlas
    - Solution: Created `textures/white.png` (1x1 white pixel) for solid color rendering
    - Changed background rendering to fully opaque (alpha=1.0) with two-pass rendering
    - First pass: solid dark color (0.05, 0.05, 0.08), second pass: slight depth overlay
    - Added `setOverlayUVs()` reset to ensure full texture is used (0,0 to 1,1)
  - **GUI Flow Update (2026-01-14)**: Main GUI now hides when editor opens
    - Main GUI sets `isVisible = false` before opening editor
    - Editor shows main GUI again when closing
    - Each GUI now creates and manages its own overlay independently
  - **ModIcon Fix (2026-01-14)**: Commented out iconFilename in modDesc.xml
    - Prevents "Missing dds file" errors in ESC menu
    - Game uses default icon until custom modIcon.dds is created
  - **Editor GUI Rewrite (2026-01-15)**: Complete rewrite with button-based interface
    - Removed all keyboard shortcuts - fully mouse-driven
    - Vehicle selection: < and > buttons to cycle through available vehicles
    - Step toolbar: "+ Add", "- Remove", "Up", "Down" labeled buttons
    - Add Step Dialog: Type selection (AutoDrive/Courseplay buttons), Target/Action with < > navigation
    - Button hover effects with brightness increase and border highlight
    - Layout constants for consistent positioning
    - Close button (X) in title bar
  - **Folder/Group Support for Targets (2026-01-16)**:
    - AutoDrive destinations now show with group prefix (e.g., `"Farm/Silo"`, `"Fields/Field1"`)
    - Uses `ADGraphManager:getMapMarkers()` to get markers with group info
    - Destinations in "All" group shown without prefix
    - Courseplay courses already supported folders via `CourseplayCoursesLoader`
    - All targets sorted alphabetically by display name
  - **AutoDrive Advanced Modes Support (2026-01-17)**:
    - Implemented all AutoDrive modes: drive, pickup_deliver, deliver, load, unload
    - Added `unloadTarget` parameter for pickup_deliver mode (two-destination workflows)
    - Added `fillType` parameter for cargo type filtering
    - Updated step data structure with optional AD-specific fields
    - Updated WorkflowStorage to save/load new parameters in XML
    - Updated AutoDriveIntegration:startRoute() to accept mode, unloadTarget, fillType
    - Added action-to-mode mapping (drive→DRIVETO, pickup_deliver→PICKUPANDDELIVER, etc.)
    - Updated WorkflowExecutor to pass all parameters to AD integration
    - Extended Add Step Dialog with new fields:
      - Mode selector with display names (Drive To, Pickup & Deliver, etc.)
      - Unload Target selector (shown only for pickup_deliver mode)
      - Fill Type selector with all game fill types from g_fillTypeManager
    - Added translations for all new UI elements (EN/DE)
    - Dialog dynamically shows/hides fields based on selected mode
  - **AutoDrive → Courseplay Handoff (2026-01-18)**:
    - When AD step is followed by CP step, AD now automatically starts CP on completion
    - Uses AutoDrive's `stateModule:setStartHelper(true)` API for seamless handoff
    - Pre-loads the CP course onto the vehicle before AD starts
    - WorkflowExecutor detects AD→CP sequence and configures handoff
    - Skips manual CP start when AD handles it, just monitors CP completion
    - Added wait timeout (5 seconds) for CP to start after AD handoff
    - Benefits: Smoother transitions, leverages AD's native CP integration
  - **Data Caching Optimization (2026-01-18)**:
    - AD destinations and CP courses now loaded once when GUI opens (not every draw/click)
    - Added `WMEditorGUI:loadDataCache()` method to populate cache
    - Added `WMEditorGUI:clearDataCache()` method to clear on GUI close
    - Cache populated in `WMManagerGUI:show()` and cleared in `WMManagerGUI:hide()`
    - `getAvailableTargets()` and `getAvailableFillTypes()` now use cached data
    - Benefits: Improved performance, reduced API calls during GUI interaction
  - **Auto-Save on Game Save (2026-01-19)**:
    - Workflows now automatically saved when player saves the game
    - Hooks `FSBaseMission.saveSavegame` via `Utils.appendedFunction`
    - Also saves on: editor Save button, workflow deletion, map unload
    - Log message: `[WorkflowManager] Game saving - persisting workflows`
  - **Double-Click to Edit (2026-01-21)**:
    - Double-clicking a workflow row in the main GUI opens the editor
    - Double-clicking a step row in the workflow editor opens the edit step dialog
    - Uses 400ms threshold for double-click detection
    - Tracks `lastClickTime` and `lastClickIndex`/`lastClickStepIndex` for same-row detection
    - UI hints updated to show "Double-click to edit" in both GUIs
    - Fixed broken `onEditClick` references to use `onClickEdit`
  - **Dropdown Selectors (2026-01-21)**:
    - Replaced all `< >` cycle buttons with proper dropdown menus
    - Converted fields: Vehicle, Action/Mode, Target, Unload Target, Fill Type
    - Features:
      - Click to open dropdown, click item to select
      - Scroll wheel support for long lists (>8 items)
      - Hover highlighting on items
      - Selected item shown with green highlight
      - Dropdown arrow indicator (▼ closed, ▲ open)
      - Auto-close when clicking outside dropdown
      - Maximum 8 visible items with scroll indicators
    - Added `drawDropdownField()` and `drawDropdownList()` methods
    - Added `handleDropdownClick()` for click handling
    - Added `onScrollEvent()` for scroll wheel support
    - Benefits: Much faster selection for lists with many items
  - **Row Separators for Lists (2026-01-21)**:
    - Added visual row separation to workflow list, step list, and dropdown items
    - Features:
      - Alternating row backgrounds (darker/lighter) for better readability
      - Subtle separator lines at the bottom of each row
      - Consistent styling across all list types
    - Updated `drawWorkflowRow()` in WorkflowManagerGUI
    - Updated `drawStepRow()` in WorkflowEditorGUI
    - Updated `drawDropdownList()` for dropdown items

### In Progress
- Milestone 5: Phase 2 Features (not yet started)

### Fixed Issues
1. **~~Glass Background with Random Icons~~** (Fixed 2026-01-14): Main GUI overlay was rendering entire UI texture atlas. Fixed by creating `textures/white.png` (1x1 white pixel) and using fully opaque two-pass rendering.
2. **~~Missing modIcon.dds Errors~~** (Fixed 2026-01-14): Commented out iconFilename reference in modDesc.xml.
3. **~~Editor GUI Glass Background~~** (Fixed 2026-01-14): Editor overlay was glassy. Fixed by:
   - Editor creates its own independent overlay from `white.png`
   - Main GUI hides when editor opens (avoids overlay conflicts)
   - Added `setOverlayUVs()` reset before drawing (0,0 to 1,1)
   - Editor shows main GUI again when closing
4. **~~AD/CP Globals Not Found~~** (Fixed 2026-01-15): AutoDrive and Courseplay mods were loaded but globals not detected. Root cause: FS25 namespaces ALL mod globals under `FS25_<ModName>`. Direct access like `AutoDrive` or `g_Courseplay` does NOT work. Fix:
   - AutoDrive: Access via `FS25_AutoDrive.AutoDrive`
   - Courseplay: Access via `FS25_Courseplay.g_Courseplay`
   - This is the ONLY working method in FS25 - direct global access is not available cross-mod
5. **~~Input Action Callback Not Firing~~** (Fixed 2026-01-15): Alt+W hotkey now works correctly via PlayerInputComponent hook pattern
6. **~~Vehicle Loading Not Working~~** (Fixed 2026-01-16): Vehicles not detected from mission. Fixed by:
   - Added fallback check for `g_currentMission.vehicleSystem.vehicles`
   - Added multiple CP detection patterns (`spec_cpAIWorker`, `spec_cpAIFieldWorker`, etc.)
   - Filter now requires BOTH AD and CP support for workflow-compatible vehicles
   - Added detailed debug logging for vehicle scanning
7. **~~Syntax Error in CourseplayVehiclesLoader~~** (Fixed 2026-01-16): Line 149 used `:` instead of `.` when checking if function exists
8. **~~Courseplay Course Loading Failed~~** (Fixed 2026-01-17): Loading saved courses onto vehicles failed with "attempt to call a nil value" at FileSystem.lua:130. Root cause: We were calling `entity:load(vehicle)` directly, but `File:load()` is an internal API expecting `(xmlSchema, xmlBaseKey, lambda, class, ...)`. Fix:
   - Use the proper public API: `vehicle:appendLoadedCpCourse(entity)`
   - This is the same method used by Courseplay's CpCourseManagerFrame GUI
   - The vehicle method internally calls `file:load()` with correct parameters
9. **~~Courseplay Course Not Changing Between Consecutive CP Steps~~** (Fixed 2026-01-19): When two Courseplay steps ran in sequence, the second step would use the first step's course. Root cause: `executeCurrentStep` only loaded a course if `hasCourse()` returned false, not checking if the *correct* course was loaded. Fix:
   - Now compares `getCurrentCourseName()` with `step.target`
   - Loads new course if names differ or no course loaded
10. **~~Workflows Not Persisted to XML~~** (Fixed 2026-01-19): Changes to workflows (create, edit, delete) were only saved in memory until map unload. Fix:
    - Added `WorkflowManager:saveWorkflows()` call to editor's `saveAndClose()`
    - Added `WorkflowManager:saveWorkflows()` call to main GUI's `onClickDelete()`
    - Added `FSBaseMission.saveSavegame` hook for auto-save on game save
11. **~~Courseplay Error When Entering Shop~~** (Fixed 2026-01-20): Error `CpCourseManager.lua:257: invalid argument #1 to 'next' (table expected, got nil)` when entering the shop or other menus. Root cause: `CPCoursesLoader` and `CPVehiclesLoader` were continuously scanning in the background (every 2-5 seconds), interfering with Courseplay's internal state. Fix:
    - Added `guiIsOpen` flag to both loaders
    - `update()` now only scans when `guiIsOpen = true`
    - Removed `scanCourses()`/`scanVehicles()` from `init()` - no longer scans on map load
    - Removed `directoryView.refresh()` call that was modifying Courseplay's internal state
    - Added `setGuiOpen(isOpen)` function to control scanning
    - `WorkflowEditorGUI:openWorkflow()` sets `guiIsOpen = true`, `close()` sets it to `false`
    - Courses/vehicles now only scanned when Editor GUI is actually open
12. **~~Courses Not Displayed in Add Step Dialog~~** (Fixed 2026-01-20): Courses were loaded (39 found in log) but not shown in the target selection dropdown. Root cause: `loadDataCache()` function existed but was never called. Fix:
    - Added `self:loadDataCache()` call in `openWorkflow()` after `setGuiOpen(true)`
    - Cache now properly populated with AD destinations, CP courses, and fill types
13. **~~Courseplay Step Completes Prematurely When CP Hands Off to AD~~** (Fixed 2026-01-20): When Courseplay finishes fieldwork and internally starts AutoDrive (e.g., to unload at a silo), WorkflowManager detected "CP stopped" and marked the step as complete, even though the vehicle was still working via AD. The full cycle can be: CP → AD (unload) → CP (continue) → AD → ... Root cause: `WorkflowExecutor.update()` only checked `CPIntegration:isRunning()` to detect completion. Fix:
    - Now also checks `ADIntegration:isRunning()` when CP stops
    - If AD is running after CP stops, sets `activeData.cpHandedOffToAD = true`
    - When AD stops, checks if CP started again (AD may restart CP)
    - If CP restarted, continues monitoring CP (handles cyclic handoffs)
    - Only marks step complete when BOTH CP and AD are not running
    - Added logging for all handoff transitions
14. **~~Dropdown Text Rendering Over Dropdown List~~** (Fixed 2026-01-21): Text from UI elements below an open dropdown would render on top of the dropdown list. Root cause: In FS25's rendering system, all text (`renderText`) renders at a higher z-level than overlays, regardless of call order. Fix:
    - Added `isPositionCoveredByDropdown(y, h)` helper function to check if a Y position overlaps with an open dropdown's list area
    - Updated `drawStepRow()` to skip text rendering when covered by dropdown
    - Updated `drawButton()` to skip text when covered (with optional `skipDropdownCheck` param)
    - Updated `drawDropdownField()` to skip text when covered by a different dropdown
    - Updated column headers and labels in both main editor and step dialog to check coverage
    - Dropdown overlays still render normally, only text is conditionally skipped

### Pending
- modIcon.dds creation
- Full workflow execution testing (AD → CP → AD sequences)
- Performance optimization
- Error handling improvements

## Debugging Guide

### Log Messages to Watch For
```
[WorkflowManager] Hooked PlayerInputComponent.registerGlobalPlayerActionEvents
[WorkflowManager] Registered global input action WM_TOGGLE_GUI
[WorkflowManager] Created overlay from mod texture: .../textures/white.png (ID: ...)
[WorkflowManager] Editor created overlay from: .../textures/white.png (ID: ...)
[WorkflowManager] Editor failed to create overlay from: ...
[WorkflowManager] Editor recreated overlay (ID: ...)
[WorkflowManager] Editor overlay missing during draw
[WorkflowManager] AutoDrive check #1: AutoDrive=... modLoaded=...
[WorkflowManager] Courseplay check #1: g_Courseplay=... modLoaded=...
[WorkflowManager] F9 key detected via manual check!
[WorkflowManager] onToggleGUI called!
[WorkflowManager] New workflow button clicked
[WorkflowManager] Opened editor for workflow: ...
[WorkflowManager] Closed workflow editor
[WorkflowManager] Found X vehicles in mission, scanning...
[WorkflowManager] Vehicle 'Name': hasAD=true, hasCP=true, type=tractor
[WorkflowManager] Processed X vehicles, included Y with AD+CP
[WorkflowManager] Loaded X Courseplay-compatible vehicle(s)
[WorkflowManager] Hooked FSBaseMission.saveSavegame for auto-save
[WorkflowManager] Game saving - persisting workflows
[WorkflowManager] Loading course for step: X (current: Y)
[WorkflowManager] Loading data cache for AD destinations and CP courses...
[WorkflowManager] Data cache loaded: X AD destinations, Y CP courses, Z fill types
[WorkflowManager] Loaded X Courseplay course(s) from API
[WorkflowManager] [DEBUG] Courseplay stopped but AutoDrive is running - waiting for AD
[WorkflowManager] [DEBUG] AutoDrive completed and Courseplay restarted - continuing to monitor CP
[WorkflowManager] [DEBUG] AutoDrive completed after Courseplay handoff - CP step complete
[WorkflowManager] Double-click on workflow X - opening editor
[WorkflowManager] Double-click on step X - opening edit dialog
```

### Testing Checklist
- [x] Full game restart (not just map reload)
- [x] Press Alt+W or F9 to toggle GUI ✓ Alt+W confirmed working (2026-01-15)
- [x] Verify main GUI has solid dark background ✓ Fixed
- [x] Click "New" and verify editor has solid dark background ✓ Fixed
- [x] Check if AD/CP detection shows "modLoaded=true" ✓ Working (2026-01-16)
- [x] Test editor button clicks:
  - [x] "+ Add" opens add step dialog
  - [x] "- Remove" removes selected step
  - [x] "Up/Down" move selected step
  - [x] Click on step row to select it
  - [x] "Save" and "Cancel" buttons work
  - [x] "X" close button works
- [x] Test Add Step Dialog:
  - [x] AutoDrive/Courseplay type selection
  - [x] Add and Cancel buttons
- [x] Verify editor closes and returns to main GUI correctly
- [x] Test workflow creation and step management
- [x] Verify AD destinations show with group/folder prefix ✓ Working (2026-01-16)
- [x] Verify CP courses show with folder prefix ✓ Working (2026-01-16)
- [x] Verify targets are sorted alphabetically ✓ Working (2026-01-16)
- [x] Verify vehicle loading shows only AD+CP vehicles ✓ Working (2026-01-16)
- [x] Test AutoDrive Advanced Modes (2026-01-17):
  - [x] Mode selector cycles through: Drive To, Pickup & Deliver, Deliver, Load, Unload
  - [x] Unload Target field appears only when "Pickup & Deliver" is selected
  - [x] Fill Type field shows all available fill types from game
- [x] Test Workflow Persistence (2026-01-19):
  - [x] Create workflow, save game, reload - workflow should persist
  - [x] Delete workflow, save game, reload - workflow should be gone
  - [x] Two consecutive CP steps use correct courses for each step
- [x] Test On-Demand Scanning (2026-01-20):
  - [x] No Courseplay errors when entering shop ✓ Fixed
  - [x] Courses only loaded when Editor GUI opens
  - [x] Courses displayed in Add Step dialog when selecting Courseplay type
- [x] Test CP↔AD Cyclic Handoff (2026-01-20):
  - [x] When CP finishes fieldwork and starts AD (e.g., for unloading), workflow waits for AD
  - [x] When AD finishes and restarts CP, workflow continues monitoring CP
  - [x] Debug log shows handoff transitions (enable DEBUG in DevConfig)
  - [x] Step only completes when BOTH CP and AD are not running
- [x] Test Double-Click to Edit (2026-01-21):
  - [x] Double-click on workflow row opens editor
  - [x] Double-click on step row opens edit step dialog
  - [x] Single click only selects the row (both GUIs)
  - [x] Double-click on different rows doesn't trigger edit (must be same row)
- [x] Test Dropdown Selectors (2026-01-21):
  - [x] Vehicle dropdown opens and shows all available vehicles
  - [x] Click on vehicle in dropdown selects it
  - [x] Action/Mode dropdown shows all available modes (Drive To, Pickup & Deliver, etc.)
  - [x] Target dropdown shows all AD destinations or CP courses
  - [x] Unload Target dropdown appears only for relevant modes
  - [x] Fill Type dropdown appears only for pickup_deliver/load modes
  - [x] Scroll wheel works to scroll through long lists
  - [x] Clicking outside dropdown closes it
  - [x] Selected item shows with green highlight
- [x] Test Dropdown Text Occlusion (2026-01-21):
  - [x] When vehicle dropdown is open, step list text below it is hidden
  - [x] When action dropdown is open in step dialog, target label below is hidden
  - [x] When target dropdown is open, unload target dropdown field text is hidden
  - [x] Text reappears immediately when dropdown is closed
  - [x] Dropdown list items still show their text correctly
- [x] Test Row Separators (2026-01-21):
  - [x] Workflow list shows alternating row backgrounds
  - [x] Workflow list has separator lines between rows
  - [x] Step list shows alternating row backgrounds
  - [x] Step list has separator lines between rows
  - [x] Dropdown items show alternating backgrounds
  - [x] Dropdown items have separator lines between items
