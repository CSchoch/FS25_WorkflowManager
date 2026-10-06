--[[
    Simple Test Runner
    Runs tests without requiring busted (for environments where busted isn't available)

    Usage: lua tests/run_tests.lua
]]

-- Simple test framework implementation
local TestRunner = {
    passed = 0,
    failed = 0,
    errors = {},
    currentDescribe = "",
    currentIt = ""
}

-- Preserve original assert function
local lua_assert = assert

-- Assertion functions (compatible with busted syntax)
-- Create a callable table that also works as a function
assert = setmetatable({}, {
    __call = function(_, val, msg)
        return lua_assert(val, msg)
    end
})

assert.is_true = function(val)
    if val ~= true then
        error("Expected true, got " .. tostring(val))
    end
end
assert.is_false = function(val)
    if val ~= false then
        error("Expected false, got " .. tostring(val))
    end
end
assert.is_nil = function(val)
    if val ~= nil then
        error("Expected nil, got " .. tostring(val))
    end
end
assert.is_not_nil = function(val)
    if val == nil then
        error("Expected non-nil value, got nil")
    end
end
assert.is_table = function(val)
    if type(val) ~= "table" then
        error("Expected table, got " .. type(val))
    end
end
assert.is_string = function(val)
    if type(val) ~= "string" then
        error("Expected string, got " .. type(val))
    end
end
assert.is_number = function(val)
    if type(val) ~= "number" then
        error("Expected number, got " .. type(val))
    end
end
assert.is_truthy = function(val)
    if not val then
        error("Expected truthy value, got " .. tostring(val))
    end
end
assert.are = {
    equal = function(expected, actual)
        if expected ~= actual then
            error("Expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end,
    same = function(expected, actual)
        if type(expected) == "table" and type(actual) == "table" then
            for k, v in pairs(expected) do
                if actual[k] ~= v then
                    error("Tables differ at key " .. tostring(k))
                end
            end
            for k, v in pairs(actual) do
                if expected[k] ~= v then
                    error("Tables differ at key " .. tostring(k))
                end
            end
        elseif expected ~= actual then
            error("Expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end
}
assert.are_not = {
    equal = function(val1, val2)
        if val1 == val2 then
            error("Expected values to be different, both are " .. tostring(val1))
        end
    end
}
assert.has_no = {
    errors = function(fn)
        local success, err = pcall(fn)
        if not success then
            error("Expected no errors, got: " .. tostring(err))
        end
    end
}

-- BDD-style functions
local describeStack = {}
local allBeforeEachFns = {}  -- All before_each functions accumulated

function describe(name, fn)
    table.insert(describeStack, name)
    local prevBeforeEachCount = #allBeforeEachFns
    TestRunner.currentDescribe = table.concat(describeStack, " > ")
    print("\n" .. string.rep("  ", #describeStack - 1) .. "○ " .. name)
    fn()
    -- Remove any before_each functions added by this describe
    while #allBeforeEachFns > prevBeforeEachCount do
        table.remove(allBeforeEachFns)
    end
    table.remove(describeStack)
    if #describeStack > 0 then
        TestRunner.currentDescribe = table.concat(describeStack, " > ")
    else
        TestRunner.currentDescribe = ""
    end
end

function it(name, fn)
    TestRunner.currentIt = name

    -- Run all accumulated before_each functions (outer to inner)
    for i, beforeFn in ipairs(allBeforeEachFns) do
        local success, err = pcall(beforeFn)
        if not success then
            TestRunner.failed = TestRunner.failed + 1
            table.insert(TestRunner.errors, {
                describe = TestRunner.currentDescribe,
                it = name,
                error = "before_each failed: " .. tostring(err)
            })
            print(string.rep("  ", #describeStack) .. "  ✗ " .. name .. " (before_each failed)")
            return
        end
    end

    -- Run the test
    local success, err = pcall(fn)
    if success then
        TestRunner.passed = TestRunner.passed + 1
        print(string.rep("  ", #describeStack) .. "  ✓ " .. name)
    else
        TestRunner.failed = TestRunner.failed + 1
        table.insert(TestRunner.errors, {
            describe = TestRunner.currentDescribe,
            it = name,
            error = tostring(err)
        })
        print(string.rep("  ", #describeStack) .. "  ✗ " .. name)
    end
end

function before_each(fn)
    table.insert(allBeforeEachFns, fn)
end

function setup(fn)
    -- Run setup immediately (once per describe block)
    local success, err = pcall(fn)
    if not success then
        print("Setup failed: " .. tostring(err))
        error("Setup failed: " .. tostring(err))
    end
end

-- Set up package path
local scriptPath = arg[0]:match("(.*/)")
if scriptPath then
    package.path = scriptPath .. "../?.lua;" ..
                   scriptPath .. "../src/?.lua;" ..
                   scriptPath .. "../src/utils/?.lua;" ..
                   scriptPath .. "mocks/?.lua;" ..
                   scriptPath .. "fixtures/?.lua;" ..
                   package.path
end

-- Load mocks
print("Loading mocks...")
dofile("tests/mocks/game_globals.lua")
dofile("tests/mocks/XMLFile.lua")
dofile("tests/mocks/vehicle.lua")
dofile("tests/fixtures/workflows.lua")

print("\n" .. string.rep("=", 60))
print("Running FS25_WorkflowManager Unit Tests")
print(string.rep("=", 60))

-- Run test files
local testFiles = {
    "tests/specs/EventHandler_spec.lua",
    "tests/specs/Logger_spec.lua",
    "tests/specs/WMSettings_spec.lua",
    "tests/specs/WorkflowStorage_spec.lua",
    "tests/specs/WorkflowManager_spec.lua",
    "tests/specs/WorkflowManagerADRequirement_spec.lua",
    "tests/specs/WorkflowManagerLifecycle_spec.lua",
    "tests/specs/WorkflowExecutor_spec.lua",
    "tests/specs/AutoDriveIntegration_spec.lua",
    "tests/specs/WorkflowManagerSpec_spec.lua",
    "tests/specs/WMHud_spec.lua",
    "tests/specs/WMLeaderVehicleSelectDialog_spec.lua",
    "tests/specs/WMModeSelectDialog_spec.lua",
    "tests/specs/WMStepDialog_spec.lua",
    "tests/specs/WMEditorDialog_spec.lua",
    "tests/specs/WMMainDialog_spec.lua",
    "tests/specs/CourseplayIntegration_spec.lua",
    "tests/specs/CourseplayCoursesLoader_spec.lua",
    "tests/specs/WMConsoleCommands_spec.lua",
    "tests/specs/WMGameSettings_spec.lua",
    "tests/specs/ModDescInputBindings_spec.lua",
    "tests/specs/WMUserMessageEvent_spec.lua",
    "tests/specs/Translations_spec.lua"
}

for _, testFile in ipairs(testFiles) do
    print("\n" .. string.rep("-", 60))
    print("Loading: " .. testFile)
    print(string.rep("-", 60))

    currentBeforeEach = nil  -- Reset before each file

    -- Snapshot ALL globals: specs may dofile real modules in setup() (replacing shared
    -- mocks like _G.ADIntegration/_G.CPIntegration) or install their own stubs
    -- (_G.WorkflowManager, _G.g_currentMission, ...). Nothing may leak into the next
    -- spec file (CLAUDE.md test framework note), so restore the full global table.
    local savedGlobals = {}
    for k, v in pairs(_G) do savedGlobals[k] = v end

    local success, err = pcall(function()
        dofile(testFile)
    end)

    -- Remove globals the spec added, restore the ones it replaced
    for k in pairs(_G) do
        if savedGlobals[k] == nil then
            _G[k] = nil
        end
    end
    for k, v in pairs(savedGlobals) do
        _G[k] = v
    end

    if not success then
        print("ERROR loading " .. testFile .. ": " .. tostring(err))
        TestRunner.failed = TestRunner.failed + 1
        table.insert(TestRunner.errors, {
            describe = testFile,
            it = "load",
            error = tostring(err)
        })
    end
end

-- Print summary
print("\n" .. string.rep("=", 60))
print("Test Results")
print(string.rep("=", 60))
print(string.format("Passed: %d", TestRunner.passed))
print(string.format("Failed: %d", TestRunner.failed))
print(string.format("Total:  %d", TestRunner.passed + TestRunner.failed))

if #TestRunner.errors > 0 then
    print("\nFailures:")
    for i, err in ipairs(TestRunner.errors) do
        print(string.format("\n  %d) %s > %s", i, err.describe, err.it))
        print("     " .. err.error)
    end
end

print("")
if TestRunner.failed == 0 then
    print("All tests passed!")
    os.exit(0)
else
    print("Some tests failed.")
    os.exit(1)
end
