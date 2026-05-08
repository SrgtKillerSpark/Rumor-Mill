extends Node

## audio_manager.gd — Sprint 7 + SPA-491 + SPA-917 + SPA-1411 audio polish.
##
## Manages three audio layers:
##   1. Music      — phase-aware music (morning_calm / evening_tension / night_suspense),
##                   crossfades between phases on game-tick transitions.
##   2. Ambient    — day/night ambient crossfade OR location-specific ambient (tavern /
##                   chapel / market / manor) while a building interior is open.
##   3. SFX        — polyphonic pool, one-shot sound effects.
##
## Audio files are loaded from res://assets/audio/.
## Missing files are silently skipped — the game runs without audio assets.
##
## Usage (from any script):
##   AudioManager.play_ui("click")           # UI feedback SFX
##   AudioManager.play_event("rumor_seeded")  # gameplay event SFX
##   AudioManager.play_sfx("recon_observe")   # direct SFX by key
##   AudioManager.play_music("morning_calm", true)   # crossfade
##   AudioManager.play_ambient("tavern")      # location ambient
##   AudioManager.set_location_ambient("tavern")
##   AudioManager.clear_location_ambient()
##   AudioManager.set_sfx_volume_db(-6.0)
##   AudioManager.duck_for_dialogue()
##   AudioManager.restore_from_dialogue()
##   AudioManager.set_heat_ambient_tension(active)
##
## Called by main.gd:
##   AudioManager.connect_to_day_night(day_night_node)
##   AudioManager.on_rumor_seeded(...)
##   AudioManager.on_rumor_success()
##   AudioManager.on_rumor_fail()
##   AudioManager.on_recon_action(message, success)
##   AudioManager.on_bribe_executed(npc_name, tick)
##   AudioManager.on_heat_warning()
##   AudioManager.set_heat_ambient_tension(active)
##   AudioManager.on_win()
##   AudioManager.on_fail()
##   AudioManager.on_socially_dead(npc_id, npc_name, tick)

# ── Constants ──────────────────────────────────────────────────────────────────

## Base path for all audio assets.
const AUDIO_BASE := "res://assets/audio"

## Hour range considered "daytime" (inclusive) for ambient crossfade.
const DAY_START_HOUR  := 6
const DAY_END_HOUR    := 20

## Day-phase boundaries (hours, inclusive start).
## morning = 6-15, evening = 16-19, night = 20-5.
const MORNING_START := 6
const EVENING_START := 16
const NIGHT_START   := 20

## Crossfade duration in seconds.
const CROSSFADE_TIME  := 2.0

## Short fade duration for win/fail music fade-out before stinger.
const STINGER_FADE_TIME := 0.6

## Default volumes (dB).
const DEFAULT_MUSIC_DB   := -12.0
const DEFAULT_AMBIENT_DB := -18.0
const DEFAULT_SFX_DB     := 0.0

## Maximum simultaneous SFX voices in the polyphonic pool.
const SFX_POOL_SIZE := 8

# ── Audio file map ─────────────────────────────────────────────────────────────
## Maps logical name → relative path under AUDIO_BASE.
## Artists/designers place .ogg or .wav files at these paths.
## Swap to .ogg when final royalty-free tracks are ready (replace files + update here).
const MUSIC_FILES: Dictionary = {
	# Main gameplay phases — crossfade as the in-game clock advances.
	"morning_calm":     "music/morning_calm.wav",
	"evening_tension":  "music/evening_tension.wav",
	"night_suspense":   "music/night_suspense.wav",
	# Legacy / menu music.
	"main_theme":       "music/main_theme.wav",
	# Day/night ambient layer.
	"ambient_day":      "music/ambient_day.wav",
	"ambient_night":    "music/ambient_night.wav",
	# Location-specific ambient (shown while a building interior is open).
	"ambient_tavern":   "music/ambient_tavern.wav",
	"ambient_chapel":   "music/ambient_chapel.wav",
	"ambient_market":   "music/ambient_market.wav",
	"ambient_manor":    "music/ambient_manor.wav",
}

const SFX_FILES: Dictionary = {
	"recon_observe":      "sfx/recon_observe.wav",
	"recon_eavesdrop":    "sfx/recon_eavesdrop.wav",
	"rumor_spread":       "sfx/rumor_spread.wav",
	"rumor_fail":         "sfx/rumor_fail.wav",
	"journal_open":       "sfx/journal_open.wav",
	"journal_close":      "sfx/journal_close.wav",
	"rumor_panel_open":   "sfx/rumor_panel_open.wav",
	"rumor_panel_close":  "sfx/rumor_panel_close.wav",
	"whisper":            "sfx/whisper.wav",
	"win":                "sfx/win.wav",
	"fail":               "sfx/fail.wav",
	"ui_click":           "sfx/ui_click.wav",
	"new_day":            "sfx/new_day.wav",
	"reputation_up":      "sfx/reputation_up.wav",
	"reputation_down":    "sfx/reputation_down.wav",
	"bribe_coin":         "sfx/bribe_coin.wav",
	"milestone_chime":    "sfx/rumor_success.wav",
	"heat_warning":       "sfx/heat_warning.wav",
	"rumor_success":      "sfx/rumor_success.wav",
	"reputation_shift":   "sfx/reputation_shift.wav",
	"victory_chime":      "sfx/victory_chime.wav",
	"failure_bell":       "sfx/failure_bell.wav",
	"event_sting":        "sfx/event_sting.wav",
}

# ── State ──────────────────────────────────────────────────────────────────────

## Currently playing music track name.
var _current_music: String = ""

## Current day phase ("morning" / "evening" / "night").
## Set to "" before connect_to_day_night so the first tick always triggers a transition.
var _current_phase: String = ""

## True if ambient is currently in "day" mode.
var _ambient_is_day: bool = true

## Ticks per in-game day; set from DayNightCycle via connect_to_day_night().
var _ticks_per_day: int = 24

## Non-empty when a location interior is open and overrides the ambient layer.
var _location_ambient: String = ""

## SPA-786: Late-game tension shift — dB bias applied to morning/evening music.
var _late_game_active: bool = false
const LATE_GAME_MORNING_BIAS := -2.0   # morning_calm gets quieter
const LATE_GAME_EVENING_BIAS :=  2.0   # evening_tension gets louder

## SPA-917: Dialogue ducking — music and ambient lowered while NPC panel is open.
var _dialogue_duck_active: bool = false
const DIALOGUE_DUCK_DB   := -10.0   # dB reduction while ducked
const DIALOGUE_DUCK_TIME :=  0.2    # seconds to duck down
const DIALOGUE_DUCK_RESTORE_TIME := 0.5  # seconds to restore
var _dialogue_duck_tween: Tween = null

## SPA-917: Heat tension ambient — ambient ducked slightly when heat warning fires.
var _heat_tension_active: bool = false
const HEAT_TENSION_AMBIENT_BIAS := -3.0  # ambient dB reduction when heat is high
var _heat_tension_tween: Tween = null

## Preloaded stream cache: name → AudioStream (or null if file absent).
var _music_cache: Dictionary = {}
var _sfx_cache:   Dictionary = {}

## Currently active volume levels (dB), kept in sync with set_*_volume_db calls.
var _music_volume_db:   float = DEFAULT_MUSIC_DB
var _ambient_volume_db: float = DEFAULT_AMBIENT_DB

# ── Node refs (created in _ready) ─────────────────────────────────────────────
var _music_player_a:   AudioStreamPlayer = null   # Crossfade slot A
var _music_player_b:   AudioStreamPlayer = null   # Crossfade slot B
var _ambient_player_a: AudioStreamPlayer = null
var _ambient_player_b: AudioStreamPlayer = null
var _sfx_player:       AudioStreamPlayer = null   # Polyphonic SFX

## Which music player is currently "active" (A=true, B=false).
var _music_active_a: bool = true
## Which ambient player is currently "active".
var _ambient_active_a: bool = true

# ── Tween refs for crossfade ───────────────────────────────────────────────────
var _music_tween:   Tween = null
var _ambient_tween: Tween = null


# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_players()
	_preload_all()
	play_music("main_theme")


func _build_players() -> void:
	# Music crossfade pair.
	_music_player_a = _make_player("MusicA", DEFAULT_MUSIC_DB, true)
	_music_player_b = _make_player("MusicB", DEFAULT_MUSIC_DB, false)
	# Ambient crossfade pair.
	_ambient_player_a = _make_player("AmbientA", DEFAULT_AMBIENT_DB, true)
	_ambient_player_b = _make_player("AmbientB", DEFAULT_AMBIENT_DB, false)
	# Polyphonic SFX player.
	_sfx_player = _make_player("SFX", DEFAULT_SFX_DB, false)
	var poly_stream := AudioStreamPolyphonic.new()
	poly_stream.polyphony = SFX_POOL_SIZE
	_sfx_player.stream = poly_stream
	_sfx_player.play()


func _make_player(node_name: String, volume_db: float, autoplay: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name     = node_name
	p.volume_db = volume_db
	p.autoplay  = autoplay
	add_child(p)
	return p


# ── Preloading ─────────────────────────────────────────────────────────────────

func _preload_all() -> void:
	for key: String in MUSIC_FILES:
		var stream := _load_stream(MUSIC_FILES[key])
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_music_cache[key] = stream
	for key: String in SFX_FILES:
		_sfx_cache[key] = _load_stream(SFX_FILES[key])


func _load_stream(relative_path: String) -> AudioStream:
	var full_path: String = AUDIO_BASE + "/" + relative_path
	if not ResourceLoader.exists(full_path):
		return null
	return load(full_path) as AudioStream


# ── Public API — Music ─────────────────────────────────────────────────────────

## Play a named music track with an optional crossfade.
## name: key from MUSIC_FILES. If already playing, no-op.
func play_music(track_name: String, crossfade: bool = false) -> void:
	if track_name == _current_music:
		return
	var stream: AudioStream = _music_cache.get(track_name, null)
	if stream == null:
		if OS.is_debug_build():
			push_warning("AudioManager: play_music('%s') — no stream in cache (asset missing?)" % track_name)
		return
	_current_music = track_name

	var next_player  := _music_player_b if _music_active_a else _music_player_a
	var prev_player  := _music_player_a if _music_active_a else _music_player_b
	_music_active_a  = not _music_active_a

	next_player.stream = stream
	if stream != null:
		next_player.volume_db = _music_volume_db if not crossfade else -80.0
		next_player.play()
	else:
		next_player.stop()

	if crossfade and stream != null:
		if _music_tween != null:
			_music_tween.kill()
		_music_tween = create_tween()
		_music_tween.set_parallel(true)
		_music_tween.tween_property(next_player, "volume_db", _music_volume_db, CROSSFADE_TIME)
		_music_tween.tween_property(prev_player, "volume_db", -80.0,            CROSSFADE_TIME)
		_music_tween.chain().tween_callback(prev_player.stop)
	else:
		prev_player.stop()


## Stop all music, optionally with a short fade-out.
func stop_music(fade_time: float = 0.0) -> void:
	if fade_time > 0.0:
		if _music_tween != null:
			_music_tween.kill()
		_music_tween = create_tween()
		_music_tween.set_parallel(true)
		_music_tween.tween_property(_music_player_a, "volume_db", -80.0, fade_time)
		_music_tween.tween_property(_music_player_b, "volume_db", -80.0, fade_time)
		_music_tween.chain().tween_callback(_stop_music_players)
	else:
		_stop_music_players()


func _stop_music_players() -> void:
	_music_player_a.stop()
	_music_player_b.stop()
	_current_music = ""


# ── Public API — Ambient ───────────────────────────────────────────────────────

## Crossfade ambient layer to day or night track.
## Skipped when a location ambient is currently active.
func set_ambient(is_day: bool) -> void:
	if is_day == _ambient_is_day:
		return
	_ambient_is_day = is_day
	if not _location_ambient.is_empty():
		# Location ambient overrides — remember the day/night state but don't switch.
		return
	var track_name: String = "ambient_day" if is_day else "ambient_night"
	_crossfade_ambient(track_name)


## Switch the ambient layer to a location-specific loop while an interior is open.
## location_id: one of "tavern", "chapel", "market", "manor".
func set_location_ambient(location_id: String) -> void:
	var track_map: Dictionary = {
		"tavern": "ambient_tavern",
		"chapel": "ambient_chapel",
		"market": "ambient_market",
		"manor":  "ambient_manor",
	}
	var track: String = track_map.get(location_id, "")
	if track.is_empty():
		return
	_location_ambient = location_id
	_crossfade_ambient(track)


## Restore ambient to the current day/night track after closing a location interior.
func clear_location_ambient() -> void:
	if _location_ambient.is_empty():
		return
	_location_ambient = ""
	var track: String = "ambient_day" if _ambient_is_day else "ambient_night"
	_crossfade_ambient(track)


## Internal: crossfade the ambient layer to the given named track.
func _crossfade_ambient(track_name: String) -> void:
	var stream: AudioStream = _music_cache.get(track_name, null)

	var next_player  := _ambient_player_b if _ambient_active_a else _ambient_player_a
	var prev_player  := _ambient_player_a if _ambient_active_a else _ambient_player_b
	_ambient_active_a = not _ambient_active_a

	next_player.stream = stream
	if stream != null:
		next_player.volume_db = -80.0
		next_player.play()
		if _ambient_tween != null:
			_ambient_tween.kill()
		_ambient_tween = create_tween()
		_ambient_tween.set_parallel(true)
		_ambient_tween.tween_property(next_player, "volume_db", _ambient_volume_db, CROSSFADE_TIME)
		_ambient_tween.tween_property(prev_player, "volume_db", -80.0,              CROSSFADE_TIME)
		_ambient_tween.chain().tween_callback(prev_player.stop)
	else:
		prev_player.stop()


# ── Public API — SFX ──────────────────────────────────────────────────────────

## Play a named sound effect. Silently skips if stream is absent.
func play_sfx(sfx_name: String) -> void:
	var stream: AudioStream = _sfx_cache.get(sfx_name, null)
	if stream == null:
		if OS.is_debug_build():
			push_warning("AudioManager: play_sfx('%s') — no stream in cache (asset missing?)" % sfx_name)
		return
	if _sfx_player == null:
		return
	var pb := _sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if pb == null:
		if OS.is_debug_build():
			push_warning("AudioManager: play_sfx('%s') — playback unavailable (player not ready or wrong stream type)" % sfx_name)
		return
	pb.play_stream(stream)


## Play a named SFX at a custom pitch scale. Useful for hover variants of click sounds.
func play_sfx_pitched(sfx_name: String, pitch_scale: float) -> void:
	var stream: AudioStream = _sfx_cache.get(sfx_name, null)
	if stream == null:
		if OS.is_debug_build():
			push_warning("AudioManager: play_sfx_pitched('%s') — no stream in cache (asset missing?)" % sfx_name)
		return
	if _sfx_player == null:
		return
	var pb := _sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if pb == null:
		if OS.is_debug_build():
			push_warning("AudioManager: play_sfx_pitched('%s') — playback unavailable (player not ready or wrong stream type)" % sfx_name)
		return
	pb.play_stream(stream, 0, 0.0, pitch_scale)


# ── Public API — Named event helpers (SPA-1411) ──────────────────────────────

## UI-feedback SFX names. Maps short name → SFX_FILES key.
const UI_SOUNDS: Dictionary = {
	"click":      "ui_click",
	"panel_open": "rumor_panel_open",
	"panel_close":"rumor_panel_close",
	"error":      "rumor_fail",
}

## Gameplay-event SFX names. Maps event name → SFX_FILES key.
const EVENT_SOUNDS: Dictionary = {
	"rumor_seeded":      "rumor_spread",
	"evidence_acquired": "journal_open",
	"npc_state_change":  "reputation_shift",
	"objective_progress":"milestone_chime",
}

## Play a UI feedback sound by short name (click, panel_open, panel_close, error).
## Falls back to play_sfx(name) if name is not in UI_SOUNDS, allowing direct SFX
## keys to work as well.
func play_ui(ui_name: String) -> void:
	var sfx_key: String = UI_SOUNDS.get(ui_name, ui_name)
	play_sfx(sfx_key)


## Play a gameplay event sound by event name (rumor_seeded, evidence_acquired,
## npc_state_change, objective_progress). Falls back to play_sfx(name) for
## unmapped names.
func play_event(event_name: String) -> void:
	var sfx_key: String = EVENT_SOUNDS.get(event_name, event_name)
	play_sfx(sfx_key)


## Convenience alias for set_location_ambient(). Crossfades ambient to a
## scene/location-specific loop.
func play_ambient(scene_id: String) -> void:
	set_location_ambient(scene_id)


# ── Public API — Volume control ────────────────────────────────────────────────

func set_music_volume_db(db: float) -> void:
	_music_volume_db = db
	# If a crossfade tween is running, kill it first to avoid conflicting targets.
	if _music_tween != null and _music_tween.is_running():
		_music_tween.kill()
		_music_tween = null
		# Snap the currently active player to the new volume and stop the fading one.
		var active   := _music_player_a if _music_active_a else _music_player_b
		var inactive := _music_player_b if _music_active_a else _music_player_a
		active.volume_db = db
		inactive.stop()
	else:
		_music_player_a.volume_db = db
		_music_player_b.volume_db = db

func set_ambient_volume_db(db: float) -> void:
	_ambient_volume_db = db
	# Same crossfade-safe pattern as set_music_volume_db.
	if _ambient_tween != null and _ambient_tween.is_running():
		_ambient_tween.kill()
		_ambient_tween = null
		var active   := _ambient_player_a if _ambient_active_a else _ambient_player_b
		var inactive := _ambient_player_b if _ambient_active_a else _ambient_player_a
		active.volume_db = db
		inactive.stop()
	else:
		_ambient_player_a.volume_db = db
		_ambient_player_b.volume_db = db

func set_sfx_volume_db(db: float) -> void:
	if _sfx_player == null:
		return
	_sfx_player.volume_db = db

func set_master_volume_db(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)


# ── Game-event hooks (called by main.gd) ──────────────────────────────────────

## Call once after the scene tree is ready, passing the DayNightCycle node.
## Hooks ambient crossfade, new_day SFX, and phase-music transitions to the cycle.
func connect_to_day_night(day_night: Node) -> void:
	if day_night == null:
		return
	if day_night.has_signal("game_tick"):
		day_night.game_tick.connect(_on_game_tick)
	if day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_day_changed)
	# Cache ticks_per_day for use in _on_game_tick.
	if "ticks_per_day" in day_night:
		_ticks_per_day = day_night.ticks_per_day
	# Determine initial ambient and music state from current tick.
	var initial_hour: int = day_night.current_tick % _ticks_per_day
	_ambient_is_day = (initial_hour >= DAY_START_HOUR and initial_hour < DAY_END_HOUR)
	var initial_track := "ambient_day" if _ambient_is_day else "ambient_night"
	var stream: AudioStream = _music_cache.get(initial_track, null)
	var ap := _ambient_player_a
	ap.stream = stream
	if stream != null:
		ap.volume_db = _ambient_volume_db
		ap.play()
	# Kick off phase music immediately.
	_current_phase = ""
	_apply_phase_music(initial_hour)


## Called when the player successfully seeds a rumor.
func on_rumor_seeded(_rumor_id: String, _subject: String, _claim: String, _target: String) -> void:
	play_sfx("rumor_spread")


## Called by recon_ctrl.action_performed signal relay in main.gd.
func on_recon_action(message: String, success: bool) -> void:
	if not success:
		return
	if message.begins_with("Observed"):
		play_sfx("recon_observe")
	elif message.begins_with("Eavesdropped"):
		play_sfx("recon_eavesdrop")


## Called when the player successfully bribes an NPC.
func on_bribe_executed(_npc_name: String, _tick: int) -> void:
	play_sfx("bribe_coin")


## Called when any NPC's heat first crosses the warning threshold (SPA-888).
## Pitched down for an ominous tension cue.
func on_heat_warning() -> void:
	play_sfx_pitched("heat_warning", 0.85)


## Called when win condition is reached.
## Fades out current music, then plays the win stinger.
func on_win() -> void:
	stop_music(STINGER_FADE_TIME)
	get_tree().create_timer(STINGER_FADE_TIME).timeout.connect(
		func() -> void: play_sfx("win"), CONNECT_ONE_SHOT)


## Called when fail condition is reached.
## Fades out current music, then plays the fail stinger.
func on_fail() -> void:
	stop_music(STINGER_FADE_TIME)
	get_tree().create_timer(STINGER_FADE_TIME).timeout.connect(
		func() -> void: play_sfx("fail"), CONNECT_ONE_SHOT)


# ── DayNightCycle signal handlers ─────────────────────────────────────────────

func _on_game_tick(tick: int) -> void:
	var hour: int = tick % _ticks_per_day
	# Ambient day/night crossfade.
	var should_be_day: bool = (hour >= DAY_START_HOUR and hour < DAY_END_HOUR)
	if should_be_day != _ambient_is_day:
		set_ambient(should_be_day)
	# Music phase transition.
	_apply_phase_music(hour)


func _apply_phase_music(hour: int) -> void:
	var new_phase: String
	if hour >= MORNING_START and hour < EVENING_START:
		new_phase = "morning"
	elif hour >= EVENING_START and hour < NIGHT_START:
		new_phase = "evening"
	else:
		new_phase = "night"
	if new_phase == _current_phase:
		return
	_current_phase = new_phase
	var phase_tracks: Dictionary = {
		"morning": "morning_calm",
		"evening": "evening_tension",
		"night":   "night_suspense",
	}
	play_music(phase_tracks[new_phase], true)
	# SPA-786: Apply late-game volume bias after crossfade starts.
	_apply_phase_volume_bias()


## SPA-786: Adjust the active music player volume based on late-game tension bias.
func _apply_phase_volume_bias() -> void:
	if not _late_game_active:
		return
	var bias: float = 0.0
	match _current_music:
		"morning_calm":    bias = LATE_GAME_MORNING_BIAS
		"evening_tension": bias = LATE_GAME_EVENING_BIAS
		_: return
	var active_player := _music_player_a if _music_active_a else _music_player_b
	# Gently tween to the biased volume so it doesn't pop.
	var target_db: float = _music_volume_db + bias
	var tw := create_tween()
	tw.tween_property(active_player, "volume_db", target_db, 1.0)


func _on_day_changed(_day: int) -> void:
	play_sfx("new_day")


## Called when the player's rumor seed attempt is rejected (no tokens, bad target, etc.).
func on_rumor_fail() -> void:
	play_sfx("rumor_fail")


## Called when a rumor succeeds in convincing an NPC (BELIEVE / SPREAD / ACT transition).
func on_rumor_success() -> void:
	play_sfx("rumor_success")


## Called when an NPC reaches the socially-dead threshold (reputation collapse).
func on_socially_dead(_npc_id: String, _npc_name: String, _tick: int) -> void:
	play_sfx("reputation_down")


## SPA-917: Duck music and ambient when an NPC dialogue panel opens.
## Safe to call multiple times — no-op if already ducked.
func duck_for_dialogue() -> void:
	if _dialogue_duck_active:
		return
	_dialogue_duck_active = true
	if _dialogue_duck_tween != null and _dialogue_duck_tween.is_valid():
		_dialogue_duck_tween.kill()
	var target_music   := _music_volume_db   + DIALOGUE_DUCK_DB
	var target_ambient := _ambient_volume_db + DIALOGUE_DUCK_DB
	_dialogue_duck_tween = create_tween().set_parallel(true)
	_dialogue_duck_tween.tween_method(
		func(v: float) -> void:
			var active_music := _music_player_a if _music_active_a else _music_player_b
			active_music.volume_db = v,
		_music_volume_db, target_music, DIALOGUE_DUCK_TIME
	)
	_dialogue_duck_tween.tween_method(
		func(v: float) -> void:
			var active_amb := _ambient_player_a if _ambient_active_a else _ambient_player_b
			active_amb.volume_db = v,
		_ambient_volume_db, target_ambient, DIALOGUE_DUCK_TIME
	)


## SPA-917: Restore music and ambient to normal levels after NPC dialogue closes.
## Safe to call if not currently ducked — no-op.
func restore_from_dialogue() -> void:
	if not _dialogue_duck_active:
		return
	_dialogue_duck_active = false
	if _dialogue_duck_tween != null and _dialogue_duck_tween.is_valid():
		_dialogue_duck_tween.kill()
	var target_music   := _music_volume_db
	var target_ambient := _ambient_volume_db
	# When heat tension is active, the ambient target is biased lower.
	if _heat_tension_active:
		target_ambient += HEAT_TENSION_AMBIENT_BIAS
	_dialogue_duck_tween = create_tween().set_parallel(true)
	_dialogue_duck_tween.tween_method(
		func(v: float) -> void:
			var active_music := _music_player_a if _music_active_a else _music_player_b
			active_music.volume_db = v,
		target_music + DIALOGUE_DUCK_DB, target_music, DIALOGUE_DUCK_RESTORE_TIME
	)
	_dialogue_duck_tween.tween_method(
		func(v: float) -> void:
			var active_amb := _ambient_player_a if _ambient_active_a else _ambient_player_b
			active_amb.volume_db = v,
		target_ambient + DIALOGUE_DUCK_DB, target_ambient, DIALOGUE_DUCK_RESTORE_TIME
	)


## SPA-917: Apply a heat-tension dB bias to the ambient layer when heat is high.
## active=true lowers ambient by HEAT_TENSION_AMBIENT_BIAS dB (making music more prominent).
## active=false restores to the normal ambient volume.
func set_heat_ambient_tension(active: bool) -> void:
	if active == _heat_tension_active:
		return
	_heat_tension_active = active
	# Skip adjustment if dialogue is currently ducking ambient.
	if _heat_tension_tween != null and _heat_tension_tween.is_valid():
		_heat_tension_tween.kill()
	var target_db: float = _ambient_volume_db + (HEAT_TENSION_AMBIENT_BIAS if active else 0.0)
	_heat_tension_tween = create_tween().set_parallel(true)
	_heat_tension_tween.tween_property(_ambient_player_a, "volume_db", target_db, 2.0)
	_heat_tension_tween.tween_property(_ambient_player_b, "volume_db", target_db, 2.0)


## SPA-786: Enable late-game tension audio shift (called from main.gd on day change).
## After 75% days used: morning_calm -2dB, evening_tension +2dB.
func set_late_game_tension(enabled: bool) -> void:
	if enabled == _late_game_active:
		return
	_late_game_active = enabled
	# Re-apply volume bias to the currently playing music if it's a phase track.
	_apply_phase_volume_bias()
