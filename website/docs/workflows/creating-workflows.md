---
id: creating-workflows
title: Creating Workflows
sidebar_position: 1
---

# Creating Workflows

Workflows are the core concept of Workflow Manager. Each workflow is a sequence of steps that automate farm operations.

## Workflow Structure

A workflow consists of:

- **Name**: A descriptive identifier (e.g., "Harvest Wheat Fields 1-3")
- **Steps**: Ordered list of AutoDrive routes and Courseplay courses

## Creating a New Workflow

### From the Workflow Manager

1. Press **Left Alt + W** to open the Workflow Manager
2. Click **New**
3. Enter a workflow name
4. The workflow editor opens

![Workflow Editor](/img/screenshots/editor-dialog.png)

### Naming Best Practices

Use descriptive names that help you identify the workflow:
- Include the crop type: "Harvest Wheat - North Fields"
- Include field numbers: "Fertilize Fields 1, 2, 3"
- Include the operation: "Baling - Grass Meadow"

## Adding Steps

Steps are added in the workflow editor.

### Step Types

| Type | Use For |
|------|---------|
| **AutoDrive** | Navigation between locations, unloading, loading |
| **Courseplay** | Field work (harvesting, seeding, cultivating, baling) |

### Adding an AutoDrive Step

1. Click **Add Step**
2. Select **AutoDrive** as the type
3. Choose a **Target** destination from the dropdown
4. Select an **Action**:
   - **Drive To** — Simple navigation to target
   - **Unload Combine** — Unload mode (for combines)
   - **Pickup and Deliver** — Load at target, deliver to second location
   - **Deliver** — Deliver current load to target
   - **Load** — Load at target, return to second location
5. For modes requiring two destinations, select **Unload Target**
6. Optionally set **Fill Type** to filter cargo
7. Click **OK**

### Adding a Courseplay Step

1. Click **Add Step**
2. Select **Courseplay** as the type
3. Choose a **Course** from the dropdown
4. Select an **Action**:
   - **Field Work** — Standard field operations
   - **Bale Collect** — Collect and wrap bales
5. Click **OK**

## Editing Steps

### Reordering Steps

- Select a step and use **Move Up** / **Move Down** buttons
- Or use keyboard shortcuts: **+** to move up, **-** to move down

### Modifying a Step

1. Double-click the step or select and click **Edit**
2. Modify the step properties
3. Click **OK** to save

### Deleting Steps

1. Select the step
2. Click **Delete** or press **Backspace**

## Workflow Example

Here's a complete workflow for harvesting multiple fields:

```
Workflow: "Wheat Harvest - Fields 1 & 2"

Step 1: AutoDrive → Field1_Entrance          Drive To
Step 2: Courseplay → Field1_Wheat_Harvest     Field Work
Step 3: AutoDrive → Farm/Silo → Sell/Mill     Pickup and Deliver · Filter: Wheat
Step 4: AutoDrive → Field2_Entrance          Drive To
Step 5: Courseplay → Field2_Wheat_Harvest     Field Work
Step 6: AutoDrive → Farm/Silo                Drive To
```

## Saving Workflows

Workflows are saved automatically when you:
- Close the editor dialog
- Exit the Workflow Manager
- Save the game

Workflows persist in your savegame folder in `workflowManager.xml`.

## Copying Workflows

Currently, workflows cannot be directly copied. To create a similar workflow:
1. Create a new workflow
2. Add the same steps manually

:::tip Future Feature
Workflow copying/templating is planned for a future update.
:::

## Best Practices

1. **Test individual components first**: Ensure your AutoDrive routes and Courseplay courses work independently
2. **Start simple**: Begin with 2-3 step workflows before creating complex sequences
3. **Use descriptive names**: Makes managing multiple workflows easier
4. **Group by operation**: Create separate workflows for different crop types or operations
5. **Consider vehicle requirements**: Ensure your vehicle supports all steps in the workflow
