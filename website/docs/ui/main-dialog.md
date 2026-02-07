---
id: main-dialog
title: Main Dialog
sidebar_position: 1
---

# Main Dialog

The Main Dialog is the entry point for managing all your workflows.

## Accessing the Dialog

1. Press **ESC** to open the game menu
2. Click on **Workflow Manager** in the menu

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

| Key | Action |
|-----|--------|
| ESC | Close dialog |
| Enter | Start selected workflow (when in vehicle) |
| Delete | Delete selected workflow |

## Status Colors

| Status | Color |
|--------|-------|
| ready | White |
| running | Green |
| paused | Yellow |
| completed | Blue |

## Filtering

Currently, all workflows are shown. Future updates may add:
- Search by name
- Filter by status
- Sort options

## Persistence

- Workflows are auto-saved when closing the dialog
- Changes are stored in `savegame[X]/workflowManager.xml`
- Workflows persist between game sessions
