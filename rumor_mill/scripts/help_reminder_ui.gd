## SPA-995: HelpReminderUI — help-reminder overlay, thought legend, and controls reference.
##
## Extracted from main.gd (_init_help_reminder, _init_thought_legend,
## _init_controls_reference).  Add as a child of main then call setup().
class_name HelpReminderUI
extends Node

# Exposed so main.gd can pass it to ContextControlsPanel.setup().
var controls_ref: CanvasLayer = null


## Initialise all three sub-systems.
## `parent`    — the main scene node (used for PlayerStats access).
## `day_night` — DayNightCycle node forwarded to ThoughtBubbleLegend.
func setup(parent: Node, day_night: Node) -> void:
	_init_controls_reference()
	_init_help_reminder()
	_init_thought_legend(day_night)


# ── SPA-541: Persistent controls reference overlay (F1 to toggle). ────────────
func _init_controls_reference() -> void:
	controls_ref = preload("res://scripts/controls_reference.gd").new()
	controls_ref.name = "ControlsReference"
	add_child(controls_ref)


# ── SPA-704: Persistent help key hints in bottom-right with subtle background. ─
## Shows essential hotkeys for 90 s then fades to a compact single-line reminder.
func _init_help_reminder() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 18
	layer.name = "HelpReminderLayer"
	add_child(layer)

	# Background panel for readability.
	var panel := PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_top    = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = -220
	panel.offset_top    = -80
	panel.offset_right  = -12
	panel.offset_bottom = -12
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.02, 0.65)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.38, 0.18, 0.40)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var line1 := Label.new()
	line1.text = "R: Rumor  |  J: Journal  |  G: Graph"
	line1.add_theme_font_size_override("font_size", 11)
	line1.add_theme_color_override("font_color", Color(0.85, 0.78, 0.58, 0.85))
	line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(line1)

	var line2 := Label.new()
	line2.text = "O: Mission  |  H: Hint  |  F1: Controls"
	line2.add_theme_font_size_override("font_size", 11)
	line2.add_theme_color_override("font_color", Color(0.80, 0.72, 0.55, 0.70))
	line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(line2)

	var line3 := Label.new()
	line3.text = "Esc: Pause + Settings"
	line3.add_theme_font_size_override("font_size", 11)
	line3.add_theme_color_override("font_color", Color(0.80, 0.72, 0.55, 0.55))
	line3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(line3)

	panel.add_child(vbox)
	layer.add_child(panel)

	# Fade out after 90 seconds.
	var fade_timer := get_tree().create_timer(90.0)
	fade_timer.timeout.connect(func() -> void:
		if not is_instance_valid(self) or not is_instance_valid(panel):
			return
		if panel != null:
			var tw := create_tween()
			tw.tween_property(panel, "modulate:a", 0.0, 1.5)
			tw.tween_callback(panel.queue_free)
	)


# ── SPA-806: Thought bubble symbol legend — bottom-right, above help reminder. ─
func _init_thought_legend(day_night: Node) -> void:
	var thought_legend: CanvasLayer = preload("res://scripts/thought_bubble_legend.gd").new()
	thought_legend.name = "ThoughtBubbleLegend"
	add_child(thought_legend)

	# Determine if the player has completed any scenario (returning player).
	var is_returning: bool = false
	for sc_id in ["scenario_1", "scenario_2", "scenario_3", "scenario_4", "scenario_5", "scenario_6"]:
		for diff in ["apprentice", "master", "spymaster"]:
			var stats: Dictionary = PlayerStats.get_scenario_stats(sc_id, diff)
			if stats.get("games_played", 0) > 0:
				is_returning = true
				break
		if is_returning:
			break

	thought_legend.setup(day_night, is_returning)
