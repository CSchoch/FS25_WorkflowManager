---
id: intro
title: Introduction
sidebar_position: 1
---

# FS25 Workflow Manager

A mod for Farming Simulator 25 that combines **AutoDrive** and **Courseplay** to create automated workflows. The mod allows multiple fields to be processed sequentially by using AutoDrive for transport between fields and Courseplay for the actual field work.

## What is Workflow Manager?

Workflow Manager bridges the gap between AutoDrive and Courseplay, allowing you to create complete automation sequences for your farm operations. Instead of manually starting each mod and switching between them, you define a workflow once and let it run automatically.

## Key Features

- **Workflow Creation**: Create multi-step workflows combining AutoDrive routes and Courseplay courses
- **Visual Editor**: Simple tabular interface for creating and managing workflows
- **In-Vehicle HUD**: Control workflows directly from your vehicle with pause, resume, and step navigation — draggable to any screen position
- **Multi-Vehicle Workflows**: Nest support sub-steps inside main steps so a helper vehicle (e.g., unloader) works in sync with the main vehicle (e.g., combine) — all in a single workflow
- **XML Storage**: Workflows are saved per savegame and persist between sessions
- **Automatic Switching**: Seamlessly transitions between AutoDrive and Courseplay
- **Save/Resume**: Active workflows are saved with the game and auto-resume after loading

## How It Works

1. **Create a workflow** with multiple steps using the GUI (press **Left Alt + W**)
2. **Define steps** - each step is either an AutoDrive route or a Courseplay course
3. **Start the workflow** from your vehicle
4. **Watch automation** - the mod handles transitions between steps automatically

## Example Workflow

```
1. AutoDrive → Drive to Field 1
2. Courseplay → Harvest Field 1
3. AutoDrive → Drive to Silo (unload)
4. AutoDrive → Drive to Field 2
5. Courseplay → Harvest Field 2
6. AutoDrive → Return to Farm
```

## Requirements

- **Farming Simulator 25**
- **AutoDrive** (FS25 version)
- **Courseplay** (FS25 version)

Both mods must be installed and properly configured with destinations (AutoDrive) and courses (Courseplay) before creating workflows.

## Quick Links

- [Getting Started](getting-started) - Set up your first workflow
- [Creating Workflows](workflows/creating-workflows) - Detailed workflow creation guide
- [Step Types](workflows/step-types) - AutoDrive and Courseplay step options
- [Multi-Vehicle Workflows](workflows/linked-workflows) - Coordinate main + support vehicles with support sub-steps
- [Troubleshooting](troubleshooting) - Common issues and solutions
