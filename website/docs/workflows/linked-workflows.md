---
id: linked-workflows
title: Linked Workflows
sidebar_position: 4
---

# Linked Workflows

Linked workflows let you coordinate two vehicles working together — for example, a combine harvester and an unloader/grain cart running in sync across multiple fields.

## What Are Linked Workflows?

Two workflows can be paired as **main** and **support**:

- The **main** workflow drives the operation (e.g., combine harvesting field by field)
- The **support** workflow follows the main's progress (e.g., unloader driving between the combine and the silo)

When the main workflow advances to the next field, the support automatically follows. Pausing, resuming, or stopping the main also affects the support vehicle automatically.

## Roles

| Role | Description |
|------|-------------|
| **Main** | The lead vehicle. Its progress determines when the pair advances to the next field. |
| **Support** | The helper vehicle. Repeats its current task until the main moves on. |

## Sync Groups

Sync groups coordinate which steps on each workflow belong to the same phase of work. Steps with the same sync group number run in parallel — the support loops its step while the main is in that group.

**Example — Harvest + Unloader:**

| Step | Main (Combine) | Sync Group | Support (Unloader) |
|------|---------------|------------|-------------------|
| 1 | Drive to Field 1 | 1 | Unload combine at Field 1 → Silo |
| 2 | Harvest Field 1 | 1 | *(loops unload step)* |
| 3 | Drive to Field 2 | 2 | Unload combine at Field 2 → Silo |
| 4 | Harvest Field 2 | 2 | *(loops unload step)* |

When the main finishes step 2 (harvesting) and moves to step 3 (drive to Field 2), the sync group changes from 1 → 2. The support automatically stops its current loop and jumps to its step 3.

## Setting Up Linked Workflows

### Step 1: Create Both Workflows

Create each workflow independently first:
- **Main workflow**: Full sequence (drive → fieldwork → drive → fieldwork…)
- **Support workflow**: Support actions for each phase (unload → unload…)

### Step 2: Link Them

1. Open the **Workflow Manager** (Left Alt + W)
2. Select the workflow you want to make the **main**
3. Click **Link**
4. Select the workflow to become the **support** from the dialog
5. Click **OK**

The main workflow now shows a link indicator, and the support shows its partner.

### Step 3: Assign Sync Groups

In the **Step Dialog**, set the **Sync Group** field (only visible when the workflow is linked). Use the same integer for all steps that belong to the same phase of work.

## Starting Linked Workflows

Start each workflow separately on its respective vehicle:

1. Enter the **combine** and start the **main** workflow
2. Enter the **unloader** and start the **support** workflow

The support will sync to the main's current phase automatically if it starts late.

:::note
Workflows are started independently. The main does not auto-start the support.
:::

## Runtime Behavior

### Pause / Resume / Stop Propagation

| Action on Main | Effect on Support |
|---------------|------------------|
| Pause | Support is also paused |
| Resume | Support is also resumed |
| Stop | Support is also stopped |

### Support Looping

While the main remains in the same sync group, the support loops **all steps in that sync group** from the beginning. If the support has only one step in a group it repeats that step; if it has two or more steps (e.g. `drive` then `unload`) it runs through all of them and then restarts from the first step of the group.

This is the intended behavior for unloader vehicles — they keep shuttling until the harvester moves to the next field.

### Late Start

If the support vehicle starts its workflow after the main is already running, it syncs to the main's current sync group and jumps to the matching step. You don't need to manually fast-forward.

### Manual Step Override

You can still use **Previous**/**Next** on the support vehicle's HUD to change its step manually at any time. It will automatically re-sync the next time the main workflow advances to a new phase.

## HUD Status Line

When a workflow is linked, the HUD shows a second status line with the partner's info:

```
┌──────────────────────────────────────────┐
│  Wheat Harvest (Combine)                 │
│  Step 2/4: Courseplay - Field Work       │
│  Target: Field1_Harvest                  │
│  Partner: Unloader Support · Step 1/2    │
├──────────────────────────────────────────┤
│  [<<]  [||/▶]   [□]   [>>]              │
└──────────────────────────────────────────┘
```

The partner line shows the linked workflow's name and current step, giving you visibility into both vehicles from either HUD.

## Unlinking Workflows

To remove a link between workflows:

1. Open the **Workflow Manager**
2. Select either workflow in the pair
3. Click **Unlink**

Both workflows are unlinked simultaneously. Their steps and sync group values are preserved.

:::warning
Unlinking does not remove sync group values from steps. If you later re-link with a different partner, review the sync groups in the editor.
:::

## Pre-positioning the Unloader

When AutoDrive starts an **Unload** step and the unloader is already on or near the field, it immediately enters passive waiting mode at its current position. It stays there until the combine signals it needs emptying — it will not move to a designated waiting spot on its own. This can cause the unloader to sit in the middle of the field and block the combine's path.

**Solution**: add a **Drive** step with the same sync group before the **Unload** step. This moves the unloader to a marker near the field first. Once it arrives, the Unload step loops it between the field and the silo as normal.

**Example support workflow:**

| Step | Action | Target | Unload Target | Sync Group |
|------|--------|--------|---------------|------------|
| 1 | Drive | Field1\_Entrance | — | 1 |
| 2 | Unload | Field1\_Area | Silo | 1 |
| 3 | Drive | Field2\_Entrance | — | 2 |
| 4 | Unload | Field2\_Area | Silo | 2 |

Steps 1 and 2 share sync group 1, so the support loops 1 → 2 → 1 → 2 while the main harvests field 1. On the first pass the unloader drives to the field entrance; on subsequent loops it goes straight to the field area. When the main transitions to sync group 2, the support jumps to step 3 and repeats the pattern for field 2.

:::tip
Place the **Drive** marker at the field entrance or a nearby headland position. This keeps the unloader close enough to respond quickly when the combine calls, without blocking the combine's path.
:::

:::tip
The Drive step also acts as a natural delay that prevents the unloader from arriving at the field before the combine and blocking it. Both vehicles start their sync group at the same time, but the unloader spends the drive leg in transit. By the time it reaches the entrance marker and the Unload step begins, the combine has usually already started field work and is ready to call for unloading. If the unloader still arrives too early, use a farther Drive marker to extend the delay.
:::

:::note
Because both steps share the same sync group, assign them the same sync group number in the Step Dialog.
:::

---

## Tips and Best Practices

- **Name clearly**: Use names like "Harvest - Main" and "Harvest - Unloader" so the pair is obvious
- **Test each workflow first**: Verify both work independently before linking
- **Support should loop safely**: The support's step at each sync group should be one that makes sense to repeat (e.g., unload, not a one-time drive)
- **Multiple steps per sync group are supported**: You can add a `Drive` step and an `Unload` step in the same group — the support loops through all steps in the group, not just the last one
- **Pre-position the unloader**: Add a Drive step (same sync group) before each Unload step so the unloader is already near the field when it starts — see [Pre-positioning the Unloader](#pre-positioning-the-unloader) above
