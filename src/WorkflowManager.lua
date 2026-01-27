--[[
    WorkflowManager - Main Entry Point
    Combines AutoDrive and Courseplay for automated field workflows

    Author: WorkflowManager Team
    Version: 1.0.0.0
]]

-- Source all required files (order matters for dependencies)
-- 1. Development config (loaded first to configure debug settings)
source(Utils.getFilename("src/DevConfig.lua", g_currentModDirectory))

-- 2. Utilities
source(Utils.getFilename("src/utils/Logger.lua", g_currentModDirectory))
source(Utils.getFilename("src/utils/EventHandler.lua", g_currentModDirectory))
source(Utils.getFilename("src/utils/DebugUtil.lua", g_currentModDirectory))

-- 3. Core modules
source(Utils.getFilename("src/WorkflowStorage.lua", g_currentModDirectory))
source(Utils.getFilename("src/WorkflowExecutor.lua", g_currentModDirectory))

-- 4. Integration modules
source(Utils.getFilename("src/integration/AutoDriveIntegration.lua", g_currentModDirectory))
source(Utils.getFilename("src/integration/CourseplayIntegration.lua", g_currentModDirectory))
source(Utils.getFilename("src/integration/CourseplayCoursesLoader.lua", g_currentModDirectory))
source(Utils.getFilename("src/integration/CourseplayVehiclesLoader.lua", g_currentModDirectory))

-- 5. GUI modules (legacy draw-based - kept for reference)
source(Utils.getFilename("src/gui/WorkflowManagerGUI.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WorkflowEditorGUI.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WorkflowManagerMenuFrame.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMTextInputDialog.lua", g_currentModDirectory))

-- 6. New dialog-based GUI (proper input blocking)
source(Utils.getFilename("src/gui/WMMainDialog.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMEditorDialog.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMStepDialog.lua", g_currentModDirectory))

-- 7. In-vehicle HUD
source(Utils.getFilename("src/gui/WMHudElements.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WMHud.lua", g_currentModDirectory))

-- Initialize logger from dev config immediately after loading
WMLogger:initFromDevConfig()

---@class WorkflowManager
WorkflowManager = {}
WorkflowManager.version = "1.0.0.0"
WorkflowManager.modName = g_currentModName
WorkflowManager.modDirectory = g_currentModDirectory

-- Workflow status constants
WorkflowManager.STATUS_READY = "ready"
WorkflowManager.STATUS_RUNNING = "running"
WorkflowManager.STATUS_PAUSED = "paused"
WorkflowManager.STATUS_COMPLETED = "completed"
WorkflowManager.STATUS_ERROR = "error"

-- Step type constants
WorkflowManager.STEP_AUTODRIVE = "autodrive"
WorkflowManager.STEP_COURSEPLAY = "courseplay"

-- Internal state
WorkflowManager.workflows = {}
WorkflowManager.activeWorkflows = {}
WorkflowManager.isInitialized = false
WorkflowManager.isShuttingDown = false
WorkflowManager.guiVisible = false

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

    -- Initialize legacy GUI (kept for fallback)
    WMManagerGUI:init()
    WMEditorGUI:init()

    -- Initialize in-vehicle HUD
    local hudSuccess, hudErr = pcall(function()
        WMHud:init()
    end)
    if not hudSuccess then
        WMLogger:error("Failed to initialize WMHud: %s", tostring(hudErr))
    end

    -- Subscribe to workflow events to show/hide HUD automatically
    WMEventHandler:subscribe(WMEventHandler.EVENT_WORKFLOW_STARTED, self, self.onWorkflowStartedEvent)
    WMEventHandler:subscribe(WMEventHandler.EVENT_WORKFLOW_STOPPED, self, self.onWorkflowStoppedEvent)
    WMEventHandler:subscribe(WMEventHandler.EVENT_WORKFLOW_COMPLETED, self, self.onWorkflowCompletedEvent)

    -- Load new dialog-based GUI (proper input blocking)
    self:loadDialogs()

    -- Setup InGameMenu integration
    self:setupInGameMenu()

    -- Register input actions (fallback for direct access)
    self:registerInputActions()

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

    -- Load Text Input Dialog
    self.textInputDialog = WMTextInputDialog.new()
    local xmlPath = Utils.getFilename("xml/gui/TextInputDialog.xml", self.modDirectory)
    local success, result = pcall(function()
        g_gui:loadGui(xmlPath, "WMTextInputDialog", self.textInputDialog)
    end)
    if success then
        WMLogger:info("Text input dialog loaded successfully")
    else
        WMLogger:warning("Failed to load text input dialog: %s", tostring(result))
        self.textInputDialog = nil
    end

    -- Load Main Dialog
    self.mainDialog = WMMainDialog.new()
    xmlPath = Utils.getFilename("xml/gui/WMMainDialog.xml", self.modDirectory)
    success, result = pcall(function()
        g_gui:loadGui(xmlPath, "WMMainDialog", self.mainDialog)
    end)
    if success then
        WMLogger:info("Main dialog loaded successfully")
    else
        WMLogger:warning("Failed to load main dialog: %s", tostring(result))
        self.mainDialog = nil
    end

    -- Load Editor Dialog
    self.editorDialog = WMEditorDialog.new()
    xmlPath = Utils.getFilename("xml/gui/WMEditorDialog.xml", self.modDirectory)
    success, result = pcall(function()
        g_gui:loadGui(xmlPath, "WMEditorDialog", self.editorDialog)
    end)
    if success then
        WMLogger:info("Editor dialog loaded successfully")
    else
        WMLogger:warning("Failed to load editor dialog: %s", tostring(result))
        self.editorDialog = nil
    end

    -- Load Step Dialog
    self.stepDialog = WMStepDialog.new()
    xmlPath = Utils.getFilename("xml/gui/WMStepDialog.xml", self.modDirectory)
    success, result = pcall(function()
        g_gui:loadGui(xmlPath, "WMStepDialog", self.stepDialog)
    end)
    if success then
        WMLogger:info("Step dialog loaded successfully")
    else
        WMLogger:warning("Failed to load step dialog: %s", tostring(result))
        self.stepDialog = nil
    end
end

---Show the text input dialog
---@param title string Dialog title
---@param text string Initial text value
---@param callback function Callback function(text, confirmed)
---@param target table Callback target object (optional)
function WorkflowManager:showTextInputDialog(title, text, callback, target)
    if self.textInputDialog == nil then
        WMLogger:warning("Text input dialog not available")
        if callback then
            callback(text, false)
        end
        return
    end

    self.textInputDialog:setTitle(title)
    self.textInputDialog:setText(text)
    self.textInputDialog:setCallback(callback, target)

    g_gui:showDialog("WMTextInputDialog")
end

---Setup InGameMenu integration
---Adds a "Workflow Manager" tab to the ESC menu
---NOTE: Currently disabled due to cleanup issues causing errors with other mods
function WorkflowManager:setupInGameMenu()
    -- DISABLED: InGameMenu integration causes state corruption during cleanup
    -- that triggers errors in other mods like Courseplay.
    -- Use standalone GUI (Alt+W or F9) instead.
    -- TODO: Re-enable when proper page registration/unregistration is implemented
    WMLogger:info("InGameMenu integration disabled - use Alt+W or F9 to open GUI")
    return

    --[[ Original implementation preserved for future use:
    WMLogger:debug("Setting up InGameMenu integration...")

    -- Check if required GUI classes exist
    if g_gui == nil then
        WMLogger:warning("g_gui not available, skipping InGameMenu integration")
        return
    end

    -- Create the menu frame instance (with error handling)
    local success, result = pcall(function()
        return WMMenuFrame.new()
    end)

    if not success then
        WMLogger:error("Failed to create menu frame: %s", tostring(result))
        WMLogger:info("InGameMenu integration disabled - using standalone GUI only")
        return
    end

    self.menuFrame = result

    -- Load the GUI from XML
    local xmlPath = Utils.getFilename("xml/gui/WorkflowManagerMenuFrame.xml", self.modDirectory)
    success, result = pcall(function()
        g_gui:loadGui(xmlPath, "WorkflowManagerMenuFrame", self.menuFrame)
    end)

    if not success then
        WMLogger:error("Failed to load menu frame XML: %s", tostring(result))
        WMLogger:info("InGameMenu integration disabled - using standalone GUI only")
        self.menuFrame = nil
        return
    end

    WMLogger:info("Menu frame loaded successfully")

    -- Register to add tab to InGameMenu when it's ready
    -- We need to wait until after the InGameMenu is initialized
    if g_inGameMenu ~= nil then
        self:addPageToInGameMenu()
    else
        -- Schedule for later when InGameMenu becomes available
        WMLogger:debug("InGameMenu not ready, will add page later")
        self.pendingMenuRegistration = true
    end
    --]]
end

---Add the Workflow Manager page to the InGameMenu
function WorkflowManager:addPageToInGameMenu()
    if g_inGameMenu == nil then
        WMLogger:warning("Cannot add page to InGameMenu - g_inGameMenu is nil")
        return false
    end

    if self.menuFrame == nil then
        WMLogger:warning("Cannot add page to InGameMenu - menuFrame is nil")
        return false
    end

    WMLogger:info("Adding Workflow Manager page to InGameMenu...")

    -- Debug: Log available methods on g_inGameMenu
    WMLogger:debug("InGameMenu type: %s", type(g_inGameMenu))
    if type(g_inGameMenu) == "table" then
        local methods = {}
        for k, v in pairs(g_inGameMenu) do
            if type(v) == "function" then
                table.insert(methods, k)
            end
        end
        WMLogger:debug("InGameMenu methods: %s", table.concat(methods, ", "):sub(1, 200))
    end

    local success, err = pcall(function()
        local inGameMenu = g_inGameMenu

        -- Check what methods are available
        local hasRegisterPage = inGameMenu.registerPage ~= nil
        local hasAddPageTab = inGameMenu.addPageTab ~= nil
        local hasPagingElement = inGameMenu.pagingElement ~= nil

        WMLogger:debug("InGameMenu capabilities: registerPage=%s, addPageTab=%s, pagingElement=%s",
            tostring(hasRegisterPage), tostring(hasAddPageTab), tostring(hasPagingElement))

        if not hasRegisterPage or not hasAddPageTab then
            WMLogger:warning("InGameMenu missing required methods, cannot add page")
            return
        end

        -- Add frame to the paging element
        if hasPagingElement and inGameMenu.pagingElement.addElement then
            inGameMenu.pagingElement:addElement(self.menuFrame)
        end

        -- Register the page (position at end, always available)
        local pageIndex = 99  -- Use high number to add at end
        if inGameMenu.getNumPages then
            pageIndex = inGameMenu:getNumPages() + 1
        elseif hasPagingElement and inGameMenu.pagingElement.getPageCount then
            pageIndex = inGameMenu.pagingElement:getPageCount() + 1
        end

        local alwaysAvailable = function() return true end
        inGameMenu:registerPage(self.menuFrame, pageIndex, alwaysAvailable)

        -- Add a tab for the page with icon
        -- Use our white.png texture as a placeholder icon
        local iconPath = Utils.getFilename("textures/white.png", self.modDirectory)
        local uvs = GuiUtils.getUVs({0, 0, 1, 1})
        inGameMenu:addPageTab(self.menuFrame, iconPath, uvs)

        -- Update the page mapping
        if hasPagingElement then
            if inGameMenu.pagingElement.updateAbsolutePosition then
                inGameMenu.pagingElement:updateAbsolutePosition()
            end
            if inGameMenu.pagingElement.updatePageMapping then
                inGameMenu.pagingElement:updatePageMapping()
            end
        end

        -- Rebuild tab list
        if inGameMenu.rebuildTabList ~= nil then
            inGameMenu:rebuildTabList()
        end
    end)

    if success then
        WMLogger:info("Successfully added Workflow Manager page to InGameMenu")
        self.menuPageAdded = true
        return true
    else
        WMLogger:error("Failed to add page to InGameMenu: %s", tostring(err))
        return false
    end
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
    local success, result = pcall(function()
        local _, eventId = g_inputBinding:registerActionEvent(
            "WM_TOGGLE_GUI",
            self,
            self.onToggleGUI,
            false,  -- triggerUp
            true,   -- triggerDown
            false,  -- triggerAlways
            true    -- startActive
        )
        return eventId
    end)

    if success then
        if result ~= nil then
            g_inputBinding:setActionEventTextVisibility(result, true)
            g_inputBinding:setActionEventTextPriority(result, GS_PRIO_NORMAL)
            WMLogger:info("Registered global input action WM_TOGGLE_GUI (eventId: %s)", tostring(result))
        else
            WMLogger:warning("Input action WM_TOGGLE_GUI registered but eventId is nil")
        end
    else
        WMLogger:error("Failed to register input action WM_TOGGLE_GUI: %s", tostring(result))
    end

    -- Register WM_START_WORKFLOW
    success, result = pcall(function()
        local _, eventId = g_inputBinding:registerActionEvent(
            "WM_START_WORKFLOW",
            self,
            self.onStartWorkflowInput,
            false, true, false, true
        )
        return eventId
    end)
    if success and result then
        g_inputBinding:setActionEventTextVisibility(result, false)
        WMLogger:debug("Registered WM_START_WORKFLOW")
    end

    -- Register WM_STOP_WORKFLOW
    success, result = pcall(function()
        local _, eventId = g_inputBinding:registerActionEvent(
            "WM_STOP_WORKFLOW",
            self,
            self.onStopWorkflowInput,
            false, true, false, true
        )
        return eventId
    end)
    if success and result then
        g_inputBinding:setActionEventTextVisibility(result, false)
        WMLogger:debug("Registered WM_STOP_WORKFLOW")
    end

    -- Register WM_TOGGLE_HUD
    success, result = pcall(function()
        local _, eventId = g_inputBinding:registerActionEvent(
            "WM_TOGGLE_HUD",
            self,
            self.onToggleHUD,
            false, true, false, true
        )
        return eventId
    end)
    if success and result then
        g_inputBinding:setActionEventTextVisibility(result, false)
        WMLogger:debug("Registered WM_TOGGLE_HUD")
    end
end

---Called when start workflow input is triggered
function WorkflowManager:onStartWorkflowInput()
    WMLogger:debug("Start workflow input triggered")
    -- Start selected workflow if GUI is open
    if WMManagerGUI.isVisible and WMManagerGUI.selectedWorkflowIndex > 0 then
        local workflows = self:getAllWorkflows()
        local workflow = workflows[WMManagerGUI.selectedWorkflowIndex]
        if workflow then
            self:startWorkflow(workflow.id)
        end
    end
end

---Called when stop workflow input is triggered
function WorkflowManager:onStopWorkflowInput()
    WMLogger:debug("Stop workflow input triggered")
    -- Stop selected workflow if GUI is open
    if WMManagerGUI.isVisible and WMManagerGUI.selectedWorkflowIndex > 0 then
        local workflows = self:getAllWorkflows()
        local workflow = workflows[WMManagerGUI.selectedWorkflowIndex]
        if workflow then
            self:stopWorkflow(workflow.id)
        end
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
    local vehicle = g_currentMission.controlledVehicle
    if vehicle then
        WMHud:toggle(vehicle)
    end
end

---Called when a workflow starts - show HUD
---@param eventType string Event type
---@param data table Event data
function WorkflowManager:onWorkflowStartedEvent(eventType, data)
    WMLogger:info("Workflow started event received for: %s", tostring(data.workflowId))

    -- Get the vehicle for this workflow
    local activeData = WMExecutor.activeWorkflows[data.workflowId]
    if activeData and activeData.vehicle then
        WMLogger:info("Showing HUD for workflow vehicle")
        WMHud:show(activeData.vehicle)
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
    local currentVehicle = g_currentMission.controlledVehicle
    if currentVehicle == nil then
        return
    end

    -- Check if there are any active workflows for this vehicle
    local hasActiveWorkflow = false
    for _, activeData in pairs(WMExecutor.activeWorkflows) do
        if activeData.vehicle == currentVehicle then
            hasActiveWorkflow = true
            break
        end
    end

    -- Hide HUD if no active workflows
    if not hasActiveWorkflow and WMHud:getIsVisible() then
        WMHud:hide()
    end
end

---Show the main workflow list dialog
function WorkflowManager:showMainDialog()
    if self.mainDialog == nil then
        WMLogger:warning("Main dialog not available, falling back to legacy GUI")
        self.guiVisible = not self.guiVisible
        if self.guiVisible then
            WMManagerGUI:show()
        else
            WMManagerGUI:hide()
        end
        return
    end

    g_gui:showDialog("WMMainDialog")
end

---Show the workflow editor dialog
---@param workflow table Workflow to edit
function WorkflowManager:showEditorDialog(workflow)
    if self.editorDialog == nil then
        WMLogger:warning("Editor dialog not available")
        return
    end

    self.editorDialog:setWorkflow(workflow)
    g_gui:showDialog("WMEditorDialog")
end

---Show the step add/edit dialog
---@param step table|nil Step to edit, or nil for new step
---@param callback function Callback when done: callback(step) or callback(nil) if cancelled
function WorkflowManager:showStepDialog(step, callback)
    if self.stepDialog == nil then
        WMLogger:warning("Step dialog not available")
        if callback then
            callback(nil)
        end
        return
    end

    self.stepDialog:setStep(step, callback)
    g_gui:showDialog("WMStepDialog")
end

---Create a new workflow
---@param name string Name of the workflow
---@return table workflow The created workflow
function WorkflowManager:createWorkflow(name)
    local workflow = {
        id = self:generateWorkflowId(),
        name = name or "New Workflow",
        -- NOTE: vehicle is no longer stored with workflow (Milestone 4)
        -- Vehicle is detected at runtime when starting the workflow
        steps = {},
        currentStep = 1,
        status = self.STATUS_READY,
        createdAt = getDate("%Y-%m-%d %H:%M:%S")
    }

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

---Delete a workflow
---@param id string Workflow ID to delete
---@return boolean success True if deleted successfully
function WorkflowManager:deleteWorkflow(id)
    for i, workflow in ipairs(self.workflows) do
        if workflow.id == id then
            -- Stop if running
            if workflow.status == self.STATUS_RUNNING then
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
        type = stepType,
        target = target,
        action = action or "default"
    }

    table.insert(workflow.steps, step)
    WMLogger:debug("Added step to workflow %s: type=%s, target=%s", workflowId, stepType, target)

    return true
end

---Start a workflow
---Uses the current vehicle the player is driving (Milestone 4)
---@param workflowId string Workflow ID to start
---@return boolean success True if started successfully
function WorkflowManager:startWorkflow(workflowId)
    local workflow = self:getWorkflowById(workflowId)
    if workflow == nil then
        WMLogger:error("Cannot start: Workflow %s not found", workflowId)
        return false
    end

    if workflow.status == self.STATUS_RUNNING then
        WMLogger:warning("Workflow %s is already running", workflowId)
        return false
    end

    if #workflow.steps == 0 then
        WMLogger:error("Cannot start: Workflow %s has no steps", workflowId)
        return false
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
        return false
    end

    -- Validate vehicle has required AutoDrive + Courseplay support
    if not self:isVehicleValid(currentVehicle) then
        local vehicleName = currentVehicle.getName and currentVehicle:getName() or "unknown"
        -- Show in-game warning to user
        local warningText = string.format(g_i18n:getText("wm_warning_incompatible_vehicle") or "Vehicle '%s' needs AutoDrive + Courseplay", vehicleName)
        if g_currentMission and g_currentMission.hud and g_currentMission.hud.showBlinkingWarning then
            g_currentMission.hud:showBlinkingWarning(warningText, 2000)
        end
        WMLogger:warning("Cannot start: Vehicle '%s' does not support workflows (needs AutoDrive + Courseplay)", vehicleName)
        return false
    end

    WMLogger:info("Starting workflow '%s' with vehicle: %s",
        workflow.name,
        currentVehicle.getName and currentVehicle:getName() or "unknown")

    -- Pass the current vehicle to the executor
    return WMExecutor:startWorkflow(workflow, currentVehicle)
end

---Check if a vehicle supports running workflows
---Requires both AutoDrive and Courseplay specs
---@param vehicle table Vehicle to validate
---@return boolean valid True if vehicle has AutoDrive and Courseplay support
function WorkflowManager:isVehicleValid(vehicle)
    if vehicle == nil then
        return false
    end

    -- Check for AutoDrive support
    local hasAutoDrive = vehicle.ad ~= nil or vehicle.spec_autoDrive ~= nil

    -- Check for Courseplay support (multiple possible spec names)
    local hasCP = vehicle.spec_cpAIWorker ~= nil or
                  vehicle.spec_cpAIFieldWorker ~= nil or
                  (vehicle.getIsCpActive ~= nil)

    return hasAutoDrive and hasCP
end

---Stop a running workflow
---@param workflowId string Workflow ID to stop
---@return boolean success True if stopped successfully
function WorkflowManager:stopWorkflow(workflowId)
    local workflow = self:getWorkflowById(workflowId)
    if workflow == nil then
        WMLogger:error("Cannot stop: Workflow %s not found", workflowId)
        return false
    end

    return WMExecutor:stopWorkflow(workflow)
end

---Pause a running workflow
---@param workflowId string Workflow ID to pause
---@return boolean success True if paused successfully
function WorkflowManager:pauseWorkflow(workflowId)
    local workflow = self:getWorkflowById(workflowId)
    if workflow == nil then
        WMLogger:error("Cannot pause: Workflow %s not found", workflowId)
        return false
    end

    return WMExecutor:pauseWorkflow(workflow)
end

---Resume a paused workflow
---@param workflowId string Workflow ID to resume
---@return boolean success True if resumed successfully
function WorkflowManager:resumeWorkflow(workflowId)
    local workflow = self:getWorkflowById(workflowId)
    if workflow == nil then
        WMLogger:error("Cannot resume: Workflow %s not found", workflowId)
        return false
    end

    return WMExecutor:resumeWorkflow(workflow)
end

---DEPRECATED: Vehicles are now detected at runtime when starting a workflow (Milestone 4)
---This function is kept for backward compatibility but does nothing
---@param workflowId string Workflow ID
---@param vehicle table Vehicle object (ignored)
---@return boolean success Always returns true
function WorkflowManager:assignVehicle(workflowId, vehicle)
    WMLogger:debug("assignVehicle called but ignored (deprecated - vehicles detected at runtime)")
    return true
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
end

---Called when map is deleted/unloaded
function WorkflowManager:deleteMap()
    WMLogger:info("Map unloading, cleaning up...")

    -- IMMEDIATELY set shuttingDown flag to prevent mouse events from triggering actions
    self.isShuttingDown = true

    -- IMMEDIATELY set isInitialized to false to stop update/draw processing
    self.isInitialized = false

    -- Stop all active workflows before cleanup to prevent CP/AD errors during shutdown
    pcall(function()
        for workflowId, activeData in pairs(WMExecutor.activeWorkflows) do
            -- Clear AD->CP handoff flag FIRST to prevent AD from restarting CP during shutdown
            if activeData.vehicle then
                pcall(function() ADIntegration:clearCPHandoff(activeData.vehicle) end)
            end

            local workflow = activeData.workflow
            if workflow then
                WMLogger:info("Stopping active workflow during shutdown: %s", workflow.name or workflowId)
                pcall(function()
                    WMExecutor:stopWorkflow(workflow)
                end)
            end
        end
        -- Clear any remaining active workflows
        WMExecutor.activeWorkflows = {}
    end)

    -- Save workflows
    pcall(function()
        self:saveWorkflows()
    end)

    -- Cleanup GUI resources (mark overlays as nil so they won't be used)
    pcall(function()
        if WMManagerGUI and WMManagerGUI.cleanup then
            WMManagerGUI:cleanup()
        end
    end)

    pcall(function()
        if WMEditorGUI and WMEditorGUI.cleanup then
            WMEditorGUI:cleanup()
        end
    end)

    -- Cleanup menu frame if it exists (currently disabled, but kept for future use)
    pcall(function()
        if self.menuFrame ~= nil then
            WMLogger:debug("Cleaning up menu frame...")
            if self.menuFrame.delete then
                self.menuFrame:delete()
            end
            self.menuFrame = nil
        end
    end)

    -- Cleanup new dialog-based GUI
    pcall(function()
        if self.mainDialog ~= nil then
            self.mainDialog = nil
        end
        if self.editorDialog ~= nil then
            self.editorDialog = nil
        end
        if self.stepDialog ~= nil then
            self.stepDialog = nil
        end
        if self.textInputDialog ~= nil then
            self.textInputDialog = nil
        end
    end)

    -- Cleanup in-vehicle HUD
    pcall(function()
        if WMHud and WMHud.delete then
            WMHud:delete()
        end
    end)

    -- Reset remaining state
    self.guiVisible = false
    self.menuPageAdded = false
    self.pendingMenuRegistration = false
    self.globalActionsRegistered = false
    self.isShuttingDown = false

    WMLogger:info("WorkflowManager cleanup completed")
end

-- Track key state for manual detection
WorkflowManager.lastF9State = false

---Called every frame
---@param dt number Delta time in milliseconds
function WorkflowManager:update(dt)
    if not self.isInitialized or self.isShuttingDown then
        return
    end

    -- Check for pending InGameMenu registration
    if self.pendingMenuRegistration and g_inGameMenu ~= nil then
        self.pendingMenuRegistration = false
        self:addPageToInGameMenu()
    end

    -- Update integrations (retry detection if not yet available)
    ADIntegration:update(dt)
    CPIntegration:update(dt)
    CPCoursesLoader:update(dt)
    CPVehiclesLoader:update(dt)

    -- Manual F9 key detection as fallback (for debugging)
    local f9Pressed = false
    if Input ~= nil and Input.isKeyPressed ~= nil then
        f9Pressed = Input.isKeyPressed(Input.KEY_F9)
    end

    if f9Pressed and not self.lastF9State then
        WMLogger:info("F9 key detected via manual check!")
        self:onToggleGUI()
    end
    self.lastF9State = f9Pressed

    WMExecutor:update(dt)
    WMDebugUtil:update(dt)
    WMManagerGUI:update(dt)
    WMEditorGUI:update(dt)

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

    -- Draw GUI
    WMManagerGUI:draw()
    WMEditorGUI:draw()

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

    -- Forward mouse events to in-vehicle HUD first
    if WMHud:mouseEvent(posX, posY, isDown, isUp, button) then
        return  -- HUD consumed the event
    end

    -- Handle scroll wheel (button 4 = scroll up, button 5 = scroll down in some systems)
    -- In FS25, scroll is often communicated via isDown with specific button values
    if button == 4 and isDown then
        -- Scroll up
        if WMEditorGUI.isVisible and WMEditorGUI:onScrollEvent(1) then
            return
        end
    elseif button == 5 and isDown then
        -- Scroll down
        if WMEditorGUI.isVisible and WMEditorGUI:onScrollEvent(-1) then
            return
        end
    end

    -- Forward mouse events to GUI
    WMManagerGUI:onMouseEvent(posX, posY, isDown, isUp, button)
    WMEditorGUI:onMouseEvent(posX, posY, isDown, isUp, button)
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

-- Hook into FSBaseMission.delete BEFORE the original runs to stop active workflows
-- and clear AD->CP handoff flags before the game destroys vehicles/tasks.
-- This prevents the CpAITaskDriveTo nil vehicle error during quit.
if FSBaseMission.delete ~= nil then
    FSBaseMission.delete = Utils.prependedFunction(FSBaseMission.delete, function()
        pcall(function()
            if not WorkflowManager.isInitialized then
                return
            end
            WorkflowManager.isShuttingDown = true
            WMLogger:info("FSBaseMission.delete - stopping active workflows before shutdown")
            for workflowId, activeData in pairs(WMExecutor.activeWorkflows) do
                -- Clear AD->CP handoff flag FIRST to prevent AD from restarting CP
                if activeData.vehicle then
                    pcall(function() ADIntegration:clearCPHandoff(activeData.vehicle) end)
                end
                -- Stop AD and CP on this vehicle
                if activeData.vehicle then
                    pcall(function() ADIntegration:stopRoute(activeData.vehicle) end)
                    pcall(function() CPIntegration:stopCourse(activeData.vehicle) end)
                end
            end
            WMExecutor.activeWorkflows = {}
        end)
    end)
    WMLogger:info("Hooked FSBaseMission.delete for shutdown cleanup")
end

WMLogger:info("WorkflowManager module loaded")
