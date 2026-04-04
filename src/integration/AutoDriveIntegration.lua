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
    -- FS25 namespaces mod globals under FS25_<ModName>
    -- The actual AutoDrive table is at FS25_AutoDrive.AutoDrive
    local fs25AD = FS25_AutoDrive
    local adFromNamespace = fs25AD and fs25AD.AutoDrive

    -- Check if loaded as mod (for retry logging)
    local modLoaded = false
    if g_modManager ~= nil then
        local adMod = g_modManager:getModByName("FS25_AutoDrive")
        if adMod ~= nil then
            modLoaded = true
        end
    end

    -- Debug: log what we find (only on retry attempts)
    if self.checkAttempts >= 1 and self.checkAttempts <= 3 then
        WMLogger:debug("AutoDrive check #%d: FS25_AutoDrive=%s, .AutoDrive=%s, modLoaded=%s",
            self.checkAttempts,
            tostring(fs25AD ~= nil),
            tostring(adFromNamespace ~= nil),
            tostring(modLoaded))
    end

    -- Check FS25 namespaced global (the only working method in FS25)
    if adFromNamespace then
        WMLogger:info("AutoDrive detected via FS25_AutoDrive.AutoDrive!")
        -- Store reference in global AutoDrive for API calls
        AutoDrive = adFromNamespace
        return true
    end

    -- If mod is loaded but globals not yet available, keep trying
    if modLoaded and self.checkAttempts <= self.maxCheckAttempts then
        WMLogger:debug("AutoDrive mod loaded but globals not yet available")
    end

    return false
end

---Get list of available AutoDrive destinations/markers
---Uses ADGraphManager to get markers with their group names
---@return table destinations List of {id, name, displayName, group, x, y, z} tables, sorted by displayName
function ADIntegration:getDestinations()
    local destinations = {}

    if not self.isAvailable then
        return destinations
    end

    WMLogger:apiCall("AutoDrive", "GetDestinations")

    -- Try to get ADGraphManager for group support
    local graphManager = nil
    if ADGraphManager then
        graphManager = ADGraphManager
    elseif FS25_AutoDrive and FS25_AutoDrive.ADGraphManager then
        graphManager = FS25_AutoDrive.ADGraphManager
    end

    -- Use GetAvailableDestinations for correct IDs that work with StartDriving
    -- Then enrich with group info from getMapMarkers if available
    if AutoDrive and AutoDrive.GetAvailableDestinations then
        local adDestinations = AutoDrive:GetAvailableDestinations()

        -- Build a lookup table for group info from graphManager
        local groupLookup = {}
        if graphManager and graphManager.getMapMarkers then
            local markers = graphManager:getMapMarkers()
            if markers then
                for _, marker in pairs(markers) do
                    if marker.name then
                        groupLookup[marker.name] = marker.group or "All"
                    end
                end
            end
        end

        if adDestinations then
            for markerID, marker in pairs(adDestinations) do
                local markerName = marker.name or ""
                local groupName = groupLookup[markerName] or "All"

                -- Create display name with group prefix (skip "All" group prefix)
                local displayName = markerName
                if groupName ~= "All" and groupName ~= "" then
                    displayName = groupName .. "/" .. markerName
                end

                table.insert(destinations, {
                    id = markerID,  -- This is the correct ID for StartDriving
                    name = markerName,
                    displayName = displayName,
                    group = groupName,
                    x = marker.x,
                    y = marker.y,
                    z = marker.z
                })
            end
        end
    -- Fallback: Use graphManager only (less reliable for StartDriving IDs)
    elseif graphManager and graphManager.getMapMarkers and graphManager.getWayPointById then
        local markers = graphManager:getMapMarkers()
        if markers then
            for _, marker in pairs(markers) do
                local point = graphManager:getWayPointById(marker.id)
                local groupName = marker.group or "All"
                local markerName = marker.name or ""

                local displayName = markerName
                if groupName ~= "All" and groupName ~= "" then
                    displayName = groupName .. "/" .. markerName
                end

                table.insert(destinations, {
                    id = marker.markerIndex,  -- Use markerIndex
                    name = markerName,
                    displayName = displayName,
                    group = groupName,
                    x = point and point.x or 0,
                    y = point and point.y or 0,
                    z = point and point.z or 0
                })
            end
        end
    end

    -- Sort destinations by displayName for consistent ordering (groups first, then name)
    table.sort(destinations, function(a, b)
        return (a.displayName or "") < (b.displayName or "")
    end)

    WMLogger:debug("Found %d AutoDrive destinations", #destinations)
    return destinations
end

---Get destination names only (for dropdown lists)
---@return table names List of destination display names (with group prefix)
function ADIntegration:getDestinationNames()
    local names = {}
    local destinations = self:getDestinations()

    for _, dest in ipairs(destinations) do
        table.insert(names, dest.displayName or dest.name)
    end

    return names
end

---Get destination/marker by name or displayName
---@param name string Destination name or displayName (with group prefix)
---@return table|nil marker Marker data {id, name, displayName, group} or nil
function ADIntegration:getDestinationByName(name)
    if not self.isAvailable then
        return nil
    end

    local destinations = self:getDestinations()
    for _, dest in ipairs(destinations) do
        -- Match by displayName (with group prefix) or plain name
        if dest.displayName == name or dest.name == name then
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

    -- Only fire the completion event if this route was not already cancelled by stopRoute.
    -- stopRoute clears pendingCallbacks[vehicle] before calling stopAutoDrive, so if the
    -- callback fires synchronously (or late) after a manual stop, we silently discard it.
    -- Without this guard, the callback fires unconditionally and triggers onStepCompleted
    -- while goToNextStep is mid-execution, causing the sync-group loop to reset the step.
    if vehicle and ADIntegration.pendingCallbacks[vehicle] then
        ADIntegration.pendingCallbacks[vehicle] = nil

        WMEventHandler:fireEvent(WMEventHandler.EVENT_AUTODRIVE_FINISHED, {
            vehicle = vehicle,
            success = true
        })
    else
        WMLogger:debug("AutoDrive route complete callback ignored - route was cancelled")
    end
end

---Map action string to AutoDrive mode constant
---@param action string Action type: "drive", "pickup_deliver", "deliver", "load", "unload"
---@return number mode AutoDrive mode constant
function ADIntegration:actionToMode(action)
    local modes = self:getModes()
    local actionModeMap = {
        drive = modes.DRIVETO,
        pickup_deliver = modes.PICKUPANDDELIVER,
        deliver = modes.DELIVERTO,
        load = modes.LOAD,
        unload = modes.UNLOAD
    }
    return actionModeMap[action] or modes.DRIVETO
end

---Check if action requires a second target
---AutoDrive modes with 2 targets: unload, pickup_deliver, load
---AutoDrive modes with 1 target: drive, deliver
---@param action string Action type
---@return boolean needsSecondTarget True if action requires a second target
function ADIntegration:actionNeedsUnloadTarget(action)
    return action == "unload" or action == "pickup_deliver" or action == "load"
end

---Check if action supports fill type / fruit selection
---Only pickup_deliver and load modes support fruit selection
---@param action string Action type
---@return boolean needsFillType True if action supports fill type selection
function ADIntegration:actionNeedsFillType(action)
    return action == "pickup_deliver" or action == "load"
end

-- Fill types to exclude from selection (same filter as AutoDrive.ItemFilterList)
-- Includes animals, bales, and other non-cargo types
ADIntegration.filteredFillTypes = {
    "AIR",
    "CHICKEN_TYPE_BLACK",
    "CHICKEN_TYPE_WHITE",
    "CHICKEN_TYPE_BROWN",
    "CHICKEN_TYPE_ROOSTER",
    "COW_TYPE_BROWN",
    "COW_TYPE_BROWN_WHITE",
    "COW_TYPE_BLACK",
    "COW_TYPE_BLACK_WHITE",
    "COW_TYPE_BRAHMAN_BROWN",
    "COW_TYPE_BRAHMAN_WHITE",
    "COW_TYPE_BRAHMAN_LIGHT_BROWN",
    "COW_TYPE_BRAHMAN_GREY",
    "EGG",
    "HORSE_TYPE_BEIGE",
    "HORSE_TYPE_BLACK",
    "HORSE_TYPE_BROWN",
    "HORSE_TYPE_BROWN_WHITE",
    "HORSE_TYPE_DARK_BROWN",
    "HORSE_TYPE_GREY",
    "HORSE_TYPE_LIGHT_BROWN",
    "HORSE_TYPE_RED_BROWN",
    "OILSEEDRADISH",
    "PIG_TYPE_RED",
    "PIG_TYPE_WHITE",
    "PIG_TYPE_BLACK_WHITE",
    "PIG_TYPE_BLACK",
    "ROUNDBALE",
    "ROUNDBALE_GRASS",
    "ROUNDBALE_DRYGRASS",
    "ROUNDBALE_WHEAT",
    "ROUNDBALE_BARLEY",
    "SHEEP_TYPE_WHITE",
    "SHEEP_TYPE_BROWN",
    "SHEEP_TYPE_BLACK_WHITE",
    "SHEEP_TYPE_BLACK",
    "SQUAREBALE",
    "SQUAREBALE_WHEAT",
    "SQUAREBALE_BARLEY",
    "TARP",
    "TREESAPLINGS",
    "UNKNOWN",
    "WEED",
    "WOOL"
}

---Get available fill types from the game (filtered and deduplicated by title)
---@return table fillTypes List of {index, name, title} tables
function ADIntegration:getAvailableFillTypes()
    local fillTypes = {}
    local seenTitles = {}  -- Track titles we've already added to avoid duplicates

    if g_fillTypeManager == nil then
        WMLogger:debug("g_fillTypeManager not available")
        return fillTypes
    end

    -- Build lookup table for filtered types
    local filteredLookup = {}
    for _, name in ipairs(self.filteredFillTypes) do
        filteredLookup[name] = true
    end

    local allFillTypes = g_fillTypeManager:getFillTypes()
    if allFillTypes == nil then
        return fillTypes
    end

    for index, fillType in ipairs(allFillTypes) do
        -- Skip filtered fill types (animals, bales, special types)
        if not filteredLookup[fillType.name] then
            local title = fillType.title or fillType.name
            -- Deduplicate by title (some fill types have same display name)
            if not seenTitles[title] then
                seenTitles[title] = true
                table.insert(fillTypes, {
                    index = index,
                    name = fillType.name,
                    title = title
                })
            end
        end
    end

    -- Sort by title for consistent ordering
    table.sort(fillTypes, function(a, b)
        return (a.title or "") < (b.title or "")
    end)

    WMLogger:debug("Found %d fill types (filtered and deduplicated)", #fillTypes)
    return fillTypes
end

---Get fill type names only (for dropdown lists)
---@return table names List of fill type display names
function ADIntegration:getFillTypeNames()
    local names = {}
    local fillTypes = self:getAvailableFillTypes()

    for _, ft in ipairs(fillTypes) do
        table.insert(names, ft.title or ft.name)
    end

    return names
end

---Start an AutoDrive route for a vehicle
---Uses AutoDrive:StartDriving() from ExternalInterface.lua
---@param vehicle table Vehicle to control
---@param targetName string Target destination name
---@param action string|nil Action type: "drive", "pickup_deliver", "deliver", "load", "unload"
---@param unloadTargetName string|nil Second destination for pickup_deliver mode
---@param fillType string|nil Fill type name for filtering (optional)
---@return boolean success True if route started successfully
function ADIntegration:startRoute(vehicle, targetName, action, unloadTargetName, fillType)
    WMLogger:debug("ADIntegration:startRoute called - target: %s, action: %s, unloadTarget: %s, fillType: %s",
        tostring(targetName), tostring(action), tostring(unloadTargetName), tostring(fillType))

    if not self.isAvailable then
        WMLogger:error("Cannot start AutoDrive route - AutoDrive not available")
        return false
    end

    if vehicle == nil then
        WMLogger:error("Cannot start AutoDrive route - vehicle is nil")
        return false
    end

    WMLogger:debug("Vehicle passed to startRoute: %s", vehicle.getName and vehicle:getName() or "unknown")

    -- Check if vehicle has AutoDrive spec
    if vehicle.ad == nil then
        WMLogger:error("Vehicle does not have AutoDrive specialization (vehicle.ad is nil)")
        return false
    end

    WMLogger:debug("Vehicle has AutoDrive spec, stateModule: %s", tostring(vehicle.ad.stateModule ~= nil))

    -- Check if already active - stop existing AD first so workflow can take control
    if self:isRunning(vehicle) then
        WMLogger:info("AutoDrive already active - stopping current route to start new one")
        self:stopRoute(vehicle)
        -- Small delay might be needed, but try to continue
    end

    -- Find the target marker
    local targetMarker = self:getDestinationByName(targetName)
    if targetMarker == nil then
        WMLogger:error("AutoDrive destination not found: %s", targetName)
        return false
    end

    -- Determine the mode based on action
    local mode = self:actionToMode(action or "drive")
    WMLogger:info("Using AutoDrive mode %d for action '%s'", mode, action or "drive")

    -- Resolve unload destination ID
    local unloadDestinationID = -1  -- Default: no second destination

    -- For pickup_deliver mode, we need an unload target
    if self:actionNeedsUnloadTarget(action) then
        if unloadTargetName ~= nil and unloadTargetName ~= "" then
            local unloadMarker = self:getDestinationByName(unloadTargetName)
            if unloadMarker ~= nil then
                unloadDestinationID = unloadMarker.id
                WMLogger:info("Unload destination: %s (markerID: %d)", unloadTargetName, unloadDestinationID)
            else
                WMLogger:warning("Unload destination not found: %s, using default", unloadTargetName)
            end
        else
            WMLogger:warning("Pickup & Deliver mode requires unload target, but none provided")
        end
    end

    WMLogger:info("Starting AutoDrive route to: %s (markerID: %d), unloadDest: %d",
        targetName, targetMarker.id, unloadDestinationID)

    -- Use the official StartDriving API with callback
    if AutoDrive.StartDriving then
        WMLogger:debug("AutoDrive.StartDriving exists, calling it...")

        -- Pre-set the markers and mode on the vehicle's stateModule
        if vehicle.ad.stateModule then
            WMLogger:debug("Pre-setting firstMarker to %d, mode to %d", targetMarker.id, mode)

            -- Set mode first
            if vehicle.ad.stateModule.setMode then
                vehicle.ad.stateModule:setMode(mode)
            end

            -- Set first marker (pickup/start location)
            if vehicle.ad.stateModule.setFirstMarker then
                vehicle.ad.stateModule:setFirstMarker(targetMarker.id)
            end
            if vehicle.ad.stateModule.setFirstMarkerId then
                vehicle.ad.stateModule:setFirstMarkerId(targetMarker.id)
            end

            -- Set second marker (unload/delivery location) if provided
            if unloadDestinationID > 0 then
                if vehicle.ad.stateModule.setSecondMarker then
                    vehicle.ad.stateModule:setSecondMarker(unloadDestinationID)
                end
                if vehicle.ad.stateModule.setSecondMarkerId then
                    vehicle.ad.stateModule:setSecondMarkerId(unloadDestinationID)
                end
            end

            -- Set fill type if provided (for selective loading)
            if fillType ~= nil and fillType ~= "" then
                if vehicle.ad.stateModule.setFillType then
                    -- Find fill type index
                    local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillType)
                    if fillTypeIndex ~= nil then
                        vehicle.ad.stateModule:setFillType(fillTypeIndex)
                        WMLogger:debug("Set fill type to %s (index: %d)", fillType, fillTypeIndex)
                    end
                end
            end
        end

        -- Track pending callback
        self.pendingCallbacks[vehicle] = true

        -- Start driving with callback for completion notification
        WMLogger:debug("Calling AutoDrive:StartDriving(vehicle, %d, %d, callback...)",
            targetMarker.id, unloadDestinationID)
        local success, errorMsg = pcall(function()
            AutoDrive:StartDriving(
                vehicle,
                targetMarker.id,       -- destinationID (pickup/start location)
                unloadDestinationID,   -- unloadDestinationID (-1=none, -2=refuel, -3=park, >0=marker)
                ADIntegration,         -- callBackObject
                ADIntegration.onRouteCompleteCallback, -- callBackFunction
                vehicle                -- callBackArg
            )
        end)

        if success then
            WMLogger:info("AutoDrive:StartDriving called successfully (mode: %d)", mode)

            -- Debug: Check vehicle state after starting
            if vehicle.ad and vehicle.ad.stateModule then
                local sm = vehicle.ad.stateModule
                local isActive = sm.isActive and sm:isActive() or false
                local currentMode = sm.getMode and sm:getMode() or "?"
                local firstMarker = sm.getFirstMarker and sm:getFirstMarker() or "?"
                local firstMarkerName = sm.getFirstMarkerName and sm:getFirstMarkerName() or "?"
                local secondMarker = sm.getSecondMarker and sm:getSecondMarker() or "?"
                WMLogger:debug("AD state after start: active=%s, mode=%s, firstMarker=%s (%s), secondMarker=%s",
                    tostring(isActive), tostring(currentMode), tostring(firstMarker),
                    tostring(firstMarkerName), tostring(secondMarker))
            end

            WMLogger:stateChange("AutoDrive", nil, "started")
            return true
        else
            WMLogger:error("AutoDrive:StartDriving failed: %s", tostring(errorMsg))
            self.pendingCallbacks[vehicle] = nil
            return false
        end
    end

    -- Fallback: Try direct mode start
    if vehicle.ad.stateModule and vehicle.ad.stateModule.getCurrentMode then
        vehicle.ad.stateModule:setMode(mode)
        vehicle.ad.stateModule:setFirstMarker(targetMarker.id)
        if unloadDestinationID > 0 and vehicle.ad.stateModule.setSecondMarker then
            vehicle.ad.stateModule:setSecondMarker(unloadDestinationID)
        end
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

    local stopped = false

    -- Primary method: Use AutoDrive's own stopAutoDrive function
    -- This properly handles braking, cruise control, module resets, etc.
    if vehicle.stopAutoDrive then
        local success = pcall(function() vehicle:stopAutoDrive() end)
        if success then
            stopped = true
            WMLogger:debug("Stopped via vehicle:stopAutoDrive()")
        end
    end

    -- Fallback: Manual stop if stopAutoDrive didn't work or isn't available
    if not stopped or self:isRunning(vehicle) then
        -- Stop the current mode's operation
        if vehicle.ad.stateModule and vehicle.ad.stateModule.getCurrentMode then
            local currentMode = vehicle.ad.stateModule:getCurrentMode()
            if currentMode and currentMode.stop then
                pcall(function() currentMode:stop() end)
            end
        end

        -- Clear the active state
        if vehicle.ad.stateModule and vehicle.ad.stateModule.setActive then
            pcall(function() vehicle.ad.stateModule:setActive(false) end)
            stopped = true
        end

        -- Disable cruise control
        pcall(function()
            if vehicle.setCruiseControlState then
                vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
            end
        end)
    end

    -- Verify the stop worked
    local stillRunning = self:isRunning(vehicle)
    if stillRunning then
        WMLogger:warning("AutoDrive still active after stop attempts")
    else
        WMLogger:stateChange("AutoDrive", "running", "stopped")
    end

    return stopped and not stillRunning
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

---Configure AutoDrive to automatically start Courseplay when route completes
---Uses stateModule:setStartHelper(true) which is the official API
---AutoDrive will check getStartHelper() and getUsedHelper() == HELPER_CP on completion
---@param vehicle table Vehicle to configure
---@param enable boolean If true, enables CP handoff; if false, disables it
---@return boolean success True if configured successfully
function ADIntegration:setStartCPOnCompletion(vehicle, enable)
    if not self.isAvailable then
        WMLogger:error("Cannot configure CP handoff - AutoDrive not available")
        return false
    end

    if vehicle == nil or vehicle.ad == nil then
        WMLogger:error("Cannot configure CP handoff - vehicle or vehicle.ad is nil")
        return false
    end

    if vehicle.ad.stateModule == nil then
        WMLogger:error("Cannot configure CP handoff - vehicle.ad.stateModule is nil")
        return false
    end

    -- Check if Courseplay is the configured helper
    local ADStateModule = FS25_AutoDrive and FS25_AutoDrive.ADStateModule
    if ADStateModule then
        local usedHelper = vehicle.ad.stateModule:getUsedHelper()
        if usedHelper ~= ADStateModule.HELPER_CP then
            WMLogger:warning("Vehicle helper is not Courseplay (helper=%s, expected=%s)",
                tostring(usedHelper), tostring(ADStateModule.HELPER_CP))
            -- Still try to set it - CP might start working
        end
    end

    -- Use the official API: setStartHelper(true) tells AD to start the helper on completion
    -- AutoDrive checks: getStartHelper() and getUsedHelper() == HELPER_CP
    if vehicle.ad.stateModule.setStartHelper then
        vehicle.ad.stateModule:setStartHelper(enable)
        WMLogger:info("Configured AutoDrive to %s Courseplay on completion (setStartHelper=%s)",
            enable and "start" or "not start", tostring(enable))
        return true
    else
        WMLogger:error("Cannot configure CP handoff - setStartHelper not available")
        return false
    end
end

---Clear the Courseplay handoff flag
---@param vehicle table Vehicle to configure
function ADIntegration:clearCPHandoff(vehicle)
    if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil then
        if vehicle.ad.stateModule.setStartHelper then
            vehicle.ad.stateModule:setStartHelper(false)
            WMLogger:debug("Cleared AutoDrive CP handoff (setStartHelper=false)")
        end
    end
end
