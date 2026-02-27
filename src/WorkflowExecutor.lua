--[[
    WorkflowManager - Workflow Executor
    Executes workflow steps and manages the state machine

    Uses AutoDrive and Courseplay APIs for step execution:
    - AutoDrive: StartDriving with callback for completion
    - Courseplay: startCpAtLastWp/startCpAtFirstWp, poll getIsCpActive

    Per-vehicle execution state lives on vehicle.spec_workflowManagerSpec.wmExecution.
    Workflow definitions are immutable templates; all mutable runtime state
    (status, currentStep, tracking flags) lives in activeData on the spec.
    activeVehicles is a lightweight set {[vehicle]=true} for update-loop iteration.

    Author: WorkflowManager Team
]]

---@class WMExecutor
WMExecutor = {}

-- Lightweight set of vehicles with active workflows (for iteration)
WMExecutor.activeVehicles = {}
WMExecutor.isInitialized = false

-- Update interval for checking step completion (ms)
WMExecutor.UPDATE_INTERVAL = 500  -- Check twice per second for responsiveness
WMExecutor.updateTimer = 0

-- Callback tracking for AutoDrive completion
WMExecutor.pendingADCallbacks = {}

---Initialize the executor
function WMExecutor:init()
    self.activeVehicles = {}
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
    for vehicle, _ in pairs(self.activeVehicles) do
        local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
        if activeData ~= nil then
            local workflow = activeData.workflow
            if activeData.vehicle == eventData.vehicle and
               activeData.waitingForCompletion and
               activeData.currentStepType == WorkflowManager.STEP_AUTODRIVE then

                WMLogger:info("AutoDrive step completed for workflow %s (via callback)", workflow.name)
                activeData.waitingForCompletion = false
                self:onStepCompleted(activeData)
                return
            end
        end
    end
end

---Start executing a workflow on a vehicle
---@param workflow table Workflow definition (immutable template)
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

    -- Check if vehicle spec is present
    if vehicle.spec_workflowManagerSpec == nil then
        WMLogger:error("Vehicle does not have WorkflowManagerSpec - cannot start workflow")
        return false
    end

    -- Check if this vehicle is already running a workflow
    if vehicle.spec_workflowManagerSpec.wmExecution ~= nil then
        WMLogger:warning("Vehicle is already running a workflow")
        return false
    end

    -- Validate workflow has steps
    if #workflow.steps == 0 then
        WMLogger:error("Workflow %s has no steps", workflow.id)
        return false
    end

    local vehicleName = vehicle.getName and vehicle:getName() or "unknown"

    -- Create per-vehicle execution state on the spec (does NOT mutate workflow definition)
    vehicle.spec_workflowManagerSpec.wmExecution = {
        workflow = workflow,
        vehicle = vehicle,
        status = WorkflowManager.STATUS_RUNNING,
        currentStep = 1,
        startTime = g_currentMission.time,
        waitingForCompletion = false
    }
    self.activeVehicles[vehicle] = true

    local activeData = vehicle.spec_workflowManagerSpec.wmExecution

    WMLogger:info("Starting workflow: %s with vehicle: %s (Step %d/%d)",
        workflow.name, vehicleName, activeData.currentStep, #workflow.steps)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_STARTED, {
        workflowId = workflow.id,
        workflowName = workflow.name,
        vehicle = vehicle,
        vehicleName = vehicleName
    })

    -- Execute first step
    self:executeCurrentStep(activeData)

    return true
end

---Stop a running workflow on a vehicle
---@param vehicle table Vehicle whose workflow to stop
---@return boolean success True if stopped successfully
function WMExecutor:stopWorkflow(vehicle)
    if vehicle == nil then
        return false
    end

    local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
    if activeData == nil then
        WMLogger:warning("No active workflow for vehicle")
        return false
    end

    local workflow = activeData.workflow

    -- Stop current step
    self:stopCurrentStep(activeData)

    -- Remove from active
    vehicle.spec_workflowManagerSpec.wmExecution = nil
    self.activeVehicles[vehicle] = nil

    WMLogger:info("Stopped workflow: %s (reset to step 1)", workflow.name)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_STOPPED, {
        workflowId = workflow.id
    })

    return true
end

---Pause a running workflow on a vehicle
---When paused, workflow tracking is interrupted and stays in current step
---even if AD or CP finishes their current operation
---@param vehicle table Vehicle whose workflow to pause
---@return boolean success True if paused successfully
function WMExecutor:pauseWorkflow(vehicle)
    if vehicle == nil then
        return false
    end

    local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
    if activeData == nil then
        WMLogger:warning("No active workflow for vehicle")
        return false
    end

    if activeData.status ~= WorkflowManager.STATUS_RUNNING then
        WMLogger:warning("Workflow %s is not running", activeData.workflow.id)
        return false
    end

    -- Mark as paused FIRST to stop tracking in update loop
    activeData.status = WorkflowManager.STATUS_PAUSED

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
    self:pauseCurrentStep(activeData)

    WMLogger:info("Paused workflow: %s at step %d (tracking interrupted)", activeData.workflow.name, activeData.currentStep)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_PAUSED, {
        workflowId = activeData.workflow.id,
        currentStep = activeData.currentStep
    })

    return true
end

---Resume a paused workflow on a vehicle
---Restores tracking state and resumes AD/CP operation
---@param vehicle table Vehicle whose workflow to resume
---@return boolean success True if resumed successfully
function WMExecutor:resumeWorkflow(vehicle)
    if vehicle == nil then
        return false
    end

    local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
    if activeData == nil then
        WMLogger:warning("No active workflow for vehicle")
        return false
    end

    if activeData.status ~= WorkflowManager.STATUS_PAUSED then
        WMLogger:warning("Workflow %s is not paused", activeData.workflow.id)
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

    activeData.status = WorkflowManager.STATUS_RUNNING

    -- Resume current step (AD/CP)
    self:resumeCurrentStep(activeData)

    WMLogger:info("Resumed workflow: %s at step %d (tracking restored)", activeData.workflow.name, activeData.currentStep)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_RESUMED, {
        workflowId = activeData.workflow.id,
        vehicle = vehicle,
        currentStep = activeData.currentStep
    })

    return true
end

---Execute the current step of a workflow
---@param activeData table Per-vehicle execution state
function WMExecutor:executeCurrentStep(activeData)
    local workflow = activeData.workflow
    local step = workflow.steps[activeData.currentStep]
    if step == nil then
        WMLogger:error("Step %d not found in workflow %s", activeData.currentStep, workflow.id)
        return
    end

    WMLogger:info("Executing step %d/%d: %s -> %s",
        activeData.currentStep, #workflow.steps, step.type, step.target)

    -- Fire step started event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_STARTED, {
        workflowId = workflow.id,
        stepNumber = activeData.currentStep,
        stepType = step.type,
        target = step.target
    })

    local vehicle = activeData.vehicle

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

        self:startAutoDriveStep(activeData, vehicle, step)

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

        self:startCourseplayStep(activeData, vehicle, step)
    else
        self:handleStepError(activeData, "Unknown step type: " .. tostring(step.type))
    end
end

---Stop the current step
---Handles both running and paused states (unfreezes CP / unpauses AD before stopping)
---Also handles cyclic handoffs: when CP step has handed off to AD, stops AD too
---@param activeData table Per-vehicle execution state
function WMExecutor:stopCurrentStep(activeData)
    local workflow = activeData.workflow
    local step = workflow.steps[activeData.currentStep]
    if step == nil then
        return
    end

    local vehicle = activeData.vehicle

    if vehicle == nil then
        WMLogger:warning("Cannot stop step - no vehicle in activeData")
        return
    end

    -- Always clear the AD->CP handoff flag to prevent AD from restarting CP during shutdown
    pcall(function() ADIntegration:clearCPHandoff(vehicle) end)

    if step.type == WorkflowManager.STEP_AUTODRIVE then
        -- Resume AD first if it was paused (HoldDriving), then stop
        if activeData.status == WorkflowManager.STATUS_PAUSED then
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
        if activeData.status == WorkflowManager.STATUS_PAUSED then
            pcall(function() CPIntegration:resumeCourse(vehicle) end)
        end
        pcall(function() CPIntegration:stopCourse(vehicle) end)
    end
end

---Start an AutoDrive step (extracted for reuse by deferred start)
---@param activeData table Per-vehicle execution state
---@param vehicle table Vehicle
---@param step table Step data
function WMExecutor:startAutoDriveStep(activeData, vehicle, step)
    local workflow = activeData.workflow
    -- Check if next step is Courseplay - if so, configure AD to hand off to CP
    local nextStep = workflow.steps[activeData.currentStep + 1]
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
        self:handleStepError(activeData, "Failed to start AutoDrive route: " .. (step.target or "nil"))
    end
end

---Start a Courseplay step (extracted for reuse by deferred start)
---@param activeData table Per-vehicle execution state
---@param vehicle table Vehicle
---@param step table Step data
function WMExecutor:startCourseplayStep(activeData, vehicle, step)
    -- Check if vehicle has the correct course loaded
    local currentCourse = CPIntegration:getCurrentCourseName(vehicle)
    local hasCourse = CPIntegration:hasCourse(vehicle)
    local needsLoad = not hasCourse or currentCourse ~= step.target

    if needsLoad then
        WMLogger:info("Loading course for step: %s (current: %s)", step.target or "nil", currentCourse or "none")
        local loadSuccess = CPIntegration:loadCourse(vehicle, step.target)
        if not loadSuccess then
            self:handleStepError(activeData, "Failed to load Courseplay course: " .. (step.target or "nil"))
            return
        end
    else
        WMLogger:debug("Correct course already loaded: %s", currentCourse or "unknown")
    end

    -- Verify course is now loaded
    if not CPIntegration:hasCourse(vehicle) then
        self:handleStepError(activeData, "Vehicle has no Courseplay course loaded for step: " .. (step.target or "nil"))
        return
    end

    -- Determine start position based on action
    local startAtNearest = activeData.resuming or false
    local startAtFirst = (step.action == "first" or step.action == "start")
    local success = CPIntegration:startFieldWork(vehicle, startAtFirst, startAtNearest)
    activeData.resuming = nil

    if success then
        activeData.waitingForCompletion = true
        activeData.currentStepType = WorkflowManager.STEP_COURSEPLAY
        activeData.cpWasRunning = true  -- Track that we started CP
        activeData.pendingCPStart = nil
        activeData.pendingCPStartRetries = nil
        WMLogger:info("Courseplay step started successfully, polling for completion")
    else
        self:handleStepError(activeData, "Failed to start Courseplay field work")
    end
end

---Pause the current step
---@param activeData table Per-vehicle execution state
function WMExecutor:pauseCurrentStep(activeData)
    local workflow = activeData.workflow
    local step = workflow.steps[activeData.currentStep]
    if step == nil then
        return
    end

    local vehicle = activeData.vehicle

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
---@param activeData table Per-vehicle execution state
function WMExecutor:resumeCurrentStep(activeData)
    local workflow = activeData.workflow
    local step = workflow.steps[activeData.currentStep]
    if step == nil then
        return
    end

    local vehicle = activeData.vehicle

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
---@param activeData table Per-vehicle execution state
function WMExecutor:onStepCompleted(activeData)
    local workflow = activeData.workflow
    local completedStepNum = activeData.currentStep

    WMLogger:info("Step %d completed for workflow %s", completedStepNum, workflow.name)

    -- Fire step completed event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_COMPLETED, {
        workflowId = workflow.id,
        stepNumber = completedStepNum
    })

    -- Check if AD handed off to CP (AD already started CP for us)
    local adHandedOffToCP = activeData.willHandoffToCP

    -- Move to next step
    activeData.currentStep = activeData.currentStep + 1

    -- Check if workflow is complete
    if activeData.currentStep > #workflow.steps then
        self:onWorkflowCompleted(activeData)
    elseif adHandedOffToCP then
        -- AD already started Courseplay - just set up monitoring, don't call executeCurrentStep
        local nextStep = workflow.steps[activeData.currentStep]
        WMLogger:info("AD handed off to CP - skipping CP start, monitoring step %d: %s",
            activeData.currentStep, nextStep.target or "unknown")

        -- Fire step started event for the CP step
        WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_STARTED, {
            workflowId = workflow.id,
            stepNumber = activeData.currentStep,
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
        self:executeCurrentStep(activeData)
    end
end

---Handle workflow completion
---@param activeData table Per-vehicle execution state
function WMExecutor:onWorkflowCompleted(activeData)
    local workflow = activeData.workflow
    local vehicle = activeData.vehicle
    WMLogger:info("Workflow completed: %s", workflow.name)

    -- Remove from active workflows
    vehicle.spec_workflowManagerSpec.wmExecution = nil
    self.activeVehicles[vehicle] = nil

    -- Fire completion event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_COMPLETED, {
        workflowId = workflow.id,
        workflowName = workflow.name
    })
end

---Handle step error
---@param activeData table Per-vehicle execution state
---@param errorMessage string Error message
function WMExecutor:handleStepError(activeData, errorMessage)
    local workflow = activeData.workflow
    WMLogger:error("Step error in workflow %s: %s", workflow.name, errorMessage)

    activeData.status = WorkflowManager.STATUS_ERROR

    -- Fire error event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_ERROR, {
        workflowId = workflow.id,
        stepNumber = activeData.currentStep,
        error = errorMessage
    })

    -- Stop the workflow
    self:stopWorkflow(activeData.vehicle)
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
    for vehicle, _ in pairs(self.activeVehicles) do
        local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
        if activeData ~= nil then
            local workflow = activeData.workflow

            -- Auto-resume check: poll every tick for the first 10 seconds after restore.
            -- If AD auto-started after load we catch it as soon as it begins running.
            if activeData.status == WorkflowManager.STATUS_PAUSED and activeData.autoResumeUntil ~= nil then
                local step = workflow.steps[activeData.currentStep]
                local adRunning = step and ADIntegration:isRunning(vehicle)
                local cpRunning = step and CPIntegration:isRunning(vehicle)

                if adRunning or cpRunning then
                    activeData.autoResumeUntil = nil  -- found - stop polling

                    WMLogger:info("Auto-resuming workflow '%s' at step %d - %s running after load",
                        workflow.name, activeData.currentStep,
                        adRunning and "AutoDrive" or "Courseplay")

                    activeData.status = WorkflowManager.STATUS_RUNNING
                    activeData.waitingForCompletion = true
                    activeData.currentStepType = step.type
                    if cpRunning then
                        activeData.cpWasRunning = true
                    end

                    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_RESUMED, {
                        workflowId = workflow.id,
                        vehicle = vehicle,
                        currentStep = activeData.currentStep
                    })
                elseif g_currentMission.time >= activeData.autoResumeUntil then
                    activeData.autoResumeUntil = nil  -- window expired - stay paused
                    WMLogger:info("Auto-resume window expired for '%s', staying paused", workflow.name)
                end
            end

            if activeData.status == WorkflowManager.STATUS_RUNNING and activeData.waitingForCompletion then
            -- Handle deferred CP start: AD was just stopped and CP needs to start
            if activeData.pendingCPStart then
                local adRunning = ADIntegration:isRunning(vehicle)
                if not adRunning then
                    -- AD has fully stopped, now start CP
                    WMLogger:info("AutoDrive fully stopped - starting deferred Courseplay step")
                    activeData.pendingCPStart = nil
                    activeData.pendingCPStartRetries = nil
                    activeData.waitingForCompletion = false
                    local step = workflow.steps[activeData.currentStep]
                    if step then
                        self:startCourseplayStep(activeData, vehicle, step)
                    end
                else
                    activeData.pendingCPStartRetries = (activeData.pendingCPStartRetries or 0) + 1
                    -- Give up after 20 checks (10 seconds) to avoid hanging
                    if activeData.pendingCPStartRetries > 20 then
                        WMLogger:warning("AutoDrive did not stop after 10s - forcing CP start")
                        activeData.pendingCPStart = nil
                        activeData.pendingCPStartRetries = nil
                        activeData.waitingForCompletion = false
                        local step = workflow.steps[activeData.currentStep]
                        if step then
                            self:startCourseplayStep(activeData, vehicle, step)
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
                    local step = workflow.steps[activeData.currentStep]
                    if step then
                        self:startAutoDriveStep(activeData, vehicle, step)
                    end
                elseif activeData.pendingADStartRetries > 20 then
                    -- Give up after 20 checks (10 seconds) to avoid hanging
                    WMLogger:warning("AutoDrive did not stop after 10s - forcing AD start")
                    activeData.pendingADStart = nil
                    activeData.pendingADStartRetries = nil
                    activeData.justStoppedAD = nil
                    activeData.waitingForCompletion = false
                    local step = workflow.steps[activeData.currentStep]
                    if step then
                        self:startAutoDriveStep(activeData, vehicle, step)
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
                    self:onStepCompleted(activeData)
                end
            end  -- if pendingCPStart/pendingADStart/else
            end  -- if STATUS_RUNNING and waitingForCompletion
        end  -- if activeData ~= nil
    end
end

---Get the count of active workflows
---@return number count Number of active workflows
function WMExecutor:getActiveWorkflowCount()
    local count = 0
    for _ in pairs(self.activeVehicles) do
        count = count + 1
    end
    return count
end

---Check if a workflow (by ID) is active on any vehicle
---@param workflowId string Workflow ID
---@return boolean isActive True if workflow is active on any vehicle
function WMExecutor:isWorkflowActive(workflowId)
    for vehicle, _ in pairs(self.activeVehicles) do
        local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
        if activeData and activeData.workflow.id == workflowId then
            return true
        end
    end
    return false
end

---Get the active execution data for a specific vehicle
---@param vehicle table Vehicle to look up
---@return table|nil activeData The execution state, or nil if not active
function WMExecutor:getActiveDataForVehicle(vehicle)
    if vehicle == nil or vehicle.spec_workflowManagerSpec == nil then return nil end
    return vehicle.spec_workflowManagerSpec.wmExecution
end

---Get the workflow definition currently running on a vehicle
---@param vehicle table Vehicle to look up
---@return table|nil workflow The workflow definition, or nil if not active
function WMExecutor:getWorkflowForVehicle(vehicle)
    local d = self:getActiveDataForVehicle(vehicle)
    return d and d.workflow or nil
end

---Check if a specific vehicle is currently running a workflow
---@param vehicle table Vehicle to check
---@return boolean isActive True if vehicle is running a workflow
function WMExecutor:isWorkflowActiveOnVehicle(vehicle)
    if vehicle == nil or vehicle.spec_workflowManagerSpec == nil then return false end
    return vehicle.spec_workflowManagerSpec.wmExecution ~= nil
end

---Reset a workflow on a vehicle (stops AD/CP and removes from active list)
---Equivalent to stopWorkflow but named separately for semantic clarity
---@param vehicle table Vehicle whose workflow to reset
---@return boolean success True if reset successfully
function WMExecutor:resetWorkflow(vehicle)
    if vehicle == nil then
        WMLogger:error("Cannot reset: nil vehicle")
        return false
    end

    local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
    if activeData == nil then
        WMLogger:warning("No active workflow for vehicle to reset")
        return false
    end

    -- Stop current step (stops AD/CP)
    self:stopCurrentStep(activeData)

    -- Remove from active
    vehicle.spec_workflowManagerSpec.wmExecution = nil
    self.activeVehicles[vehicle] = nil

    WMLogger:info("Reset workflow: %s", activeData.workflow.name)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_STOPPED, {
        workflowId = activeData.workflow.id,
        reset = true
    })

    return true
end

---Go to the previous step in a workflow
---Stops current step and moves to the previous one
---@param vehicle table Vehicle whose workflow to navigate
---@return boolean success True if moved to previous step
function WMExecutor:goToPreviousStep(vehicle)
    if vehicle == nil then
        return false
    end

    local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
    if activeData == nil then
        WMLogger:warning("No active workflow for vehicle")
        return false
    end

    if activeData.currentStep <= 1 then
        WMLogger:warning("Already at first step of workflow %s", activeData.workflow.id)
        return false
    end

    -- Remember if workflow was paused so we can resume after step change
    local wasPaused = activeData.status == WorkflowManager.STATUS_PAUSED

    -- Stop the current step (handles paused state internally)
    self:stopCurrentStep(activeData)

    -- Move to previous step
    activeData.currentStep = activeData.currentStep - 1

    WMLogger:info("Moving to previous step %d/%d for workflow %s",
        activeData.currentStep, #activeData.workflow.steps, activeData.workflow.name)

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
        activeData.status = WorkflowManager.STATUS_RUNNING
    end

    -- If workflow is running, start the new step
    if activeData.status == WorkflowManager.STATUS_RUNNING then
        self:executeCurrentStep(activeData)
    end

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_CHANGED, {
        workflowId = activeData.workflow.id,
        stepNumber = activeData.currentStep,
        direction = "previous"
    })

    return true
end

---Go to the next step in a workflow
---Stops current step and moves to the next one
---@param vehicle table Vehicle whose workflow to navigate
---@return boolean success True if moved to next step
function WMExecutor:goToNextStep(vehicle)
    if vehicle == nil then
        return false
    end

    local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
    if activeData == nil then
        WMLogger:warning("No active workflow for vehicle")
        return false
    end

    if activeData.currentStep >= #activeData.workflow.steps then
        WMLogger:warning("Already at last step of workflow %s", activeData.workflow.id)
        return false
    end

    -- Remember if workflow was paused so we can resume after step change
    local wasPaused = activeData.status == WorkflowManager.STATUS_PAUSED

    -- Stop the current step (handles paused state internally)
    self:stopCurrentStep(activeData)

    -- Move to next step
    activeData.currentStep = activeData.currentStep + 1

    WMLogger:info("Moving to next step %d/%d for workflow %s",
        activeData.currentStep, #activeData.workflow.steps, activeData.workflow.name)

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
        activeData.status = WorkflowManager.STATUS_RUNNING
    end

    -- If workflow is running, start the new step
    if activeData.status == WorkflowManager.STATUS_RUNNING then
        self:executeCurrentStep(activeData)
    end

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_CHANGED, {
        workflowId = activeData.workflow.id,
        stepNumber = activeData.currentStep,
        direction = "next"
    })

    return true
end
