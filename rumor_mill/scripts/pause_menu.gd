extends CanvasLayer

## pause_menu.gd — Escape-key pause overlay.
## Created programmatically by main.gd after the game starts.
## Pauses the game tree while open.
## Resume: unpause and close.
## Save Game: serialise state to user://saves/<scenario_id>.json.
## Load Game: restore from that file via scene reload.
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

# ── Save/load refs (wired by main.gd via setup_save_load) ─────────────────────
var _world_ref:     Node2D      = null
var _day_night_ref: Node        = null
var _journal_ref:   CanvasLayer = null

var _status_label: Label = null


func _ready() -> void:
	layer        = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_how_to_play = preload("res://scripts/how_to_play.gd").new()
	_how_to_play.name = "HowToPlay"
	add_child(_how_to_play)
	visible = false


## Called by main.gd immediately after adding this node.
func setup(scenario_id: String) -> void:
	_scenario_id = scenario_id


## Called by main.gd to provide game-system references for save/load.
func setup_save_load(world: Node2D, day_night: Node, journal: CanvasLayer) -> void:
	_world_ref     = world
	_day_night_ref = day_night
	_journal_ref   = journal


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
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


func _close() -> void:
	_is_open          = false
	visible           = false
	get_tree().paused = false


func _build_ui() -> void:
	# Full-screen dim overlay.
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bg)

	# Centred panel — tall enough for six buttons plus a status line.
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(300, 390)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
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
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(vbox)

	# Title.
	var title := Label.new()
	title.text                  = "— PAUSED —"
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.90, 0.82, 0.60, 1.0))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# Resume button.
	var btn_resume := _make_pause_btn("Resume  (Esc)", C_BTN_TEXT)
	btn_resume.pressed.connect(_close)
	vbox.add_child(btn_resume)

	# How to Play button.
	var btn_howto := _make_pause_btn("How to Play", C_BTN_TEXT)
	btn_howto.pressed.connect(_on_how_to_play)
	vbox.add_child(btn_howto)

	# Save Game button.
	var btn_save := _make_pause_btn("Save Game", Color(0.60, 0.90, 0.65, 1.0))
	btn_save.pressed.connect(_on_save_game)
	vbox.add_child(btn_save)

	# Load Game button.
	var btn_load := _make_pause_btn("Load Game", Color(0.60, 0.80, 1.00, 1.0))
	btn_load.pressed.connect(_on_load_game)
	vbox.add_child(btn_load)

	# Restart Scenario button.
	var btn_restart := _make_pause_btn("Restart Scenario", Color(0.95, 0.80, 0.40, 1.0))
	btn_restart.pressed.connect(_on_restart_scenario)
	vbox.add_child(btn_restart)

	# Quit to menu button.
	var btn_quit := _make_pause_btn("Quit to Menu", Color(1.0, 0.65, 0.55, 1.0))
	btn_quit.pressed.connect(_on_quit_to_menu)
	vbox.add_child(btn_quit)

	# Status label — shows save/load feedback.
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size  = Vector2(240, 0)
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.80, 0.75, 0.55, 1.0))
	_status_label.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(_status_label)


func _on_how_to_play() -> void:
	_how_to_play.open()


func _on_save_game() -> void:
	if _world_ref == null or _day_night_ref == null or _journal_ref == null:
		_set_status("Save unavailable — game not fully loaded.", Color(1.0, 0.5, 0.5, 1.0))
		return
	var err: String = SaveManager.save_game(_world_ref, _day_night_ref, _journal_ref)
	if err.is_empty():
		_set_status("Game saved.", Color(0.60, 0.90, 0.65, 1.0))
	else:
		_set_status("Save failed: " + err, Color(1.0, 0.5, 0.5, 1.0))


func _on_load_game() -> void:
	if _world_ref == null:
		_set_status("Load unavailable — game not fully loaded.", Color(1.0, 0.5, 0.5, 1.0))
		return
	var err: String = SaveManager.prepare_load(_scenario_id)
	if not err.is_empty():
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

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus",   focus)
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	return btn
