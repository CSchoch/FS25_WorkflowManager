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
CPIntegration.checkAttempts = 0
CPIntegration.maxCheckAttempts = 10
CPIntegration.checkInterval = 1000  -- ms between retry attempts
CPIntegration.timeSinceLastCheck = 0

---Initialize the Courseplay integration
function CPIntegration:init()
    self.checkAttempts = 0
    self.timeSinceLastCheck = 0

    -- Check if Courseplay is loaded
    self.isAvailable = self:checkAvailability()

    if self.isAvailable then
        self:completeInitialization()
    else
        WMLogger:info("Courseplay integration initialized - Courseplay not yet available, will retry")
    end

    self.isInitialized = true
end

---Complete initialization when Courseplay becomes available
function CPIntegration:completeInitialization()
    WMLogger:info("Courseplay integration initialized - Courseplay is available")
end

---Update function - checks for Courseplay availability if not yet found
---@param dt number Delta time in milliseconds
function CPIntegration:update(dt)
    -- If already available, nothing to do
    if self.isAvailable then
        return
    end

    -- If we've exceeded max attempts, stop trying
    if self.checkAttempts >= self.maxCheckAttempts then
        -- Log once when we give up
        if self.checkAttempts == self.maxCheckAttempts then
            WMLogger:warning("Courseplay not found after %d attempts - giving up", self.maxCheckAttempts)
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
            WMLogger:debug("Courseplay check attempt %d/%d - not available yet",
                self.checkAttempts, self.maxCheckAttempts)
        end
    end
end

---Check if Courseplay mod is available
---@return boolean available True if Courseplay is loaded
function CPIntegration:checkAvailability()
    -- FS25 namespaces mod globals under FS25_<ModName>
    -- The actual g_Courseplay is at FS25_Courseplay.g_Courseplay
    local fs25CP = FS25_Courseplay
    local cpFromNamespace = fs25CP and (fs25CP.g_Courseplay or fs25CP.Courseplay)

    -- Check if loaded as mod (for retry logging)
    local modLoaded = false
    if g_modManager ~= nil then
        local cpMod = g_modManager:getModByName("FS25_Courseplay")
        if cpMod ~= nil then
            modLoaded = true
        end
    end

    -- Debug: log what we find (only on retry attempts)
    if self.checkAttempts >= 1 and self.checkAttempts <= 3 then
        WMLogger:debug("Courseplay check #%d: FS25_Courseplay=%s, .g_Courseplay=%s, modLoaded=%s",
            self.checkAttempts,
            tostring(fs25CP ~= nil),
            tostring(cpFromNamespace ~= nil),
            tostring(modLoaded))
    end

    -- Check FS25 namespaced global (the only working method in FS25)
    if cpFromNamespace then
        WMLogger:info("Courseplay detected via FS25_Courseplay namespace!")
        -- Store reference globally for convenience
        g_Courseplay = cpFromNamespace
        return true
    end

    -- If mod is loaded but globals not yet available, keep trying
    if modLoaded and self.checkAttempts <= self.maxCheckAttempts then
        WMLogger:debug("Courseplay mod loaded but globals not yet available")
    end

    return false
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

---Load a course onto a vehicle by name
---@param vehicle table Vehicle to load course onto
---@param courseName string Course name (may include folder path like "Folder/CourseName")
---@return boolean success True if course was loaded
function CPIntegration:loadCourse(vehicle, courseName)
    if not self.isAvailable then
        WMLogger:error("Cannot load course - Courseplay not available")
        return false
    end

    if vehicle == nil then
        WMLogger:error("Cannot load course - vehicle is nil")
        return false
    end

    if courseName == nil or courseName == "" then
        WMLogger:error("Cannot load course - course name is empty")
        return false
    end

    WMLogger:info("Loading Courseplay course: %s", courseName)

    -- Get Courseplay object
    local courseplay = g_Courseplay
    if not courseplay then
        local fs25CP = FS25_Courseplay
        courseplay = fs25CP and (fs25CP.g_Courseplay or fs25CP.Courseplay)
    end

    if not courseplay then
        WMLogger:error("Cannot load course - g_Courseplay not found")
        return false
    end

    -- Try to load via courseStorage (FileSystem pattern)
    if courseplay.courseStorage then
        local success = self:loadCourseFromStorage(vehicle, courseplay.courseStorage, courseName)
        if success then
            return true
        end
    end

    -- Try direct vehicle method if available
    if vehicle.loadCpCourse then
        WMLogger:debug("Trying vehicle:loadCpCourse('%s')", courseName)
        local success, err = pcall(vehicle.loadCpCourse, vehicle, courseName)
        if success then
            WMLogger:info("Course loaded via loadCpCourse")
            return true
        else
            WMLogger:debug("loadCpCourse failed: %s", tostring(err))
        end
    end

    -- Try setCpCourse method
    if vehicle.setCpCourse then
        WMLogger:debug("Trying vehicle:setCpCourse('%s')", courseName)
        local success, err = pcall(vehicle.setCpCourse, vehicle, courseName)
        if success then
            WMLogger:info("Course loaded via setCpCourse")
            return true
        else
            WMLogger:debug("setCpCourse failed: %s", tostring(err))
        end
    end

    WMLogger:error("Could not load course '%s' - no working API found", courseName)
    return false
end

---True if a directory entry represents a folder.
---Courseplay exposes this as either a boolean field, a method, or getIsDirectory()
---depending on the entry type, so all three shapes are handled.
---@param entry table|nil Directory entry
---@return boolean isDirectory
function CPIntegration:isDirectoryEntry(entry)
    if entry == nil then
        return false
    end
    local flag = entry.isDirectory
    if type(flag) == "function" then
        local ok, result = pcall(flag, entry)
        return ok and result == true
    end
    if type(flag) == "boolean" then
        return flag
    end
    if type(entry.getIsDirectory) == "function" then
        local ok, result = pcall(entry.getIsDirectory, entry)
        return ok and result == true
    end
    return false
end

---Get an entry's display name, or "" if it exposes none.
---@param entry table|nil Directory entry
---@return string name
function CPIntegration:getEntryName(entry)
    if entry == nil then
        return ""
    end
    return entry.name or (type(entry.getName) == "function" and entry:getName()) or ""
end

---Get the directory view for a folder entry.
---@param entry table Folder entry
---@return table view
function CPIntegration:getSubView(entry)
    if type(entry.getView) == "function" then
        return entry:getView()
    end
    return entry.directoryView or entry
end

---Get the entries of a directory view, or nil if it exposes none.
---@param view table|nil Directory view
---@return table|nil entries
function CPIntegration:getViewEntries(view)
    if view == nil or type(view.getEntries) ~= "function" then
        return nil
    end
    local success, entries = pcall(view.getEntries, view)
    if not success then
        return nil
    end
    return entries
end

---Find a non-folder entry with the given name directly inside a view (no recursion).
---@param view table|nil Directory view
---@param name string Entry name to match
---@return table|nil entry
function CPIntegration:findEntryByName(view, name)
    local entries = self:getViewEntries(view)
    if entries == nil then
        return nil
    end
    for _, entry in pairs(entries) do
        if not self:isDirectoryEntry(entry) and self:getEntryName(entry) == name then
            return entry
        end
    end
    return nil
end

---Depth-limited recursive search for a non-folder entry with the given name.
---@param view table|nil Directory view to search from
---@param name string Entry name to match
---@param depth number Current recursion depth
---@return table|nil entry
function CPIntegration:findEntryByNameRecursive(view, name, depth)
    if view == nil or depth > 10 then
        return nil
    end
    local entries = self:getViewEntries(view)
    if entries == nil then
        return nil
    end
    for _, entry in pairs(entries) do
        if self:isDirectoryEntry(entry) then
            local found = self:findEntryByNameRecursive(self:getSubView(entry), name, depth + 1)
            if found ~= nil then
                return found
            end
        elseif self:getEntryName(entry) == name then
            return entry
        end
    end
    return nil
end

---Locate a course entry, starting from the ROOT directory view.
---Course names are stored as root-relative paths ("Folder/Course"), so resolution must start
---at the root - see the note in loadCourseFromStorage about currentDirectoryView.
---Falls back to a recursive search by base name so names recorded before folder prefixes were
---captured from the root (and courses since moved between folders) still resolve.
---@param rootView table  Root directory view
---@param folderPath string Folder path ("" for root level)
---@param baseName string Course file name without folder path
---@return table|nil entry
function CPIntegration:findCourseEntry(rootView, folderPath, baseName)
    if folderPath ~= "" then
        local folderView = self:navigateToFolder(rootView, folderPath)
        local entry = self:findEntryByName(folderView, baseName)
        if entry ~= nil then
            return entry
        end
        WMLogger:debug("Course '%s' not found in folder '%s' - searching all folders", baseName, folderPath)
    else
        local entry = self:findEntryByName(rootView, baseName)
        if entry ~= nil then
            return entry
        end
        WMLogger:debug("Course '%s' not found at root level - searching all folders", baseName)
    end

    return self:findEntryByNameRecursive(rootView, baseName, 0)
end

---Load a course from the Courseplay file storage
---@param vehicle table Vehicle to load course onto
---@param storage table Courseplay courseStorage object
---@param courseName string Course name to find and load
---@return boolean success True if loaded
function CPIntegration:loadCourseFromStorage(vehicle, storage, courseName)
    if not storage then
        return false
    end

    -- Extract folder path and course name from "Folder/CourseName" format
    local folderPath, baseName = "", courseName
    local lastSlash = courseName:match(".*/()")
    if lastSlash then
        folderPath = courseName:sub(1, lastSlash - 2)
        baseName = courseName:sub(lastSlash)
    end

    WMLogger:debug("Looking for course - folder: '%s', name: '%s'", folderPath, baseName)

    -- Resolve from the ROOT view, never currentDirectoryView: the latter follows whatever
    -- folder the player last opened in Courseplay's own course manager, so a stored path like
    -- "Farm1/Course" would be looked up relative to that folder and fail. Same reasoning as
    -- CPCoursesLoader:extractCoursesFromFileSystem, which records these names.
    local rootView = storage.rootDirectoryView or storage.currentDirectoryView
    if not rootView then
        return false
    end

    local entry = self:findCourseEntry(rootView, folderPath, baseName)
    if entry == nil then
        WMLogger:debug("Course entry not found: '%s'", courseName)
        return false
    end

    return self:tryLoadEntry(vehicle, entry)
end

---Try every known Courseplay API for loading a located course entry onto a vehicle.
---NOTE: these branches treat "the call did not raise" as success; the caller
---(WMExecutor:startCourseplayStep) re-checks hasCourse() afterwards to catch a no-op.
---@param vehicle table Vehicle to load course onto
---@param entry table Located course entry
---@return boolean success
function CPIntegration:tryLoadEntry(vehicle, entry)
    WMLogger:debug("Found course entry: %s", self:getEntryName(entry))

    -- Log available methods/properties on entry for debugging
    WMLogger:debug("Entry properties:")
    for key, value in pairs(entry) do
        local valueType = type(value)
        if valueType == "function" then
            WMLogger:debug("  %s: <function>", tostring(key))
        elseif valueType == "table" then
            WMLogger:debug("  %s: <table>", tostring(key))
        else
            WMLogger:debug("  %s: %s", tostring(key), tostring(value))
        end
    end

    -- Try entry:load(vehicle) pattern
    if type(entry.load) == "function" then
        WMLogger:debug("Trying entry:load(vehicle)")
        local loadSuccess, loadErr = pcall(entry.load, entry, vehicle)
        if loadSuccess then
            WMLogger:info("Course loaded via entry:load()")
            return true
        else
            WMLogger:debug("entry:load failed: %s", tostring(loadErr))
        end
    end

    -- Try entry:loadCourse(vehicle) pattern
    if type(entry.loadCourse) == "function" then
        WMLogger:debug("Trying entry:loadCourse(vehicle)")
        local loadSuccess, loadErr = pcall(entry.loadCourse, entry, vehicle)
        if loadSuccess then
            WMLogger:info("Course loaded via entry:loadCourse()")
            return true
        else
            WMLogger:debug("entry:loadCourse failed: %s", tostring(loadErr))
        end
    end

    -- Try vehicle methods with entry
    if vehicle.loadCpCourseFromFile then
        WMLogger:debug("Trying vehicle:loadCpCourseFromFile(entry)")
        local loadSuccess, loadErr = pcall(vehicle.loadCpCourseFromFile, vehicle, entry)
        if loadSuccess then
            WMLogger:info("Course loaded via loadCpCourseFromFile")
            return true
        else
            WMLogger:debug("loadCpCourseFromFile failed: %s", tostring(loadErr))
        end
    end

    -- Try vehicle:loadCourse(entry) pattern
    if vehicle.loadCourse then
        WMLogger:debug("Trying vehicle:loadCourse(entry)")
        local loadSuccess, loadErr = pcall(vehicle.loadCourse, vehicle, entry)
        if loadSuccess then
            WMLogger:info("Course loaded via vehicle:loadCourse(entry)")
            return true
        else
            WMLogger:debug("vehicle:loadCourse failed: %s", tostring(loadErr))
        end
    end

    -- Try spec_cpCourseManager if available
    if vehicle.spec_cpCourseManager then
        WMLogger:debug("Vehicle has spec_cpCourseManager")
        local courseManager = vehicle.spec_cpCourseManager
        if courseManager.loadCourse then
            WMLogger:debug("Trying courseManager:loadCourse(entry)")
            local loadSuccess, loadErr = pcall(courseManager.loadCourse, courseManager, entry)
            if loadSuccess then
                WMLogger:info("Course loaded via spec_cpCourseManager:loadCourse")
                return true
            else
                WMLogger:debug("courseManager:loadCourse failed: %s", tostring(loadErr))
            end
        end
        if courseManager.setCourse then
            WMLogger:debug("Trying courseManager:setCourse(entry)")
            local loadSuccess, loadErr = pcall(courseManager.setCourse, courseManager, entry)
            if loadSuccess then
                WMLogger:info("Course loaded via spec_cpCourseManager:setCourse")
                return true
            else
                WMLogger:debug("courseManager:setCourse failed: %s", tostring(loadErr))
            end
        end
    end

    -- Try with course data if entry has it
    if entry.course or entry.waypoints then
        local courseData = entry.course or entry
        if vehicle.setCpFieldWorkCourse then
            WMLogger:debug("Trying vehicle:setCpFieldWorkCourse(courseData)")
            local loadSuccess = pcall(vehicle.setCpFieldWorkCourse, vehicle, courseData)
            if loadSuccess then
                WMLogger:info("Course loaded via setCpFieldWorkCourse")
                return true
            end
        end
    end

    -- Try using entry.entity (the File object)
    -- The correct API is vehicle:appendLoadedCpCourse(file) as used by CpCourseManagerFrame
    if entry.entity then
        WMLogger:debug("Entry has 'entity' property (File object)")
        local entity = entry.entity

        -- The proper Courseplay API: vehicle:appendLoadedCpCourse(file)
        -- This is how CpCourseManagerFrame loads courses
        if vehicle.appendLoadedCpCourse then
            WMLogger:debug("Trying vehicle:appendLoadedCpCourse(entity)")
            local loadSuccess, loadErr = pcall(vehicle.appendLoadedCpCourse, vehicle, entity)
            if loadSuccess then
                WMLogger:info("Course loaded via appendLoadedCpCourse()")
                return true
            else
                WMLogger:debug("appendLoadedCpCourse failed: %s", tostring(loadErr))
            end
        end

        -- Fallback: Try vehicle methods with entity
        if vehicle.setCpFieldWorkCourse then
            WMLogger:debug("Trying vehicle:setCpFieldWorkCourse(entity)")
            local loadSuccess, loadErr = pcall(vehicle.setCpFieldWorkCourse, vehicle, entity)
            if loadSuccess then
                WMLogger:info("Course loaded via setCpFieldWorkCourse(entity)")
                return true
            else
                WMLogger:debug("setCpFieldWorkCourse(entity) failed: %s", tostring(loadErr))
            end
        end
    end

    return false
end

---Navigate to a folder in the DirectoryView
---@param directoryView table Starting directory view
---@param folderPath string Path like "Folder1/Folder2"
---@return table|nil targetView The target directory view or nil
function CPIntegration:navigateToFolder(directoryView, folderPath)
    local current = directoryView
    local parts = {}

    for part in folderPath:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    for _, folderName in ipairs(parts) do
        local entries = self:getViewEntries(current)
        if entries == nil then
            return nil
        end

        local found = false
        for _, entry in pairs(entries) do
            if self:getEntryName(entry) == folderName and self:isDirectoryEntry(entry) then
                current = self:getSubView(entry)
                found = true
                break
            end
        end

        if not found then
            return nil
        end
    end

    return current
end

---Start Courseplay field work for a vehicle
---Uses the actual FS25 CP API: startCpAtLastWp() or startCpAtFirstWp()
---@param vehicle table Vehicle to control
---@param startAtFirst boolean|nil If true, start at first waypoint (default: last)
---@param startAtNearest boolean|nil If true, start at nearest waypoint (for resume from save)
---@return boolean success True if started successfully
function CPIntegration:startFieldWork(vehicle, startAtFirst, startAtNearest)
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

    -- Resume from save: start at nearest waypoint
    if startAtNearest and vehicle.cpStartStopDriver then
        WMLogger:info("Starting Courseplay field work at nearest waypoint (resume)")
        vehicle:cpStartStopDriver(false)
        WMLogger:stateChange("Courseplay", nil, "started (nearest wp)")
        return true
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

    -- Check if actually running (use pcall as vehicle may be in bad state during shutdown)
    local isRunningOk, isRunning = pcall(self.isRunning, self, vehicle)
    if not isRunningOk then
        WMLogger:warning("Error checking Courseplay running state: %s", tostring(isRunning))
        return false
    end

    if not isRunning then
        WMLogger:debug("Courseplay is not running, nothing to stop")
        return true
    end

    WMLogger:info("Stopping Courseplay")
    WMLogger:apiCall("Courseplay", "stopCurrentAIJob", vehicle)

    -- Use the official stop method (wrapped in pcall for shutdown safety)
    if vehicle.stopCurrentAIJob then
        -- Need to pass a message - use the standard stopped by user message
        local AIMessageSuccessStoppedByUser = AIMessageSuccessStoppedByUser or
            (g_currentMission and g_currentMission.aiMessageManager and
             g_currentMission.aiMessageManager.aiMessages and
             g_currentMission.aiMessageManager.aiMessages.AIMessageSuccessStoppedByUser)

        if AIMessageSuccessStoppedByUser and AIMessageSuccessStoppedByUser.new then
            local stopOk, stopErr = pcall(vehicle.stopCurrentAIJob, vehicle, AIMessageSuccessStoppedByUser.new())
            if stopOk then
                WMLogger:stateChange("Courseplay", "running", "stopped")
                return true
            else
                WMLogger:warning("Error stopping Courseplay via stopCurrentAIJob: %s", tostring(stopErr))
            end
        end
    end

    -- Alternative: use cpStartStopDriver to toggle off
    if vehicle.cpStartStopDriver then
        local toggleOk, toggleErr = pcall(vehicle.cpStartStopDriver, vehicle, false)
        if toggleOk then
            WMLogger:stateChange("Courseplay", "running", "stopped")
            return true
        else
            WMLogger:warning("Error stopping Courseplay via cpStartStopDriver: %s", tostring(toggleErr))
        end
    end

    return false
end

---Check if the CP AI worker driver is initialized (required before freeze/unfreeze)
---@param vehicle table Vehicle to check
---@return boolean hasDriver True if driver object exists
function CPIntegration:hasActiveDriver(vehicle)
    local spec = vehicle.spec_cpAIWorker
    return spec ~= nil and spec.driver ~= nil
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

    -- Only freeze if CP is actually running
    if not self:isRunning(vehicle) then
        WMLogger:debug("holdCourse: CP not running, skipping freeze")
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

    -- Only unfreeze if CP has the unfreeze method (it may not be frozen if CP was just started)
    if not vehicle.unfreezeCp then
        WMLogger:debug("resumeCourse: unfreezeCp not available, skipping")
        return false
    end

    WMLogger:info("Resuming Courseplay")
    WMLogger:apiCall("Courseplay", "unfreezeCp", vehicle)
    vehicle:unfreezeCp()
    WMLogger:stateChange("Courseplay", "frozen", "running")
    return true
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
        local ok, progress = pcall(vehicle.getCpFieldWorkProgress, vehicle)
        if ok and type(progress) == "number" then
            return progress
        end
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
