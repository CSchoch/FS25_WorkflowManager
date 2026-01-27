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

-- Position & size in normalized screen coordinates (set on first draw)
WMHud.x = nil
WMHud.y = nil
WMHud.w = nil
WMHud.h = nil

function WMHud:ensureOverlays()
    if self.bgOverlay ~= nil then
        return
    end

    -- Calculate position from pixel values
    local px, py = getNormalizedScreenValues(10, 300)
    local pw, ph = getNormalizedScreenValues(280, 150)

    self.x = px
    self.y = py
    self.w = pw
    self.h = ph

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

    WMLogger:info("WMHud overlays created: x=%.4f y=%.4f w=%.4f h=%.4f", self.x, self.y, self.w, self.h)
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
    -- Find any active workflow
    for _, data in pairs(WMExecutor.activeWorkflows) do
        return data.workflow, data
    end
    return nil, nil
end

function WMHud:update(dt)
    -- Nothing to do; draw reads live data
end

function WMHud:draw()
    if not self.isVisible then
        return
    end

    -- Lazy-create overlays on first draw (guarantees screen globals exist)
    self:ensureOverlays()

    -- Draw backgrounds
    self.bgOverlay:render()
    self.headerOverlay:render()

    local x = self.x
    local y = self.y
    local w = self.w
    local h = self.h
    local mx = self.marginX
    local my = self.marginY

    -- Get workflow data
    local workflow = self:getActiveWorkflow()

    -- === Header ===
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(x + mx, y + h - self.headerH + my, self.titleSize, "Workflow Manager")
    setTextBold(false)

    -- Close X
    setTextAlignment(RenderText.ALIGN_RIGHT)
    renderText(x + w - mx, y + h - self.headerH + my, self.titleSize, "X")
    setTextAlignment(RenderText.ALIGN_LEFT)

    -- === Content area ===
    local lineY = y + h - self.headerH - my - self.textSize

    -- Workflow name
    setTextColor(1, 1, 1, 1)
    local name = workflow and workflow.name or "No active workflow"
    renderText(x + mx, lineY, self.textSize, name)

    -- Step info
    lineY = lineY - self.textSize - my
    setTextColor(0.9, 0.9, 0.3, 1)
    if workflow and workflow.steps then
        local cs = workflow.currentStep or 1
        local ts = #workflow.steps
        local step = workflow.steps[cs]
        if step then
            local sType = step.type == WorkflowManager.STEP_AUTODRIVE and "AD" or "CP"
            renderText(x + mx, lineY, self.smallSize,
                string.format("Step %d/%d: %s - %s", cs, ts, sType, step.target or "?"))
        end
    end

    -- Vehicle state
    lineY = lineY - self.smallSize - my
    local _, activeData = self:getActiveWorkflow()
    if activeData and activeData.vehicle then
        local vehicle = activeData.vehicle
        local adRunning = ADIntegration:isRunning(vehicle)
        local cpRunning = CPIntegration:isRunning(vehicle)

        if cpRunning then
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
                    string.format("CP active (%.0f%%)", progress * 100))
            else
                renderText(x + mx, lineY, self.smallSize, "CP active")
            end
        elseif adRunning then
            setTextColor(0.4, 0.8, 1, 1)
            renderText(x + mx, lineY, self.smallSize, "AD active")
        elseif workflow and workflow.status == "paused" then
            setTextColor(1, 0.6, 0, 1)
            renderText(x + mx, lineY, self.smallSize, "Paused")
        else
            setTextColor(0.6, 0.6, 0.6, 1)
            renderText(x + mx, lineY, self.smallSize, "Idle")
        end
    elseif not workflow then
        setTextColor(0.6, 0.6, 0.6, 1)
        renderText(x + mx, lineY, self.smallSize, "No vehicle")
    end

    -- === Button row ===
    local btnY = y + my
    setTextColor(0.8, 0.8, 0.8, 1)
    local btnW, _ = getNormalizedScreenValues(52, 0)

    renderText(x + mx, btnY, self.smallSize, "[Prev]")
    renderText(x + mx + btnW, btnY, self.smallSize,
        workflow and workflow.status == "paused" and "[Resume]" or "[Pause]")
    renderText(x + mx + btnW * 2, btnY, self.smallSize, "[Stop]")
    renderText(x + mx + btnW * 3, btnY, self.smallSize, "[Next]")

    -- Reset
    setTextColor(1, 1, 1, 1)
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function WMHud:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isVisible or self.x == nil then
        return false
    end

    if isDown and button == Input.MOUSE_BUTTON_LEFT then
        return self:handleClick(posX, posY)
    end

    return false
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

    -- Button row (bottom strip)
    local btnY = y
    local btnStripH = (self.marginY or 0.006) + (self.smallSize or 0.010) + (self.marginY or 0.006)
    if posY >= btnY and posY <= btnY + btnStripH then
        local btnW, _ = getNormalizedScreenValues(52, 0)
        local bx = x + mx
        local relX = posX - bx

        if relX >= 0 and relX < btnW then
            self:onClickPrevious()
            return true
        elseif relX >= btnW and relX < btnW * 2 then
            self:onClickPauseResume()
            return true
        elseif relX >= btnW * 2 and relX < btnW * 3 then
            self:onClickStop()
            return true
        elseif relX >= btnW * 3 and relX < btnW * 4 then
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
    local workflow = self:getActiveWorkflow()
    if workflow == nil then return end

    if workflow.status == WorkflowManager.STATUS_RUNNING then
        WorkflowManager:pauseWorkflow(workflow.id)
        WMLogger:info("Workflow paused via HUD: %s", workflow.name)
    elseif workflow.status == WorkflowManager.STATUS_PAUSED then
        WorkflowManager:resumeWorkflow(workflow.id)
        WMLogger:info("Workflow resumed via HUD: %s", workflow.name)
    end
end

function WMHud:onClickStop()
    local workflow = self:getActiveWorkflow()
    if workflow == nil then return end

    WorkflowManager:stopWorkflow(workflow.id)
    WMLogger:info("Workflow stopped via HUD: %s", workflow.name)
    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(g_i18n:getText("wm_workflow_stopped") or "Workflow stopped: %s", workflow.name))
end

function WMHud:onClickPrevious()
    local workflow = self:getActiveWorkflow()
    if workflow == nil or workflow.currentStep <= 1 then return end

    WMLogger:info("Previous step via HUD: %s", workflow.name)
    WMExecutor:goToPreviousStep(workflow)
end

function WMHud:onClickNext()
    local workflow = self:getActiveWorkflow()
    if workflow == nil or workflow.currentStep >= #workflow.steps then return end

    WMLogger:info("Next step via HUD: %s", workflow.name)
    WMExecutor:goToNextStep(workflow)
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
end

WMLogger:info("WMHud module loaded")
