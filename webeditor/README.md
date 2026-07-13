# FS25 Workflow Manager — Web Editor

A standalone static web app to create and edit Workflow Manager workflows in the browser —
no game running, no build step, no dependencies. Deployable as a GitHub Page.

## Features (parity with the in-game editor)

- **Workflows**: create, rename, duplicate, delete, search
- **Steps**: all seven step types — AutoDrive, Courseplay, the sync markers
  *Wait for Leader* / *Unlock Follower*, and the targetless AutoDrive actions
  *Park* / *Refuel* / *Repair* (quick-add buttons, no dialog needed)
- **AutoDrive modes**: Drive To, Pickup & Deliver, Deliver, Load, Unload — with the same
  dynamic target / second-target labels as the in-game step dialog
- **Courseplay actions**: Field Work, Bale Collect
- **Fill types**: multi-select with search (full FS25 base list built in, custom mod
  fill type IDs can be typed in)
- **Support sub-steps**: nest support-vehicle steps under any main step, reorder them,
  edit and duplicate them
- **AD/CP settings** per workflow: Unload Fill Level (%), Pipe Offset (m), Pre-Call Level (%)
- **Reordering**: move buttons + drag & drop
- **Import** `workflowManager.xml` (file picker or drop anywhere on the page) — old save
  formats (linked-workflow pairs, per-step sync flags) are migrated exactly like
  `WorkflowStorage.lua` does in-game
- **Export** a game-ready `workflowManager.xml` (formatVersion 2); HUD position from an
  imported file is preserved
- **Target suggestions**: maintain AutoDrive destination / Courseplay course lists, import
  marker names straight from an `AutoDrive_config.xml`, or course names from CP course files
- **Autosave** to browser localStorage, **light/dark mode**, **English/German** UI

## Usage

1. Open the page (or `index.html` locally — no server needed).
2. Build your workflows.
3. **Export XML** and place `workflowManager.xml` in your savegame folder
   (`.../My Games/FarmingSimulator2025/savegameN/`), replacing the existing file
   while the game is closed.
4. Or start from your current file: **Import XML** first.

## GitHub Pages deployment

`.github/workflows/deploy-webeditor.yml` publishes this folder via GitHub Pages on every
push to `main` that touches `webeditor/`. One-time setup: repository **Settings → Pages →
Source: GitHub Actions**.
