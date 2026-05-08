# Rumor Mill — Stakeholder Demo (Sprint 7)

A medieval social-simulation game where the player spreads and manages rumors through a town of 30 NPCs.

---

## Quick Start (Standalone Build)

### Requirements
- **Windows 10 / 11** (64-bit)
- No installation required — the exported build is self-contained.

### Launch
1. Unzip the build package (e.g. `RumorMill-v0.1.0-win64.zip`) to any folder.
2. Double-click **`Rumor Mill.exe`**.
3. The game opens at 1280×720. Use fullscreen toggle (`Alt+Enter`) if preferred.

> **Running from the Godot editor instead?**  
> Open `rumor_mill/project.godot` in **Godot 4.6** and press **F5** (or the Play button).

---

## Controls

| Action | Key / Mouse |
|---|---|
| Pan camera | W A S D or Arrow keys |
| Zoom | + / − |
| Observe building | Right-click building |
| Eavesdrop NPC | Right-click NPC |
| Open Rumor Crafting Panel | R |
| Open Player Journal | J |
| Open Social Graph | G |
| Debug console | F1 |
| NPC state badges | F2 |
| Social graph (debug) | F3 |
| Lineage tree | F4 |

---

## Scenario 1 — The Merchant's Downfall

**Objective:** Damage the merchant lord's reputation below 30 before Day 10 ends.

1. Right-click buildings or NPCs to **Observe / Eavesdrop** and gather intel.
2. Press **R** to open the Rumor Crafting Panel.
3. Select a **Subject**, choose a damaging **Claim**, then pick a well-connected NPC to seed through.
4. Watch the Social Graph Overlay (**G**) as the rumor spreads.
5. Monitor the merchant's reputation in the **Player Journal** (**J**).

A win screen appears when the objective is met; a fail screen appears if Day 10 ends without reaching it.

---

## Known Limitations (Sprint 7 Demo Build)

- **Audio**: all tracks and SFX are silent placeholder files. Final royalty-free audio will be integrated before public release.
- **Export template**: build requires the Godot 4.6 **Windows Desktop export template** to be installed in the editor. See [Godot export docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html) for setup.
- Scenarios 2 and 3 are playable but not fully balanced for this sprint.

---

## Exporting a Standalone Build

1. Open the project in **Godot 4.6**.
2. Install the Windows Desktop export template via **Editor → Manage Export Templates**.
3. Go to **Project → Export…**
4. Select the **Windows Desktop** preset (pre-configured in `export_presets.cfg`).
5. Click **Export Project** and choose an output folder.

The exported `.exe` + `.pck` pair runs without Godot installed.

---

## Developer Workflow

### GDScript parse validation

A headless Godot validation script prevents parse errors from reaching `main`.

**Run locally (bash / macOS / Linux / Git Bash on Windows):**
```bash
bash rumor_mill/tools/validate_gdscript.sh
```

**Run locally (Windows Command Prompt):**
```bat
rumor_mill\tools\validate_gdscript.bat
```

Both scripts auto-detect the Godot binary. Pass `--godot <path>` or set `GODOT_BIN` if Godot is not on your `PATH`. Exit code `0` = clean; `1` = parse errors found (failing files printed); `2` = setup error (binary/project not found).

**Install git hooks** (one-time, after cloning):
```bash
bash rumor_mill/tools/install_hooks.sh
```
This installs a `pre-commit` hook (headless Godot check on staged `.gd`/`.tscn` files) and a `pre-push` hook (lightweight static check, no Godot required).

**CI:** `.github/workflows/validate-gdscript.yml` runs automatically on every push/PR touching `rumor_mill/scripts/**`, `rumor_mill/tests/**`, `rumor_mill/scenes/**`, or `project.godot`.

---

## Data Files

All game data lives in `rumor_mill/data/` and is bundled automatically on export:

| File | Contents |
|---|---|
| `npcs.json` | 30 NPC definitions (name, faction, personality stats, schedule) |
| `claims.json` | Rumor claim templates (type, intensity, mutability) |
| `scenarios.json` | Win conditions, starting reputations, edge overrides |
| `town_grid.json` | 48×48 isometric tile grid |
