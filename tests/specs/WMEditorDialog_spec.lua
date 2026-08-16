--[[
    WMEditorDialog Unit Tests

    Focus: the edit-buffer contract. WMEditorDialog edits a deep copy of the workflow
    (self.workflow) and only writes it back to the live table (self.sourceWorkflow) in
    onClickSave -> commitToSource. Cancel must leave the live workflow untouched.

    commitToSource must mutate the live table IN PLACE, because a running execution holds
    a direct reference to it via activeData.workflow (and so does WorkflowManager.workflows).
]]

describe("WMEditorDialog", function()

    setup(function()
        _G.Class = function(cls, parent)
            if parent then
                cls.superClass = function()
                    return {
                        onOpen  = function() end,
                        onClose = function() end,
                        update  = function() end,
                    }
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
            saveWorkflows    = function() end,
            showMainDialog   = function() end,
            showStepDialog   = function() end,
            addSupportStep   = function()
                error("commitToSource contract violated: addSupportStep writes the live table")
            end,

            -- Workflow list + registration, mirroring the production implementations so the
            -- tests below assert the dialog's orchestration (does it register, once, and only
            -- on Save) rather than re-testing WorkflowManager itself.
            workflows = {},
            getWorkflowById = function(self, id)
                for _, wf in ipairs(self.workflows) do
                    if wf.id == id then return wf end
                end
                return nil
            end,
            registerWorkflow = function(self, workflow)
                if workflow == nil then return false end
                if self:getWorkflowById(workflow.id) ~= nil then return false end
                table.insert(self.workflows, workflow)
                return true
            end,
        }

        _G.CPCoursesLoader  = nil
        _G.CPVehiclesLoader = nil

        dofile("src/gui/WMEditorDialog.lua")
    end)

    -- A workflow shaped like a real one: 2 main steps, one with a support sub-step
    local function makeWorkflow()
        return {
            id   = "wf_edit",
            name = "Original Name",
            steps = {
                { type = "autodrive",  target = "Farm",   action = "drive",     support = {} },
                { type = "courseplay", target = "Field1", action = "fieldwork", support = {
                    { type = "autodrive", target = "Silo", action = "deliver" },
                }},
            },
            adSettings = { unloadFillLevel = 0.9 },
        }
    end

    -- Dialog with the GUI elements the tested methods touch stubbed out
    local function makeDialog(workflow)
        local d = WMEditorDialog.new()
        d.stepList  = nil          -- refreshStepList early-returns without a list
        d.nameInput = nil
        d.close     = function() end
        if workflow then d:setWorkflow(workflow) end
        return d
    end

    -- =========================================================================
    -- setWorkflow: buffer is an independent copy
    -- =========================================================================
    describe("setWorkflow", function()
        it("keeps a reference to the live workflow as sourceWorkflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            assert.are.equal(wf, d.sourceWorkflow)
        end)

        it("exposes a copy, not the live table, as the edit buffer", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            assert.is_not_nil(d.workflow)
            assert.are_not.equal(wf, d.workflow)
        end)

        it("copies nested step and support tables rather than sharing them", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            assert.are_not.equal(wf.steps, d.workflow.steps)
            assert.are_not.equal(wf.steps[1], d.workflow.steps[1])
            assert.are_not.equal(wf.steps[2].support, d.workflow.steps[2].support)
            assert.are_not.equal(wf.steps[2].support[1], d.workflow.steps[2].support[1])
        end)

        it("copies values faithfully", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            assert.are.equal("Original Name", d.workflow.name)
            assert.are.equal(2, #d.workflow.steps)
            assert.are.equal("Farm", d.workflow.steps[1].target)
            assert.are.equal(0.9, d.workflow.adSettings.unloadFillLevel)
        end)

        it("handles a nil workflow", function()
            local d = makeDialog()
            d:setWorkflow(nil)
            assert.is_nil(d.workflow)
            assert.is_nil(d.sourceWorkflow)
        end)
    end)

    -- =========================================================================
    -- Cancel discards
    -- =========================================================================
    describe("onClickCancel", function()
        it("does not apply an added step to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            table.insert(d.workflow.steps, { type = "autodrive", target = "New", support = {} })
            d:onClickCancel()
            assert.are.equal(2, #wf.steps)
        end)

        it("does not apply a removed step to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            table.remove(d.workflow.steps, 1)
            d:onClickCancel()
            assert.are.equal(2, #wf.steps)
            assert.are.equal("Farm", wf.steps[1].target)
        end)

        it("does not apply a renamed workflow to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            d.workflow.name = "Renamed"
            d:onClickCancel()
            assert.are.equal("Original Name", wf.name)
        end)

        it("does not apply a reordered step list to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            local s = d.workflow.steps
            s[1], s[2] = s[2], s[1]
            d:onClickCancel()
            assert.are.equal("autodrive", wf.steps[1].type)
            assert.are.equal("courseplay", wf.steps[2].type)
        end)

        it("does not apply an edited support sub-step to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            d.workflow.steps[2].support[1].target = "OtherSilo"
            d:onClickCancel()
            assert.are.equal("Silo", wf.steps[2].support[1].target)
        end)

        it("does not apply changed adSettings to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            d.workflow.adSettings = { unloadFillLevel = 0.1 }
            d:onClickCancel()
            assert.are.equal(0.9, wf.adSettings.unloadFillLevel)
        end)

        it("clears the buffer so a stale workflow cannot be committed later", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            d.workflow.name = "Renamed"
            d:onClickCancel()
            assert.is_nil(d.workflow)
            assert.is_nil(d.sourceWorkflow)
            d:commitToSource()  -- must be a no-op, not an error
            assert.are.equal("Original Name", wf.name)
        end)
    end)

    -- =========================================================================
    -- Save commits
    -- =========================================================================
    describe("onClickSave", function()
        it("blocks Save while the workflow is executing on a vehicle", function()
            -- Regression: Save swapped steps under a running execution, desyncing
            -- currentStep and the followers' sync maps.
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            table.insert(d.workflow.steps, { type = "park", target = "", support = {} })

            local origExec = _G.WMExecutor
            _G.WMExecutor = {
                getActiveVehiclesForWorkflow = function(self, workflowId)
                    if workflowId == wf.id then return { { vehicle = {} } } end
                    return {}
                end,
            }
            d:onClickSave()
            _G.WMExecutor = origExec

            -- Nothing committed; the edit buffer is still open
            assert.are.equal(2, #wf.steps)
            assert.is_not_nil(d.workflow)
        end)

        it("applies an added step to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            table.insert(d.workflow.steps, { type = "park", target = "", support = {} })
            d:onClickSave()
            assert.are.equal(3, #wf.steps)
            assert.are.equal("park", wf.steps[3].type)
        end)

        it("applies a removed step to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            table.remove(d.workflow.steps, 1)
            d:onClickSave()
            assert.are.equal(1, #wf.steps)
            assert.are.equal("courseplay", wf.steps[1].type)
        end)

        it("applies a rename to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            d.workflow.name = "Renamed"
            d:onClickSave()
            assert.are.equal("Renamed", wf.name)
        end)

        it("applies support sub-step edits to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            table.insert(d.workflow.steps[2].support, { type = "refuel", target = "" })
            d:onClickSave()
            assert.are.equal(2, #wf.steps[2].support)
            assert.are.equal("refuel", wf.steps[2].support[2].type)
        end)

        it("applies changed adSettings to the live workflow", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            d.workflow.adSettings = { unloadFillLevel = 0.25, pipeOffset = 1.5 }
            d:onClickSave()
            assert.are.equal(0.25, wf.adSettings.unloadFillLevel)
            assert.are.equal(1.5, wf.adSettings.pipeOffset)
        end)

        it("mutates the live workflow in place so held references stay valid", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            -- Stand-in for activeData.workflow, captured before editing
            local heldByExecutor = wf
            d.workflow.name = "Renamed"
            table.insert(d.workflow.steps, { type = "park", target = "", support = {} })
            d:onClickSave()
            assert.are.equal("Renamed", heldByExecutor.name)
            assert.are.equal(3, #heldByExecutor.steps)
        end)

        it("does not leave the committed steps aliased to the buffer", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            d:onClickSave()
            -- Editing the buffer after a commit must not leak into the live workflow
            d.workflow.steps[1].target = "Leaked"
            assert.are.equal("Farm", wf.steps[1].target)
        end)

        it("prefers the name input over the buffer name when present", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            d.nameInput = { text = "From Input" }
            d:onClickSave()
            assert.are.equal("From Input", wf.name)
        end)
    end)

    -- =========================================================================
    -- New workflows are registered on Save, not on open, so cancelling out of
    -- the editor leaves no empty entry in the workflow list.
    -- =========================================================================
    describe("new workflow registration", function()
        before_each(function()
            WorkflowManager.workflows = {}
        end)

        -- Mirrors WMMainDialog:onClickNew — build (unregistered) then open as new
        local function makeNewWorkflow()
            return { id = "wf_new", name = "New Workflow", steps = {} }
        end

        it("is not in the workflow list while the editor is open", function()
            local wf = makeNewWorkflow()
            makeDialog():setWorkflow(wf, true)
            assert.are.equal(0, #WorkflowManager.workflows)
        end)

        it("marks the dialog as editing a new workflow", function()
            local d = makeDialog()
            d:setWorkflow(makeNewWorkflow(), true)
            assert.is_true(d.isNewWorkflow)
        end)

        it("defaults to not-new when the flag is omitted", function()
            local d = makeDialog()
            d:setWorkflow(makeWorkflow())
            assert.is_false(d.isNewWorkflow)
        end)

        it("is added to the workflow list on Save", function()
            local wf = makeNewWorkflow()
            local d = makeDialog()
            d:setWorkflow(wf, true)
            d.workflow.name = "My Workflow"
            table.insert(d.workflow.steps, { type = "autodrive", target = "Farm", support = {} })
            d:onClickSave()
            assert.are.equal(1, #WorkflowManager.workflows)
            assert.are.equal(wf, WorkflowManager.workflows[1])
            assert.are.equal("My Workflow", WorkflowManager.workflows[1].name)
            assert.are.equal(1, #WorkflowManager.workflows[1].steps)
        end)

        it("is NOT added to the workflow list on Cancel", function()
            local d = makeDialog()
            d:setWorkflow(makeNewWorkflow(), true)
            d.workflow.name = "Abandoned"
            table.insert(d.workflow.steps, { type = "autodrive", target = "Farm", support = {} })
            d:onClickCancel()
            assert.are.equal(0, #WorkflowManager.workflows)
        end)

        it("clears the new flag on Cancel so a later commit cannot resurrect it", function()
            local d = makeDialog()
            d:setWorkflow(makeNewWorkflow(), true)
            d:onClickCancel()
            assert.is_false(d.isNewWorkflow)
            d:commitToSource()
            assert.are.equal(0, #WorkflowManager.workflows)
        end)

        it("does not register twice if commitToSource runs again", function()
            local d = makeDialog()
            d:setWorkflow(makeNewWorkflow(), true)
            d:onClickSave()
            d:commitToSource()
            assert.are.equal(1, #WorkflowManager.workflows)
        end)

        it("does not re-add an existing workflow that is edited and saved", function()
            local wf = makeWorkflow()
            WorkflowManager.workflows = { wf }
            local d = makeDialog(wf)
            d.workflow.name = "Renamed"
            d:onClickSave()
            assert.are.equal(1, #WorkflowManager.workflows)
            assert.are.equal("Renamed", WorkflowManager.workflows[1].name)
        end)

        it("keeps workflows added by other means untouched", function()
            local other = { id = "wf_other", name = "Other", steps = {} }
            WorkflowManager.workflows = { other }
            local d = makeDialog()
            d:setWorkflow(makeNewWorkflow(), true)
            d:onClickSave()
            assert.are.equal(2, #WorkflowManager.workflows)
            assert.are.equal(other, WorkflowManager.workflows[1])
        end)
    end)

    -- =========================================================================
    -- Move Up / Move Down / Add Support button states
    --
    -- The row types have different limits: a main step moves within workflow.steps
    -- (carrying its sub-steps), a support sub-step only within its own parent's list.
    -- Clicking a row does not raise onSelectionChanged in FS25, so update() polls the
    -- list's selectedIndex — without that the buttons describe the previous row.
    -- =========================================================================
    describe("button states", function()
        local function makeButton()
            return {
                disabled = false,
                setDisabled = function(self, value) self.disabled = value end,
            }
        end

        -- Flat rows of makeWorkflow(): 1 = main step 1, 2 = main step 2, 3 = its support 2.1
        local function makeListDialog(workflow)
            local d = makeDialog(workflow or makeWorkflow())
            d.editStepButton       = makeButton()
            d.removeStepButton     = makeButton()
            d.moveUpButton         = makeButton()
            d.moveDownButton       = makeButton()
            d.addSupportStepButton = makeButton()
            d.stepList = {
                selectedIndex    = 0,
                setSelectedIndex = function(self, index) self.selectedIndex = index end,
                reloadData       = function() end,
            }
            d:buildFlatList()
            return d
        end

        ---Select a flat row the way a mouse click does: the list's index moves, no callback
        local function clickRow(d, flatIndex)
            d.stepList.selectedIndex = flatIndex
            d:update(16)
        end

        it("disables Up on the first main step and enables Down", function()
            local d = makeListDialog()
            clickRow(d, 1)
            assert.is_true(d.moveUpButton.disabled)
            assert.is_false(d.moveDownButton.disabled)
        end)

        it("enables Up on the last main step and disables Down", function()
            local d = makeListDialog()
            clickRow(d, 2)
            assert.is_false(d.moveUpButton.disabled)
            assert.is_true(d.moveDownButton.disabled)
        end)

        it("updates the states when the selection switches rows (regression)", function()
            -- The states used to keep describing the previously selected row, so Up stayed
            -- disabled after moving off row 1 and Down stayed enabled.
            local d = makeListDialog()
            clickRow(d, 1)
            clickRow(d, 2)
            assert.is_false(d.moveUpButton.disabled)
            assert.is_true(d.moveDownButton.disabled)
        end)

        it("disables both directions for an only-child support sub-step", function()
            local d = makeListDialog()
            clickRow(d, 3)
            assert.is_true(d.moveUpButton.disabled)
            assert.is_true(d.moveDownButton.disabled)
        end)

        it("bounds a support sub-step by its own parent, not by the whole step list", function()
            local wf = makeWorkflow()
            table.insert(wf.steps[2].support, { type = "park", action = nil })
            local d = makeListDialog(wf)

            clickRow(d, 3)                              -- support 2.1 of 2
            assert.is_true(d.moveUpButton.disabled)     -- first in its parent
            assert.is_false(d.moveDownButton.disabled)

            clickRow(d, 4)                              -- support 2.2 of 2
            assert.is_false(d.moveUpButton.disabled)
            assert.is_true(d.moveDownButton.disabled)   -- last in its parent
        end)

        it("keeps Add Support for main steps only", function()
            local d = makeListDialog()
            clickRow(d, 2)
            assert.is_false(d.addSupportStepButton.disabled)
            clickRow(d, 3)
            assert.is_true(d.addSupportStepButton.disabled)
        end)

        it("allows Edit and Remove on support sub-steps", function()
            local d = makeListDialog()
            clickRow(d, 3)
            assert.is_false(d.editStepButton.disabled)
            assert.is_false(d.removeStepButton.disabled)
        end)

        it("disables every step button without a selection", function()
            local d = makeListDialog()
            d.workflow.steps = {}
            d:buildFlatList()
            d.selectedFlatIndex = 0
            d:updateButtons()
            assert.is_true(d.editStepButton.disabled)
            assert.is_true(d.removeStepButton.disabled)
            assert.is_true(d.moveUpButton.disabled)
            assert.is_true(d.moveDownButton.disabled)
            assert.is_true(d.addSupportStepButton.disabled)
        end)
    end)

    -- =========================================================================
    -- commitToSource guards
    -- =========================================================================
    describe("commitToSource", function()
        it("is a no-op when no workflow was set", function()
            local d = makeDialog()
            assert.has_no.errors(function() d:commitToSource() end)
        end)

        it("normalises a missing steps array to an empty table", function()
            local wf = makeWorkflow()
            local d = makeDialog(wf)
            d.workflow.steps = nil
            d:commitToSource()
            assert.is_table(wf.steps)
            assert.are.equal(0, #wf.steps)
        end)
    end)

end)
