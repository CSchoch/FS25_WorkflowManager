--[[
    WorkflowManager - Courseplay Courses Loader
    Loads saved Courseplay courses from the Courseplay API

    Accesses course information through the Courseplay global object
    rather than reading files directly from disk

    Author: WorkflowManager Team
]]

---@class CPCoursesLoader
CPCoursesLoader = {}

CPCoursesLoader.isInitialized = false
CPCoursesLoader.courses = {}
CPCoursesLoader.lastScanTime = 0
CPCoursesLoader.scanInterval = 5000  -- Rescan every 5 seconds

---Initialize the courses loader
function CPCoursesLoader:init()
    self.isInitialized = true
    self.courses = {}
    self.lastScanTime = 0

    -- Do initial scan
    self:scanCourses()
end

---Get the Courseplay global object
---@return table|nil courseplay Courseplay global object or nil
function CPCoursesLoader:getCourseplayObject()
    -- Check if Courseplay integration is available
    if not CPIntegration or not CPIntegration.isAvailable then
        return nil
    end

    -- Try to get the Courseplay global object
    -- In FS25, it's under FS25_Courseplay namespace
    local courseplay = g_Courseplay
    if not courseplay then
        local fs25CP = FS25_Courseplay
        courseplay = fs25CP and (fs25CP.g_Courseplay or fs25CP.Courseplay)
    end

    return courseplay
end

---Scan for available courses from Courseplay API
function CPCoursesLoader:scanCourses()
    self.courses = {}

    -- Get Courseplay object
    local courseplay = self:getCourseplayObject()
    if not courseplay then
        WMLogger:debug("Courseplay not available yet, cannot load courses")
        return
    end

    -- Try different API patterns to access course storage
    local courses = nil

    -- Pattern 1: courseStorage or courseManager property
    if courseplay.courseStorage then
        courses = self:extractCoursesFromStorage(courseplay.courseStorage)
    elseif courseplay.courseManager then
        courses = self:extractCoursesFromStorage(courseplay.courseManager)
    elseif courseplay.CourseStorage then
        courses = self:extractCoursesFromStorage(courseplay.CourseStorage)
    elseif courseplay.CourseManager then
        courses = self:extractCoursesFromStorage(courseplay.CourseManager)
    end

    -- Pattern 2: FileSystem property
    if not courses and courseplay.FileSystem then
        courses = self:extractCoursesFromFileSystem(courseplay.FileSystem)
    end

    -- Pattern 3: AssignedCoursesManager
    if not courses and courseplay.assignedCoursesManager then
        courses = self:extractCoursesFromAssignedManager(courseplay.assignedCoursesManager)
    end

    -- Pattern 4: Direct courses array/table
    if not courses and courseplay.courses then
        courses = self:extractCoursesFromTable(courseplay.courses)
    end

    -- Pattern 5: getCourses() method
    if not courses and type(courseplay.getCourses) == "function" then
        local success, result = pcall(courseplay.getCourses, courseplay)
        if success and result then
            courses = self:extractCoursesFromTable(result)
        end
    end

    -- Pattern 6: getAllCourses() method
    if not courses and type(courseplay.getAllCourses) == "function" then
        local success, result = pcall(courseplay.getAllCourses, courseplay)
        if success and result then
            courses = self:extractCoursesFromTable(result)
        end
    end

    if courses and #courses > 0 then
        self.courses = courses
        table.sort(self.courses)
        WMLogger:info("Loaded %d Courseplay course(s) from API", #self.courses)

        -- Log first few courses for debugging
        if WMDevConfig and WMDevConfig:isDevMode() then
            for i = 1, math.min(5, #self.courses) do
                WMLogger:debug("Course %d: %s", i, self.courses[i])
            end
        end
    else
        WMLogger:debug("No courses found via Courseplay API")

        -- In dev mode, log available properties to help diagnose
        if WMDevConfig and WMDevConfig:isDevMode() and courseplay then
            self:logCourseplayStructure(courseplay)
        end
    end
end

---Log Courseplay object structure for debugging
---@param courseplay table Courseplay object
function CPCoursesLoader:logCourseplayStructure(courseplay)
    WMLogger:debug("Courseplay object properties:")
    local props = {}
    for key, value in pairs(courseplay) do
        local valueType = type(value)
        if valueType == "table" then
            table.insert(props, string.format("  %s: <table>", tostring(key)))
        elseif valueType == "function" then
            table.insert(props, string.format("  %s: <function>", tostring(key)))
        else
            table.insert(props, string.format("  %s: %s", tostring(key), tostring(value)))
        end
    end

    -- Log up to 20 properties
    for i = 1, math.min(20, #props) do
        WMLogger:debug(props[i])
    end

    if #props > 20 then
        WMLogger:debug("  ... (%d more properties)", #props - 20)
    end
end

---Extract course names from a storage object
---@param storage table Storage object
---@return table|nil courses List of course names or nil
function CPCoursesLoader:extractCoursesFromStorage(storage)
    if not storage then
        return nil
    end

    local courses = {}

    -- Try common patterns for storage objects
    -- Pattern 1: storage.courses (array/table)
    if storage.courses then
        local extracted = self:extractCoursesFromTable(storage.courses)
        if extracted then
            return extracted
        end
    end

    -- Pattern 2: storage:getCourses() method
    if type(storage.getCourses) == "function" then
        local success, result = pcall(storage.getCourses, storage)
        if success and result then
            local extracted = self:extractCoursesFromTable(result)
            if extracted then
                return extracted
            end
        end
    end

    -- Pattern 3: storage:getAll() method
    if type(storage.getAll) == "function" then
        local success, result = pcall(storage.getAll, storage)
        if success and result then
            local extracted = self:extractCoursesFromTable(result)
            if extracted then
                return extracted
            end
        end
    end

    return nil
end

---Extract course names from FileSystem object
---@param fileSystem table FileSystem object
---@return table|nil courses List of course names or nil
function CPCoursesLoader:extractCoursesFromFileSystem(fileSystem)
    if not fileSystem then
        return nil
    end

    -- Try to get courses via FileSystem methods
    if type(fileSystem.getCourses) == "function" then
        local success, result = pcall(fileSystem.getCourses, fileSystem)
        if success and result then
            return self:extractCoursesFromTable(result)
        end
    end

    if type(fileSystem.getLoadedCourses) == "function" then
        local success, result = pcall(fileSystem.getLoadedCourses, fileSystem)
        if success and result then
            return self:extractCoursesFromTable(result)
        end
    end

    return nil
end

---Extract course names from AssignedCoursesManager
---@param manager table AssignedCoursesManager object
---@return table|nil courses List of course names or nil
function CPCoursesLoader:extractCoursesFromAssignedManager(manager)
    if not manager then
        return nil
    end

    if type(manager.getCourses) == "function" then
        local success, result = pcall(manager.getCourses, manager)
        if success and result then
            return self:extractCoursesFromTable(result)
        end
    end

    return nil
end

---Extract course names from a table/array
---@param coursesTable table Table containing course data
---@return table|nil courses List of course names or nil
function CPCoursesLoader:extractCoursesFromTable(coursesTable)
    if not coursesTable or type(coursesTable) ~= "table" then
        return nil
    end

    local courses = {}

    -- Check if it's an array of courses
    for _, course in pairs(coursesTable) do
        local courseName = nil

        if type(course) == "string" then
            -- Direct string
            courseName = course
        elseif type(course) == "table" then
            -- Try different name properties
            courseName = course.name or course.courseName or course.title or course.id
        end

        if courseName and type(courseName) == "string" and courseName ~= "" then
            table.insert(courses, courseName)
        end
    end

    return #courses > 0 and courses or nil
end

---Update function - periodically rescan for new courses
---@param dt number Delta time in milliseconds
function CPCoursesLoader:update(dt)
    if not self.isInitialized then
        return
    end

    self.lastScanTime = self.lastScanTime + dt

    if self.lastScanTime >= self.scanInterval then
        self.lastScanTime = 0
        self:scanCourses()
    end
end

---Get list of available courses
---@return table courses List of course names
function CPCoursesLoader:getCourses()
    return self.courses or {}
end

---Get number of available courses
---@return number count Number of courses
function CPCoursesLoader:getCoursesCount()
    return #(self.courses or {})
end

---Check if a course exists by name
---@param courseName string Course name to check
---@return boolean exists True if course exists
function CPCoursesLoader:courseExists(courseName)
    for _, name in ipairs(self.courses or {}) do
        if name == courseName then
            return true
        end
    end
    return false
end
