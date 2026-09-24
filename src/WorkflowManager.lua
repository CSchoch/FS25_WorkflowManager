--[[
    WorkflowManager - Main Entry Point
    Combines AutoDrive and Courseplay for automated field workflows

    Author: CSchoch
    Version: 1.2.0.0
]]

-- Source all required files (order matters for dependencies)
-- 1. Development config (optional - omitted in release builds)
local devConfigPath = Utils.getFilename("src/DevConfig.lua", g_currentModDirectory)
if fileExists(devConfigPath) then
    source(devConfigPath)
end

-- Fallback: if DevConfig was not loaded, use release defaults (all debug off)
if WMDevConfig == nil then
    WMDevConfig = {
        DEV_MODE = false,
        DEBUG_LOGGING = false,
        SHOW_DEBUG_OVERLAY = false,
        LOG_API_CALLS = false,
        LOG_STATE_CHANGES = false,
        LOG_EVENTS = false,
        AUTO_CREATE_TEST_WORKFLOW = false,
        SKIP_VEHICLE_CHECKS = false,
        SIMULATE_AD_COMPLETION_MS = 0,
        SIMULATE_CP_COMPLETION_MS = 0,
        EXECUTOR_UPDATE_INTERVAL = 1000,
        GUI_REFRESH_INTERVAL = 500,
        SHOW_FPS = false,
        DEBUG_OVERLAY_X = 0.01,
        DEBUG_OVERLAY_Y = 0.95,
        DEBUG_TEXT_SIZE = 0.012,
        isDevMode = function() return false end,
        isDebugLogging = function() return false end,
        shouldLogAPICalls = function() return false end,
        shouldLogStateChanges = function() return false end,
        shouldLogEvents = function() return false end,
        printConfig = function() end,
    }
end

-- 2. Utilities
source(Utils.getFilename("src/utils/Logger.lua", g_currentModDirectory))
source(Utils.getFilename("src/utils/EventHandler.lua", g_currentModDirectory))
source(Utils.getFilename("src/utils/DebugUtil.lua", g_currentModDirectory))

-- 3. Core modules
source(Utils.getFilename("src/WMSettings.lua", g_currentModDirectory))
source(Utils.getFilename("src/WorkflowStorage.lua", g_currentModDirectory))
source(Utils.getFilename("src/WorkflowExecutor.lua", g_currentModDirectory))
source(Utils.getFilename("src/network/WMNetworkEvents.lua", g_currentModDirectory))

-- 4. Integration modules
source(Utils.getFilename("src/integration/AutoDriveIntegration.lua", g_currentModDirectory))
source(Utils.getFilename("src/integration/CourseplayIntegration.lua", g_currentModDirectory))
source(Utils.getFilename("src/integration/CourseplayCoursesLoader.lua", g_currentModDirectory))
source(Utils.getFilename("src/integration/CourseplayVehiclesLoader.lua", g_currentModDirectory))

-- 5. Dialog-based GUI (proper input blocking)
source(Utils.getFilename("src/gui/WMMainDialog.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMEditorDialog.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMStepDialog.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMModeSelectDialog.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMADSettingsDialog.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMLeaderVehicleSelectDialog.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMGameSettings.lua", g_currentModDirectory))

-- 6. In-vehicle HUD
source(Utils.getFilename("src/gui/WMHudElements.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMHud.lua", g_currentModDirectory))

-- 7. Developer console commands
source(Utils.getFilename("src/dev/WMConsoleCommands.lua", g_currentModDirectory))

-- Initialize logger from dev config immediately after loading
WMLogger:initFromDevConfig()

---@class WorkflowManager
WorkflowManager = {}
WorkflowManager.version = "1.2.0.0"
WorkflowManager.modName = g_currentModName
WorkflowManager.modDirectory = g_currentModDirectory

-- Workflow status constants
WorkflowManager.STATUS_READY = "ready"
WorkflowManager.STATUS_RUNNING = "running"
WorkflowManager.STATUS_PAUSED = "paused"
WorkflowManager.STATUS_COMPLETED = "completed"
WorkflowManager.STATUS_ERROR = "error"
WorkflowManager.STATUS_WAITING_FOR_LEADER = "waiting_for_leader"
WorkflowManager.STATUS_WAITING_FOR_MAIN = "waiting_for_main"

-- Step type constants
WorkflowManager.STEP_AUTODRIVE = "autodrive"
WorkflowManager.STEP_COURSEPLAY = "courseplay"
-- Leader/follower sync marker steps (pass-through coordination steps, no AD/CP job)
WorkflowManager.STEP_WAIT_FOR_LEADER = "wait_for_leader"
WorkflowManager.STEP_UNLOCK_FOLLOWER = "unlock_follower"
-- Drive to the vehicle's (or an attached implement's) AutoDrive park position
WorkflowManager.STEP_PARK = "park"
-- Drive to the nearest AD-reachable fuel station for the vehicle's needed fuel type(s)
WorkflowManager.STEP_REFUEL = "refuel"
-- Drive to the nearest AD-reachable workshop and repair the vehicle
WorkflowManager.STEP_REPAIR = "repair"

-- Internal state
WorkflowManager.workflows = {}
WorkflowManager.isInitialized = false
WorkflowManager.isShuttingDown = false
WorkflowManager.guiVisible = false

---Get the localized display label for a step type
---@param stepType string Step type id
---@return string label
function WorkflowManager:getStepTypeLabel(stepType)
    if stepType == self.STEP_AUTODRIVE then return g_i18n:getText("wm_type_autodrive") end
    if stepType == self.STEP_COURSEPLAY then return g_i18n:getText("wm_type_courseplay") end
    if stepType == self.STEP_WAIT_FOR_LEADER then return g_i18n:getText("wm_type_wait_for_leader") end
    if stepType == self.STEP_UNLOCK_FOLLOWER then return g_i18n:getText("wm_type_unlock_follower") end
    if stepType == self.STEP_PARK then return g_i18n:getText("wm_type_park") end
    if stepType == self.STEP_REFUEL then return g_i18n:getText("wm_type_refuel") end
    if stepType == self.STEP_REPAIR then return g_i18n:getText("wm_type_repair") end
    return tostring(stepType)
end

---Returns true if the step type is a leader/follower sync marker (no AD/CP job)
---@param stepType string Step type id
---@return boolean
function WorkflowManager:isMarkerStepType(stepType)
    return stepType == self.STEP_WAIT_FOR_LEADER or stepType == self.STEP_UNLOCK_FOLLOWER
end

---Returns true if the step type has no user-editable target/action (auto-resolved).
---Marker steps have no target because they're pass-through; Park/Refuel/Repair have no
---target because AD resolves the destination itself (park position / nearest station).
---@param stepType string Step type id
---@return boolean
function WorkflowManager:isTargetlessStepType(stepType)
    return self:isMarkerStepType(stepType)
        or stepType == self.STEP_PARK
        or stepType == self.STEP_REFUEL
        or stepType == self.STEP_REPAIR
end

---Returns true if the step type is an AutoDrive-driven job tracked via AD's own
---start/pause/resume/stop/isActive machinery (as opposed to Courseplay or sync markers).
---@param stepType string Step type id
---@return boolean
function WorkflowManager:isAutoDriveTrackedStepType(stepType)
    return stepType == self.STEP_AUTODRIVE
        or stepType == self.STEP_PARK
        or stepType == self.STEP_REFUEL
        or stepType == self.STEP_REPAIR
end

---Get a short (AD/CP/WM) tag for a step type, for compact HUD display
---@param stepType string Step type id
---@return string shortcut "AD", "CP", "PARK", "REFUEL", "REPAIR", or "WM" (markers)
function WorkflowManager:getStepTypeShortcut(stepType)
    if stepType == self.STEP_AUTODRIVE then return "AD" end
    if stepType == self.STEP_COURSEPLAY then return "CP" end
    if stepType == self.STEP_PARK then return "PARK" end
    if stepType == self.STEP_REFUEL then return "REFUEL" end
    if stepType == self.STEP_REPAIR then return "REPAIR" end
    return "WM"
end

---Initialize the WorkflowManager
function WorkflowManager:init()
    if self.isInitialized then
        return
    end

    -- Print dev config if in dev mode
    if WMDevConfig:isDevMode() then
        WMDevConfig:printConfig()
    end

    WMLogger:info("Initializing WorkflowManager v%s", self.version)

    -- Initialize subsystems
    WMEventHandler:init()
    WMStorage:init()
    WMExecutor:init()
    ADIntegration:init()
    CPIntegration:init()
    CPCoursesLoader:init()
    CPVehiclesLoader:init()
    WMDebugUtil:init()

    -- Initialize in-vehicle HUD
    WMHud:init()

    -- Subscribe to workflow events to show/hide HUD automatically
    WMEventHandler:subscribe(WMEventHandler.EVENT_WORKFLOW_STARTED, self, self.onWorkflowStartedEvent)
    WMEventHandler:subscribe(WMEventHandler.EVENT_WORKFLOW_RESUMED, self, self.onWorkflowResumedEvent)
    WMEventHandler:subscribe(WMEventHandler.EVENT_WORKFLOW_STOPPED, self, self.onWorkflowStoppedEvent)
    WMEventHandler:subscribe(WMEventHandler.EVENT_WORKFLOW_COMPLETED, self, self.onWorkflowCompletedEvent)

    -- Load new dialog-based GUI (proper input blocking)
    self:loadDialogs()

    -- Register input actions (fallback for direct access)
    self:registerInputActions()

    -- Register developer console commands
    WMConsoleCommands:init()

    self.isInitialized = true
    WMLogger:info("WorkflowManager initialized successfully")

    -- Auto-create test workflow if enabled
    if WMDevConfig.AUTO_CREATE_TEST_WORKFLOW then
        local testWorkflow = WMDebugUtil:createTestWorkflow()
        if testWorkflow then
            table.insert(self.workflows, testWorkflow)
        end
    end
end

---Load all dialog-based GUIs
function WorkflowManager:loadDialogs()
    if g_gui == nil then
        WMLogger:warning("g_gui not available, cannot load dialogs")
        return
    end

    -- Load GUI profiles first
    local profilesPath = Utils.getFilename("xml/gui/guiProfiles.xml", self.modDirectory)
    g_gui:loadProfiles(profilesPath)
    WMLogger:debug("Loaded GUI profiles from: %s", profilesPath)

    -- Full literal paths on purpose: GIANTS' TestRunner finds used files by their path string
    -- and reports a concatenated one ("xml/gui/" .. name) as an unused file.
    self.mainDialog = self:loadDialog("xml/gui/WMMainDialog.xml", "WMMainDialog", WMMainDialog.new())
    self.editorDialog = self:loadDialog("xml/gui/WMEditorDialog.xml", "WMEditorDialog", WMEditorDialog.new())
    self.stepDialog = self:loadDialog("xml/gui/WMStepDialog.xml", "WMStepDialog", WMStepDialog.new())
    self.modeSelectDialog = self:loadDialog("xml/gui/WMModeSelectDialog.xml",
        "WMModeSelectDialog", WMModeSelectDialog.new())
    self.adSettingsDialog = self:loadDialog("xml/gui/WMADSettingsDialog.xml",
        "WMADSettingsDialog", WMADSettingsDialog.new())
    self.leaderSelectDialog = self:loadDialog("xml/gui/WMLeaderVehicleSelectDialog.xml",
        "WMLeaderVehicleSelectDialog", WMLeaderVehicleSelectDialog.new())

    -- Add the mod's options to the game's General settings page
    WMGameSettings:init()
end

---Load one dialog's GUI XML into its controller.
---@param xmlFile string Mod-relative path of the dialog XML
---@param name string GUI name
---@param controller table Dialog controller instance
---@return table|nil controller The controller, or nil if loading failed (Gui:loadGui logs why)
function WorkflowManager:loadDialog(xmlFile, name, controller)
    local xmlPath = Utils.getFilename(xmlFile, self.modDirectory)
    if g_gui:loadGui(xmlPath, name, controller) == nil then
        WMLogger:warning("Failed to load dialog: %s", name)
        return nil
    end
    WMLogger:info("Dialog loaded: %s", name)
    return controller
end

---Show the AD/CP settings dialog
---@param adSettings table|nil  Current workflow.adSettings
---@param callback   function   Called with settings table on OK, nil on cancel
function WorkflowManager:showADSettingsDialog(adSettings, callback)
    if self.adSettingsDialog == nil then
        WMLogger:warning("AD settings dialog not available")
        return
    end
    self.adSettingsDialog:setSettings(adSettings, callback)
    g_gui:showDialog("WMADSettingsDialog")
end

---Register input action bindings
---Uses PlayerInputComponent hook for global (non-vehicle) input actions
---Vehicle input is handled by WorkflowManagerSpec specialization
function WorkflowManager:registerInputActions()
    WMLogger:debug("Setting up input action registration...")

    -- Hook into PlayerInputComponent to register global actions (when NOT in vehicle)
    -- This is the pattern Courseplay uses for non-vehicle mods
    if PlayerInputComponent ~= nil and PlayerInputComponent.registerGlobalPlayerActionEvents ~= nil then
        local originalFunc = PlayerInputComponent.registerGlobalPlayerActionEvents

        PlayerInputComponent.registerGlobalPlayerActionEvents = function(playerInput, ...)
            -- Call original function first
            originalFunc(playerInput, ...)

            -- Now register our global actions
            WorkflowManager:registerGlobalActions()
        end

        WMLogger:info("Hooked PlayerInputComponent.registerGlobalPlayerActionEvents")
    else
        WMLogger:warning("PlayerInputComponent not available, trying direct registration")
        -- Fallback: try direct registration (may not work for global mods)
        self:registerGlobalActions()
    end

    -- Note: Vehicle input is now handled by WorkflowManagerSpec specialization
    -- which is registered to all enterable vehicles via g_vehicleTypeManager
    WMLogger:info("Vehicle input handled by WorkflowManagerSpec specialization")
end

---Register the actual global action events
function WorkflowManager:registerGlobalActions()
    if g_inputBinding == nil then
        WMLogger:error("Cannot register input actions - g_inputBinding is nil")
        return
    end

    -- Avoid double registration
    if self.globalActionsRegistered then
        return
    end
    self.globalActionsRegistered = true

    WMLogger:debug("Registering global input actions...")

    -- Register WM_TOGGLE_GUI
    local _, eventId = g_inputBinding:registerActionEvent(
        "WM_TOGGLE_GUI",
        self,
        self.onToggleGUI,
        false,  -- triggerUp
        true,   -- triggerDown
        false,  -- triggerAlways
        true    -- startActive
    )
    if eventId ~= nil then
        g_inputBinding:setActionEventTextVisibility(eventId, true)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
        WMLogger:info("Registered global input action WM_TOGGLE_GUI (eventId: %s)", tostring(eventId))
    else
        WMLogger:warning("Input action WM_TOGGLE_GUI registered but eventId is nil")
    end

    -- Register WM_TOGGLE_HUD
    _, eventId = g_inputBinding:registerActionEvent(
        "WM_TOGGLE_HUD",
        self,
        self.onToggleHUD,
        false, true, false, true
    )
    if eventId ~= nil then
        g_inputBinding:setActionEventTextVisibility(eventId, false)
        WMLogger:debug("Registered WM_TOGGLE_HUD")
    end
end


---Toggle the main GUI visibility
function WorkflowManager:onToggleGUI()
    WMLogger:info("onToggleGUI called!")
    self:showMainDialog()
end

---Toggle the in-vehicle HUD visibility
function WorkflowManager:onToggleHUD()
    WMLogger:info("onToggleHUD called!")
    WMHud:toggle(g_currentMission.controlledVehicle)
end

---Called when a workflow starts - show HUD
---@param eventType string Event type
---@param data table Event data
function WorkflowManager:onWorkflowStartedEvent(eventType, data)
    WMLogger:info("Workflow started event received for: %s", tostring(data.workflowId))

    -- Use vehicle from event data (set by executor)
    if data.vehicle then
        WMLogger:info("Showing HUD for workflow vehicle")
        WMHud:show(data.vehicle)
    else
        -- Fallback: try to get current vehicle
        local currentVehicle = g_currentMission.controlledVehicle
        if currentVehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
            currentVehicle = g_localPlayer:getCurrentVehicle()
        end
        if currentVehicle then
            WMLogger:info("Showing HUD for current vehicle (fallback)")
            WMHud:show(currentVehicle)
        else
            WMLogger:warning("Cannot show HUD - no vehicle found")
        end
    end
end

---Called when a workflow is resumed - show HUD
---@param eventType string Event type
---@param data table Event data
function WorkflowManager:onWorkflowResumedEvent(eventType, data)
    WMLogger:info("Workflow resumed event received for: %s", tostring(data.workflowId))

    -- Use vehicle from event data (set by executor)
    if data.vehicle then
        WMLogger:info("Showing HUD for resumed workflow vehicle")
        WMHud:show(data.vehicle)
    else
        -- Fallback: try to get current vehicle
        local currentVehicle = g_currentMission.controlledVehicle
        if currentVehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
            currentVehicle = g_localPlayer:getCurrentVehicle()
        end
        if currentVehicle then
            WMLogger:info("Showing HUD for current vehicle (fallback)")
            WMHud:show(currentVehicle)
        else
            WMLogger:warning("Cannot show HUD - no vehicle found")
        end
    end
end

---Called when a workflow stops - hide HUD if no more active workflows for this vehicle
---@param eventType string Event type
---@param data table Event data
function WorkflowManager:onWorkflowStoppedEvent(eventType, data)
    WMLogger:debug("Workflow stopped event received")
    self:checkAndHideHUD()
end

---Called when a workflow completes - hide HUD if no more active workflows for this vehicle
---@param eventType string Event type
---@param data table Event data
function WorkflowManager:onWorkflowCompletedEvent(eventType, data)
    WMLogger:debug("Workflow completed event received")
    self:checkAndHideHUD()
end

---Check if HUD should be hidden (no active workflows for current vehicle)
function WorkflowManager:checkAndHideHUD()
    -- No-op: WMHud:update() now reactively manages show/hide based on current vehicle state
end

---Show the main workflow list dialog
function WorkflowManager:showMainDialog()
    if self.mainDialog == nil then
        WMLogger:warning("Main dialog not available")
        return
    end

    g_gui:showDialog("WMMainDialog")
end

---Show the workflow editor dialog
---@param workflow table Workflow to edit
---@param isNew boolean|nil true for an unregistered workflow (registered on Save, dropped on Cancel)
function WorkflowManager:showEditorDialog(workflow, isNew)
    if self.editorDialog == nil then
        WMLogger:warning("Editor dialog not available")
        return
    end

    self.editorDialog:setWorkflow(workflow, isNew)
    g_gui:showDialog("WMEditorDialog")
end

---Re-show the editor dialog without touching its edit buffer.
---Used when a child dialog (step / AD settings) closes again: the editor is closed before
---the child opens so the two never stack. See WMEditorDialog:suspendForChildDialog.
function WorkflowManager:reopenEditorDialog()
    if self.editorDialog == nil then
        WMLogger:warning("Editor dialog not available")
        return
    end

    g_gui:showDialog("WMEditorDialog")
end

---Show the step add/edit dialog
---@param step table|nil Step to edit, or nil for new step
---@param callback function Callback when done: callback(step) or callback(nil) if cancelled
---@param isSupportStep boolean|nil true when adding/editing a support sub-step
function WorkflowManager:showStepDialog(step, callback, isSupportStep)
    if self.stepDialog == nil then
        WMLogger:warning("Step dialog not available")
        if callback then
            callback(nil)
        end
        return
    end

    self.stepDialog:setStep(step, callback, isSupportStep)
    g_gui:showDialog("WMStepDialog")
end

---Build a new workflow table WITHOUT adding it to the workflow list.
---Use this when the workflow may still be discarded (e.g. the editor's New flow, where
---Cancel must leave no trace); call registerWorkflow once it is confirmed.
---@param name string|nil Name of the workflow
---@return table workflow The new, unregistered workflow
function WorkflowManager:buildWorkflow(name)
    return {
        id = self:generateWorkflowId(),
        name = name or "New Workflow",
        -- Vehicle is detected at runtime when starting the workflow
        -- currentStep and status are per-vehicle runtime state (in vehicle.spec_workflowManagerSpec.wmExecution)
        steps = {},
        createdAt = getDate("%Y-%m-%d %H:%M:%S"),
    }
end

---Add a workflow to the workflow list. No-op if a workflow with the same id is already
---present, so committing the same edit twice cannot duplicate it.
---@param workflow table Workflow to register
---@return boolean added True if it was added, false if it was already present
function WorkflowManager:registerWorkflow(workflow)
    if workflow == nil then return false end
    if self:getWorkflowById(workflow.id) ~= nil then
        return false
    end
    table.insert(self.workflows, workflow)
    WMLogger:debug("Registered workflow: %s (ID: %s)", workflow.name, workflow.id)
    return true
end

---Create a new workflow and add it to the workflow list
---@param name string Name of the workflow
---@return table workflow The created workflow
function WorkflowManager:createWorkflow(name)
    local workflow = self:buildWorkflow(name)

    table.insert(self.workflows, workflow)
    WMLogger:debug("Created workflow: %s (ID: %s)", workflow.name, workflow.id)

    return workflow
end

---Generate a unique workflow ID
---@return string id Unique workflow ID
function WorkflowManager:generateWorkflowId()
    return string.format("workflow_%d_%d", g_currentMission.time, math.random(1000, 9999))
end

---Get workflow by ID
---@param id string Workflow ID
---@return table|nil workflow The workflow or nil if not found
function WorkflowManager:getWorkflowById(id)
    for _, workflow in ipairs(self.workflows) do
        if workflow.id == id then
            return workflow
        end
    end
    return nil
end

---Add a support sub-step to a specific main step
---@param workflowId  string  Workflow ID
---@param stepIndex   number  1-based index of the main step to attach support to
---@param supportStep table   Support sub-step definition (type, target, action, ...)
---@return boolean success
function WorkflowManager:addSupportStep(workflowId, stepIndex, supportStep)
    local workflow = self:getWorkflowById(workflowId)
    if workflow == nil then
        WMLogger:error("addSupportStep: workflow %s not found", workflowId)
        return false
    end
    local step = workflow.steps[stepIndex]
    if step == nil then
        WMLogger:error("addSupportStep: step index %d out of range for workflow %s", stepIndex, workflowId)
        return false
    end
    if step.support == nil then step.support = {} end
    table.insert(step.support, supportStep)
    return true
end

---Remove a support sub-step from a specific main step
---@param workflowId    string  Workflow ID
---@param stepIndex     number  1-based index of the main step
---@param supportIndex  number  1-based index within step.support to remove
---@return boolean success
function WorkflowManager:removeSupportStep(workflowId, stepIndex, supportIndex)
    local workflow = self:getWorkflowById(workflowId)
    if workflow == nil then return false end
    local step = workflow.steps[stepIndex]
    if step == nil or step.support == nil then return false end
    if supportIndex < 1 or supportIndex > #step.support then return false end
    table.remove(step.support, supportIndex)
    return true
end

---Returns true if any step in this workflow has at least one support sub-step
---@param workflowId string
---@return boolean
function WorkflowManager:hasSupportSteps(workflowId)
    local workflow = self:getWorkflowById(workflowId)
    if workflow == nil then return false end
    for _, step in ipairs(workflow.steps) do
        if step.support and #step.support > 0 then
            return true
        end
    end
    return false
end

---Delete a workflow
---@param id string Workflow ID to delete
---@return boolean success True if deleted successfully
function WorkflowManager:deleteWorkflow(id)
    for i, workflow in ipairs(self.workflows) do
        if workflow.id == id then
            -- Stop if running on any vehicle
            if WMExecutor:isWorkflowActive(id) then
                self:stopWorkflow(id)
            end
            table.remove(self.workflows, i)
            WMLogger:debug("Deleted workflow: %s", id)
            return true
        end
    end
    return false
end

---Add a step to a workflow
---@param workflowId string Workflow ID
---@param stepType string Step type (autodrive/courseplay)
---@param target string Target route/course name
---@param action string Action to perform
---@return boolean success True if step added successfully
function WorkflowManager:addStep(workflowId, stepType, target, action)
    local workflow = self:getWorkflowById(workflowId)
    if workflow == nil then
        WMLogger:error("Cannot add step: Workflow %s not found", workflowId)
        return false
    end

    local step = {
        type    = stepType,
        target  = target,
        action  = action or "default",
        support = {},  -- support sub-steps for this step (empty by default)
    }

    table.insert(workflow.steps, step)
    WMLogger:debug("Added step to workflow %s: type=%s, target=%s", workflowId, stepType, target)

    return true
end

---Check every condition startWorkflow validates and resolve the vehicle it would run on.
---Shows the matching in-game warning when a condition fails, so callers only react to nil.
---@param workflowId string Workflow ID to start
---@return table|nil workflow, table|nil vehicle
function WorkflowManager:resolveStartTarget(workflowId)
    local workflow = self:getWorkflowById(workflowId)
    if workflow == nil then
        WMLogger:error("Cannot start: Workflow %s not found", workflowId)
        return nil
    end

    if #workflow.steps == 0 then
        WMLogger:error("Cannot start: Workflow %s has no steps", workflowId)
        return nil
    end

    -- Milestone 4: Get the current vehicle the player is driving
    -- Use g_localPlayer:getCurrentVehicle() which works even when GUI is open
    local currentVehicle = nil
    if g_localPlayer and g_localPlayer.getCurrentVehicle then
        currentVehicle = g_localPlayer:getCurrentVehicle()
    end

    if currentVehicle == nil then
        -- Show in-game warning to user
        local warningText = g_i18n:getText("wm_warning_no_vehicle") or "Enter a vehicle to start the workflow"
        if g_currentMission and g_currentMission.hud and g_currentMission.hud.showBlinkingWarning then
            g_currentMission.hud:showBlinkingWarning(warningText, 2000)
        end
        WMLogger:warning("Cannot start: Player is not in a vehicle")
        return nil
    end

    -- Prevent starting a new workflow on a vehicle that is already running one
    if WMExecutor:isWorkflowActiveOnVehicle(currentVehicle) then
        WMLogger:warning("Cannot start: Vehicle is already running a workflow")
        local warningText = g_i18n:getText("wm_warning_vehicle_busy") or "Vehicle is already running a workflow"
        if g_currentMission and g_currentMission.hud and g_currentMission.hud.showBlinkingWarning then
            g_currentMission.hud:showBlinkingWarning(warningText, 2000)
        end
        return nil
    end

    -- Validate the vehicle supports every step type this workflow uses (CP always, AD on demand)
    if not self:isVehicleValid(currentVehicle, workflow) then
        local vehicleName = currentVehicle.getName and currentVehicle:getName() or "unknown"
        -- Show in-game warning to user - name only the mods this workflow actually needs
        local needsAD = self:workflowNeedsAutoDrive(workflow)
        local warningKey = needsAD and "wm_warning_incompatible_vehicle" or "wm_warning_incompatible_vehicle_cp"
        local fallback = needsAD and "Vehicle '%s' needs AutoDrive + Courseplay" or "Vehicle '%s' needs Courseplay"
        local warningText = string.format(g_i18n:getText(warningKey) or fallback, vehicleName)
        if g_currentMission and g_currentMission.hud and g_currentMission.hud.showBlinkingWarning then
            g_currentMission.hud:showBlinkingWarning(warningText, 2000)
        end
        WMLogger:warning("Cannot start: Vehicle '%s' does not support this workflow (needs %s)", vehicleName,
            needsAD and "AutoDrive + Courseplay" or "Courseplay")
        return nil
    end

    return workflow, currentVehicle
end

---True when startWorkflow would get past validation right now.
---A dialog that starts a workflow must ask this and close *itself* before calling
---startWorkflow: the start flow opens the mode/leader dialog on top, and closing the
---parent afterwards tears the GUI's cursor state out from under the child.
---@param workflowId string Workflow ID to start
---@return boolean
function WorkflowManager:canStartWorkflow(workflowId)
    return self:resolveStartTarget(workflowId) ~= nil
end

---Start a workflow
---Uses the current vehicle the player is driving (Milestone 4)
---The flow may pass through mode-select / leader-select dialogs, so a true return only
---means "start flow initiated" — the start command may still be cancelled by the player.
---@param workflowId string Workflow ID to start
---@param onStarted function|nil Called when the start command is actually dispatched
---                              (never called when the player cancels a dialog)
---@return boolean success False on immediate validation failure, true when the flow began
function WorkflowManager:startWorkflow(workflowId, onStarted)
    local workflow, currentVehicle = self:resolveStartTarget(workflowId)
    if workflow == nil or currentVehicle == nil then
        return false
    end

    WMLogger:info("Starting workflow '%s' with vehicle: %s",
        workflow.name,
        currentVehicle.getName and currentVehicle:getName() or "unknown")

    local function notifyStarted()
        if onStarted ~= nil then onStarted() end
    end

    local function startAsMain()
        if g_server ~= nil and self.leaderSelectDialog ~= nil then
            self:showLeaderSelectDialog(currentVehicle, function(leaderVehicle)
                if leaderVehicle == false then return end  -- user cancelled
                self:sendCommand(currentVehicle, "start", workflow.id, true, leaderVehicle)
                notifyStarted()
            end)
        else
            self:sendCommand(currentVehicle, "start", workflow.id, true, nil)
            notifyStarted()
        end
    end

    if self:hasSupportSteps(workflow.id) and self.modeSelectDialog ~= nil then
        -- Mode select first; leader dialog only shown when main role is chosen
        self:showModeSelectDialog(workflow.id, currentVehicle, function(isMain)
            if isMain == nil then return end  -- user cancelled
            if isMain then
                startAsMain()
            else
                self:sendCommand(currentVehicle, "start", workflow.id, false, nil)
                notifyStarted()
            end
        end)
    else
        -- No support steps: go straight to leader select then start as main
        startAsMain()
    end

    return true
end

---Show the leader vehicle selection dialog.
---Calls callback(leaderVehicle) where leaderVehicle may be nil (no leader chosen or cancelled=false).
---If no other vehicles are running workflows, calls callback(nil) immediately.
---@param currentVehicle table The vehicle that will run the follower workflow
---@param callback function callback(leaderVehicle|nil)
function WorkflowManager:showLeaderSelectDialog(currentVehicle, callback)
    if self.leaderSelectDialog == nil then
        callback(nil)
        return
    end
    self.leaderSelectDialog:setData(currentVehicle, callback)
    -- If no other vehicle is running a workflow, skip the dialog entirely.
    -- Opening then closing it inside onOpen() corrupts the GUI input-context stack.
    if self.leaderSelectDialog:buildVehicleList() == 0 then
        callback(nil)
        return
    end
    g_gui:showDialog("WMLeaderVehicleSelectDialog")
end

---Show the mode selection dialog (Main / Support / Cancel)
---@param workflowId string    Workflow to start
---@param vehicle    table     The vehicle that will run the workflow
---@param callback   function  Called with true (main), false (support), or nil (cancel)
function WorkflowManager:showModeSelectDialog(workflowId, vehicle, callback)
    if self.modeSelectDialog == nil then
        if callback then callback(true) end
        return
    end
    self.modeSelectDialog:setWorkflow(workflowId, vehicle, callback)
    g_gui:showDialog("WMModeSelectDialog")
end

-- ============================================================
-- Multiplayer network helpers
-- ============================================================

---Route a workflow command through the network layer.
---  • On the server (singleplayer or multiplayer host):
---      executes immediately and broadcasts state to clients.
---  • On a pure client:
---      sends a WMCommandEvent to the server.
---@param vehicle       table       Target vehicle
---@param commandType   string      "start"|"stop"|"pause"|"resume"|"next_step"|"prev_step"
---@param workflowId    string|nil  Only required for "start"
---@param isMain        boolean|nil true = main role, false = support role (only for "start")
---@param leaderVehicle table|nil   Optional leader vehicle for follower sync (server/SP only)
function WorkflowManager:sendCommand(vehicle, commandType, workflowId, isMain, leaderVehicle)
    if vehicle == nil then
        WMLogger:warning("sendCommand: vehicle is nil (cmd=%s)", commandType)
        return
    end
    if g_server ~= nil then
        -- Singleplayer or multiplayer host – execute directly
        self:executeNetworkCommand(commandType, vehicle, workflowId, isMain, leaderVehicle)
    else
        -- Pure multiplayer client – leader dialog is server/host-only; client starts without a leader
        if commandType == "start" then
            WMLogger:info("sendCommand: client path — leader-follower sync requires being the multiplayer host")
        end
        if g_client ~= nil then
            g_client:sendEvent(WMCommandEvent.new(commandType, vehicle, workflowId, isMain))
        else
            WMLogger:error("sendCommand: neither g_server nor g_client available")
        end
    end
end

---Execute a workflow command and broadcast state.  Called on the server only.
---@param commandType   string
---@param vehicle       table
---@param workflowId    string|nil
---@param isMain        boolean|nil  true = main role, false = support role (only for "start")
---@param leaderVehicle table|nil    Optional leader vehicle for follower sync
function WorkflowManager:executeNetworkCommand(commandType, vehicle, workflowId, isMain, leaderVehicle)
    if commandType == "start" then
        local wf = self:getWorkflowById(workflowId)
        if wf == nil then
            WMLogger:error("executeNetworkCommand: workflowId '%s' not found", tostring(workflowId))
            return
        end
        -- isMain defaults to true when not specified
        WMExecutor:startWorkflow(wf, vehicle, (isMain ~= false), leaderVehicle)
    elseif commandType == "stop" then
        WMExecutor:stopWorkflow(vehicle)
    elseif commandType == "pause" then
        WMExecutor:pauseWorkflow(vehicle)
    elseif commandType == "resume" then
        WMExecutor:resumeWorkflow(vehicle)
    elseif commandType == "next_step" then
        WMExecutor:goToNextStep(vehicle)
    elseif commandType == "prev_step" then
        WMExecutor:goToPreviousStep(vehicle)
    else
        WMLogger:warning("executeNetworkCommand: unknown commandType '%s'", tostring(commandType))
        return
    end
    self:broadcastState(vehicle)
end

---Broadcast a vehicle's current workflow state to all connected clients.
---No-op in singleplayer (no clients to send to).
---@param vehicle table Target vehicle
function WorkflowManager:broadcastState(vehicle)
    if g_server == nil then return end
    if self.isShuttingDown then return end
    if vehicle == nil then return end
    -- In singleplayer g_client is nil so broadcastEvent has nobody to send to – that's fine.
    g_server:broadcastEvent(WMStateSyncEvent.new(vehicle), false, nil, vehicle)
    WMLogger:debug("broadcastState: sent WMStateSyncEvent for vehicle")
end

---Add wrappers for goToNextStep / goToPreviousStep so they route via sendCommand.
---@param vehicle table
function WorkflowManager:goToNextStep(vehicle)
    self:sendCommand(vehicle, "next_step")
end

---@param vehicle table
function WorkflowManager:goToPreviousStep(vehicle)
    self:sendCommand(vehicle, "prev_step")
end

---Returns true if any step (or support sub-step) of the workflow is driven by AutoDrive.
---A workflow made only of Courseplay steps and sync markers runs without AutoDrive at all,
---so it must not be blocked on vehicles/setups that have no AutoDrive.
---A nil workflow is treated as "needs AutoDrive": callers without a workflow in hand cannot
---prove otherwise, and the conservative answer keeps the old validation behaviour.
---@param workflow table|nil Workflow definition
---@return boolean
function WorkflowManager:workflowNeedsAutoDrive(workflow)
    if workflow == nil or workflow.steps == nil then
        return true
    end

    for _, step in ipairs(workflow.steps) do
        if self:isAutoDriveTrackedStepType(step.type) then
            return true
        end
        for _, subStep in ipairs(step.support or {}) do
            if self:isAutoDriveTrackedStepType(subStep.type) then
                return true
            end
        end
    end

    return false
end

---Check if a vehicle supports running workflows
---Courseplay is always required. AutoDrive is required only when the workflow actually
---contains an AutoDrive-driven step (drive/park/refuel/repair) - see workflowNeedsAutoDrive.
---@param vehicle table Vehicle to validate
---@param workflow table|nil Workflow the vehicle should run (nil = require AutoDrive too)
---@return boolean valid True if the vehicle supports every step type the workflow uses
function WorkflowManager:isVehicleValid(vehicle, workflow)
    if vehicle == nil then
        return false
    end

    -- Check for AutoDrive support
    local hasAutoDrive = vehicle.ad ~= nil or vehicle.spec_autoDrive ~= nil

    -- Check for Courseplay support (multiple possible spec names)
    local hasCP = vehicle.spec_cpAIWorker ~= nil or
                  vehicle.spec_cpAIFieldWorker ~= nil or
                  (vehicle.getIsCpActive ~= nil)

    if not hasCP then
        return false
    end

    return hasAutoDrive or not self:workflowNeedsAutoDrive(workflow)
end

---Find the vehicle that has the given workflowId active (scan all active vehicles).
---@param workflowId string
---@return table|nil vehicle
local function findVehicleForWorkflow(workflowId)
    for v, _ in pairs(WMExecutor.activeVehicles) do
        local activeData = v.spec_workflowManagerSpec and v.spec_workflowManagerSpec.wmExecution
        if activeData and activeData.workflow and activeData.workflow.id == workflowId then
            return v
        end
    end
    return nil
end

---Stop the workflow running on the given workflowId.
---Routes through the network layer so it works in multiplayer.
---@param workflowId string Workflow ID to stop
---@return boolean success True if the command was dispatched successfully
function WorkflowManager:stopWorkflow(workflowId)
    local v = findVehicleForWorkflow(workflowId)
    if v == nil then
        WMLogger:warning("Cannot stop: Workflow %s not active on any vehicle", workflowId)
        return false
    end
    self:sendCommand(v, "stop")
    return true
end

---Pause the workflow running on the given workflowId.
---@param workflowId string Workflow ID to pause
---@return boolean success
function WorkflowManager:pauseWorkflow(workflowId)
    local v = findVehicleForWorkflow(workflowId)
    if v == nil then
        WMLogger:warning("Cannot pause: Workflow %s not active on any vehicle", workflowId)
        return false
    end
    self:sendCommand(v, "pause")
    return true
end

---Resume the paused workflow on the given workflowId.
---@param workflowId string Workflow ID to resume
---@return boolean success
function WorkflowManager:resumeWorkflow(workflowId)
    local v = findVehicleForWorkflow(workflowId)
    if v == nil then
        WMLogger:warning("Cannot resume: Workflow %s not active on any vehicle", workflowId)
        return false
    end
    self:sendCommand(v, "resume")
    return true
end

---Reset (stop) the workflow on the given workflowId.
---@param workflowId string Workflow ID to reset
---@return boolean success
function WorkflowManager:resetWorkflow(workflowId)
    return self:stopWorkflow(workflowId)
end

---Get the active execution state for a vehicle (for GUI state display)
---@param vehicle table Vehicle to query
---@return table|nil activeData Execution state or nil if not active
function WorkflowManager:getVehicleWorkflowState(vehicle)
    return WMExecutor:getActiveDataForVehicle(vehicle)
end

---Get all workflows
---@return table workflows List of all workflows
function WorkflowManager:getAllWorkflows()
    return self.workflows
end

---Get all workflows (alias for getAllWorkflows)
---@return table workflows List of all workflows
function WorkflowManager:getWorkflows()
    return self.workflows
end

---Save all workflows to XML
function WorkflowManager:saveWorkflows()
    WMStorage:saveWorkflows(self.workflows)
end

---Load workflows from XML
function WorkflowManager:loadWorkflows()
    self.workflows = WMStorage:loadWorkflows()
end

-- FS25 Event Listeners

---Called when map is loaded
function WorkflowManager:loadMap(name)
    WMLogger:info("Map loaded: %s", name)
    self:init()
    self:loadWorkflows()
    -- Per-vehicle workflow restore is handled by WorkflowManagerSpec:onPostLoad,
    -- which fires after this and has access to the now-populated self.workflows.
end

---Clear AD->CP handoffs and stop AD routes on every active vehicle, then forget them all.
---Deliberately does NOT stop Courseplay: stopCurrentAIJob during shutdown makes CP's deferred
---task cleanup run after game objects are torn down (nil-index errors in CpAITaskFieldWork).
---CP shuts itself down cleanly via its own handlers.
function WorkflowManager:releaseADForShutdown()
    for vehicle, _ in pairs(WMExecutor.activeVehicles) do
        -- A vehicle the engine already deleted must not be driven through AD's stop path
        if not vehicle.isDeleted then
            local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
            -- Clear AD->CP handoff flag FIRST to prevent AD from restarting CP during shutdown
            if activeData and activeData.vehicle then
                ADIntegration:clearCPHandoff(activeData.vehicle)
            end
            ADIntegration:stopRoute(vehicle)
        end
    end
    WMExecutor.activeVehicles = {}
end

---Called when map is deleted/unloaded
function WorkflowManager:deleteMap()
    WMLogger:info("Map unloading, cleaning up...")

    -- IMMEDIATELY set shuttingDown flag to prevent mouse events from triggering actions
    self.isShuttingDown = true

    -- IMMEDIATELY set isInitialized to false to stop update/draw processing
    self.isInitialized = false

    self:releaseADForShutdown()

    -- Save workflows
    self:saveWorkflows()

    -- Cleanup new dialog-based GUI
    self.mainDialog = nil
    self.editorDialog = nil
    self.stepDialog = nil
    self.textInputDialog = nil
    self.modeSelectDialog = nil
    self.adSettingsDialog = nil

    -- Remove the rows injected into the game's General settings page
    WMGameSettings:delete()

    -- Cleanup in-vehicle HUD (also releases the mouse cursor if WM forced it on)
    if WMHud and WMHud.delete then
        WMHud:delete()
    end

    -- Unregister developer console commands
    WMConsoleCommands:delete()

    -- Reset remaining state
    self.guiVisible = false
    self.globalActionsRegistered = false
    self.isShuttingDown = false

    WMLogger:info("WorkflowManager cleanup completed")
end

---Called every frame
---@param dt number Delta time in milliseconds
function WorkflowManager:update(dt)
    if not self.isInitialized or self.isShuttingDown then
        return
    end

    -- Update integrations (retry detection if not yet available)
    ADIntegration:update(dt)
    CPIntegration:update(dt)
    CPCoursesLoader:update(dt)
    CPVehiclesLoader:update(dt)

    WMExecutor:update(dt)
    WMDebugUtil:update(dt)

    -- Update in-vehicle HUD
    WMHud:update(dt)
end

---Called for drawing
function WorkflowManager:draw()
    if not self.isInitialized or self.isShuttingDown then
        return
    end

    -- Draw debug overlay (if enabled)
    WMDebugUtil:draw()

    -- Draw in-vehicle HUD
    WMHud:draw()
end

---Called on key events
function WorkflowManager:keyEvent(unicode, sym, modifier, isDown)
end

---Called on mouse events
function WorkflowManager:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isInitialized or self.isShuttingDown then
        return
    end

    -- Forward mouse events to in-vehicle HUD
    WMHud:mouseEvent(posX, posY, isDown, isUp, button)
end

-- Register as mod event listener
addModEventListener(WorkflowManager)

-- Hook into game save event to save workflows when player saves the game
if FSBaseMission.saveSavegame ~= nil then
    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, function()
        if WorkflowManager.isInitialized then
            WMLogger:info("Game saving - persisting workflows")
            WorkflowManager:saveWorkflows()
        end
    end)
    WMLogger:info("Hooked FSBaseMission.saveSavegame for auto-save")
end

-- Hook into FSBaseMission.delete BEFORE the original runs to clear AD->CP handoff flags
-- and stop AD routes. We intentionally do NOT stop CP here because calling stopCurrentAIJob
-- during FSBaseMission.delete causes CP's deferred task cleanup to run after game objects
-- are already torn down, producing nil-index errors in CpAITaskFieldWork. CP handles its
-- own shutdown cleanly via its own hooks.
if FSBaseMission.delete ~= nil then
    FSBaseMission.delete = Utils.prependedFunction(FSBaseMission.delete, function()
        if not WorkflowManager.isInitialized then
            return
        end
        WorkflowManager.isShuttingDown = true
        WMLogger:info("FSBaseMission.delete - clearing AD handoffs and stopping AD routes before shutdown")
        WorkflowManager:releaseADForShutdown()
    end)
    WMLogger:info("Hooked FSBaseMission.delete for shutdown cleanup")
end

WMLogger:info("WorkflowManager module loaded")
