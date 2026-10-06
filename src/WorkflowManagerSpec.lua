--[[
    WorkflowManagerSpec - Vehicle Specialization
    Registers input actions for WorkflowManager that work while in a vehicle
]]

-- Prevent multiple loads
if WorkflowManagerSpec ~= nil then
    return
end

---@class WorkflowManagerSpec
WorkflowManagerSpec = {}
WorkflowManagerSpec.specName = nil
WorkflowManagerSpec.initialized = false
WorkflowManagerSpec.registeredToVehicles = false

---Check if this specialization can be applied to a vehicle type
---@param specializations table List of specializations the vehicle has
---@return boolean True if prerequisites are met
function WorkflowManagerSpec.prerequisitesPresent(specializations)
    -- Only add to vehicles that are enterable (player can sit in them)
    return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

---Register event listeners for this specialization
---@param vehicleType table The vehicle type
function WorkflowManagerSpec.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", WorkflowManagerSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", WorkflowManagerSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", WorkflowManagerSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", WorkflowManagerSpec)
    SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", WorkflowManagerSpec)
    -- Initial state sync when a client connects mid-session
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", WorkflowManagerSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", WorkflowManagerSpec)
end

---Called when the vehicle is loaded (early init only)
---@param savegame table The savegame data
function WorkflowManagerSpec:onLoad(savegame)
    self.spec_workflowManagerSpec = {
        actionEvents = {},
        wmExecution = nil   -- set by WMExecutor when a workflow starts on this vehicle
    }
end

---Called after all vehicles are loaded and initialised.
---WorkflowManager.workflows is populated by this point (loadMap runs before onPostLoad).
---@param savegame table The savegame data
function WorkflowManagerSpec:onPostLoad(savegame)
    if savegame == nil or savegame.resetVehicles then return end

    -- Parse and store this vehicle's XML index from savegame.key ("vehicles.vehicle(N)").
    -- Used as a stable cross-session identity for leader vehicle lookup.
    local selfXmlIndex = tonumber(savegame.key:match("vehicle%((%d+)%)"))
    self.spec_workflowManagerSpec.wmXmlIndex = selfXmlIndex
    WMLogger:debug("onPostLoad: vehicle='%s' xmlIndex=%s key='%s'",
        self.getName and self:getName() or "?", tostring(selfXmlIndex), savegame.key)

    local key = savegame.key .. ".FS25_WorkflowManager.workflowManagerSpec"
    local workflowId = savegame.xmlFile:getValue(key .. "#workflowId")
    if workflowId ~= nil and workflowId ~= "" then
        local currentStep = savegame.xmlFile:getValue(key .. "#currentStep") or 1
        -- Resolve workflow immediately - loadMap has already run by now
        local workflow = nil
        for _, wf in ipairs(WorkflowManager.workflows) do
            if wf.id == workflowId then
                workflow = wf
                break
            end
        end
        if workflow then
            local isMainVehicle = savegame.xmlFile:getValue(key .. "#isMainVehicle")
            if isMainVehicle == nil then isMainVehicle = true end  -- default: main role
            local currentSupportStep = nil
            -- Support vehicle finishing a sub-step of a main step main had already left
            -- ("finish before switching"): currentSupportStep indexes that step's list
            local supportMainStepIndex = nil
            if not isMainVehicle then
                currentSupportStep = savegame.xmlFile:getValue(key .. "#currentSupportStep") or 1
                supportMainStepIndex = savegame.xmlFile:getValue(key .. "#supportMainStepIndex")
            end

            local leaderVehicle = nil
            local linkedLeaderExecution = nil
            local pendingLeaderXmlIndex = nil
            local pendingLeaderWorkflowId = nil
            local pendingLeaderUniqueId = nil

            -- Primary identity: the vehicle's own engine-assigned uniqueId (stable across
            -- save/load regardless of vehicle-list reordering, unlike a positional index).
            local leaderUniqueId = savegame.xmlFile:getValue(key .. "#leaderVehicleUniqueId")
            if leaderUniqueId ~= nil then
                for v, _ in pairs(WMExecutor.activeVehicles) do
                    if v ~= self and v.uniqueId == leaderUniqueId then
                        leaderVehicle = v
                        linkedLeaderExecution = v.spec_workflowManagerSpec.wmExecution
                        break
                    end
                end
                if leaderVehicle then
                    WMLogger:debug("Restore leader: uniqueId=%s → vehicle='%s'", leaderUniqueId,
                        leaderVehicle.getName and leaderVehicle:getName() or "?")
                else
                    pendingLeaderUniqueId = leaderUniqueId
                    WMLogger:debug("Restore leader: uniqueId=%s → not found yet, deferred", leaderUniqueId)
                end
            else
                -- Backward compat: saves written before uniqueId-based leader tracking
                local leaderXmlIdx = savegame.xmlFile:getValue(key .. "#leaderVehicleXmlIndex")
                local leaderKeyUsed = leaderXmlIdx ~= nil and "#leaderVehicleXmlIndex" or nil
                -- Backward compat: old save used 1-based Lua array index
                if leaderXmlIdx == nil then
                    local legacyIdx = savegame.xmlFile:getValue(key .. "#leaderVehicleIndex")
                    if legacyIdx then
                        leaderXmlIdx = legacyIdx - 1
                        leaderKeyUsed = "#leaderVehicleIndex(legacy)"
                    end
                end
                WMLogger:debug("Restore leader: key=%s rawValue=%s", tostring(leaderKeyUsed), tostring(leaderXmlIdx))

                if leaderXmlIdx ~= nil then
                    for v, _ in pairs(WMExecutor.activeVehicles) do
                        if v ~= self then
                            local vSpec = v.spec_workflowManagerSpec
                            if vSpec and vSpec.wmXmlIndex == leaderXmlIdx then
                                leaderVehicle = v
                                linkedLeaderExecution = vSpec.wmExecution
                                break
                            end
                        end
                    end
                    if leaderVehicle then
                        WMLogger:debug("Restore leader: xmlIndex=%d → vehicle='%s'", leaderXmlIdx,
                            leaderVehicle.getName and leaderVehicle:getName() or "?")
                    else
                        pendingLeaderXmlIndex = leaderXmlIdx
                        -- Log which candidates were visible so mismatches are diagnosable
                        local seen = {}
                        for v, _ in pairs(WMExecutor.activeVehicles) do
                            local vSpec = v.spec_workflowManagerSpec
                            table.insert(seen, string.format("'%s'(idx=%s)",
                                v.getName and v:getName() or "?",
                                tostring(vSpec and vSpec.wmXmlIndex)))
                        end
                        WMLogger:debug("Restore leader: xmlIndex=%d → not found yet, deferred (activeVehicles: %s)",
                            leaderXmlIdx, #seen > 0 and table.concat(seen, ", ") or "none")
                    end
                else
                    -- Backward compat: even older saves used workflow ID
                    local legacyWfId = savegame.xmlFile:getValue(key .. "#leaderWorkflowId")
                    if legacyWfId then
                        pendingLeaderWorkflowId = legacyWfId
                        WMLogger:debug("Restore leader: legacy workflowId='%s' (deferred)", legacyWfId)
                    else
                        WMLogger:debug("Restore leader: no leader key found in savegame")
                    end
                end
            end

            -- Restore WAITING_FOR_LEADER / WAITING_FOR_MAIN exactly as saved so the
            -- auto-resume path is never triggered for a vehicle that was waiting.
            -- All other statuses restore as PAUSED and rely on the 10-second auto-resume
            -- window to detect AD/CP still running.
            local savedStatus = savegame.xmlFile:getValue(key .. "#status")
            local isWaitingForLeader = (savedStatus == WorkflowManager.STATUS_WAITING_FOR_LEADER)
            local isWaitingForMain   = (savedStatus == WorkflowManager.STATUS_WAITING_FOR_MAIN)
            local restoredStatus
            if isWaitingForLeader then
                restoredStatus = WorkflowManager.STATUS_WAITING_FOR_LEADER
            elseif isWaitingForMain then
                restoredStatus = WorkflowManager.STATUS_WAITING_FOR_MAIN
            else
                restoredStatus = WorkflowManager.STATUS_PAUSED
            end
            local restoredAutoResume = nil
            if not isWaitingForLeader and not isWaitingForMain then
                restoredAutoResume = g_currentMission.time + 10000
            end
            -- Restore waitingForMainStep tracking fields so the idle poll can detect changes.
            local restoredWaitingForMainStep = nil
            local restoredWaitingForMainStepIndex = nil
            if isWaitingForMain then
                restoredWaitingForMainStep = true
                restoredWaitingForMainStepIndex = savegame.xmlFile:getValue(key .. "#waitingForMainStepIndex")
            end

            -- Courseplay was driving when the game was saved. It never auto-resumes, so the
            -- executor restarts it once the auto-resume window expires — at this waypoint.
            local cpWasRunningAtSave = savegame.xmlFile:getValue(key .. "#cpWasRunning")
            local cpResumeWaypoint   = savegame.xmlFile:getValue(key .. "#cpResumeWaypoint")

            self.spec_workflowManagerSpec.wmExecution = {
                workflow                = workflow,
                vehicle                 = self,
                status                  = restoredStatus,
                currentStep             = currentStep,
                startTime               = g_currentMission.time,
                waitingForCompletion    = false,
                isMainVehicle           = isMainVehicle,
                currentSupportStep      = currentSupportStep,
                leaderVehicle           = leaderVehicle,
                linkedLeaderExecution   = linkedLeaderExecution,
                pendingLeaderXmlIndex   = pendingLeaderXmlIndex,
                pendingLeaderWorkflowId = pendingLeaderWorkflowId,
                pendingLeaderUniqueId   = pendingLeaderUniqueId,
                waitingForMainStep      = restoredWaitingForMainStep,
                waitingForMainStepIndex = restoredWaitingForMainStepIndex,
                autoResumeUntil         = restoredAutoResume,
                cpWasRunningAtSave      = cpWasRunningAtSave,
                cpResumeWaypoint        = cpResumeWaypoint,
                pendingMainStepSwitch   = supportMainStepIndex ~= nil or nil,
                supportMainStepIndex    = supportMainStepIndex,
            }
            WMExecutor.activeVehicles[self] = true
            WMHud:show(self)
            WMLogger:info("Restored workflow '%s' step=%d isMain=%s on '%s' (paused)",
                workflow.name, currentStep, tostring(isMainVehicle),
                self.getName and self:getName() or "unknown")
        else
            WMLogger:warning("Cannot restore workflow: id '%s' not found", workflowId)
            WorkflowManager:showUserMessage(WorkflowManager:formatUserMessage(
                "wm_warning_restore_workflow_missing",
                { workflowId, WorkflowManager:getVehicleDisplayName(self) }), true)
        end
    end
end

---Called when the vehicle is saved to the savegame XML.
---Note: FS25 calls saveToXMLFile (no 'on' prefix) directly on the spec.
---@param xmlFile XMLFile The savegame XML file
---@param key string Base key for this vehicle
---@param usedModNames table Mod names that wrote data
function WorkflowManagerSpec:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_workflowManagerSpec
    -- Parse and cache this vehicle's XML index from the save key — same authoritative
    -- source as onPostLoad. Ensures fresh-start vehicles (savegame == nil on load)
    -- have wmXmlIndex set before any follower's saveToXMLFile reads it.
    local selfXmlIndex = tonumber(key:match("vehicle%((%d+)%)"))
    if selfXmlIndex ~= nil and spec ~= nil then
        spec.wmXmlIndex = selfXmlIndex
    end
    if spec == nil or spec.wmExecution == nil then return end

    local activeData = spec.wmExecution
    WMLogger:debug("saveToXMLFile: vehicle='%s' xmlIndex=%s step=%d status=%s leaderVehicle=%s",
        self.getName and self:getName() or "?",
        tostring(spec.wmXmlIndex),
        activeData.currentStep, tostring(activeData.status),
        activeData.leaderVehicle and (activeData.leaderVehicle.getName and activeData.leaderVehicle:getName() or "?") or "nil")
    -- 'key' already contains the full path including our mod/spec namespace
    -- (e.g. "vehicles.vehicle(49).FS25_WorkflowManager.workflowManagerSpec")
    xmlFile:setValue(key .. "#workflowId",    activeData.workflow.id)
    xmlFile:setValue(key .. "#currentStep",   activeData.currentStep)
    xmlFile:setValue(key .. "#isMainVehicle", activeData.isMainVehicle ~= false)
    if activeData.isMainVehicle == false then
        xmlFile:setValue(key .. "#currentSupportStep", activeData.currentSupportStep or 1)
        if activeData.pendingMainStepSwitch and activeData.supportMainStepIndex ~= nil then
            xmlFile:setValue(key .. "#supportMainStepIndex", activeData.supportMainStepIndex)
        end
    end
    -- Save wait statuses so vehicles are restored correctly and the auto-resume path
    -- (which bypasses sync logic) is never triggered on reload.
    if activeData.status == WorkflowManager.STATUS_WAITING_FOR_LEADER
    or activeData.status == WorkflowManager.STATUS_WAITING_FOR_MAIN then
        xmlFile:setValue(key .. "#status", activeData.status)
    end
    if activeData.status == WorkflowManager.STATUS_WAITING_FOR_MAIN then
        xmlFile:setValue(key .. "#waitingForMainStepIndex", activeData.waitingForMainStepIndex or 1)
    end
    if activeData.leaderVehicle then
        if activeData.leaderVehicle.uniqueId then
            xmlFile:setValue(key .. "#leaderVehicleUniqueId", activeData.leaderVehicle.uniqueId)
            WMLogger:debug("Saved leaderVehicleUniqueId=%s for '%s'", activeData.leaderVehicle.uniqueId,
                activeData.leaderVehicle.getName and activeData.leaderVehicle:getName() or "?")
        else
            WMLogger:warning("Leader vehicle '%s' has no uniqueId — leader not saved",
                activeData.leaderVehicle.getName and activeData.leaderVehicle:getName() or "?")
        end
    end

    -- Courseplay never restarts itself after a load (it clears the base-game AIFieldWorker
    -- #isActive flag on save), and it only records its own #rememberedWpIx on a clean stop —
    -- never mid-drive. So capture the resume waypoint ourselves while CP is still driving.
    -- Keyed off isRunning, not currentStepType: the latter is memory-only and a CP→AD handoff
    -- would misreport it.
    if CPIntegration:isRunning(self) then
        xmlFile:setValue(key .. "#cpWasRunning", true)
        local resumeWaypoint = CPIntegration:getResumeWaypointIx(self)
        if resumeWaypoint ~= nil then
            xmlFile:setValue(key .. "#cpResumeWaypoint", resumeWaypoint)
            WMLogger:debug("Saved Courseplay resume waypoint %d for '%s'", resumeWaypoint,
                self.getName and self:getName() or "?")
        else
            WMLogger:warning("Courseplay running at save but no resume waypoint could be determined "
                .. "for '%s' — the workflow will stay paused after load",
                self.getName and self:getName() or "?")
        end
    end

    WMLogger:info("Saved workflow state: id=%s step=%d isMain=%s",
        activeData.workflow.id, activeData.currentStep, tostring(activeData.isMainVehicle ~= false))
end

---Called on the SERVER when sending this vehicle to a newly-connected client.
---Writes the current wmExecution state so the client can mirror it.
---@param streamId number Network stream
---@param connection table The client connection
function WorkflowManagerSpec:onWriteStream(streamId, connection)
    local activeData = self.spec_workflowManagerSpec and self.spec_workflowManagerSpec.wmExecution
    if activeData ~= nil then
        -- Leader reference: network object id (0 = none). A workflow id is NOT a usable
        -- identity here — main and support vehicles of one workflow share it, so a joining
        -- client could bind the wrong vehicle as leader. The object id is exact; the client
        -- resolves it lazily because the leader vehicle may not have streamed in yet.
        local leaderObjectId = 0
        if activeData.leaderVehicle ~= nil and NetworkUtil ~= nil and NetworkUtil.getObjectId ~= nil then
            leaderObjectId = NetworkUtil.getObjectId(activeData.leaderVehicle) or 0
        end

        streamWriteBool(streamId, true)
        streamWriteString(streamId, activeData.workflow.id)
        streamWriteInt32(streamId, activeData.currentStep)
        streamWriteString(streamId, activeData.status)
        streamWriteBool(streamId, activeData.isMainVehicle ~= false)
        streamWriteInt32(streamId, activeData.currentSupportStep or 0)
        streamWriteBool(streamId, activeData.waitingForMainStep == true)
        streamWriteInt32(streamId, leaderObjectId)
        WMLogger:debug("onWriteStream: sent wmExecution wf=%s step=%d status=%s isMain=%s leaderObj=%d",
            activeData.workflow.id, activeData.currentStep, activeData.status,
            tostring(activeData.isMainVehicle ~= false), leaderObjectId)
    else
        streamWriteBool(streamId, false)
    end
end

---Called on the CLIENT when receiving vehicle data from the server (initial / mid-session join).
---Rebuilds the wmExecution mirror so the HUD and GUI reflect the current server state.
---@param streamId number Network stream
---@param connection table The server connection
function WorkflowManagerSpec:onReadStream(streamId, connection)
    local isActive = streamReadBool(streamId)
    if not isActive then return end

    local workflowId         = streamReadString(streamId)
    local currentStep        = streamReadInt32(streamId)
    local status             = streamReadString(streamId)
    local isMainVehicle      = streamReadBool(streamId)
    local currentSupportStep = streamReadInt32(streamId)
    if currentSupportStep == 0 then currentSupportStep = nil end
    local waitingForMainStep = streamReadBool(streamId) or nil
    local leaderObjectId     = streamReadInt32(streamId)

    -- Resolve workflow definition (loadMap has run by the time vehicles are streamed)
    local workflow = WorkflowManager:getWorkflowById(workflowId)
    if workflow == nil then
        WMLogger:warning("onReadStream: unknown workflowId '%s' – cannot restore state", workflowId)
        return
    end

    -- Resolve leader vehicle by its exact network object id. Vehicles stream in arbitrary
    -- order, so the leader may not exist client-side yet — keep the id pending and let the
    -- HUD resolve it lazily on first display.
    local leaderVehicle = nil
    local pendingLeaderObjectId = nil
    if leaderObjectId ~= nil and leaderObjectId ~= 0 then
        if NetworkUtil ~= nil and NetworkUtil.getObject ~= nil then
            leaderVehicle = NetworkUtil.getObject(leaderObjectId)
        end
        if leaderVehicle == nil then
            pendingLeaderObjectId = leaderObjectId
        end
    end

    self.spec_workflowManagerSpec.wmExecution = {
        workflow                = workflow,
        vehicle                 = self,
        status                  = status,
        currentStep             = currentStep,
        waitingForCompletion    = false,
        isMainVehicle           = isMainVehicle,
        currentSupportStep      = currentSupportStep,
        waitingForMainStep      = waitingForMainStep,
        leaderVehicle           = leaderVehicle,
        pendingLeaderObjectId   = pendingLeaderObjectId,
    }
    WMExecutor.activeVehicles[self] = true

    -- Show HUD if this is the vehicle the local player is sitting in
    local controlled = g_currentMission and g_currentMission.controlledVehicle
    if controlled == self and WMHud then
        WMHud:show(self)
    end

    WMLogger:info("onReadStream: restored workflow '%s' step=%d status=%s on '%s'",
        workflow.name, currentStep, status,
        self.getName and self:getName() or "unknown")
end

---Called when the vehicle is deleted
function WorkflowManagerSpec:onDelete()
    -- Stop workflow if running (prevents dangling state when vehicle is deleted mid-workflow)
    local spec = self.spec_workflowManagerSpec
    if spec and spec.wmExecution then
        WMLogger:info("Vehicle deleted while running workflow - stopping: %s",
            spec.wmExecution.workflow and spec.wmExecution.workflow.name or "unknown")
        WMExecutor:stopWorkflow(self)
    end
    if spec and spec.actionEvents then
        self:clearActionEventsTable(spec.actionEvents)
    end
end

---Called when the vehicle needs to register its action events
---@param isActiveForInput boolean Whether the vehicle is active for input
---@param isActiveForInputIgnoreSelection boolean Whether to ignore selection state
function WorkflowManagerSpec:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if not self.isClient then
        return
    end

    local spec = self.spec_workflowManagerSpec
    if spec == nil then
        return
    end

    -- Clear any existing action events
    self:clearActionEventsTable(spec.actionEvents)

    -- Only register if vehicle is active for input (player is controlling it)
    if not self:getIsActiveForInput(true, true) then
        return
    end

    -- Register WM_TOGGLE_HUD action for in-vehicle HUD toggle
    local _, hudEventId = self:addActionEvent(
        spec.actionEvents,
        InputAction.WM_TOGGLE_HUD,
        self,
        WorkflowManagerSpec.actionEventToggleHUD,
        false,  -- triggerUp
        true,   -- triggerDown
        false,  -- triggerAlways
        true,   -- startActive
        nil     -- callbackState
    )

    if hudEventId ~= nil then
        g_inputBinding:setActionEventTextPriority(hudEventId, GS_PRIO_HIGH)
        g_inputBinding:setActionEventTextVisibility(hudEventId, WMSettings.showHelpKeys ~= false)
    end

    -- Register WM_TOGGLE_GUI action so the main dialog is also accessible from vehicles
    local _, guiEventId = self:addActionEvent(
        spec.actionEvents,
        InputAction.WM_TOGGLE_GUI,
        self,
        WorkflowManagerSpec.actionEventToggleGUI,
        false,  -- triggerUp
        true,   -- triggerDown
        false,  -- triggerAlways
        true,   -- startActive
        nil     -- callbackState
    )

    if guiEventId ~= nil then
        g_inputBinding:setActionEventTextPriority(guiEventId, GS_PRIO_HIGH)
        g_inputBinding:setActionEventTextVisibility(guiEventId, WMSettings.showHelpKeys ~= false)
    end

    -- Show HUD when player enters a vehicle that has an active workflow
    if WMHud then
        local wmExec = spec and spec.wmExecution
        if wmExec ~= nil then
            WMHud:show(self)
        end
    end
end

---Called when the toggle HUD action is triggered (in-vehicle)
---@param actionName string The action name
---@param inputValue number The input value
---@param callbackState any The callback state
---@param isAnalog boolean Whether this is an analog input
function WorkflowManagerSpec:actionEventToggleHUD(actionName, inputValue, callbackState, isAnalog)
    if WorkflowManager and WorkflowManager.onToggleHUD then
        WorkflowManager:onToggleHUD()
    end
end

---Called when the toggle GUI action is triggered (in-vehicle)
---@param actionName string The action name
---@param inputValue number The input value
---@param callbackState any The callback state
---@param isAnalog boolean Whether this is an analog input
function WorkflowManagerSpec:actionEventToggleGUI(actionName, inputValue, callbackState, isAnalog)
    if WorkflowManager and WorkflowManager.onToggleGUI then
        WorkflowManager:onToggleGUI()
    end
end

---Register the specialization to all compatible vehicle types
---Called via TypeManager.validateTypes hook
function WorkflowManagerSpec.registerToVehicleTypes()
    -- Only run once
    if WorkflowManagerSpec.registeredToVehicles then
        return
    end

    if g_vehicleTypeManager == nil or g_vehicleTypeManager.types == nil then
        return
    end

    local specName = WorkflowManagerSpec.specName
    if specName == nil then
        return
    end

    local count = 0
    for vehicleType, typeDef in pairs(g_vehicleTypeManager.types) do
        if typeDef ~= nil then
            -- Check if already has our spec
            if typeDef.specializationsByName[specName] == nil then
                -- Check prerequisites
                if WorkflowManagerSpec.prerequisitesPresent(typeDef.specializations) then
                    g_vehicleTypeManager:addSpecialization(vehicleType, specName)
                    count = count + 1
                end
            end
        end
    end

    if count > 0 then
        WorkflowManagerSpec.registeredToVehicles = true
        print(string.format("[WorkflowManager] Added WorkflowManagerSpec to %d vehicle types", count))
    end
end

---Hook function for TypeManager.validateTypes
local function onValidateVehicleTypes(typeManager)
    -- Register to vehicle types when types are being validated
    WorkflowManagerSpec.registerToVehicleTypes()
end

-- Initialize the specialization (called once when file is first loaded)
local function initSpecialization()
    -- Prevent double initialization
    if WorkflowManagerSpec.initialized then
        return
    end
    WorkflowManagerSpec.initialized = true

    local modName = g_currentModName or "FS25_WorkflowManager"
    local specName = modName .. ".workflowManagerSpec"
    WorkflowManagerSpec.specName = specName

    -- Register with the specialization manager
    if g_specializationManager:getSpecializationByName("workflowManagerSpec") == nil then
        g_specializationManager:addSpecialization(
            "workflowManagerSpec",
            "WorkflowManagerSpec",
            Utils.getFilename("src/WorkflowManagerSpec.lua", g_currentModDirectory),
            nil
        )
        print("[WorkflowManager] Registered workflowManagerSpec with g_specializationManager")
    end

    -- Hook TypeManager.validateTypes to register to vehicle types at the right time
    -- This is the pattern AutoDrive uses
    if TypeManager ~= nil and TypeManager.validateTypes ~= nil then
        TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, onValidateVehicleTypes)
        print("[WorkflowManager] Hooked TypeManager.validateTypes for vehicle registration")
    else
        -- Fallback: register immediately (may miss some vehicle types)
        print("[WorkflowManager] TypeManager not available, registering immediately")
        WorkflowManagerSpec.registerToVehicleTypes()
    end
end

---Called by FS25 when the specialization is initialised (after all classes are loaded).
---This is the correct place to register savegame XML schema entries.
function WorkflowManagerSpec.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
    local key = "vehicles.vehicle(?).FS25_WorkflowManager.workflowManagerSpec"
    schema:register(XMLValueType.STRING, key .. "#workflowId",
        "Active workflow ID for WorkflowManager")
    schema:register(XMLValueType.INT,  key .. "#currentStep",
        "Current workflow step for WorkflowManager")
    schema:register(XMLValueType.BOOL, key .. "#isMainVehicle",
        "true = main role, false = support role")
    schema:register(XMLValueType.INT,  key .. "#currentSupportStep",
        "Current support sub-step index (support vehicles only)")
    schema:register(XMLValueType.STRING, key .. "#leaderVehicleUniqueId",
        "Engine uniqueId of the leader vehicle (absent = no leader) — stable across save/load")
    -- Legacy keys — read-only for backward compat with old saves; never written by new code
    schema:register(XMLValueType.INT, key .. "#leaderVehicleXmlIndex",
        "0-based XML vehicle index (vehicles.vehicle(N)) of the leader vehicle (absent = no leader)")
    schema:register(XMLValueType.INT,    key .. "#leaderVehicleIndex",  "Legacy: 1-based leader index")
    schema:register(XMLValueType.STRING, key .. "#leaderWorkflowId",    "Legacy: leader workflow ID")
    schema:register(XMLValueType.STRING, key .. "#status",
        "Workflow status at save time (only written for waiting_for_leader)")
    schema:register(XMLValueType.INT, key .. "#waitingForMainStepIndex",
        "Main vehicle step index when support entered WAITING_FOR_MAIN (support vehicles only)")
    schema:register(XMLValueType.INT, key .. "#supportMainStepIndex",
        "Main step whose sub-step a support vehicle finishes before following main (support vehicles only)")
    schema:register(XMLValueType.BOOL, key .. "#cpWasRunning",
        "true = Courseplay was driving this vehicle at save time (Courseplay never auto-resumes)")
    schema:register(XMLValueType.INT, key .. "#cpResumeWaypoint",
        "Courseplay waypoint to continue field work from after loading; absent = unknown, stay paused")
    print("[WorkflowManager] Registered savegame XML schema")
end

-- Call initialization
initSpecialization()

print("[WorkflowManager] WorkflowManagerSpec module loaded")
