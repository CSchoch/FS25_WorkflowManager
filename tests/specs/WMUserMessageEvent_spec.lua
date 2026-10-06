--[[
    WMUserMessageEvent Unit Tests
    Server -> client message for one farm's players (step errors, configuration warnings).
    Carries the i18n key plus string arguments so every client localizes it itself.
]]

describe("WMUserMessageEvent", function()
    local stream, shown

    setup(function()
        _G.Class = function(cls, parent) return { __index = cls } end
        _G.Event = { new = function(mt) return setmetatable({}, mt) end }
        _G.InitEventClass = function() end

        -- A single FIFO stream shared by the stream* functions
        _G.streamWriteInt32  = function(_, v) table.insert(stream, v) end
        _G.streamWriteString = function(_, v) table.insert(stream, v) end
        _G.streamWriteBool   = function(_, v) table.insert(stream, v) end
        _G.streamWriteUInt8  = function(_, v) table.insert(stream, v) end
        local function read() return table.remove(stream, 1) end
        _G.streamReadInt32, _G.streamReadString = read, read
        _G.streamReadBool, _G.streamReadUInt8 = read, read

        dofile("src/network/WMNetworkEvents.lua")
    end)

    before_each(function()
        stream, shown = {}, {}
        _G.WorkflowManager = {
            showFarmMessage = function(_, farmId, key, args, isError)
                table.insert(shown, { farmId = farmId, key = key, args = args, isError = isError })
            end,
        }
    end)

    local function connection(isServer)
        return { getIsServer = function() return isServer end }
    end

    it("round-trips farm, key, error flag and arguments through the stream", function()
        local sent = WMUserMessageEvent.new(3, "wm_error_cp_course_load", true, { "Fendt", "F34/Kalken" })
        sent:writeStream(1, connection(false))

        local received = WMUserMessageEvent.emptyNew()
        received:readStream(1, connection(true))

        assert.are.equal(1, #shown)
        assert.are.equal(3, shown[1].farmId)
        assert.are.equal("wm_error_cp_course_load", shown[1].key)
        assert.is_true(shown[1].isError)
        assert.are.same({ "Fendt", "F34/Kalken" }, shown[1].args)
        assert.are.equal(0, #stream)
    end)

    it("handles a message without arguments", function()
        WMUserMessageEvent.new(1, "wm_info_x", false, nil):writeStream(1, connection(false))
        WMUserMessageEvent.emptyNew():readStream(1, connection(true))
        assert.are.equal(0, #shown[1].args)
        assert.is_false(shown[1].isError)
    end)

    it("is ignored by the server (it already showed the message when sending)", function()
        local event = WMUserMessageEvent.new(1, "wm_error_x", true, {})
        event:run(connection(false))
        assert.are.equal(0, #shown)
    end)
end)
