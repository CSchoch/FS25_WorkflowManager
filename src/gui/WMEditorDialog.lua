--[[
    WorkflowManager - Editor Dialog
    Allows editing workflow name and managing steps.
    The step list is a flat, nested view: main steps are shown with their support
    sub-steps indented below them (  ↳ 1  AutoDrive  Field1  Unload).

    Author: WorkflowManager Team
]]

---@class WMEditorDialog
WMEditorDialog = {}

local WMEditorDialog_mt = Class(WMEditorDialog, DialogElement)

---Deep-copy a workflow/step tree. Workflow definitions hold only strings, numbers, booleans
---and nested arrays (no cycles, no functions), so a plain recursive copy is sufficient.
local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepCopy(v)
    end
    return copy
end

function WMEditorDialog.new(target)
    local self = DialogElement.new(target, WMEditorDialog_mt)
    self.workflow = nil        -- edit buffer (a copy); all step operations mutate this
    self.sourceWorkflow = nil  -- the live workflow table, written only by onClickSave
    -- Flat list for the SmoothList: each entry is {isMain, stepIndex, supportIndex}
    self.flatItems = {}
    self.selectedFlatIndex = 0
    self.inputEventIds = {}
    return self
end

function WMEditorDialog:onCreate()
    WMLogger:debug("WMEditorDialog:onCreate")
end

function WMEditorDialog:onOpen()
    WMEditorDialog:superClass().onOpen(self)
    WMLogger:debug("WMEditorDialog:onOpen")
    WMHud:onDialogOpened()

    self:registerInputEvents()

    if self.removeStepButton then self.removeStepButton:setInputAction("WM_GUI_DELETE") end
    if self.moveUpButton    then self.moveUpButton:setInputAction("WM_GUI_MOVE_UP")    end
    if self.moveDownButton  then self.moveDownButton:setInputAction("WM_GUI_MOVE_DOWN") end

    if self.stepList ~= nil then
        self.stepList:setDataSource(self)
    end

    self:loadDataCaches()
    self:refreshDisplay()
end

function WMEditorDialog:onClose()
    WMEditorDialog:superClass().onClose(self)
    WMLogger:debug("WMEditorDialog:onClose")
    WMHud:onDialogClosed()
    self:unregisterInputEvents()
end

---Set the workflow to edit.
---Edits are applied to a private copy so Cancel can discard them; onClickSave commits the
---copy back into the original table (see commitToSource).
---@param workflow table|nil Workflow to edit
---@param isNew boolean|nil  true for a workflow not yet in WorkflowManager.workflows; it is
---                          registered on Save and simply dropped on Cancel
function WMEditorDialog:setWorkflow(workflow, isNew)
    self.sourceWorkflow = workflow
    self.workflow = workflow ~= nil and deepCopy(workflow) or nil
    self.isNewWorkflow = isNew == true
    self.flatItems = {}
    self.selectedFlatIndex = 0
end

---Write the edit buffer back into the live workflow table.
---Mutates the original in place instead of replacing it: a running execution holds a direct
---reference to it via activeData.workflow, as does WorkflowManager.workflows.
---A workflow opened as new is added to the workflow list here, so it exists only once the
---user confirms with Save.
function WMEditorDialog:commitToSource()
    local source, buffer = self.sourceWorkflow, self.workflow
    if source == nil or buffer == nil then return end
    source.name       = buffer.name
    source.steps      = deepCopy(buffer.steps or {})
    source.adSettings = deepCopy(buffer.adSettings)
    if self.isNewWorkflow then
        self.isNewWorkflow = false
        WorkflowManager:registerWorkflow(source)
    end
end

-- ============================================================
-- Flat item list helpers
-- ============================================================

---Rebuild flatItems from workflow steps (main + nested support sub-steps).
function WMEditorDialog:buildFlatList()
    self.flatItems = {}
    if self.workflow == nil then return end
    for i, step in ipairs(self.workflow.steps or {}) do
        table.insert(self.flatItems, { isMain = true,  stepIndex = i, supportIndex = nil })
        for j, _ in ipairs(step.support or {}) do
            table.insert(self.flatItems, { isMain = false, stepIndex = i, supportIndex = j })
        end
    end
end

---Return the currently selected flat item, or nil.
function WMEditorDialog:getSelectedItem()
    -- Mouse clicks may not fire onSelectionChanged, so read the list's actual state
    if self.stepList and self.stepList.selectedIndex and self.stepList.selectedIndex > 0 then
        self.selectedFlatIndex = self.stepList.selectedIndex
    end
    if self.selectedFlatIndex < 1 or self.selectedFlatIndex > #self.flatItems then
        return nil
    end
    return self.flatItems[self.selectedFlatIndex]
end

---Return the flat index of the first row for a given main stepIndex.
function WMEditorDialog:flatIndexForMainStep(stepIndex)
    for i, item in ipairs(self.flatItems) do
        if item.isMain and item.stepIndex == stepIndex then
            return i
        end
    end
    return 0
end

-- ============================================================
-- Data load / display
-- ============================================================

function WMEditorDialog:loadDataCaches()
    if CPCoursesLoader then CPCoursesLoader:setGuiOpen(true) end
    if CPVehiclesLoader then CPVehiclesLoader:setGuiOpen(true) end

    self.cachedADDestinations = {}
    if ADIntegration and ADIntegration.isAvailable then
        local adDests = ADIntegration:getDestinations()
        if adDests then
            for _, dest in ipairs(adDests) do
                table.insert(self.cachedADDestinations, dest.displayName or dest.name or tostring(dest))
            end
        end
    end

    self.cachedCPCourses = {}
    if CPCoursesLoader and CPCoursesLoader.isInitialized then
        local courses = CPCoursesLoader:getCourses()
        if courses then
            for _, course in ipairs(courses) do
                table.insert(self.cachedCPCourses, course)
            end
        end
    end

    self.cachedFillTypes = {}
    if ADIntegration and ADIntegration.isAvailable then
        local fillTypes = ADIntegration:getAvailableFillTypes()
        for _, ft in ipairs(fillTypes) do
            table.insert(self.cachedFillTypes, {name = ft.name, title = ft.title or ft.name})
        end
    end

    WMLogger:debug("Data caches loaded: %d AD, %d CP, %d fillTypes",
        #self.cachedADDestinations, #self.cachedCPCourses, #self.cachedFillTypes)
end

function WMEditorDialog:refreshDisplay()
    if self.workflow == nil then return end
    if self.nameInput then self.nameInput:setText(self.workflow.name or "") end
    self:refreshStepList()
end

function WMEditorDialog:refreshStepList()
    if self.stepList == nil or self.workflow == nil then return end

    self:buildFlatList()
    self.stepList:reloadData()

    -- Restore selection within valid range
    local n = #self.flatItems
    if n == 0 then
        self.selectedFlatIndex = 0
    elseif self.selectedFlatIndex < 1 then
        self.selectedFlatIndex = 1
        self.stepList:setSelectedIndex(1)
    elseif self.selectedFlatIndex > n then
        self.selectedFlatIndex = n
        self.stepList:setSelectedIndex(n)
    else
        self.stepList:setSelectedIndex(self.selectedFlatIndex)
    end

    self:updateButtons()
end

-- ============================================================
-- SmoothList data source
-- ============================================================

function WMEditorDialog:getNumberOfItemsInSection(list, section)
    return #self.flatItems
end

function WMEditorDialog:populateCellForItemInSection(list, section, index, cell)
    local item = self.flatItems[index]
    if item == nil or self.workflow == nil then return end

    local step
    if item.isMain then
        step = self.workflow.steps[item.stepIndex]
    else
        local mainStep = self.workflow.steps[item.stepIndex]
        step = mainStep and mainStep.support and mainStep.support[item.supportIndex]
    end
    if step == nil then return end

    -- # column: step number for main rows, "└" for support sub-steps
    local numEl = cell:getDescendantByName("stepNum")
    if numEl then
        numEl:setText(item.isMain and tostring(item.stepIndex) or (tostring(item.stepIndex) .. "." .. tostring(item.supportIndex)))
    end

    -- Type column (indent support steps with "  " prefix)
    local typeEl = cell:getDescendantByName("stepType")
    if typeEl then
        local typeText = WorkflowManager:getStepTypeLabel(step.type)
        typeEl:setText(item.isMain and typeText or ("  " .. typeText))
    end

    -- Action column (indent support steps; marker/Park steps have no action)
    local actionEl = cell:getDescendantByName("stepAction")
    if actionEl then
        local actionText = ""
        if not WorkflowManager:isTargetlessStepType(step.type) then
            actionText = self:getActionDisplayName(step.action) or step.action or ""
        end
        actionEl:setText(item.isMain and actionText or ("  " .. actionText))
    end

    -- Target column (indent support steps)
    local targetEl = cell:getDescendantByName("stepTarget")
    if targetEl then
        local targetText = step.target or ""
        targetEl:setText(item.isMain and targetText or ("  " .. targetText))
    end

end

-- ============================================================
-- Action display helper
-- ============================================================

function WMEditorDialog:getActionDisplayName(action)
    local names = {
        drive          = g_i18n:getText("wm_action_drive")          or "Drive To",
        pickup_deliver = g_i18n:getText("wm_action_pickup_deliver") or "Pickup & Deliver",
        deliver        = g_i18n:getText("wm_action_deliver")        or "Deliver",
        load           = g_i18n:getText("wm_action_load")           or "Load",
        unload         = g_i18n:getText("wm_action_unload")         or "Unload",
        fieldwork      = g_i18n:getText("wm_action_fieldwork")      or "Field Work",
        bale_collect   = g_i18n:getText("wm_action_bale_collect")   or "Bale Collect",
    }
    return names[action] or action
end

-- ============================================================
-- Button state
-- ============================================================

function WMEditorDialog:updateButtons()
    local item = self:getSelectedItem()
    local hasSelection = item ~= nil
    local isMain    = hasSelection and item.isMain
    local isSupport = hasSelection and not item.isMain

    -- Edit / Remove work for both types
    if self.editStepButton   then self.editStepButton:setDisabled(not hasSelection)   end
    if self.removeStepButton then self.removeStepButton:setDisabled(not hasSelection) end

    -- Move Up
    if self.moveUpButton then
        local canUp = false
        if isMain    then canUp = item.stepIndex > 1 end
        if isSupport then canUp = item.supportIndex > 1 end
        self.moveUpButton:setDisabled(not canUp)
    end

    -- Add Support Step: only when a main step is selected
    if self.addSupportStepButton then
        self.addSupportStepButton:setDisabled(not isMain)
    end

    -- Move Down
    if self.moveDownButton then
        local canDown = false
        if isMain then
            canDown = item.stepIndex < #(self.workflow and self.workflow.steps or {})
        end
        if isSupport then
            local mainStep = self.workflow and self.workflow.steps[item.stepIndex]
            canDown = item.supportIndex < #(mainStep and mainStep.support or {})
        end
        self.moveDownButton:setDisabled(not canDown)
    end


end

-- ============================================================
-- List callbacks
-- ============================================================

function WMEditorDialog:onStepListSelectionChanged(list, section, index)
    self.selectedFlatIndex = index
    self:updateButtons()
    WMLogger:debug("Selected flat index: %d", index)
end

---Clicking a row in this list does not raise onSelectionChanged (see getSelectedItem), so the
---Up/Down/Add-Support states would keep describing the previously selected row: Up stayed
---enabled on the first support sub-step, Down on the last main step, and so on. The list's own
---selectedIndex is the reliable signal, so poll it and rebuild the button states when it moves.
function WMEditorDialog:update(dt)
    WMEditorDialog:superClass().update(self, dt)

    local listIndex = self.stepList ~= nil and self.stepList.selectedIndex or 0
    if listIndex > 0 and listIndex ~= self.selectedFlatIndex then
        self:updateButtons()   -- getSelectedItem() syncs selectedFlatIndex to the list
    end
end

function WMEditorDialog:onStepListDoubleClick(list, section, index)
    self.selectedFlatIndex = index
    self:onClickEditStep()
end

-- ============================================================
-- Step operations
-- ============================================================

function WMEditorDialog:onNameEnterPressed()
    if self.workflow and self.nameInput then
        self.workflow.name = self.nameInput.text or ""
    end
end

---Add a new main step at the end of the workflow.
function WMEditorDialog:onClickAddStep()
    WorkflowManager:showStepDialog(nil, function(step)
        if step and self.workflow then
            step.support = {}
            table.insert(self.workflow.steps, step)
            -- Select the new main step row after rebuild
            self:buildFlatList()
            self.selectedFlatIndex = self:flatIndexForMainStep(#self.workflow.steps)
            self:refreshStepList()
        end
    end)
end

---Edit the currently selected row (main step or support sub-step).
function WMEditorDialog:onClickEditStep()
    local item = self:getSelectedItem()
    if item == nil or self.workflow == nil then return end

    if item.isMain then
        local step = self.workflow.steps[item.stepIndex]
        if step == nil then return end
        local si = item.stepIndex
        WorkflowManager:showStepDialog(step, function(editedStep)
            if editedStep and self.workflow then
                editedStep.support = step.support or {}  -- preserve nested support
                self.workflow.steps[si] = editedStep
                self:refreshStepList()
            end
        end)
    else
        local mainStep = self.workflow.steps[item.stepIndex]
        if mainStep == nil or mainStep.support == nil then return end
        local supportStep = mainStep.support[item.supportIndex]
        if supportStep == nil then return end
        local si, sj = item.stepIndex, item.supportIndex
        WorkflowManager:showStepDialog(supportStep, function(editedSupportStep)
            if editedSupportStep and self.workflow then
                editedSupportStep.support = nil  -- sub-steps don't nest
                local ms = self.workflow.steps[si]
                if ms and ms.support then
                    ms.support[sj] = editedSupportStep
                end
                self:refreshStepList()
            end
        end, true)
    end
end

---Remove the currently selected row (main step or support sub-step).
function WMEditorDialog:onClickRemoveStep()
    local item = self:getSelectedItem()
    if item == nil or self.workflow == nil then return end

    if item.isMain then
        table.remove(self.workflow.steps, item.stepIndex)
        -- Try to keep selection on same flat position
        self:buildFlatList()
        self.selectedFlatIndex = math.max(1, math.min(self.selectedFlatIndex, #self.flatItems))
        if #self.flatItems == 0 then self.selectedFlatIndex = 0 end
    else
        local mainStep = self.workflow.steps[item.stepIndex]
        if mainStep and mainStep.support then
            table.remove(mainStep.support, item.supportIndex)
        end
        -- Move selection to parent main step row
        self:buildFlatList()
        self.selectedFlatIndex = self:flatIndexForMainStep(item.stepIndex)
        if self.selectedFlatIndex < 1 then self.selectedFlatIndex = 1 end
    end

    self:refreshStepList()
end

---Move selected row up (main steps or support sub-steps).
function WMEditorDialog:onClickMoveUp()
    local item = self:getSelectedItem()
    if item == nil or self.workflow == nil then return end

    if item.isMain then
        if item.stepIndex <= 1 then return end
        local steps = self.workflow.steps
        steps[item.stepIndex], steps[item.stepIndex - 1] = steps[item.stepIndex - 1], steps[item.stepIndex]
        self:buildFlatList()
        self.selectedFlatIndex = self:flatIndexForMainStep(item.stepIndex - 1)
    else
        if item.supportIndex <= 1 then return end
        local sup = self.workflow.steps[item.stepIndex].support
        sup[item.supportIndex], sup[item.supportIndex - 1] = sup[item.supportIndex - 1], sup[item.supportIndex]
        self.selectedFlatIndex = self.selectedFlatIndex - 1
    end

    self:refreshStepList()
end

---Move selected row down (main steps or support sub-steps).
function WMEditorDialog:onClickMoveDown()
    local item = self:getSelectedItem()
    if item == nil or self.workflow == nil then return end

    if item.isMain then
        if item.stepIndex >= #self.workflow.steps then return end
        local steps = self.workflow.steps
        steps[item.stepIndex], steps[item.stepIndex + 1] = steps[item.stepIndex + 1], steps[item.stepIndex]
        self:buildFlatList()
        self.selectedFlatIndex = self:flatIndexForMainStep(item.stepIndex + 1)
    else
        local mainStep = self.workflow.steps[item.stepIndex]
        local sup = mainStep and mainStep.support
        if sup == nil or item.supportIndex >= #sup then return end
        sup[item.supportIndex], sup[item.supportIndex + 1] = sup[item.supportIndex + 1], sup[item.supportIndex]
        self.selectedFlatIndex = self.selectedFlatIndex + 1
    end

    self:refreshStepList()
end

---Open the AD/CP settings dialog for the current workflow.
function WMEditorDialog:onClickADSettings()
    if self.workflow == nil then return end
    WorkflowManager:showADSettingsDialog(self.workflow.adSettings, function(settings)
        if settings ~= nil and self.workflow then
            self.workflow.adSettings = settings
        end
    end)
end

---Add a support sub-step to the currently selected main step.
function WMEditorDialog:onClickAddSupportStep()
    local item = self:getSelectedItem()
    if item == nil or not item.isMain or self.workflow == nil then return end

    local si = item.stepIndex
    WorkflowManager:showStepDialog(nil, function(supportStep)
        if supportStep and self.workflow then
            supportStep.support = nil
            -- Append to the edit buffer, not via WorkflowManager:addSupportStep (which resolves
            -- the workflow by id and would write straight to the live table, bypassing Cancel).
            local mainStep = self.workflow.steps[si]
            if mainStep == nil then return end
            if mainStep.support == nil then mainStep.support = {} end
            table.insert(mainStep.support, supportStep)
            -- Select the newly added support row
            self:buildFlatList()
            local newSj = #mainStep.support
            for i, fi in ipairs(self.flatItems) do
                if not fi.isMain and fi.stepIndex == si and fi.supportIndex == newSj then
                    self.selectedFlatIndex = i
                    break
                end
            end
            self:refreshStepList()
        end
    end, true)
end

-- ============================================================
-- Save / Cancel
-- ============================================================

function WMEditorDialog:onClickSave()
    -- A running execution holds a direct reference to the live workflow (activeData.workflow):
    -- swapping its steps mid-run desyncs currentStep and the followers' sync maps. Block Save
    -- while any vehicle is executing this workflow; the edit buffer stays open for the user.
    if self.sourceWorkflow ~= nil and not self.isNewWorkflow and WMExecutor ~= nil
    and WMExecutor.getActiveVehiclesForWorkflow ~= nil
    and #WMExecutor:getActiveVehiclesForWorkflow(self.sourceWorkflow.id) > 0 then
        local warningText = g_i18n:getText("wm_warning_workflow_running")
            or "Cannot save: workflow is currently running. Stop it first."
        if g_currentMission and g_currentMission.hud and g_currentMission.hud.showBlinkingWarning then
            g_currentMission.hud:showBlinkingWarning(warningText, 2000)
        end
        WMLogger:warning("Save blocked: workflow '%s' is running", self.sourceWorkflow.name)
        return
    end

    if self.workflow and self.nameInput then
        self.workflow.name = self.nameInput.text or self.workflow.name
    end
    self:commitToSource()
    if CPCoursesLoader then CPCoursesLoader:setGuiOpen(false) end
    if CPVehiclesLoader then CPVehiclesLoader:setGuiOpen(false) end
    WorkflowManager:saveWorkflows()
    self:close()
    WorkflowManager:showMainDialog()
end

function WMEditorDialog:onClickCancel()
    -- Discard the edit buffer without committing: the live workflow was never touched, and a
    -- workflow opened as new was never registered, so it disappears with the buffer.
    self.workflow = nil
    self.sourceWorkflow = nil
    self.isNewWorkflow = false
    self.flatItems = {}
    self.selectedFlatIndex = 0
    if CPCoursesLoader then CPCoursesLoader:setGuiOpen(false) end
    if CPVehiclesLoader then CPVehiclesLoader:setGuiOpen(false) end
    self:close()
    WorkflowManager:showMainDialog()
end

function WMEditorDialog:onEscPressed()
    self:onClickCancel()
end

-- ============================================================
-- Cache accessors (used by WMStepDialog)
-- ============================================================

function WMEditorDialog:getADDestinations() return self.cachedADDestinations or {} end
function WMEditorDialog:getCPCourses()      return self.cachedCPCourses or {}      end
function WMEditorDialog:getFillTypes()      return self.cachedFillTypes or {}      end

-- ============================================================
-- Input events
-- ============================================================

function WMEditorDialog:registerInputEvents()
    self.inputEventIds = {}

    local function reg(action, handler)
        local _, eventId = g_inputBinding:registerActionEvent(InputAction[action], self, handler, false, true, false, true)
        if eventId then
            table.insert(self.inputEventIds, eventId)
            g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
            g_inputBinding:setActionEventTextVisibility(eventId, false)
        end
    end

    reg("WM_GUI_DELETE",    self.onInputRemove)
    reg("WM_GUI_MOVE_UP",   self.onInputMoveUp)
    reg("WM_GUI_MOVE_DOWN", self.onInputMoveDown)
end

function WMEditorDialog:unregisterInputEvents()
    for _, eventId in ipairs(self.inputEventIds or {}) do
        g_inputBinding:removeActionEvent(eventId)
    end
    self.inputEventIds = {}
end

function WMEditorDialog:onInputRemove()
    if self.removeStepButton and not self.removeStepButton.disabled then self:onClickRemoveStep() end
end

function WMEditorDialog:onInputMoveUp()
    if self.moveUpButton and not self.moveUpButton.disabled then self:onClickMoveUp() end
end

function WMEditorDialog:onInputMoveDown()
    if self.moveDownButton and not self.moveDownButton.disabled then self:onClickMoveDown() end
end
