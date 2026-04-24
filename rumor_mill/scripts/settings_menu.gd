extends CanvasLayer

## settings_menu.gd — In-game settings overlay (layer 51, above pause menu).
## Accessible from the pause menu Settings button.
## Esc closes it; does NOT unpause the game tree.
## All nodes use PROCESS_MODE_ALWAYS so input is received while paused.

signal closed

# ── Palette (matches pause_menu.gd / how_to_play.gd) ─────────────────────────
const C_OVERLAY    := Color(0.0,  0.0,  0.0,  0.55)
const C_PANEL_BG   := Color(0.12, 0.08, 0.05, 1.0)
const C_BORDER     := Color(0.65, 0.55, 0.35, 1.0)
const C_TITLE      := Color(0.92, 0.78, 0.12, 1.0)
const C_LABEL      := Color(0.80, 0.75, 0.60, 1.0)
const C_VALUE      := Color(0.95, 0.91, 0.80, 1.0)
const C_BTN_NORMAL := Color(0.30, 0.18, 0.07, 1.0)
const C_BTN_HOVER  := Color(0.50, 0.30, 0.10, 1.0)
const C_BTN_BORDER := Color(0.55, 0.38, 0.18, 1.0)

var _btn_resolution:   Button = null
var _btn_window_mode:  Button = null
var _btn_ui_scale:     Button = null
var _btn_window_scale: Button = null
var _btn_text_size:    Button = null
var _btn_game_speed:   Button = null
var _slider_master:    HSlider = null
var _slider_music:     HSlider = null
var _slider_ambient:   HSlider = null
var _slider_sfx:       HSlider = null
var _lbl_master_val:   Label = null
var _lbl_music_val:    Label = null
var _lbl_ambient_val:  Label = null
var _lbl_sfx_val:      Label = null
var _btn_controls:     Button = null


func _ready() -> void:
	layer        = 51
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()


func open() -> void:
	_sync_from_settings()
	visible = true
	if _btn_resolution != null:
		_btn_resolution.call_deferred("grab_focus")


func _close() -> void:
	visible = false
	closed.emit()


# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen dim overlay.
	var overlay := ColorRect.new()
	overlay.color = C_OVERLAY
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	# Centred panel 420 x 650 (expanded to fit Gameplay section).
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(420, 650)
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,  -210)
	panel.set_offset(SIDE_RIGHT,  210)
	panel.set_offset(SIDE_TOP,   -325)
	panel.set_offset(SIDE_BOTTOM, 325)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Margin inside panel.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	margin.add_child(vbox)

	# Title.
	var title := Label.new()
	title.text                 = "— SETTINGS —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title)

	# ── Display section ───────────────────────────────────────────────────────
	vbox.add_child(_make_section_label("Display"))
	vbox.add_child(_make_separator())

	# Resolution row.
	var res_row := _make_setting_row("Resolution")
	_btn_resolution = _make_cycle_button(SettingsManager.get_resolution_label())
	_btn_resolution.pressed.connect(_on_resolution_cycle)
	res_row.add_child(_btn_resolution)
	vbox.add_child(res_row)

	# Window mode row.
	var wm_row := _make_setting_row("Window  (F11 / Alt+Enter)")
	_btn_window_mode = _make_cycle_button(SettingsManager.get_window_mode_label())
	_btn_window_mode.pressed.connect(_on_window_mode_cycle)
	wm_row.add_child(_btn_window_mode)
	vbox.add_child(wm_row)

	# Window scale row.
	var ws_row := _make_setting_row("Window Scale")
	_btn_window_scale = _make_cycle_button(SettingsManager.get_window_scale_label())
	_btn_window_scale.pressed.connect(_on_window_scale_cycle)
	ws_row.add_child(_btn_window_scale)
	vbox.add_child(ws_row)

	# UI scale row.
	var scale_row := _make_setting_row("UI Scale")
	_btn_ui_scale = _make_cycle_button(SettingsManager.get_ui_scale_label())
	_btn_ui_scale.pressed.connect(_on_ui_scale_cycle)
	scale_row.add_child(_btn_ui_scale)
	vbox.add_child(scale_row)

	# ── Audio section ────────────────────────��────────────────────────────────
	vbox.add_child(_make_section_label("Audio"))
	vbox.add_child(_make_separator())

	# Master volume.
	var master_row := _make_setting_row("Master")
	_slider_master = _make_volume_slider()
	_lbl_master_val = _make_value_label()
	_slider_master.value_changed.connect(_on_master_changed)
	master_row.add_child(_slider_master)
	master_row.add_child(_lbl_master_val)
	vbox.add_child(master_row)

	# Music volume.
	var music_row := _make_setting_row("Music")
	_slider_music = _make_volume_slider()
	_lbl_music_val = _make_value_label()
	_slider_music.value_changed.connect(_on_music_changed)
	music_row.add_child(_slider_music)
	music_row.add_child(_lbl_music_val)
	vbox.add_child(music_row)

	# Ambient volume.
	var ambient_row := _make_setting_row("Ambient")
	_slider_ambient = _make_volume_slider()
	_lbl_ambient_val = _make_value_label()
	_slider_ambient.value_changed.connect(_on_ambient_changed)
	ambient_row.add_child(_slider_ambient)
	ambient_row.add_child(_lbl_ambient_val)
	vbox.add_child(ambient_row)

	# SFX volume.
	var sfx_row := _make_setting_row("SFX")
	_slider_sfx = _make_volume_slider()
	_lbl_sfx_val = _make_value_label()
	_slider_sfx.value_changed.connect(_on_sfx_changed)
	sfx_row.add_child(_slider_sfx)
	sfx_row.add_child(_lbl_sfx_val)
	vbox.add_child(sfx_row)

	# ── Gameplay section ──────────────────────────────────────────────────────
	vbox.add_child(_make_section_label("Gameplay"))
	vbox.add_child(_make_separator())

	# Text size row.
	var text_size_row := _make_setting_row("Text Size")
	_btn_text_size = _make_cycle_button(SettingsManager.get_text_size_label())
	_btn_text_size.pressed.connect(_on_text_size_cycle)
	text_size_row.add_child(_btn_text_size)
	vbox.add_child(text_size_row)

	# Game speed row.
	var speed_row := _make_setting_row("Game Speed")
	_btn_game_speed = _make_cycle_button(SettingsManager.get_game_speed_label())
	_btn_game_speed.pressed.connect(_on_game_speed_cycle)
	speed_row.add_child(_btn_game_speed)
	vbox.add_child(speed_row)

	# ── Controls section ──────────────────────────────────────────────────────
	vbox.add_child(_make_section_label("Controls"))
	vbox.add_child(_make_separator())

	_btn_controls = _make_action_button("Controls Reference  (F1)")
	_btn_controls.pressed.connect(_on_controls_pressed)
	vbox.add_child(_btn_controls)

	# ── Spacer + Back button ──────────────────────────────────────────────────
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_back := _make_action_button("Back  (Esc)")
	btn_back.pressed.connect(_close)
	vbox.add_child(btn_back)

	# ── Focus chain (Tab / Arrow navigation) ──────────────────────────────────
	var focus_list: Array[Control] = [
		_btn_resolution, _btn_window_mode, _btn_window_scale, _btn_ui_scale,
		_slider_master, _slider_music, _slider_ambient, _slider_sfx,
		_btn_text_size, _btn_game_speed,
		_btn_controls, btn_back,
	]
	for i in focus_list.size():
		var prev_idx: int = (i - 1 + focus_list.size()) % focus_list.size()
		var next_idx: int = (i + 1) % focus_list.size()
		focus_list[i].focus_neighbor_top    = focus_list[prev_idx].get_path()
		focus_list[i].focus_neighbor_bottom = focus_list[next_idx].get_path()
		focus_list[i].focus_next            = focus_list[next_idx].get_path()
		focus_list[i].focus_previous        = focus_list[prev_idx].get_path()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", C_TITLE)
	return lbl


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = C_BORDER
	s.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", s)
	return sep


func _make_setting_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.process_mode = Node.PROCESS_MODE_ALWAYS
	row.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(90, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_LABEL)
	lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	row.add_child(lbl)

	return row


func _make_cycle_button(initial_text: String) -> Button:
	var btn := Button.new()
	btn.text = initial_text
	btn.custom_minimum_size = Vector2(120, 28)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", C_VALUE)

	for state_name: String in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		match state_name:
			"hover":   s.bg_color = C_BTN_HOVER
			"pressed": s.bg_color = Color(0.22, 0.13, 0.05, 1.0)
			_:         s.bg_color = C_BTN_NORMAL
		s.set_border_width_all(1)
		s.border_color = C_BTN_BORDER
		s.set_content_margin_all(4)
		btn.add_theme_stylebox_override(state_name, s)

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = C_BTN_HOVER
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)
	focus_style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("focus", focus_style)

	btn.pivot_offset = btn.custom_minimum_size * 0.5
	btn.mouse_entered.connect(func() -> void:
		AudioManager.play_sfx_pitched("ui_click", 2.0)
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)
	)
	return btn


func _make_volume_slider() -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(120, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.process_mode = Node.PROCESS_MODE_ALWAYS

	# Accessibility: add a visible gold focus ring so keyboard users see which
	# slider is active (matches the button focus style elsewhere in this menu).
	var grabber_area_focus := StyleBoxFlat.new()
	grabber_area_focus.bg_color = Color(0.20, 0.14, 0.06, 1.0)
	grabber_area_focus.set_border_width_all(2)
	grabber_area_focus.border_color = Color(1.00, 0.90, 0.40, 1.0)  # gold
	grabber_area_focus.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_area_focus)

	return slider


func _make_value_label() -> Label:
	var lbl := Label.new()
	lbl.text = "0"
	lbl.custom_minimum_size = Vector2(32, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_VALUE)
	lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	return lbl


func _make_action_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240, 36)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", C_VALUE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN_NORMAL
	normal.set_border_width_all(1)
	normal.border_color = C_BTN_BORDER
	normal.set_content_margin_all(8)
	normal.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_HOVER
	hover.set_border_width_all(1)
	hover.border_color = C_BTN_BORDER
	hover.set_content_margin_all(8)
	hover.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.22, 0.13, 0.05, 1.0)
	pressed.set_border_width_all(1)
	pressed.border_color = C_BTN_BORDER
	pressed.set_content_margin_all(8)
	pressed.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("pressed", pressed)

	var focus := StyleBoxFlat.new()
	focus.bg_color = C_BTN_HOVER
	focus.set_border_width_all(2)
	focus.border_color = Color(1.00, 0.90, 0.40, 1.0)
	focus.set_content_margin_all(8)
	focus.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("focus", focus)

	btn.pivot_offset = btn.custom_minimum_size * 0.5
	btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)
	)
	btn.mouse_entered.connect(func() -> void:
		AudioManager.play_sfx_pitched("ui_click", 2.0)
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)
	)
	return btn


# ── Sync UI ← SettingsManager ────────────────────────────────────────────────

func _sync_from_settings() -> void:
	_btn_resolution.text    = SettingsManager.get_resolution_label()
	_btn_window_mode.text   = SettingsManager.get_window_mode_label()
	_btn_window_scale.text  = SettingsManager.get_window_scale_label()
	_btn_ui_scale.text      = SettingsManager.get_ui_scale_label()
	_slider_master.set_value_no_signal(SettingsManager.master_volume)
	_slider_music.set_value_no_signal(SettingsManager.music_volume)
	_slider_ambient.set_value_no_signal(SettingsManager.ambient_volume)
	_slider_sfx.set_value_no_signal(SettingsManager.sfx_volume)
	_lbl_master_val.text  = str(int(SettingsManager.master_volume))
	_lbl_music_val.text   = str(int(SettingsManager.music_volume))
	_lbl_ambient_val.text = str(int(SettingsManager.ambient_volume))
	_lbl_sfx_val.text     = str(int(SettingsManager.sfx_volume))
	_btn_text_size.text   = SettingsManager.get_text_size_label()
	_btn_game_speed.text  = SettingsManager.get_game_speed_label()


# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_resolution_cycle() -> void:
	AudioManager.play_sfx("ui_click")
	SettingsManager.resolution_index = (SettingsManager.resolution_index + 1) % SettingsManager.RESOLUTIONS.size()
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
	_btn_resolution.text = SettingsManager.get_resolution_label()
	var tw := _btn_resolution.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_resolution, "scale", Vector2(0.95, 0.95), 0.06)
	tw.tween_property(_btn_resolution, "scale", Vector2.ONE, 0.10)


func _on_window_mode_cycle() -> void:
	AudioManager.play_sfx("ui_click")
	SettingsManager.window_mode = (SettingsManager.window_mode + 1) % 3
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
	_btn_window_mode.text = SettingsManager.get_window_mode_label()
	var tw := _btn_window_mode.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_window_mode, "scale", Vector2(0.95, 0.95), 0.06)
	tw.tween_property(_btn_window_mode, "scale", Vector2.ONE, 0.10)


func _on_window_scale_cycle() -> void:
	AudioManager.play_sfx("ui_click")
	SettingsManager.window_scale_index = (SettingsManager.window_scale_index + 1) % SettingsManager.WINDOW_SCALE_PRESETS.size()
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
	_btn_window_scale.text = SettingsManager.get_window_scale_label()
	var tw := _btn_window_scale.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_window_scale, "scale", Vector2(0.95, 0.95), 0.06)
	tw.tween_property(_btn_window_scale, "scale", Vector2.ONE, 0.10)


func _on_ui_scale_cycle() -> void:
	AudioManager.play_sfx("ui_click")
	SettingsManager.ui_scale_index = (SettingsManager.ui_scale_index + 1) % SettingsManager.UI_SCALE_PRESETS.size()
	SettingsManager.ui_scale = SettingsManager.UI_SCALE_PRESETS[SettingsManager.ui_scale_index]
	SettingsManager.apply_ui_scale()
	SettingsManager.save_settings()
	_btn_ui_scale.text = SettingsManager.get_ui_scale_label()
	var tw := _btn_ui_scale.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_ui_scale, "scale", Vector2(0.95, 0.95), 0.06)
	tw.tween_property(_btn_ui_scale, "scale", Vector2.ONE, 0.10)


func _on_master_changed(value: float) -> void:
	SettingsManager.master_volume = value
	_lbl_master_val.text = str(int(value))
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()


func _on_music_changed(value: float) -> void:
	SettingsManager.music_volume = value
	_lbl_music_val.text = str(int(value))
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()


func _on_ambient_changed(value: float) -> void:
	SettingsManager.ambient_volume = value
	_lbl_ambient_val.text = str(int(value))
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()


func _on_sfx_changed(value: float) -> void:
	SettingsManager.sfx_volume = value
	_lbl_sfx_val.text = str(int(value))
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()


func _on_controls_pressed() -> void:
	var ref: Node = get_tree().root.find_child("ControlsReference", true, false)
	if ref != null and ref.has_method("toggle"):
		ref.toggle()


func _on_text_size_cycle() -> void:
	AudioManager.play_sfx("ui_click")
	SettingsManager.set_text_size_index((SettingsManager.text_size_index + 1) % SettingsManager.TEXT_SIZE_LABELS.size())
	SettingsManager.apply_ui_scale()
	SettingsManager.save_settings()
	_btn_text_size.text = SettingsManager.get_text_size_label()
	var tw := _btn_text_size.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_text_size, "scale", Vector2(0.95, 0.95), 0.06)
	tw.tween_property(_btn_text_size, "scale", Vector2.ONE, 0.10)


func _on_game_speed_cycle() -> void:
	AudioManager.play_sfx("ui_click")
	SettingsManager.game_speed_index = (SettingsManager.game_speed_index + 1) % SettingsManager.GAME_SPEED_PRESETS.size()
	SettingsManager.game_speed = SettingsManager.GAME_SPEED_PRESETS[SettingsManager.game_speed_index]
	SettingsManager.save_settings()
	_btn_game_speed.text = SettingsManager.get_game_speed_label()
	# Apply to the running SpeedHUD if the game is active.
	var speed_node: Node = get_tree().root.find_child("SpeedHUD", true, false)
	if speed_node != null and speed_node.has_method("_apply_speed_from_settings"):
		speed_node._apply_speed_from_settings()
	var tw := _btn_game_speed.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_game_speed, "scale", Vector2(0.95, 0.95), 0.06)
	tw.tween_property(_btn_game_speed, "scale", Vector2.ONE, 0.10)
