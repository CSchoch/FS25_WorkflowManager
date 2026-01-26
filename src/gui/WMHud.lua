--[[
    WorkflowManager - In-Vehicle HUD
    Displays workflow status and controls when a workflow is running
    Mouse-controlled interface similar to Courseplay's HUD

    Author: WorkflowManager Team
]]

---@class WMHud
WMHud = {}

-- Colors
WMHud.BACKGROUND_COLOR = {0, 0, 0, 0.75}
WMHud.HEADER_COLOR = {0.2, 0.4, 0.6, 0.9}
WMHud.TEXT_COLOR = {1, 1, 1, 1}
WMHud.STEP_COLOR = {0.8, 0.8, 0.2, 1}
WMHud.PAUSED_COLOR = {1, 0.6, 0, 1}
WMHud.RUNNING_COLOR = {0, 0.8, 0, 1}

-- Base size in pixels (will be scaled)
WMHud.basePosition = {x = 10, y = 300}
WMHud.baseSize = {x = 280, y = 120}

WMHud.headerFontSize = 12
WMHud.titleFontSize = 14
WMHud.defaultFontSize = 12
WMHud.smallFontSize = 10

-- State
WMHud.isInitialized = false
WMHud.isVisible = false
WMHud.vehicle = nil

function WMHud:init()
    if self.isInitialized then
        return
    end

    self.uiScale = g_gameSettings:getValue("uiScale") or 1

    -- Convert pixel positions to normalized screen coordinates
    self.x, self.y = getNormalizedScreenValues(self.basePosition.x, self.basePosition.y)
    self.width, self.height = getNormalizedScreenValues(self.baseSize.x, self.baseSize.y)

    -- Calculate element sizes
    self.lineHeight = self.height / 5
    self.margin = self.lineHeight / 3
    self.buttonSize, _ = getNormalizedScreenValues(24, 24)

    -- Create background overlay
    local bgOverlay = Overlay.new(g_baseUIFilename, self.x, self.y, self.width, self.height)
    bgOverlay:setUVs(g_colorBgUVs)
    bgOverlay:setColor(unpack(self.BACKGROUND_COLOR))

    self.baseHud = WMHudElement.new(bgOverlay, nil)
    self.baseHud:setPosition(self.x, self.y)
    self.baseHud:setDimension(self.width, self.height)

    -- Create header background
    local headerHeight = self.lineHeight
    local headerOverlay = Overlay.new(g_baseUIFilename, self.x, self.y + self.height - headerHeight, self.width, headerHeight)
    headerOverlay:setUVs(g_colorBgUVs)
    headerOverlay:setColor(unpack(self.HEADER_COLOR))

    self.headerBg = WMHudElement.new(headerOverlay, self.baseHud)
    self.headerBg:setPosition(self.x, self.y + self.height - headerHeight)
    self.headerBg:setDimension(self.width, headerHeight)

    -- Create header title text
    local titleX = self.x + self.margin
    local titleY = self.y + self.height - headerHeight + self.margin / 2
    self.titleText = WMHudTextElement.new(self.baseHud, titleX, titleY, self.titleFontSize, RenderText.ALIGN_LEFT, self.TEXT_COLOR)
    self.titleText:setText("Workflow Manager")

    -- Create close button (X) in header
    local closeBtnSize, _ = getNormalizedScreenValues(16, 16)
    local closeBtnX = self.x + self.width - closeBtnSize - self.margin / 2
    local closeBtnY = self.y + self.height - headerHeight + (headerHeight - closeBtnSize) / 2
    self.closeBtn = self:createTextButton(closeBtnX, closeBtnY, "X", self.headerFontSize)
    self.closeBtn:setCallback("onClickPrimary", self, function(self)
        self:hide()
    end)

    -- Create workflow name display (line 1)
    local line1Y = self.y + self.height - headerHeight - self.lineHeight
    self.workflowNameText = WMHudTextElement.new(self.baseHud, self.x + self.margin, line1Y, self.defaultFontSize, RenderText.ALIGN_LEFT, self.TEXT_COLOR)
    self.workflowNameText:setText("No active workflow")

    -- Create step display (line 2)
    local line2Y = line1Y - self.lineHeight
    self.stepText = WMHudTextElement.new(self.baseHud, self.x + self.margin, line2Y, self.smallFontSize, RenderText.ALIGN_LEFT, self.STEP_COLOR)
    self.stepText:setText("")

    -- Create status display (line 3)
    local line3Y = line2Y - self.lineHeight * 0.7
    self.statusText = WMHudTextElement.new(self.baseHud, self.x + self.margin, line3Y, self.smallFontSize, RenderText.ALIGN_LEFT, self.RUNNING_COLOR)
    self.statusText:setText("")

    -- Create control buttons (bottom row)
    local btnY = self.y + self.margin
    local btnSpacing, _ = getNormalizedScreenValues(8, 0)
    local btnWidth, btnHeight = getNormalizedScreenValues(50, 20)
    local currentX = self.x + self.margin

    -- Previous button
    self.prevBtn = self:createTextButton(currentX, btnY, "< Prev", self.smallFontSize, btnWidth)
    self.prevBtn:setCallback("onClickPrimary", self, self.onClickPrevious)
    currentX = currentX + btnWidth + btnSpacing

    -- Pause/Resume button
    self.pauseBtn = self:createTextButton(currentX, btnY, "Pause", self.smallFontSize, btnWidth)
    self.pauseBtn:setCallback("onClickPrimary", self, self.onClickPauseResume)
    currentX = currentX + btnWidth + btnSpacing

    -- Stop button
    self.stopBtn = self:createTextButton(currentX, btnY, "Stop", self.smallFontSize, btnWidth)
    self.stopBtn:setCallback("onClickPrimary", self, self.onClickStop)
    currentX = currentX + btnWidth + btnSpacing

    -- Next button
    self.nextBtn = self:createTextButton(currentX, btnY, "Next >", self.smallFontSize, btnWidth)
    self.nextBtn:setCallback("onClickPrimary", self, self.onClickNext)

    -- Initially hidden
    self.baseHud:setVisible(false)
    self.isInitialized = true

    WMLogger:info("WMHud initialized")
end

function WMHud:createTextButton(x, y, text, fontSize, width)
    local btn = WMHudTextElement.new(self.baseHud, x, y, fontSize or self.smallFontSize, RenderText.ALIGN_LEFT, self.TEXT_COLOR)
    btn:setText(text, width)
    return btn
end

function WMHud:show(vehicle)
    if not self.isInitialized then
        self:init()
    end

    self.vehicle = vehicle
    self.isVisible = true
    self.baseHud:setVisible(true)
    WMLogger:debug("WMHud shown for vehicle")
end

function WMHud:hide()
    self.isVisible = false
    self.baseHud:setVisible(false)
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

function WMHud:getActiveWorkflowForVehicle(vehicle)
    if vehicle == nil then
        return nil, nil
    end

    -- Find active workflow for this vehicle
    for workflowId, activeData in pairs(WMExecutor.activeWorkflows) do
        if activeData.vehicle == vehicle then
            return activeData.workflow, activeData
        end
    end

    return nil, nil
end

function WMHud:update(dt)
    if not self.isInitialized or not self.isVisible then
        return
    end

    -- Get current vehicle
    local vehicle = g_currentMission.controlledVehicle
    if vehicle == nil then
        self:hide()
        return
    end

    -- Check if there's an active workflow for this vehicle
    local workflow, activeData = self:getActiveWorkflowForVehicle(vehicle)

    if workflow == nil then
        -- No active workflow - show minimal info
        self.workflowNameText:setText(g_i18n:getText("wm_hud_no_workflow") or "No active workflow")
        self.stepText:setText("")
        self.statusText:setText("")
        self:updateButtonStates(nil)
        return
    end

    -- Update workflow name
    self.workflowNameText:setText(workflow.name or "Unnamed Workflow")

    -- Update step info
    local currentStep = workflow.currentStep or 1
    local totalSteps = #workflow.steps
    local step = workflow.steps[currentStep]
    local stepInfo = ""

    if step then
        local stepType = step.type == WorkflowManager.STEP_AUTODRIVE and "AD" or "CP"
        local target = step.target or "?"
        stepInfo = string.format(g_i18n:getText("wm_hud_step_format") or "Step %d/%d: %s - %s",
            currentStep, totalSteps, stepType, target)
    end
    self.stepText:setText(stepInfo)

    -- Update status
    local status = workflow.status or WorkflowManager.STATUS_READY
    local statusText = ""
    local statusColor = self.RUNNING_COLOR

    if status == WorkflowManager.STATUS_RUNNING then
        statusText = g_i18n:getText("wm_status_running") or "Running"
        statusColor = self.RUNNING_COLOR
    elseif status == WorkflowManager.STATUS_PAUSED then
        statusText = g_i18n:getText("wm_status_paused") or "Paused"
        statusColor = self.PAUSED_COLOR
    elseif status == WorkflowManager.STATUS_COMPLETED then
        statusText = g_i18n:getText("wm_status_completed") or "Completed"
        statusColor = self.TEXT_COLOR
    elseif status == WorkflowManager.STATUS_ERROR then
        statusText = g_i18n:getText("wm_status_error") or "Error"
        statusColor = {1, 0.2, 0.2, 1}
    end

    self.statusText:setText(statusText)
    self.statusText.textColor = statusColor

    -- Update button states
    self:updateButtonStates(workflow)
end

function WMHud:updateButtonStates(workflow)
    if workflow == nil then
        self.prevBtn:setDisabled(true)
        self.pauseBtn:setDisabled(true)
        self.stopBtn:setDisabled(true)
        self.nextBtn:setDisabled(true)
        return
    end

    local isRunning = workflow.status == WorkflowManager.STATUS_RUNNING
    local isPaused = workflow.status == WorkflowManager.STATUS_PAUSED
    local isActive = isRunning or isPaused

    -- Previous: enabled if not on first step and workflow is active
    local canGoPrev = isActive and workflow.currentStep > 1
    self.prevBtn:setDisabled(not canGoPrev)

    -- Next: enabled if not on last step and workflow is active
    local canGoNext = isActive and workflow.currentStep < #workflow.steps
    self.nextBtn:setDisabled(not canGoNext)

    -- Pause/Resume: enabled when workflow is active
    self.pauseBtn:setDisabled(not isActive)
    if isPaused then
        self.pauseBtn:setText("Resume")
    else
        self.pauseBtn:setText("Pause")
    end

    -- Stop: enabled when workflow is active
    self.stopBtn:setDisabled(not isActive)
end

function WMHud:onClickPauseResume()
    local vehicle = g_currentMission.controlledVehicle
    local workflow, _ = self:getActiveWorkflowForVehicle(vehicle)

    if workflow == nil then
        return
    end

    if workflow.status == WorkflowManager.STATUS_RUNNING then
        WorkflowManager:pauseWorkflow(workflow.id)
        WMLogger:info("Workflow paused via HUD: %s", workflow.name)
    elseif workflow.status == WorkflowManager.STATUS_PAUSED then
        WorkflowManager:resumeWorkflow(workflow.id)
        WMLogger:info("Workflow resumed via HUD: %s", workflow.name)
    end
end

function WMHud:onClickStop()
    local vehicle = g_currentMission.controlledVehicle
    local workflow, _ = self:getActiveWorkflowForVehicle(vehicle)

    if workflow == nil then
        return
    end

    WorkflowManager:stopWorkflow(workflow.id)
    WMLogger:info("Workflow stopped via HUD: %s", workflow.name)

    -- Show notification
    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format(g_i18n:getText("wm_workflow_stopped") or "Workflow stopped: %s", workflow.name)
    )
end

function WMHud:onClickPrevious()
    local vehicle = g_currentMission.controlledVehicle
    local workflow, activeData = self:getActiveWorkflowForVehicle(vehicle)

    if workflow == nil or workflow.currentStep <= 1 then
        return
    end

    WMLogger:info("Previous step requested via HUD for workflow: %s", workflow.name)
    WMExecutor:goToPreviousStep(workflow)
end

function WMHud:onClickNext()
    local vehicle = g_currentMission.controlledVehicle
    local workflow, activeData = self:getActiveWorkflowForVehicle(vehicle)

    if workflow == nil or workflow.currentStep >= #workflow.steps then
        return
    end

    WMLogger:info("Next step requested via HUD for workflow: %s", workflow.name)
    WMExecutor:goToNextStep(workflow)
end

function WMHud:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isInitialized or not self.isVisible then
        return false
    end

    if self.baseHud:getIsDisabled() then
        return false
    end

    return self.baseHud:mouseEvent(posX, posY, isDown, isUp, button)
end

function WMHud:isMouseOverArea(posX, posY)
    if not self.isInitialized or not self.isVisible then
        return false
    end

    return self.baseHud:isMouseOverArea(posX, posY)
end

function WMHud:draw()
    if not self.isInitialized or not self.isVisible then
        return
    end

    self.baseHud:draw()
end

function WMHud:delete()
    if self.baseHud then
        self.baseHud:delete()
        self.baseHud = nil
    end
    self.isInitialized = false
end

WMLogger:info("WMHud module loaded")
