class_name MainMenuSettingsPanel
extends Node

## main_menu_settings_panel.gd — Settings phase panel for MainMenu (SPA-1004).
##
## Extracted from main_menu.gd.  Build with build(make_button, separator) then
## add the returned `panel` Control to the parent CanvasLayer.

signal back_requested

# ── Palette ───────────────────────────────────────────────────────────────────
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_MUTED        := Color(0.60, 0.53, 0.42, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)

# ── Public panel ref ──────────────────────────────────────────────────────────
var panel: Control = null

# ── UI state ──────────────────────────────────────────────────────────────────
var _lbl_master_val:  Label  = null
var _lbl_music_val:   Label  = null
var _lbl_ambient_val: Label  = null
var _lbl_sfx_val:     Label  = null
var _lbl_speed_val:   Label  = null
var _btn_resolution:  Button = null
var _btn_window_mode: Button = null
var _btn_window_scale: Button = null
var _btn_ui_scale:    Button = null

# ── Callables injected by main_menu.gd ───────────────────────────────────────
var _make_button: Callable
var _separator:   Callable


## Build the settings panel.  `make_button` and `separator` are factory callables
## from the coordinator (main_menu.gd) so styling stays consistent.
func build(make_button: Callable, separator: Callable) -> Control:
	_make_button = make_button
	_separator   = separator

	panel = _make_panel(480, 580)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var heading := Label.new()
	heading.text = "Settings"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color(0.91, 0.85, 0.70, 1.0))
	vbox.add_child(heading)

	vbox.add_child(_separator.call())

	# Display section
	var display_lbl := Label.new()
	display_lbl.text = "Display"
	display_lbl.add_theme_font_size_override("font_size", 14)
	display_lbl.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(display_lbl)

	_btn_resolution = _build_cycle_button(vbox, "Resolution:",
		SettingsManager.get_resolution_label(), _on_resolution_cycle)

	_btn_window_mode = _build_cycle_button(vbox, "Window (F11 / Alt+Enter):",
		SettingsManager.get_window_mode_label(), _on_window_mode_cycle)

	_btn_window_scale = _build_cycle_button(vbox, "Window Scale:",
		SettingsManager.get_window_scale_label(), _on_window_scale_cycle)

	_btn_ui_scale = _build_cycle_button(vbox, "UI Scale:",
		SettingsManager.get_ui_scale_label(), _on_ui_scale_cycle)

	vbox.add_child(_separator.call())

	# Audio section
	var audio_lbl := Label.new()
	audio_lbl.text = "Audio"
	audio_lbl.add_theme_font_size_override("font_size", 14)
	audio_lbl.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(audio_lbl)

	_lbl_master_val  = _add_slider_row(vbox, "Master",   SettingsManager.master_volume,  0.0, 100.0, 1.0,    _on_master_volume_changed)
	_lbl_music_val   = _add_slider_row(vbox, "Music",    SettingsManager.music_volume,   0.0, 100.0, 1.0,    _on_music_volume_changed)
	_lbl_ambient_val = _add_slider_row(vbox, "Ambient",  SettingsManager.ambient_volume, 0.0, 100.0, 1.0,    _on_ambient_volume_changed)
	_lbl_sfx_val     = _add_slider_row(vbox, "SFX",      SettingsManager.sfx_volume,     0.0, 100.0, 1.0,    _on_sfx_volume_changed)

	vbox.add_child(_separator.call())

	# Gameplay section
	var gameplay_lbl := Label.new()
	gameplay_lbl.text = "Gameplay"
	gameplay_lbl.add_theme_font_size_override("font_size", 14)
	gameplay_lbl.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(gameplay_lbl)

	_lbl_speed_val = _add_slider_row(vbox, "Game Speed", SettingsManager.game_speed,     0.25, 4.0, 0.25,   _on_game_speed_changed, "(lower = faster)")

	vbox.add_child(_separator.call())

	var btn_back := _make_button.call("Back", 160)
	btn_back.pressed.connect(func() -> void: back_requested.emit())
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(btn_back)
	vbox.add_child(btn_row)

	return panel


# ── Cycle button helper ───────────────────────────────────────────────────────

func _build_cycle_button(vbox: VBoxContainer, label_str: String, initial_text: String, callback: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = label_str
	name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", C_BODY)
	row.add_child(name_lbl)

	var btn := Button.new()
	btn.text = initial_text
	btn.custom_minimum_size = Vector2(120, 30)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.40, 0.22, 0.08, 1.0)
	btn_normal.set_border_width_all(1)
	btn_normal.border_color = C_PANEL_BORDER
	btn_normal.set_content_margin_all(4)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.60, 0.34, 0.12, 1.0)
	btn_hover.set_border_width_all(1)
	btn_hover.border_color = C_PANEL_BORDER
	btn_hover.set_content_margin_all(4)
	var btn_focus := StyleBoxFlat.new()
	btn_focus.bg_color = Color(0.60, 0.34, 0.12, 1.0)
	btn_focus.set_border_width_all(2)
	btn_focus.border_color = Color(1.00, 0.90, 0.40, 1.0)
	btn_focus.set_content_margin_all(4)
	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.22, 0.13, 0.05, 1.0)
	btn_pressed.set_border_width_all(1)
	btn_pressed.border_color = C_PANEL_BORDER
	btn_pressed.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal",  btn_normal)
	btn.add_theme_stylebox_override("hover",   btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_pressed)
	btn.add_theme_stylebox_override("focus",   btn_focus)
	btn.pivot_offset = btn.custom_minimum_size * 0.5
	btn.mouse_entered.connect(func() -> void:
		AudioManager.play_sfx_pitched("ui_click", 2.0)
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)
	)
	btn.pressed.connect(callback)
	row.add_child(btn)
	return btn


# ── Slider row helper ─────────────────────────────────────────────────────────

func _add_slider_row(
		parent: VBoxContainer,
		label_text: String,
		initial_value: float,
		min_val: float, max_val: float, step: float,
		change_callback: Callable,
		hint: String = "") -> Label:

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = label_text + ":"
	name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", C_BODY)
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step      = step
	slider.value     = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(change_callback)
	var grabber_focus := StyleBoxFlat.new()
	grabber_focus.bg_color = Color(0.20, 0.14, 0.06, 1.0)
	grabber_focus.set_border_width_all(2)
	grabber_focus.border_color = Color(1.00, 0.90, 0.40, 1.0)
	grabber_focus.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_focus)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(52, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", C_MUTED)
	val_lbl.text = _format_slider_val(label_text, initial_value)
	row.add_child(val_lbl)

	if hint != "":
		var hint_lbl := Label.new()
		hint_lbl.text = hint
		hint_lbl.add_theme_font_size_override("font_size", 12)
		hint_lbl.add_theme_color_override("font_color", C_MUTED)
		parent.add_child(hint_lbl)

	return val_lbl


func _format_slider_val(label_text: String, value: float) -> String:
	if label_text == "Game Speed":
		return "%.2fs" % value
	return "%d%%" % int(value)


# ── Panel factory ─────────────────────────────────────────────────────────────

func _make_panel(w: int, h: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, h)
	p.set_anchor(SIDE_LEFT,   0.5)
	p.set_anchor(SIDE_RIGHT,  0.5)
	p.set_anchor(SIDE_TOP,    0.5)
	p.set_anchor(SIDE_BOTTOM, 0.5)
	p.set_offset(SIDE_LEFT,   -w / 2.0)
	p.set_offset(SIDE_RIGHT,   w / 2.0)
	p.set_offset(SIDE_TOP,    -h / 2.0)
	p.set_offset(SIDE_BOTTOM,  h / 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.border_color = C_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", style)
	return p


# ── Event handlers ────────────────────────────────────────────────────────────

func _on_master_volume_changed(value: float) -> void:
	SettingsManager.master_volume = value
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()
	_lbl_master_val.text = _format_slider_val("Master", value)


func _on_music_volume_changed(value: float) -> void:
	SettingsManager.music_volume = value
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()
	_lbl_music_val.text = _format_slider_val("Music", value)


func _on_ambient_volume_changed(value: float) -> void:
	SettingsManager.ambient_volume = value
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()
	_lbl_ambient_val.text = _format_slider_val("Ambient", value)


func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.sfx_volume = value
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()
	_lbl_sfx_val.text = _format_slider_val("SFX", value)


func _on_game_speed_changed(value: float) -> void:
	SettingsManager.game_speed = value
	SettingsManager.save_settings()
	_lbl_speed_val.text = _format_slider_val("Game Speed", value)


func _on_resolution_cycle() -> void:
	AudioManager.play_ui("click")
	SettingsManager.resolution_index = (SettingsManager.resolution_index + 1) % SettingsManager.RESOLUTIONS.size()
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
	_btn_resolution.text = SettingsManager.get_resolution_label()
	var tw := _btn_resolution.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_resolution, "scale", Vector2(0.95, 0.95), 0.06)
	tw.tween_property(_btn_resolution, "scale", Vector2.ONE, 0.10)


func _on_window_mode_cycle() -> void:
	AudioManager.play_ui("click")
	SettingsManager.window_mode = (SettingsManager.window_mode + 1) % 3
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
	_btn_window_mode.text = SettingsManager.get_window_mode_label()
	var tw := _btn_window_mode.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_window_mode, "scale", Vector2(0.95, 0.95), 0.06)
	tw.tween_property(_btn_window_mode, "scale", Vector2.ONE, 0.10)


func _on_window_scale_cycle() -> void:
	AudioManager.play_ui("click")
	SettingsManager.window_scale_index = (SettingsManager.window_scale_index + 1) % SettingsManager.WINDOW_SCALE_PRESETS.size()
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
	_btn_window_scale.text = SettingsManager.get_window_scale_label()
	var tw := _btn_window_scale.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_window_scale, "scale", Vector2(0.95, 0.95), 0.06)
	tw.tween_property(_btn_window_scale, "scale", Vector2.ONE, 0.10)


func _on_ui_scale_cycle() -> void:
	AudioManager.play_ui("click")
	SettingsManager.ui_scale_index = (SettingsManager.ui_scale_index + 1) % SettingsManager.UI_SCALE_PRESETS.size()
	SettingsManager.ui_scale = SettingsManager.UI_SCALE_PRESETS[SettingsManager.ui_scale_index]
	SettingsManager.apply_ui_scale()
	SettingsManager.save_settings()
	_btn_ui_scale.text = SettingsManager.get_ui_scale_label()
	var tw := _btn_ui_scale.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_ui_scale, "scale", Vector2(0.95, 0.95), 0.06)
	tw.tween_property(_btn_ui_scale, "scale", Vector2.ONE, 0.10)
