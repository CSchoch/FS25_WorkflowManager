--[[
    FS25 font coverage
    The game's only font (shared/font/defaultFont.font) silently drops characters it has no glyph
    for and logs "Character 'N' not found in texture font" - the fill-type list's selection mark
    "✓" vanished that way. Every non-ASCII character the mod can show (Lua outside comments,
    translations, GUI XML, modDesc) must be one checked against the font's glyph table.

    To allow a new character: look its code point up in the font (header: uint32 glyph count at
    byte 8, then 28-byte records starting at byte 12, each beginning with a uint32 code point)
    and add it to ALLOWED only if it is there.
]]

describe("FS25 font coverage", function()

    -- Non-ASCII characters verified present in defaultFont.font (2026-11-08)
    local ALLOWED = "·ÄÖÜßäöü–—„“←↑→↓»×"

    -- UTF-8 characters of a string
    local function chars(text)
        local list = {}
        for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            table.insert(list, ch)
        end
        return list
    end

    local allowed = {}
    for _, ch in ipairs(chars(ALLOWED)) do allowed[ch] = true end

    local function readFile(path)
        local file = assert(io.open(path, "rb"), "cannot read " .. path)
        local text = file:read("*a")
        file:close()
        return text
    end

    local function listFiles(pattern)
        local files = {}
        local pipe = assert(io.popen('dir /s /b "' .. pattern .. '" 2>nul'))
        for line in pipe:lines() do
            table.insert(files, line)
        end
        pipe:close()
        return files
    end

    ---Lua source without comments (block comments first, then line comments)
    local function stripLuaComments(source)
        source = source:gsub("%-%-%[(=*)%[.-%]%1%]", "")
        return (source:gsub("%-%-[^\n]*", ""))
    end

    local function missingIn(text)
        local missing = {}
        for _, ch in ipairs(chars(text)) do
            if #ch > 1 and not allowed[ch] then missing[ch] = true end
        end
        local list = {}
        for ch in pairs(missing) do table.insert(list, ch) end
        table.sort(list)
        return list
    end

    local function assertCovered(files, transform)
        assert.is_true(#files > 0)
        local problems = {}
        for _, path in ipairs(files) do
            local text = readFile(path)
            if transform then text = transform(text) end
            local missing = missingIn(text)
            if #missing > 0 then
                table.insert(problems, path .. ": " .. table.concat(missing, " "))
            end
        end
        assert(#problems == 0, "characters without a glyph in the FS25 font:\n" .. table.concat(problems, "\n"))
    end

    it("Lua sources show only characters the font has", function()
        assertCovered(listFiles("src\\*.lua"), stripLuaComments)
    end)

    it("translations, GUI XML and modDesc use only characters the font has", function()
        local files = listFiles("translations\\*.xml")
        for _, path in ipairs(listFiles("xml\\*.xml")) do table.insert(files, path) end
        table.insert(files, "modDesc.xml")
        assertCovered(files)
    end)

    it("the selected fill type is marked with a character the font has", function()
        local source = readFile("src/gui/WMStepDialog.lua")
        assert.is_truthy(source:find('isSelected and "» "', 1, true))
    end)

    it("stripLuaComments keeps strings and drops comments", function()
        local stripped = stripLuaComments('--[[ ↳ block ]]\nlocal a = "→" -- ✓ note\n')
        assert.are.same({}, missingIn(stripped))
        assert.is_truthy(stripped:find("→", 1, true))
    end)
end)
