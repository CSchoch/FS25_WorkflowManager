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
            assert.are.equal("./workflowManager.xml", path)
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
                    { type = "autodrive", target = "Farm", action = "drive" }
                }
            }
            assert.is_true(WMStorage:saveWorkflows({ wf }))
        end)

        it("persists workflow id and name", function()
            local wf = { id = "wf_id_001", name = "My Workflow", steps = {} }
            WMStorage:saveWorkflows({ wf })

            local data = XMLFile._getDataForPath("./workflowManager.xml")
            assert.is_not_nil(data)
        end)

        it("persists step type, target and action", function()
            local wf = {
                id = "wf_steps_001", name = "Step Workflow",
                steps = {
                    { type = "autodrive",  target = "FarmGate",  action = "drive"     },
                    { type = "courseplay", target = "Wheat_01",  action = "fieldwork" },
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

        it("persists optional step fields (unloadTarget, fillType, syncGroup)", function()
            local wf = {
                id = "wf_opts_001", name = "Opts Workflow",
                steps = {
                    {
                        type = "autodrive", target = "Silo", action = "pickup_deliver",
                        unloadTarget = "BGA", fillType = "WHEAT", syncGroup = 2
                    }
                }
            }
            WMStorage:saveWorkflows({ wf })

            _G.fileExists = function() return true end
            local loaded = WMStorage:loadWorkflows()
            local step = loaded[1].steps[1]
            assert.are.equal("BGA",   step.unloadTarget)
            assert.are.equal("WHEAT", step.fillType)
            assert.are.equal(2,       step.syncGroup)
        end)

        it("persists linkedWorkflowId and linkRole for a valid linked pair", function()
            -- Both main and support must be saved together so the link validation
            -- in loadWorkflows does not discard them as "invalid".
            local main = {
                id = "wf_linked_001", name = "Main",
                linkedWorkflowId = "wf_support_001", linkRole = "main",
                steps = { { type = "autodrive", target = "A", action = "drive" } }
            }
            local support = {
                id = "wf_support_001", name = "Support",
                linkedWorkflowId = "wf_linked_001", linkRole = "support",
                steps = { { type = "courseplay", target = "B", action = "fieldwork" } }
            }
            WMStorage:saveWorkflows({ main, support })

            _G.fileExists = function() return true end
            local loaded = WMStorage:loadWorkflows()
            assert.are.equal(2,                loaded and #loaded or 0)
            assert.are.equal("wf_support_001", loaded[1].linkedWorkflowId)
            assert.are.equal("main",           loaded[1].linkRole)
            assert.are.equal("wf_linked_001",  loaded[2].linkedWorkflowId)
            assert.are.equal("support",        loaded[2].linkRole)
        end)

        it("saves multiple workflows in order", function()
            local workflows = {
                { id = "wf_m_001", name = "Alpha", steps = { { type="autodrive", target="A", action="drive" } } },
                { id = "wf_m_002", name = "Beta",  steps = { { type="autodrive", target="B", action="drive" } } },
                { id = "wf_m_003", name = "Gamma", steps = { { type="autodrive", target="C", action="drive" } } },
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

        it("clears invalid linkedWorkflowId that references a missing workflow", function()
            local wf = {
                id = "wf_orphan", name = "Orphan",
                linkedWorkflowId = "wf_missing",  -- referenced workflow does not exist
                linkRole = "main",
                steps = {
                    { type = "autodrive", target = "X", action = "drive", syncGroup = 1 }
                }
            }
            WMStorage:saveWorkflows({ wf })
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            -- Link must be cleared on load
            assert.is_nil(loaded[1].linkedWorkflowId)
            assert.is_nil(loaded[1].linkRole)
            -- syncGroup on steps must also be cleared
            assert.is_nil(loaded[1].steps[1].syncGroup)
        end)

        it("keeps valid linked workflow pair intact", function()
            local main = {
                id = "wf_main", name = "Main",
                linkedWorkflowId = "wf_support", linkRole = "main",
                steps = { { type = "autodrive", target = "A", action = "drive" } }
            }
            local support = {
                id = "wf_support", name = "Support",
                linkedWorkflowId = "wf_main", linkRole = "support",
                steps = { { type = "courseplay", target = "B", action = "fieldwork" } }
            }
            WMStorage:saveWorkflows({ main, support })
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            assert.are.equal(2, #loaded)
            -- Links must survive the load
            assert.are.equal("wf_support", loaded[1].linkedWorkflowId)
            assert.are.equal("wf_main",    loaded[2].linkedWorkflowId)
        end)

        it("does not persist runtime fields (currentStep, status) on workflow", function()
            -- WMStorage should never write currentStep or status since those are
            -- per-vehicle runtime state stored on the vehicle spec
            local wf = {
                id = "wf_rt", name = "RT",
                steps = { { type = "autodrive", target = "A", action = "drive" } }
            }
            WMStorage:saveWorkflows({ wf })
            _G.fileExists = function() return true end

            local loaded = WMStorage:loadWorkflows()
            assert.is_nil(loaded[1].currentStep)
            assert.is_nil(loaded[1].status)
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
                    linkedWorkflowId = nil, linkRole = nil,
                    steps = {
                        { type = "autodrive",  target = "Field1_Entry",  action = "drive"           },
                        { type = "courseplay", target = "Field1_Harvest", action = "fieldwork"      },
                        { type = "autodrive",  target = "Silo",          action = "pickup_deliver",
                          unloadTarget = "BGA", fillType = "WHEAT"                                  },
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
        end)
    end)
end)
