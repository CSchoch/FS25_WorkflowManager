# FS25 Workflow Manager — Development

## Roadmap

### Completed

**Milestones 1–7:** Core (WorkflowManager, Executor, XML storage), GUI (main dialog, editor, HUD, ESC menu), Vehicle selection, AD/CP integration, Searchable dropdowns

**Recent:** Multi-field workflows, hierarchical support steps, per-vehicle runtime state with savegame persistence, auto-resume after load, draggable HUD, reactive HUD show/hide, HUD badges/tooltips, step editor UX (selected-value rows, auto-select), support vehicle dummy AD hold to prevent staling, `justStoppedAD` fix for idle transitions, per-workflow AD settings (unloadFillLevel, pipeOffset, preCallLevel) accessible from main dialog via "AD/CP Einstellungen" button, fixed pcall arg-order bug in `applyWorkflowSettings`, fixed preCallLevel unit mismatch (now stored as 0.0–1.0 fraction), settings re-applied after `StartDriving`, multiplayer sync (WMCommandEvent/WMStateSyncEvent, server-authoritative executor, mid-session join via onReadStream/onWriteStream), support vehicles no longer paused when main pauses (run independently), fixed duplicate KEY_d binding (WM_GUI_DELETE → KEY_r), removed unused WM_START_WORKFLOW/WM_STOP_WORKFLOW action declarations

**Other:** Courseplay resume at nearest waypoint, release build support (DevConfig stub), DDS textures, old linked-workflow migration, multiple simultaneous support vehicles, sub-step editor numbering (N.M format), mode dialog vehicle reference fix

**Latest batch (2026-07):** Park/Refuel/Repair step types (AutoDrive-driven, no configurable target); leader-follower sync reworked from per-step Sync Target/Sync Source Yes/No flags to explicit `Wait for Leader`/`Unlock Follower` marker steps (opt-in, ordinally paired) — old flags migrated automatically; leader identity now keyed on `vehicle.uniqueId` instead of a positional XML index (fixes leader references breaking across save sessions); `STATUS_WAITING_FOR_MAIN` for support vehicles idling between main steps; HUD redesign (header shows only the title, step line gets an `[AD]`/`[CP]`/`[PARK]`/`[REFUEL]`/`[REPAIR]`/`[WM]` type tag, Waiting-for-Leader/Waiting-for-Main lines show the other vehicle's name and are clickable to jump into it); fixed Refuel never actually refueling and Repair silently resuming AD to a stale destination after completing (both traced to AutoDrive's own `RepairTask`/`RefuelTask:finished()` restarting the vehicle's AD mode); removed the entire AD completion-callback/listener pipeline after confirming it's dead code in the installed AutoDrive version (completion has always been detected by polling); Docusaurus docs swept to match all of the above.

### Milestone 9: Folder View

- [ ] Show folders in dropdowns (collapsed by default)
- [ ] For AD Targets and CP Courses
- [ ] Collapse all / Expand all buttons

### Milestone 10: Polish

- [ ] Error handling improvements
- [ ] Performance optimization

### Milestone 11: Phase 2 Features

- [x] Queue system for multiple vehicles
- [x] Park/Refuel/Repair step types
- [ ] Advanced conditions
- [ ] Add further CP settings for multiple vehicle courses
- [x] Add Multiple fill type selection for AD

---

## Screenshots Needed

Screenshots for the Docusaurus documentation site (`website/static/img/screenshots/`). Take these in-game and save them at the listed paths. Status below was verified by actually opening each existing file, not just checking it exists — several were stale after the 2026-07 HUD redesign.

### Retakes needed (file exists but shows outdated UI)

| File | What's wrong | What to show instead |
| --- | --- | --- |
| `hud-running.png` | Header still reads "Workflow Manager \| VehicleName" and the step line has no type tag — both from before the HUD redesign | Header showing just **WorkflowManager**; step line with its type tag, e.g. `[CP] Step 6/10: F91/Duengen` |
| `hud-support-main.png` | Same stale header/step-line format as above | Same fix, on the main vehicle's HUD with the `[NS]` support badge visible |
| `hud-support-vehicle.png` | Same stale header/step-line format as above | Same fix, on a support vehicle's HUD showing a sub-step counter (e.g. `Step 2.1/2`) |
| `step-dialog-autodrive.png` | Fill type list shows a single highlighted row, no green checkmarks — doesn't match the documented multi-select UI | Same dialog with 2 fill types selected via Ctrl+Click, showing the checkmark prefix and the "Selected: X, Y" label |
| `main-dialog.png` | Button row has no **AD/CP Settings** button — dialog was resized/rearranged since this was taken | Same shot, current button row, 2-3 workflows in the list |

### New screenshots wanted (no image yet - sections are currently text-only)

| File | What to show |
| --- | --- |
| `step-dialog-type-list.png` | Step Dialog's Type dropdown open, showing all 7 options (AutoDrive, Courseplay, Wait for Leader, Unlock Follower, Park, Refuel, Repair) |
| `hud-waiting-for-leader.png` | HUD showing the "Waiting for leader: VehicleName" status line |
| `hud-waiting-for-main.png` | Support vehicle HUD showing the "Waiting for main vehicle: VehicleName" status line |
| `leader-select-dialog.png` | Leader Vehicle Select dialog open, showing a list with at least one vehicle and its workflow name; Select, No Leader, and Cancel buttons visible (carried over from before - still not captured) |

### Confirmed still accurate - no action needed

`editor-dialog.png`, `editor-support-steps.png`, `step-dialog-courseplay.png`, `mode-dialog.png`, `ad-settings-dialog.png` (fine as-is, though only 1 of its 3 fields has an example value - nice-to-have retake, not urgent).

---

## Todo
