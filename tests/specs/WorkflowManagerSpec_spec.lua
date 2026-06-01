--[[
    WorkflowManagerSpec Unit Tests
    Covers: onLoad, onPostLoad (savegame restore), saveToXMLFile (savegame write),
            onWriteStream / onReadStream (MP mid-session join), onDelete (cleanup).

    The specialization is a plain Lua table of functions (no FS25 class system at
    runtime), so we can call WorkflowManagerSpec.onLoad(vehicle, ...) directly.
]]

describe("WorkflowManagerSpec", function()

    -- -------------------------------------------------------------------------
    -- Helpers
    -- -------------------------------------------------------------------------

    local BASE_KEY = "vehicles.vehicle(0).FS25_WorkflowManager.workflowManagerSpec"

    -- Minimal vehicle with the fields the spec methods touch
    local function makeVehicle(name)
        local v = {
            spec_workflowManagerSpec = nil,
            isClient = true,
            getName = function() return name or "TestVehicle" end,
            clearActionEventsTable = function(_, tbl)
                for k in pairs(tbl) do tbl[k] = nil end
            end,
            addActionEvent = function(_, tbl, action, target, cb)
                local id = "eventId_" .. tostring(action)
                tbl[action] = id
                return true, id
            end,
            getIsActiveForInput = function() return true end,
        }
        return v
    end

    -- Simple in-memory XML that mirrors FS25's savegame xmlFile OOP API
    local function makeSavegameXML(data)
        data = data or {}
        return {
            getValue = function(_, key) return data[key] end,
            setValue = function(_, key, value) data[key] = value end,
            _data    = data,
        }
    end

    -- -------------------------------------------------------------------------
    -- Setup: mock the FS25 globals that fire at dofile() time, then load
    -- -------------------------------------------------------------------------
    setup(function()
        _G.SpecializationUtil = {
            hasSpecialization    = function() return true end,
            registerEventListener = function() end,
        }
        _G.Enterable = {}

        _G.g_specializationManager = {
            getSpecializationByName = function() return nil end,
            addSpecialization       = function() end,
        }
        _G.TypeManager = { validateTypes = function() end }

        _G.Vehicle = { xmlSchemaSavegame = { register = function() end } }
        _G.XMLValueType = { STRING = 1, INT = 2, BOOL = 3 }

        -- Prevent registerToVehicleTypes from touching vehicle type tables
        _G.g_vehicleTypeManager = nil

        -- prependedFunction just needs to return the new fn for the hook
        _G.Utils.prependedFunction = function(old, new_fn)
            return function(...) new_fn(...) if old then old(...) end end
        end

        -- Reset guard and load the real specialization
        _G.WorkflowManagerSpec = nil
        dofile("src/WorkflowManagerSpec.lua")
    end)

    -- -------------------------------------------------------------------------
    -- Per-test reset
    -- -------------------------------------------------------------------------
    before_each(function()
        _G.WMExecutor = { activeVehicles = {}, stopWorkflow = function() end }

        _G.WorkflowManager = {
            STATUS_PAUSED = "paused",
            workflows     = {},
            getWorkflowById = function(_, id)
                for _, wf in ipairs(_G.WorkflowManager.workflows) do
                    if wf.id == id then return wf end
                end
                return nil
            end,
        }

        _G.WMHud = { show = function() end, hide = function() end }

        _G.g_currentMission.time = 12000
        _G.g_currentMission.controlledVehicle = nil

        _G.WMLogger.calls = { debug = {}, info = {}, warning = {}, error = {} }
    end)

    -- =========================================================================
    -- onLoad
    -- =========================================================================
    describe("onLoad", function()
        it("initialises spec with empty actionEvents table and nil wmExecution", function()
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            assert.is_not_nil(v.spec_workflowManagerSpec)
            assert.is_table(v.spec_workflowManagerSpec.actionEvents)
            assert.is_nil(v.spec_workflowManagerSpec.wmExecution)
        end)

        it("does not crash when called twice (idempotent)", function()
            local v = makeVehicle()
            assert.has_no.errors(function()
                WorkflowManagerSpec.onLoad(v, nil)
                WorkflowManagerSpec.onLoad(v, nil)
            end)
        end)
    end)

    -- =========================================================================
    -- onPostLoad
    -- =========================================================================
    describe("onPostLoad", function()
        it("does nothing when savegame is nil", function()
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            WorkflowManagerSpec.onPostLoad(v, nil)
            assert.is_nil(v.spec_workflowManagerSpec.wmExecution)
        end)

        it("does nothing when savegame.resetVehicles is true", function()
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            local sg = {
                key = "vehicles.vehicle(0)",
                xmlFile = makeSavegameXML({}),
                resetVehicles = true,
            }
            WorkflowManagerSpec.onPostLoad(v, sg)
            assert.is_nil(v.spec_workflowManagerSpec.wmExecution)
        end)

        it("does nothing when workflowId is absent from XML", function()
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            local sg = {
                key = "vehicles.vehicle(0)",
                xmlFile = makeSavegameXML({}),
                resetVehicles = false,
            }
            WorkflowManagerSpec.onPostLoad(v, sg)
            assert.is_nil(v.spec_workflowManagerSpec.wmExecution)
        end)

        it("restores wmExecution as STATUS_PAUSED when workflowId is found", function()
            local wf = { id = "wf_post_001", name = "Restore Test", steps = {} }
            _G.WorkflowManager.workflows = { wf }

            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)

            local sg = {
                key     = "vehicles.vehicle(0)",
                resetVehicles = false,
                xmlFile = makeSavegameXML({
                    [BASE_KEY .. "#workflowId"]  = "wf_post_001",
                    [BASE_KEY .. "#currentStep"] = 3,
                }),
            }
            WorkflowManagerSpec.onPostLoad(v, sg)

            local d = v.spec_workflowManagerSpec.wmExecution
            assert.is_not_nil(d)
            assert.are.equal("paused",   d.status)
            assert.are.equal(wf,         d.workflow)
            assert.are.equal(v,          d.vehicle)
            assert.are.equal(3,          d.currentStep)
            assert.is_false(d.waitingForCompletion)
        end)

        it("sets autoResumeUntil = current time + 10 000 ms", function()
            local wf = { id = "wf_timer_001", name = "Timer", steps = {} }
            _G.WorkflowManager.workflows = { wf }
            _G.g_currentMission.time = 5000

            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)

            local sg = {
                key = "vehicles.vehicle(0)", resetVehicles = false,
                xmlFile = makeSavegameXML({ [BASE_KEY .. "#workflowId"] = "wf_timer_001" }),
            }
            WorkflowManagerSpec.onPostLoad(v, sg)

            assert.are.equal(15000, v.spec_workflowManagerSpec.wmExecution.autoResumeUntil)
        end)

        it("adds the vehicle to WMExecutor.activeVehicles", function()
            local wf = { id = "wf_active_001", name = "Active", steps = {} }
            _G.WorkflowManager.workflows = { wf }

            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)

            local sg = {
                key = "vehicles.vehicle(0)", resetVehicles = false,
                xmlFile = makeSavegameXML({ [BASE_KEY .. "#workflowId"] = "wf_active_001" }),
            }
            WorkflowManagerSpec.onPostLoad(v, sg)

            assert.is_true(_G.WMExecutor.activeVehicles[v] == true)
        end)

        it("defaults isMainVehicle to true when absent from XML", function()
            local wf = { id = "wf_main_dflt", name = "Main Default", steps = {} }
            _G.WorkflowManager.workflows = { wf }

            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)

            local sg = {
                key = "vehicles.vehicle(0)", resetVehicles = false,
                xmlFile = makeSavegameXML({ [BASE_KEY .. "#workflowId"] = "wf_main_dflt" }),
            }
            WorkflowManagerSpec.onPostLoad(v, sg)

            local d = v.spec_workflowManagerSpec.wmExecution
            assert.is_true(d.isMainVehicle ~= false)
            assert.is_nil(d.currentSupportStep)
        end)

        it("restores support role: isMainVehicle=false and currentSupportStep", function()
            local wf = { id = "wf_sup_post", name = "Support Restore", steps = {} }
            _G.WorkflowManager.workflows = { wf }

            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)

            local sg = {
                key = "vehicles.vehicle(0)", resetVehicles = false,
                xmlFile = makeSavegameXML({
                    [BASE_KEY .. "#workflowId"]         = "wf_sup_post",
                    [BASE_KEY .. "#isMainVehicle"]       = false,
                    [BASE_KEY .. "#currentSupportStep"]  = 2,
                }),
            }
            WorkflowManagerSpec.onPostLoad(v, sg)

            local d = v.spec_workflowManagerSpec.wmExecution
            assert.are.equal(false, d.isMainVehicle)
            assert.are.equal(2,     d.currentSupportStep)
        end)

        it("logs a warning and leaves wmExecution nil when workflowId is not found", function()
            _G.WorkflowManager.workflows = {}  -- no matching workflow

            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)

            local sg = {
                key = "vehicles.vehicle(0)", resetVehicles = false,
                xmlFile = makeSavegameXML({ [BASE_KEY .. "#workflowId"] = "wf_ghost" }),
            }
            WorkflowManagerSpec.onPostLoad(v, sg)

            assert.is_nil(v.spec_workflowManagerSpec.wmExecution)
            assert.are.equal(1, #_G.WMLogger.calls.warning)
        end)

        it("defaults currentStep to 1 when absent from XML", function()
            local wf = { id = "wf_step_dflt", name = "Step Default", steps = {} }
            _G.WorkflowManager.workflows = { wf }

            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)

            local sg = {
                key = "vehicles.vehicle(0)", resetVehicles = false,
                xmlFile = makeSavegameXML({ [BASE_KEY .. "#workflowId"] = "wf_step_dflt" }),
            }
            WorkflowManagerSpec.onPostLoad(v, sg)

            assert.are.equal(1, v.spec_workflowManagerSpec.wmExecution.currentStep)
        end)
    end)

    -- =========================================================================
    -- saveToXMLFile
    -- =========================================================================
    describe("saveToXMLFile", function()
        it("does nothing when spec_workflowManagerSpec is nil", function()
            local written = {}
            local xml = { setValue = function(_, k, v) written[k] = v end }
            local v = { spec_workflowManagerSpec = nil }
            assert.has_no.errors(function()
                WorkflowManagerSpec.saveToXMLFile(v, xml, BASE_KEY, {})
            end)
            assert.is_nil(next(written))  -- nothing written
        end)

        it("does nothing when wmExecution is nil (no active workflow)", function()
            local written = {}
            local xml = { setValue = function(_, k, v) written[k] = v end }
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)  -- wmExecution = nil
            WorkflowManagerSpec.saveToXMLFile(v, xml, BASE_KEY, {})
            assert.is_nil(next(written))
        end)

        it("writes workflowId, currentStep, and isMainVehicle for a main vehicle", function()
            local wf = { id = "wf_save_001", name = "Save Test", steps = {} }
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            v.spec_workflowManagerSpec.wmExecution = {
                workflow      = wf,
                currentStep   = 2,
                isMainVehicle = true,
            }

            local xml = makeSavegameXML()
            WorkflowManagerSpec.saveToXMLFile(v, xml, BASE_KEY, {})

            assert.are.equal("wf_save_001", xml._data[BASE_KEY .. "#workflowId"])
            assert.are.equal(2,              xml._data[BASE_KEY .. "#currentStep"])
            assert.is_true(                  xml._data[BASE_KEY .. "#isMainVehicle"])
        end)

        it("does NOT write currentSupportStep for a main vehicle", function()
            local wf = { id = "wf_save_main", name = "Main Save", steps = {} }
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            v.spec_workflowManagerSpec.wmExecution = {
                workflow      = wf,
                currentStep   = 1,
                isMainVehicle = true,
            }

            local xml = makeSavegameXML()
            WorkflowManagerSpec.saveToXMLFile(v, xml, BASE_KEY, {})

            assert.is_nil(xml._data[BASE_KEY .. "#currentSupportStep"])
        end)

        it("writes currentSupportStep for a support vehicle", function()
            local wf = { id = "wf_save_sup", name = "Support Save", steps = {} }
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            v.spec_workflowManagerSpec.wmExecution = {
                workflow           = wf,
                currentStep        = 2,
                isMainVehicle      = false,
                currentSupportStep = 3,
            }

            local xml = makeSavegameXML()
            WorkflowManagerSpec.saveToXMLFile(v, xml, BASE_KEY, {})

            assert.are.equal(3, xml._data[BASE_KEY .. "#currentSupportStep"])
            assert.is_false(    xml._data[BASE_KEY .. "#isMainVehicle"])
        end)

        it("save/restore round-trip preserves all fields", function()
            local wf = { id = "wf_rt_spec", name = "Round-Trip", steps = {} }
            _G.WorkflowManager.workflows = { wf }

            local v1 = makeVehicle("Writer")
            WorkflowManagerSpec.onLoad(v1, nil)
            v1.spec_workflowManagerSpec.wmExecution = {
                workflow           = wf,
                currentStep        = 4,
                isMainVehicle      = false,
                currentSupportStep = 2,
            }

            -- Save
            local xml = makeSavegameXML()
            WorkflowManagerSpec.saveToXMLFile(v1, xml, BASE_KEY, {})

            -- Restore on a fresh vehicle
            local v2 = makeVehicle("Reader")
            WorkflowManagerSpec.onLoad(v2, nil)
            local sg = { key = "vehicles.vehicle(0)", resetVehicles = false, xmlFile = xml }
            WorkflowManagerSpec.onPostLoad(v2, sg)

            local d = v2.spec_workflowManagerSpec.wmExecution
            assert.are.equal(wf,    d.workflow)
            assert.are.equal(4,     d.currentStep)
            assert.are.equal(false, d.isMainVehicle)
            assert.are.equal(2,     d.currentSupportStep)
            assert.are.equal("paused", d.status)
        end)

        it("saves leaderVehicleIndex when leaderVehicle is set", function()
            local wf = { id = "wf_lv_save", name = "LV Save", steps = {} }
            local leaderV = makeVehicle("Leader")
            local followerV = makeVehicle("Follower")
            _G.g_currentMission.vehicles = { leaderV, followerV }
            WorkflowManagerSpec.onLoad(followerV, nil)
            followerV.spec_workflowManagerSpec.wmExecution = {
                workflow      = wf,
                currentStep   = 1,
                isMainVehicle = true,
                leaderVehicle = leaderV,
            }

            local xml = makeSavegameXML()
            WorkflowManagerSpec.saveToXMLFile(followerV, xml, BASE_KEY, {})

            assert.are.equal(1, xml._data[BASE_KEY .. "#leaderVehicleIndex"])
        end)

        it("save/restore round-trip preserves leaderVehicle", function()
            local wf = { id = "wf_lv_rt", name = "LV Round-Trip", steps = {} }
            _G.WorkflowManager.workflows = { wf }
            local leaderV = makeVehicle("Leader")
            local followerV = makeVehicle("Follower")
            _G.g_currentMission.vehicles = { leaderV, followerV }

            WorkflowManagerSpec.onLoad(followerV, nil)
            followerV.spec_workflowManagerSpec.wmExecution = {
                workflow      = wf,
                currentStep   = 2,
                isMainVehicle = true,
                leaderVehicle = leaderV,
            }

            local xml = makeSavegameXML()
            WorkflowManagerSpec.saveToXMLFile(followerV, xml, BASE_KEY, {})

            local v2 = makeVehicle("Reader")
            WorkflowManagerSpec.onLoad(v2, nil)
            local sg = { key = "vehicles.vehicle(0)", resetVehicles = false, xmlFile = xml }
            WorkflowManagerSpec.onPostLoad(v2, sg)

            local d = v2.spec_workflowManagerSpec.wmExecution
            assert.are.equal(leaderV, d.leaderVehicle)
            assert.are.equal(2, d.currentStep)
        end)

        it("restores nil leaderVehicle when index is absent", function()
            local wf = { id = "wf_lv_nil", name = "LV Nil", steps = {} }
            _G.WorkflowManager.workflows = { wf }
            local v1 = makeVehicle("Writer")
            WorkflowManagerSpec.onLoad(v1, nil)
            v1.spec_workflowManagerSpec.wmExecution = {
                workflow      = wf,
                currentStep   = 1,
                isMainVehicle = true,
            }

            local xml = makeSavegameXML()
            WorkflowManagerSpec.saveToXMLFile(v1, xml, BASE_KEY, {})

            local v2 = makeVehicle("Reader")
            WorkflowManagerSpec.onLoad(v2, nil)
            local sg = { key = "vehicles.vehicle(0)", resetVehicles = false, xmlFile = xml }
            WorkflowManagerSpec.onPostLoad(v2, sg)

            assert.is_nil(v2.spec_workflowManagerSpec.wmExecution.leaderVehicle)
        end)
    end)

    -- =========================================================================
    -- onWriteStream / onReadStream (multiplayer mid-session join)
    -- =========================================================================
    describe("onWriteStream / onReadStream", function()
        -- Shared stream buffer for write→read round-trip
        local streamBuf, readPos

        before_each(function()
            streamBuf = {}
            readPos   = 1

            _G.streamWriteBool   = function(_, v) table.insert(streamBuf, {t="b", v=v}) end
            _G.streamWriteString = function(_, v) table.insert(streamBuf, {t="s", v=v}) end
            _G.streamWriteInt32  = function(_, v) table.insert(streamBuf, {t="i", v=v}) end

            _G.streamReadBool   = function(_) local e=streamBuf[readPos]; readPos=readPos+1; return e and e.v end
            _G.streamReadString = function(_) local e=streamBuf[readPos]; readPos=readPos+1; return e and e.v end
            _G.streamReadInt32  = function(_) local e=streamBuf[readPos]; readPos=readPos+1; return e and e.v end
        end)

        it("onWriteStream writes false when no active workflow", function()
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)  -- wmExecution = nil
            WorkflowManagerSpec.onWriteStream(v, 1, nil)

            assert.are.equal(1, #streamBuf)
            assert.is_false(streamBuf[1].v)
        end)

        it("onWriteStream writes all fields when workflow is active", function()
            local wf = { id = "wf_ws_001", name = "WriteStream Test", steps = {} }
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            v.spec_workflowManagerSpec.wmExecution = {
                workflow           = wf,
                currentStep        = 3,
                status             = "running",
                isMainVehicle      = true,
                currentSupportStep = nil,
                waitingForMainStep = false,
            }

            WorkflowManagerSpec.onWriteStream(v, 1, nil)

            -- Expected sequence: true, wfId, step, status, isMain, supportStep(0), waitingForMain
            assert.are.equal(7, #streamBuf)
            assert.is_true(  streamBuf[1].v)            -- isActive = true
            assert.are.equal("wf_ws_001", streamBuf[2].v)
            assert.are.equal(3,           streamBuf[3].v)
            assert.are.equal("running",   streamBuf[4].v)
            assert.is_true(  streamBuf[5].v)            -- isMainVehicle
            assert.are.equal(0,           streamBuf[6].v)  -- currentSupportStep nil → 0
            assert.is_false( streamBuf[7].v)            -- waitingForMainStep
        end)

        it("onReadStream does nothing when isActive=false", function()
            -- Prime buffer with a single false
            streamBuf = {{t="b", v=false}}

            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            WorkflowManagerSpec.onReadStream(v, 1, nil)

            assert.is_nil(v.spec_workflowManagerSpec.wmExecution)
        end)

        it("onReadStream rebuilds wmExecution from stream data", function()
            local wf = { id = "wf_rs_001", name = "ReadStream Test", steps = {} }
            _G.WorkflowManager.workflows = { wf }

            -- Fill buffer as if onWriteStream had run
            local writer = makeVehicle("Writer")
            WorkflowManagerSpec.onLoad(writer, nil)
            writer.spec_workflowManagerSpec.wmExecution = {
                workflow           = wf,
                currentStep        = 2,
                status             = "paused",
                isMainVehicle      = true,
                currentSupportStep = nil,
                waitingForMainStep = false,
            }
            WorkflowManagerSpec.onWriteStream(writer, 1, nil)

            -- Now read into a fresh vehicle
            local reader = makeVehicle("Reader")
            WorkflowManagerSpec.onLoad(reader, nil)
            WorkflowManagerSpec.onReadStream(reader, 1, nil)

            local d = reader.spec_workflowManagerSpec.wmExecution
            assert.is_not_nil(d)
            assert.are.equal(wf,       d.workflow)
            assert.are.equal(2,        d.currentStep)
            assert.are.equal("paused", d.status)
            assert.is_true(            d.isMainVehicle)
            assert.is_nil(             d.currentSupportStep)
        end)

        it("onReadStream adds vehicle to WMExecutor.activeVehicles", function()
            local wf = { id = "wf_rs_av", name = "ActiveVehicles", steps = {} }
            _G.WorkflowManager.workflows = { wf }

            local writer = makeVehicle("Writer")
            WorkflowManagerSpec.onLoad(writer, nil)
            writer.spec_workflowManagerSpec.wmExecution = {
                workflow = wf, currentStep = 1, status = "running",
                isMainVehicle = true, currentSupportStep = nil, waitingForMainStep = false,
            }
            WorkflowManagerSpec.onWriteStream(writer, 1, nil)

            local reader = makeVehicle("Reader")
            WorkflowManagerSpec.onLoad(reader, nil)
            WorkflowManagerSpec.onReadStream(reader, 1, nil)

            assert.is_true(_G.WMExecutor.activeVehicles[reader] == true)
        end)

        it("onReadStream logs a warning and skips when workflowId is unknown", function()
            _G.WorkflowManager.workflows = {}  -- no workflows → getWorkflowById returns nil

            -- Build a stream that claims a workflow exists
            streamBuf = {
                {t="b", v=true},
                {t="s", v="wf_ghost"},
                {t="i", v=1},
                {t="s", v="running"},
                {t="b", v=true},
                {t="i", v=0},
                {t="b", v=false},
            }

            local reader = makeVehicle("Reader")
            WorkflowManagerSpec.onLoad(reader, nil)
            WorkflowManagerSpec.onReadStream(reader, 1, nil)

            assert.is_nil(reader.spec_workflowManagerSpec.wmExecution)
            assert.are.equal(1, #_G.WMLogger.calls.warning)
        end)

        it("onReadStream shows HUD when vehicle is the controlled vehicle", function()
            local wf = { id = "wf_rs_hud", name = "HUD Test", steps = {} }
            _G.WorkflowManager.workflows = { wf }

            local reader = makeVehicle("Controlled")
            WorkflowManagerSpec.onLoad(reader, nil)
            _G.g_currentMission.controlledVehicle = reader  -- player is IN this vehicle

            local hudShownVehicle = nil
            _G.WMHud.show = function(_, v) hudShownVehicle = v end

            streamBuf = {
                {t="b", v=true},
                {t="s", v="wf_rs_hud"},
                {t="i", v=1},
                {t="s", v="running"},
                {t="b", v=true},
                {t="i", v=0},
                {t="b", v=false},
            }
            WorkflowManagerSpec.onReadStream(reader, 1, nil)

            assert.are.equal(reader, hudShownVehicle)
        end)

        it("onReadStream restores support vehicle with currentSupportStep", function()
            local wf = { id = "wf_rs_sup", name = "Support Stream", steps = {} }
            _G.WorkflowManager.workflows = { wf }

            local writer = makeVehicle("SupportWriter")
            WorkflowManagerSpec.onLoad(writer, nil)
            writer.spec_workflowManagerSpec.wmExecution = {
                workflow = wf, currentStep = 2, status = "running",
                isMainVehicle = false, currentSupportStep = 2, waitingForMainStep = false,
            }
            WorkflowManagerSpec.onWriteStream(writer, 1, nil)

            local reader = makeVehicle("SupportReader")
            WorkflowManagerSpec.onLoad(reader, nil)
            WorkflowManagerSpec.onReadStream(reader, 1, nil)

            local d = reader.spec_workflowManagerSpec.wmExecution
            assert.are.equal(false, d.isMainVehicle)
            assert.are.equal(2,     d.currentSupportStep)
        end)
    end)

    -- =========================================================================
    -- onDelete
    -- =========================================================================
    describe("onDelete", function()
        it("does nothing when no active workflow", function()
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            assert.has_no.errors(function()
                WorkflowManagerSpec.onDelete(v)
            end)
        end)

        it("calls WMExecutor:stopWorkflow when an active workflow exists", function()
            local stopCalled = false
            _G.WMExecutor.stopWorkflow = function(_, vehicle)
                stopCalled = true
            end

            local wf = { id = "wf_del_001", name = "Delete Test", steps = {} }
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            v.spec_workflowManagerSpec.wmExecution = {
                workflow = wf, currentStep = 1, status = "running",
            }

            WorkflowManagerSpec.onDelete(v)

            assert.is_true(stopCalled)
        end)

        it("clears the actionEvents table", function()
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            v.spec_workflowManagerSpec.actionEvents["WM_TOGGLE_HUD"] = "event_001"

            WorkflowManagerSpec.onDelete(v)

            assert.is_nil(v.spec_workflowManagerSpec.actionEvents["WM_TOGGLE_HUD"])
        end)

        it("does not crash when WMExecutor:stopWorkflow errors", function()
            _G.WMExecutor.stopWorkflow = function() error("simulated stop error") end

            local wf = { id = "wf_del_err", name = "Error on Delete", steps = {} }
            local v = makeVehicle()
            WorkflowManagerSpec.onLoad(v, nil)
            v.spec_workflowManagerSpec.wmExecution = {
                workflow = wf, currentStep = 1, status = "running",
            }

            -- onDelete wraps the stop call in pcall, so this must not propagate
            assert.has_no.errors(function()
                WorkflowManagerSpec.onDelete(v)
            end)
        end)
    end)

end)
