---
id: courseplay
title: Courseplay API
sidebar_position: 2
---

# Courseplay API Reference

This page documents the Courseplay API functions used by Workflow Manager.

## Availability Check

```lua
-- Global CP object
local cpAvailable = g_Courseplay ~= nil

-- Check for specialization on vehicle
local hasCP = vehicle.spec_cpAIWorker ~= nil
```

## Core Functions (CpAIWorker)

### Start and Stop

```lua
-- Toggle start/stop (main function)
vehicle:cpStartStopDriver(isStartedByHud)

-- Stop explicitly
vehicle:stopCurrentAIJob(AIMessageSuccessStoppedByUser.new())

-- Check if CP is active
vehicle:getIsCpActive()

-- Check if can start CP
vehicle:getCanStartCp()
```

### Field Work (CpAIFieldWorker)

```lua
-- Start at first waypoint
vehicle:startCpAtFirstWp()

-- Start at last waypoint (used by AutoDrive)
vehicle:startCpAtLastWp()

-- Check field work status
vehicle:getIsCpFieldWorkActive()
vehicle:getCpFieldWorkProgress()
```

### Harvester Functions

```lua
-- Harvester status checks
vehicle:getIsCpHarvesterWaitingForUnload()
vehicle:getIsCpHarvesterWaitingForUnloadInPocket()
vehicle:getIsCpHarvesterWaitingForUnloadAfterPulledBack()
vehicle:getIsCpHarvesterManeuvering()

-- Temporarily hold harvester
vehicle:holdCpHarvesterTemporarily(periodMs)
```

## Course Management (CpCourseManager)

### Set and Get Courses

```lua
-- Set field work course
vehicle:setFieldWorkCourse(course)

-- Get current course
vehicle:getFieldWorkCourse()

-- Get all courses on vehicle
vehicle:getCpCourses()

-- Check if vehicle has a course
vehicle:hasCpCourse()
```

### Reset Courses

```lua
-- Reset all courses
vehicle:resetCpCourses()

-- Reset from GUI
vehicle:resetCpCoursesFromGui()
```

### Course Names

```lua
-- Get current course name
vehicle:getCurrentCpCourseName()

-- Set course name
vehicle:setCpCourseName(name)
```

### Load and Save

```lua
-- Load course from file/entity
vehicle:appendLoadedCpCourse(file)

-- Save courses
vehicle:saveCpCourses(file, text)

-- Copy course from another vehicle
vehicle:cpCopyCourse(course)
```

## Hold and Freeze

```lua
-- Freeze driver (debug)
vehicle:freezeCp()
vehicle:unfreezeCp()

-- Temporary hold
vehicle:cpHold(ms, fuelSaveAllowed)

-- Brake to stop
vehicle:cpBrakeToStop()
```

## Events

Courseplay fires events for external listeners:

| Event | Description |
|-------|-------------|
| `onCpFinished` | Job completed |
| `onCpEmpty` | Implement empty |
| `onCpFull` | Implement full |
| `onCpFuelEmpty` | Need refuel |
| `onCpBroken` | Need repair |
| `onCpCourseChange` | Course changed |
| `onCpFieldworkWaypointChanged` | Progress update |

### Listening for Events

```lua
-- Register event listener
SpecializationUtil.registerEventListener(
    vehicle,
    "onCpFinished",
    self
)

-- Handler function
function MyClass:onCpFinished(vehicle)
    -- Handle completion
end
```

## Course Storage

Courses are saved in the modSettings folder:

```
[UserProfile]/modSettings/FS25_Courseplay/Courses/[MapId]/
```

Structure:
```
Courses/
└── MapName/
    ├── Course1.xml
    ├── Course2.xml
    └── Folder/
        └── Course3.xml
```

## Example: Starting Field Work

```lua
function startCPFieldWork(vehicle)
    -- Check prerequisites
    if not vehicle:hasCpCourse() then
        print("No course loaded")
        return false
    end

    if not vehicle:getCanStartCpFieldWork() then
        print("Cannot start field work")
        return false
    end

    -- Start at last waypoint
    vehicle:startCpAtLastWp()
    return true
end
```

## Example: Monitoring Completion

### Polling Method

```lua
local wasRunningCP = false

function onUpdate(dt)
    local isActive = vehicle:getIsCpActive()

    if wasRunningCP and not isActive then
        -- CP just finished
        onCPComplete()
    end

    wasRunningCP = isActive
end
```

### Event Method

```lua
function setupEventListener(vehicle)
    SpecializationUtil.registerEventListener(
        vehicle,
        "onCpFinished",
        self
    )
end

function MyClass:onCpFinished(vehicle)
    -- Courseplay finished
    executeNextStep()
end
```

## Global Access

Access Courseplay globals through the mod namespace:

```lua
-- Correct way to access
local Courseplay = FS25_Courseplay.g_Courseplay

-- Check if available
if FS25_Courseplay and FS25_Courseplay.g_Courseplay then
    -- Courseplay is available
end
```

## Important Notes

1. **Course requirement**: CP requires a course to be loaded before starting
2. **Vehicle state**: Check vehicle is not already running AD/CP before starting
3. **Events**: Use event system for reliable completion notification
4. **Server-side**: Control functions should be called on the server
5. **Specializations**: Check for `spec_cpAIWorker` and `spec_cpCourseManager`
