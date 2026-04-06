--[[
    WorkflowStorage Unit Tests
    Tests for WMStorage XML persistence (save / load workflows)

    The storage layer uses FS25's XMLFile API in OOP style:
        local f = XMLFile.create(...)
        f:setString(path, value)
        f:save()
        f:delete()

    The XMLFile mock returns a proxy table that forwards OOP calls to the static
    functions, so the real WMStorage source can be loaded unchanged.
]]

describe("WMStorage", function()
    local WMStorage

    -- -------------------------------------------------------------------------
    -- Setup: load dependencies then WMStorage
    -- -------------------------------------------------------------------------
    setup(function()
        -- WorkflowManager stub (WMStorage uses WorkflowManager.modDirectory and WMHud)
        _G.WorkflowManager = _G.WorkflowManager or {}
        _G.WorkflowManager.modDirectory = "./"

        -- WMHud stub for HUD position save/restore
        _G.WMHud = { x = nil, y = nil }

        dofile("src/WorkflowStorage.lua")
        WMStorage = _G.WMStorage
    end)

    -- -------------------------------------------------------------------------
    -- Per-test reset
    -- -------------------------------------------------------------------------
    before_each(function()
        WMStorage.isInitialized = false
        XMLFile._clearAll()
        _G.WMHud = { x = nil, y = nil }
        -- Default: no file exists on disk
        _G.fileExists = function(path) return false end
        -- Reset logger
        _G.WMLogger.calls = { debug = {}, info = {}, warning = {}, error = {} }
    end)

    -- =========================================================================
    -- init
    -- =========================================================================
    describe("init", function()
        it("sets isInitialized to true", function()
            WMStorage:init()
            assert.is_true(WMStorage.isInitialized)
        end)
    end)

    -- =========================================================================
    -- getXmlPath
    -- =========================================================================
    describe("getXmlPath", function()
        it("returns mod-directory path when missionInfo is absent", function()
            _G.g_currentMission.missionInfo = nil
            local path = WMStorage:getXmlPath()
            -- modDirectory is "./" so path ends with workflowManager.xml
            assert.is_truthy(path:match("workflowManager%.xml$"))
        end)

        it("returns savegame path when missionInfo.savegameDirectory is set", function()
            _G.g_currentMission.missionInfo = { savegameDirectory = "/saves/slot1" }
            local path = WMStorage:getXmlPath()
            assert.are.equal("/saves/slot1/workflowManager.xml", path)
            -- cleanup
            _G.g_currentMission.missionInfo = nil
        end)
    end)

    -- =========================================================================
    -- saveWorkflows
    -- =========================================================================
    describe("saveWorkflows", function()
        it("returns false for nil workflows argument", function()
            assert.is_false(WMStorage:saveWorkflows(nil))
        end)

        it("returns true for an empty workflow list", function()
            assert.is_true(WMStorage:saveWorkflows({}))
        end)

        it("returns true when workflows are saved successfully", function()
            local wf = {
                id = "wf_save_001", name = "Save Test",
                steps = {
                    { type = "autodrive", target = "Farm", action = "drive", support = {} }
                }
            }
            assert.is_true(WMStorage:saveWorkflows({ wf }))
        end)

        it("persists workflow id and name", function()
            local wf = { id = "wf_id_001", name = "My Workflow", steps = {} }
            WMStorage:saveWorkflows({ wf })

            -- Verify round-trip: save then load recovers the id and name
            _G.fileExists = function() return true end
            local loaded = WMStorage:loadWorkflows()
            assert.are.equal(1,            #loaded)
            assert.are.equal("wf_id_001",  loaded[1].id)
            assert.are.equal("My Workflow", loaded[1].name)
        end)

        it("persists step type, target and action", function()
            local wf = {
                id = "wf_steps_001", name = "Step Workflow",
                steps = {
                    { type = "autodrive",  target = "FarmGate",  action = "drive",      support = {} },
                    { type = "courseplay", target = "Wheat_01",  action = "fieldwork",  support = {} },
                }
            }
            WMStorage:saveWorkflows({ wf })

            -- Reload and verify
            _G.fileExists = function() return true end
            local loaded = WMStorage:loadWorkflows()
            assert.are.equal(1, #loaded)
            assert.are.equal(2, #loaded[1].steps)
            assert.are.equal("autodrive",  loaded[1].steps[1].type)
            assert.are.equal("FarmGate",   loaded[1].steps[1].target)
            assert.are.equal("drive",      loaded[1].steps[1].action)
            assert.are.equal("courseplay", loaded[1].steps[2].type)
            assert.are.equal("Wheat_01",   loaded[1].steps[2].target)
            assert.are.equal("fieldwork",  loaded[1].steps[2].action)
        end)

        it("persists optional step fields (unloadTarget, fillType)", function()
            local wf = {
                id = "wf_opts_001", name = "Opts Workflow",
                steps = {
                    {
                        type = "autodrive", target = "Silo", action = "pickup_deliver",
                        unloadTarget = "BGA", fillType = "WHEAT", support = {}
                    }
                }
            }
            WMStorage:saveWorkflows({ wf })

            _G.fileExists = function() return true end
            local loaded = WMStorage:loadWorkflows()
            local step = loaded[1].steps[1]
            assert.are.equal("BGA",   step.unloadTarget)
            assert.are.equal("WHEAT", step.fillType)
            -- syncGroup is no longer persisted
            assert.is_nil(step.syncGroup)
        end)

        it("persists support sub-steps nested inside a main step", function()
            local wf = {
                id = "wf_support_001", name = "Support Workflow",
                steps = {
                    {
                        type = "autodrive", target = "Field43", action = "drive",
                        support = {}
                    },
                    {
                        type = "courseplay", target = "F43/Harvest", action = "fieldwork",
                        support = {
                            { type = "autodrive", target = "Field43",  action = "unload", unloadTarget = "Silo" },
                            { type = "autodrive", target = "Silo",     action = "deliver" },
                        }
                    },
                }
            }
            WMStorage:saveWorkflows({ wf })

            _G.fileExists = function() return true end
            local loaded = WMStorage:loadWorkflows()
            assert.are.equal(1, #loaded)
            assert.are.equal(2, #loaded[1].steps)

            -- Step 0 (drive): no support sub-steps
            assert.are.equal(0, #loaded[1].steps[1].support)

            -- Step 1 (fieldwork): 2 support sub-steps
            local support = loaded[1].steps[2].support
            assert.are.equal(2,          #support)
            assert.are.equal("autodrive", support[1].type)
            assert.are.equal("Field43",   support[1].target)
            assert.are.equal("unload",    support[1].action)
            assert.are.equal("Silo",      support[1].unloadTarget)
            assert.are.equal("autodrive", support[2].type)
            assert.are.equal("Silo",      support[2].target)
            assert.are.equal("deliver",   support[2].action)
        end)

        it("saves multiple workflows in order", function()
            local workflows = {
                { id = "wf_m_001", name = "Alpha", steps = { { type="autodrive", target="A", action="drive", support={} } } },
                { id = "wf_m_002", name = "Beta",  steps = { { type="autodrive", target="B", action="drive", support={} } } },
                { id = "wf_m_003", name = "Gamma", steps = { { type="autodrive", target="C", action="drive", support={} } } },
            }
            WMStorage:saveWorkflows(workflows)

            _G.fileExists = function() return true end
            local loaded = WMStorage:loadWorkflows()
            assert.are.equal(3, #loaded)
            assert.are.equal("Alpha", loaded[1].name)
            assert.are.equal("Beta",  loaded[2].name)
            assert.are.equal("Gamma", loaded[3].name)
        end)

        it("saves and restores HUD position", function()
            _G.WMHud.x = 0.75
            _G.WMHud.y = 0.25
            WMStorage:saveWorkflows({})

            -- Reset HUD state, then load and verify it is restored
            _G.WMHud.x = nil
            _G.WMHud.y = nil
            _G.fileExists = function() return true end
            WMStorage:loadWorkflows()
            assert.are.equal(0.75, _G.WMHud.x)
            assert.are.equal(0.25, _G.WMHud.y)
        end)
    end)

    -- =========================================================================
    -- loadWorkflows
    -- =========================================================================
    describe("loadWorkflows", function()
        it("returns empty table when file does not exist", function()
            _G.fileExists = function() return false end
            local loaded = WMStorage:loadWorkflows()
            assert.is_table(loaded)
            assert.are.equal(0, #loaded)
        end)

        it("returns empty table when XMLFile.load fails", function()
            -- fileExists returns true but no data is in XMLFile store → load returns nil
            _G.fileExists = function() return true end
            local loaded = WMStorage:loadWorkflows()
            assert.is_table(loaded)
            assert.are.equal(0, #loaded)
        end)

        it("loads workflow id and name", function()
            local wf = { id = "wf_load_001", name = "Load Test", steps = {} }
            WMStorage:saveWorkflows({ wf })
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            assert.are.equal(1, #loaded)
            assert.are.equal("wf_load_001", loaded[1].id)
            assert.are.equal("Load Test",   loaded[1].name)
        end)

        it("loads empty steps array when workflow has no steps", function()
            WMStorage:saveWorkflows({ { id = "wf_nostep", name = "NoStep", steps = {} } })
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            assert.is_table(loaded[1].steps)
            assert.are.equal(0, #loaded[1].steps)
        end)

        it("initialises step.support as empty table when step has no support sub-steps", function()
            local wf = {
                id = "wf_nosupport", name = "NoSupport",
                steps = { { type = "autodrive", target = "A", action = "drive", support = {} } }
            }
            WMStorage:saveWorkflows({ wf })
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            local step = loaded[1].steps[1]
            assert.is_table(step.support)
            assert.are.equal(0, #step.support)
        end)

        it("does not persist runtime fields (currentStep, status) on workflow", function()
            local wf = {
                id = "wf_rt", name = "RT",
                steps = { { type = "autodrive", target = "A", action = "drive", support = {} } }
            }
            WMStorage:saveWorkflows({ wf })
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            assert.is_nil(loaded[1].currentStep)
            assert.is_nil(loaded[1].status)
        end)

        it("does not produce linkedWorkflowId or linkRole on loaded workflows", function()
            local wf = { id = "wf_clean", name = "Clean", steps = {} }
            WMStorage:saveWorkflows({ wf })
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            assert.is_nil(loaded[1].linkedWorkflowId)
            assert.is_nil(loaded[1].linkRole)
        end)
    end)

    -- =========================================================================
    -- migration: old linked-pair format → hierarchical support format
    -- =========================================================================
    describe("migrateOldLinkedWorkflows", function()
        -- Helper: inject raw old-format data directly into the XMLFile store
        -- so loadWorkflows sees it as if it came from disk.
        local function saveOldFormat(main, support)
            -- We need to write linkRole / linkedWorkflowId / syncGroup manually
            -- because saveWorkflows no longer writes them.
            -- Use the same path that loadWorkflows will query.
            local xmlPath = WMStorage:getXmlPath()
            local f = XMLFile.create("wm_migrate_test", xmlPath, "WorkflowManager")

            local function writeWf(index, wf)
                local wk = string.format("WorkflowManager.workflows.workflow(%d)", index)
                f:setString(wk .. "#id",              wf.id)
                f:setString(wk .. "#name",            wf.name)
                if wf.linkedWorkflowId then
                    f:setString(wk .. "#linkedWorkflowId", wf.linkedWorkflowId)
                end
                if wf.linkRole then
                    f:setString(wk .. "#linkRole", wf.linkRole)
                end
                for j, step in ipairs(wf.steps) do
                    local sk = string.format("%s.step(%d)", wk, j - 1)
                    f:setString(sk .. "#type",   step.type)
                    f:setString(sk .. "#target", step.target)
                    f:setString(sk .. "#action", step.action or "default")
                    if step.syncGroup then
                        f:setInt(sk .. "#syncGroup", step.syncGroup)
                    end
                    if step.unloadTarget then
                        f:setString(sk .. "#unloadTarget", step.unloadTarget)
                    end
                end
            end

            writeWf(0, main)
            if support then writeWf(1, support) end
            f:save()
            f:delete()
        end

        it("is a no-op when no linkRole attributes are present", function()
            local wf = {
                id = "wf_clean", name = "Clean",
                steps = { { type="autodrive", target="A", action="drive", support={} } }
            }
            WMStorage:saveWorkflows({ wf })
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            -- Workflow should be unchanged (except support={} on step)
            assert.are.equal(1, #loaded)
            assert.are.equal("wf_clean", loaded[1].id)
            assert.are.equal(0, #loaded[1].steps[1].support)
        end)

        it("merges a support workflow's steps into the main workflow's steps", function()
            local main = {
                id = "wf_main_001", name = "Main",
                linkRole = "main", linkedWorkflowId = "wf_sup_001",
                steps = {
                    { type = "autodrive",  target = "Field43", action = "drive",      syncGroup = 1 },
                    { type = "courseplay", target = "F43",     action = "fieldwork",  syncGroup = 1 },
                }
            }
            local support = {
                id = "wf_sup_001", name = "Support",
                linkRole = "support", linkedWorkflowId = "wf_main_001",
                steps = {
                    { type = "autodrive", target = "Field43", action = "unload",  syncGroup = 1, unloadTarget = "Silo" },
                    { type = "autodrive", target = "Silo",    action = "deliver", syncGroup = 1 },
                }
            }
            saveOldFormat(main, support)
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()

            -- Only the main workflow should remain (support is absorbed)
            assert.are.equal(1, #loaded)
            local wf = loaded[1]
            assert.are.equal("wf_main_001", wf.id)
            assert.are.equal(2, #wf.steps)

            -- Drive step (syncGroup=1, but is NOT the last step of group 1)
            -- Support steps should be on step[2] (the last step of group 1 = fieldwork)
            assert.are.equal(0, #wf.steps[1].support)

            local support2 = wf.steps[2].support
            assert.are.equal(2,          #support2)
            assert.are.equal("unload",   support2[1].action)
            assert.are.equal("Silo",     support2[1].unloadTarget)
            assert.are.equal("deliver",  support2[2].action)

            -- No old link fields remain
            assert.is_nil(wf.linkedWorkflowId)
            assert.is_nil(wf.linkRole)
            assert.is_nil(wf.steps[1].syncGroup)
            assert.is_nil(wf.steps[2].syncGroup)
        end)

        it("removes the absorbed support workflow from the list", function()
            local main = {
                id = "wf_main_002", name = "Main",
                linkRole = "main", linkedWorkflowId = "wf_sup_002",
                steps = {
                    { type = "courseplay", target = "F1", action = "fieldwork", syncGroup = 1 },
                }
            }
            local support = {
                id = "wf_sup_002", name = "Support",
                linkRole = "support", linkedWorkflowId = "wf_main_002",
                steps = {
                    { type = "autodrive", target = "F1", action = "unload", syncGroup = 1 },
                }
            }
            saveOldFormat(main, support)
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            assert.are.equal(1, #loaded)
            assert.are.equal("wf_main_002", loaded[1].id)

            -- Confirm support workflow is NOT in the list
            for _, wf in ipairs(loaded) do
                assert.are_not.equal("wf_sup_002", wf.id)
            end
        end)

        it("handles multiple sync groups: support steps distributed to correct main steps", function()
            local main = {
                id = "wf_main_003", name = "Main",
                linkRole = "main", linkedWorkflowId = "wf_sup_003",
                steps = {
                    { type = "autodrive",  target = "Field1", action = "drive",      syncGroup = 1 },
                    { type = "courseplay", target = "F1",     action = "fieldwork",  syncGroup = 1 },
                    { type = "autodrive",  target = "Field2", action = "drive",      syncGroup = 2 },
                    { type = "courseplay", target = "F2",     action = "fieldwork",  syncGroup = 2 },
                }
            }
            local support = {
                id = "wf_sup_003", name = "Support",
                linkRole = "support", linkedWorkflowId = "wf_main_003",
                steps = {
                    { type = "autodrive", target = "Field1", action = "unload",  syncGroup = 1 },
                    { type = "autodrive", target = "Silo",   action = "deliver", syncGroup = 2 },
                }
            }
            saveOldFormat(main, support)
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            assert.are.equal(1, #loaded)
            local steps = loaded[1].steps

            -- step[1] = drive(group1): no support (not the last step of group 1)
            assert.are.equal(0, #steps[1].support)
            -- step[2] = fieldwork(group1): support gets group-1 step (unload)
            assert.are.equal(1, #steps[2].support)
            assert.are.equal("unload", steps[2].support[1].action)
            -- step[3] = drive(group2): no support (not the last step of group 2)
            assert.are.equal(0, #steps[3].support)
            -- step[4] = fieldwork(group2): support gets group-2 step (deliver)
            assert.are.equal(1, #steps[4].support)
            assert.are.equal("deliver", steps[4].support[1].action)
        end)

        it("keeps an orphaned support workflow (no valid main) as a standalone workflow", function()
            -- A support workflow whose main has been deleted
            local orphan = {
                id = "wf_orphan_001", name = "Orphan Support",
                linkRole = "support", linkedWorkflowId = "wf_missing",
                steps = {
                    { type = "autodrive", target = "X", action = "drive", syncGroup = 1 }
                }
            }
            saveOldFormat(orphan, nil)
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()

            -- Should survive as a standalone workflow
            assert.are.equal(1, #loaded)
            assert.are.equal("wf_orphan_001", loaded[1].id)
            -- Old link fields cleared
            assert.is_nil(loaded[1].linkedWorkflowId)
            assert.is_nil(loaded[1].linkRole)
            -- syncGroup cleared, support = {}
            assert.is_nil(loaded[1].steps[1].syncGroup)
            assert.are.equal(0, #loaded[1].steps[1].support)
        end)
    end)

    -- =========================================================================
    -- round-trip: save then reload
    -- =========================================================================
    describe("round-trip save/load", function()
        it("preserves complex workflow definition end-to-end", function()
            local workflows = {
                {
                    id = "wf_rt_001", name = "Harvest Route",
                    steps = {
                        { type = "autodrive",  target = "Field1_Entry",   action = "drive",      support = {} },
                        { type = "courseplay", target = "Field1_Harvest", action = "fieldwork",
                          support = {
                              { type = "autodrive", target = "Field1_Entry", action = "unload", unloadTarget = "Silo" },
                              { type = "autodrive", target = "Silo",         action = "deliver" },
                          }
                        },
                        { type = "autodrive",  target = "Silo",           action = "pickup_deliver",
                          unloadTarget = "BGA", fillType = "WHEAT",        support = {} },
                    }
                }
            }

            WMStorage:saveWorkflows(workflows)
            _G.fileExists = function() return true end
            local loaded = WMStorage:loadWorkflows()

            assert.are.equal(1,               #loaded)
            assert.are.equal("Harvest Route", loaded[1].name)
            assert.are.equal(3,               #loaded[1].steps)
            assert.are.equal("BGA",           loaded[1].steps[3].unloadTarget)
            assert.are.equal("WHEAT",         loaded[1].steps[3].fillType)

            -- Support sub-steps round-trip
            local support = loaded[1].steps[2].support
            assert.are.equal(2,         #support)
            assert.are.equal("unload",  support[1].action)
            assert.are.equal("Silo",    support[1].unloadTarget)
            assert.are.equal("deliver", support[2].action)
        end)
    end)
end)
