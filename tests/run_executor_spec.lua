--[[
    Custom runner: runs only WorkflowExecutor_spec.lua using the real test framework.
    Avoids the Logger I/O issue that stops the full runner on Windows.
]]

-- ---- Copy of test framework from run_tests.lua ----
local TestRunner = {
    passed = 0, failed = 0, errors = {},
    currentDescribe = "", currentIt = ""
}

local lua_assert = assert
assert = setmetatable({}, { __call = function(_, val, msg) return lua_assert(val, msg) end })
assert.is_true     = function(v) if v ~= true  then error("Expected true, got "    ..tostring(v)) end end
assert.is_false    = function(v) if v ~= false then error("Expected false, got "   ..tostring(v)) end end
assert.is_nil      = function(v) if v ~= nil   then error("Expected nil, got "     ..tostring(v)) end end
assert.is_not_nil  = function(v) if v == nil   then error("Expected non-nil")                    end end
assert.is_table    = function(v) if type(v) ~= "table"  then error("Expected table")  end end
assert.is_string   = function(v) if type(v) ~= "string" then error("Expected string") end end
assert.is_number   = function(v) if type(v) ~= "number" then error("Expected number") end end
assert.is_truthy   = function(v) if not v then error("Expected truthy, got "..tostring(v)) end end
assert.are = {
    equal = function(e, a)
        if e ~= a then error("Expected "..tostring(e)..", got "..tostring(a)) end
    end,
    same  = function(e, a)
        if type(e)=="table" and type(a)=="table" then
            for k,v in pairs(e) do if a[k]~=v then error("Tables differ at key "..tostring(k)) end end
            for k,v in pairs(a) do if e[k]~=v then error("Tables differ at key "..tostring(k)) end end
        elseif e ~= a then error("Expected "..tostring(e)..", got "..tostring(a)) end
    end
}
assert.are_not = {
    equal = function(v1, v2) if v1==v2 then error("Expected different, both "..tostring(v1)) end end
}
assert.has_no = {
    errors = function(fn) local ok,e = pcall(fn); if not ok then error("Expected no errors, got: "..tostring(e)) end end
}

local describeStack    = {}
local allBeforeEachFns = {}
local allAfterEachFns  = {}

function describe(name, fn)
    table.insert(describeStack, name)
    local prevBefore = #allBeforeEachFns
    local prevAfter  = #allAfterEachFns
    TestRunner.currentDescribe = table.concat(describeStack, " > ")
    print("\n"..string.rep("  ", #describeStack-1).."○ "..name)
    fn()
    while #allBeforeEachFns > prevBefore do table.remove(allBeforeEachFns) end
    while #allAfterEachFns  > prevAfter  do table.remove(allAfterEachFns)  end
    table.remove(describeStack)
    TestRunner.currentDescribe = #describeStack>0 and table.concat(describeStack," > ") or ""
end

function it(name, fn)
    TestRunner.currentIt = name
    for _, bfn in ipairs(allBeforeEachFns) do
        local ok, e = pcall(bfn)
        if not ok then
            TestRunner.failed = TestRunner.failed + 1
            table.insert(TestRunner.errors, {describe=TestRunner.currentDescribe, it=name, error="before_each: "..tostring(e)})
            print(string.rep("  ", #describeStack).."  ✗ "..name.." (before_each failed)")
            return
        end
    end
    local ok, e = pcall(fn)
    if ok then
        TestRunner.passed = TestRunner.passed + 1
        print(string.rep("  ", #describeStack).."  ✓ "..name)
    else
        TestRunner.failed = TestRunner.failed + 1
        table.insert(TestRunner.errors, {describe=TestRunner.currentDescribe, it=name, error=tostring(e)})
        print(string.rep("  ", #describeStack).."  ✗ "..name)
    end
    for _, afn in ipairs(allAfterEachFns) do pcall(afn) end
end

function before_each(fn) table.insert(allBeforeEachFns, fn) end
function after_each(fn)  table.insert(allAfterEachFns,  fn) end
function setup(fn) local ok,e = pcall(fn); if not ok then error("Setup failed: "..tostring(e)) end end

-- ---- Load mocks & fixtures ----
dofile("tests/mocks/game_globals.lua")
dofile("tests/mocks/XMLFile.lua")
dofile("tests/mocks/vehicle.lua")
dofile("tests/fixtures/workflows.lua")

-- ---- Run executor spec ----
print("\n"..string.rep("=",60))
print("WorkflowExecutor Tests")
print(string.rep("=",60))
dofile("tests/specs/WorkflowExecutor_spec.lua")

-- ---- Summary ----
print("\n"..string.rep("=",60))
print(string.format("Passed: %d", TestRunner.passed))
print(string.format("Failed: %d", TestRunner.failed))
print(string.format("Total:  %d", TestRunner.passed + TestRunner.failed))

if #TestRunner.errors > 0 then
    print("\nFailed tests:")
    for _, e in ipairs(TestRunner.errors) do
        print(string.format("  FAIL: %s > %s", e.describe, e.it))
        print(string.format("        %s", e.error))
    end
end
