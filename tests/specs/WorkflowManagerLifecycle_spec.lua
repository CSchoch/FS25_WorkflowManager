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

    -- =========================================================================
    -- Reload from disk (web editor while the game runs)
    -- =========================================================================
    describe("reloadWorkflows", function()
        local WM, fresh, fileRead, fileFound, inSync, stoppedVehicles, running, definitionsChanged

        before_each(function()
            WM = loadModule(false)
            _G.g_server = {}
            fresh, fileRead, fileFound, inSync = {}, true, true, true
            _G.WMStorage = {
                isInSyncWithDisk = function() return inSync end,
                loadWorkflows = function() return fresh, fileRead, fileFound end,
            }
            stoppedVehicles, running, definitionsChanged = {}, {}, 0
            _G.WMExecutor = {
                getActiveVehiclesForWorkflow = function(_, id) return running[id] or {} end,
                stopWorkflow = function(_, v) table.insert(stoppedVehicles, v) end,
                onWorkflowDefinitionsChanged = function() definitionsChanged = definitionsChanged + 1 end,
            }
            WM.broadcastState = function() end
            _G.WMHud = { openDialogCount = 0 }
            _G.g_i18n = { getText = function(_, key) return key end }
        end)

        it("keeps each workflow's table and replaces its definition", function()
            local live = { id = "a", name = "Old", steps = {} }
            WM.workflows = { live }
            fresh = { { id = "a", name = "New", steps = { { type = "park" } }, adSettings = { pipeOffset = 1 } } }

            assert.is_true(WM:reloadWorkflows())

            assert.are.equal(live, WM.workflows[1])
            assert.are.equal("New", live.name)
            assert.are.equal("park", live.steps[1].type)
            assert.are.equal(1, live.adSettings.pipeOffset)
        end)

        it("adds new workflows and follows the file's order", function()
            local a = { id = "a", name = "A", steps = {} }
            WM.workflows = { a }
            fresh = { { id = "b", name = "B", steps = {} }, { id = "a", name = "A", steps = {} } }

            WM:reloadWorkflows()

            assert.are.equal(2, #WM.workflows)
            assert.are.equal("b", WM.workflows[1].id)
            assert.are.equal(a, WM.workflows[2])
        end)

        it("drops a workflow removed from the file and stops every vehicle running it", function()
            WM.workflows = { { id = "gone", name = "Gone", steps = {} } }
            local main, support = {}, {}
            -- Like the real executor: execution states, not vehicles
            running.gone = { { vehicle = main }, { vehicle = support } }
            fresh = {}

            WM:reloadWorkflows()

            assert.are.equal(0, #WM.workflows)
            assert.are.same({ main, support }, stoppedVehicles)
            assert.are.equal(1, #WM.pendingUserMessages)
            assert.is_true(WM.pendingUserMessages[1].isError)
        end)

        it("tells the executor that definitions changed", function()
            WM:reloadWorkflows()
            assert.are.equal(1, definitionsChanged)
        end)

        it("does nothing on a multiplayer client", function()
            _G.g_server = nil
            WM.workflows = { { id = "a", name = "A", steps = {} } }
            assert.is_false(WM:reloadWorkflows())
            assert.are.equal(1, #WM.workflows)
        end)

        it("does nothing when the savegame path changed since the last load/save", function()
            inSync = false
            WM.workflows = { { id = "a", name = "A", steps = {} } }
            assert.is_false(WM:reloadWorkflows())
            assert.are.equal(1, #WM.workflows)
        end)

        it("keeps the workflows when the file cannot be read", function()
            fileRead = false
            WM.workflows = { { id = "a", name = "A", steps = {} } }
            assert.is_false(WM:reloadWorkflows())
            assert.are.equal(1, #WM.workflows)
            assert.are.equal(0, #stoppedVehicles)
        end)

        it("keeps every workflow and vehicle running when the file is missing (bug-306)", function()
            -- An empty tempsavegame folder during a game save read as "no workflows" and
            -- removed all of them, stopping every vehicle
            fileFound = false
            fresh = {}
            local live = { id = "a", name = "A", steps = {} }
            WM.workflows = { live }
            running.a = { { vehicle = {} } }

            assert.is_false(WM:reloadWorkflows())

            assert.are.same({ live }, WM.workflows)
            assert.are.equal(0, #stoppedVehicles)
            assert.are.equal(0, definitionsChanged)
        end)
    end)

    describe("deleteWorkflow", function()
        local WM, stoppedVehicles, sentEvents, running

        before_each(function()
            WM = loadModule(false)
            stoppedVehicles, sentEvents, running = {}, {}, {}
            _G.WMExecutor = {
                getActiveVehiclesForWorkflow = function(_, id) return running[id] or {} end,
                stopWorkflow = function(_, v) table.insert(stoppedVehicles, v) end,
            }
            WM.broadcastState = function() end
            _G.WMCommandEvent = { new = function(cmd, v) return { cmd = cmd, vehicle = v } end }
        end)

        it("stops every vehicle running the workflow, main and support", function()
            _G.g_server = {}
            WM.workflows = { { id = "wf", name = "WF", steps = {} } }
            local main, support1, support2 = {}, {}, {}
            running.wf = { { vehicle = main }, { vehicle = support1 }, { vehicle = support2 } }

            assert.is_true(WM:deleteWorkflow("wf"))

            assert.are.equal(0, #WM.workflows)
            assert.are.same({ main, support1, support2 }, stoppedVehicles)
        end)

        it("leaves vehicles running other workflows alone", function()
            _G.g_server = {}
            WM.workflows = { { id = "a", name = "A", steps = {} }, { id = "b", name = "B", steps = {} } }
            local other = {}
            running.b = { { vehicle = other } }

            WM:deleteWorkflow("a")

            assert.are.equal(0, #stoppedVehicles)
            assert.are.equal("b", WM.workflows[1].id)
        end)

        it("sends a stop for each vehicle from a multiplayer client", function()
            _G.g_server = nil
            _G.g_client = { sendEvent = function(_, e) table.insert(sentEvents, e) end }
            WM.workflows = { { id = "wf", name = "WF", steps = {} } }
            local main, support = {}, {}
            running.wf = { { vehicle = main }, { vehicle = support } }

            WM:deleteWorkflow("wf")

            assert.are.equal(2, #sentEvents)
            assert.are.equal(main, sentEvents[1].vehicle)
            assert.are.equal(support, sentEvents[2].vehicle)
            assert.are.equal("stop", sentEvents[1].cmd)
        end)
    end)

    describe("applyWorkflowChange", function()
        local WM, order

        before_each(function()
            WM = loadModule(false)
            order = {}
            WM.reloadWorkflows = function() table.insert(order, "reload") end
            WM.saveWorkflows = function() table.insert(order, "save") end
        end)

        it("reloads, applies the change, then writes the file", function()
            _G.g_server = {}
            WM:applyWorkflowChange(function() table.insert(order, "change") end)
            assert.are.same({ "reload", "change", "save" }, order)
        end)

        it("only applies the change on a multiplayer client (no workflow file there)", function()
            _G.g_server = nil
            WM:applyWorkflowChange(function() table.insert(order, "change") end)
            assert.are.same({ "change" }, order)
        end)
    end)

    describe("game save hook", function()
        local WM, loads, saves

        before_each(function()
            _G.FSBaseMission = { delete = function() end, saveSavegame = function() end }
            WM = loadModule(false)
            WM.isInitialized = true
            _G.g_server = {}
            loads, saves = 0, 0
            _G.WMStorage = {
                isInSyncWithDisk = function() return WM._inSync end,
                loadWorkflows = function() loads = loads + 1 return {}, true end,
                saveWorkflows = function() saves = saves + 1 end,
            }
            _G.WMExecutor = {
                getActiveVehiclesForWorkflow = function() return {} end,
                onWorkflowDefinitionsChanged = function() end,
            }
        end)

        it("reloads the file before writing it, keeping web-editor edits", function()
            WM._inSync = true
            FSBaseMission.saveSavegame()
            assert.are.equal(1, loads)
            assert.are.equal(1, saves)
        end)

        it("writes the in-memory workflows to a new savegame slot without merging", function()
            WM._inSync = false
            FSBaseMission.saveSavegame()
            assert.are.equal(0, loads)
            assert.are.equal(1, saves)
        end)
    end)

    describe("deleteMap", function()
        it("does not write the workflow file (quitting must not overwrite web-editor edits)", function()
            local WM = loadModule(false)
            local saves = 0
            _G.WMStorage = { saveWorkflows = function() saves = saves + 1 end }
            _G.WMExecutor = { activeVehicles = {} }
            _G.WMGameSettings = { delete = function() end }
            _G.WMHud = { delete = function() end }
            _G.WMConsoleCommands = { delete = function() end }

            WM:deleteMap()

            assert.are.equal(0, saves)
        end)
    end)

    -- =========================================================================
    -- Start validation returns its reason instead of flashing the HUD
    -- =========================================================================
    describe("canStartWorkflow", function()
        local WM, blinks

        before_each(function()
            WM = loadModule(false)
            blinks = 0
            _G.g_currentMission = { hud = { showBlinkingWarning = function() blinks = blinks + 1 end } }
            _G.g_i18n = { getText = function(_, key) return key end }
            _G.g_localPlayer = { getCurrentVehicle = function() return nil end }
        end)

        it("reports a workflow that no longer exists", function()
            WM.workflows = {}
            local ok, reason = WM:canStartWorkflow("ghost")
            assert.is_false(ok)
            assert.are.equal("wm_warning_workflow_not_found", reason)
        end)

        it("reports a workflow without steps", function()
            WM.workflows = { { id = "a", name = "A", steps = {} } }
            local ok, reason = WM:canStartWorkflow("a")
            assert.is_false(ok)
            assert.are.equal("wm_warning_no_steps", reason)
        end)

        it("reports a player on foot, without the game's blinking warning", function()
            WM.workflows = { { id = "a", name = "A", steps = { { type = "park" } } } }
            local ok, reason = WM:canStartWorkflow("a")
            assert.is_false(ok)
            assert.are.equal("wm_warning_no_vehicle", reason)
            assert.are.equal(0, blinks)
        end)

        it("startWorkflow hands the reason to showUserMessage", function()
            WM.workflows = { { id = "a", name = "A", steps = { { type = "park" } } } }
            local shown
            WM.showUserMessage = function(_, text, isError) shown = { text = text, isError = isError } end
            assert.is_false(WM:startWorkflow("a"))
            assert.are.equal("wm_warning_no_vehicle", shown.text)
            assert.is_true(shown.isError)
        end)
    end)

    -- =========================================================================
    -- Player messages
    -- =========================================================================
    describe("showUserMessage / flushUserMessages", function()
        local WM, notifications

        before_each(function()
            WM = loadModule(false)
            notifications = {}
            _G.FSBaseMission.INGAME_NOTIFICATION_OK = 1
            _G.FSBaseMission.INGAME_NOTIFICATION_CRITICAL = 2
            _G.g_currentMission = {
                hud = {},
                addIngameNotification = function(_, kind, text)
                    table.insert(notifications, { kind = kind, text = text })
                end,
            }
            _G.WMHud = { openDialogCount = 0 }
        end)

        it("writes into the open WM dialog's status line", function()
            local status
            _G.WMHud.activeDialog = { showStatus = function(_, text, isError) status = { text, isError } end }
            _G.WMHud.openDialogCount = 1

            WM:showUserMessage("Course missing", true)

            assert.are.same({ "Course missing", true }, status)
            assert.are.equal(0, #WM.pendingUserMessages)
        end)

        it("queues messages for a dialog without a status line and shows them once it closed", function()
            _G.WMHud.activeDialog = {}
            _G.WMHud.openDialogCount = 1
            WM:showUserMessage("Course missing", true)

            WM:flushUserMessages()
            assert.are.equal(0, #notifications)   -- never on top of an open dialog

            _G.WMHud.openDialogCount = 0
            WM:flushUserMessages()
            assert.are.equal(1, #notifications)
            assert.are.equal(2, notifications[1].kind)
            assert.are.equal(0, #WM.pendingUserMessages)
        end)

        it("shows infos as OK notifications", function()
            WM:showUserMessage("Workflow started", false)
            WM:flushUserMessages()
            assert.are.equal(1, notifications[1].kind)
        end)

        it("keeps messages queued while the mission HUD does not exist yet (loading)", function()
            _G.g_currentMission.hud = nil
            WM:showUserMessage("Restore failed", true)
            WM:flushUserMessages()
            assert.are.equal(0, #notifications)
            assert.are.equal(1, #WM.pendingUserMessages)
        end)
    end)

    describe("formatUserMessage", function()
        local WM

        before_each(function()
            WM = loadModule(false)
            _G.g_i18n = { getText = function(_, key)
                return ({ two = "%s: course '%s'", none = "plain" })[key]
            end }
        end)

        it("fills the placeholders", function()
            assert.are.equal("Fendt: course 'F1'", WM:formatUserMessage("two", { "Fendt", "F1" }))
        end)

        it("never raises a format error for missing arguments", function()
            assert.are.equal("Fendt: course '?'", WM:formatUserMessage("two", { "Fendt" }))
        end)

        it("ignores surplus arguments and texts without placeholders", function()
            assert.are.equal("plain", WM:formatUserMessage("none", { "x" }))
        end)
    end)

    describe("notifyFarm", function()
        local WM, broadcasts, shown

        before_each(function()
            WM = loadModule(false)
            broadcasts, shown = {}, {}
            _G.g_server = { broadcastEvent = function(_, event) table.insert(broadcasts, event) end }
            _G.WMUserMessageEvent = {
                new = function(farmId, key, isError, args)
                    return { farmId = farmId, key = key, isError = isError, args = args }
                end,
            }
            _G.g_i18n = { getText = function(_, key) return key .. " %s" end }
            WM.showUserMessage = function(_, text, isError) table.insert(shown, text) end
        end)

        local function vehicleOfFarm(farmId)
            return { getOwnerFarmId = function() return farmId end, getName = function() return "Fendt" end }
        end

        it("sends the key and string arguments to the clients", function()
            WM:notifyFarm(vehicleOfFarm(3), true, "wm_error_x", "Fendt", nil)
            assert.are.equal(1, #broadcasts)
            assert.are.equal(3, broadcasts[1].farmId)
            assert.are.equal("wm_error_x", broadcasts[1].key)
            assert.are.same({ "Fendt", "" }, broadcasts[1].args)
        end)

        it("shows it locally to a player of that farm", function()
            _G.g_localPlayer = { farmId = 3 }
            WM:notifyFarm(vehicleOfFarm(3), true, "wm_error_x", "Fendt")
            assert.are.same({ "wm_error_x Fendt" }, shown)
        end)

        it("does not show it to a player of another farm", function()
            _G.g_localPlayer = { farmId = 4 }
            WM:showFarmMessage(3, "wm_error_x", { "Fendt" }, true)
            assert.are.equal(0, #shown)
        end)

        it("shows nothing on a dedicated server (no local player)", function()
            _G.g_localPlayer = nil
            WM:notifyFarm(vehicleOfFarm(3), true, "wm_error_x", "Fendt")
            assert.are.equal(0, #shown)
            assert.are.equal(1, #broadcasts)
        end)
    end)

    -- =========================================================================
    -- F1 help window keys
    -- =========================================================================
    describe("help-key visibility", function()
        local WM, visibility

        before_each(function()
            WM = loadModule(false)
            visibility = {}
            _G.WMSettings = { showHelpKeys = true }
            _G.InputAction = { WM_TOGGLE_HUD = "WM_TOGGLE_HUD", WM_TOGGLE_GUI = "WM_TOGGLE_GUI" }
            _G.GS_PRIO_NORMAL = 1
            _G.g_inputBinding = {
                registerActionEvent = function(_, action) return true, "global_" .. action end,
                setActionEventTextPriority = function() end,
                setActionEventTextVisibility = function(_, id, visible) visibility[id] = visible end,
            }
        end)

        it("registers the on-foot Toggle GUI key hidden from the help when the option is off", function()
            _G.WMSettings.showHelpKeys = false
            WM:registerGlobalActions()
            assert.is_false(visibility["global_WM_TOGGLE_GUI"])
            assert.are.equal("global_WM_TOGGLE_GUI", WM.globalGuiEventId)
        end)

        it("switches the on-foot and in-vehicle entries live", function()
            WM:registerGlobalActions()
            local vehicle = { spec_workflowManagerSpec = { actionEvents = {
                WM_TOGGLE_HUD = { actionEventId = "veh_hud" },
                WM_TOGGLE_GUI = { actionEventId = "veh_gui" },
            } } }
            _G.g_localPlayer = { getCurrentVehicle = function() return vehicle end }

            _G.WMSettings.showHelpKeys = false
            WM:applyHelpKeyVisibility()

            assert.is_false(visibility["global_WM_TOGGLE_GUI"])
            assert.is_false(visibility["veh_hud"])
            assert.is_false(visibility["veh_gui"])

            _G.WMSettings.showHelpKeys = true
            WM:applyHelpKeyVisibility()
            assert.is_true(visibility["veh_hud"])
        end)

        it("is safe on foot (no vehicle)", function()
            _G.g_localPlayer = { getCurrentVehicle = function() return nil end }
            WM:applyHelpKeyVisibility()
            assert.is_nil(next(visibility))
        end)
    end)
end)
