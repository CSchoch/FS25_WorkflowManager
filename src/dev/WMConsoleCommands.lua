---@class WMConsoleCommands
WMConsoleCommands = {}

function WMConsoleCommands:init()
    addConsoleCommand("wmPrintState", "Print WorkflowManager execution state for the controlled vehicle", "wmPrintState", self)
end

function WMConsoleCommands:delete()
    removeConsoleCommand("wmPrintState")
end

function WMConsoleCommands:wmPrintState()
    local vehicle = g_currentMission and g_currentMission.controlledVehicle
    if vehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
        vehicle = g_localPlayer:getCurrentVehicle()
    end
    if vehicle == nil and g_currentMission and g_currentMission.playerSystem then
        for _, player in pairs(g_currentMission.playerSystem.players or {}) do
            if player.getCurrentVehicle then
                vehicle = player:getCurrentVehicle()
                if vehicle then break end
            end
        end
    end
    if vehicle == nil then
        print("[WM] wmPrintState: no controlled vehicle")
        return
    end
    vehicle = vehicle.rootVehicle or vehicle

    local spec = vehicle.spec_workflowManagerSpec
    if spec == nil then
        print("[WM] wmPrintState: vehicle has no WorkflowManager spec")
        return
    end

    local name = vehicle.getFullName and vehicle:getFullName() or tostring(vehicle)
    local ex = spec.wmExecution

    if ex == nil then
        print(string.format("[WM] %s — no active workflow", name))
        return
    end

    local wf = ex.workflow
    local wfLabel = wf and string.format("[%s] %s", tostring(wf.id), tostring(wf.name)) or "(unknown)"
    local stepTotal = wf and wf.steps and #wf.steps or "?"
    local stepType = ex.currentStepType or "(none)"
    local leaderName = "(none)"
    if ex.leaderVehicle then
        leaderName = ex.leaderVehicle.getFullName and ex.leaderVehicle:getFullName() or tostring(ex.leaderVehicle)
    end

    local pauseState = "(none)"
    if ex.pausedTrackingState ~= nil then
        local ps = ex.pausedTrackingState
        pauseState = string.format("waitingForCompletion=%s cpHandedOff=%s",
            tostring(ps.waitingForCompletion), tostring(ps.cpHandedOffToAD))
    end

    local sep = string.rep("-", 40)
    print(sep)
    print(string.format("[WM] %s", name))
    print(string.format("  workflow:          %s", wfLabel))
    print(string.format("  status:            %s", tostring(ex.status)))
    print(string.format("  step:              %s / %s  (%s)", tostring(ex.currentStep), tostring(stepTotal), stepType))
    print(string.format("  isMainVehicle:     %s", tostring(ex.isMainVehicle)))
    print(string.format("  leaderVehicle:     %s", leaderName))
    print(string.format("  waitForCompletion: %s", tostring(ex.waitingForCompletion)))
    print(string.format("  pendingADStart:    %s", tostring(ex.pendingADStart)))
    print(string.format("  pendingCPStart:    %s", tostring(ex.pendingCPStart)))
    print(string.format("  cpToCpTransition:  %s", tostring(ex.cpToCpTransition)))
    print(string.format("  cpHandedOffToAD:   %s", tostring(ex.cpHandedOffToAD)))
    print(string.format("  willHandoffToCP:   %s", tostring(ex.willHandoffToCP)))
    print(string.format("  pauseState:        %s", pauseState))
    print(sep)
end
