--[[
    WorkflowManager Unit Tests
    Tests for core WorkflowManager CRUD operations and vehicle validation
]]

describe("WorkflowManager", function()
    local WorkflowManager

    -- Setup: Load EventHandler first (dependency), then WorkflowManager components
    setup(function()
        -- Load EventHandler (required by WorkflowManager)
        dofile("src/utils/EventHandler.lua")

        -- We need to set up minimal WorkflowManager for testing
        -- without loading the full module (which has GUI dependencies)
        _G.WorkflowManager = {
            version = "1.0.0.0",
            modName = "FS25_WorkflowManager",
            modDirectory = "./",

            -- Status constants
            STATUS_READY = "ready",
            STATUS_RUNNING = "running",
            STATUS_PAUSED = "paused",
            STATUS_COMPLETED = "completed",
            STATUS_ERROR = "error",

            -- Step type constants
            STEP_AUTODRIVE = "autodrive",
            STEP_COURSEPLAY = "courseplay",

            -- Internal state
            workflows = {},
            activeWorkflows = {},
            isInitialized = true,
            isShuttingDown = false
        }

        -- Copy methods from the actual module
        WorkflowManager = _G.WorkflowManager

        -- generateWorkflowId
        WorkflowManager.generateWorkflowId = function(self)
            return string.format("workflow_%d_%d", g_currentMission.time, math.random(1000, 9999))
        end

        -- createWorkflow
        WorkflowManager.createWorkflow = function(self, name)
            local workflow = {
                id = self:generateWorkflowId(),
                name = name or "New Workflow",
                steps = {},
                currentStep = 1,
                status = self.STATUS_READY,
                createdAt = getDate("%Y-%m-%d %H:%M:%S")
            }

            table.insert(self.workflows, workflow)
            WMLogger:debug("Created workflow: %s (ID: %s)", workflow.name, workflow.id)

            return workflow
        end

        -- getWorkflowById
        WorkflowManager.getWorkflowById = function(self, id)
            for _, workflow in ipairs(self.workflows) do
                if workflow.id == id then
                    return workflow
                end
            end
            return nil
        end

        -- deleteWorkflow
        WorkflowManager.deleteWorkflow = function(self, id)
            for i, workflow in ipairs(self.workflows) do
                if workflow.id == id then
                    if workflow.status == self.STATUS_RUNNING then
                        self:stopWorkflow(id)
                    end
                    table.remove(self.workflows, i)
                    WMLogger:debug("Deleted workflow: %s", id)
                    return true
                end
            end
            return false
        end

        -- addStep
        WorkflowManager.addStep = function(self, workflowId, stepType, target, action)
            local workflow = self:getWorkflowById(workflowId)
            if workflow == nil then
                WMLogger:error("Cannot add step: Workflow %s not found", workflowId)
                return false
            end

            local step = {
                type = stepType,
                target = target,
                action = action or "default"
            }

            table.insert(workflow.steps, step)
            WMLogger:debug("Added step to workflow %s: type=%s, target=%s", workflowId, stepType, target)

            return true
        end

        -- isVehicleValid
        WorkflowManager.isVehicleValid = function(self, vehicle)
            if vehicle == nil then
                return false
            end

            local hasAutoDrive = vehicle.ad ~= nil or vehicle.spec_autoDrive ~= nil
            local hasCP = vehicle.spec_cpAIWorker ~= nil or
                          vehicle.spec_cpAIFieldWorker ~= nil or
                          (vehicle.getIsCpActive ~= nil)

            return hasAutoDrive and hasCP
        end

        -- getAllWorkflows
        WorkflowManager.getAllWorkflows = function(self)
            return self.workflows
        end

        -- getWorkflows (alias)
        WorkflowManager.getWorkflows = function(self)
            return self.workflows
        end

        -- stopWorkflow (stub for deleteWorkflow)
        WorkflowManager.stopWorkflow = function(self, id)
            local workflow = self:getWorkflowById(id)
            if workflow then
                workflow.status = self.STATUS_READY
            end
            return true
        end

        -- saveWorkflows (no-op stub)
        WorkflowManager.saveWorkflows = function(self) end

        -- getLinkedWorkflow
        WorkflowManager.getLinkedWorkflow = function(self, workflowId)
            local workflow = self:getWorkflowById(workflowId)
            if workflow == nil or workflow.linkedWorkflowId == nil then
                return nil
            end
            return self:getWorkflowById(workflow.linkedWorkflowId)
        end

        -- unlinkWorkflow
        WorkflowManager.unlinkWorkflow = function(self, workflowId)
            local workflow = self:getWorkflowById(workflowId)
            if workflow == nil then return end
            if workflow.linkedWorkflowId then
                local partner = self:getWorkflowById(workflow.linkedWorkflowId)
                if partner then
                    for _, step in ipairs(partner.steps) do step.syncGroup = nil end
                    partner.linkedWorkflowId = nil
                    partner.linkRole = nil
                end
            end
            for _, step in ipairs(workflow.steps) do step.syncGroup = nil end
            workflow.linkedWorkflowId = nil
            workflow.linkRole = nil
        end

        -- autoAssignSyncGroups
        WorkflowManager.autoAssignSyncGroups = function(self, workflowId)
            local workflow = self:getWorkflowById(workflowId)
            if workflow == nil then return end
            if workflow.linkRole == nil then
                for _, step in ipairs(workflow.steps) do step.syncGroup = nil end
                return
            end
            if workflow.linkRole == "main" then
                local group = 1
                for _, step in ipairs(workflow.steps) do
                    step.syncGroup = group
                    if step.type == self.STEP_COURSEPLAY then group = group + 1 end
                end
            elseif workflow.linkRole == "support" then
                for i, step in ipairs(workflow.steps) do
                    step.syncGroup = i
                end
            end
        end

        -- linkWorkflows
        WorkflowManager.linkWorkflows = function(self, mainWorkflowId, supportWorkflowId)
            local mainWf   = self:getWorkflowById(mainWorkflowId)
            local supportWf = self:getWorkflowById(supportWorkflowId)
            if mainWf == nil or supportWf == nil then return false end
            if mainWf.id == supportWf.id then return false end
            if mainWf.linkedWorkflowId   then self:unlinkWorkflow(mainWf.id) end
            if supportWf.linkedWorkflowId then self:unlinkWorkflow(supportWf.id) end
            mainWf.linkedWorkflowId   = supportWf.id
            mainWf.linkRole           = "main"
            supportWf.linkedWorkflowId = mainWf.id
            supportWf.linkRole         = "support"
            self:autoAssignSyncGroups(mainWf.id)
            self:autoAssignSyncGroups(supportWf.id)
            return true
        end

        -- broadcastState (requires g_server; no-op stub replaced per test)
        WorkflowManager.broadcastState = function(self, vehicle)
            if _G.g_server == nil then return end
            if self.isShuttingDown then return end
            if vehicle == nil then return end
            if _G.g_server.broadcastEvent then
                _G.g_server.broadcastEvent(_G.g_server, nil, false, nil, vehicle)
            end
        end

        -- executeNetworkCommand (dispatches to WMExecutor stubs)
        WorkflowManager.executeNetworkCommand = function(self, commandType, vehicle, workflowId)
            if commandType == "start" then
                local wf = self:getWorkflowById(workflowId)
                if wf == nil then return end
                if _G.WMExecutor then _G.WMExecutor:startWorkflow(wf, vehicle) end
            elseif commandType == "stop" then
                if _G.WMExecutor then _G.WMExecutor:stopWorkflow(vehicle) end
            elseif commandType == "pause" then
                if _G.WMExecutor then _G.WMExecutor:pauseWorkflow(vehicle) end
            elseif commandType == "resume" then
                if _G.WMExecutor then _G.WMExecutor:resumeWorkflow(vehicle) end
            elseif commandType == "next_step" then
                if _G.WMExecutor then _G.WMExecutor:goToNextStep(vehicle) end
            elseif commandType == "prev_step" then
                if _G.WMExecutor then _G.WMExecutor:goToPreviousStep(vehicle) end
            end
            self:broadcastState(vehicle)
        end

        -- sendCommand (routes to server or client)
        WorkflowManager.sendCommand = function(self, vehicle, commandType, workflowId)
            if vehicle == nil then return end
            if _G.g_server ~= nil then
                self:executeNetworkCommand(commandType, vehicle, workflowId)
            elseif _G.g_client ~= nil then
                _G.g_client.sendEvent(_G.g_client, commandType, vehicle, workflowId)
            end
        end
    end)

    -- Reset state before each test
    before_each(function()
        WorkflowManager.workflows = {}
        WorkflowManager.activeWorkflows = {}
        WorkflowManager.isInitialized = true
        WorkflowManager.isShuttingDown = false

        -- Reset mock logger
        _G.WMLogger.calls = {
            debug = {},
            info = {},
            warning = {},
            error = {}
        }

        -- Reset random seed for deterministic IDs
        math.randomseed(12345)
    end)

    describe("createWorkflow", function()
        it("should create a workflow with the given name", function()
            local workflow = WorkflowManager:createWorkflow("Test Workflow")

            assert.is_not_nil(workflow)
            assert.are.equal("Test Workflow", workflow.name)
        end)

        it("should create a workflow with a default name when none provided", function()
            local workflow = WorkflowManager:createWorkflow()

            assert.is_not_nil(workflow)
            assert.are.equal("New Workflow", workflow.name)
        end)

        it("should generate a unique ID", function()
            local workflow = WorkflowManager:createWorkflow("Test")

            assert.is_string(workflow.id)
            assert.is_truthy(workflow.id:match("^workflow_%d+_%d+$"))
        end)

        it("should set initial status to ready", function()
            local workflow = WorkflowManager:createWorkflow("Test")

            assert.are.equal(WorkflowManager.STATUS_READY, workflow.status)
        end)

        it("should set currentStep to 1", function()
            local workflow = WorkflowManager:createWorkflow("Test")

            assert.are.equal(1, workflow.currentStep)
        end)

        it("should initialize with empty steps array", function()
            local workflow = WorkflowManager:createWorkflow("Test")

            assert.is_table(workflow.steps)
            assert.are.equal(0, #workflow.steps)
        end)

        it("should set createdAt timestamp", function()
            local workflow = WorkflowManager:createWorkflow("Test")

            assert.is_string(workflow.createdAt)
            assert.are.equal("2026-02-02 12:00:00", workflow.createdAt)
        end)

        it("should add workflow to workflows list", function()
            assert.are.equal(0, #WorkflowManager.workflows)

            WorkflowManager:createWorkflow("Test")

            assert.are.equal(1, #WorkflowManager.workflows)
        end)

        it("should create multiple workflows with different IDs", function()
            local wf1 = WorkflowManager:createWorkflow("Workflow 1")
            local wf2 = WorkflowManager:createWorkflow("Workflow 2")

            assert.are_not.equal(wf1.id, wf2.id)
            assert.are.equal(2, #WorkflowManager.workflows)
        end)
    end)

    describe("getWorkflowById", function()
        it("should return workflow when found", function()
            local created = WorkflowManager:createWorkflow("Test")
            local found = WorkflowManager:getWorkflowById(created.id)

            assert.are.equal(created, found)
        end)

        it("should return nil when workflow not found", function()
            local found = WorkflowManager:getWorkflowById("nonexistent_id")

            assert.is_nil(found)
        end)

        it("should find correct workflow among multiple", function()
            local wf1 = WorkflowManager:createWorkflow("First")
            local wf2 = WorkflowManager:createWorkflow("Second")
            local wf3 = WorkflowManager:createWorkflow("Third")

            local found = WorkflowManager:getWorkflowById(wf2.id)

            assert.are.equal(wf2, found)
            assert.are.equal("Second", found.name)
        end)
    end)

    describe("deleteWorkflow", function()
        it("should delete workflow and return true", function()
            local workflow = WorkflowManager:createWorkflow("Test")
            local result = WorkflowManager:deleteWorkflow(workflow.id)

            assert.is_true(result)
            assert.are.equal(0, #WorkflowManager.workflows)
        end)

        it("should return false for non-existent workflow", function()
            local result = WorkflowManager:deleteWorkflow("nonexistent_id")

            assert.is_false(result)
        end)

        it("should remove correct workflow among multiple", function()
            local wf1 = WorkflowManager:createWorkflow("First")
            local wf2 = WorkflowManager:createWorkflow("Second")
            local wf3 = WorkflowManager:createWorkflow("Third")

            WorkflowManager:deleteWorkflow(wf2.id)

            assert.are.equal(2, #WorkflowManager.workflows)
            assert.is_nil(WorkflowManager:getWorkflowById(wf2.id))
            assert.is_not_nil(WorkflowManager:getWorkflowById(wf1.id))
            assert.is_not_nil(WorkflowManager:getWorkflowById(wf3.id))
        end)

        it("should stop running workflow before deleting", function()
            local workflow = WorkflowManager:createWorkflow("Test")
            workflow.status = WorkflowManager.STATUS_RUNNING

            WorkflowManager:deleteWorkflow(workflow.id)

            -- Workflow should be deleted (not in list)
            assert.are.equal(0, #WorkflowManager.workflows)
        end)
    end)

    describe("addStep", function()
        it("should add AutoDrive step to workflow", function()
            local workflow = WorkflowManager:createWorkflow("Test")
            local result = WorkflowManager:addStep(workflow.id, "autodrive", "Farm", "drive")

            assert.is_true(result)
            assert.are.equal(1, #workflow.steps)
            assert.are.equal("autodrive", workflow.steps[1].type)
            assert.are.equal("Farm", workflow.steps[1].target)
            assert.are.equal("drive", workflow.steps[1].action)
        end)

        it("should add Courseplay step to workflow", function()
            local workflow = WorkflowManager:createWorkflow("Test")
            local result = WorkflowManager:addStep(workflow.id, "courseplay", "Field1_Harvest", "fieldwork")

            assert.is_true(result)
            assert.are.equal(1, #workflow.steps)
            assert.are.equal("courseplay", workflow.steps[1].type)
            assert.are.equal("Field1_Harvest", workflow.steps[1].target)
            assert.are.equal("fieldwork", workflow.steps[1].action)
        end)

        it("should use default action when not specified", function()
            local workflow = WorkflowManager:createWorkflow("Test")
            WorkflowManager:addStep(workflow.id, "autodrive", "Farm")

            assert.are.equal("default", workflow.steps[1].action)
        end)

        it("should return false for non-existent workflow", function()
            local result = WorkflowManager:addStep("nonexistent_id", "autodrive", "Farm", "drive")

            assert.is_false(result)
        end)

        it("should add multiple steps in order", function()
            local workflow = WorkflowManager:createWorkflow("Test")

            WorkflowManager:addStep(workflow.id, "autodrive", "Farm", "drive")
            WorkflowManager:addStep(workflow.id, "courseplay", "Field1", "fieldwork")
            WorkflowManager:addStep(workflow.id, "autodrive", "Silo", "unload")

            assert.are.equal(3, #workflow.steps)
            assert.are.equal("Farm", workflow.steps[1].target)
            assert.are.equal("Field1", workflow.steps[2].target)
            assert.are.equal("Silo", workflow.steps[3].target)
        end)

        it("should log error for non-existent workflow", function()
            WorkflowManager:addStep("bad_id", "autodrive", "Farm", "drive")

            assert.are.equal(1, #_G.WMLogger.calls.error)
            assert.is_truthy(_G.WMLogger.calls.error[1]:match("not found"))
        end)
    end)

    describe("isVehicleValid", function()
        it("should return true for vehicle with AD and CP support", function()
            local vehicle = VehicleMock.createValid("TestTractor")
            local result = WorkflowManager:isVehicleValid(vehicle)

            assert.is_true(result)
        end)

        it("should return false for vehicle with only AD support", function()
            local vehicle = VehicleMock.createADOnly("ADOnlyTractor")
            local result = WorkflowManager:isVehicleValid(vehicle)

            assert.is_false(result)
        end)

        it("should return false for vehicle with only CP support", function()
            local vehicle = VehicleMock.createCPOnly("CPOnlyTractor")
            local result = WorkflowManager:isVehicleValid(vehicle)

            assert.is_false(result)
        end)

        it("should return false for basic vehicle without automation", function()
            local vehicle = VehicleMock.createBasic("BasicTractor")
            local result = WorkflowManager:isVehicleValid(vehicle)

            assert.is_false(result)
        end)

        it("should return false for nil vehicle", function()
            local result = WorkflowManager:isVehicleValid(nil)

            assert.is_false(result)
        end)

        it("should detect CP via getIsCpActive method", function()
            -- Vehicle with AD and getIsCpActive but no spec_cpAIWorker
            local vehicle = {
                ad = { stateModule = { isActive = function() return false end } },
                getIsCpActive = function() return false end,
                getName = function() return "CPViaMethods" end
            }

            local result = WorkflowManager:isVehicleValid(vehicle)

            assert.is_true(result)
        end)

        it("should detect AD via spec_autoDrive", function()
            -- Vehicle with spec_autoDrive instead of ad
            local vehicle = {
                spec_autoDrive = {},
                spec_cpAIWorker = {},
                getName = function() return "ADViaSpec" end
            }

            local result = WorkflowManager:isVehicleValid(vehicle)

            assert.is_true(result)
        end)
    end)

    describe("getAllWorkflows / getWorkflows", function()
        it("should return empty array when no workflows exist", function()
            local workflows = WorkflowManager:getAllWorkflows()

            assert.is_table(workflows)
            assert.are.equal(0, #workflows)
        end)

        it("should return all created workflows", function()
            WorkflowManager:createWorkflow("First")
            WorkflowManager:createWorkflow("Second")
            WorkflowManager:createWorkflow("Third")

            local workflows = WorkflowManager:getAllWorkflows()

            assert.are.equal(3, #workflows)
        end)

        it("getWorkflows should be alias for getAllWorkflows", function()
            WorkflowManager:createWorkflow("Test")

            local all = WorkflowManager:getAllWorkflows()
            local alias = WorkflowManager:getWorkflows()

            assert.are.equal(all, alias)
        end)
    end)

    -- =========================================================================
    -- linkWorkflows
    -- =========================================================================
    describe("linkWorkflows", function()
        it("links two workflows as main/support", function()
            local main    = WorkflowManager:createWorkflow("Main")
            local support = WorkflowManager:createWorkflow("Support")
            local ok = WorkflowManager:linkWorkflows(main.id, support.id)
            assert.is_true(ok)
            assert.are.equal("main",    main.linkRole)
            assert.are.equal("support", support.linkRole)
            assert.are.equal(support.id, main.linkedWorkflowId)
            assert.are.equal(main.id,   support.linkedWorkflowId)
        end)

        it("returns false when either workflow does not exist", function()
            local main = WorkflowManager:createWorkflow("Main")
            assert.is_false(WorkflowManager:linkWorkflows(main.id, "nonexistent"))
            assert.is_false(WorkflowManager:linkWorkflows("nonexistent", main.id))
        end)

        it("returns false when linking a workflow to itself", function()
            local wf = WorkflowManager:createWorkflow("Solo")
            assert.is_false(WorkflowManager:linkWorkflows(wf.id, wf.id))
        end)

        it("unlinks previous partner before creating new link", function()
            local a = WorkflowManager:createWorkflow("A")
            local b = WorkflowManager:createWorkflow("B")
            local c = WorkflowManager:createWorkflow("C")
            WorkflowManager:linkWorkflows(a.id, b.id)
            WorkflowManager:linkWorkflows(a.id, c.id)  -- re-link a to c
            assert.are.equal(c.id, a.linkedWorkflowId)
            assert.is_nil(b.linkedWorkflowId)  -- b was unlinked
        end)

        it("auto-assigns sync groups on both workflows after linking", function()
            local main    = WorkflowManager:createWorkflow("Main")
            local support = WorkflowManager:createWorkflow("Support")
            table.insert(main.steps,    { type = "autodrive",  target = "A", action = "drive"     })
            table.insert(main.steps,    { type = "courseplay", target = "B", action = "fieldwork" })
            table.insert(support.steps, { type = "autodrive",  target = "C", action = "unload"    })
            WorkflowManager:linkWorkflows(main.id, support.id)
            -- main: both steps in group 1 (CP step ends group 1)
            assert.are.equal(1, main.steps[1].syncGroup)
            assert.are.equal(1, main.steps[2].syncGroup)
            -- support: sequential groups
            assert.are.equal(1, support.steps[1].syncGroup)
        end)
    end)

    -- =========================================================================
    -- unlinkWorkflow
    -- =========================================================================
    describe("unlinkWorkflow", function()
        it("clears linkRole and linkedWorkflowId on both workflows", function()
            local main    = WorkflowManager:createWorkflow("Main")
            local support = WorkflowManager:createWorkflow("Support")
            WorkflowManager:linkWorkflows(main.id, support.id)
            WorkflowManager:unlinkWorkflow(main.id)
            assert.is_nil(main.linkRole)
            assert.is_nil(main.linkedWorkflowId)
            assert.is_nil(support.linkRole)
            assert.is_nil(support.linkedWorkflowId)
        end)

        it("clears sync groups from both workflows", function()
            local main    = WorkflowManager:createWorkflow("Main")
            local support = WorkflowManager:createWorkflow("Support")
            table.insert(main.steps,    { type = "courseplay", target = "F", action = "fieldwork", syncGroup = 1 })
            table.insert(support.steps, { type = "autodrive",  target = "S", action = "unload",    syncGroup = 1 })
            WorkflowManager:linkWorkflows(main.id, support.id)
            WorkflowManager:unlinkWorkflow(main.id)
            assert.is_nil(main.steps[1].syncGroup)
            assert.is_nil(support.steps[1].syncGroup)
        end)

        it("is safe to call on an already-unlinked workflow", function()
            local wf = WorkflowManager:createWorkflow("Solo")
            assert.has_no.errors(function()
                WorkflowManager:unlinkWorkflow(wf.id)
            end)
        end)

        it("is safe to call on a non-existent id", function()
            assert.has_no.errors(function()
                WorkflowManager:unlinkWorkflow("no_such_id")
            end)
        end)
    end)

    -- =========================================================================
    -- getLinkedWorkflow
    -- =========================================================================
    describe("getLinkedWorkflow", function()
        it("returns the linked partner workflow", function()
            local main    = WorkflowManager:createWorkflow("Main")
            local support = WorkflowManager:createWorkflow("Support")
            WorkflowManager:linkWorkflows(main.id, support.id)
            assert.are.equal(support, WorkflowManager:getLinkedWorkflow(main.id))
            assert.are.equal(main,    WorkflowManager:getLinkedWorkflow(support.id))
        end)

        it("returns nil for an unlinked workflow", function()
            local wf = WorkflowManager:createWorkflow("Solo")
            assert.is_nil(WorkflowManager:getLinkedWorkflow(wf.id))
        end)

        it("returns nil for unknown workflow id", function()
            assert.is_nil(WorkflowManager:getLinkedWorkflow("nonexistent"))
        end)
    end)

    -- =========================================================================
    -- autoAssignSyncGroups
    -- =========================================================================
    describe("autoAssignSyncGroups", function()
        it("main role: all steps before and including a CP step share a group", function()
            local wf = WorkflowManager:createWorkflow("Main")
            wf.linkRole = "main"
            table.insert(wf.steps, { type = "autodrive",  target = "A", action = "drive"     })
            table.insert(wf.steps, { type = "courseplay", target = "B", action = "fieldwork" })
            table.insert(wf.steps, { type = "autodrive",  target = "C", action = "drive"     })
            table.insert(wf.steps, { type = "courseplay", target = "D", action = "fieldwork" })
            WorkflowManager:autoAssignSyncGroups(wf.id)
            assert.are.equal(1, wf.steps[1].syncGroup)  -- AD before first CP
            assert.are.equal(1, wf.steps[2].syncGroup)  -- first CP
            assert.are.equal(2, wf.steps[3].syncGroup)  -- AD before second CP
            assert.are.equal(2, wf.steps[4].syncGroup)  -- second CP
        end)

        it("support role: each step gets a sequential group number", function()
            local wf = WorkflowManager:createWorkflow("Support")
            wf.linkRole = "support"
            table.insert(wf.steps, { type = "autodrive", target = "X", action = "unload" })
            table.insert(wf.steps, { type = "autodrive", target = "Y", action = "unload" })
            table.insert(wf.steps, { type = "autodrive", target = "Z", action = "unload" })
            WorkflowManager:autoAssignSyncGroups(wf.id)
            assert.are.equal(1, wf.steps[1].syncGroup)
            assert.are.equal(2, wf.steps[2].syncGroup)
            assert.are.equal(3, wf.steps[3].syncGroup)
        end)

        it("nil linkRole: clears all sync groups", function()
            local wf = WorkflowManager:createWorkflow("Solo")
            wf.linkRole = nil
            table.insert(wf.steps, { type = "autodrive", target = "A", action = "drive", syncGroup = 1 })
            WorkflowManager:autoAssignSyncGroups(wf.id)
            assert.is_nil(wf.steps[1].syncGroup)
        end)

        it("is a no-op for an unknown workflow id", function()
            assert.has_no.errors(function()
                WorkflowManager:autoAssignSyncGroups("nonexistent")
            end)
        end)
    end)

    -- =========================================================================
    -- sendCommand / executeNetworkCommand / broadcastState
    -- =========================================================================
    describe("sendCommand", function()
        local execCalls

        before_each(function()
            execCalls = {}
            _G.WMExecutor = {
                startWorkflow    = function(_, wf, v) table.insert(execCalls, {cmd="start",   wf=wf, v=v}) end,
                stopWorkflow     = function(_, v)     table.insert(execCalls, {cmd="stop",    v=v})       end,
                pauseWorkflow    = function(_, v)     table.insert(execCalls, {cmd="pause",   v=v})       end,
                resumeWorkflow   = function(_, v)     table.insert(execCalls, {cmd="resume",  v=v})       end,
                goToNextStep     = function(_, v)     table.insert(execCalls, {cmd="next",    v=v})       end,
                goToPreviousStep = function(_, v)     table.insert(execCalls, {cmd="prev",    v=v})       end,
            }
            _G.g_server = { broadcastEvent = function() end }
            _G.g_client = nil
        end)

        it("on server: executes command directly without sending event", function()
            local v  = VehicleMock.createValid("T")
            local wf = WorkflowManager:createWorkflow("W")
            WorkflowManager:sendCommand(v, "stop")
            assert.are.equal(1, #execCalls)
            assert.are.equal("stop", execCalls[1].cmd)
        end)

        it("on client: sends event instead of executing directly", function()
            local sentEvents = {}
            _G.g_server = nil
            _G.g_client = {
                sendEvent = function(_, cmd, v, wfId)
                    table.insert(sentEvents, {cmd=cmd, v=v, wfId=wfId})
                end
            }
            local v = VehicleMock.createValid("T")
            WorkflowManager:sendCommand(v, "pause")
            assert.are.equal(0, #execCalls)
            assert.are.equal(1, #sentEvents)
            assert.are.equal("pause", sentEvents[1].cmd)
        end)

        it("does nothing for nil vehicle", function()
            WorkflowManager:sendCommand(nil, "stop")
            assert.are.equal(0, #execCalls)
        end)
    end)

    describe("executeNetworkCommand", function()
        local execCalls

        before_each(function()
            execCalls = {}
            _G.WMExecutor = {
                startWorkflow    = function(_, wf, v) table.insert(execCalls, {cmd="start",  wf=wf, v=v}) end,
                stopWorkflow     = function(_, v)     table.insert(execCalls, {cmd="stop",   v=v})       end,
                pauseWorkflow    = function(_, v)     table.insert(execCalls, {cmd="pause",  v=v})       end,
                resumeWorkflow   = function(_, v)     table.insert(execCalls, {cmd="resume", v=v})       end,
                goToNextStep     = function(_, v)     table.insert(execCalls, {cmd="next",   v=v})       end,
                goToPreviousStep = function(_, v)     table.insert(execCalls, {cmd="prev",   v=v})       end,
            }
            _G.g_server = { broadcastEvent = function() end }
        end)

        it("dispatches 'stop' to WMExecutor:stopWorkflow", function()
            local v = VehicleMock.createValid("T")
            WorkflowManager:executeNetworkCommand("stop", v)
            assert.are.equal("stop", execCalls[1].cmd)
        end)

        it("dispatches 'pause' to WMExecutor:pauseWorkflow", function()
            local v = VehicleMock.createValid("T")
            WorkflowManager:executeNetworkCommand("pause", v)
            assert.are.equal("pause", execCalls[1].cmd)
        end)

        it("dispatches 'resume' to WMExecutor:resumeWorkflow", function()
            local v = VehicleMock.createValid("T")
            WorkflowManager:executeNetworkCommand("resume", v)
            assert.are.equal("resume", execCalls[1].cmd)
        end)

        it("dispatches 'next_step' to WMExecutor:goToNextStep", function()
            local v = VehicleMock.createValid("T")
            WorkflowManager:executeNetworkCommand("next_step", v)
            assert.are.equal("next", execCalls[1].cmd)
        end)

        it("dispatches 'prev_step' to WMExecutor:goToPreviousStep", function()
            local v = VehicleMock.createValid("T")
            WorkflowManager:executeNetworkCommand("prev_step", v)
            assert.are.equal("prev", execCalls[1].cmd)
        end)

        it("dispatches 'start' with workflow resolved by id", function()
            local wf = WorkflowManager:createWorkflow("Run")
            local v  = VehicleMock.createValid("T")
            WorkflowManager:executeNetworkCommand("start", v, wf.id)
            assert.are.equal("start", execCalls[1].cmd)
            assert.are.equal(wf, execCalls[1].wf)
        end)

        it("does not call executor for unknown workflow on 'start'", function()
            local v = VehicleMock.createValid("T")
            WorkflowManager:executeNetworkCommand("start", v, "no_such_wf")
            assert.are.equal(0, #execCalls)
        end)
    end)

    describe("broadcastState", function()
        before_each(function()
            _G.g_server = nil
        end)

        it("does nothing when g_server is nil (singleplayer client path)", function()
            local broadcastCalled = false
            -- g_server is nil, so no broadcast should happen
            assert.has_no.errors(function()
                WorkflowManager:broadcastState(VehicleMock.createValid("T"))
            end)
            assert.is_false(broadcastCalled)
        end)

        it("does nothing when vehicle is nil", function()
            _G.g_server = { broadcastEvent = function() error("should not be called") end }
            assert.has_no.errors(function()
                WorkflowManager:broadcastState(nil)
            end)
        end)

        it("does nothing when isShuttingDown is true", function()
            _G.g_server = { broadcastEvent = function() error("should not be called") end }
            WorkflowManager.isShuttingDown = true
            assert.has_no.errors(function()
                WorkflowManager:broadcastState(VehicleMock.createValid("T"))
            end)
            WorkflowManager.isShuttingDown = false
        end)

        it("calls g_server:broadcastEvent when server is set and vehicle valid", function()
            local called = false
            _G.g_server = { broadcastEvent = function() called = true end }
            WorkflowManager:broadcastState(VehicleMock.createValid("T"))
            assert.is_true(called)
        end)
    end)

    describe("status constants", function()
        it("should have all status constants defined", function()
            assert.are.equal("ready", WorkflowManager.STATUS_READY)
            assert.are.equal("running", WorkflowManager.STATUS_RUNNING)
            assert.are.equal("paused", WorkflowManager.STATUS_PAUSED)
            assert.are.equal("completed", WorkflowManager.STATUS_COMPLETED)
            assert.are.equal("error", WorkflowManager.STATUS_ERROR)
        end)

        it("should have step type constants defined", function()
            assert.are.equal("autodrive", WorkflowManager.STEP_AUTODRIVE)
            assert.are.equal("courseplay", WorkflowManager.STEP_COURSEPLAY)
        end)
    end)
end)
