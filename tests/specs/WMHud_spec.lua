--[[
    WMHud Unit Tests
    Verifies that HUD button callbacks target the correct vehicle when multiple
    vehicles run the same workflow (regression for the findVehicleForWorkflow bug).
]]

describe("WMHud", function()

    local workflow
    local vehicle1, vehicle2
    local sentCommands  -- {cmd, vehicle} pairs

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

        -- Stub notification (used by onClickStop)
        _G.g_currentMission.addIngameNotification = function() end
        _G.FSBaseMission = _G.FSBaseMission or {}
        _G.FSBaseMission.INGAME_NOTIFICATION_OK = 0

        -- Player is sitting in vehicle2
        _G.g_currentMission.controlledVehicle = vehicle2

        -- Reset WorkflowManager constants (in case mock replaced them)
        _G.WorkflowManager.STATUS_RUNNING = "running"
        _G.WorkflowManager.STATUS_PAUSED  = "paused"

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

        it("emits no command when the status is neither RUNNING nor PAUSED", function()
            vehicle2.spec_workflowManagerSpec.wmExecution.status = "completed"
            WMHud:onClickPauseResume()
            assert.are.equal(0, #sentCommands)
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
end)
