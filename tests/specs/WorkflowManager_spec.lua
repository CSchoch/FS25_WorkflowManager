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
            STEP_PARK = "park",
            STEP_REFUEL = "refuel",
            STEP_REPAIR = "repair",

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
                createdAt = getDate("%Y-%m-%d %H:%M:%S"),
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
                type    = stepType,
                target  = target,
                action  = action or "default",
                support = {},
            }

            table.insert(workflow.steps, step)
            WMLogger:debug("Added step to workflow %s: type=%s, target=%s", workflowId, stepType, target)

            return true
        end

        -- addSupportStep
        WorkflowManager.addSupportStep = function(self, workflowId, stepIndex, supportStep)
            local workflow = self:getWorkflowById(workflowId)
            if workflow == nil then return false end
            local step = workflow.steps[stepIndex]
            if step == nil then return false end
            if step.support == nil then step.support = {} end
            table.insert(step.support, supportStep)
            return true
        end

        -- removeSupportStep
        WorkflowManager.removeSupportStep = function(self, workflowId, stepIndex, supportIndex)
            local workflow = self:getWorkflowById(workflowId)
            if workflow == nil then return false end
            local step = workflow.steps[stepIndex]
            if step == nil or step.support == nil then return false end
            if supportIndex < 1 or supportIndex > #step.support then return false end
            table.remove(step.support, supportIndex)
            return true
        end

        -- hasSupportSteps
        WorkflowManager.hasSupportSteps = function(self, workflowId)
            local workflow = self:getWorkflowById(workflowId)
            if workflow == nil then return false end
            for _, step in ipairs(workflow.steps) do
                if step.support and #step.support > 0 then return true end
            end
            return false
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
        WorkflowManager.executeNetworkCommand = function(self, commandType, vehicle, workflowId, isMain)
            if commandType == "start" then
                local wf = self:getWorkflowById(workflowId)
                if wf == nil then return end
                if _G.WMExecutor then _G.WMExecutor:startWorkflow(wf, vehicle, (isMain ~= false)) end
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
        WorkflowManager.sendCommand = function(self, vehicle, commandType, workflowId, isMain)
            if vehicle == nil then return end
            if _G.g_server ~= nil then
                self:executeNetworkCommand(commandType, vehicle, workflowId, isMain)
            elseif _G.g_client ~= nil then
                _G.g_client.sendEvent(_G.g_client, commandType, vehicle, workflowId, isMain)
            end
        end

        -- hasSupportSteps / addSupportStep / removeSupportStep already defined above
        -- (also needed by startWorkflow stub, so define before it)
        WorkflowManager.modeSelectDialog = nil  -- not loaded in tests

        -- showModeSelectDialog (mirrors src/WorkflowManager.lua)
        WorkflowManager.showModeSelectDialog = function(self, workflowId, vehicle, callback)
            if self.modeSelectDialog == nil then
                if callback then callback(true) end
                return
            end
            self.modeSelectDialog:setWorkflow(workflowId, vehicle, callback)
            g_gui:showDialog("WMModeSelectDialog")
        end

        -- showLeaderSelectDialog (mirrors src/WorkflowManager.lua) — must NOT open
        -- the dialog when there are no candidate vehicles (bug-038).
        WorkflowManager.showLeaderSelectDialog = function(self, currentVehicle, callback)
            if self.leaderSelectDialog == nil then
                callback(nil)
                return
            end
            self.leaderSelectDialog:setData(currentVehicle, callback)
            if self.leaderSelectDialog:buildVehicleList() == 0 then
                callback(nil)
                return
            end
            g_gui:showDialog("WMLeaderVehicleSelectDialog")
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
    -- addSupportStep / removeSupportStep / hasSupportSteps
    -- =========================================================================
    describe("addSupportStep", function()
        it("adds a support sub-step to the specified main step", function()
            local wf = WorkflowManager:createWorkflow("Test")
            WorkflowManager:addStep(wf.id, "courseplay", "Field1", "fieldwork")
            local subStep = { type = "autodrive", target = "Field1", action = "unload" }
            local ok = WorkflowManager:addSupportStep(wf.id, 1, subStep)
            assert.is_true(ok)
            assert.are.equal(1, #wf.steps[1].support)
            assert.are.equal("unload", wf.steps[1].support[1].action)
        end)

        it("returns false for unknown workflow", function()
            assert.is_false(WorkflowManager:addSupportStep("bad_id", 1, {}))
        end)

        it("returns false when step index is out of range", function()
            local wf = WorkflowManager:createWorkflow("Test")
            assert.is_false(WorkflowManager:addSupportStep(wf.id, 99, {}))
        end)
    end)

    describe("removeSupportStep", function()
        it("removes the support sub-step at the given index", function()
            local wf = WorkflowManager:createWorkflow("Test")
            WorkflowManager:addStep(wf.id, "courseplay", "F1", "fieldwork")
            WorkflowManager:addSupportStep(wf.id, 1, { type="autodrive", target="A", action="unload" })
            WorkflowManager:addSupportStep(wf.id, 1, { type="autodrive", target="B", action="deliver" })
            WorkflowManager:removeSupportStep(wf.id, 1, 1)
            assert.are.equal(1, #wf.steps[1].support)
            assert.are.equal("B", wf.steps[1].support[1].target)
        end)

        it("returns false for unknown workflow", function()
            assert.is_false(WorkflowManager:removeSupportStep("bad_id", 1, 1))
        end)

        it("returns false for out-of-range support index", function()
            local wf = WorkflowManager:createWorkflow("Test")
            WorkflowManager:addStep(wf.id, "courseplay", "F1", "fieldwork")
            assert.is_false(WorkflowManager:removeSupportStep(wf.id, 1, 1))
        end)
    end)

    describe("hasSupportSteps", function()
        it("returns false when no steps have support sub-steps", function()
            local wf = WorkflowManager:createWorkflow("Test")
            WorkflowManager:addStep(wf.id, "autodrive", "A", "drive")
            assert.is_false(WorkflowManager:hasSupportSteps(wf.id))
        end)

        it("returns true when any step has at least one support sub-step", function()
            local wf = WorkflowManager:createWorkflow("Test")
            WorkflowManager:addStep(wf.id, "courseplay", "F1", "fieldwork")
            WorkflowManager:addSupportStep(wf.id, 1, { type="autodrive", target="X", action="unload" })
            assert.is_true(WorkflowManager:hasSupportSteps(wf.id))
        end)

        it("returns false for unknown workflow", function()
            assert.is_false(WorkflowManager:hasSupportSteps("no_such_id"))
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
                startWorkflow    = function(_, wf, v, isMain) table.insert(execCalls, {cmd="start",  wf=wf, v=v, isMain=isMain}) end,
                stopWorkflow     = function(_, v)             table.insert(execCalls, {cmd="stop",   v=v})       end,
                pauseWorkflow    = function(_, v)             table.insert(execCalls, {cmd="pause",  v=v})       end,
                resumeWorkflow   = function(_, v)             table.insert(execCalls, {cmd="resume", v=v})       end,
                goToNextStep     = function(_, v)             table.insert(execCalls, {cmd="next",   v=v})       end,
                goToPreviousStep = function(_, v)             table.insert(execCalls, {cmd="prev",   v=v})       end,
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

        it("dispatches 'start' with workflow resolved by id, passing isMain=true by default", function()
            local wf = WorkflowManager:createWorkflow("Run")
            local v  = VehicleMock.createValid("T")
            WorkflowManager:executeNetworkCommand("start", v, wf.id, true)
            assert.are.equal("start", execCalls[1].cmd)
            assert.are.equal(wf,      execCalls[1].wf)
            assert.is_true(execCalls[1].isMain)
        end)

        it("dispatches 'start' with isMain=false for support role", function()
            local wf = WorkflowManager:createWorkflow("Run")
            local v  = VehicleMock.createValid("T")
            WorkflowManager:executeNetworkCommand("start", v, wf.id, false)
            assert.is_false(execCalls[1].isMain)
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
            assert.are.equal("park", WorkflowManager.STEP_PARK)
            assert.are.equal("refuel", WorkflowManager.STEP_REFUEL)
            assert.are.equal("repair", WorkflowManager.STEP_REPAIR)
        end)
    end)

    -- Regression (bug-038): starting a workflow with no other active vehicles
    -- left the game with no working inputs because the leader dialog was opened
    -- then closed inside onOpen(). The fix pre-checks buildVehicleList() and must
    -- skip g_gui:showDialog entirely (calling callback(nil) directly) when empty.
    describe("showLeaderSelectDialog", function()
        local shownDialog
        local callbackResult

        before_each(function()
            shownDialog = "NOT_SHOWN"
            callbackResult = "NOT_CALLED"
            _G.g_gui = { showDialog = function(_, name) shownDialog = name end }
        end)

        it("does NOT show the dialog and calls callback(nil) when no candidate vehicles", function()
            WorkflowManager.leaderSelectDialog = {
                setData = function() end,
                buildVehicleList = function() return 0 end,
            }
            WorkflowManager:showLeaderSelectDialog({}, function(r) callbackResult = r end)

            assert.are.equal("NOT_SHOWN", shownDialog)  -- dialog never opened
            assert.is_nil(callbackResult)               -- started with no leader
        end)

        it("shows the dialog when candidate vehicles exist", function()
            WorkflowManager.leaderSelectDialog = {
                setData = function() end,
                buildVehicleList = function() return 2 end,
            }
            WorkflowManager:showLeaderSelectDialog({}, function(r) callbackResult = r end)

            assert.are.equal("WMLeaderVehicleSelectDialog", shownDialog)
            assert.are.equal("NOT_CALLED", callbackResult)  -- waits for user choice
        end)

        it("calls callback(nil) when no dialog is loaded (pure client)", function()
            WorkflowManager.leaderSelectDialog = nil
            WorkflowManager:showLeaderSelectDialog({}, function(r) callbackResult = r end)

            assert.are.equal("NOT_SHOWN", shownDialog)
            assert.is_nil(callbackResult)
        end)
    end)

    describe("showModeSelectDialog", function()
        local shownDialog
        local callbackResult

        before_each(function()
            shownDialog    = "NOT_SHOWN"
            callbackResult = "NOT_CALLED"
            _G.g_gui = { showDialog = function(_, name) shownDialog = name end }
        end)

        it("calls callback(true) when modeSelectDialog is nil", function()
            WorkflowManager.modeSelectDialog = nil
            WorkflowManager:showModeSelectDialog("wf_001", {}, function(r) callbackResult = r end)
            assert.is_true(callbackResult)
            assert.are.equal("NOT_SHOWN", shownDialog)
        end)

        it("does not crash when callback is nil and modeSelectDialog is nil", function()
            WorkflowManager.modeSelectDialog = nil
            assert.has_no.errors(function()
                WorkflowManager:showModeSelectDialog("wf_001", {}, nil)
            end)
        end)

        it("shows dialog and does not call callback when modeSelectDialog is loaded", function()
            WorkflowManager.modeSelectDialog = { setWorkflow = function() end }
            WorkflowManager:showModeSelectDialog("wf_001", {}, function(r) callbackResult = r end)
            assert.are.equal("WMModeSelectDialog", shownDialog)
            assert.are.equal("NOT_CALLED", callbackResult)
        end)
    end)
end)
