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
        -- Milestone 4: Use activeData.vehicle instead of workflow.vehicle
        if activeData.vehicle == eventData.vehicle and
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
---Milestone 4: Vehicle is now passed as a parameter instead of being stored in workflow
---@param workflow table Workflow to execute
---@param vehicle table Vehicle to use for this workflow execution
---@return boolean success True if started successfully
function WMExecutor:startWorkflow(workflow, vehicle)
    if workflow == nil then
        WMLogger:error("Cannot start nil workflow")
        return false
    end

    if vehicle == nil then
        WMLogger:error("Cannot start workflow without a vehicle")
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

    -- Milestone 4: Store vehicle in activeData instead of workflow
    self.activeWorkflows[workflow.id] = {
        workflow = workflow,
        vehicle = vehicle,  -- Vehicle is stored here at runtime, not in workflow
        startTime = g_currentMission.time,
        waitingForCompletion = false
    }

    local vehicleName = vehicle.getName and vehicle:getName() or "unknown"
    WMLogger:info("Starting workflow: %s with vehicle: %s (Step %d/%d)",
        workflow.name, vehicleName, workflow.currentStep, #workflow.steps)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_STARTED, {
        workflowId = workflow.id,
        workflowName = workflow.name,
        vehicleName = vehicleName
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
---When paused, workflow tracking is interrupted and stays in current step
---even if AD or CP finishes their current operation
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

    -- Mark as paused FIRST to stop tracking in update loop
    workflow.status = WorkflowManager.STATUS_PAUSED

    -- Store tracking state so we can restore it on resume
    activeData.pausedTrackingState = {
        waitingForCompletion = activeData.waitingForCompletion,
        currentStepType = activeData.currentStepType,
        willHandoffToCP = activeData.willHandoffToCP,
        cpHandedOffToAD = activeData.cpHandedOffToAD,
        cpWasRunning = activeData.cpWasRunning
    }

    -- Stop waiting for completion while paused
    -- This ensures we stay in the current step even if AD/CP finishes
    activeData.waitingForCompletion = false

    -- Pause current step (AD/CP)
    self:pauseCurrentStep(workflow)

    WMLogger:info("Paused workflow: %s at step %d (tracking interrupted)", workflow.name, workflow.currentStep)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_PAUSED, {
        workflowId = workflow.id,
        currentStep = workflow.currentStep
    })

    return true
end

---Resume a paused workflow
---Restores tracking state and resumes AD/CP operation
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

    -- Restore tracking state from before pause
    if activeData.pausedTrackingState then
        activeData.waitingForCompletion = activeData.pausedTrackingState.waitingForCompletion
        activeData.currentStepType = activeData.pausedTrackingState.currentStepType
        activeData.willHandoffToCP = activeData.pausedTrackingState.willHandoffToCP
        activeData.cpHandedOffToAD = activeData.pausedTrackingState.cpHandedOffToAD
        activeData.cpWasRunning = activeData.pausedTrackingState.cpWasRunning
        activeData.pausedTrackingState = nil
    else
        -- Fallback: restore waitingForCompletion
        activeData.waitingForCompletion = true
    end

    workflow.status = WorkflowManager.STATUS_RUNNING

    -- Resume current step (AD/CP)
    self:resumeCurrentStep(workflow)

    WMLogger:info("Resumed workflow: %s at step %d (tracking restored)", workflow.name, workflow.currentStep)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_RESUMED, {
        workflowId = workflow.id,
        currentStep = workflow.currentStep
    })

    return true
end

---Execute the current step of a workflow
---Milestone 4: Uses activeData.vehicle instead of workflow.vehicle
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
    local vehicle = activeData.vehicle  -- Milestone 4: Get vehicle from activeData

    -- Execute based on step type
    if step.type == WorkflowManager.STEP_AUTODRIVE then
        -- AutoDrive: Use startRoute which internally uses StartDriving with callback
        -- Pass all step parameters including unloadTarget and fillType
        WMLogger:info("Starting AutoDrive step - vehicle: %s, target: %s, action: %s, unloadTarget: %s, fillType: %s",
            vehicle and (vehicle.getName and vehicle:getName() or "unknown") or "nil",
            step.target or "nil",
            step.action or "nil",
            step.unloadTarget or "nil",
            step.fillType or "nil")

        -- If AutoDrive was just stopped (e.g., manual PREV/NEXT from another AD step),
        -- we must wait for AD to fully reset before starting a new route.
        -- isRunning() may return false immediately after setActive(false), but AD's internal
        -- state may not be fully reset yet.
        if ADIntegration:isRunning(vehicle) or activeData.justStoppedAD then
            WMLogger:debug("Deferring AD start for reset (isRunning=%s, justStopped=%s)",
                tostring(ADIntegration:isRunning(vehicle)), tostring(activeData.justStoppedAD or false))
            activeData.waitingForCompletion = true
            activeData.currentStepType = WorkflowManager.STEP_AUTODRIVE
            activeData.pendingADStart = true
            activeData.pendingADStartRetries = 0
            return
        end

        self:startAutoDriveStep(workflow, activeData, vehicle, step)

    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        -- Courseplay: The 'target' field specifies which course to load
        WMLogger:info("Starting Courseplay step - vehicle: %s, course: %s, action: %s",
            vehicle and (vehicle.getName and vehicle:getName() or "unknown") or "nil",
            step.target or "nil",
            step.action or "nil")

        -- If AutoDrive was just stopped (e.g., manual PREV/NEXT), it may still be
        -- "active" for a frame. Defer CP start to the update loop so AD can fully release.
        if ADIntegration:isRunning(vehicle) then
            WMLogger:info("AutoDrive still active after stop - deferring CP start")
            activeData.waitingForCompletion = true
            activeData.currentStepType = WorkflowManager.STEP_COURSEPLAY
            activeData.pendingCPStart = true
            activeData.pendingCPStartRetries = 0
            return
        end

        self:startCourseplayStep(workflow, activeData, vehicle, step)
    else
        self:handleStepError(workflow, "Unknown step type: " .. tostring(step.type))
    end
end

---Stop the current step
---Handles both running and paused states (unfreezes CP / unpauses AD before stopping)
---Also handles cyclic handoffs: when CP step has handed off to AD, stops AD too
---Milestone 4: Uses activeData.vehicle instead of workflow.vehicle
---@param workflow table Workflow
function WMExecutor:stopCurrentStep(workflow)
    local step = workflow.steps[workflow.currentStep]
    if step == nil then
        return
    end

    local activeData = self.activeWorkflows[workflow.id]
    local vehicle = activeData and activeData.vehicle or nil

    if vehicle == nil then
        WMLogger:warning("Cannot stop step - no vehicle in activeData")
        return
    end

    -- Always clear the AD->CP handoff flag to prevent AD from restarting CP during shutdown
    pcall(function() ADIntegration:clearCPHandoff(vehicle) end)

    if step.type == WorkflowManager.STEP_AUTODRIVE then
        -- Resume AD first if it was paused (HoldDriving), then stop
        if workflow.status == WorkflowManager.STATUS_PAUSED then
            pcall(function() ADIntegration:resumeRoute(vehicle) end)
        end
        pcall(function() ADIntegration:stopRoute(vehicle) end)
        -- Mark that we just stopped AD - next AD start needs to wait a frame
        activeData.justStoppedAD = true
    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        -- During CP steps, AD may be running due to cyclic handoff (CP->AD for unload)
        -- Stop both AD and CP to ensure clean shutdown
        if activeData.cpHandedOffToAD or ADIntegration:isRunning(vehicle) then
            WMLogger:info("Stopping AutoDrive (running during CP step due to handoff)")
            pcall(function() ADIntegration:stopRoute(vehicle) end)
        end

        -- Unfreeze CP first if it was frozen (paused), then stop
        if workflow.status == WorkflowManager.STATUS_PAUSED then
            pcall(function() CPIntegration:resumeCourse(vehicle) end)
        end
        pcall(function() CPIntegration:stopCourse(vehicle) end)
    end
end

---Start an AutoDrive step (extracted for reuse by deferred start)
---@param workflow table Workflow
---@param activeData table Active workflow data
---@param vehicle table Vehicle
---@param step table Step data
function WMExecutor:startAutoDriveStep(workflow, activeData, vehicle, step)
    -- Check if next step is Courseplay - if so, configure AD to hand off to CP
    local nextStep = workflow.steps[workflow.currentStep + 1]
    local willHandoffToCP = false

    if nextStep ~= nil and nextStep.type == WorkflowManager.STEP_COURSEPLAY then
        WMLogger:info("Next step is Courseplay - configuring AD->CP handoff")

        -- Pre-load the Courseplay course onto the vehicle
        if not CPIntegration:hasCourse(vehicle) or true then  -- Always try to load correct course
            WMLogger:info("Pre-loading Courseplay course for handoff: %s", nextStep.target or "nil")
            local loadSuccess = CPIntegration:loadCourse(vehicle, nextStep.target)
            if loadSuccess then
                -- Configure AutoDrive to start Courseplay when it completes
                -- Uses stateModule:setStartHelper(true) - AD will start CP automatically
                ADIntegration:setStartCPOnCompletion(vehicle, true)
                willHandoffToCP = true
                WMLogger:info("AD->CP handoff configured, course pre-loaded, setStartHelper enabled")
            else
                WMLogger:warning("Failed to pre-load CP course, will start CP manually after AD completes")
            end
        end
    end

    local success = ADIntegration:startRoute(
        vehicle,
        step.target,
        step.action,
        step.unloadTarget,
        step.fillType
    )
    if success then
        activeData.waitingForCompletion = true
        activeData.currentStepType = WorkflowManager.STEP_AUTODRIVE
        activeData.willHandoffToCP = willHandoffToCP  -- Track that AD will start CP
        activeData.pendingADStart = nil
        activeData.pendingADStartRetries = nil
        activeData.justStoppedAD = nil  -- Clear the flag now that AD has started
        WMLogger:info("AutoDrive step started successfully, waiting for completion (handoffToCP=%s)",
            tostring(willHandoffToCP))
    else
        -- Clear handoff flag if AD failed to start
        if willHandoffToCP then
            ADIntegration:clearCPHandoff(vehicle)
        end
        self:handleStepError(workflow, "Failed to start AutoDrive route: " .. (step.target or "nil"))
    end
end

---Start a Courseplay step (extracted for reuse by deferred start)
---@param workflow table Workflow
---@param activeData table Active workflow data
---@param vehicle table Vehicle
---@param step table Step data
function WMExecutor:startCourseplayStep(workflow, activeData, vehicle, step)
    -- Check if vehicle has the correct course loaded
    local currentCourse = CPIntegration:getCurrentCourseName(vehicle)
    local hasCourse = CPIntegration:hasCourse(vehicle)
    local needsLoad = not hasCourse or currentCourse ~= step.target

    if needsLoad then
        WMLogger:info("Loading course for step: %s (current: %s)", step.target or "nil", currentCourse or "none")
        local loadSuccess = CPIntegration:loadCourse(vehicle, step.target)
        if not loadSuccess then
            self:handleStepError(workflow, "Failed to load Courseplay course: " .. (step.target or "nil"))
            return
        end
    else
        WMLogger:debug("Correct course already loaded: %s", currentCourse or "unknown")
    end

    -- Verify course is now loaded
    if not CPIntegration:hasCourse(vehicle) then
        self:handleStepError(workflow, "Vehicle has no Courseplay course loaded for step: " .. (step.target or "nil"))
        return
    end

    -- Determine start position based on action
    local startAtFirst = (step.action == "first" or step.action == "start")
    local success = CPIntegration:startFieldWork(vehicle, startAtFirst)

    if success then
        activeData.waitingForCompletion = true
        activeData.currentStepType = WorkflowManager.STEP_COURSEPLAY
        activeData.cpWasRunning = true  -- Track that we started CP
        activeData.pendingCPStart = nil
        activeData.pendingCPStartRetries = nil
        WMLogger:info("Courseplay step started successfully, polling for completion")
    else
        self:handleStepError(workflow, "Failed to start Courseplay field work")
    end
end

---Pause the current step
---Milestone 4: Uses activeData.vehicle instead of workflow.vehicle
---@param workflow table Workflow
function WMExecutor:pauseCurrentStep(workflow)
    local step = workflow.steps[workflow.currentStep]
    if step == nil then
        return
    end

    local activeData = self.activeWorkflows[workflow.id]
    local vehicle = activeData and activeData.vehicle or nil

    if vehicle == nil then
        WMLogger:warning("Cannot pause step - no vehicle in activeData")
        return
    end

    if step.type == WorkflowManager.STEP_AUTODRIVE then
        ADIntegration:pauseRoute(vehicle)
    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        -- Use holdCourse for CP (temporary pause)
        CPIntegration:holdCourse(vehicle, nil)  -- nil = indefinite freeze
    end
end

---Resume the current step
---Milestone 4: Uses activeData.vehicle instead of workflow.vehicle
---@param workflow table Workflow
function WMExecutor:resumeCurrentStep(workflow)
    local step = workflow.steps[workflow.currentStep]
    if step == nil then
        return
    end

    local activeData = self.activeWorkflows[workflow.id]
    local vehicle = activeData and activeData.vehicle or nil

    if vehicle == nil then
        WMLogger:warning("Cannot resume step - no vehicle in activeData")
        return
    end

    if step.type == WorkflowManager.STEP_AUTODRIVE then
        ADIntegration:resumeRoute(vehicle)
    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        CPIntegration:resumeCourse(vehicle)
    end
end

---Handle step completion
---@param workflow table Workflow
function WMExecutor:onStepCompleted(workflow)
    local activeData = self.activeWorkflows[workflow.id]
    local completedStepNum = workflow.currentStep

    WMLogger:info("Step %d completed for workflow %s", completedStepNum, workflow.name)

    -- Fire step completed event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_COMPLETED, {
        workflowId = workflow.id,
        stepNumber = completedStepNum
    })

    -- Check if AD handed off to CP (AD already started CP for us)
    local adHandedOffToCP = activeData and activeData.willHandoffToCP

    -- Move to next step
    workflow.currentStep = workflow.currentStep + 1

    -- Check if workflow is complete
    if workflow.currentStep > #workflow.steps then
        self:onWorkflowCompleted(workflow)
    elseif adHandedOffToCP then
        -- AD already started Courseplay - just set up monitoring, don't call executeCurrentStep
        local nextStep = workflow.steps[workflow.currentStep]
        WMLogger:info("AD handed off to CP - skipping CP start, monitoring step %d: %s",
            workflow.currentStep, nextStep.target or "unknown")

        -- Fire step started event for the CP step
        WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_STARTED, {
            workflowId = workflow.id,
            stepNumber = workflow.currentStep,
            stepType = nextStep.type,
            target = nextStep.target
        })

        -- Set up CP monitoring (AD already started it)
        activeData.waitingForCompletion = true
        activeData.currentStepType = WorkflowManager.STEP_COURSEPLAY
        activeData.willHandoffToCP = false  -- Clear the handoff flag
        activeData.cpWasRunning = true  -- Assume CP is running since AD started it
        activeData.cpStartedByAD = true  -- Track that AD started CP
    else
        -- Normal case: Execute next step
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
        local vehicle = activeData.vehicle  -- Milestone 4: Use vehicle from activeData

        if workflow.status == WorkflowManager.STATUS_RUNNING and activeData.waitingForCompletion then
            -- Handle deferred CP start: AD was just stopped and CP needs to start
            if activeData.pendingCPStart then
                local adRunning = ADIntegration:isRunning(vehicle)
                if not adRunning then
                    -- AD has fully stopped, now start CP
                    WMLogger:info("AutoDrive fully stopped - starting deferred Courseplay step")
                    activeData.pendingCPStart = nil
                    activeData.pendingCPStartRetries = nil
                    activeData.waitingForCompletion = false
                    local step = workflow.steps[workflow.currentStep]
                    if step then
                        self:startCourseplayStep(workflow, activeData, vehicle, step)
                    end
                else
                    activeData.pendingCPStartRetries = (activeData.pendingCPStartRetries or 0) + 1
                    -- Give up after 20 checks (10 seconds) to avoid hanging
                    if activeData.pendingCPStartRetries > 20 then
                        WMLogger:warning("AutoDrive did not stop after 10s - forcing CP start")
                        activeData.pendingCPStart = nil
                        activeData.pendingCPStartRetries = nil
                        activeData.waitingForCompletion = false
                        local step = workflow.steps[workflow.currentStep]
                        if step then
                            self:startCourseplayStep(workflow, activeData, vehicle, step)
                        end
                    else
                        WMLogger:debug("Waiting for AD to stop before starting CP (%d/20)", activeData.pendingCPStartRetries)
                    end
                end
            -- Handle deferred AD start: AD was just stopped (from another AD step) and needs to restart
            elseif activeData.pendingADStart then
                -- Always increment retry counter first - we need at least one wait cycle
                -- for AD to fully reset internally (even if isRunning returns false immediately)
                activeData.pendingADStartRetries = (activeData.pendingADStartRetries or 0) + 1

                local adRunning = ADIntegration:isRunning(vehicle)
                -- Require at least 2 cycles (1 second) for AD to fully reset, or until AD stops running
                local minWaitCycles = 2
                local readyToStart = not adRunning and activeData.pendingADStartRetries >= minWaitCycles

                if readyToStart then
                    -- AD has fully stopped and we've waited enough, now start the new AD route
                    WMLogger:debug("AD reset complete - starting deferred step")
                    activeData.pendingADStart = nil
                    activeData.pendingADStartRetries = nil
                    activeData.justStoppedAD = nil
                    activeData.waitingForCompletion = false
                    local step = workflow.steps[workflow.currentStep]
                    if step then
                        self:startAutoDriveStep(workflow, activeData, vehicle, step)
                    end
                elseif activeData.pendingADStartRetries > 20 then
                    -- Give up after 20 checks (10 seconds) to avoid hanging
                    WMLogger:warning("AutoDrive did not stop after 10s - forcing AD start")
                    activeData.pendingADStart = nil
                    activeData.pendingADStartRetries = nil
                    activeData.justStoppedAD = nil
                    activeData.waitingForCompletion = false
                    local step = workflow.steps[workflow.currentStep]
                    if step then
                        self:startAutoDriveStep(workflow, activeData, vehicle, step)
                    end
                end
            else
                -- Normal completion check
                local isComplete = false

                -- Check completion based on current step type
                if activeData.currentStepType == WorkflowManager.STEP_AUTODRIVE then
                    -- AutoDrive: Check if route is complete (polling fallback, callbacks preferred)
                    isComplete = ADIntegration:isRouteComplete(vehicle)

                elseif activeData.currentStepType == WorkflowManager.STEP_COURSEPLAY then
                    -- Courseplay: Check if CP is no longer running
                    -- We need to detect transition from running -> not running
                    -- Also handle cyclic handoffs: CP → AD (unload) → CP (continue) → AD → ...
                    local cpRunning = CPIntegration:isRunning(vehicle)
                    local adRunning = ADIntegration:isRunning(vehicle)

                    -- Handle case: CP handed off to AD and we're waiting for AD to complete
                    if activeData.cpHandedOffToAD then
                        if not adRunning then
                            -- AD finished after CP handed off to it
                            -- But check if CP started again (AD may have restarted CP)
                            if cpRunning then
                                WMLogger:debug("AutoDrive completed and Courseplay restarted - continuing to monitor CP")
                                activeData.cpHandedOffToAD = false
                                activeData.cpWasRunning = true  -- Track that CP is running again
                            else
                                -- Neither CP nor AD running - truly complete
                                WMLogger:debug("AutoDrive completed after Courseplay handoff - CP step complete")
                                isComplete = true
                                activeData.cpHandedOffToAD = false
                            end
                        -- else: still waiting for AD, no log needed (would spam every 500ms)
                        end
                    elseif activeData.cpWasRunning and not cpRunning then
                        -- CP was running and now stopped
                        -- Check if CP handed off to AutoDrive
                        if adRunning then
                            -- CP stopped but AD is now running - CP internally started AD
                            -- This happens when CP finishes fieldwork and starts AD for unloading
                            WMLogger:debug("Courseplay stopped but AutoDrive is running - waiting for AD")
                            activeData.cpHandedOffToAD = true
                            -- Don't mark as complete - wait for AD to finish
                        else
                            -- CP stopped and AD is not running = truly completed
                            isComplete = true
                            WMLogger:debug("Courseplay step completed (was running, now stopped)")
                        end
                    elseif not cpRunning and not activeData.cpWasRunning then
                        -- CP not running and was never detected running
                        -- Check if AD is running (might have started before we could detect CP)
                        if adRunning then
                            WMLogger:debug("AutoDrive detected running at start of CP step - waiting for AD")
                            activeData.cpHandedOffToAD = true
                        elseif activeData.cpStartedByAD then
                            -- AD handed off to CP - give it some time to actually start
                            -- Initialize wait counter if not set
                            if activeData.cpStartWaitCount == nil then
                                activeData.cpStartWaitCount = 0
                            end
                            activeData.cpStartWaitCount = activeData.cpStartWaitCount + 1

                            -- Wait up to 10 checks (5 seconds at 500ms interval) for CP to start
                            if activeData.cpStartWaitCount > 10 then
                                WMLogger:warning("Courseplay did not start after AD handoff for workflow %s", workflow.name)
                                isComplete = true  -- Treat as complete to avoid hanging
                            else
                                WMLogger:debug("Waiting for CP to start after AD handoff (%d/10)", activeData.cpStartWaitCount)
                            end
                        else
                            -- CP never started or failed to start (not from AD handoff)
                            WMLogger:warning("Courseplay never started for workflow %s", workflow.name)
                            isComplete = true  -- Treat as complete to avoid hanging
                        end
                    elseif cpRunning and activeData.cpStartedByAD then
                        -- CP started successfully after AD handoff
                        WMLogger:debug("Courseplay started successfully after AD handoff")
                        activeData.cpStartedByAD = false  -- Clear the flag
                        activeData.cpStartWaitCount = nil
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

---Go to the previous step in a workflow
---Stops current step and moves to the previous one
---@param workflow table Workflow
---@return boolean success True if moved to previous step
function WMExecutor:goToPreviousStep(workflow)
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

    -- Remember if workflow was paused so we can resume after step change
    local wasPaused = workflow.status == WorkflowManager.STATUS_PAUSED

    -- Stop the current step (handles paused state internally)
    self:stopCurrentStep(workflow)

    -- Move to previous step
    workflow.currentStep = workflow.currentStep - 1

    WMLogger:info("Moving to previous step %d/%d for workflow %s",
        workflow.currentStep, #workflow.steps, workflow.name)

    -- Reset waiting state
    activeData.waitingForCompletion = false
    activeData.willHandoffToCP = false
    activeData.cpHandedOffToAD = false
    activeData.cpWasRunning = false
    activeData.cpStartedByAD = false
    activeData.cpStartWaitCount = nil
    activeData.pausedTrackingState = nil
    activeData.pendingCPStart = nil
    activeData.pendingCPStartRetries = nil
    activeData.pendingADStart = nil
    activeData.pendingADStartRetries = nil

    -- Resume workflow to running state if it was paused, then execute new step
    if wasPaused then
        workflow.status = WorkflowManager.STATUS_RUNNING
    end

    -- If workflow is running, start the new step
    if workflow.status == WorkflowManager.STATUS_RUNNING then
        self:executeCurrentStep(workflow)
    end

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_CHANGED, {
        workflowId = workflow.id,
        stepNumber = workflow.currentStep,
        direction = "previous"
    })

    return true
end

---Go to the next step in a workflow
---Stops current step and moves to the next one
---@param workflow table Workflow
---@return boolean success True if moved to next step
function WMExecutor:goToNextStep(workflow)
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

    -- Remember if workflow was paused so we can resume after step change
    local wasPaused = workflow.status == WorkflowManager.STATUS_PAUSED

    -- Stop the current step (handles paused state internally)
    self:stopCurrentStep(workflow)

    -- Move to next step
    workflow.currentStep = workflow.currentStep + 1

    WMLogger:info("Moving to next step %d/%d for workflow %s",
        workflow.currentStep, #workflow.steps, workflow.name)

    -- Reset waiting state
    activeData.waitingForCompletion = false
    activeData.willHandoffToCP = false
    activeData.cpHandedOffToAD = false
    activeData.cpWasRunning = false
    activeData.cpStartedByAD = false
    activeData.cpStartWaitCount = nil
    activeData.pausedTrackingState = nil
    activeData.pendingCPStart = nil
    activeData.pendingCPStartRetries = nil
    activeData.pendingADStart = nil
    activeData.pendingADStartRetries = nil

    -- Resume workflow to running state if it was paused, then execute new step
    if wasPaused then
        workflow.status = WorkflowManager.STATUS_RUNNING
    end

    -- If workflow is running, start the new step
    if workflow.status == WorkflowManager.STATUS_RUNNING then
        self:executeCurrentStep(workflow)
    end

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_CHANGED, {
        workflowId = workflow.id,
        stepNumber = workflow.currentStep,
        direction = "next"
    })

    return true
end
