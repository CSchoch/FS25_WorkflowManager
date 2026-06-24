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

-- Global mission-level updateable that polls waiting vehicles (WAITING_FOR_LEADER /
-- WAITING_FOR_MAIN) independently of the vehicle sleep state. Created on demand;
-- torn down when no vehicles are in a wait state.
WMExecutor.globalWaitPoller = nil

---Initialize the executor
function WMExecutor:init()
    self.activeVehicles = {}
    self.pendingADCallbacks = {}
    self.updateTimer = 0
    self.globalWaitPoller = nil
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
---@param isMain boolean|nil true = main role, false = support role (default true)
---@param leaderVehicle table|nil Vehicle to follow (follower waits at each step until leader advances)
---@return boolean success True if started successfully
function WMExecutor:startWorkflow(workflow, vehicle, isMain, leaderVehicle)
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

    local isMainVehicle = (isMain ~= false)

    -- Create per-vehicle execution state on the spec (does NOT mutate workflow definition)
    vehicle.spec_workflowManagerSpec.wmExecution = {
        workflow = workflow,
        vehicle = vehicle,
        status = WorkflowManager.STATUS_RUNNING,
        currentStep = 1,
        startTime = g_currentMission.time,
        waitingForCompletion = false,
        isMainVehicle = isMainVehicle,
        currentSupportStep = not isMainVehicle and 1 or nil,
        leaderVehicle = leaderVehicle,
        linkedLeaderExecution = leaderVehicle and leaderVehicle.spec_workflowManagerSpec and leaderVehicle.spec_workflowManagerSpec.wmExecution,
    }
    self.activeVehicles[vehicle] = true

    local activeData = vehicle.spec_workflowManagerSpec.wmExecution

    -- Late-start sync: if support vehicle, find what main step is current and log it.
    -- currentSupportStep stays at 1 — support always starts from sub-step 1 of the
    -- current main step, regardless of how far along the main vehicle is.
    if not isMainVehicle then
        local mainActiveData = self:getMainActiveDataForWorkflow(workflow.id)
        if mainActiveData and mainActiveData.status == WorkflowManager.STATUS_RUNNING then
            WMLogger:info("Late-start sync: support vehicle joining '%s' at main step %d",
                workflow.name, mainActiveData.currentStep)
        end
    end

    WMLogger:info("Starting workflow: %s with vehicle: %s (Step %d/%d)",
        workflow.name, vehicleName, activeData.currentStep, #workflow.steps)
    if leaderVehicle then
        local leaderName = leaderVehicle.getName and leaderVehicle:getName() or "?"
        WMLogger:debug("Leader sync: following '%s' (execLinked=%s)",
            leaderName, tostring(activeData.linkedLeaderExecution ~= nil))
        -- Build ordinal-based sync maps for index-based step synchronization
        self:buildSyncMaps(activeData)
    end

    -- Apply per-workflow AD settings to the vehicle before the first step runs
    ADIntegration:applyWorkflowSettings(vehicle, workflow.adSettings)

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

    -- Broadcast cleared state (isActive=false) to all clients
    WorkflowManager:broadcastState(vehicle)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_WORKFLOW_STOPPED, {
        workflowId = workflow.id
    })

    return true
end

---Build the leader-sync lookup tables on a follower's activeData.
--- syncSourceOrdinals  maps each "wait_for_leader" follower step index to its
---   position in the wait sequence (nil for all other steps).
--- syncTargets         is an ordered list of the leader step indices that are
---   "unlock_follower" markers.  Follower wait ordinal N is released once the
---   leader has reached (is on or past) syncTargets[N].
---Called at workflow start and whenever the linked leader execution is first snapped.
---@param activeData table Follower's active execution state
function WMExecutor:buildSyncMaps(activeData)
    -- Wait-marker ordinals: scan follower's own workflow (always available)
    local syncSourceOrdinals = {}
    local ordinal = 0
    for i, s in ipairs(activeData.workflow.steps) do
        if s.type == WorkflowManager.STEP_WAIT_FOR_LEADER then
            ordinal = ordinal + 1
            syncSourceOrdinals[i] = ordinal
        end
    end
    activeData.syncSourceOrdinals = syncSourceOrdinals

    -- Unlock-marker indices: scan leader's workflow (may be nil if not yet linked)
    local syncTargets = {}
    local leaderWorkflow = activeData.linkedLeaderExecution
                           and activeData.linkedLeaderExecution.workflow
    if leaderWorkflow then
        for i, s in ipairs(leaderWorkflow.steps) do
            if s.type == WorkflowManager.STEP_UNLOCK_FOLLOWER then
                table.insert(syncTargets, i)
            end
        end
    end
    activeData.syncTargets = syncTargets
end

---Returns true if the follower may proceed past its current wait_for_leader step.
---Encapsulates: leader reference snapping, leader-gone detection (frees follower),
---and the ordinal-based sync check against the leader's unlock markers.
---@param activeData table Follower's active execution state
---@return boolean satisfied
function WMExecutor:isLeaderSyncSatisfied(activeData)
    if activeData.pendingLeaderXmlIndex ~= nil or activeData.pendingLeaderWorkflowId ~= nil then
        return false  -- leader reference not yet resolved; block until poller resolves it
    end
    if activeData.leaderVehicle == nil then return true end

    local leaderSpec = activeData.leaderVehicle.spec_workflowManagerSpec
    local leaderExec = leaderSpec and leaderSpec.wmExecution

    -- Snap reference + (re)build sync maps if needed (covers save/load restore ordering)
    if leaderExec ~= nil and (activeData.linkedLeaderExecution == nil or activeData.syncTargets == nil) then
        activeData.linkedLeaderExecution = leaderExec
        local leaderName = activeData.leaderVehicle.getName and activeData.leaderVehicle:getName() or "?"
        WMLogger:debug("Leader sync: snapped execution reference for '%s'", leaderName)
        self:buildSyncMaps(activeData)
    end

    -- Leader finished, stopped, or restarted — free the follower
    if leaderExec == nil or (activeData.linkedLeaderExecution ~= nil and leaderExec ~= activeData.linkedLeaderExecution) then
        local leaderName = activeData.leaderVehicle.getName and activeData.leaderVehicle:getName() or "?"
        WMLogger:info("Leader '%s' %s — follower continuing freely",
            leaderName, leaderExec == nil and "finished/stopped" or "restarted with new execution")
        activeData.leaderVehicle = nil
        activeData.linkedLeaderExecution = nil
        return true
    end

    local ordinal = activeData.syncSourceOrdinals
                    and activeData.syncSourceOrdinals[activeData.currentStep]
    if ordinal == nil then return true end  -- current step is not a paired wait marker

    local required = activeData.syncTargets and activeData.syncTargets[ordinal]
    if required == nil then
        -- More wait markers than unlock markers: wait until the leader finishes
        local leaderWF = activeData.linkedLeaderExecution and activeData.linkedLeaderExecution.workflow
        required = leaderWF and (#leaderWF.steps + 1) or 1
    end

    if leaderExec.currentStep < required then
        WMLogger:debug("Waiting for leader: need leader at step %d (at %d), follower wait step %d",
            required, leaderExec.currentStep, activeData.currentStep)
        return false
    end
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

    local isRunningOrWaiting = activeData.status == WorkflowManager.STATUS_RUNNING
                            or activeData.status == WorkflowManager.STATUS_WAITING_FOR_MAIN
                            or activeData.status == WorkflowManager.STATUS_WAITING_FOR_LEADER
    if not isRunningOrWaiting then
        WMLogger:warning("Workflow %s is not running", activeData.workflow.id)
        return false
    end

    local wasWaitingForMain   = activeData.status == WorkflowManager.STATUS_WAITING_FOR_MAIN
    local wasWaitingForLeader = activeData.status == WorkflowManager.STATUS_WAITING_FOR_LEADER

    -- Mark as paused FIRST to stop tracking in update loop
    activeData.status = WorkflowManager.STATUS_PAUSED
    activeData.pendingAutoStep = nil  -- cancel any deferred step start

    -- Store tracking state so we can restore it on resume
    activeData.pausedTrackingState = {
        waitingForCompletion = activeData.waitingForCompletion,
        currentStepType = activeData.currentStepType,
        cpHandedOffToAD = activeData.cpHandedOffToAD,
        cpWasRunning = activeData.cpWasRunning,
        wasWaitingForMain   = wasWaitingForMain,
        wasWaitingForLeader = wasWaitingForLeader,
    }

    -- Stop waiting for completion while paused
    -- This ensures we stay in the current step even if AD/CP finishes
    activeData.waitingForCompletion = false

    -- Release wait poller if pausing from an idle wait state (no real AD/CP to pause)
    if wasWaitingForMain or wasWaitingForLeader then
        self:stopWaitPollerIfIdle()
    else
        self:pauseCurrentStep(activeData)
    end

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

    -- Step was updated while paused (e.g., main advanced to a new step while support was paused).
    -- resetStepTrackingState already cleared pausedTrackingState, so we must execute fresh.
    if activeData.pendingExecuteOnResume then
        activeData.pendingExecuteOnResume = nil
        activeData.status = WorkflowManager.STATUS_RUNNING
        WMLogger:info("Resumed workflow: %s — executing staged sub-step", activeData.workflow.name)
        self:executeCurrentStep(activeData)
    -- Restore tracking state from before pause
    elseif activeData.pausedTrackingState then
        local pts = activeData.pausedTrackingState
        activeData.waitingForCompletion = pts.waitingForCompletion
        activeData.currentStepType      = pts.currentStepType
        activeData.cpHandedOffToAD      = pts.cpHandedOffToAD
        activeData.cpWasRunning         = pts.cpWasRunning
        local wasWaitingForLeader       = pts.wasWaitingForLeader
        activeData.pausedTrackingState  = nil

        -- Follower was waiting for leader sync — restore that state and restart poller.
        if wasWaitingForLeader then
            activeData.status = WorkflowManager.STATUS_WAITING_FOR_LEADER
            self:ensureWaitPollerActive()
        -- Support vehicle was idling (STATUS_WAITING_FOR_MAIN) before pause — restore that
        -- state and restart the poller. No real AD/CP route to unpause.
        elseif activeData.isMainVehicle == false and activeData.waitingForMainStep then
            activeData.status = WorkflowManager.STATUS_WAITING_FOR_MAIN
            self:ensureWaitPollerActive()
        else
            activeData.status = WorkflowManager.STATUS_RUNNING
            self:resumeCurrentStep(activeData)
        end

        WMLogger:info("Resumed workflow: %s at step %d (tracking restored)", activeData.workflow.name, activeData.currentStep)
    else
        -- No pausedTrackingState: workflow was restored from a saved game and was never
        -- paused programmatically in this session. AD/CP has auto-started on its own, so
        -- we must NOT restart it – just attach tracking state so the completion loop can
        -- detect when the current step finishes and advance to the next one.
        local step = self:getCurrentStep(activeData)

        activeData.status = WorkflowManager.STATUS_RUNNING
        activeData.autoResumeUntil = nil  -- cancel auto-resume window; we are resuming now
        activeData.waitingForCompletion = true
        activeData.currentStepType = step and step.type
        if step and step.type == WorkflowManager.STEP_COURSEPLAY and CPIntegration:isRunning(vehicle) then
            activeData.cpWasRunning = true
        end

        WMLogger:info("Resumed workflow: %s at step %d (monitoring existing AD/CP, type=%s)",
            activeData.workflow.name, activeData.currentStep, tostring(activeData.currentStepType))
    end

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
    local vehicle = activeData.vehicle

    -- Safety net: if the player resumes before the first wait-poller tick (or
    -- goToNext/PreviousStep is called early after load), pendingLeaderXmlIndex may still
    -- be set.  tryResolvePendingLeader is the same loop runWaitPoll uses every 500 ms.
    self:tryResolvePendingLeader(activeData)

    -- ===== Support vehicle path =====
    if activeData.isMainVehicle == false then
        local mainActiveData = self:getMainActiveDataForWorkflow(workflow.id)
        if mainActiveData == nil then
            WMLogger:info("Support vehicle: main not running, stopping support")
            self:stopWorkflow(vehicle)
            return
        end

        local mainStep = workflow.steps[mainActiveData.currentStep]
        local supportSteps = mainStep and mainStep.support or {}

        if #supportSteps == 0 then
            WMLogger:info("Support vehicle: main step %d has no support sub-steps, idling",
                mainActiveData.currentStep)
            activeData.status = WorkflowManager.STATUS_WAITING_FOR_MAIN
            activeData.waitingForMainStep = true
            activeData.waitingForMainStepIndex = mainActiveData.currentStep
            self:ensureWaitPollerActive()
            WorkflowManager:broadcastState(activeData.vehicle)
            return
        end

        -- Clamp index in case it drifted
        if activeData.currentSupportStep > #supportSteps then
            activeData.currentSupportStep = 1
        end

        local supportSubStep = supportSteps[activeData.currentSupportStep]
        if supportSubStep == nil then
            WMLogger:error("Support vehicle: no sub-step at index %d", activeData.currentSupportStep)
            return
        end

        activeData.status = WorkflowManager.STATUS_RUNNING

        WMLogger:info("Executing support sub-step %d/%d: %s -> %s (main step %d)",
            activeData.currentSupportStep, #supportSteps,
            supportSubStep.type, supportSubStep.target or "nil", mainActiveData.currentStep)

        WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_STARTED, {
            workflowId = workflow.id,
            stepNumber = activeData.currentSupportStep,
            stepType = supportSubStep.type,
            target = supportSubStep.target
        })

        if supportSubStep.type == WorkflowManager.STEP_AUTODRIVE then
            if ADIntegration:isRunning(vehicle) or activeData.justStoppedAD then
                activeData.waitingForCompletion = true
                activeData.currentStepType = WorkflowManager.STEP_AUTODRIVE
                activeData.pendingADStart = true
                activeData.pendingADStartRetries = 0
                return
            end
            self:startAutoDriveStep(activeData, vehicle, supportSubStep)
        elseif supportSubStep.type == WorkflowManager.STEP_COURSEPLAY then
            local comingFromCP = (activeData.currentStepType == WorkflowManager.STEP_COURSEPLAY)
            if ADIntegration:isRunning(vehicle) or comingFromCP then
                activeData.waitingForCompletion = true
                activeData.currentStepType = WorkflowManager.STEP_COURSEPLAY
                activeData.pendingCPStart = true
                activeData.pendingCPStartRetries = 0
                activeData.cpToCpTransition = comingFromCP
                return
            end
            self:startCourseplayStep(activeData, vehicle, supportSubStep)
        else
            self:handleStepError(activeData, "Unknown support sub-step type: " .. tostring(supportSubStep.type))
        end
        return
    end

    -- ===== Main vehicle path =====
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

    -- Execute based on step type
    if step.type == WorkflowManager.STEP_AUTODRIVE then
        -- AutoDrive: Use startRoute which internally uses StartDriving with callback
        -- Pass all step parameters including unloadTarget and fillTypes
        WMLogger:info("Starting AutoDrive step - vehicle: %s, target: %s, action: %s, unloadTarget: %s, fillTypes: %s",
            vehicle and (vehicle.getName and vehicle:getName() or "unknown") or "nil",
            step.target or "nil",
            step.action or "nil",
            step.unloadTarget or "nil",
            step.fillTypes and table.concat(step.fillTypes, ",") or "nil")

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

        -- Defer CP start if AD is still active, or if we just came from a CP step (CP->CP).
        -- The CP->CP deferral gives CP's previous job time to fully clean up (reset tasks,
        -- unregister listeners). Without it, CpAITask:reset() can nil out self.vehicle
        -- while the new task's update loop is still running, causing getCpSettings errors.
        local comingFromCP = (activeData.currentStepType == WorkflowManager.STEP_COURSEPLAY)
        if ADIntegration:isRunning(vehicle) or comingFromCP then
            if comingFromCP then
                WMLogger:info("CP->CP transition: deferring start to allow Courseplay cleanup")
            else
                WMLogger:info("AutoDrive still active after stop - deferring CP start")
            end
            activeData.waitingForCompletion = true
            activeData.currentStepType = WorkflowManager.STEP_COURSEPLAY
            activeData.pendingCPStart = true
            activeData.pendingCPStartRetries = 0
            activeData.cpToCpTransition = comingFromCP
            return
        end

        self:startCourseplayStep(activeData, vehicle, step)

    elseif step.type == WorkflowManager.STEP_UNLOCK_FOLLOWER then
        -- Leader-side milestone: pure pass-through for the vehicle running it.
        WMLogger:info("Unlock Follower marker reached — passing through")
        self:onStepCompleted(activeData)

    elseif step.type == WorkflowManager.STEP_WAIT_FOR_LEADER then
        -- Follower-side gate: block until the matching unlock marker is reached.
        if self:isLeaderSyncSatisfied(activeData) then
            WMLogger:info("Wait for Leader marker satisfied — passing through")
            self:onStepCompleted(activeData)
        else
            activeData.status = WorkflowManager.STATUS_WAITING_FOR_LEADER
            self:ensureWaitPollerActive()
            WorkflowManager:broadcastState(activeData.vehicle)
        end
    else
        self:handleStepError(activeData, "Unknown step type: " .. tostring(step.type))
    end
end

---Stop the current step
---Handles both running and paused states (unfreezes CP / unpauses AD before stopping)
---Also handles cyclic handoffs: when CP step has handed off to AD, stops AD too
---@param activeData table Per-vehicle execution state
function WMExecutor:stopCurrentStep(activeData)
    local step = self:getCurrentStep(activeData)
    if step == nil then
        -- Fallback: use cached step type when step lookup fails
        -- (e.g. support vehicle whose main has already been cleaned up)
        if activeData.currentStepType == nil then return end
        step = { type = activeData.currentStepType }
    end

    local vehicle = activeData.vehicle

    if vehicle == nil then
        WMLogger:warning("Cannot stop step - no vehicle in activeData")
        return
    end

    -- Wait states: no real AD/CP route was running. The global poller self-cleans next tick.
    if activeData.status == WorkflowManager.STATUS_WAITING_FOR_LEADER
    or activeData.status == WorkflowManager.STATUS_WAITING_FOR_MAIN then
        return
    end

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

---Resolve a pending leader reference (by xmlIndex or legacy workflowId) if the leader
---vehicle is now available in activeVehicles.  Called from executeCurrentStep (early-resume
---safety net) and runWaitPoll (normal deferred path after save/load).
---@param activeData table Per-vehicle execution state
function WMExecutor:tryResolvePendingLeader(activeData)
    if activeData.leaderVehicle ~= nil then return end
    if activeData.pendingLeaderWorkflowId == nil and activeData.pendingLeaderXmlIndex == nil then return end
    for candidate, _ in pairs(self.activeVehicles) do
        if candidate ~= activeData.vehicle then
            local vSpec = candidate.spec_workflowManagerSpec
            local vExec = vSpec and vSpec.wmExecution
            local matched = (activeData.pendingLeaderWorkflowId ~= nil
                and vExec and vExec.workflow and vExec.workflow.id == activeData.pendingLeaderWorkflowId)
                or (activeData.pendingLeaderXmlIndex ~= nil
                and vSpec and vSpec.wmXmlIndex == activeData.pendingLeaderXmlIndex)
            if matched then
                activeData.leaderVehicle           = candidate
                activeData.linkedLeaderExecution   = vExec
                activeData.pendingLeaderWorkflowId = nil
                activeData.pendingLeaderXmlIndex   = nil
                WMLogger:info("Resolved pending leader '%s' for follower at step %d",
                    candidate.getName and candidate:getName() or "?", activeData.currentStep)
                break
            end
        end
    end
end

---Ensure the global wait-poller is registered with g_currentMission. The poller iterates
---all active vehicles every ~500 ms and calls runWaitPoll for those in a waiting status.
---This keeps polling alive even when FS25 puts distant vehicles to sleep.
function WMExecutor:ensureWaitPollerActive()
    if self.globalWaitPoller then return end
    local executor = self
    local poller = { throttle = 0, cycles = 0 }
    function poller:update(dt)
        if g_server == nil then return end
        self.throttle = self.throttle - dt
        if self.throttle > 0 then return end
        self.throttle = 500
        self.cycles = self.cycles + 1
        local vehicles = {}
        for vehicle, _ in pairs(executor.activeVehicles) do
            vehicles[#vehicles + 1] = vehicle
        end
        for _, vehicle in ipairs(vehicles) do
            local spec = vehicle.spec_workflowManagerSpec
            local ad = spec and spec.wmExecution
            if ad then executor:runWaitPoll(ad, vehicle) end
        end
        -- Self-cleanup: remove poller once no vehicles remain in a wait state.
        -- Called at tick-end so status changes from runWaitPoll are already applied.
        executor:stopWaitPollerIfIdle()
    end
    self.globalWaitPoller = poller
    g_currentMission:addUpdateable(poller)
    WMLogger:debug("Global wait poller started")
end

---Remove the global wait poller if no vehicles remain in a wait status.
function WMExecutor:stopWaitPollerIfIdle()
    if not self.globalWaitPoller then return end
    for vehicle, _ in pairs(self.activeVehicles) do
        local spec = vehicle.spec_workflowManagerSpec
        local ad = spec and spec.wmExecution
        if ad and (ad.status == WorkflowManager.STATUS_WAITING_FOR_LEADER
                or ad.status == WorkflowManager.STATUS_WAITING_FOR_MAIN
                or ad.pendingLeaderXmlIndex ~= nil
                or ad.pendingLeaderWorkflowId ~= nil) then
            return
        end
    end
    g_currentMission:removeUpdateable(self.globalWaitPoller)
    self.globalWaitPoller = nil
    WMLogger:debug("Global wait poller stopped (no vehicles waiting)")
end

---Poll logic for a single vehicle in a wait state. Called by the global poller every ~500 ms.
---Covers: pending leader resolution, WAITING_FOR_LEADER unblock, WAITING_FOR_MAIN unblock.
---@param activeData table Per-vehicle execution state
---@param vehicle table Vehicle
function WMExecutor:runWaitPoll(activeData, vehicle)
    local workflow = activeData.workflow

    -- Retry pending leader resolution (leader may load after follower during map load)
    self:tryResolvePendingLeader(activeData)

    -- Leader-follower poll: check if leader has advanced past our current step
    if activeData.status == WorkflowManager.STATUS_WAITING_FOR_LEADER then
        -- isLeaderSyncSatisfied handles reference snapping, leader-gone detection
        -- (frees the follower), and the ordinal-based unlock check.
        if self:isLeaderSyncSatisfied(activeData) then
            WMLogger:info("Sync condition met (poll) — follower advancing past wait step %d",
                activeData.currentStep)
            activeData.status = WorkflowManager.STATUS_RUNNING
            self:executeCurrentStep(activeData)
            WorkflowManager:broadcastState(activeData.vehicle)
        end
    end

    -- Support vehicle idle polling: check if main has moved to a step with support sub-steps
    if activeData.status == WorkflowManager.STATUS_WAITING_FOR_MAIN then
        local mainActiveData = self:getMainActiveDataForWorkflow(workflow.id)
        if mainActiveData == nil then
            WMLogger:info("Support vehicle (idle): main stopped, stopping support")
            self:stopWorkflow(vehicle)
        else
            local mainStep = workflow.steps[mainActiveData.currentStep]
            local supportSteps = mainStep and mainStep.support or {}
            local mainStepChanged = mainActiveData.currentStep ~= activeData.waitingForMainStepIndex
            if #supportSteps > 0 and mainStepChanged then
                WMLogger:info("Support vehicle (idle): main moved to step %d which has sub-steps",
                    mainActiveData.currentStep)
                self:onMainStepChanged(activeData, mainActiveData.currentStep)
            end
        end
    end
end

---Start an AutoDrive step (extracted for reuse by deferred start)
---@param activeData table Per-vehicle execution state
---@param vehicle table Vehicle
---@param step table Step data
function WMExecutor:startAutoDriveStep(activeData, vehicle, step)
    local workflow = activeData.workflow

    -- Clear any CP-handoff flag before starting AD, regardless of success.
    -- A prior CP step may have called setStartCPOnCompletion(true); if startRoute
    -- fails without calling StartDriving, that flag stays armed and the next AD
    -- activation would auto-start CP. (On success, StartDriving resets the flag
    -- internally anyway, so calling clear first is safe and idempotent.)
    ADIntegration:clearCPHandoff(vehicle)

    local success = ADIntegration:startRoute(
        vehicle,
        step.target,
        step.action,
        step.unloadTarget,
        step.fillTypes
    )
    if success then
        activeData.waitingForCompletion = true
        activeData.currentStepType = WorkflowManager.STEP_AUTODRIVE
        activeData.pendingADStart = nil
        activeData.pendingADStartRetries = nil
        activeData.justStoppedAD = nil
        activeData.lastADTarget = step.target
        -- Apply after StartDriving so AD's own route-start logic can't overwrite them
        ADIntegration:applyWorkflowSettings(vehicle, workflow.adSettings)
        WMLogger:info("AutoDrive step started successfully, waiting for completion")
    else
        self:handleStepError(activeData, "Failed to start AutoDrive route: " .. (step.target or "nil"))
    end
end

---Start a Courseplay step (extracted for reuse by deferred start)
---@param activeData table Per-vehicle execution state
---@param vehicle table Vehicle
---@param step table Step data
function WMExecutor:startCourseplayStep(activeData, vehicle, step)
    -- Safety: if CP is somehow already running, just attach monitoring — never reset a running course
    if CPIntegration:isRunning(vehicle) then
        WMLogger:warning("Courseplay unexpectedly already running at CP step start - attaching monitoring only")
        activeData.waitingForCompletion = true
        activeData.currentStepType = WorkflowManager.STEP_COURSEPLAY
        activeData.cpWasRunning = true
        activeData.pendingCPStart = nil
        activeData.pendingCPStartRetries = nil
        activeData.cpToCpTransition = nil
        return
    end

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
        activeData.cpToCpTransition = nil
        -- Enable AD to auto-start CP after a refill run (CP triggers AD → AD finishes → CP resumes)
        ADIntegration:setStartCPOnCompletion(vehicle, true)
        WMLogger:info("Courseplay step started successfully, polling for completion")
    else
        self:handleStepError(activeData, "Failed to start Courseplay field work")
    end
end

---Pause the current step
---@param activeData table Per-vehicle execution state
function WMExecutor:pauseCurrentStep(activeData)
    local step = self:getCurrentStep(activeData)
    if step == nil then
        if activeData.currentStepType == nil then return end
        step = { type = activeData.currentStepType }
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
    local step = self:getCurrentStep(activeData)
    if step == nil then
        if activeData.currentStepType == nil then return end
        step = { type = activeData.currentStepType }
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

    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_COMPLETED, {
        workflowId = workflow.id,
        stepNumber = completedStepNum
    })

    -- ===== Support vehicle: advance currentSupportStep and loop =====
    if activeData.isMainVehicle == false then
        local mainActiveData = self:getMainActiveDataForWorkflow(workflow.id)
        if mainActiveData == nil then
            WMLogger:info("Support vehicle: main not running, stopping support")
            self:stopWorkflow(activeData.vehicle)
            return
        end

        local mainStep = workflow.steps[mainActiveData.currentStep]
        local supportSteps = mainStep and mainStep.support or {}

        activeData.currentSupportStep = activeData.currentSupportStep + 1
        if activeData.currentSupportStep > #supportSteps then
            -- All sub-steps for this main step are done — wait for main to advance.
            -- Record which main step we finished so the idle poll can detect when it changes.
            activeData.currentSupportStep = 1
            activeData.waitingForMainStep = true
            activeData.waitingForMainStepIndex = mainActiveData.currentStep
            activeData.status = WorkflowManager.STATUS_WAITING_FOR_MAIN
            WMLogger:info("Support vehicle: all sub-steps done, waiting for main to advance (main step %d)",
                mainActiveData.currentStep)
            self:ensureWaitPollerActive()
            WorkflowManager:broadcastState(activeData.vehicle)
            return
        end

        self:executeCurrentStep(activeData)
        WorkflowManager:broadcastState(activeData.vehicle)
        return
    end

    -- ===== Main vehicle: advance currentStep =====
    activeData.currentStep = activeData.currentStep + 1

    -- Helper: notify all support vehicles that main moved to a new step
    local function notifySupport()
        local supportDataList = self:getSupportActiveDataListForWorkflow(workflow.id)
        for _, supportActiveData in ipairs(supportDataList) do
            self:onMainStepChanged(supportActiveData, activeData.currentStep)
        end
    end

    if activeData.currentStep > #workflow.steps then
        self:onWorkflowCompleted(activeData)
    else
        notifySupport()
        -- Delay next step by 2s to give the player time to press "previous step".
        activeData.pendingAutoStep = g_currentMission.time + 2000
        WMLogger:info("Deferring step %d start by 2s", activeData.currentStep)
    end
    -- Broadcast the new step / status to all multiplayer clients (no-op in singleplayer)
    WorkflowManager:broadcastState(activeData.vehicle)
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

    -- Broadcast cleared state (isActive=false) to all clients
    WorkflowManager:broadcastState(vehicle)

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

    -- Execution logic (AD/CP API calls) must only run on the server.
    -- Clients keep their wmExecution mirrors up to date via WMStateSyncEvent.
    if g_server == nil then
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

                    -- Re-apply AD settings after savegame restore (AD may have reset them on load)
                    ADIntegration:applyWorkflowSettings(vehicle, workflow.adSettings)

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
                    -- Broadcast the new running state to all clients
                    WorkflowManager:broadcastState(vehicle)
                elseif g_currentMission.time >= activeData.autoResumeUntil then
                    activeData.autoResumeUntil = nil  -- window expired - stay paused
                    WMLogger:info("Auto-resume window expired for '%s', staying paused", workflow.name)
                end
            end

            -- Deferred auto-step: player was in vehicle when step completed; start next step after 2s.
            if activeData.pendingAutoStep and g_currentMission.time >= activeData.pendingAutoStep then
                activeData.pendingAutoStep = nil
                WMLogger:info("Deferred auto-step timer elapsed — starting step %d", activeData.currentStep)
                self:executeCurrentStep(activeData)
                WorkflowManager:broadcastState(activeData.vehicle)
            end

            -- Leader-follower poll and support-vehicle idle poll are handled by the global
            -- wait poller (runWaitPoll via g_currentMission:addUpdateable), so they run
            -- even when FS25 puts distant vehicles to sleep.

            if activeData.status == WorkflowManager.STATUS_RUNNING and activeData.waitingForCompletion then
            -- Handle deferred CP start: either AD was stopped (AD->CP) or previous step
            -- was also CP (CP->CP transition needs cleanup time).
            if activeData.pendingCPStart then
                activeData.pendingCPStartRetries = (activeData.pendingCPStartRetries or 0) + 1
                local adRunning = ADIntegration:isRunning(vehicle)
                -- CP->CP: wait at least 2 cycles (1 second) for previous CP job to clean up.
                -- AD->CP: start as soon as AD stops (no minimum wait needed).
                local minWaitCycles = activeData.cpToCpTransition and 2 or 0
                local readyToStart = not adRunning and activeData.pendingCPStartRetries >= minWaitCycles
                if readyToStart then
                    local msg = activeData.cpToCpTransition and
                        "CP cleanup complete - starting deferred Courseplay step" or
                        "AutoDrive fully stopped - starting deferred Courseplay step"
                    WMLogger:info(msg)
                    activeData.pendingCPStart = nil
                    activeData.pendingCPStartRetries = nil
                    activeData.cpToCpTransition = nil
                    activeData.waitingForCompletion = false
                    local step = self:getCurrentStep(activeData)
                    if step then
                        self:startCourseplayStep(activeData, vehicle, step)
                    end
                else
                    -- Give up after 20 checks (10 seconds) to avoid hanging
                    if activeData.pendingCPStartRetries > 20 then
                        WMLogger:warning("CP start deferred too long (20 cycles) - forcing start")
                        activeData.pendingCPStart = nil
                        activeData.pendingCPStartRetries = nil
                        activeData.cpToCpTransition = nil
                        activeData.waitingForCompletion = false
                        local step = self:getCurrentStep(activeData)
                        if step then
                            self:startCourseplayStep(activeData, vehicle, step)
                        end
                    elseif adRunning then
                        WMLogger:debug("Waiting for AD to stop before starting CP (%d/20)", activeData.pendingCPStartRetries)
                    else
                        WMLogger:debug("Waiting for CP cleanup before starting next step (%d/%d)",
                            activeData.pendingCPStartRetries, minWaitCycles)
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
                    local step = self:getCurrentStep(activeData)
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
                    local step = self:getCurrentStep(activeData)
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
                            -- But check if CP started again (AD may have restarted CP via setStartHelper)
                            if cpRunning then
                                WMLogger:debug("AutoDrive completed and Courseplay restarted - continuing to monitor CP")
                                activeData.cpHandedOffToAD = false
                                activeData.cpHandedOffWait = nil
                                activeData.cpWasRunning = true  -- Track that CP is running again
                            else
                                -- CP hasn't restarted yet — give setStartHelper a grace period (2 polls ≈ 1s)
                                activeData.cpHandedOffWait = (activeData.cpHandedOffWait or 0) + 1
                                if activeData.cpHandedOffWait >= 2 then
                                    WMLogger:debug("AutoDrive completed after Courseplay handoff - CP did not restart, step complete")
                                    isComplete = true
                                    activeData.cpHandedOffToAD = false
                                    activeData.cpHandedOffWait = nil
                                else
                                    WMLogger:debug("AutoDrive completed - waiting for CP to restart (%d/2)", activeData.cpHandedOffWait)
                                end
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
                        if adRunning then
                            -- AD may have started before we could detect CP (e.g. CP→AD handoff at step start)
                            WMLogger:debug("AutoDrive detected running at start of CP step - waiting for AD")
                            activeData.cpHandedOffToAD = true
                        else
                            -- CP never started or failed to start
                            WMLogger:warning("Courseplay never started for workflow %s", workflow.name)
                            isComplete = true
                        end
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

---Get the active execution data for a workflow by its ID
---Scans activeVehicles to find which vehicle is running this workflow
---@param workflowId string Workflow ID to look up
---@return table|nil activeData The execution state, or nil if workflow is not running
function WMExecutor:getActiveDataForWorkflow(workflowId)
    for vehicle, _ in pairs(self.activeVehicles) do
        local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
        if activeData and activeData.workflow.id == workflowId then
            return activeData
        end
    end
    return nil
end

---Get all active execution data entries for a given workflow ID.
---A support workflow may be running on multiple vehicles simultaneously.
---@param workflowId string Workflow ID to look up
---@return table activeDataList Array of activeData tables (empty if none running)
function WMExecutor:getActiveVehiclesForWorkflow(workflowId)
    local result = {}
    for vehicle, _ in pairs(self.activeVehicles) do
        local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
        if activeData and activeData.workflow.id == workflowId then
            table.insert(result, activeData)
        end
    end
    return result
end

---Get the main-role active execution data for a given workflow ID.
---@param workflowId string Workflow ID
---@return table|nil activeData The main vehicle's activeData, or nil
function WMExecutor:getMainActiveDataForWorkflow(workflowId)
    for vehicle, _ in pairs(self.activeVehicles) do
        local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
        if activeData and activeData.workflow.id == workflowId and activeData.isMainVehicle ~= false then
            return activeData
        end
    end
    return nil
end

---Get all support-role active execution data entries for a given workflow ID.
---@param workflowId string Workflow ID
---@return table activeDataList Array of support activeData tables (empty if none)
function WMExecutor:getSupportActiveDataListForWorkflow(workflowId)
    local result = {}
    for vehicle, _ in pairs(self.activeVehicles) do
        local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
        if activeData and activeData.workflow.id == workflowId and activeData.isMainVehicle == false then
            table.insert(result, activeData)
        end
    end
    return result
end

---Get the current step definition for an activeData entry.
---For main vehicles returns workflow.steps[currentStep].
---For support vehicles returns the current support sub-step from the main step's support array.
---@param activeData table Per-vehicle execution state
---@return table|nil step Step definition, or nil if not found
function WMExecutor:getCurrentStep(activeData)
    local workflow = activeData.workflow
    if activeData.isMainVehicle ~= false then
        return workflow.steps[activeData.currentStep]
    else
        local mainActiveData = self:getMainActiveDataForWorkflow(workflow.id)
        if mainActiveData == nil then return nil end
        local mainStep = workflow.steps[mainActiveData.currentStep]
        if mainStep == nil then return nil end
        local support = mainStep.support or {}
        return support[activeData.currentSupportStep]
    end
end

---Called when the main vehicle advances to a new step.
---Stops the current support sub-step, resets to sub-step 1, and executes the new one.
---@param supportActiveData table Support vehicle's execution state
---@param newMainStep number New main step index (1-based, for logging)
function WMExecutor:onMainStepChanged(supportActiveData, newMainStep)
    WMLogger:info("Main step changed to %d - resetting support vehicle to sub-step 1", newMainStep)
    self:stopCurrentStep(supportActiveData)
    supportActiveData.currentSupportStep = 1
    supportActiveData.waitingForMainStep = nil
    supportActiveData.waitingForMainStepIndex = nil
    self:resetStepTrackingState(supportActiveData)

    if supportActiveData.status == WorkflowManager.STATUS_PAUSED then
        -- Support is paused — update step state but do not start execution.
        -- Mark it so executeCurrentStep is called when the vehicle resumes.
        supportActiveData.pendingExecuteOnResume = true
        WMLogger:info("Support vehicle is paused — sub-step staged, will execute on resume")
    else
        self:executeCurrentStep(supportActiveData)
    end
    WorkflowManager:broadcastState(supportActiveData.vehicle)
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

---Reset all per-step tracking flags on activeData.
---Call this whenever a step is abandoned mid-execution (manual prev/next, sync transition).
---@param activeData table Per-vehicle execution state
function WMExecutor:resetStepTrackingState(activeData)
    activeData.waitingForCompletion = false
    activeData.cpHandedOffToAD = false
    activeData.cpHandedOffWait = nil
    activeData.cpWasRunning = false
    activeData.pausedTrackingState = nil
    activeData.pendingCPStart = nil
    activeData.pendingCPStartRetries = nil
    activeData.cpToCpTransition = nil
    activeData.pendingADStart = nil
    activeData.pendingADStartRetries = nil
    activeData.justStoppedAD = nil
    activeData.waitingForMainStep = nil
    activeData.waitingForMainStepIndex = nil
    activeData.pendingExecuteOnResume = nil
    activeData.pendingAutoStep = nil
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

    local workflow = activeData.workflow

    -- Deferred auto-step window: navigate only; don't execute the step yet.
    -- Restart the 10s timer so the player can navigate multiple steps.
    if activeData.pendingAutoStep then
        activeData.currentStep = activeData.currentStep - 1
        activeData.pendingAutoStep = g_currentMission.time + 10000
        WMLogger:info("Deferred: navigated to step %d, timer restarted", activeData.currentStep)
        if activeData.isMainVehicle ~= false then
            for _, sd in ipairs(self:getSupportActiveDataListForWorkflow(workflow.id)) do
                self:onMainStepChanged(sd, activeData.currentStep)
            end
        end
        WorkflowManager:broadcastState(vehicle)
        return true
    end

    -- Remember if workflow was paused so we can resume after step change
    local wasPaused = activeData.status == WorkflowManager.STATUS_PAUSED

    -- Stop the current step (handles paused state internally)
    self:stopCurrentStep(activeData)

    -- Move to previous step
    activeData.currentStep = activeData.currentStep - 1

    WMLogger:info("Moving to previous step %d/%d for workflow %s",
        activeData.currentStep, #workflow.steps, workflow.name)

    self:resetStepTrackingState(activeData)

    -- Resume to RUNNING if was paused or in any wait state (manual nav always resumes)
    if wasPaused or activeData.status == WorkflowManager.STATUS_WAITING_FOR_LEADER
                 or activeData.status == WorkflowManager.STATUS_WAITING_FOR_MAIN then
        activeData.status = WorkflowManager.STATUS_RUNNING
    end

    -- If workflow is running, start the new step
    if activeData.status == WorkflowManager.STATUS_RUNNING then
        self:executeCurrentStep(activeData)
    end

    -- Notify all support vehicles to follow the new main step
    if activeData.isMainVehicle ~= false then
        local supportDataList = self:getSupportActiveDataListForWorkflow(workflow.id)
        for _, supportActiveData in ipairs(supportDataList) do
            self:onMainStepChanged(supportActiveData, activeData.currentStep)
        end
    end

    -- Broadcast main vehicle's new step/status to all clients
    WorkflowManager:broadcastState(vehicle)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_CHANGED, {
        workflowId = workflow.id,
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

    local workflow = activeData.workflow

    if activeData.currentStep >= #workflow.steps then
        WMLogger:warning("Already at last step of workflow %s", workflow.id)
        return false
    end

    -- Deferred auto-step window: navigate only; don't execute the step yet.
    if activeData.pendingAutoStep then
        activeData.currentStep = activeData.currentStep + 1
        activeData.pendingAutoStep = g_currentMission.time + 10000
        WMLogger:info("Deferred: navigated to step %d, timer restarted", activeData.currentStep)
        if activeData.isMainVehicle ~= false then
            for _, sd in ipairs(self:getSupportActiveDataListForWorkflow(workflow.id)) do
                self:onMainStepChanged(sd, activeData.currentStep)
            end
        end
        WorkflowManager:broadcastState(vehicle)
        return true
    end

    -- Remember if workflow was paused so we can resume after step change
    local wasPaused = activeData.status == WorkflowManager.STATUS_PAUSED

    -- Stop the current step (handles paused state internally)
    self:stopCurrentStep(activeData)

    -- Move to next step
    activeData.currentStep = activeData.currentStep + 1

    WMLogger:info("Moving to next step %d/%d for workflow %s",
        activeData.currentStep, #workflow.steps, workflow.name)

    self:resetStepTrackingState(activeData)

    -- Resume to RUNNING if was paused or in any wait state (manual nav always resumes)
    if wasPaused or activeData.status == WorkflowManager.STATUS_WAITING_FOR_LEADER
                 or activeData.status == WorkflowManager.STATUS_WAITING_FOR_MAIN then
        activeData.status = WorkflowManager.STATUS_RUNNING
    end

    -- If workflow is running, start the new step
    if activeData.status == WorkflowManager.STATUS_RUNNING then
        self:executeCurrentStep(activeData)
    end

    -- Notify all support vehicles to follow the new main step
    if activeData.isMainVehicle ~= false then
        local supportDataList = self:getSupportActiveDataListForWorkflow(workflow.id)
        for _, supportActiveData in ipairs(supportDataList) do
            self:onMainStepChanged(supportActiveData, activeData.currentStep)
        end
    end

    -- Broadcast main vehicle's new step/status to all clients
    WorkflowManager:broadcastState(vehicle)

    -- Fire event
    WMEventHandler:fireEvent(WMEventHandler.EVENT_STEP_CHANGED, {
        workflowId = workflow.id,
        stepNumber = activeData.currentStep,
        direction = "next"
    })

    return true
end
