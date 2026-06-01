--[[
    WMLeaderVehicleSelectDialog Unit Tests
]]

describe("WMLeaderVehicleSelectDialog", function()

    local dialog
    local v1, v2, v3       -- vehicles
    local callbackResult   -- records what callback received
    local closeCalled

    -- Minimal FS25 class infrastructure needed by the dialog module
    setup(function()
        -- Class(cls, parent) must return a metatable whose __index is cls,
        -- so that DialogElement.new(target, mt) can set it on the instance.
        _G.Class = function(cls, parent)
            if parent then
                cls.superClass = function()
                    return { onOpen = function() end, onClose = function() end }
                end
            end
            return { __index = cls }
        end

        _G.DialogElement = {
            new = function(target, mt)
                local self = {}
                if mt then setmetatable(self, mt) end
                return self
            end
        }

        dofile("src/gui/WMLeaderVehicleSelectDialog.lua")
    end)

    -- Helper: build a vehicle with wmExecution attached
    local function makeVehicle(name, workflowName)
        local v = { _name = name }
        v.getName = function(self) return self._name end
        v.spec_workflowManagerSpec = {
            wmExecution = {
                workflow = { name = workflowName },
                status = "running"
            }
        }
        return v
    end

    -- Helper: make a mock list element
    local function makeList()
        local l = { _dataSource = nil, _selectedIndex = nil, _reloaded = false }
        l.setDataSource  = function(self, ds) self._dataSource = ds end
        l.reloadData     = function(self) self._reloaded = true end
        l.setSelectedIndex = function(self, i) self._selectedIndex = i end
        return l
    end

    -- Helper: make a mock button
    local function makeButton()
        local b = { _disabled = false }
        b.setDisabled = function(self, v) self._disabled = v end
        return b
    end

    before_each(function()
        v1 = makeVehicle("Tractor1", "Harvest North")
        v2 = makeVehicle("Tractor2", "Harvest South")
        v3 = makeVehicle("Tractor3", "Bale Work")

        callbackResult = "NOT_CALLED"
        closeCalled    = false

        -- Fresh dialog instance each test
        dialog = WMLeaderVehicleSelectDialog.new()
        dialog.vehicleList  = makeList()
        dialog.selectButton = makeButton()
        dialog.close = function(self) closeCalled = true end

        -- Default: v1 and v2 are active, v3 is the currentVehicle (excluded)
        _G.WMExecutor = {
            activeVehicles = { [v1] = true, [v2] = true, [v3] = true }
        }

        dialog:setData(v3, function(result)
            callbackResult = result
        end)
    end)

    -- =========================================================================
    -- setData
    -- =========================================================================
    describe("setData", function()
        it("stores currentVehicle", function()
            assert.are.equal(v3, dialog.currentVehicle)
        end)

        it("stores callback", function()
            assert.is_not_nil(dialog.callback)
        end)
    end)

    -- =========================================================================
    -- buildVehicleList — vehicle list population (called before showing)
    -- =========================================================================
    describe("buildVehicleList", function()
        it("excludes currentVehicle from the list", function()
            dialog:buildVehicleList()
            for _, entry in ipairs(dialog.vehicles) do
                assert.are_not.equal(v3, entry.vehicle)
            end
        end)

        it("includes other active vehicles", function()
            dialog:buildVehicleList()
            assert.are.equal(2, #dialog.vehicles)
        end)

        it("returns the number of candidate vehicles", function()
            assert.are.equal(2, dialog:buildVehicleList())
        end)

        it("returns 0 when only the currentVehicle is active", function()
            _G.WMExecutor.activeVehicles = { [v3] = true }
            assert.are.equal(0, dialog:buildVehicleList())
            assert.are.equal(0, #dialog.vehicles)
        end)

        it("stores vehicle name and workflow name per entry", function()
            dialog:buildVehicleList()
            local names = {}
            local wfNames = {}
            for _, entry in ipairs(dialog.vehicles) do
                names[entry.name] = true
                wfNames[entry.workflowName] = true
            end
            assert.is_true(names["Tractor1"])
            assert.is_true(names["Tractor2"])
            assert.is_true(wfNames["Harvest North"])
            assert.is_true(wfNames["Harvest South"])
        end)
    end)

    -- =========================================================================
    -- onOpen — wires up the list (list already built by buildVehicleList)
    -- =========================================================================
    describe("onOpen", function()
        it("wires up vehicleList and selects first item", function()
            dialog:buildVehicleList()
            dialog:onOpen()
            assert.are.equal(dialog, dialog.vehicleList._dataSource)
            assert.is_true(dialog.vehicleList._reloaded)
            assert.are.equal(1, dialog.vehicleList._selectedIndex)
        end)

        it("sets selectedIndex to 1", function()
            dialog:buildVehicleList()
            dialog:onOpen()
            assert.are.equal(1, dialog.selectedIndex)
        end)

        -- Regression (bug-038): onOpen must NEVER call close() synchronously.
        -- Closing a dialog mid-open corrupts the FS25 input-context stack,
        -- leaving no inputs registered (HUD/menu can't be closed afterward).
        it("does not call close() even when no other vehicles are active", function()
            _G.WMExecutor.activeVehicles = { [v3] = true }  -- only currentVehicle
            dialog:buildVehicleList()
            dialog:onOpen()
            assert.is_false(closeCalled)
        end)
    end)

    -- =========================================================================
    -- SmoothList data source callbacks
    -- =========================================================================
    describe("getNumberOfItemsInSection", function()
        it("returns count of loaded vehicles", function()
            dialog:buildVehicleList()
            assert.are.equal(2, dialog:getNumberOfItemsInSection(nil, nil))
        end)

        it("returns 0 before the list is built", function()
            assert.are.equal(0, dialog:getNumberOfItemsInSection(nil, nil))
        end)
    end)

    describe("populateCellForItemInSection", function()
        it("sets leaderVehicleName and leaderWorkflowName on the cell", function()
            dialog:buildVehicleList()

            local nameSet, wfSet
            local cell = {
                getDescendantByName = function(self, name)
                    if name == "leaderVehicleName" then
                        return { setText = function(_, t) nameSet = t end }
                    elseif name == "leaderWorkflowName" then
                        return { setText = function(_, t) wfSet = t end }
                    end
                end
            }

            -- Populate first item — either Tractor1 or Tractor2 (order not guaranteed)
            dialog:populateCellForItemInSection(nil, nil, 1, cell)

            assert.is_not_nil(nameSet)
            assert.is_not_nil(wfSet)
        end)

        it("does nothing when index is out of range", function()
            dialog:buildVehicleList()
            assert.has_no.errors(function()
                dialog:populateCellForItemInSection(nil, nil, 99, {
                    getDescendantByName = function() return nil end
                })
            end)
        end)
    end)

    -- =========================================================================
    -- Selection and button state
    -- =========================================================================
    describe("onListSelectionChanged", function()
        it("updates selectedIndex", function()
            dialog:buildVehicleList()
            dialog:onListSelectionChanged(nil, nil, 2)
            assert.are.equal(2, dialog.selectedIndex)
        end)

        it("enables selectButton when index is valid", function()
            dialog:buildVehicleList()
            dialog:onListSelectionChanged(nil, nil, 1)
            assert.is_false(dialog.selectButton._disabled)
        end)

        it("disables selectButton when index is 0", function()
            dialog:buildVehicleList()
            dialog:onListSelectionChanged(nil, nil, 0)
            assert.is_true(dialog.selectButton._disabled)
        end)
    end)

    describe("onListDoubleClick", function()
        it("selects the item and fires onClickSelect", function()
            dialog:buildVehicleList()
            local vehicle = dialog.vehicles[1].vehicle
            dialog:onListDoubleClick(nil, nil, 1)
            assert.is_true(closeCalled)
            assert.are.equal(vehicle, callbackResult)
        end)
    end)

    describe("updateButtons", function()
        it("disables selectButton when vehicles list is empty", function()
            -- No onOpen, so vehicles = {} and selectedIndex = 0
            dialog:updateButtons()
            assert.is_true(dialog.selectButton._disabled)
        end)

        it("enables selectButton when selectedIndex is valid", function()
            dialog:buildVehicleList()
            dialog.selectedIndex = 1
            dialog:updateButtons()
            assert.is_false(dialog.selectButton._disabled)
        end)
    end)

    -- =========================================================================
    -- Button callbacks
    -- =========================================================================
    describe("onClickSelect", function()
        it("calls callback with the selected vehicle", function()
            dialog:buildVehicleList()
            local expected = dialog.vehicles[1].vehicle
            dialog.selectedIndex = 1
            dialog:onClickSelect()
            assert.are.equal(expected, callbackResult)
        end)

        it("closes the dialog", function()
            dialog:buildVehicleList()
            dialog:onClickSelect()
            assert.is_true(closeCalled)
        end)

        it("calls callback(nil) when selectedIndex points to nothing", function()
            dialog:buildVehicleList()
            dialog.selectedIndex = 99
            dialog:onClickSelect()
            assert.is_nil(callbackResult)
        end)
    end)

    describe("onClickNoLeader", function()
        it("calls callback with nil", function()
            dialog:onClickNoLeader()
            assert.is_nil(callbackResult)
        end)

        it("closes the dialog", function()
            dialog:onClickNoLeader()
            assert.is_true(closeCalled)
        end)
    end)

    describe("onClickCancel", function()
        it("calls callback with false (aborts start)", function()
            dialog:onClickCancel()
            assert.is_false(callbackResult)
        end)

        it("closes the dialog", function()
            dialog:onClickCancel()
            assert.is_true(closeCalled)
        end)
    end)

    describe("onEscPressed", function()
        it("behaves like onClickCancel (aborts start)", function()
            dialog:onEscPressed()
            assert.is_false(callbackResult)
            assert.is_true(closeCalled)
        end)
    end)
end)
