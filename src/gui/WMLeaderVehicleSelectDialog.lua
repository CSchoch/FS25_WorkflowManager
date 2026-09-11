--[[
    WorkflowManager - Leader Vehicle Select Dialog
    Lets the player pick which currently-running vehicle to follow as leader,
    or start without a leader.
]]

---@class WMLeaderVehicleSelectDialog
WMLeaderVehicleSelectDialog = {}

local WMLeaderVehicleSelectDialog_mt = Class(WMLeaderVehicleSelectDialog, DialogElement)

function WMLeaderVehicleSelectDialog.new(target)
    local self = DialogElement.new(target, WMLeaderVehicleSelectDialog_mt)
    self.currentVehicle  = nil
    self.callback        = nil
    self.vehicles        = {}   -- list of {vehicle, name, workflowName}
    self.selectedIndex   = 0
    self.inputEventIds   = {}
    return self
end

function WMLeaderVehicleSelectDialog:onCreate()
    WMLogger:debug("WMLeaderVehicleSelectDialog:onCreate")
end

---Build the list of selectable leader vehicles (active vehicles excluding currentVehicle).
---Safe to call before the dialog is shown. Returns the number of candidates.
function WMLeaderVehicleSelectDialog:buildVehicleList()
    self.vehicles = {}
    for vehicle, _ in pairs(WMExecutor.activeVehicles) do
        if vehicle ~= self.currentVehicle then
            local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
            local workflowName = activeData and activeData.workflow and activeData.workflow.name or "?"
            local vehicleName = vehicle.getName and vehicle:getName() or tostring(vehicle)
            table.insert(self.vehicles, { vehicle = vehicle, name = vehicleName, workflowName = workflowName })
        end
    end
    return #self.vehicles
end

function WMLeaderVehicleSelectDialog:onOpen()
    WMLeaderVehicleSelectDialog:superClass().onOpen(self)
    WMLogger:debug("WMLeaderVehicleSelectDialog:onOpen")
    WMHud:onDialogOpened()

    self:registerInputEvents()

    if self.noLeaderButton then self.noLeaderButton:setInputAction("WM_GUI_NO_LEADER") end

    if self.vehicleList then
        self.vehicleList:setDataSource(self)
        self.vehicleList:reloadData()
        self.vehicleList:setSelectedIndex(1)
        self.selectedIndex = 1
    end

    self:updateButtons()
end

function WMLeaderVehicleSelectDialog:onClose()
    WMLeaderVehicleSelectDialog:superClass().onClose(self)
    WMLogger:debug("WMLeaderVehicleSelectDialog:onClose")
    WMHud:onDialogClosed()
    self:unregisterInputEvents()
end

---Configure the dialog before showing it.
---@param currentVehicle table  The vehicle that will run the follower workflow (excluded from list)
---@param callback function     callback(leaderVehicle|nil|false): vehicle=leader chosen, nil=no leader, false=cancelled
function WMLeaderVehicleSelectDialog:setData(currentVehicle, callback)
    self.currentVehicle = currentVehicle
    self.callback       = callback
end

---SmoothList data source: item count
function WMLeaderVehicleSelectDialog:getNumberOfItemsInSection(list, section)
    return #self.vehicles
end

---SmoothList data source: populate cell
function WMLeaderVehicleSelectDialog:populateCellForItemInSection(list, section, index, cell)
    local entry = self.vehicles[index]
    if entry == nil then return end

    local nameEl = cell:getDescendantByName("leaderVehicleName")
    if nameEl then nameEl:setText(entry.name) end

    local wfEl = cell:getDescendantByName("leaderWorkflowName")
    if wfEl then wfEl:setText(entry.workflowName) end
end

function WMLeaderVehicleSelectDialog:onListSelectionChanged(list, section, index)
    self.selectedIndex = index
    self:updateButtons()
end

function WMLeaderVehicleSelectDialog:onListDoubleClick(list, section, index)
    self.selectedIndex = index
    self:onClickSelect()
end

function WMLeaderVehicleSelectDialog:updateButtons()
    local hasSelection = self.selectedIndex > 0 and self.selectedIndex <= #self.vehicles
    if self.selectButton then
        self.selectButton:setDisabled(not hasSelection)
    end
end

function WMLeaderVehicleSelectDialog:onClickSelect()
    local entry = self.vehicles[self.selectedIndex]
    local leaderVehicle = entry and entry.vehicle or nil
    self:close()
    if self.callback then self.callback(leaderVehicle) end
end

function WMLeaderVehicleSelectDialog:onClickNoLeader()
    self:close()
    if self.callback then self.callback(nil) end
end

function WMLeaderVehicleSelectDialog:onClickCancel()
    self:close()
    if self.callback then self.callback(false) end
end

function WMLeaderVehicleSelectDialog:onEscPressed()
    self:onClickCancel()
end

-- ============================================================
-- Input events
-- ============================================================

function WMLeaderVehicleSelectDialog:registerInputEvents()
    self.inputEventIds = {}

    local _, eventId = g_inputBinding:registerActionEvent(InputAction.WM_GUI_NO_LEADER, self, self.onInputNoLeader, false, true, false, true)
    if eventId ~= nil then
        table.insert(self.inputEventIds, eventId)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end
end

function WMLeaderVehicleSelectDialog:unregisterInputEvents()
    for _, eventId in ipairs(self.inputEventIds or {}) do
        g_inputBinding:removeActionEvent(eventId)
    end
    self.inputEventIds = {}
end

function WMLeaderVehicleSelectDialog:onInputNoLeader()
    if self.noLeaderButton and not self.noLeaderButton.disabled then self:onClickNoLeader() end
end

WMLogger:info("WMLeaderVehicleSelectDialog module loaded")
