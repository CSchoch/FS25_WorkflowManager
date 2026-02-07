---
id: xml-format
title: XML Format
sidebar_position: 3
---

# XML Format

Workflow Manager saves your workflows in an XML file within each savegame. You normally don't need to touch this file, but it can be useful for manual editing, backup, or troubleshooting.

## File Location

```
Documents/My Games/FarmingSimulator2025/savegame[X]/workflowManager.xml
```

The file is created automatically when you save your first workflow.

## XML Structure

### Root Element

```xml
<?xml version="1.0" encoding="utf-8"?>
<WorkflowManager>
    <workflows>
        <!-- Workflow elements here -->
    </workflows>
</WorkflowManager>
```

### Workflow Element

```xml
<workflow
    id="workflow_001"
    name="Harvest wheat – fields 1–2"
    currentStep="1"
    status="ready">
    <!-- Step elements here -->
</workflow>
```

#### Workflow Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | string | Unique identifier (auto-generated) |
| `name` | string | Display name |
| `currentStep` | integer | Current step number (1-based) |
| `status` | string | Status: ready, running, paused, completed |

### Step Element

```xml
<step
    type="autodrive"
    target="Route_Field1"
    action="drive"/>
```

#### Step Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | Yes | `autodrive` or `courseplay` |
| `target` | string | Yes | Destination or course name |
| `action` | string | Yes | Action to perform |
| `unloadTarget` | string | No | Secondary destination (AD only) |
| `fillType` | string | No | Cargo filter (AD only) |

## Complete Example

```xml
<?xml version="1.0" encoding="utf-8"?>
<WorkflowManager>
    <workflows>
        <workflow id="workflow_001" name="Harvest wheat – fields 1–2" currentStep="1" status="ready">
            <step type="autodrive" target="Route_Field1" action="drive"/>
            <step type="courseplay" target="Field1_Harvest" action="fieldwork"/>
            <step type="autodrive" target="Farm/Silo" action="pickup_deliver" unloadTarget="Sell/BGA" fillType="WHEAT"/>
            <step type="autodrive" target="Route_Field2" action="drive"/>
            <step type="courseplay" target="Field2_Harvest" action="fieldwork"/>
            <step type="autodrive" target="Farm" action="drive"/>
        </workflow>
        <workflow id="workflow_002" name="Fertilize Fields" currentStep="1" status="ready">
            <step type="autodrive" target="Field3_Entrance" action="drive"/>
            <step type="courseplay" target="Field3_Fertilize" action="fieldwork"/>
        </workflow>
    </workflows>
</WorkflowManager>
```

## AutoDrive Step Types

### Simple Navigation

```xml
<step type="autodrive" target="Field1_Entrance" action="drive"/>
```

### Pickup and Deliver

```xml
<step
    type="autodrive"
    target="Farm/Silo"
    action="pickup_deliver"
    unloadTarget="Sell/Mill"
    fillType="WHEAT"/>
```

### Unload Mode (Combine Support)

```xml
<step
    type="autodrive"
    target="Field1_Harvest"
    action="unload"
    unloadTarget="Farm/Silo"/>
```

### Load Mode

```xml
<step
    type="autodrive"
    target="Shop/Seeds"
    action="load"
    unloadTarget="Field1_Entrance"
    fillType="SEEDS"/>
```

## Courseplay Step Types

### Field Work

```xml
<step type="courseplay" target="Field1_Wheat_Harvest" action="fieldwork"/>
```

### Bale Collection

```xml
<step type="courseplay" target="Meadow_Baling" action="bale_collect"/>
```

## Data Types

### Action Values

**AutoDrive:**
- `drive` - Simple point-to-point
- `unload` - Unload mode
- `pickup_deliver` - Load and deliver
- `deliver` - Deliver current load
- `load` - Load and return

**Courseplay:**
- `fieldwork` - Field operations
- `bale_collect` - Bale collection

### Status Values

- `ready` - Workflow ready to start
- `running` - Workflow currently executing
- `paused` - Workflow paused
- `completed` - All steps finished

### Fill Types

Standard FS25 fill types:
- `WHEAT`
- `BARLEY`
- `CANOLA`
- `CORN`
- `SUNFLOWER`
- `SOYBEAN`
- etc.

## ID Generation

Workflow IDs are generated automatically:
- Format: `workflow_XXX` where XXX is a three-digit number
- IDs are unique within a savegame
- Deleted workflow IDs may be reused

## Backup and Recovery

### Manual Backup

Copy `workflowManager.xml` to a safe location before making changes.

### Restoring Workflows

1. Stop the game
2. Copy backup file to savegame folder
3. Rename to `workflowManager.xml`
4. Load the savegame

### Editing Manually

You can edit the XML file directly:
1. Exit the game
2. Open `workflowManager.xml` in a text editor
3. Make changes
4. Save the file
5. Load the savegame

:::warning
Invalid XML will cause loading errors. Always validate your changes.
:::

## Validation

The mod validates workflows on load:
- Missing required attributes → Step skipped
- Invalid action → Warning logged
- Missing target → Step not executable

Check the game log for validation warnings:
```
[WorkflowManager] Warning: Step missing target attribute
```
