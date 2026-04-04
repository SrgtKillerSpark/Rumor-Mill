extends Node

## audio_manager.gd — Sprint 7: centralised audio singleton (autoload).
##
## Manages three audio layers:
##   1. Music      — main_theme (looping), crossfades with ambient tracks.
##   2. Ambient    — ambient_day / ambient_night crossfade on DayNightCycle ticks.
##   3. SFX        — polyphonic pool, one-shot sound effects.
##
## Audio files are loaded from res://assets/audio/.
## Missing files are silently skipped — the game runs without audio assets.
##
## Usage (from any script):
##   AudioManager.play_sfx("recon_observe")
##   AudioManager.play_music("main_theme")
##   AudioManager.set_sfx_volume_db(-6.0)
##
## Called by main.gd:
##   AudioManager.connect_to_day_night(day_night_node)
##   AudioManager.on_rumor_seeded(...)
##   AudioManager.on_recon_action(message, success)
##   AudioManager.on_win()
##   AudioManager.on_fail()

# ── Constants ──────────────────────────────────────────────────────────────────

## Base path for all audio assets.
const AUDIO_BASE := "res://assets/audio"

## Hour range considered "daytime" (inclusive) for ambient crossfade.
const DAY_START_HOUR  := 6
const DAY_END_HOUR    := 20

## Crossfade duration in seconds.
const CROSSFADE_TIME  := 2.0

## Default volumes (dB).
const DEFAULT_MUSIC_DB := -12.0
const DEFAULT_AMBIENT_DB := -18.0
const DEFAULT_SFX_DB   := 0.0

## Maximum simultaneous SFX voices in the polyphonic pool.
const SFX_POOL_SIZE := 8

# ── Audio file map ─────────────────────────────────────────────────────────────
## Maps logical name → relative path under AUDIO_BASE.
## Artists/designers place .ogg or .wav files at these paths.
## Sprint 7: using .wav placeholders so audio works without a production encoder.
## Swap to .ogg when final royalty-free tracks are ready (replace files + update here).
const MUSIC_FILES: Dictionary = {
	"main_theme":    "music/main_theme.wav",
	"ambient_day":   "music/ambient_day.wav",
	"ambient_night": "music/ambient_night.wav",
}

const SFX_FILES: Dictionary = {
	"recon_observe":      "sfx/recon_observe.wav",
	"recon_eavesdrop":    "sfx/recon_eavesdrop.wav",
	"rumor_spread":       "sfx/rumor_spread.wav",
	"journal_open":       "sfx/journal_open.wav",
	"journal_close":      "sfx/journal_close.wav",
	"rumor_panel_open":   "sfx/rumor_panel_open.wav",
	"rumor_panel_close":  "sfx/rumor_panel_close.wav",
	"whisper":            "sfx/whisper.wav",
	"win":                "sfx/win.wav",
	"fail":               "sfx/fail.wav",
	"ui_click":           "sfx/ui_click.wav",
	"new_day":            "sfx/new_day.wav",
}

# ── State ──────────────────────────────────────────────────────────────────────

## Currently playing music track name.
var _current_music: String = ""

## True if ambient is currently in "day" mode.
var _ambient_is_day: bool = true

## Preloaded stream cache: name → AudioStream (or null if file absent).
var _music_cache: Dictionary = {}
var _sfx_cache:   Dictionary = {}

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
	_current_music = track_name

	var next_player  := _music_player_b if _music_active_a else _music_player_a
	var prev_player  := _music_player_a if _music_active_a else _music_player_b
	_music_active_a  = not _music_active_a

	next_player.stream = stream
	if stream != null:
		next_player.volume_db = DEFAULT_MUSIC_DB if not crossfade else -80.0
		next_player.play()
	else:
		next_player.stop()

	if crossfade and stream != null:
		if _music_tween != null:
			_music_tween.kill()
		_music_tween = create_tween()
		_music_tween.set_parallel(true)
		_music_tween.tween_property(next_player, "volume_db", DEFAULT_MUSIC_DB, CROSSFADE_TIME)
		_music_tween.tween_property(prev_player, "volume_db", -80.0,            CROSSFADE_TIME)
		_music_tween.chain().tween_callback(prev_player.stop)
	else:
		prev_player.stop()


## Stop all music.
func stop_music() -> void:
	_music_player_a.stop()
	_music_player_b.stop()
	_current_music = ""


# ── Public API — Ambient ───────────────────────────────────────────────────────

## Crossfade ambient layer to day or night track.
func set_ambient(is_day: bool) -> void:
	if is_day == _ambient_is_day:
		return
	_ambient_is_day = is_day

	var track_name: String = "ambient_day" if is_day else "ambient_night"
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
		_ambient_tween.tween_property(next_player, "volume_db", DEFAULT_AMBIENT_DB, CROSSFADE_TIME)
		_ambient_tween.tween_property(prev_player, "volume_db", -80.0,              CROSSFADE_TIME)
		_ambient_tween.chain().tween_callback(prev_player.stop)
	else:
		prev_player.stop()


# ── Public API — SFX ──────────────────────────────────────────────────────────

## Play a named sound effect. Silently skips if stream is absent.
func play_sfx(sfx_name: String) -> void:
	var stream: AudioStream = _sfx_cache.get(sfx_name, null)
	if stream == null:
		return
	var pb := _sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if pb != null:
		pb.play_stream(stream)


## Play a named SFX at a custom pitch scale. Useful for hover variants of click sounds.
func play_sfx_pitched(sfx_name: String, pitch_scale: float) -> void:
	var stream: AudioStream = _sfx_cache.get(sfx_name, null)
	if stream == null:
		return
	var pb := _sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if pb != null:
		pb.play_stream(stream, 0, 0.0, pitch_scale)


# ── Public API — Volume control ────────────────────────────────────────────────

func set_music_volume_db(db: float) -> void:
	_music_player_a.volume_db = db
	_music_player_b.volume_db = db

func set_ambient_volume_db(db: float) -> void:
	_ambient_player_a.volume_db = db
	_ambient_player_b.volume_db = db

func set_sfx_volume_db(db: float) -> void:
	_sfx_player.volume_db = db


# ── Game-event hooks (called by main.gd) ──────────────────────────────────────

## Call once after the scene tree is ready, passing the DayNightCycle node.
## Hooks ambient crossfade and new_day SFX to the cycle's signals.
func connect_to_day_night(day_night: Node) -> void:
	if day_night == null:
		return
	if day_night.has_signal("game_tick"):
		day_night.game_tick.connect(_on_game_tick)
	if day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_day_changed)
	# Determine initial ambient state from current tick.
	var initial_hour: int = day_night.current_tick % day_night.ticks_per_day
	_ambient_is_day = (initial_hour >= DAY_START_HOUR and initial_hour < DAY_END_HOUR)
	var initial_track := "ambient_day" if _ambient_is_day else "ambient_night"
	var stream: AudioStream = _music_cache.get(initial_track, null)
	var ap := _ambient_player_a
	ap.stream = stream
	if stream != null:
		ap.volume_db = DEFAULT_AMBIENT_DB
		ap.play()


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


## Called when win condition is reached.
func on_win() -> void:
	play_sfx("win")
	stop_music()


## Called when fail condition is reached.
func on_fail() -> void:
	play_sfx("fail")
	stop_music()


# ── DayNightCycle signal handlers ─────────────────────────────────────────────

func _on_game_tick(tick: int) -> void:
	var hour: int = tick % 24   # ticks_per_day assumed 24; safe fallback
	var should_be_day: bool = (hour >= DAY_START_HOUR and hour < DAY_END_HOUR)
	if should_be_day != _ambient_is_day:
		set_ambient(should_be_day)


func _on_day_changed(_day: int) -> void:
	play_sfx("new_day")
