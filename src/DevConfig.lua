--[[
    WorkflowManager - Development Configuration
    Settings for development and debugging

    Author: WorkflowManager Team

    IMPORTANT: Set DEV_MODE to false before releasing the mod!
]]

---@class WMDevConfig
WMDevConfig = {}

-- ============================================================================
-- DEVELOPMENT MODE
-- Set to false for release builds
-- ============================================================================
WMDevConfig.DEV_MODE = true

-- ============================================================================
-- DEBUG SETTINGS
-- ============================================================================

-- Enable verbose logging (DEBUG level)
WMDevConfig.DEBUG_LOGGING = true

-- Show debug overlay on screen
WMDevConfig.SHOW_DEBUG_OVERLAY = false

-- Log all API calls to AutoDrive/Courseplay
WMDevConfig.LOG_API_CALLS = true

-- Log workflow state changes
WMDevConfig.LOG_STATE_CHANGES = true

-- Log event firing
WMDevConfig.LOG_EVENTS = true

-- ============================================================================
-- TEST SETTINGS
-- ============================================================================

-- Auto-create a test workflow on load (for testing)
WMDevConfig.AUTO_CREATE_TEST_WORKFLOW = false

-- Skip vehicle checks (for testing without proper vehicle)
WMDevConfig.SKIP_VEHICLE_CHECKS = false

-- Simulate AutoDrive completion after X milliseconds (0 = disabled)
WMDevConfig.SIMULATE_AD_COMPLETION_MS = 0

-- Simulate Courseplay completion after X milliseconds (0 = disabled)
WMDevConfig.SIMULATE_CP_COMPLETION_MS = 0

-- ============================================================================
-- PERFORMANCE SETTINGS
-- ============================================================================

-- GUI refresh interval (ms)
WMDevConfig.GUI_REFRESH_INTERVAL = 500

-- ============================================================================
-- UI SETTINGS
-- ============================================================================

-- Show FPS counter in debug overlay
WMDevConfig.SHOW_FPS = true

-- Debug overlay position (0-1 screen coordinates)
WMDevConfig.DEBUG_OVERLAY_X = 0.01
WMDevConfig.DEBUG_OVERLAY_Y = 0.95

-- Debug text size
WMDevConfig.DEBUG_TEXT_SIZE = 0.012

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

---Check if development mode is enabled
---@return boolean enabled
function WMDevConfig:isDevMode()
    return self.DEV_MODE == true
end

---Check if debug logging is enabled
---@return boolean enabled
function WMDevConfig:isDebugLogging()
    return self.DEV_MODE and self.DEBUG_LOGGING
end

---Check if API call logging is enabled
---@return boolean enabled
function WMDevConfig:shouldLogAPICalls()
    return self.DEV_MODE and self.LOG_API_CALLS
end

---Check if state change logging is enabled
---@return boolean enabled
function WMDevConfig:shouldLogStateChanges()
    return self.DEV_MODE and self.LOG_STATE_CHANGES
end

---Check if event logging is enabled
---@return boolean enabled
function WMDevConfig:shouldLogEvents()
    return self.DEV_MODE and self.LOG_EVENTS
end

---Print current dev configuration
function WMDevConfig:printConfig()
    if not self.DEV_MODE then
        return
    end

    print("==============================================")
    print("[WorkflowManager] Development Configuration")
    print("==============================================")
    print("  DEV_MODE: " .. tostring(self.DEV_MODE))
    print("  DEBUG_LOGGING: " .. tostring(self.DEBUG_LOGGING))
    print("  SHOW_DEBUG_OVERLAY: " .. tostring(self.SHOW_DEBUG_OVERLAY))
    print("  LOG_API_CALLS: " .. tostring(self.LOG_API_CALLS))
    print("  LOG_STATE_CHANGES: " .. tostring(self.LOG_STATE_CHANGES))
    print("  LOG_EVENTS: " .. tostring(self.LOG_EVENTS))
    print("  SIMULATE_AD_COMPLETION_MS: " .. tostring(self.SIMULATE_AD_COMPLETION_MS))
    print("  SIMULATE_CP_COMPLETION_MS: " .. tostring(self.SIMULATE_CP_COMPLETION_MS))
    print("==============================================")
end
