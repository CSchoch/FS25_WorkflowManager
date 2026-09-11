--[[
    modDesc.xml Input Binding Tests

    While a GIANTS dialog is open, Gui:registerMenuInput registers the menu navigation actions
    in the same input context as the WM dialog hotkeys. A WM_GUI_* default bound to a key those
    actions own is silently dead: the Edit hotkey shipped on KEY_e, which is MENU_PAGE_NEXT, and
    never fired in any dialog; Stop on KEY_x (MENU_EXTRA_1) was dead the same way. Pin the
    confirmed-dead keys so no default lands on them again.
]]

describe("modDesc.xml input bindings", function()

    -- Keys confirmed dead for a dialog hotkey in-game
    local MENU_RESERVED = { KEY_q = "MENU_PAGE_PREV", KEY_e = "MENU_PAGE_NEXT", KEY_x = "MENU_EXTRA_1" }

    local bindings = {}

    setup(function()
        local file = assert(io.open("modDesc.xml", "r"))
        local xml = file:read("*a")
        file:close()
        for action, body in xml:gmatch('<actionBinding action="([%w_]+)">(.-)</actionBinding>') do
            bindings[action] = body:match('input="([^"]+)"')
        end
    end)

    it("binds Edit to KEY_t", function()
        assert.are.equal("KEY_t", bindings.WM_GUI_EDIT)
    end)

    it("binds Stop to KEY_k", function()
        assert.are.equal("KEY_k", bindings.WM_GUI_STOP)
    end)

    it("binds no dialog hotkey to a confirmed menu-owned key", function()
        local found = 0
        for action, input in pairs(bindings) do
            if action:find("^WM_GUI_") then
                found = found + 1
                if MENU_RESERVED[input] then
                    error(string.format("%s is bound to %s, which %s owns in dialogs",
                        action, input, MENU_RESERVED[input]))
                end
            end
        end
        assert.is_true(found > 0)
    end)
end)
