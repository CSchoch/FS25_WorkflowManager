--[[
    WorkflowManager - Text Input Dialog
    A simple dialog for text input using FS25's DialogElement

    Author: WorkflowManager Team
]]

---@class WMTextInputDialog
WMTextInputDialog = {}

local WMTextInputDialog_mt = Class(WMTextInputDialog, DialogElement)

function WMTextInputDialog.new(target)
    local self = DialogElement.new(target, WMTextInputDialog_mt)
    self.callback = nil
    self.callbackTarget = nil
    self.inputText = ""
    return self
end

function WMTextInputDialog:onCreate()
    WMLogger:debug("WMTextInputDialog:onCreate")
end

function WMTextInputDialog:onOpen()
    WMTextInputDialog:superClass().onOpen(self)
    WMLogger:debug("WMTextInputDialog:onOpen")

    if self.textInputElement then
        self.textInputElement.blockTime = 0
        self.textInputElement:setText(self.inputText or "")
        self.textInputElement:onFocusActivate()
    end
end

function WMTextInputDialog:onClose()
    WMTextInputDialog:superClass().onClose(self)
    WMLogger:debug("WMTextInputDialog:onClose")
end

---Set the dialog title
---@param title string Title text
function WMTextInputDialog:setTitle(title)
    if self.titleElement then
        self.titleElement:setText(title or "")
    end
end

---Set the initial text
---@param text string Initial text value
function WMTextInputDialog:setText(text)
    self.inputText = text or ""
    if self.textInputElement then
        self.textInputElement:setText(self.inputText)
    end
end

---Set the callback function
---@param callback function Callback function(text, confirmed)
---@param target table Callback target object
function WMTextInputDialog:setCallback(callback, target)
    self.callback = callback
    self.callbackTarget = target
end

---Called when OK button is clicked
function WMTextInputDialog:onClickOk()
    WMLogger:debug("WMTextInputDialog:onClickOk")
    local text = ""
    if self.textInputElement then
        text = self.textInputElement.text or ""
    end

    self:close()

    if self.callback then
        if self.callbackTarget then
            self.callback(self.callbackTarget, text, true)
        else
            self.callback(text, true)
        end
    end
end

---Called when Cancel/Back button is clicked
function WMTextInputDialog:onClickBack()
    WMLogger:debug("WMTextInputDialog:onClickBack")
    self:close()

    if self.callback then
        if self.callbackTarget then
            self.callback(self.callbackTarget, self.inputText, false)
        else
            self.callback(self.inputText, false)
        end
    end
end

---Called when Enter is pressed in the text input
function WMTextInputDialog:onEnterPressed(_, isClick)
    WMLogger:debug("WMTextInputDialog:onEnterPressed")
    if not isClick then
        self:onClickOk()
    end
end

---Called when Escape is pressed in the text input
function WMTextInputDialog:onEscPressed()
    WMLogger:debug("WMTextInputDialog:onEscPressed")
    self:onClickBack()
end
