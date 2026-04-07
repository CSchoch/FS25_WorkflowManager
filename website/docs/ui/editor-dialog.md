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
┌─────────────────────────────────────────────────────────┐
│  Edit Workflow: Harvest Fields                     [X]  │
├─────────────────────────────────────────────────────────┤
│  #       Type        Target                 Action  Sup │
│  ──────────────────────────────────────────────────────  │
│  1       AutoDrive   Field1_Entrance        Drive To    │
│  2       Courseplay  Field1_Harvest         Field Work +2│
│  2.1       AutoDrive   Field1              Unload       │
│  2.2       AutoDrive   Silo                Deliver      │
│  3       AutoDrive   Field2_Entrance        Drive To    │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  [Add Step]  [Edit]  [Delete]  [↑]  [↓]                │
│  [Add Support Step]                                     │
└─────────────────────────────────────────────────────────┘

        Double-click a step to edit
```

![Editor Dialog](/img/screenshots/editor-dialog.png)

## Step List

The step list shows main steps and their support sub-steps in a single nested list. Main steps are numbered starting at 1. Support sub-steps appear indented directly below their parent step, numbered `N.M` — where `N` is the parent step number and `M` is the sub-step's position within that step.

| Column | Description |
|--------|-------------|
| # | Step number (`1`, `2`, …) or sub-step number (`2.1`, `2.2`, …) |
| Type | AutoDrive or Courseplay |
| Target | Destination name or course name |
| Action | The action to perform |
| Sup | Shows `+N` on main step rows that have N support sub-steps |

### For AutoDrive steps with two destinations:
- Shows `Target → Unload Target` format
- Example: `Farm/Silo → Sell/Mill`

## Action Buttons

### Add Step

Opens the Step Dialog to add a new **main step**:
1. Click **Add Step**
2. Configure the step (type, target, action)
3. Click **OK**
4. Step is added at the end of the list

### Add Support Step

Adds a support sub-step to the currently selected **main step**:
1. Select a main step row (numbered `1`, `2`, `3`, …)
2. Click **Add Support Step**
3. Configure the sub-step in the Step Dialog
4. Click **OK**

The new sub-step appears indented below its parent, numbered `N.M`. The **Add Support Step** button is disabled when a support sub-step row is selected — select the parent main step first.

For more on support sub-steps and multi-vehicle setups, see [Multi-Vehicle Workflows](../workflows/linked-workflows).

### Edit

Modify the selected step or sub-step:
1. Select a row from the list
2. Click **Edit** (or double-click the row)
3. Modify properties in the Step Dialog
4. Click **OK**

### Delete

Remove the selected step or sub-step:
1. Select the row
2. Click **Delete**

Deleting a main step also removes all of its support sub-steps.

:::tip
Deleting a step automatically renumbers remaining steps.
:::

### Move Up (↑) / Move Down (↓)

Reorder steps:
- For **main steps**: swaps the step with the one above or below
- For **support sub-steps**: reorders within the parent main step's sub-step list

Disabled at the top/bottom of the respective list.

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
│                                             │
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
5. **Add support sub-steps to field work steps**: Drive-to steps usually need no support activity — leave them empty so the support vehicle idles during transit
