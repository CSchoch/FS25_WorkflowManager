---@class WMConsoleCommands
WMConsoleCommands = {}

function WMConsoleCommands:init()
    addConsoleCommand("wmPrintState", "Print WorkflowManager execution state for the controlled vehicle", "wmPrintState", self)
    addConsoleCommand("wmPrintStateAll", "Print WorkflowManager execution state for all WM vehicles", "wmPrintStateAll", self)
    addConsoleCommand("wmPrintWorkflow", "Print annotated workflow steps with sync ordinals for the controlled vehicle (+ leader)", "wmPrintWorkflow", self)
end

function WMConsoleCommands:delete()
    removeConsoleCommand("wmPrintState")
    removeConsoleCommand("wmPrintStateAll")
    removeConsoleCommand("wmPrintWorkflow")
end

function WMConsoleCommands:printVehicleState(vehicle)
    vehicle = vehicle.rootVehicle or vehicle
    local spec = vehicle.spec_workflowManagerSpec
    if spec == nil then return end

    local name = vehicle.getFullName and vehicle:getFullName() or tostring(vehicle)
    local ex = spec.wmExecution

    local sep = string.rep("-", 40)
    print(sep)
    print(string.format("[WM] %s", name))

    if ex == nil then
        print("  (no active workflow)")
        print(sep)
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
    print(string.format("  pauseState:        %s", pauseState))
    print(string.format("  waitForMainStep:   %s", tostring(ex.waitingForMainStepIndex)))
    print(string.format("  pendingLeaderIdx:  %s", tostring(ex.pendingLeaderXmlIndex)))
    print(string.format("  pendingLeaderWF:   %s", tostring(ex.pendingLeaderWorkflowId)))
    print(string.format("  pendingLeaderUid:  %s", tostring(ex.pendingLeaderUniqueId)))
    local leaderStep = ex.linkedLeaderExecution and ex.linkedLeaderExecution.currentStep
    local syncRequired = nil
    if ex.syncTargets then
        for _, target in ipairs(ex.syncTargets) do
            if leaderStep == nil or leaderStep < target then
                syncRequired = target
                break
            end
        end
    end
    -- Overflow: ordinal beyond target list — unblocks only when leader finishes (leaderExec→nil)
    if syncRequired == nil and ex.syncSourceOrdinals and ex.currentStep then
        local ordinal = ex.syncSourceOrdinals[ex.currentStep]
        if ordinal and (ex.syncTargets == nil or ex.syncTargets[ordinal] == nil) then
            syncRequired = "waiting until leader finishes"
        end
    end
    -- Ask the executor for the real gate value instead of re-deriving it here — a hand
    -- copy of the formula silently goes stale when the sync rule is tuned.
    local blockedByLeader = nil
    if ex.leaderVehicle and WMExecutor and WMExecutor.getLeaderSyncRequirement then
        local required = WMExecutor:getLeaderSyncRequirement(ex)
        if required ~= nil and (leaderStep == nil or leaderStep < required) then
            blockedByLeader = string.format("need leader at step %d (currently at %s)", required, tostring(leaderStep))
        end
    end
    print(string.format("  leaderStep:        %s", tostring(leaderStep)))
    print(string.format("  syncRequired:      %s", tostring(syncRequired)))
    print(string.format("  blockedByLeader:   %s", tostring(blockedByLeader)))

    -- Sync ordinals dump (only meaningful for followers)
    if ex.workflow and ex.syncSourceOrdinals then
        local parts = {}
        for i = 1, #ex.workflow.steps do
            local ord = ex.syncSourceOrdinals[i]
            if ord then table.insert(parts, string.format("step%d→#%d", i, ord)) end
        end
        print(string.format("  syncSourceOrds:    %s", #parts > 0 and table.concat(parts, ", ") or "(none)"))
    end
    if ex.syncTargets and #ex.syncTargets > 0 then
        local parts = {}
        for ord, tgt in ipairs(ex.syncTargets) do
            table.insert(parts, string.format("#%d→L%d", ord, tgt))
        end
        print(string.format("  syncTargets:       %s", table.concat(parts, ", ")))
    end

    print(sep)
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
    self:printVehicleState(vehicle)
end

function WMConsoleCommands:wmPrintStateAll()
    local count = 0
    for v, _ in pairs(WMExecutor.activeVehicles) do
        self:printVehicleState(v)
        count = count + 1
    end
    if count == 0 then
        print("[WM] wmPrintStateAll: no WM vehicles found")
    end
end

---Print one workflow's steps as an annotated table.
---@param label string  Section header
---@param steps table   workflow.steps array
---@param currentStep number|nil  Active step index (marks with [>])
---@param syncSourceOrdinals table|nil  stepIdx → ordinal (follower, built at runtime)
---@param reverseTargets table|nil  leaderStepIdx → ordinal (leader annotation)
local function printWorkflowSteps(label, steps, currentStep, syncSourceOrdinals, reverseTargets)
    print(string.format("  %s  (%d steps)", label, #steps))
    print("    Idx  Type  Target                           Sync")
    for i, step in ipairs(steps) do
        local marker = (i == currentStep) and "[>]" or "   "
        local t = step.type or "?"
        if t == "autodrive" then t = "AD"
        elseif t == "courseplay" then t = "CP"
        elseif t == "wait_for_leader" then t = "WAIT"
        elseif t == "unlock_follower" then t = "UNLK" end
        local target = (step.target or "(none)"):sub(1, 32)
        local syncStr = "-"
        if step.type == "wait_for_leader" then
            local ord = syncSourceOrdinals and syncSourceOrdinals[i]
            syncStr = ord and ("wait #" .. ord) or "wait"
        elseif step.type == "unlock_follower" then
            local ord = reverseTargets and reverseTargets[i]
            syncStr = ord and ("unlock ←#" .. ord) or "unlock"
        end
        print(string.format("    %s %2d  %-4s  %-32s  %s", marker, i, t, target, syncStr))
    end
end

function WMConsoleCommands:wmPrintWorkflow()
    local vehicle = g_currentMission and g_currentMission.controlledVehicle
    if vehicle == nil and g_localPlayer and g_localPlayer.getCurrentVehicle then
        vehicle = g_localPlayer:getCurrentVehicle()
    end
    if vehicle == nil then
        print("[WM] wmPrintWorkflow: no controlled vehicle")
        return
    end

    vehicle = vehicle.rootVehicle or vehicle
    local spec = vehicle.spec_workflowManagerSpec
    if spec == nil then return end
    local ex = spec.wmExecution
    if ex == nil then
        print("[WM] wmPrintWorkflow: no active workflow")
        return
    end

    local sep = string.rep("-", 60)
    local name = vehicle.getFullName and vehicle:getFullName() or tostring(vehicle)
    print(sep)
    print(string.format("[WM WORKFLOWS] %s  status=%s", name, tostring(ex.status)))

    -- Current vehicle's workflow
    local wf = ex.workflow
    if wf and wf.steps then
        local role = ex.isMainVehicle and "MAIN" or "FOLLOWER"
        local wfLabel = string.format("%s  workflow:[%s] %s", role, tostring(wf.id), tostring(wf.name))
        printWorkflowSteps(wfLabel, wf.steps, ex.currentStep, ex.syncSourceOrdinals, nil)
    end

    -- Leader workflow: prefer linkedLeaderExecution, fall back to leader's live spec
    local leaderVehicle = ex.leaderVehicle
    local leaderEx = ex.linkedLeaderExecution
    if leaderEx == nil and leaderVehicle and leaderVehicle.spec_workflowManagerSpec then
        leaderEx = leaderVehicle.spec_workflowManagerSpec.wmExecution
    end

    if leaderVehicle then
        local lName = leaderVehicle.getFullName and leaderVehicle:getFullName() or tostring(leaderVehicle)
        if leaderEx and leaderEx.workflow then
            local lwf = leaderEx.workflow
            local reverseTargets = {}
            if ex.syncTargets then
                for ord, leaderStepIdx in ipairs(ex.syncTargets) do
                    reverseTargets[leaderStepIdx] = ord
                end
            end
            local lLabel = string.format("LEADER  (%s)  workflow:[%s] %s", lName, tostring(lwf.id), tostring(lwf.name))
            printWorkflowSteps(lLabel, lwf.steps, leaderEx.currentStep, nil, reverseTargets)
        else
            print(string.format("  LEADER  (%s)  — no active execution", lName))
        end
    elseif ex.pendingLeaderWorkflowId ~= nil or ex.pendingLeaderXmlIndex ~= nil or ex.pendingLeaderUniqueId ~= nil then
        print(string.format("  LEADER  — pending (workflowId=%s  xmlIndex=%s  uniqueId=%s)",
            tostring(ex.pendingLeaderWorkflowId), tostring(ex.pendingLeaderXmlIndex), tostring(ex.pendingLeaderUniqueId)))
    end

    print(sep)
end
