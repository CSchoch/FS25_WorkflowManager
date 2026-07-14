--[[
    WorkflowManager - Event Handler Utility
    Manages custom events and callbacks for workflow state changes

    Author: WorkflowManager Team
]]

---@class WMEventHandler
WMEventHandler = {}

-- Event types
WMEventHandler.EVENT_WORKFLOW_STARTED = "workflowStarted"
WMEventHandler.EVENT_WORKFLOW_STOPPED = "workflowStopped"
WMEventHandler.EVENT_WORKFLOW_PAUSED = "workflowPaused"
WMEventHandler.EVENT_WORKFLOW_RESUMED = "workflowResumed"
WMEventHandler.EVENT_WORKFLOW_COMPLETED = "workflowCompleted"
WMEventHandler.EVENT_WORKFLOW_ERROR = "workflowError"
WMEventHandler.EVENT_STEP_STARTED = "stepStarted"
WMEventHandler.EVENT_STEP_COMPLETED = "stepCompleted"
WMEventHandler.EVENT_STEP_ERROR = "stepError"
WMEventHandler.EVENT_STEP_CHANGED = "stepChanged"
WMEventHandler.EVENT_COURSEPLAY_FINISHED = "courseplayFinished"

-- Internal storage for event listeners
WMEventHandler.listeners = {}

---Initialize the event handler
function WMEventHandler:init()
    self.listeners = {}
    WMLogger:debug("EventHandler initialized")
end

---Register an event listener
---@param eventType string Event type constant
---@param callback function Callback function to call when event fires
---@param target table|nil Target object for callback (self)
---@return number listenerId ID of the registered listener
function WMEventHandler:addEventListener(eventType, callback, target)
    if self.listeners[eventType] == nil then
        self.listeners[eventType] = {}
    end

    local listenerId = #self.listeners[eventType] + 1
    self.listeners[eventType][listenerId] = {
        callback = callback,
        target = target
    }

    WMLogger:debug("Added event listener for: %s (ID: %d)", eventType, listenerId)
    return listenerId
end

---Remove an event listener
---@param eventType string Event type constant
---@param listenerId number Listener ID returned from addEventListener
function WMEventHandler:removeEventListener(eventType, listenerId)
    if self.listeners[eventType] ~= nil then
        self.listeners[eventType][listenerId] = nil
        WMLogger:debug("Removed event listener: %s (ID: %d)", eventType, listenerId)
    end
end

---Fire an event to all registered listeners
---@param eventType string Event type constant
---@param data table|nil Event data to pass to listeners
function WMEventHandler:fireEvent(eventType, data)
    WMLogger:debug("Firing event: %s", eventType)

    if self.listeners[eventType] == nil then
        return
    end

    for _, listener in pairs(self.listeners[eventType]) do
        if listener.callback ~= nil then
            if listener.target ~= nil then
                listener.callback(listener.target, eventType, data)
            else
                listener.callback(eventType, data)
            end
        end
    end
end

---Remove all listeners for an event type
---@param eventType string Event type constant
function WMEventHandler:removeAllListeners(eventType)
    if eventType ~= nil then
        self.listeners[eventType] = nil
    else
        self.listeners = {}
    end
end

---Subscribe to an event (convenience method)
---@param eventType string Event type constant
---@param target table Target object (self)
---@param callback function Method to call on target
---@return number listenerId ID of the registered listener
function WMEventHandler:subscribe(eventType, target, callback)
    return self:addEventListener(eventType, callback, target)
end

---Unsubscribe from an event
---@param eventType string Event type constant
---@param listenerId number Listener ID
function WMEventHandler:unsubscribe(eventType, listenerId)
    self:removeEventListener(eventType, listenerId)
end
