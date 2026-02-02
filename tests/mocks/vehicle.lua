--[[
    Vehicle Mock Factory
    Creates mock vehicle objects for testing
]]

---@class VehicleMock
VehicleMock = {}

---Create a valid vehicle with both AutoDrive and Courseplay support
---@param name string|nil Vehicle name
---@return table vehicle Mock vehicle object
function VehicleMock.createValid(name)
    local vehicle = {
        _name = name or "TestTractor",
        _isADActive = false,
        _isCPActive = false,
        _hasCourse = false,
        _courseName = nil,

        -- AutoDrive spec
        ad = {
            stateModule = {
                isActive = function(self)
                    return vehicle._isADActive
                end,
                setActive = function(self, active)
                    vehicle._isADActive = active
                end,
                setStartHelper = function(self, enabled)
                    vehicle._startCPOnCompletion = enabled
                end
            }
        },

        -- Courseplay specs
        spec_cpAIWorker = {
            -- CP AI worker spec present
        },
        spec_cpAIFieldWorker = {
            -- CP field worker spec present
        },

        -- Vehicle name getter
        getName = function(self)
            return self._name
        end,

        -- Courseplay methods
        getIsCpActive = function(self)
            return self._isCPActive
        end,
        hasCpCourse = function(self)
            return self._hasCourse
        end,
        appendLoadedCpCourse = function(self, entity)
            self._hasCourse = true
            return true
        end,
        startCpAtLastWp = function(self)
            self._isCPActive = true
            return true
        end,
        startCpAtFirstWp = function(self)
            self._isCPActive = true
            return true
        end,

        -- AutoDrive methods
        stopAutoDrive = function(self)
            self._isADActive = false
        end
    }

    return vehicle
end

---Create a vehicle with only AutoDrive support (no Courseplay)
---@param name string|nil Vehicle name
---@return table vehicle Mock vehicle object
function VehicleMock.createADOnly(name)
    local vehicle = {
        _name = name or "ADOnlyTractor",
        _isADActive = false,

        -- AutoDrive spec only
        ad = {
            stateModule = {
                isActive = function(self)
                    return vehicle._isADActive
                end,
                setActive = function(self, active)
                    vehicle._isADActive = active
                end
            }
        },

        getName = function(self)
            return self._name
        end,

        stopAutoDrive = function(self)
            self._isADActive = false
        end
    }

    return vehicle
end

---Create a vehicle with only Courseplay support (no AutoDrive)
---@param name string|nil Vehicle name
---@return table vehicle Mock vehicle object
function VehicleMock.createCPOnly(name)
    local vehicle = {
        _name = name or "CPOnlyTractor",
        _isCPActive = false,
        _hasCourse = false,

        -- Courseplay specs only
        spec_cpAIWorker = {},

        getName = function(self)
            return self._name
        end,

        getIsCpActive = function(self)
            return self._isCPActive
        end,
        hasCpCourse = function(self)
            return self._hasCourse
        end
    }

    return vehicle
end

---Create a vehicle with no automation support
---@param name string|nil Vehicle name
---@return table vehicle Mock vehicle object
function VehicleMock.createBasic(name)
    local vehicle = {
        _name = name or "BasicTractor",

        getName = function(self)
            return self._name
        end
    }

    return vehicle
end

---Create a nil vehicle (for edge case testing)
---@return nil
function VehicleMock.createNil()
    return nil
end

---Set the controlled vehicle in g_currentMission
---@param vehicle table|nil Vehicle to set
function VehicleMock.setControlledVehicle(vehicle)
    _G.g_currentMission.controlledVehicle = vehicle

    -- Also update g_localPlayer
    _G.g_localPlayer.getCurrentVehicle = function(self)
        return vehicle
    end
end

---Clear the controlled vehicle
function VehicleMock.clearControlledVehicle()
    _G.g_currentMission.controlledVehicle = nil
    _G.g_localPlayer.getCurrentVehicle = function(self)
        return nil
    end
end

print("[Mock] VehicleMock loaded")
