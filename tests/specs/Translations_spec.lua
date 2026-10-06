--[[
    Translation consistency
    Every wm_ text must exist in both languages with the same number of %s placeholders:
    player messages are built with string.format, and a translation with a different
    placeholder count would show a wrong text (or "?" fillers) in that language only.
]]

describe("Translations", function()
    local function readTexts(path)
        local f = assert(io.open(path, "r"))
        local src = f:read("*a")
        f:close()
        local texts = {}
        for name, text in src:gmatch('<text%s+name="([^"]+)"%s+text="([^"]*)"') do
            texts[name] = text
        end
        return texts
    end

    local en = readTexts("translations/translation_en.xml")
    local de = readTexts("translations/translation_de.xml")

    local function placeholders(text)
        local _, count = text:gsub("%%s", "")
        return count
    end

    it("reads both translation files", function()
        assert.is_not_nil(en.wm_title)
        assert.is_not_nil(de.wm_title)
    end)

    it("has every English wm_ key in German", function()
        local missing = {}
        for name in pairs(en) do
            if name:sub(1, 3) == "wm_" and de[name] == nil then table.insert(missing, name) end
        end
        table.sort(missing)
        assert.are.equal("", table.concat(missing, ", "))
    end)

    it("has every German wm_ key in English", function()
        local missing = {}
        for name in pairs(de) do
            if name:sub(1, 3) == "wm_" and en[name] == nil then table.insert(missing, name) end
        end
        table.sort(missing)
        assert.are.equal("", table.concat(missing, ", "))
    end)

    it("uses the same number of %s placeholders in both languages", function()
        local mismatched = {}
        for name, text in pairs(en) do
            if de[name] ~= nil and placeholders(text) ~= placeholders(de[name]) then
                table.insert(mismatched, name)
            end
        end
        table.sort(mismatched)
        assert.are.equal("", table.concat(mismatched, ", "))
    end)

    it("contains every message key the code sends to players", function()
        local keys = {
            "wm_error_step_failed", "wm_error_ad_target_not_found", "wm_error_ad_start_failed",
            "wm_error_no_park_position", "wm_error_no_repair_station", "wm_error_seed_type",
            "wm_error_cp_course_load", "wm_error_cp_start_failed", "wm_error_unknown_step_type",
            "wm_warning_ad_unload_not_found", "wm_warning_cp_course_ambiguous", "wm_info_seed_locked",
            "wm_warning_cp_no_resume_waypoint", "wm_warning_restore_workflow_missing",
            "wm_warning_workflow_not_found", "wm_warning_no_steps", "wm_info_workflow_removed",
            "wm_settings_showHelpKeys", "wm_settings_debugMode", "wm_editor_finish_before_switch",
            "wm_option_no", "wm_option_yes",
        }
        for _, key in ipairs(keys) do
            assert.is_not_nil(en[key])
        end
    end)
end)
