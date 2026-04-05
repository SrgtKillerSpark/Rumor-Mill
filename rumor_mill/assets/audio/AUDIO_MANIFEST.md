# Rumor Mill — Audio Manifest

Place audio files in the directories below. The `AudioManager` autoload
(`scripts/audio_manager.gd`) loads them at startup; missing files are silently
skipped so the game runs without audio assets during development.

Preferred format: `.wav` (all tracks; convert to `.ogg` for final shipping and
update `MUSIC_FILES` / `SFX_FILES` dictionaries in `audio_manager.gd`).

---

## Music — phase-aware  (`assets/audio/music/`)

The `AudioManager` plays **three time-of-day music phases** that crossfade as the
in-game clock advances (wired to `DayNightCycle.phase_changed`).  Crossfade
duration: **2 seconds**.

| File                   | Phase      | Loop | Description                                 |
|------------------------|------------|------|---------------------------------------------|
| `morning_calm.wav`     | Morning    | Yes  | Soft lute/harp, hopeful medieval feel       |
| `evening_tension.wav`  | Evening    | Yes  | Building tension, minor-key strings         |
| `night_suspense.wav`   | Night      | Yes  | Sparse, ominous — drone + plucked lute      |

### Legacy / menu music

| File               | When used          | Loop | Description                        |
|--------------------|--------------------|------|------------------------------------|
| `main_theme.wav`   | Title / main menu  | Yes  | Opening medieval lute theme        |

### Day/night ambient layer

A secondary ambient track crossfades alongside the music layer.  Triggers at
dawn (hour 6) and dusk (hour 20).  Crossfade duration: **2 seconds**.

| File               | Condition          | Loop | Description                              |
|--------------------|--------------------|------|------------------------------------------|
| `ambient_day.wav`  | Hours 6 – 19       | Yes  | Birds, distant market chatter            |
| `ambient_night.wav`| Hours 20 – 5       | Yes  | Crickets, distant bells                  |

### Location-specific ambient

Played on the **ambient layer** (replacing day/night ambient) while a building
interior panel is open.  Restores to day/night ambient on panel close.

| File                  | Building interior | Loop | Description                               |
|-----------------------|-------------------|------|-------------------------------------------|
| `ambient_tavern.wav`  | Tavern            | Yes  | Murmur of patrons, crackling fire         |
| `ambient_chapel.wav`  | Chapel            | Yes  | Choir hum, echo, quiet reverence          |
| `ambient_market.wav`  | Market            | Yes  | Stall calls, coin clinks, crowd chatter   |
| `ambient_manor.wav`   | Manor             | Yes  | Quiet grandeur, distant servants' steps   |

---

## SFX  (`assets/audio/sfx/`)

| File                   | Trigger / context                                          |
|------------------------|------------------------------------------------------------|
| `recon_observe.wav`    | Successful Observe recon action                            |
| `recon_eavesdrop.wav`  | Successful Eavesdrop recon action                          |
| `rumor_spread.wav`     | Player seeds a rumor via the Crafting Panel                |
| `rumor_fail.wav`       | Rumor rejected / fails to spread                           |
| `journal_open.wav`     | Player Journal panel opens                                 |
| `journal_close.wav`    | Player Journal panel closes                                |
| `rumor_panel_open.wav` | Rumor Crafting Panel opens                                 |
| `rumor_panel_close.wav`| Rumor Crafting Panel closes                                |
| `whisper.wav`          | NPC-to-NPC rumor transmission (propagation tick)           |
| `win.wav`              | Win condition reached                                      |
| `fail.wav`             | Fail / day-limit condition reached                         |
| `ui_click.wav`         | Generic UI button press                                    |
| `new_day.wav`          | New in-game day begins                                     |
| `reputation_up.wav`    | Player or faction reputation increases                     |
| `reputation_down.wav`  | Player or faction reputation decreases                     |
| `bribe_coin.wav`       | Bribe action used (coin drop clink)                        |

---

## Hover Sound

Button hover uses `AudioManager.play_sfx_pitched("ui_click", 2.0)` — the same
`ui_click.wav` played at 2× pitch scale, producing a lighter tick distinct from
the full click.  No separate `ui_hover.wav` asset is required.  Wired in:
`main_menu.gd`, `pause_menu.gd`, `speed_hud.gd`, `rumor_panel.gd`.

---

## Music Looping

All `.wav` tracks have `edit/loop_mode=0` in their `.import` files (Godot
default).  `AudioManager._preload_all()` sets
`stream.loop_mode = AudioStreamWAV.LOOP_FORWARD` at runtime for all entries in
`MUSIC_FILES`, ensuring continuous playback without editor reimport.
