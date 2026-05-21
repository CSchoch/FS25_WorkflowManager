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
    return self
end

function WMLeaderVehicleSelectDialog:onCreate()
    WMLogger:debug("WMLeaderVehicleSelectDialog:onCreate")
end

function WMLeaderVehicleSelectDialog:onOpen()
    WMLeaderVehicleSelectDialog:superClass().onOpen(self)
    WMLogger:debug("WMLeaderVehicleSelectDialog:onOpen")

    -- Build vehicle list: active vehicles excluding currentVehicle
    self.vehicles = {}
    for vehicle, _ in pairs(WMExecutor.activeVehicles) do
        if vehicle ~= self.currentVehicle then
            local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
            local workflowName = activeData and activeData.workflow and activeData.workflow.name or "?"
            local vehicleName = vehicle.getName and vehicle:getName() or tostring(vehicle)
            table.insert(self.vehicles, { vehicle = vehicle, name = vehicleName, workflowName = workflowName })
        end
    end

    -- If no other vehicle is running, skip the dialog entirely
    if #self.vehicles == 0 then
        self:close()
        if self.callback then self.callback(nil) end
        return
    end

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
end

---Configure the dialog before showing it.
---@param currentVehicle table  The vehicle that will run the follower workflow (excluded from list)
---@param callback function     callback(leaderVehicle|nil)
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
    if self.callback then self.callback(nil) end
end

function WMLeaderVehicleSelectDialog:onEscPressed()
    self:onClickCancel()
end

WMLogger:info("WMLeaderVehicleSelectDialog module loaded")
