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

1. Press **Left Alt + W** to open the Workflow Manager
2. Select a workflow from the list
3. Click **Start** (or press **S**)

Workflows without support sub-steps start immediately and the dialog closes.

### Role Selection (Multi-Vehicle Workflows)

If the workflow contains support sub-steps, a **Role Selection** dialog appears before starting:

```
┌──────────────────────────────────────────┐
│  Wheat Harvest – Fields 1 & 2            │
│  This workflow has support steps.        │
│  Choose your role:                       │
│                                          │
│  [Run as Main Vehicle] [Run as Support]  │
│                       [Cancel]           │
└──────────────────────────────────────────┘
```

- **Run as Main Vehicle** — this vehicle leads the workflow. It executes the main steps in order.
- **Run as Support Vehicle** — this vehicle is a helper. It executes the support sub-steps for whichever main step the lead vehicle is currently on.

To run a two-vehicle setup:
1. Enter the **main vehicle** (e.g., combine) → open Workflow Manager → Start → **Run as Main Vehicle**
2. Enter the **support vehicle** (e.g., unloader) → open Workflow Manager → Start → **Run as Support Vehicle**

Both vehicles use the same workflow. The main dialog shows `[+S]` next to workflows that have support sub-steps.

See [Multi-Vehicle Workflows](linked-workflows) for full details.

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

For support vehicles the step counter shows the sub-step position, e.g. `Step 2.1/2` (main is on step 2, support is executing sub-step 1 of 2).

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
- If paused from the **main vehicle**, all active support vehicles pause too

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
- Stopping the **main vehicle** also stops all active support vehicles

## Step Completion

### AutoDrive Step Completion

An AutoDrive step completes when:
- The vehicle reaches the destination
- The unload/load operation finishes (for cargo modes)

### Courseplay Step Completion

A Courseplay step completes when the field work course finishes.

### Support Sub-Step Sequencing

When running as a support vehicle:
1. Execute sub-step 1 for the current main step
2. Execute sub-step 2 … continue through all sub-steps
3. After the last sub-step — **wait** for the main vehicle to advance
4. When the main advances, immediately start sub-step 1 of the new step

If the main vehicle advances to a step that has no support sub-steps, the support vehicle idles until the main moves on again.

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

If you save the game while a workflow is running, the vehicle's state is preserved automatically. When you reload, the workflow is restored as paused — use the **HUD Resume button** (`>`) to continue from where it left off. The role (Main or Support) and the current sub-step are also saved and restored.

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
6. **Start main vehicle first**: For multi-vehicle setups, start the main vehicle before the support vehicle so the support can join at the correct step
