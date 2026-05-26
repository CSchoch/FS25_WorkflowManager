# FS25 Workflow Manager — Development

## Roadmap

### Completed

**Milestones 1–7:** Core (WorkflowManager, Executor, XML storage), GUI (main dialog, editor, HUD, ESC menu), Vehicle selection, AD/CP integration, Searchable dropdowns

**Recent:** Multi-field workflows, hierarchical support steps, per-vehicle runtime state with savegame persistence, auto-resume after load, draggable HUD, reactive HUD show/hide, HUD badges/tooltips, step editor UX (selected-value rows, auto-select), support vehicle dummy AD hold to prevent staling, `justStoppedAD` fix for idle transitions, per-workflow AD settings (unloadFillLevel, pipeOffset, preCallLevel) accessible from main dialog via "AD/CP Einstellungen" button, fixed pcall arg-order bug in `applyWorkflowSettings`, fixed preCallLevel unit mismatch (now stored as 0.0–1.0 fraction), settings re-applied after `StartDriving`, multiplayer sync (WMCommandEvent/WMStateSyncEvent, server-authoritative executor, mid-session join via onReadStream/onWriteStream), support vehicles no longer paused when main pauses (run independently), fixed duplicate KEY_d binding (WM_GUI_DELETE → KEY_r), removed unused WM_START_WORKFLOW/WM_STOP_WORKFLOW action declarations

**Other:** Courseplay resume at nearest waypoint, release build support (DevConfig stub), DDS textures, old linked-workflow migration, multiple simultaneous support vehicles, sub-step editor numbering (N.M format), mode dialog vehicle reference fix

### Milestone 9: Folder View

- [ ] Show folders in dropdowns (collapsed by default)
- [ ] For AD Targets and CP Courses
- [ ] Collapse all / Expand all buttons

### Milestone 10: Polish

- [ ] Error handling improvements
- [ ] Performance optimization

### Milestone 11: Phase 2 Features

- [x] Queue system for multiple vehicles
- [ ] Advanced conditions
- [ ] Add further CP settings for multiple vehicle courses
- [x] Add Multiple fill type selection for AD

---

## Screenshots Needed

Screenshots for the Docusaurus documentation site (`website/static/img/screenshots/`). Take these in-game and save them at the listed paths:

| File                         | What to show                                                                                                                | Used in                                                                        | Status                             |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ---------------------------------- |
| `main-dialog.png`            | Main dialog (1100px wide) showing button row with **AD/CP Settings** button and 2–3 workflows in the list                   | `ui/main-dialog.md`, `workflows/creating-workflows.md`                         | **Retake needed** (dialog resized) |
| `ad-settings-dialog.png`     | AD/CP Settings dialog open with example values in all three fields (Unload Fill Level, Pipe Offset, Pre-Call Level)         | `ui/main-dialog.md`                                                            | **New — not yet taken**            |
| `editor-dialog.png`          | Editor dialog open for a workflow with 3–5 steps visible, including a mix of AutoDrive and Courseplay rows                  | `ui/editor-dialog.md`                                                          | Exists                             |
| `step-dialog-autodrive.png`  | Step dialog open with **AutoDrive** selected, showing Target, Action, Unload Target, and Fill Type fields — ideally with 2 fill types selected (✓ green) to show multi-select | `ui/editor-dialog.md`, `workflows/step-types.md`                               | **Retake needed** (multi-select UI added) |
| `step-dialog-courseplay.png` | Step dialog open with **Courseplay** selected, showing the course dropdown and Action field                                 | `ui/editor-dialog.md`, `workflows/step-types.md`                               | Exists                             |
| `hud-running.png`            | In-vehicle HUD overlay while a workflow is actively running, showing workflow name, step counter, and the 4 control buttons | `ui/hud-controls.md`, `workflows/executing-workflows.md`, `getting-started.md` | Exists                             |
| `leader-select-dialog.png`   | Leader Vehicle Select dialog open, showing a list with at least one vehicle and its workflow name; **Select**, **No Leader**, and **Cancel** buttons visible | `workflows/queue-system.md`                                                    | **New — not yet taken**            |

---

## Todo
