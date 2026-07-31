--[[
    WMMainDialog Unit Tests

    Focus: the New-workflow flow. onClickNew must hand the editor an *unregistered* workflow
    (buildWorkflow, not createWorkflow) flagged as new, so that cancelling out of the editor
    leaves no empty entry in the workflow list. The editor registers it on Save
    (see WMEditorDialog_spec > "new workflow registration").
]]

describe("WMMainDialog", function()

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

        dofile("src/gui/WMMainDialog.lua")
    end)

    -- Records what onClickNew / onClickEdit did, without touching the real manager
    local shown

    before_each(function()
        shown = nil
        _G.WorkflowManager = {
            workflows = {},
            nextId = 0,
            -- Unregistered builder (production: WorkflowManager:buildWorkflow)
            buildWorkflow = function(self, name)
                self.nextId = self.nextId + 1
                return { id = "wf_" .. self.nextId, name = name or "New Workflow", steps = {} }
            end,
            -- Registering builder (production: WorkflowManager:createWorkflow)
            createWorkflow = function(self, name)
                local wf = self:buildWorkflow(name)
                table.insert(self.workflows, wf)
                return wf
            end,
            showEditorDialog = function(self, workflow, isNew)
                shown = { workflow = workflow, isNew = isNew }
            end,
            getWorkflows = function(self) return self.workflows end,
        }
    end)

    local function makeDialog()
        local d = WMMainDialog.new()
        d.close = function() end
        d.workflowList = nil   -- refreshWorkflowList early-returns without a list
        return d
    end

    describe("onClickNew", function()
        it("opens the editor with a workflow", function()
            local d = makeDialog()
            d:onClickNew()
            assert.is_not_nil(shown)
            assert.is_not_nil(shown.workflow)
        end)

        it("does NOT add the workflow to the list before the editor confirms", function()
            local d = makeDialog()
            d:onClickNew()
            assert.are.equal(0, #WorkflowManager.workflows)
        end)

        it("flags the workflow as new so the editor registers it on Save", function()
            local d = makeDialog()
            d:onClickNew()
            assert.is_true(shown.isNew)
        end)

        it("leaves nothing behind when the editor is cancelled", function()
            -- Cancelling is modelled by the editor simply never registering the workflow
            local d = makeDialog()
            d:onClickNew()
            assert.are.equal(0, #WorkflowManager.workflows)
            assert.is_nil(WorkflowManager.workflows[1])
        end)

        it("produces a workflow with a fresh id and no steps", function()
            local d = makeDialog()
            d:onClickNew()
            assert.is_string(shown.workflow.id)
            assert.is_table(shown.workflow.steps)
            assert.are.equal(0, #shown.workflow.steps)
        end)
    end)

    describe("onClickEdit", function()
        it("opens an existing workflow without the new flag", function()
            local existing = { id = "wf_existing", name = "Existing", steps = {} }
            WorkflowManager.workflows = { existing }
            local d = makeDialog()
            d.workflows = WorkflowManager.workflows
            d.selectedWorkflowIndex = 1
            d:onClickEdit()
            assert.are.equal(existing, shown.workflow)
            assert.is_true(shown.isNew ~= true)
        end)

        it("does nothing without a selection", function()
            local d = makeDialog()
            d.workflows = {}
            d.selectedWorkflowIndex = 0
            d:onClickEdit()
            assert.is_nil(shown)
        end)
    end)

end)
