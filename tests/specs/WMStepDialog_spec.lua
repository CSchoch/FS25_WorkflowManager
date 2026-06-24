--[[
    WMStepDialog Unit Tests
    Covers the six type-branching sites that must use WorkflowManager step-type
    constants instead of hardcoded string literals.
]]

describe("WMStepDialog", function()

    setup(function()
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

        _G.WorkflowManager = {
            STEP_AUTODRIVE       = "autodrive",
            STEP_COURSEPLAY      = "courseplay",
            STEP_WAIT_FOR_LEADER = "wait_for_leader",
            STEP_UNLOCK_FOLLOWER = "unlock_follower",
            isMarkerStepType = function(self, stepType)
                return stepType == self.STEP_WAIT_FOR_LEADER
                    or stepType == self.STEP_UNLOCK_FOLLOWER
            end,
            getStepTypeLabel = function(self, stepType) return stepType end,
            editorDialog = nil,
        }

        dofile("src/gui/WMStepDialog.lua")
    end)

    local function makeDialog()
        return WMStepDialog.new()
    end

    -- =========================================================================
    -- getAvailableActions  (line 291 in WMStepDialog.lua)
    -- =========================================================================
    describe("getAvailableActions", function()
        it("returns 5 AD actions for STEP_AUTODRIVE", function()
            local d = makeDialog()
            d.stepType = WorkflowManager.STEP_AUTODRIVE
            local actions = d:getAvailableActions()
            assert.are.equal(5, #actions)
            assert.are.equal("drive", actions[1])
        end)

        it("returns 2 CP actions for STEP_COURSEPLAY", function()
            local d = makeDialog()
            d.stepType = WorkflowManager.STEP_COURSEPLAY
            local actions = d:getAvailableActions()
            assert.are.equal(2, #actions)
            assert.are.equal("fieldwork", actions[1])
        end)
    end)

    -- =========================================================================
    -- refreshTargetList  (line 171 in WMStepDialog.lua)
    -- =========================================================================
    describe("refreshTargetList", function()
        before_each(function()
            _G.WorkflowManager.editorDialog = {
                getADDestinations = function() return {"Farm", "Silo"} end,
                getCPCourses      = function() return {"Field1", "Field2"} end,
            }
        end)

        it("loads AD destinations for STEP_AUTODRIVE", function()
            local d = makeDialog()
            d.stepType = WorkflowManager.STEP_AUTODRIVE
            d:refreshTargetList()
            assert.are.equal(2, #d.targetItems)
            assert.are.equal("Farm", d.targetItems[1].name)
        end)

        it("loads CP courses for STEP_COURSEPLAY", function()
            local d = makeDialog()
            d.stepType = WorkflowManager.STEP_COURSEPLAY
            d:refreshTargetList()
            assert.are.equal(2, #d.targetItems)
            assert.are.equal("Field1", d.targetItems[1].name)
        end)
    end)

    -- =========================================================================
    -- actionNeedsUnloadTarget  (line 493 in WMStepDialog.lua)
    -- =========================================================================
    describe("actionNeedsUnloadTarget", function()
        it("returns false for STEP_COURSEPLAY regardless of action", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_COURSEPLAY
            d.stepAction = "fieldwork"
            assert.is_false(d:actionNeedsUnloadTarget())
        end)

        it("returns true for 'unload' action on STEP_AUTODRIVE", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_AUTODRIVE
            d.stepAction = "unload"
            assert.is_true(d:actionNeedsUnloadTarget())
        end)

        it("returns false for 'drive' action on STEP_AUTODRIVE", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_AUTODRIVE
            d.stepAction = "drive"
            assert.is_false(d:actionNeedsUnloadTarget())
        end)
    end)

    -- =========================================================================
    -- actionNeedsFillType  (line 501 in WMStepDialog.lua)
    -- =========================================================================
    describe("actionNeedsFillType", function()
        it("returns false for STEP_COURSEPLAY", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_COURSEPLAY
            d.stepAction = "fieldwork"
            assert.is_false(d:actionNeedsFillType())
        end)

        it("returns true for 'load' action on STEP_AUTODRIVE", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_AUTODRIVE
            d.stepAction = "load"
            assert.is_true(d:actionNeedsFillType())
        end)

        it("returns true for 'pickup_deliver' action on STEP_AUTODRIVE", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_AUTODRIVE
            d.stepAction = "pickup_deliver"
            assert.is_true(d:actionNeedsFillType())
        end)
    end)

    -- =========================================================================
    -- onTypeChanged – defaultActions map  (line 642 in WMStepDialog.lua)
    -- =========================================================================
    describe("onTypeChanged defaultActions", function()
        -- Helper: a dialog whose refresh side-effects are stubbed out
        local function makeStubDialog(fromType, fromAction)
            local d = makeDialog()
            d.stepType            = fromType
            d.stepAction          = fromAction
            d.selectedFillTypes   = {}
            d.targetSearchInput   = nil
            d.unloadTargetSearchInput = nil
            d.fillTypeSearchInput = nil
            d.refreshTargetList   = function(self) end
            d.refreshActionDropdown = function(self) end
            d.refreshTargetDisplay  = function(self) end
            d.updateFieldVisibility = function(self) end
            return d
        end

        it("defaults stepAction to 'drive' when switching to STEP_AUTODRIVE (index 1)", function()
            local d = makeStubDialog(WorkflowManager.STEP_COURSEPLAY, "fieldwork")
            WMStepDialog.onTypeChanged(d, 1)  -- index 1 = STEP_AUTODRIVE in getStepTypes()
            assert.are.equal(WorkflowManager.STEP_AUTODRIVE, d.stepType)
            assert.are.equal("drive", d.stepAction)
        end)

        it("defaults stepAction to 'fieldwork' when switching to STEP_COURSEPLAY (index 2)", function()
            local d = makeStubDialog(WorkflowManager.STEP_AUTODRIVE, "drive")
            WMStepDialog.onTypeChanged(d, 2)  -- index 2 = STEP_COURSEPLAY in getStepTypes()
            assert.are.equal(WorkflowManager.STEP_COURSEPLAY, d.stepType)
            assert.are.equal("fieldwork", d.stepAction)
        end)
    end)

    -- =========================================================================
    -- onClickConfirm – AD-specific fields  (line 796 in WMStepDialog.lua)
    -- =========================================================================
    describe("onClickConfirm AD-specific fields", function()
        local function confirm(d)
            local result
            d.callback = function(s) result = s end
            d.close = function(self) end
            WMStepDialog.onClickConfirm(d)
            return result
        end

        it("includes unloadTarget for 'unload' step on STEP_AUTODRIVE", function()
            local d = makeDialog()
            d.stepType        = WorkflowManager.STEP_AUTODRIVE
            d.stepAction      = "unload"
            d.stepTarget      = "Silo"
            d.stepUnloadTarget = "Field1"
            local step = confirm(d)
            assert.are.equal("Field1", step.unloadTarget)
        end)

        it("does not include unloadTarget for STEP_COURSEPLAY step", function()
            local d = makeDialog()
            d.stepType        = WorkflowManager.STEP_COURSEPLAY
            d.stepAction      = "fieldwork"
            d.stepTarget      = "Field1"
            d.stepUnloadTarget = "Silo"  -- populated but must be ignored for CP
            local step = confirm(d)
            assert.is_nil(step.unloadTarget)
        end)

        it("includes fillTypes for 'load' step on STEP_AUTODRIVE", function()
            local d = makeDialog()
            d.stepType         = WorkflowManager.STEP_AUTODRIVE
            d.stepAction       = "load"
            d.stepTarget       = "Silo"
            d.selectedFillTypes = {"wheat"}
            local step = confirm(d)
            assert.is_not_nil(step.fillTypes)
            assert.are.equal("wheat", step.fillTypes[1])
        end)

        it("does not include fillTypes for STEP_COURSEPLAY step", function()
            local d = makeDialog()
            d.stepType         = WorkflowManager.STEP_COURSEPLAY
            d.stepAction       = "fieldwork"
            d.stepTarget       = "Field1"
            d.selectedFillTypes = {"wheat"}  -- must be ignored for CP
            local step = confirm(d)
            assert.is_nil(step.fillTypes)
        end)
    end)

end)
