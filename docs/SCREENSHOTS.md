# Screenshot Guide (Developer Reference)

Screenshots are used by the Docusaurus documentation site. All files go in:

```
website/static/img/screenshots/
```

The site references them as `/img/screenshots/<filename>.png`. If a file is missing, the image tag renders broken — no fallback.

---

## Required Screenshots

### 1. `main-dialog.png`

**Used in:** `ui/main-dialog.md`, `workflows/creating-workflows.md`

**Setup:** Open the Workflow Manager (Alt+W). Have at least one workflow actively running on the current vehicle so its name appears in green and the step counter shows `X/Y` progress. Have 2–3 more workflows in the idle list below it.

**Show:** The full main dialog — workflow list with mixed idle/active states, the New / Edit / Delete / Start / Stop buttons visible at the bottom.

---

### 2. `editor-dialog.png`

**Used in:** `ui/editor-dialog.md`, `workflows/creating-workflows.md`

**Setup:** Open a workflow in the editor that has 4–5 steps including at least one Courseplay step with 2 support sub-steps below it. The sub-steps must be numbered `N.M` (e.g. `2.1`, `2.2`) and the parent step must show `+2` in the Sup column.

**Show:** The full editor dialog — step list with main steps and indented sub-steps visible, Add Step / Add Support Step / Edit / Delete / Move buttons at the bottom.

---

### 3. `editor-support-steps.png`

**Used in:** `workflows/linked-workflows.md`

**Setup:** Same as `editor-dialog.png` — a workflow with a main step that has 2 support sub-steps expanded below it.

**Show:** Focus on the step list area. The `N.M` sub-step numbering and the `+2` Sup badge must both be clearly readable. Can be the same screenshot as `editor-dialog.png` if both requirements are met.

---

### 4. `step-dialog-autodrive.png`

**Used in:** `ui/step-dialog.md`, `ui/editor-dialog.md`, `workflows/step-types.md`

**Setup:** Click Add Step (or edit an existing AutoDrive step). Set Type = AutoDrive, Action = **Pickup and Deliver** — this makes all four fields visible (Target, Action, Unload Target, Fill Type).

**Show:** The full Step Dialog — all four fields populated or at minimum visible (not grayed out/hidden). Both Target and Unload Target dropdowns should have a value selected.

---

### 5. `step-dialog-courseplay.png`

**Used in:** `ui/step-dialog.md`, `ui/editor-dialog.md`, `workflows/step-types.md`

**Setup:** Click Add Step (or edit an existing CP step). Set Type = Courseplay, select a course, set Action = Field Work.

**Show:** The full Step Dialog with Courseplay selected — course dropdown filled, Action dropdown showing "Field Work".

---

### 6. `hud-running.png`

**Used in:** `ui/hud-controls.md`, `getting-started.md`

**Setup:** Be in a vehicle with a workflow actively running (not paused). No support vehicles needed.

**Show:** The HUD overlay — header line `WorkflowManager | <VehicleName>`, workflow name line, step counter (`Step 2/5` style), and all 4 icon buttons (`<<`, pause/resume, stop, `>>`). Make sure the game world is visible behind it (not in a menu).

---

### 7. `hud-support-main.png`

**Used in:** `ui/hud-controls.md`, `workflows/linked-workflows.md`

**Setup:** Two vehicles running the same workflow — one as Main, one as Support. Be in the **main vehicle**. The support vehicle must be actively running its sub-step (status = running, badge should appear green).

**Show:** HUD on the main vehicle — header, workflow name with the colored `[1S]` badge visible next to it, step counter, icon buttons.

---

### 8. `hud-support-vehicle.png`

**Used in:** `ui/hud-controls.md`, `workflows/linked-workflows.md`

**Setup:** Same two-vehicle setup as above. Switch to (or be in) the **support vehicle**.

**Show:** HUD on the support vehicle — step counter must show the sub-step format (`Step 2.1/2`), header with support vehicle name, icon buttons.

---

### 9. `mode-dialog.png`

**Used in:** `ui/mode-dialog.md`, `workflows/linked-workflows.md`, `workflows/executing-workflows.md`

**Setup:** Have a workflow with at least one support sub-step. Click **Start** on that workflow from the main dialog.

**Show:** The role selection dialog — "Run as Main Vehicle" and "Run as Support Vehicle" buttons both visible, workflow name in the title, Cancel button.

---

### 10. `ad-settings-dialog.png`

**Used in:** `ui/ad-settings-dialog.md`

**Setup:** Select a workflow in the main dialog and click **AD/CP Settings**.

**Show:** All three input fields — Unload Fill Level, Pipe Offset, Pre-Call Level. Fill at least two of them with values (e.g. `80` and `2.5`) and leave one **empty**, so the "empty means unchanged" behavior is visible. OK and Cancel buttons in frame.

---

## Missing Screenshots

These pages currently have no image, or describe behavior that text alone conveys poorly.

### 11. `leader-select-dialog.png` — **required**

**Used in:** `ui/leader-select-dialog.md`, `workflows/queue-system.md`

This is the only dialog page with no screenshot at all.

**Setup:** Start a workflow on one vehicle and leave it running. Enter a **second** vehicle, open Workflow Manager, select a workflow, and click **Start**. The leader dialog appears. Ideally have **two or three** other vehicles already running so the list has more than one row.

**Show:** The candidate list with both columns readable — vehicle name and the workflow each one is running — one row highlighted, and all three buttons visible (**Select**, **No Leader**, **Cancel**).

---

### 12. `hud-waiting-leader.png` — **required**

**Used in:** `ui/hud-controls.md`, `ui/leader-select-dialog.md`, `workflows/queue-system.md`

The *Waiting for leader* state is described in three places with no picture, and it's the state users hit when a queue setup misbehaves.

**Setup:** Set up a leader and a follower per the queue system docs. The follower needs a **Wait for Leader** step it is currently parked at, with the leader still working toward its matching **Unlock Follower** step. Be in the follower vehicle.

**Show:** The HUD status line reading **Waiting for leader** followed by the leader vehicle's name. The name is a clickable link — if it renders in a distinct color, make sure that's visible.

---

### 13. `step-dialog-targetless.png` — nice to have

**Used in:** `ui/step-dialog.md`, `workflows/step-types.md`

Shows that the dialog *collapses* for targetless types, which is otherwise hard to picture from prose.

**Setup:** Click **Add Step** and set Type = **Park** (or **Wait for Leader**).

**Show:** The Step Dialog with only the Type dropdown and the OK/Cancel buttons — Action, Target, Unload Target, and Fill Type rows all hidden. Pair it with `step-dialog-autodrive.png` to show the contrast.

---

### 14. `step-dialog-filltypes.png` — nice to have

**Used in:** `ui/step-dialog.md`, `workflows/step-types.md`

Ctrl+Click multi-select is easy to miss and hard to describe.

**Setup:** Add an AutoDrive step, set Action = **Pickup and Deliver**, then Ctrl+Click two or three fill types in the list.

**Show:** The fill type list with multiple entries carrying the green **✓** prefix, and the label below reading `Selected: Wheat, Barley` (two selections) — not the `3 selected` collapsed form, since the named form is more informative.

---

### 15. `web-editor.png` — nice to have

**Used in:** `web-editor.md`

The Web Editor page currently has no image, so there's nothing showing what the tool looks like before someone clicks through.

**Setup:** Open <https://cschoch.github.io/FS25_WorkflowManagerWebeditor/> in a browser. Load or build a workflow with 5–6 steps including a main step with support sub-steps nested under it. Use **dark mode** to match the docs site default.

**Show:** The full editor — workflow list on one side, the step table with nested sub-steps visible, and the Import/Export buttons in frame. Browser chrome can be cropped out.

---

## Checklist

| # | File | Priority | Taken |
|---|------|----------|-------|
| 1 | `main-dialog.png` | required | [x] |
| 2 | `editor-dialog.png` | required | [x] |
| 3 | `editor-support-steps.png` | required | [x] |
| 4 | `step-dialog-autodrive.png` | required | [x] |
| 5 | `step-dialog-courseplay.png` | required | [x] |
| 6 | `hud-running.png` | required | [x] |
| 7 | `hud-support-main.png` | required | [x] |
| 8 | `hud-support-vehicle.png` | required | [x] |
| 9 | `mode-dialog.png` | required | [x] |
| 10 | `ad-settings-dialog.png` | required | [x] |
| 11 | `leader-select-dialog.png` | required | [ ] |
| 12 | `hud-waiting-leader.png` | required | [ ] |
| 13 | `step-dialog-targetless.png` | nice to have | [ ] |
| 14 | `step-dialog-filltypes.png` | nice to have | [ ] |
| 15 | `web-editor.png` | nice to have | [ ] |

Items 1–10 are already present in `website/static/img/screenshots/`.

**Note:** the Console Commands page (`website/docs/api/console-commands.md`) deliberately uses **text code blocks** rather than screenshots — console output is copy-pasteable, searchable, and stays legible at any zoom. Don't screenshot it.

---

## Technical Notes

- **Format:** PNG
- **Resolution:** No strict requirement — use your native game resolution. The site scales images to fit.
- **UI Scale:** Use default FS25 UI scale so dialogs appear at a readable size.
- **Crop:** No need to crop — full-screen is fine. The Docusaurus theme constrains image width automatically.
- **Naming:** Exact filenames matter — the docs reference them literally. No spaces, exact case as listed above.
