--[[
    WMConsoleCommands Unit Tests
    Covers console command registration/removal and the wmPrintState leader-sync
    diagnosis, which must report the executor's real gate (getLeaderSyncRequirement)
    instead of a hand-copied formula that can silently go stale.
]]

describe("WMConsoleCommands", function()

    local registered

    setup(function()
        registered = {}
        _G.addConsoleCommand = function(name, desc, fnName, target)
            registered[name] = true
        end
        _G.removeConsoleCommand = function(name)
            registered[name] = nil
        end
        dofile("src/dev/WMConsoleCommands.lua")
    end)

    before_each(function()
        registered = {}
    end)

    -- Run fn with print captured; restores print even when fn errors
    local function captureOutput(fn)
        local lines = {}
        local origPrint = _G.print
        _G.print = function(s) table.insert(lines, tostring(s)) end
        local ok, err = pcall(fn)
        _G.print = origPrint
        assert(ok, err)
        return table.concat(lines, "\n")
    end

    local function makeVehicle(ex)
        return {
            getFullName = function() return "TestVehicle" end,
            spec_workflowManagerSpec = { wmExecution = ex },
        }
    end

    -- =========================================================================
    -- init / delete
    -- =========================================================================
    describe("init / delete", function()
        it("registers the three wm console commands", function()
            WMConsoleCommands:init()
            assert.is_true(registered["wmPrintState"])
            assert.is_true(registered["wmPrintStateAll"])
            assert.is_true(registered["wmPrintWorkflow"])
        end)

        it("removes them again on delete", function()
            WMConsoleCommands:init()
            WMConsoleCommands:delete()
            assert.is_nil(registered["wmPrintState"])
            assert.is_nil(registered["wmPrintStateAll"])
            assert.is_nil(registered["wmPrintWorkflow"])
        end)
    end)

    -- =========================================================================
    -- printVehicleState
    -- =========================================================================
    describe("printVehicleState", function()
        it("prints (no active workflow) without an execution", function()
            local out = captureOutput(function()
                WMConsoleCommands:printVehicleState(makeVehicle(nil))
            end)
            assert.is_truthy(out:find("no active workflow", 1, true))
        end)

        it("prints the workflow header and step for a running execution", function()
            local ex = {
                workflow    = { id = "wf_x", name = "Harvest", steps = { {}, {} } },
                status      = "running",
                currentStep = 2,
            }
            local out = captureOutput(function()
                WMConsoleCommands:printVehicleState(makeVehicle(ex))
            end)
            assert.is_truthy(out:find("Harvest", 1, true))
            assert.is_truthy(out:find("2 / 2", 1, true))
        end)

        it("asks the executor for the sync gate instead of re-deriving it", function()
            local askedWith = nil
            _G.WMExecutor = {
                getLeaderSyncRequirement = function(_, activeData)
                    askedWith = activeData
                    return 3
                end,
            }
            local ex = {
                workflow    = { id = "wf_f", name = "Follower",
                                steps = { { type = "wait_for_leader" }, { type = "autodrive" } } },
                status      = "waiting_for_leader",
                currentStep = 1,
                leaderVehicle = { getFullName = function() return "Leader" end },
                linkedLeaderExecution = { currentStep = 2, workflow = { steps = { {}, {}, {} } } },
                syncSourceOrdinals = { [1] = 1 },
                syncTargets = { [1] = 3 },
            }
            local out = captureOutput(function()
                WMConsoleCommands:printVehicleState(makeVehicle(ex))
            end)
            assert.are.equal(ex, askedWith)
            assert.is_truthy(out:find("need leader at step 3", 1, true))
        end)

        it("reports not blocked once the executor gate is satisfied", function()
            _G.WMExecutor = {
                getLeaderSyncRequirement = function() return 3 end,
            }
            local ex = {
                workflow    = { id = "wf_f", name = "Follower",
                                steps = { { type = "wait_for_leader" } } },
                status      = "waiting_for_leader",
                currentStep = 1,
                leaderVehicle = { getFullName = function() return "Leader" end },
                linkedLeaderExecution = { currentStep = 3, workflow = { steps = { {}, {}, {} } } },
            }
            local out = captureOutput(function()
                WMConsoleCommands:printVehicleState(makeVehicle(ex))
            end)
            assert.is_truthy(out:find("blockedByLeader:   nil", 1, true))
        end)
    end)
end)
