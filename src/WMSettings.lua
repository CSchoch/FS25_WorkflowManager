--[[
    WorkflowManager - Mod Settings
    Player-facing options shown in the game's General settings page.

    Values are persisted per savegame by WMStorage (WorkflowManager.settings.general),
    so in multiplayer the server's savegame is the single source of truth — which is
    also where the executor runs.

    Author: WorkflowManager Team
]]

---@class WMSettings
WMSettings = {}

--- Every option with its default. Adding a key here is enough for reset() to cover it;
--- WMStorage still needs an explicit read/write line per key.
WMSettings.DEFAULTS = {
    -- Re-issue the Courseplay start after a savegame load (at the waypoint recorded at
    -- save time). Off = the workflow stays paused until the player presses Resume.
    courseplayAutoResume = true,
}

WMSettings.courseplayAutoResume = WMSettings.DEFAULTS.courseplayAutoResume

---Restore every option to its default. Called before loading a savegame's values so a
---setting from a previously loaded savegame cannot leak into the next one.
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
