--[[
    WorkflowManager - Workflow Editor GUI
    Allows editing workflow details and steps
    Uses FS25 GUI system with XML layouts

    Author: WorkflowManager Team
]]

---@class WMEditorGUI
WMEditorGUI = {}

WMEditorGUI.isVisible = false
WMEditorGUI.currentWorkflow = nil
WMEditorGUI.selectedStepIndex = 0
WMEditorGUI.isAddStepDialogOpen = false

-- Add step dialog state
WMEditorGUI.addStepType = "autodrive"
WMEditorGUI.addStepTarget = ""
WMEditorGUI.addStepAction = "drive"

-- Available vehicles cache
WMEditorGUI.availableVehicles = {}
WMEditorGUI.selectedVehicleIndex = 0

-- Editing state
WMEditorGUI.isEditingName = false
WMEditorGUI.editedName = ""

-- Mouse tracking
WMEditorGUI.mouseX = 0
WMEditorGUI.mouseY = 0
WMEditorGUI.wasMouseDown = false
WMEditorGUI.buttonAreas = {}
WMEditorGUI.stepToolbarAreas = {}

---Initialize the editor GUI
function WMEditorGUI:init()
    self.isVisible = false
    self.currentWorkflow = nil
    self.selectedStepIndex = 0
    self.availableVehicles = {}

    WMLogger:debug("WorkflowEditorGUI initialized")
end

---Open the editor for a workflow
---@param workflow table Workflow to edit
function WMEditorGUI:openWorkflow(workflow)
    if workflow == nil then
        WMLogger:error("Cannot open editor - workflow is nil")
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
    end
    self:close()

    -- Refresh main GUI
    WMManagerGUI:refresh()
end

---Cancel changes and close
function WMEditorGUI:cancelAndClose()
    self:close()
end

---Refresh the list of available vehicles
function WMEditorGUI:refreshVehicleList()
    self.availableVehicles = {}

    if g_currentMission == nil or g_currentMission.vehicles == nil then
        return
    end

    for _, vehicle in ipairs(g_currentMission.vehicles) do
        -- Check if vehicle has AutoDrive or Courseplay
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

    WMLogger:debug("Found %d vehicles with AD/CP support", #self.availableVehicles)
end

---Set workflow name
---@param name string New workflow name
function WMEditorGUI:setWorkflowName(name)
    self.editedName = name
    if self.currentWorkflow ~= nil then
        self.currentWorkflow.name = name
    end
end

---Assign vehicle to workflow by index
---@param index number Vehicle index in availableVehicles
function WMEditorGUI:assignVehicleByIndex(index)
    if self.currentWorkflow == nil then
        return
    end

    self.selectedVehicleIndex = index

    if index > 0 and index <= #self.availableVehicles then
        self.currentWorkflow.vehicle = self.availableVehicles[index].vehicle
        WMLogger:debug("Assigned vehicle: %s", self.availableVehicles[index].name)
    else
        self.currentWorkflow.vehicle = nil
        WMLogger:debug("Cleared vehicle assignment")
    end
end

---Add a new step to the workflow
---@param stepType string Step type (autodrive/courseplay)
---@param target string Target route/course name
---@param action string|nil Action type
function WMEditorGUI:addStep(stepType, target, action)
    if self.currentWorkflow == nil then
        return
    end

    local step = {
        type = stepType,
        target = target,
        action = action or "default"
    }

    table.insert(self.currentWorkflow.steps, step)
    WMLogger:debug("Added step: %s -> %s", stepType, target)
end

---Remove selected step
function WMEditorGUI:removeSelectedStep()
    if self.currentWorkflow == nil or self.selectedStepIndex <= 0 then
        return
    end

    table.remove(self.currentWorkflow.steps, self.selectedStepIndex)

    -- Adjust selection
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

---Get available AutoDrive destinations
---@return table destinations List of destination names
function WMEditorGUI:getAutoDriveDestinations()
    local destinations = {}

    if ADIntegration and ADIntegration.isAvailable then
        local adDests = ADIntegration:getDestinations()
        if adDests then
            for _, dest in ipairs(adDests) do
                table.insert(destinations, dest.name or dest)
            end
        end
    end

    return destinations
end

---Get available Courseplay actions
---@return table actions List of action names
function WMEditorGUI:getCourseplayActions()
    return {
        {id = "last", name = g_i18n:getText("wm_action_last")},
        {id = "first", name = g_i18n:getText("wm_action_first")},
        {id = "fieldwork", name = g_i18n:getText("wm_action_fieldwork")},
        {id = "harvest", name = g_i18n:getText("wm_action_harvest")},
    }
end

---Get AutoDrive actions
---@return table actions List of action names
function WMEditorGUI:getAutoDriveActions()
    return {
        {id = "drive", name = g_i18n:getText("wm_action_drive")},
    }
end

---Open the add step dialog
function WMEditorGUI:openAddStepDialog()
    self.isAddStepDialogOpen = true
    self.addStepType = "autodrive"
    self.addStepTarget = ""
    self.addStepAction = "drive"
end

---Close the add step dialog
function WMEditorGUI:closeAddStepDialog()
    self.isAddStepDialogOpen = false
end

---Confirm adding a step from the dialog
function WMEditorGUI:confirmAddStep()
    if self.addStepTarget ~= "" then
        self:addStep(self.addStepType, self.addStepTarget, self.addStepAction)
    end
    self:closeAddStepDialog()
end

---Draw the editor GUI
function WMEditorGUI:draw()
    if not self.isVisible or self.currentWorkflow == nil then
        return
    end

    local workflow = self.currentWorkflow

    -- Draw semi-transparent background
    local bgX, bgY = 0.2, 0.08
    local bgW, bgH = 0.6, 0.84

    setTextColor(0, 0, 0, 0.8)
    renderOverlay(g_baseUIFilename, bgX, bgY, bgW, bgH)

    -- Draw border
    local borderColor = {0.3, 0.7, 0.3, 1}
    setTextColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    renderOverlay(g_baseUIFilename, bgX, bgY, bgW, 0.003)
    renderOverlay(g_baseUIFilename, bgX, bgY + bgH - 0.003, bgW, 0.003)
    renderOverlay(g_baseUIFilename, bgX, bgY, 0.003, bgH)
    renderOverlay(g_baseUIFilename, bgX + bgW - 0.003, bgY, 0.003, bgH)

    -- Draw title bar
    setTextColor(0.15, 0.15, 0.15, 1)
    renderOverlay(g_baseUIFilename, bgX, bgY + bgH - 0.06, bgW, 0.06)

    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(bgX + 0.02, bgY + bgH - 0.045, 0.022, g_i18n:getText("wm_editor_title") .. ": " .. workflow.name)
    setTextBold(false)

    -- Close hint
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(bgX + bgW - 0.08, bgY + bgH - 0.04, 0.016, "[ESC]")

    -- Draw workflow properties
    local propY = bgY + bgH - 0.12

    -- Name field
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(bgX + 0.02, propY, 0.016, g_i18n:getText("wm_editor_name"))
    setTextColor(1, 1, 1, 1)
    renderText(bgX + 0.12, propY, 0.016, self.editedName)
    setTextColor(0.5, 0.5, 0.5, 1)
    renderText(bgX + 0.45, propY, 0.012, "[Press F2 to edit]")

    propY = propY - 0.04

    -- Vehicle field
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(bgX + 0.02, propY, 0.016, g_i18n:getText("wm_editor_vehicle"))

    local vehicleText = g_i18n:getText("wm_no_vehicle")
    if self.selectedVehicleIndex > 0 and self.selectedVehicleIndex <= #self.availableVehicles then
        vehicleText = self.availableVehicles[self.selectedVehicleIndex].name
    end
    setTextColor(1, 1, 1, 1)
    renderText(bgX + 0.12, propY, 0.016, vehicleText)
    setTextColor(0.5, 0.5, 0.5, 1)
    renderText(bgX + 0.45, propY, 0.012, "[V: cycle vehicles]")

    -- Steps section header
    propY = propY - 0.06
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(bgX + 0.02, propY, 0.018, g_i18n:getText("wm_editor_steps"))
    setTextBold(false)

    -- Step toolbar
    self:drawStepToolbar(bgX + 0.35, propY - 0.005)

    -- Column headers
    propY = propY - 0.04
    setTextColor(0.7, 0.7, 0.7, 1)
    renderText(bgX + 0.02, propY, 0.014, "#")
    renderText(bgX + 0.06, propY, 0.014, g_i18n:getText("wm_editor_type"))
    renderText(bgX + 0.18, propY, 0.014, g_i18n:getText("wm_editor_target"))
    renderText(bgX + 0.42, propY, 0.014, g_i18n:getText("wm_editor_action"))

    -- Separator
    propY = propY - 0.015
    setTextColor(0.4, 0.4, 0.4, 1)
    renderOverlay(g_baseUIFilename, bgX + 0.01, propY, bgW - 0.02, 0.002)

    -- Steps list
    propY = propY - 0.03
    if #workflow.steps == 0 then
        setTextColor(0.6, 0.6, 0.6, 1)
        renderText(bgX + 0.15, propY - 0.05, 0.016, g_i18n:getText("wm_editor_no_steps"))
    else
        for i, step in ipairs(workflow.steps) do
            self:drawStepRow(bgX, propY, i, step)
            propY = propY - 0.04

            if i >= 10 then
                break
            end
        end
    end

    -- Bottom buttons
    local btnY = bgY + 0.04
    self:drawBottomButtons(bgX + 0.15, btnY)

    -- Draw add step dialog if open
    if self.isAddStepDialogOpen then
        self:drawAddStepDialog()
    end
end

---Draw step toolbar buttons
---@param x number X position
---@param y number Y position
function WMEditorGUI:drawStepToolbar(x, y)
    local buttonSize = 0.03
    local spacing = 0.005
    local currentX = x

    local buttons = {
        {text = "^", hint = "Up", action = "up"},
        {text = "v", hint = "Down", action = "down"},
        {text = "+", hint = "Add", action = "add"},
        {text = "-", hint = "Remove", action = "remove"},
    }

    for _, btn in ipairs(buttons) do
        setTextColor(0.3, 0.3, 0.3, 0.8)
        renderOverlay(g_baseUIFilename, currentX, y, buttonSize, buttonSize)

        setTextColor(1, 1, 1, 1)
        local textX = currentX + buttonSize * 0.35
        renderText(textX, y + buttonSize * 0.25, 0.016, btn.text)

        currentX = currentX + buttonSize + spacing
    end

    -- Keyboard hints
    setTextColor(0.5, 0.5, 0.5, 1)
    renderText(currentX + 0.01, y + 0.008, 0.010, "[+/-/U/D]")
end

---Draw a single step row
---@param baseX number Base X position
---@param y number Y position
---@param index number Step index
---@param step table Step data
function WMEditorGUI:drawStepRow(baseX, y, index, step)
    local isSelected = (index == self.selectedStepIndex)
    local rowHeight = 0.035

    -- Selection highlight
    if isSelected then
        setTextColor(0.2, 0.5, 0.2, 0.4)
        renderOverlay(g_baseUIFilename, baseX + 0.01, y - rowHeight + 0.01, 0.58, rowHeight)
    end

    -- Row color by type
    local textColor = {1, 1, 1, 1}
    if step.type == WorkflowManager.STEP_AUTODRIVE then
        textColor = {0.4, 0.7, 1, 1}  -- Blue for AutoDrive
    elseif step.type == WorkflowManager.STEP_COURSEPLAY then
        textColor = {0.4, 1, 0.4, 1}  -- Green for Courseplay
    end

    setTextColor(textColor[1], textColor[2], textColor[3], textColor[4])

    -- Step number
    renderText(baseX + 0.02, y, 0.014, tostring(index))

    -- Type
    local typeText = step.type == WorkflowManager.STEP_AUTODRIVE and
        g_i18n:getText("wm_type_autodrive") or g_i18n:getText("wm_type_courseplay")
    renderText(baseX + 0.06, y, 0.014, typeText)

    -- Target (truncate if too long)
    local target = step.target or ""
    if string.len(target) > 25 then
        target = string.sub(target, 1, 23) .. ".."
    end
    renderText(baseX + 0.18, y, 0.014, target)

    -- Action
    renderText(baseX + 0.42, y, 0.014, step.action or "default")
end

---Draw bottom action buttons
---@param x number X position
---@param y number Y position
function WMEditorGUI:drawBottomButtons(x, y)
    local buttonW = 0.12
    local buttonH = 0.045
    local spacing = 0.02

    -- Save button
    setTextColor(0.2, 0.5, 0.2, 0.8)
    renderOverlay(g_baseUIFilename, x, y, buttonW, buttonH)
    setTextColor(1, 1, 1, 1)
    local saveText = g_i18n:getText("wm_button_save")
    renderText(x + buttonW * 0.5 - getTextWidth(0.016, saveText) * 0.5, y + buttonH * 0.3, 0.016, saveText)

    -- Cancel button
    local cancelX = x + buttonW + spacing
    setTextColor(0.5, 0.3, 0.3, 0.8)
    renderOverlay(g_baseUIFilename, cancelX, y, buttonW, buttonH)
    setTextColor(1, 1, 1, 1)
    local cancelText = g_i18n:getText("wm_button_cancel")
    renderText(cancelX + buttonW * 0.5 - getTextWidth(0.016, cancelText) * 0.5, y + buttonH * 0.3, 0.016, cancelText)

    -- Keyboard hints
    setTextColor(0.5, 0.5, 0.5, 1)
    renderText(x + 0.3, y + 0.015, 0.012, "[Enter: Save] [ESC: Cancel]")
end

---Draw the add step dialog
function WMEditorGUI:drawAddStepDialog()
    -- Dialog background
    local dlgX, dlgY = 0.35, 0.3
    local dlgW, dlgH = 0.3, 0.4

    setTextColor(0, 0, 0, 0.9)
    renderOverlay(g_baseUIFilename, dlgX, dlgY, dlgW, dlgH)

    -- Border
    setTextColor(0.5, 0.8, 0.5, 1)
    renderOverlay(g_baseUIFilename, dlgX, dlgY, dlgW, 0.003)
    renderOverlay(g_baseUIFilename, dlgX, dlgY + dlgH - 0.003, dlgW, 0.003)
    renderOverlay(g_baseUIFilename, dlgX, dlgY, 0.003, dlgH)
    renderOverlay(g_baseUIFilename, dlgX + dlgW - 0.003, dlgY, 0.003, dlgH)

    -- Title
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(dlgX + 0.02, dlgY + dlgH - 0.05, 0.020, g_i18n:getText("wm_dialog_add_step"))
    setTextBold(false)

    local fieldY = dlgY + dlgH - 0.12

    -- Step type
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(dlgX + 0.02, fieldY, 0.016, g_i18n:getText("wm_editor_type") .. ":")
    setTextColor(1, 1, 1, 1)
    local typeText = self.addStepType == "autodrive" and
        g_i18n:getText("wm_type_autodrive") or g_i18n:getText("wm_type_courseplay")
    renderText(dlgX + 0.10, fieldY, 0.016, typeText)
    setTextColor(0.5, 0.5, 0.5, 1)
    renderText(dlgX + 0.22, fieldY, 0.012, "[T: toggle]")

    fieldY = fieldY - 0.06

    -- Target
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(dlgX + 0.02, fieldY, 0.016, g_i18n:getText("wm_editor_target") .. ":")
    setTextColor(1, 1, 1, 1)
    local targetDisplay = self.addStepTarget ~= "" and self.addStepTarget or "(none)"
    renderText(dlgX + 0.10, fieldY, 0.016, targetDisplay)

    fieldY = fieldY - 0.06

    -- Action
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(dlgX + 0.02, fieldY, 0.016, g_i18n:getText("wm_editor_action") .. ":")
    setTextColor(1, 1, 1, 1)
    renderText(dlgX + 0.10, fieldY, 0.016, self.addStepAction)

    -- Dialog buttons
    local btnY = dlgY + 0.04
    local btnW = 0.08
    local btnH = 0.04

    -- OK button
    setTextColor(0.2, 0.5, 0.2, 0.8)
    renderOverlay(g_baseUIFilename, dlgX + 0.05, btnY, btnW, btnH)
    setTextColor(1, 1, 1, 1)
    renderText(dlgX + 0.07, btnY + 0.012, 0.014, "OK")

    -- Cancel button
    setTextColor(0.5, 0.3, 0.3, 0.8)
    renderOverlay(g_baseUIFilename, dlgX + 0.17, btnY, btnW, btnH)
    setTextColor(1, 1, 1, 1)
    renderText(dlgX + 0.18, btnY + 0.012, 0.014, "Cancel")
end

---Update function
---@param dt number Delta time
function WMEditorGUI:update(dt)
    if not self.isVisible then
        return
    end

    self:handleInput()
end

---Handle keyboard/mouse input
function WMEditorGUI:handleInput()
    if self.isAddStepDialogOpen then
        self:handleAddStepDialogInput()
        return
    end

    -- ESC to close
    if Input.isKeyPressed(Input.KEY_escape) then
        self:cancelAndClose()
        return
    end

    -- Enter to save
    if Input.isKeyPressed(Input.KEY_return) then
        self:saveAndClose()
        return
    end

    -- V to cycle vehicles
    if Input.isKeyPressed(Input.KEY_v) then
        local nextIndex = self.selectedVehicleIndex + 1
        if nextIndex > #self.availableVehicles then
            nextIndex = 0  -- None
        end
        self:assignVehicleByIndex(nextIndex)
    end

    -- Step selection with number keys
    for i = 1, 9 do
        if Input.isKeyPressed(Input["KEY_" .. tostring(i)]) then
            if self.currentWorkflow and i <= #self.currentWorkflow.steps then
                self.selectedStepIndex = i
            end
        end
    end

    -- Arrow keys for step navigation
    if Input.isKeyPressed(Input.KEY_up) then
        if self.currentWorkflow and self.selectedStepIndex > 1 then
            self.selectedStepIndex = self.selectedStepIndex - 1
        end
    end

    if Input.isKeyPressed(Input.KEY_down) then
        if self.currentWorkflow and self.selectedStepIndex < #self.currentWorkflow.steps then
            self.selectedStepIndex = self.selectedStepIndex + 1
        elseif self.currentWorkflow and self.selectedStepIndex == 0 and #self.currentWorkflow.steps > 0 then
            self.selectedStepIndex = 1
        end
    end

    -- + to add step (opens dialog)
    if Input.isKeyPressed(Input.KEY_KP_add) or Input.isKeyPressed(Input.KEY_equals) then
        self:openAddStepDialog()
    end

    -- - to remove step
    if Input.isKeyPressed(Input.KEY_KP_subtract) or Input.isKeyPressed(Input.KEY_minus) then
        self:removeSelectedStep()
    end

    -- U to move up
    if Input.isKeyPressed(Input.KEY_u) then
        self:moveStepUp()
    end

    -- D to move down
    if Input.isKeyPressed(Input.KEY_d) then
        self:moveStepDown()
    end
end

---Handle input for add step dialog
function WMEditorGUI:handleAddStepDialogInput()
    -- ESC to close dialog
    if Input.isKeyPressed(Input.KEY_escape) then
        self:closeAddStepDialog()
        return
    end

    -- Enter to confirm
    if Input.isKeyPressed(Input.KEY_return) then
        self:confirmAddStep()
        return
    end

    -- T to toggle type
    if Input.isKeyPressed(Input.KEY_t) then
        if self.addStepType == "autodrive" then
            self.addStepType = "courseplay"
            self.addStepAction = "last"
        else
            self.addStepType = "autodrive"
            self.addStepAction = "drive"
        end
    end

    -- Number keys to select target (simplified for now)
    local destinations = self:getAutoDriveDestinations()
    for i = 1, math.min(9, #destinations) do
        if Input.isKeyPressed(Input["KEY_" .. tostring(i)]) then
            self.addStepTarget = destinations[i]
        end
    end
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

    -- Only handle left mouse button
    if button ~= 1 then
        return
    end

    -- Handle click on button release
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

---Handle mouse click at position
---@param x number Mouse X
---@param y number Mouse Y
function WMEditorGUI:handleMouseClick(x, y)
    -- If add step dialog is open, handle that first
    if self.isAddStepDialogOpen then
        self:handleAddStepDialogClick(x, y)
        return
    end

    -- Check bottom buttons (Save/Cancel)
    local bgX, bgY = 0.2, 0.08
    local bgW, bgH = 0.6, 0.84
    local btnY = bgY + 0.04
    local buttonW = 0.12
    local buttonH = 0.045
    local spacing = 0.02
    local btnX = bgX + 0.15

    -- Save button
    if self:isMouseInArea(btnX, btnY, buttonW, buttonH) then
        self:saveAndClose()
        return
    end

    -- Cancel button
    if self:isMouseInArea(btnX + buttonW + spacing, btnY, buttonW, buttonH) then
        self:cancelAndClose()
        return
    end

    -- Check step toolbar
    local toolbarX = bgX + 0.35
    local toolbarY = bgY + bgH - 0.12 - 0.06 - 0.005
    local buttonSize = 0.03
    local btnSpacing = 0.005

    -- Up button
    if self:isMouseInArea(toolbarX, toolbarY, buttonSize, buttonSize) then
        self:moveStepUp()
        return
    end
    -- Down button
    if self:isMouseInArea(toolbarX + buttonSize + btnSpacing, toolbarY, buttonSize, buttonSize) then
        self:moveStepDown()
        return
    end
    -- Add button
    if self:isMouseInArea(toolbarX + 2 * (buttonSize + btnSpacing), toolbarY, buttonSize, buttonSize) then
        self:openAddStepDialog()
        return
    end
    -- Remove button
    if self:isMouseInArea(toolbarX + 3 * (buttonSize + btnSpacing), toolbarY, buttonSize, buttonSize) then
        self:removeSelectedStep()
        return
    end

    -- Check step list clicks
    self:handleStepListClick(x, y)
end

---Handle click on step list
---@param x number Mouse X
---@param y number Mouse Y
function WMEditorGUI:handleStepListClick(x, y)
    if self.currentWorkflow == nil then
        return
    end

    local bgX, bgY = 0.2, 0.08
    local bgH = 0.84
    local propY = bgY + bgH - 0.12
    propY = propY - 0.04  -- After name
    propY = propY - 0.06  -- After vehicle
    propY = propY - 0.04  -- After headers
    propY = propY - 0.015 -- After separator
    propY = propY - 0.03  -- Start of list
    local rowHeight = 0.04

    for i = 1, math.min(#self.currentWorkflow.steps, 10) do
        local rowY = propY - (i - 1) * rowHeight
        if self:isMouseInArea(bgX + 0.01, rowY - rowHeight + 0.01, 0.58, rowHeight) then
            self.selectedStepIndex = i
            return
        end
    end
end

---Handle click on add step dialog
---@param x number Mouse X
---@param y number Mouse Y
function WMEditorGUI:handleAddStepDialogClick(x, y)
    local dlgX, dlgY = 0.35, 0.3
    local dlgW, dlgH = 0.3, 0.4
    local btnY = dlgY + 0.04
    local btnW = 0.08
    local btnH = 0.04

    -- OK button
    if self:isMouseInArea(dlgX + 0.05, btnY, btnW, btnH) then
        self:confirmAddStep()
        return
    end

    -- Cancel button
    if self:isMouseInArea(dlgX + 0.17, btnY, btnW, btnH) then
        self:closeAddStepDialog()
        return
    end

    -- Type toggle area
    local fieldY = dlgY + dlgH - 0.12
    if self:isMouseInArea(dlgX + 0.02, fieldY - 0.02, dlgW - 0.04, 0.04) then
        if self.addStepType == "autodrive" then
            self.addStepType = "courseplay"
            self.addStepAction = "last"
        else
            self.addStepType = "autodrive"
            self.addStepAction = "drive"
        end
    end
end
