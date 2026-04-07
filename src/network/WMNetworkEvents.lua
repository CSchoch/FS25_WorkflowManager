--[[
    WorkflowManager - Network Events
    Multiplayer synchronisation via FS25 network event system.

    WMCommandEvent  : Client -> Server  (start/stop/pause/resume/next_step/prev_step)
    WMStateSyncEvent: Server -> All Clients  (current step + status per vehicle)

    Architecture:
    - WMExecutor.update() only runs on the server (g_server ~= nil).
    - HUD and dialog commands are routed through WorkflowManager:sendCommand().
      On the server/singleplayer host this calls executeNetworkCommand() directly.
      On a pure client this sends a WMCommandEvent to the server.
    - After every executor state change the server calls WorkflowManager:broadcastState()
      which sends WMStateSyncEvent to all connected clients so their local wmExecution
      mirrors stay current for HUD display.
]]

-- ============================================================
-- WMCommandEvent  (Client -> Server)
-- ============================================================
WMCommandEvent = {}
local WMCommandEvent_mt = Class(WMCommandEvent, Event)
InitEventClass(WMCommandEvent, "WMCommandEvent")

function WMCommandEvent.emptyNew()
    return Event.new(WMCommandEvent_mt)
end

---Create a new command event.
---@param commandType string       "start"|"stop"|"pause"|"resume"|"next_step"|"prev_step"
---@param vehicle     table        Target vehicle (needs a network node)
---@param workflowId  string|nil   Required for "start" only
---@param isMain      boolean|nil  true = main role, false = support role (only for "start")
function WMCommandEvent.new(commandType, vehicle, workflowId, isMain)
    local self = WMCommandEvent.emptyNew()
    self.commandType = commandType
    self.vehicle     = vehicle
    self.workflowId  = workflowId
    self.isMain      = (isMain ~= false)  -- default true
    return self
end

function WMCommandEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.commandType)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    local hasId = self.workflowId ~= nil
    streamWriteBool(streamId, hasId)
    if hasId then
        streamWriteString(streamId, self.workflowId)
    end
    -- isMain is only meaningful for "start", but always write it for simplicity
    streamWriteBool(streamId, self.isMain)
end

function WMCommandEvent:readStream(streamId, connection)
    self.commandType = streamReadString(streamId)
    self.vehicle     = NetworkUtil.readNodeObject(streamId)
    local hasId      = streamReadBool(streamId)
    if hasId then
        self.workflowId = streamReadString(streamId)
    end
    self.isMain = streamReadBool(streamId)
    self:run(connection)
end

function WMCommandEvent:run(connection)
    -- Only execute on the server (when received from a client connection)
    if not connection:getIsServer() then
        WMLogger:debug("WMCommandEvent received on server: cmd=%s isMain=%s", self.commandType, tostring(self.isMain))
        WorkflowManager:executeNetworkCommand(self.commandType, self.vehicle, self.workflowId, self.isMain)
    end
    -- Clients do nothing here – they wait for the WMStateSyncEvent response
end

-- ============================================================
-- WMStateSyncEvent  (Server -> All Clients)
-- ============================================================
WMStateSyncEvent = {}
local WMStateSyncEvent_mt = Class(WMStateSyncEvent, Event)
InitEventClass(WMStateSyncEvent, "WMStateSyncEvent")

function WMStateSyncEvent.emptyNew()
    return Event.new(WMStateSyncEvent_mt)
end

---Snapshot a vehicle's current execution state for broadcast.
---@param vehicle table Target vehicle
function WMStateSyncEvent.new(vehicle)
    local self = WMStateSyncEvent.emptyNew()
    self.vehicle = vehicle
    local activeData = vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
    if activeData ~= nil then
        self.isActive           = true
        self.workflowId         = activeData.workflow.id
        self.currentStep        = activeData.currentStep
        self.status             = activeData.status
        self.isMainVehicle      = activeData.isMainVehicle ~= false
        self.currentSupportStep = activeData.currentSupportStep or 0
    else
        self.isActive           = false
        self.workflowId         = ""
        self.currentStep        = 0
        self.status             = ""
        self.isMainVehicle      = true
        self.currentSupportStep = 0
    end
    return self
end

function WMStateSyncEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isActive)
    if self.isActive then
        streamWriteString(streamId, self.workflowId)
        streamWriteInt32(streamId, self.currentStep)
        streamWriteString(streamId, self.status)
        streamWriteBool(streamId, self.isMainVehicle)
        streamWriteInt32(streamId, self.currentSupportStep)
    end
end

function WMStateSyncEvent:readStream(streamId, connection)
    self.vehicle  = NetworkUtil.readNodeObject(streamId)
    self.isActive = streamReadBool(streamId)
    if self.isActive then
        self.workflowId         = streamReadString(streamId)
        self.currentStep        = streamReadInt32(streamId)
        self.status             = streamReadString(streamId)
        self.isMainVehicle      = streamReadBool(streamId)
        self.currentSupportStep = streamReadInt32(streamId)
    end
    self:run(connection)
end

function WMStateSyncEvent:run(connection)
    local vehicle = self.vehicle
    if vehicle == nil or vehicle.spec_workflowManagerSpec == nil then
        WMLogger:warning("WMStateSyncEvent: received for unknown/unspecced vehicle")
        return
    end

    if not self.isActive then
        -- Workflow ended on this vehicle – clear client-side mirror
        vehicle.spec_workflowManagerSpec.wmExecution = nil
        WMExecutor.activeVehicles[vehicle] = nil
        if WMHud and WMHud.vehicle == vehicle then
            WMHud:hide()
        end
        WMLogger:debug("WMStateSyncEvent: cleared workflow state on vehicle")
        return
    end

    -- Find the workflow definition (loaded from XML, same on all peers)
    local workflow = WorkflowManager:getWorkflowById(self.workflowId)
    if workflow == nil then
        WMLogger:warning("WMStateSyncEvent: unknown workflowId '%s' – ignoring", tostring(self.workflowId))
        return
    end

    -- Update (or create) the client-side execution mirror
    local activeData = vehicle.spec_workflowManagerSpec.wmExecution
    if activeData == nil then
        activeData = { waitingForCompletion = false }
        vehicle.spec_workflowManagerSpec.wmExecution = activeData
    end
    activeData.workflow             = workflow
    activeData.vehicle              = vehicle
    activeData.status               = self.status
    activeData.currentStep          = self.currentStep
    activeData.isMainVehicle        = self.isMainVehicle
    activeData.currentSupportStep   = self.currentSupportStep ~= 0 and self.currentSupportStep or nil

    WMExecutor.activeVehicles[vehicle] = true

    -- Show HUD if the local player is currently controlling this vehicle
    local controlled = g_currentMission and g_currentMission.controlledVehicle
    if controlled == vehicle and WMHud then
        WMHud:show(vehicle)
    end

    WMLogger:debug("WMStateSyncEvent: synced vehicle step=%d status=%s wf=%s",
        self.currentStep, self.status, self.workflowId)
end

print("[WorkflowManager] WMNetworkEvents module loaded")
