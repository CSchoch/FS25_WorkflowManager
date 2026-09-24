--[[
    WorkflowManager - Courseplay Vehicles Loader
    Loads vehicles that are compatible with Courseplay

    Accesses vehicle information through g_currentMission.vehicles
    and filters for Courseplay-compatible vehicles

    Author: WorkflowManager Team
]]

---@class CPVehiclesLoader
CPVehiclesLoader = {}

CPVehiclesLoader.isInitialized = false
CPVehiclesLoader.vehicles = {}
CPVehiclesLoader.lastScanTime = 0
CPVehiclesLoader.scanInterval = 2000  -- Rescan every 2 seconds (only when GUI is open)
CPVehiclesLoader.guiIsOpen = false  -- Only scan when GUI is open

---Initialize the vehicles loader
function CPVehiclesLoader:init()
    self.isInitialized = true
    self.vehicles = {}
    self.lastScanTime = 0
    self.guiIsOpen = false

    -- NOTE: Do NOT scan on init - only scan when GUI is opened
    -- Scanning on init can interfere with Courseplay's internal state
    -- and cause errors in CpCourseManager.lua
end

---Scan for Courseplay-compatible vehicles
function CPVehiclesLoader:scanVehicles()
    self.vehicles = {}

    -- Check if mission is available
    if not g_currentMission then
        WMLogger:debug("g_currentMission not available yet")
        return
    end

    -- FS25 uses vehicleSystem.vehicles or direct vehicles table
    local missionVehicles = g_currentMission.vehicles
    if not missionVehicles and g_currentMission.vehicleSystem then
        missionVehicles = g_currentMission.vehicleSystem.vehicles
    end

    if not missionVehicles then
        WMLogger:debug("No vehicles table found in mission (vehicles=%s, vehicleSystem=%s)",
            tostring(g_currentMission.vehicles ~= nil),
            tostring(g_currentMission.vehicleSystem ~= nil))
        return
    end

    -- Count vehicles in table
    local vehicleCount = 0
    for _ in pairs(missionVehicles) do
        vehicleCount = vehicleCount + 1
    end

    if vehicleCount == 0 then
        WMLogger:debug("Mission vehicles table is empty")
        return
    end

    -- Only log on first scan or if count changed
    if not self.lastVehicleCount or self.lastVehicleCount ~= vehicleCount then
        WMLogger:debug("Scanning %d vehicles in mission", vehicleCount)
        self.lastVehicleCount = vehicleCount
    end

    -- Try to get vehicles from Courseplay API first
    local vehicles = self:getVehiclesFromCourseplayAPI()

    -- Fallback: scan g_currentMission.vehicles
    if not vehicles or #vehicles == 0 then
        vehicles = self:getVehiclesFromMission()
    end

    if vehicles and #vehicles > 0 then
        self.vehicles = vehicles
        -- Only log if count changed
        if not self.lastCompatibleCount or self.lastCompatibleCount ~= #self.vehicles then
            WMLogger:debug("Found %d AD+CP compatible vehicles", #self.vehicles)
            self.lastCompatibleCount = #self.vehicles
        end
    end
end

---Get vehicles from Courseplay API
---@return table|nil vehicles List of vehicle info or nil
function CPVehiclesLoader:getVehiclesFromCourseplayAPI()
    -- Get Courseplay object
    local courseplay = self:getCourseplayObject()
    if not courseplay then
        return nil
    end

    local vehicles = nil

    -- Try different API patterns
    -- Pattern 1: vehicleManager property
    if courseplay.vehicleManager then
        vehicles = self:extractVehiclesFromManager(courseplay.vehicleManager)
    end

    -- Pattern 2: getVehicles() method
    if not vehicles and type(courseplay.getVehicles) == "function" then
        local result = courseplay:getVehicles()
        if result then
            vehicles = self:extractVehiclesFromTable(result)
        end
    end

    -- Pattern 3: getAllVehicles() method
    if not vehicles and type(courseplay.getAllVehicles) == "function" then
        local result = courseplay:getAllVehicles()
        if result then
            vehicles = self:extractVehiclesFromTable(result)
        end
    end

    -- Pattern 4: vehicles property
    if not vehicles and courseplay.vehicles then
        vehicles = self:extractVehiclesFromTable(courseplay.vehicles)
    end

    return vehicles
end

---Get vehicles from g_currentMission.vehicles
---@return table vehicles List of vehicle info
function CPVehiclesLoader:getVehiclesFromMission()
    local vehicles = {}

    -- Get vehicles table (FS25 may use vehicleSystem)
    local missionVehicles = g_currentMission.vehicles
    if not missionVehicles and g_currentMission.vehicleSystem then
        missionVehicles = g_currentMission.vehicleSystem.vehicles
    end

    if not missionVehicles then
        return vehicles
    end

    local totalCount = 0
    local includedCount = 0
    for _, vehicle in pairs(missionVehicles) do
        totalCount = totalCount + 1
        local vehicleInfo = self:createVehicleInfo(vehicle)
        if vehicleInfo then
            -- Only include vehicles with BOTH AutoDrive AND Courseplay support
            if vehicleInfo.hasAD and vehicleInfo.hasCP then
                table.insert(vehicles, vehicleInfo)
                includedCount = includedCount + 1
            end
        end
    end


    -- Sort by name
    table.sort(vehicles, function(a, b)
        return a.name < b.name
    end)

    return vehicles
end

---Create vehicle info object from a vehicle
---@param vehicle table Vehicle object
---@return table|nil vehicleInfo Vehicle info or nil
function CPVehiclesLoader:createVehicleInfo(vehicle)
    if not vehicle then
        return nil
    end

    -- Check for AutoDrive and Courseplay support
    -- FS25: AD uses vehicle.ad, CP uses spec_cpAIWorker or similar
    local hasAD = vehicle.ad ~= nil
    local hasCP = false

    -- Check for Courseplay support via multiple patterns
    if CPIntegration and CPIntegration.hasSpec then
        hasCP = CPIntegration:hasSpec(vehicle)
    end

    -- Fallback: check for CP-related specs directly
    if not hasCP then
        hasCP = vehicle.spec_cpAIWorker ~= nil or
                vehicle.spec_cpAIFieldWorker ~= nil or
                vehicle.spec_cpCourseManager ~= nil or
                (vehicle.getCpDriveStrategy ~= nil)
    end

    -- Get vehicle name
    local name = "Unknown Vehicle"
    if vehicle.getName then
        name = vehicle:getName()
    elseif vehicle.name then
        name = vehicle.name
    end


    -- Get current course name if available
    local currentCourse = nil
    if hasCP and CPIntegration and CPIntegration.getCurrentCourseName then
        currentCourse = CPIntegration:getCurrentCourseName(vehicle)
    end

    return {
        vehicle = vehicle,
        name = name,
        hasAD = hasAD,
        hasCP = hasCP,
        currentCourse = currentCourse,
        isActive = hasCP and CPIntegration and CPIntegration:isRunning(vehicle) or false
    }
end

---Get the Courseplay global object
---@return table|nil courseplay Courseplay global object or nil
function CPVehiclesLoader:getCourseplayObject()
    -- Check if Courseplay integration is available
    if not CPIntegration or not CPIntegration.isAvailable then
        return nil
    end

    -- Try to get the Courseplay global object
    local courseplay = g_Courseplay
    if not courseplay then
        local fs25CP = FS25_Courseplay
        courseplay = fs25CP and (fs25CP.g_Courseplay or fs25CP.Courseplay)
    end

    return courseplay
end

---Extract vehicles from a vehicle manager object
---@param manager table Vehicle manager object
---@return table|nil vehicles List of vehicle info or nil
function CPVehiclesLoader:extractVehiclesFromManager(manager)
    if not manager then
        return nil
    end

    -- Try common patterns for manager objects
    if type(manager.getVehicles) == "function" then
        local result = manager:getVehicles()
        if result then
            return self:extractVehiclesFromTable(result)
        end
    end

    if type(manager.getAll) == "function" then
        local result = manager:getAll()
        if result then
            return self:extractVehiclesFromTable(result)
        end
    end

    if manager.vehicles then
        return self:extractVehiclesFromTable(manager.vehicles)
    end

    return nil
end

---Extract vehicle info from a table/array of vehicles
---@param vehiclesTable table Table containing vehicle data
---@return table|nil vehicles List of vehicle info or nil
function CPVehiclesLoader:extractVehiclesFromTable(vehiclesTable)
    if not vehiclesTable or type(vehiclesTable) ~= "table" then
        return nil
    end

    local vehicles = {}

    for _, vehicle in pairs(vehiclesTable) do
        local vehicleInfo = self:createVehicleInfo(vehicle)
        if vehicleInfo and (vehicleInfo.hasCP or vehicleInfo.hasAD) then
            table.insert(vehicles, vehicleInfo)
        end
    end

    -- Sort by name
    if #vehicles > 0 then
        table.sort(vehicles, function(a, b)
            return a.name < b.name
        end)
        return vehicles
    end

    return nil
end

---Update function - periodically rescan for new vehicles (only when GUI is open)
---@param dt number Delta time in milliseconds
function CPVehiclesLoader:update(dt)
    if not self.isInitialized then
        return
    end

    -- Only scan when GUI is open to avoid interfering with Courseplay's internal state
    if not self.guiIsOpen then
        return
    end

    self.lastScanTime = self.lastScanTime + dt

    if self.lastScanTime >= self.scanInterval then
        self.lastScanTime = 0
        self:scanVehicles()
    end
end

---Set whether the GUI is open (controls automatic scanning)
---@param isOpen boolean
function CPVehiclesLoader:setGuiOpen(isOpen)
    self.guiIsOpen = isOpen
    -- Do an immediate scan when GUI opens
    if isOpen then
        self:scanVehicles()
    end
end

---Get list of available vehicles
---@return table vehicles List of vehicle info objects
function CPVehiclesLoader:getVehicles()
    return self.vehicles or {}
end

---Get number of available vehicles
---@return number count Number of vehicles
function CPVehiclesLoader:getVehiclesCount()
    return #(self.vehicles or {})
end

---Find vehicle by name
---@param vehicleName string Vehicle name to find
---@return table|nil vehicleInfo Vehicle info or nil
function CPVehiclesLoader:findVehicleByName(vehicleName)
    for _, vehicleInfo in ipairs(self.vehicles or {}) do
        if vehicleInfo.name == vehicleName then
            return vehicleInfo
        end
    end
    return nil
end

---Get vehicle names as a list
---@return table names List of vehicle names
function CPVehiclesLoader:getVehicleNames()
    local names = {}
    for _, vehicleInfo in ipairs(self.vehicles or {}) do
        table.insert(names, vehicleInfo.name)
    end
    return names
end

---Get vehicles with Courseplay support only
---@return table vehicles List of CP-compatible vehicle info
function CPVehiclesLoader:getCPVehicles()
    local cpVehicles = {}
    for _, vehicleInfo in ipairs(self.vehicles or {}) do
        if vehicleInfo.hasCP then
            table.insert(cpVehicles, vehicleInfo)
        end
    end
    return cpVehicles
end

---Get vehicles with AutoDrive support only
---@return table vehicles List of AD-compatible vehicle info
function CPVehiclesLoader:getADVehicles()
    local adVehicles = {}
    for _, vehicleInfo in ipairs(self.vehicles or {}) do
        if vehicleInfo.hasAD then
            table.insert(adVehicles, vehicleInfo)
        end
    end
    return adVehicles
end
