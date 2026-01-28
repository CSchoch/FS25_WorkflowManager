# Queue System Concept - FS25 Workflow Manager

**Status**: Design concept (Phase 2 feature)
**Date**: 2026-01-28

---

## Current State

- One workflow runs on one vehicle at a time
- Vehicle detected at runtime via `g_currentMission.controlledVehicle`
- HUD shows single active workflow
- Workflows stored as templates in XML (no execution state persisted)

---

## Queue System Options

### Option A: Multi-Vehicle Parallel Execution

Run the **same workflow on multiple vehicles simultaneously**:

```
Workflow "Harvest Fields 1-3"
├── Harvester 1: Step 2/6 - Harvesting Field 1 [RUNNING]
├── Harvester 2: Step 4/6 - Driving to Field 2 [RUNNING]
└── Harvester 3: Step 1/6 - Queued, waiting [PENDING]
```

**Use case**: Multiple harvesters working the same route of fields

**Features**:
- Assign vehicles to a workflow (either pre-assigned or at start)
- Each vehicle gets its own "instance" with independent progress
- HUD shows list of active vehicles/workflows
- Vehicles can start at different steps (staggered)

---

### Option B: Vehicle Work Queue

Assign **multiple workflows to a single vehicle** to run sequentially:

```
Harvester 1 Queue:
├── [1] Harvest wheat - Fields 1-2 [RUNNING]
├── [2] Harvest barley - Fields 3-4 [QUEUED]
└── [3] Transport to BGA [QUEUED]
```

**Use case**: Set up a full day's work for a vehicle

**Features**:
- When one workflow completes, next starts automatically
- Vehicle keeps working through the night
- Reorder/add/remove from queue while running
- Per-vehicle queue management UI

---

### Option C: Global Job Queue (Combined)

A dispatch system showing all vehicles and their assignments:

```
┌─────────────────────────────────────────────────────┐
│ WORKFLOW QUEUE                                      │
├─────────────────────────────────────────────────────┤
│ Harvester 1    │ Harvest wheat 1-2    │ Step 3/6  │
│ Harvester 2    │ Harvest wheat 1-2    │ Step 1/6  │
│ Transport 1    │ Grain shuttle        │ Running   │
│ Seeder 1       │ (idle)               │ -         │
├─────────────────────────────────────────────────────┤
│ [+ Assign Workflow]  [Pause All]  [Stop All]       │
└─────────────────────────────────────────────────────┘
```

**Use case**: Fleet management overview

**Features**:
- Combined view of all vehicles and their current work
- Quick assignment from this screen
- Batch controls (pause all, stop all)
- See idle vehicles that could be assigned

---

## Architectural Changes Required

### 1. Workflow Instances (Critical)

Separate workflow **template** from workflow **instance**:

```lua
-- Template (stored in XML, reusable)
Workflow = {
    id = "wf_001",
    name = "Harvest wheat",
    steps = {...}
}

-- Instance (runtime, per-vehicle execution)
WorkflowInstance = {
    instanceId = "inst_001",
    workflowId = "wf_001",      -- Reference to template
    vehicle = vehicle,          -- Assigned vehicle
    currentStep = 3,
    status = "running",
    startTime = timestamp
}
```

**Current**: `activeWorkflows[workflowId]` (one execution per template)
**Needed**: `activeWorkflows[instanceId]` (multiple executions per template)

### 2. Vehicle Pre-Assignment

**Current**: Vehicle detected at start via `g_currentMission.controlledVehicle`
**Needed**:
- Option to pre-assign vehicle when creating instance
- Vehicle selector dialog when starting workflow
- Support for assigning to non-controlled vehicles

### 3. Multi-Vehicle HUD

**Current**: Shows first active workflow only
**Needed**:
- List view of active workflows with vehicle names
- Or: per-vehicle HUD that shows that vehicle's workflow
- Filter/switch between vehicles
- Vehicle context in all event routing

### 4. Event System Enhancement

**Current**: Events have workflow context only
**Needed**: Events include `{workflowId, instanceId, vehicle}`

```lua
EVENT_WORKFLOW_STARTED = {
    workflowId = "wf_001",
    instanceId = "inst_001",
    vehicle = vehicle
}
```

### 5. Instance Lifecycle Management

```
Created → Queued → Running → Completed
                      ↓
                   Paused
```

- Track instance state separately from template status
- Allow pausing individual instances
- Clean up completed instances
- Optional: persist queue state across save/load

---

## File Impact Assessment

### Major Changes Required

| File | Changes |
|------|---------|
| `WMExecutor.lua` | Instance ID keying, multi-vehicle polling |
| `WMHud.lua` | Per-vehicle display or queue view |
| `WMMainDialog.lua` | Show instances, vehicle assignment |
| `EventHandler.lua` | Add vehicle context to events |
| `WorkflowManager.lua` | Instance creation/management |

### Minimal Changes

| File | Notes |
|------|-------|
| `WorkflowStorage.lua` | Templates unchanged (instances are runtime-only) |
| `AutoDriveIntegration.lua` | Already vehicle-aware |
| `CourseplayIntegration.lua` | Already vehicle-aware |

---

## Recommended Implementation Order

1. **Phase 1**: Workflow Instances
   - Refactor activeWorkflows to use instanceId
   - Create WorkflowInstance class
   - Single vehicle still, but architecture ready

2. **Phase 2**: Vehicle Selection
   - Vehicle selector when starting workflow
   - Support non-controlled vehicles

3. **Phase 3**: Multi-Instance Support
   - Same workflow on multiple vehicles
   - HUD shows list of active instances

4. **Phase 4**: Queue View UI
   - Global dispatch screen
   - Batch controls

5. **Phase 5**: Per-Vehicle Queue (Option B)
   - Sequential workflow queue per vehicle
   - Auto-start next workflow

---

## Open Questions

1. **Persistence**: Should queue state survive save/load?
2. **Priority**: Can higher-priority workflows preempt?
3. **Conflicts**: What if two workflows need same vehicle?
4. **Errors**: How to handle errors in multi-vehicle scenario?
5. **UI Location**: New ESC menu tab or extend existing dialogs?

---

*This document captures design concepts for future implementation.*
