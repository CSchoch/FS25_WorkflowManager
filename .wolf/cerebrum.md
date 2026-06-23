# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-04-05

## User Preferences

<!-- How the user likes things done. Code style, tools, patterns, communication. -->

## Key Learnings

- **Global wait poller pattern:** `g_currentMission:addUpdateable(obj)` / `removeUpdateable(obj)` is the confirmed FS25 pattern for running logic regardless of vehicle sleep. `obj` must have an `update(dt)` method. WMExecutor uses one shared `globalWaitPoller` for all waiting vehicles (WAITING_FOR_LEADER + WAITING_FOR_MAIN); it self-cleans at the end of each tick via `stopWaitPollerIfIdle()`. The poller also stays alive while any vehicle has `pendingLeaderXmlIndex` or `pendingLeaderWorkflowId` set (checked in `stopWaitPollerIfIdle`).
- **Leader vehicle save/restore identity:** Save leader by XML index from `savegame.key` (`"vehicles.vehicle(N)"` → `wmXmlIndex = N`), stored as `#leaderVehicleXmlIndex`. Do NOT use `g_currentMission.vehicles` array position (unstable — map scripts can prepend vehicles, shifting indices). Do NOT use workflow ID (ambiguous — multiple vehicles can run the same workflow). The XML index parsed from `savegame.key` is FS25's own authoritative vehicle identity.
- **Pending leader resolution gap:** `runWaitPoll` resolves `pendingLeaderXmlIndex`, but the poller only runs while WAITING states are active. Vehicles that restore as PAUSED (standard case) or auto-resume to RUNNING never enter a WAITING state, so `pendingLeaderXmlIndex` would stay unresolved indefinitely. Fix: call `ensureWaitPollerActive()` in `onPostLoad` whenever a pending leader is set; extend `stopWaitPollerIfIdle` to also check `pendingLeaderXmlIndex`/`pendingLeaderWorkflowId`.
- **`onPostLoad` ordering:** FS25 calls `onPostLoad` for each vehicle as it loads — order is not guaranteed. A vehicle that has a leader may load BEFORE the leader, so leader resolution must be deferred. The wait poller retries every 500ms until the leader's `onPostLoad` has run and set `wmXmlIndex`.
- **STATUS_WAITING_FOR_MAIN:** Added 2026-06-17. Support vehicle enters this status when main is on a step with no support sub-steps OR when all sub-steps for the current step are done. Pauseable. Saved to XML as `#status`. Poller detects `waitingForMainStepIndex != main.currentStep` AND `#supportSteps > 0` to trigger resume via `onMainStepChanged`. When support starts a sub-step, `executeCurrentStep` sets `status = RUNNING` explicitly before dispatching to `startAutoDriveStep` / `startCourseplayStep`.
- **Test poll triggering:** In executor tests, replace `WMExecutor.updateTimer=0; WMExecutor:update(500)` poll patterns with `triggerPoll()` (defined in the spec as a local helper). For manual WAITING_FOR_LEADER status sets (without `executeCurrentStep`), also call `WMExecutor:ensureWaitPollerActive()` first. The `WorkflowManagerSpec_spec.lua` WMExecutor stub must include `ensureWaitPollerActive = function() end`.

- **Project:** FS25_WorkflowManager
- **HUD show/hide architecture:** `WMHud:update(dt)` polls every frame to auto-hide after 3s when current vehicle has no active workflow. Re-show on vehicle entry is handled by `WorkflowManagerSpec:onRegisterActionEvents()` (fires when player enters and takes control of a vehicle) — NOT by the update loop, because `g_currentMission.controlledVehicle` may not be populated yet when update() first runs after a vehicle switch.
- **FS25 `wm_hBox` alignment:** `wm_hBox` has `elementSpacing=10px` and `alignmentX=center`. Rows with different child counts center at different X positions. Always use 2 children per row (label + content wrapper) with identical declared widths for consistent alignment. For list+slider rows, put both inside a no-spacing inner BoxLayout as one child.
- **FS25 `MultiTextOption` effective width:** A 500px `MultiTextOption` has ~40px consumed by arrow buttons, leaving ~460px visible text area. Match `TextInput` widths to 460px (with a 40px spacer) to align visually with dropdowns.
- **FS25 slider pattern:** `SmoothList` + `ThreePartBitmap (fs25_listSliderBox)` + `Slider` always in a `flowDirection="horizontal"` BoxLayout; list width = container width − 40px (slider).

## Do-Not-Repeat

[2026-06-17] **SUPERSEDED — dummy hold replaced by global wait poller.** `startDummyHold` and `dummyHelperActive` are GONE. The vehicle-sleep problem is now solved by `WMExecutor.globalWaitPoller` registered with `g_currentMission:addUpdateable()`. This runs at mission level regardless of vehicle sleep state. Poller is created by `ensureWaitPollerActive()` and self-removes via `stopWaitPollerIfIdle()` when no vehicles are waiting. Do NOT reintroduce `stateModule:setActive()` calls for wait states — they cause AD to auto-start on reload.


[2026-05-21] Calling `SmoothList:reloadData()` inside `onSelectionChanged` (or any callback that fires during `mouseEvent` processing) without an `isFiltering` guard causes infinite recursion → `GuiElement.lua:1198: stack overflow`. Always wrap any `reloadData()` call inside a selection callback with `self.isFiltering = true` / `false`.

[2026-05-21] In FS25, `SmoothList.onSelectionChanged` fires during `mouseEvent`. If `reloadData()` is called inside that callback, the engine re-enters `mouseEvent` → `onSelectionChanged` → `reloadData()` → infinite loop. This applies to ALL SmoothList selection callbacks, not just multi-select ones.

[2026-04-10] When deactivating a dummy helper on pause, always call `setActive(false)` AND skip `pauseCurrentStep` entirely (`wasDummy` guard). `pauseCurrentStep` falls back to `currentStepType` from the last real sub-step, which calls `HoldDriving` and blocks player control even after `setActive(false)`.

[2026-04-10] `justStoppedAD` was not cleared in `resetStepTrackingState`. This caused a spurious `pendingADStart` deferral whenever `onMainStepChanged` fired on an idle support vehicle, making the first real sub-step appear to not start. Fix: always clear `justStoppedAD` (and `dummyHelperActive`) in `resetStepTrackingState`.

[2026-04-10] `vehicle.ad.drivePathModule.isPaused` is a **boolean field**, not a method, in the current AD version. Always check `type(...) == "function"` before calling any AD drivePathModule member. Same pattern may apply to other AD module fields.

[2026-04-10] `ADDrivePathModule.PAUSE_TIMEOUT = 3000 ms` — `HoldDriving` only pauses AD for 3 seconds before it auto-resumes. Do NOT use `startRoute + HoldDriving` as a dummy idle helper; the timeout causes the vehicle to start driving. Instead, call `vehicle.ad.stateModule:setActive(true)` directly (via pcall) to keep AD's subsystem alive without a real route. Deactivate with `setActive(false)` when real work starts.

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->

[2026-04-09] HUD re-show on vehicle switch must use `onRegisterActionEvents` in WorkflowManagerSpec, NOT `update()` polling. The `update()` loop's `getActiveWorkflow()` doesn't reliably see the new `controlledVehicle` immediately after a switch. `onRegisterActionEvents` fires exactly when the player enters and takes control of a vehicle.

[2026-04-09] `checkAndHideHUD()` was calling `WMHud:hide()` immediately on workflow stop, overriding the auto-hide timer. The fix: make it a no-op; let `WMHud:update(dt)` manage all show/hide logic reactively.

[2026-04-09] FS25 `setColor()` does not exist on GUI Text elements — use `setTextColor(r, g, b, a)` instead.

[2026-04-07] Support idle poll must check if main step CHANGED, not just if it has sub-steps. The poll for `waitingForMainStep` ran every update cycle and would immediately restart support on the same main step because it didn't track which step triggered the idle. Fix: use `waitingForMainStepIndex` to record which step was active when idle was entered; only resume when `mainActiveData.currentStep ~= waitingForMainStepIndex`.

[2026-05-14] FS25 DDS compression rules: images with alpha → BC3_UNORM (DXT5); fully opaque images → BC1_UNORM (DXT1). Uncompressed RGBA (Pillow default) is rejected as "unknown" compression. BC1/DXT1 on alpha-channel textures corrupts transparency.

[2026-05-14] FS25 `Overlay.new()` and `createImageOverlay()` DO accept DDS for GUI overlays. BC3_UNORM 32×32 icon DDS files work correctly with `Overlay.new`; R8G8B8A8_UNORM DDS works with `createImageOverlay` for the white background texture. Use properly-formed DDS (BC3_UNORM for alpha textures ≥4×4, BC1_UNORM for opaque ≥4×4. Keep all source PNGs at least 4×4 to enable block compression) — eliminates "raw format" and CPU mip-generation warnings. Source PNGs live in `_art/textures/`; generate DDS with `tools/png_to_dds.py`.

[2026-05-26] Never call `self:close()` synchronously inside a dialog's `onOpen()` in FS25. Closing mid-open (before `g_gui` finishes the open transition / input-context push) corrupts the input-context stack → no inputs recognized afterward (HUD/menu can't be closed). If a dialog might have nothing to show, decide BEFORE `g_gui:showDialog`: build the data first and skip showing the dialog when empty (call the callback directly). WMLeaderVehicleSelectDialog now exposes `buildVehicleList()` for this pre-check.

[2026-06-06] In Lua 5.1, `local vehicle = { ... }` does NOT allow closures inside the table literal to capture `vehicle` as an upvalue — it resolves to a global instead. Always declare the local first (`local vehicle`), then assign (`vehicle = { ... }`). This applies to VehicleMock and any other mock that has methods closing over the object being constructed.

[2026-05-21] All WM dialog XML files must use `inputContext="MENU"` (a standard registered FS25 context), NOT custom names like `inputContext="DIALOG_WMEditorDialog"`. Unregistered context names silently fail to activate, leaving the current context as `""`. TextInputElement then pushes TEXT_INPUT with `""` as the saved previous context. On focus-leave (e.g. clicking a SmoothList) it tries to revert to `""` which is undefined → warning + input system corruption → no inputs recognized after dialog closes.

[2026-06-08] `stateModule:setStartHelper(true)` must be called AFTER `AutoDrive:StartDriving` (via `ADIntegration:startRoute`). AD's `StartDriving` resets the `startHelper` flag as part of route initialization. Calling `setStartCPOnCompletion` before `startRoute` means AD silently wipes the flag → CP never auto-starts at target → refill/seed workflows stall. Pattern matches `applyWorkflowSettings`, which already had this "apply after StartDriving" comment.

[2026-06-23] Leader/follower sync is expressed as explicit marker step types — `STEP_WAIT_FOR_LEADER` (follower gate) and `STEP_UNLOCK_FOLLOWER` (leader milestone), paired by ordinal (k-th wait ↔ k-th unlock). They are pass-through steps (no AD/CP job): the wait branch in `executeCurrentStep` calls `WMExecutor:isLeaderSyncSatisfied` then either `onStepCompleted` (proceed) or sets `STATUS_WAITING_FOR_LEADER`; the unlock branch always `onStepCompleted`. `buildSyncMaps` keys off `step.type`, not the old `isSyncTarget/isSyncSource` flags (removed). Sync is opt-in: a workflow with no markers never waits.

[2026-06-23] `WorkflowManager:getStepTypeLabel(type)` / `isMarkerStepType(type)` are the single source for rendering/branching on step type — use them instead of `type == STEP_AUTODRIVE and "AutoDrive" or "Courseplay"` ternaries (which mislabel the two marker types). Touch-points: WorkflowEditorGUI, WMEditorDialog, WMHud, WMConsoleCommands.

[2026-06-23] Unit-test specs stub `_G.WorkflowManager` themselves (NOT the real module): `WorkflowExecutor_spec.lua` (STATUS_*/STEP_* constants + `broadcastState`) and `WorkflowStorage_spec.lua` (minimal stub + STEP_* constants). Adding a new `WorkflowManager.STEP_*` constant or a called method MUST be mirrored in these stubs or tests fail with "unknown step type"/nil-index. WorkflowStorage avoids method coupling via a file-local `isMarkerStepType` that only reads the constants.

[2026-06-23] Storage needs `WorkflowManager#formatVersion` (absent=1, current=2) to migrate. The old save only wrote `isSyncTarget/isSyncSource` when `false`, so an all-default v1 workflow is byte-identical to a new no-marker v2 workflow — version is the only reliable "needs migration" signal. `migrateSyncFlagsToMarkers` inserts a wait marker before each former sync-source step and an unlock marker before each former sync-target step (default true). Migration tests for OTHER concerns (legacy `#fillType`, linked-workflow) must write `formatVersion=2` in their XML to isolate.

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->

[2026-04-09] Support step visibility: when a support sub-step starts automatically (triggered by main advancing), the player in another vehicle has no HUD feedback. This is known and intentional — no cross-vehicle notification was added (user explicitly declined).
