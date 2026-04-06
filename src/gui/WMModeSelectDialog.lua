--[[
    WorkflowManager - Mode Select Dialog
    Lets the player choose Main or Support role when starting a workflow that has support sub-steps.

    Author: WorkflowManager Team
]]

---@class WMModeSelectDialog
WMModeSelectDialog = {}

local WMModeSelectDialog_mt = Class(WMModeSelectDialog, DialogElement)

function WMModeSelectDialog.new(target)
    local self = DialogElement.new(target, WMModeSelectDialog_mt)
    self.workflowId = nil
    self.vehicle    = nil
    self.callback   = nil
    return self
end

function WMModeSelectDialog:onCreate()
    WMLogger:debug("WMModeSelectDialog:onCreate")
end

function WMModeSelectDialog:onOpen()
    WMModeSelectDialog:superClass().onOpen(self)
    WMLogger:debug("WMModeSelectDialog:onOpen")

    -- Set title to workflow name
    if self.titleElement and self.workflowId then
        local wf = WorkflowManager:getWorkflowById(self.workflowId)
        if wf then
            self.titleElement:setText(wf.name)
        end
    end
end

function WMModeSelectDialog:onClose()
    WMModeSelectDialog:superClass().onClose(self)
    WMLogger:debug("WMModeSelectDialog:onClose")
end

---Configure the dialog before showing it.
---@param workflowId string  Workflow to start
---@param vehicle    table   Vehicle that will run the workflow
---@param callback   function  Called with true (main), false (support), or nil (cancel)
function WMModeSelectDialog:setWorkflow(workflowId, vehicle, callback)
    self.workflowId = workflowId
    self.vehicle    = vehicle
    self.callback   = callback
end

function WMModeSelectDialog:onClickMain()
    self:close()
    if self.callback then self.callback(true) end
end

function WMModeSelectDialog:onClickSupport()
    self:close()
    if self.callback then self.callback(false) end
end

function WMModeSelectDialog:onClickCancel()
    self:close()
    if self.callback then self.callback(nil) end
end

function WMModeSelectDialog:onEscPressed()
    self:onClickCancel()
end

WMLogger:info("WMModeSelectDialog module loaded")
