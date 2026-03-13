--[[
    XMLFile Mock
    Provides an in-memory mock of FS25's XMLFile class for testing XML storage.

    FS25 uses XMLFile handles that support OOP-style method calls:
        local xmlFile = XMLFile.create(...)
        xmlFile:setString(path, value)   -- OOP syntax

    This mock returns a proxy table for each open file so that both the static
    form (XMLFile.getString(xmlId, path)) and the OOP form (xmlFile:getString(path))
    work transparently.

    Data is stored by file *path* so that close + re-open preserves content,
    matching real savegame behaviour.
]]

-- Persistent file data keyed by path
local xmlDataStore = {}   -- { [path] = data_table }

-- Active handle registry: xmlId -> path
local xmlHandles = {}
local xmlIdCounter = 0

---@class XMLFile
_G.XMLFile = {}

-- XML value type constants
XMLFile.XML_TYPE_STRING = 1
XMLFile.XML_TYPE_INT    = 2
XMLFile.XML_TYPE_FLOAT  = 3
XMLFile.XML_TYPE_BOOL   = 4

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

-- Build a proxy table for the given handle id.
-- Every method call on the proxy is forwarded to the corresponding static
-- XMLFile function with xmlId prepended automatically.
local function createProxy(xmlId)
    return setmetatable({}, {
        __index = function(_, key)
            local fn = XMLFile[key]
            if type(fn) == "function" then
                -- Return a closure that injects xmlId as the first argument
                return function(self, ...)
                    return fn(xmlId, ...)
                end
            end
        end
    })
end

-- Navigate (and optionally create) a nested table from a dot-separated path.
-- Supports array notation like "workflows.workflow(0).step(1)".
local function parsePath(path)
    local parts = {}
    for part in path:gmatch("[^%.]+") do
        local name, idx = part:match("^([^%(]+)%((%d+)%)$")
        if name then
            table.insert(parts, { name = name, idx = tonumber(idx) + 1 })  -- 1-based
        elseif part:sub(1, 1) == "#" then
            table.insert(parts, { attr = part:sub(2) })
        else
            table.insert(parts, { name = part })
        end
    end
    return parts
end

local function getNestedPath(data, path)
    local parts = parsePath(path)
    local current = data
    for _, p in ipairs(parts) do
        if current == nil then return nil end
        if p.attr then
            current = current[p.attr]
        elseif p.idx then
            local tbl = current[p.name]
            if type(tbl) ~= "table" then return nil end
            current = tbl[p.idx]
        else
            current = current[p.name]
        end
    end
    return current
end

local function setNestedPath(data, path, value)
    local parts = parsePath(path)
    local current = data
    for i = 1, #parts - 1 do
        local p = parts[i]
        if p.attr then
            -- attributes can only be the last element; skip as intermediate
        elseif p.idx then
            if type(current[p.name]) ~= "table" then current[p.name] = {} end
            if current[p.name][p.idx] == nil then current[p.name][p.idx] = {} end
            current = current[p.name][p.idx]
        else
            if type(current[p.name]) ~= "table" then current[p.name] = {} end
            current = current[p.name]
        end
    end
    local last = parts[#parts]
    if last.attr then
        current[last.attr] = value
    elseif last.idx then
        if type(current[last.name]) ~= "table" then current[last.name] = {} end
        current[last.name][last.idx] = value
    else
        current[last.name] = value
    end
end

local function getOrCreateData(xmlId)
    local path = xmlHandles[xmlId]
    if path == nil then return nil end
    if xmlDataStore[path] == nil then xmlDataStore[path] = {} end
    return xmlDataStore[path]
end

-- ---------------------------------------------------------------------------
-- Handle lifecycle
-- ---------------------------------------------------------------------------

---Create a new XML file (in memory, persists by path)
---@return table proxy Proxy object supporting OOP-style method calls
function XMLFile.create(name, path, schema)
    xmlIdCounter = xmlIdCounter + 1
    local xmlId = xmlIdCounter
    xmlHandles[xmlId] = path
    -- Reset data for this path (fresh create overwrites existing)
    xmlDataStore[path] = {}
    return createProxy(xmlId)
end

---Load an existing XML file
---@return table|nil proxy Proxy object, or nil if path has no stored data
function XMLFile.load(name, path, schema)
    if xmlDataStore[path] == nil then
        return nil
    end
    xmlIdCounter = xmlIdCounter + 1
    local xmlId = xmlIdCounter
    xmlHandles[xmlId] = path
    return createProxy(xmlId)
end

---Load if exists, otherwise create
---@return table proxy Proxy object
function XMLFile.loadIfExists(name, path, schema)
    return XMLFile.load(name, path, schema) or XMLFile.create(name, path, schema)
end

---Close a file handle (data persists in xmlDataStore for reload)
function XMLFile.delete(xmlId)
    xmlHandles[xmlId] = nil
end

---Save file to disk (no-op in mock; data already in xmlDataStore)
function XMLFile.save(xmlId)
    -- Mark as saved for test assertions
    local path = xmlHandles[xmlId]
    if path and xmlDataStore[path] then
        xmlDataStore[path]._saved = true
    end
end

-- ---------------------------------------------------------------------------
-- Get / Set
-- ---------------------------------------------------------------------------

function XMLFile.getString(xmlId, path, default)
    local data = getOrCreateData(xmlId)
    if data == nil then return default end
    local v = getNestedPath(data, path)
    if v == nil then return default end
    return tostring(v)
end

function XMLFile.setString(xmlId, path, value)
    local data = getOrCreateData(xmlId)
    if data then setNestedPath(data, path, value) end
end

function XMLFile.getInt(xmlId, path, default)
    local data = getOrCreateData(xmlId)
    if data == nil then return default end
    local v = getNestedPath(data, path)
    if v == nil then return default end
    return math.floor(tonumber(v) or (default or 0))
end

function XMLFile.setInt(xmlId, path, value)
    local data = getOrCreateData(xmlId)
    if data then setNestedPath(data, path, math.floor(value)) end
end

function XMLFile.getFloat(xmlId, path, default)
    local data = getOrCreateData(xmlId)
    if data == nil then return default end
    local v = getNestedPath(data, path)
    if v == nil then return default end
    return tonumber(v) or default
end

function XMLFile.setFloat(xmlId, path, value)
    local data = getOrCreateData(xmlId)
    if data then setNestedPath(data, path, value) end
end

function XMLFile.getBool(xmlId, path, default)
    local data = getOrCreateData(xmlId)
    if data == nil then return default end
    local v = getNestedPath(data, path)
    if v == nil then return default end
    if type(v) == "boolean" then return v end
    return v == "true" or v == true
end

function XMLFile.setBool(xmlId, path, value)
    local data = getOrCreateData(xmlId)
    if data then setNestedPath(data, path, value) end
end

function XMLFile.hasProperty(xmlId, path)
    local data = getOrCreateData(xmlId)
    if data == nil then return false end
    return getNestedPath(data, path) ~= nil
end

function XMLFile.getNumOfChildren(xmlId, path)
    local data = getOrCreateData(xmlId)
    if data == nil then return 0 end
    local parent = getNestedPath(data, path)
    if type(parent) ~= "table" then return 0 end
    local count = 0
    for k in pairs(parent) do
        if type(k) == "number" then
            count = math.max(count, k)
        end
    end
    return count
end

function XMLFile.getValue(xmlId, path, valueType, default)
    if valueType == XMLFile.XML_TYPE_STRING then return XMLFile.getString(xmlId, path, default)
    elseif valueType == XMLFile.XML_TYPE_INT   then return XMLFile.getInt(xmlId, path, default)
    elseif valueType == XMLFile.XML_TYPE_FLOAT then return XMLFile.getFloat(xmlId, path, default)
    elseif valueType == XMLFile.XML_TYPE_BOOL  then return XMLFile.getBool(xmlId, path, default)
    end
    return default
end

function XMLFile.setValue(xmlId, path, value, valueType)
    if valueType == XMLFile.XML_TYPE_STRING then XMLFile.setString(xmlId, path, value)
    elseif valueType == XMLFile.XML_TYPE_INT   then XMLFile.setInt(xmlId, path, value)
    elseif valueType == XMLFile.XML_TYPE_FLOAT then XMLFile.setFloat(xmlId, path, value)
    elseif valueType == XMLFile.XML_TYPE_BOOL  then XMLFile.setBool(xmlId, path, value)
    end
end

-- ---------------------------------------------------------------------------
-- Test helpers
-- ---------------------------------------------------------------------------

---Clear all stored XML data and handles
function XMLFile._clearAll()
    xmlDataStore  = {}
    xmlHandles    = {}
    xmlIdCounter  = 0
end

---Get the raw data store (for inspection in tests)
function XMLFile._getStorage()
    return xmlDataStore
end

---Get data for a specific path directly (bypasses handle lifecycle)
function XMLFile._getDataForPath(path)
    return xmlDataStore[path]
end

print("[Mock] XMLFile loaded")
