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
    -- resetWorkflow
    -- =========================================================================
    describe("resetWorkflow", function()
        local v

        before_each(function()
            v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
        end)

        it("returns false for nil vehicle", function()
            assert.is_false(WMExecutor:resetWorkflow(NIL_TABLE))
        end)

        it("returns false when vehicle has no active workflow", function()
            assert.is_false(WMExecutor:resetWorkflow(makeVehicle("Other")))
        end)

        it("clears wmExecution from the vehicle spec", function()
            WMExecutor:resetWorkflow(v)
            assert.is_nil(activeData(v))
        end)

        it("removes vehicle from activeVehicles", function()
            WMExecutor:resetWorkflow(v)
            assert.are.equal(0, WMExecutor:getActiveWorkflowCount())
        end)

        it("fires WORKFLOW_STOPPED event with reset=true", function()
            local eventData = nil
            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_STOPPED, function(_, data)
                eventData = data
            end)
            WMExecutor:resetWorkflow(v)
            assert.is_not_nil(eventData)
            assert.is_true((eventData or {}).reset == true)
        end)
    end)

    -- =========================================================================
    -- handleStepError
    -- =========================================================================
    describe("handleStepError", function()
        local v

        before_each(function()
            v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
        end)

        it("fires STEP_ERROR event", function()
            local fired = false
            WMEventHandler:addEventListener(WMEventHandler.EVENT_STEP_ERROR, function()
                fired = true
            end)
            WMExecutor:handleStepError(activeData(v), "test error")
            assert.is_true(fired)
        end)

        it("STEP_ERROR event contains error message", function()
            local errMsg = nil
            WMEventHandler:addEventListener(WMEventHandler.EVENT_STEP_ERROR, function(_, data)
                errMsg = data and data.error
            end)
            WMExecutor:handleStepError(activeData(v), "something went wrong")
            assert.are.equal("something went wrong", errMsg)
        end)

        it("stops the workflow (clears wmExecution)", function()
            WMExecutor:handleStepError(activeData(v), "test error")
            assert.is_nil(activeData(v))
        end)

        it("removes vehicle from activeVehicles", function()
            WMExecutor:handleStepError(activeData(v), "test error")
            assert.are.equal(0, WMExecutor:getActiveWorkflowCount())
        end)
    end)

    -- =========================================================================
    -- getActiveDataForWorkflow / getActiveDataForVehicle / getWorkflowForVehicle
    -- =========================================================================
    describe("data accessor helpers", function()
        local v, wf

        before_each(function()
            v  = makeVehicle()
            wf = makeWorkflow("wf_accessor")
            WMExecutor:startWorkflow(wf, v)
        end)

        it("getActiveDataForWorkflow returns activeData when workflow is running", function()
            local d = WMExecutor:getActiveDataForWorkflow("wf_accessor")
            assert.is_not_nil(d)
            assert.are.equal(wf, d.workflow)
        end)

        it("getActiveDataForWorkflow returns nil for unknown workflow id", function()
            assert.is_nil(WMExecutor:getActiveDataForWorkflow("no_such_workflow"))
        end)

        it("getActiveDataForWorkflow returns nil after workflow is stopped", function()
            WMExecutor:stopWorkflow(v)
            assert.is_nil(WMExecutor:getActiveDataForWorkflow("wf_accessor"))
        end)

        it("getActiveDataForVehicle returns activeData for the vehicle", function()
            local d = WMExecutor:getActiveDataForVehicle(v)
            assert.is_not_nil(d)
            assert.are.equal("running", d.status)
        end)

        it("getActiveDataForVehicle returns nil for vehicle without active workflow", function()
            assert.is_nil(WMExecutor:getActiveDataForVehicle(makeVehicle("Idle")))
        end)

        it("getActiveDataForVehicle returns nil for nil vehicle", function()
            assert.is_nil(WMExecutor:getActiveDataForVehicle(nil))
        end)

        it("getWorkflowForVehicle returns the workflow definition", function()
            local w = WMExecutor:getWorkflowForVehicle(v)
            assert.are.equal(wf, w)
        end)

        it("getWorkflowForVehicle returns nil for idle vehicle", function()
            assert.is_nil(WMExecutor:getWorkflowForVehicle(makeVehicle("Idle")))
        end)
    end)

    -- =========================================================================
    -- findStepByGroup
    -- =========================================================================
    describe("findStepByGroup", function()
        local wfWithGroups

        before_each(function()
            wfWithGroups = {
                id    = "wf_sync",
                name  = "Sync Workflow",
                steps = {
                    { type = "autodrive",  target = "A", action = "drive",     syncGroup = 1 },
                    { type = "courseplay", target = "B", action = "fieldwork", syncGroup = 1 },
                    { type = "autodrive",  target = "C", action = "drive",     syncGroup = 2 },
                },
            }
        end)

        it("returns first step index matching the group", function()
            assert.are.equal(1, WMExecutor:findStepByGroup(wfWithGroups, 1))
        end)

        it("returns step index for a later group", function()
            assert.are.equal(3, WMExecutor:findStepByGroup(wfWithGroups, 2))
        end)

        it("returns nil for non-existent group", function()
            assert.is_nil(WMExecutor:findStepByGroup(wfWithGroups, 99))
        end)

        it("returns nil for nil workflow", function()
            assert.is_nil(WMExecutor:findStepByGroup(nil, 1))
        end)

        it("returns nil for nil groupNum", function()
            assert.is_nil(WMExecutor:findStepByGroup(wfWithGroups, nil))
        end)
    end)

    -- =========================================================================
    -- goToNextStep — additional edge cases
    -- =========================================================================
    describe("goToNextStep (edge cases)", function()
        it("completes workflow when advancing past the last step via onStepCompleted", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            -- Place at last step and simulate completion
            local d = activeData(v)
            d.currentStep = 3
            d.currentStepType = WorkflowManager.STEP_AUTODRIVE
            WMExecutor:onStepCompleted(d)
            -- Workflow should be complete and wmExecution cleared
            assert.is_nil(activeData(v))
        end)

        it("step count remains consistent before and after step navigation", function()
            local v = makeVehicle()
            local wf = makeWorkflow()
            WMExecutor:startWorkflow(wf, v)
            assert.are.equal(1, activeData(v).currentStep)
            WMExecutor:goToNextStep(v)
            assert.are.equal(2, activeData(v).currentStep)
            WMExecutor:goToNextStep(v)
            assert.are.equal(3, activeData(v).currentStep)
            -- At last step, goToNextStep should return false
            assert.is_false(WMExecutor:goToNextStep(v))
        end)
    end)

    -- =========================================================================
    -- goToPreviousStep — additional edge cases
    -- =========================================================================
    describe("goToPreviousStep (edge cases)", function()
        it("stays at step 1 when already at first step", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            assert.are.equal(1, activeData(v).currentStep)
            assert.is_false(WMExecutor:goToPreviousStep(v))
            assert.are.equal(1, activeData(v).currentStep)
        end)

        it("can navigate back from last step", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            activeData(v).currentStep = 3
            WMExecutor:goToPreviousStep(v)
            assert.are.equal(2, activeData(v).currentStep)
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

    -- =========================================================================
    -- resetStepTrackingState
    -- =========================================================================
    describe("resetStepTrackingState", function()
        it("clears all tracking flags on activeData", function()
            local d = {
                waitingForCompletion = true,
                willHandoffToCP      = true,
                cpHandedOffToAD      = true,
                cpWasRunning         = true,
                cpStartedByAD        = true,
                cpStartWaitCount     = 5,
                pausedTrackingState  = { something = true },
                pendingCPStart       = true,
                pendingCPStartRetries = 3,
                cpToCpTransition     = true,
                pendingADStart       = true,
                pendingADStartRetries = 2,
            }
            WMExecutor:resetStepTrackingState(d)
            assert.is_false(d.waitingForCompletion)
            assert.is_false(d.willHandoffToCP)
            assert.is_false(d.cpHandedOffToAD)
            assert.is_false(d.cpWasRunning)
            assert.is_false(d.cpStartedByAD)
            assert.is_nil(d.cpStartWaitCount)
            assert.is_nil(d.pausedTrackingState)
            assert.is_nil(d.pendingCPStart)
            assert.is_nil(d.pendingCPStartRetries)
            assert.is_nil(d.cpToCpTransition)
            assert.is_nil(d.pendingADStart)
            assert.is_nil(d.pendingADStartRetries)
        end)

        it("is safe to call on an already-clean activeData", function()
            assert.has_no.errors(function()
                WMExecutor:resetStepTrackingState({})
            end)
        end)
    end)

    -- =========================================================================
    -- handleLinkedWorkflowStepChange
    -- =========================================================================
    describe("handleLinkedWorkflowStepChange", function()
        -- Helpers: a linked pair with sync groups
        local function makeLinkedPair()
            local main = {
                id = "wf_main", name = "Main", linkRole = "main", linkedWorkflowId = "wf_sup",
                steps = {
                    { type = "autodrive",  target = "A", action = "drive",     syncGroup = 1 },
                    { type = "courseplay", target = "B", action = "fieldwork", syncGroup = 1 },
                    { type = "autodrive",  target = "C", action = "drive",     syncGroup = 2 },
                    { type = "courseplay", target = "D", action = "fieldwork", syncGroup = 2 },
                },
            }
            local sup = {
                id = "wf_sup", name = "Support", linkRole = "support", linkedWorkflowId = "wf_main",
                steps = {
                    { type = "autodrive", target = "X", action = "unload", syncGroup = 1 },
                    { type = "autodrive", target = "Y", action = "unload", syncGroup = 2 },
                },
            }
            return main, sup
        end

        it("sets syncOverridden=true when a support workflow step is manually changed", function()
            local main, sup = makeLinkedPair()
            local v = makeVehicle("Support")
            WMExecutor:startWorkflow(sup, v)
            local d = activeData(v)
            WMExecutor:handleLinkedWorkflowStepChange(d, 1)
            assert.is_true(d.syncOverridden)
        end)

        it("does not trigger sync transition when main stays in same group", function()
            local main, sup = makeLinkedPair()
            local transitionCalled = false
            local origFn = WMExecutor.onSyncGroupTransition
            WMExecutor.onSyncGroupTransition = function() transitionCalled = true end

            local v = makeVehicle("Main")
            WMExecutor:startWorkflow(main, v)
            local d = activeData(v)
            d.currentStep = 2  -- still group 1
            -- prevGroup = 1, newGroup for step 2 = 1 → no transition
            WMExecutor:handleLinkedWorkflowStepChange(d, 1)
            assert.is_false(transitionCalled)

            WMExecutor.onSyncGroupTransition = origFn
        end)

        it("triggers onSyncGroupTransition when main moves to a new group", function()
            local main, sup = makeLinkedPair()
            local transitions = {}
            local origFn = WMExecutor.onSyncGroupTransition
            WMExecutor.onSyncGroupTransition = function(_, mainData, from, to)
                table.insert(transitions, {from=from, to=to})
            end

            local v = makeVehicle("Main")
            WMExecutor:startWorkflow(main, v)
            local d = activeData(v)
            d.currentStep = 3  -- group 2
            -- prevGroup = 1, newGroup for step 3 = 2 → transition 1→2
            WMExecutor:handleLinkedWorkflowStepChange(d, 1)
            assert.are.equal(1, #transitions)
            assert.are.equal(1, transitions[1].from)
            assert.are.equal(2, transitions[1].to)

            WMExecutor.onSyncGroupTransition = origFn
        end)

        it("does nothing for unlinked workflow", function()
            local wf = makeWorkflow("wf_solo")
            local v = makeVehicle("Solo")
            WMExecutor:startWorkflow(wf, v)
            local d = activeData(v)
            -- linkRole is nil → should not error or set syncOverridden
            assert.has_no.errors(function()
                WMExecutor:handleLinkedWorkflowStepChange(d, 1)
            end)
            assert.is_nil(d.syncOverridden)
        end)
    end)

    -- =========================================================================
    -- onSyncGroupTransition
    -- =========================================================================
    describe("onSyncGroupTransition", function()
        local function makeLinkedVehicles()
            local main = {
                id = "wf_m", name = "Main", linkRole = "main", linkedWorkflowId = "wf_s",
                steps = {
                    { type = "autodrive",  target = "A", action = "drive",     syncGroup = 1 },
                    { type = "courseplay", target = "B", action = "fieldwork", syncGroup = 1 },
                    { type = "autodrive",  target = "C", action = "drive",     syncGroup = 2 },
                    { type = "courseplay", target = "D", action = "fieldwork", syncGroup = 2 },
                },
            }
            local sup = {
                id = "wf_s", name = "Support", linkRole = "support", linkedWorkflowId = "wf_m",
                steps = {
                    { type = "autodrive", target = "X", action = "unload", syncGroup = 1 },
                    { type = "autodrive", target = "Y", action = "unload", syncGroup = 2 },
                },
            }
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(main, vm)
            WMExecutor:startWorkflow(sup,  vs)
            -- Make WorkflowManager stub return the linked partner
            _G.WorkflowManager.getLinkedWorkflow = function(_, id)
                if id == "wf_m" then return sup end
                if id == "wf_s" then return main end
                return nil
            end
            return vm, vs, main, sup
        end

        before_each(function()
            -- Reset getLinkedWorkflow to default no-op after each test
        end)

        it("moves support to the step matching the new sync group", function()
            local vm, vs = makeLinkedVehicles()
            local mainData = activeData(vm)
            WMExecutor:onSyncGroupTransition(mainData, 1, 2)
            assert.are.equal(2, activeData(vs).currentStep)  -- step 2 has syncGroup=2
        end)

        it("clears syncOverridden on support after transition", function()
            local vm, vs = makeLinkedVehicles()
            activeData(vs).syncOverridden = true
            WMExecutor:onSyncGroupTransition(activeData(vm), 1, 2)
            assert.is_false(activeData(vs).syncOverridden)
        end)

        it("resets all tracking flags on support via resetStepTrackingState", function()
            local vm, vs = makeLinkedVehicles()
            local d = activeData(vs)
            d.pendingCPStart = true
            d.cpWasRunning   = true
            WMExecutor:onSyncGroupTransition(activeData(vm), 1, 2)
            assert.is_nil(activeData(vs).pendingCPStart)
            assert.is_false(activeData(vs).cpWasRunning)
        end)

        it("stops support workflow when no step matches the new group", function()
            local vm, vs = makeLinkedVehicles()
            WMExecutor:onSyncGroupTransition(activeData(vm), 1, 99)  -- group 99 doesn't exist
            assert.is_nil(activeData(vs))  -- support was stopped
        end)

        it("does nothing when support workflow is not running", function()
            local vm, vs = makeLinkedVehicles()
            WMExecutor:stopWorkflow(vs)
            assert.has_no.errors(function()
                WMExecutor:onSyncGroupTransition(activeData(vm), 1, 2)
            end)
        end)

        it("does nothing when support workflow has no active execution", function()
            local vm = makeVehicle("MainOnly")
            local main = {
                id = "wf_m2", name = "Main", linkRole = "main", linkedWorkflowId = "wf_s2",
                steps = {
                    { type = "autodrive", target = "A", action = "drive", syncGroup = 1 },
                    { type = "autodrive", target = "B", action = "drive", syncGroup = 2 },
                },
            }
            WMExecutor:startWorkflow(main, vm)
            _G.WorkflowManager.getLinkedWorkflow = function(_, id)
                if id == "wf_m2" then
                    return { id = "wf_s2", name = "Support", steps = {
                        { type = "autodrive", target = "X", action = "unload", syncGroup = 2 },
                    }}
                end
                return nil
            end
            -- Support is NOT running (no vehicle started it)
            assert.has_no.errors(function()
                WMExecutor:onSyncGroupTransition(activeData(vm), 1, 2)
            end)
            _G.WorkflowManager.getLinkedWorkflow = function() return nil end
        end)
    end)

    -- =========================================================================
    -- Linked workflow propagation: stop / pause / resume
    -- =========================================================================
    describe("linked workflow propagation", function()
        local function makeLinkedRunningPair(mainId, supId)
            local main = {
                id = mainId or "wf_main", name = "Main",
                linkRole = "main", linkedWorkflowId = supId or "wf_sup",
                steps = {
                    { type = "autodrive", target = "A", action = "drive", syncGroup = 1 },
                },
            }
            local sup = {
                id = supId or "wf_sup", name = "Support",
                linkRole = "support", linkedWorkflowId = mainId or "wf_main",
                steps = {
                    { type = "autodrive", target = "X", action = "unload", syncGroup = 1 },
                },
            }
            local vm = makeVehicle("MainV")
            local vs = makeVehicle("SupportV")
            WMExecutor:startWorkflow(main, vm)
            WMExecutor:startWorkflow(sup,  vs)
            return vm, vs, main, sup
        end

        describe("stopWorkflow propagation", function()
            it("stopping main also stops support", function()
                local vm, vs = makeLinkedRunningPair()
                WMExecutor:stopWorkflow(vm)
                assert.is_nil(activeData(vm))
                assert.is_nil(activeData(vs))
            end)

            it("stopping support alone does NOT stop main", function()
                local vm, vs = makeLinkedRunningPair()
                WMExecutor:stopWorkflow(vs)
                assert.is_nil(activeData(vs))
                assert.is_not_nil(activeData(vm))  -- main still running
            end)

            it("stopping already-stopped support is safe", function()
                local vm, vs = makeLinkedRunningPair()
                WMExecutor:stopWorkflow(vs)  -- stop support first
                assert.has_no.errors(function()
                    WMExecutor:stopWorkflow(vm)  -- stop main – support already gone
                end)
            end)
        end)

        describe("pauseWorkflow propagation", function()
            it("pausing main also pauses running support", function()
                local vm, vs = makeLinkedRunningPair()
                WMExecutor:pauseWorkflow(vm)
                assert.are.equal("paused", activeData(vm).status)
                assert.are.equal("paused", activeData(vs).status)
            end)

            it("pausing support alone does NOT pause main", function()
                local vm, vs = makeLinkedRunningPair()
                WMExecutor:pauseWorkflow(vs)
                assert.are.equal("paused", activeData(vs).status)
                assert.are.equal("running", activeData(vm).status)
            end)

            it("pausing main does not crash when support is already paused", function()
                local vm, vs = makeLinkedRunningPair()
                WMExecutor:pauseWorkflow(vs)  -- pre-pause support
                assert.has_no.errors(function()
                    WMExecutor:pauseWorkflow(vm)
                end)
            end)
        end)

        describe("resumeWorkflow propagation", function()
            it("resuming main also resumes paused support", function()
                local vm, vs = makeLinkedRunningPair()
                WMExecutor:pauseWorkflow(vm)  -- propagates pause to support
                WMExecutor:resumeWorkflow(vm)
                assert.are.equal("running", activeData(vm).status)
                assert.are.equal("running", activeData(vs).status)
            end)

            it("resuming support alone does NOT resume main", function()
                local vm, vs = makeLinkedRunningPair()
                WMExecutor:pauseWorkflow(vm)  -- pauses both
                WMExecutor:resumeWorkflow(vs)
                assert.are.equal("running", activeData(vs).status)
                assert.are.equal("paused",  activeData(vm).status)
            end)

            it("resuming main does not crash when support is already running", function()
                local vm, vs = makeLinkedRunningPair()
                WMExecutor:pauseWorkflow(vm)
                WMExecutor:resumeWorkflow(vs)   -- resume support independently
                assert.has_no.errors(function()
                    WMExecutor:resumeWorkflow(vm)
                end)
            end)
        end)
    end)

end)
