---
id: hud-controls
title: HUD Controls
sidebar_position: 3
---

# HUD Controls

The in-vehicle HUD provides workflow control without opening menus.

## HUD Overview

When a workflow is running, an overlay appears on screen:

![HUD while workflow is running](/img/screenshots/hud-running.png)

The **Pause** and **Resume** buttons share the same slot. The button shows `||` (Pause) while the workflow is running, and switches to `▶` (Resume) when the workflow is paused.

Hovering over any button shows a tooltip label: **Previous Step**, **Pause**, **Resume**, **Stop**, or **Next Step**.

### Main Vehicle with Support Vehicles

If one or more support vehicles are following the same workflow, a colored badge appears next to the workflow name in the header:

![Main vehicle HUD with support badge](/img/screenshots/hud-support-main.png)

The `[NS]` badge shows the number of active support vehicles. Its color indicates their combined status: **green** (running), **orange** (paused), **gray** (idle/waiting).

### Support Vehicle HUD

When running as a **support vehicle**, the HUD shows which main step is being followed and which sub-step is currently executing:

![Support vehicle HUD](/img/screenshots/hud-support-vehicle.png)

`Step 2.1/2` means: the main vehicle is on step 2, and the support vehicle is executing sub-step 1 of 2 sub-steps for that main step. When the support vehicle finishes all sub-steps it waits until the main advances.

## HUD Position

The HUD can be freely repositioned by dragging:
- **Click and drag the header** to move the HUD anywhere on screen
- Position is clamped to screen bounds so it won't go off-screen
- The header changes color while dragging for visual feedback
- Default position: lower-left area

## Status Display

### Vehicle Name / Workflow Name
The header shows **WorkflowManager | VehicleName** (vehicle name truncated to 16 characters). The line below shows the workflow name, including the support badge if support vehicles are active.

### Step Counter
Shows current step and total steps (e.g., `Step 2/5`). For support vehicles, shows the sub-step counter (e.g., `Step 2.1/2`).

### Step Target
Displays the target destination or course name for the current step (e.g., `Field1_Harvest`). No AD/CP type prefix is shown.

## Control Buttons

### Previous Step (`<<`)

**Function**: Jump to the previous step

**When to use**:
- Repeat a step that didn't complete correctly
- Go back after accidentally skipping

**Behavior**:
- Stops current step
- Moves to previous step
- Starts that step

**Disabled when**: On step 1 (no previous step)

### Pause / Resume (`||` / `▶`)

**Function**: Toggle workflow pause state. The button shows **Pause** (`||`) while running and switches to **Resume** (`▶`) when paused — only one is visible at a time.

**Pause (`||`)** — shown while the workflow is running:
- Suspends the current step
- AutoDrive pauses navigation
- Courseplay pauses field work
- If you are the main vehicle, all support vehicles pause too

**Resume (`▶`)** — shown while the workflow is paused:
- Continues from where it stopped

**When to use**:
- Need to make manual adjustments
- Temporary stop without resetting

### Stop (□)

**Function**: Completely stop the workflow

**Behavior**:
- Stops current step
- Resets workflow to step 1
- Sets status to Ready
- Stops any running AD/CP jobs
- If you are the main vehicle, all support vehicles are stopped too

**When to use**:
- Abort the workflow
- Something went wrong
- Want to restart from beginning

### Next Step (`>>`)

**Function**: Skip to the next step

**When to use**:
- Current step is stuck
- Want to skip a step manually
- Testing workflow progression

**Behavior**:
- Stops current step
- Moves to next step
- Starts that step

**Disabled when**: On last step (no next step)

## Button States

### Visual Feedback

| State | Color | Description |
|-------|-------|-------------|
| Normal | White | Default state |
| Hover | Cyan | Mouse is over button |
| Active | Green | Currently active (e.g., running) |
| Disabled | Gray | Action not available |

## Interaction

### Mouse Control
- Move mouse over buttons to see hover effect
- Click to activate the button

### Toggle HUD

Press **Left Alt + H** to show or hide the HUD overlay.

## When HUD Appears

The HUD is visible when:
- A workflow is running or paused
- You are in the vehicle that started the workflow

The HUD hides when:
- Workflow is stopped or completed
- You exit the vehicle
- Game menu is open

## HUD Updates

The HUD updates in real-time:
- Step counter updates on step change
- Button states update on workflow state change
- Target info updates for each step

## Customization

- Toggle the HUD with **Left Alt + H**
- Reposition the HUD by dragging the header to any location on screen

## Troubleshooting

### HUD Not Appearing
- Ensure a workflow is running
- Check you're in the correct vehicle
- Verify the workflow has steps

### Buttons Not Responding
- Check button is not disabled (gray)
- Ensure mouse is clicking the button area
- Game may need focus

### HUD Overlapping Other UI
- Drag the HUD to a different position by clicking and holding the header
- The F1 help menu is a known overlap — close it when using workflows
