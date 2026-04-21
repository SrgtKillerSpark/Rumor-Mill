extends Node

## settings_manager.gd — Persists user preferences to user://user_settings.cfg.
## Autoloaded as SettingsManager. Applies settings to AudioManager on startup.
##
## Stored settings:
##   music_volume   — linear 0-100 (maps to AudioManager.set_music_volume_db)
##   ambient_volume — linear 0-100 (maps to AudioManager.set_ambient_volume_db)
##   sfx_volume     — linear 0-100 (maps to AudioManager.set_sfx_volume_db)
##   game_speed     — tick_duration_seconds (0.25 = fast, 1.0 = normal, 4.0 = slow)
##   window_mode    — 0=Windowed, 1=Borderless, 2=Fullscreen
##
## Usage:
##   SettingsManager.music_volume = 80.0
##   SettingsManager.save_settings()

const SAVE_PATH := "user://user_settings.cfg"
const SECTION   := "settings"

const DEFAULT_MASTER_VOL         := 100.0  ## Linear 0-100
const DEFAULT_MUSIC_VOL          := 80.0   ## Linear 0-100
const DEFAULT_AMBIENT_VOL        := 60.0
const DEFAULT_SFX_VOL            := 80.0
const DEFAULT_GAME_SPEED         := 1.0    ## tick_duration_seconds
const DEFAULT_ANALYTICS_ENABLED  := true   ## Opt-in local analytics (SPA-244)
const DEFAULT_RESOLUTION_INDEX   := 0      ## 0=720p (see RESOLUTIONS)
const DEFAULT_WINDOW_MODE        := 0      ## 0=Windowed, 1=Borderless, 2=Fullscreen
const DEFAULT_UI_SCALE           := 1.0    ## 1.0 = 100%, range 0.75–1.5

## Available UI scale presets.
const UI_SCALE_PRESETS := [0.75, 0.85, 1.0, 1.15, 1.25, 1.5]

## Text size presets (Small/Medium/Large) — each maps to a UI_SCALE_PRESETS index.
const TEXT_SIZE_LABELS := ["Small", "Medium", "Large"]
const TEXT_SIZE_SCALE_INDICES := [0, 2, 4]  ## maps to 0.75, 1.0, 1.25

## Game speed presets: tick_duration_seconds for 0.5×, 1×, 2× gameplay speed.
const GAME_SPEED_LABELS  := ["0.5×", "1×", "2×"]
const GAME_SPEED_PRESETS := [2.0, 1.0, 0.5]

## Window scale presets — multiplier of base 1280×720 viewport for windowed mode.
const WINDOW_SCALE_PRESETS := [1.0, 1.5, 2.0]

## Window mode constants.
const WINDOW_WINDOWED   := 0   ## Regular window with title bar and decorations.
const WINDOW_BORDERLESS := 1   ## Borderless fullscreen (windowed fullscreen).
const WINDOW_FULLSCREEN := 2   ## Exclusive fullscreen.

## Base resolution presets (width × height). Native is appended at runtime if unique.
const BASE_RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

## Runtime resolution list (includes native if not already a preset).
var RESOLUTIONS: Array[Vector2i] = []

var master_volume:       float = DEFAULT_MASTER_VOL
var music_volume:        float = DEFAULT_MUSIC_VOL
var ambient_volume:      float = DEFAULT_AMBIENT_VOL
var sfx_volume:          float = DEFAULT_SFX_VOL
var game_speed:          float = DEFAULT_GAME_SPEED
var analytics_enabled:   bool  = DEFAULT_ANALYTICS_ENABLED
var resolution_index:    int   = DEFAULT_RESOLUTION_INDEX
var window_mode:         int   = DEFAULT_WINDOW_MODE
var ui_scale:            float = DEFAULT_UI_SCALE
var ui_scale_index:      int   = 2   ## index into UI_SCALE_PRESETS (default 1.0)
var window_scale_index:  int   = 0   ## index into WINDOW_SCALE_PRESETS (default 1x)
var text_size_index:     int   = 1   ## index into TEXT_SIZE_LABELS (0=Small, 1=Medium, 2=Large)
var game_speed_index:    int   = 1   ## index into GAME_SPEED_PRESETS (0=0.5×, 1=1×, 2=2×)
var dismissed_tooltips:  Dictionary = {}  ## Persistent tooltip dismissal tracking (tooltip_id → true).


func _ready() -> void:
	# Enforce minimum window size so the game never drops below 720p.
	DisplayServer.window_set_min_size(Vector2i(1280, 720))
	_build_resolution_list()
	load_settings()
	apply_to_audio_manager()
	apply_display_settings()
	apply_ui_scale()


## Build the runtime RESOLUTIONS array from BASE_RESOLUTIONS + native screen size.
func _build_resolution_list() -> void:
	RESOLUTIONS.clear()
	for res in BASE_RESOLUTIONS:
		RESOLUTIONS.append(res)
	# Append the native screen resolution if it's not already a preset.
	var native := DisplayServer.screen_get_size()
	if native not in RESOLUTIONS and native.x >= 1280 and native.y >= 720:
		RESOLUTIONS.append(native)
		RESOLUTIONS.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # File absent — use defaults
	master_volume     = cfg.get_value(SECTION, "master_volume",     DEFAULT_MASTER_VOL)
	music_volume      = cfg.get_value(SECTION, "music_volume",      DEFAULT_MUSIC_VOL)
	ambient_volume    = cfg.get_value(SECTION, "ambient_volume",    DEFAULT_AMBIENT_VOL)
	sfx_volume        = cfg.get_value(SECTION, "sfx_volume",        DEFAULT_SFX_VOL)
	game_speed        = cfg.get_value(SECTION, "game_speed",        DEFAULT_GAME_SPEED)
	analytics_enabled = cfg.get_value(SECTION, "analytics_enabled", DEFAULT_ANALYTICS_ENABLED)
	resolution_index  = cfg.get_value(SECTION, "resolution_index",  DEFAULT_RESOLUTION_INDEX)
	resolution_index  = clampi(resolution_index, 0, RESOLUTIONS.size() - 1)
	# Migrate legacy bool fullscreen → window_mode.
	var _legacy_fs: bool = cfg.get_value(SECTION, "fullscreen", false)
	window_mode = cfg.get_value(SECTION, "window_mode",
		WINDOW_FULLSCREEN if _legacy_fs else DEFAULT_WINDOW_MODE)
	ui_scale_index = cfg.get_value(SECTION, "ui_scale_index", 2)
	ui_scale_index = clampi(ui_scale_index, 0, UI_SCALE_PRESETS.size() - 1)
	ui_scale = UI_SCALE_PRESETS[ui_scale_index]
	window_scale_index = cfg.get_value(SECTION, "window_scale_index", 0)
	window_scale_index = clampi(window_scale_index, 0, WINDOW_SCALE_PRESETS.size() - 1)
	text_size_index = cfg.get_value(SECTION, "text_size_index", 1)
	text_size_index = clampi(text_size_index, 0, TEXT_SIZE_LABELS.size() - 1)
	# Sync ui_scale to text_size selection if it was persisted.
	ui_scale_index = TEXT_SIZE_SCALE_INDICES[text_size_index]
	ui_scale = UI_SCALE_PRESETS[ui_scale_index]
	game_speed_index = cfg.get_value(SECTION, "game_speed_index", 1)
	game_speed_index = clampi(game_speed_index, 0, GAME_SPEED_PRESETS.size() - 1)
	game_speed = GAME_SPEED_PRESETS[game_speed_index]
	dismissed_tooltips = cfg.get_value(SECTION, "dismissed_tooltips", {})


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume",     master_volume)
	cfg.set_value(SECTION, "music_volume",      music_volume)
	cfg.set_value(SECTION, "ambient_volume",    ambient_volume)
	cfg.set_value(SECTION, "sfx_volume",        sfx_volume)
	cfg.set_value(SECTION, "game_speed",        game_speed)
	cfg.set_value(SECTION, "analytics_enabled", analytics_enabled)
	cfg.set_value(SECTION, "resolution_index",  resolution_index)
	cfg.set_value(SECTION, "window_mode",       window_mode)
	cfg.set_value(SECTION, "ui_scale_index",    ui_scale_index)
	cfg.set_value(SECTION, "window_scale_index", window_scale_index)
	cfg.set_value(SECTION, "text_size_index",   text_size_index)
	cfg.set_value(SECTION, "game_speed_index",  game_speed_index)
	cfg.set_value(SECTION, "dismissed_tooltips", dismissed_tooltips)
	cfg.save(SAVE_PATH)


## Apply current volume settings to AudioManager.
func apply_to_audio_manager() -> void:
	AudioManager.set_master_volume_db(_to_db(master_volume))
	AudioManager.set_music_volume_db(_to_db(music_volume))
	AudioManager.set_ambient_volume_db(_to_db(ambient_volume))
	AudioManager.set_sfx_volume_db(_to_db(sfx_volume))


## Apply resolution and window mode settings to the display window.
func apply_display_settings() -> void:
	var idx: int = clampi(resolution_index, 0, RESOLUTIONS.size() - 1)
	var res: Vector2i = RESOLUTIONS[idx]
	match window_mode:
		WINDOW_FULLSCREEN:
			DisplayServer.window_set_size(res)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		WINDOW_BORDERLESS:
			DisplayServer.window_set_size(res)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:  # WINDOW_WINDOWED
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# Window scale overrides resolution in windowed mode.
			var scale: float = WINDOW_SCALE_PRESETS[clampi(window_scale_index, 0, WINDOW_SCALE_PRESETS.size() - 1)]
			var target := Vector2i(int(1280.0 * scale), int(720.0 * scale))
			var screen_size := DisplayServer.screen_get_size()
			target.x = clampi(target.x, 1280, screen_size.x)
			target.y = clampi(target.y, 720, screen_size.y)
			DisplayServer.window_set_size(target)
			# Centre window on screen.
			var win_pos := Vector2i((screen_size.x - target.x) / 2, (screen_size.y - target.y) / 2)
			DisplayServer.window_set_position(win_pos)


## Apply the UI scale factor to the root viewport's content_scale_factor.
func apply_ui_scale() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.root.content_scale_factor = ui_scale


## Get the label for the current UI scale preset.
func get_ui_scale_label() -> String:
	return "%d%%" % int(ui_scale * 100.0)


## Get the label for the current resolution preset.
func get_resolution_label() -> String:
	var idx: int = clampi(resolution_index, 0, RESOLUTIONS.size() - 1)
	var res: Vector2i = RESOLUTIONS[idx]
	var label := "%dx%d" % [res.x, res.y]
	if res == DisplayServer.screen_get_size() and res not in BASE_RESOLUTIONS:
		label += " (Native)"
	return label


## Get the label for the current window scale preset.
func get_window_scale_label() -> String:
	var scale: float = WINDOW_SCALE_PRESETS[clampi(window_scale_index, 0, WINDOW_SCALE_PRESETS.size() - 1)]
	if scale == int(scale):
		return "%dx" % int(scale)
	return "%.1fx" % scale


## Get the display label for the current text size preset.
func get_text_size_label() -> String:
	return TEXT_SIZE_LABELS[clampi(text_size_index, 0, TEXT_SIZE_LABELS.size() - 1)]


## Set text size index and sync ui_scale to the mapped preset.
func set_text_size_index(idx: int) -> void:
	text_size_index = clampi(idx, 0, TEXT_SIZE_LABELS.size() - 1)
	ui_scale_index  = TEXT_SIZE_SCALE_INDICES[text_size_index]
	ui_scale        = UI_SCALE_PRESETS[ui_scale_index]


## Get the display label for the current game speed preset.
func get_game_speed_label() -> String:
	return GAME_SPEED_LABELS[clampi(game_speed_index, 0, GAME_SPEED_LABELS.size() - 1)]


## Get the display label for the current window mode.
func get_window_mode_label() -> String:
	match window_mode:
		WINDOW_BORDERLESS: return "Borderless"
		WINDOW_FULLSCREEN: return "Fullscreen"
		_: return "Windowed"


## Toggle between windowed and the current fullscreen mode via F11.
## If currently windowed, switches to borderless fullscreen.
## If currently fullscreen (any mode), switches back to windowed.
func toggle_fullscreen() -> void:
	if window_mode == WINDOW_WINDOWED:
		window_mode = WINDOW_BORDERLESS
	else:
		window_mode = WINDOW_WINDOWED
	apply_display_settings()
	save_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


## Convert linear 0-100 to dB. Returns -80 for zero (silence).
func _to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return linear_to_db(linear / 100.0)
