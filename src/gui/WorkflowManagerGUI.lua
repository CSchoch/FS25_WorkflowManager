--[[
    WorkflowManager - Main GUI
    Displays list of workflows and provides management controls

    Author: WorkflowManager Team
]]

---@class WMManagerGUI
WMManagerGUI = {}

WMManagerGUI.isVisible = false
WMManagerGUI.selectedWorkflowIndex = 0

-- GUI element references
WMManagerGUI.guiElement = nil
WMManagerGUI.workflowList = nil

---Initialize the GUI
function WMManagerGUI:init()
    WMLogger:debug("WorkflowManagerGUI initialized")
end

---Show the GUI
function WMManagerGUI:show()
    if self.isVisible then
        return
    end

    self.isVisible = true
    self:refresh()

    -- Show GUI using FS25 GUI system
    -- Note: Full implementation requires XML GUI definition
    WMLogger:debug("WorkflowManagerGUI shown")

    -- For now, use simple on-screen display
    -- Full GUI will be implemented when XML layouts are created
end

---Hide the GUI
function WMManagerGUI:hide()
    if not self.isVisible then
        return
    end

    self.isVisible = false
    WMLogger:debug("WorkflowManagerGUI hidden")
end

---Toggle GUI visibility
function WMManagerGUI:toggle()
    if self.isVisible then
        self:hide()
    else
        self:show()
    end
end

---Refresh the workflow list
function WMManagerGUI:refresh()
    if not self.isVisible then
        return
    end

    -- Get all workflows
    local workflows = WorkflowManager:getAllWorkflows()

    -- Update list display
    -- Full implementation will update GUI elements
    WMLogger:debug("Refreshed workflow list: %d workflows", #workflows)
end

---Handle workflow selection
---@param index number Selected index
function WMManagerGUI:onWorkflowSelected(index)
    self.selectedWorkflowIndex = index
    WMLogger:debug("Selected workflow index: %d", index)
end

---Handle "New" button click
function WMManagerGUI:onNewClick()
    WMLogger:debug("New workflow button clicked")

    -- Create new workflow
    local workflow = WorkflowManager:createWorkflow("New Workflow")

    -- Open editor for the new workflow
    WMEditorGUI:openWorkflow(workflow)

    self:refresh()
end

---Handle "Edit" button click
function WMManagerGUI:onEditClick()
    if self.selectedWorkflowIndex <= 0 then
        WMLogger:warning("No workflow selected for editing")
        return
    end

    local workflows = WorkflowManager:getAllWorkflows()
    local workflow = workflows[self.selectedWorkflowIndex]

    if workflow ~= nil then
        WMEditorGUI:openWorkflow(workflow)
    end
end

---Handle "Delete" button click
function WMManagerGUI:onDeleteClick()
    if self.selectedWorkflowIndex <= 0 then
        WMLogger:warning("No workflow selected for deletion")
        return
    end

    local workflows = WorkflowManager:getAllWorkflows()
    local workflow = workflows[self.selectedWorkflowIndex]

    if workflow ~= nil then
        WorkflowManager:deleteWorkflow(workflow.id)
        self.selectedWorkflowIndex = 0
        self:refresh()
    end
end

---Handle "Start" button click
function WMManagerGUI:onStartClick()
    if self.selectedWorkflowIndex <= 0 then
        WMLogger:warning("No workflow selected to start")
        return
    end

    local workflows = WorkflowManager:getAllWorkflows()
    local workflow = workflows[self.selectedWorkflowIndex]

    if workflow ~= nil then
        WorkflowManager:startWorkflow(workflow.id)
        self:refresh()
    end
end

---Handle "Stop" button click
function WMManagerGUI:onStopClick()
    if self.selectedWorkflowIndex <= 0 then
        WMLogger:warning("No workflow selected to stop")
        return
    end

    local workflows = WorkflowManager:getAllWorkflows()
    local workflow = workflows[self.selectedWorkflowIndex]

    if workflow ~= nil then
        WorkflowManager:stopWorkflow(workflow.id)
        self:refresh()
    end
end

---Handle "Pause" button click
function WMManagerGUI:onPauseClick()
    if self.selectedWorkflowIndex <= 0 then
        return
    end

    local workflows = WorkflowManager:getAllWorkflows()
    local workflow = workflows[self.selectedWorkflowIndex]

    if workflow ~= nil then
        if workflow.status == WorkflowManager.STATUS_RUNNING then
            WorkflowManager:pauseWorkflow(workflow.id)
        elseif workflow.status == WorkflowManager.STATUS_PAUSED then
            WorkflowManager:resumeWorkflow(workflow.id)
        end
        self:refresh()
    end
end

---Draw the GUI (called each frame when visible)
function WMManagerGUI:draw()
    if not self.isVisible then
        return
    end

    -- Simple text-based display for development
    -- Will be replaced with proper GUI elements
    local workflows = WorkflowManager:getAllWorkflows()

    -- Draw header
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(0.3, 0.9, 0.025, "Workflow Manager")
    setTextBold(false)

    -- Draw workflow list
    local y = 0.85
    for i, workflow in ipairs(workflows) do
        local statusText = workflow.status
        if workflow.status == WorkflowManager.STATUS_RUNNING then
            statusText = string.format("Running (%d/%d)", workflow.currentStep, #workflow.steps)
        end

        local color = {1, 1, 1, 1}
        if i == self.selectedWorkflowIndex then
            color = {0.2, 0.8, 0.2, 1}
        end
        setTextColor(color[1], color[2], color[3], color[4])

        local text = string.format("%d. %s - %s [%s]",
            i, workflow.name, statusText, #workflow.steps .. " steps")
        renderText(0.3, y, 0.018, text)

        y = y - 0.025
    end

    if #workflows == 0 then
        setTextColor(0.7, 0.7, 0.7, 1)
        renderText(0.3, y, 0.018, "No workflows created yet")
    end

    -- Draw controls hint
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(0.3, 0.15, 0.015, "Press Alt+W to close | Ctrl+Alt+W to start | Shift+Alt+W to stop")
end

---Update function
---@param dt number Delta time
function WMManagerGUI:update(dt)
    if not self.isVisible then
        return
    end

    -- Handle input for selection
    -- Full implementation will use proper GUI input handling
end
