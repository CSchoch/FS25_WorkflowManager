---
id: hud-controls
title: HUD Controls
sidebar_position: 3
---

# HUD Controls

The in-vehicle HUD provides workflow control without opening menus.

## HUD Overview

When a workflow is running, an overlay appears on screen:

```
┌──────────────────────────────────────┐
│  Harvest Fields 1-2            ════  │  ← drag handle
│  Step 2/5: Courseplay - Field Work   │
│  Target: Field1_Harvest              │
├──────────────────────────────────────┤
│  [<<]  [||/▶]   [□]   [>>]          │
│  Prev  Pause/  Stop   Next           │
│        Resume                        │
└──────────────────────────────────────┘
```

The **Pause** and **Resume** buttons share the same slot. The button shows `||` (Pause) while the workflow is running, and switches to `▶` (Resume) when the workflow is paused.

If the vehicle is part of a **linked workflow** pair, a second status line shows the partner's progress:

```
┌──────────────────────────────────────┐
│  Wheat Harvest (Combine)       ════  │
│  Step 2/4: Courseplay - Field Work   │
│  Target: Field1_Harvest              │
│  Partner: Unloader Support · Step 1/2│
├──────────────────────────────────────┤
│  [<<]  [||/▶]   [□]   [>>]          │
└──────────────────────────────────────┘
```

![HUD while workflow is running](/img/screenshots/hud-running.png)

## HUD Position

The HUD can be freely repositioned by dragging:
- **Click and drag the header** to move the HUD anywhere on screen
- Position is clamped to screen bounds so it won't go off-screen
- The header changes color while dragging for visual feedback
- Default position: lower-left area

## Status Display

### Workflow Name
Shows the name of the currently running workflow.

### Step Counter
Shows current step and total steps (e.g., "Step 2/5").

### Step Details
Displays:
- Step type (AutoDrive or Courseplay)
- Action being performed
- Target destination or course

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
