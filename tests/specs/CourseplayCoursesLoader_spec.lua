--[[
    CPCoursesLoader Unit Tests — course enumeration

    Focus: courses must be enumerated from rootDirectoryView, producing root-relative names
    ("Folder/Course") that CPIntegration:findCourseEntry can resolve later. Enumerating from
    currentDirectoryView (whichever folder the player last opened in Courseplay's own course
    manager) hides everything outside that folder and yields names relative to it.
]]

describe("CPCoursesLoader (enumeration)", function()

    setup(function()
        -- CPCoursesLoader delegates entry-shape questions to CPIntegration
        dofile("src/integration/CourseplayIntegration.lua")
        dofile("src/integration/CourseplayCoursesLoader.lua")
    end)

    -- -------------------------------------------------------------------------
    -- Fake Courseplay FileSystem / DirectoryView
    -- -------------------------------------------------------------------------
    local function file(name)
        return { name = name, isDirectory = false }
    end

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

    local function view(name, children)
        return { name = name, getEntries = function() return children end }
    end

    --  root/
    --    Root Course
    --    Farm1/
    --      Field A
    --      Deep/
    --        Buried Course
    --    Farm2/
    --      Field B
    local function makeFileSystem()
        local deep  = folder("Deep",  { file("Buried Course") })
        local farm1 = folder("Farm1", { file("Field A"), deep })
        local farm2 = folder("Farm2", { file("Field B") })
        local root  = view("Singleplayer", { file("Root Course"), farm1, farm2 })
        return {
            rootDirectoryView = root,
            -- Player is inside Farm2 in Courseplay's own GUI
            currentDirectoryView = farm2,
        }
    end

    local function contains(list, value)
        for _, v in ipairs(list or {}) do
            if v == value then return true end
        end
        return false
    end

    -- =========================================================================
    -- extractCoursesFromFileSystem
    -- =========================================================================
    describe("extractCoursesFromFileSystem", function()
        it("returns nil for a nil file system", function()
            assert.is_nil(CPCoursesLoader:extractCoursesFromFileSystem(nil))
        end)

        it("enumerates every course regardless of the current folder", function()
            local courses = CPCoursesLoader:extractCoursesFromFileSystem(makeFileSystem())
            assert.is_not_nil(courses)
            assert.are.equal(4, #courses)
        end)

        it("includes courses outside the current folder", function()
            local courses = CPCoursesLoader:extractCoursesFromFileSystem(makeFileSystem())
            assert.is_true(contains(courses, "Root Course"))
            assert.is_true(contains(courses, "Farm1/Field A"))
        end)

        it("names courses relative to the root, not the current folder", function()
            -- Enumerating from currentDirectoryView (Farm2) would yield a bare "Field B"
            local courses = CPCoursesLoader:extractCoursesFromFileSystem(makeFileSystem())
            assert.is_true(contains(courses, "Farm2/Field B"))
            assert.is_false(contains(courses, "Field B"))
        end)

        it("does not prefix the root view's own name", function()
            local courses = CPCoursesLoader:extractCoursesFromFileSystem(makeFileSystem())
            assert.is_false(contains(courses, "Singleplayer/Root Course"))
        end)

        it("builds full paths for nested folders", function()
            local courses = CPCoursesLoader:extractCoursesFromFileSystem(makeFileSystem())
            assert.is_true(contains(courses, "Farm1/Deep/Buried Course"))
        end)

        it("does not list folders as if they were courses", function()
            local courses = CPCoursesLoader:extractCoursesFromFileSystem(makeFileSystem())
            assert.is_false(contains(courses, "Farm1"))
            assert.is_false(contains(courses, "Farm1/Deep"))
        end)

        it("treats a boolean isDirectory field as a folder", function()
            -- Courseplay exposes this as a field on some entry types; if it were mistaken for a
            -- course the folder name itself would appear in the list
            local sub  = { name = "Sub", isDirectory = true,
                           getEntries = function() return { file("Inner") } end }
            local root = view("root", { sub })
            local courses = CPCoursesLoader:extractCoursesFromFileSystem({ rootDirectoryView = root })
            assert.is_true(contains(courses, "Sub/Inner"))
            assert.is_false(contains(courses, "Sub"))
        end)

        it("strips the .xml extension", function()
            local root = view("root", { file("Course.xml") })
            local courses = CPCoursesLoader:extractCoursesFromFileSystem({ rootDirectoryView = root })
            assert.is_true(contains(courses, "Course"))
        end)
    end)

    -- =========================================================================
    -- Fallback: only when the root view yields nothing
    -- =========================================================================
    describe("currentDirectoryView fallback", function()
        it("is used when there is no root view", function()
            local fs = makeFileSystem()
            fs.rootDirectoryView = nil
            local courses = CPCoursesLoader:extractCoursesFromFileSystem(fs)
            assert.is_not_nil(courses)
            assert.is_true(contains(courses, "Field B"))
        end)

        it("is used when the root view is empty", function()
            local fs = makeFileSystem()
            fs.rootDirectoryView = view("root", {})
            local courses = CPCoursesLoader:extractCoursesFromFileSystem(fs)
            assert.is_not_nil(courses)
            assert.is_true(contains(courses, "Field B"))
        end)

        it("is NOT used when the root view returned courses", function()
            local fs = makeFileSystem()
            local courses = CPCoursesLoader:extractCoursesFromFileSystem(fs)
            -- Farm2/Field B appears exactly once, from the root walk - not again from the
            -- fallback walk, which would also have added a bare "Field B"
            local count = 0
            for _, c in ipairs(courses) do
                if c == "Farm2/Field B" then count = count + 1 end
            end
            assert.are.equal(1, count)
            assert.is_false(contains(courses, "Field B"))
        end)

        it("returns nil when neither view yields anything", function()
            local empty = view("root", {})
            assert.is_nil(CPCoursesLoader:extractCoursesFromFileSystem({ rootDirectoryView = empty }))
        end)
    end)

end)
