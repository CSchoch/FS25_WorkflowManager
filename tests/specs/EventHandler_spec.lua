--[[
    EventHandler Unit Tests
    Tests for WMEventHandler event system functionality
]]

describe("WMEventHandler", function()
    local WMEventHandler

    -- Load the actual source file before tests
    setup(function()
        -- Load the EventHandler source
        dofile("src/utils/EventHandler.lua")
        WMEventHandler = _G.WMEventHandler
    end)

    -- Reset state before each test
    before_each(function()
        WMEventHandler:init()
    end)

    describe("init", function()
        it("should initialize with empty listeners table", function()
            WMEventHandler:init()
            assert.is_table(WMEventHandler.listeners)
            assert.are.equal(0, #WMEventHandler.listeners)
        end)

        it("should clear existing listeners on init", function()
            -- Add a listener first
            WMEventHandler:addEventListener("testEvent", function() end)
            assert.is_not_nil(WMEventHandler.listeners["testEvent"])

            -- Re-init should clear it
            WMEventHandler:init()
            assert.is_nil(WMEventHandler.listeners["testEvent"])
        end)
    end)

    describe("addEventListener", function()
        it("should add a listener and return an ID", function()
            local callback = function() end
            local id = WMEventHandler:addEventListener("testEvent", callback)

            assert.is_number(id)
            assert.is_true(id >= 1)
        end)

        it("should store callback in listeners table", function()
            local callback = function() end
            WMEventHandler:addEventListener("testEvent", callback)

            assert.is_not_nil(WMEventHandler.listeners["testEvent"])
            assert.is_not_nil(WMEventHandler.listeners["testEvent"][1])
            assert.are.equal(callback, WMEventHandler.listeners["testEvent"][1].callback)
        end)

        it("should store target when provided", function()
            local target = { name = "TestTarget" }
            local callback = function() end
            WMEventHandler:addEventListener("testEvent", callback, target)

            assert.are.equal(target, WMEventHandler.listeners["testEvent"][1].target)
        end)

        it("should allow multiple listeners for same event", function()
            local callback1 = function() end
            local callback2 = function() end

            local id1 = WMEventHandler:addEventListener("testEvent", callback1)
            local id2 = WMEventHandler:addEventListener("testEvent", callback2)

            assert.are_not.equal(id1, id2)
            assert.is_not_nil(WMEventHandler.listeners["testEvent"][1])
            assert.is_not_nil(WMEventHandler.listeners["testEvent"][2])
        end)

        it("should assign sequential IDs", function()
            local id1 = WMEventHandler:addEventListener("testEvent", function() end)
            local id2 = WMEventHandler:addEventListener("testEvent", function() end)
            local id3 = WMEventHandler:addEventListener("testEvent", function() end)

            assert.are.equal(1, id1)
            assert.are.equal(2, id2)
            assert.are.equal(3, id3)
        end)
    end)

    describe("removeEventListener", function()
        it("should remove a listener by ID", function()
            local callback = function() end
            local id = WMEventHandler:addEventListener("testEvent", callback)

            WMEventHandler:removeEventListener("testEvent", id)

            assert.is_nil(WMEventHandler.listeners["testEvent"][id])
        end)

        it("should not affect other listeners", function()
            local callback1 = function() end
            local callback2 = function() end

            local id1 = WMEventHandler:addEventListener("testEvent", callback1)
            local id2 = WMEventHandler:addEventListener("testEvent", callback2)

            WMEventHandler:removeEventListener("testEvent", id1)

            assert.is_nil(WMEventHandler.listeners["testEvent"][id1])
            assert.is_not_nil(WMEventHandler.listeners["testEvent"][id2])
        end)

        it("should handle non-existent event type gracefully", function()
            -- Should not error
            assert.has_no.errors(function()
                WMEventHandler:removeEventListener("nonExistentEvent", 1)
            end)
        end)

        it("should handle non-existent listener ID gracefully", function()
            WMEventHandler:addEventListener("testEvent", function() end)

            -- Should not error when removing non-existent ID
            assert.has_no.errors(function()
                WMEventHandler:removeEventListener("testEvent", 999)
            end)
        end)
    end)

    describe("fireEvent", function()
        it("should call registered callback", function()
            local called = false
            local callback = function()
                called = true
            end

            WMEventHandler:addEventListener("testEvent", callback)
            WMEventHandler:fireEvent("testEvent")

            assert.is_true(called)
        end)

        it("should pass event type and data to callback without target", function()
            local receivedType, receivedData
            local callback = function(eventType, data)
                receivedType = eventType
                receivedData = data
            end

            WMEventHandler:addEventListener("testEvent", callback)
            WMEventHandler:fireEvent("testEvent", { value = 42 })

            assert.are.equal("testEvent", receivedType)
            assert.is_table(receivedData)
            assert.are.equal(42, receivedData.value)
        end)

        it("should call callback with target as first argument when target is set", function()
            local target = { name = "TestTarget" }
            local receivedSelf, receivedType, receivedData

            local callback = function(self, eventType, data)
                receivedSelf = self
                receivedType = eventType
                receivedData = data
            end

            WMEventHandler:addEventListener("testEvent", callback, target)
            WMEventHandler:fireEvent("testEvent", { value = 123 })

            assert.are.equal(target, receivedSelf)
            assert.are.equal("testEvent", receivedType)
            assert.are.equal(123, receivedData.value)
        end)

        it("should call all registered listeners", function()
            local count = 0
            local callback1 = function() count = count + 1 end
            local callback2 = function() count = count + 1 end
            local callback3 = function() count = count + 1 end

            WMEventHandler:addEventListener("testEvent", callback1)
            WMEventHandler:addEventListener("testEvent", callback2)
            WMEventHandler:addEventListener("testEvent", callback3)

            WMEventHandler:fireEvent("testEvent")

            assert.are.equal(3, count)
        end)

        it("should not error when firing event with no listeners", function()
            assert.has_no.errors(function()
                WMEventHandler:fireEvent("nonExistentEvent", { data = "test" })
            end)
        end)

        it("should not call removed listeners", function()
            local called1 = false
            local called2 = false

            local callback1 = function() called1 = true end
            local callback2 = function() called2 = true end

            local id1 = WMEventHandler:addEventListener("testEvent", callback1)
            WMEventHandler:addEventListener("testEvent", callback2)

            WMEventHandler:removeEventListener("testEvent", id1)
            WMEventHandler:fireEvent("testEvent")

            assert.is_false(called1)
            assert.is_true(called2)
        end)
    end)

    describe("removeAllListeners", function()
        it("should remove all listeners for a specific event type", function()
            WMEventHandler:addEventListener("event1", function() end)
            WMEventHandler:addEventListener("event1", function() end)
            WMEventHandler:addEventListener("event2", function() end)

            WMEventHandler:removeAllListeners("event1")

            assert.is_nil(WMEventHandler.listeners["event1"])
            assert.is_not_nil(WMEventHandler.listeners["event2"])
        end)

        it("should remove all listeners when called with nil", function()
            WMEventHandler:addEventListener("event1", function() end)
            WMEventHandler:addEventListener("event2", function() end)
            WMEventHandler:addEventListener("event3", function() end)

            WMEventHandler:removeAllListeners(nil)

            assert.are.equal(0, #WMEventHandler.listeners)
        end)
    end)

    describe("subscribe (convenience method)", function()
        it("should work same as addEventListener with target", function()
            local target = { name = "TestTarget" }
            local callback = function() end

            local id = WMEventHandler:subscribe("testEvent", target, callback)

            assert.is_number(id)
            assert.are.equal(callback, WMEventHandler.listeners["testEvent"][id].callback)
            assert.are.equal(target, WMEventHandler.listeners["testEvent"][id].target)
        end)
    end)

    describe("unsubscribe (convenience method)", function()
        it("should work same as removeEventListener", function()
            local callback = function() end
            local id = WMEventHandler:addEventListener("testEvent", callback)

            WMEventHandler:unsubscribe("testEvent", id)

            assert.is_nil(WMEventHandler.listeners["testEvent"][id])
        end)
    end)

    describe("event type constants", function()
        it("should have workflow event constants defined", function()
            assert.are.equal("workflowStarted", WMEventHandler.EVENT_WORKFLOW_STARTED)
            assert.are.equal("workflowStopped", WMEventHandler.EVENT_WORKFLOW_STOPPED)
            assert.are.equal("workflowPaused", WMEventHandler.EVENT_WORKFLOW_PAUSED)
            assert.are.equal("workflowResumed", WMEventHandler.EVENT_WORKFLOW_RESUMED)
            assert.are.equal("workflowCompleted", WMEventHandler.EVENT_WORKFLOW_COMPLETED)
            assert.are.equal("workflowError", WMEventHandler.EVENT_WORKFLOW_ERROR)
        end)

        it("should have step event constants defined", function()
            assert.are.equal("stepStarted", WMEventHandler.EVENT_STEP_STARTED)
            assert.are.equal("stepCompleted", WMEventHandler.EVENT_STEP_COMPLETED)
            assert.are.equal("stepError", WMEventHandler.EVENT_STEP_ERROR)
            assert.are.equal("stepChanged", WMEventHandler.EVENT_STEP_CHANGED)
        end)

        it("should have integration event constants defined", function()
            assert.are.equal("autodriveFinished", WMEventHandler.EVENT_AUTODRIVE_FINISHED)
            assert.are.equal("courseplayFinished", WMEventHandler.EVENT_COURSEPLAY_FINISHED)
        end)
    end)
end)
