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

-- Available vehicles cache
WMEditorGUI.availableVehicles = {}
WMEditorGUI.selectedVehicleIndex = 0

-- Editing state
WMEditorGUI.editedName = ""

-- Mouse tracking
WMEditorGUI.mouseX = 0
WMEditorGUI.mouseY = 0
WMEditorGUI.wasMouseDown = false

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
    self.availableVehicles = {}

    -- Create own overlay from white.png texture
    self.overlayId = nil

    if WorkflowManager.modDirectory ~= nil then
        local whiteTexture = WorkflowManager.modDirectory .. "textures/white.png"
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
            local whiteTexture = WorkflowManager.modDirectory .. "textures/white.png"
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

    -- Refresh available vehicles
    self:refreshVehicleList()

    -- Find current vehicle index
    self.selectedVehicleIndex = 0
    if workflow.vehicle ~= nil then
        for i, vData in ipairs(self.availableVehicles) do
            if vData.vehicle == workflow.vehicle then
                self.selectedVehicleIndex = i
                break
            end
        end
    end

    WMLogger:debug("Opened editor for workflow: %s", workflow.name)
end

---Close the editor
function WMEditorGUI:close()
    self.isVisible = false
    self.currentWorkflow = nil
    self.selectedStepIndex = 0
    self.isAddStepDialogOpen = false

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
    self.availableVehicles = {}
end

---Refresh the list of available vehicles
function WMEditorGUI:refreshVehicleList()
    -- Use the centralized vehicle loader instead of scanning ourselves
    if CPVehiclesLoader and CPVehiclesLoader.isInitialized then
        self.availableVehicles = CPVehiclesLoader:getVehicles()
        WMLogger:debug("Loaded %d vehicles from CPVehiclesLoader", #self.availableVehicles)
    else
        -- Fallback: scan vehicles directly if loader not available
        self.availableVehicles = {}

        if g_currentMission == nil or g_currentMission.vehicles == nil then
            return
        end

        for _, vehicle in ipairs(g_currentMission.vehicles) do
            local hasAD = vehicle.ad ~= nil
            local hasCP = vehicle.spec_cpAIWorker ~= nil or vehicle.spec_cpAIFieldWorker ~= nil

            if hasAD or hasCP then
                local name = "Unknown Vehicle"
                if vehicle.getName then
                    name = vehicle:getName()
                elseif vehicle.name then
                    name = vehicle.name
                end

                table.insert(self.availableVehicles, {
                    vehicle = vehicle,
                    name = name,
                    hasAD = hasAD,
                    hasCP = hasCP
                })
            end
        end

        WMLogger:debug("Found %d vehicles with AD/CP support (fallback)", #self.availableVehicles)
    end
end

---Cycle to previous vehicle
function WMEditorGUI:prevVehicle()
    if #self.availableVehicles == 0 then return end

    self.selectedVehicleIndex = self.selectedVehicleIndex - 1
    if self.selectedVehicleIndex < 0 then
        self.selectedVehicleIndex = #self.availableVehicles
    end
    self:applyVehicleSelection()
end

---Cycle to next vehicle
function WMEditorGUI:nextVehicle()
    if #self.availableVehicles == 0 then return end

    self.selectedVehicleIndex = self.selectedVehicleIndex + 1
    if self.selectedVehicleIndex > #self.availableVehicles then
        self.selectedVehicleIndex = 0
    end
    self:applyVehicleSelection()
end

---Apply the current vehicle selection to the workflow
function WMEditorGUI:applyVehicleSelection()
    if self.currentWorkflow == nil then return end

    if self.selectedVehicleIndex > 0 and self.selectedVehicleIndex <= #self.availableVehicles then
        self.currentWorkflow.vehicle = self.availableVehicles[self.selectedVehicleIndex].vehicle
    else
        self.currentWorkflow.vehicle = nil
    end
end

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

---Get available targets based on step type
---@return table targets List of target names (with folder prefixes for organization)
function WMEditorGUI:getAvailableTargets()
    local targets = {}

    if self.addStepType == "autodrive" then
        -- Get AutoDrive destinations (with group/folder support)
        if ADIntegration and ADIntegration.isAvailable then
            local adDests = ADIntegration:getDestinations()
            if adDests then
                for _, dest in ipairs(adDests) do
                    -- Use displayName which includes group prefix (e.g., "GroupName/MarkerName")
                    table.insert(targets, dest.displayName or dest.name or tostring(dest))
                end
            end
        end
        -- Add some defaults if none found
        if #targets == 0 then
            table.insert(targets, "Farm/Silo")
            table.insert(targets, "Farm/Workshop")
            table.insert(targets, "Field1")
            table.insert(targets, "Field2")
        end
    else
        -- Courseplay courses - load from saved courses (already includes folder paths)
        if CPCoursesLoader and CPCoursesLoader.isInitialized then
            local courses = CPCoursesLoader:getCourses()
            if courses and #courses > 0 then
                for _, course in ipairs(courses) do
                    table.insert(targets, course)
                end
            else
                -- No courses found - show placeholder
                table.insert(targets, "<No courses found>")
            end
        else
            -- Fallback if loader not available
            table.insert(targets, "Harvest/Field1_Course")
            table.insert(targets, "Harvest/Field2_Course")
            table.insert(targets, "Cultivate/Field1_Course")
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

---Get available fill types
---@return table fillTypes List of fill type names with "None" as first option
function WMEditorGUI:getAvailableFillTypes()
    local fillTypes = {g_i18n:getText("wm_none") or "(None)"}

    if ADIntegration and ADIntegration.isAvailable then
        local adFillTypes = ADIntegration:getFillTypeNames()
        for _, name in ipairs(adFillTypes) do
            table.insert(fillTypes, name)
        end
    end

    return fillTypes
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

    -- === VEHICLE SECTION ===
    currentY = currentY - 0.05
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(L.bgX + L.margin, currentY, 0.016, g_i18n:getText("wm_editor_vehicle") .. ":")

    -- Prev button
    self:drawButton(L.bgX + 0.12, currentY - 0.008, L.smallBtnW, L.smallBtnH, "<", {0.3, 0.3, 0.5, 1})

    -- Vehicle name display
    setOverlayColor(self.overlayId, 0.1, 0.1, 0.12, 1)
    renderOverlay(self.overlayId, L.bgX + 0.17, currentY - 0.008, 0.25, 0.03)

    local vehicleText = g_i18n:getText("wm_no_vehicle")
    if self.selectedVehicleIndex > 0 and self.selectedVehicleIndex <= #self.availableVehicles then
        vehicleText = self.availableVehicles[self.selectedVehicleIndex].name
    end
    if string.len(vehicleText) > 22 then
        vehicleText = string.sub(vehicleText, 1, 20) .. ".."
    end
    setTextColor(1, 1, 1, 1)
    renderText(L.bgX + 0.18, currentY, 0.015, vehicleText)

    -- Next button
    self:drawButton(L.bgX + 0.43, currentY - 0.008, L.smallBtnW, L.smallBtnH, ">", {0.3, 0.3, 0.5, 1})

    -- Vehicle count
    setTextColor(0.5, 0.5, 0.5, 1)
    local countText = string.format("(%d/%d)", self.selectedVehicleIndex, #self.availableVehicles)
    renderText(L.bgX + 0.48, currentY, 0.012, countText)

    -- === STEPS SECTION ===
    currentY = currentY - 0.06
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(L.bgX + L.margin, currentY, 0.018, g_i18n:getText("wm_editor_steps"))
    setTextBold(false)

    -- Step toolbar buttons
    local toolbarX = L.bgX + 0.12
    self:drawButton(toolbarX, currentY - 0.01, 0.07, L.smallBtnH, "+ " .. g_i18n:getText("wm_button_add"), {0.2, 0.5, 0.2, 1})
    self:drawButton(toolbarX + 0.08, currentY - 0.01, 0.07, L.smallBtnH, g_i18n:getText("wm_button_edit"), {0.3, 0.5, 0.7, 1})
    self:drawButton(toolbarX + 0.16, currentY - 0.01, 0.09, L.smallBtnH, "- " .. g_i18n:getText("wm_button_remove"), {0.5, 0.2, 0.2, 1})
    self:drawButton(toolbarX + 0.26, currentY - 0.01, 0.06, L.smallBtnH, g_i18n:getText("wm_button_up"), {0.3, 0.3, 0.5, 1})
    self:drawButton(toolbarX + 0.33, currentY - 0.01, 0.07, L.smallBtnH, g_i18n:getText("wm_button_down"), {0.3, 0.3, 0.5, 1})

    -- Column headers
    currentY = currentY - 0.05
    setTextColor(0.7, 0.7, 0.7, 1)
    renderText(L.bgX + 0.02, currentY, 0.014, "#")
    renderText(L.bgX + 0.05, currentY, 0.014, g_i18n:getText("wm_editor_type"))
    renderText(L.bgX + 0.18, currentY, 0.014, g_i18n:getText("wm_editor_target"))
    renderText(L.bgX + 0.45, currentY, 0.014, g_i18n:getText("wm_editor_action"))

    -- Separator
    currentY = currentY - 0.015
    setOverlayColor(self.overlayId, 0.4, 0.4, 0.4, 1)
    renderOverlay(self.overlayId, L.bgX + 0.01, currentY, L.bgW - 0.02, 0.002)

    -- Steps list
    currentY = currentY - 0.01
    local stepsStartY = currentY

    if #workflow.steps == 0 then
        setTextColor(0.5, 0.5, 0.5, 1)
        renderText(L.bgX + 0.20, currentY - 0.05, 0.016, g_i18n:getText("wm_editor_no_steps"))
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
end

---Draw a button
---@param x number X position
---@param y number Y position
---@param w number Width
---@param h number Height
---@param text string Button text
---@param color table RGBA color
function WMEditorGUI:drawButton(x, y, w, h, text, color)
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

    setTextColor(1, 1, 1, 1)
    local textWidth = getTextWidth(0.014, text)
    renderText(x + (w - textWidth) / 2, y + h * 0.3, 0.014, text)
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

    -- Row background
    if isSelected then
        setOverlayColor(self.overlayId, 0.2, 0.5, 0.2, 0.5)
    else
        setOverlayColor(self.overlayId, 0.1, 0.1, 0.12, 0.5)
    end
    renderOverlay(self.overlayId, baseX + 0.01, y, L.bgW - 0.02, rowHeight)

    -- Row color by type
    local textColor = {1, 1, 1, 1}
    if step.type == WorkflowManager.STEP_AUTODRIVE then
        textColor = {0.4, 0.7, 1, 1}
    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        textColor = {0.4, 1, 0.4, 1}
    end

    setTextColor(textColor[1], textColor[2], textColor[3], textColor[4])

    local textY = y + rowHeight * 0.3

    -- Step number
    renderText(baseX + 0.02, textY, 0.014, tostring(index))

    -- Type
    local typeText = step.type == WorkflowManager.STEP_AUTODRIVE and g_i18n:getText("wm_type_autodrive") or g_i18n:getText("wm_type_courseplay")
    renderText(baseX + 0.05, textY, 0.014, typeText)

    -- Target
    local target = step.target or ""
    if string.len(target) > 40 then
        target = string.sub(target, 1, 38) .. ".."
    end
    renderText(baseX + 0.18, textY, 0.014, target)

    -- Action
    renderText(baseX + 0.45, textY, 0.014, step.action or "default")
end

---Draw the step dialog (add or edit mode)
function WMEditorGUI:drawStepDialog()
    local dlgX, dlgY = 0.25, 0.15
    local dlgW, dlgH = 0.50, 0.70

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

    -- === STEP TYPE ===
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(dlgX + 0.02, fieldY, 0.016, g_i18n:getText("wm_editor_type") .. ":")

    -- Type buttons
    local adColor = self.addStepType == "autodrive" and {0.3, 0.5, 0.7, 1} or {0.2, 0.2, 0.25, 1}
    local cpColor = self.addStepType == "courseplay" and {0.3, 0.6, 0.3, 1} or {0.2, 0.2, 0.25, 1}

    self:drawButton(dlgX + 0.12, fieldY - 0.008, 0.12, 0.035, g_i18n:getText("wm_type_autodrive"), adColor)
    self:drawButton(dlgX + 0.25, fieldY - 0.008, 0.12, 0.035, g_i18n:getText("wm_type_courseplay"), cpColor)

    -- === ACTION / MODE (now above Target) ===
    fieldY = fieldY - 0.06
    setTextColor(0.8, 0.8, 0.8, 1)
    local actionLabel = self.addStepType == "autodrive" and (g_i18n:getText("wm_editor_mode") or "Mode") or (g_i18n:getText("wm_editor_action") or "Action")
    renderText(dlgX + 0.02, fieldY, 0.016, actionLabel .. ":")

    local actions = self:getAvailableActions()

    -- Prev action button
    self:drawButton(dlgX + 0.12, fieldY - 0.008, 0.04, 0.035, "<", {0.3, 0.3, 0.5, 1})

    -- Action display
    setOverlayColor(self.overlayId, 0.1, 0.1, 0.12, 1)
    renderOverlay(self.overlayId, dlgX + 0.17, fieldY - 0.008, 0.25, 0.035)

    local actionText = self:getActionDisplayName(actions[self.addStepActionIndex] or "default")
    setTextColor(1, 1, 1, 1)
    renderText(dlgX + 0.18, fieldY, 0.014, actionText)

    -- Next action button
    self:drawButton(dlgX + 0.43, fieldY - 0.008, 0.04, 0.035, ">", {0.3, 0.3, 0.5, 1})

    -- === TARGET (Primary destination) ===
    -- Labels based on mode:
    --   drive: Target | unload: Unload | pickup_deliver: Pickup | deliver: Target | load: Return To
    fieldY = fieldY - 0.06
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
        -- drive and deliver use default "Target"
    end
    renderText(dlgX + 0.02, fieldY, 0.016, targetLabel .. ":")

    local targets = self:getAvailableTargets()

    -- Prev target button
    self:drawButton(dlgX + 0.12, fieldY - 0.008, 0.04, 0.035, "<", {0.3, 0.3, 0.5, 1})

    -- Target display
    setOverlayColor(self.overlayId, 0.1, 0.1, 0.12, 1)
    renderOverlay(self.overlayId, dlgX + 0.17, fieldY - 0.008, 0.25, 0.035)

    local targetText = targets[self.addStepTargetIndex] or g_i18n:getText("wm_none")
    if string.len(targetText) > 30 then
        targetText = string.sub(targetText, 1, 28) .. ".."
    end
    setTextColor(1, 1, 1, 1)
    renderText(dlgX + 0.18, fieldY, 0.014, targetText)

    -- Next target button
    self:drawButton(dlgX + 0.43, fieldY - 0.008, 0.04, 0.035, ">", {0.3, 0.3, 0.5, 1})

    -- === SECOND TARGET (for modes requiring 2 targets: unload, pickup_deliver, load) ===
    if self.addStepType == "autodrive" and self:currentActionNeedsUnloadTarget() then
        fieldY = fieldY - 0.06
        setTextColor(0.8, 0.8, 0.8, 1)

        -- Label depends on mode:
        --   unload: Target | pickup_deliver: Deliver To | load: Load At
        local actions = self:getAvailableActions()
        local currentAction = actions[self.addStepActionIndex]
        local secondTargetLabel = g_i18n:getText("wm_editor_unload_target") or "Deliver To"
        if currentAction == "unload" then
            secondTargetLabel = g_i18n:getText("wm_editor_target") or "Target"
        elseif currentAction == "load" then
            secondTargetLabel = g_i18n:getText("wm_editor_load_target") or "Load At"
        end
        renderText(dlgX + 0.02, fieldY, 0.016, secondTargetLabel .. ":")

        -- Prev unload target button
        self:drawButton(dlgX + 0.12, fieldY - 0.008, 0.04, 0.035, "<", {0.3, 0.3, 0.5, 1})

        -- Unload target display
        setOverlayColor(self.overlayId, 0.1, 0.1, 0.12, 1)
        renderOverlay(self.overlayId, dlgX + 0.17, fieldY - 0.008, 0.25, 0.035)

        local unloadText = g_i18n:getText("wm_none") or "(Not Set)"
        if self.addStepUnloadTargetIndex > 0 and self.addStepUnloadTargetIndex <= #targets then
            unloadText = targets[self.addStepUnloadTargetIndex]
        end
        if string.len(unloadText) > 30 then
            unloadText = string.sub(unloadText, 1, 28) .. ".."
        end
        setTextColor(1, 1, 1, 1)
        renderText(dlgX + 0.18, fieldY, 0.014, unloadText)

        -- Next unload target button
        self:drawButton(dlgX + 0.43, fieldY - 0.008, 0.04, 0.035, ">", {0.3, 0.3, 0.5, 1})
    end

    -- === FILL TYPE (only for pickup_deliver and load modes) ===
    if self.addStepType == "autodrive" and self:currentActionNeedsFillType() then
        fieldY = fieldY - 0.06
        setTextColor(0.8, 0.8, 0.8, 1)
        renderText(dlgX + 0.02, fieldY, 0.016, (g_i18n:getText("wm_editor_fill_type") or "Fill Type") .. ":")

        local fillTypes = self:getAvailableFillTypes()

        -- Prev fill type button
        self:drawButton(dlgX + 0.12, fieldY - 0.008, 0.04, 0.035, "<", {0.3, 0.3, 0.5, 1})

        -- Fill type display
        setOverlayColor(self.overlayId, 0.1, 0.1, 0.12, 1)
        renderOverlay(self.overlayId, dlgX + 0.17, fieldY - 0.008, 0.25, 0.035)

        local fillTypeText = fillTypes[self.addStepFillTypeIndex] or g_i18n:getText("wm_none") or "(None)"
        if string.len(fillTypeText) > 30 then
            fillTypeText = string.sub(fillTypeText, 1, 28) .. ".."
        end
        setTextColor(1, 1, 1, 1)
        renderText(dlgX + 0.18, fieldY, 0.014, fillTypeText)

        -- Next fill type button
        self:drawButton(dlgX + 0.43, fieldY - 0.008, 0.04, 0.035, ">", {0.3, 0.3, 0.5, 1})
    end

    -- === DIALOG BUTTONS ===
    local btnY = dlgY + 0.03
    local confirmText = self.isEditStepDialogOpen and g_i18n:getText("wm_button_save") or g_i18n:getText("wm_button_add")
    self:drawButton(dlgX + 0.10, btnY, 0.12, 0.045, confirmText, {0.2, 0.6, 0.2, 1})
    self:drawButton(dlgX + 0.28, btnY, 0.12, 0.045, g_i18n:getText("wm_button_cancel"), {0.6, 0.3, 0.3, 1})
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

    -- Vehicle prev button
    if self:isMouseInArea(L.bgX + 0.12, currentY - 0.05 - 0.008, L.smallBtnW, L.smallBtnH) then
        self:prevVehicle()
        return
    end

    -- Vehicle next button
    if self:isMouseInArea(L.bgX + 0.43, currentY - 0.05 - 0.008, L.smallBtnW, L.smallBtnH) then
        self:nextVehicle()
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
            self.selectedStepIndex = i
            return
        end
    end
end

---Handle click on step dialog (add or edit)
---@param x number Mouse X
---@param y number Mouse Y
function WMEditorGUI:handleStepDialogClick(x, y)
    local dlgX, dlgY = 0.25, 0.15
    local dlgW, dlgH = 0.50, 0.70
    local fieldY = dlgY + dlgH - 0.10

    -- Type buttons
    if self:isMouseInArea(dlgX + 0.12, fieldY - 0.008, 0.12, 0.035) then
        self.addStepType = "autodrive"
        self.addStepTargetIndex = 1
        self.addStepActionIndex = 1
        self.addStepUnloadTargetIndex = 0
        self.addStepFillTypeIndex = 1
        return
    end
    if self:isMouseInArea(dlgX + 0.25, fieldY - 0.008, 0.12, 0.035) then
        self.addStepType = "courseplay"
        self.addStepTargetIndex = 1
        self.addStepActionIndex = 1
        self.addStepUnloadTargetIndex = 0
        self.addStepFillTypeIndex = 1
        return
    end

    -- Action/Mode navigation (now above Target)
    fieldY = fieldY - 0.06
    local actions = self:getAvailableActions()

    if self:isMouseInArea(dlgX + 0.12, fieldY - 0.008, 0.04, 0.035) then
        self.addStepActionIndex = self.addStepActionIndex - 1
        if self.addStepActionIndex < 1 then
            self.addStepActionIndex = #actions
        end
        return
    end
    if self:isMouseInArea(dlgX + 0.43, fieldY - 0.008, 0.04, 0.035) then
        self.addStepActionIndex = self.addStepActionIndex + 1
        if self.addStepActionIndex > #actions then
            self.addStepActionIndex = 1
        end
        return
    end

    -- Target navigation
    fieldY = fieldY - 0.06
    local targets = self:getAvailableTargets()

    if self:isMouseInArea(dlgX + 0.12, fieldY - 0.008, 0.04, 0.035) then
        self.addStepTargetIndex = self.addStepTargetIndex - 1
        if self.addStepTargetIndex < 1 then
            self.addStepTargetIndex = #targets
        end
        return
    end
    if self:isMouseInArea(dlgX + 0.43, fieldY - 0.008, 0.04, 0.035) then
        self.addStepTargetIndex = self.addStepTargetIndex + 1
        if self.addStepTargetIndex > #targets then
            self.addStepTargetIndex = 1
        end
        return
    end

    -- Second target navigation (for unload, pickup_deliver, load modes)
    if self.addStepType == "autodrive" and self:currentActionNeedsUnloadTarget() then
        fieldY = fieldY - 0.06

        if self:isMouseInArea(dlgX + 0.12, fieldY - 0.008, 0.04, 0.035) then
            self.addStepUnloadTargetIndex = self.addStepUnloadTargetIndex - 1
            if self.addStepUnloadTargetIndex < 0 then
                self.addStepUnloadTargetIndex = #targets
            end
            return
        end
        if self:isMouseInArea(dlgX + 0.43, fieldY - 0.008, 0.04, 0.035) then
            self.addStepUnloadTargetIndex = self.addStepUnloadTargetIndex + 1
            if self.addStepUnloadTargetIndex > #targets then
                self.addStepUnloadTargetIndex = 0
            end
            return
        end
    end

    -- Fill type navigation (only for pickup_deliver and load modes)
    if self.addStepType == "autodrive" and self:currentActionNeedsFillType() then
        fieldY = fieldY - 0.06
        local fillTypes = self:getAvailableFillTypes()

        if self:isMouseInArea(dlgX + 0.12, fieldY - 0.008, 0.04, 0.035) then
            self.addStepFillTypeIndex = self.addStepFillTypeIndex - 1
            if self.addStepFillTypeIndex < 1 then
                self.addStepFillTypeIndex = #fillTypes
            end
            return
        end
        if self:isMouseInArea(dlgX + 0.43, fieldY - 0.008, 0.04, 0.035) then
            self.addStepFillTypeIndex = self.addStepFillTypeIndex + 1
            if self.addStepFillTypeIndex > #fillTypes then
                self.addStepFillTypeIndex = 1
            end
            return
        end
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
