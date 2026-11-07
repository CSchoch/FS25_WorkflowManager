--[[
    WMDocScreenshots Unit Tests (dev-only website screenshot capture)
    Covers command registration, the refusal outside a vehicle, the open -> prepare -> capture ->
    close sequence for every scenario, the demo data the overrides serve while a scenario is up,
    crop boxes, and that every override is put back afterwards (also when deleted mid-run).
]]

describe("WMDocScreenshots", function()

    local registered, shots, updateables, xmlWrites, vehicle, dialogs, opened
    local originals

    local function noop() end

    local function newDialog(name)
        return {
            name = name,
            close = function() table.insert(opened, "close:" .. name) end,
            elements = {
                { profile = "newLayer", elements = {} },
                { profile = "fs25_dialogBg", absPosition = { 0.2, 0.1 }, absSize = { 0.6, 0.8 }, elements = {} },
            },
        }
    end

    local function installStubs()
        registered, shots, updateables, xmlWrites, opened = {}, {}, {}, {}, {}
        vehicle = { getName = function() return "Own Tractor" end }

        _G.addConsoleCommand = function(name) registered[name] = true end
        _G.removeConsoleCommand = function(name) registered[name] = nil end
        _G.getUserProfileAppPath = function() return "C:/FS25/" end
        _G.createFolder = noop
        _G.g_languageShort = "de"
        _G.saveScreenshot = function(path) table.insert(shots, path) end
        _G.XMLFile = {
            create = function(_, path)
                local file = { path = path, values = {} }
                function file:setString(key, value) self.values[key] = value end
                function file:setFloat(key, value) self.values[key] = value end
                function file:save() table.insert(xmlWrites, self) end
                function file:delete() end
                return file
            end,
        }
        _G.g_fillTypeManager = nil
        _G.g_localPlayer = nil
        _G.g_currentMission = {
            controlledVehicle = vehicle,
            addUpdateable = function(_, obj) updateables[obj] = true end,
            removeUpdateable = function(_, obj) updateables[obj] = nil end,
        }

        dialogs = {}
        for _, key in ipairs({ "mainDialog", "editorDialog", "stepDialog", "adSettingsDialog", "modeSelectDialog",
            "leaderSelectDialog" }) do
            dialogs[key] = newDialog(key)
        end
        dialogs.editorDialog.setWorkflow = noop
        dialogs.editorDialog.loadDataCaches = noop
        dialogs.editorDialog.refreshStepList = function(self) self.refreshedAt = self.selectedFlatIndex end
        dialogs.editorDialog.getStepSubtitle = function(_, i, j) return "sub " .. tostring(i) .. "/" .. tostring(j) end

        _G.WorkflowManager = {
            STATUS_RUNNING = "running", STATUS_WAITING_FOR_MAIN = "waiting_for_main",
            workflows = { { id = "real", name = "Real Workflow", steps = {} } },
            reloadWorkflows = function() error("must not reload during a capture") end,
            saveWorkflows = function() error("must not save during a capture") end,
            applyWorkflowChange = function() error("must not write during a capture") end,
            getVehicleWorkflowState = function() return "real state" end,
            showMainDialog = function() table.insert(opened, "main") end,
            showEditorDialog = function() table.insert(opened, "editor") end,
            showStepDialog = function(_, step, _, isSupport, subtitle)
                table.insert(opened, "step:" .. step.type .. ":" .. tostring(isSupport) .. ":" .. subtitle)
            end,
            showADSettingsDialog = function() table.insert(opened, "ad") end,
            showModeSelectDialog = function(_, id) table.insert(opened, "mode:" .. id) end,
            showLeaderSelectDialog = function(_, current)
                -- the real dialog builds its candidate list from WMExecutor.activeVehicles right here
                local names = {}
                for v in pairs(WMExecutor.activeVehicles) do
                    if v ~= current then table.insert(names, v:getName()) end
                end
                table.sort(names)
                table.insert(opened, "leader:" .. table.concat(names, ","))
            end,
        }
        for key, dialog in pairs(dialogs) do WorkflowManager[key] = dialog end

        _G.WMExecutor = {
            activeVehicles = { realVehicle = true },
            update = function() return "real update" end,
            getMainActiveDataForWorkflow = function() return "real main" end,
            getSupportActiveDataListForWorkflow = function() return "real list" end,
            getSupportMainStepIndex = function() return "real index" end,
        }
        _G.ADIntegration = {
            isAvailable = false,
            getDestinations = function() return "real destinations" end,
            getAvailableFillTypes = function() return "real fill types" end,
            isRunning = function() return "real ad" end,
        }
        _G.CPIntegration = {
            isRunning = function() return "real cp" end,
            getProgress = function() return "real progress" end,
        }
        _G.CPCoursesLoader = {
            isInitialized = false,
            getCourses = function() return "real courses" end,
            setGuiOpen = function() error("must not touch the course loader during a capture") end,
        }
        _G.WMHud = {
            x = 0.05, y = 0.2, w = 0.15, h = 0.12, isVisible = true,
            getActiveWorkflow = function() return "real hud" end,
            updateHoverState = function() return "real hover" end,
        }

        originals = {
            workflows = WorkflowManager.workflows,
            reload = WorkflowManager.reloadWorkflows,
            state = WorkflowManager.getVehicleWorkflowState,
            main = WMExecutor.getMainActiveDataForWorkflow,
            adRunning = ADIntegration.isRunning,
            courses = CPCoursesLoader.getCourses,
            hud = WMHud.getActiveWorkflow,
            activeVehicles = WMExecutor.activeVehicles,
            update = WMExecutor.update,
        }
        dofile("src/dev/WMDocScreenshots.lua")
    end

    local function assertRestored()
        assert.are.equal(originals.workflows, WorkflowManager.workflows)
        assert.are.equal(originals.reload, WorkflowManager.reloadWorkflows)
        assert.are.equal(originals.state, WorkflowManager.getVehicleWorkflowState)
        assert.are.equal(originals.main, WMExecutor.getMainActiveDataForWorkflow)
        assert.are.equal(originals.adRunning, ADIntegration.isRunning)
        assert.are.equal(originals.courses, CPCoursesLoader.getCourses)
        assert.are.equal(originals.hud, WMHud.getActiveWorkflow)
        assert.are.equal(originals.activeVehicles, WMExecutor.activeVehicles)
        assert.are.equal(originals.update, WMExecutor.update)
        assert.is_false(ADIntegration.isAvailable)
        assert.is_false(CPCoursesLoader.isInitialized)
        assert.is_true(WMHud.isVisible)
    end

    -- Advance the run by one phase
    local function step()
        WMDocScreenshots:update(WMDocScreenshots.START_MS + WMDocScreenshots.OPEN_MS
            + WMDocScreenshots.PREPARE_MS + WMDocScreenshots.SHOT_MS + WMDocScreenshots.GAP_MS)
    end

    local function runToEnd()
        local guard = 0
        while WMDocScreenshots.running and guard < 200 do
            step()
            guard = guard + 1
        end
    end

    -- Advance until the named scenario is open (just before its prepare step)
    local function openScenario(name)
        local guard = 0
        repeat
            step()
            guard = guard + 1
            local shot = WMDocScreenshots.queue[WMDocScreenshots.index]
        until (shot and shot.name == name and WMDocScreenshots.phase == "prepare") or guard > 200
    end

    before_each(installStubs)

    describe("init / delete", function()
        it("registers and removes the wmDocScreenshots command", function()
            WMDocScreenshots:init()
            assert.is_true(registered["wmDocScreenshots"])
            WMDocScreenshots:delete()
            assert.is_nil(registered["wmDocScreenshots"])
        end)
    end)

    describe("consoleCapture", function()
        it("refuses outside a vehicle and stages nothing", function()
            g_currentMission.controlledVehicle = nil
            local msg = WMDocScreenshots:consoleCapture()
            assert.is_truthy(msg:find("sit in a vehicle", 1, true))
            assert.is_nil(next(updateables))
            assertRestored()
        end)

        it("stages demo data and starts the run in the game language's folder", function()
            local msg = WMDocScreenshots:consoleCapture()
            assert.is_truthy(msg:find("C:/FS25/screenshots/wm_docs/de/", 1, true))
            assert.is_true(updateables[WMDocScreenshots])
            assert.are_not.equal(originals.workflows, WorkflowManager.workflows)
            assert.is_true(ADIntegration.isAvailable)
            assert.is_false(WMHud.isVisible)
            WMDocScreenshots:finish(false)
        end)

        it("tells the player to close the console and waits before the first scenario", function()
            local msg = WMDocScreenshots:consoleCapture()
            assert.is_truthy(msg:find("CLOSE THE CONSOLE", 1, true))
            WMDocScreenshots:update(WMDocScreenshots.START_MS - 1)
            assert.are.equal(0, WMDocScreenshots.index)
            WMDocScreenshots:update(1)
            assert.are.equal(1, WMDocScreenshots.index)
            assert.are.same({ "main" }, opened)
            WMDocScreenshots:finish(false)
        end)

        it("does not start a second run while one is going", function()
            WMDocScreenshots:consoleCapture()
            local msg = WMDocScreenshots:consoleCapture()
            assert.is_truthy(msg:find("already running", 1, true))
            WMDocScreenshots:finish(false)
        end)
    end)

    describe("run", function()
        it("captures every website screenshot once, in order, then restores everything", function()
            WMDocScreenshots:consoleCapture()
            runToEnd()

            local names = {}
            for _, path in ipairs(shots) do
                table.insert(names, (path:gsub("^C:/FS25/screenshots/wm_docs/de/", "")))
            end
            assert.are.same({
                "main-dialog.png", "editor-dialog.png", "editor-support-steps.png", "step-dialog-autodrive.png",
                "step-dialog-courseplay.png", "ad-settings-dialog.png", "mode-dialog.png",
                "leader-select-dialog.png", "hud-running.png", "hud-support-main.png", "hud-support-vehicle.png",
            }, names)
            assert.is_nil(next(updateables))
            assertRestored()
        end)

        it("closes each dialog after its screenshot", function()
            WMDocScreenshots:consoleCapture()
            runToEnd()
            assert.are.same({
                "main", "close:mainDialog",
                "editor", "close:editorDialog",
                "editor", "close:editorDialog",
                "step:autodrive:false:sub 6/nil", "close:stepDialog",
                "step:courseplay:false:sub 4/nil", "close:stepDialog",
                "ad", "close:adSettingsDialog",
                "mode:wm_doc_chopping", "close:modeSelectDialog",
                "leader:Claas Jaguar 1000,John Deere X9 1100", "close:leaderSelectDialog",
            }, opened)
        end)

        it("writes one crop box per screenshot to crops.xml", function()
            WMDocScreenshots:consoleCapture()
            runToEnd()
            assert.are.equal(1, #xmlWrites)
            local crops = xmlWrites[1]
            assert.are.equal("C:/FS25/screenshots/wm_docs/de/crops.xml", crops.path)
            assert.are.equal("main-dialog", crops.values["crops.crop(0)#name"])
            assert.are.equal(0.2, crops.values["crops.crop(0)#x"])
            assert.are.equal(0.8, crops.values["crops.crop(0)#h"])
            assert.are.equal("leader-select-dialog", crops.values["crops.crop(7)#name"])
            assert.are.equal("hud-running", crops.values["crops.crop(8)#name"])
            assert.are.equal(0.05, crops.values["crops.crop(8)#x"])
            assert.are.equal(0.12, crops.values["crops.crop(8)#h"])
            assert.is_nil(crops.values["crops.crop(11)#name"])
        end)

        it("selects support sub-step 2.1 only after the editor has opened", function()
            WMDocScreenshots:consoleCapture()
            openScenario("editor-support-steps")
            assert.is_nil(dialogs.editorDialog.refreshedAt)
            step()
            assert.are.equal(3, dialogs.editorDialog.refreshedAt)
            WMDocScreenshots:finish(false)
        end)

        it("delete mid-run stops it and restores everything without writing crops", function()
            WMDocScreenshots:consoleCapture()
            step()
            WMDocScreenshots:delete()
            assert.is_false(WMDocScreenshots.running)
            assert.are.equal(0, #xmlWrites)
            assertRestored()
        end)
    end)

    describe("real workflows keep running untouched", function()
        it("the step runner sleeps for the whole run and wakes up afterwards", function()
            WMDocScreenshots:consoleCapture()
            assert.is_nil(WMExecutor:update(500))
            WMDocScreenshots:finish(false)
            assert.are.equal("real update", WMExecutor:update(500))
        end)

        it("other vehicles still get the real AD/CP state and workflow state", function()
            WMDocScreenshots:consoleCapture()
            openScenario("hud-support-main")
            local other = {}
            assert.are.equal("real ad", ADIntegration:isRunning(other))
            assert.are.equal("real cp", CPIntegration:isRunning(other))
            assert.are.equal("real progress", CPIntegration:getProgress(other))
            assert.are.equal("real state", WorkflowManager:getVehicleWorkflowState(other))
            WMDocScreenshots:finish(false)
        end)
    end)

    describe("staged data", function()
        it("main dialog: the own vehicle runs Grass Fertilizing at step 6", function()
            WMDocScreenshots:consoleCapture()
            openScenario("main-dialog")
            local data = WorkflowManager:getVehicleWorkflowState(vehicle)
            assert.are.equal("Grass Fertilizing", data.workflow.name)
            assert.are.equal(6, data.currentStep)
            WMDocScreenshots:finish(false)
        end)

        it("editor and step dialogs get the demo destinations, courses and fill types", function()
            WMDocScreenshots:consoleCapture()
            openScenario("editor-dialog")
            assert.are.equal("Fields 41-60/Field 48", ADIntegration:getDestinations()[1].displayName)
            assert.are.equal("Singleplayer/F48/Liming", CPCoursesLoader:getCourses()[1])
            assert.are.same({ name = "WHEAT", title = "WHEAT" }, ADIntegration:getAvailableFillTypes()[1])
            WMDocScreenshots:finish(false)
        end)

        it("fill types carry the game's localized title when it has one", function()
            _G.g_fillTypeManager = {
                getFillTypeByName = function(_, name) return name == "WHEAT" and { title = "Weizen" } or nil end,
            }
            WMDocScreenshots:consoleCapture()
            local list = ADIntegration:getAvailableFillTypes()
            assert.are.equal("Weizen", list[1].title)
            assert.are.equal("BARLEY", list[2].title)
            WMDocScreenshots:finish(false)
        end)

        it("leader select: two running stand-ins, the executor's own list is back right after", function()
            WMDocScreenshots:consoleCapture()
            openScenario("leader-select-dialog")
            assert.are.equal("leader:Claas Jaguar 1000,John Deere X9 1100", opened[#opened])
            assert.are.equal(originals.activeVehicles, WMExecutor.activeVehicles)
            WMDocScreenshots:finish(false)
        end)

        it("HUD with support: main runs Grass Chopping with two support vehicles, CP at 27%", function()
            WMDocScreenshots:consoleCapture()
            openScenario("hud-support-main")
            assert.is_true(WMHud.isVisible)
            local workflow, data = WMHud:getActiveWorkflow()
            assert.are.equal("Grass Chopping", workflow.name)
            assert.are.equal(vehicle, data.vehicle)
            local supports = WMExecutor:getSupportActiveDataListForWorkflow(workflow.id)
            assert.are.equal(2, #supports)
            assert.are.equal("Fendt 942 Vario", supports[1].vehicle:getName())
            assert.are.equal("waiting_for_main", supports[2].status)
            assert.are.equal(data, WMExecutor:getMainActiveDataForWorkflow(workflow.id))
            assert.is_true(CPIntegration:isRunning(vehicle))
            assert.are.equal(0.27, CPIntegration:getProgress(vehicle))
            assert.is_false(ADIntegration:isRunning(vehicle))
            WMDocScreenshots:finish(false)
        end)

        it("HUD as support vehicle: follows the Claas Jaguar on step 3 while AD drives", function()
            WMDocScreenshots:consoleCapture()
            openScenario("hud-support-vehicle")
            local workflow, data = WMHud:getActiveWorkflow()
            assert.is_false(data.isMainVehicle)
            local main = WMExecutor:getMainActiveDataForWorkflow(workflow.id)
            assert.are.equal("Claas Jaguar 1000", main.vehicle:getName())
            assert.are.equal(3, WMExecutor:getSupportMainStepIndex(data, main))
            assert.is_true(ADIntegration:isRunning(vehicle))
            assert.is_false(CPIntegration:isRunning(vehicle))
            WMDocScreenshots:finish(false)
        end)

        it("dialogs hide the HUD so it cannot appear around them", function()
            WMDocScreenshots:consoleCapture()
            openScenario("hud-support-vehicle")
            WMDocScreenshots:finish(false)
            installStubs()
            WMDocScreenshots:consoleCapture()
            openScenario("main-dialog")
            assert.is_false(WMHud.isVisible)
            WMDocScreenshots:finish(false)
        end)

        it("the mouse cannot change the HUD hover mid-run", function()
            WMDocScreenshots:consoleCapture()
            openScenario("hud-running")
            WMHud.hoveredButton = "stop"
            WMHud.updateHoverState(WMHud, 0.5, 0.5)
            assert.is_nil(WMHud.hoveredButton)
            WMDocScreenshots:finish(false)
        end)
    end)

    describe("getDialogRect", function()
        it("returns the dialog panel's box", function()
            local rect = WMDocScreenshots:getDialogRect(newDialog("x"))
            assert.are.same({ x = 0.2, y = 0.1, w = 0.6, h = 0.8 }, rect)
        end)

        it("falls back to the whole screen when the panel is not found", function()
            local rect = WMDocScreenshots:getDialogRect({ elements = { { profile = "other" } } })
            assert.are.same({ x = 0, y = 0, w = 1, h = 1 }, rect)
        end)
    end)
end)
