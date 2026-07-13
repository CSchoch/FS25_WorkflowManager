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
            STATUS_READY              = "ready",
            STATUS_RUNNING            = "running",
            STATUS_PAUSED             = "paused",
            STATUS_COMPLETED          = "completed",
            STATUS_ERROR              = "error",
            STATUS_WAITING_FOR_LEADER = "waiting_for_leader",
            STATUS_WAITING_FOR_MAIN   = "waiting_for_main",
            STEP_AUTODRIVE            = "autodrive",
            STEP_COURSEPLAY           = "courseplay",
            STEP_WAIT_FOR_LEADER      = "wait_for_leader",
            STEP_UNLOCK_FOLLOWER      = "unlock_follower",
            STEP_PARK                 = "park",
            STEP_REFUEL               = "refuel",
            STEP_REPAIR               = "repair",
            isAutoDriveTrackedStepType = function(self, stepType)
                return stepType == self.STEP_AUTODRIVE
                    or stepType == self.STEP_PARK
                    or stepType == self.STEP_REFUEL
                    or stepType == self.STEP_REPAIR
            end,
            broadcastState            = function() end,
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

    -- Create a simple 3-step test workflow (AD -> CP -> AD), each step with empty support array
    local function makeWorkflow(id)
        return {
            id    = id or "wf_001",
            name  = "Test Workflow",
            steps = {
                { type = "autodrive",  target = "Farm",   action = "drive",     support = {} },
                { type = "courseplay", target = "Field1", action = "fieldwork", support = {} },
                { type = "autodrive",  target = "Silo",   action = "unload", unloadTarget = "Silo", support = {} },
            },
        }
    end

    -- Workflow where step 2 (fieldwork) has 2 support sub-steps; others have none
    local function makeWorkflowWithSupport(id)
        return {
            id   = id or "wf_wsup",
            name = "Workflow With Support",
            steps = {
                { type = "autodrive",  target = "Farm",   action = "drive",     support = {} },
                { type = "courseplay", target = "Field1", action = "fieldwork", support = {
                    { type = "autodrive", target = "Field1", action = "unload", unloadTarget = "Silo" },
                    { type = "autodrive", target = "Silo",   action = "deliver" },
                }},
                { type = "autodrive",  target = "Farm2",  action = "drive",     support = {} },
            },
        }
    end

    -- Leader workflow with an unlock_follower marker at index 2 (syncTargets = {2})
    local function makeLeaderWF(id)
        return {
            id    = id or "wf_leader",
            name  = "Leader Workflow",
            steps = {
                { type = "autodrive",       target = "A", action = "drive", support = {} },
                { type = "unlock_follower", target = "", support = {} },
                { type = "autodrive",       target = "C", action = "drive", support = {} },
            },
        }
    end

    -- Follower workflow with a wait_for_leader marker at index 2 (syncSourceOrdinals = {[2]=1})
    local function makeFollowerWF(id)
        return {
            id    = id or "wf_follower",
            name  = "Follower Workflow",
            steps = {
                { type = "autodrive",      target = "A", action = "drive", support = {} },
                { type = "wait_for_leader", target = "", support = {} },
                { type = "autodrive",      target = "C", action = "drive", support = {} },
            },
        }
    end

    -- Fire one update tick (bypasses throttle). Call after arranging
    -- WAITING_FOR_LEADER / WAITING_FOR_MAIN state to simulate a poll tick.
    local function triggerPoll()
        WMExecutor.updateTimer = WMExecutor.UPDATE_INTERVAL
        WMExecutor:update(0)
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

        it("returns true when pausing a WAITING_FOR_LEADER follower", function()
            local leader   = makeVehicle("PL1")
            local follower = makeVehicle("PF1")
            WMExecutor:startWorkflow(makeLeaderWF("wf_pl1"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_pf1"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
            assert.is_true(WMExecutor:pauseWorkflow(follower))
        end)

        it("sets status to PAUSED when pausing from WAITING_FOR_LEADER", function()
            local leader   = makeVehicle("PL2")
            local follower = makeVehicle("PF2")
            WMExecutor:startWorkflow(makeLeaderWF("wf_pl2"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_pf2"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            WMExecutor:pauseWorkflow(follower)
            assert.are.equal(WorkflowManager.STATUS_PAUSED, activeData(follower).status)
        end)

        it("records wasWaitingForLeader in pausedTrackingState", function()
            local leader   = makeVehicle("PL3")
            local follower = makeVehicle("PF3")
            WMExecutor:startWorkflow(makeLeaderWF("wf_pl3"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_pf3"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            WMExecutor:pauseWorkflow(follower)
            assert.is_true(activeData(follower).pausedTrackingState.wasWaitingForLeader)
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

        it("restores WAITING_FOR_LEADER when wasWaitingForLeader was set on pause", function()
            local leader   = makeVehicle("RL1")
            local follower = makeVehicle("RF1")
            WMExecutor:startWorkflow(makeLeaderWF("wf_rl1"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_rf1"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            WMExecutor:pauseWorkflow(follower)
            WMExecutor:resumeWorkflow(follower)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
        end)

        it("resumes wait poller when restoring WAITING_FOR_LEADER", function()
            local leader   = makeVehicle("RL2")
            local follower = makeVehicle("RF2")
            WMExecutor:startWorkflow(makeLeaderWF("wf_rl2"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_rf2"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            WMExecutor:pauseWorkflow(follower)
            WMExecutor:resumeWorkflow(follower)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
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
    -- startWorkflow: isMain parameter
    -- =========================================================================
    describe("startWorkflow isMain parameter", function()
        it("defaults isMainVehicle=true when isMain not provided", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            assert.is_true(activeData(v).isMainVehicle ~= false)
        end)

        it("sets isMainVehicle=true when isMain=true", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v, true)
            assert.is_true(activeData(v).isMainVehicle ~= false)
        end)

        it("sets isMainVehicle=false when isMain=false", function()
            local wf = makeWorkflowWithSupport()
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)   -- main must be running first
            WMExecutor:startWorkflow(wf, vs, false)
            assert.are.equal(false, activeData(vs).isMainVehicle)
        end)

        it("sets currentSupportStep=nil for main vehicle", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v, true)
            assert.is_nil(activeData(v).currentSupportStep)
        end)

        it("sets currentSupportStep=1 for support vehicle", function()
            local wf = makeWorkflowWithSupport()
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            assert.are.equal(1, activeData(vs).currentSupportStep)
        end)
    end)

    -- =========================================================================
    -- getMainActiveDataForWorkflow / getSupportActiveDataListForWorkflow
    -- =========================================================================
    describe("role-typed helpers", function()
        it("getMainActiveDataForWorkflow returns main vehicle's activeData", function()
            local wf = makeWorkflowWithSupport("wf_r")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            local d = WMExecutor:getMainActiveDataForWorkflow("wf_r")
            assert.is_not_nil(d)
            assert.are.equal(vm, d.vehicle)
        end)

        it("getMainActiveDataForWorkflow returns nil when no main is running", function()
            local wf = makeWorkflowWithSupport("wf_r2")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vs, false)
            assert.is_nil(WMExecutor:getMainActiveDataForWorkflow("wf_r2"))
        end)

        it("getSupportActiveDataListForWorkflow returns support vehicles only", function()
            local wf = makeWorkflowWithSupport("wf_r3")
            local vm  = makeVehicle("Main")
            local vs1 = makeVehicle("S1")
            local vs2 = makeVehicle("S2")
            WMExecutor:startWorkflow(wf, vm,  true)
            WMExecutor:startWorkflow(wf, vs1, false)
            WMExecutor:startWorkflow(wf, vs2, false)
            local list = WMExecutor:getSupportActiveDataListForWorkflow("wf_r3")
            assert.are.equal(2, #list)
        end)

        it("getSupportActiveDataListForWorkflow does not include main vehicle", function()
            local wf = makeWorkflowWithSupport("wf_r4")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            local list = WMExecutor:getSupportActiveDataListForWorkflow("wf_r4")
            assert.are.equal(1, #list)
            assert.are.equal(vs, list[1].vehicle)
        end)
    end)

    -- =========================================================================
    -- getCurrentStep
    -- =========================================================================
    describe("getCurrentStep", function()
        it("returns main step for main vehicle", function()
            local wf = makeWorkflowWithSupport("wf_cs")
            local vm = makeVehicle()
            WMExecutor:startWorkflow(wf, vm, true)
            local d = activeData(vm)
            d.currentStep = 1
            local step = WMExecutor:getCurrentStep(d)
            assert.is_not_nil(step)
            assert.are.equal("autodrive", step.type)
        end)

        it("returns support sub-step for support vehicle", function()
            local wf = makeWorkflowWithSupport("wf_cs2")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            -- Main is on step 2 (fieldwork with 2 support sub-steps)
            activeData(vm).currentStep = 2
            local d = activeData(vs)
            d.currentSupportStep = 1
            local step = WMExecutor:getCurrentStep(d)
            assert.is_not_nil(step)
            assert.are.equal("autodrive", step.type)
            assert.are.equal("Field1", step.target)
        end)

        it("returns nil for support vehicle when main not running", function()
            local wf = makeWorkflowWithSupport("wf_cs3")
            local vs = makeVehicle("Support")
            -- Manually create activeData without running startWorkflow
            -- (to avoid auto-stop when no main is present)
            vs.spec_workflowManagerSpec.wmExecution = {
                workflow = wf,
                vehicle = vs,
                status = "running",
                currentStep = 1,
                currentSupportStep = 1,
                isMainVehicle = false,
                waitingForCompletion = false,
            }
            WMExecutor.activeVehicles[vs] = true
            -- No main vehicle running
            local step = WMExecutor:getCurrentStep(vs.spec_workflowManagerSpec.wmExecution)
            assert.is_nil(step)
        end)
    end)

    -- =========================================================================
    -- onMainStepChanged
    -- =========================================================================
    describe("onMainStepChanged", function()
        it("resets currentSupportStep to 1", function()
            local wf = makeWorkflowWithSupport("wf_msc")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            activeData(vm).currentStep = 2  -- step with support sub-steps
            local d = activeData(vs)
            d.currentSupportStep = 2
            WMExecutor:onMainStepChanged(d, 2)
            assert.are.equal(1, activeData(vs).currentSupportStep)
        end)

        it("clears waitingForMainStep", function()
            local wf = makeWorkflowWithSupport("wf_msc2")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            activeData(vm).currentStep = 2
            local d = activeData(vs)
            d.waitingForMainStep = true
            WMExecutor:onMainStepChanged(d, 2)
            assert.is_nil(activeData(vs).waitingForMainStep)
        end)

        it("paused support: sets pendingExecuteOnResume, does not start execution", function()
            local wf = makeWorkflowWithSupport("wf_msc_pause")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            activeData(vm).currentStep = 2
            local d = activeData(vs)
            d.status = WorkflowManager.STATUS_PAUSED
            WMExecutor:onMainStepChanged(d, 2)
            -- Must not have started execution (waitingForCompletion stays false)
            assert.is_false(d.waitingForCompletion)
            -- Must have staged the sub-step for when vehicle resumes
            assert.is_true(d.pendingExecuteOnResume)
            -- Sub-step index must be reset to 1
            assert.are.equal(1, d.currentSupportStep)
        end)

        it("paused support: executeCurrentStep called on resume after main step change", function()
            local wf = makeWorkflowWithSupport("wf_msc_resume")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            activeData(vm).currentStep = 2
            local d = activeData(vs)
            -- Pause the support vehicle
            WMExecutor:pauseWorkflow(vs)
            assert.are.equal(WorkflowManager.STATUS_PAUSED, d.status)
            -- Main advances while support is paused
            WMExecutor:onMainStepChanged(d, 2)
            assert.is_true(d.pendingExecuteOnResume)
            -- Resume — should call executeCurrentStep for the new sub-step
            WMExecutor:resumeWorkflow(vs)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, d.status)
            assert.is_nil(d.pendingExecuteOnResume)
            -- Sub-step should now be executing (waitingForCompletion set by startAutoDriveStep)
            assert.is_true(d.waitingForCompletion)
        end)

        it("resetStepTrackingState clears pendingExecuteOnResume", function()
            local wf = makeWorkflowWithSupport("wf_msc_rst")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            local d = activeData(vs)
            d.pendingExecuteOnResume = true
            WMExecutor:resetStepTrackingState(d)
            assert.is_nil(d.pendingExecuteOnResume)
        end)
    end)

    -- =========================================================================
    -- Support vehicle: execution and looping
    -- =========================================================================
    describe("support vehicle execution", function()
        it("support vehicle idles (WAITING_FOR_MAIN) when main step has no sub-steps", function()
            local wf = makeWorkflowWithSupport("wf_sv1")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            -- Main is on step 1 which has no support sub-steps
            local d = activeData(vs)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_MAIN, d.status)
            assert.is_true(d.waitingForMainStep == true)
        end)

        it("support vehicle executes sub-step when main step has sub-steps", function()
            local wf = makeWorkflowWithSupport("wf_sv2")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            -- Move main to step 2 (has support sub-steps) then trigger support
            activeData(vm).currentStep = 2
            WMExecutor:onMainStepChanged(activeData(vs), 2)
            -- Support should be waiting for completion (executing sub-step 1)
            local d = activeData(vs)
            assert.is_true(d.waitingForCompletion)
            assert.are.equal(1, d.currentSupportStep)
        end)

        it("support sub-step loops back to 1 after completing last sub-step", function()
            local wf = makeWorkflowWithSupport("wf_sv3")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            -- Move main to step 2 and support to sub-step 2 (last)
            activeData(vm).currentStep = 2
            local d = activeData(vs)
            d.currentSupportStep = 2
            d.waitingForMainStep = nil
            d.isMainVehicle = false
            d.waitingForCompletion = true
            d.currentStepType = "autodrive"
            -- Simulate completing sub-step 2
            WMExecutor:onStepCompleted(d)
            -- Should loop back to sub-step 1 (or re-execute)
            -- activeData may have been reset to step 1
            local da = activeData(vs)
            if da ~= nil then
                assert.are.equal(1, da.currentSupportStep)
            end
        end)
    end)

    -- =========================================================================
    -- Main completion does NOT stop support vehicles (they run independently)
    -- =========================================================================
    describe("main workflow completion stops support", function()
        it("onWorkflowCompleted does NOT stop support vehicles", function()
            local wf = makeWorkflowWithSupport("wf_comp")
            local vm  = makeVehicle("Main")
            local vs1 = makeVehicle("S1")
            local vs2 = makeVehicle("S2")
            WMExecutor:startWorkflow(wf, vm,  true)
            WMExecutor:startWorkflow(wf, vs1, false)
            WMExecutor:startWorkflow(wf, vs2, false)
            WMExecutor:onWorkflowCompleted(activeData(vm))
            assert.is_nil(activeData(vm))
            assert.is_not_nil(activeData(vs1))
            assert.is_not_nil(activeData(vs2))
        end)

        it("stopping support alone does NOT stop main", function()
            local wf = makeWorkflowWithSupport("wf_comp2")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm,  true)
            WMExecutor:startWorkflow(wf, vs, false)
            WMExecutor:stopWorkflow(vs)
            assert.is_nil(activeData(vs))
            assert.is_not_nil(activeData(vm))
        end)
    end)

    -- =========================================================================
    -- Pause/resume propagation with isMainVehicle
    -- =========================================================================
    describe("pause/resume propagation (isMainVehicle)", function()
        local function makeMainSupportPair(wfId)
            local wf = makeWorkflowWithSupport(wfId or "wf_pr")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm,  true)
            WMExecutor:startWorkflow(wf, vs, false)
            -- Ensure support is actually running (move main to step 2)
            activeData(vm).currentStep = 2
            WMExecutor:onMainStepChanged(activeData(vs), 2)
            return vm, vs
        end

        it("pausing main does NOT pause support vehicle", function()
            local vm, vs = makeMainSupportPair("wf_pr1")
            WMExecutor:pauseWorkflow(vm)
            assert.are.equal("paused",  activeData(vm).status)
            assert.are.equal("running", activeData(vs).status)
        end)

        it("pausing support alone does NOT pause main", function()
            local vm, vs = makeMainSupportPair("wf_pr2")
            WMExecutor:pauseWorkflow(vs)
            assert.are.equal("paused",  activeData(vs).status)
            assert.are.equal("running", activeData(vm).status)
        end)

        it("resuming main does not affect independently-running support", function()
            local vm, vs = makeMainSupportPair("wf_pr3")
            WMExecutor:pauseWorkflow(vm)
            WMExecutor:resumeWorkflow(vm)
            assert.are.equal("running", activeData(vm).status)
            assert.are.equal("running", activeData(vs).status)
        end)

        it("resuming support alone does NOT resume main", function()
            local vm, vs = makeMainSupportPair("wf_pr4")
            WMExecutor:pauseWorkflow(vm)
            WMExecutor:resumeWorkflow(vs)
            assert.are.equal("running", activeData(vs).status)
            assert.are.equal("paused",  activeData(vm).status)
        end)
    end)

    -- (findStepByGroup section removed — function no longer exists)

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
                cpHandedOffToAD      = true,
                cpHandedOffWait      = 1,
                cpWasRunning         = true,
                pausedTrackingState  = { something = true },
                pendingCPStart       = true,
                pendingCPStartRetries = 3,
                cpToCpTransition     = true,
                pendingADStart       = true,
                pendingADStartRetries = 2,
            }
            WMExecutor:resetStepTrackingState(d)
            assert.is_false(d.waitingForCompletion)
            assert.is_false(d.cpHandedOffToAD)
            assert.is_nil(d.cpHandedOffWait)
            assert.is_false(d.cpWasRunning)
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
    -- AD->CP transition: WM starts CP directly after AD completes
    -- =========================================================================
    describe("AD->CP transition", function()
        local wfAdThenCp = {
            id = "wf_adcp", name = "AD then CP",
            steps = {
                { type = "autodrive",  target = "Farm",   action = "drive",     support = {} },
                { type = "courseplay", target = "Field1", action = "fieldwork", support = {} },
            }
        }

        it("starts CP directly via executeCurrentStep after AD completes", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfAdThenCp, v)
            local d = activeData(v)
            assert.are.equal(WorkflowManager.STEP_AUTODRIVE, d.currentStepType)

            -- Simulate AD completing: step advances but execution is deferred 2s
            WMExecutor:onStepCompleted(d)
            assert.are.equal(2, d.currentStep)
            assert.is_not_nil(d.pendingAutoStep)
            assert.are.equal(g_currentMission.time + 2000, d.pendingAutoStep)

            -- Advance time past the deferred timer and poll
            g_currentMission.time = d.pendingAutoStep + 1
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)

            -- CP step should now be started
            assert.are.equal(WorkflowManager.STEP_COURSEPLAY, d.currentStepType)
            assert.is_true(d.waitingForCompletion)
        end)
    end)


    -- =========================================================================
    -- getActiveVehiclesForWorkflow
    -- =========================================================================
    describe("getActiveVehiclesForWorkflow", function()
        it("returns empty array when no vehicle runs that workflow", function()
            local result = WMExecutor:getActiveVehiclesForWorkflow("wf_ghost")
            assert.are.equal(0, #result)
        end)

        it("returns one entry when one vehicle runs that workflow", function()
            local wf = makeWorkflow("wf_x")
            local v  = makeVehicle("V1")
            WMExecutor:startWorkflow(wf, v)
            local result = WMExecutor:getActiveVehiclesForWorkflow("wf_x")
            assert.are.equal(1, #result)
            assert.are.equal(activeData(v), result[1])
        end)

        it("returns two entries when two vehicles share the same workflow", function()
            local wf = makeWorkflow("wf_shared")
            local v1 = makeVehicle("V1")
            local v2 = makeVehicle("V2")
            WMExecutor:startWorkflow(wf, v1)
            WMExecutor:startWorkflow(wf, v2)
            local result = WMExecutor:getActiveVehiclesForWorkflow("wf_shared")
            assert.are.equal(2, #result)
        end)

        it("does not return vehicles running a different workflow", function()
            local wfA = makeWorkflow("wf_a")
            local wfB = makeWorkflow("wf_b")
            local vA  = makeVehicle("VA")
            local vB  = makeVehicle("VB")
            WMExecutor:startWorkflow(wfA, vA)
            WMExecutor:startWorkflow(wfB, vB)
            local result = WMExecutor:getActiveVehiclesForWorkflow("wf_a")
            assert.are.equal(1, #result)
            assert.are.equal(activeData(vA), result[1])
        end)
    end)


    -- =========================================================================
    -- Leader-follower synchronization (marker steps)
    -- =========================================================================
    describe("leader-follower synchronization", function()
        it("startWorkflow stores leaderVehicle on activeData", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_ldr_store"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_f_store"), follower, true, leader)
            assert.are.equal(leader, activeData(follower).leaderVehicle)
        end)

        it("non-marker first step runs freely regardless of leader", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_ldr_run"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_f_run"), follower, true, leader)
            -- Follower starts on step 1 (an AD step, not a wait marker) → runs
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("no leader: wait_for_leader marker passes straight through", function()
            local follower = makeVehicle("Solo")
            WMExecutor:startWorkflow(makeFollowerWF("wf_solo"), follower, true, nil)
            -- Move onto the wait marker (step 2); with no leader it must pass through
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            -- Passed through the marker to the next work step
            assert.are.equal(3, activeData(follower).currentStep)
        end)

        it("unlock_follower marker passes straight through for the leader", function()
            local leader = makeVehicle("Leader")
            WMExecutor:startWorkflow(makeLeaderWF("wf_unlock"), leader)
            activeData(leader).currentStep = 2  -- the unlock marker
            activeData(leader).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(leader))
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(leader).status)
            assert.are.equal(3, activeData(leader).currentStep)
        end)

        it("follower blocks at wait marker until leader reaches unlock marker", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_block"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_f_block"), follower, true, leader)
            -- Follower reaches wait marker (step 2) while leader still on step 1 → waits
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
            -- Leader reaches its unlock marker (step 2) → follower resumes via poll
            activeData(leader).currentStep = 2
            triggerPoll()
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("follower waiting at marker registers global wait poller", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_poll"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_f_poll"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
        end)

        it("frees follower and resumes when leader stops", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_stop"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_f_stop"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
            WMExecutor:stopWorkflow(leader)
            triggerPoll()
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.is_nil(activeData(follower).leaderVehicle)
        end)

        it("frees follower when leader restarts the same workflow", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_restart"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_f_restart"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
            -- Leader stops and restarts → new wmExecution table, same workflow id
            WMExecutor:stopWorkflow(leader)
            WMExecutor:startWorkflow(makeLeaderWF("wf_restart"), leader)
            triggerPoll()
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.is_nil(activeData(follower).leaderVehicle)
            assert.is_nil(activeData(follower).linkedLeaderExecution)
        end)

        it("detaches leader and goes standalone when leader finishes while follower isn't blocked at a wait marker", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_finish_free"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_f_finish_free"), follower, true, leader)
            -- Follower is still on step 1 (running its own AutoDrive step), not at the wait marker
            assert.are.equal(1, activeData(follower).currentStep)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.are.equal(leader, activeData(follower).leaderVehicle)

            WMExecutor:stopWorkflow(leader)
            triggerPoll()

            -- Follower keeps running its own step but is no longer tied to the leader
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.are.equal(1, activeData(follower).currentStep)
            assert.is_nil(activeData(follower).leaderVehicle)
            assert.is_nil(activeData(follower).linkedLeaderExecution)
        end)
    end)

    -- =========================================================================
    -- buildSyncMaps (marker steps)
    -- =========================================================================
    describe("buildSyncMaps", function()
        it("syncTargets lists leader unlock_follower step indices in order", function()
            local wf = {
                id = "wf_sm_t", name = "T",
                steps = {
                    { type = "autodrive",       target = "A", action = "drive", support = {} },
                    { type = "unlock_follower", target = "", support = {} },
                    { type = "autodrive",       target = "C", action = "drive", support = {} },
                    { type = "unlock_follower", target = "", support = {} },
                },
            }
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_sm_tf"), follower, true, leader)
            assert.are.same({2, 4}, activeData(follower).syncTargets)
        end)

        it("leader with no unlock markers: syncTargets is empty", function()
            local leader   = makeVehicle("L2")
            local follower = makeVehicle("F2")
            WMExecutor:startWorkflow(makeWorkflow("wf_sm_none"), leader)  -- AD/CP/AD, no markers
            WMExecutor:startWorkflow(makeFollowerWF("wf_sm_nonef"), follower, true, leader)
            assert.are.same({}, activeData(follower).syncTargets)
        end)

        it("syncSourceOrdinals maps each wait_for_leader step to its ordinal", function()
            local wf = {
                id = "wf_sm_s", name = "S",
                steps = {
                    { type = "wait_for_leader", target = "", support = {} },
                    { type = "autodrive",       target = "B", action = "drive", support = {} },
                    { type = "wait_for_leader", target = "", support = {} },
                },
            }
            local leader   = makeVehicle("L3")
            local follower = makeVehicle("F3")
            WMExecutor:startWorkflow(makeLeaderWF("wf_sm_sl"), leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            local ord = activeData(follower).syncSourceOrdinals
            assert.are.equal(1, ord[1])
            assert.is_nil(ord[2])
            assert.are.equal(2, ord[3])
        end)

        it("no leader: syncTargets and syncSourceOrdinals are nil", function()
            local v = makeVehicle("Solo")
            WMExecutor:startWorkflow(makeFollowerWF("wf_sm_noldr"), v, true, nil)
            assert.is_nil(activeData(v).syncTargets)
            assert.is_nil(activeData(v).syncSourceOrdinals)
        end)
    end)

    -- =========================================================================
    -- Sync conditions: executeCurrentStep + update poll (marker steps)
    -- =========================================================================
    describe("marker sync conditions", function()
        it("wait marker resumes when leader reaches the paired unlock marker", function()
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(makeLeaderWF("wf_mc_resume"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_mc_resume_f"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
            activeData(leader).currentStep = 2
            triggerPoll()
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("more wait markers than unlock markers: extra wait waits until leader finishes", function()
            local fwf = {
                id = "wf_mc_extra_f", name = "ExtraF",
                steps = {
                    { type = "wait_for_leader", target = "", support = {} },  -- ordinal 1 → unlock @2
                    { type = "autodrive",       target = "B", action = "drive", support = {} },
                    { type = "wait_for_leader", target = "", support = {} },  -- ordinal 2 → no unlock
                    { type = "autodrive",       target = "D", action = "drive", support = {} },
                },
            }
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(makeLeaderWF("wf_mc_extra"), leader)  -- one unlock at index 2
            WMExecutor:startWorkflow(fwf, follower, true, leader)
            -- Leader already at its unlock (step 2); follower's 2nd wait has no unlock → waits
            activeData(leader).currentStep = 2
            activeData(follower).currentStep = 3
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
            -- Leader finishes → follower freed
            leader.spec_workflowManagerSpec.wmExecution = nil
            triggerPoll()
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("leader already past unlock before follower reaches wait: passes through", function()
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(makeLeaderWF("wf_mc_past"), leader)
            activeData(leader).currentStep = 3  -- already past the unlock at index 2
            WMExecutor:startWorkflow(makeFollowerWF("wf_mc_past_f"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.are.equal(3, activeData(follower).currentStep)
        end)

        it("poll keeps follower waiting until leader reaches unlock marker", function()
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(makeLeaderWF("wf_mc_poll"), leader)
            WMExecutor:startWorkflow(makeFollowerWF("wf_mc_poll_f"), follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_WAITING_FOR_LEADER
            -- Leader still on step 1 (< unlock index 2) → stays waiting
            triggerPoll()
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
            -- Leader reaches unlock → resumes
            activeData(leader).currentStep = 2
            triggerPoll()
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)
    end)

    -- =========================================================================
    -- save/load restore: nil sync maps (marker steps)
    -- =========================================================================
    describe("save/load restore: nil sync maps", function()
        -- Build a follower exec that mimics onPostLoad restore — leaderVehicle and
        -- linkedLeaderExecution are set, sitting on the wait marker, but maps are nil.
        local function makeRestoredFollower(wf, follower, leaderExec)
            local exec = {
                workflow              = wf,
                vehicle               = follower,
                status                = WorkflowManager.STATUS_RUNNING,
                currentStep           = 2,  -- the wait_for_leader marker
                isMainVehicle         = true,
                waitingForCompletion  = false,
                leaderVehicle         = leaderExec.vehicle,
                linkedLeaderExecution = leaderExec,
                syncSourceOrdinals    = nil,
                syncTargets           = nil,
            }
            follower.spec_workflowManagerSpec.wmExecution = exec
            WMExecutor.activeVehicles[follower] = true
            return exec
        end

        it("executeCurrentStep rebuilds nil sync maps and waits when leader has not reached unlock", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_rs_wait"), leader)  -- leader on step 1
            local followerExec = makeRestoredFollower(makeFollowerWF("wf_rs_wait_f"), follower, activeData(leader))
            WMExecutor:executeCurrentStep(followerExec)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, followerExec.status)
            assert.is_not_nil(followerExec.syncSourceOrdinals)
            assert.is_not_nil(followerExec.syncTargets)
        end)

        it("executeCurrentStep rebuilds nil sync maps and runs when leader already past unlock", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_rs_free"), leader)
            activeData(leader).currentStep = 3  -- past unlock at index 2
            local followerExec = makeRestoredFollower(makeFollowerWF("wf_rs_free_f"), follower, activeData(leader))
            WMExecutor:executeCurrentStep(followerExec)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, followerExec.status)
        end)

        it("update poll rebuilds nil sync maps and keeps follower waiting", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_rs_poll"), leader)
            local followerExec = makeRestoredFollower(makeFollowerWF("wf_rs_poll_f"), follower, activeData(leader))
            followerExec.status = WorkflowManager.STATUS_WAITING_FOR_LEADER
            triggerPoll()
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, followerExec.status)
            assert.is_not_nil(followerExec.syncSourceOrdinals)
        end)

        it("update poll rebuilds nil sync maps and unblocks when leader advances", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_rs_unblock"), leader)
            local followerExec = makeRestoredFollower(makeFollowerWF("wf_rs_unblock_f"), follower, activeData(leader))
            followerExec.status = WorkflowManager.STATUS_WAITING_FOR_LEADER
            activeData(leader).currentStep = 2  -- reach unlock
            triggerPoll()
            assert.are.equal(WorkflowManager.STATUS_RUNNING, followerExec.status)
        end)
    end)

    -- =========================================================================
    -- goToPreviousStep / goToNextStep: STATUS_WAITING_FOR_LEADER reset
    -- =========================================================================
    describe("goToPreviousStep / goToNextStep: WAITING_FOR_LEADER reset", function()
        local wf = {
            id = "wf_nav_wfl", name = "NavWFL",
            steps = {
                { type = "autodrive", target = "A", action = "drive", support = {} },
                { type = "autodrive", target = "B", action = "drive", support = {} },
                { type = "autodrive", target = "C", action = "drive", support = {} },
            },
        }

        it("goToPreviousStep resumes from WAITING_FOR_LEADER to RUNNING", function()
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_WAITING_FOR_LEADER
            WMExecutor:goToPreviousStep(follower)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.are.equal(1, activeData(follower).currentStep)
        end)

        it("goToNextStep resumes from WAITING_FOR_LEADER to RUNNING", function()
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Advance leader to step 2 so the sync condition is already satisfied
            -- (without this the follower would re-enter WAITING_FOR_LEADER after nav)
            activeData(leader).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_WAITING_FOR_LEADER
            WMExecutor:goToNextStep(follower)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.are.equal(2, activeData(follower).currentStep)
        end)
    end)

    -- =========================================================================
    -- pending leader resolution: executeCurrentStep safety-net vs runWaitPoll
    -- Both share the same loop; this section pins both paths against regression.
    -- =========================================================================
    describe("pending leader resolution", function()
        -- Build a follower exec that mimics save/load restore when the leader
        -- has not yet appeared in activeVehicles: leaderVehicle is nil and
        -- pendingLeaderXmlIndex is set.  The follower is placed on step 1 (AD)
        -- so executeCurrentStep can proceed after resolution without hitting a
        -- wait_for_leader marker.
        local function makePendingFollowerExec(follower, wf, xmlIndex)
            local exec = {
                workflow              = wf,
                vehicle               = follower,
                status                = WorkflowManager.STATUS_RUNNING,
                currentStep           = 1,
                isMainVehicle         = true,
                waitingForCompletion  = false,
                leaderVehicle         = nil,
                pendingLeaderXmlIndex = xmlIndex,
            }
            follower.spec_workflowManagerSpec.wmExecution = exec
            WMExecutor.activeVehicles[follower] = true
            return exec
        end

        it("executeCurrentStep resolves pendingLeaderXmlIndex before the first poll tick", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(makeLeaderWF("wf_pend_exec_l"), leader)
            leader.spec_workflowManagerSpec.wmXmlIndex = 77

            local followerExec = makePendingFollowerExec(follower, makeFollowerWF("wf_pend_exec_f"), 77)

            -- Simulate manual resume before any poll tick fires
            WMExecutor:executeCurrentStep(followerExec)

            assert.are.equal(leader, followerExec.leaderVehicle)
            assert.is_nil(followerExec.pendingLeaderXmlIndex)
        end)

        it("runWaitPoll resolves pendingLeaderXmlIndex when leader loads after follower", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")

            -- Follower is waiting; leader not yet in activeVehicles
            local followerExec = makePendingFollowerExec(follower, makeFollowerWF("wf_pend_poll_f"), 42)
            followerExec.status = WorkflowManager.STATUS_WAITING_FOR_LEADER

            -- Leader arrives with matching wmXmlIndex
            WMExecutor:startWorkflow(makeLeaderWF("wf_pend_poll_l"), leader)
            leader.spec_workflowManagerSpec.wmXmlIndex = 42

            triggerPoll()

            assert.are.equal(leader, followerExec.leaderVehicle)
            assert.is_nil(followerExec.pendingLeaderXmlIndex)
        end)

        it("executeCurrentStep blocks at WAIT_FOR_LEADER when pendingLeaderXmlIndex is unresolved", function()
            local follower = makeVehicle("Follower")
            local wf = makeFollowerWF("wf_pend_block_f")
            -- Follower at the wait_for_leader step (step 2) with unresolved leader
            local followerExec = {
                workflow              = wf,
                vehicle               = follower,
                status                = WorkflowManager.STATUS_RUNNING,
                currentStep           = 2,
                isMainVehicle         = true,
                waitingForCompletion  = false,
                leaderVehicle         = nil,
                pendingLeaderXmlIndex = 99,
            }
            follower.spec_workflowManagerSpec.wmExecution = followerExec
            WMExecutor.activeVehicles[follower] = true
            -- No leader in activeVehicles — tryResolvePendingLeader will fail

            WMExecutor:executeCurrentStep(followerExec)

            -- Must block, not pass through the wait gate
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, followerExec.status)
            assert.are.equal(2, followerExec.currentStep)
            assert.are.equal(99, followerExec.pendingLeaderXmlIndex)
        end)

        it("runWaitPoll blocks WAITING_FOR_LEADER follower when pendingLeaderXmlIndex is still unresolved", function()
            local follower = makeVehicle("Follower")
            local wf = makeFollowerWF("wf_pend_poll_block_f")
            local followerExec = {
                workflow              = wf,
                vehicle               = follower,
                status                = WorkflowManager.STATUS_WAITING_FOR_LEADER,
                currentStep           = 2,
                isMainVehicle         = true,
                waitingForCompletion  = false,
                leaderVehicle         = nil,
                pendingLeaderXmlIndex = 88,
            }
            follower.spec_workflowManagerSpec.wmExecution = followerExec
            WMExecutor.activeVehicles[follower] = true
            -- No leader in activeVehicles

            triggerPoll()

            -- Must stay blocked
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, followerExec.status)
            assert.are.equal(2, followerExec.currentStep)
        end)

        -- Same coverage as pendingLeaderXmlIndex above, but keyed on the vehicle's own
        -- engine-assigned uniqueId (stable across save/load, unlike a positional index).
        local function makePendingFollowerExecByUid(follower, wf, uniqueId)
            local exec = {
                workflow              = wf,
                vehicle               = follower,
                status                = WorkflowManager.STATUS_RUNNING,
                currentStep           = 1,
                isMainVehicle         = true,
                waitingForCompletion  = false,
                leaderVehicle         = nil,
                pendingLeaderUniqueId = uniqueId,
            }
            follower.spec_workflowManagerSpec.wmExecution = exec
            WMExecutor.activeVehicles[follower] = true
            return exec
        end

        it("executeCurrentStep resolves pendingLeaderUniqueId before the first poll tick", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            leader.uniqueId = "vehicleUID_A"
            WMExecutor:startWorkflow(makeLeaderWF("wf_pend_uid_exec_l"), leader)

            local followerExec = makePendingFollowerExecByUid(follower, makeFollowerWF("wf_pend_uid_exec_f"), "vehicleUID_A")

            WMExecutor:executeCurrentStep(followerExec)

            assert.are.equal(leader, followerExec.leaderVehicle)
            assert.is_nil(followerExec.pendingLeaderUniqueId)
        end)

        it("runWaitPoll resolves pendingLeaderUniqueId when leader loads after follower", function()
            local leader   = makeVehicle("Leader")
            local follower = makeVehicle("Follower")

            local followerExec = makePendingFollowerExecByUid(follower, makeFollowerWF("wf_pend_uid_poll_f"), "vehicleUID_B")
            followerExec.status = WorkflowManager.STATUS_WAITING_FOR_LEADER

            leader.uniqueId = "vehicleUID_B"
            WMExecutor:startWorkflow(makeLeaderWF("wf_pend_uid_poll_l"), leader)

            triggerPoll()

            assert.are.equal(leader, followerExec.leaderVehicle)
            assert.is_nil(followerExec.pendingLeaderUniqueId)
        end)

        it("executeCurrentStep blocks at WAIT_FOR_LEADER when pendingLeaderUniqueId is unresolved", function()
            local follower = makeVehicle("Follower")
            local wf = makeFollowerWF("wf_pend_uid_block_f")
            local followerExec = {
                workflow              = wf,
                vehicle               = follower,
                status                = WorkflowManager.STATUS_RUNNING,
                currentStep           = 2,
                isMainVehicle         = true,
                waitingForCompletion  = false,
                leaderVehicle         = nil,
                pendingLeaderUniqueId = "vehicleUID_NOTFOUND",
            }
            follower.spec_workflowManagerSpec.wmExecution = followerExec
            WMExecutor.activeVehicles[follower] = true

            WMExecutor:executeCurrentStep(followerExec)

            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, followerExec.status)
            assert.are.equal(2, followerExec.currentStep)
            assert.are.equal("vehicleUID_NOTFOUND", followerExec.pendingLeaderUniqueId)
        end)
    end)

    -- =========================================================================
    -- STATUS_WAITING_FOR_MAIN: global poller, poll-triggered resume, pause/resume
    -- =========================================================================
    describe("STATUS_WAITING_FOR_MAIN", function()

        it("global wait poller is registered when support enters WAITING_FOR_MAIN", function()
            local wf = makeWorkflowWithSupport("wf_wfm_poll")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            -- Main on step 1 (no sub-steps) → support should be in WAITING_FOR_MAIN
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_MAIN, activeData(vs).status)
        end)

        it("poll triggers support to start sub-step when main advances to a step with sub-steps", function()
            local wf = makeWorkflowWithSupport("wf_wfm_trigger")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_MAIN, activeData(vs).status)
            -- Main advances to step 2 (has 2 support sub-steps)
            activeData(vm).currentStep = 2
            triggerPoll()
            -- Support should now be executing sub-step 1 (RUNNING, waitingForCompletion)
            local d = activeData(vs)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, d.status)
            assert.is_true(d.waitingForCompletion)
        end)

        it("poll does nothing if main step changed but still has no sub-steps", function()
            local wf = makeWorkflowWithSupport("wf_wfm_nostep")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_MAIN, activeData(vs).status)
            -- Main advances to step 3 (no sub-steps) — support stays waiting
            activeData(vm).currentStep = 3
            triggerPoll()
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_MAIN, activeData(vs).status)
        end)

        it("can pause from WAITING_FOR_MAIN and resume returns to WAITING_FOR_MAIN", function()
            local wf = makeWorkflowWithSupport("wf_wfm_pause")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_MAIN, activeData(vs).status)
            WMExecutor:pauseWorkflow(vs)
            assert.are.equal(WorkflowManager.STATUS_PAUSED, activeData(vs).status)
            WMExecutor:resumeWorkflow(vs)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_MAIN, activeData(vs).status)
        end)

        it("goToNextStep resumes from WAITING_FOR_MAIN to RUNNING", function()
            local wf = makeWorkflowWithSupport("wf_wfm_nav")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_MAIN, activeData(vs).status)
            -- Move main to step 2 first so there is a step to navigate to
            activeData(vm).currentStep = 2
            WMExecutor:goToNextStep(vs)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(vs).status)
        end)

        it("support stops when main stops while support is in WAITING_FOR_MAIN", function()
            local wf = makeWorkflowWithSupport("wf_wfm_mainstop")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_MAIN, activeData(vs).status)
            -- Main stops → poll detects mainActiveData == nil → stop support
            WMExecutor:stopWorkflow(vm)
            triggerPoll()
            assert.is_nil(activeData(vs))
        end)

    end)

    -- =========================================================================
    -- CP refill cycle: setStartHelper set on CP step start
    -- =========================================================================
    describe("CP refill cycle: setStartCPOnCompletion", function()
        local wfCp = {
            id = "wf_cp_refill", name = "CP Refill",
            steps = {
                { type = "courseplay", target = "Field1", action = "fieldwork", support = {} },
            },
        }
        local wfAd = {
            id = "wf_ad_refill", name = "AD Refill",
            steps = {
                { type = "autodrive", target = "Farm", action = "drive", support = {} },
            },
        }

        it("setStartCPOnCompletion(true) called when CP step starts", function()
            local called = false
            local origFn = ADIntegration.setStartCPOnCompletion
            ADIntegration.setStartCPOnCompletion = function(_, _, enabled)
                if enabled == true then called = true end
            end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfCp, v)
            ADIntegration.setStartCPOnCompletion = origFn
            assert.is_true(called)
        end)

        it("clearCPHandoff called when AD step starts", function()
            local called = false
            local origFn = ADIntegration.clearCPHandoff
            ADIntegration.clearCPHandoff = function()
                called = true
            end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfAd, v)
            ADIntegration.clearCPHandoff = origFn
            assert.is_true(called)
        end)

        it("clearCPHandoff called even when startRoute fails", function()
            local cleared = false
            local origStart = ADIntegration.startRoute
            local origClear = ADIntegration.clearCPHandoff
            ADIntegration.startRoute   = function() return false end
            ADIntegration.clearCPHandoff = function() cleared = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfAd, v)
            ADIntegration.startRoute   = origStart
            ADIntegration.clearCPHandoff = origClear
            assert.is_true(cleared)  -- must disarm setStartHelper even when AD route fails to start
        end)
    end)

    -- =========================================================================
    -- Park step: drive to AD park position (reuses AD start/stop/pause/poll)
    -- =========================================================================
    describe("Park step", function()
        local wfPark = {
            id = "wf_park", name = "Park Workflow",
            steps = {
                { type = "park", target = "", support = {} },
            },
        }
        local wfAdThenPark = {
            id = "wf_ad_park", name = "AD then Park",
            steps = {
                { type = "autodrive", target = "Farm", action = "drive", support = {} },
                { type = "park",      target = "",     support = {} },
            },
        }

        it("startParkRoute called and currentStepType set to STEP_PARK on start", function()
            local called = false
            local origFn = ADIntegration.startParkRoute
            ADIntegration.startParkRoute = function(_, _) called = true; return true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfPark, v)
            ADIntegration.startParkRoute = origFn
            local d = activeData(v)
            assert.is_true(called)
            assert.are.equal(WorkflowManager.STEP_PARK, d.currentStepType)
            assert.is_true(d.waitingForCompletion)
        end)

        it("handleStepError (STATUS_ERROR) when no park position is configured", function()
            -- Start a normal workflow first to obtain a valid activeData/vehicle pair,
            -- then drive startParkStep directly so we can hold a reference to the
            -- activeData table from before handleStepError->stopWorkflow clears it
            -- off the vehicle spec (the table itself keeps its .status field).
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            local d = activeData(v)

            local origFn = ADIntegration.startParkRoute
            ADIntegration.startParkRoute = function(_, _) return false end
            WMExecutor:startParkStep(d, v, { type = "park", target = "" })
            ADIntegration.startParkRoute = origFn

            assert.are.equal(WorkflowManager.STATUS_ERROR, d.status)
            assert.is_nil(activeData(v))  -- wmExecution cleared by stopWorkflow
        end)

        it("clearCPHandoff called when Park step starts", function()
            local called = false
            local origFn = ADIntegration.clearCPHandoff
            ADIntegration.clearCPHandoff = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfPark, v)
            ADIntegration.clearCPHandoff = origFn
            assert.is_true(called)
        end)

        it("onADFinishedEvent completes a Park step (currentStepType == STEP_PARK)", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfPark, v)
            local d = activeData(v)
            assert.is_true(d.waitingForCompletion)

            WMExecutor:onADFinishedEvent({ vehicle = v })
            -- wfPark is a single-step workflow, so completion clears wmExecution entirely
            assert.is_nil(activeData(v))
            assert.is_false(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)

        it("completion poll (isRouteComplete) advances a Park step", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfPark, v)

            local origComplete = ADIntegration.isRouteComplete
            ADIntegration.isRouteComplete = function() return true end
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            ADIntegration.isRouteComplete = origComplete

            -- wfPark is a single-step workflow, so completion clears wmExecution entirely
            assert.is_nil(activeData(v))
            assert.is_false(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)

        it("pauseCurrentStep calls ADIntegration:pauseRoute for a Park step", function()
            local called = false
            local origFn = ADIntegration.pauseRoute
            ADIntegration.pauseRoute = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfPark, v)
            local d = activeData(v)
            WMExecutor:pauseCurrentStep(d)
            ADIntegration.pauseRoute = origFn
            assert.is_true(called)
        end)

        it("resumeCurrentStep calls ADIntegration:resumeRoute for a Park step", function()
            local called = false
            local origFn = ADIntegration.resumeRoute
            ADIntegration.resumeRoute = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfPark, v)
            local d = activeData(v)
            WMExecutor:resumeCurrentStep(d)
            ADIntegration.resumeRoute = origFn
            assert.is_true(called)
        end)

        it("stopCurrentStep calls ADIntegration:stopRoute for a Park step", function()
            local called = false
            local origFn = ADIntegration.stopRoute
            ADIntegration.stopRoute = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfPark, v)
            local d = activeData(v)
            WMExecutor:stopCurrentStep(d)
            ADIntegration.stopRoute = origFn
            assert.is_true(called)
        end)

        it("starts Park directly via executeCurrentStep after AD completes", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfAdThenPark, v)
            local d = activeData(v)
            assert.are.equal(WorkflowManager.STEP_AUTODRIVE, d.currentStepType)

            -- Simulate AD completing: step advances but execution is deferred 2s
            WMExecutor:onStepCompleted(d)
            assert.are.equal(2, d.currentStep)
            assert.is_not_nil(d.pendingAutoStep)

            -- Advance time past the deferred timer and poll
            g_currentMission.time = d.pendingAutoStep + 1
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)

            assert.are.equal(WorkflowManager.STEP_PARK, d.currentStepType)
            assert.is_true(d.waitingForCompletion)
        end)

        it("resolvePendingADStart routes to startParkStep (not startAutoDriveStep) when deferred", function()
            local adStillRunning = true
            local origIsRunning = ADIntegration.isRunning
            local origStartRoute = ADIntegration.startRoute
            local parkStarted = false
            local adStarted = false
            ADIntegration.isRunning = function() return adStillRunning end
            ADIntegration.startRoute = function() adStarted = true; return true end
            local origStartPark = ADIntegration.startParkRoute
            ADIntegration.startParkRoute = function() parkStarted = true; return true end

            local v = makeVehicle()
            -- AD reports running -> Park start is deferred via pendingADStart
            WMExecutor:startWorkflow(wfPark, v)
            local d = activeData(v)
            assert.is_true(d.pendingADStart)
            assert.is_false(parkStarted)

            -- AD stops; two poll cycles should release the deferred Park start
            adStillRunning = false
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)

            ADIntegration.isRunning = origIsRunning
            ADIntegration.startRoute = origStartRoute
            ADIntegration.startParkRoute = origStartPark

            assert.is_true(parkStarted)
            assert.is_false(adStarted)
        end)
    end)

    -- =========================================================================
    -- Refuel step: drive to AD's nearest matching fuel station (reuses AD machinery)
    -- =========================================================================
    describe("Refuel step", function()
        local wfRefuel = {
            id = "wf_refuel", name = "Refuel Workflow",
            steps = {
                { type = "refuel", target = "", support = {} },
            },
        }
        local wfAdThenRefuel = {
            id = "wf_ad_refuel", name = "AD then Refuel",
            steps = {
                { type = "autodrive", target = "Farm", action = "drive", support = {} },
                { type = "refuel",    target = "",     support = {} },
            },
        }

        it("startRefuelRoute called and currentStepType set to STEP_REFUEL on start", function()
            local called = false
            local origFn = ADIntegration.startRefuelRoute
            ADIntegration.startRefuelRoute = function(_, _) called = true; return true, false end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRefuel, v)
            ADIntegration.startRefuelRoute = origFn
            local d = activeData(v)
            assert.is_true(called)
            assert.are.equal(WorkflowManager.STEP_REFUEL, d.currentStepType)
            assert.is_true(d.waitingForCompletion)
        end)

        it("handleStepError (STATUS_ERROR) when AutoDrive is unavailable", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            local d = activeData(v)

            local origFn = ADIntegration.startRefuelRoute
            ADIntegration.startRefuelRoute = function(_, _) return false, false end
            WMExecutor:startRefuelStep(d, v, { type = "refuel", target = "" })
            ADIntegration.startRefuelRoute = origFn

            assert.are.equal(WorkflowManager.STATUS_ERROR, d.status)
            assert.is_nil(activeData(v))
        end)

        it("skips (onStepCompleted, not handleStepError) when already fueled or no station reachable", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            local d = activeData(v)

            local origFn = ADIntegration.startRefuelRoute
            ADIntegration.startRefuelRoute = function(_, _) return false, true end
            WMExecutor:startRefuelStep(d, v, { type = "refuel", target = "" })
            ADIntegration.startRefuelRoute = origFn

            -- onStepCompleted advances currentStep rather than erroring
            assert.are_not.equal(WorkflowManager.STATUS_ERROR, d.status)
            assert.are.equal(2, d.currentStep)
        end)

        it("clearCPHandoff called when Refuel step starts", function()
            local called = false
            local origFn = ADIntegration.clearCPHandoff
            ADIntegration.clearCPHandoff = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRefuel, v)
            ADIntegration.clearCPHandoff = origFn
            assert.is_true(called)
        end)

        it("onADFinishedEvent completes a Refuel step (currentStepType == STEP_REFUEL)", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRefuel, v)
            local d = activeData(v)
            assert.is_true(d.waitingForCompletion)

            WMExecutor:onADFinishedEvent({ vehicle = v })
            assert.is_nil(activeData(v))
            assert.is_false(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)

        it("completion poll (isRouteComplete) advances a Refuel step", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRefuel, v)

            local origComplete = ADIntegration.isRouteComplete
            ADIntegration.isRouteComplete = function() return true end
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            ADIntegration.isRouteComplete = origComplete

            assert.is_nil(activeData(v))
            assert.is_false(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)

        it("pauseCurrentStep calls ADIntegration:pauseRoute for a Refuel step", function()
            local called = false
            local origFn = ADIntegration.pauseRoute
            ADIntegration.pauseRoute = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRefuel, v)
            local d = activeData(v)
            WMExecutor:pauseCurrentStep(d)
            ADIntegration.pauseRoute = origFn
            assert.is_true(called)
        end)

        it("resumeCurrentStep calls ADIntegration:resumeRoute for a Refuel step", function()
            local called = false
            local origFn = ADIntegration.resumeRoute
            ADIntegration.resumeRoute = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRefuel, v)
            local d = activeData(v)
            WMExecutor:resumeCurrentStep(d)
            ADIntegration.resumeRoute = origFn
            assert.is_true(called)
        end)

        it("stopCurrentStep calls ADIntegration:stopRoute for a Refuel step", function()
            local called = false
            local origFn = ADIntegration.stopRoute
            ADIntegration.stopRoute = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRefuel, v)
            local d = activeData(v)
            WMExecutor:stopCurrentStep(d)
            ADIntegration.stopRoute = origFn
            assert.is_true(called)
        end)

        it("starts Refuel directly via executeCurrentStep after AD completes", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfAdThenRefuel, v)
            local d = activeData(v)
            assert.are.equal(WorkflowManager.STEP_AUTODRIVE, d.currentStepType)

            WMExecutor:onStepCompleted(d)
            assert.are.equal(2, d.currentStep)
            assert.is_not_nil(d.pendingAutoStep)

            g_currentMission.time = d.pendingAutoStep + 1
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)

            assert.are.equal(WorkflowManager.STEP_REFUEL, d.currentStepType)
            assert.is_true(d.waitingForCompletion)
        end)

        it("resolvePendingADStart routes to startRefuelStep (not startAutoDriveStep) when deferred", function()
            local adStillRunning = true
            local origIsRunning = ADIntegration.isRunning
            local origStartRoute = ADIntegration.startRoute
            local refuelStarted = false
            local adStarted = false
            ADIntegration.isRunning = function() return adStillRunning end
            ADIntegration.startRoute = function() adStarted = true; return true end
            local origStartRefuel = ADIntegration.startRefuelRoute
            ADIntegration.startRefuelRoute = function() refuelStarted = true; return true, false end

            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRefuel, v)
            local d = activeData(v)
            assert.is_true(d.pendingADStart)
            assert.is_false(refuelStarted)

            adStillRunning = false
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)

            ADIntegration.isRunning = origIsRunning
            ADIntegration.startRoute = origStartRoute
            ADIntegration.startRefuelRoute = origStartRefuel

            assert.is_true(refuelStarted)
            assert.is_false(adStarted)
        end)
    end)

    -- =========================================================================
    -- Repair step: drive to AD's nearest reachable workshop (reuses AD machinery)
    -- =========================================================================
    describe("Repair step", function()
        local wfRepair = {
            id = "wf_repair", name = "Repair Workflow",
            steps = {
                { type = "repair", target = "", support = {} },
            },
        }
        local wfAdThenRepair = {
            id = "wf_ad_repair", name = "AD then Repair",
            steps = {
                { type = "autodrive", target = "Farm", action = "drive", support = {} },
                { type = "repair",    target = "",     support = {} },
            },
        }

        it("startRepairRoute called and currentStepType set to STEP_REPAIR on start", function()
            local called = false
            local origFn = ADIntegration.startRepairRoute
            ADIntegration.startRepairRoute = function(_, _) called = true; return true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRepair, v)
            ADIntegration.startRepairRoute = origFn
            local d = activeData(v)
            assert.is_true(called)
            assert.are.equal(WorkflowManager.STEP_REPAIR, d.currentStepType)
            assert.is_true(d.waitingForCompletion)
        end)

        it("handleStepError (STATUS_ERROR) when no repair station is reachable", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(makeWorkflow(), v)
            local d = activeData(v)

            local origFn = ADIntegration.startRepairRoute
            ADIntegration.startRepairRoute = function(_, _) return false end
            WMExecutor:startRepairStep(d, v, { type = "repair", target = "" })
            ADIntegration.startRepairRoute = origFn

            assert.are.equal(WorkflowManager.STATUS_ERROR, d.status)
            assert.is_nil(activeData(v))
        end)

        it("clearCPHandoff called when Repair step starts", function()
            local called = false
            local origFn = ADIntegration.clearCPHandoff
            ADIntegration.clearCPHandoff = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRepair, v)
            ADIntegration.clearCPHandoff = origFn
            assert.is_true(called)
        end)

        it("onADFinishedEvent completes a Repair step (currentStepType == STEP_REPAIR)", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRepair, v)
            local d = activeData(v)
            assert.is_true(d.waitingForCompletion)

            WMExecutor:onADFinishedEvent({ vehicle = v })
            assert.is_nil(activeData(v))
            assert.is_false(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)

        it("completion poll (isRouteComplete) advances a Repair step", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRepair, v)

            local origComplete = ADIntegration.isRouteComplete
            ADIntegration.isRouteComplete = function() return true end
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            ADIntegration.isRouteComplete = origComplete

            assert.is_nil(activeData(v))
            assert.is_false(WMExecutor:isWorkflowActiveOnVehicle(v))
        end)

        it("pauseCurrentStep calls ADIntegration:pauseRoute for a Repair step", function()
            local called = false
            local origFn = ADIntegration.pauseRoute
            ADIntegration.pauseRoute = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRepair, v)
            local d = activeData(v)
            WMExecutor:pauseCurrentStep(d)
            ADIntegration.pauseRoute = origFn
            assert.is_true(called)
        end)

        it("resumeCurrentStep calls ADIntegration:resumeRoute for a Repair step", function()
            local called = false
            local origFn = ADIntegration.resumeRoute
            ADIntegration.resumeRoute = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRepair, v)
            local d = activeData(v)
            WMExecutor:resumeCurrentStep(d)
            ADIntegration.resumeRoute = origFn
            assert.is_true(called)
        end)

        it("stopCurrentStep calls ADIntegration:stopRoute for a Repair step", function()
            local called = false
            local origFn = ADIntegration.stopRoute
            ADIntegration.stopRoute = function() called = true end
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRepair, v)
            local d = activeData(v)
            WMExecutor:stopCurrentStep(d)
            ADIntegration.stopRoute = origFn
            assert.is_true(called)
        end)

        it("starts Repair directly via executeCurrentStep after AD completes", function()
            local v = makeVehicle()
            WMExecutor:startWorkflow(wfAdThenRepair, v)
            local d = activeData(v)
            assert.are.equal(WorkflowManager.STEP_AUTODRIVE, d.currentStepType)

            WMExecutor:onStepCompleted(d)
            assert.are.equal(2, d.currentStep)
            assert.is_not_nil(d.pendingAutoStep)

            g_currentMission.time = d.pendingAutoStep + 1
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)

            assert.are.equal(WorkflowManager.STEP_REPAIR, d.currentStepType)
            assert.is_true(d.waitingForCompletion)
        end)

        it("resolvePendingADStart routes to startRepairStep (not startAutoDriveStep) when deferred", function()
            local adStillRunning = true
            local origIsRunning = ADIntegration.isRunning
            local origStartRoute = ADIntegration.startRoute
            local repairStarted = false
            local adStarted = false
            ADIntegration.isRunning = function() return adStillRunning end
            ADIntegration.startRoute = function() adStarted = true; return true end
            local origStartRepair = ADIntegration.startRepairRoute
            ADIntegration.startRepairRoute = function() repairStarted = true; return true end

            local v = makeVehicle()
            WMExecutor:startWorkflow(wfRepair, v)
            local d = activeData(v)
            assert.is_true(d.pendingADStart)
            assert.is_false(repairStarted)

            adStillRunning = false
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)

            ADIntegration.isRunning = origIsRunning
            ADIntegration.startRoute = origStartRoute
            ADIntegration.startRepairRoute = origStartRepair

            assert.is_true(repairStarted)
            assert.is_false(adStarted)
        end)
    end)

end)
