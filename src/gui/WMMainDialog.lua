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
    self.workflows = WorkflowManager:getWorkflows() or {}

    if self.workflowList then
        self.workflowList:reloadData()

        -- Select first item if available
        if #self.workflows > 0 then
            self.workflowList:setSelectedIndex(1)
            self.selectedWorkflowIndex = 1
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

    -- Set workflow name
    local nameElement = cell:getDescendantByName("workflowName")
    if nameElement then
        nameElement:setText(workflow.name or "Unnamed")
    end

    -- Set step count (show progress if resumable)
    local stepsElement = cell:getDescendantByName("workflowSteps")
    if stepsElement then
        local stepCount = workflow.steps and #workflow.steps or 0
        local isResumable = WMExecutor:isWorkflowResumable(workflow)
        if isResumable and workflow.currentStep and workflow.currentStep > 1 then
            -- Show progress: "3/5"
            stepsElement:setText(string.format("%d/%d", workflow.currentStep, stepCount))
        else
            stepsElement:setText(tostring(stepCount))
        end
    end

    -- Set status
    local statusElement = cell:getDescendantByName("workflowStatus")
    if statusElement then
        local statusText = self:getStatusText(workflow.status)
        statusElement:setText(statusText)
    end
end

---Get localized status text
---@param status string Status key
---@return string statusText Localized status
function WMMainDialog:getStatusText(status)
    local statusKeys = {
        ready = "wm_status_ready",
        running = "wm_status_running",
        paused = "wm_status_paused",
        completed = "wm_status_completed",
        error = "wm_status_error"
    }
    local key = statusKeys[status] or statusKeys.ready
    return g_i18n:getText(key) or status or "Ready"
end

---Update button states based on selection
function WMMainDialog:updateButtons()
    local hasSelection = self.selectedWorkflowIndex > 0 and self.selectedWorkflowIndex <= #self.workflows
    local selectedWorkflow = hasSelection and self.workflows[self.selectedWorkflowIndex] or nil
    local isRunning = selectedWorkflow and selectedWorkflow.status == "running"
    local isResumable = selectedWorkflow and WMExecutor:isWorkflowResumable(selectedWorkflow)

    if self.editButton then
        self.editButton:setDisabled(not hasSelection)
    end
    if self.deleteButton then
        self.deleteButton:setDisabled(not hasSelection)
    end
    if self.startButton then
        self.startButton:setDisabled(not hasSelection or isRunning)
        -- Change button text to "Resume" if workflow is resumable
        if isResumable then
            self.startButton:setText(g_i18n:getText("wm_button_resume") or "Resume")
        else
            self.startButton:setText(g_i18n:getText("wm_button_start") or "Start")
        end
    end
    if self.stopButton then
        -- Stop available when running OR when resumable (to reset saved progress)
        self.stopButton:setDisabled(not hasSelection or (not isRunning and not isResumable))
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

        -- Check if workflow is resumable (has saved progress)
        local isResumable = WMExecutor:isWorkflowResumable(workflow)
        local success, errorMsg

        if isResumable then
            -- Resume from saved state
            success, errorMsg = WorkflowManager:resumeFromSaveWorkflow(workflow.id)
            if success then
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                    string.format(g_i18n:getText("wm_workflow_resumed") or "Workflow resumed: %s (Step %d)", workflow.name, workflow.currentStep or 1))
            else
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                    errorMsg or g_i18n:getText("wm_workflow_error") or "Failed to resume workflow")
            end
        else
            -- Start from beginning
            success, errorMsg = WorkflowManager:startWorkflow(workflow.id)
            if success then
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                    string.format(g_i18n:getText("wm_workflow_started") or "Workflow started: %s", workflow.name))
            else
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                    errorMsg or g_i18n:getText("wm_workflow_error") or "Failed to start workflow")
            end
        end

        self:refreshWorkflowList()
    end
end

---Called when Stop button is clicked
function WMMainDialog:onClickStop()
    WMLogger:debug("WMMainDialog:onClickStop")

    if self.selectedWorkflowIndex > 0 and self.selectedWorkflowIndex <= #self.workflows then
        local workflow = self.workflows[self.selectedWorkflowIndex]
        local isRunning = workflow.status == "running"
        local isResumable = WMExecutor:isWorkflowResumable(workflow)

        if isRunning then
            -- Stop active workflow
            WorkflowManager:stopWorkflow(workflow.id)
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                string.format(g_i18n:getText("wm_workflow_stopped") or "Workflow stopped: %s", workflow.name))
        elseif isResumable then
            -- Reset paused workflow (clear saved progress)
            WorkflowManager:resetWorkflow(workflow.id)
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                string.format(g_i18n:getText("wm_workflow_reset") or "Workflow reset: %s", workflow.name))
        end

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
