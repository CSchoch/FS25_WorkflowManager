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

-- 5. GUI modules
source(Utils.getFilename("src/gui/WorkflowManagerGUI.lua", g_currentModDirectory))
source(Utils.getFilename("src/gui/WorkflowEditorGUI.lua", g_currentModDirectory))

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
    WMDebugUtil:init()

    -- Initialize GUI
    WMManagerGUI:init()
    WMEditorGUI:init()

    -- Register input actions
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

---Register input action bindings
function WorkflowManager:registerInputActions()
    -- Register action events for key bindings defined in modDesc.xml
    if g_inputBinding ~= nil then
        local _, eventId = g_inputBinding:registerActionEvent(
            InputAction.WM_TOGGLE_GUI,
            self,
            self.onToggleGUI,
            false,
            true,
            false,
            true
        )
        if eventId ~= nil then
            g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
            g_inputBinding:setActionEventText(eventId, g_i18n:getText("action_WM_TOGGLE_GUI"))
        end
    end
end

---Toggle the main GUI visibility
function WorkflowManager:onToggleGUI()
    self.guiVisible = not self.guiVisible
    if self.guiVisible then
        WMManagerGUI:show()
    else
        WMManagerGUI:hide()
    end
end

---Create a new workflow
---@param name string Name of the workflow
---@return table workflow The created workflow
function WorkflowManager:createWorkflow(name)
    local workflow = {
        id = self:generateWorkflowId(),
        name = name or "New Workflow",
        vehicle = nil,
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

    if workflow.vehicle == nil then
        WMLogger:error("Cannot start: Workflow %s has no vehicle assigned", workflowId)
        return false
    end

    return WMExecutor:startWorkflow(workflow)
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

---Assign a vehicle to a workflow
---@param workflowId string Workflow ID
---@param vehicle table Vehicle object
---@return boolean success True if assigned successfully
function WorkflowManager:assignVehicle(workflowId, vehicle)
    local workflow = self:getWorkflowById(workflowId)
    if workflow == nil then
        WMLogger:error("Cannot assign vehicle: Workflow %s not found", workflowId)
        return false
    end

    workflow.vehicle = vehicle
    WMLogger:debug("Assigned vehicle to workflow %s", workflowId)

    return true
end

---Get all workflows
---@return table workflows List of all workflows
function WorkflowManager:getAllWorkflows()
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
    WMLogger:info("Map unloading, saving workflows...")
    self:saveWorkflows()
    self.isInitialized = false
end

---Called every frame
---@param dt number Delta time in milliseconds
function WorkflowManager:update(dt)
    if not self.isInitialized then
        return
    end

    WMExecutor:update(dt)
    WMDebugUtil:update(dt)
    WMManagerGUI:update(dt)
    WMEditorGUI:update(dt)
end

---Called for drawing
function WorkflowManager:draw()
    if not self.isInitialized then
        return
    end

    -- Draw debug overlay (if enabled)
    WMDebugUtil:draw()

    -- Draw GUI
    WMManagerGUI:draw()
    WMEditorGUI:draw()
end

---Called on key events
function WorkflowManager:keyEvent(unicode, sym, modifier, isDown)
end

---Called on mouse events
function WorkflowManager:mouseEvent(posX, posY, isDown, isUp, button)
end

-- Register as mod event listener
addModEventListener(WorkflowManager)

WMLogger:info("WorkflowManager module loaded")
