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
    local notifications
    local userMessages   -- WorkflowManager:showUserMessage calls (queued for after the dialog)
    local mouseCursorShown
    local events   -- ordered log of "close" / "start" for the start-flow ordering contract

    before_each(function()
        shown = nil
        events = {}
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
            getVehicleWorkflowState = function() return nil end,
            -- Models the async start contract: onStarted fires only when the start command
            -- is actually dispatched. startDeferred simulates a mode/leader dialog still
            -- being open (or the player cancelling it): flow initiated, nothing started yet.
            canStartWorkflow = function(self)
                if self.startResult then return true end
                return false, "wm_warning_no_vehicle"
            end,
            startWorkflow = function(self, id, onStarted)
                table.insert(events, "start")
                if self.startResult and not self.startDeferred and onStarted then onStarted() end
                return self.startResult
            end,
            startResult = true,
            startDeferred = false,

            -- AD/CP settings is a child dialog: the main dialog has to close before it opens
            -- and reopen when it returns, so the two never sit on the GUI stack together.
            adCallback = nil,
            showADSettingsDialog = function(self, settings, callback)
                table.insert(events, "showAD")
                self.adCallback = callback
            end,
            showMainDialog = function() table.insert(events, "reopenMain") end,
            saveWorkflows  = function() table.insert(events, "save") end,
            -- The file is the source of truth: reload, change, save
            reloadWorkflows = function() table.insert(events, "reload") end,
            applyWorkflowChange = function(self, change)
                table.insert(events, "reload")
                change()
                table.insert(events, "save")
            end,
            registerWorkflow = function(self, wf) table.insert(events, "register") end,
            deleteWorkflow = function(self, id) table.insert(events, "delete:" .. id) end,
            stopWorkflow = function(self, id) table.insert(events, "stop:" .. id) end,
            showUserMessage = function(self, text, isError)
                table.insert(userMessages, { text = text, isError = isError })
            end,
        }
        userMessages = {}

        notifications = {}
        _G.FSBaseMission = { INGAME_NOTIFICATION_OK = 1, INGAME_NOTIFICATION_CRITICAL = 2 }
        _G.g_currentMission = {
            controlledVehicle = nil,
            addIngameNotification = function(self, kind, text)
                table.insert(notifications, { kind = kind, text = text })
            end,
        }
        _G.g_i18n = { getText = function(self, key) return key end }

        -- The dialog hands the cursor to the HUD, which owns it from there on
        mouseCursorShown = false
        _G.WMHud = {
            setMouseCursorActive = function(_, active) mouseCursorShown = active end,
            onDialogOpened = function() end,
            onDialogClosed = function() end,
        }
    end)

    local function makeDialog()
        local d = WMMainDialog.new()
        d.closed = false
        d.close = function(self) self.closed = true; table.insert(events, "close") end
        d.workflowList = nil   -- refreshWorkflowList early-returns without a list
        d.statusText = {
            text = nil, color = nil,
            setText = function(self, t) self.text = t end,
            setTextColor = function(self, r, g, b, a) self.color = { r, g, b, a } end,
        }
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

    describe("onClickStart", function()
        local function makeStartDialog()
            local d = makeDialog()
            d.workflows = { { id = "wf_1", name = "Harvest", steps = {} } }
            d.selectedWorkflowIndex = 1
            return d
        end

        it("closes the dialog once the workflow is running", function()
            WorkflowManager.startResult = true
            local d = makeStartDialog()
            d:onClickStart()
            assert.is_true(d.closed)
        end)

        it("still tells the player that the workflow started (queued, the dialog is closed)", function()
            WorkflowManager.startResult = true
            local d = makeStartDialog()
            d:onClickStart()
            assert.are.equal(1, #userMessages)
            assert.is_false(userMessages[1].isError)
            assert.are.equal(0, #notifications)
        end)

        it("hands the mouse cursor to the HUD so it stays clickable", function()
            WorkflowManager.startResult = true
            local d = makeStartDialog()
            d:onClickStart()
            assert.is_true(mouseCursorShown)
        end)

        it("closes BEFORE the start flow opens the leader/mode dialog (regression)", function()
            -- Closing afterwards tore the GUI cursor state out from under the child dialog,
            -- leaving the leader-select dialog without a mouse pointer.
            WorkflowManager.startResult = true
            local d = makeStartDialog()
            d:onClickStart()
            assert.are.same({ "close", "start" }, events)
        end)

        it("does not start when the workflow cannot start", function()
            WorkflowManager.startResult = false
            local d = makeStartDialog()
            d:onClickStart()
            assert.are.same({}, events)
        end)

        it("stays open and shows the reason in its status line when the start fails", function()
            WorkflowManager.startResult = false
            local d = makeStartDialog()
            d:onClickStart()
            assert.is_false(d.closed)
            assert.are.equal("wm_warning_no_vehicle", d.statusText.text)
            assert.are.equal(1, d.statusText.color[1])     -- red
            assert.are.equal(0.35, d.statusText.color[2])
        end)

        it("does not use the game's notifications while the dialog is open", function()
            WorkflowManager.startResult = false
            local d = makeStartDialog()
            d:onClickStart()
            assert.are.equal(0, #notifications)
        end)

        it("does NOT claim success while a mode/leader dialog is still deciding (regression)", function()
            -- startWorkflow returned true after merely OPENING the mode-select dialog;
            -- the old code showed 'Workflow started' even if the player then cancelled.
            WorkflowManager.startResult = true
            WorkflowManager.startDeferred = true
            local d = makeStartDialog()
            d:onClickStart()
            WorkflowManager.startDeferred = false

            assert.is_true(d.closed)              -- main dialog steps aside for the next dialog
            assert.are.equal(0, #userMessages)    -- but no success message yet
            assert.is_false(mouseCursorShown)     -- and the cursor was not handed over
        end)

        it("does nothing without a selection", function()
            local d = makeDialog()
            d.workflows = {}
            d.selectedWorkflowIndex = 0
            d:onClickStart()
            assert.is_false(d.closed)
            assert.are.equal(0, #notifications)
        end)
    end)

    describe("onClickStop", function()
        it("stops the workflow and reports it in the status line", function()
            local d = makeDialog()
            d.workflows = { { id = "wf_1", name = "Harvest", steps = {} } }
            d.selectedWorkflowIndex = 1
            d:onClickStop()
            assert.are.same({ "stop:wf_1" }, events)
            assert.are.equal("wm_workflow_stopped", d.statusText.text)
            assert.are.equal(0, #notifications)
        end)
    end)

    describe("onOpen", function()
        it("reloads the workflow file and clears the status line", function()
            _G.WMLogger = _G.WMLogger or { debug = function() end }
            local d = makeDialog()
            d.statusText.text = "old message"
            d.registerInputEvents = function() end
            local refreshedAfterReload = false
            d.refreshWorkflowList = function() refreshedAfterReload = events[#events] == "reload" end

            d:onOpen()

            assert.are.equal("", d.statusText.text)
            assert.are.same({ "reload" }, events)
            assert.is_true(refreshedAfterReload)
        end)
    end)

    describe("onClickDelete", function()
        it("deletes through applyWorkflowChange (reload, delete, save)", function()
            _G.YesNoDialog = { show = function(callback, target) callback(nil, true) end }
            local d = makeDialog()
            d.workflows = { { id = "wf_1", name = "Harvest", steps = {} } }
            d.selectedWorkflowIndex = 1
            d.refreshWorkflowList = function() end

            d:onClickDelete()

            assert.are.same({ "reload", "delete:wf_1", "save" }, events)
        end)
    end)

    -- =========================================================================
    -- AD/CP settings: child dialog must not stack on the main dialog
    -- =========================================================================
    describe("onClickADSettings", function()
        -- Two WM dialogs open at once leave the FS25 input-context stack unbalanced: a
        -- TextInput focused in the nested dialog cannot revert its context on focus-leave,
        -- and once everything closes the game is stuck in a dead context with no keyboard
        -- and no mouse. Same contract as the editor (WMEditorDialog_spec).
        local function makeSettingsDialog()
            local d = makeDialog()
            d.workflows = { { id = "wf_1", name = "Harvest", steps = {}, adSettings = {} } }
            d.selectedWorkflowIndex = 1
            return d
        end

        it("closes the main dialog before opening the settings dialog", function()
            local d = makeSettingsDialog()
            d:onClickADSettings()
            assert.are.same({"close", "showAD"}, events)
        end)

        it("reopens the main dialog after the settings are confirmed", function()
            local d = makeSettingsDialog()
            d:onClickADSettings()
            WorkflowManager.adCallback({ unloadFillLevel = 0.8 })
            assert.are.equal("reopenMain", events[#events])
            assert.are.equal(0.8, d.workflows[1].adSettings.unloadFillLevel)
        end)

        it("stores confirmed settings through applyWorkflowChange", function()
            local d = makeSettingsDialog()
            d:onClickADSettings()
            WorkflowManager.adCallback({ unloadFillLevel = 0.8 })
            assert.are.same({ "close", "showAD", "reload", "register", "save", "reopenMain" }, events)
        end)

        it("reopens the main dialog when the settings dialog is cancelled", function()
            local d = makeSettingsDialog()
            d:onClickADSettings()
            WorkflowManager.adCallback(nil)
            assert.are.equal("reopenMain", events[#events])
        end)

        it("does nothing without a selection", function()
            local d = makeDialog()
            d.workflows = {}
            d.selectedWorkflowIndex = 0
            d:onClickADSettings()
            assert.are.same({}, events)
        end)
    end)

    -- =========================================================================
    -- Input bindings: New and Edit were the only step buttons without a hotkey
    -- =========================================================================
    describe("input bindings", function()

        local registered

        local function installInputGlobals()
            registered = {}
            _G.WMLogger = _G.WMLogger or { debug = function() end, info = function() end }
            _G.GS_PRIO_VERY_LOW = 1
            _G.InputAction = {
                WM_GUI_NEW         = "ia_new",
                WM_GUI_EDIT        = "ia_edit",
                WM_GUI_DELETE      = "ia_delete",
                WM_GUI_START       = "ia_start",
                WM_GUI_STOP        = "ia_stop",
                WM_GUI_AD_SETTINGS = "ia_adsettings",
            }
            _G.g_inputBinding = {
                removed = {},
                registerActionEvent = function(self, action, target, handler)
                    table.insert(registered, { action = action, handler = handler })
                    return true, "evt_" .. tostring(#registered)
                end,
                setActionEventTextPriority   = function() end,
                setActionEventTextVisibility = function() end,
                removeActionEvent = function(self, eventId) table.insert(self.removed, eventId) end,
            }
        end

        local function makeButton()
            local b = { disabled = false }
            b.setInputAction = function(self, action) self.inputAction = action end
            b.setDisabled    = function(self, v) self.disabled = v end
            b.setText        = function(self, t) self.text = t end
            return b
        end

        local function makeBoundDialog()
            installInputGlobals()
            local d = makeDialog()
            d.newButton        = makeButton()
            d.editButton       = makeButton()
            d.deleteButton     = makeButton()
            d.startButton      = makeButton()
            d.stopButton       = makeButton()
            d.adSettingsButton = makeButton()
            return d
        end

        it("shows a key glyph on New and Edit alongside the existing buttons", function()
            local d = makeBoundDialog()
            d:onOpen()
            assert.are.equal("WM_GUI_NEW",    d.newButton.inputAction)
            assert.are.equal("WM_GUI_EDIT",   d.editButton.inputAction)
            assert.are.equal("WM_GUI_DELETE", d.deleteButton.inputAction)
            assert.are.equal("WM_GUI_START",  d.startButton.inputAction)
            assert.are.equal("WM_GUI_STOP",   d.stopButton.inputAction)
        end)

        it("registers an action event for every hotkey button", function()
            local d = makeBoundDialog()
            d:registerInputEvents()
            local actions = {}
            for _, r in ipairs(registered) do table.insert(actions, r.action) end
            assert.are.same({ "ia_new", "ia_edit", "ia_delete", "ia_start", "ia_stop", "ia_adsettings" }, actions)
            assert.are.equal(6, #d.inputEventIds)
        end)

        it("removes every registered event on close", function()
            local d = makeBoundDialog()
            d:registerInputEvents()
            d:unregisterInputEvents()
            assert.are.equal(6, #g_inputBinding.removed)
            assert.are.equal(0, #d.inputEventIds)
        end)

        it("routes the New and Edit keys to their click handlers", function()
            local d = makeBoundDialog()
            local calls = {}
            d.onClickNew  = function() table.insert(calls, "new")  end
            d.onClickEdit = function() table.insert(calls, "edit") end
            d:onInputNew()
            d:onInputEdit()
            assert.are.same({ "new", "edit" }, calls)
        end)

        it("ignores the Edit key while the button is disabled", function()
            -- Edit is disabled without a selected workflow; the key must honour that gate.
            local d = makeBoundDialog()
            local calls = {}
            d.onClickEdit = function() table.insert(calls, "edit") end
            d.editButton.disabled = true
            d:onInputEdit()
            assert.are.equal(0, #calls)
        end)
    end)

end)
