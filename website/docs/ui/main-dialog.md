---
id: main-dialog
title: Main Dialog
sidebar_position: 1
---

# Main Dialog

The Main Dialog is the entry point for managing all your workflows.

## Accessing the Dialog

- Press **Left Alt + W** from anywhere (on foot or in a vehicle)
- Or press **ESC** and click **Workflow Manager** in the menu

## Interface Overview

```
┌─────────────────────────────────────────────┐
│  Workflow Manager                       [X] │
├─────────────────────────────────────────────┤
│                                             │
│  [Workflow 1]              ready            │
│  [Workflow 2]              running          │
│  [Workflow 3]              completed        │
│                                             │
├─────────────────────────────────────────────┤
│  [New]  [Edit]  [Delete]  [Start]  [Stop]   │
└─────────────────────────────────────────────┘
```

## Workflow List

The main area displays all saved workflows with:

| Column | Description |
|--------|-------------|
| Name | Workflow name (click to select) |
| Status | Current state (ready, running, paused, completed) |

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
| **Left Alt + W** | Open/close the Workflow Manager |
| **Left Ctrl + Left Alt + W** | Quick-start a workflow with current vehicle |
| **Left Shift + Left Alt + W** | Stop the active workflow |

### In the Dialog

| Key | Action |
|-----|--------|
| **S** | Start selected workflow |
| **X** | Stop selected workflow |
| **D** | Delete selected workflow |
| Double-click | Edit workflow |

## Status Colors

| Status | Color |
|--------|-------|
| ready | White |
| running | Green |
| paused | Yellow |
| completed | Blue |

## Resume After Save

If you save the game while a workflow is running, it will be set to **paused** on reload. Select the workflow and click **Start** to resume from the saved step.

To reset a paused workflow back to step 1, click **Stop** first, then **Start**.

## Persistence

- Workflows are auto-saved when closing the dialog
- Changes are stored in `savegame[X]/workflowManager.xml`
- Workflows persist between game sessions
