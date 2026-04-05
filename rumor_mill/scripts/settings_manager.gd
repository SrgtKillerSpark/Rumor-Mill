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

const DEFAULT_MUSIC_VOL          := 80.0   ## Linear 0-100
const DEFAULT_AMBIENT_VOL        := 60.0
const DEFAULT_SFX_VOL            := 80.0
const DEFAULT_GAME_SPEED         := 1.0    ## tick_duration_seconds
const DEFAULT_ANALYTICS_ENABLED  := true   ## Opt-in local analytics (SPA-244)
const DEFAULT_RESOLUTION_INDEX   := 0      ## 0=720p, 1=1080p, 2=1440p
const DEFAULT_WINDOW_MODE        := 0      ## 0=Windowed, 1=Borderless, 2=Fullscreen
const DEFAULT_UI_SCALE           := 1.0    ## 1.0 = 100%, range 0.75–1.5

## Available UI scale presets.
const UI_SCALE_PRESETS := [0.75, 0.85, 1.0, 1.15, 1.25, 1.5]

## Window mode constants.
const WINDOW_WINDOWED   := 0   ## Regular window with title bar and decorations.
const WINDOW_BORDERLESS := 1   ## Borderless fullscreen (windowed fullscreen).
const WINDOW_FULLSCREEN := 2   ## Exclusive fullscreen.

## Available resolution presets (width × height).
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var music_volume:        float = DEFAULT_MUSIC_VOL
var ambient_volume:      float = DEFAULT_AMBIENT_VOL
var sfx_volume:          float = DEFAULT_SFX_VOL
var game_speed:          float = DEFAULT_GAME_SPEED
var analytics_enabled:   bool  = DEFAULT_ANALYTICS_ENABLED
var resolution_index:    int   = DEFAULT_RESOLUTION_INDEX
var window_mode:         int   = DEFAULT_WINDOW_MODE
var ui_scale:            float = DEFAULT_UI_SCALE
var ui_scale_index:      int   = 2   ## index into UI_SCALE_PRESETS (default 1.0)


func _ready() -> void:
	load_settings()
	apply_to_audio_manager()
	apply_display_settings()
	apply_ui_scale()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # File absent — use defaults
	music_volume      = cfg.get_value(SECTION, "music_volume",      DEFAULT_MUSIC_VOL)
	ambient_volume    = cfg.get_value(SECTION, "ambient_volume",    DEFAULT_AMBIENT_VOL)
	sfx_volume        = cfg.get_value(SECTION, "sfx_volume",        DEFAULT_SFX_VOL)
	game_speed        = cfg.get_value(SECTION, "game_speed",        DEFAULT_GAME_SPEED)
	analytics_enabled = cfg.get_value(SECTION, "analytics_enabled", DEFAULT_ANALYTICS_ENABLED)
	resolution_index  = cfg.get_value(SECTION, "resolution_index",  DEFAULT_RESOLUTION_INDEX)
	# Migrate legacy bool fullscreen → window_mode.
	var _legacy_fs: bool = cfg.get_value(SECTION, "fullscreen", false)
	window_mode = cfg.get_value(SECTION, "window_mode",
		WINDOW_FULLSCREEN if _legacy_fs else DEFAULT_WINDOW_MODE)
	ui_scale_index = cfg.get_value(SECTION, "ui_scale_index", 2)
	ui_scale_index = clampi(ui_scale_index, 0, UI_SCALE_PRESETS.size() - 1)
	ui_scale = UI_SCALE_PRESETS[ui_scale_index]


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "music_volume",      music_volume)
	cfg.set_value(SECTION, "ambient_volume",    ambient_volume)
	cfg.set_value(SECTION, "sfx_volume",        sfx_volume)
	cfg.set_value(SECTION, "game_speed",        game_speed)
	cfg.set_value(SECTION, "analytics_enabled", analytics_enabled)
	cfg.set_value(SECTION, "resolution_index",  resolution_index)
	cfg.set_value(SECTION, "window_mode",       window_mode)
	cfg.set_value(SECTION, "ui_scale_index",    ui_scale_index)
	cfg.save(SAVE_PATH)


## Apply current volume settings to AudioManager.
func apply_to_audio_manager() -> void:
	AudioManager.set_music_volume_db(_to_db(music_volume))
	AudioManager.set_ambient_volume_db(_to_db(ambient_volume))
	AudioManager.set_sfx_volume_db(_to_db(sfx_volume))


## Apply resolution and window mode settings to the display window.
func apply_display_settings() -> void:
	var idx: int = clampi(resolution_index, 0, RESOLUTIONS.size() - 1)
	var res: Vector2i = RESOLUTIONS[idx]
	match window_mode:
		WINDOW_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		WINDOW_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:  # WINDOW_WINDOWED
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var screen_size := DisplayServer.screen_get_size()
			if res.x < 320 or res.y < 240 or res.x > screen_size.x or res.y > screen_size.y:
				push_warning("SettingsManager: invalid resolution %s, clamping to screen." % str(res))
				res.x = clampi(res.x, 320, screen_size.x)
				res.y = clampi(res.y, 240, screen_size.y)
			DisplayServer.window_set_size(res)
			# Centre window on screen.
			var win_pos := Vector2i((screen_size.x - res.x) / 2, (screen_size.y - res.y) / 2)
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
	return "%dx%d" % [res.x, res.y]


## Get the display label for the current window mode.
func get_window_mode_label() -> String:
	match window_mode:
		WINDOW_BORDERLESS: return "Borderless"
		WINDOW_FULLSCREEN: return "Fullscreen"
		_: return "Windowed"


## Convert linear 0-100 to dB. Returns -80 for zero (silence).
func _to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return linear_to_db(linear / 100.0)
