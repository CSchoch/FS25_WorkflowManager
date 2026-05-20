---
id: xml-format
title: XML Format
sidebar_position: 3
---

# XML Format

:::info Advanced Users
This page is for advanced users who want to manually back up, restore, or edit their workflows. Most users do not need to read this — the in-game editor handles everything automatically.
:::

Workflow Manager saves your workflows in an XML file within each savegame. You normally don't need to touch this file, but it can be useful for manual editing, backup, or sharing workflows between savegames.

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
    name="Harvest wheat – fields 1–2">
    <!-- Step elements here -->
</workflow>
```

#### Workflow Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | string | Unique identifier (auto-generated, do not change) |
| `name` | string | Display name shown in the Workflow Manager |

### AD Settings Element (optional)

A workflow can optionally contain an `<adSettings>` element with AutoDrive overrides. All attributes are optional — omit any that should keep AutoDrive's own value.

```xml
<workflow id="wf_001" name="Combine Harvest">
    <adSettings unloadFillLevel="0.9" pipeOffset="0.5" preCallLevel="0.8"/>
    <!-- steps … -->
</workflow>
```

#### adSettings Attributes

| Attribute | Type | Range | Description |
|-----------|------|-------|-------------|
| `unloadFillLevel` | float | 0.0 – 1.0 | Fill fraction at which the unloader is called (0.9 = 90 %). |
| `pipeOffset` | float | –5.0 – 5.0 | Horizontal pipe position offset in metres. |
| `preCallLevel` | float | 0.0 – 1.0 | Fill fraction at which AutoDrive pre-calls the unloader (0.8 = 80 %). |

:::note
All three values are stored as fractions (0.0–1.0). The in-game dialog shows and accepts them as percentages (0–100) and converts automatically.
:::

The `<adSettings>` element is omitted entirely when no overrides are set.

### Step Element

Main steps are direct children of `<workflow>`. Steps that have support sub-steps contain nested `<support>` child elements.

```xml
<step type="autodrive" target="Route_Field1" action="drive"/>

<step type="courseplay" target="Field1_Harvest" action="fieldwork">
    <support type="autodrive" target="Field1" action="unload" unloadTarget="Silo"/>
    <support type="autodrive" target="Silo" action="deliver"/>
</step>
```

#### Step Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | Yes | `autodrive` or `courseplay` |
| `target` | string | Yes | Destination name (AutoDrive) or course name (Courseplay) |
| `action` | string | Yes | Action to perform |
| `unloadTarget` | string | No | Secondary destination (AutoDrive only) |
| `fillType` | string | No | Cargo filter (AutoDrive only) |

#### Support Sub-Step Attributes

`<support>` elements use the same attributes as `<step>` (without nesting of their own).

Steps with no support activity simply have no `<support>` children. You can leave the closing tag out entirely (self-closing `/>` is fine).

## Complete Example

### Single-vehicle workflow

```xml
<?xml version="1.0" encoding="utf-8"?>
<WorkflowManager>
    <workflows>
        <workflow id="workflow_001" name="Harvest wheat – fields 1–2">
            <step type="autodrive" target="Route_Field1" action="drive"/>
            <step type="courseplay" target="Field1_Harvest" action="fieldwork"/>
            <step type="autodrive" target="Farm/Silo" action="pickup_deliver" unloadTarget="Sell/BGA" fillType="WHEAT"/>
            <step type="autodrive" target="Route_Field2" action="drive"/>
            <step type="courseplay" target="Field2_Harvest" action="fieldwork"/>
            <step type="autodrive" target="Farm" action="drive"/>
        </workflow>
        <workflow id="workflow_002" name="Fertilize Fields">
            <step type="autodrive" target="Field3_Entrance" action="drive"/>
            <step type="courseplay" target="Field3_Fertilize" action="fieldwork"/>
        </workflow>
    </workflows>
</WorkflowManager>
```

### Two-vehicle workflow (combine + unloader)

Support sub-steps are nested inside the main steps they belong to. Drive-to steps have no `<support>` children — the support vehicle idles during transit.

```xml
<?xml version="1.0" encoding="utf-8"?>
<WorkflowManager>
    <workflows>
        <workflow id="wf_001" name="Combine Harvest">
            <adSettings unloadFillLevel="0.9" pipeOffset="0.5" preCallLevel="0.8"/>
            <step type="autodrive" target="Route_Field1" action="drive"/>
            <step type="courseplay" target="Field1_Harvest" action="fieldwork">
                <support type="autodrive" target="Field1" action="unload" unloadTarget="Silo"/>
                <support type="autodrive" target="Silo" action="deliver"/>
            </step>
            <step type="autodrive" target="Route_Field2" action="drive"/>
            <step type="courseplay" target="Field2_Harvest" action="fieldwork">
                <support type="autodrive" target="Field2" action="unload" unloadTarget="Silo"/>
                <support type="autodrive" target="Silo" action="deliver"/>
            </step>
        </workflow>
    </workflows>
</WorkflowManager>
```

Both vehicles start the **same** workflow and choose their role (Main or Support) in-game when starting. There is only one workflow element — not two separate linked files.

## AutoDrive Step Examples

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
<support
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

## Courseplay Step Examples

### Field Work

```xml
<step type="courseplay" target="Field1_Wheat_Harvest" action="fieldwork"/>
```

### Bale Collection

```xml
<step type="courseplay" target="Meadow_Baling" action="bale_collect"/>
```

## Action Reference

**AutoDrive actions:**
- `drive` - Simple point-to-point navigation
- `unload` - Unload combine (follows combine, delivers grain)
- `pickup_deliver` - Load at target, deliver to unload target
- `deliver` - Deliver current load to target
- `load` - Load at target, return to unload target

**Courseplay actions:**
- `fieldwork` - Field operations (harvest, cultivate, seed, spray, etc.)
- `bale_collect` - Collect and wrap bales

## Fill Types

Common FS25 fill types for the `fillType` attribute:
- `WHEAT`
- `BARLEY`
- `CANOLA`
- `CORN`
- `SUNFLOWER`
- `SOYBEAN`
- (and others — the name is the internal fill type ID shown in the step dialog)

## Old Format Migration

If you have a savegame from an older version of Workflow Manager that used `linkRole`, `linkedWorkflowId`, and `syncGroup` attributes, those files are migrated automatically when you load the game. The old linked workflow pair is converted into a single workflow with nested `<support>` elements. No manual action is required.

## Backup and Recovery

### Manual Backup

Copy `workflowManager.xml` to a safe location before making changes.

### Restoring Workflows

1. Stop the game
2. Copy the backup file to the savegame folder
3. Rename it to `workflowManager.xml` (replacing the existing file)
4. Load the savegame

### Editing Manually

You can edit the XML file directly:
1. Exit the game
2. Open `workflowManager.xml` in a text editor
3. Make your changes
4. Save the file
5. Load the savegame

:::warning
Invalid XML will cause loading errors. Make a backup before editing, and double-check your changes.
:::

## Sharing Workflows

To share workflows with another player:

1. Copy your `workflowManager.xml` to them
2. They place it in their savegame folder
3. **Important**: AutoDrive destination names and Courseplay course names must match exactly on their setup, otherwise steps will fail to execute
