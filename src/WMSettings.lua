--[[
    WorkflowManager - Mod Settings
    Player-facing options shown in the game's General settings page, plus the HUD position.

    Values are stored per player / machine in modSettings/FS25_WorkflowManager.xml, so they
    apply to every savegame. In multiplayer each machine has its own file; for options that
    gate server-side behaviour (courseplayAutoResume) the host's value is the one that counts.

    Author: WorkflowManager Team
]]

---@class WMSettings
WMSettings = {}

WMSettings.FILE_NAME = "FS25_WorkflowManager.xml"
WMSettings.ROOT_KEY = "WorkflowManagerSettings"

--- Every option with its default. Adding a key here is enough for reset(), load and save.
WMSettings.DEFAULTS = {
    -- Re-issue the Courseplay start after loading a savegame, at the waypoint recorded at
    -- save time. Off = the workflow stays paused until the player presses Resume.
    courseplayAutoResume = true,
    -- List the Workflow Manager keys in the F1 help window. The keys work either way.
    showHelpKeys = true,
    -- Verbose logging (debug level plus API/event/state-change lines) in log.txt.
    debugMode = false,
}

WMSettings.courseplayAutoResume = WMSettings.DEFAULTS.courseplayAutoResume
WMSettings.showHelpKeys = WMSettings.DEFAULTS.showHelpKeys
WMSettings.debugMode = WMSettings.DEFAULTS.debugMode

--- Keys present in the settings file (name -> true; "hud" for the HUD position).
--- Legacy values from a savegame are adopted only for keys the file does not have yet.
WMSettings.storedKeys = {}

---Restore every option to its default.
function WMSettings:reset()
    for name, value in pairs(self.DEFAULTS) do
        self[name] = value
    end
end

---True unless the player explicitly switched Courseplay auto-resume off.
---@return boolean enabled
function WMSettings:isCourseplayAutoResumeEnabled()
    return self.courseplayAutoResume ~= false
end

---@return string path Full path of the per-player settings file
function WMSettings:getFilePath()
    return getUserProfileAppPath() .. "modSettings/" .. self.FILE_NAME
end

---Read the settings file (defaults for anything it does not contain) and apply the result.
function WMSettings:loadUserSettings()
    self:reset()
    self.storedKeys = {}

    local path = self:getFilePath()
    local xmlFile = fileExists(path) and XMLFile.load("wmSettings", path) or nil
    if xmlFile ~= nil then
        -- No default: an absent attribute keeps the default and stays adoptable
        for name, _ in pairs(self.DEFAULTS) do
            local value = xmlFile:getBool(self.ROOT_KEY .. ".general#" .. name)
            if value ~= nil then
                self[name] = value
                self.storedKeys[name] = true
            end
        end

        local hudX = xmlFile:getFloat(self.ROOT_KEY .. ".hud#posX")
        local hudY = xmlFile:getFloat(self.ROOT_KEY .. ".hud#posY")
        if hudX ~= nil and hudY ~= nil and WMHud ~= nil then
            WMHud.x = hudX
            WMHud.y = hudY
            self.storedKeys.hud = true
        end
        xmlFile:delete()
        WMLogger:info("Loaded settings from %s", path)
    end

    self:apply()
end

---Write every option and the HUD position to the settings file.
function WMSettings:saveUserSettings()
    createFolder(getUserProfileAppPath() .. "modSettings/")

    local path = self:getFilePath()
    local xmlFile = XMLFile.create("wmSettings", path, self.ROOT_KEY)
    if xmlFile == nil then
        WMLogger:error("Failed to create settings file: %s", path)
        return
    end

    for name, _ in pairs(self.DEFAULTS) do
        xmlFile:setBool(self.ROOT_KEY .. ".general#" .. name, self[name] == true)
        self.storedKeys[name] = true
    end
    if WMHud ~= nil and WMHud.x ~= nil and WMHud.y ~= nil then
        xmlFile:setFloat(self.ROOT_KEY .. ".hud#posX", WMHud.x)
        xmlFile:setFloat(self.ROOT_KEY .. ".hud#posY", WMHud.y)
        self.storedKeys.hud = true
    end

    xmlFile:save()
    xmlFile:delete()
end

---Change one option, persist it and apply it right away.
---@param name string Option name (key of DEFAULTS)
---@param value boolean New value
function WMSettings:setOption(name, value)
    self[name] = value
    WMLogger:info("Setting %s=%s", name, tostring(value))
    self:saveUserSettings()
    self:apply()
end

---Push the options that act immediately into the systems that use them.
function WMSettings:apply()
    if WMLogger.setDebugMode ~= nil then
        WMLogger:setDebugMode(self.debugMode == true)
    end
    if WorkflowManager ~= nil and WorkflowManager.applyHelpKeyVisibility ~= nil then
        WorkflowManager:applyHelpKeyVisibility()
    end
end

---Take over an option a savegame stored before settings moved to the per-player file.
---Ignored once the settings file has the option, so it runs at most once per option.
---@param name string Option name
---@param value boolean|nil Value read from the savegame (nil = not present there)
function WMSettings:adoptLegacySetting(name, value)
    if value == nil or self.storedKeys[name] then return end
    self[name] = value
    WMLogger:info("Adopted setting %s=%s from the savegame", name, tostring(value))
    self:saveUserSettings()
    self:apply()
end

---Take over a HUD position a savegame stored before it moved to the per-player file.
---@param x number|nil
---@param y number|nil
function WMSettings:adoptLegacyHudPosition(x, y)
    if x == nil or y == nil or self.storedKeys.hud or WMHud == nil then return end
    WMHud.x = x
    WMHud.y = y
    WMLogger:info("Adopted HUD position from the savegame: x=%.4f y=%.4f", x, y)
    self:saveUserSettings()
end
