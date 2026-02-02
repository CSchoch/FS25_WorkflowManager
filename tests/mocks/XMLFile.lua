--[[
    XMLFile Mock
    Provides an in-memory mock of FS25's XMLFile class for testing XML storage
]]

-- Store XML data in memory
local xmlStorage = {}
local xmlIdCounter = 0

---@class XMLFile
_G.XMLFile = {}

-- XML value type constants
XMLFile.XML_TYPE_STRING = 1
XMLFile.XML_TYPE_INT = 2
XMLFile.XML_TYPE_FLOAT = 3
XMLFile.XML_TYPE_BOOL = 4

---Create a new XML file (in memory)
---@param name string Internal name for the file
---@param path string File path (used as key)
---@param schema table|nil XML schema (ignored in mock)
---@return number xmlId Handle to the XML file
function XMLFile.create(name, path, schema)
    xmlIdCounter = xmlIdCounter + 1
    local xmlId = xmlIdCounter

    xmlStorage[xmlId] = {
        name = name,
        path = path,
        data = {},
        isNew = true
    }

    return xmlId
end

---Load an existing XML file (in memory)
---@param name string Internal name for the file
---@param path string File path (used as key)
---@param schema table|nil XML schema (ignored in mock)
---@return number|nil xmlId Handle to the XML file, or nil if not found
function XMLFile.load(name, path, schema)
    -- Check if we have data stored for this path
    for id, xmlData in pairs(xmlStorage) do
        if xmlData.path == path and not xmlData.deleted then
            return id
        end
    end

    -- Simulate file not found
    return nil
end

---Load or create an XML file
---@param name string Internal name for the file
---@param path string File path
---@param schema table|nil XML schema (ignored in mock)
---@return number xmlId Handle to the XML file
function XMLFile.loadIfExists(name, path, schema)
    local xmlId = XMLFile.load(name, path, schema)
    if xmlId == nil then
        xmlId = XMLFile.create(name, path, schema)
    end
    return xmlId
end

---Close/delete an XML file handle
---@param xmlId number XML file handle
function XMLFile.delete(xmlId)
    if xmlStorage[xmlId] then
        xmlStorage[xmlId].deleted = true
    end
end

---Save XML file to disk (no-op in mock, data already in memory)
---@param xmlId number XML file handle
function XMLFile.save(xmlId)
    -- Mark as saved (for testing purposes)
    if xmlStorage[xmlId] then
        xmlStorage[xmlId].saved = true
    end
end

-- Helper to get/set nested values using dot-separated paths
local function getNestedPath(data, path)
    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end

    local current = data
    for i, part in ipairs(parts) do
        -- Handle array indexing like "workflows.workflow(0)"
        local name, index = part:match("([^%(]+)%((%d+)%)")
        if name and index then
            index = tonumber(index)
            if current[name] == nil then
                return nil
            end
            current = current[name][index + 1]  -- Lua is 1-indexed
        else
            if current[part] == nil then
                return nil
            end
            current = current[part]
        end
        if current == nil then
            return nil
        end
    end
    return current
end

local function setNestedPath(data, path, value)
    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end

    local current = data
    for i = 1, #parts - 1 do
        local part = parts[i]
        -- Handle array indexing
        local name, index = part:match("([^%(]+)%((%d+)%)")
        if name and index then
            index = tonumber(index)
            if current[name] == nil then
                current[name] = {}
            end
            if current[name][index + 1] == nil then
                current[name][index + 1] = {}
            end
            current = current[name][index + 1]
        else
            if current[part] == nil then
                current[part] = {}
            end
            current = current[part]
        end
    end

    local lastPart = parts[#parts]
    -- Handle array indexing for last part
    local name, index = lastPart:match("([^%(]+)%((%d+)%)")
    if name and index then
        index = tonumber(index)
        if current[name] == nil then
            current[name] = {}
        end
        current[name][index + 1] = value
    else
        current[lastPart] = value
    end
end

---Get string value from XML
---@param xmlId number XML file handle
---@param path string XML path (e.g., "workflow.name")
---@param default string|nil Default value
---@return string|nil value
function XMLFile.getString(xmlId, path, default)
    if not xmlStorage[xmlId] then return default end
    local value = getNestedPath(xmlStorage[xmlId].data, path)
    if value == nil then return default end
    return tostring(value)
end

---Set string value in XML
---@param xmlId number XML file handle
---@param path string XML path
---@param value string Value to set
function XMLFile.setString(xmlId, path, value)
    if not xmlStorage[xmlId] then return end
    setNestedPath(xmlStorage[xmlId].data, path, value)
end

---Get integer value from XML
---@param xmlId number XML file handle
---@param path string XML path
---@param default number|nil Default value
---@return number|nil value
function XMLFile.getInt(xmlId, path, default)
    if not xmlStorage[xmlId] then return default end
    local value = getNestedPath(xmlStorage[xmlId].data, path)
    if value == nil then return default end
    return math.floor(tonumber(value) or default or 0)
end

---Set integer value in XML
---@param xmlId number XML file handle
---@param path string XML path
---@param value number Value to set
function XMLFile.setInt(xmlId, path, value)
    if not xmlStorage[xmlId] then return end
    setNestedPath(xmlStorage[xmlId].data, path, math.floor(value))
end

---Get float value from XML
---@param xmlId number XML file handle
---@param path string XML path
---@param default number|nil Default value
---@return number|nil value
function XMLFile.getFloat(xmlId, path, default)
    if not xmlStorage[xmlId] then return default end
    local value = getNestedPath(xmlStorage[xmlId].data, path)
    if value == nil then return default end
    return tonumber(value) or default
end

---Set float value in XML
---@param xmlId number XML file handle
---@param path string XML path
---@param value number Value to set
function XMLFile.setFloat(xmlId, path, value)
    if not xmlStorage[xmlId] then return end
    setNestedPath(xmlStorage[xmlId].data, path, value)
end

---Get boolean value from XML
---@param xmlId number XML file handle
---@param path string XML path
---@param default boolean|nil Default value
---@return boolean|nil value
function XMLFile.getBool(xmlId, path, default)
    if not xmlStorage[xmlId] then return default end
    local value = getNestedPath(xmlStorage[xmlId].data, path)
    if value == nil then return default end
    if type(value) == "boolean" then return value end
    return value == "true" or value == true
end

---Set boolean value in XML
---@param xmlId number XML file handle
---@param path string XML path
---@param value boolean Value to set
function XMLFile.setBool(xmlId, path, value)
    if not xmlStorage[xmlId] then return end
    setNestedPath(xmlStorage[xmlId].data, path, value)
end

---Check if a path exists in XML
---@param xmlId number XML file handle
---@param path string XML path
---@return boolean exists
function XMLFile.hasProperty(xmlId, path)
    if not xmlStorage[xmlId] then return false end
    return getNestedPath(xmlStorage[xmlId].data, path) ~= nil
end

---Get number of child elements at path
---@param xmlId number XML file handle
---@param path string XML path to parent
---@return number count
function XMLFile.getNumOfChildren(xmlId, path)
    if not xmlStorage[xmlId] then return 0 end
    local parent = getNestedPath(xmlStorage[xmlId].data, path)
    if type(parent) ~= "table" then return 0 end

    -- Count array elements
    local count = 0
    for k, v in pairs(parent) do
        if type(k) == "number" then
            count = math.max(count, k)
        end
    end
    return count
end

---Get value with automatic type detection
---@param xmlId number XML file handle
---@param path string XML path
---@param valueType number Value type constant
---@param default any Default value
---@return any value
function XMLFile.getValue(xmlId, path, valueType, default)
    if valueType == XMLFile.XML_TYPE_STRING then
        return XMLFile.getString(xmlId, path, default)
    elseif valueType == XMLFile.XML_TYPE_INT then
        return XMLFile.getInt(xmlId, path, default)
    elseif valueType == XMLFile.XML_TYPE_FLOAT then
        return XMLFile.getFloat(xmlId, path, default)
    elseif valueType == XMLFile.XML_TYPE_BOOL then
        return XMLFile.getBool(xmlId, path, default)
    end
    return default
end

---Set value with automatic type detection
---@param xmlId number XML file handle
---@param path string XML path
---@param value any Value to set
---@param valueType number Value type constant
function XMLFile.setValue(xmlId, path, value, valueType)
    if valueType == XMLFile.XML_TYPE_STRING then
        XMLFile.setString(xmlId, path, value)
    elseif valueType == XMLFile.XML_TYPE_INT then
        XMLFile.setInt(xmlId, path, value)
    elseif valueType == XMLFile.XML_TYPE_FLOAT then
        XMLFile.setFloat(xmlId, path, value)
    elseif valueType == XMLFile.XML_TYPE_BOOL then
        XMLFile.setBool(xmlId, path, value)
    end
end

-- Test helper: Clear all stored XML data
function XMLFile._clearAll()
    xmlStorage = {}
    xmlIdCounter = 0
end

-- Test helper: Get raw storage for inspection
function XMLFile._getStorage()
    return xmlStorage
end

-- Test helper: Set data directly for a path
function XMLFile._setTestData(xmlId, data)
    if xmlStorage[xmlId] then
        xmlStorage[xmlId].data = data
    end
end

print("[Mock] XMLFile loaded")
