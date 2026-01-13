--[[
    WorkflowManager - AutoDrive Integration
    Provides interface to AutoDrive mod functionality

    Based on analysis of AutoDrive ExternalInterface.lua

    Author: WorkflowManager Team
]]

---@class ADIntegration
ADIntegration = {}

ADIntegration.isInitialized = false
ADIntegration.isAvailable = false
ADIntegration.checkAttempts = 0
ADIntegration.maxCheckAttempts = 10
ADIntegration.checkInterval = 1000  -- ms between retry attempts
ADIntegration.timeSinceLastCheck = 0

-- Callback tracking for completion detection
ADIntegration.pendingCallbacks = {}

---Initialize the AutoDrive integration
function ADIntegration:init()
    self.checkAttempts = 0
    self.timeSinceLastCheck = 0

    -- Check if AutoDrive is loaded
    self.isAvailable = self:checkAvailability()

    if self.isAvailable then
        self:completeInitialization()
    else
        WMLogger:info("AutoDrive integration initialized - AutoDrive not yet available, will retry")
    end

    self.isInitialized = true
end

---Complete initialization when AutoDrive becomes available
function ADIntegration:completeInitialization()
    WMLogger:info("AutoDrive integration initialized - AutoDrive is available")

    -- Register as destination listener to get notifications when AD routes complete
    if AutoDrive and AutoDrive.registerDestinationListener then
        AutoDrive:registerDestinationListener(self, self.onDestinationReached)
    end
end

---Update function - checks for AutoDrive availability if not yet found
---@param dt number Delta time in milliseconds
function ADIntegration:update(dt)
    -- If already available, nothing to do
    if self.isAvailable then
        return
    end

    -- If we've exceeded max attempts, stop trying
    if self.checkAttempts >= self.maxCheckAttempts then
        -- Log once when we give up
        if self.checkAttempts == self.maxCheckAttempts then
            WMLogger:warning("AutoDrive not found after %d attempts - giving up", self.maxCheckAttempts)
            self.checkAttempts = self.checkAttempts + 1  -- Prevent repeated logging
        end
        return
    end

    -- Accumulate time
    self.timeSinceLastCheck = self.timeSinceLastCheck + dt

    -- Check at intervals
    if self.timeSinceLastCheck >= self.checkInterval then
        self.timeSinceLastCheck = 0
        self.checkAttempts = self.checkAttempts + 1

        self.isAvailable = self:checkAvailability()

        if self.isAvailable then
            self:completeInitialization()
        else
            WMLogger:debug("AutoDrive check attempt %d/%d - not available yet",
                self.checkAttempts, self.maxCheckAttempts)
        end
    end
end

---Check if AutoDrive mod is available
---@return boolean available True if AutoDrive is loaded
function ADIntegration:checkAvailability()
    -- Check multiple possible globals that AutoDrive might use
    local adExists = rawget(_G, "AutoDrive") ~= nil
    local adManagerExists = rawget(_G, "ADGraphManager") ~= nil
    local gAutodriveExists = rawget(_G, "g_autoDrive") ~= nil

    -- Also check if loaded as mod (FS25 style)
    local modLoaded = false
    if g_modManager ~= nil then
        local adMod = g_modManager:getModByName("FS25_AutoDrive")
        if adMod ~= nil then
            modLoaded = true
        end
    end

    -- Check via g_currentMission (some mods attach there)
    local missionAD = g_currentMission ~= nil and g_currentMission.autoDrive ~= nil

    -- Debug: log what we find (more detailed on first few attempts)
    if self.checkAttempts <= 3 then
        WMLogger:debug("AutoDrive check #%d: AutoDrive=%s (type=%s), ADGraphManager=%s, g_autoDrive=%s, modLoaded=%s, missionAD=%s",
            self.checkAttempts,
            tostring(adExists),
            type(rawget(_G, "AutoDrive")),
            tostring(adManagerExists),
            tostring(gAutodriveExists),
            tostring(modLoaded),
            tostring(missionAD))
    end

    if adExists or adManagerExists or gAutodriveExists or missionAD then
        WMLogger:info("AutoDrive detected!")
        return true
    end

    -- If mod is loaded but globals not yet available, keep trying
    if modLoaded and self.checkAttempts <= self.maxCheckAttempts then
        WMLogger:debug("AutoDrive mod loaded but globals not yet available")
    end

    return false
end

---Get list of available AutoDrive destinations/markers
---Uses the official AutoDrive:GetAvailableDestinations() API
---@return table destinations List of {id, name, x, y, z} tables
function ADIntegration:getDestinations()
    local destinations = {}

    if not self.isAvailable then
        return destinations
    end

    WMLogger:apiCall("AutoDrive", "GetAvailableDestinations")

    -- Use official API from ExternalInterface.lua
    if AutoDrive.GetAvailableDestinations then
        local adDestinations = AutoDrive:GetAvailableDestinations()
        if adDestinations then
            for markerID, marker in pairs(adDestinations) do
                table.insert(destinations, {
                    id = markerID,
                    name = marker.name,
                    x = marker.x,
                    y = marker.y,
                    z = marker.z
                })
            end
        end
    -- Fallback to direct access
    elseif ADGraphManager and ADGraphManager.getMapMarkers then
        for markerID, marker in pairs(ADGraphManager:getMapMarkers()) do
            table.insert(destinations, {
                id = markerID,
                name = marker.name
            })
        end
    end

    WMLogger:debug("Found %d AutoDrive destinations", #destinations)
    return destinations
end

---Get destination names only (for dropdown lists)
---@return table names List of destination name strings
function ADIntegration:getDestinationNames()
    local names = {}
    local destinations = self:getDestinations()

    for _, dest in ipairs(destinations) do
        table.insert(names, dest.name)
    end

    return names
end

---Get destination/marker by name
---@param name string Destination name
---@return table|nil marker Marker data {id, name} or nil
function ADIntegration:getDestinationByName(name)
    if not self.isAvailable then
        return nil
    end

    local destinations = self:getDestinations()
    for _, dest in ipairs(destinations) do
        if dest.name == name then
            return dest
        end
    end

    return nil
end

---Get destination/marker by ID
---@param id number Destination ID
---@return table|nil marker Marker data or nil
function ADIntegration:getDestinationById(id)
    if not self.isAvailable then
        return nil
    end

    if ADGraphManager and ADGraphManager.getMapMarkerById then
        return ADGraphManager:getMapMarkerById(id)
    end

    return nil
end

---Callback function when AutoDrive completes a route
---@param success boolean Whether the route completed successfully
function ADIntegration:onDestinationReached(success)
    WMLogger:debug("AutoDrive destination reached callback, success: %s", tostring(success))

    -- Fire event for workflow manager to handle
    WMEventHandler:fireEvent(WMEventHandler.EVENT_AUTODRIVE_FINISHED, {
        success = success
    })
end

---Callback wrapper for AutoDrive StartDriving
---@param vehicle table Vehicle that completed
function ADIntegration.onRouteCompleteCallback(vehicle)
    WMLogger:debug("AutoDrive route complete callback for vehicle")

    -- Remove from pending
    if vehicle and ADIntegration.pendingCallbacks[vehicle] then
        ADIntegration.pendingCallbacks[vehicle] = nil
    end

    -- Fire completion event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_AUTODRIVE_FINISHED, {
        vehicle = vehicle,
        success = true
    })
end

---Start an AutoDrive route for a vehicle
---Uses AutoDrive:StartDriving() from ExternalInterface.lua
---@param vehicle table Vehicle to control
---@param targetName string Target destination name
---@param action string|nil Action type (optional): "drive", "load", "unload"
---@return boolean success True if route started successfully
function ADIntegration:startRoute(vehicle, targetName, action)
    if not self.isAvailable then
        WMLogger:error("Cannot start AutoDrive route - AutoDrive not available")
        return false
    end

    if vehicle == nil then
        WMLogger:error("Cannot start AutoDrive route - vehicle is nil")
        return false
    end

    -- Check if vehicle has AutoDrive spec
    if vehicle.ad == nil then
        WMLogger:error("Vehicle does not have AutoDrive specialization")
        return false
    end

    -- Check if already active
    if self:isRunning(vehicle) then
        WMLogger:warning("AutoDrive is already active for this vehicle")
        return false
    end

    -- Find the target marker
    local targetMarker = self:getDestinationByName(targetName)
    if targetMarker == nil then
        WMLogger:error("AutoDrive destination not found: %s", targetName)
        return false
    end

    WMLogger:info("Starting AutoDrive route to: %s (ID: %d)", targetName, targetMarker.id)
    WMLogger:apiCall("AutoDrive", "StartDriving", vehicle, targetMarker.id)

    -- Use the official StartDriving API with callback
    if AutoDrive.StartDriving then
        -- Set mode to DRIVETO (mode 1)
        if vehicle.ad.stateModule then
            vehicle.ad.stateModule:setMode(AutoDrive.MODE_DRIVETO or 1)
            vehicle.ad.stateModule:setFirstMarker(targetMarker.id)
        end

        -- Track pending callback
        self.pendingCallbacks[vehicle] = true

        -- Start driving with callback for completion notification
        AutoDrive:StartDriving(
            vehicle,
            targetMarker.id,      -- destinationID
            -1,                    -- unloadDestinationID (-1 = none)
            ADIntegration,         -- callBackObject
            ADIntegration.onRouteCompleteCallback, -- callBackFunction
            vehicle                -- callBackArg
        )

        WMLogger:stateChange("AutoDrive", nil, "started")
        return true
    end

    -- Fallback: Try direct mode start
    if vehicle.ad.stateModule and vehicle.ad.stateModule.getCurrentMode then
        vehicle.ad.stateModule:setMode(AutoDrive.MODE_DRIVETO or 1)
        vehicle.ad.stateModule:setFirstMarker(targetMarker.id)
        vehicle.ad.stateModule:getCurrentMode():start()
        return true
    end

    WMLogger:error("Failed to start AutoDrive - API method not found")
    return false
end

---Stop AutoDrive for a vehicle
---@param vehicle table Vehicle to stop
---@return boolean success True if stopped successfully
function ADIntegration:stopRoute(vehicle)
    if not self.isAvailable then
        return false
    end

    if vehicle == nil or vehicle.ad == nil then
        return false
    end

    WMLogger:info("Stopping AutoDrive route")
    WMLogger:apiCall("AutoDrive", "stopRoute", vehicle)

    -- Remove from pending callbacks
    self.pendingCallbacks[vehicle] = nil

    -- Use stateModule to stop
    if vehicle.ad.stateModule and vehicle.ad.stateModule.getCurrentMode then
        local currentMode = vehicle.ad.stateModule:getCurrentMode()
        if currentMode and currentMode.stop then
            currentMode:stop()
            WMLogger:stateChange("AutoDrive", "running", "stopped")
            return true
        end
    end

    return false
end

---Pause AutoDrive for a vehicle
---Uses AutoDrive:HoldDriving() from ExternalInterface.lua
---@param vehicle table Vehicle to pause
---@return boolean success True if paused successfully
function ADIntegration:pauseRoute(vehicle)
    if not self.isAvailable then
        return false
    end

    if vehicle == nil or vehicle.ad == nil then
        return false
    end

    WMLogger:info("Pausing AutoDrive route")
    WMLogger:apiCall("AutoDrive", "HoldDriving", vehicle)

    -- Use official HoldDriving API
    if AutoDrive.HoldDriving then
        AutoDrive:HoldDriving(vehicle)
        WMLogger:stateChange("AutoDrive", "running", "paused")
        return true
    end

    -- Fallback: use drivePathModule
    if vehicle.ad.drivePathModule and vehicle.ad.drivePathModule.setPaused then
        vehicle.ad.drivePathModule:setPaused()
        return true
    end

    return false
end

---Resume AutoDrive for a vehicle
---@param vehicle table Vehicle to resume
---@return boolean success True if resumed successfully
function ADIntegration:resumeRoute(vehicle)
    if not self.isAvailable then
        return false
    end

    if vehicle == nil or vehicle.ad == nil then
        return false
    end

    WMLogger:info("Resuming AutoDrive route")

    -- Resume via drivePathModule
    if vehicle.ad.drivePathModule and vehicle.ad.drivePathModule.setUnPaused then
        vehicle.ad.drivePathModule:setUnPaused()
        WMLogger:stateChange("AutoDrive", "paused", "running")
        return true
    end

    return false
end

---Check if AutoDrive route is complete for a vehicle
---@param vehicle table Vehicle to check
---@return boolean complete True if route is complete
function ADIntegration:isRouteComplete(vehicle)
    if not self.isAvailable then
        return true -- Consider complete if AD not available
    end

    if vehicle == nil or vehicle.ad == nil then
        return true
    end

    -- Check if AutoDrive is still active/running
    if vehicle.ad.stateModule ~= nil and vehicle.ad.stateModule.isActive then
        local isActive = vehicle.ad.stateModule:isActive()
        return not isActive
    end

    return true
end

---Check if vehicle is currently running AutoDrive
---@param vehicle table Vehicle to check
---@return boolean running True if AutoDrive is running
function ADIntegration:isRunning(vehicle)
    if not self.isAvailable then
        return false
    end

    if vehicle == nil or vehicle.ad == nil then
        return false
    end

    if vehicle.ad.stateModule ~= nil and vehicle.ad.stateModule.isActive then
        return vehicle.ad.stateModule:isActive()
    end

    return false
end

---Check if vehicle is paused
---@param vehicle table Vehicle to check
---@return boolean paused True if paused
function ADIntegration:isPaused(vehicle)
    if not self.isAvailable then
        return false
    end

    if vehicle == nil or vehicle.ad == nil then
        return false
    end

    if vehicle.ad.drivePathModule and vehicle.ad.drivePathModule.isPaused then
        return vehicle.ad.drivePathModule:isPaused()
    end

    return false
end

---Get current AutoDrive mode for a vehicle
---@param vehicle table Vehicle to check
---@return number|nil mode AutoDrive mode constant or nil
function ADIntegration:getCurrentMode(vehicle)
    if not self.isAvailable then
        return nil
    end

    if vehicle == nil or vehicle.ad == nil then
        return nil
    end

    if vehicle.ad.stateModule ~= nil and vehicle.ad.stateModule.getMode then
        return vehicle.ad.stateModule:getMode()
    end

    return nil
end

---Get AutoDrive mode constants
---@return table modes Table with mode constants
function ADIntegration:getModes()
    if not self.isAvailable then
        return {}
    end

    return {
        DRIVETO = AutoDrive.MODE_DRIVETO or 1,
        PICKUPANDDELIVER = AutoDrive.MODE_PICKUPANDDELIVER or 2,
        DELIVERTO = AutoDrive.MODE_DELIVERTO or 3,
        LOAD = AutoDrive.MODE_LOAD or 4,
        UNLOAD = AutoDrive.MODE_UNLOAD or 5,
        BGA = AutoDrive.MODE_BGA or 6
    }
end

---Get the driver name set for a vehicle
---@param vehicle table Vehicle
---@return string|nil name Driver name or nil
function ADIntegration:getDriverName(vehicle)
    if not self.isAvailable or vehicle == nil then
        return nil
    end

    if AutoDrive.GetDriverName then
        return AutoDrive:GetDriverName(vehicle)
    end

    return nil
end
