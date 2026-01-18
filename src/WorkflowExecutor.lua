--[[
    WorkflowManager - Workflow Executor
    Executes workflow steps and manages the state machine

    Uses AutoDrive and Courseplay APIs for step execution:
    - AutoDrive: StartDriving with callback for completion
    - Courseplay: startCpAtLastWp/startCpAtFirstWp, poll getIsCpActive

    Author: WorkflowManager Team
]]

---@class WMExecutor
WMExecutor = {}

-- Executor state
WMExecutor.activeWorkflows = {}
WMExecutor.isInitialized = false

-- Update interval for checking step completion (ms)
WMExecutor.UPDATE_INTERVAL = 500  -- Check twice per second for responsiveness
WMExecutor.updateTimer = 0

-- Callback tracking for AutoDrive completion
WMExecutor.pendingADCallbacks = {}

---Initialize the executor
function WMExecutor:init()
    self.activeWorkflows = {}
    self.pendingADCallbacks = {}
    self.updateTimer = 0
    self.isInitialized = true

    -- Register for AutoDrive destination listener (global completion notifications)
    if AutoDrive and AutoDrive.registerDestinationListener then
        AutoDrive:registerDestinationListener(self, self.onADDestinationReached)
        WMLogger:debug("Registered AutoDrive destination listener")
    end

    -- Subscribe to internal events
    WMEventHandler:subscribe(WMEventHandler.EVENT_AUTODRIVE_FINISHED, self, self.onADFinishedEvent)

    WMLogger:debug("WorkflowExecutor initialized")
end

---Callback when AutoDrive reaches destination (global listener)
---@param success boolean Whether the route completed successfully
function WMExecutor:onADDestinationReached(success)
    WMLogger:debug("AutoDrive destination reached (global), success: %s", tostring(success))
    -- This is called for ALL AD completions, we handle specific ones via the callback system
end

---Handle AutoDrive finished event from our integration
---@param eventData table Event data with vehicle and success
function WMExecutor:onADFinishedEvent(eventData)
    if eventData == nil or eventData.vehicle == nil then
        return
    end

    -- Find the workflow that was waiting for this vehicle
    for workflowId, activeData in pairs(self.activeWorkflows) do
        local workflow = activeData.workflow
        if workflow.vehicle == eventData.vehicle and
           activeData.waitingForCompletion and
           activeData.currentStepType == WorkflowManager.STEP_AUTODRIVE then

            WMLogger:info("AutoDrive step completed for workflow %s (via callback)", workflow.name)
            activeData.waitingForCompletion = false
            self:onStepCompleted(workflow)
            return
        end
    end
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

    -- Always start from beginning (reset to step 1)
    workflow.currentStep = 1
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
        -- AutoDrive: Use startRoute which internally uses StartDriving with callback
        -- Pass all step parameters including unloadTarget and fillType
        WMLogger:info("Starting AutoDrive step - vehicle: %s, target: %s, action: %s, unloadTarget: %s, fillType: %s",
            workflow.vehicle and (workflow.vehicle.getName and workflow.vehicle:getName() or "unknown") or "nil",
            step.target or "nil",
            step.action or "nil",
            step.unloadTarget or "nil",
            step.fillType or "nil")

        local success = ADIntegration:startRoute(
            workflow.vehicle,
            step.target,
            step.action,
            step.unloadTarget,
            step.fillType
        )
        if success then
            activeData.waitingForCompletion = true
            activeData.currentStepType = WorkflowManager.STEP_AUTODRIVE
            WMLogger:info("AutoDrive step started successfully, waiting for completion")
        else
            self:handleStepError(workflow, "Failed to start AutoDrive route: " .. (step.target or "nil"))
        end

    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        -- Courseplay: The 'target' field specifies which course to load
        WMLogger:info("Starting Courseplay step - vehicle: %s, course: %s, action: %s",
            workflow.vehicle and (workflow.vehicle.getName and workflow.vehicle:getName() or "unknown") or "nil",
            step.target or "nil",
            step.action or "nil")

        -- Check if vehicle has the course loaded, if not try to load it
        if not CPIntegration:hasCourse(workflow.vehicle) then
            WMLogger:info("No course loaded on vehicle, attempting to load: %s", step.target)
            local loadSuccess = CPIntegration:loadCourse(workflow.vehicle, step.target)
            if not loadSuccess then
                self:handleStepError(workflow, "Failed to load Courseplay course: " .. (step.target or "nil"))
                return
            end
        else
            -- Course is loaded - check if it's the right one
            local currentCourse = CPIntegration:getCurrentCourseName(workflow.vehicle)
            WMLogger:debug("Vehicle already has course loaded: %s", currentCourse or "unknown")
        end

        -- Verify course is now loaded
        if not CPIntegration:hasCourse(workflow.vehicle) then
            self:handleStepError(workflow, "Vehicle has no Courseplay course loaded for step: " .. (step.target or "nil"))
            return
        end

        -- Determine start position based on action
        local startAtFirst = (step.action == "first" or step.action == "start")
        local success = CPIntegration:startFieldWork(workflow.vehicle, startAtFirst)

        if success then
            activeData.waitingForCompletion = true
            activeData.currentStepType = WorkflowManager.STEP_COURSEPLAY
            activeData.cpWasRunning = true  -- Track that we started CP
            WMLogger:info("Courseplay step started successfully, polling for completion")
        else
            self:handleStepError(workflow, "Failed to start Courseplay field work")
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
        -- Use holdCourse for CP (temporary pause)
        CPIntegration:holdCourse(workflow.vehicle, nil)  -- nil = indefinite freeze
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
                -- AutoDrive: Check if route is complete (polling fallback, callbacks preferred)
                isComplete = ADIntegration:isRouteComplete(workflow.vehicle)

            elseif activeData.currentStepType == WorkflowManager.STEP_COURSEPLAY then
                -- Courseplay: Check if CP is no longer running
                -- We need to detect transition from running -> not running
                local cpRunning = CPIntegration:isRunning(workflow.vehicle)

                if activeData.cpWasRunning and not cpRunning then
                    -- CP was running and now stopped = completed
                    isComplete = true
                    WMLogger:debug("Courseplay step completed (was running, now stopped)")
                elseif not cpRunning and not activeData.cpWasRunning then
                    -- CP never started or failed to start
                    WMLogger:warning("Courseplay never started for workflow %s", workflow.name)
                    isComplete = true  -- Treat as complete to avoid hanging
                end

                -- Update tracking
                activeData.cpWasRunning = cpRunning
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
