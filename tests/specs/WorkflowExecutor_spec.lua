--[[
    WorkflowExecutor Unit Tests
    Tests for workflow execution state machine and step transitions
]]

describe("WMExecutor", function()
    -- Use globals for test fixtures to work with simple test runner
    _G._testWorkflow = nil
    _G._testVehicle = nil

    -- Setup: Load dependencies and create WMExecutor
    setup(function()
        -- Load EventHandler first
        dofile("src/utils/EventHandler.lua")

        -- Initialize WorkflowManager constants (needed by Executor)
        _G.WorkflowManager = {
            STATUS_READY = "ready",
            STATUS_RUNNING = "running",
            STATUS_PAUSED = "paused",
            STATUS_COMPLETED = "completed",
            STATUS_ERROR = "error",
            STEP_AUTODRIVE = "autodrive",
            STEP_COURSEPLAY = "courseplay"
        }

        -- Create WMExecutor with minimal implementation for testing
        _G.WMExecutor = {
            activeWorkflows = {},
            isInitialized = false,
            UPDATE_INTERVAL = 500,
            updateTimer = 0,
            pendingADCallbacks = {}
        }

        WMExecutor = _G.WMExecutor

        -- init
        WMExecutor.init = function(self)
            self.activeWorkflows = {}
            self.pendingADCallbacks = {}
            self.updateTimer = 0
            self.isInitialized = true
            WMEventHandler:init()
        end

        -- startWorkflow
        WMExecutor.startWorkflow = function(self, workflow, vehicle)
            if workflow == nil then
                WMLogger:error("Cannot start nil workflow")
                return false
            end

            if vehicle == nil then
                WMLogger:error("Cannot start workflow without a vehicle")
                return false
            end

            if self.activeWorkflows[workflow.id] ~= nil then
                WMLogger:warning("Workflow %s is already active", workflow.id)
                return false
            end

            if #workflow.steps == 0 then
                WMLogger:error("Workflow %s has no steps", workflow.id)
                return false
            end

            workflow.currentStep = 1
            workflow.status = WorkflowManager.STATUS_RUNNING

            self.activeWorkflows[workflow.id] = {
                workflow = workflow,
                vehicle = vehicle,
                startTime = g_currentMission.time,
                waitingForCompletion = false
            }

            WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_STARTED, {
                workflowId = workflow.id,
                workflowName = workflow.name,
                vehicleName = vehicle:getName()
            })

            -- Simulate starting first step
            self:executeCurrentStep(workflow)

            return true
        end

        -- stopWorkflow
        WMExecutor.stopWorkflow = function(self, workflow)
            if workflow == nil then
                return false
            end

            local activeData = self.activeWorkflows[workflow.id]
            if activeData == nil then
                WMLogger:warning("Workflow %s is not active", workflow.id)
                return false
            end

            workflow.status = WorkflowManager.STATUS_READY
            self.activeWorkflows[workflow.id] = nil

            WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_STOPPED, {
                workflowId = workflow.id
            })

            return true
        end

        -- pauseWorkflow
        WMExecutor.pauseWorkflow = function(self, workflow)
            if workflow == nil then
                return false
            end

            local activeData = self.activeWorkflows[workflow.id]
            if activeData == nil then
                WMLogger:warning("Workflow %s is not active", workflow.id)
                return false
            end

            if workflow.status ~= WorkflowManager.STATUS_RUNNING then
                WMLogger:warning("Workflow %s is not running", workflow.id)
                return false
            end

            workflow.status = WorkflowManager.STATUS_PAUSED

            activeData.pausedTrackingState = {
                waitingForCompletion = activeData.waitingForCompletion
            }
            activeData.waitingForCompletion = false

            WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_PAUSED, {
                workflowId = workflow.id,
                currentStep = workflow.currentStep
            })

            return true
        end

        -- resumeWorkflow
        WMExecutor.resumeWorkflow = function(self, workflow)
            if workflow == nil then
                return false
            end

            local activeData = self.activeWorkflows[workflow.id]
            if activeData == nil then
                WMLogger:warning("Workflow %s is not active", workflow.id)
                return false
            end

            if workflow.status ~= WorkflowManager.STATUS_PAUSED then
                WMLogger:warning("Workflow %s is not paused", workflow.id)
                return false
            end

            if activeData.pausedTrackingState then
                activeData.waitingForCompletion = activeData.pausedTrackingState.waitingForCompletion
                activeData.pausedTrackingState = nil
            else
                activeData.waitingForCompletion = true
            end

            workflow.status = WorkflowManager.STATUS_RUNNING

            WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_RESUMED, {
                workflowId = workflow.id,
                currentStep = workflow.currentStep
            })

            return true
        end

        -- executeCurrentStep (simplified for testing)
        WMExecutor.executeCurrentStep = function(self, workflow)
            local step = workflow.steps[workflow.currentStep]
            if step == nil then
                return
            end

            local activeData = self.activeWorkflows[workflow.id]
            activeData.waitingForCompletion = true
            activeData.currentStepType = step.type

            WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_STARTED, {
                workflowId = workflow.id,
                stepNumber = workflow.currentStep,
                stepType = step.type,
                target = step.target
            })
        end

        -- onStepCompleted
        WMExecutor.onStepCompleted = function(self, workflow)
            local activeData = self.activeWorkflows[workflow.id]

            WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_COMPLETED, {
                workflowId = workflow.id,
                stepNumber = workflow.currentStep
            })

            workflow.currentStep = workflow.currentStep + 1

            if workflow.currentStep > #workflow.steps then
                self:onWorkflowCompleted(workflow)
            else
                self:executeCurrentStep(workflow)
            end
        end

        -- onWorkflowCompleted
        WMExecutor.onWorkflowCompleted = function(self, workflow)
            workflow.status = WorkflowManager.STATUS_COMPLETED
            workflow.currentStep = 1

            self.activeWorkflows[workflow.id] = nil

            WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_COMPLETED, {
                workflowId = workflow.id,
                workflowName = workflow.name
            })
        end

        -- getActiveWorkflowCount
        WMExecutor.getActiveWorkflowCount = function(self)
            local count = 0
            for _ in pairs(self.activeWorkflows) do
                count = count + 1
            end
            return count
        end

        -- isWorkflowActive
        WMExecutor.isWorkflowActive = function(self, workflowId)
            return self.activeWorkflows[workflowId] ~= nil
        end

        -- goToPreviousStep
        WMExecutor.goToPreviousStep = function(self, workflow)
            if workflow == nil then
                return false
            end

            local activeData = self.activeWorkflows[workflow.id]
            if activeData == nil then
                WMLogger:warning("Workflow %s is not active", workflow.id)
                return false
            end

            if workflow.currentStep <= 1 then
                WMLogger:warning("Already at first step of workflow %s", workflow.id)
                return false
            end

            local wasPaused = workflow.status == WorkflowManager.STATUS_PAUSED
            workflow.currentStep = workflow.currentStep - 1

            activeData.waitingForCompletion = false

            if wasPaused then
                workflow.status = WorkflowManager.STATUS_RUNNING
            end

            if workflow.status == WorkflowManager.STATUS_RUNNING then
                self:executeCurrentStep(workflow)
            end

            WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_CHANGED, {
                workflowId = workflow.id,
                stepNumber = workflow.currentStep,
                direction = "previous"
            })

            return true
        end

        -- goToNextStep
        WMExecutor.goToNextStep = function(self, workflow)
            if workflow == nil then
                return false
            end

            local activeData = self.activeWorkflows[workflow.id]
            if activeData == nil then
                WMLogger:warning("Workflow %s is not active", workflow.id)
                return false
            end

            if workflow.currentStep >= #workflow.steps then
                WMLogger:warning("Already at last step of workflow %s", workflow.id)
                return false
            end

            local wasPaused = workflow.status == WorkflowManager.STATUS_PAUSED
            workflow.currentStep = workflow.currentStep + 1

            activeData.waitingForCompletion = false

            if wasPaused then
                workflow.status = WorkflowManager.STATUS_RUNNING
            end

            if workflow.status == WorkflowManager.STATUS_RUNNING then
                self:executeCurrentStep(workflow)
            end

            WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_CHANGED, {
                workflowId = workflow.id,
                stepNumber = workflow.currentStep,
                direction = "next"
            })

            return true
        end
    end)

    -- Reset state before each test
    before_each(function()
        WMExecutor:init()

        -- Create a test workflow
        _G._testWorkflow = {
            id = "test_workflow_001",
            name = "Test Workflow",
            steps = {
                { type = "autodrive", target = "Farm", action = "drive" },
                { type = "courseplay", target = "Field1", action = "fieldwork" },
                { type = "autodrive", target = "Silo", action = "unload" }
            },
            currentStep = 1,
            status = "ready"
        }

        -- Create a test vehicle
        _G._testVehicle = VehicleMock.createValid("TestTractor")

        -- Reset logger calls
        _G.WMLogger.calls = {
            debug = {},
            info = {},
            warning = {},
            error = {}
        }
    end)

    describe("init", function()
        it("should initialize with empty activeWorkflows", function()
            WMExecutor:init()

            assert.is_table(WMExecutor.activeWorkflows)
            assert.are.equal(0, WMExecutor:getActiveWorkflowCount())
        end)

        it("should set isInitialized to true", function()
            WMExecutor.isInitialized = false
            WMExecutor:init()

            assert.is_true(WMExecutor.isInitialized)
        end)
    end)

    describe("startWorkflow", function()
        it("should start workflow and set status to running", function()
            local result = WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)

            assert.is_true(result)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, _G._testWorkflow.status)
        end)

        it("should add workflow to activeWorkflows", function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)

            assert.is_true(WMExecutor:isWorkflowActive(_G._testWorkflow.id))
            assert.are.equal(1, WMExecutor:getActiveWorkflowCount())
        end)

        it("should store vehicle in activeData", function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)

            local activeData = WMExecutor.activeWorkflows[_G._testWorkflow.id]
            assert.are.equal(_G._testVehicle, activeData.vehicle)
        end)

        it("should reset currentStep to 1", function()
            _G._testWorkflow.currentStep = 3
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)

            assert.are.equal(1, _G._testWorkflow.currentStep)
        end)

        it("should fire WORKFLOW_STARTED event", function()
            local eventFired = false
            local eventData = nil

            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_STARTED, function(eventType, data)
                eventFired = true
                eventData = data
            end)

            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)

            assert.is_true(eventFired)
            assert.are.equal(_G._testWorkflow.id, eventData.workflowId)
        end)

        it("should return false for nil workflow", function()
            local result = WMExecutor:startWorkflow(nil, _G._testVehicle)

            assert.is_false(result)
        end)

        it("should return false for nil vehicle", function()
            local result = WMExecutor:startWorkflow(_G._testWorkflow, nil)

            assert.is_false(result)
        end)

        it("should return false for workflow with no steps", function()
            _G._testWorkflow.steps = {}
            local result = WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)

            assert.is_false(result)
        end)

        it("should return false if workflow already active", function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)
            local result = WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)

            assert.is_false(result)
        end)
    end)

    describe("stopWorkflow", function()
        before_each(function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)
        end)

        it("should stop running workflow", function()
            local result = WMExecutor:stopWorkflow(_G._testWorkflow)

            assert.is_true(result)
            assert.are.equal(WorkflowManager.STATUS_READY, _G._testWorkflow.status)
        end)

        it("should remove workflow from activeWorkflows", function()
            WMExecutor:stopWorkflow(_G._testWorkflow)

            assert.is_false(WMExecutor:isWorkflowActive(_G._testWorkflow.id))
            assert.are.equal(0, WMExecutor:getActiveWorkflowCount())
        end)

        it("should fire WORKFLOW_STOPPED event", function()
            local eventFired = false

            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_STOPPED, function()
                eventFired = true
            end)

            WMExecutor:stopWorkflow(_G._testWorkflow)

            assert.is_true(eventFired)
        end)

        it("should return false for non-active workflow", function()
            WMExecutor:stopWorkflow(_G._testWorkflow)  -- Stop first
            local result = WMExecutor:stopWorkflow(_G._testWorkflow)  -- Try again

            assert.is_false(result)
        end)

        it("should return false for nil workflow", function()
            local result = WMExecutor:stopWorkflow(nil)

            assert.is_false(result)
        end)
    end)

    describe("pauseWorkflow", function()
        before_each(function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)
        end)

        it("should pause running workflow", function()
            local result = WMExecutor:pauseWorkflow(_G._testWorkflow)

            assert.is_true(result)
            assert.are.equal(WorkflowManager.STATUS_PAUSED, _G._testWorkflow.status)
        end)

        it("should store tracking state for resume", function()
            local activeData = WMExecutor.activeWorkflows[_G._testWorkflow.id]
            activeData.waitingForCompletion = true

            WMExecutor:pauseWorkflow(_G._testWorkflow)

            assert.is_not_nil(activeData.pausedTrackingState)
            assert.is_true(activeData.pausedTrackingState.waitingForCompletion)
        end)

        it("should set waitingForCompletion to false", function()
            WMExecutor:pauseWorkflow(_G._testWorkflow)

            local activeData = WMExecutor.activeWorkflows[_G._testWorkflow.id]
            assert.is_false(activeData.waitingForCompletion)
        end)

        it("should fire WORKFLOW_PAUSED event", function()
            local eventFired = false

            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_PAUSED, function()
                eventFired = true
            end)

            WMExecutor:pauseWorkflow(_G._testWorkflow)

            assert.is_true(eventFired)
        end)

        it("should return false for non-running workflow", function()
            _G._testWorkflow.status = WorkflowManager.STATUS_READY
            local result = WMExecutor:pauseWorkflow(_G._testWorkflow)

            assert.is_false(result)
        end)

        it("should return false for non-active workflow", function()
            WMExecutor:stopWorkflow(_G._testWorkflow)
            local result = WMExecutor:pauseWorkflow(_G._testWorkflow)

            assert.is_false(result)
        end)
    end)

    describe("resumeWorkflow", function()
        before_each(function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)
            WMExecutor:pauseWorkflow(_G._testWorkflow)
        end)

        it("should resume paused workflow", function()
            local result = WMExecutor:resumeWorkflow(_G._testWorkflow)

            assert.is_true(result)
            assert.are.equal(WorkflowManager.STATUS_RUNNING, _G._testWorkflow.status)
        end)

        it("should restore tracking state", function()
            local activeData = WMExecutor.activeWorkflows[_G._testWorkflow.id]

            WMExecutor:resumeWorkflow(_G._testWorkflow)

            assert.is_nil(activeData.pausedTrackingState)
        end)

        it("should fire WORKFLOW_RESUMED event", function()
            local eventFired = false

            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_RESUMED, function()
                eventFired = true
            end)

            WMExecutor:resumeWorkflow(_G._testWorkflow)

            assert.is_true(eventFired)
        end)

        it("should return false for non-paused workflow", function()
            WMExecutor:resumeWorkflow(_G._testWorkflow)  -- Resume to running
            local result = WMExecutor:resumeWorkflow(_G._testWorkflow)  -- Try again

            assert.is_false(result)
        end)
    end)

    describe("goToPreviousStep", function()
        before_each(function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)
            _G._testWorkflow.currentStep = 2  -- Start at step 2
        end)

        it("should move to previous step", function()
            local result = WMExecutor:goToPreviousStep(_G._testWorkflow)

            assert.is_true(result)
            assert.are.equal(1, _G._testWorkflow.currentStep)
        end)

        it("should fire STEP_CHANGED event", function()
            local eventData = nil

            WMEventHandler:addEventListener(WMEventHandler.EVENT_STEP_CHANGED, function(eventType, data)
                eventData = data
            end)

            WMExecutor:goToPreviousStep(_G._testWorkflow)

            assert.is_not_nil(eventData)
            assert.are.equal("previous", eventData.direction)
        end)

        it("should return false at first step", function()
            _G._testWorkflow.currentStep = 1
            local result = WMExecutor:goToPreviousStep(_G._testWorkflow)

            assert.is_false(result)
        end)

        it("should return false for non-active workflow", function()
            WMExecutor:stopWorkflow(_G._testWorkflow)
            local result = WMExecutor:goToPreviousStep(_G._testWorkflow)

            assert.is_false(result)
        end)

        it("should resume from paused when navigating", function()
            WMExecutor:pauseWorkflow(_G._testWorkflow)
            WMExecutor:goToPreviousStep(_G._testWorkflow)

            assert.are.equal(WorkflowManager.STATUS_RUNNING, _G._testWorkflow.status)
        end)
    end)

    describe("goToNextStep", function()
        before_each(function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)
        end)

        it("should move to next step", function()
            local result = WMExecutor:goToNextStep(_G._testWorkflow)

            assert.is_true(result)
            assert.are.equal(2, _G._testWorkflow.currentStep)
        end)

        it("should fire STEP_CHANGED event", function()
            local eventData = nil

            WMEventHandler:addEventListener(WMEventHandler.EVENT_STEP_CHANGED, function(eventType, data)
                eventData = data
            end)

            WMExecutor:goToNextStep(_G._testWorkflow)

            assert.is_not_nil(eventData)
            assert.are.equal("next", eventData.direction)
        end)

        it("should return false at last step", function()
            _G._testWorkflow.currentStep = 3  -- Last step
            local result = WMExecutor:goToNextStep(_G._testWorkflow)

            assert.is_false(result)
        end)

        it("should return false for non-active workflow", function()
            WMExecutor:stopWorkflow(_G._testWorkflow)
            local result = WMExecutor:goToNextStep(_G._testWorkflow)

            assert.is_false(result)
        end)

        it("should resume from paused when navigating", function()
            WMExecutor:pauseWorkflow(_G._testWorkflow)
            WMExecutor:goToNextStep(_G._testWorkflow)

            assert.are.equal(WorkflowManager.STATUS_RUNNING, _G._testWorkflow.status)
        end)
    end)

    describe("onStepCompleted", function()
        before_each(function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)
        end)

        it("should fire STEP_COMPLETED event", function()
            local eventFired = false

            WMEventHandler:addEventListener(WMEventHandler.EVENT_STEP_COMPLETED, function()
                eventFired = true
            end)

            WMExecutor:onStepCompleted(_G._testWorkflow)

            assert.is_true(eventFired)
        end)

        it("should advance to next step", function()
            WMExecutor:onStepCompleted(_G._testWorkflow)

            assert.are.equal(2, _G._testWorkflow.currentStep)
        end)

        it("should complete workflow after last step", function()
            _G._testWorkflow.currentStep = 3  -- Last step

            WMExecutor:onStepCompleted(_G._testWorkflow)

            assert.are.equal(WorkflowManager.STATUS_COMPLETED, _G._testWorkflow.status)
            assert.is_false(WMExecutor:isWorkflowActive(_G._testWorkflow.id))
        end)
    end)

    describe("onWorkflowCompleted", function()
        before_each(function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)
        end)

        it("should set status to completed", function()
            WMExecutor:onWorkflowCompleted(_G._testWorkflow)

            assert.are.equal(WorkflowManager.STATUS_COMPLETED, _G._testWorkflow.status)
        end)

        it("should reset currentStep to 1", function()
            _G._testWorkflow.currentStep = 3
            WMExecutor:onWorkflowCompleted(_G._testWorkflow)

            assert.are.equal(1, _G._testWorkflow.currentStep)
        end)

        it("should remove from activeWorkflows", function()
            WMExecutor:onWorkflowCompleted(_G._testWorkflow)

            assert.is_false(WMExecutor:isWorkflowActive(_G._testWorkflow.id))
        end)

        it("should fire WORKFLOW_COMPLETED event", function()
            local eventData = nil

            WMEventHandler:addEventListener(WMEventHandler.EVENT_WORKFLOW_COMPLETED, function(eventType, data)
                eventData = data
            end)

            WMExecutor:onWorkflowCompleted(_G._testWorkflow)

            assert.is_not_nil(eventData)
            assert.are.equal(_G._testWorkflow.id, eventData.workflowId)
        end)
    end)

    describe("getActiveWorkflowCount", function()
        it("should return 0 when no workflows active", function()
            assert.are.equal(0, WMExecutor:getActiveWorkflowCount())
        end)

        it("should return correct count", function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)

            local workflow2 = {
                id = "test_workflow_002",
                name = "Test 2",
                steps = {{ type = "autodrive", target = "X", action = "drive" }},
                currentStep = 1,
                status = "ready"
            }
            local vehicle2 = VehicleMock.createValid("Tractor2")
            WMExecutor:startWorkflow(workflow2, vehicle2)

            assert.are.equal(2, WMExecutor:getActiveWorkflowCount())
        end)
    end)

    describe("isWorkflowActive", function()
        it("should return false for non-active workflow", function()
            assert.is_false(WMExecutor:isWorkflowActive("nonexistent"))
        end)

        it("should return true for active workflow", function()
            WMExecutor:startWorkflow(_G._testWorkflow, _G._testVehicle)

            assert.is_true(WMExecutor:isWorkflowActive(_G._testWorkflow.id))
        end)
    end)
end)
