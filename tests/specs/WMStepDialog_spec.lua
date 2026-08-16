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
            STEP_PARK            = "park",
            STEP_REFUEL          = "refuel",
            STEP_REPAIR          = "repair",
            isMarkerStepType = function(self, stepType)
                return stepType == self.STEP_WAIT_FOR_LEADER
                    or stepType == self.STEP_UNLOCK_FOLLOWER
            end,
            isTargetlessStepType = function(self, stepType)
                return self:isMarkerStepType(stepType)
                    or stepType == self.STEP_PARK
                    or stepType == self.STEP_REFUEL
                    or stepType == self.STEP_REPAIR
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

        it("maps click indices against the RENDERED list after a type change (regression: saved wrong type)", function()
            -- Legacy marker sub-step renders a 7-entry list [AD, CP, WAIT, UNLOCK, PARK, REFUEL, REPAIR].
            -- After switching to AutoDrive, getStepTypes() would shrink to 5 entries — but the
            -- visible labels still show 7, so clicking the label 'Park' (index 5) used to map
            -- to types[5] = repair on the recomputed list and silently save a Repair step.
            local d = makeStubDialog(WorkflowManager.STEP_WAIT_FOR_LEADER, nil)
            d.isSupportStep = true
            d.typeDropdown = {
                setTexts = function() end,
                setState = function() end,
            }
            WMStepDialog.refreshTypeDropdown(d)
            assert.are.equal(7, #d.renderedStepTypes)

            -- First change: pick AutoDrive (index 1); dropdown labels are NOT re-rendered
            WMStepDialog.onTypeChanged(d, 1)
            assert.are.equal(WorkflowManager.STEP_AUTODRIVE, d.stepType)

            -- Second change: click the visible 'Park' label (index 5 of the rendered list)
            WMStepDialog.onTypeChanged(d, 5)
            assert.are.equal(WorkflowManager.STEP_PARK, d.stepType)
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

    -- =========================================================================
    -- Park step type (line 250 getStepTypes, line 259 isMarkerStep, line 448
    -- updateFieldVisibility, line 780 onClickConfirm in WMStepDialog.lua)
    -- =========================================================================
    describe("Park step type", function()
        it("is included in getStepTypes()", function()
            local d = makeDialog()
            local types = d:getStepTypes()
            local found = false
            for _, t in ipairs(types) do
                if t == WorkflowManager.STEP_PARK then found = true end
            end
            assert.is_true(found)
        end)

        it("isMarkerStep() returns true for STEP_PARK (no target/action fields)", function()
            local d = makeDialog()
            d.stepType = WorkflowManager.STEP_PARK
            assert.is_true(d:isMarkerStep())
        end)

        it("onClickConfirm produces {type='park', target=''} with no validation gate", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_PARK
            d.stepTarget = ""  -- Park needs no target; must not block confirm like AD/CP do
            local result
            d.callback = function(s) result = s end
            d.close = function(self) end
            WMStepDialog.onClickConfirm(d)
            assert.is_not_nil(result)
            assert.are.equal(WorkflowManager.STEP_PARK, result.type)
            assert.are.equal("", result.target)
        end)
    end)

    describe("Refuel step type", function()
        it("is included in getStepTypes()", function()
            local d = makeDialog()
            local types = d:getStepTypes()
            local found = false
            for _, t in ipairs(types) do
                if t == WorkflowManager.STEP_REFUEL then found = true end
            end
            assert.is_true(found)
        end)

        it("isMarkerStep() returns true for STEP_REFUEL (no target/action fields)", function()
            local d = makeDialog()
            d.stepType = WorkflowManager.STEP_REFUEL
            assert.is_true(d:isMarkerStep())
        end)

        it("onClickConfirm produces {type='refuel', target=''} with no validation gate", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_REFUEL
            d.stepTarget = ""
            local result
            d.callback = function(s) result = s end
            d.close = function(self) end
            WMStepDialog.onClickConfirm(d)
            assert.is_not_nil(result)
            assert.are.equal(WorkflowManager.STEP_REFUEL, result.type)
            assert.are.equal("", result.target)
        end)
    end)

    describe("Repair step type", function()
        it("is included in getStepTypes()", function()
            local d = makeDialog()
            local types = d:getStepTypes()
            local found = false
            for _, t in ipairs(types) do
                if t == WorkflowManager.STEP_REPAIR then found = true end
            end
            assert.is_true(found)
        end)

        it("isMarkerStep() returns true for STEP_REPAIR (no target/action fields)", function()
            local d = makeDialog()
            d.stepType = WorkflowManager.STEP_REPAIR
            assert.is_true(d:isMarkerStep())
        end)

        it("onClickConfirm produces {type='repair', target=''} with no validation gate", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_REPAIR
            d.stepTarget = ""
            local result
            d.callback = function(s) result = s end
            d.close = function(self) end
            WMStepDialog.onClickConfirm(d)
            assert.is_not_nil(result)
            assert.are.equal(WorkflowManager.STEP_REPAIR, result.type)
            assert.are.equal("", result.target)
        end)
    end)

    -- =========================================================================
    -- Support sub-steps must not offer sync markers: leader/follower pairing is
    -- built from workflow.steps only, so a nested marker has nothing to pair
    -- with and the executor cannot run it as a real sub-step.
    -- =========================================================================
    describe("support sub-step type restrictions", function()
        local function contains(list, value)
            for _, v in ipairs(list) do
                if v == value then return true end
            end
            return false
        end

        it("defaults to isSupportStep=false (main step behaviour)", function()
            local d = makeDialog()
            assert.is_false(d.isSupportStep)
        end)

        it("setStep(step, cb, true) marks the dialog as editing a support sub-step", function()
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end, true)
            assert.is_true(d.isSupportStep)
        end)

        it("setStep without the flag leaves isSupportStep false", function()
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end)
            assert.is_false(d.isSupportStep)
        end)

        it("omits both sync marker types for support sub-steps", function()
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end, true)
            local types = d:getStepTypes()
            assert.is_false(contains(types, WorkflowManager.STEP_WAIT_FOR_LEADER))
            assert.is_false(contains(types, WorkflowManager.STEP_UNLOCK_FOLLOWER))
        end)

        it("still offers AD, CP, Park, Refuel and Repair for support sub-steps", function()
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end, true)
            local types = d:getStepTypes()
            assert.are.equal(5, #types)
            assert.is_true(contains(types, WorkflowManager.STEP_AUTODRIVE))
            assert.is_true(contains(types, WorkflowManager.STEP_COURSEPLAY))
            assert.is_true(contains(types, WorkflowManager.STEP_PARK))
            assert.is_true(contains(types, WorkflowManager.STEP_REFUEL))
            assert.is_true(contains(types, WorkflowManager.STEP_REPAIR))
        end)

        it("keeps AD/CP at indices 1 and 2 so onTypeChanged indexing is unchanged", function()
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end, true)
            local types = d:getStepTypes()
            assert.are.equal(WorkflowManager.STEP_AUTODRIVE, types[1])
            assert.are.equal(WorkflowManager.STEP_COURSEPLAY, types[2])
        end)

        it("still offers all 7 types for main steps", function()
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end, false)
            assert.are.equal(7, #d:getStepTypes())
        end)

        it("re-lists markers when editing a support sub-step that already is one", function()
            -- Legacy data: a marker saved as a support sub-step before this restriction.
            -- The dropdown must show its real type rather than silently displaying AutoDrive.
            local d = makeDialog()
            WMStepDialog.setStep(d, { type = WorkflowManager.STEP_WAIT_FOR_LEADER, target = "" },
                function() end, true)
            local types = d:getStepTypes()
            assert.is_true(contains(types, WorkflowManager.STEP_WAIT_FOR_LEADER))
            assert.is_true(contains(types, WorkflowManager.STEP_UNLOCK_FOLLOWER))
        end)
    end)

    -- =========================================================================
    -- onClickConfirm – missing target must warn, not fail silently
    -- =========================================================================
    describe("onClickConfirm target validation", function()
        local warnings

        before_each(function()
            warnings = {}
            -- Replace the global outright rather than mutating the shared mock's insides:
            -- the runner's per-file _G snapshot restores replaced globals, but not tables
            -- that a spec has reached into and modified.
            _G.g_currentMission = {
                hud = {
                    showBlinkingWarning = function(_, text, duration)
                        table.insert(warnings, { text = text, duration = duration })
                    end
                }
            }
        end)

        ---Confirm and report both the produced step and whether the dialog closed.
        local function confirm(d)
            local result, closed = nil, false
            d.callback = function(s) result = s end
            d.close = function() closed = true end
            WMStepDialog.onClickConfirm(d)
            return result, closed
        end

        it("does not confirm or close an AutoDrive step with no target", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_AUTODRIVE
            d.stepAction = "drive"
            d.stepTarget = ""
            local step, closed = confirm(d)
            assert.is_nil(step)
            assert.is_false(closed)
        end)

        it("warns the player instead of doing nothing", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_AUTODRIVE
            d.stepAction = "drive"
            d.stepTarget = ""
            confirm(d)
            assert.are.equal(1, #warnings)
            assert.are.equal("wm_warning_no_target", warnings[1].text)
        end)

        it("blocks a Courseplay step with no course selected", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_COURSEPLAY
            d.stepAction = "fieldwork"
            d.stepTarget = ""
            local step, closed = confirm(d)
            assert.is_nil(step)
            assert.is_false(closed)
            assert.are.equal(1, #warnings)
        end)

        it("confirms without warning once a target is set", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_COURSEPLAY
            d.stepAction = "fieldwork"
            d.stepTarget = "Singleplayer/F34/Kalken"
            local step, closed = confirm(d)
            assert.are.equal("Singleplayer/F34/Kalken", step.target)
            assert.is_true(closed)
            assert.are.equal(0, #warnings)
        end)

        it("confirms a targetless step type with an empty target", function()
            -- Park/Refuel/Repair and the sync markers legitimately carry no target.
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_PARK
            d.stepTarget = ""
            local step, closed = confirm(d)
            assert.are.equal(WorkflowManager.STEP_PARK, step.type)
            assert.is_true(closed)
            assert.are.equal(0, #warnings)
        end)
    end)

end)
