--[[
    WorkflowExecutor Unit Tests
    Tests the real WorkflowExecutor.lua state machine and step transitions.

    The real executor stores all mutable state per-vehicle on
    vehicle.spec_workflowManagerSpec.wmExecution (activeData), not on the
    workflow definition. Public API is vehicle-based:
      startWorkflow(workflow, vehicle)
      stopWorkflow(vehicle)
      pauseWorkflow(vehicle)
      resumeWorkflow(vehicle)
      goToPreviousStep(vehicle)
      goToNextStep(vehicle)
]]

describe("WMExecutor (real)", function()

    -- -------------------------------------------------------------------------
    -- Setup: load real executor once, extend mocks as needed
    -- -------------------------------------------------------------------------
    setup(function()
        dofile("src/utils/EventHandler.lua")

        -- WorkflowManager constants + stub methods called by executor
        _G.WorkflowManager = {
            STATUS_READY     = "ready",
            STATUS_RUNNING   = "running",
            STATUS_PAUSED    = "paused",
            STATUS_COMPLETED = "completed",
            STATUS_ERROR     = "error",
            STEP_AUTODRIVE   = "autodrive",
            STEP_COURSEPLAY  = "courseplay",
            broadcastState   = function() end,
            getLinkedWorkflow = function() return nil end,
        }

        -- Executor runs server-side only; make tests act as the server
        _G.g_server = {}

        -- Load the real executor
        dofile("src/WorkflowExecutor.lua")
    end)

    -- -------------------------------------------------------------------------
    -- Helpers
    -- -------------------------------------------------------------------------

    -- Typed nil for passing to APIs that expect a table (intentional nil tests)
    ---@type table
    local NIL_TABLE = nil  ---@diagnostic disable-line: assign-type-mismatch

    -- Create a vehicle with spec_workflowManagerSpec (required by real executor)
    local function makeVehicle(name)
        local v = VehicleMock.createValid(name)
        v.spec_workflowManagerSpec = { wmExecution = nil }
        return v
    end

    -- Return the per-vehicle execution state (nil if not running)
    local function activeData(vehicle)
        return vehicle.spec_workflowManagerSpec.wmExecution
    end

    -- Create a simple 3-step test workflow (AD -> CP -> AD)
    local function makeWorkflow(id)
        return {
            id       = id or "wf_001",
            name     = "Test Workflow",
            linkRole = nil,
            linkedWorkflowId = nil,
            steps = {
                { type = "autodrive",  target = "Farm",   action = "drive"      },
                { type = "courseplay", target = "Field1", action = "fieldwork"  },
                { type = "autodrive",  target = "Silo",   action = "unload", unloadTarget = "Silo" },
            },
        }
    end

    -- -------------------------------------------------------------------------
    -- Reset between each test
    -- -------------------------------------------------------------------------
    before_each(function()
        WMExecutor:init()

        -- Reset logger call tracking
        _G.WMLogger.calls = { debug = {}, info = {}, warning = {}, error = {} }
    end)

    -- =========================================================================
    -- init
    -- =========================================================================
    describe("init", function()
        it("starts with empty activeVehicles", function()
            WMExecutor:init()
            assert.are.equal(0, WMExecutor:getActiveWorkflowCount())
        end)

        it("sets isInitialized to true", function()
            WMExecutor.isInitialized = false
            WMExecutor:init()
            assert.is_true(WMExecutor.isInitialized)
        end)
    end)

    -- =========================================================================
    -- startWorkflow
    -- =========================================================================
    describe("startWorkflow", function()
        it("returns false for nil workflow", function()
            local v = makeVehicle()
            assert.is_false(WMExecutor:startWorkflow(NIL_TABLE, v))
        end)

        it("returns false for nil vehicle", function()
            assert.is_false(WMExecutor:startWorkflow(makeWorkflow(), NIL_TABLE))
        end)

        it("returns false for vehicle without spec_workflowManagerSpec", function()
            local v = VehicleMock.createValid()  -- no spec
            assert.is_false(WMExecutor:startWorkflow(makeWorkflow(), v))
        end)

        it("returns false for workflow with no steps", function()
            local wf = makeWorkflow()
            wf.steps = {}
            assert.is_false(WMExecutor:startWorkflow(wf, makeVehicle()))
        end)

        it("returns false if vehicle already running a workflow", function()
            local v  = makeVehicle()
            local wf = makeWorkflow()
            WMExecutor:startWorkflow(wf, v)
            assert.is_false(WMExecutor:startWorkflow(wf, v))
        end)

        it("stores execution state on vehicle spec (not on workflow)", function()
            local v  = makeVehicle()
            local wf = makeWorkflow()
            WMExecutor:startWorkflow(wf, v)

            local d = activeData(v)
            assert.is_not_nil(d)
            assert.are.equal("running", d.status)
            assert.are.equal(1, d.currentStep)
            -- workflow definition must NOT be mutated
            assert.is_nil(wf.status)
            assert.is_nil(wf.currentStep)
        end)

        it("adds vehicle to activeVehicles set", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            assert.are.equal(1, WMExecutor:getActiveWorkflowCount())
            assert.is_true(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)

        it("fires WORKFLOW_STARTED event", function()
            local fired = false
            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_STARTED, function()
                fired = true
            end)
            WMExecutor:startWorkflow(makeWorkflow(), makeVehicle())
            assert.is_true(fired)
        end)

        it("begins executing the first step immediately", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            -- After start, executor should be waiting for the first AD step
            local d = activeData(v)
            assert.is_true(d.waitingForCompletion)
            assert.are.equal(WorkflowManager.STEP_AUTODRIVE, d.currentStepType)
        end)
    end)

    -- =========================================================================
    -- stopWorkflow
    -- =========================================================================
    describe("stopWorkflow", function()
        local v, wf

        before_each(function()
            v  = makeVehicle()
            wf = makeWorkflow()
            WMExecutor:startWorkflow(wf, v)
        end)

        it("returns false for nil vehicle", function()
            assert.is_false(WMExecutor:stopWorkflow(NIL_TABLE))
        end)

        it("returns false when vehicle has no active workflow", function()
            local other = makeVehicle("Other")
            assert.is_false(WMExecutor:stopWorkflow(other))
        end)

        it("clears wmExecution from the vehicle spec", function()
            WMExecutor:stopWorkflow(v)
            assert.is_nil(activeData(v))
        end)

        it("removes vehicle from activeVehicles", function()
            WMExecutor:stopWorkflow(v)
            assert.are.equal(0, WMExecutor:getActiveWorkflowCount())
            assert.is_false(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)

        it("fires WORKFLOW_STOPPED event", function()
            local fired = false
            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_STOPPED, function()
                fired = true
            end)
            WMExecutor:stopWorkflow(v)
            assert.is_true(fired)
        end)

        it("does not mutate the workflow definition", function()
            WMExecutor:stopWorkflow(v)
            assert.is_nil(wf.status)
        end)
    end)

    -- =========================================================================
    -- pauseWorkflow
    -- =========================================================================
    describe("pauseWorkflow", function()
        local v

        before_each(function()
            v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
        end)

        it("returns false for nil vehicle", function()
            assert.is_false(WMExecutor:pauseWorkflow(NIL_TABLE))
        end)

        it("returns false when vehicle has no active workflow", function()
            assert.is_false(WMExecutor:pauseWorkflow(makeVehicle("Other")))
        end)

        it("returns false if workflow is not running", function()
            activeData(v).status = WorkflowManager.STATUS_PAUSED
            assert.is_false(WMExecutor:pauseWorkflow(v))
        end)

        it("sets status to paused on activeData", function()
            WMExecutor:pauseWorkflow(v)
            assert.are.equal("paused", activeData(v).status)
        end)

        it("saves tracking state for resume", function()
            local d = activeData(v)
            d.waitingForCompletion = true
            WMExecutor:pauseWorkflow(v)
            assert.is_not_nil(d.pausedTrackingState)
            assert.is_true(d.pausedTrackingState.waitingForCompletion)
        end)

        it("sets waitingForCompletion to false", function()
            WMExecutor:pauseWorkflow(v)
            assert.is_false(activeData(v).waitingForCompletion)
        end)

        it("fires WORKFLOW_PAUSED event", function()
            local fired = false
            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_PAUSED, function()
                fired = true
            end)
            WMExecutor:pauseWorkflow(v)
            assert.is_true(fired)
        end)
    end)

    -- =========================================================================
    -- resumeWorkflow
    -- =========================================================================
    describe("resumeWorkflow", function()
        local v

        before_each(function()
            v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            WMExecutor:pauseWorkflow(v)
        end)

        it("returns false for nil vehicle", function()
            assert.is_false(WMExecutor:resumeWorkflow(NIL_TABLE))
        end)

        it("returns false when vehicle has no active workflow", function()
            assert.is_false(WMExecutor:resumeWorkflow(makeVehicle("Other")))
        end)

        it("returns false if workflow is not paused", function()
            WMExecutor:resumeWorkflow(v)  -- resume → running
            assert.is_false(WMExecutor:resumeWorkflow(v))
        end)

        it("sets status back to running", function()
            WMExecutor:resumeWorkflow(v)
            assert.are.equal("running", activeData(v).status)
        end)

        it("clears pausedTrackingState", function()
            WMExecutor:resumeWorkflow(v)
            assert.is_nil(activeData(v).pausedTrackingState)
        end)

        it("fires WORKFLOW_RESUMED event", function()
            local fired = false
            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_RESUMED, function()
                fired = true
            end)
            WMExecutor:resumeWorkflow(v)
            assert.is_true(fired)
        end)
    end)

    -- =========================================================================
    -- goToPreviousStep
    -- =========================================================================
    describe("goToPreviousStep", function()
        local v

        before_each(function()
            v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            activeData(v).currentStep = 2  -- place at step 2 for back-navigation
        end)

        it("returns false for nil vehicle", function()
            assert.is_false(WMExecutor:goToPreviousStep(NIL_TABLE))
        end)

        it("returns false when vehicle has no active workflow", function()
            assert.is_false(WMExecutor:goToPreviousStep(makeVehicle("Other")))
        end)

        it("returns false when already at first step", function()
            activeData(v).currentStep = 1
            assert.is_false(WMExecutor:goToPreviousStep(v))
        end)

        it("decrements currentStep", function()
            WMExecutor:goToPreviousStep(v)
            assert.are.equal(1, activeData(v).currentStep)
        end)

        it("resumes to running if was paused", function()
            WMExecutor:pauseWorkflow(v)
            WMExecutor:goToPreviousStep(v)
            assert.are.equal("running", activeData(v).status)
        end)

        it("fires STEP_CHANGED event with direction=previous", function()
            local dir = nil
            WMEventHandler:addEventListener(WMEventHandler.EVENT_STEP_CHANGED, function(_, data)
                dir = data.direction
            end)
            WMExecutor:goToPreviousStep(v)
            assert.are.equal("previous", dir)
        end)
    end)

    -- =========================================================================
    -- goToNextStep
    -- =========================================================================
    describe("goToNextStep", function()
        local v

        before_each(function()
            v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            -- step 1, can advance to 2 or 3
        end)

        it("returns false for nil vehicle", function()
            assert.is_false(WMExecutor:goToNextStep(NIL_TABLE))
        end)

        it("returns false when vehicle has no active workflow", function()
            assert.is_false(WMExecutor:goToNextStep(makeVehicle("Other")))
        end)

        it("returns false when already at last step", function()
            activeData(v).currentStep = 3
            assert.is_false(WMExecutor:goToNextStep(v))
        end)

        it("increments currentStep", function()
            WMExecutor:goToNextStep(v)
            assert.are.equal(2, activeData(v).currentStep)
        end)

        it("resumes to running if was paused", function()
            WMExecutor:pauseWorkflow(v)
            WMExecutor:goToNextStep(v)
            assert.are.equal("running", activeData(v).status)
        end)

        it("fires STEP_CHANGED event with direction=next", function()
            local dir = nil
            WMEventHandler:addEventListener(WMEventHandler.EVENT_STEP_CHANGED, function(_, data)
                dir = data.direction
            end)
            WMExecutor:goToNextStep(v)
            assert.are.equal("next", dir)
        end)
    end)

    -- =========================================================================
    -- onStepCompleted (internal, called via test to verify state machine)
    -- =========================================================================
    describe("onStepCompleted", function()
        local v

        before_each(function()
            v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
        end)

        it("fires STEP_COMPLETED event", function()
            local fired = false
            WMEventHandler:addEventListener(WMEventHandler.EVENT_STEP_COMPLETED, function()
                fired = true
            end)
            WMExecutor:onStepCompleted(activeData(v))
            assert.is_true(fired)
        end)

        it("advances currentStep", function()
            WMExecutor:onStepCompleted(activeData(v))
            -- step should now be 2 (or workflow completed, handled separately)
            local d = activeData(v)
            if d ~= nil then
                assert.are.equal(2, d.currentStep)
            end
        end)

        it("completes workflow after the last step", function()
            local d = activeData(v)
            d.currentStep = 3  -- last step
            d.currentStepType = WorkflowManager.STEP_AUTODRIVE
            WMExecutor:onStepCompleted(d)

            assert.is_nil(activeData(v))  -- wmExecution cleared
            assert.is_false(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)

        it("fires WORKFLOW_COMPLETED event on last step", function()
            local fired = false
            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_COMPLETED, function()
                fired = true
            end)
            local d = activeData(v)
            d.currentStep = 3
            d.currentStepType = WorkflowManager.STEP_AUTODRIVE
            WMExecutor:onStepCompleted(d)
            assert.is_true(fired)
        end)
    end)

    -- =========================================================================
    -- onWorkflowCompleted
    -- =========================================================================
    describe("onWorkflowCompleted", function()
        local v

        before_each(function()
            v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
        end)

        it("clears wmExecution from vehicle spec", function()
            WMExecutor:onWorkflowCompleted(activeData(v))
            assert.is_nil(activeData(v))
        end)

        it("removes vehicle from activeVehicles", function()
            WMExecutor:onWorkflowCompleted(activeData(v))
            assert.are.equal(0, WMExecutor:getActiveWorkflowCount())
        end)

        it("fires WORKFLOW_COMPLETED event", function()
            local eventData = nil
            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_COMPLETED, function(_, data)
                eventData = data
            end)
            local wf = activeData(v).workflow
            WMExecutor:onWorkflowCompleted(activeData(v))
            assert.is_not_nil(eventData)
            local ed = eventData or {}
            assert.are.equal(wf.id, ed.workflowId)
        end)
    end)

    -- =========================================================================
    -- getActiveWorkflowCount / isWorkflowActive / isWorkflowActiveOnVehicle
    -- =========================================================================
    describe("query helpers", function()
        it("getActiveWorkflowCount returns 0 when idle", function()
            assert.are.equal(0, WMExecutor:getActiveWorkflowCount())
        end)

        it("getActiveWorkflowCount counts active vehicles", function()
            local v1 = makeVehicle("T1")
            local v2 = makeVehicle("T2")
            WMExecutor:startWorkflow(makeWorkflow("wf_1"), v1)
            WMExecutor:startWorkflow(makeWorkflow("wf_2"), v2)
            assert.are.equal(2, WMExecutor:getActiveWorkflowCount())
        end)

        it("isWorkflowActive returns false for unknown id", function()
            assert.is_false(WMExecutor:isWorkflowActive("nonexistent"))
        end)

        it("isWorkflowActive returns true for running workflow", function()
            local v = makeVehicle()
            local wf = makeWorkflow("wf_q")
            WMExecutor:startWorkflow(wf, v)
            assert.is_true(WMExecutor:isWorkflowActive("wf_q"))
        end)

        it("isWorkflowActiveOnVehicle returns false before start", function()
            assert.is_false(WMExecutor:isWorkflowActiveOnVehicle(makeVehicle()))
        end)

        it("isWorkflowActiveOnVehicle returns true after start", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            assert.is_true(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)

        it("isWorkflowActiveOnVehicle returns false after stop", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            WMExecutor:stopWorkflow(v)
            assert.is_false(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)
    end)

end)
