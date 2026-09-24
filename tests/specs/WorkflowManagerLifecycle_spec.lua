--[[
    WorkflowManager - lifecycle tests (dev config, dialog loading, shutdown)

    These paths used to be wrapped in pcall. GIANTS' TestRunner (PublicLuaCheck) rejects every
    pcall, so they now rely on explicit checks instead - this spec pins those checks down
    against the REAL src/WorkflowManager.lua, loaded with `source` recorded rather than run.
]]

describe("WorkflowManager lifecycle", function()
    local sourced

    local function loadModule(devConfigExists)
        sourced = {}
        _G.source = function(path) table.insert(sourced, path) end
        _G.fileExists = function() return devConfigExists end
        _G.WMDevConfig = nil
        dofile("src/WorkflowManager.lua")
        return _G.WorkflowManager
    end

    local function wasSourced(path)
        for _, p in ipairs(sourced) do
            if p == path then return true end
        end
        return false
    end

    setup(function()
        _G.Utils = {
            getFilename = function(name) return name end,
            appendedFunction = function(old, new) return new end,
            prependedFunction = function(old, new) return new end,
        }
        _G.addModEventListener = function() end
        _G.g_currentModName = "FS25_WorkflowManager"
        _G.g_currentModDirectory = "./"

        local noop = function() end
        _G.WMLogger = {
            initFromDevConfig = noop, info = noop, debug = noop,
            warning = noop, error = noop, apiCall = noop,
            event = noop, state = noop,
        }
    end)

    before_each(function()
        _G.FSBaseMission = { delete = function() end }
    end)

    describe("dev config", function()
        it("is not sourced when the file is absent (release zip) and release defaults apply", function()
            loadModule(false)
            assert.is_false(wasSourced("src/DevConfig.lua"))
            assert.is_false(_G.WMDevConfig:isDevMode())
        end)

        it("is sourced when the file exists (development checkout)", function()
            loadModule(true)
            assert.is_true(wasSourced("src/DevConfig.lua"))
        end)
    end)

    describe("loadDialog", function()
        local WM

        before_each(function()
            WM = loadModule(false)
        end)

        it("returns the controller when the GUI loads", function()
            local controller = {}
            _G.g_gui = { loadGui = function() return {} end }
            assert.are.equal(controller, WM:loadDialog("xml/gui/WMMainDialog.xml", "WMMainDialog", controller))
        end)

        it("returns nil when Gui:loadGui fails (it returns nil and logs the error itself)", function()
            _G.g_gui = { loadGui = function() return nil end }
            assert.is_nil(WM:loadDialog("xml/gui/WMMainDialog.xml", "WMMainDialog", {}))
        end)

        it("loads the given XML under the given GUI name", function()
            local gotPath, gotName
            _G.g_gui = { loadGui = function(_, path, name) gotPath, gotName = path, name return {} end }
            WM:loadDialog("xml/gui/WMStepDialog.xml", "WMStepDialog", {})
            assert.are.equal("xml/gui/WMStepDialog.xml", gotPath)
            assert.are.equal("WMStepDialog", gotName)
        end)
    end)

    -- GIANTS' TestRunner (ObsoleteFiles) only sees a dialog XML as used when its full path
    -- appears as a literal string; a concatenated path got all six dialogs flagged as unused.
    describe("dialog XML references", function()
        it("names every dialog XML by its full literal path", function()
            local f = assert(io.open("src/WorkflowManager.lua", "r"))
            local src = f:read("*a")
            f:close()
            for _, name in ipairs({ "WMMainDialog", "WMEditorDialog", "WMStepDialog",
                    "WMModeSelectDialog", "WMADSettingsDialog", "WMLeaderVehicleSelectDialog" }) do
                assert.is_truthy(src:find('"xml/gui/' .. name .. '.xml"', 1, true))
            end
        end)
    end)

    describe("releaseADForShutdown", function()
        local WM, cleared, stopped

        before_each(function()
            WM = loadModule(false)
            cleared, stopped = {}, {}
            _G.ADIntegration = {
                clearCPHandoff = function(_, v) table.insert(cleared, v) end,
                stopRoute = function(_, v) table.insert(stopped, v) end,
            }
            -- Courseplay must never be stopped during shutdown (see CLAUDE.md / memory)
            _G.CPIntegration = {
                stopCourse = function() error("CPIntegration:stopCourse must not run during shutdown") end,
            }
        end)

        local function activeVehicle()
            local v = { spec_workflowManagerSpec = {} }
            v.spec_workflowManagerSpec.wmExecution = { vehicle = v }
            return v
        end

        it("clears the handoff and stops AD on every live vehicle, then forgets them", function()
            local a, b = activeVehicle(), activeVehicle()
            _G.WMExecutor = { activeVehicles = { [a] = true, [b] = true } }

            WM:releaseADForShutdown()

            assert.are.equal(2, #cleared)
            assert.are.equal(2, #stopped)
            assert.is_nil(next(_G.WMExecutor.activeVehicles))
        end)

        it("skips a vehicle the engine has already deleted", function()
            local gone = activeVehicle()
            gone.isDeleted = true
            _G.WMExecutor = { activeVehicles = { [gone] = true } }

            WM:releaseADForShutdown()

            assert.are.equal(0, #cleared)
            assert.are.equal(0, #stopped)
            assert.is_nil(next(_G.WMExecutor.activeVehicles))
        end)

        it("runs from the FSBaseMission.delete hook only once initialized", function()
            local v = activeVehicle()
            _G.WMExecutor = { activeVehicles = { [v] = true } }

            WM.isInitialized = false
            FSBaseMission.delete()
            assert.are.equal(0, #stopped)

            WM.isInitialized = true
            FSBaseMission.delete()
            assert.are.equal(1, #stopped)
            assert.is_true(WM.isShuttingDown)
        end)
    end)
end)
