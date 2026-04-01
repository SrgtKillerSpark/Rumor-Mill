# Rumor Mill — Audio Manifest (Sprint 7)

Place audio files in the directories below. The `AudioManager` autoload loads
them at startup; missing files are silently skipped so the game runs without
audio assets during development.

Preferred format: `.ogg` (music/ambient), `.wav` (SFX).

## Music  (`assets/audio/music/`)

| File                  | Description                                      | Loop |
|-----------------------|--------------------------------------------------|------|
| `main_theme.ogg`      | Opening / title screen medieval lute theme       | Yes  |
| `ambient_day.ogg`     | Daytime town ambience (birds, market chatter)    | Yes  |
| `ambient_night.ogg`   | Nighttime ambience (crickets, distant bells)     | Yes  |

Day/night crossfade triggers at hour 6 (dawn) and hour 20 (dusk).
Crossfade duration: 2 seconds.

## SFX  (`assets/audio/sfx/`)

| File                    | Trigger                                          |
|-------------------------|--------------------------------------------------|
| `recon_observe.wav`     | Successful Observe action                        |
| `recon_eavesdrop.wav`   | Successful Eavesdrop action                      |
| `rumor_spread.wav`      | Player seeds a rumor via the Crafting Panel      |
| `journal_open.wav`      | Player Journal panel opens                       |
| `journal_close.wav`     | Player Journal panel closes                      |
| `rumor_panel_open.wav`  | Rumor Crafting Panel opens                       |
| `rumor_panel_close.wav` | Rumor Crafting Panel closes                      |
| `whisper.wav`           | NPC-to-NPC rumor transmission (propagation tick) |
| `win.wav`               | Win condition reached                            |
| `fail.wav`              | Fail / day-limit condition reached               |
| `ui_click.wav`          | Generic UI button press                          |
| `new_day.wav`           | New in-game day begins                           |
