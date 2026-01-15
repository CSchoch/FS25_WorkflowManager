--[[
    WorkflowManager - Courseplay Courses Loader
    Loads saved Courseplay courses from the user's modSettings directory

    Courses are stored in: [UserProfile]/modSettings/FS25_Courseplay/Courses/[MapId]/
    Each course is an XML file with course data

    Author: WorkflowManager Team
]]

---@class CPCoursesLoader
CPCoursesLoader = {}

CPCoursesLoader.isInitialized = false
CPCoursesLoader.courses = {}
CPCoursesLoader.coursesDirectory = nil
CPCoursesLoader.lastScanTime = 0
CPCoursesLoader.scanInterval = 5000  -- Rescan every 5 seconds

---Initialize the courses loader
function CPCoursesLoader:init()
    self.isInitialized = true
    self.courses = {}
    self.lastScanTime = 0

    -- Get the courses directory path
    self.coursesDirectory = self:getCoursesDirectory()

    if self.coursesDirectory then
        WMLogger:info("Courseplay courses directory: %s", self.coursesDirectory)
        -- Do initial scan
        self:scanCourses()
    else
        WMLogger:warning("Could not determine Courseplay courses directory")
    end
end

---Get the Courseplay courses directory path
---@return string|nil directory Path to courses directory or nil
function CPCoursesLoader:getCoursesDirectory()
    -- Get user profile path
    local userProfile = getUserProfileAppPath()
    if not userProfile then
        WMLogger:error("Could not get user profile path")
        return nil
    end

    -- Get current map ID
    local mapId = nil
    if g_currentMission and g_currentMission.missionInfo then
        mapId = g_currentMission.missionInfo.mapId
        if not mapId or mapId == "" then
            -- Fallback: try to get from map title or filename
            local mapTitle = g_currentMission.missionInfo.mapTitle
            if mapTitle and mapTitle ~= "" then
                -- Clean up map title to use as directory name
                mapId = mapTitle:gsub("[^%w_]", "")
            end
        end
    end

    if not mapId or mapId == "" then
        WMLogger:error("Could not determine map ID")
        return nil
    end

    -- Construct path: [UserProfile]/modSettings/FS25_Courseplay/Courses/[MapId]/
    local coursesPath = userProfile .. "modSettings/FS25_Courseplay/Courses/" .. mapId .. "/"

    return coursesPath
end

---Scan the courses directory and load course names
function CPCoursesLoader:scanCourses()
    if not self.coursesDirectory then
        return
    end

    self.courses = {}

    -- Check if directory exists
    if not fileExists(self.coursesDirectory) then
        WMLogger:debug("Courseplay courses directory does not exist: %s", self.coursesDirectory)
        return
    end

    -- Get all XML files in the directory
    local files = self:getFilesInDirectory(self.coursesDirectory, ".xml")

    if not files or #files == 0 then
        WMLogger:debug("No course files found in: %s", self.coursesDirectory)
        return
    end

    WMLogger:info("Found %d course file(s), parsing...", #files)

    -- Parse each file to get course name
    for _, filename in ipairs(files) do
        local courseName = self:parseCourseName(filename)
        if courseName then
            table.insert(self.courses, courseName)
            WMLogger:debug("Loaded course: %s", courseName)
        end
    end

    -- Sort courses alphabetically
    table.sort(self.courses)

    WMLogger:info("Loaded %d Courseplay course(s)", #self.courses)
end

---Get all files with a specific extension in a directory
---@param directory string Directory path
---@param extension string File extension (e.g., ".xml")
---@return table files List of file paths
function CPCoursesLoader:getFilesInDirectory(directory, extension)
    local files = {}

    -- Use Giants Engine file system API
    -- FS25 uses fileExists, createFolder, and directory iteration

    -- Try to iterate directory using FS25's file system
    local i = 0
    while true do
        local filename = getXMLFileNameFromIdx(directory, i)
        if not filename then
            break
        end

        if filename:sub(-#extension) == extension then
            table.insert(files, directory .. filename)
        end

        i = i + 1
    end

    -- Alternative method: use LuaFileSystem if available
    if #files == 0 and lfs then
        for file in lfs.dir(directory) do
            if file ~= "." and file ~= ".." then
                local filepath = directory .. file
                local attr = lfs.attributes(filepath)
                if attr and attr.mode == "file" and file:sub(-#extension) == extension then
                    table.insert(files, filepath)
                end
            end
        end
    end

    return files
end

---Parse a course file to extract the course name
---@param filepath string Path to course XML file
---@return string|nil courseName Course name or nil
function CPCoursesLoader:parseCourseName(filepath)
    -- Try to load the XML file
    local xmlFile = loadXMLFile("courseFile", filepath)
    if not xmlFile then
        WMLogger:warning("Could not load course file: %s", filepath)
        return nil
    end

    -- Try to get course name from XML
    -- Courseplay course XML structure varies, try multiple common locations
    local courseName = getXMLString(xmlFile, "course#name")

    if not courseName or courseName == "" then
        -- Try alternative path
        courseName = getXMLString(xmlFile, "course.name#value")
    end

    if not courseName or courseName == "" then
        -- Fallback: use filename without extension
        local filename = filepath:match("([^/\\]+)%.xml$")
        if filename then
            courseName = filename
        end
    end

    delete(xmlFile)

    return courseName
end

---Update function - periodically rescan for new courses
---@param dt number Delta time in milliseconds
function CPCoursesLoader:update(dt)
    if not self.isInitialized or not self.coursesDirectory then
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
