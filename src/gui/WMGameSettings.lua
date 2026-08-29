--[[
    WorkflowManager - Game settings rows

    Appends the mod's options to the base game's General settings list
    (ESC -> Settings -> General) instead of opening a page of its own.

    The rows are built by cloning the vanilla ones, so no own GUI XML is needed and the
    styling always matches the game's:
        page  = g_gui.screenControllers[InGameMenu].pageSettings
        layout = page.generalSettingsLayout
        header prefab = the layout element named "sectionHeader"
        row prefab    = page.checkWoodHarvesterAutoCutBox
                        box.elements[1] = option control (its elements[1] = tooltip)
                        box.elements[2] = label
    Verified against FS25_MovePlaceablesAdvanced (scripts/AxesMovement.lua), which uses the
    same injection.

    Author: WorkflowManager Team
]]

---@class WMGameSettings
WMGameSettings = {}

WMGameSettings.menuInjected = false
WMGameSettings.menuControls = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---Cloned elements keep the focus ids they were cloned from; those collide with the
---originals, so every element in the copy needs a fresh one.
local function updateFocusIds(element)
    if element == nil then return end
    element.focusId = FocusManager:serveAutoFocusId()
    for _, child in pairs(element.elements or {}) do
        updateFocusIds(child)
    end
end

---The in-game settings page and the layout of its General tab
---@return table|nil page
---@return table|nil layout
function WMGameSettings:getSettingsPage()
    local menu = g_gui ~= nil and g_gui.screenControllers[InGameMenu] or nil
    local page = menu ~= nil and menu.pageSettings or nil
    if page == nil and g_inGameMenu ~= nil then
        page = g_inGameMenu.pageSettings
    end
    if page == nil then return nil, nil end
    return page, page.generalSettingsLayout
end

-- ---------------------------------------------------------------------------
-- Injection
-- ---------------------------------------------------------------------------

---Add the section header and the option rows to the General settings list.
---Runs once; safe to call on every settings-frame open.
function WMGameSettings:ensureMenuInjected()
    if self.menuInjected then return end

    local page, layout = self:getSettingsPage()
    if page == nil or layout == nil then return end

    -- A previous mission's copy of this module may still be hooked into the settings
    -- frame and inject first. The controls live on the page, so adopt them instead of
    -- adding a second row, and take over the callback target.
    if page.wmCpAutoResumeControl ~= nil then
        self.menuControls.cpAutoResume = page.wmCpAutoResumeControl
        self.menuControls.cpAutoResume.target = self
        self.menuInjected = true
        return
    end

    local rowPrefab = page.checkWoodHarvesterAutoCutBox
    if rowPrefab == nil then
        WMLogger:warning("checkWoodHarvesterAutoCutBox not found on the settings page - the "
            .. "Workflow Manager options are not shown in the settings menu; they keep their "
            .. "saved values.")
        return
    end

    -- Section header: clone the one the vanilla list already uses
    for _, element in ipairs(layout.elements) do
        if element.name == "sectionHeader" then
            local header = element:clone(layout)
            header.id      = "wmSectionHeader"
            header.focusId = FocusManager:serveAutoFocusId()
            header:setText(g_i18n:getText("wm_settings_title"))
            table.insert(page.controlsList, header)
            self.menuControls.sectionHeader = header
            break
        end
    end

    -- Courseplay auto-resume row
    local box = rowPrefab:clone(layout)
    if box == nil then
        WMLogger:warning("Failed to clone the settings row - Workflow Manager options not shown")
        return
    end
    box.id = "wmCpAutoResumeBox"

    local control = box.elements[1]
    if control ~= nil then
        control.target = self
        control.id     = "wmCpAutoResume"
        control:setCallback("onClickCallback", "onCpAutoResumeChanged")
        control:setDisabled(false)
        local tooltip = control.elements[1]
        if tooltip ~= nil then
            tooltip:setText(g_i18n:getText("wm_settings_cpAutoResume_tooltip"))
        end
    end
    local label = box.elements[2]
    if label ~= nil then
        label:setText(g_i18n:getText("wm_settings_cpAutoResume"))
    end

    updateFocusIds(box)
    table.insert(page.controlsList, box)

    self.menuControls.cpAutoResume = control
    page.wmCpAutoResumeControl = control

    layout:invalidateLayout()
    self.menuInjected = true

    WMLogger:info("Added Workflow Manager options to the General settings page")
end

---Push the stored values into the controls (called on every settings-frame open)
function WMGameSettings:refreshMenuState()
    self:ensureMenuInjected()

    local control = self.menuControls.cpAutoResume
    if control == nil then return end

    control:setIsChecked(WMSettings:isCourseplayAutoResumeEnabled())

    -- The executor runs server-side off the server's savegame, so a client toggling this
    -- would change nothing. Show it, but read-only.
    control:setDisabled(g_server == nil)
end

---Option toggled by the player
---@param state number CheckedOptionElement state
function WMGameSettings:onCpAutoResumeChanged(state)
    WMSettings.courseplayAutoResume = (state == CheckedOptionElement.STATE_CHECKED)
    WMLogger:info("Setting courseplayAutoResume=%s", tostring(WMSettings.courseplayAutoResume))
end

-- ---------------------------------------------------------------------------
-- Setup / teardown
-- ---------------------------------------------------------------------------

---Hook the settings frame. Safe to call on every map load.
function WMGameSettings:init()
    self.menuInjected = false
    self.menuControls = {}

    if self.isHooked then return end

    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(
        InGameMenuSettingsFrame.onFrameOpen,
        function() WMGameSettings:refreshMenuState() end)

    -- Injecting is not enough: the FocusManager rebuilds its element map when the settings
    -- GUI is (re)opened, so the cloned controls have to be registered there as well or
    -- keyboard/controller navigation skips them.
    FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
        if gui ~= "ingameMenuSettings" then return end
        WMGameSettings:ensureMenuInjected()
        for _, control in pairs(WMGameSettings.menuControls) do
            if not control.focusId
            or not FocusManager.currentFocusData.idToElementMapping[control.focusId] then
                FocusManager:loadElementFromCustomValues(control, nil, nil, false, false)
            end
        end
        local _, layout = WMGameSettings:getSettingsPage()
        if layout ~= nil then
            layout:invalidateLayout()
        end
    end)

    self.isHooked = true
end

---Remove the injected rows. Called from WorkflowManager:deleteMap.
function WMGameSettings:delete()
    local page, layout = self:getSettingsPage()

    for _, element in pairs(self.menuControls) do
        -- The option control is a child of the cloned row container; drop the container
        local root = element.parent ~= nil and element.parent ~= layout and element.parent or element
        pcall(function()
            if page ~= nil and page.controlsList ~= nil then
                for i = #page.controlsList, 1, -1 do
                    if page.controlsList[i] == root then
                        table.remove(page.controlsList, i)
                    end
                end
            end
            if root.parent ~= nil then
                root.parent:removeElement(root)
            end
            root:delete()
        end)
    end

    self.menuControls = {}
    self.menuInjected = false

    if page ~= nil then
        page.wmCpAutoResumeControl = nil
    end
    if layout ~= nil then
        pcall(function() layout:invalidateLayout() end)
    end
end
