--[[
    WMHud Unit Tests
    Verifies that HUD button callbacks target the correct vehicle when multiple
    vehicles run the same workflow (regression for the findVehicleForWorkflow bug).
]]

describe("WMHud", function()

    local workflow
    local vehicle1, vehicle2
    local sentCommands  -- {cmd, vehicle} pairs
    local userMessages  -- {text, isError} passed to WorkflowManager:showUserMessage

    -- Helper: create a vehicle with wmExecution set up
    local function makeVehicle(name, workflow_, status)
        local v = VehicleMock.createValid(name)
        v.spec_workflowManagerSpec = {
            wmExecution = {
                workflow    = workflow_,
                vehicle     = v,
                status      = status,
                currentStep = 1,
            }
        }
        return v
    end

    setup(function()
        -- Load the real WMHud module (only defines methods, no render calls at load time)
        dofile("src/gui/WMHud.lua")
    end)

    before_each(function()
        -- Shared workflow definition (same id = same template, two vehicles running it)
        workflow = {
            id    = "wf_shared_001",
            name  = "Shared Workflow",
            steps = {
                { type = "autodrive",  target = "Farm",   action = "drive"     },
                { type = "courseplay", target = "Field1",  action = "fieldwork" },
            },
            linkedWorkflowId = nil,
            linkRole         = nil,
        }

        -- Own WorkflowManager stub — the runner restores globals between spec files, so
        -- do NOT rely on an earlier spec leaking the real module
        _G.WorkflowManager = {
            STATUS_RUNNING = "running",
            STATUS_PAUSED  = "paused",
            STATUS_WAITING_FOR_MAIN   = "waiting_for_main",
            STATUS_WAITING_FOR_LEADER = "waiting_for_leader",
        }

        vehicle1 = makeVehicle("Tractor1", workflow, WorkflowManager.STATUS_RUNNING)
        vehicle2 = makeVehicle("Tractor2", workflow, WorkflowManager.STATUS_RUNNING)

        -- Both vehicles are active
        _G.WMExecutor = {
            activeVehicles = { [vehicle1] = true, [vehicle2] = true },
        }

        -- Track sendCommand calls
        sentCommands = {}
        _G.WorkflowManager.sendCommand = function(_, vehicle, commandType)
            table.insert(sentCommands, { cmd = commandType, vehicle = vehicle })
        end

        -- Player feedback (used by onClickStop)
        userMessages = {}
        _G.WorkflowManager.showUserMessage = function(_, text, isError)
            table.insert(userMessages, { text = text, isError = isError })
        end

        -- Player is sitting in vehicle2
        _G.g_currentMission.controlledVehicle = vehicle2

        -- Reset HUD state
        WMHud.isVisible = true
    end)

    -- =========================================================================
    -- onClickStop
    -- =========================================================================
    describe("onClickStop", function()
        it("stops the controlled vehicle, not the other vehicle sharing the same workflow", function()
            WMHud:onClickStop()

            assert.are.equal(1, #sentCommands)
            assert.are.equal("stop",    sentCommands[1].cmd)
            assert.are.equal(vehicle2,  sentCommands[1].vehicle)
        end)

        it("does not send a command for the non-controlled vehicle", function()
            WMHud:onClickStop()

            for _, call in ipairs(sentCommands) do
                assert.are_not.equal(vehicle1, call.vehicle)
            end
        end)

        it("does nothing when no workflow is active on the controlled vehicle", function()
            _G.g_currentMission.controlledVehicle = nil
            WMHud:onClickStop()
            assert.are.equal(0, #sentCommands)
        end)

        it("reports the stop through showUserMessage as an info", function()
            WMHud:onClickStop()
            assert.are.equal(1, #userMessages)
            assert.is_false(userMessages[1].isError)
        end)
    end)

    -- =========================================================================
    -- onClickPauseResume — pause path (status = RUNNING)
    -- =========================================================================
    describe("onClickPauseResume (running -> pause)", function()
        before_each(function()
            vehicle2.spec_workflowManagerSpec.wmExecution.status = WorkflowManager.STATUS_RUNNING
        end)

        it("pauses the controlled vehicle", function()
            WMHud:onClickPauseResume()

            assert.are.equal(1, #sentCommands)
            assert.are.equal("pause",  sentCommands[1].cmd)
            assert.are.equal(vehicle2, sentCommands[1].vehicle)
        end)

        it("does not pause the other vehicle sharing the same workflow", function()
            WMHud:onClickPauseResume()

            for _, call in ipairs(sentCommands) do
                assert.are_not.equal(vehicle1, call.vehicle)
            end
        end)
    end)

    -- =========================================================================
    -- onClickPauseResume — resume path (status = PAUSED)
    -- =========================================================================
    describe("onClickPauseResume (paused -> resume)", function()
        before_each(function()
            -- vehicle1 is already RUNNING (simulates the auto-resumed vehicle from save)
            vehicle1.spec_workflowManagerSpec.wmExecution.status = WorkflowManager.STATUS_RUNNING
            -- vehicle2 is still PAUSED (the one the player is sitting in)
            vehicle2.spec_workflowManagerSpec.wmExecution.status = WorkflowManager.STATUS_PAUSED
        end)

        it("resumes the controlled (paused) vehicle, not the already-running one", function()
            WMHud:onClickPauseResume()

            assert.are.equal(1, #sentCommands)
            assert.are.equal("resume", sentCommands[1].cmd)
            assert.are.equal(vehicle2, sentCommands[1].vehicle)
        end)

        it("does not emit resume for the already-running vehicle", function()
            WMHud:onClickPauseResume()

            for _, call in ipairs(sentCommands) do
                assert.are_not.equal(vehicle1, call.vehicle)
            end
        end)

        it("emits no command when the status is neither RUNNING, PAUSED nor a wait state", function()
            vehicle2.spec_workflowManagerSpec.wmExecution.status = "completed"
            WMHud:onClickPauseResume()
            assert.are.equal(0, #sentCommands)
        end)

        it("pauses a vehicle waiting for its leader (regression: button was inert)", function()
            vehicle2.spec_workflowManagerSpec.wmExecution.status = WorkflowManager.STATUS_WAITING_FOR_LEADER
            WMHud:onClickPauseResume()
            assert.are.equal(1, #sentCommands)
            assert.are.equal("pause",  sentCommands[1].cmd)
            assert.are.equal(vehicle2, sentCommands[1].vehicle)
        end)

        it("pauses a support vehicle waiting for main (regression: button was inert)", function()
            vehicle2.spec_workflowManagerSpec.wmExecution.status = WorkflowManager.STATUS_WAITING_FOR_MAIN
            WMHud:onClickPauseResume()
            assert.are.equal(1, #sentCommands)
            assert.are.equal("pause",  sentCommands[1].cmd)
        end)
    end)

    -- =========================================================================
    -- onClickPrevious / onClickNext (already vehicle-safe; guard regressions)
    -- =========================================================================
    describe("onClickPrevious", function()
        before_each(function()
            vehicle2.spec_workflowManagerSpec.wmExecution.currentStep = 2

            -- goToPreviousStep must be available on WMExecutor (already stubs activeVehicles)
            _G.WorkflowManager.goToPreviousStep = function(_, vehicle)
                table.insert(sentCommands, { cmd = "prev_step", vehicle = vehicle })
            end
        end)

        it("targets the controlled vehicle", function()
            WMHud:onClickPrevious()
            assert.are.equal(1, #sentCommands)
            assert.are.equal("prev_step", sentCommands[1].cmd)
            assert.are.equal(vehicle2,    sentCommands[1].vehicle)
        end)
    end)

    describe("onClickNext", function()
        before_each(function()
            vehicle2.spec_workflowManagerSpec.wmExecution.currentStep = 1

            _G.WorkflowManager.goToNextStep = function(_, vehicle)
                table.insert(sentCommands, { cmd = "next_step", vehicle = vehicle })
            end
        end)

        it("targets the controlled vehicle", function()
            WMHud:onClickNext()
            assert.are.equal(1, #sentCommands)
            assert.are.equal("next_step", sentCommands[1].cmd)
            assert.are.equal(vehicle2,    sentCommands[1].vehicle)
        end)
    end)

    -- =========================================================================
    -- Mouse cursor ownership
    -- =========================================================================
    describe("setMouseCursorActive", function()
        local cursorCalls

        before_each(function()
            cursorCalls = {}
            WMHud.mouseCursorForced = false
            WMHud.openDialogCount = 0
            WMHud.pendingCursorGrant = nil
            _G.g_inputBinding = {
                setShowMouseCursor = function(_, show) table.insert(cursorCalls, show) end,
            }
        end)

        it("turns the cursor on and remembers that WM owns it", function()
            WMHud:setMouseCursorActive(true)
            assert.are.same({ true }, cursorCalls)
            assert.is_true(WMHud.mouseCursorForced)
        end)

        it("releases the cursor it turned on", function()
            WMHud:setMouseCursorActive(true)
            WMHud:setMouseCursorActive(false)
            assert.are.same({ true, false }, cursorCalls)
            assert.is_false(WMHud.mouseCursorForced)
        end)

        it("does not switch off a cursor another mod turned on", function()
            WMHud:setMouseCursorActive(false)
            assert.are.equal(0, #cursorCalls)
        end)

        it("does not re-enable an already forced cursor", function()
            WMHud:setMouseCursorActive(true)
            WMHud:setMouseCursorActive(true)
            assert.are.same({ true }, cursorCalls)
        end)

        -- The HUD auto-hides a few seconds after a workflow ends; taking the cursor with it
        -- would yank it away mid-use. Release is tied to the dialog chain instead
        -- (WorkflowManager:onDialogClosed).
        it("keeps the cursor when the HUD hides", function()
            WMHud:setMouseCursorActive(true)
            WMHud:hide()
            assert.are.same({ true }, cursorCalls)
            assert.is_true(WMHud.mouseCursorForced)
        end)

        it("releases the cursor when the player closes the HUD (X button / toggle key)", function()
            WMHud:setMouseCursorActive(true)
            WMHud:closeManually()
            assert.are.same({ true, false }, cursorCalls)
            assert.is_false(WMHud.isVisible)
        end)

        it("releases the cursor on manual close even while a dialog is counted open", function()
            WMHud:setMouseCursorActive(true)
            WMHud:onDialogOpened()
            WMHud:closeManually()
            assert.are.same({ true, false }, cursorCalls)
        end)

        it("manual close cancels a cursor grant that is still pending", function()
            WMHud:onDialogOpened()
            WMHud:setMouseCursorActive(true)   -- deferred: chain still open
            WMHud:closeManually()
            assert.are.same({}, cursorCalls)
            assert.is_nil(WMHud.pendingCursorGrant)
        end)

        it("releases the cursor on delete", function()
            WMHud:setMouseCursorActive(true)
            WMHud:delete()
            assert.are.same({ true, false }, cursorCalls)
        end)
    end)

    -- =========================================================================
    -- Dialog chain — the cursor is handed back when the last WM dialog closes
    -- =========================================================================
    describe("onDialogOpened / onDialogClosed", function()
        local cursorCalls

        before_each(function()
            cursorCalls = {}
            WMHud.mouseCursorForced = false
            WMHud.openDialogCount = 0
            WMHud.pendingCursorGrant = nil
            _G.g_inputBinding = {
                setShowMouseCursor = function(_, show) table.insert(cursorCalls, show) end,
            }
        end)

        it("releases the cursor when the last dialog closes", function()
            WMHud:setMouseCursorActive(true)   -- HUD owns the cursor (start flow ended earlier)
            WMHud:onDialogOpened()
            WMHud:onDialogClosed()
            assert.are.same({ true, false }, cursorCalls)
        end)

        it("keeps the cursor while another dialog in the chain is still open", function()
            -- main -> editor: editor opens before main is counted out
            WMHud:setMouseCursorActive(true)
            WMHud:onDialogOpened()
            WMHud:onDialogOpened()
            WMHud:onDialogClosed()
            assert.are.same({ true }, cursorCalls)
            assert.is_true(WMHud.mouseCursorForced)

            WMHud:onDialogClosed()
            assert.are.same({ true, false }, cursorCalls)
        end)

        it("defers a grant requested while a chain is open until the chain closes (regression)", function()
            -- Start flow with a stacked leader-select dialog: the grant used to be revoked
            -- the moment that dialog closed, leaving the HUD on screen but unclickable.
            WMHud:onDialogOpened()             -- leader select still open
            WMHud:setMouseCursorActive(true)   -- start callback hands the cursor to the HUD
            assert.are.same({}, cursorCalls)   -- not granted yet
            WMHud:onDialogClosed()             -- chain fully closes
            assert.are.same({ true }, cursorCalls)
            assert.is_true(WMHud.mouseCursorForced)
        end)

        it("never counts below zero", function()
            WMHud:onDialogClosed()
            WMHud:onDialogClosed()
            assert.are.equal(0, WMHud.openDialogCount)
        end)

        it("does not touch the cursor when WM never forced it on", function()
            WMHud:onDialogOpened()
            WMHud:onDialogClosed()
            assert.are.equal(0, #cursorCalls)
        end)

        it("resets the count on delete so a soft reset starts clean", function()
            WMHud:onDialogOpened()
            WMHud:delete()
            assert.are.equal(0, WMHud.openDialogCount)
        end)

        it("tracks the open dialog as the target for player messages", function()
            local dialog = {}
            WMHud:onDialogOpened(dialog)
            assert.are.equal(dialog, WMHud.activeDialog)
            WMHud:onDialogClosed(dialog)
            assert.is_nil(WMHud.activeDialog)
        end)

        it("keeps the newer dialog when an older one closes after it opened", function()
            -- main -> editor hand-over: the editor opens before main's close is counted
            local main, editor = {}, {}
            WMHud:onDialogOpened(main)
            WMHud:onDialogOpened(editor)
            WMHud:onDialogClosed(main)
            assert.are.equal(editor, WMHud.activeDialog)
        end)

        it("forgets the dialog on delete", function()
            WMHud:onDialogOpened({})
            WMHud:delete()
            assert.is_nil(WMHud.activeDialog)
        end)
    end)

    -- =========================================================================
    -- delete (map unload / soft reset)
    -- =========================================================================
    describe("delete", function()
        it("clears the visible state so a soft reset does not resurrect the HUD", function()
            WMHud.isVisible = true
            WMHud.vehicle = vehicle2
            WMHud:delete()
            assert.is_false(WMHud.isVisible)
            assert.is_nil(WMHud.vehicle)
        end)

        it("ignores mouse events once deleted", function()
            WMHud.isVisible = true
            WMHud:delete()
            assert.is_false(WMHud:mouseEvent(0.5, 0.5, true, false, 1))
        end)

        it("cancels an in-progress drag", function()
            WMHud.isDragging = true
            WMHud:delete()
            assert.is_false(WMHud.isDragging)
        end)
    end)

    -- =========================================================================
    -- Dragging: the position is a per-player setting
    -- =========================================================================
    describe("drag end", function()
        it("saves the position to the per-player settings file, not the workflow file", function()
            local settingsSaves, workflowSaves = 0, 0
            _G.WMSettings = { saveUserSettings = function() settingsSaves = settingsSaves + 1 end }
            _G.WorkflowManager.saveWorkflows = function() workflowSaves = workflowSaves + 1 end
            _G.Input = { MOUSE_BUTTON_LEFT = 1 }
            WMHud.isVisible, WMHud.x, WMHud.y, WMHud.h = true, 0.1, 0.1, 0.1
            WMHud.isDragging = true

            assert.is_true(WMHud:mouseEvent(0.5, 0.5, false, true, 1))

            assert.are.equal(1, settingsSaves)
            assert.are.equal(0, workflowSaves)
            assert.is_false(WMHud.isDragging)
        end)
    end)
end)
