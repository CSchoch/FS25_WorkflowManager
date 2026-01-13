--[[
    WorkflowManager - Workflow Executor
    Executes workflow steps and manages the state machine

    Author: WorkflowManager Team
]]

---@class WMExecutor
WMExecutor = {}

-- Executor state
WMExecutor.activeWorkflows = {}
WMExecutor.isInitialized = false

-- Update interval for checking step completion (ms)
WMExecutor.UPDATE_INTERVAL = 1000
WMExecutor.updateTimer = 0

---Initialize the executor
function WMExecutor:init()
    self.activeWorkflows = {}
    self.updateTimer = 0
    self.isInitialized = true
    WMLogger:debug("WorkflowExecutor initialized")
end

---Start executing a workflow
---@param workflow table Workflow to execute
---@return boolean success True if started successfully
function WMExecutor:startWorkflow(workflow)
    if workflow == nil then
        WMLogger:error("Cannot start nil workflow")
        return false
    end

    -- Check if already running
    if self.activeWorkflows[workflow.id] ~= nil then
        WMLogger:warning("Workflow %s is already active", workflow.id)
        return false
    end

    -- Validate workflow has steps
    if #workflow.steps == 0 then
        WMLogger:error("Workflow %s has no steps", workflow.id)
        return false
    end

    -- Start from beginning or current step
    workflow.currentStep = workflow.currentStep or 1
    workflow.status = WorkflowManager.STATUS_RUNNING

    -- Add to active workflows
    self.activeWorkflows[workflow.id] = {
        workflow = workflow,
        startTime = g_currentMission.time,
        waitingForCompletion = false
    }

    WMLogger:info("Starting workflow: %s (Step %d/%d)", workflow.name, workflow.currentStep, #workflow.steps)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_STARTED, {
        workflowId = workflow.id,
        workflowName = workflow.name
    })

    -- Execute first step
    self:executeCurrentStep(workflow)

    return true
end

---Stop a running workflow
---@param workflow table Workflow to stop
---@return boolean success True if stopped successfully
function WMExecutor:stopWorkflow(workflow)
    if workflow == nil then
        return false
    end

    local activeData = self.activeWorkflows[workflow.id]
    if activeData == nil then
        WMLogger:warning("Workflow %s is not active", workflow.id)
        return false
    end

    -- Stop current step
    self:stopCurrentStep(workflow)

    -- Update status
    workflow.status = WorkflowManager.STATUS_READY

    -- Remove from active
    self.activeWorkflows[workflow.id] = nil

    WMLogger:info("Stopped workflow: %s", workflow.name)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_STOPPED, {
        workflowId = workflow.id
    })

    return true
end

---Pause a running workflow
---@param workflow table Workflow to pause
---@return boolean success True if paused successfully
function WMExecutor:pauseWorkflow(workflow)
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

    -- Pause current step
    self:pauseCurrentStep(workflow)

    workflow.status = WorkflowManager.STATUS_PAUSED

    WMLogger:info("Paused workflow: %s at step %d", workflow.name, workflow.currentStep)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_PAUSED, {
        workflowId = workflow.id,
        currentStep = workflow.currentStep
    })

    return true
end

---Resume a paused workflow
---@param workflow table Workflow to resume
---@return boolean success True if resumed successfully
function WMExecutor:resumeWorkflow(workflow)
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

    workflow.status = WorkflowManager.STATUS_RUNNING

    -- Resume current step
    self:resumeCurrentStep(workflow)

    WMLogger:info("Resumed workflow: %s at step %d", workflow.name, workflow.currentStep)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_RESUMED, {
        workflowId = workflow.id,
        currentStep = workflow.currentStep
    })

    return true
end

---Execute the current step of a workflow
---@param workflow table Workflow
function WMExecutor:executeCurrentStep(workflow)
    local step = workflow.steps[workflow.currentStep]
    if step == nil then
        WMLogger:error("Step %d not found in workflow %s", workflow.currentStep, workflow.id)
        return
    end

    WMLogger:info("Executing step %d/%d: %s -> %s",
        workflow.currentStep, #workflow.steps, step.type, step.target)

    -- Fire step started event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_STARTED, {
        workflowId = workflow.id,
        stepNumber = workflow.currentStep,
        stepType = step.type,
        target = step.target
    })

    local activeData = self.activeWorkflows[workflow.id]

    -- Execute based on step type
    if step.type == WorkflowManager.STEP_AUTODRIVE then
        local success = ADIntegration:startRoute(workflow.vehicle, step.target, step.action)
        if success then
            activeData.waitingForCompletion = true
            activeData.currentStepType = WorkflowManager.STEP_AUTODRIVE
        else
            self:handleStepError(workflow, "Failed to start AutoDrive route: " .. step.target)
        end
    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        local success = CPIntegration:startCourse(workflow.vehicle, step.target, step.action)
        if success then
            activeData.waitingForCompletion = true
            activeData.currentStepType = WorkflowManager.STEP_COURSEPLAY
        else
            self:handleStepError(workflow, "Failed to start Courseplay course: " .. step.target)
        end
    else
        self:handleStepError(workflow, "Unknown step type: " .. tostring(step.type))
    end
end

---Stop the current step
---@param workflow table Workflow
function WMExecutor:stopCurrentStep(workflow)
    local step = workflow.steps[workflow.currentStep]
    if step == nil then
        return
    end

    if step.type == WorkflowManager.STEP_AUTODRIVE then
        ADIntegration:stopRoute(workflow.vehicle)
    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        CPIntegration:stopCourse(workflow.vehicle)
    end
end

---Pause the current step
---@param workflow table Workflow
function WMExecutor:pauseCurrentStep(workflow)
    local step = workflow.steps[workflow.currentStep]
    if step == nil then
        return
    end

    if step.type == WorkflowManager.STEP_AUTODRIVE then
        ADIntegration:pauseRoute(workflow.vehicle)
    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        CPIntegration:pauseCourse(workflow.vehicle)
    end
end

---Resume the current step
---@param workflow table Workflow
function WMExecutor:resumeCurrentStep(workflow)
    local step = workflow.steps[workflow.currentStep]
    if step == nil then
        return
    end

    if step.type == WorkflowManager.STEP_AUTODRIVE then
        ADIntegration:resumeRoute(workflow.vehicle)
    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        CPIntegration:resumeCourse(workflow.vehicle)
    end
end

---Handle step completion
---@param workflow table Workflow
function WMExecutor:onStepCompleted(workflow)
    WMLogger:info("Step %d completed for workflow %s", workflow.currentStep, workflow.name)

    -- Fire step completed event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_COMPLETED, {
        workflowId = workflow.id,
        stepNumber = workflow.currentStep
    })

    -- Move to next step
    workflow.currentStep = workflow.currentStep + 1

    -- Check if workflow is complete
    if workflow.currentStep > #workflow.steps then
        self:onWorkflowCompleted(workflow)
    else
        -- Execute next step
        self:executeCurrentStep(workflow)
    end
end

---Handle workflow completion
---@param workflow table Workflow
function WMExecutor:onWorkflowCompleted(workflow)
    WMLogger:info("Workflow completed: %s", workflow.name)

    workflow.status = WorkflowManager.STATUS_COMPLETED
    workflow.currentStep = 1 -- Reset for potential re-run

    -- Remove from active workflows
    self.activeWorkflows[workflow.id] = nil

    -- Fire completion event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_COMPLETED, {
        workflowId = workflow.id,
        workflowName = workflow.name
    })
end

---Handle step error
---@param workflow table Workflow
---@param errorMessage string Error message
function WMExecutor:handleStepError(workflow, errorMessage)
    WMLogger:error("Step error in workflow %s: %s", workflow.name, errorMessage)

    workflow.status = WorkflowManager.STATUS_ERROR

    -- Fire error event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_ERROR, {
        workflowId = workflow.id,
        stepNumber = workflow.currentStep,
        error = errorMessage
    })

    -- Stop the workflow
    self:stopWorkflow(workflow)
end

---Update function called every frame
---@param dt number Delta time in milliseconds
function WMExecutor:update(dt)
    if not self.isInitialized then
        return
    end

    -- Throttle update checks
    self.updateTimer = self.updateTimer + dt
    if self.updateTimer < self.UPDATE_INTERVAL then
        return
    end
    self.updateTimer = 0

    -- Check each active workflow for step completion
    for workflowId, activeData in pairs(self.activeWorkflows) do
        local workflow = activeData.workflow

        if workflow.status == WorkflowManager.STATUS_RUNNING and activeData.waitingForCompletion then
            local isComplete = false

            -- Check completion based on current step type
            if activeData.currentStepType == WorkflowManager.STEP_AUTODRIVE then
                isComplete = ADIntegration:isRouteComplete(workflow.vehicle)
            elseif activeData.currentStepType == WorkflowManager.STEP_COURSEPLAY then
                isComplete = CPIntegration:isCourseComplete(workflow.vehicle)
            end

            if isComplete then
                activeData.waitingForCompletion = false
                self:onStepCompleted(workflow)
            end
        end
    end
end

---Get the count of active workflows
---@return number count Number of active workflows
function WMExecutor:getActiveWorkflowCount()
    local count = 0
    for _ in pairs(self.activeWorkflows) do
        count = count + 1
    end
    return count
end

---Check if a workflow is active
---@param workflowId string Workflow ID
---@return boolean isActive True if workflow is active
function WMExecutor:isWorkflowActive(workflowId)
    return self.activeWorkflows[workflowId] ~= nil
end
