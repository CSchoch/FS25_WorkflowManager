--[[
    WorkflowManager - In-Vehicle HUD
    Displays workflow status and controls when a workflow is running
    Pure direct rendering (no HUDElement system)

    Author: WorkflowManager Team
]]

---@class WMHud
WMHud = {}

WMHud.isVisible = false
WMHud.vehicle = nil
WMHud.bgOverlay = nil
WMHud.headerOverlay = nil

-- Icon overlays
WMHud.iconOverlays = nil
WMHud.hoveredButton = nil

-- Auto-hide after workflow completion
WMHud.autoHideAt = nil             -- absolute g_currentMission.time when HUD should hide, nil = inactive

-- Drag state
WMHud.isDragging = false
WMHud.dragOffsetX = 0
WMHud.dragOffsetY = 0
WMHud.isHoveringHeader = false

-- Icon colors
WMHud.ICON_NORMAL = { 1, 1, 1, 0.9 }
WMHud.ICON_HOVER = { 0.165, 0.757, 0.929, 1 } -- Cyan/blue
WMHud.ICON_DISABLED = { 0.4, 0.4, 0.4, 0.5 }
WMHud.ICON_ACTIVE = { 0.3, 0.9, 0.3, 1 }    -- Green for active/resume


-- Position & size in normalized screen coordinates (set on first draw)
WMHud.x = nil
WMHud.y = nil
WMHud.w = nil
WMHud.h = nil

function WMHud:ensureOverlays()
    if self.bgOverlay ~= nil then
        return
    end

    -- Calculate size from pixel values
    local pw, ph = getNormalizedScreenValues(280, 140)
    self.w = pw
    self.h = ph

    -- Only set default position if not already loaded from save
    if self.x == nil or self.y == nil then
        local px, py = getNormalizedScreenValues(10, 300)
        self.x = px
        self.y = py
    end

    -- Main background
    self.bgOverlay = Overlay.new(g_baseUIFilename, self.x, self.y, self.w, self.h)
    self.bgOverlay:setUVs(g_colorBgUVs)
    self.bgOverlay:setColor(0, 0, 0, 0.75)

    -- Header background
    local _, headerH = getNormalizedScreenValues(0, 24)
    self.headerH = headerH
    self.headerOverlay = Overlay.new(g_baseUIFilename, self.x, self.y + self.h - headerH, self.w, headerH)
    self.headerOverlay:setUVs(g_colorBgUVs)
    self.headerOverlay:setColor(0.2, 0.4, 0.6, 0.9)

    -- Text sizes
    local _, ts14 = getNormalizedScreenValues(0, 14)
    local _, ts13 = getNormalizedScreenValues(0, 13)
    local _, ts12 = getNormalizedScreenValues(0, 12)
    self.titleSize = ts14
    self.textSize = ts13
    self.smallSize = ts12

    -- Margin
    local marginX, marginY = getNormalizedScreenValues(8, 6)
    self.marginX = marginX
    self.marginY = marginY

    -- Create icon overlays
    self:createIconOverlays()

    WMLogger:info("WMHud overlays created: x=%.4f y=%.4f w=%.4f h=%.4f", self.x, self.y, self.w, self.h)
end

function WMHud:createIconOverlays()
    local iconW, iconH = getNormalizedScreenValues(24, 24)

    -- Get mod directory for icon paths
    local modDir = WorkflowManager.modDirectory or g_currentModDirectory or ""

    local iconPrev = Utils.getFilename("textures/icon_prev.dds", modDir)
    local iconPause = Utils.getFilename("textures/icon_pause.dds", modDir)
    local iconPlay = Utils.getFilename("textures/icon_play.dds", modDir)
    local iconStop = Utils.getFilename("textures/icon_stop.dds", modDir)
    local iconNext = Utils.getFilename("textures/icon_next.dds", modDir)

    -- Button positioning
    local btnSpacing = getNormalizedScreenValues(8, 0)
    local btnY = self.y + self.marginY
    local startX = self.x + self.marginX

    self.iconOverlays = {}
    self.buttonBounds = {}

    -- Calculate button width including spacing
    local btnTotalW = iconW + btnSpacing

    -- Create overlays for each button
    -- Button 1: Previous
    local prevOverlay = Overlay.new(iconPrev, startX, btnY, iconW, iconH)
    prevOverlay:setColor(unpack(self.ICON_NORMAL))
    self.iconOverlays.prev = prevOverlay
    self.buttonBounds.prev = { x = startX, y = btnY, w = iconW, h = iconH }

    -- Button 2: Pause (will swap with Play based on state)
    local pauseX = startX + btnTotalW
    local pauseOverlay = Overlay.new(iconPause, pauseX, btnY, iconW, iconH)
    pauseOverlay:setColor(unpack(self.ICON_NORMAL))
    self.iconOverlays.pause = pauseOverlay

    local playOverlay = Overlay.new(iconPlay, pauseX, btnY, iconW, iconH)
    playOverlay:setColor(unpack(self.ICON_ACTIVE))
    self.iconOverlays.play = playOverlay
    self.buttonBounds.pauseResume = { x = pauseX, y = btnY, w = iconW, h = iconH }

    -- Button 3: Stop
    local stopX = startX + btnTotalW * 2
    local stopOverlay = Overlay.new(iconStop, stopX, btnY, iconW, iconH)
    stopOverlay:setColor(unpack(self.ICON_NORMAL))
    self.iconOverlays.stop = stopOverlay
    self.buttonBounds.stop = { x = stopX, y = btnY, w = iconW, h = iconH }

    -- Button 4: Next
    local nextX = startX + btnTotalW * 3
    local nextOverlay = Overlay.new(iconNext, nextX, btnY, iconW, iconH)
    nextOverlay:setColor(unpack(self.ICON_NORMAL))
    self.iconOverlays.next = nextOverlay
    self.buttonBounds.next = { x = nextX, y = btnY, w = iconW, h = iconH }

    -- Store icon dimensions for later use
    self.iconW = iconW
    self.iconH = iconH
    self.btnSpacing = btnSpacing

    WMLogger:info("WMHud icon overlays created")
end

function WMHud:updateOverlayPositions()
    if self.bgOverlay == nil then return end

    self.bgOverlay:setPosition(self.x, self.y)
    self.headerOverlay:setPosition(self.x, self.y + self.h - self.headerH)


    local btnY = self.y + self.marginY
    local startX = self.x + self.marginX
    local btnTotalW = self.iconW + self.btnSpacing

    self.iconOverlays.prev:setPosition(startX, btnY)
    self.buttonBounds.prev = { x = startX, y = btnY, w = self.iconW, h = self.iconH }

    local pauseX = startX + btnTotalW
    self.iconOverlays.pause:setPosition(pauseX, btnY)
    self.iconOverlays.play:setPosition(pauseX, btnY)
    self.buttonBounds.pauseResume = { x = pauseX, y = btnY, w = self.iconW, h = self.iconH }

    local stopX = startX + btnTotalW * 2
    self.iconOverlays.stop:setPosition(stopX, btnY)
    self.buttonBounds.stop = { x = stopX, y = btnY, w = self.iconW, h = self.iconH }

    local nextX = startX + btnTotalW * 3
    self.iconOverlays.next:setPosition(nextX, btnY)
    self.buttonBounds.next = { x = nextX, y = btnY, w = self.iconW, h = self.iconH }
end

function WMHud:init()
    -- Nothing needed at load time; overlays created lazily on first draw
    WMLogger:info("WMHud:init() - lazy init mode")
end

function WMHud:show(vehicle)
    self.vehicle = vehicle
    self.isVisible = true
    WMLogger:info("WMHud shown")
end

function WMHud:hide()
    self.isVisible = false
    WMLogger:debug("WMHud hidden")
end

function WMHud:toggle(vehicle)
    if self.isVisible then
        self:hide()
    else
        self:show(vehicle)
    end
end

function WMHud:getIsVisible()
    return self.isVisible
end

function WMHud:getActiveWorkflow()
    -- Find active workflow for the current controlled vehicle
    local controlledVehicle = g_currentMission.controlledVehicle

    -- Fallback: try g_localPlayer:getCurrentVehicle()
    if controlledVehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
        controlledVehicle = g_localPlayer:getCurrentVehicle()
    end

    -- Fallback: try g_currentMission.playerSystem
    if controlledVehicle == nil and g_currentMission.playerSystem then
        local player = g_currentMission.playerSystem:getLocalPlayer()
        if player and player.getCurrentVehicle then
            controlledVehicle = player:getCurrentVehicle()
        end
    end

    if controlledVehicle == nil then
        return nil, nil
    end

    -- Get root vehicle (in case we're in an implement or attached vehicle)
    local controlledRoot = controlledVehicle.rootVehicle or controlledVehicle

    for vehicle, _ in pairs(WMExecutor.activeVehicles) do
        local data = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
        if data ~= nil then
            local workflowVehicle = data.vehicle
            local workflowRoot = workflowVehicle and (workflowVehicle.rootVehicle or workflowVehicle)

            -- Compare both direct reference and root vehicle
            if workflowVehicle == controlledVehicle or
                workflowVehicle == controlledRoot or
                workflowRoot == controlledVehicle or
                workflowRoot == controlledRoot then
                return data.workflow, data
            end
        end
    end

    return nil, nil
end

function WMHud:update(dt)
    if not g_currentMission then return end

    local _, activeData = self:getActiveWorkflow()
    local hasWorkflow = activeData ~= nil

    if hasWorkflow then
        -- Workflow active on current vehicle: ensure HUD is visible, cancel any hide timer
        if not self.isVisible then
            local cv = g_currentMission.controlledVehicle
            if cv ~= nil then self:show(cv) end
        end
        self.autoHideAt = nil
    elseif self.isVisible then
        -- HUD visible but no active workflow: countdown then hide
        if self.autoHideAt == nil then
            self.autoHideAt = g_currentMission.time + 3000
        elseif g_currentMission.time >= self.autoHideAt then
            self.autoHideAt = nil
            self:hide()
        end
    else
        self.autoHideAt = nil
    end
end

function WMHud:draw()
    if not self.isVisible then
        return
    end
    -- Don't draw if player is not in a vehicle
    local controlledVehicle = g_currentMission.controlledVehicle
    if controlledVehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
        controlledVehicle = g_localPlayer:getCurrentVehicle()
    end
    if controlledVehicle == nil and g_currentMission.playerSystem then
        local player = g_currentMission.playerSystem:getLocalPlayer()
        if player and player.getCurrentVehicle then
            controlledVehicle = player:getCurrentVehicle()
        end
    end
    if controlledVehicle == nil then
        return
    end

    -- Lazy-create overlays on first draw (guarantees screen globals exist)
    self:ensureOverlays()

    -- Get workflow data early (used for header and all content)
    local workflow, activeData = self:getActiveWorkflow()


    -- Draw backgrounds
    self.bgOverlay:render()

    -- Header color changes on hover/drag to signal it's draggable
    if self.isDragging then
        self.headerOverlay:setColor(0.3, 0.55, 0.8, 0.95)   -- brighter while dragging
    elseif self.isHoveringHeader then
        self.headerOverlay:setColor(0.25, 0.48, 0.7, 0.95)  -- slightly lighter on hover
    else
        self.headerOverlay:setColor(0.2, 0.4, 0.6, 0.9)     -- normal
    end
    self.headerOverlay:render()

    local x = self.x
    local y = self.y
    local w = self.w
    local h = self.h
    local mx = self.marginX
    local my = self.marginY

    -- === Header: title ===
    local headerTitle = g_i18n:getText("wm_hud_title") or "WorkflowManager"

    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(x + mx, y + h - self.headerH + my, self.titleSize, headerTitle)
    setTextBold(false)

    -- Close X
    setTextAlignment(RenderText.ALIGN_RIGHT)
    renderText(x + w - mx, y + h - self.headerH + my, self.titleSize, "X")
    setTextAlignment(RenderText.ALIGN_LEFT)

    -- === Content area ===
    local lineY = y + h - self.headerH - my - self.textSize

    -- Workflow name; append compact support badge if support vehicles exist
    setTextColor(1, 1, 1, 1)
    local displayName = workflow and workflow.name or (g_i18n:getText("wm_hud_no_workflow") or "No workflow")
    if workflow and activeData and activeData.isMainVehicle ~= false then
        local supportList = WMExecutor:getSupportActiveDataListForWorkflow(workflow.id)
        if #supportList > 0 then
            local running, paused, waiting = 0, 0, 0
            for _, sd in ipairs(supportList) do
                if sd.status == WorkflowManager.STATUS_WAITING_FOR_LEADER then waiting = waiting + 1
                elseif sd.status == WorkflowManager.STATUS_RUNNING then running = running + 1
                elseif sd.status == WorkflowManager.STATUS_PAUSED then paused = paused + 1
                end
            end
            -- Append colored badge-style count (rendered as a second text segment)
            renderText(x + mx, lineY, self.textSize, displayName)
            -- Draw support count badge to the right of the name
            local nameW = getTextWidth(self.textSize, displayName)
            if waiting > 0 then
                setTextColor(1, 0.85, 0, 1)
            elseif running > 0 then
                setTextColor(0.3, 0.9, 0.3, 1)
            elseif paused > 0 then
                setTextColor(1, 0.6, 0, 1)
            else
                setTextColor(0.5, 0.5, 0.5, 1)
            end
            local badgeText = waiting > 0
                and string.format("[%dS·%dW]", #supportList, waiting)
                or  string.format("[%dS]", #supportList)
            renderText(x + mx + nameW + mx * 0.5, lineY, self.smallSize, badgeText)
            setTextColor(1, 1, 1, 1)
        else
            renderText(x + mx, lineY, self.textSize, displayName)
        end
    else
        renderText(x + mx, lineY, self.textSize, displayName)
    end

    -- Step info: full type names, em dash separator
    lineY = lineY - self.textSize - my
    setTextColor(0.9, 0.9, 0.3, 1)
    if workflow and activeData and workflow.steps then
        local ts = #workflow.steps
        if activeData.isMainVehicle == false then
            -- Support vehicle
            local mainData = WMExecutor:getMainActiveDataForWorkflow(workflow.id)
            local mainStep = mainData and workflow.steps[mainData.currentStep]
            local supSteps = mainStep and mainStep.support or {}
            local css = activeData.currentSupportStep or 1
            local tss = #supSteps
            local supStep = supSteps[css]
            if supStep then
                renderText(x + mx, lineY, self.smallSize,
                    string.format("[%s] Step %s.%d/%d: %s",
                        WorkflowManager:getStepTypeShortcut(supStep.type),
                        mainData and tostring(mainData.currentStep) or "?",
                        css, tss, supStep.target or "?"))
            end
        else
            -- Main vehicle
            local cs = activeData.currentStep or 1
            local step = workflow.steps[cs]
            if step then
                local desc = WorkflowManager:isMarkerStepType(step.type)
                    and WorkflowManager:getStepTypeLabel(step.type)
                    or (step.target or "?")
                renderText(x + mx, lineY, self.smallSize,
                    string.format("[%s] Step %d/%d: %s", WorkflowManager:getStepTypeShortcut(step.type), cs, ts, desc))
            end
        end
    end

    -- Vehicle state
    lineY = lineY - self.smallSize - my
    self.buttonBounds.leaderName = nil
    self.buttonBounds.mainName = nil
    self.nameClickVehicles = self.nameClickVehicles or {}
    self.nameClickVehicles.leaderName = nil
    self.nameClickVehicles.mainName = nil
    if activeData and activeData.vehicle then
        local vehicle = activeData.vehicle
        local adRunning = ADIntegration:isRunning(vehicle)
        local cpRunning = CPIntegration:isRunning(vehicle)

        if activeData.status == WorkflowManager.STATUS_WAITING_FOR_LEADER then
            setTextColor(1, 0.85, 0, 1)
            local prefixText = g_i18n:getText("wm_hud_waiting_for_leader")
            local leaderName = nil
            if activeData.leaderVehicle then
                local ok, name = pcall(function() return activeData.leaderVehicle:getName() end)
                if ok and name and name ~= "" then leaderName = name end
            end
            if leaderName then
                renderText(x + mx, lineY, self.smallSize, prefixText .. ": ")
                local prefixW = getTextWidth(self.smallSize, prefixText .. ": ")
                if self.hoveredButton == "leaderName" then
                    setTextColor(0.165, 0.757, 0.929, 1)
                else
                    setTextColor(1, 0.85, 0, 1)
                end
                renderText(x + mx + prefixW, lineY, self.smallSize, leaderName)
                local nameW = getTextWidth(self.smallSize, leaderName)
                self.buttonBounds.leaderName = { x = x + mx + prefixW, y = lineY, w = nameW, h = self.smallSize }
                self.nameClickVehicles.leaderName = activeData.leaderVehicle
            else
                renderText(x + mx, lineY, self.smallSize, prefixText)
            end
        elseif activeData.status == WorkflowManager.STATUS_WAITING_FOR_MAIN then
            setTextColor(1, 0.85, 0, 1)
            local prefixText = g_i18n:getText("wm_hud_waiting_for_main")
            local mainData = workflow and WMExecutor:getMainActiveDataForWorkflow(workflow.id)
            local mainVehicle = mainData and mainData.vehicle
            local mainName = nil
            if mainVehicle then
                local ok, name = pcall(function() return mainVehicle:getName() end)
                if ok and name and name ~= "" then mainName = name end
            end
            if mainName then
                renderText(x + mx, lineY, self.smallSize, prefixText .. ": ")
                local prefixW = getTextWidth(self.smallSize, prefixText .. ": ")
                if self.hoveredButton == "mainName" then
                    setTextColor(0.165, 0.757, 0.929, 1)
                else
                    setTextColor(1, 0.85, 0, 1)
                end
                renderText(x + mx + prefixW, lineY, self.smallSize, mainName)
                local nameW = getTextWidth(self.smallSize, mainName)
                self.buttonBounds.mainName = { x = x + mx + prefixW, y = lineY, w = nameW, h = self.smallSize }
                self.nameClickVehicles.mainName = mainVehicle
            else
                renderText(x + mx, lineY, self.smallSize, prefixText)
            end
        elseif cpRunning then
            local progress = nil
            if vehicle.getCpFieldWorkProgress then
                local ok, p = pcall(vehicle.getCpFieldWorkProgress, vehicle)
                if ok and type(p) == "number" then
                    progress = p
                end
            end
            setTextColor(0.4, 0.8, 1, 1)
            if progress then
                renderText(x + mx, lineY, self.smallSize,
                    string.format(g_i18n:getText("wm_hud_cp_active_progress"), progress * 100))
            else
                renderText(x + mx, lineY, self.smallSize, g_i18n:getText("wm_hud_cp_active"))
            end
        elseif adRunning then
            setTextColor(0.4, 0.8, 1, 1)
            renderText(x + mx, lineY, self.smallSize, g_i18n:getText("wm_hud_ad_active"))
        elseif activeData.status == WorkflowManager.STATUS_PAUSED then
            setTextColor(1, 0.6, 0, 1)
            renderText(x + mx, lineY, self.smallSize, g_i18n:getText("wm_hud_paused"))
        else
            setTextColor(0.6, 0.6, 0.6, 1)
            renderText(x + mx, lineY, self.smallSize, g_i18n:getText("wm_hud_idle"))
        end
    elseif not workflow then
        setTextColor(0.6, 0.6, 0.6, 1)
        renderText(x + mx, lineY, self.smallSize, g_i18n:getText("wm_hud_no_vehicle"))
    end

    -- === Button row (icons) ===
    self:drawIconButtons(activeData)

    -- === Tooltip for hovered button ===
    self:drawButtonTooltip(activeData)

    -- Reset
    setTextColor(1, 1, 1, 1)
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

---Draw a tooltip label above the currently hovered button
function WMHud:drawButtonTooltip(activeData)
    if self.hoveredButton == nil or self.buttonBounds == nil then return end

    local bounds = self.buttonBounds[self.hoveredButton]
    if bounds == nil then return end

    local isPaused = activeData and activeData.status == WorkflowManager.STATUS_PAUSED

    local tooltipText
    if self.hoveredButton == "prev" then
        tooltipText = g_i18n:getText("wm_hud_tooltip_prev") or "Previous Step"
    elseif self.hoveredButton == "pauseResume" then
        tooltipText = isPaused
            and (g_i18n:getText("wm_hud_tooltip_resume") or "Resume")
            or  (g_i18n:getText("wm_hud_tooltip_pause")  or "Pause")
    elseif self.hoveredButton == "stop" then
        tooltipText = g_i18n:getText("wm_hud_tooltip_stop") or "Stop"
    elseif self.hoveredButton == "next" then
        tooltipText = g_i18n:getText("wm_hud_tooltip_next") or "Next Step"
    elseif self.hoveredButton == "leaderName" or self.hoveredButton == "mainName" then
        tooltipText = g_i18n:getText("wm_hud_tooltip_switch_vehicle") or "Click to switch to this vehicle"
    end

    if not tooltipText then return end

    -- Render tooltip text centered above the button
    local tipY = bounds.y + bounds.h + self.marginY * 0.5
    local tipX = bounds.x + bounds.w * 0.5

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(0.9, 0.9, 0.9, 0.95)
    renderText(tipX, tipY, self.smallSize, tooltipText)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function WMHud:drawIconButtons(activeData)
    if not self.iconOverlays then
        return
    end

    local hasWorkflow = activeData ~= nil
    local isPaused = hasWorkflow and activeData.status == WorkflowManager.STATUS_PAUSED
    local currentStep = hasWorkflow and activeData.currentStep or 1
    local stepCount = hasWorkflow and activeData.workflow.steps and #activeData.workflow.steps or 0
    local canGoPrev = hasWorkflow and currentStep > 1
    local canGoNext = hasWorkflow and currentStep < stepCount

    -- Previous button
    local prevColor = self.ICON_DISABLED
    if canGoPrev then
        prevColor = self.hoveredButton == "prev" and self.ICON_HOVER or self.ICON_NORMAL
    end
    self.iconOverlays.prev:setColor(unpack(prevColor))
    self.iconOverlays.prev:render()

    -- Pause/Resume button (show play icon when paused, pause icon when running)
    if isPaused then
        local playColor = self.hoveredButton == "pauseResume" and self.ICON_HOVER or self.ICON_ACTIVE
        self.iconOverlays.play:setColor(unpack(playColor))
        self.iconOverlays.play:render()
    else
        local pauseColor = self.ICON_DISABLED
        if hasWorkflow and activeData.status == WorkflowManager.STATUS_RUNNING then
            pauseColor = self.hoveredButton == "pauseResume" and self.ICON_HOVER or self.ICON_NORMAL
        end
        self.iconOverlays.pause:setColor(unpack(pauseColor))
        self.iconOverlays.pause:render()
    end

    -- Stop button
    local stopColor = self.ICON_DISABLED
    if hasWorkflow then
        stopColor = self.hoveredButton == "stop" and self.ICON_HOVER or self.ICON_NORMAL
    end
    self.iconOverlays.stop:setColor(unpack(stopColor))
    self.iconOverlays.stop:render()

    -- Next button
    local nextColor = self.ICON_DISABLED
    if canGoNext then
        nextColor = self.hoveredButton == "next" and self.ICON_HOVER or self.ICON_NORMAL
    end
    self.iconOverlays.next:setColor(unpack(nextColor))
    self.iconOverlays.next:render()
end

function WMHud:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isVisible or self.x == nil or self.h == nil then
        return false
    end

    -- Stop drag on left mouse up
    if isUp and button == Input.MOUSE_BUTTON_LEFT and self.isDragging then
        self.isDragging = false
        WorkflowManager:saveWorkflows()  -- persist new position
        return true
    end

    -- Handle mouse down
    if isDown and button == Input.MOUSE_BUTTON_LEFT then
        local isInHeader = posY >= self.y + self.h - self.headerH and
                           posX >= self.x and posX <= self.x + self.w and
                           posY <= self.y + self.h
        local isCloseBtn = isInHeader and posX > self.x + self.w - (self.marginX or 0.008) * 4

        -- Start drag when clicking header (but not close button)
        if isInHeader and not isCloseBtn then
            self.isDragging = true
            self.dragOffsetX = posX - self.x
            self.dragOffsetY = posY - self.y
            return true
        end

        -- Regular click (handles close button, icon buttons)
        return self:handleClick(posX, posY)
    end

    -- Mouse move: update drag position
    if self.isDragging then
        self.x = math.max(0, math.min(1 - self.w, posX - self.dragOffsetX))
        self.y = math.max(0, math.min(1 - self.h, posY - self.dragOffsetY))
        self:updateOverlayPositions()
        return true
    end

    -- Update hover state (header + buttons)
    self:updateHoverState(posX, posY)
    return false
end

function WMHud:updateHoverState(posX, posY)
    self.hoveredButton = nil

    if self.h == nil or self.headerH == nil then
        return
    end

    -- Track header hover for visual drag indicator
    local isInHeader = posY >= self.y + self.h - self.headerH and
                       posX >= self.x and posX <= self.x + self.w
    local isCloseBtn = isInHeader and posX > self.x + self.w - (self.marginX or 0.008) * 4
    self.isHoveringHeader = isInHeader and not isCloseBtn

    if not self.buttonBounds then
        return
    end

    -- Check each button for hover
    for btnName, bounds in pairs(self.buttonBounds) do
        if posX >= bounds.x and posX <= bounds.x + bounds.w and
            posY >= bounds.y and posY <= bounds.y + bounds.h then
            self.hoveredButton = btnName
            return
        end
    end
end

function WMHud:handleClick(posX, posY)
    local x = self.x
    local y = self.y
    local w = self.w
    local h = self.h
    local mx = self.marginX or 0.008

    -- Outside HUD?
    if posX < x or posX > x + w or posY < y or posY > y + h then
        return false
    end

    -- Close button (top-right corner of header)
    if posX > x + w - mx * 4 and posY > y + h - self.headerH then
        self:hide()
        return true
    end

    -- Leader/main vehicle name click (jump to that vehicle)
    if self.buttonBounds and self.nameClickVehicles then
        local leaderNameBounds = self.buttonBounds.leaderName
        if leaderNameBounds and self.nameClickVehicles.leaderName and
            posX >= leaderNameBounds.x and posX <= leaderNameBounds.x + leaderNameBounds.w and
            posY >= leaderNameBounds.y and posY <= leaderNameBounds.y + leaderNameBounds.h then
            self:onClickVehicleName(self.nameClickVehicles.leaderName)
            return true
        end

        local mainNameBounds = self.buttonBounds.mainName
        if mainNameBounds and self.nameClickVehicles.mainName and
            posX >= mainNameBounds.x and posX <= mainNameBounds.x + mainNameBounds.w and
            posY >= mainNameBounds.y and posY <= mainNameBounds.y + mainNameBounds.h then
            self:onClickVehicleName(self.nameClickVehicles.mainName)
            return true
        end
    end

    -- Check icon button clicks
    if self.buttonBounds then
        local _, activeData = self:getActiveWorkflow()
        local hasWorkflow = activeData ~= nil
        local currentStep = hasWorkflow and activeData.currentStep or 1
        local stepCount = hasWorkflow and activeData.workflow.steps and #activeData.workflow.steps or 0
        local canGoPrev = hasWorkflow and currentStep > 1
        local canGoNext = hasWorkflow and currentStep < stepCount

        -- Previous button
        local prevBounds = self.buttonBounds.prev
        if prevBounds and canGoPrev and
            posX >= prevBounds.x and posX <= prevBounds.x + prevBounds.w and
            posY >= prevBounds.y and posY <= prevBounds.y + prevBounds.h then
            self:onClickPrevious()
            return true
        end

        -- Pause/Resume button
        local pauseBounds = self.buttonBounds.pauseResume
        if pauseBounds and hasWorkflow and
            posX >= pauseBounds.x and posX <= pauseBounds.x + pauseBounds.w and
            posY >= pauseBounds.y and posY <= pauseBounds.y + pauseBounds.h then
            self:onClickPauseResume()
            return true
        end

        -- Stop button
        local stopBounds = self.buttonBounds.stop
        if stopBounds and hasWorkflow and
            posX >= stopBounds.x and posX <= stopBounds.x + stopBounds.w and
            posY >= stopBounds.y and posY <= stopBounds.y + stopBounds.h then
            self:onClickStop()
            return true
        end

        -- Next button
        local nextBounds = self.buttonBounds.next
        if nextBounds and canGoNext and
            posX >= nextBounds.x and posX <= nextBounds.x + nextBounds.w and
            posY >= nextBounds.y and posY <= nextBounds.y + nextBounds.h then
            self:onClickNext()
            return true
        end
    end

    return true -- consumed (inside HUD)
end

function WMHud:isMouseOverArea(posX, posY)
    if not self.isVisible or self.x == nil then
        return false
    end
    return posX >= self.x and posX <= self.x + self.w and posY >= self.y and posY <= self.y + self.h
end

-- === Button callbacks ===

function WMHud:onClickPauseResume()
    local workflow, activeData = self:getActiveWorkflow()
    if activeData == nil then return end

    if activeData.status == WorkflowManager.STATUS_RUNNING then
        WorkflowManager:sendCommand(activeData.vehicle, "pause")
        WMLogger:info("Workflow paused via HUD: %s", workflow.name)
    elseif activeData.status == WorkflowManager.STATUS_PAUSED then
        WorkflowManager:sendCommand(activeData.vehicle, "resume")
        WMLogger:info("Workflow resumed via HUD: %s", workflow.name)
    end
end

---Switch player control to the given vehicle (clicking a leader/main vehicle name in the HUD)
function WMHud:onClickVehicleName(vehicle)
    if vehicle == nil or g_localPlayer == nil or g_localPlayer.requestToEnterVehicle == nil then return end
    g_localPlayer:requestToEnterVehicle(vehicle)
end

function WMHud:onClickStop()
    local workflow, activeData = self:getActiveWorkflow()
    if activeData == nil then return end

    WorkflowManager:sendCommand(activeData.vehicle, "stop")
    WMLogger:info("Workflow stopped via HUD: %s", workflow.name)
    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(g_i18n:getText("wm_workflow_stopped") or "Workflow stopped: %s", workflow.name))
end

function WMHud:onClickPrevious()
    local _, activeData = self:getActiveWorkflow()
    if activeData == nil or activeData.currentStep <= 1 then return end

    WMLogger:info("Previous step via HUD: %s", activeData.workflow.name)
    WorkflowManager:goToPreviousStep(activeData.vehicle)
end

function WMHud:onClickNext()
    local _, activeData = self:getActiveWorkflow()
    if activeData == nil or activeData.currentStep >= #activeData.workflow.steps then return end

    WMLogger:info("Next step via HUD: %s", activeData.workflow.name)
    WorkflowManager:goToNextStep(activeData.vehicle)
end

function WMHud:delete()
    if self.bgOverlay then
        self.bgOverlay:delete()
        self.bgOverlay = nil
    end
    if self.headerOverlay then
        self.headerOverlay:delete()
        self.headerOverlay = nil
    end
    -- Delete icon overlays
    if self.iconOverlays then
        for _, overlay in pairs(self.iconOverlays) do
            if overlay and overlay.delete then
                overlay:delete()
            end
        end
        self.iconOverlays = nil
    end
    self.buttonBounds = nil
    self.hoveredButton = nil
end

WMLogger:info("WMHud module loaded")
