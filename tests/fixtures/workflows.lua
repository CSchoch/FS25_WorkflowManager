--[[
    Test Fixtures - Sample Workflow Data
    Provides pre-configured workflow objects for testing
]]

TestFixtures = {}

---Create a simple single-step workflow
---@return table workflow
function TestFixtures.createSimpleWorkflow()
    return {
        id = "fixture_simple_001",
        name = "Simple Workflow",
        steps = {
            { type = "autodrive", target = "Farm", action = "drive" }
        },
        currentStep = 1,
        status = "ready",
        createdAt = "2026-02-02 12:00:00"
    }
end

---Create a multi-step harvest workflow
---@return table workflow
function TestFixtures.createHarvestWorkflow()
    return {
        id = "fixture_harvest_001",
        name = "Harvest Wheat Fields 1-2",
        steps = {
            { type = "autodrive", target = "Field1_Entry", action = "drive" },
            { type = "courseplay", target = "Field1_Harvest", action = "fieldwork" },
            { type = "autodrive", target = "Farm/Silo", action = "pickup_deliver", unloadTarget = "Sell/BGA", fillTypes = {"WHEAT"} },
            { type = "autodrive", target = "Field2_Entry", action = "drive" },
            { type = "courseplay", target = "Field2_Harvest", action = "fieldwork" },
            { type = "autodrive", target = "Farm/Silo", action = "pickup_deliver", unloadTarget = "Sell/BGA", fillTypes = {"WHEAT"} }
        },
        currentStep = 1,
        status = "ready",
        createdAt = "2026-02-02 12:00:00"
    }
end

---Create a bale collection workflow
---@return table workflow
function TestFixtures.createBaleWorkflow()
    return {
        id = "fixture_bales_001",
        name = "Collect Bales Field 3",
        steps = {
            { type = "autodrive", target = "Field3_Entry", action = "drive" },
            { type = "courseplay", target = "Field3_Bales", action = "bale_collect" },
            { type = "autodrive", target = "Farm/BaleStorage", action = "deliver" }
        },
        currentStep = 1,
        status = "ready",
        createdAt = "2026-02-02 12:00:00"
    }
end

---Create a workflow with no steps (for edge case testing)
---@return table workflow
function TestFixtures.createEmptyWorkflow()
    return {
        id = "fixture_empty_001",
        name = "Empty Workflow",
        steps = {},
        currentStep = 1,
        status = "ready",
        createdAt = "2026-02-02 12:00:00"
    }
end

---Create a running workflow (mid-execution)
---@return table workflow
function TestFixtures.createRunningWorkflow()
    return {
        id = "fixture_running_001",
        name = "Running Workflow",
        steps = {
            { type = "autodrive", target = "Farm", action = "drive" },
            { type = "courseplay", target = "Field1", action = "fieldwork" },
            { type = "autodrive", target = "Silo", action = "unload" }
        },
        currentStep = 2,  -- Currently on step 2
        status = "running",
        createdAt = "2026-02-02 11:00:00"
    }
end

---Create a paused workflow
---@return table workflow
function TestFixtures.createPausedWorkflow()
    return {
        id = "fixture_paused_001",
        name = "Paused Workflow",
        steps = {
            { type = "autodrive", target = "Farm", action = "drive" },
            { type = "courseplay", target = "Field1", action = "fieldwork" }
        },
        currentStep = 1,
        status = "paused",
        createdAt = "2026-02-02 10:00:00"
    }
end

---Create a completed workflow
---@return table workflow
function TestFixtures.createCompletedWorkflow()
    return {
        id = "fixture_completed_001",
        name = "Completed Workflow",
        steps = {
            { type = "autodrive", target = "Farm", action = "drive" },
            { type = "courseplay", target = "Field1", action = "fieldwork" }
        },
        currentStep = 1,  -- Reset after completion
        status = "completed",
        createdAt = "2026-02-02 09:00:00"
    }
end

---Create an AutoDrive step
---@param target string Target destination
---@param action string|nil Action (default: "drive")
---@param unloadTarget string|nil Second destination for pickup_deliver
---@param fillTypes table|nil Fill type filter (array of fill type name strings)
---@return table step
function TestFixtures.createADStep(target, action, unloadTarget, fillTypes)
    return {
        type = "autodrive",
        target = target,
        action = action or "drive",
        unloadTarget = unloadTarget,
        fillTypes = fillTypes
    }
end

---Create a Courseplay step
---@param target string Course name
---@param action string|nil Action (default: "fieldwork")
---@return table step
function TestFixtures.createCPStep(target, action)
    return {
        type = "courseplay",
        target = target,
        action = action or "fieldwork"
    }
end

---Create a list of workflows for batch testing
---@param count number Number of workflows to create
---@return table workflows
function TestFixtures.createWorkflowBatch(count)
    local workflows = {}
    for i = 1, count do
        table.insert(workflows, {
            id = string.format("fixture_batch_%03d", i),
            name = string.format("Batch Workflow %d", i),
            steps = {
                { type = "autodrive", target = "Target" .. i, action = "drive" }
            },
            currentStep = 1,
            status = "ready",
            createdAt = "2026-02-02 12:00:00"
        })
    end
    return workflows
end

print("[Fixtures] Test fixtures loaded")
