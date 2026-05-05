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

![Main Dialog](/img/screenshots/main-dialog.png)

## Workflow List

The main area displays all saved workflows with:

| Column | Description |
|--------|-------------|
| Name | Workflow name — colored **green** (running), **orange** (paused), or **white** (idle) on the current vehicle |
| Steps | Total step count, or `current/total` progress (e.g., `2/6`) while the workflow is active on the current vehicle |

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

### AD/CP Settings

Opens the AutoDrive settings override dialog for the selected workflow:
1. Select a workflow from the list
2. Click **AD/CP Settings**
3. Adjust the values and click **OK**

These settings are applied automatically every time the workflow starts. See [Per-Workflow AD Settings](#per-workflow-ad-settings) below for details.

## Per-Workflow AD Settings

Each workflow can store AutoDrive setting overrides that are applied to the vehicle automatically whenever the workflow starts (or auto-resumes after a save/reload).

Click **AD/CP Settings** in the main dialog to open the settings dialog for the selected workflow.

![AD/CP Settings Dialog](/img/screenshots/ad-settings-dialog.png)

| Setting | Unit | Description |
|---------|------|-------------|
| **Unload Fill Level** | % (0–100) | Minimum fill level before AutoDrive calls an unloader. Leave empty to keep AutoDrive's current value. |
| **Pipe Offset** | meters | Horizontal pipe position offset for unloading. Leave empty to keep AutoDrive's current value. |
| **Pre-Call Level** | % (0–100) | Fill level at which AutoDrive pre-calls the unloader so it arrives just in time. Leave empty to keep AutoDrive's current value. |

:::tip
Leave a field **empty** to leave that setting unchanged — the workflow will use whatever value is already configured in AutoDrive for that vehicle.
:::

Settings are stored inside the workflow definition and persist across sessions. They are re-applied each time the workflow starts a new AutoDrive step, so AutoDrive's own route-start logic cannot overwrite them.

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
