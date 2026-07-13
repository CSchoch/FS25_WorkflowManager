--[[
    ADIntegration Unit Tests: AD "Park"/"Refuel"/"Repair" resolution and route start
    Covers getRearAttachedObject, getObjectParkDestination, getVehicleParkDestinationId,
    startParkRoute, startRefuelRoute, and startRepairRoute (Park/Refuel/Repair WM step types).
]]

describe("ADIntegration (park position)", function()

    setup(function()
        -- Fresh AD availability/marker mocks for these tests
        _G.ADGraphManager = {
            _markers = { [10] = { id = 10, name = "ParkSpotA" } },
            getMapMarkerById = function(self, id)
                return self._markers[id]
            end,
        }

        -- Production calls this via colon syntax (AutoDrive:StartDriving(...)), which
        -- implicitly passes AutoDrive itself as the first (self) argument - define with
        -- a leading self param so the real explicit args land where the test expects.
        -- getClosestRepairTrigger is likewise called via colon syntax in production.
        _G.AutoDrive = {
            MODE_DRIVETO = 3,
            StartDriving = function(self, vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
                _G.__lastStartDrivingCall = {
                    vehicle = vehicle, destinationID = destinationID,
                    unloadDestinationID = unloadDestinationID,
                    callBackObject = callBackObject, callBackFunction = callBackFunction,
                    callBackArg = callBackArg,
                }
            end,
            getClosestRepairTrigger = function(self, vehicle)
                return _G.__repairTriggerResult
            end,
        }

        -- Called via dot syntax (ADTriggerManager.getClosestRefuelDestination(vehicle, ...)) in production.
        _G.ADTriggerManager = {
            getClosestRefuelDestination = function(vehicle, ignoreFillLevel)
                return _G.__refuelDestinationResult
            end,
        }

        dofile("src/integration/AutoDriveIntegration.lua")
    end)

    before_each(function()
        ADIntegration.isAvailable = true
        ADIntegration.pendingCallbacks = {}
        _G.__lastStartDrivingCall = nil
        _G.__refuelDestinationResult = nil
        _G.__repairTriggerResult = nil
        _G.ADGraphManager._markers = { [10] = { id = 10, name = "ParkSpotA" } }
    end)

    -- Build a vehicle with an AD state module and (optionally) a rear-attached implement
    local function makeVehicle(opts)
        opts = opts or {}
        local vehicle  -- declared first so stateModule closures capture it as an upvalue (Lua 5.1)
        vehicle = {
            _active = false,
            advd = opts.vehicleParkId ~= nil and { parkDestination = opts.vehicleParkId } or nil,
            ad = {
                stateModule = {
                    isActive = function(self) return vehicle._active end,
                    setParkDestinationAtJobFinished = function(self, id)
                        vehicle._parkDestinationAtJobFinished = id
                    end,
                    setMode = function(self, mode)
                        vehicle._mode = mode
                    end,
                },
            },
            getAttachedImplements = function(self)
                if opts.rearParkId == nil and not opts.hasEmptyImplementList then
                    return {}
                end
                return { { object = { advd = { parkDestination = opts.rearParkId } } } }
            end,
            startAutoDrive = function(self)
                vehicle._startAutoDriveCalled = true
            end,
        }
        return vehicle
    end

    -- =========================================================================
    -- getRearAttachedObject
    -- =========================================================================
    describe("getRearAttachedObject", function()
        it("returns nil when vehicle is nil", function()
            assert.is_nil(ADIntegration:getRearAttachedObject(nil))
        end)

        it("returns nil when vehicle has no getAttachedImplements method", function()
            assert.is_nil(ADIntegration:getRearAttachedObject({}))
        end)

        it("returns nil when no implements are attached", function()
            local v = makeVehicle({})
            assert.is_nil(ADIntegration:getRearAttachedObject(v))
        end)

        it("returns the first attached implement's object", function()
            local v = makeVehicle({ rearParkId = 10 })
            local obj = ADIntegration:getRearAttachedObject(v)
            assert.is_not_nil(obj)
            assert.are.equal(10, obj.advd.parkDestination)
        end)
    end)

    -- =========================================================================
    -- getObjectParkDestination
    -- =========================================================================
    describe("getObjectParkDestination", function()
        it("returns nil when obj is nil", function()
            assert.is_nil(ADIntegration:getObjectParkDestination(nil))
        end)

        it("returns nil when obj.advd is nil", function()
            assert.is_nil(ADIntegration:getObjectParkDestination({}))
        end)

        it("returns nil when parkDestination is unset (-1)", function()
            assert.is_nil(ADIntegration:getObjectParkDestination({ advd = { parkDestination = -1 } }))
        end)

        it("returns nil when the marker no longer exists (stale id)", function()
            assert.is_nil(ADIntegration:getObjectParkDestination({ advd = { parkDestination = 999 } }))
        end)

        it("returns the id when configured and the marker exists", function()
            assert.are.equal(10, ADIntegration:getObjectParkDestination({ advd = { parkDestination = 10 } }))
        end)
    end)

    -- =========================================================================
    -- getVehicleParkDestinationId
    -- =========================================================================
    describe("getVehicleParkDestinationId", function()
        it("prefers the rear-attached implement's park position over the vehicle's own", function()
            _G.ADGraphManager._markers[11] = { id = 11, name = "ParkSpotB" }
            local v = makeVehicle({ rearParkId = 10, vehicleParkId = 11 })
            assert.are.equal(10, ADIntegration:getVehicleParkDestinationId(v))
        end)

        it("falls back to the vehicle's own park position when the rear implement has none", function()
            local v = makeVehicle({ vehicleParkId = 10 })
            assert.are.equal(10, ADIntegration:getVehicleParkDestinationId(v))
        end)

        it("returns nil when neither the rear implement nor the vehicle has one configured", function()
            local v = makeVehicle({})
            assert.is_nil(ADIntegration:getVehicleParkDestinationId(v))
        end)
    end)

    -- =========================================================================
    -- startParkRoute
    -- =========================================================================
    describe("startParkRoute", function()
        it("returns false when AutoDrive is not available", function()
            ADIntegration.isAvailable = false
            local v = makeVehicle({ vehicleParkId = 10 })
            assert.is_false(ADIntegration:startParkRoute(v))
        end)

        it("returns false when vehicle is missing AutoDrive specialization", function()
            assert.is_false(ADIntegration:startParkRoute({}))
        end)

        it("returns false when no park position is configured", function()
            local v = makeVehicle({})
            assert.is_false(ADIntegration:startParkRoute(v))
        end)

        it("stops an already-running route before starting the park route", function()
            local v = makeVehicle({ vehicleParkId = 10 })
            v._active = true
            local stopped = false
            local origStop = ADIntegration.stopRoute
            ADIntegration.stopRoute = function(self, vehicle) stopped = true end
            ADIntegration:startParkRoute(v)
            ADIntegration.stopRoute = origStop
            assert.is_true(stopped)
        end)

        it("sets parkDestinationAtJobFinished and calls AutoDrive:StartDriving with -1, -3", function()
            local v = makeVehicle({ vehicleParkId = 10 })
            local success = ADIntegration:startParkRoute(v)
            assert.is_true(success)
            assert.are.equal(10, v._parkDestinationAtJobFinished)
            assert.is_not_nil(_G.__lastStartDrivingCall)
            assert.are.equal(v, _G.__lastStartDrivingCall.vehicle)
            assert.are.equal(-1, _G.__lastStartDrivingCall.destinationID)
            assert.are.equal(-3, _G.__lastStartDrivingCall.unloadDestinationID)
        end)

        it("prefers the rear-attached implement's park position over the vehicle's own", function()
            _G.ADGraphManager._markers[11] = { id = 11, name = "ParkSpotB" }
            local v = makeVehicle({ rearParkId = 10, vehicleParkId = 11 })
            ADIntegration:startParkRoute(v)
            assert.are.equal(10, v._parkDestinationAtJobFinished)
        end)
    end)

    -- =========================================================================
    -- startRefuelRoute
    -- =========================================================================
    describe("startRefuelRoute", function()
        it("returns false, false when AutoDrive is not available", function()
            ADIntegration.isAvailable = false
            local v = makeVehicle({})
            local success, skipped = ADIntegration:startRefuelRoute(v)
            assert.is_false(success)
            assert.is_false(skipped)
        end)

        it("returns false, false when vehicle is missing AutoDrive specialization", function()
            local success, skipped = ADIntegration:startRefuelRoute({})
            assert.is_false(success)
            assert.is_false(skipped)
        end)

        it("returns false, true (skip, not failure) when no station is reachable or already fueled", function()
            _G.__refuelDestinationResult = nil
            local v = makeVehicle({})
            local success, skipped = ADIntegration:startRefuelRoute(v)
            assert.is_false(success)
            assert.is_true(skipped)
        end)

        it("stops an already-running route before starting the refuel route", function()
            _G.__refuelDestinationResult = 20
            local v = makeVehicle({})
            v._active = true
            local stopped = false
            local origStop = ADIntegration.stopRoute
            ADIntegration.stopRoute = function(self, vehicle) stopped = true end
            ADIntegration:startRefuelRoute(v)
            ADIntegration.stopRoute = origStop
            assert.is_true(stopped)
        end)

        it("sets mode/onRouteToRefuel and calls AutoDrive:StartDriving with -1, -2", function()
            _G.__refuelDestinationResult = 20
            local v = makeVehicle({})
            local success, skipped = ADIntegration:startRefuelRoute(v)
            assert.is_true(success)
            assert.is_false(skipped)
            assert.are.equal(AutoDrive.MODE_DRIVETO, v._mode)
            assert.is_true(v.ad.onRouteToRefuel)
            assert.is_not_nil(_G.__lastStartDrivingCall)
            assert.are.equal(v, _G.__lastStartDrivingCall.vehicle)
            assert.are.equal(-1, _G.__lastStartDrivingCall.destinationID)
            assert.are.equal(-2, _G.__lastStartDrivingCall.unloadDestinationID)
        end)
    end)

    -- =========================================================================
    -- startRepairRoute
    -- =========================================================================
    describe("startRepairRoute", function()
        it("returns false when AutoDrive is not available", function()
            ADIntegration.isAvailable = false
            local v = makeVehicle({})
            assert.is_false(ADIntegration:startRepairRoute(v))
        end)

        it("returns false when vehicle is missing AutoDrive specialization", function()
            assert.is_false(ADIntegration:startRepairRoute({}))
        end)

        it("returns false when no repair station is reachable", function()
            _G.__repairTriggerResult = nil
            local v = makeVehicle({})
            assert.is_false(ADIntegration:startRepairRoute(v))
        end)

        it("stops an already-running route before starting the repair route", function()
            _G.__repairTriggerResult = { marker = 30 }
            local v = makeVehicle({})
            v._active = true
            local stopped = false
            local origStop = ADIntegration.stopRoute
            ADIntegration.stopRoute = function(self, vehicle) stopped = true end
            ADIntegration:startRepairRoute(v)
            ADIntegration.stopRoute = origStop
            assert.is_true(stopped)
        end)

        it("sets mode/onRouteToRepair and calls vehicle:startAutoDrive (no StartDriving sentinel exists)", function()
            _G.__repairTriggerResult = { marker = 30 }
            local v = makeVehicle({})
            local success = ADIntegration:startRepairRoute(v)
            assert.is_true(success)
            assert.are.equal(AutoDrive.MODE_DRIVETO, v._mode)
            assert.is_true(v.ad.onRouteToRepair)
            assert.is_true(v._startAutoDriveCalled)
        end)
    end)

end)
