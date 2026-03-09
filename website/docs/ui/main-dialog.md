---
id: main-dialog
title: Main Dialog
sidebar_position: 1
---

# Main Dialog

The Main Dialog is the entry point for managing all your workflows.

## Accessing the Dialog

- Press **Left Alt + W** from anywhere (on foot or in a vehicle)

## Interface Overview

```
┌───────────────────────────────────────────────────────┐
│  Workflow Manager                                 [X] │
├───────────────────────────────────────────────────────┤
│                                                       │
│  [Harvest Fields 1-3]          6 steps                │
│  [Fertilize - North]           4 steps                │
│  [Baling Route]                3 steps                │
│                                                       │
├───────────────────────────────────────────────────────┤
│  [New]  [Edit]  [Delete]  [Link]  [Unlink]            │
│  [Start]  [Stop]                                      │
└───────────────────────────────────────────────────────┘
```

![Main Dialog](/img/screenshots/main-dialog.png)

## Workflow List

The main area displays all saved workflows with:

| Column | Description |
|--------|-------------|
| Name | Workflow name (click to select) |
| Steps | Number of steps in the workflow |

### Selection

- **Single click**: Select a workflow
- **Double click**: Open the workflow editor

## Action Buttons

### New Workflow

Creates a new workflow:
1. Click **New**
2. Enter a workflow name in the dialog
3. Click **OK**
4. The Editor Dialog opens for adding steps

### Edit Workflow

Opens the selected workflow for editing:
1. Select a workflow from the list
2. Click **Edit** (or double-click the workflow)
3. The Editor Dialog opens

### Delete Workflow

Removes the selected workflow:
1. Select a workflow from the list
2. Click **Delete**
3. Confirm the deletion

:::warning
Deleted workflows cannot be recovered.
:::

### Link Workflow

Links the selected workflow to a partner workflow for coordinated multi-vehicle operation:
1. Select a workflow (this becomes the **main**)
2. Click **Link**
3. Select the partner workflow (this becomes the **support**)
4. Click **OK**

The two workflows are now paired. See [Linked Workflows](../workflows/linked-workflows) for details.

### Unlink Workflow

Removes the link between the selected workflow and its partner:
1. Select either workflow in a linked pair
2. Click **Unlink**

Both workflows are unlinked simultaneously.

### Start Workflow

Begins execution of the selected workflow:
1. Ensure you are in a compatible vehicle
2. Select a workflow
3. Click **Start**

Requirements:
- Vehicle must support both AutoDrive and Courseplay
- Workflow must have at least one step
- No other AD/CP job can be running

### Stop Workflow

Stops a running workflow:
1. Select the running workflow
2. Click **Stop**

This resets the workflow to step 1 and sets status to "ready".

## Keyboard Shortcuts

### Global (work anywhere)

| Shortcut | Action |
|----------|--------|
| **Left Alt + W** | Open the Workflow Manager |

### In the Dialog

| Key | Action |
|-----|--------|
| **S** | Start selected workflow |
| **X** | Stop selected workflow |
| **D** | Delete selected workflow |
| Double-click | Edit workflow |

## Resume After Save

If you save the game while a workflow is running, the vehicle's state is preserved automatically. When you reload, the workflow is restored as paused on the vehicle — use the **HUD** to resume from where it left off.

Clicking **Start** in the main dialog always starts the workflow fresh from step 1.

## Persistence

- Workflows are auto-saved when closing the dialog
- Changes are stored in `savegame[X]/workflowManager.xml`
- Workflows persist between game sessions
