--[[
    WMSettings Unit Tests
    Tests the per-player option model (modSettings/FS25_WorkflowManager.xml): defaults,
    load/save, applying options, and adopting values a savegame stored before the move.
]]

describe("WMSettings", function()
    local WMSettings
    local SETTINGS_PATH = "/profile/modSettings/FS25_WorkflowManager.xml"
    local createdFolders, debugModeCalls, helpKeyCalls
    local sharedLogger = _G.WMLogger

    setup(function()
        _G.getUserProfileAppPath = function() return "/profile/" end
        _G.createFolder = function(path) table.insert(createdFolders, path) end
        dofile("src/WMSettings.lua")
        WMSettings = _G.WMSettings
    end)

    before_each(function()
        XMLFile._clearAll()
        createdFolders, debugModeCalls, helpKeyCalls = {}, {}, 0
        _G.fileExists = function(path) return XMLFile._getDataForPath(path) ~= nil end
        _G.WMHud = { x = nil, y = nil }
        -- Own logger proxy: adding setDebugMode to the shared mock would leak into later specs
        _G.WMLogger = setmetatable({
            setDebugMode = function(_, enabled) table.insert(debugModeCalls, enabled) end,
        }, { __index = sharedLogger })
        _G.WorkflowManager = { applyHelpKeyVisibility = function() helpKeyCalls = helpKeyCalls + 1 end }
        WMSettings:reset()
        WMSettings.storedKeys = {}
    end)

    local function writeSettingsFile(general, hud)
        local f = XMLFile.create("wmSettings", SETTINGS_PATH, "WorkflowManagerSettings")
        for name, value in pairs(general or {}) do
            f:setBool("WorkflowManagerSettings.general#" .. name, value)
        end
        if hud ~= nil then
            f:setFloat("WorkflowManagerSettings.hud#posX", hud.x)
            f:setFloat("WorkflowManagerSettings.hud#posY", hud.y)
        end
    end

    describe("defaults", function()
        it("enables Courseplay auto-resume out of the box", function()
            assert.is_true(WMSettings.DEFAULTS.courseplayAutoResume)
            assert.is_true(WMSettings.courseplayAutoResume)
        end)

        it("shows the keys in the help window out of the box", function()
            assert.is_true(WMSettings.showHelpKeys)
        end)

        it("has debug logging off out of the box", function()
            assert.is_false(WMSettings.debugMode)
        end)
    end)

    describe("reset", function()
        it("restores every option to its default", function()
            WMSettings.courseplayAutoResume = false
            WMSettings.showHelpKeys = false
            WMSettings.debugMode = true

            WMSettings:reset()

            assert.is_true(WMSettings.courseplayAutoResume)
            assert.is_true(WMSettings.showHelpKeys)
            assert.is_false(WMSettings.debugMode)
        end)
    end)

    describe("isCourseplayAutoResumeEnabled", function()
        it("is true when the option is on", function()
            WMSettings.courseplayAutoResume = true
            assert.is_true(WMSettings:isCourseplayAutoResumeEnabled())
        end)

        it("is false only when the option was explicitly switched off", function()
            WMSettings.courseplayAutoResume = false
            assert.is_false(WMSettings:isCourseplayAutoResumeEnabled())
        end)

        it("treats an unset value as enabled", function()
            WMSettings.courseplayAutoResume = nil
            assert.is_true(WMSettings:isCourseplayAutoResumeEnabled())
        end)
    end)

    describe("getFilePath", function()
        it("points into the user profile's modSettings folder", function()
            assert.are.equal(SETTINGS_PATH, WMSettings:getFilePath())
        end)
    end)

    describe("loadUserSettings", function()
        it("uses the defaults when there is no settings file", function()
            WMSettings.debugMode = true

            WMSettings:loadUserSettings()

            assert.is_false(WMSettings.debugMode)
            assert.is_true(WMSettings.showHelpKeys)
            assert.is_nil(next(WMSettings.storedKeys))
        end)

        it("reads every option from the file", function()
            writeSettingsFile({ courseplayAutoResume = false, showHelpKeys = false, debugMode = true })

            WMSettings:loadUserSettings()

            assert.is_false(WMSettings.courseplayAutoResume)
            assert.is_false(WMSettings.showHelpKeys)
            assert.is_true(WMSettings.debugMode)
            assert.is_true(WMSettings.storedKeys.debugMode)
        end)

        it("keeps the default for an option the file does not contain", function()
            writeSettingsFile({ debugMode = true })

            WMSettings:loadUserSettings()

            assert.is_true(WMSettings.courseplayAutoResume)
            assert.is_nil(WMSettings.storedKeys.courseplayAutoResume)
        end)

        it("restores the HUD position", function()
            writeSettingsFile({}, { x = 0.6, y = 0.3 })

            WMSettings:loadUserSettings()

            assert.are.equal(0.6, _G.WMHud.x)
            assert.are.equal(0.3, _G.WMHud.y)
            assert.is_true(WMSettings.storedKeys.hud)
        end)

        it("applies the loaded options", function()
            writeSettingsFile({ debugMode = true })

            WMSettings:loadUserSettings()

            assert.are.same({ true }, debugModeCalls)
            assert.are.equal(1, helpKeyCalls)
        end)
    end)

    describe("saveUserSettings", function()
        it("creates the modSettings folder and writes every option", function()
            WMSettings.showHelpKeys = false
            WMSettings.debugMode = true

            WMSettings:saveUserSettings()

            assert.are.same({ "/profile/modSettings/" }, createdFolders)
            WMSettings:reset()
            WMSettings:loadUserSettings()
            assert.is_false(WMSettings.showHelpKeys)
            assert.is_true(WMSettings.debugMode)
            assert.is_true(WMSettings.courseplayAutoResume)
        end)

        it("writes the HUD position when it is known", function()
            _G.WMHud.x, _G.WMHud.y = 0.4, 0.2

            WMSettings:saveUserSettings()

            _G.WMHud.x, _G.WMHud.y = nil, nil
            WMSettings:loadUserSettings()
            assert.are.equal(0.4, _G.WMHud.x)
            assert.are.equal(0.2, _G.WMHud.y)
        end)
    end)

    describe("setOption", function()
        it("changes, persists and applies the option", function()
            WMSettings:setOption("debugMode", true)

            assert.is_true(WMSettings.debugMode)
            assert.is_not_nil(XMLFile._getDataForPath(SETTINGS_PATH))
            assert.are.same({ true }, debugModeCalls)
            assert.are.equal(1, helpKeyCalls)
        end)
    end)

    describe("adoptLegacySetting", function()
        it("adopts a savegame value the settings file does not have yet", function()
            WMSettings:adoptLegacySetting("courseplayAutoResume", false)

            assert.is_false(WMSettings.courseplayAutoResume)
            assert.is_true(WMSettings.storedKeys.courseplayAutoResume)
            assert.is_not_nil(XMLFile._getDataForPath(SETTINGS_PATH))
        end)

        it("ignores the savegame value once the settings file has the option", function()
            WMSettings.storedKeys.courseplayAutoResume = true

            WMSettings:adoptLegacySetting("courseplayAutoResume", false)

            assert.is_true(WMSettings.courseplayAutoResume)
        end)

        it("ignores a savegame that never stored the option", function()
            WMSettings:adoptLegacySetting("courseplayAutoResume", nil)

            assert.is_nil(XMLFile._getDataForPath(SETTINGS_PATH))
        end)

        it("runs only once: the first adoption stores the option", function()
            WMSettings:adoptLegacySetting("courseplayAutoResume", false)
            WMSettings:adoptLegacySetting("courseplayAutoResume", true)

            assert.is_false(WMSettings.courseplayAutoResume)
        end)
    end)

    describe("adoptLegacyHudPosition", function()
        it("adopts a savegame HUD position the settings file does not have yet", function()
            WMSettings:adoptLegacyHudPosition(0.7, 0.1)

            assert.are.equal(0.7, _G.WMHud.x)
            assert.are.equal(0.1, _G.WMHud.y)
            assert.is_true(WMSettings.storedKeys.hud)
        end)

        it("keeps the stored position once the settings file has one", function()
            _G.WMHud.x, _G.WMHud.y = 0.5, 0.5
            WMSettings.storedKeys.hud = true

            WMSettings:adoptLegacyHudPosition(0.7, 0.1)

            assert.are.equal(0.5, _G.WMHud.x)
        end)

        it("ignores an incomplete position", function()
            WMSettings:adoptLegacyHudPosition(0.7, nil)

            assert.is_nil(_G.WMHud.x)
        end)
    end)
end)
