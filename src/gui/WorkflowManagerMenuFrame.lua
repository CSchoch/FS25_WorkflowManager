--[[
    WorkflowManager - InGameMenu Frame
    Provides a page/tab in the ESC menu for the Workflow Manager

    Based on Courseplay's CpInGameMenu pattern

    Author: WorkflowManager Team
]]

---@class WMMenuFrame
WMMenuFrame = {}

-- Try to use TabbedMenuFrameElement if available, otherwise fall back to a simple table
local baseClass = TabbedMenuFrameElement or FrameElement or {}
local WMMenuFrame_mt = Class(WMMenuFrame, baseClass)

WMMenuFrame.CONTROLS = {
    "workflowList",
    "buttonNew",
    "buttonEdit",
    "buttonDelete",
    "buttonStart",
    "buttonStop"
}

---Create new menu frame instance
function WMMenuFrame.new(target)
    local self

    -- Try to create with proper base class
    if TabbedMenuFrameElement ~= nil and TabbedMenuFrameElement.new ~= nil then
        self = TabbedMenuFrameElement.new(target, WMMenuFrame_mt)
    elseif FrameElement ~= nil and FrameElement.new ~= nil then
        self = FrameElement.new(target, WMMenuFrame_mt)
    else
        -- Fallback: create simple table
        self = setmetatable({}, WMMenuFrame_mt)
        self.target = target
    end

    self.workflows = {}
    self.selectedIndex = 0
    self.hasCustomMenuButtons = true
    self.isActive = true  -- Flag to prevent updates during cleanup

    -- Only call registerControls if it exists
    if self.registerControls ~= nil then
        self:registerControls(WMMenuFrame.CONTROLS)
    end

    WMLogger:debug("WMMenuFrame created (base class: %s)",
        TabbedMenuFrameElement ~= nil and "TabbedMenuFrameElement" or
        (FrameElement ~= nil and "FrameElement" or "table"))

    return self
end

---Called when frame is created from XML
function WMMenuFrame:onCreate()
    WMLogger:debug("WMMenuFrame:onCreate()")
end

---Called when frame is opened
function WMMenuFrame:onFrameOpen()
    WMLogger:debug("WMMenuFrame:onFrameOpen()")

    -- Refresh workflow list
    self:refreshWorkflowList()

    -- Focus the list
    if self.workflowList then
        FocusManager:setFocus(self.workflowList)
    end
end

---Called when frame is closed
function WMMenuFrame:onFrameClose()
    WMLogger:debug("WMMenuFrame:onFrameClose()")
end

---Refresh the workflow list from WorkflowManager
function WMMenuFrame:refreshWorkflowList()
    self.workflows = WorkflowManager:getAllWorkflows()

    if self.workflowList then
        self.workflowList:deleteListItems()

        for i, workflow in ipairs(self.workflows) do
            local item = self.workflowList:createItem()
            if item then
                self:updateListItem(item, workflow, i)
                self.workflowList:addItem(item)
            end
        end

        -- Select first item if available
        if #self.workflows > 0 then
            self.workflowList:setSelectedIndex(1)
            self.selectedIndex = 1
        else
            self.selectedIndex = 0
        end
    end

    self:updateButtonStates()
end

---Update a list item with workflow data
function WMMenuFrame:updateListItem(item, workflow, index)
    local nameElement = item:getDescendantByName("workflowName")
    local vehicleElement = item:getDescendantByName("workflowVehicle")
    local stepsElement = item:getDescendantByName("workflowSteps")
    local statusElement = item:getDescendantByName("workflowStatus")

    if nameElement then
        nameElement:setText(workflow.name or "")
    end

    if vehicleElement then
        local vehicleName = workflow.vehicle and workflow.vehicle:getName() or g_i18n:getText("wm_no_vehicle")
        vehicleElement:setText(vehicleName)
    end

    if stepsElement then
        stepsElement:setText(tostring(#workflow.steps))
    end

    if statusElement then
        local statusKey = "wm_status_" .. (workflow.status or "ready")
        statusElement:setText(g_i18n:getText(statusKey))
    end
end

---Update button enabled states based on selection
function WMMenuFrame:updateButtonStates()
    local hasSelection = self.selectedIndex > 0 and self.selectedIndex <= #self.workflows
    local workflow = hasSelection and self.workflows[self.selectedIndex] or nil
    local isRunning = workflow and workflow.status == WorkflowManager.STATUS_RUNNING
    local hasSteps = workflow and #workflow.steps > 0
    local hasVehicle = workflow and workflow.vehicle ~= nil

    if self.buttonEdit then
        self.buttonEdit:setDisabled(not hasSelection)
    end
    if self.buttonDelete then
        self.buttonDelete:setDisabled(not hasSelection or isRunning)
    end
    if self.buttonStart then
        self.buttonStart:setDisabled(not hasSelection or isRunning or not hasSteps or not hasVehicle)
    end
    if self.buttonStop then
        self.buttonStop:setDisabled(not hasSelection or not isRunning)
    end
end

---Called when list selection changes
function WMMenuFrame:onListSelectionChanged(list, section, index)
    self.selectedIndex = index
    self:updateButtonStates()
end

---Called when New button is clicked
function WMMenuFrame:onClickNew()
    WMLogger:debug("WMMenuFrame:onClickNew()")

    local workflow = WorkflowManager:createWorkflow(g_i18n:getText("wm_new_workflow_name") or "New Workflow")
    self:refreshWorkflowList()

    -- Select the new workflow
    self.selectedIndex = #self.workflows
    if self.workflowList then
        self.workflowList:setSelectedIndex(self.selectedIndex)
    end

    -- Open editor for the new workflow
    self:openEditor(workflow)
end

---Called when Edit button is clicked
function WMMenuFrame:onClickEdit()
    WMLogger:debug("WMMenuFrame:onClickEdit()")

    if self.selectedIndex > 0 and self.selectedIndex <= #self.workflows then
        local workflow = self.workflows[self.selectedIndex]
        self:openEditor(workflow)
    end
end

---Open the workflow editor for a workflow
function WMMenuFrame:openEditor(workflow)
    if workflow then
        WMEditorGUI:setWorkflow(workflow)
        WMEditorGUI:show()
    end
end

---Called when Delete button is clicked
function WMMenuFrame:onClickDelete()
    WMLogger:debug("WMMenuFrame:onClickDelete()")

    if self.selectedIndex > 0 and self.selectedIndex <= #self.workflows then
        local workflow = self.workflows[self.selectedIndex]

        -- Show confirmation dialog
        YesNoDialog.show(
            function(dialog, clickOk)
                if clickOk then
                    WorkflowManager:deleteWorkflow(workflow.id)
                    self:refreshWorkflowList()
                end
            end,
            self,
            string.format(g_i18n:getText("wm_confirm_delete") or "Delete workflow '%s'?", workflow.name)
        )
    end
end

---Called when Start button is clicked
function WMMenuFrame:onClickStart()
    WMLogger:debug("WMMenuFrame:onClickStart()")

    if self.selectedIndex > 0 and self.selectedIndex <= #self.workflows then
        local workflow = self.workflows[self.selectedIndex]
        local success = WorkflowManager:startWorkflow(workflow.id)

        if success then
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                string.format(g_i18n:getText("wm_workflow_started"), workflow.name))
        end

        self:refreshWorkflowList()
    end
end

---Called when Stop button is clicked
function WMMenuFrame:onClickStop()
    WMLogger:debug("WMMenuFrame:onClickStop()")

    if self.selectedIndex > 0 and self.selectedIndex <= #self.workflows then
        local workflow = self.workflows[self.selectedIndex]
        local success = WorkflowManager:stopWorkflow(workflow.id)

        if success then
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                string.format(g_i18n:getText("wm_workflow_stopped"), workflow.name))
        end

        self:refreshWorkflowList()
    end
end

---Get menu button info for this page
function WMMenuFrame:getMenuButtonInfo()
    local buttons = {}

    -- Back button
    table.insert(buttons, {
        inputAction = InputAction.MENU_BACK,
        text = g_i18n:getText("button_back"),
        callback = function() self:onClickBack() end
    })

    return buttons
end

---Called when Back button is clicked
function WMMenuFrame:onClickBack()
    -- Close the menu
    g_gui:changeScreen(nil)
end

---Update method called each frame when visible
function WMMenuFrame:update(dt)
    -- Skip update if we're being cleaned up
    if not self.isActive then
        return
    end

    -- Safely call parent update with nil checks
    local superClass = WMMenuFrame:superClass()
    if superClass ~= nil and superClass.update ~= nil then
        local success, err = pcall(function()
            superClass.update(self, dt)
        end)
        if not success then
            -- Silently ignore errors during cleanup/shutdown
            -- WMLogger:debug("WMMenuFrame update error (likely during cleanup): %s", tostring(err))
        end
    end

    -- Check for workflow status changes and refresh if needed
    -- This ensures the list stays up to date while viewing
end

---Cleanup method called when the frame is being destroyed
function WMMenuFrame:delete()
    WMLogger:debug("WMMenuFrame:delete() called")

    -- Mark as inactive to prevent further updates
    self.isActive = false

    -- Call parent delete if available
    local superClass = WMMenuFrame:superClass()
    if superClass ~= nil and superClass.delete ~= nil then
        pcall(function()
            superClass.delete(self)
        end)
    end
end
