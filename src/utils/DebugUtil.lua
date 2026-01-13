--[[
    WorkflowManager - Debug Utilities
    Helper functions for development and debugging

    Author: WorkflowManager Team
]]

---@class WMDebugUtil
WMDebugUtil = {}

WMDebugUtil.frameCount = 0
WMDebugUtil.lastFPSUpdate = 0
WMDebugUtil.currentFPS = 0
WMDebugUtil.frameTimeAccum = 0
WMDebugUtil.frameCountForFPS = 0

---Initialize debug utilities
function WMDebugUtil:init()
    self.frameCount = 0
    self.lastFPSUpdate = 0
    self.currentFPS = 0
end

---Update debug utilities (call every frame)
---@param dt number Delta time in milliseconds
function WMDebugUtil:update(dt)
    if not WMDevConfig:isDevMode() then
        return
    end

    self.frameCount = self.frameCount + 1
    self.frameTimeAccum = self.frameTimeAccum + dt
    self.frameCountForFPS = self.frameCountForFPS + 1

    -- Update FPS every second
    if self.frameTimeAccum >= 1000 then
        self.currentFPS = self.frameCountForFPS
        self.frameCountForFPS = 0
        self.frameTimeAccum = 0
    end
end

---Draw debug overlay
function WMDebugUtil:draw()
    if not WMDevConfig:isDevMode() or not WMDevConfig.SHOW_DEBUG_OVERLAY then
        return
    end

    local x = WMDevConfig.DEBUG_OVERLAY_X
    local y = WMDevConfig.DEBUG_OVERLAY_Y
    local textSize = WMDevConfig.DEBUG_TEXT_SIZE
    local lineHeight = textSize * 1.5

    setTextColor(1, 1, 0, 1)
    setTextBold(true)

    -- Header
    renderText(x, y, textSize, "[WM Debug]")
    y = y - lineHeight

    setTextBold(false)
    setTextColor(1, 1, 1, 1)

    -- FPS
    if WMDevConfig.SHOW_FPS then
        renderText(x, y, textSize, string.format("FPS: %d", self.currentFPS))
        y = y - lineHeight
    end

    -- Workflow status
    if WorkflowManager and WorkflowManager.workflows then
        local totalWorkflows = #WorkflowManager.workflows
        local activeCount = WMExecutor and WMExecutor:getActiveWorkflowCount() or 0

        renderText(x, y, textSize, string.format("Workflows: %d (Active: %d)", totalWorkflows, activeCount))
        y = y - lineHeight
    end

    -- AutoDrive status
    local adStatus = ADIntegration and ADIntegration.isAvailable and "Available" or "Not Available"
    setTextColor(ADIntegration and ADIntegration.isAvailable and 0 or 1,
                 ADIntegration and ADIntegration.isAvailable and 1 or 0, 0, 1)
    renderText(x, y, textSize, "AutoDrive: " .. adStatus)
    y = y - lineHeight

    -- Courseplay status
    local cpStatus = CPIntegration and CPIntegration.isAvailable and "Available" or "Not Available"
    setTextColor(CPIntegration and CPIntegration.isAvailable and 0 or 1,
                 CPIntegration and CPIntegration.isAvailable and 1 or 0, 0, 1)
    renderText(x, y, textSize, "Courseplay: " .. cpStatus)
    y = y - lineHeight

    -- GUI state
    setTextColor(1, 1, 1, 1)
    local guiState = WorkflowManager and WorkflowManager.guiVisible and "Visible" or "Hidden"
    renderText(x, y, textSize, "GUI: " .. guiState)
end

---Dump a table to the log (for debugging)
---@param tbl table Table to dump
---@param name string|nil Name for the dump
---@param maxDepth number|nil Maximum recursion depth (default 3)
function WMDebugUtil:dumpTable(tbl, name, maxDepth)
    if not WMDevConfig:isDevMode() then
        return
    end

    name = name or "table"
    maxDepth = maxDepth or 3

    print(string.format("[WM Debug] Dumping %s:", name))
    self:dumpTableRecursive(tbl, "", maxDepth, 0)
end

---Internal recursive table dump
function WMDebugUtil:dumpTableRecursive(tbl, indent, maxDepth, currentDepth)
    if currentDepth >= maxDepth then
        print(indent .. "  ... (max depth reached)")
        return
    end

    if type(tbl) ~= "table" then
        print(indent .. tostring(tbl))
        return
    end

    for key, value in pairs(tbl) do
        local keyStr = tostring(key)
        local valueType = type(value)

        if valueType == "table" then
            print(indent .. "  " .. keyStr .. " = {")
            self:dumpTableRecursive(value, indent .. "  ", maxDepth, currentDepth + 1)
            print(indent .. "  }")
        elseif valueType == "function" then
            print(indent .. "  " .. keyStr .. " = [function]")
        elseif valueType == "string" then
            print(indent .. "  " .. keyStr .. " = \"" .. value .. "\"")
        else
            print(indent .. "  " .. keyStr .. " = " .. tostring(value))
        end
    end
end

---Log a workflow state for debugging
---@param workflow table Workflow to log
function WMDebugUtil:logWorkflowState(workflow)
    if not WMDevConfig:shouldLogStateChanges() then
        return
    end

    if workflow == nil then
        print("[WM Debug] Workflow is nil")
        return
    end

    print(string.format("[WM Debug] Workflow State: %s", workflow.name or "unnamed"))
    print(string.format("  ID: %s", workflow.id or "none"))
    print(string.format("  Status: %s", workflow.status or "unknown"))
    print(string.format("  Current Step: %d / %d", workflow.currentStep or 0, #(workflow.steps or {})))

    if workflow.vehicle then
        local vehicleName = workflow.vehicle.getName and workflow.vehicle:getName() or "unknown"
        print(string.format("  Vehicle: %s", vehicleName))
    else
        print("  Vehicle: none assigned")
    end
end

---Create a test workflow for development
---@return table workflow Test workflow
function WMDebugUtil:createTestWorkflow()
    if not WMDevConfig:isDevMode() then
        return nil
    end

    print("[WM Debug] Creating test workflow...")

    local workflow = {
        id = "test_workflow_" .. tostring(g_currentMission and g_currentMission.time or 0),
        name = "Test Workflow (Debug)",
        vehicle = nil,
        steps = {
            {
                type = WorkflowManager.STEP_AUTODRIVE,
                target = "TestRoute1",
                action = "drive"
            },
            {
                type = WorkflowManager.STEP_COURSEPLAY,
                target = "TestCourse1",
                action = "fieldwork"
            },
            {
                type = WorkflowManager.STEP_AUTODRIVE,
                target = "TestRoute2",
                action = "drive"
            }
        },
        currentStep = 1,
        status = WorkflowManager.STATUS_READY
    }

    print("[WM Debug] Test workflow created with " .. #workflow.steps .. " steps")
    return workflow
end

---Get memory usage info (if available)
---@return string memoryInfo
function WMDebugUtil:getMemoryInfo()
    if collectgarbage then
        local memKB = collectgarbage("count")
        return string.format("%.2f MB", memKB / 1024)
    end
    return "N/A"
end

---Benchmark a function
---@param func function Function to benchmark
---@param iterations number Number of iterations
---@param name string|nil Name for logging
function WMDebugUtil:benchmark(func, iterations, name)
    if not WMDevConfig:isDevMode() then
        return
    end

    name = name or "function"
    iterations = iterations or 1000

    local startTime = getTimeSec and getTimeSec() or os.clock()

    for i = 1, iterations do
        func()
    end

    local endTime = getTimeSec and getTimeSec() or os.clock()
    local totalTime = endTime - startTime
    local avgTime = totalTime / iterations

    print(string.format("[WM Debug] Benchmark '%s': %d iterations in %.4f sec (avg: %.6f sec)",
        name, iterations, totalTime, avgTime))
end
