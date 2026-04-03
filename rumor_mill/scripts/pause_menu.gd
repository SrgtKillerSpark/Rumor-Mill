extends CanvasLayer

## pause_menu.gd — Escape-key pause overlay.
## Created programmatically by main.gd after the game starts.
## Pauses the game tree while open.
## Resume: unpause and close.
## Restart Scenario: unpause, then reload the scene and auto-start the same scenario.
## Quit to Menu: unpause then reload the scene (returns to main menu).

## Persists across scene reloads so main.gd can skip the menu on restart.
static var _pending_restart_id: String = ""

var _is_open: bool = false
var _scenario_id: String = ""


func _ready() -> void:
	layer        = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


## Called by main.gd immediately after adding this node.
func setup(scenario_id: String) -> void:
	_scenario_id = scenario_id


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

	# Centred panel — tall enough for three buttons.
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(300, 230)
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
	var btn_resume := Button.new()
	btn_resume.text = "Resume  (Esc)"
	btn_resume.add_theme_font_size_override("font_size", 14)
	btn_resume.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_resume.pressed.connect(_close)
	vbox.add_child(btn_resume)

	# Restart Scenario button.
	var btn_restart := Button.new()
	btn_restart.text = "Restart Scenario"
	btn_restart.add_theme_font_size_override("font_size", 14)
	btn_restart.add_theme_color_override("font_color", Color(0.95, 0.80, 0.40, 1.0))
	btn_restart.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_restart.pressed.connect(_on_restart_scenario)
	vbox.add_child(btn_restart)

	# Quit to menu button.
	var btn_quit := Button.new()
	btn_quit.text = "Quit to Menu"
	btn_quit.add_theme_font_size_override("font_size", 14)
	btn_quit.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45, 1.0))
	btn_quit.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_quit.pressed.connect(_on_quit_to_menu)
	vbox.add_child(btn_quit)


func _on_restart_scenario() -> void:
	_pending_restart_id = _scenario_id
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_to_menu() -> void:
	_pending_restart_id = ""
	get_tree().paused = false
	get_tree().reload_current_scene()
