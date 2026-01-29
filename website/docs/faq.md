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

Currently, only one workflow per vehicle. Multiple vehicles can run different workflows.

### What if a step fails?

The workflow pauses and shows an error. Fix the issue and use the HUD to resume or skip the step.

---

## Technical

### Where are workflows stored?

```
Documents/My Games/FarmingSimulator2025/savegame[X]/workflowManager.xml
```

### Can I edit workflows manually?

Yes, you can edit the XML file directly when the game is not running.

### Does Workflow Manager affect performance?

Impact is minimal. The mod only checks workflow state once per frame when a workflow is running.

### Is there a debug mode?

Check `DevConfig.lua` for development settings and logging options.

---

## Future Plans

### Will there be a queue system?

Yes, a queue system for multiple vehicles is planned for Phase 2.

### Will conditions be supported?

Advanced workflow conditions (wait for, if/then) are planned for future updates.

### Will there be visual route planning?

This is being considered for future development.
