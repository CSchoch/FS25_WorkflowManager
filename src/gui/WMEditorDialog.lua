--[[
    WorkflowManager - Editor Dialog
    Allows editing workflow name and managing steps
    Uses proper FS25 DialogElement for input blocking

    Author: WorkflowManager Team
]]

---@class WMEditorDialog
WMEditorDialog = {}

local WMEditorDialog_mt = Class(WMEditorDialog, DialogElement)

function WMEditorDialog.new(target)
    local self = DialogElement.new(target, WMEditorDialog_mt)
    self.workflow = nil
    self.selectedStepIndex = 0
    self.inputEventIds = {}
    return self
end

function WMEditorDialog:onCreate()
    WMLogger:debug("WMEditorDialog:onCreate")
end

function WMEditorDialog:onOpen()
    WMEditorDialog:superClass().onOpen(self)
    WMLogger:debug("WMEditorDialog:onOpen")

    -- Register custom input events
    self:registerInputEvents()

    -- Set correct input action indicators on buttons
    if self.removeStepButton then
        self.removeStepButton:setInputAction("WM_GUI_DELETE")
    end
    if self.moveUpButton then
        self.moveUpButton:setInputAction("WM_GUI_MOVE_UP")
    end
    if self.moveDownButton then
        self.moveDownButton:setInputAction("WM_GUI_MOVE_DOWN")
    end

    -- Setup list data source
    if self.stepList ~= nil then
        self.stepList:setDataSource(self)
    end

    -- Load data caches for dropdowns
    self:loadDataCaches()

    -- Refresh display
    self:refreshDisplay()
end

function WMEditorDialog:onClose()
    WMEditorDialog:superClass().onClose(self)
    WMLogger:debug("WMEditorDialog:onClose")

    -- Unregister custom input events
    self:unregisterInputEvents()
end

---Set the workflow to edit
---@param workflow table Workflow to edit
function WMEditorDialog:setWorkflow(workflow)
    self.workflow = workflow
    self.selectedStepIndex = 0
end

---Load data caches for AD destinations and CP courses
function WMEditorDialog:loadDataCaches()
    -- Tell loaders to start scanning
    if CPCoursesLoader then
        CPCoursesLoader:setGuiOpen(true)
    end
    if CPVehiclesLoader then
        CPVehiclesLoader:setGuiOpen(true)
    end

    -- Cache AD destinations
    self.cachedADDestinations = {}
    if ADIntegration and ADIntegration.isAvailable then
        local adDests = ADIntegration:getDestinations()
        if adDests then
            for _, dest in ipairs(adDests) do
                table.insert(self.cachedADDestinations, dest.displayName or dest.name or tostring(dest))
            end
        end
    end

    -- Cache CP courses
    self.cachedCPCourses = {}
    if CPCoursesLoader and CPCoursesLoader.isInitialized then
        local courses = CPCoursesLoader:getCourses()
        if courses and #courses > 0 then
            for _, course in ipairs(courses) do
                table.insert(self.cachedCPCourses, course)
            end
        end
    end

    -- Cache fill types
    self.cachedFillTypes = {}
    if ADIntegration and ADIntegration.isAvailable then
        self.cachedFillTypes = ADIntegration:getFillTypeNames()
    end

    WMLogger:debug("Data caches loaded: %d AD, %d CP, %d fillTypes",
        #self.cachedADDestinations, #self.cachedCPCourses, #self.cachedFillTypes)
end

---Refresh the display with current workflow data
function WMEditorDialog:refreshDisplay()
    if self.workflow == nil then
        return
    end

    -- Set workflow name
    if self.nameInput then
        self.nameInput:setText(self.workflow.name or "")
    end

    -- Refresh step list
    self:refreshStepList()
end

---Refresh the step list
function WMEditorDialog:refreshStepList()
    if self.stepList == nil or self.workflow == nil then
        return
    end

    self.stepList:reloadData()

    local steps = self.workflow.steps or {}

    -- Restore selection
    if self.selectedStepIndex > 0 and self.selectedStepIndex <= #steps then
        self.stepList:setSelectedIndex(self.selectedStepIndex)
    elseif #steps > 0 then
        self.stepList:setSelectedIndex(1)
        self.selectedStepIndex = 1
    else
        self.selectedStepIndex = 0
    end

    self:updateButtons()
end

---SmoothList data source: Get number of items
function WMEditorDialog:getNumberOfItemsInSection(list, section)
    if self.workflow == nil then
        return 0
    end
    return #(self.workflow.steps or {})
end

---SmoothList data source: Populate cell
function WMEditorDialog:populateCellForItemInSection(list, section, index, cell)
    if self.workflow == nil then
        return
    end

    local step = self.workflow.steps[index]
    if step == nil then
        return
    end

    -- Step number
    local numElement = cell:getDescendantByName("stepNum")
    if numElement then
        numElement:setText(tostring(index))
    end

    -- Step type
    local typeElement = cell:getDescendantByName("stepType")
    if typeElement then
        local typeText = step.type == "autodrive" and
            g_i18n:getText("wm_type_autodrive") or g_i18n:getText("wm_type_courseplay")
        typeElement:setText(typeText or step.type)
    end

    -- Step target
    local targetElement = cell:getDescendantByName("stepTarget")
    if targetElement then
        targetElement:setText(step.target or "")
    end

    -- Step action
    local actionElement = cell:getDescendantByName("stepAction")
    if actionElement then
        actionElement:setText(self:getActionDisplayName(step.action) or step.action or "")
    end
end

---Get display name for an action
---@param action string Action name
---@return string displayName Localized display name
function WMEditorDialog:getActionDisplayName(action)
    local actionDisplayNames = {
        drive = g_i18n:getText("wm_action_drive") or "Drive To",
        pickup_deliver = g_i18n:getText("wm_action_pickup_deliver") or "Pickup & Deliver",
        deliver = g_i18n:getText("wm_action_deliver") or "Deliver",
        load = g_i18n:getText("wm_action_load") or "Load",
        unload = g_i18n:getText("wm_action_unload") or "Unload",
        fieldwork = g_i18n:getText("wm_action_fieldwork") or "Field Work",
        bale_collect = g_i18n:getText("wm_action_bale_collect") or "Bale Collect"
    }
    return actionDisplayNames[action] or action
end

---Update button states based on selection
function WMEditorDialog:updateButtons()
    local hasSteps = self.workflow and self.workflow.steps and #self.workflow.steps > 0
    local hasSelection = self.selectedStepIndex > 0

    if self.editStepButton then
        self.editStepButton:setDisabled(not hasSelection)
    end
    if self.removeStepButton then
        self.removeStepButton:setDisabled(not hasSelection)
    end
    if self.moveUpButton then
        self.moveUpButton:setDisabled(not hasSelection or self.selectedStepIndex <= 1)
    end
    if self.moveDownButton then
        local maxIndex = self.workflow and self.workflow.steps and #self.workflow.steps or 0
        self.moveDownButton:setDisabled(not hasSelection or self.selectedStepIndex >= maxIndex)
    end
end

---Called when step list selection changes
function WMEditorDialog:onStepListSelectionChanged(list, section, index)
    self.selectedStepIndex = index
    self:updateButtons()
    WMLogger:debug("Selected step index: %d", index)
end

---Called when step list item is double-clicked
function WMEditorDialog:onStepListDoubleClick(list, section, index)
    self.selectedStepIndex = index
    self:onClickEditStep()
end

---Called when name input text changes
function WMEditorDialog:onNameEnterPressed()
    if self.workflow and self.nameInput then
        self.workflow.name = self.nameInput.text or ""
        WMLogger:debug("Workflow name changed to: %s", self.workflow.name)
    end
end

---Called when Add Step button is clicked
function WMEditorDialog:onClickAddStep()
    WMLogger:debug("WMEditorDialog:onClickAddStep")
    WorkflowManager:showStepDialog(nil, function(step)
        if step and self.workflow then
            table.insert(self.workflow.steps, step)
            self.selectedStepIndex = #self.workflow.steps
            self:refreshStepList()
        end
    end)
end

---Called when Edit Step button is clicked
function WMEditorDialog:onClickEditStep()
    WMLogger:debug("WMEditorDialog:onClickEditStep")

    if self.selectedStepIndex > 0 and self.workflow and self.workflow.steps then
        local step = self.workflow.steps[self.selectedStepIndex]
        if step then
            WorkflowManager:showStepDialog(step, function(editedStep)
                if editedStep then
                    self.workflow.steps[self.selectedStepIndex] = editedStep
                    self:refreshStepList()
                end
            end)
        end
    end
end

---Called when Remove Step button is clicked
function WMEditorDialog:onClickRemoveStep()
    WMLogger:debug("WMEditorDialog:onClickRemoveStep")

    if self.selectedStepIndex > 0 and self.workflow and self.workflow.steps then
        table.remove(self.workflow.steps, self.selectedStepIndex)
        if self.selectedStepIndex > #self.workflow.steps then
            self.selectedStepIndex = #self.workflow.steps
        end
        self:refreshStepList()
    end
end

---Called when Move Up button is clicked
function WMEditorDialog:onClickMoveUp()
    WMLogger:debug("WMEditorDialog:onClickMoveUp")

    if self.selectedStepIndex > 1 and self.workflow and self.workflow.steps then
        local steps = self.workflow.steps
        local temp = steps[self.selectedStepIndex]
        steps[self.selectedStepIndex] = steps[self.selectedStepIndex - 1]
        steps[self.selectedStepIndex - 1] = temp
        self.selectedStepIndex = self.selectedStepIndex - 1
        self:refreshStepList()
    end
end

---Called when Move Down button is clicked
function WMEditorDialog:onClickMoveDown()
    WMLogger:debug("WMEditorDialog:onClickMoveDown")

    if self.workflow and self.workflow.steps then
        local maxIndex = #self.workflow.steps
        if self.selectedStepIndex > 0 and self.selectedStepIndex < maxIndex then
            local steps = self.workflow.steps
            local temp = steps[self.selectedStepIndex]
            steps[self.selectedStepIndex] = steps[self.selectedStepIndex + 1]
            steps[self.selectedStepIndex + 1] = temp
            self.selectedStepIndex = self.selectedStepIndex + 1
            self:refreshStepList()
        end
    end
end

---Called when Save button is clicked
function WMEditorDialog:onClickSave()
    WMLogger:debug("WMEditorDialog:onClickSave")

    -- Get final name from input
    if self.workflow and self.nameInput then
        self.workflow.name = self.nameInput.text or self.workflow.name
    end

    -- Stop loaders
    if CPCoursesLoader then
        CPCoursesLoader:setGuiOpen(false)
    end
    if CPVehiclesLoader then
        CPVehiclesLoader:setGuiOpen(false)
    end

    -- Save workflows
    WorkflowManager:saveWorkflows()

    self:close()

    -- Reopen main dialog
    WorkflowManager:showMainDialog()
end

---Called when Cancel button is clicked
function WMEditorDialog:onClickCancel()
    WMLogger:debug("WMEditorDialog:onClickCancel")

    -- Stop loaders
    if CPCoursesLoader then
        CPCoursesLoader:setGuiOpen(false)
    end
    if CPVehiclesLoader then
        CPVehiclesLoader:setGuiOpen(false)
    end

    self:close()

    -- Reopen main dialog
    WorkflowManager:showMainDialog()
end

---Called when Escape is pressed
function WMEditorDialog:onEscPressed()
    self:onClickCancel()
end

---Get cached AD destinations
function WMEditorDialog:getADDestinations()
    return self.cachedADDestinations or {}
end

---Get cached CP courses
function WMEditorDialog:getCPCourses()
    return self.cachedCPCourses or {}
end

---Get cached fill types
function WMEditorDialog:getFillTypes()
    return self.cachedFillTypes or {}
end

---Register custom input events for hotkeys
function WMEditorDialog:registerInputEvents()
    self.inputEventIds = {}

    -- Remove: Backspace key
    local _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_DELETE, self, self.onInputRemove, false, true, false, true)
    if eventId ~= nil then
        table.insert(self.inputEventIds, eventId)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end

    -- Move Up: + key
    _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_MOVE_UP, self, self.onInputMoveUp, false, true, false, true)
    if eventId ~= nil then
        table.insert(self.inputEventIds, eventId)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end

    -- Move Down: - key
    _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_MOVE_DOWN, self, self.onInputMoveDown, false, true, false, true)
    if eventId ~= nil then
        table.insert(self.inputEventIds, eventId)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end
end

---Unregister custom input events
function WMEditorDialog:unregisterInputEvents()
    if self.inputEventIds then
        for _, eventId in ipairs(self.inputEventIds) do
            g_inputBinding:removeActionEvent(eventId)
        end
        self.inputEventIds = {}
    end
end

---Input handler for Remove key (Backspace)
function WMEditorDialog:onInputRemove(actionName, inputValue)
    if self.removeStepButton and not self.removeStepButton.disabled then
        self:onClickRemoveStep()
    end
end

---Input handler for Move Up key (+)
function WMEditorDialog:onInputMoveUp(actionName, inputValue)
    if self.moveUpButton and not self.moveUpButton.disabled then
        self:onClickMoveUp()
    end
end

---Input handler for Move Down key (-)
function WMEditorDialog:onInputMoveDown(actionName, inputValue)
    if self.moveDownButton and not self.moveDownButton.disabled then
        self:onClickMoveDown()
    end
end
