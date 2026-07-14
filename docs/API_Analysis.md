# AutoDrive & Courseplay API Analysis

**Date:** 2026-01-13
**Analyzed versions:** FS25_AutoDrive, FS25_Courseplay

---

## AutoDrive API (ExternalInterface.lua)

### Availability Check
```lua
-- Check if AutoDrive is available
AutoDrive ~= nil

-- Check if vehicle has AD spec
vehicle.ad ~= nil
```

### Core API Functions

#### Get Available Destinations
```lua
-- Returns table: {markerID = {name, x, y, z, id}, ...}
AutoDrive:GetAvailableDestinations()

-- Alternative: Direct access to map markers
ADGraphManager:getMapMarkers()
ADGraphManager:getMapMarkerById(markerID)
```

#### Start Driving
```lua
-- Main function to start AutoDrive
-- Parameters:
--   vehicle: Vehicle object
--   destinationID: Target marker ID
--   unloadDestinationID: Secondary destination (-1 = none, -2 = refuel, -3 = park)
--   callBackObject: Object to call when complete
--   callBackFunction: Function to call when complete
--   callBackArg: Argument passed to callback
AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)

-- With pathfinder (handles special modes)
AutoDrive:StartDrivingWithPathFinder(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
```

#### Pause/Hold Driving
```lua
-- Pause current route
AutoDrive:HoldDriving(vehicle)

-- Internal pause control
vehicle.ad.drivePathModule:setPaused()
vehicle.ad.drivePathModule:setUnPaused()
vehicle.ad.drivePathModule:isPaused()
```

#### Stop/Status
```lua
-- Check if active
vehicle.ad.stateModule:isActive()

-- Get current mode
vehicle.ad.stateModule:getMode()

-- Stop current mode
vehicle.ad.stateModule:getCurrentMode():stop()
```

#### Destination Listener (Completion Notification)
```lua
-- Register to be notified when ANY AD route completes
AutoDrive:registerDestinationListener(callBackObject, callBackFunction)
AutoDrive:unRegisterDestinationListener(callBackObject)
AutoDrive:notifyDestinationListeners()

-- Callback signature:
function callBackFunction(callBackObject, success)
```

#### Mode Constants
```lua
AutoDrive.MODE_DRIVETO = 1           -- Simple drive to destination
AutoDrive.MODE_PICKUPANDDELIVER = 2  -- Load at first, unload at second
AutoDrive.MODE_DELIVERTO = 3         -- Deliver load to destination
AutoDrive.MODE_LOAD = 4              -- Load mode
AutoDrive.MODE_UNLOAD = 5            -- Unload mode
AutoDrive.MODE_BGA = 6               -- BGA mode
```

#### Utility Functions
```lua
AutoDrive:GetDriverName(vehicle)
AutoDrive:GetParkDestination(vehicle)
AutoDrive:GetPath(startX, startZ, startYRot, destinationID, options)
AutoDrive:GetPathVia(startX, startZ, startYRot, viaID, destinationID, options)
AutoDrive:GetClosestPointToLocation(x, z, minDistance)
```

### Courseplay Integration (via AD)
```lua
-- AD can control CP
AutoDrive:StartCP(vehicle)           -- Start CP at last waypoint
AutoDrive:RestartCP(vehicle)         -- Restart CP
AutoDrive:StopCP(vehicle)            -- Stop CP if active
AutoDrive:getIsCPActive(vehicle)     -- Check if CP is running
AutoDrive:getIsCPWaitingForUnload(vehicle)
AutoDrive:getIsCPTurning(vehicle)
AutoDrive:getIsCPCombineInPocket(vehicle)
AutoDrive:holdCPCombine(vehicle)
```

---

## Courseplay API

### Availability Check
```lua
-- Global CP object
g_Courseplay ~= nil
-- OR check for specialization
vehicle.spec_cpAIWorker ~= nil
```

### Core API Functions (via CpAIWorker)

#### Start/Stop Driver
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

#### Field Work Specific (CpAIFieldWorker)
```lua
-- Start at first waypoint
vehicle:startCpAtFirstWp()

-- Start at last waypoint (used by AutoDrive)
vehicle:startCpAtLastWp()

-- Check status
vehicle:getIsCpFieldWorkActive()
vehicle:getCpFieldWorkProgress()

-- Harvester specific
vehicle:getIsCpHarvesterWaitingForUnload()
vehicle:getIsCpHarvesterWaitingForUnloadInPocket()
vehicle:getIsCpHarvesterWaitingForUnloadAfterPulledBack()
vehicle:getIsCpHarvesterManeuvering()
vehicle:holdCpHarvesterTemporarily(periodMs)
```

#### Course Management (CpCourseManager)
```lua
-- Set/Get courses
vehicle:setFieldWorkCourse(course)
vehicle:getFieldWorkCourse()
vehicle:getCpCourses()
vehicle:hasCpCourse()
vehicle:resetCpCourses()
vehicle:resetCpCoursesFromGui()

-- Course names
vehicle:getCurrentCpCourseName()
vehicle:setCpCourseName(name)

-- Load from file
vehicle:appendLoadedCpCourse(file)
vehicle:saveCpCourses(file, text)

-- Copy course from another vehicle
vehicle:cpCopyCourse(course)
```

#### Hold/Freeze
```lua
-- Freeze driver (debug)
vehicle:freezeCp()
vehicle:unfreezeCp()

-- Temporary hold
vehicle:cpHold(ms, fuelSaveAllowed)

-- Brake to stop
vehicle:cpBrakeToStop()
```

### CP Events (for external listeners)
```lua
-- Register event listeners on vehicle
"onCpFinished"       -- Job completed
"onCpEmpty"          -- Implement empty
"onCpFull"           -- Implement full
"onCpFuelEmpty"      -- Need refuel
"onCpBroken"         -- Need repair
"onCpCourseChange"   -- Course changed
"onCpFieldworkWaypointChanged"  -- Progress update
```

### Course Storage
Courses are stored in: `[UserProfile]/modSettings/FS25_Courseplay/Courses/[MapId]/`

---

## Integration Strategy for WorkflowManager

### Starting AutoDrive Route
```lua
function startADRoute(vehicle, targetName, onComplete)
    local destinations = AutoDrive:GetAvailableDestinations()
    local targetId = findDestinationByName(destinations, targetName)

    if targetId then
        AutoDrive:StartDriving(
            vehicle,
            targetId,
            -1,  -- no second destination
            self,  -- callback object
            onComplete,  -- callback function
            vehicle  -- callback arg
        )
        return true
    end
    return false
end
```

### Starting Courseplay Field Work
```lua
function startCPFieldWork(vehicle)
    if vehicle:hasCpCourse() and vehicle:getCanStartCpFieldWork() then
        vehicle:startCpAtLastWp()  -- or startCpAtFirstWp()
        return true
    end
    return false
end
```

### Detecting Completion

#### AutoDrive Completion
1. **Callback method**: Pass callback to `StartDriving()` - **confirmed non-functional** in the
   currently installed AD version: `vehicle.ad.callBackFunction` is assigned inside
   `StartDriving` but never invoked anywhere else in the AD source. Do not rely on it.
2. **Listener method**: Register via `registerDestinationListener()` - **not vehicle-completion
   related**: `notifyDestinationListeners()` is only called when the AD road network (routes/
   markers) changes (route upload, graph edits), never when a vehicle finishes driving.
3. **Polling method**: Check `vehicle.ad.stateModule:isActive()` - the only method that actually
   works; this is what WM uses (`ADIntegration:isRouteComplete`/`isRefuelRepairComplete`).

#### Courseplay Completion
1. **Event method**: Listen for `onCpFinished` event
2. **Polling method**: Check `vehicle:getIsCpActive()`

### Recommended Workflow Execution Pattern
```lua
-- 1. Check both mods available
local adAvailable = AutoDrive ~= nil
local cpAvailable = g_Courseplay ~= nil

-- 2. For AutoDrive step
AutoDrive:StartDriving(vehicle, destId, -1, self, onADComplete, vehicle)

-- 3. On AD complete callback, start CP
function onADComplete(vehicle)
    if vehicle:hasCpCourse() then
        vehicle:startCpAtLastWp()
    end
end

-- 4. Monitor CP via update loop or event
function onUpdate()
    if wasRunningCP and not vehicle:getIsCpActive() then
        -- CP finished, proceed to next step
        executeNextStep()
    end
end
```

---

## Important Notes

1. **Server-side**: Most control functions should be called on the server (`self.isServer`)
2. **Callbacks**: AD callbacks are reliable; CP uses event system
3. **Course requirement**: CP requires a course to be loaded before starting
4. **Vehicle state**: Check vehicle is not already running AD/CP before starting
5. **AD restartCP flag**: AD uses `vehicle.ad.restartCP` to indicate CP should continue after AD finishes
