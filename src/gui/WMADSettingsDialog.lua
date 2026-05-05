--[[
    WorkflowManager - AD/CP Settings Dialog
    Edits per-workflow AutoDrive settings overrides (and future CP settings).
    Opened from the workflow editor via the "AD/CP Settings" button.

    Author: WorkflowManager Team
]]

---@class WMADSettingsDialog
WMADSettingsDialog = {}

local WMADSettingsDialog_mt = Class(WMADSettingsDialog, DialogElement)

function WMADSettingsDialog.new(target)
    local self = DialogElement.new(target, WMADSettingsDialog_mt)
    self.callback    = nil
    self.adSettings  = nil
    return self
end

function WMADSettingsDialog:onCreate()
    WMLogger:debug("WMADSettingsDialog:onCreate")
end

function WMADSettingsDialog:onOpen()
    WMADSettingsDialog:superClass().onOpen(self)
    WMLogger:debug("WMADSettingsDialog:onOpen")

    local s = self.adSettings or {}

    -- unloadFillLevel is stored as 0.0–1.0 internally; displayed as 0–100 %
    if self.unloadFillInput then
        local v = s.unloadFillLevel
        self.unloadFillInput:setText(v ~= nil and tostring(math.floor(v * 100 + 0.5)) or "")
    end
    if self.pipeOffsetInput then
        self.pipeOffsetInput:setText(s.pipeOffset ~= nil and tostring(s.pipeOffset) or "")
    end
    if self.preCallInput then
        local v = s.preCallLevel
        self.preCallInput:setText(v ~= nil and tostring(math.floor(v * 100 + 0.5)) or "")
    end
end

function WMADSettingsDialog:onClose()
    WMADSettingsDialog:superClass().onClose(self)
    WMLogger:debug("WMADSettingsDialog:onClose")
end

---Prepare the dialog before showing it.
---@param adSettings table|nil  Current workflow.adSettings (may be nil)
---@param callback   function   Called with a settings table on OK, or nil on cancel
function WMADSettingsDialog:setSettings(adSettings, callback)
    self.adSettings = adSettings
    self.callback   = callback
end

function WMADSettingsDialog:onClickConfirm()
    local function parseNum(el)
        return el and tonumber(el.text) or nil
    end

    -- unloadFillLevel and preCallLevel: user enters 0–100 %, store as 0.0–1.0
    local fillPct    = parseNum(self.unloadFillInput)
    local preCallPct = parseNum(self.preCallInput)
    local settings = {
        unloadFillLevel = fillPct    ~= nil and (fillPct    / 100) or nil,
        pipeOffset      = parseNum(self.pipeOffsetInput),
        preCallLevel    = preCallPct ~= nil and (preCallPct / 100) or nil,
    }

    self:close()

    if self.callback then
        self.callback(settings)
    end
end

function WMADSettingsDialog:onClickCancel()
    self:close()
    if self.callback then
        self.callback(nil)
    end
end

function WMADSettingsDialog:onEscPressed()
    self:onClickCancel()
end
