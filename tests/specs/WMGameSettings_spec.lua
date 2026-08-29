--[[
    WMGameSettings Unit Tests

    WMGameSettings appends the mod's options to the base game's General settings list by
    CLONING the vanilla rows:
        page   = g_gui.screenControllers[InGameMenu].pageSettings
        layout = page.generalSettingsLayout
        row prefab    = page.checkWoodHarvesterAutoCutBox
                        box.elements[1] = option control (its elements[1] = tooltip)
                        box.elements[2] = label
        header prefab = the layout element named "sectionHeader"

    The tests below model just enough of the FS25 GuiElement contract (clone/addElement/
    removeElement/setText/setIsChecked/setCallback/invalidateLayout) to exercise that.
]]

describe("WMGameSettings", function()

    local page, layout, rowPrefab, headerPrefab

    -- -------------------------------------------------------------------------
    -- Minimal GuiElement model
    -- -------------------------------------------------------------------------
    local makeElement
    makeElement = function(name)
        local e = {
            name      = name,
            elements  = {},
            parent    = nil,
            callbacks = {},
            deleted   = false,
        }
        function e:setText(text)         self.text = text end
        function e:setDisabled(value)    self.disabled = value end
        function e:setIsChecked(value)   self.checked = value end
        function e:setCallback(cb, fn)   self.callbacks[cb] = fn end
        function e:invalidateLayout()    self.layoutInvalidated = (self.layoutInvalidated or 0) + 1 end
        function e:delete()              self.deleted = true end
        function e:addElement(child)
            table.insert(self.elements, child)
            child.parent = self
        end
        function e:removeElement(child)
            for i = #self.elements, 1, -1 do
                if self.elements[i] == child then table.remove(self.elements, i) end
            end
            child.parent = nil
        end
        function e:clone(parent)
            local copy = makeElement(self.name)
            copy.text, copy.disabled, copy.checked = self.text, self.disabled, self.checked
            copy.focusId    = self.focusId          -- clones inherit the id: must be replaced
            copy.clonedFrom = self
            for _, child in ipairs(self.elements) do
                child:clone(copy)
            end
            if parent ~= nil then parent:addElement(copy) end
            return copy
        end
        return e
    end

    -- Rebuild the vanilla General settings page
    local function makeSettingsPage()
        headerPrefab = makeElement("sectionHeader")
        headerPrefab.focusId = "vanilla_header"

        rowPrefab = makeElement("checkWoodHarvesterAutoCutBox")
        rowPrefab.focusId = "vanilla_box"
        local control = makeElement("control")
        control.focusId = "vanilla_control"
        control:addElement(makeElement("tooltip"))
        rowPrefab:addElement(control)                 -- box.elements[1]
        rowPrefab:addElement(makeElement("label"))    -- box.elements[2]

        layout = makeElement("generalSettingsLayout")
        layout:addElement(headerPrefab)
        layout:addElement(rowPrefab)

        return {
            generalSettingsLayout        = layout,
            checkWoodHarvesterAutoCutBox = rowPrefab,
            controlsList                 = {},
        }
    end

    -- The elements the module injected
    local function injectedBox()
        for _, element in ipairs(layout.elements) do
            if element.id == "wmCpAutoResumeBox" then return element end
        end
        return nil
    end
    local function injectedHeader()
        for _, element in ipairs(layout.elements) do
            if element.id == "wmSectionHeader" then return element end
        end
        return nil
    end

    -- -------------------------------------------------------------------------
    -- Setup
    -- -------------------------------------------------------------------------
    setup(function()
        _G.InGameMenu = "InGameMenuClass"
        _G.InGameMenuSettingsFrame = { onFrameOpen = function() end }
        _G.CheckedOptionElement = { STATE_CHECKED = 2, STATE_UNCHECKED = 1 }

        local focusIdCounter = 0
        _G.FocusManager = {
            currentFocusData = { idToElementMapping = {} },
            serveAutoFocusId = function()
                focusIdCounter = focusIdCounter + 1
                return "auto_" .. focusIdCounter
            end,
            loadElementFromCustomValues = function(self, element)
                self._loaded = self._loaded or {}
                table.insert(self._loaded, element)
                return true
            end,
            setGui = function() end,
        }

        dofile("src/WMSettings.lua")
        dofile("src/gui/WMGameSettings.lua")
    end)

    before_each(function()
        -- init() appends to these; without a reset the hooks pile up across tests
        _G.InGameMenuSettingsFrame.onFrameOpen = function() end
        _G.FocusManager.setGui = function() end

        page = makeSettingsPage()
        _G.g_gui.screenControllers = { [_G.InGameMenu] = { pageSettings = page } }
        _G.g_server = true          -- singleplayer / host by default
        _G.WMSettings:reset()

        WMGameSettings.menuInjected = false
        WMGameSettings.menuControls = {}
        WMGameSettings.isHooked     = false

        _G.WMLogger.calls = { debug = {}, info = {}, warning = {}, error = {} }
    end)

    -- =========================================================================
    -- ensureMenuInjected
    -- =========================================================================
    describe("ensureMenuInjected", function()
        it("clones a section header and an option row into the General layout", function()
            WMGameSettings:ensureMenuInjected()

            local header = injectedHeader()
            local box    = injectedBox()
            assert.is_not_nil(header)
            assert.is_not_nil(box)
            assert.are.equal(headerPrefab, header.clonedFrom)
            assert.are.equal(rowPrefab,    box.clonedFrom)
            assert.is_true(WMGameSettings.menuInjected)
        end)

        it("labels the rows from the mod translations", function()
            WMGameSettings:ensureMenuInjected()

            local box = injectedBox()
            assert.are.equal("wm_settings_title",                injectedHeader().text)
            assert.are.equal("wm_settings_cpAutoResume",         box.elements[2].text)
            assert.are.equal("wm_settings_cpAutoResume_tooltip", box.elements[1].elements[1].text)
        end)

        it("routes the click callback of the control to WMGameSettings", function()
            WMGameSettings:ensureMenuInjected()

            local control = injectedBox().elements[1]
            assert.are.equal(WMGameSettings, control.target)
            assert.are.equal("onCpAutoResumeChanged", control.callbacks.onClickCallback)
            assert.are.equal(control, WMGameSettings.menuControls.cpAutoResume)
        end)

        it("registers both elements in the controls list of the page", function()
            WMGameSettings:ensureMenuInjected()

            assert.are.equal(2, #page.controlsList)
            assert.are.equal(injectedHeader(), page.controlsList[1])
            assert.are.equal(injectedBox(),    page.controlsList[2])
        end)

        it("gives every cloned element a fresh focus id", function()
            WMGameSettings:ensureMenuInjected()

            local box = injectedBox()
            -- Clones inherit the prefab ids; leaving them collides with the originals
            assert.is_true(box.focusId ~= rowPrefab.focusId)
            assert.is_true(box.elements[1].focusId ~= rowPrefab.elements[1].focusId)
            assert.is_true(injectedHeader().focusId ~= headerPrefab.focusId)
        end)

        it("invalidates the layout so the new rows are positioned", function()
            WMGameSettings:ensureMenuInjected()
            assert.is_true((layout.layoutInvalidated or 0) > 0)
        end)

        it("is idempotent - a second call adds nothing", function()
            WMGameSettings:ensureMenuInjected()
            local count = #layout.elements

            WMGameSettings:ensureMenuInjected()

            assert.are.equal(count, #layout.elements)
            assert.are.equal(2, #page.controlsList)
        end)

        it("adopts a control a previous session already injected into the page", function()
            -- A stale copy of this module (previous mission) is still hooked and injects
            -- first; adding a second row would duplicate it in the menu.
            WMGameSettings:ensureMenuInjected()
            local control = WMGameSettings.menuControls.cpAutoResume
            local elementCount = #layout.elements

            WMGameSettings.menuInjected = false
            WMGameSettings.menuControls = {}
            control.target = "stale module"

            WMGameSettings:ensureMenuInjected()

            assert.are.equal(elementCount, #layout.elements)
            assert.are.equal(control, WMGameSettings.menuControls.cpAutoResume)
            assert.are.equal(WMGameSettings, control.target)  -- newest generation owns it
        end)

        it("warns and injects nothing when the vanilla row prefab is missing", function()
            page.checkWoodHarvesterAutoCutBox = nil

            WMGameSettings:ensureMenuInjected()

            assert.is_nil(injectedBox())
            assert.is_false(WMGameSettings.menuInjected)
            assert.is_true(#_G.WMLogger.calls.warning > 0)
        end)

        it("does nothing when the settings page is not available", function()
            _G.g_gui.screenControllers = {}

            WMGameSettings:ensureMenuInjected()

            assert.is_false(WMGameSettings.menuInjected)
        end)

        it("does nothing when the General layout is not available", function()
            page.generalSettingsLayout = nil

            WMGameSettings:ensureMenuInjected()

            assert.is_false(WMGameSettings.menuInjected)
        end)
    end)

    -- =========================================================================
    -- refreshMenuState
    -- =========================================================================
    describe("refreshMenuState", function()
        it("injects on first use and shows the stored value", function()
            _G.WMSettings.courseplayAutoResume = false

            WMGameSettings:refreshMenuState()

            assert.is_false(injectedBox().elements[1].checked)
        end)

        it("shows the option as enabled by default", function()
            WMGameSettings:refreshMenuState()
            assert.is_true(injectedBox().elements[1].checked)
        end)

        it("stays editable on the server", function()
            _G.g_server = true
            WMGameSettings:refreshMenuState()
            assert.is_false(injectedBox().elements[1].disabled)
        end)

        it("is read-only on a multiplayer client", function()
            -- The executor runs server-side off the server savegame, so a client toggle
            -- would change nothing.
            _G.g_server = nil
            WMGameSettings:refreshMenuState()
            assert.is_true(injectedBox().elements[1].disabled)
        end)
    end)

    -- =========================================================================
    -- onCpAutoResumeChanged
    -- =========================================================================
    describe("onCpAutoResumeChanged", function()
        it("switches the option on when the box is checked", function()
            _G.WMSettings.courseplayAutoResume = false

            WMGameSettings:onCpAutoResumeChanged(_G.CheckedOptionElement.STATE_CHECKED)

            assert.is_true(_G.WMSettings.courseplayAutoResume)
        end)

        it("switches the option off when the box is unchecked", function()
            WMGameSettings:onCpAutoResumeChanged(_G.CheckedOptionElement.STATE_UNCHECKED)
            assert.is_false(_G.WMSettings.courseplayAutoResume)
        end)
    end)

    -- =========================================================================
    -- init
    -- =========================================================================
    describe("init", function()
        it("refreshes the rows when the settings frame is opened", function()
            _G.WMSettings.courseplayAutoResume = false
            WMGameSettings:init()

            InGameMenuSettingsFrame.onFrameOpen()

            assert.is_not_nil(injectedBox())
            assert.is_false(injectedBox().elements[1].checked)
        end)

        it("registers the cloned controls with the focus manager", function()
            WMGameSettings:init()
            FocusManager._loaded = {}

            FocusManager.setGui(FocusManager, "ingameMenuSettings")

            assert.is_true(#FocusManager._loaded > 0)
        end)

        it("ignores focus changes for other GUIs", function()
            WMGameSettings:init()
            FocusManager._loaded = {}

            FocusManager.setGui(FocusManager, "ingameMenuGeneral")

            assert.are.equal(0, #FocusManager._loaded)
            assert.is_false(WMGameSettings.menuInjected)
        end)

        it("hooks the settings frame only once", function()
            -- Every map load calls init(); without the isHooked guard the handler is
            -- appended again and the whole refresh runs once per past map load.
            WMGameSettings:init()
            WMGameSettings:init()
            WMGameSettings:init()

            local refreshes = 0
            local realRefresh = WMGameSettings.refreshMenuState
            WMGameSettings.refreshMenuState = function() refreshes = refreshes + 1 end

            InGameMenuSettingsFrame.onFrameOpen()

            WMGameSettings.refreshMenuState = realRefresh
            assert.are.equal(1, refreshes)
        end)

        it("hooks the focus manager only once", function()
            WMGameSettings:init()
            WMGameSettings:init()

            local injections = 0
            local realEnsure = WMGameSettings.ensureMenuInjected
            WMGameSettings.ensureMenuInjected = function() injections = injections + 1 end

            FocusManager.setGui(FocusManager, "ingameMenuSettings")

            WMGameSettings.ensureMenuInjected = realEnsure
            assert.are.equal(1, injections)
        end)
    end)

    -- =========================================================================
    -- delete
    -- =========================================================================
    describe("delete", function()
        it("removes the injected rows from the layout and the controls list", function()
            WMGameSettings:ensureMenuInjected()

            WMGameSettings:delete()

            assert.is_nil(injectedBox())
            assert.is_nil(injectedHeader())
            assert.are.equal(0, #page.controlsList)
            -- The vanilla prefabs must survive
            assert.are.equal(2, #layout.elements)
        end)

        it("clears the injected state so the next map load re-injects", function()
            WMGameSettings:ensureMenuInjected()

            WMGameSettings:delete()

            assert.is_false(WMGameSettings.menuInjected)
            assert.is_nil(WMGameSettings.menuControls.cpAutoResume)
            assert.is_nil(page.wmCpAutoResumeControl)

            WMGameSettings:ensureMenuInjected()
            assert.is_not_nil(injectedBox())
        end)

        it("is safe when nothing was injected", function()
            WMGameSettings:delete()
            assert.is_false(WMGameSettings.menuInjected)
        end)
    end)
end)
