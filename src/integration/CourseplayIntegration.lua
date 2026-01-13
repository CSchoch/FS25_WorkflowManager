--[[
    WorkflowManager - Courseplay Integration
    Provides interface to Courseplay mod functionality

    Based on analysis of FS25_Courseplay source code:
    - CpAIWorker.lua (main driver control)
    - CpAIFieldWorker.lua (field work specifics)
    - CpCourseManager.lua (course management)

    Author: WorkflowManager Team
]]

---@class CPIntegration
CPIntegration = {}

CPIntegration.isInitialized = false
CPIntegration.isAvailable = false

---Initialize the Courseplay integration
function CPIntegration:init()
    -- Check if Courseplay is loaded
    self.isAvailable = self:checkAvailability()

    if self.isAvailable then
        WMLogger:info("Courseplay integration initialized - Courseplay is available")
    else
        WMLogger:warning("Courseplay integration initialized - Courseplay is NOT available")
    end

    self.isInitialized = true
end

---Check if Courseplay mod is available
---@return boolean available True if Courseplay is loaded
function CPIntegration:checkAvailability()
    -- FS25 Courseplay uses g_Courseplay global
    return g_Courseplay ~= nil
end

---Check if vehicle has Courseplay worker specialization
---@param vehicle table Vehicle to check
---@return boolean hasCp True if vehicle has CP spec
function CPIntegration:hasSpec(vehicle)
    if vehicle == nil then
        return false
    end
    return vehicle.spec_cpAIWorker ~= nil
end

---Check if vehicle has Courseplay field worker specialization
---@param vehicle table Vehicle to check
---@return boolean hasFieldWorker True if vehicle has CP field worker spec
function CPIntegration:hasFieldWorkerSpec(vehicle)
    if vehicle == nil then
        return false
    end
    return vehicle.spec_cpAIFieldWorker ~= nil
end

---Check if vehicle has a course loaded
---@param vehicle table Vehicle to check
---@return boolean hasCourse True if vehicle has a course
function CPIntegration:hasCourse(vehicle)
    if not self.isAvailable or vehicle == nil then
        return false
    end

    if vehicle.hasCpCourse then
        return vehicle:hasCpCourse()
    end

    return false
end

---Get current course name for a vehicle
---@param vehicle table Vehicle to check
---@return string|nil name Course name or nil
function CPIntegration:getCurrentCourseName(vehicle)
    if not self.isAvailable or vehicle == nil then
        return nil
    end

    if vehicle.getCurrentCpCourseName then
        return vehicle:getCurrentCpCourseName()
    end

    return nil
end

---Start Courseplay field work for a vehicle
---Uses the actual FS25 CP API: startCpAtLastWp() or startCpAtFirstWp()
---@param vehicle table Vehicle to control
---@param startAtFirst boolean|nil If true, start at first waypoint (default: last)
---@return boolean success True if started successfully
function CPIntegration:startFieldWork(vehicle, startAtFirst)
    if not self.isAvailable then
        WMLogger:error("Cannot start Courseplay - Courseplay not available")
        return false
    end

    if vehicle == nil then
        WMLogger:error("Cannot start Courseplay - vehicle is nil")
        return false
    end

    -- Check if vehicle has the field worker spec
    if not self:hasFieldWorkerSpec(vehicle) then
        WMLogger:error("Vehicle does not have Courseplay field worker specialization")
        return false
    end

    -- Check if vehicle has a course
    if not self:hasCourse(vehicle) then
        WMLogger:error("Vehicle has no Courseplay course loaded")
        return false
    end

    -- Check if can start
    if vehicle.getCanStartCpFieldWork and not vehicle:getCanStartCpFieldWork() then
        WMLogger:error("Vehicle cannot start Courseplay field work")
        return false
    end

    WMLogger:info("Starting Courseplay field work")
    WMLogger:apiCall("Courseplay", startAtFirst and "startCpAtFirstWp" or "startCpAtLastWp", vehicle)

    -- Use the official API
    if startAtFirst and vehicle.startCpAtFirstWp then
        vehicle:startCpAtFirstWp()
        WMLogger:stateChange("Courseplay", nil, "started (first wp)")
        return true
    elseif vehicle.startCpAtLastWp then
        vehicle:startCpAtLastWp()
        WMLogger:stateChange("Courseplay", nil, "started (last wp)")
        return true
    end

    -- Fallback: use cpStartStopDriver
    if vehicle.cpStartStopDriver then
        vehicle:cpStartStopDriver(false)
        WMLogger:stateChange("Courseplay", nil, "started")
        return true
    end

    WMLogger:error("Failed to start Courseplay - API method not found")
    return false
end

---Stop Courseplay for a vehicle
---@param vehicle table Vehicle to stop
---@return boolean success True if stopped successfully
function CPIntegration:stopCourse(vehicle)
    if not self.isAvailable then
        return false
    end

    if vehicle == nil or not self:hasSpec(vehicle) then
        return false
    end

    -- Check if actually running
    if not self:isRunning(vehicle) then
        WMLogger:debug("Courseplay is not running, nothing to stop")
        return true
    end

    WMLogger:info("Stopping Courseplay")
    WMLogger:apiCall("Courseplay", "stopCurrentAIJob", vehicle)

    -- Use the official stop method
    if vehicle.stopCurrentAIJob then
        -- Need to pass a message - use the standard stopped by user message
        local AIMessageSuccessStoppedByUser = AIMessageSuccessStoppedByUser or
            (g_currentMission and g_currentMission.aiMessageManager and
             g_currentMission.aiMessageManager.aiMessages and
             g_currentMission.aiMessageManager.aiMessages.AIMessageSuccessStoppedByUser)

        if AIMessageSuccessStoppedByUser and AIMessageSuccessStoppedByUser.new then
            vehicle:stopCurrentAIJob(AIMessageSuccessStoppedByUser.new())
            WMLogger:stateChange("Courseplay", "running", "stopped")
            return true
        end
    end

    -- Alternative: use cpStartStopDriver to toggle off
    if vehicle.cpStartStopDriver and self:isRunning(vehicle) then
        vehicle:cpStartStopDriver(false)
        WMLogger:stateChange("Courseplay", "running", "stopped")
        return true
    end

    return false
end

---Hold/Pause Courseplay temporarily
---@param vehicle table Vehicle to pause
---@param ms number|nil Milliseconds to hold (default: indefinite via freeze)
---@return boolean success True if paused successfully
function CPIntegration:holdCourse(vehicle, ms)
    if not self.isAvailable then
        return false
    end

    if vehicle == nil or not self:hasSpec(vehicle) then
        return false
    end

    WMLogger:info("Holding Courseplay for %d ms", ms or 0)
    WMLogger:apiCall("Courseplay", "cpHold", vehicle, ms)

    -- Use cpHold for temporary hold
    if ms and vehicle.cpHold then
        vehicle:cpHold(ms, false)
        return true
    end

    -- Use freeze for indefinite hold
    if vehicle.freezeCp then
        vehicle:freezeCp()
        WMLogger:stateChange("Courseplay", "running", "frozen")
        return true
    end

    return false
end

---Resume/Unfreeze Courseplay
---@param vehicle table Vehicle to resume
---@return boolean success True if resumed successfully
function CPIntegration:resumeCourse(vehicle)
    if not self.isAvailable then
        return false
    end

    if vehicle == nil or not self:hasSpec(vehicle) then
        return false
    end

    WMLogger:info("Resuming Courseplay")
    WMLogger:apiCall("Courseplay", "unfreezeCp", vehicle)

    if vehicle.unfreezeCp then
        vehicle:unfreezeCp()
        WMLogger:stateChange("Courseplay", "frozen", "running")
        return true
    end

    return false
end

---Check if Courseplay is currently active for a vehicle
---@param vehicle table Vehicle to check
---@return boolean running True if Courseplay is running
function CPIntegration:isRunning(vehicle)
    if not self.isAvailable then
        return false
    end

    if vehicle == nil or not self:hasSpec(vehicle) then
        return false
    end

    -- Use the official getIsCpActive method
    if vehicle.getIsCpActive then
        return vehicle:getIsCpActive()
    end

    return false
end

---Check if Courseplay field work is specifically active
---@param vehicle table Vehicle to check
---@return boolean running True if field work is running
function CPIntegration:isFieldWorkActive(vehicle)
    if not self.isAvailable then
        return false
    end

    if vehicle == nil or not self:hasFieldWorkerSpec(vehicle) then
        return false
    end

    if vehicle.getIsCpFieldWorkActive then
        return vehicle:getIsCpFieldWorkActive()
    end

    return false
end

---Check if Courseplay course is complete (not running)
---@param vehicle table Vehicle to check
---@return boolean complete True if course is complete or not running
function CPIntegration:isCourseComplete(vehicle)
    return not self:isRunning(vehicle)
end

---Get field work progress (0-1)
---@param vehicle table Vehicle to check
---@return number|nil progress Progress 0-1 or nil
function CPIntegration:getProgress(vehicle)
    if not self.isAvailable or vehicle == nil then
        return nil
    end

    if vehicle.getCpFieldWorkProgress then
        return vehicle:getCpFieldWorkProgress()
    end

    return nil
end

---Check if harvester is waiting for unload
---@param vehicle table Vehicle to check
---@return boolean waiting True if waiting for unload
function CPIntegration:isHarvesterWaitingForUnload(vehicle)
    if not self.isAvailable or vehicle == nil then
        return false
    end

    if vehicle.getIsCpHarvesterWaitingForUnload then
        return vehicle:getIsCpHarvesterWaitingForUnload()
    end

    return false
end

---Check if harvester is maneuvering (turning, pocket, etc.)
---@param vehicle table Vehicle to check
---@return boolean maneuvering True if maneuvering
function CPIntegration:isHarvesterManeuvering(vehicle)
    if not self.isAvailable or vehicle == nil then
        return false
    end

    if vehicle.getIsCpHarvesterManeuvering then
        return vehicle:getIsCpHarvesterManeuvering()
    end

    return false
end

---Get the Courseplay specialization from a vehicle (legacy compatibility)
---@param vehicle table Vehicle to check
---@return table|nil cpSpec Courseplay spec or nil
function CPIntegration:getCourseplaySpec(vehicle)
    if vehicle == nil then
        return nil
    end

    -- FS25 uses spec_cpAIWorker
    if vehicle.spec_cpAIWorker ~= nil then
        return vehicle.spec_cpAIWorker
    end

    return nil
end

---Get available work types for Courseplay (informational)
---@return table workTypes List of work type names
function CPIntegration:getWorkTypes()
    return {
        "fieldwork",    -- General field work
        "harvest",      -- Combine harvesting
        "bale_finder",  -- Bale collection
        "combine_unloader", -- Unload combines
        "silo_loader",  -- Silo loading
        "bunker_silo"   -- Bunker silo compacting
    }
end
