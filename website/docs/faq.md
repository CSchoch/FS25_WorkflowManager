---
id: faq
title: FAQ
sidebar_position: 7
---

# Frequently Asked Questions

## General

### What is Workflow Manager?

Workflow Manager is a mod that connects AutoDrive and Courseplay, allowing you to create automated sequences of navigation and field work.

### Do I need both AutoDrive and Courseplay?

Yes, both mods are required. Workflow Manager acts as a bridge between them.

### Does it work in multiplayer?

Yes, workflows execute on the server and all players can see workflow status.

### Are my workflows saved?

Yes, workflows are saved automatically in your savegame folder and persist between sessions.

---

## Workflows

### How many steps can a workflow have?

There is no hard limit. However, very long workflows may be harder to manage.

### Can I copy a workflow?

Not currently. This feature is planned for a future update.

### Can I share workflows with others?

You can manually copy the `workflowManager.xml` file between savegames, but target names must match.

### Why can't I see my AutoDrive destinations?

Ensure AutoDrive is installed and you have created at least one map marker/destination.

### Why can't I see my Courseplay courses?

Courses must be saved in Courseplay before they appear. Check:
- `modSettings/FS25_Courseplay/Courses/[MapName]/`

---

## Execution

### How do I open the Workflow Manager?

Press **Left Alt + W** from anywhere (on foot or in a vehicle).

### What are the keyboard shortcuts?

| Shortcut | Action |
|----------|--------|
| **Left Alt + W** | Open/close the Workflow Manager |
| **Left Alt + H** | Toggle the HUD overlay |

### Why won't my workflow start?

Check:
1. You're in a compatible vehicle (has both AD and CP support)
2. The workflow has at least one step
3. No other AD or CP job is running

### Can I use any vehicle?

The vehicle must have both AutoDrive and Courseplay specializations. Most tractors, harvesters, and trucks support both.

### What happens if I exit the vehicle during a workflow?

The workflow continues running. You can re-enter the vehicle to see the HUD.

### Can I run multiple workflows simultaneously?

One workflow per vehicle. Multiple vehicles can each run their own workflow. To coordinate two vehicles together, use [Linked Workflows](workflows/linked-workflows).

### What happens after I reload a savegame?

Workflows that were running are set to paused. Open the Workflow Manager and resume them to continue from the saved step.

### What if a step fails?

The workflow stops and shows an error. Fix the issue, then restart or use the HUD to skip the step.

---

## Linked Workflows

### What is a linked workflow?

A linked workflow pairs two workflows as **main** and **support** for coordinated multi-vehicle automation — for example, a combine harvester (main) and an unloader (support) working together across multiple fields.

### How does sync work between linked workflows?

Steps are assigned **sync group** numbers. Steps with the same group across the two workflows run in parallel — the support loops its step while the main is in that phase. When the main advances to a new sync group, the support automatically jumps to the matching step.

### Do both workflows start automatically?

No. You start each workflow separately on its own vehicle. The support syncs to the main's current group if it starts late.

### Does pausing the main also pause the support?

Yes. Pause, resume, and stop actions on the main are automatically propagated to the support workflow.

### Can I still manually control the support vehicle's steps?

Yes. You can use the HUD's Previous/Next buttons on the support vehicle at any time. The sync will realign on the next main group transition.

### What is "Auto Groups"?

A button in the editor dialog that automatically assigns sync group numbers to all steps. It increments the group after each Courseplay step, which is the correct pattern for most harvest workflows. It saves you from assigning numbers manually.

---

## Technical

### Where are workflows stored?

```
Documents/My Games/FarmingSimulator2025/savegame[X]/workflowManager.xml
```

### Can I edit workflows manually?

Yes, you can edit the XML file directly when the game is not running.

### Does Workflow Manager affect performance?

Impact is minimal. The mod checks workflow state twice per second (every 500ms) when a workflow is running.

### Something went wrong — where do I find error details?

The game writes errors to `log.txt` in your Farming Simulator 25 root folder. If you're reporting a bug, include relevant lines from this file.

---

## Future Plans

### Will there be a queue system?

Yes, a queue system for multiple vehicles is planned for Phase 2.

### Will conditions be supported?

Advanced workflow conditions (wait for, if/then) are planned for future updates.

### Will there be visual route planning?

This is being considered for future development.
