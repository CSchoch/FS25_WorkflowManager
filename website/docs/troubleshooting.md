---
id: troubleshooting
title: Troubleshooting
sidebar_position: 8
---

# Troubleshooting

Common issues and solutions for Workflow Manager.

## Installation Issues

### Workflow Manager not showing in menu

**Symptoms**: ESC menu doesn't show Workflow Manager option

**Solutions**:
1. Verify the mod is enabled in the mod selection screen
2. Check that both AutoDrive and Courseplay are also enabled
3. Look at the game log (`log.txt`) for error messages
4. Ensure the ZIP file is not corrupted

### "AutoDrive not found" error

**Symptoms**: Error message when opening Workflow Manager

**Solutions**:
1. Install AutoDrive from GitHub or ModHub
2. Enable AutoDrive in the mod selection
3. Restart the game after enabling

### "Courseplay not found" error

**Symptoms**: Error message when opening Workflow Manager

**Solutions**:
1. Install Courseplay from GitHub or ModHub
2. Enable Courseplay in the mod selection
3. Restart the game after enabling

---

## Workflow Creation Issues

### No destinations in dropdown

**Symptoms**: AutoDrive target dropdown is empty

**Solutions**:
1. Create at least one marker in AutoDrive first
2. Close and reopen the Workflow Manager GUI
3. Check AutoDrive is properly configured

### No courses in dropdown

**Symptoms**: Courseplay course dropdown is empty

**Solutions**:
1. Save at least one course in Courseplay
2. Courses are map-specific - ensure you're on the correct map
3. Check the courses folder: `modSettings/FS25_Courseplay/Courses/[MapName]/`

### Cannot add steps

**Symptoms**: Add Step button doesn't work

**Solutions**:
1. Ensure you have a workflow open in the editor
2. Check the game log for errors
3. Try creating a new workflow

---

## Execution Issues

### Workflow won't start

**Symptoms**: Clicking Start does nothing

**Solutions**:
1. Enter a compatible vehicle first
2. Check the vehicle supports both AD and CP
3. Ensure no other AD/CP job is running
4. Verify the workflow has at least one step

### Step doesn't complete

**Symptoms**: Workflow stuck on a step

**Solutions**:
1. Check if AD/CP is actually running (look for their indicators)
2. The step may be waiting for a condition (e.g., unloading)
3. Use the HUD Skip button to move to next step
4. Check that the destination/course exists

### AutoDrive step fails

**Symptoms**: AD step errors or doesn't navigate

**Solutions**:
1. Verify the destination exists in AutoDrive
2. Check there's a valid path to the destination
3. Ensure the vehicle is on/near the AD network
4. Test the route manually in AutoDrive first

### Courseplay step fails

**Symptoms**: CP step errors or doesn't start

**Solutions**:
1. Verify the course is loaded on the vehicle
2. Check required implements are attached
3. Ensure the course is for the correct map/field
4. Test the course manually in Courseplay first

### Vehicle drives in circles

**Symptoms**: Vehicle repeating behavior instead of advancing

**Solutions**:
1. The step may have cyclic operations (harvest + unload)
2. Wait for both AD and CP to fully complete
3. Check for stuck AI or pathfinding issues

---

## HUD Issues

### HUD not appearing

**Symptoms**: No workflow HUD when running

**Solutions**:
1. Ensure a workflow is actually running
2. Enter the vehicle that started the workflow
3. Close any open game menus
4. Check if HUD is hidden behind other UI

### HUD buttons not responding

**Symptoms**: Clicking buttons does nothing

**Solutions**:
1. Check button is not disabled (gray color)
2. Ensure mouse cursor is over the button
3. Game window must have focus
4. Try clicking the center of the button

### HUD overlapping other UI

**Symptoms**: HUD covers important game elements

**Solutions**:
1. Known issue with F1 help menu
2. Close the help menu when using workflows
3. HUD position adjustment planned for future

---

## Save/Load Issues

### Workflows missing after reload

**Symptoms**: Saved workflows don't appear

**Solutions**:
1. Ensure you saved the game after creating workflows
2. Check `workflowManager.xml` exists in savegame folder
3. File might be corrupted - check for backup

### XML load errors

**Symptoms**: Error messages about XML on load

**Solutions**:
1. Check `workflowManager.xml` for syntax errors
2. Delete the file to reset (loses all workflows)
3. Restore from backup if available

---

## Performance Issues

### Game stuttering during workflow

**Symptoms**: FPS drops when workflow runs

**Solutions**:
1. Check if AD or CP is causing the issue (test independently)
2. Complex paths or courses may cause load
3. Report issue with log file if persistent

---

## Reporting Bugs

If you encounter issues not covered here:

1. **Collect the game log**: Find `log.txt` in your Farming Simulator 25 root folder (the same folder as the game executable)
2. **Note reproduction steps**: Write down exactly how to trigger the issue
3. **Report on GitHub**: [Issues Page](https://github.com/CSchoch/LS25_WorkflowManager/issues)

Include:
- Mod version
- AutoDrive/Courseplay versions
- Game version
- Steps to reproduce
- Relevant log excerpts
