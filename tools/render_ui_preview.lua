--[[
    Renders previews of the Workflow Manager UI (docs/ui/*.svg) from the real code.

    Dialogs: the layout is read from xml/gui/*.xml (+ xml/gui/guiProfiles.xml), and the dialog
    Lua (src/gui/WM*Dialog.lua) runs for real against fake GUI elements: setStep / setWorkflow,
    onOpen, refreshDisplay, updateButtons and populateCellForItemInSection decide labels, row
    visibility, disabled buttons, key glyphs and list rows, exactly as in the game.
    HUD: the real WMHud:draw() runs against stubbed engine draw calls, recorded as SVG.

    FS25's own look (vanilla fs25_* profiles, font, key glyph boxes) is approximated in FS25
    below, calibrated against the screenshots in website/static/img/screenshots. Re-run after
    any change to xml/gui, src/gui or the translations.

    Usage (from the mod root):
        & "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\render_ui_preview.lua
    With RENDER_UI_NO_WRITE = true the file only returns the module (used by the tests).
]]

local LANG = "en"
local OUT_DIR = "docs/ui"
local FONT = "'Nunito Sans', 'Segoe UI', 'Helvetica Neue', Arial, sans-serif"

-- Reference screen for the HUD (normalized coordinates <-> pixels)
local SCREEN_W, SCREEN_H = 1920, 1080

-- Vanilla FS25 look, measured from the in-game screenshots
local FS25 = {
    frame = "#0b0b0b",
    panel = "#232323",
    panelEdge = "#3a3a3a",
    footerH = 64,
    -- The list colours in guiProfiles.xml (wm_listItem) are overridden in game by the
    -- vanilla list item look; these are the colours the screenshots show.
    rowLight = "#6b6b6b",
    rowDark = "#5c5c5c",
    rowSelected = "#00b8e6",
    input = "#2c2c2c",
    optionBg = "#1e1e1e",
    optionEdge = "#4c4c4c",
    glyphBg = "#1b2617",
    glyph = "#8cc63f",
    glyphDisabled = "#4a6328",
    label = "#ffffff",
    labelDisabled = "#8a8a8a",
    sliderTrack = "#3a3a3a",
    sliderThumb = "#8a8a8a",
    buttonLabelSize = 18,
    glyphH = 38,
    separatorH = 16,
    sliderW = 40,
    defaultGlyph = { buttonOK = "ENTER", buttonActivate = "SPACE", buttonBack = "ESC" },
}

-- Values of the vanilla profiles WM's profiles extend (base game, not in guiProfiles.xml)
local VANILLA_PROFILES = {
    fs25_dialogButtonBox = {
        flowDirection = "horizontal", alignmentX = "right", alignmentY = "middle", elementSpacing = "14px",
    },
}

-- Base-game l10n keys referenced by WM's XML (not in WM's translation files)
local BASE_TEXTS = { button_ok = "OK", button_back = "Back" }

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function readFile(path)
    local file = assert(io.open(path, "r"), "cannot read " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

local function noop() end

local function esc(text)
    return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function utf8Len(text)
    local _, count = tostring(text):gsub("[^\128-\191]", "")
    return count
end

-- Width estimate for the FS25 UI font (rounded geometric sans)
local function textWidth(text, size, bold, upper)
    local factor = upper and 0.66 or 0.47
    if bold then factor = factor + 0.04 end
    return utf8Len(text) * size * factor
end

local function fmt(n)
    return string.format("%.1f", n):gsub("%.0$", "")
end

local function rgba(color)
    if color == nil then return "#ffffff", 1 end
    local r, g, b, a = color[1], color[2], color[3], color[4] or 1
    return string.format("#%02x%02x%02x",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)), a
end

local function parseColor(value)
    if value == nil then return nil end
    local parts = {}
    for n in value:gmatch("[%d%.]+") do parts[#parts + 1] = tonumber(n) end
    return parts
end

local function px(value)
    return value and tonumber(value:match("^%s*(-?[%d%.]+)")) or nil
end

-- ---------------------------------------------------------------------------
-- Texts, key bindings
-- ---------------------------------------------------------------------------

local function loadTexts(lang)
    local texts = {}
    local src = readFile("translations/translation_" .. lang .. ".xml")
    for name, text in src:gmatch('<text%s+name="([^"]+)"%s+text="([^"]*)"') do
        texts[name] = text:gsub("&quot;", '"'):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")
    end
    return texts
end

local function getText(texts, key)
    local text = texts[key] or BASE_TEXTS[key]
    assert(text, "missing text " .. tostring(key))
    return text
end

-- action name -> key label from modDesc.xml ("WM_GUI_EDIT" -> "T")
local function loadKeyBindings()
    local keys = {}
    local src = readFile("modDesc.xml")
    for action, input in src:gmatch('<actionBinding%s+action="([^"]+)">%s*<binding[^>]-input="([^"]+)"') do
        local parts = {}
        for key in input:gmatch("KEY_(%w+)") do
            key = key:upper()
            if key == "LALT" then key = "ALT" end
            parts[#parts + 1] = key
        end
        keys[action] = table.concat(parts, "+")
    end
    return keys
end

-- ---------------------------------------------------------------------------
-- XML
-- ---------------------------------------------------------------------------

local function parseXml(src)
    src = src:gsub("<!%-%-.-%-%->", ""):gsub("<%?.-%?>", "")
    local root = { tag = "#root", attr = {}, children = {} }
    local stack = { root }
    local pos = 1
    while true do
        local s, e, close, tag, attrs, selfClose = src:find("<(/?)([%w_:%.]+)(.-)(/?)>", pos)
        if s == nil then break end
        if close == "/" then
            table.remove(stack)
        else
            local node = { tag = tag, attr = {}, children = {} }
            for k, v in attrs:gmatch('([%w_:%.]+)%s*=%s*"([^"]*)"') do node.attr[k] = v end
            table.insert(stack[#stack].children, node)
            if selfClose ~= "/" then table.insert(stack, node) end
        end
        pos = e + 1
    end
    return root.children[1]
end

local profiles

local function loadProfiles()
    profiles = {}
    local root = parseXml(readFile("xml/gui/guiProfiles.xml"))
    for _, node in ipairs(root.children) do
        if node.tag == "Profile" then
            local values = {}
            for _, child in ipairs(node.children) do values[child.tag] = child.attr.value end
            profiles[node.attr.name] = { extends = node.attr.extends, with = node.attr.with, values = values }
        end
    end
end

-- Value of a profile key, following the `extends` chain of guiProfiles.xml
local function profileValue(name, key)
    while name do
        local profile = profiles[name]
        if profile == nil then
            return VANILLA_PROFILES[name] and VANILLA_PROFILES[name][key]
        end
        if profile.values[key] ~= nil then return profile.values[key] end
        name = profile.extends
    end
    return nil
end

-- Anchor traits ("with") of a profile and the profiles it extends
local function profileWith(name)
    local parts = {}
    while name and profiles[name] do
        parts[#parts + 1] = profiles[name].with or ""
        name = profiles[name].extends
    end
    return table.concat(parts, " ")
end

-- Attribute on the element first, then its profile
local function prop(node, key)
    local value = node.attr[key]
    if value == nil then value = profileValue(node.attr.profile, key) end
    return value
end

-- ---------------------------------------------------------------------------
-- Fake GUI elements (the dialog Lua writes into these; the renderer reads them)
-- ---------------------------------------------------------------------------

local FakeElement = {}

-- Recorded state uses the real FS25 element field names (the dialog Lua reads some of them,
-- e.g. list.selectedIndex); every other unknown key is a no-op GUI method.
local DATA_FIELDS = {
    text = true, textColor = true, visible = true, disabled = true, texts = true, state = true, imageColor = true,
    inputAction = true, dataSource = true, selectedIndex = true, named = true,
}
function FakeElement:setText(text) self.text = text end
function FakeElement:getText() return self.text or "" end
function FakeElement:setTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function FakeElement:setVisible(visible) self.visible = visible end
function FakeElement:getIsVisible() return self.visible ~= false end
function FakeElement:setDisabled(disabled) self.disabled = disabled end
function FakeElement:getIsDisabled() return self.disabled == true end
function FakeElement:setTexts(texts) self.texts = texts end
function FakeElement:setState(state) self.state = state end
function FakeElement:getState() return self.state or 1 end
function FakeElement:setInputAction(action) self.inputAction = action end
function FakeElement:setDataSource(source) self.dataSource = source end
function FakeElement:setSelectedIndex(index) self.selectedIndex = index end
function FakeElement:setImageColor(_, r, g, b, a) self.imageColor = { r, g, b, a } end
function FakeElement:getSelectedIndex() return self.selectedIndex or 0 end
function FakeElement:getDescendantByName(name)
    self.named = self.named or {}
    self.named[name] = self.named[name] or M.newFakeElement()
    return self.named[name]
end

local FAKE_MT = {
    __index = function(_, key)
        if FakeElement[key] ~= nil then return FakeElement[key] end
        if DATA_FIELDS[key] then return nil end
        -- Any other GUI method the dialog calls is a no-op
        return noop
    end,
}

function M.newFakeElement()
    return setmetatable({}, FAKE_MT)
end

-- ---------------------------------------------------------------------------
-- Globals: each render runs in its own environment and restores _G afterwards
-- ---------------------------------------------------------------------------

local function withCleanGlobals(fn)
    local saved = {}
    for k, v in pairs(_G) do saved[k] = v end
    local result = fn()
    local added = {}
    for k in pairs(_G) do
        if saved[k] == nil then added[#added + 1] = k end
    end
    for _, k in ipairs(added) do _G[k] = nil end
    for k, v in pairs(saved) do _G[k] = v end
    return result
end

local function installBaseStubs(texts, sample)
    _G.source = noop
    _G.fileExists = function() return false end -- no DevConfig: release defaults
    _G.Utils = {
        getFilename = function(name, dir) return (dir or "") .. name end,
        appendedFunction = function(_, new) return new end,
        prependedFunction = function(_, new) return new end,
    }
    _G.addModEventListener = noop
    _G.FSBaseMission = {}
    _G.g_currentModName = "FS25_WorkflowManager"
    _G.g_currentModDirectory = ""
    _G.WMLogger = setmetatable({}, { __index = function() return noop end })
    _G.g_i18n = { getText = function(_, key) return getText(texts, key) end }
    _G.InputAction = setmetatable({}, { __index = function(_, key) return key end })
    _G.g_inputBinding = setmetatable({
        registerActionEvent = function() return true, "event" end,
    }, { __index = function() return noop end })
    _G.Class = function(class, base)
        setmetatable(class, { __index = base })
        class.superClass = function() return base end
        return { __index = class }
    end
    _G.DialogElement = {
        new = function(_, mt) return setmetatable({}, mt) end,
        onOpen = noop,
        onClose = noop,
    }
    _G.g_currentMission = { controlledVehicle = sample.controlledVehicle, time = 0 }
    _G.g_localPlayer = nil

    dofile("src/WorkflowManager.lua")
    WorkflowManager.workflows = sample.workflows
    WorkflowManager.reloadWorkflows = noop -- storage concern, not UI

    _G.WMExecutor = {
        activeVehicles = sample.activeVehicles,
        getActiveDataForVehicle = function(_, vehicle)
            return vehicle and vehicle.spec_workflowManagerSpec and vehicle.spec_workflowManagerSpec.wmExecution
        end,
        getSupportActiveDataListForWorkflow = function(_, workflowId)
            local list = {}
            for vehicle in pairs(sample.activeVehicles) do
                local data = vehicle.spec_workflowManagerSpec.wmExecution
                if data.workflow.id == workflowId and data.isMainVehicle == false then list[#list + 1] = data end
            end
            return list
        end,
        getMainActiveDataForWorkflow = function(_, workflowId)
            for vehicle in pairs(sample.activeVehicles) do
                local data = vehicle.spec_workflowManagerSpec.wmExecution
                if data.workflow.id == workflowId and data.isMainVehicle ~= false then return data end
            end
            return nil
        end,
        getSupportMainStepIndex = function(_, supportData, mainData)
            return supportData.supportMainStepIndex or mainData.currentStep
        end,
    }
    _G.ADIntegration = {
        isAvailable = true,
        getDestinations = function()
            local list = {}
            for _, name in ipairs(sample.adDestinations) do list[#list + 1] = { displayName = name } end
            return list
        end,
        getAvailableFillTypes = function() return sample.fillTypes end,
        isRunning = function(_, vehicle) return vehicle.adRunning == true end,
    }
    _G.CPIntegration = {
        getSeedFruitTypes = function() return sample.seedTypes end,
        isRunning = function(_, vehicle) return vehicle.cpProgress ~= nil end,
        getProgress = function(_, vehicle) return vehicle.cpProgress end,
    }
    _G.CPCoursesLoader = {
        isInitialized = true,
        setGuiOpen = noop,
        getCourses = function() return sample.cpCourses end,
    }
    _G.CPVehiclesLoader = nil -- never inherit a test runner mock

    dofile("src/gui/WMHud.lua")
end

-- ---------------------------------------------------------------------------
-- Sample data (modelled on the documentation screenshots)
-- ---------------------------------------------------------------------------

local function steps(count)
    local list = {}
    for i = 1, count do
        list[i] = { type = "autodrive", action = "drive", target = "Fields 1-20/Field " .. i }
    end
    return list
end

local function vehicle(name, data)
    local v = { getName = function() return name end }
    v.spec_workflowManagerSpec = { wmExecution = data }
    if data then data.vehicle = v end
    return v
end

local function buildSample()
    local chopping = {
        id = "wf_chopping", name = "Grass Chopping",
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
    local fertilizing = { id = "wf_fert", name = "Grass Fertilizing", steps = {
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
    local threshingSupport = { id = "wf_thresh_sup", name = "Threshing with Support", steps = steps(32) }
    threshingSupport.steps[2].support = { { type = "autodrive", action = "unload", target = "Fields 1-20/Field 2" } }

    local workflows = {
        { id = "wf_thresh", name = "Threshing", steps = steps(20) },
        threshingSupport,
        { id = "wf_baling", name = "Baling", steps = steps(32) },
        { id = "wf_thresh6", name = "Threshing 6m", steps = steps(32) },
        { id = "wf_bales", name = "Bale Collecting", steps = steps(32) },
        { id = "wf_hoe", name = "Hoeing", steps = steps(32) },
        { id = "wf_mow", name = "Mowing", steps = steps(12) },
        fertilizing,
        { id = "wf_lime", name = "Grass Liming", steps = steps(10) },
        { id = "wf_ted", name = "Grass Tedding", steps = steps(12) },
        chopping,
        { id = "wf_gbales", name = "Grass Bale Collecting", steps = steps(6) },
    }

    return {
        workflows = workflows,
        chopping = chopping,
        fertilizing = fertilizing,
        activeVehicles = {},
        adDestinations = {
            "Fields 41-60/Field 48", "Fields 41-60/Field 49", "Fields 41-60/Field 50",
            "Fields 41-60/Field 51 Grass", "_Farm 1 Center/Farm 1 Silage", "_Farm 1 Center/Grain Silo",
            "_Farm 1 Center/Fertilizer", "Sell Points/Grain Mill",
        },
        cpCourses = {
            "Singleplayer/F48/Liming", "Singleplayer/F48/Sowing", "Singleplayer/F49/Fertilizing",
            "Singleplayer/F49/Chopping", "Singleplayer/F50/Chopping", "Singleplayer/F51/Chopping",
        },
        fillTypes = {
            { name = "WHEAT", title = "Wheat" }, { name = "BARLEY", title = "Barley" },
            { name = "CANOLA", title = "Canola" }, { name = "SEEDS", title = "Seeds" },
            { name = "FERTILIZER", title = "Fertilizer" }, { name = "LIME", title = "Lime" },
        },
        seedTypes = {
            { name = "WHEAT", title = "Wheat" }, { name = "BARLEY", title = "Barley" },
            { name = "CANOLA", title = "Canola" }, { name = "MAIZE", title = "Maize" },
        },
    }
end

-- Puts vehicles on the sample: the player sits in `controlled`
local function addVehicle(sample, name, data, controlled)
    local v = vehicle(name, data)
    sample.activeVehicles[v] = true
    if controlled then sample.controlledVehicle = v end
    return v
end

-- ---------------------------------------------------------------------------
-- SVG canvas
-- ---------------------------------------------------------------------------

local function newCanvas()
    local canvas = { parts = {}, clipCount = 0 }
    function canvas:add(s) self.parts[#self.parts + 1] = s end
    function canvas:rect(x, y, w, h, fill, opts)
        opts = opts or {}
        self:add(string.format('<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"%s%s%s/>',
            fmt(x), fmt(y), fmt(math.max(w, 0)), fmt(math.max(h, 0)), fmt(opts.rx or 0), fill,
            opts.opacity and string.format(' fill-opacity="%s"', fmt(opts.opacity)) or "",
            opts.stroke and string.format(' stroke="%s" stroke-width="%s"', opts.stroke, fmt(opts.strokeW or 1)) or "",
            opts.extra or ""))
    end
    function canvas:text(x, y, text, size, fill, opts)
        opts = opts or {}
        if text == nil or text == "" then return end
        -- preserve: the editor indents support rows with leading spaces
        self:add(string.format('<text xml:space="preserve" x="%s" y="%s" font-size="%s" fill="%s"%s%s%s%s>%s</text>',
            fmt(x), fmt(y), fmt(size), fill,
            opts.bold and ' font-weight="700"' or "",
            opts.italic and ' font-style="italic"' or "",
            opts.anchor and string.format(' text-anchor="%s"', opts.anchor) or "",
            opts.opacity and opts.opacity < 1 and string.format(' fill-opacity="%s"', fmt(opts.opacity)) or "",
            esc(text)))
    end
    function canvas:clip(x, y, w, h)
        self.clipCount = self.clipCount + 1
        local id = "clip" .. self.clipCount
        self:add(string.format('<clipPath id="%s"><rect x="%s" y="%s" width="%s" height="%s"/></clipPath>',
            id, fmt(x), fmt(y), fmt(w), fmt(h)))
        return id
    end
    function canvas:svg(width, height, title)
        return table.concat({
            string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="%s">',
                width, height, width, height, FONT),
            string.format("<title>%s</title>", esc(title)),
            table.concat(self.parts, "\n"),
            "</svg>\n",
        }, "\n")
    end
    return canvas
end

-- ---------------------------------------------------------------------------
-- Dialog layout + drawing
-- ---------------------------------------------------------------------------

local function parseSize(node, parentW, parentH)
    local value = node.attr.size or profileValue(node.attr.profile, "size")
    if value == nil then return nil, nil end
    local a, b = value:match("^%s*(%S+)%s+(%S+)")
    local function one(v, parent)
        if v:find("%%") then return parent * tonumber(v:match("[%d%.]+")) / 100 end
        return px(v)
    end
    return one(a, parentW), one(b, parentH)
end

local Renderer = {}
Renderer.__index = Renderer

function Renderer.new(texts, keys, dialog, canvas)
    return setmetatable({ texts = texts, keys = keys, dialog = dialog, canvas = canvas, lists = {} }, Renderer)
end

function Renderer:fake(node)
    return node.attr.id and self.dialog[node.attr.id]
end

function Renderer:isVisible(node)
    local fake = self:fake(node)
    return fake == nil or fake.visible ~= false
end

function Renderer:resolve(text)
    if text == nil then return nil end
    local key = text:match("^%$l10n_(.+)$")
    if key then return getText(self.texts, key) end
    return text
end

-- Text of an element: what the Lua set, else the XML text
function Renderer:textOf(node)
    local fake = self:fake(node)
    if fake and fake.text ~= nil then return fake.text end
    return self:resolve(node.attr.text)
end

function Renderer:buttonLabel(node)
    local label = self:textOf(node) or ""
    return label:upper()
end

function Renderer:buttonGlyph(node)
    local fake = self:fake(node)
    if fake and fake.inputAction then
        return assert(self.keys[fake.inputAction], "no key for " .. fake.inputAction)
    end
    return FS25.defaultGlyph[node.attr.profile] or "SPACE"
end

function Renderer:glyphWidth(glyph)
    if glyph == "ENTER" then return 54 end
    return math.max(54, textWidth(glyph, 20, true, true) + 28)
end

function Renderer:buttonWidth(node)
    local label = self:buttonLabel(node)
    return self:glyphWidth(self:buttonGlyph(node)) + 14 + textWidth(label, FS25.buttonLabelSize, true, true) + 10
end

-- Size of an element inside a parent box
function Renderer:measure(node, parentW, parentH)
    local w, h = parseSize(node, parentW, parentH)
    local profile = node.attr.profile
    if node.tag == "Button" and (node.attr.size == nil or profile ~= nil) then
        -- FS25 buttons grow to glyph + label, whatever the declared width
        return self:buttonWidth(node), h or 40
    end
    if profile == "wm_dialogContentContainer" then
        return parentW - px("21px"), parentH - px("30px")
    end
    if profile == "wm_dialogTitleLineSeparator" then
        return parentW - 100, FS25.separatorH
    end
    if profile == "fs25_listSliderBox" then
        return FS25.sliderW, parentH
    end
    if profile == "fs25_dialogButtonBoxSeparator" then
        return 1, 36
    end
    return w or parentW, h or 40
end

function Renderer:visibleChildren(node)
    local list = {}
    for _, child in ipairs(node.children) do
        if self:isVisible(child) then list[#list + 1] = child end
    end
    return list
end

function Renderer:drawBox(node, x, y, w, h)
    local horizontal = (prop(node, "flowDirection") or "vertical") == "horizontal"
    local spacing = px(prop(node, "elementSpacing")) or 0
    local alignX = prop(node, "alignmentX") or "left"
    local alignY = prop(node, "alignmentY") or "top"
    local children = self:visibleChildren(node)

    local sizes, total = {}, 0
    for i, child in ipairs(children) do
        local cw, ch = self:measure(child, w, h)
        sizes[i] = { cw, ch }
        total = total + (horizontal and cw or ch) + (i > 1 and spacing or 0)
    end

    local cursor = horizontal and x or y
    if horizontal and alignX == "center" then cursor = x + (w - total) / 2 end
    if horizontal and alignX == "right" then cursor = x + w - total end
    for i, child in ipairs(children) do
        local cw, ch = sizes[i][1], sizes[i][2]
        if horizontal then
            local cy = y
            if alignY == "middle" then cy = y + (h - ch) / 2 end
            self:draw(child, cursor, cy, cw, ch)
            cursor = cursor + cw + spacing
        else
            local cx = x
            if alignX == "center" then cx = x + (w - cw) / 2 end
            self:draw(child, cx, cursor, cw, ch)
            cursor = cursor + ch + spacing
        end
    end
end

function Renderer:drawText(node, x, y, w, h, fake)
    local text = (fake and fake.text) or self:textOf(node)
    if text == nil or text == "" then return end
    local size = px(prop(node, "textSize")) or 16
    local bold = prop(node, "textBold") == "true"
    local upper = prop(node, "textUpperCase") == "true"
    local italic = prop(node, "textItalic") == "true"
    local align = prop(node, "textAlignment") or "left"
    local color = (fake and fake.textColor) or parseColor(prop(node, "textColor")) or { 1, 1, 1, 1 }
    local offsetX = px(prop(node, "textOffset")) or 0
    if upper then text = text:upper() end

    -- Word wrap for multi-line texts (textMaxNumLines > 1)
    local lines = { text }
    local maxLines = tonumber(prop(node, "textMaxNumLines") or "1") or 1
    if maxLines > 1 and textWidth(text, size, bold, upper) > w then
        lines = {}
        local line = ""
        for word in text:gmatch("%S+") do
            local candidate = line == "" and word or (line .. " " .. word)
            if textWidth(candidate, size, bold, upper) > w and line ~= "" then
                lines[#lines + 1] = line
                line = word
            else
                line = candidate
            end
        end
        lines[#lines + 1] = line
    end

    local fill, opacity = rgba(color)
    local anchor, tx = "start", x + offsetX
    if align == "center" then anchor, tx = "middle", x + w / 2 end
    if align == "right" then anchor, tx = "end", x + w - offsetX end
    local lineH = size * 1.25
    local top = y + h / 2 - (#lines * lineH) / 2
    for i, line in ipairs(lines) do
        self.canvas:text(tx, top + (i - 0.5) * lineH + size * 0.35, line, size, fill,
            { bold = bold, italic = italic, anchor = anchor, opacity = opacity })
    end
end

function Renderer:drawGlyph(glyph, x, y, disabled)
    local c = self.canvas
    local gw, gh = self:glyphWidth(glyph), FS25.glyphH
    c:rect(x, y, gw, gh, FS25.glyphBg, { rx = 4 })
    local color = disabled and FS25.glyphDisabled or FS25.glyph
    if glyph == "ENTER" then
        -- the return-arrow glyph FS25 shows for MENU_ACCEPT
        local cx, cy = x + gw / 2, y + gh / 2
        c:add(string.format('<path d="M%s %s v6 h-14 m5 -5 l-5 5 l5 5" fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
            fmt(cx + 7), fmt(cy - 7), color))
    else
        c:text(x + gw / 2, y + gh / 2 + 7, glyph, 20, color, { bold = true, anchor = "middle" })
    end
    return gw
end

function Renderer:drawButton(node, x, y, w, h)
    local fake = self:fake(node)
    local disabled = fake and fake.disabled == true
    local glyph = self:buttonGlyph(node)
    local gy = y + (h - FS25.glyphH) / 2
    local gw = self:drawGlyph(glyph, x, gy, disabled)
    self.canvas:text(x + gw + 14, y + h / 2 + FS25.buttonLabelSize * 0.36, self:buttonLabel(node),
        FS25.buttonLabelSize, disabled and FS25.labelDisabled or FS25.label, { bold = true })
end

function Renderer:drawTextInput(node, x, y, w, h)
    local fake = self:fake(node)
    local c = self.canvas
    local hasIcon = false
    for _, child in ipairs(node.children) do
        if child.attr.profile == "fs25_textInputIconBox" then hasIcon = true end
    end
    c:rect(x, y, w, h, FS25.input, { rx = 4 })
    if hasIcon then
        c:rect(x + w - h, y + 2, h - 2, h - 4, "#3a3a3a", { rx = 3 })
        -- pencil
        local cx, cy = x + w - h / 2, y + h / 2
        c:add(string.format('<path d="M%s %s l8 -8 l3 3 l-8 8 h-3 z" fill="#ffffff"/>', fmt(cx - 5), fmt(cy + 4)))
    end
    local text = fake and fake.text or ""
    c:text(x + (w - (hasIcon and h or 0)) / 2, y + h / 2 + 6, text, 16, "#ffffff", { bold = true, anchor = "middle" })
end

function Renderer:drawMultiTextOption(node, x, y, w, h)
    local fake = self:fake(node)
    local c = self.canvas
    c:rect(x + 1, y + 1, w - 2, h - 2, FS25.optionBg, { rx = 6, stroke = FS25.optionEdge, strokeW = 2 })
    local texts = fake and fake.texts or {}
    local state = fake and fake.state or 1
    local value = texts[state] or ""
    if state > 1 then
        c:add(string.format('<path d="M%s %s l7 -5 v10 z" fill="#bbbbbb"/>', fmt(x + 9), fmt(y + h / 2)))
    end
    if state < #texts then
        c:add(string.format('<path d="M%s %s l-7 -5 v10 z" fill="#bbbbbb"/>', fmt(x + w - 9), fmt(y + h / 2)))
    end
    c:text(x + w / 2, y + h / 2 + 6, value:upper(), 17, "#e6e6e6", { anchor = "middle" })
end

function Renderer:drawList(node, x, y, w, h)
    local fake = self:fake(node)
    local c = self.canvas
    local template
    for _, child in ipairs(node.children) do
        if child.tag == "ListItem" then template = child end
    end
    local _, rowH = parseSize(template, w, h)
    local source = fake and fake.dataSource
    local count = source and source:getNumberOfItemsInSection(fake, 1) or 0
    local selected = fake and fake.selectedIndex or 0
    self.lists[node.attr.id] = { count = count, rowH = rowH, h = h, selected = selected }

    local clipId = c:clip(x, y, w, h)
    c:add(string.format('<g clip-path="url(#%s)">', clipId))
    for i = 1, count do
        local ry = y + (i - 1) * rowH
        if ry > y + h then break end
        local fill = (i == selected) and FS25.rowSelected or ((i % 2 == 0) and FS25.rowLight or FS25.rowDark)
        c:rect(x, ry, w, rowH, fill)
        local cell = M.newFakeElement()
        source:populateCellForItemInSection(fake, 1, i, cell)
        self:drawCell(template, cell, x, ry, w, rowH)
    end
    c:add("</g>")
end

-- Lays out a list row template, taking texts, colours and visibility from the populated fake cell
function Renderer:drawCell(node, cell, x, y, w, h)
    local saved = self.cellSource
    self.cellSource = cell
    for _, child in ipairs(node.children) do
        if child.tag == "BoxLayout" then
            self:drawBox(child, x, y, w, h)
        elseif child.tag == "Bitmap" then
            self:drawBitmap(child, x, y, w, h)
        end
    end
    self.cellSource = saved
end

-- The fake an element's Lua writes to: by name inside a list row, else by id
function Renderer:elementFake(node)
    if self.cellSource and node.attr.name then
        return self.cellSource:getDescendantByName(node.attr.name)
    end
    return self:fake(node)
end

-- Solid colour block (imageColor, no imageSliceId: row tint, type chip), placed by its profile anchors
function Renderer:drawBitmap(node, x, y, w, h)
    local fake = self:elementFake(node)
    if fake and fake.visible == false then return end
    local with = profileWith(node.attr.profile)
    local bx, by, bw, bh = x, y, w, h
    local stretch = with:find("anchorStretchingYStretchingX") ~= nil
    if not stretch then
        local sw, sh = parseSize(node, w, h)
        bw, bh = sw or w, sh or h
        bx = x + (px(node.attr.position or profileValue(node.attr.profile, "position")) or 0)
        if with:find("anchorMiddle") then by = y + (h - bh) / 2 end
    end
    local fill, opacity = rgba((fake and fake.imageColor) or parseColor(prop(node, "imageColor")))
    self.canvas:rect(bx, by, bw, bh, fill, { opacity = opacity, rx = stretch and 0 or 3 })
    for _, child in ipairs(node.children) do
        self:draw(child, bx, by, bw, bh)
    end
end

function Renderer:drawSlider(node, x, y, w, h)
    local slider = node.children[1]
    local list = slider and self.lists[slider.attr.dataElementId]
    local c = self.canvas
    c:rect(x + 4, y, 6, h, FS25.sliderTrack, { rx = 3 })
    if list and list.count * list.rowH > list.h then
        local thumbH = math.max(30, h * list.h / (list.count * list.rowH))
        c:rect(x + 4, y, 6, thumbH, FS25.sliderThumb, { rx = 3 })
    end
end

function Renderer:draw(node, x, y, w, h)
    local tag, profile = node.tag, node.attr.profile
    if tag == "BoxLayout" then
        self:drawBox(node, x, y, w, h)
    elseif tag == "Text" then
        self:drawText(node, x, y, w, h, self:elementFake(node))
    elseif tag == "Button" then
        self:drawButton(node, x, y, w, h)
    elseif tag == "TextInput" then
        self:drawTextInput(node, x, y, w, h)
    elseif tag == "MultiTextOption" then
        self:drawMultiTextOption(node, x, y, w, h)
    elseif tag == "SmoothList" then
        self:drawList(node, x, y, w, h)
    elseif tag == "ThreePartBitmap" and profile == "fs25_listSliderBox" then
        self:drawSlider(node, x, y, w, h)
    elseif tag == "ThreePartBitmap" and profile == "wm_dialogTitleLineSeparator" then
        self.canvas:add(string.format(
            '<rect x="%s" y="%s" width="%s" height="2" fill="url(#separator)"/>', fmt(x), fmt(y + 6), fmt(w)))
    elseif tag == "Bitmap" and prop(node, "imageSliceId") == nil and prop(node, "imageColor") ~= nil then
        self:drawBitmap(node, x, y, w, h)
    elseif tag == "Bitmap" and profile == "fs25_dialogButtonBoxSeparator" then
        self.canvas:rect(x, y, 1, h, "#4a4a4a")
    elseif tag == "GuiElement" then
        -- plain container (conditional section, chip column) or spacer
        for _, child in ipairs(self:visibleChildren(node)) do
            if child.tag == "Bitmap" then
                self:drawBitmap(child, x, y, w, h)
            else
                local cw, ch = self:measure(child, w, h)
                self:draw(child, x + (w - cw) / 2, y, cw, ch)
            end
        end
    end
end

-- Renders a dialog XML with a dialog instance whose fake elements the Lua has filled
local function renderDialog(xmlPath, dialog, texts, keys, title)
    local root = parseXml(readFile(xmlPath))
    local bg
    for _, child in ipairs(root.children) do
        if child.attr.profile == "fs25_dialogBg" then bg = child end
    end
    local W, H = parseSize(bg, SCREEN_W, SCREEN_H)
    local pad = 12
    local canvasW, canvasH = W + pad * 2, H + FS25.footerH + 8
    local canvas = newCanvas()
    canvas:add('<defs><linearGradient id="separator" x1="0" x2="1" y1="0" y2="0">'
        .. '<stop offset="0" stop-color="#ffffff" stop-opacity="0"/>'
        .. '<stop offset="0.5" stop-color="#ffffff" stop-opacity="0.75"/>'
        .. '<stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient></defs>')
    canvas:rect(0, 0, canvasW, canvasH, FS25.frame, { rx = 10 })
    canvas:rect(pad, 4, W, H, FS25.panel, { rx = 8, stroke = FS25.panelEdge, strokeW = 1 })

    local renderer = Renderer.new(texts, keys, dialog, canvas)
    for _, child in ipairs(bg.children) do
        local profile = child.attr.profile
        if profile == "wm_dialogContentContainer" then
            local cw, ch = renderer:measure(child, W, H)
            renderer:drawBox(child, pad + (W - cw) / 2 + 4, 4 + 14, cw, ch)
        elseif profile == "wm_dialogButtonBoxBottom" then
            renderer:drawBox(child, pad, H + 4 + (FS25.footerH - 40) / 2 + 2, W - 6, 40)
        end
    end
    return canvas:svg(canvasW, canvasH, title)
end

-- Creates a dialog with one fake element per XML id
local function newDialog(class, xmlPath)
    local dialog = class.new()
    local function walk(node)
        if node.attr.id then dialog[node.attr.id] = M.newFakeElement() end
        for _, child in ipairs(node.children) do walk(child) end
    end
    walk(parseXml(readFile(xmlPath)))
    return dialog
end

-- ---------------------------------------------------------------------------
-- HUD: the real WMHud:draw() against recording stubs
-- ---------------------------------------------------------------------------

local HUD_ICONS = {
    prev = function(c, x, y, s, color)
        c:add(string.format('<path d="M%s %s l-%s %s l%s %s z M%s %s l-%s %s l%s %s z" fill="%s"/>',
            fmt(x + s * 0.5), fmt(y + s * 0.2), fmt(s * 0.4), fmt(s * 0.3), fmt(s * 0.4), fmt(s * 0.3),
            fmt(x + s * 0.9), fmt(y + s * 0.2), fmt(s * 0.4), fmt(s * 0.3), fmt(s * 0.4), fmt(s * 0.3), color))
    end,
    next = function(c, x, y, s, color)
        c:add(string.format('<path d="M%s %s l%s %s l-%s %s z M%s %s l%s %s l-%s %s z" fill="%s"/>',
            fmt(x + s * 0.1), fmt(y + s * 0.2), fmt(s * 0.4), fmt(s * 0.3), fmt(s * 0.4), fmt(s * 0.3),
            fmt(x + s * 0.5), fmt(y + s * 0.2), fmt(s * 0.4), fmt(s * 0.3), fmt(s * 0.4), fmt(s * 0.3), color))
    end,
    pause = function(c, x, y, s, color)
        c:rect(x + s * 0.22, y + s * 0.15, s * 0.2, s * 0.7, color)
        c:rect(x + s * 0.58, y + s * 0.15, s * 0.2, s * 0.7, color)
    end,
    play = function(c, x, y, s, color)
        c:add(string.format('<path d="M%s %s l%s %s l-%s %s z" fill="%s"/>',
            fmt(x + s * 0.25), fmt(y + s * 0.15), fmt(s * 0.6), fmt(s * 0.35), fmt(s * 0.6), fmt(s * 0.35), color))
    end,
    stop = function(c, x, y, s, color)
        c:rect(x + s * 0.18, y + s * 0.18, s * 0.64, s * 0.64, color)
    end,
}

local function installHudStubs(canvas, origin)
    -- normalized (FS25: origin bottom-left) -> canvas pixels
    local function toX(nx) return nx * SCREEN_W - origin.x end
    local function toY(ny) return (1 - ny) * SCREEN_H - origin.y end

    _G.getNormalizedScreenValues = function(x, y) return x / SCREEN_W, y / SCREEN_H end
    _G.g_baseUIFilename = "baseUI"
    _G.g_colorBgUVs = {}
    _G.RenderText = { ALIGN_LEFT = "start", ALIGN_CENTER = "middle", ALIGN_RIGHT = "end" }

    local state = { color = { 1, 1, 1, 1 }, bold = false, align = "start" }
    _G.setTextColor = function(r, g, b, a) state.color = { r, g, b, a } end
    _G.setTextBold = function(bold) state.bold = bold end
    _G.setTextAlignment = function(align) state.align = align end
    _G.getTextWidth = function(size, text)
        return textWidth(text, size * SCREEN_H, state.bold, false) / SCREEN_W
    end
    _G.renderText = function(x, y, size, text)
        local fill, opacity = rgba(state.color)
        canvas:text(toX(x), toY(y), text, size * SCREEN_H, fill,
            { bold = state.bold, anchor = state.align, opacity = opacity })
    end

    local Overlay = {}
    Overlay.__index = Overlay
    _G.Overlay = {
        new = function(file, x, y, w, h)
            return setmetatable({ file = file, x = x, y = y, w = w, h = h, color = { 1, 1, 1, 1 } }, Overlay)
        end,
    }
    function Overlay:setUVs() end
    function Overlay:setColor(r, g, b, a) self.color = { r, g, b, a } end
    function Overlay:setPosition(x, y) self.x, self.y = x, y end
    function Overlay:setDimension(w, h) self.w, self.h = w, h end
    function Overlay:render()
        local fill, opacity = rgba(self.color)
        local icon = self.file:match("icon_(%a+)%.dds$")
        local x, y = toX(self.x), toY(self.y + self.h)
        local w, h = self.w * SCREEN_W, self.h * SCREEN_H
        if icon then
            canvas:add(string.format('<g fill-opacity="%s">', fmt(opacity)))
            HUD_ICONS[icon](canvas, x, y, h, fill)
            canvas:add("</g>")
        else
            canvas:rect(x, y, w, h, fill, { opacity = opacity })
        end
    end
end

local function renderHud(sample, texts, hovered, title)
    local margin = 24
    local origin = {}
    local canvas = newCanvas()

    return withCleanGlobals(function()
        installBaseStubs(texts, sample)
        installHudStubs(canvas, origin)
        -- Crop around the HUD at its default spot, with the size WMHud itself sets up
        WMHud:ensureOverlays()
        local hudW, hudH = WMHud.w * SCREEN_W, WMHud.h * SCREEN_H
        origin.x = WMHud.x * SCREEN_W - margin
        origin.y = (1 - WMHud.y) * SCREEN_H - hudH - margin
        local W, H = math.floor(hudW + margin * 2 + 0.5), math.floor(hudH + margin * 2 + 0.5)
        canvas:add('<defs><linearGradient id="field" x1="0" x2="1" y1="0" y2="1">'
            .. '<stop offset="0" stop-color="#5b6b2e"/><stop offset="0.5" stop-color="#46562a"/>'
            .. '<stop offset="1" stop-color="#3b4a22"/></linearGradient></defs>')
        canvas:rect(0, 0, W, H, "url(#field)", { rx = 8 })
        WMHud.isVisible = true
        WMHud.hoveredButton = hovered
        WMHud:draw()
        return canvas:svg(W, H, title)
    end)
end

-- ---------------------------------------------------------------------------
-- Scenarios
-- ---------------------------------------------------------------------------

local SCENARIOS = {}
local ORDER = {}

local function scenario(name, title, fn)
    SCENARIOS[name] = { title = title, fn = fn }
    ORDER[#ORDER + 1] = name
end

local function running(workflow, step, extra)
    local data = { workflow = workflow, currentStep = step, status = "running", isMainVehicle = true }
    for k, v in pairs(extra or {}) do data[k] = v end
    return data
end

scenario("main", "Main dialog", function(texts, keys)
    local sample = buildSample()
    local tractor = addVehicle(sample, "Fendt 942 Vario", running(sample.fertilizing, 6), true)
    tractor.cpProgress = 0.27
    return withCleanGlobals(function()
        installBaseStubs(texts, sample)
        dofile("src/gui/WMMainDialog.lua")
        local dialog = newDialog(WMMainDialog, "xml/gui/WMMainDialog.xml")
        dialog:onOpen()
        return renderDialog("xml/gui/WMMainDialog.xml", dialog, texts, keys, "Main dialog")
    end)
end)

scenario("editor", "Workflow editor", function(texts, keys)
    local sample = buildSample()
    return withCleanGlobals(function()
        installBaseStubs(texts, sample)
        dofile("src/gui/WMEditorDialog.lua")
        local dialog = newDialog(WMEditorDialog, "xml/gui/WMEditorDialog.xml")
        dialog:setWorkflow(sample.chopping)
        dialog:onOpen()
        return renderDialog("xml/gui/WMEditorDialog.xml", dialog, texts, keys, "Workflow editor")
    end)
end)

-- subtitleFor: {stepIndex, supportIndex} for the editor's real subtitle (nil = new step)
local function stepScenario(name, title, step, isSupport, subtitleFor)
    scenario(name, title, function(texts, keys)
        local sample = buildSample()
        return withCleanGlobals(function()
            installBaseStubs(texts, sample)
            dofile("src/gui/WMEditorDialog.lua")
            dofile("src/gui/WMStepDialog.lua")
            local editor = newDialog(WMEditorDialog, "xml/gui/WMEditorDialog.xml")
            editor:loadDataCaches()
            WorkflowManager.editorDialog = editor
            local dialog = newDialog(WMStepDialog, "xml/gui/WMStepDialog.xml")
            editor:setWorkflow(sample.chopping)
            local subtitle = editor:getStepSubtitle(unpack(subtitleFor or {}))
            dialog:setStep(step, noop, isSupport, subtitle)
            dialog:onOpen()
            return renderDialog("xml/gui/WMStepDialog.xml", dialog, texts, keys, title)
        end)
    end)
end

stepScenario("step-courseplay", "Step dialog: Courseplay field work with seed",
    { type = "courseplay", action = "fieldwork", target = "Singleplayer/F48/Sowing", seedFruitType = "WHEAT" },
    false, { 4 })
stepScenario("step-autodrive-load", "Step dialog: AutoDrive load with fill types",
    { type = "autodrive", action = "load", target = "Fields 41-60/Field 49",
      unloadTarget = "_Farm 1 Center/Grain Silo", fillTypes = { "WHEAT", "BARLEY" } },
    false, { 6 })
stepScenario("step-support", "Step dialog: support sub-step",
    { type = "autodrive", action = "unload", target = "Fields 41-60/Field 50", finishBeforeSwitch = true },
    true, { 2, 1 })

scenario("mode-select", "Run as main or support", function(texts, keys)
    local sample = buildSample()
    return withCleanGlobals(function()
        installBaseStubs(texts, sample)
        dofile("src/gui/WMModeSelectDialog.lua")
        local dialog = newDialog(WMModeSelectDialog, "xml/gui/WMModeSelectDialog.xml")
        dialog:setWorkflow(sample.chopping.id, nil, noop)
        dialog:onOpen()
        return renderDialog("xml/gui/WMModeSelectDialog.xml", dialog, texts, keys, "Run as main or support")
    end)
end)

scenario("leader-select", "Leader vehicle selection", function(texts, keys)
    local sample = buildSample()
    addVehicle(sample, "John Deere X9 1100", running(sample.chopping, 2))
    addVehicle(sample, "Claas Jaguar 1000", running(sample.workflows[1], 4))
    local own = addVehicle(sample, "Fendt 942 Vario", nil, true)
    sample.activeVehicles[own] = nil
    return withCleanGlobals(function()
        installBaseStubs(texts, sample)
        dofile("src/gui/WMLeaderVehicleSelectDialog.lua")
        local dialog = newDialog(WMLeaderVehicleSelectDialog, "xml/gui/WMLeaderVehicleSelectDialog.xml")
        dialog:setData(own, noop)
        dialog:buildVehicleList()
        dialog:onOpen()
        return renderDialog("xml/gui/WMLeaderVehicleSelectDialog.xml", dialog, texts, keys, "Leader vehicle selection")
    end)
end)

scenario("ad-settings", "AD/CP settings", function(texts, keys)
    local sample = buildSample()
    return withCleanGlobals(function()
        installBaseStubs(texts, sample)
        dofile("src/gui/WMADSettingsDialog.lua")
        local dialog = newDialog(WMADSettingsDialog, "xml/gui/WMADSettingsDialog.xml")
        dialog:setSettings({ unloadFillLevel = 0.9, pipeOffset = 1.5, preCallLevel = 0.7 }, noop)
        dialog:onOpen()
        return renderDialog("xml/gui/WMADSettingsDialog.xml", dialog, texts, keys, "AD/CP settings")
    end)
end)

scenario("hud-main", "HUD: main vehicle with support", function(texts)
    local sample = buildSample()
    local main = addVehicle(sample, "Claas Jaguar 1000", running(sample.chopping, 2), true)
    main.cpProgress = 0.27
    addVehicle(sample, "Fendt 942 Vario", running(sample.chopping, 2, { isMainVehicle = false, currentSupportStep = 1 }))
    addVehicle(sample, "Fendt 728 Vario", running(sample.chopping, 2,
        { isMainVehicle = false, currentSupportStep = 1, status = "waiting_for_main" }))
    return renderHud(sample, texts, nil, "HUD: main vehicle with support")
end)

scenario("hud-support", "HUD: support vehicle", function(texts)
    local sample = buildSample()
    addVehicle(sample, "Claas Jaguar 1000", running(sample.chopping, 3))
    local support = addVehicle(sample, "Fendt 942 Vario",
        running(sample.chopping, 3, { isMainVehicle = false, currentSupportStep = 1 }), true)
    support.adRunning = true
    return renderHud(sample, texts, "pauseResume", "HUD: support vehicle")
end)

scenario("hud-support-switch", "HUD: support vehicle, main vehicle name hovered", function(texts)
    local sample = buildSample()
    addVehicle(sample, "Claas Jaguar 1000", running(sample.chopping, 3))
    local support = addVehicle(sample, "Fendt 942 Vario",
        running(sample.chopping, 3, { isMainVehicle = false, currentSupportStep = 1 }), true)
    support.adRunning = true
    return renderHud(sample, texts, "mainName", "HUD: support vehicle, main vehicle name hovered")
end)

scenario("hud-waiting", "HUD: waiting for leader", function(texts)
    local sample = buildSample()
    local leader = addVehicle(sample, "John Deere X9 1100", running(sample.chopping, 4))
    addVehicle(sample, "Fendt 942 Vario",
        running(sample.fertilizing, 1, { status = "waiting_for_leader", leaderVehicle = leader }), true)
    return renderHud(sample, texts, "leaderName", "HUD: waiting for leader")
end)

scenario("hud-paused", "HUD: paused", function(texts)
    local sample = buildSample()
    addVehicle(sample, "Fendt 942 Vario", running(sample.fertilizing, 6, { status = "paused" }), true)
    return renderHud(sample, texts, nil, "HUD: paused")
end)

-- ---------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------

M.ORDER = ORDER

---Renders one scenario and returns the SVG text
function M.render(name, lang)
    loadProfiles()
    local entry = assert(SCENARIOS[name], "unknown scenario " .. tostring(name))
    return entry.fn(loadTexts(lang or LANG), loadKeyBindings())
end

function M.title(name)
    return SCENARIOS[name].title
end

if not RENDER_UI_NO_WRITE then
    for _, name in ipairs(ORDER) do
        local svg = M.render(name)
        local path = OUT_DIR .. "/" .. name .. ".svg"
        local file = io.open(path, "w")
        if file == nil then
            os.execute('mkdir "' .. OUT_DIR:gsub("/", "\\") .. '"')
            file = assert(io.open(path, "w"), "cannot write " .. path)
        end
        file:write(svg)
        file:close()
        print("wrote " .. path)
    end
end

return M
