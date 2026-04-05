extends CanvasLayer

## pause_menu.gd — Escape-key pause overlay.
## Created programmatically by main.gd after the game starts.
## Pauses the game tree while open.
## Resume: unpause and close.
## Save Game: pick a slot (1–3), serialise state to that slot file.
## Load Game: pick a slot (auto, 1–3), restore from that slot via scene reload.
## Restart Scenario: unpause, then reload the scene and auto-start the same scenario.
## Quit to Menu: unpause then reload the scene (returns to main menu).

## Persists across scene reloads so main.gd can skip the menu on restart.
static var _pending_restart_id: String = ""

# ── Palette (matches main_menu.gd) ───────────────────────────────────────────
const C_BTN_NORMAL   := Color(0.30, 0.18, 0.07, 1.0)
const C_BTN_HOVER    := Color(0.50, 0.30, 0.10, 1.0)
const C_BTN_PRESSED  := Color(0.22, 0.13, 0.05, 1.0)
const C_BTN_BORDER   := Color(0.55, 0.38, 0.18, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)

var _is_open: bool = false
var _scenario_id: String = ""
var _how_to_play: CanvasLayer = null
var _settings_menu: CanvasLayer = null

# ── Save/load refs (wired by main.gd via setup_save_load / setup_tutorial) ────
var _world_ref:       Node2D        = null
var _day_night_ref:   Node          = null
var _journal_ref:     CanvasLayer   = null
var _tutorial_sys_ref: TutorialSystem = null

var _status_label: Label = null

# ── Slot picker state ──────────────────────────────────────────────────────────
var _main_container:  VBoxContainer = null   # main menu buttons
var _slot_container:  VBoxContainer = null   # slot picker panel
var _slot_mode_save:  bool = false           # true = saving, false = loading
var _slot_label:      Label = null           # "Save to Slot" / "Load from Slot"
var _slot_btn_auto:   Button = null
var _slot_btn_1:      Button = null
var _slot_btn_2:      Button = null
var _slot_btn_3:      Button = null

# ── Panel animation refs ──────────────────────────────────────────────────────
var _bg_rect:         ColorRect = null
var _center_panel:    Panel     = null
var _open_tween:      Tween     = null


func _ready() -> void:
	layer        = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_how_to_play = preload("res://scripts/how_to_play.gd").new()
	_how_to_play.name = "HowToPlay"
	add_child(_how_to_play)
	_settings_menu = preload("res://scripts/settings_menu.gd").new()
	_settings_menu.name = "SettingsMenu"
	add_child(_settings_menu)
	visible = false


## Called by main.gd immediately after adding this node.
func setup(scenario_id: String) -> void:
	_scenario_id = scenario_id


## Called by main.gd to provide game-system references for save/load.
func setup_save_load(world: Node2D, day_night: Node, journal: CanvasLayer) -> void:
	_world_ref     = world
	_day_night_ref = day_night
	_journal_ref   = journal


## Called by main.gd to provide the tutorial system reference for save/load.
func setup_tutorial(sys: TutorialSystem) -> void:
	_tutorial_sys_ref = sys


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _slot_container != null and _slot_container.visible:
				_hide_slot_picker()
			else:
				toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	if _is_open:
		_close()
	else:
		_open()


func _open() -> void:
	_is_open          = true
	visible           = true
	get_tree().paused = true
	if _status_label != null:
		_status_label.text = ""
	_hide_slot_picker()
	# Animate open: fade bg + scale panel in.
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	if _bg_rect != null:
		_bg_rect.modulate.a = 0.0
	if _center_panel != null:
		_center_panel.scale = Vector2(0.92, 0.92)
		_center_panel.modulate.a = 0.0
	_open_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _bg_rect != null:
		_open_tween.tween_property(_bg_rect, "modulate:a", 1.0, 0.18)
	if _center_panel != null:
		_open_tween.tween_property(_center_panel, "scale", Vector2.ONE, 0.22)
		_open_tween.tween_property(_center_panel, "modulate:a", 1.0, 0.18)
	# Set keyboard focus on the first menu button.
	if _main_container != null and _main_container.get_child_count() > 0:
		var first := _main_container.get_child(0)
		if first is Button:
			first.call_deferred("grab_focus")


func _close() -> void:
	_is_open = false
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	var tw := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _bg_rect != null:
		tw.tween_property(_bg_rect, "modulate:a", 0.0, 0.12)
	if _center_panel != null:
		tw.tween_property(_center_panel, "scale", Vector2(0.92, 0.92), 0.15)
		tw.tween_property(_center_panel, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func() -> void:
		get_tree().paused = false
		visible = false
	)


func _build_ui() -> void:
	# Full-screen dim overlay.
	_bg_rect = ColorRect.new()
	_bg_rect.color = Color(0.0, 0.0, 0.0, 0.55)
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bg_rect)

	# Centred panel — tall enough for buttons + slot picker + status line.
	_center_panel = Panel.new()
	_center_panel.custom_minimum_size = Vector2(300, 460)
	_center_panel.set_anchors_preset(Control.PRESET_CENTER)
	_center_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_center_panel.pivot_offset = Vector2(150, 230)  # centre of 300x460
	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.10, 0.08, 0.06, 0.96)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color        = Color(0.65, 0.55, 0.35, 1.0)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	_center_panel.add_theme_stylebox_override("panel", style)
	add_child(_center_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_vbox.add_theme_constant_override("separation", 12)
	outer_vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	_center_panel.add_child(outer_vbox)

	# Title.
	var title := Label.new()
	title.text                  = "— PAUSED —"
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.90, 0.82, 0.60, 1.0))
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	outer_vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	outer_vbox.add_child(spacer)

	# ── Main buttons container ─────────────────────────────────────────────────
	_main_container = VBoxContainer.new()
	_main_container.add_theme_constant_override("separation", 10)
	_main_container.process_mode = Node.PROCESS_MODE_ALWAYS
	outer_vbox.add_child(_main_container)

	var btn_resume := _make_pause_btn("Resume  (Esc)", C_BTN_TEXT)
	btn_resume.pressed.connect(_close)
	_main_container.add_child(btn_resume)

	var btn_howto := _make_pause_btn("How to Play", C_BTN_TEXT)
	btn_howto.pressed.connect(_on_how_to_play)
	_main_container.add_child(btn_howto)

	var btn_settings := _make_pause_btn("Settings", C_BTN_TEXT)
	btn_settings.pressed.connect(_on_settings)
	_main_container.add_child(btn_settings)

	var btn_save := _make_pause_btn("Save Game", Color(0.60, 0.90, 0.65, 1.0))
	btn_save.pressed.connect(_on_save_game)
	_main_container.add_child(btn_save)

	var btn_load := _make_pause_btn("Load Game", Color(0.60, 0.80, 1.00, 1.0))
	btn_load.pressed.connect(_on_load_game)
	_main_container.add_child(btn_load)

	var btn_restart := _make_pause_btn("Restart Scenario", Color(0.95, 0.80, 0.40, 1.0))
	btn_restart.pressed.connect(_on_restart_scenario)
	_main_container.add_child(btn_restart)

	var btn_quit := _make_pause_btn("Quit to Menu", Color(1.0, 0.65, 0.55, 1.0))
	btn_quit.pressed.connect(_on_quit_to_menu)
	_main_container.add_child(btn_quit)

	# ── Slot picker container (hidden initially) ───────────────────────────────
	_slot_container = VBoxContainer.new()
	_slot_container.add_theme_constant_override("separation", 10)
	_slot_container.process_mode = Node.PROCESS_MODE_ALWAYS
	_slot_container.visible = false
	outer_vbox.add_child(_slot_container)

	_slot_label = Label.new()
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.add_theme_font_size_override("font_size", 13)
	_slot_label.add_theme_color_override("font_color", Color(0.90, 0.82, 0.60, 1.0))
	_slot_label.process_mode = Node.PROCESS_MODE_ALWAYS
	_slot_container.add_child(_slot_label)

	_slot_btn_auto = _make_pause_btn("Auto — Empty", Color(0.75, 0.75, 0.75, 1.0))
	_slot_btn_auto.pressed.connect(func() -> void: _on_slot_action(SaveManager.AUTO_SLOT))
	_slot_container.add_child(_slot_btn_auto)

	_slot_btn_1 = _make_pause_btn("Slot 1 — Empty", C_BTN_TEXT)
	_slot_btn_1.pressed.connect(func() -> void: _on_slot_action(1))
	_slot_container.add_child(_slot_btn_1)

	_slot_btn_2 = _make_pause_btn("Slot 2 — Empty", C_BTN_TEXT)
	_slot_btn_2.pressed.connect(func() -> void: _on_slot_action(2))
	_slot_container.add_child(_slot_btn_2)

	_slot_btn_3 = _make_pause_btn("Slot 3 — Empty", C_BTN_TEXT)
	_slot_btn_3.pressed.connect(func() -> void: _on_slot_action(3))
	_slot_container.add_child(_slot_btn_3)

	var btn_cancel := _make_pause_btn("Cancel", Color(0.80, 0.60, 0.60, 1.0))
	btn_cancel.pressed.connect(_hide_slot_picker)
	_slot_container.add_child(btn_cancel)

	# ── Status label ──────────────────────────────────────────────────────────
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size  = Vector2(240, 0)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.80, 0.75, 0.55, 1.0))
	_status_label.process_mode = Node.PROCESS_MODE_ALWAYS
	outer_vbox.add_child(_status_label)


func _on_how_to_play() -> void:
	_how_to_play.open()


func _on_settings() -> void:
	_settings_menu.open()


func _on_save_game() -> void:
	if _world_ref == null or _day_night_ref == null or _journal_ref == null:
		_set_status("Save unavailable — game not fully loaded.", Color(1.0, 0.5, 0.5, 1.0))
		return
	_slot_mode_save = true
	_show_slot_picker()


func _on_load_game() -> void:
	if _world_ref == null:
		_set_status("Load unavailable — game not fully loaded.", Color(1.0, 0.5, 0.5, 1.0))
		return
	_slot_mode_save = false
	_show_slot_picker()


func _show_slot_picker() -> void:
	_refresh_slot_buttons()
	_main_container.visible = false
	_slot_container.visible = true
	if _status_label != null:
		_status_label.text = ""
	if _slot_mode_save:
		_slot_label.text = "— Save to Slot —"
		_slot_btn_auto.visible = false   # auto-save is not a manual save target
		if _slot_btn_1 != null:
			_slot_btn_1.call_deferred("grab_focus")
	else:
		_slot_label.text = "— Load from Slot —"
		_slot_btn_auto.visible = true
		if _slot_btn_auto != null:
			_slot_btn_auto.call_deferred("grab_focus")


func _hide_slot_picker() -> void:
	_main_container.visible = true
	_slot_container.visible = false
	# Restore keyboard focus to the first main menu button.
	if _main_container.get_child_count() > 0:
		var first := _main_container.get_child(0)
		if first is Button:
			first.call_deferred("grab_focus")


func _refresh_slot_buttons() -> void:
	# Update each slot button label to show save info or "Empty".
	_update_slot_button(_slot_btn_auto, SaveManager.AUTO_SLOT, "Auto")
	_update_slot_button(_slot_btn_1,    1,                     "Slot 1")
	_update_slot_button(_slot_btn_2,    2,                     "Slot 2")
	_update_slot_button(_slot_btn_3,    3,                     "Slot 3")


func _update_slot_button(btn: Button, slot: int, label: String) -> void:
	if btn == null:
		return
	var info: Dictionary = SaveManager.get_save_info(_scenario_id, slot)
	if info.is_empty():
		btn.text = label + " — Empty"
		btn.disabled = not _slot_mode_save  # can't load from empty slot
	else:
		btn.text = "%s — Day %d" % [label, info.get("day", 1)]
		btn.disabled = false


func _on_slot_action(slot: int) -> void:
	if _slot_mode_save:
		if _world_ref == null or _day_night_ref == null or _journal_ref == null:
			_set_status("Save unavailable.", Color(1.0, 0.5, 0.5, 1.0))
			_hide_slot_picker()
			return
		var err: String = SaveManager.save_game(_world_ref, _day_night_ref, _journal_ref, slot, _tutorial_sys_ref)
		_hide_slot_picker()
		if err.is_empty():
			var slot_name := "Auto" if slot == SaveManager.AUTO_SLOT else ("Slot %d" % slot)
			_set_status("Saved to %s." % slot_name, Color(0.60, 0.90, 0.65, 1.0))
		else:
			_set_status("Save failed: " + err, Color(1.0, 0.5, 0.5, 1.0))
	else:
		var err: String = SaveManager.prepare_load(_scenario_id, slot)
		if not err.is_empty():
			_hide_slot_picker()
			_set_status(err, Color(1.0, 0.5, 0.5, 1.0))
			return
		# Reload the scene; main.gd will restore state via SaveManager.apply_pending_load().
		_pending_restart_id = SaveManager.pending_scenario_id()
		get_tree().paused   = false
		get_tree().reload_current_scene()


func _set_status(msg: String, colour: Color) -> void:
	if _status_label == null:
		return
	_status_label.text = msg
	_status_label.add_theme_color_override("font_color", colour)


func _on_restart_scenario() -> void:
	_pending_restart_id = _scenario_id
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_to_menu() -> void:
	_pending_restart_id = ""
	get_tree().paused = false
	get_tree().reload_current_scene()


func _make_pause_btn(label_text: String, font_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(240, 40)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", font_color)

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN_NORMAL
	normal.set_border_width_all(1)
	normal.border_color = C_BTN_BORDER
	normal.set_content_margin_all(8)
	normal.set_corner_radius_all(3)

	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_HOVER
	hover.set_border_width_all(1)
	hover.border_color = C_BTN_BORDER
	hover.set_content_margin_all(8)
	hover.set_corner_radius_all(3)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = C_BTN_PRESSED
	pressed.set_border_width_all(1)
	pressed.border_color = C_BTN_BORDER
	pressed.set_content_margin_all(8)
	pressed.set_corner_radius_all(3)

	var focus := StyleBoxFlat.new()
	focus.bg_color = C_BTN_HOVER
	focus.set_border_width_all(2)
	focus.border_color = Color(1.00, 0.90, 0.40, 1.0)  # bright gold — clearly visible focus ring
	focus.set_content_margin_all(8)
	focus.set_corner_radius_all(3)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.18, 0.12, 0.08, 0.6)
	disabled.set_border_width_all(1)
	disabled.border_color = Color(C_BTN_BORDER.r, C_BTN_BORDER.g, C_BTN_BORDER.b, 0.35)
	disabled.set_content_margin_all(8)
	disabled.set_corner_radius_all(3)

	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  pressed)
	btn.add_theme_stylebox_override("focus",    focus)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.50, 0.40, 0.5))
	btn.pivot_offset = btn.custom_minimum_size * 0.5
	btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)
	)
	btn.mouse_entered.connect(func() -> void:
		AudioManager.play_sfx_pitched("ui_click", 2.0)
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)
	)
	return btn
