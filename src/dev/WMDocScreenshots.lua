-- ============================================================
-- WMDocScreenshots — DEV ONLY, not part of the release zip
-- ============================================================
-- Console command `wmDocScreenshots`: opens every dialog and HUD state the website shows, with
-- demo workflows and vehicles, and saves a screenshot of each plus a crop box (crops.xml).
-- tools/crop_screenshots.py then cuts them into website/static/img/screenshots/.
--
-- Nothing real is changed: the demo data is put in place by overriding read functions on the
-- WM globals (workflow list, executor lookups, AD/CP queries, HUD target) and every override is
-- restored when the run ends. Saving is switched off for the duration of the run.
--
-- create_release.ps1 excludes this file; WorkflowManager.lua sources it only if it exists.

---@class WMDocScreenshots
WMDocScreenshots = {}

WMDocScreenshots.START_MS = 5000    -- command -> first scenario: time to close the console
WMDocScreenshots.OPEN_MS = 800      -- dialog/HUD open -> optional prepare step
WMDocScreenshots.PREPARE_MS = 400   -- prepare step -> screenshot
WMDocScreenshots.SHOT_MS = 400      -- screenshot -> close
WMDocScreenshots.GAP_MS = 400       -- close -> next scenario
WMDocScreenshots.DIALOG_PROFILE = "fs25_dialogBg"

local function noop() end

function WMDocScreenshots:init()
    addConsoleCommand("wmDocScreenshots",
        "Dev: capture the website screenshots (sit in a vehicle first)", "consoleCapture", self)
end

function WMDocScreenshots:delete()
    removeConsoleCommand("wmDocScreenshots")
    if self.running then
        self:finish(false)
    end
end

-- ------------------------------------------------------------
-- Demo data (same workflows as tools/render_ui_preview.lua)
-- ------------------------------------------------------------

local function steps(count)
    local list = {}
    for i = 1, count do
        list[i] = { type = "autodrive", action = "drive", target = "Fields 1-20/Field " .. i }
    end
    return list
end

function WMDocScreenshots:buildSample()
    local chopping = {
        id = "wm_doc_chopping", name = "Grass Chopping",
        steps = {
            { type = "autodrive", action = "drive", target = "Fields 41-60/Field 50" },
            { type = "courseplay", action = "fieldwork", target = "Singleplayer/F49/Chopping",
              support = { { type = "autodrive", action = "unload", target = "Fields 41-60/Field 50" } } },
            { type = "autodrive", action = "drive", target = "Fields 41-60/Field 50",
              support = { { type = "autodrive", action = "deliver", target = "_Farm 1 Center/Farm 1 Silage",
                            finishBeforeSwitch = true } } },
            { type = "courseplay", action = "fieldwork", target = "Singleplayer/F50/Chopping",
              support = { { type = "autodrive", action = "unload", target = "Fields 41-60/Field 50" } } },
            { type = "wait_for_leader" },
            { type = "autodrive", action = "drive", target = "Fields 41-60/Field 51 Grass" },
            { type = "courseplay", action = "fieldwork", target = "Singleplayer/F51/Chopping",
              support = { { type = "autodrive", action = "unload", target = "Fields 41-60/Field 51 Grass" } } },
            { type = "unlock_follower" },
            { type = "refuel" },
            { type = "park" },
        },
    }
    local fertilizing = { id = "wm_doc_fert", name = "Grass Fertilizing", steps = {
        { type = "autodrive", action = "drive", target = "Fields 81-x/Field 91" },
        { type = "courseplay", action = "fieldwork", target = "Singleplayer/F91/Fertilizing" },
        { type = "autodrive", action = "drive", target = "_Farm 1 Center/Fertilizer" },
        { type = "autodrive", action = "drive", target = "Fields 81-x/Field 92" },
        { type = "courseplay", action = "fieldwork", target = "Singleplayer/F92/Fertilizing" },
        { type = "courseplay", action = "fieldwork", target = "Singleplayer/F91/Fertilizing" },
        { type = "autodrive", action = "drive", target = "Fields 81-x/Field 93" },
        { type = "courseplay", action = "fieldwork", target = "Singleplayer/F93/Fertilizing" },
        { type = "refuel" },
        { type = "park" },
    } }
    local threshingSupport = { id = "wm_doc_thresh_sup", name = "Threshing with Support", steps = steps(32) }
    threshingSupport.steps[2].support = { { type = "autodrive", action = "unload", target = "Fields 1-20/Field 2" } }

    return {
        chopping = chopping,
        fertilizing = fertilizing,
        workflows = {
            { id = "wm_doc_thresh", name = "Threshing", steps = steps(20) },
            threshingSupport,
            { id = "wm_doc_baling", name = "Baling", steps = steps(32) },
            { id = "wm_doc_bales", name = "Bale Collecting", steps = steps(32) },
            { id = "wm_doc_mow", name = "Mowing", steps = steps(12) },
            fertilizing,
            { id = "wm_doc_lime", name = "Grass Liming", steps = steps(10) },
            chopping,
            { id = "wm_doc_gbales", name = "Grass Bale Collecting", steps = steps(6) },
        },
        adDestinations = {
            "Fields 41-60/Field 48", "Fields 41-60/Field 49", "Fields 41-60/Field 50",
            "Fields 41-60/Field 51 Grass", "_Farm 1 Center/Farm 1 Silage", "_Farm 1 Center/Grain Silo",
            "_Farm 1 Center/Fertilizer", "Sell Points/Grain Mill",
        },
        cpCourses = {
            "Singleplayer/F48/Liming", "Singleplayer/F48/Sowing", "Singleplayer/F49/Fertilizing",
            "Singleplayer/F49/Chopping", "Singleplayer/F50/Chopping", "Singleplayer/F51/Chopping",
        },
        fillTypes = { "WHEAT", "BARLEY", "CANOLA", "SEEDS", "FERTILIZER", "LIME" },
    }
end

---Fill types as the editor expects them, titled in the game language where the game knows them
function WMDocScreenshots:getFillTypes()
    local list = {}
    for _, name in ipairs(self.sample.fillTypes) do
        local title = name
        if g_fillTypeManager ~= nil then
            local fillType = g_fillTypeManager:getFillTypeByName(name)
            if fillType ~= nil and fillType.title ~= nil then
                title = fillType.title
            end
        end
        table.insert(list, { name = name, title = title })
    end
    return list
end

local function running(workflow, step, extra)
    local data = { workflow = workflow, currentStep = step, status = WorkflowManager.STATUS_RUNNING,
        isMainVehicle = true }
    for k, v in pairs(extra or {}) do data[k] = v end
    return data
end

---A stand-in for another vehicle: only its name and execution data are ever read
local function fakeVehicle(name, data)
    local vehicle = { getName = function() return name end }
    vehicle.spec_workflowManagerSpec = { wmExecution = data }
    data.vehicle = vehicle
    return vehicle
end

-- ------------------------------------------------------------
-- Staging: temporary overrides, restored in reverse order
-- ------------------------------------------------------------

function WMDocScreenshots:override(tbl, key, value)
    table.insert(self.originals, { tbl = tbl, key = key, value = rawget(tbl, key) })
    tbl[key] = value
end

function WMDocScreenshots:restoreOverrides()
    for i = #(self.originals or {}), 1, -1 do
        local entry = self.originals[i]
        entry.tbl[entry.key] = entry.value
    end
    self.originals = {}
end

---Execution data of every staged vehicle (own vehicle first)
function WMDocScreenshots:getStagedData()
    local list = {}
    if self.ownData ~= nil then
        table.insert(list, self.ownData)
    end
    for _, data in ipairs(self.otherData or {}) do
        table.insert(list, data)
    end
    return list
end

function WMDocScreenshots:stage()
    local shots = self
    local sample = self.sample
    self.originals = {}

    -- The step runner sleeps for the whole run. It reads the same AD/CP queries and workflow list
    -- that are swapped below: left running, it took "CP not running" for a finished field and
    -- looked the next real AD target up in the demo destinations (2026-11-08: stopped two real
    -- workflows). AutoDrive and Courseplay keep driving meanwhile; the runner catches up afterwards.
    self:override(WMExecutor, "update", noop)

    -- Workflow list; nothing may be written to or re-read from the savegame meanwhile
    local realState = WorkflowManager.getVehicleWorkflowState
    self:override(WorkflowManager, "workflows", sample.workflows)
    self:override(WorkflowManager, "reloadWorkflows", noop)
    self:override(WorkflowManager, "saveWorkflows", noop)
    self:override(WorkflowManager, "applyWorkflowChange", noop)
    self:override(WorkflowManager, "getVehicleWorkflowState", function(wm, vehicle)
        if vehicle == shots.vehicle then return shots.ownData end
        return realState(wm, vehicle)
    end)

    -- Executor lookups (reads only; the executor's own vehicle list stays untouched)
    self:override(WMExecutor, "getMainActiveDataForWorkflow", function(_, workflowId)
        for _, data in ipairs(shots:getStagedData()) do
            if data.workflow.id == workflowId and data.isMainVehicle ~= false then return data end
        end
        return nil
    end)
    self:override(WMExecutor, "getSupportActiveDataListForWorkflow", function(_, workflowId)
        local list = {}
        for _, data in ipairs(shots:getStagedData()) do
            if data.workflow.id == workflowId and data.isMainVehicle == false then table.insert(list, data) end
        end
        return list
    end)
    self:override(WMExecutor, "getSupportMainStepIndex", function(_, supportData, mainData)
        return supportData.supportMainStepIndex or mainData.currentStep
    end)

    -- AutoDrive / Courseplay queries: staged answers for the own vehicle only, every other
    -- vehicle still gets the real one
    local realADRunning, realCPRunning = ADIntegration.isRunning, CPIntegration.isRunning
    local realCPProgress = CPIntegration.getProgress
    self:override(ADIntegration, "isAvailable", true)
    self:override(ADIntegration, "getDestinations", function()
        local list = {}
        for _, name in ipairs(sample.adDestinations) do table.insert(list, { displayName = name }) end
        return list
    end)
    self:override(ADIntegration, "getAvailableFillTypes", function() return shots:getFillTypes() end)
    self:override(ADIntegration, "isRunning", function(ad, vehicle)
        if vehicle == shots.vehicle then return shots.adRunning == true end
        return realADRunning(ad, vehicle)
    end)
    self:override(CPIntegration, "isRunning", function(cp, vehicle)
        if vehicle == shots.vehicle then return shots.cpProgress ~= nil end
        return realCPRunning(cp, vehicle)
    end)
    self:override(CPIntegration, "getProgress", function(cp, vehicle)
        if vehicle == shots.vehicle then return shots.cpProgress end
        return realCPProgress(cp, vehicle)
    end)
    self:override(CPCoursesLoader, "isInitialized", true)
    self:override(CPCoursesLoader, "getCourses", function() return sample.cpCourses end)
    self:override(CPCoursesLoader, "setGuiOpen", noop)

    -- HUD: staged target and a fixed hover (the mouse must not change it mid-run)
    self:override(WMHud, "getActiveWorkflow", function()
        if shots.ownData == nil then return nil, nil end
        return shots.ownData.workflow, shots.ownData
    end)
    self:override(WMHud, "updateHoverState", function(hud) hud.hoveredButton = shots.hovered end)
end

-- ------------------------------------------------------------
-- Crop boxes (normalized screen coordinates, origin bottom-left)
-- ------------------------------------------------------------

local function findByProfile(element, profile)
    if element == nil then return nil end
    if element.profile == profile then return element end
    for _, child in ipairs(element.elements or {}) do
        local found = findByProfile(child, profile)
        if found ~= nil then return found end
    end
    return nil
end

---Box of a dialog's background panel; the whole screen when it cannot be found
function WMDocScreenshots:getDialogRect(dialog)
    local panel = findByProfile(dialog, self.DIALOG_PROFILE)
    if panel ~= nil and panel.absPosition ~= nil and panel.absSize ~= nil then
        return { x = panel.absPosition[1], y = panel.absPosition[2], w = panel.absSize[1], h = panel.absSize[2] }
    end
    return { x = 0, y = 0, w = 1, h = 1 }
end

function WMDocScreenshots:getHudRect()
    return { x = WMHud.x, y = WMHud.y, w = WMHud.w, h = WMHud.h }
end

-- ------------------------------------------------------------
-- Scenarios: file name = website/static/img/screenshots/<name>.png
-- ------------------------------------------------------------

function WMDocScreenshots:setVehicles(ownData, others, adRunning, cpProgress, hovered)
    self.ownData = ownData
    if ownData ~= nil then ownData.vehicle = self.vehicle end
    self.otherData = others or {}
    self.adRunning = adRunning
    self.cpProgress = cpProgress
    self.hovered = hovered
end

function WMDocScreenshots:buildScenarios()
    local sample = self.sample
    local wm = WorkflowManager

    local function dialogShot(name, dialogKey, open, prepare)
        return {
            name = name,
            open = function(shots)
                WMHud.isVisible = false
                open(shots)
            end,
            prepare = prepare,
            crop = function(shots) return shots:getDialogRect(wm[dialogKey]) end,
            close = function() wm[dialogKey]:close() end,
        }
    end

    local function hudShot(name, stageVehicles)
        return {
            name = name,
            open = function(shots)
                stageVehicles(shots)
                WMHud.isVisible = true
            end,
            crop = function(shots) return shots:getHudRect() end,
            close = noop,
        }
    end

    local function openStep(step, isSupport, stepIndex, supportIndex)
        return function()
            local editor = wm.editorDialog
            editor:setWorkflow(sample.chopping, false)
            editor:loadDataCaches()
            wm:showStepDialog(step, noop, isSupport, editor:getStepSubtitle(stepIndex, supportIndex))
        end
    end

    return {
        dialogShot("main-dialog", "mainDialog", function(shots)
            shots:setVehicles(running(sample.fertilizing, 6), nil, false, 0.27)
            wm:showMainDialog()
        end),
        dialogShot("editor-dialog", "editorDialog", function(shots)
            shots:setVehicles(nil)
            wm:showEditorDialog(sample.chopping, false)
        end),
        dialogShot("editor-support-steps", "editorDialog", function()
            wm:showEditorDialog(sample.chopping, false)
        end, function()
            -- Row 3 is support sub-step 2.1; set after the list has settled (it restores its own index on open)
            local editor = wm.editorDialog
            editor.selectedFlatIndex = 3
            editor:refreshStepList()
        end),
        dialogShot("step-dialog-autodrive", "stepDialog", openStep(
            { type = "autodrive", action = "load", target = "Fields 41-60/Field 49",
              unloadTarget = "_Farm 1 Center/Grain Silo", fillTypes = { "WHEAT", "BARLEY" } }, false, 6)),
        dialogShot("step-dialog-courseplay", "stepDialog", openStep(
            { type = "courseplay", action = "fieldwork", target = "Singleplayer/F48/Sowing", seedFruitType = "WHEAT" },
            false, 4)),
        dialogShot("ad-settings-dialog", "adSettingsDialog", function()
            wm:showADSettingsDialog({ unloadFillLevel = 0.9, pipeOffset = 1.5, preCallLevel = 0.7 }, noop)
        end),
        dialogShot("mode-dialog", "modeSelectDialog", function(shots)
            wm:showModeSelectDialog(sample.chopping.id, shots.vehicle, noop)
        end),
        dialogShot("leader-select-dialog", "leaderSelectDialog", function(shots)
            local chopper = running(sample.chopping, 2)
            local thresher = running(sample.workflows[1], 4)
            fakeVehicle("John Deere X9 1100", chopper)
            fakeVehicle("Claas Jaguar 1000", thresher)
            -- The candidate list is built from the executor's own vehicle list, inside this call:
            -- swap it for exactly that long, so the executor never runs on the stand-ins
            local realVehicles = WMExecutor.activeVehicles
            WMExecutor.activeVehicles = { [chopper.vehicle] = true, [thresher.vehicle] = true }
            wm:showLeaderSelectDialog(shots.vehicle, noop)
            WMExecutor.activeVehicles = realVehicles
        end),
        hudShot("hud-running", function(shots)
            shots:setVehicles(running(sample.fertilizing, 6), nil, false, 0.27)
        end),
        hudShot("hud-support-main", function(shots)
            local supportA = running(sample.chopping, 2, { isMainVehicle = false, currentSupportStep = 1 })
            local supportB = running(sample.chopping, 2, { isMainVehicle = false, currentSupportStep = 1,
                status = WorkflowManager.STATUS_WAITING_FOR_MAIN })
            fakeVehicle("Fendt 942 Vario", supportA)
            fakeVehicle("Fendt 728 Vario", supportB)
            shots:setVehicles(running(sample.chopping, 2), { supportA, supportB }, false, 0.27)
        end),
        hudShot("hud-support-vehicle", function(shots)
            local main = running(sample.chopping, 3)
            fakeVehicle("Claas Jaguar 1000", main)
            shots:setVehicles(running(sample.chopping, 3, { isMainVehicle = false, currentSupportStep = 1 }),
                { main }, true, nil)
        end),
    }
end

-- ------------------------------------------------------------
-- Run
-- ------------------------------------------------------------

local function getControlledVehicle()
    local vehicle = g_currentMission and g_currentMission.controlledVehicle
    if vehicle == nil and g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil then
        vehicle = g_localPlayer:getCurrentVehicle()
    end
    return vehicle
end

function WMDocScreenshots:consoleCapture()
    if self.running then
        return "wmDocScreenshots: already running"
    end
    local vehicle = getControlledVehicle()
    if vehicle == nil then
        return "wmDocScreenshots: sit in a vehicle first - the HUD only draws inside one"
    end

    local base = getUserProfileAppPath() .. "screenshots/"
    local language = g_languageShort or "en"
    createFolder(base)
    createFolder(base .. "wm_docs/")
    self.outDir = base .. "wm_docs/" .. language .. "/"
    createFolder(self.outDir)

    self.vehicle = vehicle
    self.sample = self:buildSample()
    self.hudWasVisible = WMHud.isVisible
    WMHud.isVisible = false
    self:setVehicles(nil)
    self:stage()
    self.queue = self:buildScenarios()
    self.index = 0
    self.crops = {}
    self.phase = "next"
    self.timer = self.START_MS
    self.running = true
    g_currentMission:addUpdateable(self)

    return string.format("wmDocScreenshots: CLOSE THE CONSOLE NOW - in %d s, %d screenshots go to %s; "
        .. "then don't touch mouse or keyboard", self.START_MS / 1000, #self.queue, self.outDir)
end

function WMDocScreenshots:update(dt)
    if not self.running then return end
    self.timer = self.timer - dt
    if self.timer > 0 then return end

    local shot = self.queue[self.index]
    if self.phase == "next" then
        self.index = self.index + 1
        shot = self.queue[self.index]
        if shot == nil then
            self:finish(true)
            return
        end
        shot.open(self)
        self.phase = "prepare"
        self.timer = self.OPEN_MS
    elseif self.phase == "prepare" then
        if shot.prepare ~= nil then shot.prepare(self) end
        self.phase = "capture"
        self.timer = self.PREPARE_MS
    elseif self.phase == "capture" then
        table.insert(self.crops, { name = shot.name, rect = shot.crop(self) })
        saveScreenshot(self.outDir .. shot.name .. ".png")
        self.phase = "close"
        self.timer = self.SHOT_MS
    elseif self.phase == "close" then
        shot.close()
        self.phase = "next"
        self.timer = self.GAP_MS
    end
end

---End the run: write the crop boxes (when complete) and put everything back
---@param completed boolean
function WMDocScreenshots:finish(completed)
    self.running = false
    if g_currentMission ~= nil then
        g_currentMission:removeUpdateable(self)
    end
    self:restoreOverrides()
    WMHud.isVisible = self.hudWasVisible == true
    self:setVehicles(nil)

    if completed then
        self:writeCrops()
        print(string.format("wmDocScreenshots: done - now run tools/crop_screenshots.py (%s)", self.outDir))
    end
end

function WMDocScreenshots:writeCrops()
    local xmlFile = XMLFile.create("wmDocScreenshots", self.outDir .. "crops.xml", "crops")
    if xmlFile == nil then
        print("wmDocScreenshots: could not write crops.xml")
        return
    end
    for i, crop in ipairs(self.crops) do
        local key = string.format("crops.crop(%d)", i - 1)
        xmlFile:setString(key .. "#name", crop.name)
        xmlFile:setFloat(key .. "#x", crop.rect.x)
        xmlFile:setFloat(key .. "#y", crop.rect.y)
        xmlFile:setFloat(key .. "#w", crop.rect.w)
        xmlFile:setFloat(key .. "#h", crop.rect.h)
    end
    xmlFile:save()
    xmlFile:delete()
end
