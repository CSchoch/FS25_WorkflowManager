--[[
    WMModeSelectDialog Unit Tests

    The dialog asks the player which role a vehicle takes when starting a workflow that has
    support sub-steps, and reports the answer through one callback:
      true  = run as main, false = run as support, nil = cancelled.
    Getting that tri-state wrong silently starts the vehicle in the wrong role, so each of
    the three exits is pinned here, along with the "Run as Support" hotkey.
]]

describe("WMModeSelectDialog", function()

    -- onOpen registers the Run-as-Support hotkey, so every onOpen test needs the input
    -- globals; installed file-wide here and reset per test via resetInputStubs().
    local registeredInputs = {}

    local function resetInputStubs()
        registeredInputs = {}
        g_inputBinding.removed = {}
    end

    local function installInputStubs()
        _G.GS_PRIO_VERY_LOW = 1
        _G.InputAction = { WM_GUI_RUN_SUPPORT = "ia_runsupport" }
        _G.g_inputBinding = {
            removed = {},
            registerActionEvent = function(self, action, target, handler)
                table.insert(registeredInputs, { action = action, handler = handler })
                return true, "evt_" .. tostring(#registeredInputs)
            end,
            setActionEventTextPriority   = function() end,
            setActionEventTextVisibility = function() end,
            removeActionEvent = function(self, eventId) table.insert(self.removed, eventId) end,
        }
    end

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

        _G.WMLogger = { debug = function() end, info = function() end }
        _G.WMHud = {
            onDialogOpened = function() end,
            onDialogClosed = function() end,
        }
        _G.WorkflowManager = {
            getWorkflowById = function(_, id)
                if id == "wf_1" then return { id = "wf_1", name = "Harvest Run" } end
                return nil
            end,
        }

        installInputStubs()

        dofile("src/gui/WMModeSelectDialog.lua")
    end)

    local closed
    local result, callbackCalled

    before_each(function()
        closed = false
        result, callbackCalled = "unset", false
    end)

    local function makeDialog()
        local d = WMModeSelectDialog.new()
        d.close = function() closed = true end
        d:setWorkflow("wf_1", {}, function(v) result = v; callbackCalled = true end)
        return d
    end

    -- =========================================================================
    -- The three exits
    -- =========================================================================
    describe("role selection", function()
        it("reports true for Run as Main", function()
            local d = makeDialog()
            d:onClickMain()
            assert.is_true(closed)
            assert.is_true(result)
        end)

        it("reports false for Run as Support", function()
            local d = makeDialog()
            d:onClickSupport()
            assert.is_true(closed)
            assert.is_false(result)
        end)

        it("reports nil for Cancel", function()
            local d = makeDialog()
            d:onClickCancel()
            assert.is_true(closed)
            assert.is_true(callbackCalled)
            assert.is_nil(result)
        end)

        it("treats Esc as Cancel", function()
            local d = makeDialog()
            d:onEscPressed()
            assert.is_true(closed)
            assert.is_true(callbackCalled)
            assert.is_nil(result)
        end)
    end)

    describe("onOpen", function()
        it("titles the dialog with the workflow name", function()
            local d = makeDialog()
            local titleText
            d.titleElement = { setText = function(_, t) titleText = t end }
            d:onOpen()
            assert.are.equal("Harvest Run", titleText)
        end)
    end)

    -- =========================================================================
    -- Input bindings: "Run as Support" is the one choice with no other hotkey
    -- =========================================================================
    describe("input bindings", function()

        local function makeBoundDialog()
            resetInputStubs()
            local d = makeDialog()
            d.supportButton = {
                disabled = false,
                setInputAction = function(self, action) self.inputAction = action end,
            }
            return d
        end

        it("shows a key glyph on the Run as Support button", function()
            local d = makeBoundDialog()
            d:onOpen()
            assert.are.equal("WM_GUI_RUN_SUPPORT", d.supportButton.inputAction)
        end)

        it("registers and unregisters the action event with the dialog", function()
            local d = makeBoundDialog()
            d:registerInputEvents()
            assert.are.equal(1, #registeredInputs)
            assert.are.equal("ia_runsupport", registeredInputs[1].action)
            d:unregisterInputEvents()
            assert.are.equal(1, #g_inputBinding.removed)
            assert.are.equal(0, #d.inputEventIds)
        end)

        it("starts the vehicle in the support role when the key is pressed", function()
            local d = makeBoundDialog()
            d:onInputSupport()
            assert.is_true(closed)
            assert.is_false(result)
        end)
    end)

end)
