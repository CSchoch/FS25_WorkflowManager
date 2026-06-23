--[[
    WorkflowManager - Workflow Editor GUI
    Allows editing workflow details and steps
    Fully button-based interface (no keyboard shortcuts required)

    Author: WorkflowManager Team
]]

---@class WMEditorGUI
WMEditorGUI = {}

WMEditorGUI.isVisible = false
WMEditorGUI.currentWorkflow = nil
WMEditorGUI.selectedStepIndex = 0
WMEditorGUI.isAddStepDialogOpen = false
WMEditorGUI.isEditStepDialogOpen = false
WMEditorGUI.editingStepIndex = 0

-- Add/Edit step dialog state
WMEditorGUI.addStepType = "autodrive"
WMEditorGUI.addStepTargetIndex = 0
WMEditorGUI.addStepActionIndex = 1
WMEditorGUI.availableTargets = {}

-- AutoDrive advanced mode parameters
WMEditorGUI.addStepUnloadTargetIndex = 0
WMEditorGUI.addStepFillTypeIndex = 0
WMEditorGUI.availableFillTypes = {}

-- Milestone 4: Vehicle selection removed from editor
-- Vehicles are now detected at runtime when starting a workflow

-- Cached data for AD destinations and CP courses (loaded once when GUI opens)
WMEditorGUI.cachedADDestinations = nil  -- Cached AutoDrive destinations
WMEditorGUI.cachedCPCourses = nil       -- Cached Courseplay courses
WMEditorGUI.cachedFillTypes = nil       -- Cached fill types
WMEditorGUI.dataCacheLoaded = false     -- Flag to indicate if cache is loaded

-- Editing state
WMEditorGUI.editedName = ""

-- Mouse tracking
WMEditorGUI.mouseX = 0
WMEditorGUI.mouseY = 0
WMEditorGUI.wasMouseDown = false

-- Double-click tracking for step list
WMEditorGUI.lastClickTime = 0
WMEditorGUI.lastClickStepIndex = 0
WMEditorGUI.DOUBLE_CLICK_THRESHOLD = 400  -- milliseconds

-- Dropdown state
WMEditorGUI.openDropdown = nil  -- Name of currently open dropdown (nil = none open)
WMEditorGUI.dropdownScrollOffset = 0  -- Scroll offset for long lists
WMEditorGUI.DROPDOWN_MAX_VISIBLE = 8  -- Max items visible in dropdown
WMEditorGUI.DROPDOWN_ITEM_HEIGHT = 0.03  -- Height of each dropdown item

-- Overlay ID for rendering
WMEditorGUI.overlayId = nil

-- Layout constants
WMEditorGUI.LAYOUT = {
    bgX = 0.15,
    bgY = 0.08,
    bgW = 0.7,
    bgH = 0.84,
    buttonW = 0.10,
    buttonH = 0.04,
    smallBtnW = 0.04,
    smallBtnH = 0.035,
    rowHeight = 0.045,
    margin = 0.015,
    spacing = 0.01
}

---Initialize the editor GUI
function WMEditorGUI:init()
    self.isVisible = false
    self.currentWorkflow = nil
    self.selectedStepIndex = 0
    -- Milestone 4: Vehicle selection removed

    -- Initialize cache as empty (will be loaded when main GUI opens)
    self.cachedADDestinations = nil
    self.cachedCPCourses = nil
    self.cachedFillTypes = nil
    self.dataCacheLoaded = false

    -- Initialize dropdown state
    self.openDropdown = nil
    self.dropdownScrollOffset = 0
    -- Milestone 4: vehicleDropdownPos removed
    self.dialogDropdowns = {}

    -- Create own overlay from white.dds texture
    self.overlayId = nil

    if WorkflowManager.modDirectory ~= nil then
        local whiteTexture = Utils.getFilename("textures/white.dds", WorkflowManager.modDirectory)
        self.overlayId = createImageOverlay(whiteTexture)
        if self.overlayId ~= nil and self.overlayId ~= 0 then
            WMLogger:debug("Editor created overlay from: %s (ID: %s)", whiteTexture, tostring(self.overlayId))
        else
            WMLogger:error("Editor failed to create overlay from: %s", whiteTexture)
        end
    end

    if self.overlayId == nil or self.overlayId == 0 then
        WMLogger:warning("Editor could not create overlay")
    end

    WMLogger:debug("WorkflowEditorGUI initialized")
end

---Open the editor for a workflow
---@param workflow table Workflow to edit
function WMEditorGUI:openWorkflow(workflow)
    if workflow == nil then
        WMLogger:error("Cannot open editor - workflow is nil")
        return
    end

    -- Check if overlay exists, recreate if needed
    if self.overlayId == nil or self.overlayId == 0 then
        if WorkflowManager.modDirectory ~= nil then
            local whiteTexture = Utils.getFilename("textures/white.dds", WorkflowManager.modDirectory)
            self.overlayId = createImageOverlay(whiteTexture)
            WMLogger:debug("Editor recreated overlay (ID: %s)", tostring(self.overlayId))
        end
    end

    if self.overlayId == nil or self.overlayId == 0 then
        WMLogger:error("Cannot open editor - no overlay available")
        return
    end

    self.currentWorkflow = workflow
    self.selectedStepIndex = 0
    self.isVisible = true
    self.isAddStepDialogOpen = false
    self.editedName = workflow.name or ""

    -- Tell loaders to start scanning (only while GUI is open)
    CPCoursesLoader:setGuiOpen(true)
    CPVehiclesLoader:setGuiOpen(true)

    -- Load data cache (AD destinations, CP courses, fill types)
    self:loadDataCache()

    -- Milestone 4: Vehicle selection removed from editor
    -- Vehicles are detected at runtime when starting a workflow

    WMLogger:debug("Opened editor for workflow: %s", workflow.name)
end

---Close the editor
function WMEditorGUI:close()
    self.isVisible = false
    self.currentWorkflow = nil
    self.selectedStepIndex = 0
    self.isAddStepDialogOpen = false
    self.isEditStepDialogOpen = false

    -- Close any open dropdown
    self:closeDropdown()

    -- Stop loaders scanning when GUI is closed
    CPCoursesLoader:setGuiOpen(false)
    CPVehiclesLoader:setGuiOpen(false)

    -- Show main GUI again
    WMManagerGUI.isVisible = true
    WMManagerGUI:refresh()

    WMLogger:debug("Closed workflow editor")
end

---Save changes and close
function WMEditorGUI:saveAndClose()
    if self.currentWorkflow ~= nil then
        -- Apply edited name
        if self.editedName ~= "" then
            self.currentWorkflow.name = self.editedName
        end

        WMLogger:info("Saved workflow: %s", self.currentWorkflow.name)

        -- Persist to XML
        WorkflowManager:saveWorkflows()
    end
    self:close()
end

---Cancel changes and close
function WMEditorGUI:cancelAndClose()
    self:close()
end

---Cleanup the GUI and release resources
function WMEditorGUI:cleanup()
    WMLogger:debug("WorkflowEditorGUI:cleanup() called")
    self.overlayId = nil
    self.isVisible = false
    self.currentWorkflow = nil
    self.selectedStepIndex = 0
    self.isAddStepDialogOpen = false
    self.isEditStepDialogOpen = false
    -- Milestone 4: Vehicle selection removed

    -- Clear data cache
    self.cachedADDestinations = nil
    self.cachedCPCourses = nil
    self.cachedFillTypes = nil
    self.dataCacheLoaded = false

    -- Reset double-click tracking
    self.lastClickTime = 0
    self.lastClickStepIndex = 0

    -- Reset dropdown state
    self.openDropdown = nil
    self.dropdownScrollOffset = 0
    self.dialogDropdowns = {}
end

---Load all data caches (AD destinations, CP courses, fill types)
---This should be called once when the main GUI opens
function WMEditorGUI:loadDataCache()
    WMLogger:debug("Loading data cache for AD destinations and CP courses...")

    -- Load AutoDrive destinations
    self.cachedADDestinations = {}
    if ADIntegration and ADIntegration.isAvailable then
        local adDests = ADIntegration:getDestinations()
        if adDests then
            for _, dest in ipairs(adDests) do
                table.insert(self.cachedADDestinations, dest.displayName or dest.name or tostring(dest))
            end
        end
        WMLogger:debug("Cached %d AutoDrive destinations", #self.cachedADDestinations)
    else
        WMLogger:debug("AutoDrive not available, no destinations cached")
    end

    -- Load Courseplay courses
    self.cachedCPCourses = {}
    if CPCoursesLoader and CPCoursesLoader.isInitialized then
        local courses = CPCoursesLoader:getCourses()
        if courses and #courses > 0 then
            for _, course in ipairs(courses) do
                table.insert(self.cachedCPCourses, course)
            end
        end
        WMLogger:debug("Cached %d Courseplay courses", #self.cachedCPCourses)
    else
        WMLogger:debug("CPCoursesLoader not available, no courses cached")
    end

    -- Load fill types
    self.cachedFillTypes = {g_i18n:getText("wm_none") or "(None)"}
    if ADIntegration and ADIntegration.isAvailable then
        local adFillTypes = ADIntegration:getFillTypeNames()
        for _, name in ipairs(adFillTypes) do
            table.insert(self.cachedFillTypes, name)
        end
        WMLogger:debug("Cached %d fill types", #self.cachedFillTypes - 1)  -- -1 for "(None)"
    end

    self.dataCacheLoaded = true
    WMLogger:info("Data cache loaded: %d AD destinations, %d CP courses, %d fill types",
        #self.cachedADDestinations, #self.cachedCPCourses, #self.cachedFillTypes - 1)
end

---Clear the data cache (called when GUI closes)
function WMEditorGUI:clearDataCache()
    self.cachedADDestinations = nil
    self.cachedCPCourses = nil
    self.cachedFillTypes = nil
    self.dataCacheLoaded = false
    WMLogger:debug("Data cache cleared")
end

-- Milestone 4: Vehicle selection functions removed
-- refreshVehicleList, prevVehicle, nextVehicle, applyVehicleSelection are no longer needed
-- Vehicles are detected at runtime when starting a workflow

---Remove selected step
function WMEditorGUI:removeSelectedStep()
    if self.currentWorkflow == nil or self.selectedStepIndex <= 0 then
        return
    end

    table.remove(self.currentWorkflow.steps, self.selectedStepIndex)

    if self.selectedStepIndex > #self.currentWorkflow.steps then
        self.selectedStepIndex = #self.currentWorkflow.steps
    end

    WMLogger:debug("Removed step")
end

---Move selected step up
function WMEditorGUI:moveStepUp()
    if self.currentWorkflow == nil or self.selectedStepIndex <= 1 then
        return
    end

    local steps = self.currentWorkflow.steps
    local temp = steps[self.selectedStepIndex]
    steps[self.selectedStepIndex] = steps[self.selectedStepIndex - 1]
    steps[self.selectedStepIndex - 1] = temp

    self.selectedStepIndex = self.selectedStepIndex - 1
end

---Move selected step down
function WMEditorGUI:moveStepDown()
    if self.currentWorkflow == nil then
        return
    end

    local steps = self.currentWorkflow.steps
    if self.selectedStepIndex <= 0 or self.selectedStepIndex >= #steps then
        return
    end

    local temp = steps[self.selectedStepIndex]
    steps[self.selectedStepIndex] = steps[self.selectedStepIndex + 1]
    steps[self.selectedStepIndex + 1] = temp

    self.selectedStepIndex = self.selectedStepIndex + 1
end

---Get available targets based on step type (uses cached data)
---@return table targets List of target names (with folder prefixes for organization)
function WMEditorGUI:getAvailableTargets()
    local targets = {}

    if self.addStepType == "autodrive" then
        -- Use cached AutoDrive destinations
        if self.cachedADDestinations and #self.cachedADDestinations > 0 then
            for _, dest in ipairs(self.cachedADDestinations) do
                table.insert(targets, dest)
            end
        else
            -- Add some defaults if none cached
            table.insert(targets, "Farm/Silo")
            table.insert(targets, "Farm/Workshop")
            table.insert(targets, "Field1")
            table.insert(targets, "Field2")
        end
    else
        -- Use cached Courseplay courses
        if self.cachedCPCourses and #self.cachedCPCourses > 0 then
            for _, course in ipairs(self.cachedCPCourses) do
                table.insert(targets, course)
            end
        else
            -- No courses found - show placeholder
            table.insert(targets, "<No courses found>")
        end
    end

    return targets
end

---Get available actions based on step type
---AutoDrive actions map to AD modes:
---  drive -> MODE_DRIVETO (simple point-to-point)
---  pickup_deliver -> MODE_PICKUPANDDELIVER (load at first, unload at second)
---  deliver -> MODE_DELIVERTO (deliver already-loaded cargo)
---  load -> MODE_LOAD (load at specific location)
---  unload -> MODE_UNLOAD (unload at specific location)
---Courseplay actions (FS25 currently supports):
---  fieldwork -> General field work (harvesting, cultivating, etc.)
---  bale_collect -> Load/wrap bales
function WMEditorGUI:getAvailableActions()
    if self.addStepType == "autodrive" then
        return {"drive", "pickup_deliver", "deliver", "load", "unload"}
    else
        return {"fieldwork", "bale_collect"}
    end
end

---Get display name for an action
---@param action string Action name
---@return string displayName Localized display name
function WMEditorGUI:getActionDisplayName(action)
    local actionDisplayNames = {
        -- AutoDrive modes
        drive = g_i18n:getText("wm_action_drive") or "Drive To",
        pickup_deliver = g_i18n:getText("wm_action_pickup_deliver") or "Pickup & Deliver",
        deliver = g_i18n:getText("wm_action_deliver") or "Deliver",
        load = g_i18n:getText("wm_action_load") or "Load",
        unload = g_i18n:getText("wm_action_unload") or "Unload",
        -- Courseplay actions
        fieldwork = g_i18n:getText("wm_action_fieldwork") or "Field Work",
        bale_collect = g_i18n:getText("wm_action_bale_collect") or "Bale Collect"
    }
    return actionDisplayNames[action] or action
end

---Check if current action requires a second target
---AutoDrive modes with 2 targets: unload, pickup_deliver, load
---AutoDrive modes with 1 target: drive, deliver
---@return boolean needsSecondTarget
function WMEditorGUI:currentActionNeedsUnloadTarget()
    if self.addStepType ~= "autodrive" then
        return false
    end
    local actions = self:getAvailableActions()
    local currentAction = actions[self.addStepActionIndex]
    return currentAction == "unload" or currentAction == "pickup_deliver" or currentAction == "load"
end

---Check if current action supports fill type / fruit selection
---Only pickup_deliver and load modes support fruit selection
---@return boolean needsFillType
function WMEditorGUI:currentActionNeedsFillType()
    if self.addStepType ~= "autodrive" then
        return false
    end
    local actions = self:getAvailableActions()
    local currentAction = actions[self.addStepActionIndex]
    return currentAction == "pickup_deliver" or currentAction == "load"
end

---Get available fill types (uses cached data)
---@return table fillTypes List of fill type names with "None" as first option
function WMEditorGUI:getAvailableFillTypes()
    -- Use cached fill types if available
    if self.cachedFillTypes and #self.cachedFillTypes > 0 then
        return self.cachedFillTypes
    end

    -- Fallback if cache not loaded
    return {g_i18n:getText("wm_none") or "(None)"}
end

---Open the add step dialog
function WMEditorGUI:openAddStepDialog()
    self.isAddStepDialogOpen = true
    self.isEditStepDialogOpen = false
    self.editingStepIndex = 0
    self.addStepType = "autodrive"
    self.addStepTargetIndex = 1
    self.addStepActionIndex = 1
    self.addStepUnloadTargetIndex = 0  -- 0 = not set
    self.addStepFillTypeIndex = 1  -- 1 = "(None)"
    self.availableTargets = self:getAvailableTargets()
    self.availableFillTypes = self:getAvailableFillTypes()
end

---Open the edit step dialog for the selected step
function WMEditorGUI:openEditStepDialog()
    if self.currentWorkflow == nil or self.selectedStepIndex <= 0 then
        return
    end

    local step = self.currentWorkflow.steps[self.selectedStepIndex]
    if step == nil then
        return
    end

    self.isAddStepDialogOpen = false
    self.isEditStepDialogOpen = true
    self.editingStepIndex = self.selectedStepIndex

    -- Pre-populate with current step values
    self.addStepType = step.type or "autodrive"

    -- Find target index
    local targets = self:getAvailableTargets()
    self.addStepTargetIndex = 1
    for i, target in ipairs(targets) do
        if target == step.target then
            self.addStepTargetIndex = i
            break
        end
    end

    -- Find action index
    local actions = self:getAvailableActions()
    self.addStepActionIndex = 1
    for i, action in ipairs(actions) do
        if action == step.action then
            self.addStepActionIndex = i
            break
        end
    end

    -- Find unload target index (if set)
    self.addStepUnloadTargetIndex = 0
    if step.unloadTarget ~= nil and step.unloadTarget ~= "" then
        for i, target in ipairs(targets) do
            if target == step.unloadTarget then
                self.addStepUnloadTargetIndex = i
                break
            end
        end
    end

    -- Find fill type index (if set)
    self.availableFillTypes = self:getAvailableFillTypes()
    self.addStepFillTypeIndex = 1  -- Default to "(None)"
    if step.fillType ~= nil and step.fillType ~= "" then
        for i, ft in ipairs(self.availableFillTypes) do
            if ft == step.fillType then
                self.addStepFillTypeIndex = i
                break
            end
        end
    end

    self.availableTargets = targets
    WMLogger:debug("Opened edit dialog for step %d", self.selectedStepIndex)
end

---Close the step dialog (add or edit)
function WMEditorGUI:closeStepDialog()
    self.isAddStepDialogOpen = false
    self.isEditStepDialogOpen = false
    self.editingStepIndex = 0
    -- Close any open dropdown
    self:closeDropdown()
end

---Close the add step dialog (legacy, calls closeStepDialog)
function WMEditorGUI:closeAddStepDialog()
    self:closeStepDialog()
end

---Confirm adding a step from the dialog
function WMEditorGUI:confirmAddStep()
    if self.currentWorkflow == nil then
        self:closeStepDialog()
        return
    end

    local targets = self:getAvailableTargets()
    local actions = self:getAvailableActions()
    local fillTypes = self:getAvailableFillTypes()

    local target = targets[self.addStepTargetIndex] or "default"
    local action = actions[self.addStepActionIndex] or "default"

    local step = {
        type = self.addStepType,
        target = target,
        action = action
    }

    -- Add AutoDrive-specific parameters
    if self.addStepType == "autodrive" then
        -- Second target (for unload, pickup_deliver, load modes)
        if self:currentActionNeedsUnloadTarget() and self.addStepUnloadTargetIndex > 0 then
            step.unloadTarget = targets[self.addStepUnloadTargetIndex]
        end

        -- Fill type (only for pickup_deliver and load modes)
        if self:currentActionNeedsFillType() and self.addStepFillTypeIndex > 1 then
            -- Get the actual fill type name (not the display title)
            if ADIntegration and ADIntegration.isAvailable then
                local adFillTypes = ADIntegration:getAvailableFillTypes()
                -- Index is offset by 1 because we have "(None)" at index 1
                local ftData = adFillTypes[self.addStepFillTypeIndex - 1]
                if ftData then
                    step.fillType = ftData.name
                end
            end
        end
    end

    table.insert(self.currentWorkflow.steps, step)
    WMLogger:debug("Added step: %s -> %s (%s), unload: %s, fillType: %s",
        self.addStepType, target, action,
        step.unloadTarget or "nil", step.fillType or "nil")

    self:closeStepDialog()
end

---Confirm editing a step from the dialog
function WMEditorGUI:confirmEditStep()
    if self.currentWorkflow == nil or self.editingStepIndex <= 0 then
        self:closeStepDialog()
        return
    end

    local step = self.currentWorkflow.steps[self.editingStepIndex]
    if step == nil then
        self:closeStepDialog()
        return
    end

    local targets = self:getAvailableTargets()
    local actions = self:getAvailableActions()
    local fillTypes = self:getAvailableFillTypes()

    step.type = self.addStepType
    step.target = targets[self.addStepTargetIndex] or "default"
    step.action = actions[self.addStepActionIndex] or "default"

    -- Update AutoDrive-specific parameters
    if self.addStepType == "autodrive" then
        -- Second target (for unload, pickup_deliver, load modes)
        if self:currentActionNeedsUnloadTarget() and self.addStepUnloadTargetIndex > 0 then
            step.unloadTarget = targets[self.addStepUnloadTargetIndex]
        else
            step.unloadTarget = nil
        end

        -- Fill type (only for pickup_deliver and load modes)
        if self:currentActionNeedsFillType() and self.addStepFillTypeIndex > 1 then
            -- Get the actual fill type name (not the display title)
            if ADIntegration and ADIntegration.isAvailable then
                local adFillTypes = ADIntegration:getAvailableFillTypes()
                -- Index is offset by 1 because we have "(None)" at index 1
                local ftData = adFillTypes[self.addStepFillTypeIndex - 1]
                if ftData then
                    step.fillType = ftData.name
                end
            end
        else
            step.fillType = nil
        end
    else
        -- Clear AD-specific fields for non-AD steps
        step.unloadTarget = nil
        step.fillType = nil
    end

    WMLogger:debug("Edited step %d: %s -> %s (%s), unload: %s, fillType: %s",
        self.editingStepIndex, step.type, step.target, step.action,
        step.unloadTarget or "nil", step.fillType or "nil")

    self:closeStepDialog()
end

---Draw the editor GUI
function WMEditorGUI:draw()
    if not self.isVisible or self.currentWorkflow == nil then
        return
    end

    if self.overlayId == nil or self.overlayId == 0 then
        WMLogger:warning("Editor overlay missing during draw")
        return
    end

    local L = self.LAYOUT
    local workflow = self.currentWorkflow

    -- Reset UVs
    setOverlayUVs(self.overlayId, 0, 0, 1, 0, 0, 1, 1, 1)

    -- If step dialog is open, only draw the dialog (skip editor content)
    if self.isAddStepDialogOpen or self.isEditStepDialogOpen then
        self:drawStepDialog()
        return
    end

    -- Draw background
    setOverlayColor(self.overlayId, 0.05, 0.05, 0.08, 1)
    renderOverlay(self.overlayId, L.bgX, L.bgY, L.bgW, L.bgH)
    setOverlayColor(self.overlayId, 0, 0, 0, 0.3)
    renderOverlay(self.overlayId, L.bgX, L.bgY, L.bgW, L.bgH)

    -- Draw border
    setOverlayColor(self.overlayId, 0.3, 0.7, 0.3, 1)
    renderOverlay(self.overlayId, L.bgX, L.bgY, L.bgW, 0.003)
    renderOverlay(self.overlayId, L.bgX, L.bgY + L.bgH - 0.003, L.bgW, 0.003)
    renderOverlay(self.overlayId, L.bgX, L.bgY, 0.003, L.bgH)
    renderOverlay(self.overlayId, L.bgX + L.bgW - 0.003, L.bgY, 0.003, L.bgH)

    -- Draw title bar
    setOverlayColor(self.overlayId, 0.15, 0.15, 0.15, 1)
    renderOverlay(self.overlayId, L.bgX, L.bgY + L.bgH - 0.06, L.bgW, 0.06)

    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(L.bgX + L.margin, L.bgY + L.bgH - 0.042, 0.022, g_i18n:getText("wm_editor_title"))
    setTextBold(false)

    -- Close button (X)
    self:drawButton(L.bgX + L.bgW - 0.05, L.bgY + L.bgH - 0.05, 0.04, 0.04, "X", {0.6, 0.2, 0.2, 1})

    local currentY = L.bgY + L.bgH - 0.10

    -- === NAME SECTION ===
    currentY = currentY - 0.02
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(L.bgX + L.margin, currentY, 0.016, g_i18n:getText("wm_editor_name") .. ":")

    -- Name display box
    setOverlayColor(self.overlayId, 0.1, 0.1, 0.12, 1)
    renderOverlay(self.overlayId, L.bgX + 0.12, currentY - 0.008, 0.30, 0.03)
    setTextColor(1, 1, 1, 1)
    local displayName = self.editedName
    if string.len(displayName) > 25 then
        displayName = string.sub(displayName, 1, 23) .. ".."
    end
    renderText(L.bgX + 0.13, currentY, 0.016, displayName)

    -- Edit name button
    self:drawButton(L.bgX + 0.43, currentY - 0.008, 0.06, 0.03, g_i18n:getText("wm_button_edit"), {0.3, 0.5, 0.7, 1})

    -- Milestone 4: Vehicle section removed - vehicles detected at runtime
    -- Show hint about vehicle requirement instead
    currentY = currentY - 0.03
    setTextColor(0.6, 0.7, 0.8, 1)
    renderText(L.bgX + L.margin, currentY, 0.013, g_i18n:getText("wm_vehicle_hint") or "Vehicle: Uses current vehicle when starting workflow")

    -- === STEPS SECTION ===
    currentY = currentY - 0.06
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(L.bgX + L.margin, currentY, 0.018, g_i18n:getText("wm_editor_steps"))
    setTextBold(false)

    -- Double-click hint
    setTextColor(0.5, 0.5, 0.5, 1)
    renderText(L.bgX + L.bgW - 0.18, currentY, 0.011, "Double-click to edit")

    -- Step toolbar buttons
    local toolbarX = L.bgX + 0.12
    self:drawButton(toolbarX, currentY - 0.01, 0.07, L.smallBtnH, "+ " .. g_i18n:getText("wm_button_add"), {0.2, 0.5, 0.2, 1})
    self:drawButton(toolbarX + 0.08, currentY - 0.01, 0.07, L.smallBtnH, g_i18n:getText("wm_button_edit"), {0.3, 0.5, 0.7, 1})
    self:drawButton(toolbarX + 0.16, currentY - 0.01, 0.09, L.smallBtnH, "- " .. g_i18n:getText("wm_button_remove"), {0.5, 0.2, 0.2, 1})
    self:drawButton(toolbarX + 0.26, currentY - 0.01, 0.06, L.smallBtnH, g_i18n:getText("wm_button_up"), {0.3, 0.3, 0.5, 1})
    self:drawButton(toolbarX + 0.33, currentY - 0.01, 0.07, L.smallBtnH, g_i18n:getText("wm_button_down"), {0.3, 0.3, 0.5, 1})

    -- Column headers
    currentY = currentY - 0.05
    local headerY = currentY

    -- Only render column header text if not covered by dropdown
    if not self:isPositionCoveredByDropdown(headerY, 0.02) then
        setTextColor(0.7, 0.7, 0.7, 1)
        renderText(L.bgX + 0.02, currentY, 0.014, "#")
        renderText(L.bgX + 0.05, currentY, 0.014, g_i18n:getText("wm_editor_type"))
        renderText(L.bgX + 0.18, currentY, 0.014, g_i18n:getText("wm_editor_target"))
        renderText(L.bgX + 0.45, currentY, 0.014, g_i18n:getText("wm_editor_action"))
    end

    -- Separator
    currentY = currentY - 0.015
    setOverlayColor(self.overlayId, 0.4, 0.4, 0.4, 1)
    renderOverlay(self.overlayId, L.bgX + 0.01, currentY, L.bgW - 0.02, 0.002)

    -- Steps list
    currentY = currentY - 0.01
    local stepsStartY = currentY

    if #workflow.steps == 0 then
        -- Only render "no steps" text if not covered by dropdown
        if not self:isPositionCoveredByDropdown(currentY - 0.05, 0.02) then
            setTextColor(0.5, 0.5, 0.5, 1)
            renderText(L.bgX + 0.20, currentY - 0.05, 0.016, g_i18n:getText("wm_editor_no_steps"))
        end
    else
        for i, step in ipairs(workflow.steps) do
            currentY = currentY - L.rowHeight
            self:drawStepRow(L.bgX, currentY, i, step)

            if i >= 8 then
                break
            end
        end
    end

    -- === BOTTOM BUTTONS ===
    local bottomY = L.bgY + 0.02
    local centerX = L.bgX + L.bgW / 2

    self:drawButton(centerX - 0.22, bottomY, L.buttonW, L.buttonH, g_i18n:getText("wm_button_save"), {0.2, 0.6, 0.2, 1})
    self:drawButton(centerX - 0.06, bottomY, L.buttonW, L.buttonH, g_i18n:getText("wm_button_cancel"), {0.6, 0.3, 0.3, 1})

    -- Milestone 4: Vehicle dropdown removed - no dropdowns to draw in main editor
end

---Draw a button
---@param x number X position
---@param y number Y position
---@param w number Width
---@param h number Height
---@param text string Button text
---@param color table RGBA color
---@param skipDropdownCheck boolean Optional - skip dropdown coverage check (for dialog buttons)
function WMEditorGUI:drawButton(x, y, w, h, text, color, skipDropdownCheck)
    local isHovered = self:isMouseInArea(x, y, w, h)
    local brightness = isHovered and 1.2 or 1.0

    setOverlayColor(self.overlayId,
        math.min(color[1] * brightness, 1),
        math.min(color[2] * brightness, 1),
        math.min(color[3] * brightness, 1),
        color[4])
    renderOverlay(self.overlayId, x, y, w, h)

    -- Border when hovered
    if isHovered then
        setOverlayColor(self.overlayId, 1, 1, 1, 0.3)
        renderOverlay(self.overlayId, x, y, w, 0.002)
        renderOverlay(self.overlayId, x, y + h - 0.002, w, 0.002)
        renderOverlay(self.overlayId, x, y, 0.002, h)
        renderOverlay(self.overlayId, x + w - 0.002, y, 0.002, h)
    end

    -- Skip text rendering if covered by dropdown (unless skipDropdownCheck is true)
    if not skipDropdownCheck and self:isPositionCoveredByDropdown(y, h) then
        return
    end

    setTextColor(1, 1, 1, 1)
    local textWidth = getTextWidth(0.014, text)
    renderText(x + (w - textWidth) / 2, y + h * 0.3, 0.014, text)
end

---Draw a dropdown selector field
---@param x number X position
---@param y number Y position
---@param w number Width
---@param h number Height
---@param dropdownName string Unique name for this dropdown
---@param items table List of items to display
---@param selectedIndex number Currently selected index (0 = none)
---@param placeholder string Text to show when nothing selected
function WMEditorGUI:drawDropdownField(x, y, w, h, dropdownName, items, selectedIndex, placeholder)
    local isOpen = self.openDropdown == dropdownName
    local isHovered = self:isMouseInArea(x, y, w, h)

    -- Check if this field is covered by a different dropdown
    local isCoveredByOther = (self.openDropdown ~= nil and self.openDropdown ~= dropdownName)
        and self:isPositionCoveredByDropdown(y, h)

    -- Draw field background
    if isHovered or isOpen then
        setOverlayColor(self.overlayId, 0.15, 0.15, 0.18, 1)
    else
        setOverlayColor(self.overlayId, 0.1, 0.1, 0.12, 1)
    end
    renderOverlay(self.overlayId, x, y, w, h)

    -- Border when hovered or open
    if isHovered or isOpen then
        setOverlayColor(self.overlayId, 0.5, 0.7, 0.9, 0.5)
        renderOverlay(self.overlayId, x, y, w, 0.002)
        renderOverlay(self.overlayId, x, y + h - 0.002, w, 0.002)
        renderOverlay(self.overlayId, x, y, 0.002, h)
        renderOverlay(self.overlayId, x + w - 0.002, y, 0.002, h)
    end

    -- Skip text rendering if covered by another dropdown
    if isCoveredByOther then
        return
    end

    -- Display text
    local displayText = placeholder or "(None)"
    if selectedIndex > 0 and selectedIndex <= #items then
        displayText = items[selectedIndex]
        if type(displayText) == "table" then
            displayText = displayText.name or displayText.displayName or tostring(displayText)
        end
    end

    -- Truncate if too long (leave room for arrow)
    local maxChars = math.floor((w - 0.04) / 0.008)
    if string.len(displayText) > maxChars then
        displayText = string.sub(displayText, 1, maxChars - 2) .. ".."
    end

    setTextColor(1, 1, 1, 1)
    renderText(x + 0.01, y + h * 0.3, 0.014, displayText)

    -- Draw dropdown arrow
    local arrowX = x + w - 0.025
    local arrowY = y + h * 0.35
    setTextColor(0.7, 0.7, 0.7, 1)
    renderText(arrowX, arrowY, 0.014, isOpen and "▲" or "▼")
end

---Draw the dropdown list when open
---@param x number X position (left edge of dropdown)
---@param y number Y position (bottom of field, list drops down from here)
---@param w number Width
---@param dropdownName string Unique name for this dropdown
---@param items table List of items to display
---@param selectedIndex number Currently selected index
function WMEditorGUI:drawDropdownList(x, y, w, dropdownName, items, selectedIndex)
    if self.openDropdown ~= dropdownName or #items == 0 then
        return
    end

    local itemH = self.DROPDOWN_ITEM_HEIGHT
    local maxVisible = math.min(#items, self.DROPDOWN_MAX_VISIBLE)
    local listH = maxVisible * itemH + 0.01

    -- Calculate list position (drops down below the field)
    local listY = y - listH

    -- Ensure list doesn't go off-screen
    if listY < 0.02 then
        listY = 0.02
    end

    -- Draw list background
    setOverlayColor(self.overlayId, 0.08, 0.08, 0.1, 0.98)
    renderOverlay(self.overlayId, x, listY, w, listH)

    -- Draw border
    setOverlayColor(self.overlayId, 0.5, 0.7, 0.9, 0.8)
    renderOverlay(self.overlayId, x, listY, w, 0.002)
    renderOverlay(self.overlayId, x, listY + listH - 0.002, w, 0.002)
    renderOverlay(self.overlayId, x, listY, 0.002, listH)
    renderOverlay(self.overlayId, x + w - 0.002, listY, 0.002, listH)

    -- Draw items
    local startIndex = self.dropdownScrollOffset + 1
    local endIndex = math.min(startIndex + maxVisible - 1, #items)

    for i = startIndex, endIndex do
        local itemY = listY + listH - 0.005 - (i - startIndex + 1) * itemH
        local itemText = items[i]
        if type(itemText) == "table" then
            itemText = itemText.name or itemText.displayName or tostring(itemText)
        end

        -- Highlight hovered or selected item
        local isItemHovered = self:isMouseInArea(x + 0.002, itemY, w - 0.004, itemH)
        local isSelected = (i == selectedIndex)

        if isItemHovered then
            setOverlayColor(self.overlayId, 0.3, 0.5, 0.7, 0.8)
            renderOverlay(self.overlayId, x + 0.002, itemY, w - 0.004, itemH)
        elseif isSelected then
            setOverlayColor(self.overlayId, 0.2, 0.4, 0.2, 0.7)
            renderOverlay(self.overlayId, x + 0.002, itemY, w - 0.004, itemH)
        else
            -- Alternating row background for non-hovered/non-selected items
            local rowIndex = i - startIndex
            if rowIndex % 2 == 0 then
                setOverlayColor(self.overlayId, 0.14, 0.14, 0.17, 0.95)
            else
                setOverlayColor(self.overlayId, 0.10, 0.10, 0.12, 0.95)
            end
            renderOverlay(self.overlayId, x + 0.002, itemY, w - 0.004, itemH)
        end

        -- Row separator line at bottom of each item
        setOverlayColor(self.overlayId, 0.4, 0.4, 0.45, 0.3)
        renderOverlay(self.overlayId, x + 0.01, itemY, w - 0.02, 0.001)

        -- Truncate text if needed
        local maxChars = math.floor((w - 0.02) / 0.008)
        if string.len(itemText) > maxChars then
            itemText = string.sub(itemText, 1, maxChars - 2) .. ".."
        end

        setTextColor(1, 1, 1, 1)
        renderText(x + 0.01, itemY + itemH * 0.3, 0.013, itemText)
    end

    -- Draw scroll indicators if needed
    if #items > maxVisible then
        setTextColor(0.6, 0.6, 0.6, 1)
        if self.dropdownScrollOffset > 0 then
            renderText(x + w - 0.02, listY + listH - 0.015, 0.012, "▲")
        end
        if endIndex < #items then
            renderText(x + w - 0.02, listY + 0.005, 0.012, "▼")
        end
    end
end

---Handle click on a dropdown field - returns true if handled
---@param x number Click X
---@param y number Click Y
---@param fieldX number Field X position
---@param fieldY number Field Y position
---@param fieldW number Field width
---@param fieldH number Field height
---@param dropdownName string Dropdown name
---@param items table Items list
---@param onSelect function Callback when item selected (receives index)
---@return boolean handled
function WMEditorGUI:handleDropdownClick(x, y, fieldX, fieldY, fieldW, fieldH, dropdownName, items, onSelect)
    local isOpen = self.openDropdown == dropdownName

    -- If dropdown is open, check for list clicks first
    if isOpen and #items > 0 then
        local itemH = self.DROPDOWN_ITEM_HEIGHT
        local maxVisible = math.min(#items, self.DROPDOWN_MAX_VISIBLE)
        local listH = maxVisible * itemH + 0.01
        local listY = fieldY - listH

        -- Ensure list doesn't go off-screen
        if listY < 0.02 then
            listY = 0.02
        end

        -- Check if click is in the list area
        if self:isMouseInArea(fieldX, listY, fieldW, listH) then
            -- Find which item was clicked
            local startIndex = self.dropdownScrollOffset + 1
            local endIndex = math.min(startIndex + maxVisible - 1, #items)

            for i = startIndex, endIndex do
                local itemY = listY + listH - 0.005 - (i - startIndex + 1) * itemH
                if self:isMouseInArea(fieldX + 0.002, itemY, fieldW - 0.004, itemH) then
                    -- Item clicked - select it
                    if onSelect then
                        onSelect(i)
                    end
                    self.openDropdown = nil
                    self.dropdownScrollOffset = 0
                    return true
                end
            end

            -- Click was in list but not on an item (scroll area?) - just close
            self.openDropdown = nil
            self.dropdownScrollOffset = 0
            return true
        end
    end

    -- Check if click is on the field itself
    if self:isMouseInArea(fieldX, fieldY, fieldW, fieldH) then
        if isOpen then
            -- Close this dropdown
            self.openDropdown = nil
            self.dropdownScrollOffset = 0
        else
            -- Open this dropdown (close any other)
            self.openDropdown = dropdownName
            self.dropdownScrollOffset = 0
        end
        return true
    end

    return false
end

---Handle scroll wheel for dropdowns
---@param direction number Scroll direction (-1 or 1)
function WMEditorGUI:handleDropdownScroll(direction)
    if self.openDropdown == nil then
        return false
    end

    -- Get the items for the current dropdown
    local items = self:getDropdownItems(self.openDropdown)
    if items == nil or #items <= self.DROPDOWN_MAX_VISIBLE then
        return false
    end

    local maxScroll = #items - self.DROPDOWN_MAX_VISIBLE
    self.dropdownScrollOffset = math.max(0, math.min(maxScroll, self.dropdownScrollOffset + direction))
    return true
end

---Get items for a dropdown by name
---@param dropdownName string
---@return table items
function WMEditorGUI:getDropdownItems(dropdownName)
    -- Milestone 4: Vehicle dropdown removed
    if dropdownName == "action" then
        return self:getAvailableActions()
    elseif dropdownName == "target" then
        return self:getAvailableTargets()
    elseif dropdownName == "unloadTarget" then
        return self:getAvailableTargets()
    elseif dropdownName == "fillType" then
        return self:getAvailableFillTypes()
    end
    return {}
end

---Close any open dropdown
function WMEditorGUI:closeDropdown()
    self.openDropdown = nil
    self.dropdownScrollOffset = 0
end

---Check if a Y position is covered by an open dropdown
---@param testY number Y position to check
---@param testH number Height of element to check (optional, defaults to 0)
---@return boolean isCovered True if the position is covered by dropdown
function WMEditorGUI:isPositionCoveredByDropdown(testY, testH)
    if self.openDropdown == nil then
        return false
    end

    testH = testH or 0

    -- Get dropdown position based on which one is open
    -- Milestone 4: Vehicle dropdown removed
    local ddPos = nil
    if self.dialogDropdowns and self.dialogDropdowns[self.openDropdown] then
        ddPos = self.dialogDropdowns[self.openDropdown]
    end

    if ddPos == nil then
        return false
    end

    -- Calculate dropdown list bounds
    local items = self:getDropdownItems(self.openDropdown)
    if items == nil or #items == 0 then
        return false
    end

    local itemH = self.DROPDOWN_ITEM_HEIGHT
    local maxVisible = math.min(#items, self.DROPDOWN_MAX_VISIBLE)
    local listH = maxVisible * itemH + 0.01
    local listY = ddPos.y - listH

    -- Ensure list doesn't go off-screen
    if listY < 0.02 then
        listY = 0.02
    end

    local listTop = listY + listH
    local listBottom = listY

    -- Check if the test position overlaps with the dropdown list
    local testTop = testY + testH
    local testBottom = testY

    -- Overlap check
    return testBottom < listTop and testTop > listBottom
end

---Draw a single step row
---@param baseX number Base X position
---@param y number Y position
---@param index number Step index
---@param step table Step data
function WMEditorGUI:drawStepRow(baseX, y, index, step)
    local L = self.LAYOUT
    local isSelected = (index == self.selectedStepIndex)
    local rowHeight = L.rowHeight - 0.005

    -- Check if this row is covered by a dropdown
    local isCovered = self:isPositionCoveredByDropdown(y, rowHeight)

    -- Row background (always draw, just the overlay)
    if isSelected then
        setOverlayColor(self.overlayId, 0.2, 0.5, 0.2, 0.7)
    elseif index % 2 == 0 then
        -- Even rows: lighter background
        setOverlayColor(self.overlayId, 0.12, 0.12, 0.15, 0.9)
    else
        -- Odd rows: darker background
        setOverlayColor(self.overlayId, 0.08, 0.08, 0.10, 0.9)
    end
    renderOverlay(self.overlayId, baseX + 0.01, y, L.bgW - 0.02, rowHeight)

    -- Row separator line at bottom
    setOverlayColor(self.overlayId, 0.3, 0.3, 0.35, 0.4)
    renderOverlay(self.overlayId, baseX + 0.02, y, L.bgW - 0.04, 0.001)

    -- Skip text rendering if covered by dropdown
    if isCovered then
        return
    end

    -- Row color by type
    local textColor = {1, 1, 1, 1}
    if step.type == WorkflowManager.STEP_AUTODRIVE then
        textColor = {0.4, 0.7, 1, 1}
    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        textColor = {0.4, 1, 0.4, 1}
    elseif WorkflowManager:isMarkerStepType(step.type) then
        textColor = {1, 0.8, 0.3, 1}  -- amber for sync markers
    end

    setTextColor(textColor[1], textColor[2], textColor[3], textColor[4])

    local textY = y + rowHeight * 0.3

    -- Step number
    renderText(baseX + 0.02, textY, 0.014, tostring(index))

    -- Type
    local typeText = WorkflowManager:getStepTypeLabel(step.type)
    renderText(baseX + 0.05, textY, 0.014, typeText)

    -- Target
    local target = step.target or ""
    if string.len(target) > 40 then
        target = string.sub(target, 1, 38) .. ".."
    end
    renderText(baseX + 0.18, textY, 0.014, target)

    -- Action (marker steps have none)
    if not WorkflowManager:isMarkerStepType(step.type) then
        renderText(baseX + 0.45, textY, 0.014, step.action or "default")
    end
end

---Draw the step dialog (add or edit mode)
function WMEditorGUI:drawStepDialog()
    local dlgX, dlgY = 0.25, 0.15
    local dlgW, dlgH = 0.50, 0.70
    local fieldW = 0.35
    local fieldH = 0.035

    -- Reset dialog dropdown positions
    self.dialogDropdowns = {}

    -- Full-screen dimming overlay to block content behind
    setOverlayColor(self.overlayId, 0, 0, 0, 0.85)
    renderOverlay(self.overlayId, 0, 0, 1, 1)

    -- Dialog background (fully opaque)
    setOverlayColor(self.overlayId, 0.08, 0.08, 0.1, 1)
    renderOverlay(self.overlayId, dlgX, dlgY, dlgW, dlgH)

    -- Border
    setOverlayColor(self.overlayId, 0.5, 0.8, 0.5, 1)
    renderOverlay(self.overlayId, dlgX, dlgY, dlgW, 0.003)
    renderOverlay(self.overlayId, dlgX, dlgY + dlgH - 0.003, dlgW, 0.003)
    renderOverlay(self.overlayId, dlgX, dlgY, 0.003, dlgH)
    renderOverlay(self.overlayId, dlgX + dlgW - 0.003, dlgY, 0.003, dlgH)

    -- Title (different for add vs edit)
    local titleText = self.isEditStepDialogOpen and g_i18n:getText("wm_dialog_edit_step") or g_i18n:getText("wm_dialog_add_step")
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(dlgX + 0.02, dlgY + dlgH - 0.045, 0.020, titleText)
    setTextBold(false)

    local fieldY = dlgY + dlgH - 0.10
    local fieldX = dlgX + 0.12

    -- === STEP TYPE ===
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(dlgX + 0.02, fieldY, 0.016, g_i18n:getText("wm_editor_type") .. ":")

    -- Type buttons (keep as toggle buttons, not dropdown)
    local adColor = self.addStepType == "autodrive" and {0.3, 0.5, 0.7, 1} or {0.2, 0.2, 0.25, 1}
    local cpColor = self.addStepType == "courseplay" and {0.3, 0.6, 0.3, 1} or {0.2, 0.2, 0.25, 1}

    self:drawButton(fieldX, fieldY - 0.008, 0.12, fieldH, g_i18n:getText("wm_type_autodrive"), adColor)
    self:drawButton(fieldX + 0.13, fieldY - 0.008, 0.12, fieldH, g_i18n:getText("wm_type_courseplay"), cpColor)

    -- === ACTION / MODE ===
    fieldY = fieldY - 0.06
    local actions = self:getAvailableActions()
    local actionDisplayNames = {}
    for _, action in ipairs(actions) do
        table.insert(actionDisplayNames, self:getActionDisplayName(action))
    end

    -- Draw dropdown field first (populates dialogDropdowns for coverage check)
    self:drawDropdownField(fieldX, fieldY - 0.008, fieldW, fieldH,
        "action", actionDisplayNames, self.addStepActionIndex, g_i18n:getText("wm_none"))
    self.dialogDropdowns.action = {x = fieldX, y = fieldY - 0.008, w = fieldW, h = fieldH, items = actionDisplayNames}

    -- Draw label (skip if covered by dropdown above)
    if not self:isPositionCoveredByDropdown(fieldY, 0.02) then
        setTextColor(0.8, 0.8, 0.8, 1)
        local actionLabel = self.addStepType == "autodrive" and (g_i18n:getText("wm_editor_mode") or "Mode") or (g_i18n:getText("wm_editor_action") or "Action")
        renderText(dlgX + 0.02, fieldY, 0.016, actionLabel .. ":")
    end

    -- === TARGET (Primary destination) ===
    fieldY = fieldY - 0.06
    local targets = self:getAvailableTargets()
    local searchBtnW = 0.04

    -- Draw dropdown field first (narrower to make room for search button)
    self:drawDropdownField(fieldX, fieldY - 0.008, fieldW - searchBtnW - 0.01, fieldH,
        "target", targets, self.addStepTargetIndex, g_i18n:getText("wm_none"))
    self.dialogDropdowns.target = {x = fieldX, y = fieldY - 0.008, w = fieldW - searchBtnW - 0.01, h = fieldH, items = targets}

    -- Search button for target
    self:drawButton(fieldX + fieldW - searchBtnW, fieldY - 0.008, searchBtnW, fieldH, "?", {0.4, 0.5, 0.6, 1}, true)

    -- Draw label (skip if covered)
    if not self:isPositionCoveredByDropdown(fieldY, 0.02) then
        setTextColor(0.8, 0.8, 0.8, 1)
        local targetLabel = g_i18n:getText("wm_editor_target") or "Target"
        if self.addStepType == "autodrive" then
            local currentAction = actions[self.addStepActionIndex]
            if currentAction == "unload" then
                targetLabel = g_i18n:getText("wm_editor_unload_first") or "Unload"
            elseif currentAction == "pickup_deliver" then
                targetLabel = g_i18n:getText("wm_editor_pickup_target") or "Pickup"
            elseif currentAction == "load" then
                targetLabel = g_i18n:getText("wm_editor_return_target") or "Return To"
            end
        end
        renderText(dlgX + 0.02, fieldY, 0.016, targetLabel .. ":")
    end

    -- === SECOND TARGET (for modes requiring 2 targets: unload, pickup_deliver, load) ===
    if self.addStepType == "autodrive" and self:currentActionNeedsUnloadTarget() then
        fieldY = fieldY - 0.06

        -- Draw dropdown field first (narrower to make room for search button)
        self:drawDropdownField(fieldX, fieldY - 0.008, fieldW - searchBtnW - 0.01, fieldH,
            "unloadTarget", targets, self.addStepUnloadTargetIndex, g_i18n:getText("wm_none"))
        self.dialogDropdowns.unloadTarget = {x = fieldX, y = fieldY - 0.008, w = fieldW - searchBtnW - 0.01, h = fieldH, items = targets}

        -- Search button for unloadTarget
        self:drawButton(fieldX + fieldW - searchBtnW, fieldY - 0.008, searchBtnW, fieldH, "?", {0.4, 0.5, 0.6, 1}, true)

        -- Draw label (skip if covered)
        if not self:isPositionCoveredByDropdown(fieldY, 0.02) then
            setTextColor(0.8, 0.8, 0.8, 1)
            local currentAction = actions[self.addStepActionIndex]
            local secondTargetLabel = g_i18n:getText("wm_editor_unload_target") or "Deliver To"
            if currentAction == "unload" then
                secondTargetLabel = g_i18n:getText("wm_editor_target") or "Target"
            elseif currentAction == "load" then
                secondTargetLabel = g_i18n:getText("wm_editor_load_target") or "Load At"
            end
            renderText(dlgX + 0.02, fieldY, 0.016, secondTargetLabel .. ":")
        end
    end

    -- === FILL TYPE (only for pickup_deliver and load modes) ===
    if self.addStepType == "autodrive" and self:currentActionNeedsFillType() then
        fieldY = fieldY - 0.06
        local fillTypes = self:getAvailableFillTypes()

        -- Draw dropdown field first (narrower to make room for search button)
        self:drawDropdownField(fieldX, fieldY - 0.008, fieldW - searchBtnW - 0.01, fieldH,
            "fillType", fillTypes, self.addStepFillTypeIndex, g_i18n:getText("wm_none"))
        self.dialogDropdowns.fillType = {x = fieldX, y = fieldY - 0.008, w = fieldW - searchBtnW - 0.01, h = fieldH, items = fillTypes}

        -- Search button for fillType
        self:drawButton(fieldX + fieldW - searchBtnW, fieldY - 0.008, searchBtnW, fieldH, "?", {0.4, 0.5, 0.6, 1}, true)

        -- Draw label (skip if covered)
        if not self:isPositionCoveredByDropdown(fieldY, 0.02) then
            setTextColor(0.8, 0.8, 0.8, 1)
            renderText(dlgX + 0.02, fieldY, 0.016, (g_i18n:getText("wm_editor_fill_type") or "Fill Type") .. ":")
        end
    end

    -- === DIALOG BUTTONS ===
    local btnY = dlgY + 0.03
    local confirmText = self.isEditStepDialogOpen and g_i18n:getText("wm_button_save") or g_i18n:getText("wm_button_add")
    self:drawButton(dlgX + 0.10, btnY, 0.12, 0.045, confirmText, {0.2, 0.6, 0.2, 1})
    self:drawButton(dlgX + 0.28, btnY, 0.12, 0.045, g_i18n:getText("wm_button_cancel"), {0.6, 0.3, 0.3, 1})

    -- === DRAW DROPDOWN LISTS (on top of everything) ===
    if self.dialogDropdowns.action then
        local dd = self.dialogDropdowns.action
        self:drawDropdownList(dd.x, dd.y, dd.w, "action", dd.items, self.addStepActionIndex)
    end
    if self.dialogDropdowns.target then
        local dd = self.dialogDropdowns.target
        self:drawDropdownList(dd.x, dd.y, dd.w, "target", dd.items, self.addStepTargetIndex)
    end
    if self.dialogDropdowns.unloadTarget then
        local dd = self.dialogDropdowns.unloadTarget
        self:drawDropdownList(dd.x, dd.y, dd.w, "unloadTarget", dd.items, self.addStepUnloadTargetIndex)
    end
    if self.dialogDropdowns.fillType then
        local dd = self.dialogDropdowns.fillType
        self:drawDropdownList(dd.x, dd.y, dd.w, "fillType", dd.items, self.addStepFillTypeIndex)
    end
end

---Update function
---@param dt number Delta time
function WMEditorGUI:update(dt)
    if not self.isVisible then
        return
    end
    -- No keyboard handling needed - all button based
end

---Handle mouse click on GUI elements
---@param posX number Mouse X position (0-1)
---@param posY number Mouse Y position (0-1)
---@param isDown boolean Is mouse button down
---@param isUp boolean Is mouse button up
---@param button number Mouse button (1=left)
function WMEditorGUI:onMouseEvent(posX, posY, isDown, isUp, button)
    if not self.isVisible then
        return
    end

    self.mouseX = posX
    self.mouseY = posY

    if button ~= 1 then
        return
    end

    if isUp and self.wasMouseDown then
        self:handleMouseClick(posX, posY)
    end

    self.wasMouseDown = isDown
end

---Handle scroll wheel event for dropdown scrolling
---@param direction number Scroll direction (-1 = down, 1 = up)
---@return boolean handled True if scroll was handled
function WMEditorGUI:onScrollEvent(direction)
    if not self.isVisible then
        return false
    end

    -- Only handle scroll when a dropdown is open
    if self.openDropdown == nil then
        return false
    end

    -- Get items for current dropdown
    local items = self:getDropdownItems(self.openDropdown)
    if items == nil or #items <= self.DROPDOWN_MAX_VISIBLE then
        return false
    end

    local maxScroll = #items - self.DROPDOWN_MAX_VISIBLE
    self.dropdownScrollOffset = math.max(0, math.min(maxScroll, self.dropdownScrollOffset - direction))
    return true
end

---Check if mouse is inside an area
---@param x number Area X
---@param y number Area Y
---@param w number Area width
---@param h number Area height
---@return boolean isInside
function WMEditorGUI:isMouseInArea(x, y, w, h)
    return self.mouseX >= x and self.mouseX <= x + w and
           self.mouseY >= y and self.mouseY <= y + h
end

---Open the text input dialog to edit the workflow name
function WMEditorGUI:openNameEditDialog()
    WorkflowManager:showTextInputDialog(
        g_i18n:getText("wm_editor_name"),
        self.editedName,
        function(text, confirmed)
            if confirmed and text ~= nil and text ~= "" then
                self.editedName = text
                if self.currentWorkflow then
                    self.currentWorkflow.name = text
                end
                WMLogger:debug("Name changed to: %s", text)
            end
        end
    )
end

---Open a search dialog for a dropdown
---@param dropdownName string Name of dropdown to search ("target", "unloadTarget", "fillType")
function WMEditorGUI:openDropdownSearchDialog(dropdownName)
    local items = self:getDropdownItems(dropdownName)
    if items == nil or #items == 0 then
        return
    end

    -- Store which dropdown we're searching
    self.searchingDropdown = dropdownName

    WorkflowManager:showTextInputDialog(
        g_i18n:getText("wm_search") or "Search",
        "",
        function(text, confirmed)
            if confirmed and text ~= nil and text ~= "" then
                -- Find first matching item (case-insensitive)
                local searchLower = string.lower(text)
                for i, item in ipairs(items) do
                    local itemText = item
                    if type(item) == "table" then
                        itemText = item.name or item.displayName or tostring(item)
                    end
                    if string.find(string.lower(itemText), searchLower, 1, true) then
                        -- Found a match - select it
                        self:selectDropdownItem(dropdownName, i)
                        WMLogger:debug("Search '%s' matched: %s (index %d)", text, itemText, i)
                        break
                    end
                end
            end
            self.searchingDropdown = nil
        end
    )
end

---Select an item in a dropdown by index
---@param dropdownName string Dropdown name
---@param index number Item index to select
function WMEditorGUI:selectDropdownItem(dropdownName, index)
    if dropdownName == "target" then
        self.addStepTargetIndex = index
    elseif dropdownName == "unloadTarget" then
        self.addStepUnloadTargetIndex = index
    elseif dropdownName == "fillType" then
        self.addStepFillTypeIndex = index
    elseif dropdownName == "action" then
        self.addStepActionIndex = index
    end
end

---Handle mouse click at position
---@param x number Mouse X
---@param y number Mouse Y
function WMEditorGUI:handleMouseClick(x, y)
    local L = self.LAYOUT

    -- If step dialog is open (add or edit), handle that first
    if self.isAddStepDialogOpen or self.isEditStepDialogOpen then
        self:handleStepDialogClick(x, y)
        return
    end

    -- Milestone 4: Vehicle dropdown handling removed

    -- If a dropdown is open and we clicked elsewhere, close it
    if self.openDropdown ~= nil then
        self:closeDropdown()
        return
    end

    -- Close button (X)
    if self:isMouseInArea(L.bgX + L.bgW - 0.05, L.bgY + L.bgH - 0.05, 0.04, 0.04) then
        self:cancelAndClose()
        return
    end

    local currentY = L.bgY + L.bgH - 0.10 - 0.02

    -- Name field click (opens edit dialog)
    if self:isMouseInArea(L.bgX + 0.12, currentY - 0.008, 0.30, 0.03) then
        self:openNameEditDialog()
        return
    end

    -- Edit name button
    if self:isMouseInArea(L.bgX + 0.43, currentY - 0.008, 0.06, 0.03) then
        self:openNameEditDialog()
        return
    end

    -- Step toolbar buttons
    local toolbarY = currentY - 0.05 - 0.06 - 0.01
    local toolbarX = L.bgX + 0.12

    -- Add step button
    if self:isMouseInArea(toolbarX, toolbarY, 0.07, L.smallBtnH) then
        self:openAddStepDialog()
        return
    end

    -- Edit step button
    if self:isMouseInArea(toolbarX + 0.08, toolbarY, 0.07, L.smallBtnH) then
        self:openEditStepDialog()
        return
    end

    -- Remove step button
    if self:isMouseInArea(toolbarX + 0.16, toolbarY, 0.09, L.smallBtnH) then
        self:removeSelectedStep()
        return
    end

    -- Move up button
    if self:isMouseInArea(toolbarX + 0.26, toolbarY, 0.06, L.smallBtnH) then
        self:moveStepUp()
        return
    end

    -- Move down button
    if self:isMouseInArea(toolbarX + 0.33, toolbarY, 0.07, L.smallBtnH) then
        self:moveStepDown()
        return
    end

    -- Bottom buttons
    local bottomY = L.bgY + 0.02
    local centerX = L.bgX + L.bgW / 2

    -- Save button
    if self:isMouseInArea(centerX - 0.22, bottomY, L.buttonW, L.buttonH) then
        self:saveAndClose()
        return
    end

    -- Cancel button
    if self:isMouseInArea(centerX - 0.06, bottomY, L.buttonW, L.buttonH) then
        self:cancelAndClose()
        return
    end

    -- Step list clicks
    self:handleStepListClick(x, y)
end

---Handle click on step list
---@param x number Mouse X
---@param y number Mouse Y
function WMEditorGUI:handleStepListClick(x, y)
    if self.currentWorkflow == nil then
        return
    end

    local L = self.LAYOUT
    local stepsStartY = L.bgY + L.bgH - 0.10 - 0.02 - 0.05 - 0.06 - 0.05 - 0.015 - 0.01

    for i = 1, math.min(#self.currentWorkflow.steps, 8) do
        local rowY = stepsStartY - (i * L.rowHeight)
        if self:isMouseInArea(L.bgX + 0.01, rowY, L.bgW - 0.02, L.rowHeight - 0.005) then
            -- Get current time in milliseconds
            local currentTime = g_currentMission ~= nil and g_currentMission.time or 0

            -- Check for double-click on the same row
            if self.lastClickStepIndex == i and (currentTime - self.lastClickTime) < self.DOUBLE_CLICK_THRESHOLD then
                -- Double-click detected - open edit dialog
                WMLogger:debug("Double-click on step %d - opening edit dialog", i)
                self.selectedStepIndex = i
                self:openEditStepDialog()
                -- Reset double-click tracking
                self.lastClickTime = 0
                self.lastClickStepIndex = 0
            else
                -- Single click - just select
                self.selectedStepIndex = i
                self.lastClickTime = currentTime
                self.lastClickStepIndex = i
            end
            return
        end
    end

    -- Click outside step list - reset double-click tracking
    self.lastClickTime = 0
    self.lastClickStepIndex = 0
end

---Handle click on step dialog (add or edit)
---@param x number Mouse X
---@param y number Mouse Y
function WMEditorGUI:handleStepDialogClick(x, y)
    local dlgX, dlgY = 0.25, 0.15
    local dlgW, dlgH = 0.50, 0.70
    local fieldY = dlgY + dlgH - 0.10
    local fieldX = dlgX + 0.12
    local fieldW = 0.35
    local fieldH = 0.035

    -- Handle dropdown clicks first (they appear on top)
    if self.dialogDropdowns then
        -- Action dropdown
        if self.dialogDropdowns.action then
            local dd = self.dialogDropdowns.action
            local actions = self:getAvailableActions()
            local actionDisplayNames = {}
            for _, action in ipairs(actions) do
                table.insert(actionDisplayNames, self:getActionDisplayName(action))
            end
            if self:handleDropdownClick(x, y, dd.x, dd.y, dd.w, dd.h, "action", actionDisplayNames,
                function(index)
                    self.addStepActionIndex = index
                end) then
                return
            end
        end

        -- Target dropdown
        if self.dialogDropdowns.target then
            local dd = self.dialogDropdowns.target
            local targets = self:getAvailableTargets()
            if self:handleDropdownClick(x, y, dd.x, dd.y, dd.w, dd.h, "target", targets,
                function(index)
                    self.addStepTargetIndex = index
                end) then
                return
            end
        end

        -- Unload Target dropdown
        if self.dialogDropdowns.unloadTarget then
            local dd = self.dialogDropdowns.unloadTarget
            local targets = self:getAvailableTargets()
            if self:handleDropdownClick(x, y, dd.x, dd.y, dd.w, dd.h, "unloadTarget", targets,
                function(index)
                    self.addStepUnloadTargetIndex = index
                end) then
                return
            end
        end

        -- Fill Type dropdown
        if self.dialogDropdowns.fillType then
            local dd = self.dialogDropdowns.fillType
            local fillTypes = self:getAvailableFillTypes()
            if self:handleDropdownClick(x, y, dd.x, dd.y, dd.w, dd.h, "fillType", fillTypes,
                function(index)
                    self.addStepFillTypeIndex = index
                end) then
                return
            end
        end
    end

    -- If a dropdown is open and we clicked elsewhere, close it
    if self.openDropdown ~= nil then
        self:closeDropdown()
        return
    end

    -- Search button click handlers
    local searchBtnW = 0.04
    local searchBtnX = fieldX + fieldW - searchBtnW

    -- Calculate field positions (same as in drawStepDialog)
    local targetFieldY = fieldY - 0.06  -- Action is at fieldY - 0.06, Target is one more down
    targetFieldY = targetFieldY - 0.06  -- Target Y position

    -- Target search button
    if self:isMouseInArea(searchBtnX, targetFieldY - 0.008, searchBtnW, fieldH) then
        self:openDropdownSearchDialog("target")
        return
    end

    -- Unload Target search button (if visible)
    if self.addStepType == "autodrive" and self:currentActionNeedsUnloadTarget() then
        local unloadFieldY = targetFieldY - 0.06
        if self:isMouseInArea(searchBtnX, unloadFieldY - 0.008, searchBtnW, fieldH) then
            self:openDropdownSearchDialog("unloadTarget")
            return
        end

        -- Fill Type search button (if visible, after unloadTarget)
        if self:currentActionNeedsFillType() then
            local fillTypeFieldY = unloadFieldY - 0.06
            if self:isMouseInArea(searchBtnX, fillTypeFieldY - 0.008, searchBtnW, fieldH) then
                self:openDropdownSearchDialog("fillType")
                return
            end
        end
    elseif self.addStepType == "autodrive" and self:currentActionNeedsFillType() then
        -- Fill Type search button (directly after target, no unloadTarget)
        local fillTypeFieldY = targetFieldY - 0.06
        if self:isMouseInArea(searchBtnX, fillTypeFieldY - 0.008, searchBtnW, fieldH) then
            self:openDropdownSearchDialog("fillType")
            return
        end
    end

    -- Type buttons (not dropdowns)
    if self:isMouseInArea(fieldX, fieldY - 0.008, 0.12, fieldH) then
        self.addStepType = "autodrive"
        self.addStepTargetIndex = 1
        self.addStepActionIndex = 1
        self.addStepUnloadTargetIndex = 0
        self.addStepFillTypeIndex = 1
        return
    end
    if self:isMouseInArea(fieldX + 0.13, fieldY - 0.008, 0.12, fieldH) then
        self.addStepType = "courseplay"
        self.addStepTargetIndex = 1
        self.addStepActionIndex = 1
        self.addStepUnloadTargetIndex = 0
        self.addStepFillTypeIndex = 1
        return
    end

    -- Dialog buttons
    local btnY = dlgY + 0.03

    if self:isMouseInArea(dlgX + 0.10, btnY, 0.12, 0.045) then
        -- Confirm button - add or edit based on mode
        if self.isEditStepDialogOpen then
            self:confirmEditStep()
        else
            self:confirmAddStep()
        end
        return
    end
    if self:isMouseInArea(dlgX + 0.28, btnY, 0.12, 0.045) then
        self:closeStepDialog()
        return
    end
end
