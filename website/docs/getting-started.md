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

## Creating Your First Workflow

### Step 1: Open the Workflow Manager

1. Press **ESC** to open the game menu
2. Navigate to **Workflow Manager** in the menu
3. The main dialog will show a list of existing workflows (empty initially)

### Step 2: Create a New Workflow

1. Click the **New Workflow** button
2. Enter a name for your workflow (e.g., "Harvest Field 1")
3. The workflow editor will open

### Step 3: Add Steps

1. Click **Add Step** to create a new step
2. Select the step type:
   - **AutoDrive** - For navigation between locations
   - **Courseplay** - For field work
3. Configure the step:
   - For AutoDrive: Select target destination and action (drive, unload, etc.)
   - For Courseplay: Select the course and action (fieldwork, bale collect)
4. Click **OK** to add the step

### Step 4: Save the Workflow

1. Review your steps in the editor
2. Close the editor to save automatically
3. Your workflow appears in the main list

## Running a Workflow

### Start the Workflow

1. Enter a compatible vehicle (must have both AD and CP support)
2. Open the Workflow Manager
3. Select a workflow from the list
4. Click **Start** or use the keyboard shortcut

### Monitor Progress

- The **in-vehicle HUD** shows the current workflow status
- Use HUD buttons to:
  - **Pause/Resume** the workflow
  - **Skip** to next/previous step
  - **Stop** the workflow

### Workflow Completion

When all steps complete, the workflow status changes to "completed". You can restart it from the beginning at any time.

## Example: Simple Harvest Workflow

Here's a practical example of a wheat harvest workflow:

| Step | Type       | Target           | Action      |
|------|------------|------------------|-------------|
| 1    | AutoDrive  | Field 1 Entrance | drive       |
| 2    | Courseplay | Wheat Harvest F1 | fieldwork   |
| 3    | AutoDrive  | Farm Silo        | drive       |

This workflow:
1. Drives the harvester to Field 1
2. Runs the Courseplay course to harvest the field
3. Returns to the farm silo

## Next Steps

- Learn about [Step Types](./workflows/step-types) for more automation options
- Explore the [User Interface](./ui/main-dialog) in detail
- Check [Troubleshooting](./troubleshooting) if you encounter issues
