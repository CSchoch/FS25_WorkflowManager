---
id: courseplay
title: Courseplay Reference
sidebar_position: 2
---

# Courseplay Reference

This page explains how Workflow Manager uses Courseplay and what you need to know to set up Courseplay steps.

## What Courseplay Does

Courseplay handles all **field work** in your workflows. It runs saved courses on your vehicle to perform operations like harvesting, cultivating, seeding, and baling.

## Setting Up Courseplay

Before using Courseplay steps in workflows, you need:

1. **Generate a course** for each field and operation (e.g., a harvesting course for Field 1)
2. **Save the course** in Courseplay's course manager
3. **Attach the right implements** to your vehicle for the operation

### Where Courses Are Stored

Courseplay saves courses per map in:
```
Documents/My Games/FarmingSimulator2025/modSettings/FS25_Courseplay/Courses/[MapName]/
```

You can organize courses in subfolders. When selecting courses in Workflow Manager, folder paths appear as `FolderName/CourseName`.

## Courseplay Actions

### Field Work

Runs the saved Courseplay course for general field operations.

**Use for:** Harvesting, cultivating, seeding, spraying, fertilizing, mowing, and any other field operation Courseplay supports.

**How it works:**
1. Workflow Manager loads the specified course onto the vehicle
2. Courseplay starts the field work
3. When the course finishes, the workflow moves to the next step

### Bale Collect

Collects, loads, and wraps bales in the field.

**Use for:** Picking up bales after mowing/baling operations.

## Course Selection

In the step editor, the course dropdown shows all saved courses for the current map:

- Courses are listed alphabetically
- Courses in folders appear as `Folder/CourseName`
- Use the **search box** to quickly find courses by name

## How Courseplay Completion Works

Workflow Manager monitors Courseplay and waits for it to finish before moving to the next step.

### Simple Case
Courseplay finishes the course, the workflow advances.

### With Internal AutoDrive
Sometimes Courseplay triggers AutoDrive internally (e.g., a harvester sends an unloader to deliver grain via AutoDrive). Workflow Manager handles this automatically:

1. Courseplay pauses and starts AutoDrive for the delivery
2. AutoDrive delivers and returns
3. Courseplay resumes field work
4. This cycle repeats until the course is complete
5. Only when both Courseplay AND AutoDrive are finished does the workflow advance

You don't need to set this up separately - it happens automatically if your vehicle is configured for it in AutoDrive/Courseplay.

## Tips

- **Save courses before creating workflows.** The course must exist in Courseplay's saved courses before you can select it in a workflow step.
- **Course names are exact.** If you rename or move a course file, update your workflow steps.
- **Attach implements first.** Make sure the right implements are attached to the vehicle before starting the workflow (e.g., a header for harvesting).
- **Test courses first.** Run each course manually in Courseplay to verify it works correctly before adding it to a workflow.
- **One course per step.** Each Courseplay step uses one saved course. For multiple fields, add separate steps.
