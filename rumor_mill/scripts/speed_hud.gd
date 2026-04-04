extends CanvasLayer

## speed_hud.gd — Game speed controls: Pause / 1× Normal / 3× Fast.
## SPA-214: Tier 3, Item #10.
##
## Shown top-right during gameplay.
## Keyboard: Space = pause toggle (ignored while pause menu is open).

const C_ACTIVE := Color(0.70, 0.55, 0.20, 1.0)
const C_NORMAL := Color(0.20, 0.15, 0.08, 0.90)
const C_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_TEXT   := Color(0.95, 0.91, 0.80, 1.0)

enum Speed { PAUSE, NORMAL, FAST }
const TICK_DURATION: Dictionary = { Speed.NORMAL: 1.0, Speed.FAST: 0.333 }

var _day_night: Node  = null
var _speed:     Speed = Speed.NORMAL

var _btn_pause:  Button = null
var _btn_normal: Button = null
var _btn_fast:   Button = null


func _ready() -> void:
	layer        = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func setup(day_night: Node) -> void:
	_day_night = day_night
	_apply_speed()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Space toggles pause, but only when the pause menu is not open.
		if event.keycode == KEY_SPACE and not get_tree().paused:
			_set_speed(Speed.PAUSE if _speed != Speed.PAUSE else Speed.NORMAL)
			get_viewport().set_input_as_handled()


func _set_speed(s: Speed) -> void:
	_speed = s
	_apply_speed()


func _apply_speed() -> void:
	if _day_night == null:
		return
	if _speed == Speed.PAUSE:
		_day_night.set_paused(true)
	else:
		var dur: float = TICK_DURATION[_speed]
		_day_night.set_paused(false)
		_day_night.tick_duration_seconds = dur
		_day_night.tick_timer.wait_time   = dur
		_day_night.tick_timer.start()
	_refresh_buttons()


func _refresh_buttons() -> void:
	_style_btn(_btn_pause,  _speed == Speed.PAUSE)
	_style_btn(_btn_normal, _speed == Speed.NORMAL)
	_style_btn(_btn_fast,   _speed == Speed.FAST)


func _build_ui() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left   = -170.0
	row.offset_top    =   8.0
	row.offset_right  =  -8.0
	row.offset_bottom =  36.0
	row.add_theme_constant_override("separation", 4)
	add_child(row)

	_btn_pause  = _make_btn("  ||  ")
	_btn_normal = _make_btn("  1×  ")
	_btn_fast   = _make_btn("  3×  ")

	_btn_pause.tooltip_text  = "Pause  (Space)"
	_btn_normal.tooltip_text = "Normal Speed  (1×)"
	_btn_fast.tooltip_text   = "Fast Speed  (3×)"

	_btn_pause.pressed.connect(func() -> void:  _set_speed(Speed.PAUSE))
	_btn_normal.pressed.connect(func() -> void: _set_speed(Speed.NORMAL))
	_btn_fast.pressed.connect(func() -> void:   _set_speed(Speed.FAST))

	row.add_child(_btn_pause)
	row.add_child(_btn_normal)
	row.add_child(_btn_fast)

	# Normal is the default active speed.
	_style_btn(_btn_pause,  false)
	_style_btn(_btn_normal, true)
	_style_btn(_btn_fast,   false)


func _make_btn(label_text: String) -> Button:
	var btn := Button.new()
	btn.text                = label_text
	btn.custom_minimum_size = Vector2(48, 28)
	btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	btn.mouse_entered.connect(func() -> void: AudioManager.play_sfx_pitched("ui_click", 2.0))
	return btn


func _style_btn(btn: Button, active: bool) -> void:
	if btn == null:
		return
	var s := StyleBoxFlat.new()
	s.bg_color = C_ACTIVE if active else C_NORMAL
	s.set_border_width_all(2 if active else 1)
	s.border_color = C_BORDER
	s.set_content_margin_all(4)
	s.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   s)
	btn.add_theme_stylebox_override("pressed", s)

	var f := StyleBoxFlat.new()
	f.bg_color = C_ACTIVE if active else C_NORMAL
	f.set_border_width_all(2)
	f.border_color = Color(1.00, 0.90, 0.40, 1.0)  # gold focus ring
	f.set_content_margin_all(4)
	f.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("focus", f)
