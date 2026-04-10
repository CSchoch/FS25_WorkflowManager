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

**Used in:** `ui/editor-dialog.md`, `workflows/step-types.md`

**Setup:** Click Add Step (or edit an existing AutoDrive step). Set Type = AutoDrive, Action = **Pickup and Deliver** — this makes all four fields visible (Target, Action, Unload Target, Fill Type).

**Show:** The full Step Dialog — all four fields populated or at minimum visible (not grayed out/hidden). Both Target and Unload Target dropdowns should have a value selected.

---

### 5. `step-dialog-courseplay.png`

**Used in:** `ui/editor-dialog.md`, `workflows/step-types.md`

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

**Used in:** `workflows/linked-workflows.md`

**Setup:** Have a workflow with at least one support sub-step. Click **Start** on that workflow from the main dialog.

**Show:** The role selection dialog — "Run as Main Vehicle" and "Run as Support Vehicle" buttons both visible, workflow name in the title, Cancel button.

---

## Checklist

| # | File | Taken |
|---|------|-------|
| 1 | `main-dialog.png` | [ ] |
| 2 | `editor-dialog.png` | [ ] |
| 3 | `editor-support-steps.png` | [ ] |
| 4 | `step-dialog-autodrive.png` | [ ] |
| 5 | `step-dialog-courseplay.png` | [ ] |
| 6 | `hud-running.png` | [ ] |
| 7 | `hud-support-main.png` | [ ] |
| 8 | `hud-support-vehicle.png` | [ ] |
| 9 | `mode-dialog.png` | [ ] |

---

## Technical Notes

- **Format:** PNG
- **Resolution:** No strict requirement — use your native game resolution. The site scales images to fit.
- **UI Scale:** Use default FS25 UI scale so dialogs appear at a readable size.
- **Crop:** No need to crop — full-screen is fine. The Docusaurus theme constrains image width automatically.
- **Naming:** Exact filenames matter — the docs reference them literally. No spaces, exact case as listed above.
