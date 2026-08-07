# Multiplayer Concept

Status: **design** — not yet implemented.
Investigated against `FS25_AutoDrive` and `FS25_Courseplay` sources, and verified against
GIANTS' own game source (`sdk/debugger/gameSource.zip`) — see §9.

## 1. What exists today

WM already has a coherent server-authoritative *execution* model:

| Piece | Where | Status |
| --- | --- | --- |
| Execution runs on the server only | `WMExecutor:update` — `if g_server == nil then return end` | works |
| Client → server commands | `WMCommandEvent` (start/stop/pause/resume/next/prev) | works |
| Server → clients state push | `WMStateSyncEvent` (step + status per vehicle) | works |
| Mid-session join, per-vehicle | `WorkflowManagerSpec:onWriteStream` / `onReadStream` | works |

The gap is one layer below all of it.

## 2. The core defect

Both network events identify a workflow by **id only**, and expect the receiver to
resolve it:

```lua
-- WMNetworkEvents.lua
-- Find the workflow definition (loaded from XML, same on all peers)
local workflow = WorkflowManager:getWorkflowById(self.workflowId)
```

That comment is the bug. Nothing ever sends the definitions, so "same on all peers"
holds only when every peer reads the same file — i.e. a listen-server host, where
`g_server` and `g_client` are the same process.

On a joining client:

1. `WMStorage:getXmlPath()` derives from `g_currentMission.missionInfo.savegameDirectory`.
   A client has no server savegame, so this is nil and the path falls back to
   `WorkflowManager.modDirectory .. "/workflowManager.xml"` — a file that is not shipped.
2. `loadWorkflows()` therefore returns `{}`.
3. Every `WMStateSyncEvent` dead-ends at `"unknown workflowId '%s' – ignoring"`.
4. The client's main dialog is empty, so they cannot start a workflow either.

Net effect: **multiplayer works for the host and nobody else**, while `modDesc.xml`
advertises "Works in multiplayer — all players see the correct state on their screens".

## 3. Full defect list

Fixing the sync alone is not sufficient. The complete set:

| # | Defect | Location |
| --- | --- | --- |
| M1 | Workflow definitions are never transmitted | `WMNetworkEvents.lua` |
| M2 | Definition CRUD (create/edit/delete) is client-local, never propagated | `WorkflowManager`, `WMEditorDialog`, `WMMainDialog` |
| M3 | `saveWorkflows()` is unguarded — a client writes into the mod directory | 6 GUI call sites + `deleteMap` + the `FSBaseMission.saveSavegame` hook |
| M4 | HUD position is stored inside the workflow file, so a per-player UI preference is entangled with server-owned data | `WorkflowStorage.lua:140` |
| M5 | Leader identity is sent as a *workflow id*, but several vehicles can share one workflow | `WorkflowManagerSpec:onWriteStream` |
| M6 | `WMStateSyncEvent` never carries the leader link, so a mirror it creates cannot show the leader name | `WMNetworkEvents.lua` |
| M7 | No rights handling of any kind — see §6 | everywhere |
| M8 | `onDelete` calls `stopWorkflow` → AD/CP shutdown on clients, against a mirror | `WorkflowManagerSpec:onDelete` |
| M9 | Leader selection is host-only by explicit fallback | `WorkflowManager:sendCommand` |
| M10 | Vehicle eligibility (`isVehicleValid`, "already running") is validated **client-side only**; `executeNetworkCommand` re-checks almost none of it | `WorkflowManager:startWorkflow` vs `executeNetworkCommand` |
| M11 | Shutdown paths call AutoDrive against client-side mirrors | `WorkflowManager:deleteMap`, `FSBaseMission.delete` hook |
| M12 | Mod-directory storage fallback leaks a phantom workflow library across servers | `WorkflowStorage:getXmlPath` |
| M13 | Nothing guards a dedicated server (`g_dedicatedServer` appears 0 times) | `WMHud`, `WorkflowManagerSpec:onPostLoad` |
| M14 | Executor mutators are unguarded while its update loop is guarded | `WorkflowExecutor.lua` |
| M15 | HUD is shown for every restored vehicle, not the occupied one | `WorkflowManagerSpec:onPostLoad` |
| M16 | `savegameDirectory` is nil before a game's first save, so the M12 fallback bleeds workflows between **single-player** savegames too | `WorkflowStorage:getXmlPath` |
| M17 | Course names are *picked* against the client's local Courseplay library but *resolved* against the server's — the two are different folders on different machines | `CPCoursesLoader` (client) vs `CPIntegration:loadCourseFromStorage` (server) |

M3 and M4 are why this cannot be fixed by "just adding a sync event": once definitions
become server-owned, client-side saving must stop, and the HUD position must be extracted
first or clients silently lose it.

## 4. Precedent in AutoDrive and Courseplay

Both mods solve "mod-owned data that must exist on every peer", and they solve it
differently depending on *when* the data is needed.

### AutoDrive — networked `Object` for bulk state

```lua
-- AutoDrive.lua:179 (inside loadMap)
if g_server ~= nil then
    AutoDrive.AutoDriveSync = AutoDriveSync.new(g_server ~= nil, g_client ~= nil)
    AutoDrive.AutoDriveSync:register(false)
end
```

`AutoDriveSync` is an `Object` subclass (`InitObjectClass`). Its `writeStream` pushes the
entire graph — waypoints, map markers, groups — and `readStream` installs it on the client:

```lua
function AutoDriveSync:readStream(streamId, connection)
    if connection:getIsServer() then
        local wayPoints, mapMarkers, groups = AutoDriveSync.streamReadGraph(streamId)
        ADGraphManager:setWayPoints(wayPoints)
        ...
```

Two things to copy:

- The object is created **only on the server**, and registered during `loadMap` — before
  any vehicle exists. It therefore takes part in the initial object sync, which is what
  makes the graph available to AD's own vehicle specialisations.
- `AutoDrive.saveToXML()` is wrapped in `if g_server ~= nil` (`AutoDrive:saveSavegame`).
  Clients never write. This is exactly the M3 guard WM is missing.

### Courseplay — join event for settings, per-vehicle events for data

```lua
-- CpJoinEvent.lua
FSBaseMission.onConnectionFinishedLoading =
    Utils.appendedFunction(FSBaseMission.onConnectionFinishedLoading, sendEvent)
```

Simpler, but it fires **after** the client has finished loading — i.e. after vehicles have
streamed. Fine for CP's global settings; wrong for WM, whose vehicle spec `onReadStream`
needs the definitions already present.

Note also what CP does *not* do: it never ships its saved-course library to clients. It
syncs the course *loaded onto a vehicle* (`CoursesEvent`). WM cannot take that shortcut,
because a client must be able to browse and start workflows.

`CoursesEvent:run` is still worth copying for its request/broadcast shape:

```lua
if not connection:getIsServer() then
    -- event came from a client: we are the server, rebroadcast to everyone else
    g_server:broadcastEvent(CoursesEvent.new(...), nil, connection, self.vehicle)
end
```

## 5. Proposed architecture

Four layers. Definitions become **server-owned**; the server is the only writer of
`workflowManager.xml`, and clients hold a replica.

```
              ┌─────────────────────── SERVER ───────────────────────┐
              │  WorkflowManager.workflows   (authoritative)         │
              │  workflowManager.xml         (sole writer)           │
              └───────┬─────────────────────────────┬───────────────┘
   join: full replica │                             │ broadcast on change
              ┌───────▼─────────┐         ┌─────────▼──────────┐
              │  WMSyncObject   │         │  WMWorkflowEvent   │
              │  (Object)       │         │  (upsert / delete) │
              └───────┬─────────┘         └─────────┬──────────┘
                      │                             ▲ request
              ┌───────▼─────────────────────────────┴───────────────┐
              │  CLIENT: WorkflowManager.workflows (replica, RO)     │
              │  hud position → separate per-user file               │
              └──────────────────────────────────────────────────────┘
```

### Layer 1 — `WMSyncObject`: replica on join (fixes M1)

An `Object` subclass mirroring `AutoDriveSync`, created only on the server in
`WorkflowManager:loadMap` and registered with `:register(false)`.

- `writeStream` — serialise every workflow: id, name, adSettings, steps (type, target,
  action, unloadTarget, fillTypes) and nested support sub-steps.
- `readStream` — guarded with `if connection:getIsServer()`, replaces
  `WorkflowManager.workflows` wholesale.

Serialisation needs a nil-safe string writer; several WM fields are optional
(`action`, `unloadTarget`, `fillTypes`). AD has exactly this helper —
`AutoDrive.streamWriteStringOrEmpty` — worth mirroring rather than inventing.

Sizing: a heavy realistic set (30 workflows × 20 steps × ~64 bytes) is roughly 40 KB.
AD pushes an entire road graph — thousands of waypoints — through the same mechanism,
so this is comfortably within budget.

### Layer 2 — `WMWorkflowEvent`: mutations (fixes M2)

One event carrying `{ action = "upsert" | "delete", workflow | workflowId }`.

- Client → server: a *request*.
- Server: validates, applies to `WorkflowManager.workflows`, then broadcasts to all
  clients, using the `if not connection:getIsServer()` rebroadcast pattern from
  `CoursesEvent:run`.
- Server/host: applies locally and broadcasts directly (the existing `sendCommand` shape).

Call sites to route through it: `WMEditorDialog:onClickSave` (upsert — pairs naturally
with the `commitToSource` boundary already introduced), `WMMainDialog:onClickDelete`
(delete), and `WorkflowManager:registerWorkflow`.

### Layer 3 — storage ownership (fixes M3, M4)

- Guard `WorkflowManager:saveWorkflows()` with `if g_server == nil then return end`,
  matching `AutoDrive:saveSavegame`. This covers all 8 call sites at once.
- Extract the HUD position out of `workflowManager.xml` into a per-user file
  (`getUserProfileAppPath() .. "FS25_WorkflowManager_hud.xml"`, or modSettings), written
  by every peer. Without this, guarding saves silently breaks HUD position for clients —
  and it is per-player UI state that never belonged in server-owned data anyway.

### Layer 4 — hardening (fixes M5–M8)

- **M5/M6**: identify the leader by `vehicle.uniqueId` in `onWriteStream`/`onReadStream`
  *and* add it to `WMStateSyncEvent`. `uniqueId` is already the save-path identity
  (see the bug-119 fix); the wire path is the last place still using the ambiguous
  workflow id.
- **M7**: in `WMCommandEvent:run`, verify the vehicle exists and that the sending
  connection's farm may control it, before dispatching.
- **M8**: guard the AD/CP calls in `WorkflowManagerSpec:onDelete` with `g_server ~= nil`;
  clearing the local mirror is still correct on a client.
- **Ordering safety net**: make `WorkflowManagerSpec:onReadStream` keep the raw
  `workflowId` and resolve it lazily when unknown, instead of warning and dropping the
  state. WM already has this idiom for leader vehicles (`pendingLeaderUniqueId` +
  `tryResolvePendingLeader`). This removes any dependence on the object-vs-vehicle stream
  ordering assumption below.

### M9 — client-side leader selection

Once definitions replicate and clients hold `activeVehicles` mirrors, the leader dialog
can run on a client: it only needs the list of vehicles currently running workflows.
The chosen leader must then travel in `WMCommandEvent` as a `uniqueId`. This is a
follow-up, not part of the core fix.

## 6. Rights and permissions

WM currently has **none**. A grep across `src/` for `accessHandler`, `getHasPlayerPermission`,
`isMasterUser`, `getOwnerFarmId` and `userManager` returns nothing. `WMCommandEvent:run`
dispatches whatever arrives:

```lua
function WMCommandEvent:run(connection)
    if not connection:getIsServer() then
        WorkflowManager:executeNetworkCommand(self.commandType, self.vehicle, ...)
    end
end
```

Any client can therefore start, stop, pause or step any vehicle on the map, including
vehicles belonging to another farm.

### What FS25 provides

Three distinct tiers, all visible in AD/CP usage:

| Tier | API | Precedent | Question it answers |
| --- | --- | --- | --- |
| Object access | `g_currentMission.accessHandler:canPlayerAccess(vehicle)`<br>`…:canFarmAccess(farmId, object)` | `CpCourseGeneratorFrame:687`, `AutoDrive.lua:287` | may this player touch this object at all? |
| Farm action permission | `g_currentMission:getHasPlayerPermission(perm, connection, farmId)` | `CpAIJob:getIsStartable` | may this connection's user perform action X on behalf of this farm? |
| Administrator | `g_currentMission.isMasterUser` | `ADRoutesManager:load` | may this player change global shared config? |

The authoritative precedent is Courseplay, because it is doing the same thing WM does —
starting a helper on someone's vehicle:

```lua
-- CpAIJob.lua:315
function CpAIJob:getIsStartable(connection)
    local vehicle = self.vehicleParameter:getVehicle()
    if vehicle == nil then return false, AIJobFieldWork.START_ERROR_VEHICLE_DELETED end
    if not g_currentMission:getHasPlayerPermission("hireAssistant", connection, vehicle:getOwnerFarmId()) then
        return false, AIJobFieldWork.START_ERROR_NO_PERMISSION
    end
    if vehicle:getIsInUse(connection) then return false, AIJobFieldWork.START_ERROR_VEHICLE_IN_USE end
    return true, AIJob.START_SUCCESS
end
```

Note what it does **not** do: it never trusts a client-supplied farm id. `farmId` comes from
`vehicle:getOwnerFarmId()` (server-side truth) and the identity comes from `connection`.

AutoDrive is a **counter-example, not a model** here — `AutoDriveInputEventEvent` accepts a
`farmId` written by the client and passes it straight to `ADInputManager:onInputCall`:

```lua
function AutoDriveInputEventEvent:run(connection)
    if g_server ~= nil then
        ADInputManager:onInputCall(self.vehicle, input, self.farmId, false)   -- client-supplied farmId
    end
end
```

Do not copy that shape.

### Proposed model for WM

**Execution commands** (`WMCommandEvent`) — **two axes, not one.** An earlier draft of this
section required `"hireAssistant"` for every command. Reading the base game shows that is
stricter than GIANTS themselves are, and in a way that matters:

```lua
-- AISystem.lua:563 - no permission check anywhere on this path
function AISystem:stopJob(job, aiMessage)
    if self.isServer then
        self:stopJobInternal(job, aiMessage)
        g_server:broadcastEvent(AIJobStopEvent.new(job, aiMessage))
    else
        g_client:getServerConnection():sendEvent(AIJobStopEvent.new(job, aiMessage))
    end
end
```

Starting a helper is gated (`getIsStartable`); **stopping one is not**. That is a
deliberate safety valve — whoever notices a helper causing damage can halt it. WM should
not be more restrictive than the game it automates.

| Command | Vehicle access | `hireAssistant` |
| --- | --- | --- |
| `start`, `resume`, `next_step`, `prev_step` | required | **required** — these begin or redirect work |
| `stop`, `pause` | required | *not* required — safety valve, matches `AISystem:stopJob` |

Vehicle access is the farm check (`canFarmAccess` / `canPlayerAccess`); it applies to every
command, so a player still cannot touch a farm they have no business in.

The start path should also mirror the base game's third check, which the earlier draft
missed — `vehicle:getIsInUse(connection)`. `AIJobVehicle:getIsInUse` returns true whenever
`getIsAIActive()`, so this catches both "another player is in the seat" and "an AI job is
already running"; WM's own `isWorkflowActiveOnVehicle` covers neither.

```lua
function WMCommandEvent:run(connection)
    if connection:getIsServer() then return end           -- server -> client, nothing to do

    local vehicle = self.vehicle
    if vehicle == nil or vehicle.spec_workflowManagerSpec == nil then return end

    local farmId = vehicle.getOwnerFarmId and vehicle:getOwnerFarmId()
    if farmId == nil or not g_currentMission.accessHandler:canFarmAccess(farmId, vehicle) then
        return
    end

    -- Only commands that start or redirect work need the helper permission.
    local needsHirePermission = self.commandType ~= "stop" and self.commandType ~= "pause"
    if needsHirePermission
    and not g_currentMission:getHasPlayerPermission("hireAssistant", connection, farmId) then
        WMLogger:warning("WMCommandEvent: rejected '%s' - no hireAssistant permission",
            tostring(self.commandType))
        return
    end

    if self.commandType == "start" and vehicle:getIsInUse(connection) then
        WMLogger:warning("WMCommandEvent: rejected 'start' - vehicle in use")
        return
    end

    WorkflowManager:executeNetworkCommand(...)
end
```

**Definition edits** (`WMWorkflowEvent`, layer 2) — this is a **product decision**, because
workflow definitions are currently global to the savegame, not owned by a farm:

| Option | Behaviour | Precedent |
| --- | --- | --- |
| A. Open | any player may create/edit/delete any workflow | AD map markers (`CreateMapMarkerEvent` — ungated) |
| B. Admin-only | only server/`isMasterUser` may edit; others read and run | `ADRoutesManager` |
| C. Farm-owned | add `workflow.farmId`; visible to all, editable by the owning farm | base-game ownership model |

Recommendation: **A**, plus one guard — refuse to delete or restructure a workflow that is
currently executing on a vehicle the requester has no `hireAssistant` permission for. That
preserves today's single-player feel, avoids a migration (no new `farmId` field), and still
prevents the one destructive cross-farm action. B is a one-line change on top if a server
owner wants it locked down; C should wait until someone actually asks for per-farm libraries.

**UI gating** — the base game has a dedicated form for exactly this that the earlier draft
missed: `getHasPlayerPermission` called with **no connection** is a *local* check.

```lua
-- AIJobVehicle.lua:244, in getCanStartAIVehicle
if not g_currentMission:getHasPlayerPermission("hireAssistant") then
    return false
end

-- AIModeSelection.lua:259 - and the denial message it shows
if g_currentMission:getHasPlayerPermission("hireAssistant") then
    self:toggleAIVehicle()
else
    g_currentMission:showBlinkingWarning(g_i18n:getText("ai_startStateNoPermission"), 2000)
end
```

So HUD/dialog gating should use the 1-argument local form plus `canPlayerAccess(vehicle)`,
and reuse **`ai_startStateNoPermission`** for the warning rather than adding a WM
translation — it is a base-game key, already localised in every shipped language, and it is
the exact wording players see when the base game refuses a helper for the same reason.

**Permission vocabulary is deliberately small.** Grepping every permission reference in the
base game yields only four names — `hireAssistant`, `createFields`, `cutTrees`,
`tradeAnimals` (plus `Farm.PERMISSION.BUY_VEHICLE` / `.CUT_TREES` as constants). There is no
finer-grained permission to reach for, which settles `hireAssistant` as the only sensible
choice rather than merely a plausible one.

**Optional:** `g_currentMission.aiSystem:getAILimitedReached()` is the base game's first
check in `getIsStartable`. WM does not start AI jobs itself — CP does, and CP will hit the
limit on its own — but checking it in `startWorkflow` would turn an obscure downstream CP
failure into a clear "helper limit reached" message.

**M10 — move validation server-side.** `WorkflowManager:startWorkflow` checks
`isVehicleValid` (AD + CP present) and "vehicle already busy" *before* `sendCommand`, i.e.
on the client. `executeNetworkCommand` → `WMExecutor:startWorkflow` re-checks only spec
presence and `wmExecution ~= nil`. The `isVehicleValid` check must be repeated server-side;
client-side checks are UX, never enforcement.

## 7. Full-codebase client/server sweep

A pass over every module for side-confusion, beyond the sync and rights axes.

### Clean — no action needed

| Area | Why it is fine |
| --- | --- |
| `WMExecutor:update` | `if g_server == nil then return end` — the only guarded entry point |
| `WorkflowManagerSpec:onPostLoad` | `if savegame == nil ... then return end`; a client has no savegame, so the whole restore path is server-only by construction |
| `WorkflowManagerSpec:onRegisterActionEvents` | `if not self.isClient then return end` |
| `WorkflowManager:loadDialogs` / `registerGlobalActions` | nil-check `g_gui` / `g_inputBinding` before use |
| `WorkflowManager:broadcastState` | `g_server:broadcastEvent(evt, false, …)` — `sendLocalEvent = false`, so a host does not re-apply its own state through the client mirror path |
| `sendCommand` | routes to `executeNetworkCommand` on the server and to `WMCommandEvent` on a client; a host never does both |
| `g_currentMission.hud:showBlinkingWarning` calls | all guarded with a full nil-chain |
| Executor timing (`pendingAutoStep`, `autoResumeUntil`) | only evaluated inside the server-guarded update loop |

### M11 — shutdown paths call AutoDrive on clients

Both `WorkflowManager:deleteMap` and the `FSBaseMission.delete` prepended hook iterate
`WMExecutor.activeVehicles` and call `ADIntegration:clearCPHandoff` / `stopRoute`. On a
client that table is full of **mirrors** created by `onReadStream` / `WMStateSyncEvent`, so
every client leaving a server issues AD commands against vehicles it does not own.
`deleteMap` additionally calls `saveWorkflows()` (see M3/M12) on clients.

Same class as M8, different location — the fix is one guard shared by all three sites.

### M12 — the mod-directory fallback leaks a phantom library between servers

```lua
-- WorkflowStorage.lua:53
if savegamePath ~= nil then return savegamePath .. "/" .. self.xmlFilename end
return WorkflowManager.modDirectory .. "/" .. self.xmlFilename   -- <-- same path on every server
```

This is worse than "clients have no workflows". The fallback path is **identical for every
server the player joins**, and it is written by any dialog Save, any HUD drag, and by
`deleteMap` on exit. So a client accumulates a persistent local workflow library in the mod
folder that is loaded on every subsequent join to *any* server, containing ids that match
nothing the server knows.

Consequences: confusing phantom entries in the client's list; `WMStateSyncEvent` warnings
that look like a sync bug but are not; and, once definitions replicate, a stale file that
must be ignored or removed rather than merged. Shipping Layer 1 should delete or ignore this
file on clients.

### M13 — nothing guards a dedicated server

`grep -c g_dedicatedServer src/` → **0**. AutoDrive guards both its HUD and its sync object
with `g_dedicatedServer == nil` / `~= nil` (`Hud.lua:584`, `Sync.lua:235`).

`WMHud:show()` is called unconditionally from three places that do run on a dedicated server:
`WorkflowManagerSpec:onPostLoad` (the server loads the savegame), and the
`EVENT_WORKFLOW_STARTED` / `EVENT_WORKFLOW_RESUMED` handlers (fired by the server-side
executor). Each sets `WMHud.isVisible = true` on a headless host. If `draw()` is dispatched
there, `WMHud:draw` → `ensureOverlays()` → `getNormalizedScreenValues` and
`Overlay.new(g_baseUIFilename, …)` run without a display.

Whether a dedicated server dispatches `draw` needs live confirmation, but the guard costs
nothing: make `WMHud:show/update/draw` no-op when `g_dedicatedServer ~= nil`.

### M14 — the executor's contract is inconsistent

`WMExecutor:update` is server-guarded; `startWorkflow`, `stopWorkflow`, `pauseWorkflow`,
`resumeWorkflow`, `goToNextStep` and `goToPreviousStep` are not. Today the only path that
exploits this is `onDelete` (M8), because everything else arrives through
`executeNetworkCommand`. But "the loop is guarded, the entry points are not" is exactly the
shape that invites a future regression — any new caller silently gets client-side AD/CP
execution.

Recommend one shared guard (e.g. an early `if not WMExecutor:isAuthoritative() then` in each
public mutator) rather than relying on every future caller knowing the rule.

### M17 — the course library a step names is not the one that resolves it

Courseplay's course storage is **per machine**, not per savegame and not synced:

```lua
-- Courseplay.lua:19
self.baseDir = getUserProfileAppPath() .. "modSettings/" .. Courseplay.MOD_NAME .. "/"
-- Courseplay.lua:251-253
self.courseDir = self.baseDir .. "Courses"
self.courseStorage = FileSystem(self.courseDir, g_currentMission.missionInfo.mapId)
```

`Courseplay:load()` runs on every peer, so every peer builds a `FileSystem` over *its own*
`modSettings` folder. §4 already notes CP never ships the library to clients; the consequence
for WM is a split that no other defect in this list has:

| Phase | Runs on | Reads |
| --- | --- | --- |
| Authoring — `CPCoursesLoader:scanCourses` fills the step dialog's course list | the **client** with the GUI open | that client's `modSettings` courses |
| Execution — `CPIntegration:loadCourseFromStorage` | the **server** (`WMExecutor:update` is `g_server`-guarded; `startCourseplayStep` is reached only from there) | the server's `modSettings` courses |

So a client can only pick a course the server may not have, and the stored string is the
sole link between the two. On a dedicated server the server-side library is typically empty,
in which case `loadCourseFromStorage` returns false and `loadCourse` falls through to
`vehicle.loadCpCourse` / `setCpCourse`.

Note this is **not** made worse by the bug-`cp-wrong-folder-course` fix. That fix only
re-orders which candidate wins among same-named files and still falls back to the first
name match when no path matches, so it is strictly tighter than the previous
"first file with this base name anywhere" behaviour. But it does not — and cannot — help
when the file simply is not on the resolving machine.

Options, none of them free:

- **A. Sync the name only** (status quo). Works when both peers keep matching course folders,
  which is what a listen-server host with one player already satisfies. Document the
  requirement rather than pretending it holds.
- **B. Resolve on the client, ship the resolved course.** Mirrors CP's own `CoursesEvent`,
  which syncs the course *loaded onto a vehicle* rather than the library. Most faithful to
  CP's design, but WM's execution is server-driven and would have to await a client round-trip
  mid-step — and the authoring client may be offline by then.
- **C. Ship the library.** Rejected for the same reason CP rejected it: unbounded size, and it
  makes WM the owner of another mod's data.

Recommendation: **A** for now, plus a diagnostic — when `loadCourseFromStorage` finds nothing,
log the server-side course count so the failure reads as "this server has 0 courses" instead
of a silent fall-through. Revisit B only if MP course execution becomes a real use case.

### M15 — HUD show-on-restore is indiscriminate (minor)

`onPostLoad` calls `WMHud:show(self)` for *every* restored vehicle, not just the one the
player occupies. Self-corrects through the 3-second auto-hide in `WMHud:update`, but a host
restoring several active workflows gets a visible flicker on load.

### Dead code found during the sweep

`WMExecutor:resetWorkflow` (`WorkflowExecutor.lua:1518`) has no callers.
`WorkflowManager:resetWorkflow(workflowId)` is a separate function that delegates to
`stopWorkflow`. Unrelated to MP; noted so it is not mistaken for the live path.

## 8. Suggested phasing

| Phase | Contents | Outcome |
| --- | --- | --- |
| 1 | `WMSyncObject` (L1) + storage guards and HUD split (L3) + stale-file cleanup (M12) | Clients see workflows, the HUD works, state sync resolves. Clients can start/stop/pause but not edit. This alone makes the modDesc claim true. |
| 2 | `WMWorkflowEvent` (L2) | Clients can create/edit/delete; changes propagate to everyone. |
| 3 | Rights (§6) + hardening (L4, §7) | `hireAssistant` check on every command, server-side eligibility validation, UI gating, correct leader identity on the wire, no client-side AD/CP calls (M8/M11/M14), dedicated-server guards (M13). |
| 4 | Client-side leader selection (M9) | Removes the host-only restriction. |

Phase 1 is self-contained and independently shippable. Phase 3's ordering safety net is
worth pulling forward into Phase 1 if the stream-ordering check below is inconclusive.

## 9. Verification against GIANTS sources

Three authoritative sources exist locally, none of which needs the internet:

| Source | Path | Covers |
| --- | --- | --- |
| GIANTS game Lua source | `…/Farming Simulator 25/sdk/debugger/gameSource.zip` | 951 files / ~93k lines of real base-game script |
| Engine C++ bindings | `…/sdk/debugger/scriptBinding.xml` | every engine function (`streamWrite*`, etc.) with parameter lists |
| Online LUADOC | `gdn.giants-software.com/documentation_scripting_fs25.php` | same shipped subset, browsable |
| Local LUADOC scrape | `C:\Users\Chef\Downloads\FS25_LuaDoc_Markdown.zip` | 65 classes as markdown, **Script v1.15.0.0** |

`gameSource.zip` is a **partial** dump: gameplay scripts (vehicles, ai, placeables, objects,
specializations) are present; the mission/network core (`FSBaseMission`, `Server`, `Object`,
`Connection`, `AccessHandler`, `Farm`) is **not**. GDN documents the same subset, so it adds
nothing for those classes.

### Confirmed

| Claim | Evidence |
| --- | --- |
| `getHasPlayerPermission("hireAssistant", connection, vehicle:getOwnerFarmId())` is the right check for starting a helper | verbatim in five base-game jobs: `AIJobFieldWork:253`, `AIJobConveyor:129`, `AIJobDeliver:483`, `AIJobGoTo:205`, `AIJobLoadAndDeliver:584`. CP copied the base game; §6 copies it too |
| Permission names may be strings or `Farm.PERMISSION.*` constants | `"tradeAnimals"`, `"createFields"`, `"cutTrees"` as strings; `Farm.PERMISSION.BUY_VEHICLE`, `Farm.PERMISSION.CUT_TREES` as constants |
| A 4-argument form exists | `Plow.lua:822` — `getHasPlayerPermission("createFields", self:getOwnerConnection(), nil, true)` |
| `broadcastEvent(event, sendLocalEvent, ignoreConnection, object)` | `HusbandryMeadowCreateEvent:53` — `g_server:broadcastEvent(self, false, connection, self.placeable)`; `FenceNewSegmentEvent:117`. **WM's existing `broadcastEvent(evt, false, nil, vehicle)` is correct as written** |
| `:register(true/false)` is the standard Object registration call | ~10 base-game call sites (`AnimatedMapObject:29`, `HandToolHolder:136`, …) |
| `missionInfo.savegameDirectory` can legitimately be nil | `AISystem:1105` guards it with *"Savegame directory does not exist yet, please save the game first"* |

### M16 — `savegameDirectory` is nil before the first save, so M12 also bites single-player

The base game's own error message proves the nil case is **a new game that has not been
saved yet**, on the server — not only a client. That makes the M12 fallback a
single-player data-bleed bug as well:

1. Start a new savegame, create workflows *before* the first manual save.
2. `getXmlPath()` returns `modDirectory/workflowManager.xml`; they are written there.
3. Start a *different* new savegame. `loadWorkflows()` reads the same mod-directory file —
   the previous game's workflows appear in the new one.

This raises M12's priority: it is not an MP-only concern and should be fixed independently
of the sync work. The correct behaviour is to refuse to load or save when
`savegameDirectory` is nil, rather than silently falling back to a shared path.

### What the LUADOC scrape adds

The markdown scrape confirms the farm permission model that §6 builds on — `Farm.md`
documents `Farm.PERMISSION` as the canonical constants table, plus the per-user API:

```
getUserPermissions(userId)                          -- hash table {permission=}
setUserPermission(userId, permission, hasPermission) -- "Permission key from Farm.PERMISSION"
isUserFarmManager / promoteUser / demoteUser
addUser  -- "adds it to the players and active players list. And also gives default permissions."
```

It also gives `AccessHandler.EVERYONE` (`BoatyardActivatable.md`, `HandTool.md`) and confirms
`Farm` has `Object` as its parent — so `Object` is a real, live base class.

Caveats: it is **Script v1.15.0.0** against an installed game of **1.21.1.0** (GDN currently
serves v1.20.0.0), and it covers 65 classes rather than GDN's full set. Treat it as
corroboration, not as the primary source — prefer `gameSource.zip`, which matches the
installed build.

### Still unverified — and *no* documentation will settle it

`savegameDirectory` on a *joining client*; `g_dedicatedServer`; `Object:register` semantics
and object-vs-vehicle stream ordering; `FSBaseMission.onConnectionFinishedLoading`.

This is now a firm conclusion rather than a gap in our searching. GDN **does not document
the base `Object` class at all** — its Objects category (`category=63`) lists only concrete
subclasses (`AnimatedMapObject` 567 … `VehicleSellingPoint` 580), and there is no `Server`,
`Connection` or `MissionInfo` entry anywhere. These live in the engine/core that GIANTS
ships neither as source nor as documentation, so logging into GDN would not help either.

Two options remain, and they are complementary:

1. **Trust the working precedent.** AutoDrive uses `Object` + `:register(false)` in
   `loadMap` and it demonstrably works in production MP for exactly this purpose. The design
   already copies that shape, and the §5 Layer-4 deferred-resolution safety net makes the
   stream-ordering question moot.
2. **Measure it once in a live session** — see §10. Four log lines settle all four items.

Further documentation research is not worth doing; stop here and verify in-game.

## 10. Needs live verification

These are inferences from the AD/CP sources, not things provable offline:

1. **`savegameDirectory` is nil on a joining client.** Strongly implied — AD's
   `getXMLFile()` carries an explicit fallback for the nil case — but confirm by logging
   `WMStorage:getXmlPath()` on a client.
2. **Object streams precede vehicle streams.** AD relies on this for its graph, and
   registering in `loadMap` (before vehicles exist) should order it first. The Layer 4
   safety net makes the design correct either way, which is why it is cheap insurance.
3. **Total serialised size** in a real save with many workflows.

## 11. Explicitly out of scope

- Per-farm workflow ownership / visibility. Currently every workflow is global to the
  save; making them farm-scoped is a product decision, not a sync fix.
- Conflict resolution for two clients editing one workflow simultaneously. Last-write-wins
  via the server is sufficient at this scale.
