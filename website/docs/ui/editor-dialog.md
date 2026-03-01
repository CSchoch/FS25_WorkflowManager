---
id: editor-dialog
title: Editor Dialog
sidebar_position: 2
---

# Editor Dialog

The Editor Dialog is where you build and modify workflow steps.

## Accessing the Editor

- Click **New** in the Main Dialog to create a new workflow
- Click **Edit** or double-click a workflow to edit existing

## Interface Overview

```
┌─────────────────────────────────────────────┐
│  Edit Workflow: Harvest Fields          [X] │
├─────────────────────────────────────────────┤
│  #  Type        Target              Action  │
│  ─────────────────────────────────────────  │
│  1  AutoDrive   Field1_Entrance     Drive To   │
│  2  Courseplay  Field1_Harvest      Field Work │
│  3  AutoDrive   Farm/Silo           Drive To   │
│                                             │
├─────────────────────────────────────────────┤
│  [Add Step]  [Edit]  [Delete]  [↑]  [↓]     │
└─────────────────────────────────────────────┘

        Double-click a step to edit
```

![Editor Dialog](/img/screenshots/editor-dialog.png)

## Step List

The main area shows all steps in the workflow:

| Column | Description |
|--------|-------------|
| # | Step number (execution order) |
| Type | AutoDrive or Courseplay |
| Target | Destination name or course name |
| Action | The action to perform |

### For AutoDrive steps with two destinations:
- Shows `Target → Unload Target` format
- Example: `Farm/Silo → Sell/Mill`

## Action Buttons

### Add Step

Opens the Step Dialog to add a new step:
1. Click **Add Step**
2. Configure the step (type, target, action)
3. Click **OK**
4. Step is added at the end of the list

### Edit Step

Modify an existing step:
1. Select a step from the list
2. Click **Edit** (or double-click the step)
3. Modify properties in the Step Dialog
4. Click **OK**

### Delete Step

Remove a step:
1. Select the step
2. Click **Delete**
3. Step is removed immediately

:::tip
Deleting a step automatically renumbers remaining steps.
:::

### Move Up (↑)

Move the selected step earlier in the sequence:
1. Select a step
2. Click **↑** (Move Up)
3. Step swaps with the step above

Disabled if the step is already first.

### Move Down (↓)

Move the selected step later in the sequence:
1. Select a step
2. Click **↓** (Move Down)
3. Step swaps with the step below

Disabled if the step is already last.

## Step Dialog

When adding or editing a step, the Step Dialog appears:

```
┌─────────────────────────────────────────────┐
│  Add Step                               [X] │
├─────────────────────────────────────────────┤
│  Type:         [AutoDrive     ▼]            │
│                                             │
│  Target:       [Field1_Entrance  ▼] 🔍      │
│                                             │
│  Action:       [Drive To       ▼]           │
│                                             │
│  Unload Target: [               ▼] 🔍       │
│  (Only for Pickup and Deliver, Load, Unload Combine) │
│                                             │
│  Fill Type:    [WHEAT          ▼]           │
│  (Optional cargo filter)                    │
├─────────────────────────────────────────────┤
│              [Cancel]   [OK]                │
└─────────────────────────────────────────────┘
```

![Step Dialog – AutoDrive](/img/screenshots/step-dialog-autodrive.png)
![Step Dialog – Courseplay](/img/screenshots/step-dialog-courseplay.png)

### Searchable Dropdowns

Target and course dropdowns support search:
- Click the search icon (🔍) next to the dropdown
- Type to filter the list
- Select from filtered results

This is especially useful when you have many AD destinations or CP courses.

### Dynamic Fields

Fields shown depend on step type and action:

**AutoDrive with single destination** (**Drive To**, **Deliver**):
- Target
- Action

**AutoDrive with two destinations** (**Pickup and Deliver**, **Load**, **Unload Combine**):
- Target
- Action
- Unload Target
- Fill Type (optional)

**Courseplay**:
- Target (course)
- Action

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **Backspace** | Delete selected step |
| **+** | Move step up |
| **-** | Move step down |

## Workflow Name

The workflow name is shown in the title bar. You can rename it via the main dialog.

## Saving

Changes are saved automatically when:
- Closing the editor dialog
- Closing the main dialog
- Saving the game

## Best Practices

1. **Logical ordering**: Place navigation steps before work steps
2. **Complete sequences**: End with a step that returns the vehicle to a known location
3. **Test components**: Verify AD routes and CP courses work before adding to workflow
4. **Use descriptive targets**: Name your AD destinations and CP courses clearly
