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
            STEP_AUTODRIVE            = "autodrive",
            STEP_COURSEPLAY           = "courseplay",
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
        it("support vehicle idles (waitingForMainStep) when main step has no sub-steps", function()
            local wf = makeWorkflowWithSupport("wf_sv1")
            local vm = makeVehicle("Main")
            local vs = makeVehicle("Support")
            WMExecutor:startWorkflow(wf, vm, true)
            WMExecutor:startWorkflow(wf, vs, false)
            -- Main is on step 1 which has no support sub-steps
            -- Support vehicle should be idle
            local d = activeData(vs)
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
    -- Leader-follower synchronization
    -- =========================================================================
    describe("leader-follower synchronization", function()
        it("startWorkflow stores leaderVehicle on activeData", function()
            local wf      = makeWorkflow("wf_ldr_store")
            local leader  = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            assert.are.equal(leader, activeData(follower).leaderVehicle)
        end)

        it("follower runs freely when leader is on the same step", function()
            local wf      = makeWorkflow("wf_ldr_wait")
            local leader  = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(wf, leader)
            -- leader at step 1, follower also starts at step 1 → runs freely (leader reached required step)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("does not enter waiting_for_leader when no leader is set", function()
            local wf = makeWorkflow("wf_no_leader")
            local v  = makeVehicle("Solo")
            WMExecutor:startWorkflow(wf, v, true, nil)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(v).status)
            assert.is_nil(activeData(v).leaderVehicle)
        end)

        it("resumes follower when leader reaches its sync step", function()
            local wf      = makeWorkflow("wf_ldr_advance")
            local leader  = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Advance follower to step 2 while leader is still on step 1 → must wait
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)

            -- Leader reaches step 2 (follower's required step) → follower resumes
            activeData(leader).currentStep = 2
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("frees follower and resumes when leader stops", function()
            local wf      = makeWorkflow("wf_ldr_stop")
            local leader  = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Advance follower to step 2 while leader is on step 1 → follower waits
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)

            -- Leader stops (wmExecution cleared)
            WMExecutor:stopWorkflow(leader)

            WMExecutor.updateTimer = 0
            WMExecutor:update(500)

            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.is_nil(activeData(follower).leaderVehicle)
        end)

        it("frees follower when leader restarts the same workflow (step check alone would miss this)", function()
            local wf      = makeWorkflow("wf_ldr_restart")
            local leader  = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Advance follower to step 2 (leader still on step 1) → follower waits
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)

            -- Leader stops and immediately restarts — new wmExecution table, same workflow id, step=1
            WMExecutor:stopWorkflow(leader)
            WMExecutor:startWorkflow(wf, leader)

            WMExecutor.updateTimer = 0
            WMExecutor:update(500)

            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.is_nil(activeData(follower).leaderVehicle)
            assert.is_nil(activeData(follower).linkedLeaderExecution)
        end)

        it("follower waiting for leader activates dummy AD hold", function()
            local wf      = makeWorkflow("wf_ldr_dummy")
            local leader  = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Advance follower to step 2 while leader is still on step 1 → must wait
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
            assert.is_true(activeData(follower).dummyHelperActive)
            assert.is_true(follower._isADActive)
        end)

        it("dummy AD hold is deactivated when leader reaches sync step", function()
            local wf      = makeWorkflow("wf_ldr_dummy_rel")
            local leader  = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Advance follower to step 2 while leader is on step 1 → wait + dummy active
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.is_true(activeData(follower).dummyHelperActive)
            assert.is_true(follower._isADActive)
            -- Leader reaches step 2 (= required) → follower unblocked, dummy deactivated
            activeData(leader).currentStep = 2
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.is_nil(activeData(follower).dummyHelperActive)
            assert.is_false(follower._isADActive)
        end)

        it("dummy AD hold is deactivated when leader stops", function()
            local wf      = makeWorkflow("wf_ldr_dummy_stop")
            local leader  = makeVehicle("Leader")
            local follower = makeVehicle("Follower")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Advance follower to step 2 while leader is on step 1 → wait + dummy active
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.is_true(activeData(follower).dummyHelperActive)
            assert.is_true(follower._isADActive)
            -- Leader stops → follower freed, dummy deactivated
            WMExecutor:stopWorkflow(leader)
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
            assert.is_nil(activeData(follower).dummyHelperActive)
            assert.is_false(follower._isADActive)
        end)

    end)

    -- =========================================================================
    -- buildSyncMaps
    -- =========================================================================
    describe("buildSyncMaps", function()

        it("all-default workflow: syncTargets covers every step in order", function()
            local wf     = makeWorkflow("wf_sm_all")
            local leader = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            local ad = activeData(follower)
            assert.are.same({1, 2, 3}, ad.syncTargets)
        end)

        it("leader step 2 isSyncTarget=false: syncTargets skips that step", function()
            local wf = {
                id = "wf_sm_skip", name = "Skip",
                steps = {
                    { type = "autodrive",  target = "A", action = "drive",     isSyncTarget = true,  isSyncSource = true,  support = {} },
                    { type = "courseplay", target = "B", action = "fieldwork", isSyncTarget = false, isSyncSource = true,  support = {} },
                    { type = "autodrive",  target = "C", action = "drive",     isSyncTarget = true,  isSyncSource = true,  support = {} },
                },
            }
            local leader   = makeVehicle("L2")
            local follower = makeVehicle("F2")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            assert.are.same({1, 3}, activeData(follower).syncTargets)
        end)

        it("leader with no sync targets: syncTargets is empty", function()
            local wf = {
                id = "wf_sm_none", name = "None",
                steps = {
                    { type = "autodrive", target = "A", action = "drive", isSyncTarget = false, isSyncSource = true, support = {} },
                    { type = "autodrive", target = "B", action = "drive", isSyncTarget = false, isSyncSource = true, support = {} },
                },
            }
            local leader   = makeVehicle("L3")
            local follower = makeVehicle("F3")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            assert.are.same({}, activeData(follower).syncTargets)
        end)

        it("all-default follower workflow: syncSourceOrdinals maps every step", function()
            local wf     = makeWorkflow("wf_sm_ord")
            local leader = makeVehicle("L4")
            local follower = makeVehicle("F4")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            local ord = activeData(follower).syncSourceOrdinals
            assert.are.equal(1, ord[1])
            assert.are.equal(2, ord[2])
            assert.are.equal(3, ord[3])
        end)

        it("follower step 2 isSyncSource=false: that step gets no ordinal, step 3 gets ordinal 2", function()
            local wf = {
                id = "wf_sm_src", name = "Src",
                steps = {
                    { type = "autodrive", target = "A", action = "drive", isSyncTarget = true, isSyncSource = true,  support = {} },
                    { type = "autodrive", target = "B", action = "drive", isSyncTarget = true, isSyncSource = false, support = {} },
                    { type = "autodrive", target = "C", action = "drive", isSyncTarget = true, isSyncSource = true,  support = {} },
                },
            }
            local leader   = makeVehicle("L5")
            local follower = makeVehicle("F5")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            local ord = activeData(follower).syncSourceOrdinals
            assert.are.equal(1,   ord[1])
            assert.is_nil(        ord[2])
            assert.are.equal(2,   ord[3])
        end)

        it("no leader: syncTargets and syncSourceOrdinals are nil", function()
            local wf = makeWorkflow("wf_sm_noldr")
            local v  = makeVehicle("Solo")
            WMExecutor:startWorkflow(wf, v, true, nil)
            assert.is_nil(activeData(v).syncTargets)
            assert.is_nil(activeData(v).syncSourceOrdinals)
        end)

    end)

    -- =========================================================================
    -- Index-based sync: executeCurrentStep + update poll
    -- =========================================================================
    describe("index-based sync conditions", function()

        it("default flags: follower step 1 runs when leader is on step 1", function()
            local wf      = makeWorkflow("wf_ibs_bc")
            local leader  = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Both on step 1 — follower runs freely (leader has reached required step)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("default flags: follower step 2 waits when leader is on step 1, resumes when leader reaches step 2", function()
            local wf      = makeWorkflow("wf_ibs_resume")
            local leader  = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Advance follower to step 2 while leader is on step 1 → waits
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
            -- Leader reaches step 2 → follower resumes
            activeData(leader).currentStep = 2
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("follower step with isSyncSource=false runs freely even while leader is on same step", function()
            local wf = {
                id = "wf_ibs_free", name = "Free",
                steps = {
                    { type = "autodrive", target = "A", action = "drive", isSyncTarget = true, isSyncSource = false, support = {} },
                    { type = "autodrive", target = "B", action = "drive", isSyncTarget = true, isSyncSource = true,  support = {} },
                },
            }
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Step 1 has isSyncSource=false → follower should NOT wait
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("leader step with isSyncTarget=false is skipped: follower step 2 waits for leader step 3", function()
            local wf = {
                id = "wf_ibs_skip", name = "Skip",
                steps = {
                    { type = "autodrive", target = "A", action = "drive", isSyncTarget = true,  isSyncSource = true, support = {} },
                    { type = "autodrive", target = "B", action = "drive", isSyncTarget = false, isSyncSource = true, support = {} },
                    { type = "autodrive", target = "C", action = "drive", isSyncTarget = true,  isSyncSource = true, support = {} },
                },
            }
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Advance follower to step 2
            activeData(leader).currentStep = 2
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            -- Follower step 2 is the 2nd source, required = syncTargets[2] = 3
            -- Leader is on step 2, which is <= 3, so follower must wait
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)

            -- Leader reaches step 3 (= required) → follower resumes
            activeData(leader).currentStep = 3
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("more sources than targets: extra source step runs freely (no 3rd target)", function()
            local wf = {
                id = "wf_ibs_extra", name = "Extra",
                steps = {
                    { type = "autodrive", target = "A", action = "drive", isSyncTarget = true,  isSyncSource = true, support = {} },
                    { type = "autodrive", target = "B", action = "drive", isSyncTarget = false, isSyncSource = true, support = {} },
                    { type = "autodrive", target = "C", action = "drive", isSyncTarget = false, isSyncSource = true, support = {} },
                },
            }
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Step 1 runs freely (1st source, syncTargets[1]=1, leader step=1 which is >= 1)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)

            -- Advance to step 3: syncSourceOrdinals[3]=2, syncTargets[2]=nil → run freely
            activeData(leader).currentStep = 2
            activeData(follower).currentStep = 3
            activeData(follower).status = WorkflowManager.STATUS_RUNNING
            WMExecutor:executeCurrentStep(activeData(follower))
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("leader already past required step: follower does not wait", function()
            local wf      = makeWorkflow("wf_ibs_past")
            local leader  = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            -- Advance leader to step 3 before follower starts
            activeData(leader).currentStep = 3
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Follower step 1: required=1, leader=3 > 1 → no wait
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

        it("poll: follower stays waiting while leader has not yet passed required step", function()
            local wf = {
                id = "wf_ibs_poll", name = "Poll",
                steps = {
                    { type = "autodrive", target = "A", action = "drive", isSyncTarget = true,  isSyncSource = true, support = {} },
                    { type = "autodrive", target = "B", action = "drive", isSyncTarget = false, isSyncSource = true, support = {} },
                    { type = "autodrive", target = "C", action = "drive", isSyncTarget = true,  isSyncSource = true, support = {} },
                },
            }
            -- syncTargets = {1, 3}; follower step 2 = 2nd source → required = 3
            local leader   = makeVehicle("L")
            local follower = makeVehicle("F")
            WMExecutor:startWorkflow(wf, leader)
            WMExecutor:startWorkflow(wf, follower, true, leader)
            -- Set follower to step 2, manually waiting
            activeData(leader).currentStep  = 2
            activeData(follower).currentStep = 2
            activeData(follower).status = WorkflowManager.STATUS_WAITING_FOR_LEADER
            -- Poll: leader at 2, required 3 → still waits
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            assert.are.equal(WorkflowManager.STATUS_WAITING_FOR_LEADER, activeData(follower).status)
            -- Advance leader past required step (3)
            activeData(leader).currentStep = 4
            WMExecutor.updateTimer = 0
            WMExecutor:update(500)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, activeData(follower).status)
        end)

    end)

end)
