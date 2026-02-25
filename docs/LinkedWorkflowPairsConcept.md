# Linked Workflow Pairs with Step Synchronization

## Summary

Add ability to link two workflows together for coordinated multi-vehicle operations (e.g., Combine + Unloader for harvesting). Linked workflows use **sync groups** to coordinate step progression across workflows with asymmetric step counts.

## Problem

A combine harvesting multiple fields needs 2 steps per field (AD drive + CP fieldwork), but the support unloader needs only 1 step per field (AD unload). A simple 1:1 step mapping doesn't work because the step counts differ. Sync groups solve this by grouping related steps together.

## Design Decisions

- **Link storage**: `linkedWorkflowId` and `linkRole` fields on workflow
- **Bidirectional**: When A links to B, both store each other's ID
- **Roles**: One workflow is "main" (drives sync), the other is "support" (follows)
- **Sync groups**: Integer on each step; steps with the same group number across workflows are coordinated
- **No vehicle storage**: Vehicles still detected at runtime
- **User-driven start**: Prompt user to start linked workflow, don't auto-start

---

## Sync Groups

### Concept

Each step has a `syncGroup` integer. Steps with the same `syncGroup` across linked workflows are coordinated — the support workflow stays on its current group until the main workflow transitions to the next group.

**Example: Harvesting Fields 1 & 2**

| Main (Combine)         | syncGroup | Support (Unloader)        | syncGroup |
|------------------------|-----------|---------------------------|-----------|
| AD drive to Field 1    | 1         | AD unload at Field 1      | 1         |
| CP harvest Field 1     | 1         |                           |           |
| AD drive to Field 2    | 2         | AD unload at Field 2      | 2         |
| CP harvest Field 2     | 2         |                           |           |

The main workflow has 4 steps, the support has 2. Sync groups map them correctly:
- While main is in group 1 (steps 1-2), support runs its group 1 step (AD unload Field 1)
- When main transitions to group 2 (step 3), support advances to its group 2 step (AD unload Field 2)

### Auto-Assignment Logic

When the user clicks "Auto Groups" in the editor, sync groups are assigned automatically:

**Main workflow**: Group number increments after each CP step.
```
Step 1: AD drive to Field 1   → syncGroup = 1
Step 2: CP harvest Field 1    → syncGroup = 1  (CP step → increment after this)
Step 3: AD drive to Field 2   → syncGroup = 2
Step 4: CP harvest Field 2    → syncGroup = 2  (CP step → increment after this)
```

**Support workflow**: Each step gets sequential group numbers.
```
Step 1: AD unload Field 1     → syncGroup = 1
Step 2: AD unload Field 2     → syncGroup = 2
```

Users can also set sync groups manually via the step dialog.

### Support Auto-Restart (Looping)

When the support workflow finishes its current step but the main is still in the same sync group, the support **restarts its current step automatically**. This is natural behavior — an unloader loops between the field and the silo until the combine finishes.

The loop stops when:
- Main transitions to the next sync group (support advances)
- Main completes entirely (support stops)
- User manually pauses/stops

---

## Data Structure Changes

### Workflow

```lua
local workflow = {
    id = self:generateWorkflowId(),
    name = name or "New Workflow",
    steps = {},
    currentStep = 1,
    status = self.STATUS_READY,
    createdAt = getDate("%Y-%m-%d %H:%M:%S"),
    linkedWorkflowId = nil,    -- ID of linked partner workflow
    linkRole = nil             -- "main" or "support"
}
```

### Step

```lua
local step = {
    type = "autodrive",        -- "autodrive" or "courseplay"
    target = "Route_Field1",
    action = "drive",
    unloadTarget = nil,
    fillType = nil,
    syncGroup = nil            -- Integer for sync coordination (nil if not linked)
}
```

### Helper Methods

```lua
function WorkflowManager:linkWorkflows(mainWorkflowId, supportWorkflowId)
function WorkflowManager:unlinkWorkflow(workflowId)
function WorkflowManager:getLinkedWorkflow(workflowId)
function WorkflowManager:autoAssignSyncGroups(workflowId)
```

---

## Executor Logic

### 1. Sync Group Transition Detection

In `onStepCompleted()`, after advancing to the next step on the main workflow, check if the sync group changed:

```lua
local prevGroup = workflow.steps[prevStep].syncGroup
local nextGroup = workflow.steps[workflow.currentStep].syncGroup
if prevGroup ~= nextGroup then
    self:onSyncGroupTransition(workflow, prevGroup, nextGroup)
end
```

### 2. Sync Group Transition Handler

When the main workflow changes sync group:

```lua
function WorkflowExecutor:onSyncGroupTransition(mainWorkflow, fromGroup, toGroup)
    local supportWorkflow = WorkflowManager:getLinkedWorkflow(mainWorkflow.id)
    if not supportWorkflow or supportWorkflow.status ~= "running" then return end

    -- Stop support's current step
    self:stopCurrentStep(supportWorkflow)

    -- Find the support step matching the new group
    local targetStep = self:findStepByGroup(supportWorkflow, toGroup)
    if targetStep then
        supportWorkflow.currentStep = targetStep
        self:startStep(supportWorkflow)
    end
end
```

### 3. Support Step Looping

When a support workflow step completes, check if main is still in the same group:

```lua
function WorkflowExecutor:onSupportStepCompleted(supportWorkflow)
    local mainWorkflow = WorkflowManager:getLinkedWorkflow(supportWorkflow.id)
    if not mainWorkflow or mainWorkflow.status ~= "running" then
        self:stopWorkflow(supportWorkflow)
        return
    end

    local mainGroup = mainWorkflow.steps[mainWorkflow.currentStep].syncGroup
    local supportGroup = supportWorkflow.steps[supportWorkflow.currentStep].syncGroup

    if mainGroup == supportGroup then
        -- Main still in same group → restart support step
        self:startStep(supportWorkflow)
    else
        -- Main moved on → advance support to match
        local targetStep = self:findStepByGroup(supportWorkflow, mainGroup)
        if targetStep then
            supportWorkflow.currentStep = targetStep
            self:startStep(supportWorkflow)
        end
    end
end
```

### 4. Pause/Resume/Stop Propagation

Actions on the main workflow propagate to the support:

| Main Action | Support Effect |
|-------------|----------------|
| Pause       | Pause support  |
| Resume      | Resume support |
| Stop        | Stop support   |
| Complete    | Stop support   |

Support actions do **not** propagate to main (support is subordinate).

### 5. Late Start Sync

If the support workflow starts after the main is already running, it syncs to the main's current group:

```lua
function WorkflowExecutor:onSupportStarted(supportWorkflow)
    local mainWorkflow = WorkflowManager:getLinkedWorkflow(supportWorkflow.id)
    if mainWorkflow and mainWorkflow.status == "running" then
        local mainGroup = mainWorkflow.steps[mainWorkflow.currentStep].syncGroup
        local targetStep = self:findStepByGroup(supportWorkflow, mainGroup)
        if targetStep then
            supportWorkflow.currentStep = targetStep
        end
    end
    self:startStep(supportWorkflow)
end
```

### 6. Manual Step Switching

When the user manually switches steps (prev/next) on the main workflow:
- If the sync group changes, trigger `onSyncGroupTransition()` to advance support
- If the sync group stays the same, no sync action needed

When the user manually switches steps on the support workflow:
- Allow free movement (no restriction)
- Set a `syncOverridden` flag on the support workflow
- Clear the flag when main transitions to a new group (re-syncs automatically)

---

## XML Format

```xml
<WorkflowManager>
    <workflows>
        <workflow id="wf_001" name="Combine Harvest"
                  linkedWorkflowId="wf_002" linkRole="main"
                  currentStep="1" status="ready">
            <step type="autodrive" target="Route_Field1" action="drive" syncGroup="1"/>
            <step type="courseplay" target="Field1_Harvest" action="fieldwork" syncGroup="1"/>
            <step type="autodrive" target="Route_Field2" action="drive" syncGroup="2"/>
            <step type="courseplay" target="Field2_Harvest" action="fieldwork" syncGroup="2"/>
        </workflow>
        <workflow id="wf_002" name="Unloader Support"
                  linkedWorkflowId="wf_001" linkRole="support"
                  currentStep="1" status="ready">
            <step type="autodrive" target="Field1" action="unload"
                  unloadTarget="Silo" syncGroup="1"/>
            <step type="autodrive" target="Field2" action="unload"
                  unloadTarget="Silo" syncGroup="2"/>
        </workflow>
    </workflows>
</WorkflowManager>
```

---

## GUI Changes

### Main Dialog (`WMMainDialog.lua`)

- **Link button**: Shows list of other workflows to link to
- **Role selection**: When linking, user picks which is "main" and which is "support"
- **Linked indicator**: Show link icon or "(Linked)" next to linked workflows in list
- **Start prompt**: When starting a main workflow, prompt: "Start linked workflow 'X' as well?"
- **Unlink button**: Remove link from both workflows

### Editor Dialog (`WMEditorDialog.lua`)

- **Sync group column**: Show syncGroup number for each step (visible only when workflow is linked)
- **Auto Groups button**: Auto-assign sync groups based on step types

### Step Dialog (`WMStepDialog.lua`)

- **Sync group input**: Number input field for syncGroup (visible only when workflow is linked)

### HUD (`WMHud.lua`)

- **Linked status line**: Show linked workflow name and status
  - Running: green text
  - Idle/Paused: orange text
  - Not started: gray text

---

## User Flow

1. Create "Combine Harvest" workflow:
   - AD drive to Field 1
   - CP harvest Field 1
   - AD drive to Field 2
   - CP harvest Field 2
2. Create "Unloader Support" workflow:
   - AD unload at Field 1 → Silo
   - AD unload at Field 2 → Silo
3. Select "Combine Harvest", click **Link**, select "Unloader Support"
4. Assign roles: Combine = main, Unloader = support
5. Click **Auto Groups** on each workflow (or groups are auto-assigned on link)
6. Enter combine, start "Combine Harvest"
7. Dialog: "Start linked workflow 'Unloader Support'?" → Yes
8. Switch to unloader vehicle, start "Unloader Support"
9. Both run coordinated:
   - Combine drives to Field 1, starts harvesting
   - Unloader loops AD unload at Field 1 until combine finishes
   - Combine transitions to Field 2, unloader auto-advances to Field 2 unload
10. When combine completes, unloader stops automatically

---

## Edge Cases

| Case | Handling |
|------|----------|
| Support finishes step, main still in same group | Restart support step (loop) |
| Main completes all steps | Stop support workflow |
| Support has no step for main's current group | Stop support, log warning |
| Main paused | Pause support |
| Main resumed | Resume support |
| Manual prev/next on support | Allow, set `syncOverridden` flag; re-sync on next main group change |
| Manual prev/next on main changes group | Trigger sync group transition on support |
| Delete linked workflow | Auto-unlink the partner, show warning |
| Replace existing link | Prompt: "Replace link to X with Y?" |
| Start both on same vehicle | Warn: "Vehicle already running workflow X" |
| Invalid link on load | Clear the invalid linkedWorkflowId |
| Mismatched group counts | Warn on link creation; support stops when no matching group found |
| Late start (support starts after main) | Sync support to main's current group before starting |

---

## Files to Modify

| File | Changes |
|------|---------|
| `src/WorkflowManager.lua` | Add `linkedWorkflowId`, `linkRole` fields; link/unlink methods; `autoAssignSyncGroups()` |
| `src/WorkflowStorage.lua` | Save/load `linkedWorkflowId`, `linkRole`, `syncGroup` |
| `src/WorkflowExecutor.lua` | Sync group transitions, support looping, pause/resume/stop propagation, late start sync |
| `src/gui/WMMainDialog.lua` | Link/Unlink button, role selection, linked indicator, start prompt |
| `src/gui/WMEditorDialog.lua` | Sync group column, Auto Groups button |
| `src/gui/WMStepDialog.lua` | Sync group input field |
| `xml/gui/WMMainDialog.xml` | Link/Unlink button elements |
| `xml/gui/WMEditorDialog.xml` | Sync group column header |
| `xml/gui/WMStepDialog.xml` | Sync group input section |
| `src/gui/WMHud.lua` | Linked workflow status line |
| `translations/translation_en.xml` | English strings for link UI and sync groups |
| `translations/translation_de.xml` | German translations |

---

## Translations

### English (`translation_en.xml`)

```xml
<text name="wm_button_link" text="Link"/>
<text name="wm_button_unlink" text="Unlink"/>
<text name="wm_linked_to" text="Linked to: %s"/>
<text name="wm_linked_start_prompt" text="Start linked workflow '%s' as well?"/>
<text name="wm_link_role_main" text="Main"/>
<text name="wm_link_role_support" text="Support"/>
<text name="wm_sync_group" text="Sync Group"/>
<text name="wm_auto_groups" text="Auto Groups"/>
<text name="wm_link_role_select" text="Select role for '%s':"/>
<text name="wm_link_group_mismatch" text="Warning: Sync group counts differ between workflows"/>
```

---

## Verification

1. Create two workflows with asymmetric step counts (4 main, 2 support)
2. Link them together, assign roles
3. Auto-assign sync groups → verify correct grouping
4. Save game, reload → verify link, roles, and sync groups persist
5. Start main workflow, verify prompt to start support
6. Start support on different vehicle
7. Verify support loops while main is in same group
8. Verify support advances when main changes group
9. Pause main → verify support pauses
10. Resume main → verify support resumes
11. Stop main → verify support stops
12. Start main mid-workflow, then start support late → verify late sync
13. Manual prev/next on support → verify free movement and re-sync
14. Delete one workflow → verify partner is unlinked
