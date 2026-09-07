--[[
    WorkflowManager - Step Dialog
    Allows adding/editing workflow steps with searchable dropdowns
    Uses proper FS25 DialogElement for input blocking

    Author: WorkflowManager Team
]]

---@class WMStepDialog
WMStepDialog = {}

local WMStepDialog_mt = Class(WMStepDialog, DialogElement)

function WMStepDialog.new(target)
    local self = DialogElement.new(target, WMStepDialog_mt)
    self.step = nil
    self.callback = nil
    self.isEditMode = false
    -- true when editing/adding a support sub-step (restricts the selectable type list)
    self.isSupportStep = false

    -- Step data
    self.stepType = "autodrive"
    self.stepAction = "drive"
    self.stepTarget = ""
    self.stepUnloadTarget = ""
    self.selectedFillTypes = {}  -- array of selected fill type name strings
    self.stepSeedFruitType = ""  -- fruit type name ("WHEAT"), "" = keep whatever is selected
    self.ctrlPressed = false

    -- List data
    self.targetItems = {}
    self.filteredTargetItems = {}
    self.selectedTargetIndex = 0

    self.unloadTargetItems = {}
    self.filteredUnloadTargetItems = {}
    self.selectedUnloadTargetIndex = 0

    self.fillTypeItems = {}
    self.filteredFillTypeItems = {}

    self.seedTypeItems = {}

    -- Flag to suppress list-callback recursion (set before any reloadData inside a callback)
    self.isFiltering = false

    return self
end

function WMStepDialog:onCreate()
    WMLogger:debug("WMStepDialog:onCreate")
end

function WMStepDialog:onOpen()
    WMStepDialog:superClass().onOpen(self)
    WMLogger:debug("WMStepDialog:onOpen")
    WMHud:onDialogOpened()

    -- Manually set callbacks for dropdowns (XML callback binding doesn't work for MultiTextOption)
    if self.typeDropdown ~= nil then
        local dialog = self
        self.typeDropdown.onClickCallback = function(_, state)
            dialog:onTypeChanged(nil, state)
        end
    end
    if self.actionDropdown ~= nil then
        local dialog = self
        self.actionDropdown.onClickCallback = function(_, state)
            dialog:onActionChanged(nil, state)
        end
    end
    if self.seedTypeDropdown ~= nil then
        local dialog = self
        self.seedTypeDropdown.onClickCallback = function(_, state)
            dialog:onSeedTypeChanged(nil, state)
        end
    end
    -- Setup list data sources and callbacks
    local dialog = self
    if self.targetList ~= nil then
        self.targetList:setDataSource(self)
        self.targetList.dataSourceId = "target"
        self.targetList.target = self
        self.targetList.onSelectionChanged = function(list, section, index)
            dialog:onTargetListSelectionChanged(list, section, index)
        end
        if self.targetList.setCallback then
            self.targetList:setCallback("onSelectionChanged", self, "onTargetListSelectionChanged")
        end
    end
    if self.unloadTargetList ~= nil then
        self.unloadTargetList:setDataSource(self)
        self.unloadTargetList.dataSourceId = "unloadTarget"
        self.unloadTargetList.target = self
        self.unloadTargetList.onSelectionChanged = function(list, section, index)
            dialog:onUnloadTargetListSelectionChanged(list, section, index)
        end
        if self.unloadTargetList.setCallback then
            self.unloadTargetList:setCallback("onSelectionChanged", self, "onUnloadTargetListSelectionChanged")
        end
    end
    if self.fillTypeList ~= nil then
        self.fillTypeList:setDataSource(self)
        self.fillTypeList.dataSourceId = "fillType"
        self.fillTypeList.target = self
        self.fillTypeList.onSelectionChanged = function(list, section, index)
            dialog:onFillTypeListSelectionChanged(list, section, index)
        end
        if self.fillTypeList.setCallback then
            self.fillTypeList:setCallback("onSelectionChanged", self, "onFillTypeListSelectionChanged")
        end
    end

    -- Load available targets and fill types
    self:loadAvailableData()

    -- Apply initial values
    self:refreshDisplay()
end

function WMStepDialog:onClose()
    WMStepDialog:superClass().onClose(self)
    WMLogger:debug("WMStepDialog:onClose")
    WMHud:onDialogClosed()
    self.ctrlPressed = false
end

function WMStepDialog:keyEvent(unicode, sym, mod, isDown, isUp, ...)
    if sym == Input.KEY_lctrl or sym == Input.KEY_rctrl then
        self.ctrlPressed = isDown
    end
    return WMStepDialog:superClass().keyEvent(self, unicode, sym, mod, isDown, isUp, ...)
end

---Set the step to edit (nil for new step)
---@param step table|nil Step to edit, or nil for new
---@param callback function Callback when done: callback(step) or callback(nil) if cancelled
---@param isSupportStep boolean|nil true when this is a support sub-step (hides sync marker types)
function WMStepDialog:setStep(step, callback, isSupportStep)
    self.callback = callback
    self.isEditMode = step ~= nil
    self.isSupportStep = isSupportStep == true

    if step then
        self.step = step
        self.stepType = step.type or "autodrive"
        self.stepAction = step.action or "drive"
        self.stepTarget = step.target or ""
        self.stepUnloadTarget = step.unloadTarget or ""
        self.selectedFillTypes = step.fillTypes and {unpack(step.fillTypes)} or {}
        self.stepSeedFruitType = step.seedFruitType or ""
    else
        self.step = nil
        self.stepType = "autodrive"
        self.stepAction = "drive"
        self.stepTarget = ""
        self.stepUnloadTarget = ""
        self.selectedFillTypes = {}
        self.stepSeedFruitType = ""
    end
end

---Load available data from caches
function WMStepDialog:loadAvailableData()
    -- Get editor dialog for cached data
    local editor = WorkflowManager.editorDialog

    -- Load targets based on type
    self:refreshTargetList()

    -- Load fill types (name = internal ID like "WHEAT", display = localized title like "Wheat")
    self.fillTypeItems = {}
    if editor then
        local fillTypes = editor:getFillTypes()
        for _, ft in ipairs(fillTypes) do
            table.insert(self.fillTypeItems, {name = ft.name, display = ft.title or ft.name})
        end
    end
    self.filteredFillTypeItems = self.fillTypeItems

    -- Load seed types (name = fruit type ID like "WHEAT", display = localized fill type title)
    self.seedTypeItems = {}
    if editor and editor.getSeedTypes then
        for _, st in ipairs(editor:getSeedTypes()) do
            table.insert(self.seedTypeItems, {name = st.name, display = st.title or st.name})
        end
    end
end

---Refresh the target list based on current step type
function WMStepDialog:refreshTargetList()
    local editor = WorkflowManager.editorDialog
    self.targetItems = {}

    if self.stepType == WorkflowManager.STEP_AUTODRIVE then
        if editor then
            local dests = editor:getADDestinations()
            for _, dest in ipairs(dests) do
                table.insert(self.targetItems, {name = dest, display = dest})
            end
        end
    else
        if editor then
            local courses = editor:getCPCourses()
            for _, course in ipairs(courses) do
                table.insert(self.targetItems, {name = course, display = course})
            end
        end
    end

    -- Unload targets use same list as targets (AD destinations)
    self.unloadTargetItems = {}
    if editor then
        local dests = editor:getADDestinations()
        for _, dest in ipairs(dests) do
            table.insert(self.unloadTargetItems, {name = dest, display = dest})
        end
    end

    self.filteredTargetItems = self.targetItems
    self.filteredUnloadTargetItems = self.unloadTargetItems
end

---Refresh the display with current values
function WMStepDialog:refreshDisplay()
    -- Update title
    if self.titleElement then
        local titleKey = self.isEditMode and "wm_dialog_edit_step" or "wm_dialog_add_step"
        self.titleElement:setText(g_i18n:getText(titleKey))
    end

    -- Update type dropdown
    self:refreshTypeDropdown()

    -- Update action dropdown
    self:refreshActionDropdown()

    -- Update seed type dropdown
    self:refreshSeedTypeDropdown()

    -- Update input field values
    self:setInputFieldValues()

    -- Update target list
    self:refreshTargetDisplay()

    -- Update visibility of unload target and fill type
    self:updateFieldVisibility()
end

---Refresh type dropdown options
function WMStepDialog:refreshTypeDropdown()
    if self.typeDropdown == nil then
        return
    end

    local types = self:getStepTypes()
    -- Snapshot the rendered list: getStepTypes() depends on the CURRENT stepType (marker
    -- entries appear only for legacy marker sub-steps), so onTypeChanged must map click
    -- indices against what is actually displayed, not against a freshly recomputed list.
    self.renderedStepTypes = types
    local texts = {}
    for _, t in ipairs(types) do
        table.insert(texts, WorkflowManager:getStepTypeLabel(t))
    end
    self.typeDropdown:setTexts(texts)

    -- Find current type index
    local currentIndex = 1
    for i, t in ipairs(types) do
        if t == self.stepType then
            currentIndex = i
            break
        end
    end
    self.typeDropdown:setState(currentIndex)
end

---Ordered list of selectable step types (must match onTypeChanged indexing).
---Sync markers are omitted for support sub-steps: leader/follower pairing is built from
---workflow.steps only (see WMExecutor:buildSyncMaps), so a marker nested under a main step
---has nothing to pair with and would abort the workflow at runtime.
function WMStepDialog:getStepTypes()
    local types = {
        WorkflowManager.STEP_AUTODRIVE,
        WorkflowManager.STEP_COURSEPLAY,
    }
    -- Exception: keep them listed when the step being edited already is a marker (data saved
    -- before this restriction existed), so the dropdown reflects reality and can convert it.
    if not self.isSupportStep or WorkflowManager:isMarkerStepType(self.stepType) then
        table.insert(types, WorkflowManager.STEP_WAIT_FOR_LEADER)
        table.insert(types, WorkflowManager.STEP_UNLOCK_FOLLOWER)
    end
    table.insert(types, WorkflowManager.STEP_PARK)
    table.insert(types, WorkflowManager.STEP_REFUEL)
    table.insert(types, WorkflowManager.STEP_REPAIR)
    return types
end

---True if the currently selected step type has no target/action fields (sync marker, Park, Refuel, or Repair)
function WMStepDialog:isMarkerStep()
    return WorkflowManager:isTargetlessStepType(self.stepType)
end

---Refresh action dropdown options
function WMStepDialog:refreshActionDropdown()
    if self.actionDropdown == nil then
        return
    end

    local actions = self:getAvailableActions()
    local texts = {}
    for _, action in ipairs(actions) do
        table.insert(texts, self:getActionDisplayName(action))
    end

    self.actionDropdown:setTexts(texts)

    -- Find current action index
    local currentIndex = 1
    for i, action in ipairs(actions) do
        if action == self.stepAction then
            currentIndex = i
            break
        end
    end

    self.actionDropdown:setState(currentIndex)
end

---Refresh seed type dropdown options. Entry 1 is "none" (leave the machine's current seed).
function WMStepDialog:refreshSeedTypeDropdown()
    if self.seedTypeDropdown == nil then
        return
    end

    -- Snapshot the rendered list: the change handler must map click indices against what is
    -- actually displayed, never against a freshly built list (see refreshTypeDropdown).
    self.renderedSeedTypes = self.seedTypeItems or {}

    local texts = {g_i18n:getText("wm_none") or "None"}
    local currentIndex = 1
    for i, item in ipairs(self.renderedSeedTypes) do
        table.insert(texts, item.display)
        if item.name == self.stepSeedFruitType then
            currentIndex = i + 1
        end
    end

    self.seedTypeDropdown:setTexts(texts)
    self.seedTypeDropdown:setState(currentIndex)
end

---Get available actions based on step type
function WMStepDialog:getAvailableActions()
    if self.stepType == WorkflowManager.STEP_AUTODRIVE then
        return {"drive", "pickup_deliver", "deliver", "load", "unload"}
    else
        return {"fieldwork", "bale_collect"}
    end
end

---Get display name for an action
function WMStepDialog:getActionDisplayName(action)
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

---SmoothList data source: Get number of items
function WMStepDialog:getNumberOfItemsInSection(list, section)
    if list.dataSourceId == "target" then
        return #self.filteredTargetItems
    elseif list.dataSourceId == "unloadTarget" then
        return #self.filteredUnloadTargetItems
    elseif list.dataSourceId == "fillType" then
        return #self.filteredFillTypeItems
    end
    return 0
end

---SmoothList data source: Called when selection changes (delegate method)
function WMStepDialog:onListSelectionChanged(list, section, index)
    -- Ignore selection changes during filtering to prevent feedback loop
    if self.isFiltering then
        return
    end

    if list.dataSourceId == "target" then
        self:onTargetListSelectionChanged(list, section, index)
    elseif list.dataSourceId == "unloadTarget" then
        self:onUnloadTargetListSelectionChanged(list, section, index)
    elseif list.dataSourceId == "fillType" then
        self:onFillTypeListSelectionChanged(list, section, index)
    end
end

---SmoothList data source: Populate cell
function WMStepDialog:populateCellForItemInSection(list, section, index, cell)
    if list.dataSourceId == "target" then
        local item = self.filteredTargetItems[index]
        if item then
            local textElement = cell:getDescendantByName("targetText")
            if textElement then
                textElement:setText(item.display)
            end
        end
    elseif list.dataSourceId == "unloadTarget" then
        local item = self.filteredUnloadTargetItems[index]
        if item then
            local textElement = cell:getDescendantByName("unloadTargetText")
            if textElement then
                textElement:setText(item.display)
            end
        end
    elseif list.dataSourceId == "fillType" then
        local item = self.filteredFillTypeItems[index]
        if item then
            local textElement = cell:getDescendantByName("fillTypeText")
            if textElement then
                local isSelected = false
                for _, name in ipairs(self.selectedFillTypes) do
                    if name == item.name then isSelected = true; break end
                end
                textElement:setText((isSelected and "✓ " or "  ") .. item.display)
                if isSelected then
                    textElement:setTextColor(0.0, 0.85, 0.17, 1)
                else
                    textElement:setTextColor(1, 1, 1, 1)
                end
            end
        end
    end
end

---Refresh target list display
function WMStepDialog:refreshTargetDisplay()
    -- Set flag to ignore selection callbacks during refresh
    self.isFiltering = true

    -- Refresh target list
    if self.targetList then
        self.targetList:reloadData()

        -- Select current target
        self.selectedTargetIndex = 0
        for i, item in ipairs(self.filteredTargetItems) do
            if item.name == self.stepTarget then
                self.selectedTargetIndex = i
                self.targetList:setSelectedIndex(i)
                self:updateSelectedLabel("target", item.display)
                break
            end
        end
        if self.selectedTargetIndex == 0 then
            self:updateSelectedLabel("target", nil)
        end
    end

    -- Refresh unload target list
    if self.unloadTargetList then
        self.unloadTargetList:reloadData()

        -- Select current unload target
        self.selectedUnloadTargetIndex = 0
        for i, item in ipairs(self.filteredUnloadTargetItems) do
            if item.name == self.stepUnloadTarget then
                self.selectedUnloadTargetIndex = i
                self.unloadTargetList:setSelectedIndex(i)
                self:updateSelectedLabel("unloadTarget", item.display)
                break
            end
        end
        if self.selectedUnloadTargetIndex == 0 then
            self:updateSelectedLabel("unloadTarget", nil)
        end
    end

    -- Refresh fill type list (multi-select: checkmarks in populateCellForItemInSection)
    if self.fillTypeList then
        self.fillTypeList:reloadData()
        self:updateFillTypeLabel()
    end

    -- Clear filtering flag
    self.isFiltering = false
end

---Set input field values from current step data (called on open for edit mode)
function WMStepDialog:setInputFieldValues()
    -- Input fields are for filtering only, so leave them empty
    -- The selected value is shown by the highlighted item in the list
    if self.targetSearchInput then
        self.targetSearchInput:setText("")
    end
    if self.unloadTargetSearchInput then
        self.unloadTargetSearchInput:setText("")
    end
    if self.fillTypeSearchInput then
        self.fillTypeSearchInput:setText("")
    end
end

---Update field visibility based on step type and action
function WMStepDialog:updateFieldVisibility()
    -- Marker steps (wait_for_leader/unlock_follower) and Park need no action/target/unload/fill fields
    local isMarker = self:isMarkerStep()
    local needsUnloadTarget = not isMarker and self:actionNeedsUnloadTarget()
    local needsFillType = not isMarker and self:actionNeedsFillType()
    local needsSeedType = not isMarker and self:actionNeedsSeedType()

    -- Action + target rows are hidden entirely for marker steps
    if self.actionRow then self.actionRow:setVisible(not isMarker) end
    if self.targetRow then self.targetRow:setVisible(not isMarker) end
    if self.targetSelectedRow then self.targetSelectedRow:setVisible(not isMarker) end
    if self.targetDropdownContainer then self.targetDropdownContainer:setVisible(not isMarker) end

    -- Seed type row (Courseplay field work only)
    if self.seedTypeRow then self.seedTypeRow:setVisible(needsSeedType) end

    -- Update unload target label based on action
    if self.unloadTargetLabel then
        if self.stepAction == "load" then
            self.unloadTargetLabel:setText(g_i18n:getText("wm_editor_load_point") or "Load Point")
        else
            self.unloadTargetLabel:setText(g_i18n:getText("wm_editor_unload_target") or "Deliver To")
        end
    end

    -- Unload target section, selected label, and list
    if self.unloadTargetSection then
        self.unloadTargetSection:setVisible(needsUnloadTarget)
    end
    if self.unloadSelectedRow then
        self.unloadSelectedRow:setVisible(needsUnloadTarget)
    end
    if self.unloadTargetDropdownContainer then
        self.unloadTargetDropdownContainer:setVisible(needsUnloadTarget)
    end

    -- Fill type section, selected label, and list
    if self.fillTypeSection then
        self.fillTypeSection:setVisible(needsFillType)
    end
    if self.fillTypeSelectedRow then
        self.fillTypeSelectedRow:setVisible(needsFillType)
    end
    if self.fillTypeDropdownContainer then
        self.fillTypeDropdownContainer:setVisible(needsFillType)
    end
end

---Check if current action needs unload target
function WMStepDialog:actionNeedsUnloadTarget()
    if self.stepType ~= WorkflowManager.STEP_AUTODRIVE then
        return false
    end
    return self.stepAction == "unload" or self.stepAction == "pickup_deliver" or self.stepAction == "load"
end

---Check if current action needs fill type
function WMStepDialog:actionNeedsFillType()
    if self.stepType ~= WorkflowManager.STEP_AUTODRIVE then
        return false
    end
    return self.stepAction == "pickup_deliver" or self.stepAction == "load"
end

---Check if current action can select a seed type (Courseplay field work only)
function WMStepDialog:actionNeedsSeedType()
    return self.stepType == WorkflowManager.STEP_COURSEPLAY and self.stepAction == "fieldwork"
end

---Filter target list by search text
function WMStepDialog:filterTargets(searchText)
    searchText = string.lower(searchText or "")
    self.filteredTargetItems = {}

    if searchText == "" then
        self.filteredTargetItems = self.targetItems
    else
        for _, item in ipairs(self.targetItems) do
            if string.find(string.lower(item.display), searchText, 1, true) then
                table.insert(self.filteredTargetItems, item)
            end
        end
    end

    -- Reload list
    self.isFiltering = true
    if self.targetList then
        self.targetList:reloadData()
    end
    self.isFiltering = false

    -- Auto-select when exactly one result matches
    if #self.filteredTargetItems == 1 then
        self.selectedTargetIndex = 1
        self.stepTarget = self.filteredTargetItems[1].name
        if self.targetList then self.targetList:setSelectedIndex(1) end
        self:updateSelectedLabel("target", self.filteredTargetItems[1].display)
    end
end

---Filter unload target list by search text
function WMStepDialog:filterUnloadTargets(searchText)
    searchText = string.lower(searchText or "")
    self.filteredUnloadTargetItems = {}

    if searchText == "" then
        self.filteredUnloadTargetItems = self.unloadTargetItems
    else
        for _, item in ipairs(self.unloadTargetItems) do
            if string.find(string.lower(item.display), searchText, 1, true) then
                table.insert(self.filteredUnloadTargetItems, item)
            end
        end
    end

    -- Reload list
    self.isFiltering = true
    if self.unloadTargetList then
        self.unloadTargetList:reloadData()
    end
    self.isFiltering = false

    -- Auto-select when exactly one result matches
    if #self.filteredUnloadTargetItems == 1 then
        self.selectedUnloadTargetIndex = 1
        self.stepUnloadTarget = self.filteredUnloadTargetItems[1].name
        if self.unloadTargetList then self.unloadTargetList:setSelectedIndex(1) end
        self:updateSelectedLabel("unloadTarget", self.filteredUnloadTargetItems[1].display)
    end
end

---Filter fill type list by search text
function WMStepDialog:filterFillTypes(searchText)
    searchText = string.lower(searchText or "")
    self.filteredFillTypeItems = {}

    if searchText == "" then
        self.filteredFillTypeItems = self.fillTypeItems
    else
        for _, item in ipairs(self.fillTypeItems) do
            if string.find(string.lower(item.display), searchText, 1, true) then
                table.insert(self.filteredFillTypeItems, item)
            end
        end
    end

    self.isFiltering = true
    if self.fillTypeList then
        self.fillTypeList:reloadData()
    end
    self.isFiltering = false
end

---Update the "Selected: ..." label for a given field
---@param field string "target", "unloadTarget", or "fillType"
---@param displayName string|nil The selected item's display name, or nil to clear
function WMStepDialog:updateSelectedLabel(field, displayName)
    local prefix = g_i18n:getText("wm_step_selected") or "Selected"
    local text = displayName and (prefix .. ": " .. displayName) or ""

    if field == "target" and self.selectedTargetLabel then
        self.selectedTargetLabel:setText(text)
    elseif field == "unloadTarget" and self.selectedUnloadTargetLabel then
        self.selectedUnloadTargetLabel:setText(text)
    end
end

---Update the "Selected: ..." label for fill types from self.selectedFillTypes
function WMStepDialog:updateFillTypeLabel()
    if not self.selectedFillTypeLabel then return end
    local prefix = g_i18n:getText("wm_step_selected") or "Selected"
    local none = g_i18n:getText("wm_none") or "(None)"
    if #self.selectedFillTypes == 0 then
        self.selectedFillTypeLabel:setText("(" .. none .. ")")
        return
    end
    local displayNames = {}
    for _, name in ipairs(self.selectedFillTypes) do
        local displayName = name
        for _, item in ipairs(self.fillTypeItems) do
            if item.name == name then displayName = item.display; break end
        end
        table.insert(displayNames, displayName)
    end
    local text
    if #displayNames <= 2 then
        text = prefix .. ": " .. table.concat(displayNames, ", ")
    else
        text = prefix .. ": " .. #displayNames .. " selected"
    end
    self.selectedFillTypeLabel:setText(text)
end


-- Event handlers

---Called when type dropdown changes
function WMStepDialog:onTypeChanged(element, state)
    -- Handle both (state) and (element, state) signatures
    if state == nil then
        state = element
    end

    -- Map the click index against the list the dropdown was rendered with — recomputing
    -- getStepTypes() here desyncs after the first type change (the list shrinks once the
    -- step is no longer a legacy marker, silently remapping the visible labels).
    local types = self.renderedStepTypes or self:getStepTypes()
    local defaultActions = {[WorkflowManager.STEP_AUTODRIVE] = "drive", [WorkflowManager.STEP_COURSEPLAY] = "fieldwork"}

    if type(state) == "number" and state > 0 and state <= #types then
        local newType = types[state]
        if self.stepType ~= newType then
            self.stepType = newType
            self.stepAction = defaultActions[newType]

            -- Clear target
            self.stepTarget = ""
            if self.targetSearchInput then
                self.targetSearchInput:setText("")
            end

            -- Clear unload target (not applicable for courseplay)
            self.stepUnloadTarget = ""
            if self.unloadTargetSearchInput then
                self.unloadTargetSearchInput:setText("")
            end

            -- Clear fill type (not applicable for courseplay)
            self.selectedFillTypes = {}
            if self.fillTypeSearchInput then
                self.fillTypeSearchInput:setText("")
            end

            -- Clear seed type if the new type/default action can't carry one
            if not self:actionNeedsSeedType() then
                self.stepSeedFruitType = ""
            end

            self:refreshTargetList()
            self:refreshActionDropdown()
            self:refreshSeedTypeDropdown()
            self:refreshTargetDisplay()
            self:updateFieldVisibility()
        end
    end
end

---Called when action dropdown changes
function WMStepDialog:onActionChanged(element, state)
    -- Handle both (state) and (element, state) signatures
    if state == nil then
        state = element
    end

    local actions = self:getAvailableActions()
    if type(state) == "number" and state > 0 and state <= #actions then
        self.stepAction = actions[state]

        -- Clear unload target if new action doesn't need it
        if not self:actionNeedsUnloadTarget() then
            self.stepUnloadTarget = ""
            if self.unloadTargetSearchInput then
                self.unloadTargetSearchInput:setText("")
            end
        end

        -- Clear fill type if new action doesn't need it
        if not self:actionNeedsFillType() then
            self.selectedFillTypes = {}
            if self.fillTypeSearchInput then
                self.fillTypeSearchInput:setText("")
            end
        end

        -- Clear seed type if new action can't carry one
        if not self:actionNeedsSeedType() then
            self.stepSeedFruitType = ""
        end
        self:refreshSeedTypeDropdown()

        self:updateFieldVisibility()
    end
end

---Called when seed type dropdown changes
function WMStepDialog:onSeedTypeChanged(element, state)
    -- Handle both (state) and (element, state) signatures
    if state == nil then
        state = element
    end

    -- Index 1 is the "none" entry; the rest map onto the list the dropdown was rendered with
    local items = self.renderedSeedTypes or self.seedTypeItems or {}
    if type(state) == "number" and state > 0 and state <= #items + 1 then
        if state == 1 then
            self.stepSeedFruitType = ""
        else
            self.stepSeedFruitType = items[state - 1].name
        end
    end
end

---Called when target search text changes
function WMStepDialog:onTargetSearchChanged()
    if self.targetSearchInput then
        self:filterTargets(self.targetSearchInput.text)
    end
end

---Called when target list selection changes
function WMStepDialog:onTargetListSelectionChanged(list, section, index)
    self.selectedTargetIndex = index
    if index > 0 and index <= #self.filteredTargetItems then
        local item = self.filteredTargetItems[index]
        self.stepTarget = item.name
        self:updateSelectedLabel("target", item.display)
    end
end

---Called when unload target search text changes
function WMStepDialog:onUnloadTargetSearchChanged()
    if self.unloadTargetSearchInput then
        self:filterUnloadTargets(self.unloadTargetSearchInput.text)
    end
end

---Called when unload target list selection changes
function WMStepDialog:onUnloadTargetListSelectionChanged(list, section, index)
    self.selectedUnloadTargetIndex = index
    if index > 0 and index <= #self.filteredUnloadTargetItems then
        local item = self.filteredUnloadTargetItems[index]
        self.stepUnloadTarget = item.name
        self:updateSelectedLabel("unloadTarget", item.display)
    end
end

---Called when fill type search text changes
function WMStepDialog:onFillTypeSearchChanged()
    if self.fillTypeSearchInput then
        self:filterFillTypes(self.fillTypeSearchInput.text)
    end
end

---Called when fill type list selection changes
---Plain click = single-select; Ctrl+click = toggle (add/remove)
function WMStepDialog:onFillTypeListSelectionChanged(list, section, index)
    if self.isFiltering then return end
    if index > 0 and index <= #self.filteredFillTypeItems then
        local item = self.filteredFillTypeItems[index]
        if self.ctrlPressed then
            local found = false
            for i, name in ipairs(self.selectedFillTypes) do
                if name == item.name then
                    table.remove(self.selectedFillTypes, i)
                    found = true
                    break
                end
            end
            if not found then
                table.insert(self.selectedFillTypes, item.name)
            end
        else
            self.selectedFillTypes = {item.name}
        end
        self.isFiltering = true
        self.fillTypeList:reloadData()
        self.isFiltering = false
        self:updateFillTypeLabel()
    end
end

---Called when Confirm button is clicked
function WMStepDialog:onClickConfirm()
    local step

    if self:isMarkerStep() then
        -- Sync marker: only the type matters (no target/action)
        step = { type = self.stepType, target = "" }
    else
        -- Validate - target is required for AD/CP steps. Warn instead of returning silently:
        -- a dead OK button reads as a broken dialog.
        if self.stepTarget == "" then
            local warningText = g_i18n:getText("wm_warning_no_target")
                or "Select a target before confirming the step."
            if g_currentMission and g_currentMission.hud and g_currentMission.hud.showBlinkingWarning then
                g_currentMission.hud:showBlinkingWarning(warningText, 2000)
            end
            WMLogger:warning("Step confirm blocked: no target selected for type '%s'", tostring(self.stepType))
            return
        end

        step = {
            type = self.stepType,
            action = self.stepAction,
            target = self.stepTarget
        }

        -- Add AD-specific fields
        if self.stepType == WorkflowManager.STEP_AUTODRIVE then
            if self:actionNeedsUnloadTarget() and self.stepUnloadTarget ~= "" then
                step.unloadTarget = self.stepUnloadTarget
            end
            if self:actionNeedsFillType() and #self.selectedFillTypes > 0 then
                step.fillTypes = {unpack(self.selectedFillTypes)}
            end
        elseif self.stepType == WorkflowManager.STEP_COURSEPLAY then
            if self:actionNeedsSeedType() and self.stepSeedFruitType ~= "" then
                step.seedFruitType = self.stepSeedFruitType
            end
        end
    end

    self:close()

    if self.callback then
        self.callback(step)
    end
end

---Called when Cancel button is clicked
function WMStepDialog:onClickCancel()
    WMLogger:debug("WMStepDialog:onClickCancel")
    self:close()

    if self.callback then
        self.callback(nil)
    end
end

---Called when Escape is pressed
function WMStepDialog:onEscPressed()
    self:onClickCancel()
end
