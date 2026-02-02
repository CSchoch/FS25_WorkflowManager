--[[
    Logger Unit Tests
    Tests for WMLogger logging functionality
]]

describe("WMLogger", function()
    local WMLogger
    local capturedOutput = {}

    -- Setup: Load the actual Logger source
    setup(function()
        -- Mock print to capture output
        _G.print = function(...)
            table.insert(capturedOutput, table.concat({...}, " "))
        end

        -- Mock Logging object (FS25's logging system)
        _G.Logging = {
            info = function(format, ...)
                table.insert(capturedOutput, string.format("[INFO] " .. format, ...))
            end,
            warning = function(format, ...)
                table.insert(capturedOutput, string.format("[WARNING] " .. format, ...))
            end,
            error = function(format, ...)
                table.insert(capturedOutput, string.format("[ERROR] " .. format, ...))
            end
        }

        -- Mock WMDevConfig
        _G.WMDevConfig = {
            isDebugLogging = function() return false end,
            shouldLogAPICalls = function() return false end,
            shouldLogEvents = function() return false end,
            shouldLogStateChanges = function() return false end
        }

        -- Load the Logger source
        dofile("src/utils/Logger.lua")
        WMLogger = _G.WMLogger
    end)

    -- Reset state before each test
    before_each(function()
        capturedOutput = {}
        WMLogger.currentLevel = WMLogger.LEVEL_INFO
        WMLogger.initializedFromConfig = false
    end)

    describe("log level constants", function()
        it("should have all log levels defined", function()
            assert.are.equal(1, WMLogger.LEVEL_DEBUG)
            assert.are.equal(2, WMLogger.LEVEL_INFO)
            assert.are.equal(3, WMLogger.LEVEL_WARNING)
            assert.are.equal(4, WMLogger.LEVEL_ERROR)
        end)

        it("should have levels in ascending order of severity", function()
            assert.is_true(WMLogger.LEVEL_DEBUG < WMLogger.LEVEL_INFO)
            assert.is_true(WMLogger.LEVEL_INFO < WMLogger.LEVEL_WARNING)
            assert.is_true(WMLogger.LEVEL_WARNING < WMLogger.LEVEL_ERROR)
        end)
    end)

    describe("setLevel", function()
        it("should change current log level", function()
            WMLogger:setLevel(WMLogger.LEVEL_DEBUG)
            assert.are.equal(WMLogger.LEVEL_DEBUG, WMLogger.currentLevel)

            WMLogger:setLevel(WMLogger.LEVEL_ERROR)
            assert.are.equal(WMLogger.LEVEL_ERROR, WMLogger.currentLevel)
        end)
    end)

    describe("enableDebug / disableDebug", function()
        it("enableDebug should set level to DEBUG", function()
            WMLogger:enableDebug()
            assert.are.equal(WMLogger.LEVEL_DEBUG, WMLogger.currentLevel)
        end)

        it("disableDebug should set level to INFO", function()
            WMLogger:enableDebug()
            WMLogger:disableDebug()
            assert.are.equal(WMLogger.LEVEL_INFO, WMLogger.currentLevel)
        end)
    end)

    describe("debug", function()
        it("should output when level is DEBUG", function()
            WMLogger:setLevel(WMLogger.LEVEL_DEBUG)
            WMLogger:debug("Test debug message")

            assert.are.equal(1, #capturedOutput)
            assert.is_truthy(capturedOutput[1]:match("DEBUG"))
            assert.is_truthy(capturedOutput[1]:match("Test debug message"))
        end)

        it("should NOT output when level is INFO", function()
            WMLogger:setLevel(WMLogger.LEVEL_INFO)
            WMLogger:debug("Test debug message")

            assert.are.equal(0, #capturedOutput)
        end)

        it("should format message with arguments", function()
            WMLogger:setLevel(WMLogger.LEVEL_DEBUG)
            WMLogger:debug("Value: %d, Name: %s", 42, "test")

            assert.is_truthy(capturedOutput[1]:match("Value: 42"))
            assert.is_truthy(capturedOutput[1]:match("Name: test"))
        end)

        it("should include prefix", function()
            WMLogger:setLevel(WMLogger.LEVEL_DEBUG)
            WMLogger:debug("Test")

            assert.is_truthy(capturedOutput[1]:match("%[WorkflowManager%]"))
        end)
    end)

    describe("info", function()
        it("should output when level is INFO or lower", function()
            WMLogger:setLevel(WMLogger.LEVEL_INFO)
            WMLogger:info("Test info message")

            assert.are.equal(1, #capturedOutput)
            assert.is_truthy(capturedOutput[1]:match("INFO"))
        end)

        it("should NOT output when level is WARNING", function()
            WMLogger:setLevel(WMLogger.LEVEL_WARNING)
            WMLogger:info("Test info message")

            assert.are.equal(0, #capturedOutput)
        end)

        it("should format message with arguments", function()
            WMLogger:info("Count: %d", 123)

            assert.is_truthy(capturedOutput[1]:match("Count: 123"))
        end)
    end)

    describe("warning", function()
        it("should output when level is WARNING or lower", function()
            WMLogger:setLevel(WMLogger.LEVEL_WARNING)
            WMLogger:warning("Test warning message")

            assert.are.equal(1, #capturedOutput)
            assert.is_truthy(capturedOutput[1]:match("WARNING"))
        end)

        it("should NOT output when level is ERROR", function()
            WMLogger:setLevel(WMLogger.LEVEL_ERROR)
            WMLogger:warning("Test warning message")

            assert.are.equal(0, #capturedOutput)
        end)

        it("should format message with arguments", function()
            WMLogger:warning("File not found: %s", "config.xml")

            assert.is_truthy(capturedOutput[1]:match("File not found: config.xml"))
        end)
    end)

    describe("error", function()
        it("should always output (highest level)", function()
            WMLogger:setLevel(WMLogger.LEVEL_ERROR)
            WMLogger:error("Test error message")

            assert.are.equal(1, #capturedOutput)
            assert.is_truthy(capturedOutput[1]:match("ERROR"))
        end)

        it("should output at all log levels", function()
            local levels = {
                WMLogger.LEVEL_DEBUG,
                WMLogger.LEVEL_INFO,
                WMLogger.LEVEL_WARNING,
                WMLogger.LEVEL_ERROR
            }

            for _, level in ipairs(levels) do
                capturedOutput = {}
                WMLogger:setLevel(level)
                WMLogger:error("Error at level %d", level)

                assert.are.equal(1, #capturedOutput,
                    "Error should output at level " .. level)
            end
        end)

        it("should format message with arguments", function()
            WMLogger:error("Failed to load: %s (code: %d)", "file.xml", 404)

            assert.is_truthy(capturedOutput[1]:match("Failed to load: file.xml"))
            assert.is_truthy(capturedOutput[1]:match("code: 404"))
        end)
    end)

    describe("message formatting", function()
        before_each(function()
            WMLogger:setLevel(WMLogger.LEVEL_DEBUG)
        end)

        it("should handle message without arguments", function()
            WMLogger:debug("Simple message")

            assert.is_truthy(capturedOutput[1]:match("Simple message"))
        end)

        it("should handle string formatting", function()
            WMLogger:debug("Hello %s!", "World")

            assert.is_truthy(capturedOutput[1]:match("Hello World!"))
        end)

        it("should handle number formatting", function()
            WMLogger:debug("Integer: %d, Float: %.2f", 42, 3.14159)

            assert.is_truthy(capturedOutput[1]:match("Integer: 42"))
            assert.is_truthy(capturedOutput[1]:match("Float: 3.14"))
        end)

        it("should handle multiple arguments", function()
            WMLogger:debug("A=%s B=%d C=%s", "one", 2, "three")

            assert.is_truthy(capturedOutput[1]:match("A=one"))
            assert.is_truthy(capturedOutput[1]:match("B=2"))
            assert.is_truthy(capturedOutput[1]:match("C=three"))
        end)
    end)

    describe("prefix", function()
        it("should have default prefix", function()
            assert.are.equal("[WorkflowManager]", WMLogger.prefix)
        end)
    end)

    describe("initFromDevConfig", function()
        it("should only initialize once", function()
            WMLogger.initializedFromConfig = false

            _G.WMDevConfig.isDebugLogging = function() return true end
            WMLogger:initFromDevConfig()
            assert.are.equal(WMLogger.LEVEL_DEBUG, WMLogger.currentLevel)

            -- Change config, but shouldn't re-init
            _G.WMDevConfig.isDebugLogging = function() return false end
            WMLogger:initFromDevConfig()
            assert.are.equal(WMLogger.LEVEL_DEBUG, WMLogger.currentLevel)  -- Still DEBUG
        end)

        it("should set DEBUG level when WMDevConfig.isDebugLogging returns true", function()
            WMLogger.initializedFromConfig = false
            _G.WMDevConfig.isDebugLogging = function() return true end

            WMLogger:initFromDevConfig()

            assert.are.equal(WMLogger.LEVEL_DEBUG, WMLogger.currentLevel)
        end)

        it("should set INFO level when WMDevConfig.isDebugLogging returns false", function()
            WMLogger.initializedFromConfig = false
            WMLogger.currentLevel = WMLogger.LEVEL_DEBUG  -- Start at DEBUG
            _G.WMDevConfig.isDebugLogging = function() return false end

            WMLogger:initFromDevConfig()

            assert.are.equal(WMLogger.LEVEL_INFO, WMLogger.currentLevel)
        end)

        it("should handle nil WMDevConfig gracefully", function()
            WMLogger.initializedFromConfig = false
            local originalConfig = _G.WMDevConfig
            _G.WMDevConfig = nil

            assert.has_no.errors(function()
                WMLogger:initFromDevConfig()
            end)

            _G.WMDevConfig = originalConfig
        end)
    end)

    describe("apiCall", function()
        it("should log API calls when enabled", function()
            _G.WMDevConfig.shouldLogAPICalls = function() return true end

            WMLogger:apiCall("AutoDrive", "StartDriving", "vehicle1", "destination")

            assert.are.equal(1, #capturedOutput)
            assert.is_truthy(capturedOutput[1]:match("API"))
            assert.is_truthy(capturedOutput[1]:match("AutoDrive"))
            assert.is_truthy(capturedOutput[1]:match("StartDriving"))
        end)

        it("should NOT log API calls when disabled", function()
            _G.WMDevConfig.shouldLogAPICalls = function() return false end

            WMLogger:apiCall("AutoDrive", "StartDriving")

            assert.are.equal(0, #capturedOutput)
        end)
    end)

    describe("event", function()
        it("should log events when enabled", function()
            _G.WMDevConfig.shouldLogEvents = function() return true end

            WMLogger:event("workflowStarted", { workflowId = "wf001" })

            assert.are.equal(1, #capturedOutput)
            assert.is_truthy(capturedOutput[1]:match("EVENT"))
            assert.is_truthy(capturedOutput[1]:match("workflowStarted"))
        end)

        it("should NOT log events when disabled", function()
            _G.WMDevConfig.shouldLogEvents = function() return false end

            WMLogger:event("workflowStarted", { workflowId = "wf001" })

            assert.are.equal(0, #capturedOutput)
        end)

        it("should handle nil data", function()
            _G.WMDevConfig.shouldLogEvents = function() return true end

            assert.has_no.errors(function()
                WMLogger:event("simpleEvent", nil)
            end)
        end)
    end)

    describe("stateChange", function()
        it("should log state changes when enabled", function()
            _G.WMDevConfig.shouldLogStateChanges = function() return true end

            WMLogger:stateChange("Workflow", "ready", "running")

            assert.are.equal(1, #capturedOutput)
            assert.is_truthy(capturedOutput[1]:match("STATE"))
            assert.is_truthy(capturedOutput[1]:match("ready"))
            assert.is_truthy(capturedOutput[1]:match("running"))
        end)

        it("should NOT log state changes when disabled", function()
            _G.WMDevConfig.shouldLogStateChanges = function() return false end

            WMLogger:stateChange("Workflow", "ready", "running")

            assert.are.equal(0, #capturedOutput)
        end)

        it("should handle nil oldState", function()
            _G.WMDevConfig.shouldLogStateChanges = function() return true end

            assert.has_no.errors(function()
                WMLogger:stateChange("Workflow", nil, "running")
            end)

            assert.is_truthy(capturedOutput[1]:match("-> running"))
        end)
    end)
end)
