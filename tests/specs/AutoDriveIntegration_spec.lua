--[[
    ADIntegration Unit Tests: AD "Park"/"Refuel"/"Repair" resolution and route start
    Covers getObjectParkDestination, getVehicleParkDestinationId, startParkRoute,
    startRefuelRoute, and startRepairRoute (Park/Refuel/Repair WM step types).
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
            StartDriving = function(self, vehicle, destinationID, unloadDestinationID)
                _G.__lastStartDrivingCall = {
                    vehicle = vehicle, destinationID = destinationID,
                    unloadDestinationID = unloadDestinationID,
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

        -- Optional geometry mocks for the "prefer the rear implement" tiebreak. Mock nodes
        -- carry a plain .z; worldToLocal reduces to (nodeZ - vehicle._zPos) for tests.
        _G.getWorldTranslation = function(node)
            return 0, 0, node.z or 0
        end
        _G.AutoDrive.worldToLocal = function(vehicle, _, _, z)
            return 0, 0, z - (vehicle._zPos or 0)
        end

        dofile("src/integration/AutoDriveIntegration.lua")
    end)

    before_each(function()
        ADIntegration.isAvailable = true
        _G.__lastStartDrivingCall = nil
        _G.__refuelDestinationResult = nil
        _G.__repairTriggerResult = nil
        _G.ADGraphManager._markers = { [10] = { id = 10, name = "ParkSpotA" } }
    end)

    -- Build a mock implement with an optional configured park destination (false = unconfigured,
    -- distinct from a nil array hole so ipairs can walk a list containing it) and an optional
    -- world z position (nil = no geometry data, matching a real implement with no components).
    local function makeImplement(parkId, z)
        local obj = { advd = { parkDestination = parkId ~= false and parkId or nil } }
        if z ~= nil then
            obj.components = { { node = { z = z } } }
        end
        return { object = obj }
    end

    -- Build a vehicle with an AD state module and (optionally) directly attached implements.
    -- opts.implementParkIds is an ordered list of park ids (or `false` for "no park id set")
    -- for successive attached implements, in the same order getAttachedImplements() returns -
    -- AD stores the configured park position on whichever object was selected when the user
    -- set it, so resolution must check every attached implement, not assume a fixed position.
    -- opts.implementZs is a parallel list of world z positions (rear = negative), only needed
    -- to exercise the "prefer the rear implement" tiebreak.
    local function makeVehicle(opts)
        opts = opts or {}
        local vehicle  -- declared first so stateModule closures capture it as an upvalue (Lua 5.1)
        vehicle = {
            _active = false,
            _zPos = 0,
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
                local list = {}
                for i, parkId in ipairs(opts.implementParkIds or {}) do
                    local z = opts.implementZs and opts.implementZs[i] or nil
                    table.insert(list, makeImplement(parkId, z))
                end
                return list
            end,
            startAutoDrive = function(self)
                vehicle._startAutoDriveCalled = true
            end,
        }
        return vehicle
    end

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
        it("prefers an attached implement's park position over the vehicle's own", function()
            _G.ADGraphManager._markers[11] = { id = 11, name = "ParkSpotB" }
            local v = makeVehicle({ implementParkIds = { 10 }, vehicleParkId = 11 })
            assert.are.equal(10, ADIntegration:getVehicleParkDestinationId(v))
        end)

        it("falls back to the vehicle's own park position when no implement has one", function()
            local v = makeVehicle({ vehicleParkId = 10 })
            assert.are.equal(10, ADIntegration:getVehicleParkDestinationId(v))
        end)

        it("returns nil when neither an attached implement nor the vehicle has one configured", function()
            local v = makeVehicle({})
            assert.is_nil(ADIntegration:getVehicleParkDestinationId(v))
        end)

        it("skips an attached implement with no park position configured and uses the next one that has one", function()
            -- Regression: a vehicle can have multiple directly attached implements (e.g. a
            -- front tool with nothing configured, plus a trailer the user actually set the
            -- park position on via AD's own UI) - resolution must check all of them, not just
            -- the first, since AD stores the position on whichever object was selected (bug-151).
            _G.ADGraphManager._markers[11] = { id = 11, name = "ParkSpotB" }
            local v = makeVehicle({ implementParkIds = { false, 10 }, vehicleParkId = 11 })
            assert.are.equal(10, ADIntegration:getVehicleParkDestinationId(v))
        end)

        it("prefers the implement furthest behind the vehicle when multiple have a park position configured", function()
            _G.ADGraphManager._markers[11] = { id = 11, name = "ParkSpotB" }
            -- implement 1 (front, z=5) has 11 configured; implement 2 (rear, z=-5) has 10 configured
            local v = makeVehicle({ implementParkIds = { 11, 10 }, implementZs = { 5, -5 } })
            assert.are.equal(10, ADIntegration:getVehicleParkDestinationId(v))
        end)

        it("keeps attach order when a candidate implement's position can't be determined", function()
            _G.ADGraphManager._markers[11] = { id = 11, name = "ParkSpotB" }
            local v = makeVehicle({ implementParkIds = { 11, 10 } })
            assert.are.equal(11, ADIntegration:getVehicleParkDestinationId(v))
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

        it("prefers an attached implement's park position over the vehicle's own", function()
            _G.ADGraphManager._markers[11] = { id = 11, name = "ParkSpotB" }
            local v = makeVehicle({ implementParkIds = { 10 }, vehicleParkId = 11 })
            ADIntegration:startParkRoute(v)
            assert.are.equal(10, v._parkDestinationAtJobFinished)
        end)

        -- No pcall any more (ModHub TestRunner), so a missing API must be caught up front
        it("returns false without touching the vehicle when AutoDrive:StartDriving is missing", function()
            local orig = AutoDrive.StartDriving
            AutoDrive.StartDriving = nil
            local v = makeVehicle({ vehicleParkId = 10 })
            local success = ADIntegration:startParkRoute(v)
            AutoDrive.StartDriving = orig
            assert.is_false(success)
            assert.is_nil(v._parkDestinationAtJobFinished)
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

        it("sets mode/onRouteToRefuel and calls vehicle:startAutoDrive (no StartDriving sentinel used)", function()
            _G.__refuelDestinationResult = 20
            local v = makeVehicle({})
            local success, skipped = ADIntegration:startRefuelRoute(v)
            assert.is_true(success)
            assert.is_false(skipped)
            assert.are.equal(AutoDrive.MODE_DRIVETO, v._mode)
            assert.is_true(v.ad.onRouteToRefuel)
            assert.is_true(v._startAutoDriveCalled)
            assert.is_nil(_G.__lastStartDrivingCall)
        end)

        it("returns false, false without arming onRouteToRefuel when vehicle:startAutoDrive is missing", function()
            _G.__refuelDestinationResult = 20
            local v = makeVehicle({})
            v.startAutoDrive = nil
            local success, skipped = ADIntegration:startRefuelRoute(v)
            assert.is_false(success)
            assert.is_false(skipped)
            assert.is_nil(v.ad.onRouteToRefuel)
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

        it("returns false without arming onRouteToRepair when vehicle:startAutoDrive is missing", function()
            _G.__repairTriggerResult = { marker = 30 }
            local v = makeVehicle({})
            v.startAutoDrive = nil
            assert.is_false(ADIntegration:startRepairRoute(v))
            assert.is_nil(v.ad.onRouteToRepair)
        end)
    end)

    -- =========================================================================
    -- isRefuelRepairComplete
    -- =========================================================================
    describe("isRefuelRepairComplete", function()
        it("returns true when vehicle is nil", function()
            assert.is_true(ADIntegration:isRefuelRepairComplete(nil, "onRouteToRefuel"))
        end)

        it("returns true when vehicle has no AutoDrive specialization", function()
            assert.is_true(ADIntegration:isRefuelRepairComplete({}, "onRouteToRefuel"))
        end)

        it("returns false while the route flag is still set", function()
            local v = makeVehicle({})
            v.ad.onRouteToRefuel = true
            assert.is_false(ADIntegration:isRefuelRepairComplete(v, "onRouteToRefuel"))
        end)

        it("returns true and does not stop the route when the flag is clear and AD is idle", function()
            local v = makeVehicle({})
            v.ad.onRouteToRepair = false
            v._active = false
            local stopped = false
            local origStop = ADIntegration.stopRoute
            ADIntegration.stopRoute = function(self, vehicle) stopped = true end
            assert.is_true(ADIntegration:isRefuelRepairComplete(v, "onRouteToRepair"))
            ADIntegration.stopRoute = origStop
            assert.is_false(stopped)
        end)

        it("returns true and cancels AD's own mode-restart when the flag is clear but AD reactivated itself", function()
            local v = makeVehicle({})
            v.ad.onRouteToRepair = false
            v._active = true -- RepairTask:finished() called getCurrentMode():start(), reactivating AD
            local stopped = false
            local origStop = ADIntegration.stopRoute
            ADIntegration.stopRoute = function(self, vehicle) stopped = true end
            assert.is_true(ADIntegration:isRefuelRepairComplete(v, "onRouteToRepair"))
            ADIntegration.stopRoute = origStop
            assert.is_true(stopped)
        end)
    end)

    -- =========================================================================
    -- startRoute: configuration problems reach the player
    -- =========================================================================
    describe("startRoute configuration errors", function()
        local farmMessages, realGetDestinationByName

        before_each(function()
            farmMessages = {}
            _G.WorkflowManager = {
                notifyFarm = function(_, vehicle, isError, key, ...)
                    table.insert(farmMessages, { isError = isError, key = key, args = { ... } })
                end,
                getVehicleDisplayName = function() return "Tractor" end,
            }
            realGetDestinationByName = ADIntegration.getDestinationByName
            ADIntegration.getDestinationByName = function(_, name)
                if name == "Farm" then return { id = 10, name = "Farm" } end
                return nil
            end
        end)

        local function restore()
            ADIntegration.getDestinationByName = realGetDestinationByName
        end

        it("returns the destination-not-found message key for an unknown target", function()
            local ok, errorKey = ADIntegration:startRoute(makeVehicle(), "Nowhere", "drive")
            restore()
            assert.is_false(ok)
            assert.are.equal("wm_error_ad_target_not_found", errorKey)
        end)

        it("warns the farm about an unknown unload destination and still starts", function()
            local ok = ADIntegration:startRoute(makeVehicle(), "Farm", "pickup_deliver", "Ghost Silo")
            restore()
            assert.is_true(ok)
            assert.are.equal(1, #farmMessages)
            assert.are.equal("wm_warning_ad_unload_not_found", farmMessages[1].key)
            assert.are.same({ "Tractor", "Ghost Silo" }, farmMessages[1].args)
        end)
    end)

end)
