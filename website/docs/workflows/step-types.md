---
id: step-types
title: Step Types
sidebar_position: 2
---

# Step Types

Workflow Manager supports two types of steps: **AutoDrive** for navigation and **Courseplay** for field work.

## AutoDrive Steps

AutoDrive handles all navigation and transport operations.

### Actions/Modes

| Action | Mode | Targets | Description |
|--------|------|---------|-------------|
| `drive` | MODE_DRIVETO | 1 | Simple point-to-point navigation |
| `unload` | MODE_UNLOAD | 2 | Unload combine (follows combine, delivers grain) |
| `pickup_deliver` | MODE_PICKUPANDDELIVER | 2 | Load at target, deliver to unload target |
| `deliver` | MODE_DELIVERTO | 1 | Deliver current load to target |
| `load` | MODE_LOAD | 2 | Load at target, return to unload target |

### Target Selection

- **Target**: Primary destination (where to go first)
- **Unload Target**: Secondary destination (for multi-destination modes)
- Destinations come from your AutoDrive network markers

### Fill Type Filtering

For cargo operations (`pickup_deliver`, `load`), you can specify a fill type:
- Limits what the vehicle will pick up
- Useful when multiple fill types are available at a location

### Examples

**Simple Navigation**
```
Type: AutoDrive
Target: Field1_Entrance
Action: drive
```

**Grain Delivery**
```
Type: AutoDrive
Target: Farm/Silo
Action: pickup_deliver
Unload Target: Sell/Mill
Fill Type: WHEAT
```

**Combine Unloader**
```
Type: AutoDrive
Target: Field1_Harvest
Action: unload
Unload Target: Farm/Silo
```

## Courseplay Steps

Courseplay handles all field work operations.

### Actions

| Action | Description |
|--------|-------------|
| `fieldwork` | Standard field operations (harvest, cultivate, seed, spray, etc.) |
| `bale_collect` | Collect, load, and wrap bales |

### Course Selection

- Courses must be saved in Courseplay before they appear in the dropdown
- Courses are stored in: `modSettings/FS25_Courseplay/Courses/[MapId]/`
- The dropdown shows all available courses for the current map

### Course Requirements

Before starting a workflow, ensure:
1. The vehicle has the course loaded
2. The vehicle is configured correctly for the course (implements attached)
3. The course was created for the correct field

### Examples

**Wheat Harvest**
```
Type: Courseplay
Target: Field1_Wheat_Harvest
Action: fieldwork
```

**Bale Collection**
```
Type: Courseplay
Target: Meadow_Baling_Route
Action: bale_collect
```

## Step Transitions

### AutoDrive to Courseplay

When an AutoDrive step finishes and the next step is Courseplay:
1. The Courseplay course is pre-loaded onto the vehicle
2. AutoDrive hands off to Courseplay automatically
3. Courseplay starts field work without any manual input

### Courseplay to AutoDrive

When a Courseplay step finishes and the next step is AutoDrive:
1. Workflow Manager detects that Courseplay has stopped
2. The next AutoDrive route starts automatically

### Internal Handoffs

During Courseplay field work, AutoDrive may be triggered internally (e.g., a harvester calling an unloader via AutoDrive). The mod handles this automatically - it waits for both AutoDrive and Courseplay to finish before moving to the next step.

## Step Order Considerations

### Start Position
- The first step should account for where the vehicle currently is
- Use an AutoDrive `drive` step to position the vehicle if needed

### End Position
- Consider where the vehicle will be after the last step
- You may want to add a final AutoDrive step to return home

### Course Prerequisites
- Ensure implements are attached before starting
- For multi-tool workflows, consider implement changes between steps

## Troubleshooting Steps

### AutoDrive Step Won't Start
- Check that the destination exists in AutoDrive
- Verify the vehicle has the AutoDrive spec
- Ensure no other AD/CP job is running

### Courseplay Step Won't Start
- Verify the course exists and is for the correct map
- Check that required implements are attached
- Ensure the vehicle supports the course type

See [Troubleshooting](../troubleshooting) for more solutions.
