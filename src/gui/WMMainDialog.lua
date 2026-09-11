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
    self.adSettingsButton = nil
    return self
end

function WMMainDialog:onCreate()
    WMLogger:debug("WMMainDialog:onCreate")
end

function WMMainDialog:onOpen()
    WMMainDialog:superClass().onOpen(self)
    WMLogger:debug("WMMainDialog:onOpen")
    WMHud:onDialogOpened()

    -- Register custom input events
    self:registerInputEvents()

    -- Set correct input action indicators on buttons
    if self.newButton then
        self.newButton:setInputAction("WM_GUI_NEW")
    end
    if self.editButton then
        self.editButton:setInputAction("WM_GUI_EDIT")
    end
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
    WMHud:onDialogClosed()

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

    -- Get runtime state for the current vehicle
    local vehicle = g_currentMission and g_currentMission.controlledVehicle
    if vehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
        vehicle = g_localPlayer:getCurrentVehicle()
    end
    local activeData = vehicle and WorkflowManager:getVehicleWorkflowState(vehicle)
    local isThisWorkflow = activeData and activeData.workflow and activeData.workflow.id == workflow.id
    local currentStep = isThisWorkflow and activeData.currentStep or 1
    local status = isThisWorkflow and activeData.status or nil

    -- Set workflow name (with support steps indicator), colored by status
    local nameElement = cell:getDescendantByName("workflowName")
    if nameElement then
        local displayName = workflow.name or "Unnamed"
        if WorkflowManager:hasSupportSteps(workflow.id) then
            displayName = displayName .. " [+S]"
        end
        nameElement:setText(displayName)

        -- Color name by workflow status on current vehicle
        if status == WorkflowManager.STATUS_RUNNING then
            nameElement:setTextColor(0.3, 0.9, 0.3, 1)      -- green: running
        elseif status == WorkflowManager.STATUS_PAUSED then
            nameElement:setTextColor(1, 0.65, 0.1, 1)        -- orange: paused
        else
            nameElement:setTextColor(1, 1, 1, 1)             -- white: idle/not active
        end
    end

    -- Set step count; show progress and vehicle name when active on current vehicle
    local stepsElement = cell:getDescendantByName("workflowSteps")
    if stepsElement then
        local stepCount = workflow.steps and #workflow.steps or 0
        if isThisWorkflow then
            -- Show progress: "2/5"
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
    if self.adSettingsButton then
        self.adSettingsButton:setDisabled(not hasSelection)
        self.adSettingsButton:setInputAction("WM_GUI_AD_SETTINGS")
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

    -- Build the workflow but do not register it yet: the editor adds it to the list on Save,
    -- so cancelling out of the editor leaves no empty entry behind.
    local workflow = WorkflowManager:buildWorkflow()
    if workflow then
        -- Close this dialog and open editor
        self:close()
        WorkflowManager:showEditorDialog(workflow, true)
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
        local workflowName = workflow.name

        if not WorkflowManager:canStartWorkflow(workflow.id) then
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                g_i18n:getText("wm_workflow_error") or "Failed to start workflow")
            self:refreshWorkflowList()
            return
        end

        -- Close BEFORE starting: the start flow may open the mode/leader select dialog on
        -- top of this one, and closing afterwards drops the GUI cursor the child still needs.
        self:close()

        -- The start flow may pass through mode/leader select dialogs; only report success
        -- and hand the cursor to the HUD once the start command is actually dispatched
        -- (the callback never fires when the player cancels one of those dialogs).
        WorkflowManager:startWorkflow(workflow.id, function()
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK,
                string.format(g_i18n:getText("wm_workflow_started") or "Workflow started: %s", workflowName))
            -- Closing the dialogs hides the cursor; hand it to the HUD, which releases it
            -- again when it is closed or the workflow ends
            WMHud:setMouseCursorActive(true)
        end)
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

---Called when AD/CP Settings button is clicked
function WMMainDialog:onClickADSettings()
    WMLogger:debug("WMMainDialog:onClickADSettings")
    if self.selectedWorkflowIndex < 1 or self.selectedWorkflowIndex > #self.workflows then return end
    local workflow = self.workflows[self.selectedWorkflowIndex]
    -- Close BEFORE opening the settings dialog: two WM dialogs stacked on the GUI leave the
    -- input context stack unbalanced once they close (see WMEditorDialog:suspendForChildDialog)
    self:close()
    WorkflowManager:showADSettingsDialog(workflow.adSettings, function(settings)
        if settings ~= nil then
            workflow.adSettings = settings
            WorkflowManager:saveWorkflows()
        end
        WorkflowManager:showMainDialog()
    end)
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

    -- New: N key
    local _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_NEW, self, self.onInputNew, false, true, false, true)
    if eventId ~= nil then
        table.insert(self.inputEventIds, eventId)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end

    -- Edit: E key
    _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_EDIT, self, self.onInputEdit, false, true, false, true)
    if eventId ~= nil then
        table.insert(self.inputEventIds, eventId)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end

    -- Delete: ENTF key
    _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_DELETE, self, self.onInputDelete, false, true, false, true)
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

    -- AD/CP Settings: B key
    _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_AD_SETTINGS, self, self.onInputADSettings, false, true, false, true)
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

---Input handler for New key
function WMMainDialog:onInputNew(actionName, inputValue)
    if self.newButton and not self.newButton.disabled then
        self:onClickNew()
    end
end

---Input handler for Edit key
function WMMainDialog:onInputEdit(actionName, inputValue)
    if self.editButton and not self.editButton.disabled then
        self:onClickEdit()
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

---Input handler for AD/CP Settings key (B)
function WMMainDialog:onInputADSettings(actionName, inputValue)
    if self.adSettingsButton and not self.adSettingsButton.disabled then
        self:onClickADSettings()
    end
end
