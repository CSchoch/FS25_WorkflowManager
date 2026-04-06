--[[
    WorkflowManager - Main Dialog
    Shows workflow list with New/Edit/Delete/Start/Stop buttons
    Uses proper FS25 DialogElement for input blocking

    Author: WorkflowManager Team
]]

---@class WMMainDialog
WMMainDialog = {}

local WMMainDialog_mt = Class(WMMainDialog, DialogElement)

function WMMainDialog.new(target)
    local self = DialogElement.new(target, WMMainDialog_mt)
    self.selectedWorkflowIndex = 0
    self.workflows = {}
    self.inputEventIds = {}
    return self
end

function WMMainDialog:onCreate()
    WMLogger:debug("WMMainDialog:onCreate")
end

function WMMainDialog:onOpen()
    WMMainDialog:superClass().onOpen(self)
    WMLogger:debug("WMMainDialog:onOpen")

    -- Register custom input events
    self:registerInputEvents()

    -- Set correct input action indicators on buttons
    if self.deleteButton then
        self.deleteButton:setInputAction("WM_GUI_DELETE")
    end
    if self.startButton then
        self.startButton:setInputAction("WM_GUI_START")
    end
    if self.stopButton then
        self.stopButton:setInputAction("WM_GUI_STOP")
    end

    -- Setup list data source
    if self.workflowList ~= nil then
        self.workflowList:setDataSource(self)
    end

    -- Refresh workflow list
    self:refreshWorkflowList()
end

function WMMainDialog:onClose()
    WMMainDialog:superClass().onClose(self)
    WMLogger:debug("WMMainDialog:onClose")

    -- Unregister custom input events
    self:unregisterInputEvents()
end

---Refresh the workflow list from WorkflowManager
function WMMainDialog:refreshWorkflowList()
    local previousIndex = self.selectedWorkflowIndex
    self.workflows = WorkflowManager:getWorkflows() or {}

    if self.workflowList then
        self.workflowList:reloadData()

        if #self.workflows > 0 then
            -- Restore previous selection, clamped to valid range
            local newIndex = math.max(1, math.min(previousIndex > 0 and previousIndex or 1, #self.workflows))
            self.workflowList:setSelectedIndex(newIndex)
            self.selectedWorkflowIndex = newIndex
        else
            self.selectedWorkflowIndex = 0
        end
    end

    self:updateButtons()
end

---SmoothList data source: Get number of items
function WMMainDialog:getNumberOfItemsInSection(list, section)
    return #self.workflows
end

---SmoothList data source: Populate cell
function WMMainDialog:populateCellForItemInSection(list, section, index, cell)
    local workflow = self.workflows[index]
    if workflow == nil then
        return
    end

    -- Set workflow name (with support steps indicator)
    local nameElement = cell:getDescendantByName("workflowName")
    if nameElement then
        local displayName = workflow.name or "Unnamed"
        if WorkflowManager:hasSupportSteps(workflow.id) then
            displayName = displayName .. " [+S]"
        end
        nameElement:setText(displayName)
    end

    -- Get runtime state for the current vehicle
    local vehicle = g_currentMission and g_currentMission.controlledVehicle
    if vehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
        vehicle = g_localPlayer:getCurrentVehicle()
    end
    local activeData = vehicle and WorkflowManager:getVehicleWorkflowState(vehicle)
    local isThisWorkflow = activeData and activeData.workflow.id == workflow.id
    local currentStep = isThisWorkflow and activeData.currentStep or 1

    -- Set step count (show progress if running/paused)
    local stepsElement = cell:getDescendantByName("workflowSteps")
    if stepsElement then
        local stepCount = workflow.steps and #workflow.steps or 0
        if isThisWorkflow and currentStep > 1 then
            -- Show progress: "3/5"
            stepsElement:setText(string.format("%d/%d", currentStep, stepCount))
        else
            stepsElement:setText(tostring(stepCount))
        end
    end
end

---Update button states based on selection
function WMMainDialog:updateButtons()
    local hasSelection = self.selectedWorkflowIndex > 0 and self.selectedWorkflowIndex <= #self.workflows
    local selectedWorkflow = hasSelection and self.workflows[self.selectedWorkflowIndex] or nil

    -- Get runtime state for the current vehicle
    local vehicle = g_currentMission and g_currentMission.controlledVehicle
    if vehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
        vehicle = g_localPlayer:getCurrentVehicle()
    end
    local activeData = vehicle and WorkflowManager:getVehicleWorkflowState(vehicle)
    local isThisWorkflow = activeData and selectedWorkflow and activeData.workflow.id == selectedWorkflow.id
    local isRunning = isThisWorkflow and activeData.status == WorkflowManager.STATUS_RUNNING

    if self.editButton then
        self.editButton:setDisabled(not hasSelection)
    end
    if self.deleteButton then
        self.deleteButton:setDisabled(not hasSelection)
    end
    if self.startButton then
        self.startButton:setDisabled(not hasSelection or isRunning)
        self.startButton:setText(g_i18n:getText("wm_button_start") or "Start")
    end
    if self.stopButton then
        -- Stop only available when this workflow is actively running on current vehicle
        self.stopButton:setDisabled(not hasSelection or not isThisWorkflow)
    end

end

---Called when list selection changes
function WMMainDialog:onListSelectionChanged(list, section, index)
    self.selectedWorkflowIndex = index
    self:updateButtons()
    WMLogger:debug("Selected workflow index: %d", index)
end

---Called when list item is double-clicked
function WMMainDialog:onListDoubleClick(list, section, index)
    self.selectedWorkflowIndex = index
    self:onClickEdit()
end

---Called when New button is clicked
function WMMainDialog:onClickNew()
    WMLogger:debug("WMMainDialog:onClickNew")

    -- Create new workflow
    local workflow = WorkflowManager:createWorkflow()
    if workflow then
        -- Close this dialog and open editor
        self:close()
        WorkflowManager:showEditorDialog(workflow)
    end
end

---Called when Edit button is clicked
function WMMainDialog:onClickEdit()
    WMLogger:debug("WMMainDialog:onClickEdit")

    if self.selectedWorkflowIndex > 0 and self.selectedWorkflowIndex <= #self.workflows then
        local workflow = self.workflows[self.selectedWorkflowIndex]
        -- Close this dialog and open editor
        self:close()
        WorkflowManager:showEditorDialog(workflow)
    end
end

---Called when Delete button is clicked
function WMMainDialog:onClickDelete()
    WMLogger:debug("WMMainDialog:onClickDelete")

    if self.selectedWorkflowIndex > 0 and self.selectedWorkflowIndex <= #self.workflows then
        local workflow = self.workflows[self.selectedWorkflowIndex]

        -- Show confirmation dialog
        YesNoDialog.show(
            function(dialog, clickOk)
                if clickOk then
                    WorkflowManager:deleteWorkflow(workflow.id)
                    WorkflowManager:saveWorkflows()
                    self:refreshWorkflowList()
                end
            end,
            self,
            string.format(g_i18n:getText("wm_confirm_delete") or "Delete workflow '%s'?", workflow.name)
        )
    end
end

---Called when Start button is clicked
function WMMainDialog:onClickStart()
    WMLogger:debug("WMMainDialog:onClickStart")

    if self.selectedWorkflowIndex > 0 and self.selectedWorkflowIndex <= #self.workflows then
        local workflow = self.workflows[self.selectedWorkflowIndex]

        local success = WorkflowManager:startWorkflow(workflow.id)
        if success then
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                string.format(g_i18n:getText("wm_workflow_started") or "Workflow started: %s", workflow.name))
        else
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                g_i18n:getText("wm_workflow_error") or "Failed to start workflow")
        end

        self:refreshWorkflowList()
    end
end

---Called when Stop button is clicked
function WMMainDialog:onClickStop()
    WMLogger:debug("WMMainDialog:onClickStop")

    if self.selectedWorkflowIndex > 0 and self.selectedWorkflowIndex <= #self.workflows then
        local workflow = self.workflows[self.selectedWorkflowIndex]
        WorkflowManager:stopWorkflow(workflow.id)
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format(g_i18n:getText("wm_workflow_stopped") or "Workflow stopped: %s", workflow.name))
        self:refreshWorkflowList()
    end
end

---Called when Close button is clicked
function WMMainDialog:onClickClose()
    WMLogger:debug("WMMainDialog:onClickClose")
    self:close()
end

---Called when Escape is pressed
function WMMainDialog:onEscPressed()
    self:onClickClose()
end

---Register custom input events for hotkeys
function WMMainDialog:registerInputEvents()
    self.inputEventIds = {}

    -- Delete: ENTF key
    local _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_DELETE, self, self.onInputDelete, false, true, false, true)
    if eventId ~= nil then
        table.insert(self.inputEventIds, eventId)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end

    -- Start: S key
    _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_START, self, self.onInputStart, false, true, false, true)
    if eventId ~= nil then
        table.insert(self.inputEventIds, eventId)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end

    -- Stop: Backspace key
    _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_STOP, self, self.onInputStop, false, true, false, true)
    if eventId ~= nil then
        table.insert(self.inputEventIds, eventId)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end
end

---Unregister custom input events
function WMMainDialog:unregisterInputEvents()
    if self.inputEventIds then
        for _, eventId in ipairs(self.inputEventIds) do
            g_inputBinding:removeActionEvent(eventId)
        end
        self.inputEventIds = {}
    end
end

---Input handler for Delete key
function WMMainDialog:onInputDelete(actionName, inputValue)
    if self.deleteButton and not self.deleteButton.disabled then
        self:onClickDelete()
    end
end

---Input handler for Start key
function WMMainDialog:onInputStart(actionName, inputValue)
    if self.startButton and not self.startButton.disabled then
        self:onClickStart()
    end
end

---Input handler for Stop key (Backspace)
function WMMainDialog:onInputStop(actionName, inputValue)
    if self.stopButton and not self.stopButton.disabled then
        self:onClickStop()
    end
end
