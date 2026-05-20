---
id: autodrive
title: AutoDrive Reference
sidebar_position: 1
---

# AutoDrive Reference

This page explains how Workflow Manager uses AutoDrive and what you need to know to set up AutoDrive steps.

## What AutoDrive Does

AutoDrive handles all **navigation and transport** in your workflows. It drives your vehicle between locations using the AutoDrive road network you've set up on the map.

## Setting Up AutoDrive

Before using AutoDrive steps in workflows, you need:

1. **Create an AutoDrive network** on your map (roads connecting your fields, farm, sell points, etc.)
2. **Set up destinations** (markers) at key locations like field entrances, silos, and sell points
3. **Organize destinations in groups** (optional) for easier management

### Destination Groups

AutoDrive lets you organize markers into groups (folders). In Workflow Manager, grouped destinations appear with their group prefix:

- Destinations in the "All" group show as just their name: `Field 1`
- Grouped destinations show as: `Farm/Silo`, `Sell/Mill`, etc.

## AutoDrive Actions

### Drive To

The simplest mode. Drives the vehicle from its current position to the target destination.

**Use for:** Getting to a field, returning to the farm, moving between locations.

**Targets needed:** 1 (destination)

### Pickup and Deliver

Loads cargo at the target location, then delivers it to a second location.

**Use for:** Collecting grain from a silo and delivering to a sell point.

**Targets needed:** 2 (pickup location + delivery location)

**Fill Type:** Optional. Filters what cargo to pick up (e.g., only Wheat).

### Deliver

Delivers the vehicle's current cargo to the target destination.

**Use for:** Taking what's already loaded to a sell point or storage.

**Targets needed:** 1 (delivery destination)

### Load

Loads cargo at the target location, then returns to a second location.

**Use for:** Picking up seeds/fertilizer and returning to a field.

**Targets needed:** 2 (load point + return location)

**Fill Type:** Optional. Filters what cargo to load.

### Unload Combine

Follows a combine and unloads its grain, then delivers to a destination.

**Use for:** Running an unloader/grain cart alongside a harvester.

**Targets needed:** 2 (combine field area + unload/delivery point)

## Fill Type Filtering

For Pickup and Deliver and Load actions, you can select a specific fill type:

- Limits what the vehicle will pick up
- Useful when multiple cargo types are available at one location
- Common fill types: Wheat, Barley, Canola, Corn, Sunflower, Soybeans, etc.

## Tips

- **Test routes first.** Before adding an AutoDrive step to a workflow, test the route manually in AutoDrive to make sure it works.
- **Vehicle must be on the AD network.** The vehicle needs to be near an AutoDrive road to start navigating.
- **Destination names are exact.** The step uses the exact destination name - if you rename a destination in AutoDrive, update your workflow steps too.
- **Make sure paths exist.** AutoDrive needs a valid path between the vehicle's position and the target. If there's no path, the step will fail.
