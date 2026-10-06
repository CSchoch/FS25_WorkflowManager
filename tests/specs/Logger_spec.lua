--[[
    Logger Unit Tests
    Tests for WMLogger logging functionality
]]

describe("WMLogger", function()
    local WMLogger
    local originalPrint = print  -- Preserve original print for test runner

    -- Global captured output (accessible from all scopes)
    _G._loggerTestOutput = {}

    -- Custom print that captures AND outputs
    local function capturingPrint(...)
        table.insert(_G._loggerTestOutput, table.concat({...}, " "))
    end

    -- Setup: Load the actual Logger source
    setup(function()
        -- Mock Logging object (FS25's logging system)
        _G.Logging = {
            info = function(format, ...)
                table.insert(_G._loggerTestOutput, string.format("[INFO] " .. format, ...))
            end,
            warning = function(format, ...)
                table.insert(_G._loggerTestOutput, string.format("[WARNING] " .. format, ...))
            end,
            error = function(format, ...)
                table.insert(_G._loggerTestOutput, string.format("[ERROR] " .. format, ...))
            end
        }

        -- Mock WMDevConfig
        _G.WMDevConfig = {
            isDebugLogging = function() return false end,
            shouldLogAPICalls = function() return false end,
            shouldLogEvents = function() return false end,
            shouldLogStateChanges = function() return false end
        }

        -- Temporarily override print to capture output during Logger load
        local tempPrint = _G.print
        _G.print = capturingPrint

        -- Load the Logger source
        dofile("src/utils/Logger.lua")
        WMLogger = _G.WMLogger

        -- Restore print for test runner
        _G.print = tempPrint
    end)

    -- Reset state before each test
    before_each(function()
        _G._loggerTestOutput = {}
        -- Set up print capture for this test
        _G.print = capturingPrint
        WMLogger.currentLevel = WMLogger.LEVEL_INFO
        WMLogger.initializedFromConfig = false
        WMLogger.debugMode = false
        _G.WMDevConfig.isDebugLogging = function() return false end
        _G.WMDevConfig.shouldLogAPICalls = function() return false end
        _G.WMDevConfig.shouldLogEvents = function() return false end
        _G.WMDevConfig.shouldLogStateChanges = function() return false end
    end)

    -- =========================================================================
    -- setDebugMode ("Debug logging" mod option)
    -- =========================================================================
    describe("setDebugMode", function()
        it("switches to DEBUG level when the option is turned on", function()
            WMLogger:setDebugMode(true)
            assert.are.equal(WMLogger.LEVEL_DEBUG, WMLogger.currentLevel)
            assert.is_true(WMLogger.debugMode)
        end)

        it("returns to INFO level when the option is turned off", function()
            WMLogger:setDebugMode(true)
            WMLogger:setDebugMode(false)
            assert.are.equal(WMLogger.LEVEL_INFO, WMLogger.currentLevel)
        end)

        it("keeps DEBUG level when the developer config asks for it", function()
            _G.WMDevConfig.isDebugLogging = function() return true end
            WMLogger:setDebugMode(false)
            assert.are.equal(WMLogger.LEVEL_DEBUG, WMLogger.currentLevel)
        end)

        it("logs API calls, events and state changes with every dev flag off", function()
            -- A release build has no DevConfig flags at all; the option alone decides
            WMLogger:setDebugMode(true)

            WMLogger:apiCall("AutoDrive", "StartDriving")
            WMLogger:event("STEP", nil)
            WMLogger:stateChange("Workflow", "ready", "running")

            assert.are.equal(3, #_G._loggerTestOutput)
        end)

        it("stays silent for those lines when both the option and the dev flags are off", function()
            WMLogger:setDebugMode(false)

            WMLogger:apiCall("AutoDrive", "StartDriving")
            WMLogger:event("STEP", nil)
            WMLogger:stateChange("Workflow", "ready", "running")

            assert.are.equal(0, #_G._loggerTestOutput)
        end)
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

            assert.are.equal(1, #_G._loggerTestOutput)
            assert.is_truthy(_G._loggerTestOutput[1]:match("DEBUG"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("Test debug message"))
        end)

        it("should NOT output when level is INFO", function()
            WMLogger:setLevel(WMLogger.LEVEL_INFO)
            WMLogger:debug("Test debug message")

            assert.are.equal(0, #_G._loggerTestOutput)
        end)

        it("should format message with arguments", function()
            WMLogger:setLevel(WMLogger.LEVEL_DEBUG)
            WMLogger:debug("Value: %d, Name: %s", 42, "test")

            assert.is_truthy(_G._loggerTestOutput[1]:match("Value: 42"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("Name: test"))
        end)

        it("should include prefix", function()
            WMLogger:setLevel(WMLogger.LEVEL_DEBUG)
            WMLogger:debug("Test")

            assert.is_truthy(_G._loggerTestOutput[1]:match("%[WorkflowManager%]"))
        end)
    end)

    describe("info", function()
        it("should output when level is INFO or lower", function()
            WMLogger:setLevel(WMLogger.LEVEL_INFO)
            WMLogger:info("Test info message")

            assert.are.equal(1, #_G._loggerTestOutput)
            assert.is_truthy(_G._loggerTestOutput[1]:match("INFO"))
        end)

        it("should NOT output when level is WARNING", function()
            WMLogger:setLevel(WMLogger.LEVEL_WARNING)
            WMLogger:info("Test info message")

            assert.are.equal(0, #_G._loggerTestOutput)
        end)

        it("should format message with arguments", function()
            WMLogger:info("Count: %d", 123)

            assert.is_truthy(_G._loggerTestOutput[1]:match("Count: 123"))
        end)
    end)

    describe("warning", function()
        it("should output when level is WARNING or lower", function()
            WMLogger:setLevel(WMLogger.LEVEL_WARNING)
            WMLogger:warning("Test warning message")

            assert.are.equal(1, #_G._loggerTestOutput)
            assert.is_truthy(_G._loggerTestOutput[1]:match("WARNING"))
        end)

        it("should NOT output when level is ERROR", function()
            WMLogger:setLevel(WMLogger.LEVEL_ERROR)
            WMLogger:warning("Test warning message")

            assert.are.equal(0, #_G._loggerTestOutput)
        end)

        it("should format message with arguments", function()
            WMLogger:warning("File not found: %s", "config.xml")

            assert.is_truthy(_G._loggerTestOutput[1]:match("File not found: config.xml"))
        end)
    end)

    describe("error", function()
        it("should always output (highest level)", function()
            WMLogger:setLevel(WMLogger.LEVEL_ERROR)
            WMLogger:error("Test error message")

            assert.are.equal(1, #_G._loggerTestOutput)
            assert.is_truthy(_G._loggerTestOutput[1]:match("ERROR"))
        end)

        it("should output at all log levels", function()
            local levels = {
                WMLogger.LEVEL_DEBUG,
                WMLogger.LEVEL_INFO,
                WMLogger.LEVEL_WARNING,
                WMLogger.LEVEL_ERROR
            }

            for _, level in ipairs(levels) do
                _G._loggerTestOutput = {}
                WMLogger:setLevel(level)
                WMLogger:error("Error at level %d", level)

                assert.are.equal(1, #_G._loggerTestOutput,
                    "Error should output at level " .. level)
            end
        end)

        it("should format message with arguments", function()
            WMLogger:error("Failed to load: %s (code: %d)", "file.xml", 404)

            assert.is_truthy(_G._loggerTestOutput[1]:match("Failed to load: file.xml"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("code: 404"))
        end)
    end)

    describe("message formatting", function()
        before_each(function()
            WMLogger:setLevel(WMLogger.LEVEL_DEBUG)
        end)

        it("should handle message without arguments", function()
            WMLogger:debug("Simple message")

            assert.is_truthy(_G._loggerTestOutput[1]:match("Simple message"))
        end)

        it("should handle string formatting", function()
            WMLogger:debug("Hello %s!", "World")

            assert.is_truthy(_G._loggerTestOutput[1]:match("Hello World!"))
        end)

        it("should handle number formatting", function()
            WMLogger:debug("Integer: %d, Float: %.2f", 42, 3.14159)

            assert.is_truthy(_G._loggerTestOutput[1]:match("Integer: 42"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("Float: 3.14"))
        end)

        it("should handle multiple arguments", function()
            WMLogger:debug("A=%s B=%d C=%s", "one", 2, "three")

            assert.is_truthy(_G._loggerTestOutput[1]:match("A=one"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("B=2"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("C=three"))
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

            assert.are.equal(1, #_G._loggerTestOutput)
            assert.is_truthy(_G._loggerTestOutput[1]:match("API"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("AutoDrive"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("StartDriving"))
        end)

        it("should NOT log API calls when disabled", function()
            _G.WMDevConfig.shouldLogAPICalls = function() return false end

            WMLogger:apiCall("AutoDrive", "StartDriving")

            assert.are.equal(0, #_G._loggerTestOutput)
        end)
    end)

    describe("event", function()
        it("should log events when enabled", function()
            _G.WMDevConfig.shouldLogEvents = function() return true end

            WMLogger:event("workflowStarted", { workflowId = "wf001" })

            assert.are.equal(1, #_G._loggerTestOutput)
            assert.is_truthy(_G._loggerTestOutput[1]:match("EVENT"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("workflowStarted"))
        end)

        it("should NOT log events when disabled", function()
            _G.WMDevConfig.shouldLogEvents = function() return false end

            WMLogger:event("workflowStarted", { workflowId = "wf001" })

            assert.are.equal(0, #_G._loggerTestOutput)
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

            assert.are.equal(1, #_G._loggerTestOutput)
            assert.is_truthy(_G._loggerTestOutput[1]:match("STATE"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("ready"))
            assert.is_truthy(_G._loggerTestOutput[1]:match("running"))
        end)

        it("should NOT log state changes when disabled", function()
            _G.WMDevConfig.shouldLogStateChanges = function() return false end

            WMLogger:stateChange("Workflow", "ready", "running")

            assert.are.equal(0, #_G._loggerTestOutput)
        end)

        it("should handle nil oldState", function()
            _G.WMDevConfig.shouldLogStateChanges = function() return true end

            assert.has_no.errors(function()
                WMLogger:stateChange("Workflow", nil, "running")
            end)

            assert.is_truthy(_G._loggerTestOutput[1]:match("-> running"))
        end)
    end)
end)
