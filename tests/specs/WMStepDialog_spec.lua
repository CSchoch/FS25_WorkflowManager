--[[
    WMStepDialog Unit Tests
    Covers the six type-branching sites that must use WorkflowManager step-type
    constants instead of hardcoded string literals.
]]

describe("WMStepDialog", function()

    -- Shared so a test can make the base class's onOpen raise list events like the engine does
    local superStub = { onOpen = function() end, onClose = function() end, update = function() end }

    setup(function()
        _G.Class = function(cls, parent)
            if parent then
                cls.superClass = function()
                    return superStub
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
            getCourseDisplayName = function(self, name) return (string.gsub(name or "", "^Singleplayer/", "")) end,
            editorDialog = nil,
        }

        -- AutoDrive present by default: getStepTypes() hides the AD-driven types without it.
        _G.ADIntegration = { isAvailable = true }

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
    -- actionNeedsSeedType  (Courseplay field work only)
    -- =========================================================================
    describe("actionNeedsSeedType", function()
        it("returns true for 'fieldwork' on STEP_COURSEPLAY", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_COURSEPLAY
            d.stepAction = "fieldwork"
            assert.is_true(d:actionNeedsSeedType())
        end)

        it("returns false for 'bale_collect' on STEP_COURSEPLAY", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_COURSEPLAY
            d.stepAction = "bale_collect"
            assert.is_false(d:actionNeedsSeedType())
        end)

        it("returns false for STEP_AUTODRIVE", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_AUTODRIVE
            d.stepAction = "load"
            assert.is_false(d:actionNeedsSeedType())
        end)
    end)

    -- =========================================================================
    -- Seed type dropdown
    -- =========================================================================
    describe("seed type dropdown", function()
        local function dropdownDialog()
            local d = makeDialog()
            d.seedTypeItems = {{name = "BARLEY", display = "Barley"}, {name = "WHEAT", display = "Wheat"}}
            d.texts, d.state = nil, nil
            d.seedTypeDropdown = {
                setTexts = function(_, t) d.texts = t end,
                setState = function(_, i) d.state = i end,
            }
            return d
        end

        it("renders a 'none' entry ahead of the seed types", function()
            local d = dropdownDialog()
            d:refreshSeedTypeDropdown()
            assert.are.equal(3, #d.texts)
            assert.are.equal("Wheat", d.texts[3])
            assert.are.equal(1, d.state)
        end)

        it("selects the step's current seed type", function()
            local d = dropdownDialog()
            d.stepSeedFruitType = "WHEAT"
            d:refreshSeedTypeDropdown()
            assert.are.equal(3, d.state)
        end)

        it("maps a click against the rendered list", function()
            local d = dropdownDialog()
            d:refreshSeedTypeDropdown()
            d:onSeedTypeChanged(nil, 2)
            assert.are.equal("BARLEY", d.stepSeedFruitType)
            d:onSeedTypeChanged(nil, 1)
            assert.are.equal("", d.stepSeedFruitType)
        end)

        it("clears the seed type when the action can no longer carry one", function()
            local d = dropdownDialog()
            d.stepType         = WorkflowManager.STEP_COURSEPLAY
            d.stepAction       = "fieldwork"
            d.stepSeedFruitType = "WHEAT"
            d.actionDropdown   = nil
            d:onActionChanged(nil, 2)  -- bale_collect
            assert.are.equal("bale_collect", d.stepAction)
            assert.are.equal("", d.stepSeedFruitType)
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
            -- Load shows the route in driving order: first block = load point, second = target
            d.stepTarget       = "Farm"
            d.stepUnloadTarget = "Silo"
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

        it("includes seedFruitType for 'fieldwork' step on STEP_COURSEPLAY", function()
            local d = makeDialog()
            d.stepType          = WorkflowManager.STEP_COURSEPLAY
            d.stepAction        = "fieldwork"
            d.stepTarget        = "Field1"
            d.stepSeedFruitType = "WHEAT"
            local step = confirm(d)
            assert.are.equal("WHEAT", step.seedFruitType)
        end)

        it("does not include seedFruitType for 'bale_collect' on STEP_COURSEPLAY", function()
            local d = makeDialog()
            d.stepType          = WorkflowManager.STEP_COURSEPLAY
            d.stepAction        = "bale_collect"
            d.stepTarget        = "Field1"
            d.stepSeedFruitType = "WHEAT"
            local step = confirm(d)
            assert.is_nil(step.seedFruitType)
        end)

        it("does not include seedFruitType for STEP_AUTODRIVE step", function()
            local d = makeDialog()
            d.stepType          = WorkflowManager.STEP_AUTODRIVE
            d.stepAction        = "load"
            d.stepTarget        = "Farm"   -- load point (first block for Load)
            d.stepUnloadTarget  = "Silo"   -- target
            d.stepSeedFruitType = "WHEAT"  -- must be ignored for AD
            local step = confirm(d)
            assert.is_nil(step.seedFruitType)
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

        it("starts a new step as AutoDrive while AutoDrive is installed", function()
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end, false)
            assert.are.equal(WorkflowManager.STEP_AUTODRIVE, d.stepType)
            assert.are.equal("drive", d.stepAction)
        end)

        it("starts a new step as Courseplay when AutoDrive is missing", function()
            -- Otherwise the dropdown (which hides AutoDrive) and the step being edited
            -- disagree, and confirming would save an unrunnable AutoDrive step.
            _G.ADIntegration = { isAvailable = false }
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end, false)
            assert.are.equal(WorkflowManager.STEP_COURSEPLAY, d.stepType)
            assert.are.equal("fieldwork", d.stepAction)
            assert.are.equal(WorkflowManager.STEP_COURSEPLAY, d:getStepTypes()[1])
            _G.ADIntegration = { isAvailable = true }
        end)

        it("hides the four AD-driven types when AutoDrive is not installed", function()
            _G.ADIntegration = { isAvailable = false }
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end, false)
            local types = d:getStepTypes()
            assert.are.equal(3, #types)
            assert.are.equal(WorkflowManager.STEP_COURSEPLAY, types[1])
            assert.is_false(contains(types, WorkflowManager.STEP_AUTODRIVE))
            assert.is_false(contains(types, WorkflowManager.STEP_PARK))
            assert.is_false(contains(types, WorkflowManager.STEP_REFUEL))
            assert.is_false(contains(types, WorkflowManager.STEP_REPAIR))
            _G.ADIntegration = { isAvailable = true }
        end)

        it("leaves only Courseplay for support sub-steps without AutoDrive", function()
            _G.ADIntegration = { isAvailable = false }
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end, true)
            local types = d:getStepTypes()
            assert.are.equal(1, #types)
            assert.are.equal(WorkflowManager.STEP_COURSEPLAY, types[1])
            _G.ADIntegration = { isAvailable = true }
        end)

        it("re-lists an AD step type it is already editing without AutoDrive", function()
            -- Workflow authored while AD was installed, opened after AD was removed: the
            -- dropdown must show the step's real type so it can be converted, not relabelled.
            _G.ADIntegration = { isAvailable = false }
            local d = makeDialog()
            WMStepDialog.setStep(d, { type = WorkflowManager.STEP_REFUEL, target = "" },
                function() end, false)
            local types = d:getStepTypes()
            assert.is_true(contains(types, WorkflowManager.STEP_REFUEL))
            assert.is_false(contains(types, WorkflowManager.STEP_AUTODRIVE))
            assert.is_false(contains(types, WorkflowManager.STEP_PARK))
            _G.ADIntegration = { isAvailable = true }
        end)

        it("treats a missing ADIntegration global as AutoDrive unavailable", function()
            _G.ADIntegration = nil
            local d = makeDialog()
            WMStepDialog.setStep(d, nil, function() end, false)
            assert.is_false(d:isAutoDriveAvailable())
            assert.is_false(contains(d:getStepTypes(), WorkflowManager.STEP_AUTODRIVE))
            _G.ADIntegration = { isAvailable = true }
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
            d.statusText = {
                setText = function(self, t) self.text = t end,
                setTextColor = function(self, r) self.red = r end,
            }
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

        it("warns the player in the dialog's status line instead of doing nothing", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_AUTODRIVE
            d.stepAction = "drive"
            d.stepTarget = ""
            confirm(d)
            assert.are.equal("wm_warning_no_target", d.statusText.text)
            -- The game's blinking warning sits behind the open dialog: not used any more
            assert.are.equal(0, #warnings)
        end)

        it("blocks a Courseplay step with no course selected", function()
            local d = makeDialog()
            d.stepType   = WorkflowManager.STEP_COURSEPLAY
            d.stepAction = "fieldwork"
            d.stepTarget = ""
            local step, closed = confirm(d)
            assert.is_nil(step)
            assert.is_false(closed)
            assert.are.equal("wm_warning_no_target", d.statusText.text)
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

    -- =========================================================================
    -- "Finish before switching" (support sub-steps)
    -- =========================================================================
    describe("finish before switching", function()
        local function confirm(d)
            local result
            d.callback = function(s) result = s end
            d.close = function() end
            WMStepDialog.onClickConfirm(d)
            return result
        end

        local function makeDropdown()
            return {
                setTexts = function(self, t) self.texts = t end,
                setState = function(self, s) self.state = s end,
            }
        end

        it("is offered for support sub-steps that run a job", function()
            local d = makeDialog()
            d.isSupportStep = true
            for _, t in ipairs({ "autodrive", "courseplay", "park", "refuel", "repair" }) do
                d.stepType = t
                assert.is_true(d:canFinishBeforeSwitch())
            end
        end)

        it("is not offered for main steps or sync markers", function()
            local d = makeDialog()
            d.isSupportStep = false
            d.stepType = WorkflowManager.STEP_AUTODRIVE
            assert.is_false(d:canFinishBeforeSwitch())
            d.isSupportStep = true
            d.stepType = WorkflowManager.STEP_WAIT_FOR_LEADER
            assert.is_false(d:canFinishBeforeSwitch())
        end)

        it("loads the flag from the edited step; a new step starts with it off", function()
            local d = makeDialog()
            d:setStep({ type = "autodrive", action = "drive", target = "Silo", finishBeforeSwitch = true }, nil, true)
            assert.is_true(d.stepFinishBeforeSwitch)
            d:setStep(nil, nil, true)
            assert.is_false(d.stepFinishBeforeSwitch)
        end)

        it("renders No/Yes and selects the current value", function()
            local d = makeDialog()
            d.finishBeforeSwitchDropdown = makeDropdown()
            d.stepFinishBeforeSwitch = true
            d:refreshFinishBeforeSwitchDropdown()
            assert.are.same({ "wm_option_no", "wm_option_yes" }, d.finishBeforeSwitchDropdown.texts)
            assert.are.equal(2, d.finishBeforeSwitchDropdown.state)
        end)

        it("maps the dropdown state onto the flag", function()
            local d = makeDialog()
            d:onFinishBeforeSwitchChanged(nil, 2)
            assert.is_true(d.stepFinishBeforeSwitch)
            d:onFinishBeforeSwitchChanged(1)
            assert.is_false(d.stepFinishBeforeSwitch)
        end)

        it("saves the flag on a support sub-step", function()
            local d = makeDialog()
            d.isSupportStep = true
            d.stepType, d.stepAction, d.stepTarget = "autodrive", "drive", "Silo"
            d.stepFinishBeforeSwitch = true
            assert.is_true(confirm(d).finishBeforeSwitch)
        end)

        it("saves the flag on a targetless support sub-step (Park)", function()
            local d = makeDialog()
            d.isSupportStep = true
            d.stepType, d.stepTarget = WorkflowManager.STEP_PARK, ""
            d.stepFinishBeforeSwitch = true
            assert.is_true(confirm(d).finishBeforeSwitch)
        end)

        it("never writes the flag on a main step", function()
            local d = makeDialog()
            d.isSupportStep = false
            d.stepType, d.stepAction, d.stepTarget = "autodrive", "drive", "Silo"
            d.stepFinishBeforeSwitch = true
            assert.is_nil(confirm(d).finishBeforeSwitch)
        end)

        it("writes nothing when the flag is off", function()
            local d = makeDialog()
            d.isSupportStep = true
            d.stepType, d.stepAction, d.stepTarget = "autodrive", "drive", "Silo"
            d.stepFinishBeforeSwitch = false
            assert.is_nil(confirm(d).finishBeforeSwitch)
        end)
    end)

    -- =========================================================================
    -- Reopening the dialog (regression: fill types reset to the first list entry)
    -- =========================================================================
    describe("reopening", function()
        local function makeList()
            return {
                setDataSource = function() end,
                setCallback = function() end,
                reloadData = function() end,
                setSelectedIndex = function() end,
            }
        end

        local function makeOpenableDialog()
            _G.WMLogger = { debug = function() end }
            _G.WMHud = { onDialogOpened = function() end }
            WorkflowManager.editorDialog = {
                getFillTypes = function()
                    return { { name = "WHEAT", title = "Wheat" }, { name = "BARLEY", title = "Barley" } }
                end,
                getADDestinations = function() return { "Farm", "Silo" } end,
                getCPCourses = function() return {} end,
            }
            local d = makeDialog()
            d.fillTypeList, d.targetList, d.unloadTargetList = makeList(), makeList(), makeList()
            return d
        end

        -- What FS25 does while a dialog opens: re-raise the list's current selection (row 1)
        local function engineReraisesSelection(d)
            d.fillTypeList.onSelectionChanged(d.fillTypeList, 1, 1)
            d.targetList.onSelectionChanged(d.targetList, 1, 1)
            d.unloadTargetList.onSelectionChanged(d.unloadTargetList, 1, 1)
        end

        local step = { type = "autodrive", action = "pickup_deliver", target = "Silo",
                       unloadTarget = "Silo", fillTypes = { "BARLEY" } }

        before_each(function()
            superStub.onOpen = function() end
            WorkflowManager.editorDialog = nil
        end)

        it("keeps the step's fill type when the list re-raises its selection on the second open", function()
            local d = makeOpenableDialog()
            d:setStep(step, function() end)
            d:onOpen()
            d:update(0)

            d:setStep(step, function() end)
            superStub.onOpen = engineReraisesSelection   -- callbacks from the first open are live
            d:onOpen()
            engineReraisesSelection(d)                   -- and again on focus restore, after onOpen
            d:update(0)

            assert.are.same({ "BARLEY" }, d.selectedFillTypes)
            assert.are.equal("Silo", d.stepTarget)
            assert.are.equal("Silo", d.stepUnloadTarget)
        end)

        it("applies list clicks again once the dialog has updated", function()
            local d = makeOpenableDialog()
            d:setStep(step, function() end)
            d:onOpen()
            d:update(0)

            d.fillTypeList.onSelectionChanged(d.fillTypeList, 1, 1)
            assert.are.same({ "WHEAT" }, d.selectedFillTypes)
        end)
    end)

    -- =========================================================================
    -- Regression: a route list reloaded while hidden showed the PREVIOUS step's target
    -- =========================================================================
    describe("reopening after a list was hidden", function()
        -- The parts of FS25's SmoothListElement that matter here: reloadData on a hidden list
        -- stores the old selection (setNextOpenIndex), the list's own onOpen - which runs AFTER
        -- the dialog's onOpen - re-applies it, and onFocusEnter re-announces the selection.
        local function makeEngineList(container, dialog)
            local list = { selectedIndex = 1 }
            list.setDataSource = function() end
            list.setCallback = function() end
            list.reloadData = function(self)
                if container.visible == false then
                    self.setNextOpenIndex = self.selectedIndex
                    self.setNextOpenSectionIndex = 1
                end
            end
            list.setSelectedIndex = function(self, i) self.selectedIndex = i end
            list.onOpen = function(self)
                if self.setNextOpenIndex ~= nil then
                    self.selectedIndex = self.setNextOpenIndex
                    self.setNextOpenIndex = nil
                end
            end
            list.onFocusEnter = function(self) dialog:onListSelectionChanged(self, 1, self.selectedIndex) end
            return list
        end

        local function container()
            return { setVisible = function(self, v) self.visible = v end }
        end

        local function makeOpenableDialog()
            _G.WMLogger = { debug = function() end }
            _G.WMHud = { onDialogOpened = function() end }
            WorkflowManager.editorDialog = {
                getFillTypes = function() return {} end,
                getADDestinations = function() return { "Farm", "Silo" } end,
                getCPCourses = function() return {} end,
            }
            local d = makeDialog()
            d.targetDropdownContainer, d.unloadTargetDropdownContainer = container(), container()
            d.targetList = makeEngineList(d.targetDropdownContainer, d)
            d.unloadTargetList = makeEngineList(d.unloadTargetDropdownContainer, d)
            return d
        end

        -- showDialog: the dialog's onOpen, then the lists' onOpen, then the first update
        local function open(d, step)
            d:setStep(step, function() end)
            d:onOpen()
            d.targetList:onOpen()
            d.unloadTargetList:onOpen()
            d:update(0)
        end

        before_each(function()
            superStub.onOpen = function() end
            WorkflowManager.editorDialog = nil
        end)

        it("keeps the unload target when the previous step hid the unload list", function()
            local d = makeOpenableDialog()
            open(d, { type = "autodrive", action = "unload", target = "Farm", unloadTarget = "Silo" })
            open(d, { type = "autodrive", action = "drive", target = "Silo" })
            open(d, { type = "autodrive", action = "unload", target = "Silo", unloadTarget = "Farm" })

            assert.are.equal(1, d.unloadTargetList.selectedIndex)
            d.unloadTargetList:onFocusEnter()
            assert.are.equal("Farm", d.stepUnloadTarget)
        end)

        it("keeps the target when the previous step hid the target list", function()
            local d = makeOpenableDialog()
            open(d, { type = "autodrive", action = "drive", target = "Silo" })
            open(d, { type = "park" })
            open(d, { type = "autodrive", action = "drive", target = "Farm" })

            assert.are.equal(1, d.targetList.selectedIndex)
            d.targetList:onFocusEnter()
            assert.are.equal("Farm", d.stepTarget)
        end)
    end)

    -- =========================================================================
    -- UI review 2026-10-17: Load in driving order, subtitle, "(none)" line, course names
    -- =========================================================================
    describe("Load shows the route in driving order", function()
        local function textEl()
            local el = {}
            el.setText = function(self, t) self.text = t end
            el.setTextColor = function(self, r, g, b, a) self.color = { r, g, b, a } end
            el.setVisible = function(self, v) self.visible = v end
            return el
        end

        local function confirm(d)
            local result
            d.close = function() end
            d.callback = function(s) result = s end
            WMStepDialog.onClickConfirm(d)
            return result
        end

        before_each(function()
            _G.g_i18n = { getText = function(_, key) return key end }
            _G.WMLogger = { debug = function() end, warning = function() end }
        end)

        local loadStep = { type = "autodrive", action = "load", target = "Field 9", unloadTarget = "Grain Silo" }

        it("puts the load point in the first block when a Load step opens", function()
            local d = makeDialog()
            d:setStep(loadStep, function() end)
            assert.are.equal("Grain Silo", d.stepTarget)
            assert.are.equal("Field 9", d.stepUnloadTarget)
        end)

        it("saves target and load point unchanged", function()
            local d = makeDialog()
            d:setStep(loadStep, function() end)
            local step = confirm(d)
            assert.are.equal("Field 9", step.target)
            assert.are.equal("Grain Silo", step.unloadTarget)
        end)

        it("leaves the order of other actions alone", function()
            local d = makeDialog()
            d:setStep({ type = "autodrive", action = "pickup_deliver", target = "Field 9", unloadTarget = "Silo" },
                function() end)
            assert.are.equal("Field 9", d.stepTarget)
            assert.are.equal("Silo", d.stepUnloadTarget)
        end)

        it("moves the values when the action changes into and out of Load", function()
            local d = makeDialog()
            d:setStep({ type = "autodrive", action = "pickup_deliver", target = "Field 9", unloadTarget = "Silo" },
                function() end)
            d:onActionChanged(nil, 4)   -- load
            assert.are.equal("Silo", d.stepTarget)
            assert.are.equal("Field 9", d.stepUnloadTarget)
            d:onActionChanged(nil, 2)   -- pickup_deliver
            assert.are.equal("Field 9", d.stepTarget)
            assert.are.equal("Silo", d.stepUnloadTarget)
        end)

        it("asks for the target (second block) when a Load step has none", function()
            local d = makeDialog()
            d.showStatus = function(self, text) self.status = text end
            d:setStep({ type = "autodrive", action = "load", target = "", unloadTarget = "Grain Silo" }, function() end)
            assert.is_nil(confirm(d))
            assert.are.equal("wm_warning_no_target", d.status)
        end)

        it("labels the blocks Load At / Deliver To for Load, Target otherwise", function()
            local d = makeDialog()
            d.targetLabel, d.unloadTargetLabel = textEl(), textEl()
            d:setStep(loadStep, function() end)
            d:updateFieldVisibility()
            assert.are.equal("wm_editor_load_target", d.targetLabel.text)
            assert.are.equal("wm_editor_unload_target", d.unloadTargetLabel.text)
            d.stepAction = "drive"
            d:updateFieldVisibility()
            assert.are.equal("wm_editor_target", d.targetLabel.text)
        end)

        it("shows the subtitle the editor passes, and hides an empty one", function()
            local d = makeDialog()
            d.titleElement, d.subtitleElement = textEl(), textEl()
            d:setStep(nil, function() end, false, "Grass Chopping · step 3")
            d:refreshDisplay()
            assert.are.equal("Grass Chopping · step 3", d.subtitleElement.text)
            assert.is_true(d.subtitleElement.visible)
            d:setStep(nil, function() end)
            d:refreshDisplay()
            assert.is_false(d.subtitleElement.visible)
        end)

        it("says (none) in amber when no target is selected", function()
            local d = makeDialog()
            d.selectedUnloadTargetLabel = textEl()
            d:updateSelectedLabel("unloadTarget", nil)
            assert.are.equal("wm_step_selected: wm_step_selected_none", d.selectedUnloadTargetLabel.text)
            assert.are.same({ 1, 0.8, 0.3, 1 }, d.selectedUnloadTargetLabel.color)
            d:updateSelectedLabel("unloadTarget", "Silo")
            assert.are.equal("wm_step_selected: Silo", d.selectedUnloadTargetLabel.text)
            assert.are.same({ 1, 1, 1, 1 }, d.selectedUnloadTargetLabel.color)
        end)

        it("lists courses without the Singleplayer/ prefix but keeps the stored name", function()
            WorkflowManager.editorDialog = {
                getADDestinations = function() return {} end,
                getCPCourses = function() return { "Singleplayer/F49/Chopping" } end,
            }
            local d = makeDialog()
            d.stepType = WorkflowManager.STEP_COURSEPLAY
            d:refreshTargetList()
            assert.are.equal("Singleplayer/F49/Chopping", d.targetItems[1].name)
            assert.are.equal("F49/Chopping", d.targetItems[1].display)
            WorkflowManager.editorDialog = nil
        end)
    end)

    describe("list row text on the highlight bar", function()
        -- Rows recolour textColor per cell (selected fill type green). TextElement falls back to
        -- textColor for a selected row when the profile has no textSelectedColor, which drew
        -- "» Wheat" green on the cyan bar (unreadable, seen in the 2026-11-08 screenshots).
        it("wm_listItemText draws the highlighted row white", function()
            local f = assert(io.open("xml/gui/guiProfiles.xml", "r"))
            local xml = f:read("*a")
            f:close()
            local body = xml:match('<Profile name="wm_listItemText".-</Profile>')
            assert.is_not_nil(body)
            assert.is_truthy(body:find('<textSelectedColor value="1 1 1 1"/>', 1, true))
        end)

        it("the fill type list uses that profile", function()
            local f = assert(io.open("xml/gui/WMStepDialog.xml", "r"))
            local xml = f:read("*a")
            f:close()
            assert.is_truthy(xml:find('name="fillTypeText" profile="wm_listItemText"', 1, true))
        end)
    end)

end)
