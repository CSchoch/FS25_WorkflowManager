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

        it("does not propagate an error from a throwing isDirectory()", function()
            assert.is_false(CPIntegration:isDirectoryEntry({ isDirectory = function() error("boom") end }))
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

end)
