---
id: installation
title: Installation
sidebar_position: 3
---

# Installation

## Download

Download the latest version of FS25 Workflow Manager from:
- [GitHub Releases](https://github.com/CSchoch/LS25_WorkflowManager/releases)
- Giants ModHub (coming soon)

## Installation Steps

### Standard Installation

1. Download `FS25_WorkflowManager.zip`
2. Copy the ZIP file to your mods folder:
   ```
   Documents/My Games/FarmingSimulator2025/mods/
   ```
3. Do **not** extract the ZIP file - the game loads mods directly from ZIP

### Required Dependencies

Workflow Manager requires both of these mods to be installed:

| Mod | Download | Description |
|-----|----------|-------------|
| **AutoDrive** | [GitHub](https://github.com/Stephan-S/FS25_AutoDrive) | Handles navigation between locations |
| **Courseplay** | [GitHub](https://github.com/Courseplay/Courseplay_FS25) | Handles field work automation |

### Verifying Installation

1. Start Farming Simulator 25
2. In the mod selection screen, ensure all three mods are enabled:
   - FS25_WorkflowManager
   - FS25_AutoDrive
   - FS25_Courseplay
3. Load a savegame
4. Press ESC - you should see "Workflow Manager" in the menu

## File Structure

After installation, your mods folder should contain:

```
mods/
├── FS25_WorkflowManager.zip
├── FS25_AutoDrive.zip
└── FS25_Courseplay.zip
```

## Savegame Data

Workflows are stored per savegame in:
```
Documents/My Games/FarmingSimulator2025/savegame[X]/workflowManager.xml
```

This file is created automatically when you save your first workflow.

## Updating

To update Workflow Manager:

1. Download the new version
2. Replace the old ZIP file in your mods folder
3. Your workflows are preserved (stored in savegame, not mod)

## Uninstallation

To remove Workflow Manager:

1. Delete `FS25_WorkflowManager.zip` from your mods folder
2. Optionally delete `workflowManager.xml` from each savegame folder

## Troubleshooting Installation

### Mod Not Showing in Menu

- Verify the ZIP file is in the correct mods folder
- Check that AutoDrive and Courseplay are also enabled
- Look at the game log for error messages

### Dependencies Not Found

If you see "AutoDrive not found" or "Courseplay not found":
- Ensure both dependency mods are installed and enabled
- Load the savegame again after enabling the mods

See [Troubleshooting](./troubleshooting) for more common issues.
