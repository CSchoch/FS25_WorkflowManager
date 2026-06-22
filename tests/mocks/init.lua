--[[
    Test Mock Initialization
    Loads all mock modules and sets up the test environment
]]

-- Set up package path to find modules from the mod root
local function setupPackagePath()
    -- Get the directory of this init.lua file
    local info = debug.getinfo(1, "S")
    local path = info.source:match("@(.*/)")
    if path then
        -- We're in tests/mocks/, go up two levels to mod root
        local modRoot = path:gsub("tests/mocks/$", "")
        package.path = modRoot .. "?.lua;" ..
                       modRoot .. "src/?.lua;" ..
                       modRoot .. "tests/?.lua;" ..
                       modRoot .. "tests/mocks/?.lua;" ..
                       modRoot .. "tests/fixtures/?.lua;" ..
                       package.path
    end
end

setupPackagePath()

-- Store original globals to restore later if needed
local originalGlobals = {}

-- Load game globals mock first (sets up _G.g_currentMission, etc.)
require("game_globals")

-- Load XMLFile mock
require("XMLFile")

-- Load vehicle mock factory
require("vehicle")

-- Load fixtures
require("workflows")

-- Helper function to reset all mocks between tests
function resetMocks()
    -- Reset game globals
    _G.g_currentMission = {
        time = 12345678,
        controlledVehicle = nil,
        hud = {
            showBlinkingWarning = function() end
        },
        _updateables = {},
        addUpdateable = function(self, obj)
            table.insert(self._updateables, obj)
        end,
        removeUpdateable = function(self, obj)
            for i, v in ipairs(self._updateables) do
                if v == obj then table.remove(self._updateables, i) return end
            end
        end,
    }

    _G.g_localPlayer = {
        getCurrentVehicle = function() return nil end
    }

    -- Reset WMLogger call tracking
    if _G.WMLogger then
        _G.WMLogger.calls = {
            debug = {},
            info = {},
            warning = {},
            error = {}
        }
    end

    -- Reset WMEventHandler
    if _G.WMEventHandler then
        _G.WMEventHandler.listeners = {}
    end

    -- Reset WorkflowManager
    if _G.WorkflowManager then
        _G.WorkflowManager.workflows = {}
        _G.WorkflowManager.activeWorkflows = {}
        _G.WorkflowManager.isInitialized = true
        _G.WorkflowManager.isShuttingDown = false
    end

    -- Reset WMExecutor
    if _G.WMExecutor then
        _G.WMExecutor.activeWorkflows = {}
        _G.WMExecutor.pendingADCallbacks = {}
        _G.WMExecutor.updateTimer = 0
        _G.WMExecutor.isInitialized = true
    end

    -- Reset CPIntegration per-vehicle state
    if _G.CPIntegration and _G.CPIntegration._reset then
        _G.CPIntegration:_reset()
    end

    -- Clear XMLFile in-memory storage
    if _G.XMLFile and _G.XMLFile._clearAll then
        _G.XMLFile._clearAll()
    end

    -- Reset fileExists to default (no files exist)
    _G.fileExists = function(path) return false end

    -- Reset math.random seed for deterministic tests
    math.randomseed(12345)
end

-- Helper to load source files with proper path handling
function loadSource(relativePath)
    local fullPath = "src/" .. relativePath
    local chunk, err = loadfile(fullPath)
    if chunk then
        return chunk()
    else
        -- Try without src/ prefix
        chunk, err = loadfile(relativePath)
        if chunk then
            return chunk()
        end
        error("Failed to load source file: " .. relativePath .. " - " .. tostring(err))
    end
end

-- Print confirmation that mocks are loaded
print("[Test Setup] Mocks initialized")
