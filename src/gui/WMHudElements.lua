--[[
    WorkflowManager - HUD Elements
    Basic HUD elements for the in-vehicle workflow control display
    Based on Courseplay's HUD element pattern

    Author: WorkflowManager Team
]]

---@class WMHudElement
WMHudElement = {}
local WMHudElement_mt = Class(WMHudElement, HUDElement)

function WMHudElement.new(overlay, parentHudElement, customMt)
    if customMt == nil then
        customMt = WMHudElement_mt
    end

    if overlay == nil then
        overlay = Overlay.new(nil, 0, 0, 0, 0)
        overlay:setColor(1, 1, 1, 1)
    end

    local self = HUDElement.new(overlay, parentHudElement, customMt)
    self.callbacks = {}
    self.visible = true
    self.disabled = false
    self.hovered = false
    return self
end

function WMHudElement:mouseEvent(posX, posY, isDown, isUp, button, wasUsed)
    if wasUsed == nil then
        wasUsed = false
    end

    if self.visible and not self.disabled and self:isMouseOverArea(posX, posY) then
        self:setHovered(true)
    else
        self:setHovered(false)
    end

    for _, child in ipairs(self.children) do
        if child.mouseEvent and child:mouseEvent(posX, posY, isDown, isUp, button, wasUsed) then
            wasUsed = true
        end
    end
    return wasUsed
end

function WMHudElement:setHovered(hovered)
    self.hovered = hovered
end

function WMHudElement:getIsHovered()
    return self.hovered
end

function WMHudElement:isMouseOverArea(posX, posY)
    local x = self.overlay.x
    local y = self.overlay.y
    local width = self.overlay.width
    local height = self.overlay.height
    local offsetX, offsetY = self.overlay.offsetX or 0, self.overlay.offsetY or 0
    return GuiUtils.checkOverlayOverlap(posX, posY, x + offsetX, y + offsetY, width, height)
end

function WMHudElement:setCallback(callbackStr, class, func)
    self.callbacks[callbackStr] = {
        class = class,
        func = func
    }
end

function WMHudElement:raiseCallback(callbackStr, args)
    if self.callbacks[callbackStr] then
        local func = self.callbacks[callbackStr].func
        local class = self.callbacks[callbackStr].class
        if args ~= nil then
            func(class, self, unpack(args))
        else
            func(class, self)
        end
    end
end

function WMHudElement:setVisible(visible)
    WMHudElement:superClass().setVisible(self, visible)
    self.visible = visible
    for _, child in pairs(self.children) do
        if child.setVisible then
            child:setVisible(visible)
        end
    end
end

function WMHudElement:setDisabled(disabled)
    self.disabled = disabled
    for _, child in pairs(self.children) do
        if child.setDisabled then
            child:setDisabled(disabled)
        end
    end
end

function WMHudElement:getIsDisabled()
    return self.disabled
end

---@class WMHudButtonElement : WMHudElement
WMHudButtonElement = {}
local WMHudButtonElement_mt = Class(WMHudButtonElement, WMHudElement)

function WMHudButtonElement.new(overlay, parentHudElement, customMt)
    if customMt == nil then
        customMt = WMHudButtonElement_mt
    end
    local self = WMHudElement.new(overlay, parentHudElement, customMt)
    return self
end

function WMHudButtonElement:mouseEvent(posX, posY, isDown, isUp, button, wasUsed)
    if self.visible and not self.disabled and self:isMouseOverArea(posX, posY) then
        self:setHovered(true)
        if button == Input.MOUSE_BUTTON_LEFT and isDown then
            self:onClickPrimary(posX, posY)
            wasUsed = true
        end
    else
        self:setHovered(false)
    end

    return WMHudButtonElement:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, wasUsed)
end

function WMHudButtonElement:onClickPrimary(posX, posY)
    self:raiseCallback("onClickPrimary")
end

---@class WMHudTextElement : WMHudButtonElement
WMHudTextElement = {}
local WMHudTextElement_mt = Class(WMHudTextElement, WMHudButtonElement)
WMHudTextElement.highlightedColor = {42 / 255, 193 / 255, 237 / 255, 1}
WMHudTextElement.disabledColor = {0.4, 0.4, 0.4, 0.7}

function WMHudTextElement.new(parentHudElement, posX, posY, textSize, textAlignment, textColor, customMt)
    if customMt == nil then
        customMt = WMHudTextElement_mt
    end

    local backgroundOverlay = Overlay.new(nil, 0, 0, 0, 0)
    backgroundOverlay:setColor(1, 1, 1, 1)

    local self = WMHudButtonElement.new(backgroundOverlay, parentHudElement, customMt)

    self.text = ""
    self.textSize = textSize or 14
    self.screenTextSize = self.textSize / 1080 * g_screenHeight
    self.textAlignment = textAlignment or RenderText.ALIGN_LEFT
    self.textColor = textColor or {1, 1, 1, 1}
    self.maxWidth = 0.9

    self:setPosition(posX or 0, posY or 0)
    return self
end

function WMHudTextElement:setText(text, maxWidth)
    self.text = text or ""
    self.maxWidth = maxWidth or self.maxWidth

    setTextAlignment(self.textAlignment)
    setTextWrapWidth(self.maxWidth)
    local width = getTextWidth(self.screenTextSize, self.text)
    local height = getTextHeight(self.screenTextSize, self.text)
    self:setDimension(width, height)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextWrapWidth(0)
end

function WMHudTextElement:setScale(uiScale)
    WMHudTextElement:superClass().setScale(self, uiScale, uiScale)
    self.screenTextSize = (self.textSize / 1080 * g_screenHeight) * uiScale
end

function WMHudTextElement:draw()
    if not self.visible then
        return
    end

    local posX, posY = self:getPosition()
    setTextAlignment(self.textAlignment)
    setTextWrapWidth(self.maxWidth)

    local r, g, b, a
    if self.disabled then
        r, g, b, a = unpack(WMHudTextElement.disabledColor)
    elseif self.hovered then
        r, g, b, a = unpack(WMHudTextElement.highlightedColor)
    else
        r, g, b, a = unpack(self.textColor)
    end

    setTextColor(r, g, b, a)
    renderText(posX, posY, self.screenTextSize, self.text)

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextWrapWidth(0)
    setTextColor(1, 1, 1, 1)

    WMHudTextElement:superClass().draw(self)
end

---@class WMHudIconButton : WMHudButtonElement
WMHudIconButton = {}
local WMHudIconButton_mt = Class(WMHudIconButton, WMHudButtonElement)

WMHudIconButton.NORMAL_COLOR = {1, 1, 1, 0.9}
WMHudIconButton.HOVER_COLOR = {42 / 255, 193 / 255, 237 / 255, 1}
WMHudIconButton.DISABLED_COLOR = {0.4, 0.4, 0.4, 0.5}
WMHudIconButton.ACTIVE_COLOR = {0, 0.8, 0, 1}

function WMHudIconButton.new(parentHudElement, posX, posY, width, height, iconFilename, uvs, customMt)
    if customMt == nil then
        customMt = WMHudIconButton_mt
    end

    local overlay
    if iconFilename then
        overlay = Overlay.new(iconFilename, posX or 0, posY or 0, width or 0.03, height or 0.03)
        if uvs then
            overlay:setUVs(uvs)
        end
    else
        overlay = Overlay.new(nil, posX or 0, posY or 0, width or 0.03, height or 0.03)
    end
    overlay:setColor(unpack(WMHudIconButton.NORMAL_COLOR))

    local self = WMHudButtonElement.new(overlay, parentHudElement, customMt)
    self.isActive = false
    self:setPosition(posX or 0, posY or 0)
    self:setDimension(width or 0.03, height or 0.03)
    return self
end

function WMHudIconButton:setActive(active)
    self.isActive = active
end

function WMHudIconButton:draw()
    if not self.visible then
        return
    end

    local r, g, b, a
    if self.disabled then
        r, g, b, a = unpack(WMHudIconButton.DISABLED_COLOR)
    elseif self.isActive then
        r, g, b, a = unpack(WMHudIconButton.ACTIVE_COLOR)
    elseif self.hovered then
        r, g, b, a = unpack(WMHudIconButton.HOVER_COLOR)
    else
        r, g, b, a = unpack(WMHudIconButton.NORMAL_COLOR)
    end

    self.overlay:setColor(r, g, b, a)
    WMHudIconButton:superClass().draw(self)
end

-- Utility function to create overlay
function WMHudCreateOverlay(width, height, filename, uvs, color)
    local w, h = getNormalizedScreenValues(width, height)
    local overlay = Overlay.new(filename, 0, 0, w, h)
    if uvs then
        overlay:setUVs(uvs)
    end
    if color then
        overlay:setColor(unpack(color))
    end
    return overlay, w, h
end

WMLogger:info("WMHudElements module loaded")
