--[[
    WorkflowManager - Main GUI
    Displays list of workflows and provides management controls
    Uses FS25 GUI system with XML layouts

    Author: WorkflowManager Team
]]

---@class WMManagerGUI
WMManagerGUI = {}

WMManagerGUI.isVisible = false
WMManagerGUI.selectedWorkflowIndex = 0
WMManagerGUI.isXmlGuiLoaded = false

-- GUI element references (populated after XML load)
WMManagerGUI.frame = nil
WMManagerGUI.workflowList = nil
WMManagerGUI.emptyListText = nil
WMManagerGUI.statusText = nil

-- List item data cache
WMManagerGUI.listData = {}

-- Mouse tracking
WMManagerGUI.mouseX = 0
WMManagerGUI.mouseY = 0
WMManagerGUI.wasMouseDown = false

-- Double-click tracking
WMManagerGUI.lastClickTime = 0
WMManagerGUI.lastClickIndex = 0
WMManagerGUI.DOUBLE_CLICK_THRESHOLD = 400  -- milliseconds

-- Button positions (set during draw)
WMManagerGUI.buttonAreas = {}

-- Overlay IDs (created once, used for rendering)
WMManagerGUI.overlayId = nil

---Initialize the GUI
function WMManagerGUI:init()
    self.isVisible = false
    self.selectedWorkflowIndex = 0
    self.listData = {}
    self.mouseX = 0
    self.mouseY = 0
    self.wasMouseDown = false
    self.buttonAreas = {}
    self.lastClickTime = 0
    self.lastClickIndex = 0

    -- Create overlay for rendering solid colors
    -- Use our mod's white.dds texture (1x1 white pixel that can be tinted)
    self.overlayId = nil

    if WorkflowManager.modDirectory ~= nil then
        local whiteTexture = Utils.getFilename("textures/white.dds", WorkflowManager.modDirectory)
        self.overlayId = createImageOverlay(whiteTexture)
        if self.overlayId ~= nil and self.overlayId ~= 0 then
            WMLogger:debug("Created overlay from mod texture: %s (ID: %s)", whiteTexture, tostring(self.overlayId))
        else
            WMLogger:error("Failed to create overlay from: %s", whiteTexture)
        end
    else
        WMLogger:error("WorkflowManager.modDirectory is nil!")
    end

    if self.overlayId == nil or self.overlayId == 0 then
        WMLogger:warning("Could not create overlay - GUI rendering may fail")
    end

    -- Try to load XML GUI
    self:loadXmlGui()

    WMLogger:debug("WorkflowManagerGUI initialized (XML loaded: %s)", tostring(self.isXmlGuiLoaded))
end

---Load the XML GUI layout
function WMManagerGUI:loadXmlGui()
    local xmlFile = Utils.getFilename("xml/gui/WorkflowManagerGUI.xml", WorkflowManager.modDirectory)

    if xmlFile == nil or not fileExists(xmlFile) then
        WMLogger:warning("GUI XML file not found: %s", tostring(xmlFile))
        return
    end

    -- Register the frame element with the GUI system
    if g_gui ~= nil then
        -- Create frame from XML
        local success = pcall(function()
            g_gui:loadProfiles(xmlFile)
        end)

        if success then
            self.isXmlGuiLoaded = true
            WMLogger:debug("Loaded GUI profiles from XML")
        else
            WMLogger:debug("Could not load GUI profiles (using fallback rendering)")
        end
    end
end

---Show the GUI
function WMManagerGUI:show()
    if self.isVisible then
        return
    end

    self.isVisible = true
    self:refresh()

    -- Load data cache for AD destinations and CP courses (only loaded once per GUI session)
    if WMEditorGUI and not WMEditorGUI.dataCacheLoaded then
        WMEditorGUI:loadDataCache()
    end

    -- Disable input to game while GUI is shown
    if g_inputBinding ~= nil then
        g_inputBinding:setShowMouseCursor(true)
    end

    WMLogger:debug("WorkflowManagerGUI shown")
end

---Hide the GUI
function WMManagerGUI:hide()
    if not self.isVisible then
        return
    end

    self.isVisible = false

    -- Re-enable game input
    if g_inputBinding ~= nil then
        g_inputBinding:setShowMouseCursor(false)
    end

    -- Also close editor if open
    if WMEditorGUI.isVisible then
        WMEditorGUI:close()
    end

    -- Clear data cache so it refreshes on next open
    if WMEditorGUI then
        WMEditorGUI:clearDataCache()
    end

    WMLogger:debug("WorkflowManagerGUI hidden")
end

---Toggle GUI visibility
function WMManagerGUI:toggle()
    if self.isVisible then
        self:hide()
    else
        self:show()
    end
end

---Refresh the workflow list
function WMManagerGUI:refresh()
    if not self.isVisible then
        return
    end

    -- Get all workflows
    local workflows = WorkflowManager:getAllWorkflows()
    self.listData = workflows

    -- Update status
    WMLogger:debug("Refreshed workflow list: %d workflows", #workflows)
end

---Get status text for a workflow
---Uses vehicle-aware runtime state for active workflows
---@param workflow table Workflow definition
---@return string statusText Formatted status text
function WMManagerGUI:getStatusText(workflow)
    -- Look up runtime state from current vehicle
    local vehicle = g_currentMission and g_currentMission.controlledVehicle
    if vehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
        vehicle = g_localPlayer:getCurrentVehicle()
    end
    local activeData = vehicle and WorkflowManager:getVehicleWorkflowState(vehicle)
    local isThisWorkflow = activeData and activeData.workflow.id == workflow.id
    local status = isThisWorkflow and activeData.status or WorkflowManager.STATUS_READY
    local currentStep = isThisWorkflow and activeData.currentStep or 1

    if status == WorkflowManager.STATUS_RUNNING then
        return string.format("%s (%d/%d)",
            g_i18n:getText("wm_status_running"),
            currentStep,
            #workflow.steps)
    elseif status == WorkflowManager.STATUS_READY then
        return g_i18n:getText("wm_status_ready")
    elseif status == WorkflowManager.STATUS_PAUSED then
        return g_i18n:getText("wm_status_paused")
    elseif status == WorkflowManager.STATUS_COMPLETED then
        return g_i18n:getText("wm_status_completed")
    elseif status == WorkflowManager.STATUS_ERROR then
        return g_i18n:getText("wm_status_error")
    end

    return status or "unknown"
end

---Milestone 4: Vehicle is no longer stored with workflow
---This function now returns a hint about current vehicle usage
---@param workflow table Workflow data (not used)
---@return string vehicleName Static text about current vehicle
function WMManagerGUI:getVehicleName(workflow)
    -- Milestone 4: Vehicles are detected at runtime when starting
    return g_i18n:getText("wm_current_vehicle") or "Current"
end

---Handle workflow selection
---@param index number Selected index
function WMManagerGUI:onWorkflowSelected(index)
    self.selectedWorkflowIndex = index
    WMLogger:debug("Selected workflow index: %d", index)
end

---Handle workflow selection changed (callback from GUI)
function WMManagerGUI:onWorkflowSelectionChanged(list, section, index)
    self:onWorkflowSelected(index)
end

---Handle workflow double click (callback from GUI)
function WMManagerGUI:onWorkflowDoubleClick(list, section, index)
    self:onWorkflowSelected(index)
    self:onClickEdit()
end

---Handle "New" button click
function WMManagerGUI:onClickNew()
    WMLogger:debug("New workflow button clicked")

    -- Create new workflow
    local workflow = WorkflowManager:createWorkflow(g_i18n:getText("wm_editor_title"))

    -- Hide main GUI while editor is open
    self.isVisible = false

    -- Open editor for the new workflow
    WMEditorGUI:openWorkflow(workflow)
end

---Handle "Edit" button click
function WMManagerGUI:onClickEdit()
    if self.selectedWorkflowIndex <= 0 then
        WMLogger:warning("No workflow selected for editing")
        return
    end

    local workflows = WorkflowManager:getAllWorkflows()
    local workflow = workflows[self.selectedWorkflowIndex]

    if workflow ~= nil then
        -- Hide main GUI while editor is open
        self.isVisible = false

        WMEditorGUI:openWorkflow(workflow)
    end
end

---Handle "Delete" button click
function WMManagerGUI:onClickDelete()
    if self.selectedWorkflowIndex <= 0 then
        WMLogger:warning("No workflow selected for deletion")
        return
    end

    local workflows = WorkflowManager:getAllWorkflows()
    local workflow = workflows[self.selectedWorkflowIndex]

    if workflow ~= nil then
        WorkflowManager:deleteWorkflow(workflow.id)
        self.selectedWorkflowIndex = 0
        self:refresh()

        -- Persist to XML
        WorkflowManager:saveWorkflows()
    end
end

---Handle "Start" button click
function WMManagerGUI:onClickStart()
    if self.selectedWorkflowIndex <= 0 then
        WMLogger:warning("No workflow selected to start")
        return
    end

    local workflows = WorkflowManager:getAllWorkflows()
    local workflow = workflows[self.selectedWorkflowIndex]

    if workflow ~= nil then
        WorkflowManager:startWorkflow(workflow.id)
        self:refresh()
    end
end

---Handle "Stop" button click
function WMManagerGUI:onClickStop()
    if self.selectedWorkflowIndex <= 0 then
        WMLogger:warning("No workflow selected to stop")
        return
    end

    local workflows = WorkflowManager:getAllWorkflows()
    local workflow = workflows[self.selectedWorkflowIndex]

    if workflow ~= nil then
        WorkflowManager:stopWorkflow(workflow.id)
        self:refresh()
    end
end

---Handle "Pause" button click
function WMManagerGUI:onClickPause()
    if self.selectedWorkflowIndex <= 0 then
        return
    end

    local workflows = WorkflowManager:getAllWorkflows()
    local workflow = workflows[self.selectedWorkflowIndex]

    if workflow ~= nil then
        local vehicle = g_currentMission and g_currentMission.controlledVehicle
        if vehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
            vehicle = g_localPlayer:getCurrentVehicle()
        end
        local activeData = vehicle and WorkflowManager:getVehicleWorkflowState(vehicle)
        local isThisWorkflow = activeData and activeData.workflow.id == workflow.id
        if isThisWorkflow then
            if activeData.status == WorkflowManager.STATUS_RUNNING then
                WorkflowManager:pauseWorkflow(workflow.id)
            elseif activeData.status == WorkflowManager.STATUS_PAUSED then
                WorkflowManager:resumeWorkflow(workflow.id)
            end
        end
        self:refresh()
    end
end

---Handle "Close" button click
function WMManagerGUI:onClickClose()
    self:hide()
end

---Draw the GUI (called each frame when visible)
function WMManagerGUI:draw()
    if not self.isVisible then
        return
    end

    -- Ensure overlay exists
    if self.overlayId == nil then
        return
    end

    -- Reset UVs to use full texture (bottom-left, bottom-right, top-left, top-right)
    setOverlayUVs(self.overlayId, 0, 0, 1, 0, 0, 1, 1, 1)

    -- Draw solid background (render twice for full opacity)
    local bgX, bgY = 0.25, 0.12
    local bgW, bgH = 0.5, 0.76
    -- First pass: dark background
    setOverlayColor(self.overlayId, 0.05, 0.05, 0.08, 1)
    renderOverlay(self.overlayId, bgX, bgY, bgW, bgH)
    -- Second pass: slight transparency for depth effect
    setOverlayColor(self.overlayId, 0, 0, 0, 0.3)
    renderOverlay(self.overlayId, bgX, bgY, bgW, bgH)

    -- Draw border
    local borderColor = {0.2, 0.6, 0.9, 1}
    setOverlayColor(self.overlayId, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    renderOverlay(self.overlayId, bgX, bgY, bgW, 0.003)           -- Bottom
    renderOverlay(self.overlayId, bgX, bgY + bgH - 0.003, bgW, 0.003)  -- Top
    renderOverlay(self.overlayId, bgX, bgY, 0.003, bgH)           -- Left
    renderOverlay(self.overlayId, bgX + bgW - 0.003, bgY, 0.003, bgH)  -- Right

    -- Draw title bar
    setOverlayColor(self.overlayId, 0.15, 0.15, 0.15, 1)
    renderOverlay(self.overlayId, bgX, bgY + bgH - 0.06, bgW, 0.06)

    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(bgX + 0.02, bgY + bgH - 0.045, 0.025, g_i18n:getText("wm_title"))
    setTextBold(false)

    -- Draw close button hint
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(bgX + bgW - 0.08, bgY + bgH - 0.04, 0.018, "[X] ESC")

    -- Draw toolbar
    local toolbarY = bgY + bgH - 0.13
    self:drawToolbar(bgX + 0.02, toolbarY)

    -- Draw column headers
    -- Milestone 4: Vehicle column removed - vehicles detected at runtime
    local headerY = toolbarY - 0.05
    setTextColor(0.7, 0.7, 0.7, 1)
    setTextBold(true)
    renderText(bgX + 0.02, headerY, 0.016, g_i18n:getText("wm_header_name"))
    renderText(bgX + 0.28, headerY, 0.016, g_i18n:getText("wm_header_steps"))
    renderText(bgX + 0.36, headerY, 0.016, g_i18n:getText("wm_header_status"))
    setTextBold(false)

    -- Draw separator line
    setOverlayColor(self.overlayId, 0.4, 0.4, 0.4, 1)
    renderOverlay(self.overlayId, bgX + 0.01, headerY - 0.015, bgW - 0.02, 0.002)

    -- Draw workflow list
    local listY = headerY - 0.04
    local workflows = WorkflowManager:getAllWorkflows()

    if #workflows == 0 then
        setTextColor(0.6, 0.6, 0.6, 1)
        renderText(bgX + 0.1, listY - 0.1, 0.018, g_i18n:getText("wm_no_workflows"))
    else
        for i, workflow in ipairs(workflows) do
            self:drawWorkflowRow(bgX, listY, i, workflow)
            listY = listY - 0.045

            -- Stop if we've drawn too many
            if i >= 12 then
                break
            end
        end
    end

    -- Draw status bar
    local statusY = bgY + 0.02
    setTextColor(0.6, 0.6, 0.6, 1)
    local statusInfo = string.format(g_i18n:getText("wm_workflows_count"), #workflows)
    renderText(bgX + 0.02, statusY, 0.014, statusInfo)

    -- Draw key hints
    setTextColor(0.5, 0.5, 0.5, 1)
    renderText(bgX + bgW - 0.28, statusY, 0.012, "Double-click to edit | 1-9: Select")
end

---Draw toolbar buttons
---@param x number X position
---@param y number Y position
function WMManagerGUI:drawToolbar(x, y)
    local buttonW = 0.07
    local buttonH = 0.04
    local spacing = 0.01
    local currentX = x

    -- Clear button areas at start of draw
    self.buttonAreas = {}

    local buttons = {
        {text = g_i18n:getText("wm_button_new"), action = "new", color = {0.2, 0.6, 0.2, 1}},
        {text = g_i18n:getText("wm_button_edit"), action = "edit", color = {0.3, 0.5, 0.7, 1}},
        {text = g_i18n:getText("wm_button_delete"), action = "delete", color = {0.7, 0.3, 0.3, 1}},
        {text = g_i18n:getText("wm_button_start"), action = "start", color = {0.2, 0.7, 0.2, 1}},
        {text = g_i18n:getText("wm_button_stop"), action = "stop", color = {0.7, 0.2, 0.2, 1}},
        {text = g_i18n:getText("wm_button_pause"), action = "pause", color = {0.6, 0.6, 0.2, 1}},
    }

    for _, btn in ipairs(buttons) do
        -- Check if mouse is hovering
        local isHovered = self:isMouseInArea(currentX, y, buttonW, buttonH)

        -- Button background (brighter if hovered)
        local brightness = isHovered and 0.8 or 0.6
        setOverlayColor(self.overlayId, btn.color[1] * brightness, btn.color[2] * brightness, btn.color[3] * brightness, 0.9)
        renderOverlay(self.overlayId, currentX, y, buttonW, buttonH)

        -- Button text
        setTextColor(1, 1, 1, 1)
        local textX = currentX + buttonW * 0.5 - getTextWidth(0.014, btn.text) * 0.5
        renderText(textX, y + buttonH * 0.3, 0.014, btn.text)

        -- Store button area for click detection
        table.insert(self.buttonAreas, {
            x = currentX,
            y = y,
            w = buttonW,
            h = buttonH,
            action = btn.action
        })

        currentX = currentX + buttonW + spacing
    end
end

---Check if mouse is inside an area
---@param x number Area X
---@param y number Area Y
---@param w number Area width
---@param h number Area height
---@return boolean isInside
function WMManagerGUI:isMouseInArea(x, y, w, h)
    return self.mouseX >= x and self.mouseX <= x + w and
           self.mouseY >= y and self.mouseY <= y + h
end

---Draw a single workflow row
---@param baseX number Base X position
---@param y number Y position
---@param index number Row index
---@param workflow table Workflow data
function WMManagerGUI:drawWorkflowRow(baseX, y, index, workflow)
    local isSelected = (index == self.selectedWorkflowIndex)
    local rowHeight = 0.04

    -- Row background (all rows get a background for visual separation)
    if isSelected then
        setOverlayColor(self.overlayId, 0.2, 0.4, 0.6, 0.7)
    elseif index % 2 == 0 then
        -- Even rows: lighter background
        setOverlayColor(self.overlayId, 0.12, 0.12, 0.15, 0.9)
    else
        -- Odd rows: darker background
        setOverlayColor(self.overlayId, 0.08, 0.08, 0.10, 0.9)
    end
    renderOverlay(self.overlayId, baseX + 0.01, y - rowHeight + 0.01, 0.48, rowHeight)

    -- Row separator line at bottom
    setOverlayColor(self.overlayId, 0.3, 0.3, 0.35, 0.4)
    renderOverlay(self.overlayId, baseX + 0.02, y - rowHeight + 0.01, 0.46, 0.001)

    -- Row color based on runtime status (vehicle-aware)
    local vehicle = g_currentMission and g_currentMission.controlledVehicle
    if vehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
        vehicle = g_localPlayer:getCurrentVehicle()
    end
    local rowActiveData = vehicle and WorkflowManager:getVehicleWorkflowState(vehicle)
    local rowIsThis = rowActiveData and rowActiveData.workflow.id == workflow.id
    local rowStatus = rowIsThis and rowActiveData.status or WorkflowManager.STATUS_READY

    local textColor = {1, 1, 1, 1}
    if rowStatus == WorkflowManager.STATUS_RUNNING then
        textColor = {0.3, 0.9, 0.3, 1}
    elseif rowStatus == WorkflowManager.STATUS_PAUSED then
        textColor = {0.9, 0.9, 0.3, 1}
    elseif rowStatus == WorkflowManager.STATUS_ERROR then
        textColor = {0.9, 0.3, 0.3, 1}
    elseif rowStatus == WorkflowManager.STATUS_COMPLETED then
        textColor = {0.5, 0.7, 0.9, 1}
    end

    setTextColor(textColor[1], textColor[2], textColor[3], textColor[4])

    -- Draw workflow data
    -- Milestone 4: Vehicle column removed
    local textY = y - 0.01

    -- Index + Name (wider now without vehicle column)
    local displayName = string.format("%d. %s", index, workflow.name or g_i18n:getText("wm_unnamed"))
    if string.len(displayName) > 30 then
        displayName = string.sub(displayName, 1, 28) .. ".."
    end
    renderText(baseX + 0.02, textY, 0.015, displayName)

    -- Steps count
    renderText(baseX + 0.28, textY, 0.015, tostring(#workflow.steps))

    -- Status
    local statusText = self:getStatusText(workflow)
    renderText(baseX + 0.36, textY, 0.015, statusText)
end

---Update function
---@param dt number Delta time
function WMManagerGUI:update(dt)
    if not self.isVisible then
        return
    end

    -- Update mouse position
    self:updateMousePosition()

    -- Handle keyboard input for workflow selection
    self:handleInput()
end

---Update mouse position from input
function WMManagerGUI:updateMousePosition()
    -- Get normalized mouse position (0-1 range)
    if g_inputBinding ~= nil then
        local mouseX, mouseY = g_inputBinding:getMousePosition()
        if mouseX ~= nil and mouseY ~= nil then
            self.mouseX = mouseX
            self.mouseY = mouseY
        end
    end
end

---Handle mouse click on GUI elements
---@param posX number Mouse X position (0-1)
---@param posY number Mouse Y position (0-1)
---@param isDown boolean Is mouse button down
---@param isUp boolean Is mouse button up
---@param button number Mouse button (1=left)
function WMManagerGUI:onMouseEvent(posX, posY, isDown, isUp, button)
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

---Handle mouse click at position
---@param x number Mouse X
---@param y number Mouse Y
function WMManagerGUI:handleMouseClick(x, y)
    -- Check toolbar buttons
    for _, btn in ipairs(self.buttonAreas) do
        if self:isMouseInArea(btn.x, btn.y, btn.w, btn.h) then
            WMLogger:debug("Button clicked: %s", btn.action)
            self:executeButtonAction(btn.action)
            return
        end
    end

    -- Check workflow list clicks
    self:handleListClick(x, y)
end

---Execute a button action
---@param action string Button action name
function WMManagerGUI:executeButtonAction(action)
    if action == "new" then
        self:onClickNew()
    elseif action == "edit" then
        self:onClickEdit()
    elseif action == "delete" then
        self:onClickDelete()
    elseif action == "start" then
        self:onClickStart()
    elseif action == "stop" then
        self:onClickStop()
    elseif action == "pause" then
        self:onClickPause()
    end
end

---Handle click on workflow list
---@param x number Mouse X
---@param y number Mouse Y
function WMManagerGUI:handleListClick(x, y)
    -- GUI dimensions matching draw()
    local bgX, bgY = 0.25, 0.12
    local bgW, bgH = 0.5, 0.76
    local toolbarY = bgY + bgH - 0.13
    local headerY = toolbarY - 0.05
    local listStartY = headerY - 0.04
    local rowHeight = 0.045

    -- Check if click is in list area
    if x >= bgX + 0.01 and x <= bgX + bgW - 0.01 then
        local workflows = WorkflowManager:getAllWorkflows()
        for i = 1, math.min(#workflows, 12) do
            local rowY = listStartY - (i - 1) * rowHeight
            if y >= rowY - rowHeight + 0.01 and y <= rowY + 0.01 then
                -- Get current time in milliseconds
                local currentTime = g_currentMission ~= nil and g_currentMission.time or 0

                -- Check for double-click on the same row
                if self.lastClickIndex == i and (currentTime - self.lastClickTime) < self.DOUBLE_CLICK_THRESHOLD then
                    -- Double-click detected - open editor
                    WMLogger:debug("Double-click on workflow %d - opening editor", i)
                    self:onWorkflowSelected(i)
                    self:onClickEdit()
                    -- Reset double-click tracking
                    self.lastClickTime = 0
                    self.lastClickIndex = 0
                else
                    -- Single click - just select
                    self:onWorkflowSelected(i)
                    self.lastClickTime = currentTime
                    self.lastClickIndex = i
                end
                return
            end
        end
    end

    -- Click outside list area - reset double-click tracking
    self.lastClickTime = 0
    self.lastClickIndex = 0
end

---Cleanup the GUI and release resources
function WMManagerGUI:cleanup()
    WMLogger:debug("WorkflowManagerGUI:cleanup() called")

    -- Don't manually delete overlays - the game's cleanup system handles this
    -- Just set to nil so we don't try to use them anymore
    self.overlayId = nil

    -- Reset state
    self.isVisible = false
    self.selectedWorkflowIndex = 0
    self.listData = {}
    self.buttonAreas = {}
    self.lastClickTime = 0
    self.lastClickIndex = 0
end

---Handle keyboard/mouse input
function WMManagerGUI:handleInput()
    -- Number keys 1-9 for quick selection
    for i = 1, 9 do
        if Input.isKeyPressed(Input["KEY_" .. tostring(i)]) then
            local workflows = WorkflowManager:getAllWorkflows()
            if i <= #workflows then
                self:onWorkflowSelected(i)
            end
        end
    end

    -- ESC to close
    if Input.isKeyPressed(Input.KEY_escape) then
        -- Check if editor is open first
        if WMEditorGUI.isVisible then
            WMEditorGUI:close()
        else
            self:hide()
        end
    end

    -- Enter to edit selected
    if Input.isKeyPressed(Input.KEY_return) then
        if self.selectedWorkflowIndex > 0 then
            self:onClickEdit()
        end
    end

    -- Delete key
    if Input.isKeyPressed(Input.KEY_delete) then
        if self.selectedWorkflowIndex > 0 then
            self:onClickDelete()
        end
    end

    -- Arrow keys for navigation
    if Input.isKeyPressed(Input.KEY_up) then
        local workflows = WorkflowManager:getAllWorkflows()
        if self.selectedWorkflowIndex > 1 then
            self:onWorkflowSelected(self.selectedWorkflowIndex - 1)
        elseif #workflows > 0 and self.selectedWorkflowIndex == 0 then
            self:onWorkflowSelected(#workflows)
        end
    end

    if Input.isKeyPressed(Input.KEY_down) then
        local workflows = WorkflowManager:getAllWorkflows()
        if self.selectedWorkflowIndex < #workflows then
            self:onWorkflowSelected(self.selectedWorkflowIndex + 1)
        elseif #workflows > 0 and self.selectedWorkflowIndex == 0 then
            self:onWorkflowSelected(1)
        end
    end

    -- N for new
    if Input.isKeyPressed(Input.KEY_n) then
        self:onClickNew()
    end

    -- S for start
    if Input.isKeyPressed(Input.KEY_s) then
        if self.selectedWorkflowIndex > 0 then
            self:onClickStart()
        end
    end

    -- P for pause/resume
    if Input.isKeyPressed(Input.KEY_p) then
        if self.selectedWorkflowIndex > 0 then
            self:onClickPause()
        end
    end

    -- X for stop
    if Input.isKeyPressed(Input.KEY_x) then
        if self.selectedWorkflowIndex > 0 then
            self:onClickStop()
        end
    end
end
