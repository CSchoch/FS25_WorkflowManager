---
id: executing-workflows
title: Executing Workflows
sidebar_position: 3
---

# Executing Workflows

This guide covers how to run, monitor, and control workflows during execution.

## Starting a Workflow

### Requirements

Before starting a workflow:
1. Enter a **compatible vehicle** (must have both AutoDrive and Courseplay support)
2. Ensure required **implements are attached**
3. The vehicle should not have another AD or CP job running

### Starting from the GUI

1. Press **Left Alt + W** to open the Workflow Manager (or use the ESC menu)
2. Select a workflow from the list
3. Click **Start** (or press **S**)

The workflow begins with the first step and the dialog closes automatically.

## Workflow Status

Workflows have four possible states:

| Status | Description |
|--------|-------------|
| **Ready** | Workflow is configured and ready to start |
| **Running** | Workflow is actively executing |
| **Paused** | Workflow is paused, waiting for resume |
| **Completed** | All steps have finished |

## In-Vehicle HUD

When a workflow is running, an HUD overlay appears showing:
- Current workflow name
- Current step (e.g., "Step 2/5")
- Step details (type, target, action)
- Control buttons

![HUD while workflow is running](/img/screenshots/hud-running.png)

### HUD Controls

| Button | Icon | Function |
|--------|------|----------|
| Previous | `<<` | Jump to previous step |
| Pause | `||` | Pause the current workflow |
| Resume | `>` | Resume a paused workflow |
| Stop | `□` | Stop and reset the workflow |
| Next | `>>` | Skip to next step |

### Button Colors

- **White**: Normal state
- **Cyan**: Mouse hovering
- **Green**: Active (e.g., play when running)
- **Gray**: Disabled

## Controlling Execution

### Pausing

Pause a workflow to:
- Temporarily stop automation
- Make manual adjustments
- Handle unexpected situations

When paused:
- The current step remains active but suspended
- AutoDrive pauses navigation
- Courseplay pauses field work

### Resuming

Resume a paused workflow:
- Click the Resume (play) button on the HUD
- Execution continues from where it stopped

### Skipping Steps

Use Previous/Next to manually navigate:
- **Next**: Skip to the next step (useful if current step is stuck)
- **Previous**: Go back to repeat a step

:::warning
Skipping steps may leave the vehicle in an unexpected position. Use carefully.
:::

### Stopping

Stop a workflow completely:
- Resets the workflow to step 1
- Sets status back to Ready
- Stops any running AutoDrive or Courseplay jobs

## Step Completion

### AutoDrive Step Completion

An AutoDrive step completes when:
- The vehicle reaches the destination
- The unload/load operation finishes (for cargo modes)

### Courseplay Step Completion

A Courseplay step completes when the field work course finishes.

### Cyclic Operations

Some harvest setups involve a harvester that calls a grain cart or unloader via AutoDrive to deliver grain, then resumes harvesting. Workflow Manager handles this automatically — it waits for both AutoDrive and Courseplay to be fully finished before advancing to the next step. You don't need to set this up specially.

## Error Handling

### Step Fails to Start

If a step cannot start:
1. An error message appears in the HUD
2. The workflow pauses
3. Fix the issue and resume

Common causes:
- Missing destination/course
- Vehicle not compatible
- Another job already running

### Vehicle Becomes Unavailable

If the vehicle is sold or reset during execution:
- The workflow stops automatically
- Status is set to Ready
- Start again with a new vehicle

## Multiplayer Considerations

In multiplayer:
- Workflows execute on the server
- All players can see workflow status
- Only the controlling player can modify execution

## Resume After Save

If you save the game while a workflow is running, the vehicle's state is preserved automatically. When you reload, the workflow is restored as paused — use the **HUD Resume button** (`>`) to continue from where it left off.

Clicking **Start** in the main dialog always starts the workflow fresh from step 1.

## Performance

Workflows are monitored via the game's update loop:
- Minimal performance impact
- Status checks every 500ms when running
- No polling when idle

## Best Practices

1. **Test before running**: Verify AD routes and CP courses work independently
2. **Start with simple workflows**: Begin with 2-3 steps
3. **Monitor first runs**: Watch the first execution to catch issues
4. **Use pause for adjustments**: Pause if you need to intervene
5. **Check vehicle position**: Ensure the vehicle is appropriately positioned before starting
