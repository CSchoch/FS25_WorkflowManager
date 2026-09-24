--[[
    CPIntegration Unit Tests — course entry resolution

    Focus: course names are stored as ROOT-relative paths ("Folder/Course"), so lookup must
    start at rootDirectoryView. currentDirectoryView follows whatever folder the player last
    opened in Courseplay's own course manager, so resolving against it silently fails (or finds
    the wrong file) depending on where they happened to be.

    Also covers the fallback search by base name, which keeps course names recorded before
    that fix (bare names captured from inside a subfolder) loadable.
]]

describe("CPIntegration (course resolution)", function()

    setup(function()
        dofile("src/integration/CourseplayIntegration.lua")
    end)

    -- -------------------------------------------------------------------------
    -- Fake Courseplay FileSystem / DirectoryView
    -- -------------------------------------------------------------------------

    -- A course file entry. `entity` is what the real appendLoadedCpCourse() consumes.
    local function file(name)
        return { name = name, isDirectory = false, entity = { fileName = name } }
    end

    -- A folder entry that is also its own view (Courseplay's DirectoryView shape)
    local function folder(name, children)
        local f
        f = {
            name = name,
            isDirectory = true,
            getEntries = function() return children end,
            getView = function() return f end,
        }
        return f
    end

    local function view(children)
        return { getEntries = function() return children end }
    end

    --  root/
    --    Root Course
    --    Farm1/
    --      Field A
    --      Deep/
    --        Buried Course
    --    Farm2/
    --      Field A          <- same base name as Farm1/Field A
    local function makeStorage()
        local deep  = folder("Deep",  { file("Buried Course") })
        local farm1 = folder("Farm1", { file("Field A"), deep })
        local farm2 = folder("Farm2", { file("Field B") })
        local root  = view({ file("Root Course"), farm1, farm2 })
        return {
            rootDirectoryView = root,
            -- The player happens to be sitting inside Farm2 in Courseplay's own GUI
            currentDirectoryView = farm2,
        }, root, farm1, farm2
    end

    -- Vehicle that records which entry was handed to appendLoadedCpCourse
    local function makeVehicle()
        local v = { loaded = nil }
        v.appendLoadedCpCourse = function(self, entity) self.loaded = entity end
        return v
    end

    -- =========================================================================
    -- Entry-shape helpers
    -- =========================================================================
    describe("isDirectoryEntry", function()
        it("detects a boolean isDirectory field", function()
            assert.is_true(CPIntegration:isDirectoryEntry({ isDirectory = true }))
            assert.is_false(CPIntegration:isDirectoryEntry({ isDirectory = false }))
        end)

        it("detects an isDirectory() method", function()
            assert.is_true(CPIntegration:isDirectoryEntry({ isDirectory = function() return true end }))
            assert.is_false(CPIntegration:isDirectoryEntry({ isDirectory = function() return false end }))
        end)

        it("detects a getIsDirectory() method", function()
            assert.is_true(CPIntegration:isDirectoryEntry({ getIsDirectory = function() return true end }))
        end)

        it("returns false for a plain entry or nil", function()
            assert.is_false(CPIntegration:isDirectoryEntry({ name = "x" }))
            assert.is_false(CPIntegration:isDirectoryEntry(nil))
        end)

        -- ModHub's TestRunner rejects pcall: a Courseplay error must reach the game log, not vanish
        it("lets an error from a throwing isDirectory() reach the log", function()
            local ok = pcall(CPIntegration.isDirectoryEntry, CPIntegration,
                { isDirectory = function() error("boom") end })
            assert.is_false(ok)
        end)
    end)

    describe("getEntryName", function()
        it("prefers the name field", function()
            assert.are.equal("A", CPIntegration:getEntryName({ name = "A" }))
        end)

        it("falls back to getName()", function()
            assert.are.equal("B", CPIntegration:getEntryName({ getName = function() return "B" end }))
        end)

        it("returns empty string for nil or nameless entries", function()
            assert.are.equal("", CPIntegration:getEntryName(nil))
            assert.are.equal("", CPIntegration:getEntryName({}))
        end)
    end)

    -- =========================================================================
    -- findCourseEntry: resolve from root
    -- =========================================================================
    describe("findCourseEntry", function()
        it("finds a root-level course", function()
            local _, root = makeStorage()
            local entry = CPIntegration:findCourseEntry(root, "", "Root Course")
            assert.is_not_nil(entry)
            assert.are.equal("Root Course", entry.name)
        end)

        it("finds a course inside a folder via its path", function()
            local _, root = makeStorage()
            local entry = CPIntegration:findCourseEntry(root, "Farm1", "Field A")
            assert.is_not_nil(entry)
            assert.are.equal("Field A", entry.name)
        end)

        it("finds a course in a nested folder via its path", function()
            local _, root = makeStorage()
            local entry = CPIntegration:findCourseEntry(root, "Farm1/Deep", "Buried Course")
            assert.is_not_nil(entry)
            assert.are.equal("Buried Course", entry.name)
        end)

        it("never returns a folder when a course shares its name", function()
            local _, root = makeStorage()
            assert.is_nil(CPIntegration:findCourseEntry(root, "", "Farm1"))
        end)

        it("returns nil when nothing matches anywhere", function()
            local _, root = makeStorage()
            assert.is_nil(CPIntegration:findCourseEntry(root, "Farm1", "No Such Course"))
        end)

        -- Legacy names: recorded as bare names while Courseplay sat inside a subfolder
        it("falls back to a recursive search for a bare legacy name", function()
            local _, root = makeStorage()
            local entry = CPIntegration:findCourseEntry(root, "", "Field A")
            assert.is_not_nil(entry)
            assert.are.equal("Field A", entry.name)
        end)

        it("falls back to a recursive search for a deeply nested bare name", function()
            local _, root = makeStorage()
            local entry = CPIntegration:findCourseEntry(root, "", "Buried Course")
            assert.is_not_nil(entry)
            assert.are.equal("Buried Course", entry.name)
        end)

        -- Course moved to a different folder since the workflow was authored
        it("falls back to a recursive search when the stated folder is wrong", function()
            local _, root = makeStorage()
            local entry = CPIntegration:findCourseEntry(root, "Farm2", "Buried Course")
            assert.is_not_nil(entry)
            assert.are.equal("Buried Course", entry.name)
        end)

        it("falls back to a recursive search when the folder does not exist", function()
            local _, root = makeStorage()
            local entry = CPIntegration:findCourseEntry(root, "Nope", "Root Course")
            assert.is_not_nil(entry)
            assert.are.equal("Root Course", entry.name)
        end)

        -- Names recorded before enumeration moved to the root view are missing the leading
        -- segment ("F34/Kalken" for what the root view calls "Singleplayer/F34/Kalken").
        -- The folder walk fails, and the fallback must NOT grab the first same-named file.
        --  root/
        --    Singleplayer/
        --      F09/ Kalken     <- sorted first, the wrong one
        --      F34/ Kalken
        local function makeLegacyStorage()
            local f09  = folder("F09", { file("Kalken") })
            local f34  = folder("F34", { file("Kalken") })
            local sp   = folder("Singleplayer", { f09, f34 })
            local root = view({ sp })
            return root, f09.getEntries()[1], f34.getEntries()[1]
        end

        it("resolves a legacy path by matching the folder path suffix", function()
            local root, _, wanted = makeLegacyStorage()
            local entry = CPIntegration:findCourseEntry(root, "F34", "Kalken")
            assert.are.equal(wanted, entry)
        end)

        it("still resolves the same course by its full current path", function()
            local root, _, wanted = makeLegacyStorage()
            local entry = CPIntegration:findCourseEntry(root, "Singleplayer/F34", "Kalken")
            assert.are.equal(wanted, entry)
        end)

        it("matches the suffix on a multi-segment legacy path", function()
            local root, _, wanted = makeLegacyStorage()
            local entry = CPIntegration:findCourseEntry(root, "Singleplayer/F34", "Kalken")
            assert.are.equal(wanted, entry)
            assert.are.equal(wanted, CPIntegration:findCourseEntry(root, "F34", "Kalken"))
        end)

        it("does not treat a partial folder-name match as a suffix", function()
            -- "34" is not the folder "F34"; with no real suffix match it falls back by name
            local root, first = makeLegacyStorage()
            assert.are.equal(first, CPIntegration:findCourseEntry(root, "34", "Kalken"))
        end)

        -- The suffix match must not depend on the root child being named "Singleplayer".
        -- Courseplay hardcodes that name, but the resolution rule is about path shape, not
        -- about any particular prefix, and must survive Courseplay renaming it.
        it("is independent of what the root-level folder is called", function()
            local f09  = folder("F09", { file("Kalken") })
            local f34  = folder("F34", { file("Kalken") })
            local root = view({ folder("SomeOtherRootName", { f09, f34 }) })
            assert.are.equal(f34.getEntries()[1], CPIntegration:findCourseEntry(root, "F34", "Kalken"))
        end)
    end)

    -- =========================================================================
    -- loadCourseFromStorage: root, not currentDirectoryView
    -- =========================================================================
    describe("loadCourseFromStorage", function()
        it("resolves from the root even when Courseplay sits in another folder", function()
            -- currentDirectoryView is Farm2; "Farm1/Field A" only resolves from the root
            local storage = makeStorage()
            local v = makeVehicle()
            assert.is_true(CPIntegration:loadCourseFromStorage(v, storage, "Farm1/Field A"))
            assert.are.equal("Field A", v.loaded.fileName)
        end)

        it("finds root-level courses that currentDirectoryView cannot see", function()
            local storage = makeStorage()
            local v = makeVehicle()
            assert.is_true(CPIntegration:loadCourseFromStorage(v, storage, "Root Course"))
            assert.are.equal("Root Course", v.loaded.fileName)
        end)

        it("loads a nested course by its full path", function()
            local storage = makeStorage()
            local v = makeVehicle()
            assert.is_true(CPIntegration:loadCourseFromStorage(v, storage, "Farm1/Deep/Buried Course"))
            assert.are.equal("Buried Course", v.loaded.fileName)
        end)

        it("still loads a bare legacy course name", function()
            local storage = makeStorage()
            local v = makeVehicle()
            assert.is_true(CPIntegration:loadCourseFromStorage(v, storage, "Buried Course"))
            assert.are.equal("Buried Course", v.loaded.fileName)
        end)

        it("returns false for an unknown course without loading anything", function()
            local storage = makeStorage()
            local v = makeVehicle()
            assert.is_false(CPIntegration:loadCourseFromStorage(v, storage, "Farm1/Ghost"))
            assert.is_nil(v.loaded)
        end)

        it("returns false when storage is nil", function()
            assert.is_false(CPIntegration:loadCourseFromStorage(makeVehicle(), nil, "Any"))
        end)

        it("returns false when the storage exposes no directory view at all", function()
            assert.is_false(CPIntegration:loadCourseFromStorage(makeVehicle(), {}, "Any"))
        end)

        it("uses currentDirectoryView only when there is no root view", function()
            local storage = makeStorage()
            storage.rootDirectoryView = nil   -- Farm2 remains as currentDirectoryView
            local v = makeVehicle()
            assert.is_true(CPIntegration:loadCourseFromStorage(v, storage, "Field B"))
            assert.are.equal("Field B", v.loaded.fileName)
        end)
    end)

    -- =========================================================================
    -- navigateToFolder
    -- =========================================================================
    describe("navigateToFolder", function()
        it("walks a multi-segment path", function()
            local _, root = makeStorage()
            local target = CPIntegration:navigateToFolder(root, "Farm1/Deep")
            assert.is_not_nil(target)
            assert.are.equal("Deep", target.name)
        end)

        it("returns nil for a missing folder", function()
            local _, root = makeStorage()
            assert.is_nil(CPIntegration:navigateToFolder(root, "Farm1/Missing"))
        end)

        it("does not step into a course file that shares the folder name", function()
            local _, root = makeStorage()
            assert.is_nil(CPIntegration:navigateToFolder(root, "Root Course"))
        end)
    end)

    -- =========================================================================
    -- Resume waypoint (savegame load)
    --
    -- Courseplay only writes its own #rememberedWpIx when a job stops cleanly, never while
    -- driving, so WM reads the live strategy's own "best waypoint to continue" at save time.
    -- =========================================================================
    describe("resume waypoint", function()
        -- These helpers gate on isAvailable, unlike the pure entry-shape helpers above.
        -- Re-armed per test because one case below deliberately switches it off.
        before_each(function()
            CPIntegration.isAvailable = true
        end)

        -- Vehicle driving a field work course, with CP's strategy attached
        local function drivingVehicle(bestWaypoint, rememberedIx)
            local v = { remembered = nil }
            v.getCpDriveStrategy = function()
                if bestWaypoint == nil then
                    return { }  -- e.g. bale finder / combine unloader: no fieldwork method
                end
                return {
                    fieldWorkCourse = {},
                    getBestWaypointToContinueFieldWork = function() return bestWaypoint end,
                }
            end
            v.getCpLastRememberedWaypointIx = function() return rememberedIx end
            v.rememberCpLastWaypointIx = function(self, ix) self.remembered = ix end
            return v
        end

        describe("getResumeWaypointIx", function()
            it("prefers the live drive strategy over the remembered index", function()
                assert.are.equal(42, CPIntegration:getResumeWaypointIx(drivingVehicle(42, 7)))
            end)

            it("falls back to the remembered index when the strategy has no fieldwork method", function()
                assert.are.equal(7, CPIntegration:getResumeWaypointIx(drivingVehicle(nil, 7)))
            end)

            it("returns nil when neither source yields a waypoint", function()
                assert.is_nil(CPIntegration:getResumeWaypointIx(drivingVehicle(nil, nil)))
            end)

            it("returns nil for a vehicle without the Courseplay functions", function()
                assert.is_nil(CPIntegration:getResumeWaypointIx({}))
            end)

            it("returns nil for a nil vehicle or when CP is unavailable", function()
                assert.is_nil(CPIntegration:getResumeWaypointIx(nil))
                CPIntegration.isAvailable = false
                assert.is_nil(CPIntegration:getResumeWaypointIx(drivingVehicle(42, 7)))
            end)

            -- The real getBestWaypointToContinueFieldWork indexes self.fieldWorkCourse unguarded,
            -- and this runs during savegame writing - so it must never be reached without one.
            it("skips a strategy without a field work course and falls back to the remembered index", function()
                local called = false
                local v = {
                    getCpDriveStrategy = function()
                        return { getBestWaypointToContinueFieldWork = function() called = true return 42 end }
                    end,
                    getCpLastRememberedWaypointIx = function() return 5 end,
                }
                assert.are.equal(5, CPIntegration:getResumeWaypointIx(v))
                assert.is_false(called)
            end)
        end)

        describe("getProgress", function()
            it("reads progress from a field work strategy", function()
                local v = { getCpDriveStrategy = function()
                    return { fieldWorkCourse = {}, getProgress = function() return 0.25 end }
                end }
                assert.are.equal(0.25, CPIntegration:getProgress(v))
            end)

            -- Regression: while CP starts, the active strategy has no getProgress. CP's own
            -- getCpFieldWorkProgress calls it anyway and errored on every HUD draw frame.
            it("returns nil for a strategy without getProgress and never uses getCpFieldWorkProgress", function()
                local v = {
                    getCpDriveStrategy = function() return {} end,
                    getCpFieldWorkProgress = function() error("must not be called") end,
                }
                assert.is_nil(CPIntegration:getProgress(v))
            end)

            it("returns nil for a strategy without a field work course", function()
                local called = false
                local v = { getCpDriveStrategy = function()
                    return { getProgress = function() called = true return 0.5 end }
                end }
                assert.is_nil(CPIntegration:getProgress(v))
                assert.is_false(called)
            end)

            it("returns nil when no strategy is active", function()
                assert.is_nil(CPIntegration:getProgress({ getCpDriveStrategy = function() return nil end }))
                assert.is_nil(CPIntegration:getProgress({}))
            end)
        end)

        describe("setResumeWaypointIx", function()
            it("hands the waypoint to Courseplay", function()
                local v = drivingVehicle(42, nil)
                assert.is_true(CPIntegration:setResumeWaypointIx(v, 42))
                assert.are.equal(42, v.remembered)
            end)

            it("returns false when the vehicle has no rememberCpLastWaypointIx", function()
                assert.is_false(CPIntegration:setResumeWaypointIx({}, 42))
            end)

            it("returns false for a nil vehicle or nil waypoint", function()
                assert.is_false(CPIntegration:setResumeWaypointIx(nil, 42))
                assert.is_false(CPIntegration:setResumeWaypointIx(drivingVehicle(42, nil), nil))
            end)
        end)
    end)

    -- =========================================================================
    -- Seed type selection (base-game SowingMachine specialization)
    --
    -- Courseplay has no seed setting at all — the seed lives on the attached implement's
    -- spec_sowingMachine. setSeedFruitType() is a silent no-op for a fruit the machine
    -- cannot sow, so membership in spec.seeds has to be checked before calling it.
    -- =========================================================================
    describe("seed type", function()
        local WHEAT, BARLEY, MEADOW, NOSEED = 1, 2, 3, 4

        before_each(function()
            local fruitTypes = {
                {index = WHEAT,  name = "WHEAT"},
                {index = BARLEY, name = "BARLEY"},
                {index = MEADOW, name = "MEADOW"},
                {index = NOSEED, name = "NOSEED"},   -- has no fill type
            }
            local fillTypes = {
                [WHEAT]  = {title = "Wheat"},
                [BARLEY] = {title = "Barley"},
                [MEADOW] = {title = "Meadow"},
            }
            _G.g_fruitTypeManager = {
                getFruitTypes = function() return fruitTypes end,
                getFruitTypeByName = function(_, name)
                    for _, ft in ipairs(fruitTypes) do
                        if ft.name == name then return ft end
                    end
                    return nil
                end,
                getFillTypeByFruitTypeIndex = function(_, index) return fillTypes[index] end,
            }
        end)

        -- An implement carrying the base-game sowing machine specialization
        local function seeder(name, seeds, allowChange)
            local s
            s = {
                spec_sowingMachine = {seeds = seeds},
                applied = nil,
                getName = function() return name end,
                setSeedFruitType = function(_, index) s.applied = index end,
            }
            if allowChange ~= nil then
                s.getIsSeedChangeAllowed = function() return allowChange end
            end
            return s
        end

        local function vehicleWith(children)
            return {getChildVehicles = function() return children end}
        end

        describe("getSeedFruitTypes", function()
            it("lists plantable fruit types sorted by title", function()
                local seeds = CPIntegration:getSeedFruitTypes()
                assert.are.equal(2, #seeds)
                assert.are.equal("BARLEY", seeds[1].name)
                assert.are.equal("Barley", seeds[1].title)
                assert.are.equal("WHEAT", seeds[2].name)
            end)

            it("excludes MEADOW and fruits without a fill type", function()
                for _, entry in ipairs(CPIntegration:getSeedFruitTypes()) do
                    assert.is_true(entry.name ~= "MEADOW")
                    assert.is_true(entry.name ~= "NOSEED")
                end
            end)

            it("returns an empty list without a fruit type manager", function()
                _G.g_fruitTypeManager = nil
                assert.are.equal(0, #CPIntegration:getSeedFruitTypes())
            end)
        end)

        describe("applySeedFruitType", function()
            it("selects the seed on the attached sowing machine", function()
                local s = seeder("Seeder", {WHEAT, BARLEY})
                assert.is_true(CPIntegration:applySeedFruitType(vehicleWith({s}), "WHEAT"))
                assert.are.equal(WHEAT, s.applied)
            end)

            it("selects the seed on every sowing machine that supports it", function()
                local a = seeder("A", {WHEAT})
                local b = seeder("B", {WHEAT, BARLEY})
                assert.is_true(CPIntegration:applySeedFruitType(vehicleWith({a, b}), "WHEAT"))
                assert.are.equal(WHEAT, a.applied)
                assert.are.equal(WHEAT, b.applied)
            end)

            it("skips silently when no sowing machine is attached", function()
                local plain = {}
                assert.is_true(CPIntegration:applySeedFruitType(vehicleWith({plain}), "WHEAT"))
            end)

            it("fails when a sowing machine is attached but none can sow the fruit", function()
                local s = seeder("Seeder", {BARLEY})
                local ok, reason = CPIntegration:applySeedFruitType(vehicleWith({s}), "WHEAT")
                assert.is_false(ok)
                assert.is_not_nil(reason)
                assert.is_nil(s.applied)
            end)

            it("succeeds when at least one of several machines can sow the fruit", function()
                local supported = seeder("A", {WHEAT})
                local other     = seeder("B", {BARLEY})
                assert.is_true(CPIntegration:applySeedFruitType(vehicleWith({supported, other}), "WHEAT"))
                assert.are.equal(WHEAT, supported.applied)
                assert.is_nil(other.applied)
            end)

            it("keeps the game's seed when seed changing is not allowed", function()
                local s = seeder("Seeder", {WHEAT}, false)
                assert.is_true(CPIntegration:applySeedFruitType(vehicleWith({s}), "WHEAT"))
                assert.is_nil(s.applied)
            end)

            it("fails for an unknown fruit type name", function()
                local ok, reason = CPIntegration:applySeedFruitType(vehicleWith({seeder("S", {WHEAT})}), "NOTAFRUIT")
                assert.is_false(ok)
                assert.is_not_nil(reason)
            end)

            it("does nothing for a nil or empty seed type", function()
                local s = seeder("Seeder", {WHEAT})
                assert.is_true(CPIntegration:applySeedFruitType(vehicleWith({s}), nil))
                assert.is_true(CPIntegration:applySeedFruitType(vehicleWith({s}), ""))
                assert.is_nil(s.applied)
            end)

            it("tolerates a vehicle without getChildVehicles", function()
                assert.is_true(CPIntegration:applySeedFruitType({}, "WHEAT"))
                assert.is_true(CPIntegration:applySeedFruitType(nil, "WHEAT"))
            end)
        end)
    end)

end)
