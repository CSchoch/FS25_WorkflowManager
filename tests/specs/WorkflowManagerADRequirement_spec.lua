--[[
    WorkflowManager - AutoDrive requirement tests

    Unlike WorkflowManager_spec.lua (which re-implements the CRUD surface as stubs), this
    spec exercises the REAL workflowNeedsAutoDrive / isVehicleValid from src/WorkflowManager.lua:
    they decide whether a workflow may start at all, so a stubbed copy would prove nothing.
    The module is loaded with `source` neutered, so only its own definitions are evaluated
    and none of the ~20 modules it sources are pulled in.
]]

describe("WorkflowManager AutoDrive requirement", function()
    local WM

    setup(function()
        _G.source = function() end
        _G.Utils = {
            getFilename = function(name) return name end,
            appendedFunction = function(old, new) return new end,
            prependedFunction = function(old, new) return new end,
        }
        _G.addModEventListener = function() end
        _G.FSBaseMission = {}
        _G.g_currentModName = "FS25_WorkflowManager"
        _G.g_currentModDirectory = "./"

        local noop = function() end
        _G.WMLogger = {
            initFromDevConfig = noop, info = noop, debug = noop,
            warning = noop, error = noop, apiCall = noop,
            event = noop, state = noop,
        }

        dofile("src/WorkflowManager.lua")
        WM = _G.WorkflowManager
    end)

    local function wf(steps)
        return { id = "wf1", name = "Test", steps = steps }
    end

    local function cpOnlyVehicle()
        return { spec_cpAIWorker = {}, getName = function() return "CPOnly" end }
    end

    local function adAndCpVehicle()
        return { ad = {}, spec_cpAIWorker = {}, getName = function() return "Full" end }
    end

    describe("workflowNeedsAutoDrive", function()
        it("returns false for a workflow of Courseplay steps only", function()
            assert.is_false(WM:workflowNeedsAutoDrive(wf({
                { type = WM.STEP_COURSEPLAY, target = "F1" },
                { type = WM.STEP_COURSEPLAY, target = "F2" },
            })))
        end)

        it("returns false for Courseplay steps plus sync markers", function()
            assert.is_false(WM:workflowNeedsAutoDrive(wf({
                { type = WM.STEP_WAIT_FOR_LEADER },
                { type = WM.STEP_COURSEPLAY, target = "F1" },
                { type = WM.STEP_UNLOCK_FOLLOWER },
            })))
        end)

        it("returns true when any step is an AutoDrive drive step", function()
            assert.is_true(WM:workflowNeedsAutoDrive(wf({
                { type = WM.STEP_COURSEPLAY, target = "F1" },
                { type = WM.STEP_AUTODRIVE, target = "Farm" },
            })))
        end)

        it("returns true for each AD-driven convenience type", function()
            for _, adType in ipairs({WM.STEP_PARK, WM.STEP_REFUEL, WM.STEP_REPAIR}) do
                assert.is_true(WM:workflowNeedsAutoDrive(wf({ { type = adType } })))
            end
        end)

        it("returns true when only a support sub-step needs AutoDrive", function()
            assert.is_true(WM:workflowNeedsAutoDrive(wf({
                {
                    type = WM.STEP_COURSEPLAY, target = "F1",
                    support = { { type = WM.STEP_AUTODRIVE, target = "Silo" } },
                },
            })))
        end)

        it("ignores support sub-steps that are Courseplay only", function()
            assert.is_false(WM:workflowNeedsAutoDrive(wf({
                {
                    type = WM.STEP_COURSEPLAY, target = "F1",
                    support = { { type = WM.STEP_COURSEPLAY, target = "F1b" } },
                },
            })))
        end)

        it("treats a nil workflow as needing AutoDrive", function()
            assert.is_true(WM:workflowNeedsAutoDrive(nil))
        end)

        it("treats a workflow without a steps table as needing AutoDrive", function()
            assert.is_true(WM:workflowNeedsAutoDrive({ id = "wf1", name = "Broken" }))
        end)
    end)

    describe("isVehicleValid", function()
        local cpOnlyWorkflow = wf({ { type = "courseplay", target = "F1" } })
        local adWorkflow = wf({ { type = "autodrive", target = "Farm" } })

        it("accepts a Courseplay-only vehicle for a Courseplay-only workflow", function()
            assert.is_true(WM:isVehicleValid(cpOnlyVehicle(), cpOnlyWorkflow))
        end)

        it("rejects a Courseplay-only vehicle for a workflow with AutoDrive steps", function()
            assert.is_false(WM:isVehicleValid(cpOnlyVehicle(), adWorkflow))
        end)

        it("accepts an AD+CP vehicle for either workflow", function()
            assert.is_true(WM:isVehicleValid(adAndCpVehicle(), cpOnlyWorkflow))
            assert.is_true(WM:isVehicleValid(adAndCpVehicle(), adWorkflow))
        end)

        it("rejects a vehicle without Courseplay even for a Courseplay-only workflow", function()
            local adOnly = { ad = {}, getName = function() return "ADOnly" end }
            assert.is_false(WM:isVehicleValid(adOnly, cpOnlyWorkflow))
        end)

        it("still requires AutoDrive when called without a workflow", function()
            assert.is_false(WM:isVehicleValid(cpOnlyVehicle()))
            assert.is_true(WM:isVehicleValid(adAndCpVehicle()))
        end)

        it("detects AutoDrive via spec_autoDrive as well as vehicle.ad", function()
            local viaSpec = { spec_autoDrive = {}, spec_cpAIWorker = {} }
            assert.is_true(WM:isVehicleValid(viaSpec, adWorkflow))
        end)

        it("detects Courseplay via getIsCpActive", function()
            local viaMethod = { getIsCpActive = function() return false end }
            assert.is_true(WM:isVehicleValid(viaMethod, cpOnlyWorkflow))
        end)

        it("rejects a nil vehicle", function()
            assert.is_false(WM:isVehicleValid(nil, cpOnlyWorkflow))
        end)
    end)
end)
