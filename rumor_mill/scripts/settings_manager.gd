extends Node

## settings_manager.gd — Persists user preferences to user://user_settings.cfg.
## Autoloaded as SettingsManager. Applies settings to AudioManager on startup.
##
## Stored settings:
##   music_volume   — linear 0-100 (maps to AudioManager.set_music_volume_db)
##   ambient_volume — linear 0-100 (maps to AudioManager.set_ambient_volume_db)
##   sfx_volume     — linear 0-100 (maps to AudioManager.set_sfx_volume_db)
##   game_speed     — tick_duration_seconds (0.25 = fast, 1.0 = normal, 4.0 = slow)
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

var music_volume:        float = DEFAULT_MUSIC_VOL
var ambient_volume:      float = DEFAULT_AMBIENT_VOL
var sfx_volume:          float = DEFAULT_SFX_VOL
var game_speed:          float = DEFAULT_GAME_SPEED
var analytics_enabled:   bool  = DEFAULT_ANALYTICS_ENABLED


func _ready() -> void:
	load_settings()
	apply_to_audio_manager()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # File absent — use defaults
	music_volume      = cfg.get_value(SECTION, "music_volume",      DEFAULT_MUSIC_VOL)
	ambient_volume    = cfg.get_value(SECTION, "ambient_volume",    DEFAULT_AMBIENT_VOL)
	sfx_volume        = cfg.get_value(SECTION, "sfx_volume",        DEFAULT_SFX_VOL)
	game_speed        = cfg.get_value(SECTION, "game_speed",        DEFAULT_GAME_SPEED)
	analytics_enabled = cfg.get_value(SECTION, "analytics_enabled", DEFAULT_ANALYTICS_ENABLED)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "music_volume",      music_volume)
	cfg.set_value(SECTION, "ambient_volume",    ambient_volume)
	cfg.set_value(SECTION, "sfx_volume",        sfx_volume)
	cfg.set_value(SECTION, "game_speed",        game_speed)
	cfg.set_value(SECTION, "analytics_enabled", analytics_enabled)
	cfg.save(SAVE_PATH)


## Apply current volume settings to AudioManager.
func apply_to_audio_manager() -> void:
	AudioManager.set_music_volume_db(_to_db(music_volume))
	AudioManager.set_ambient_volume_db(_to_db(ambient_volume))
	AudioManager.set_sfx_volume_db(_to_db(sfx_volume))


## Convert linear 0-100 to dB. Returns -80 for zero (silence).
func _to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return linear_to_db(linear / 100.0)
