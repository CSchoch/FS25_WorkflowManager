--[[
    WorkflowManager - Logger Utility
    Provides logging functionality with different log levels

    Author: WorkflowManager Team
]]

---@class WMLogger
WMLogger = {}

-- Log levels
WMLogger.LEVEL_DEBUG = 1
WMLogger.LEVEL_INFO = 2
WMLogger.LEVEL_WARNING = 3
WMLogger.LEVEL_ERROR = 4

-- Current log level (can be changed for debugging)
-- Will be updated by initFromDevConfig() if WMDevConfig is available
WMLogger.currentLevel = WMLogger.LEVEL_INFO

-- Prefix for all log messages
WMLogger.prefix = "[WorkflowManager]"

-- Track if we've been initialized from dev config
WMLogger.initializedFromConfig = false

---Format a log message with variable arguments
---@param message string Format string
---@param ... any Arguments for format string
---@return string formatted Formatted message
local function formatMessage(message, ...)
    if select("#", ...) > 0 then
        return string.format(message, ...)
    end
    return message
end

---Log a debug message
---@param message string Message format string
---@param ... any Arguments for format string
function WMLogger:debug(message, ...)
    if self.currentLevel <= self.LEVEL_DEBUG then
        local formatted = formatMessage(message, ...)
        print(string.format("%s [DEBUG] %s", self.prefix, formatted))
    end
end

---Log an info message
---@param message string Message format string
---@param ... any Arguments for format string
function WMLogger:info(message, ...)
    if self.currentLevel <= self.LEVEL_INFO then
        local formatted = formatMessage(message, ...)
        Logging.info("%s %s", self.prefix, formatted)
    end
end

---Log a warning message
---@param message string Message format string
---@param ... any Arguments for format string
function WMLogger:warning(message, ...)
    if self.currentLevel <= self.LEVEL_WARNING then
        local formatted = formatMessage(message, ...)
        Logging.warning("%s %s", self.prefix, formatted)
    end
end

---Log an error message
---@param message string Message format string
---@param ... any Arguments for format string
function WMLogger:error(message, ...)
    if self.currentLevel <= self.LEVEL_ERROR then
        local formatted = formatMessage(message, ...)
        Logging.error("%s %s", self.prefix, formatted)
    end
end

---Set the current log level
---@param level number Log level constant
function WMLogger:setLevel(level)
    self.currentLevel = level
end

---Enable debug logging
function WMLogger:enableDebug()
    self.currentLevel = self.LEVEL_DEBUG
end

---Disable debug logging (set to info)
function WMLogger:disableDebug()
    self.currentLevel = self.LEVEL_INFO
end

---Initialize logger from development config
---Call this after WMDevConfig is loaded
function WMLogger:initFromDevConfig()
    if self.initializedFromConfig then
        return
    end

    if WMDevConfig ~= nil then
        if WMDevConfig:isDebugLogging() then
            self.currentLevel = self.LEVEL_DEBUG
            self:debug("Logger initialized in DEBUG mode from DevConfig")
        else
            self.currentLevel = self.LEVEL_INFO
        end
        self.initializedFromConfig = true
    end
end

---Log an API call (only if enabled in DevConfig)
---@param apiName string API name (e.g., "AutoDrive", "Courseplay")
---@param methodName string Method being called
---@param ... any Additional parameters to log
function WMLogger:apiCall(apiName, methodName, ...)
    if WMDevConfig ~= nil and WMDevConfig:shouldLogAPICalls() then
        local params = ""
        local args = {...}
        if #args > 0 then
            local paramStrings = {}
            for _, arg in ipairs(args) do
                table.insert(paramStrings, tostring(arg))
            end
            params = table.concat(paramStrings, ", ")
        end
        print(string.format("%s [API] %s.%s(%s)", self.prefix, apiName, methodName, params))
    end
end

---Log an event (only if enabled in DevConfig)
---@param eventType string Event type
---@param data table|nil Event data
function WMLogger:event(eventType, data)
    if WMDevConfig ~= nil and WMDevConfig:shouldLogEvents() then
        local dataStr = ""
        if data ~= nil then
            local parts = {}
            for k, v in pairs(data) do
                table.insert(parts, string.format("%s=%s", tostring(k), tostring(v)))
            end
            dataStr = " {" .. table.concat(parts, ", ") .. "}"
        end
        print(string.format("%s [EVENT] %s%s", self.prefix, eventType, dataStr))
    end
end

---Log a state change (only if enabled in DevConfig)
---@param entity string Entity name (e.g., "Workflow", "Step")
---@param oldState string|nil Old state
---@param newState string New state
function WMLogger:stateChange(entity, oldState, newState)
    if WMDevConfig ~= nil and WMDevConfig:shouldLogStateChanges() then
        if oldState ~= nil then
            print(string.format("%s [STATE] %s: %s -> %s", self.prefix, entity, oldState, newState))
        else
            print(string.format("%s [STATE] %s: -> %s", self.prefix, entity, newState))
        end
    end
end
