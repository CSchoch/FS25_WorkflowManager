# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-04-05

## User Preferences

<!-- How the user likes things done. Code style, tools, patterns, communication. -->

## Key Learnings

- **Project:** FS25_WorkflowManager
- **HUD show/hide architecture:** `WMHud:update(dt)` polls every frame to auto-hide after 3s when current vehicle has no active workflow. Re-show on vehicle entry is handled by `WorkflowManagerSpec:onRegisterActionEvents()` (fires when player enters and takes control of a vehicle) — NOT by the update loop, because `g_currentMission.controlledVehicle` may not be populated yet when update() first runs after a vehicle switch.
- **FS25 `wm_hBox` alignment:** `wm_hBox` has `elementSpacing=10px` and `alignmentX=center`. Rows with different child counts center at different X positions. Always use 2 children per row (label + content wrapper) with identical declared widths for consistent alignment. For list+slider rows, put both inside a no-spacing inner BoxLayout as one child.
- **FS25 `MultiTextOption` effective width:** A 500px `MultiTextOption` has ~40px consumed by arrow buttons, leaving ~460px visible text area. Match `TextInput` widths to 460px (with a 40px spacer) to align visually with dropdowns.
- **FS25 slider pattern:** `SmoothList` + `ThreePartBitmap (fs25_listSliderBox)` + `Slider` always in a `flowDirection="horizontal"` BoxLayout; list width = container width − 40px (slider).

## Do-Not-Repeat

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->

[2026-04-09] HUD re-show on vehicle switch must use `onRegisterActionEvents` in WorkflowManagerSpec, NOT `update()` polling. The `update()` loop's `getActiveWorkflow()` doesn't reliably see the new `controlledVehicle` immediately after a switch. `onRegisterActionEvents` fires exactly when the player enters and takes control of a vehicle.

[2026-04-09] `checkAndHideHUD()` was calling `WMHud:hide()` immediately on workflow stop, overriding the auto-hide timer. The fix: make it a no-op; let `WMHud:update(dt)` manage all show/hide logic reactively.

[2026-04-09] FS25 `setColor()` does not exist on GUI Text elements — use `setTextColor(r, g, b, a)` instead.

[2026-04-07] Support idle poll must check if main step CHANGED, not just if it has sub-steps. The poll for `waitingForMainStep` ran every update cycle and would immediately restart support on the same main step because it didn't track which step triggered the idle. Fix: use `waitingForMainStepIndex` to record which step was active when idle was entered; only resume when `mainActiveData.currentStep ~= waitingForMainStepIndex`.

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->

[2026-04-09] Support step visibility: when a support sub-step starts automatically (triggered by main advancing), the player in another vehicle has no HUD feedback. This is known and intentional — no cross-vehicle notification was added (user explicitly declined).
