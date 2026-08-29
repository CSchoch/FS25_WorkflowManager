--[[
    WMSettings Unit Tests
    Tests the mod option model shown in the game's General settings page.
]]

describe("WMSettings", function()
    local WMSettings

    setup(function()
        dofile("src/WMSettings.lua")
        WMSettings = _G.WMSettings
    end)

    before_each(function()
        WMSettings:reset()
    end)

    describe("defaults", function()
        it("enables Courseplay auto-resume out of the box", function()
            assert.is_true(WMSettings.DEFAULTS.courseplayAutoResume)
            assert.is_true(WMSettings.courseplayAutoResume)
        end)
    end)

    describe("reset", function()
        it("restores every option to its default", function()
            WMSettings.courseplayAutoResume = false

            WMSettings:reset()

            assert.is_true(WMSettings.courseplayAutoResume)
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
end)
