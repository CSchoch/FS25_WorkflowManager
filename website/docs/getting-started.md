---
id: getting-started
title: Getting Started
sidebar_position: 2
---

# Getting Started

This guide will help you create your first automated workflow in Farming Simulator 25.

## Prerequisites

Before using Workflow Manager, ensure you have:

1. **AutoDrive** installed and configured with at least one destination
2. **Courseplay** installed with at least one saved course
3. A vehicle that supports both AutoDrive and Courseplay

## Keyboard Shortcuts

These shortcuts work both on foot and in a vehicle:

| Shortcut | Action |
|----------|--------|
| **Left Alt + W** | Open/close the Workflow Manager |
| **Left Ctrl + Left Alt + W** | Quick-start a workflow with current vehicle |
| **Left Shift + Left Alt + W** | Stop the active workflow |
| **Left Alt + H** | Toggle the HUD overlay on/off |

## Creating Your First Workflow

### Step 1: Open the Workflow Manager

Press **Left Alt + W** to open the Workflow Manager. You can also find it in the ESC menu.

The main dialog shows your list of workflows (empty at first).

### Step 2: Create a New Workflow

1. Click **New**
2. Enter a name for your workflow (e.g., "Harvest Field 1")
3. The workflow editor opens

### Step 3: Add Steps

1. Click **+** (Add Step) to create a new step
2. Select the step type:
   - **AutoDrive** - For navigation between locations
   - **Courseplay** - For field work
3. Configure the step:
   - For AutoDrive: Select a target destination and action (Drive To, Pickup and Deliver, etc.)
   - For Courseplay: Select a saved course and action (Field Work, Bale Collect)
4. Use the search box to quickly find destinations or courses
5. Click **OK** to add the step

### Step 4: Close the Editor

Close the editor when you're done adding steps. Your workflow is saved automatically.

## Running a Workflow

### Start the Workflow

1. **Get into a vehicle** that has both AutoDrive and Courseplay support
2. Press **Left Alt + W** to open the Workflow Manager
3. Select your workflow from the list
4. Click **Start** (or press **S**)

The workflow begins executing step by step. The dialog closes and the HUD appears.

### Monitor Progress

The **in-vehicle HUD** shows the current workflow status. Use the HUD buttons to:
- **Pause/Resume** the workflow
- **Skip** to next or previous step
- **Stop** the workflow

![HUD while workflow is running](/img/screenshots/hud-running.png)

### Resume After Save

If you save the game while a workflow is running, it will be paused on reload. Select the workflow and click **Start** to continue from where you left off.

### Workflow Completion

When all steps complete the workflow is done. You can restart it from the beginning at any time by selecting it and clicking **Start**.

## Example: Simple Harvest Workflow

Here's a practical example of a wheat harvest workflow:

| Step | Type       | Target           | Action      |
|------|------------|------------------|-------------|
| 1    | AutoDrive  | Field 1 Entrance | Drive To    |
| 2    | Courseplay | Wheat Harvest F1 | Field Work  |
| 3    | AutoDrive  | Farm Silo        | Drive To    |

This workflow:
1. Drives the harvester to Field 1
2. Runs the Courseplay course to harvest the field
3. Returns to the farm silo

## Next Steps

- Learn about [Step Types](./workflows/step-types) for more automation options
- Explore the [User Interface](./ui/main-dialog) in detail
- Check [Troubleshooting](./troubleshooting) if you encounter issues
