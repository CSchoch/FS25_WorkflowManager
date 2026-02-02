# FS25_WorkflowManager Unit Tests

Unit tests for the WorkflowManager mod using the **busted** test framework.

## Prerequisites

### Install Lua and LuaRocks

**Windows (using Scoop):**
```powershell
scoop install lua luarocks
```

**Windows (using Chocolatey):**
```powershell
choco install lua luarocks
```

**Manual Installation:**
1. Download Lua from https://www.lua.org/download.html
2. Download LuaRocks from https://luarocks.org/

### Install busted

```bash
luarocks install busted
```

## Running Tests

From the mod root directory (`FS25_WorkflowManager/`):

```bash
# Run all tests
busted tests/specs

# Run specific test file
busted tests/specs/EventHandler_spec.lua

# Verbose output
busted -v tests/specs

# Run with TAP output (for CI)
busted -o TAP tests/specs
```

## Test Structure

```
tests/
├── .busted              # busted configuration
├── README.md            # This file
├── mocks/
│   ├── init.lua         # Mock loader
│   ├── game_globals.lua # g_currentMission, g_i18n, etc.
│   ├── XMLFile.lua      # In-memory XML mock
│   └── vehicle.lua      # Vehicle factory
├── fixtures/
│   └── workflows.lua    # Sample workflow data
└── specs/
    ├── EventHandler_spec.lua
    ├── WorkflowManager_spec.lua
    ├── WorkflowExecutor_spec.lua
    └── Logger_spec.lua
```

## Writing Tests

Tests use BDD-style syntax:

```lua
describe("ModuleName", function()
    before_each(function()
        -- Setup before each test
    end)

    it("should do something", function()
        assert.are.equal(expected, actual)
    end)
end)
```

### Using Mocks

```lua
-- Create a valid vehicle with AD+CP support
local vehicle = VehicleMock.createValid("MyTractor")

-- Set the controlled vehicle
VehicleMock.setControlledVehicle(vehicle)

-- Check logger calls
assert.are.equal(1, #WMLogger.calls.error)
```

### Using Fixtures

```lua
local workflow = TestFixtures.createHarvestWorkflow()
```

## Test Coverage

| Module | Tests | Coverage |
|--------|-------|----------|
| EventHandler | addEventListener, fireEvent, removeEventListener, removeAllListeners | Core event system |
| WorkflowManager | createWorkflow, getWorkflowById, deleteWorkflow, addStep, isVehicleValid | CRUD operations |
| WorkflowExecutor | start, stop, pause, resume, goToPreviousStep, goToNextStep | State machine |
| Logger | log levels, formatting, conditional logging | Logging utility |

## CI Integration

For CI pipelines, use TAP output:

```bash
busted -o TAP tests/specs > test-results.tap
```

Or JUnit XML:
```bash
luarocks install busted-junit
busted -o junit tests/specs > test-results.xml
```
