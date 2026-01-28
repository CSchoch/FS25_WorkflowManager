# Linked Workflow Pairs - Implementation Plan

## Summary

Add ability to link two workflows together for coordinated multi-vehicle operations (e.g., Combine + Unloader for harvesting). Workflows remain independent in storage but can be started as a coordinated pair.

## Design Decisions

- **Link storage**: Simple `linkedWorkflowId` field on workflow
- **Bidirectional**: When A links to B, both store each other's ID
- **No vehicle storage**: Vehicles still detected at runtime
- **User-driven coordination**: Prompt user to start linked workflow, don't auto-start

---

## Implementation Steps

### 1. Data Structure (`WorkflowManager.lua`)

Add `linkedWorkflowId` to workflow creation (around line 638):
```lua
local workflow = {
    id = self:generateWorkflowId(),
    name = name or "New Workflow",
    steps = {},
    currentStep = 1,
    status = self.STATUS_READY,
    createdAt = getDate("%Y-%m-%d %H:%M:%S"),
    linkedWorkflowId = nil  -- NEW
}
```

Add helper methods:
```lua
function WorkflowManager:linkWorkflows(workflowId1, workflowId2)
function WorkflowManager:unlinkWorkflow(workflowId)
function WorkflowManager:getLinkedWorkflow(workflowId)
```

### 2. Storage (`WorkflowStorage.lua`)

**Save** (around line 53):
```lua
if workflow.linkedWorkflowId then
    xmlFile:setString(workflowKey .. "#linkedWorkflowId", workflow.linkedWorkflowId)
end
```

**Load** (around line 118):
```lua
linkedWorkflowId = xmlFile:getString(workflowKey .. "#linkedWorkflowId")
```

### 3. Main Dialog UI (`WMMainDialog.lua`)

Add "Link" button:
- Shows list of other workflows to link to
- Creates bidirectional link

Modify `onClickStart()`:
- Check if workflow has linked workflow
- Show prompt: "Start linked workflow 'X' as well?"
- On Yes: remind user to switch vehicle and start it

### 4. Main Dialog XML (`xml/gui/WMMainDialog.xml`)

Add Link button in button row:
```xml
<Button profile="buttonActivate" id="linkButton" text="$l10n_wm_button_link"
        onClick="onClickLink"/>
```

### 5. HUD Enhancement (`WMHud.lua`)

Show linked workflow status:
- "Linked: Unloader Support (Running)" in green
- "Linked: Unloader Support (Idle)" in orange

### 6. Translations (`translations/translation_en.xml`)

```xml
<text name="wm_button_link" text="Link"/>
<text name="wm_button_unlink" text="Unlink"/>
<text name="wm_linked_to" text="Linked to: %s"/>
<text name="wm_linked_start_prompt" text="Start linked workflow '%s' as well?"/>
```

---

## XML Format Change

```xml
<workflow id="workflow_001" name="Combine Harvest"
          linkedWorkflowId="workflow_002">
    <step type="autodrive" target="Field1" action="drive"/>
    <step type="courseplay" target="Field1_Harvest" action="fieldwork"/>
</workflow>
<workflow id="workflow_002" name="Unloader Support"
          linkedWorkflowId="workflow_001">
    <step type="autodrive" target="Field1" action="unload" unloadTarget="Silo"/>
</workflow>
```

---

## User Flow

1. Create "Combine Harvest" workflow with AD→CP steps
2. Create "Unloader Support" workflow with AD unload step
3. Select one, click "Link", select the other
4. Enter combine, start "Combine Harvest"
5. Dialog: "Start linked workflow 'Unloader Support'?" → Yes
6. Switch to unloader vehicle
7. Start "Unloader Support"
8. Both run in parallel, HUD shows linked status

---

## Edge Cases

| Case | Handling |
|------|----------|
| Delete linked workflow | Auto-unlink the partner, show warning |
| Replace existing link | Prompt: "Replace link to X with Y?" |
| Start on same vehicle | Warn: "Vehicle already running workflow X" |
| Invalid link on load | Clear the invalid linkedWorkflowId |

---

## Files to Modify

| File | Changes |
|------|---------|
| `src/WorkflowManager.lua` | Add linkedWorkflowId field, link/unlink methods |
| `src/WorkflowStorage.lua` | Save/load linkedWorkflowId attribute |
| `src/gui/WMMainDialog.lua` | Add Link button, modify start logic |
| `src/gui/WMHud.lua` | Display linked workflow status |
| `xml/gui/WMMainDialog.xml` | Add Link button element |
| `translations/translation_en.xml` | Add link-related strings |
| `translations/translation_de.xml` | German translations |

---

## Verification

1. Create two workflows
2. Link them together via UI
3. Save game, reload → verify link persists
4. Start one workflow, verify prompt appears
5. Start linked workflow on different vehicle
6. Verify HUD shows both statuses
7. Delete one workflow → verify partner is unlinked
