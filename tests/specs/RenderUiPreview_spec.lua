--[[
    tools/render_ui_preview.lua - UI previews (docs/ui/*.svg)

    The tool runs the real dialog Lua and the real WMHud:draw() against fake elements / draw
    stubs. These specs keep it working as the GUI code changes: every scenario must render,
    in both languages, show what the real code decides, and leave no globals behind.
]]

describe("render_ui_preview", function()
    local R

    setup(function()
        _G.RENDER_UI_NO_WRITE = true
        R = dofile("tools/render_ui_preview.lua")
    end)

    local function has(svg, text)
        return svg:find(text, 1, true) ~= nil
    end

    it("renders every scenario as an SVG", function()
        assert.is_true(#R.ORDER >= 12)
        for _, name in ipairs(R.ORDER) do
            local svg = R.render(name)
            assert.is_true(svg:sub(1, 4) == "<svg")
            assert.is_true(has(svg, "</svg>"))
        end
    end)

    it("renders every scenario with the German texts too", function()
        for _, name in ipairs(R.ORDER) do
            assert.is_true(has(R.render(name, "de"), "</svg>"))
        end
    end)

    it("shows the main dialog list as WMMainDialog populates it", function()
        local svg = R.render("main")
        assert.is_true(has(svg, "Grass Fertilizing"))
        assert.is_true(has(svg, ">6/10<"))               -- running workflow shows its progress
        assert.is_true(has(svg, ">Threshing with Support<"))  -- no "[+S]": Support column instead
        assert.is_true(has(svg, ">Yes<"))
        assert.is_true(has(svg, ">T<"))                  -- Edit key glyph comes from modDesc
    end)

    it("lists support sub-steps in the editor", function()
        local svg = R.render("editor")
        assert.is_true(has(svg, ">→ 2.1<"))
        assert.is_true(has(svg, ">CP<"))                 -- type chip
        assert.is_true(has(svg, ">F49/Chopping<"))       -- course name without "Singleplayer/"
        assert.is_true(has(svg, "Unload Combine"))
    end)

    it("shows the step dialog rows the real visibility logic picks", function()
        local cp = R.render("step-courseplay")
        assert.is_true(has(cp, "Seed Type"))
        assert.is_true(not has(cp, "Fill Type"))
        local load = R.render("step-autodrive-load")
        assert.is_true(has(load, "Fill Type"))
        assert.is_true(not has(load, "Seed Type"))
        assert.is_true(has(R.render("step-support"), "Finish before")) -- label wraps
    end)

    it("draws the HUD through the real WMHud:draw", function()
        local svg = R.render("hud-main")
        assert.is_true(has(svg, "Grass Chopping"))
        assert.is_true(has(svg, "Step 2/10"))
        assert.is_true(has(svg, "CP active (27%)"))
        assert.is_true(has(R.render("hud-waiting"), "John Deere X9 1100"))
    end)

    it("labels the support summary on a main vehicle's HUD", function()
        assert.is_true(has(R.render("hud-main"), ">Supporters: <"))
        assert.is_true(has(R.render("hud-main"), ">1 waiting<"))
        assert.is_true(has(R.render("hud-main", "de"), ">Unterstützer: <"))
        assert.is_true(has(R.render("hud-main", "de"), ">1 wartet<"))
    end)

    it("makes the main vehicle's name on a support vehicle's HUD clickable", function()
        local svg = R.render("hud-support-switch")
        assert.is_true(has(svg, ">Main vehicle: <"))
        assert.is_true(has(svg, 'fill="#2ac1ed" text-anchor="start">Claas Jaguar 1000<'))  -- hover colour
        assert.is_true(has(svg, "Click to switch to this vehicle"))                      -- name has bounds
    end)

    it("leaves no globals behind", function()
        local before = {}
        for k, v in pairs(_G) do before[k] = v end
        R.render("editor")
        R.render("hud-main")
        for k, v in pairs(_G) do
            assert.is_true(before[k] == v)  -- nothing added, nothing replaced
        end
        for k in pairs(before) do
            assert.is_true(rawget(_G, k) ~= nil)
        end
    end)
end)
