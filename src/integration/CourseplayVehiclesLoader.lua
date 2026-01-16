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
CPVehiclesLoader.scanInterval = 2000  -- Rescan every 2 seconds

---Initialize the vehicles loader
function CPVehiclesLoader:init()
    self.isInitialized = true
    self.vehicles = {}
    self.lastScanTime = 0

    -- Do initial scan
    self:scanVehicles()
end

---Scan for Courseplay-compatible vehicles
function CPVehiclesLoader:scanVehicles()
    self.vehicles = {}

    -- Check if mission is available
    if not g_currentMission or not g_currentMission.vehicles then
        WMLogger:debug("Mission not available yet, cannot load vehicles")
        return
    end

    -- Try to get vehicles from Courseplay API first
    local vehicles = self:getVehiclesFromCourseplayAPI()

    -- Fallback: scan g_currentMission.vehicles
    if not vehicles or #vehicles == 0 then
        vehicles = self:getVehiclesFromMission()
    end

    if vehicles and #vehicles > 0 then
        self.vehicles = vehicles
        WMLogger:info("Loaded %d Courseplay-compatible vehicle(s)", #self.vehicles)

        -- Log first few vehicles for debugging
        if WMDevConfig and WMDevConfig:isDevMode() then
            for i = 1, math.min(3, #self.vehicles) do
                WMLogger:debug("Vehicle %d: %s (hasAD=%s, hasCP=%s)",
                    i,
                    self.vehicles[i].name,
                    tostring(self.vehicles[i].hasAD),
                    tostring(self.vehicles[i].hasCP))
            end
        end
    else
        WMLogger:debug("No Courseplay-compatible vehicles found")
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
        local success, result = pcall(courseplay.getVehicles, courseplay)
        if success and result then
            vehicles = self:extractVehiclesFromTable(result)
        end
    end

    -- Pattern 3: getAllVehicles() method
    if not vehicles and type(courseplay.getAllVehicles) == "function" then
        local success, result = pcall(courseplay.getAllVehicles, courseplay)
        if success and result then
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

    for _, vehicle in ipairs(g_currentMission.vehicles) do
        local vehicleInfo = self:createVehicleInfo(vehicle)
        if vehicleInfo and (vehicleInfo.hasCP or vehicleInfo.hasAD) then
            table.insert(vehicles, vehicleInfo)
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
    local hasAD = vehicle.ad ~= nil
    local hasCP = CPIntegration and CPIntegration:hasSpec(vehicle)

    -- Get vehicle name
    local name = "Unknown Vehicle"
    if vehicle.getName then
        name = vehicle:getName()
    elseif vehicle.name then
        name = vehicle.name
    end

    -- Get current course name if available
    local currentCourse = nil
    if hasCP and CPIntegration and CPIntegration:getCurrentCourseName then
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
        local success, result = pcall(manager.getVehicles, manager)
        if success and result then
            return self:extractVehiclesFromTable(result)
        end
    end

    if type(manager.getAll) == "function" then
        local success, result = pcall(manager.getAll, manager)
        if success and result then
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

---Update function - periodically rescan for new vehicles
---@param dt number Delta time in milliseconds
function CPVehiclesLoader:update(dt)
    if not self.isInitialized then
        return
    end

    self.lastScanTime = self.lastScanTime + dt

    if self.lastScanTime >= self.scanInterval then
        self.lastScanTime = 0
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
