--[[
    Game Globals Mock
    Provides mock implementations of FS25 global objects and functions
]]

-- Core game state
_G.g_currentMission = {
    time = 12345678,
    isRunning = true,
    controlledVehicle = nil,
    hud = {
        showBlinkingWarning = function(self, text, duration) end
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

-- Player object
_G.g_localPlayer = {
    getCurrentVehicle = function(self)
        return _G.g_currentMission.controlledVehicle
    end
}

-- Internationalization
_G.g_i18n = {
    getText = function(self, key, ...)
        -- Return the key itself (or with parameters substituted)
        local args = {...}
        if #args > 0 then
            return string.format(key, unpack(args))
        end
        return key
    end
}

-- GUI system (minimal mock)
_G.g_gui = {
    showDialog = function(self, dialogName) end,
    loadProfiles = function(self, path) end,
    loadGui = function(self, xmlPath, name, controller) end
}

-- Input binding system
_G.g_inputBinding = {
    registerActionEvent = function(self, actionName, target, callback, triggerUp, triggerDown, triggerAlways, startActive)
        return true, "eventId_" .. actionName
    end,
    setActionEventTextVisibility = function(self, eventId, visible) end,
    setActionEventTextPriority = function(self, eventId, priority) end
}

-- Priority constants
_G.GS_PRIO_NORMAL = 1
_G.GS_PRIO_HIGH = 2
_G.GS_PRIO_LOW = 0

-- Mod info (used in WorkflowManager)
_G.g_currentModName = "FS25_WorkflowManager"
_G.g_currentModDirectory = "./"

-- Date function
_G.getDate = function(format)
    if format then
        -- Return a predictable date for testing
        return "2026-02-02 12:00:00"
    end
    return os.date()
end

-- Logging system (FS25's Logging object)
_G.Logging = {
    info = function(format, ...)
        -- For tests, we can optionally capture these
    end,
    warning = function(format, ...)
    end,
    error = function(format, ...)
    end,
    devInfo = function(format, ...)
    end,
    devWarning = function(format, ...)
    end,
    devError = function(format, ...)
    end
}

-- Utils namespace
_G.Utils = {
    getFilename = function(filename, baseDir)
        if baseDir then
            return baseDir .. filename
        end
        return filename
    end,
    appendedFunction = function(oldFunc, newFunc)
        return function(...)
            if oldFunc then oldFunc(...) end
            if newFunc then newFunc(...) end
        end
    end,
    prependedFunction = function(oldFunc, newFunc)
        return function(...)
            if newFunc then newFunc(...) end
            if oldFunc then oldFunc(...) end
        end
    end
}

-- GuiUtils
_G.GuiUtils = {
    getUVs = function(uvTable)
        return uvTable
    end
}

-- File existence check (FS25 global)
_G.fileExists = function(path)
    return false  -- Default: file not found; override per-test as needed
end

-- Source function (loads Lua files in FS25)
_G.source = function(filepath)
    -- In tests, we don't actually load files via source()
    -- The test framework loads files directly
end

-- FSBaseMission (for hooks)
_G.FSBaseMission = {
    saveSavegame = function() end,
    delete = function() end
}

-- Input constants
_G.Input = {
    KEY_F9 = 68,
    isKeyPressed = function(key)
        return false
    end
}

-- PlayerInputComponent (for input registration hook)
_G.PlayerInputComponent = {
    registerGlobalPlayerActionEvents = function(playerInput, ...)
    end
}

-- AI Message classes
_G.AIMessageSuccessStoppedByUser = {
    new = function()
        return { type = "AIMessageSuccessStoppedByUser" }
    end
}

-- addModEventListener function
_G.addModEventListener = function(listener)
    -- Store the listener for potential testing
    _G._modEventListeners = _G._modEventListeners or {}
    table.insert(_G._modEventListeners, listener)
end

-- WMDevConfig mock (development configuration)
_G.WMDevConfig = {
    isDevMode = function() return false end,
    isDebugLogging = function() return false end,
    shouldLogAPICalls = function() return false end,
    shouldLogEvents = function() return false end,
    shouldLogStateChanges = function() return false end,
    printConfig = function() end,
    AUTO_CREATE_TEST_WORKFLOW = false
}

-- WMLogger mock with call tracking
_G.WMLogger = {
    LEVEL_DEBUG = 1,
    LEVEL_INFO = 2,
    LEVEL_WARNING = 3,
    LEVEL_ERROR = 4,
    currentLevel = 2,  -- INFO by default
    prefix = "[WorkflowManager]",
    initializedFromConfig = false,

    -- Call tracking for assertions
    calls = {
        debug = {},
        info = {},
        warning = {},
        error = {}
    },

    debug = function(self, message, ...)
        if self.currentLevel <= self.LEVEL_DEBUG then
            local formatted = string.format(message, ...)
            table.insert(self.calls.debug, formatted)
        end
    end,

    info = function(self, message, ...)
        if self.currentLevel <= self.LEVEL_INFO then
            local formatted = string.format(message, ...)
            table.insert(self.calls.info, formatted)
        end
    end,

    warning = function(self, message, ...)
        if self.currentLevel <= self.LEVEL_WARNING then
            local formatted = string.format(message, ...)
            table.insert(self.calls.warning, formatted)
        end
    end,

    error = function(self, message, ...)
        if self.currentLevel <= self.LEVEL_ERROR then
            local formatted = string.format(message, ...)
            table.insert(self.calls.error, formatted)
        end
    end,

    setLevel = function(self, level)
        self.currentLevel = level
    end,

    enableDebug = function(self)
        self.currentLevel = self.LEVEL_DEBUG
    end,

    disableDebug = function(self)
        self.currentLevel = self.LEVEL_INFO
    end,

    initFromDevConfig = function(self)
        -- No-op in tests
    end,

    apiCall = function(self, apiName, methodName, ...)
    end,

    event = function(self, eventType, data)
    end,

    stateChange = function(self, entity, oldState, newState)
    end
}

-- Integration mocks (minimal)
_G.ADIntegration = {
    init = function() end,
    update = function(self, dt) end,
    isAvailable = function() return true end,
    isRunning = function(self, vehicle) return false end,
    isRouteComplete = function(self, vehicle) return false end,
    isRefuelRepairComplete = function(self, vehicle, flagName) return false end,
    startRoute = function(self, vehicle, target, action, unloadTarget, fillType) return true end,
    startParkRoute = function(self, vehicle) return true end,
    startRefuelRoute = function(self, vehicle) return true, false end,
    startRepairRoute = function(self, vehicle) return true end,
    stopRoute = function(self, vehicle) end,
    pauseRoute = function(self, vehicle) end,
    resumeRoute = function(self, vehicle) end,
    setStartCPOnCompletion = function(self, vehicle, enabled) end,
    clearCPHandoff = function(self, vehicle) end,
    getDestinations = function() return {} end,
    applyWorkflowSettings = function(self, vehicle, settings) end,
}

_G.CPIntegration = {
    _vehicleCourses  = {},  -- [vehicle] = courseName
    _vehicleRunning  = {},  -- [vehicle] = bool

    init = function(self) end,
    update = function(self, dt) end,
    isAvailable = function(self) return true end,
    isRunning = function(self, vehicle) return self._vehicleRunning[vehicle] == true end,
    hasCourse = function(self, vehicle) return self._vehicleCourses[vehicle] ~= nil end,
    loadCourse = function(self, vehicle, courseName)
        self._vehicleCourses[vehicle] = courseName
        return true
    end,
    getCurrentCourseName = function(self, vehicle) return self._vehicleCourses[vehicle] end,
    startFieldWork = function(self, vehicle, startAtFirst, startAtNearest)
        self._vehicleRunning[vehicle] = true
        return true
    end,
    stopCourse = function(self, vehicle)
        self._vehicleRunning[vehicle] = false
    end,
    holdCourse = function(self, vehicle, duration)
        -- freeze in place (still "has course", not running)
        self._vehicleRunning[vehicle] = false
    end,
    resumeCourse = function(self, vehicle)
        self._vehicleRunning[vehicle] = true
    end,
    getCourses = function(self) return {} end,

    -- Test helper: reset all per-vehicle state
    _reset = function(self)
        self._vehicleCourses = {}
        self._vehicleRunning = {}
    end
}

_G.CPCoursesLoader = {
    init = function() end,
    update = function(self, dt) end
}

_G.CPVehiclesLoader = {
    init = function() end,
    update = function(self, dt) end
}

-- GUI mocks
_G.WMManagerGUI = {
    init = function() end,
    show = function() end,
    hide = function() end,
    update = function(self, dt) end,
    draw = function() end,
    cleanup = function() end,
    onMouseEvent = function(self, posX, posY, isDown, isUp, button) end,
    isVisible = false,
    selectedWorkflowIndex = 0
}

_G.WMEditorGUI = {
    init = function() end,
    update = function(self, dt) end,
    draw = function() end,
    cleanup = function() end,
    onMouseEvent = function(self, posX, posY, isDown, isUp, button) end,
    onScrollEvent = function(self, direction) return false end,
    isVisible = false
}

_G.WMHud = {
    init = function() end,
    update = function(self, dt) end,
    draw = function() end,
    delete = function() end,
    show = function(self, vehicle) end,
    hide = function() end,
    toggle = function(self, vehicle) end,
    getIsVisible = function() return false end,
    mouseEvent = function(self, posX, posY, isDown, isUp, button) return false end
}

_G.WMDebugUtil = {
    init = function() end,
    update = function(self, dt) end,
    draw = function() end,
    createTestWorkflow = function() return nil end
}

_G.WMStorage = {
    init = function() end,
    saveWorkflows = function(self, workflows) end,
    loadWorkflows = function() return {} end
}

print("[Mock] Game globals loaded")
