---
id: autodrive
title: AutoDrive API
sidebar_position: 1
---

# AutoDrive API Reference

This page documents the AutoDrive API functions used by Workflow Manager.

## Availability Check

```lua
-- Check if AutoDrive is available
local adAvailable = AutoDrive ~= nil

-- Check if vehicle has AD spec
local hasAD = vehicle.ad ~= nil
```

## Core Functions

### Get Available Destinations

```lua
-- Returns table: {markerID = {name, x, y, z, id}, ...}
AutoDrive:GetAvailableDestinations()

-- Direct access to map markers
ADGraphManager:getMapMarkers()
ADGraphManager:getMapMarkerById(markerID)
```

### Start Driving

```lua
-- Main function to start AutoDrive
AutoDrive:StartDriving(
    vehicle,            -- Vehicle object
    destinationID,      -- Target marker ID
    unloadDestinationID, -- Secondary destination
    callBackObject,     -- Object to call when complete
    callBackFunction,   -- Function to call when complete
    callBackArg         -- Argument passed to callback
)

-- With pathfinder (handles special modes)
AutoDrive:StartDrivingWithPathFinder(
    vehicle,
    destinationID,
    unloadDestinationID,
    callBackObject,
    callBackFunction,
    callBackArg
)
```

#### Secondary Destination Values

| Value | Meaning |
|-------|---------|
| `-1` | No secondary destination |
| `-2` | Refuel |
| `-3` | Park |
| `> 0` | Marker ID for unload destination |

### Pause and Resume

```lua
-- Pause current route
AutoDrive:HoldDriving(vehicle)

-- Internal pause control
vehicle.ad.drivePathModule:setPaused()
vehicle.ad.drivePathModule:setUnPaused()
vehicle.ad.drivePathModule:isPaused()
```

### Stop and Status

```lua
-- Check if active
vehicle.ad.stateModule:isActive()

-- Get current mode
vehicle.ad.stateModule:getMode()

-- Stop current mode
vehicle.ad.stateModule:getCurrentMode():stop()
```

## Destination Listener

Register to be notified when ANY AutoDrive route completes:

```lua
-- Register listener
AutoDrive:registerDestinationListener(callBackObject, callBackFunction)

-- Unregister listener
AutoDrive:unRegisterDestinationListener(callBackObject)

-- Trigger notification (internal)
AutoDrive:notifyDestinationListeners()

-- Callback signature
function callBackFunction(callBackObject, success)
    -- success: boolean indicating if route completed successfully
end
```

## Mode Constants

```lua
AutoDrive.MODE_DRIVETO = 1           -- Simple drive to destination
AutoDrive.MODE_PICKUPANDDELIVER = 2  -- Load at first, unload at second
AutoDrive.MODE_DELIVERTO = 3         -- Deliver load to destination
AutoDrive.MODE_LOAD = 4              -- Load mode
AutoDrive.MODE_UNLOAD = 5            -- Unload mode
AutoDrive.MODE_BGA = 6               -- BGA mode
```

## Utility Functions

```lua
-- Get driver name
AutoDrive:GetDriverName(vehicle)

-- Get park destination
AutoDrive:GetParkDestination(vehicle)

-- Get path between points
AutoDrive:GetPath(startX, startZ, startYRot, destinationID, options)

-- Get path via intermediate point
AutoDrive:GetPathVia(startX, startZ, startYRot, viaID, destinationID, options)

-- Find closest network point
AutoDrive:GetClosestPointToLocation(x, z, minDistance)
```

## Courseplay Integration (via AD)

AutoDrive provides functions to control Courseplay:

```lua
-- Start CP at last waypoint
AutoDrive:StartCP(vehicle)

-- Restart CP
AutoDrive:RestartCP(vehicle)

-- Stop CP if active
AutoDrive:StopCP(vehicle)

-- Check CP status
AutoDrive:getIsCPActive(vehicle)
AutoDrive:getIsCPWaitingForUnload(vehicle)
AutoDrive:getIsCPTurning(vehicle)
AutoDrive:getIsCPCombineInPocket(vehicle)

-- Hold CP combine
AutoDrive:holdCPCombine(vehicle)
```

## AD → CP Handoff

AutoDrive can automatically start Courseplay on completion:

```lua
-- Tell AD to start helper on completion
vehicle.ad.stateModule:setStartHelper(true)

-- Pre-load CP course before starting AD
-- AD handles the switch automatically
```

## Destination Groups/Folders

AutoDrive organizes destinations in groups:

```lua
-- Get all markers with group info
local markers = ADGraphManager:getMapMarkers()

-- Markers structure
for _, marker in pairs(markers) do
    local name = marker.name
    local group = marker.group
    -- Markers in "All" group shown without prefix
    -- Others as "Group/Name"
end
```

## Example: Starting a Route

```lua
function startADRoute(vehicle, targetName, onComplete)
    local destinations = AutoDrive:GetAvailableDestinations()

    -- Find destination by name
    local targetId = nil
    for id, dest in pairs(destinations) do
        if dest.name == targetName then
            targetId = id
            break
        end
    end

    if targetId then
        AutoDrive:StartDriving(
            vehicle,
            targetId,
            -1,          -- no second destination
            self,        -- callback object
            onComplete,  -- callback function
            vehicle      -- callback arg
        )
        return true
    end
    return false
end
```

## Important Notes

1. **Server-side**: Control functions should be called on the server (`self.isServer`)
2. **Callbacks**: AD callbacks are reliable for completion notification
3. **restartCP flag**: AD uses `vehicle.ad.restartCP` to indicate CP should continue after AD finishes
4. **State module**: Always check `stateModule:isActive()` before starting a new route
