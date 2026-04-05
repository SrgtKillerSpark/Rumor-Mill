extends CanvasLayer

## ready_overlay.gd — SPA-519: "Paused — press Space to begin" overlay.
##
## Shown once on Day 1 game start so the player can read the tutorial banner
## and orient before time begins ticking.

signal dismissed

var _backdrop: ColorRect = null
var _label:    Label     = null
var _pulse_tween: Tween  = null


func _ready() -> void:
	layer        = 15  # above HUD (5), below pause menu (20)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	# Semi-transparent dark backdrop.
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.05, 0.04, 0.08, 0.55)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# Centered prompt label — medieval parchment style.
	_label = Label.new()
	_label.text = "Paused  —  press Space to begin"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.anchor_left   = 0.5
	_label.anchor_right  = 0.5
	_label.anchor_top    = 0.5
	_label.anchor_bottom = 0.5
	_label.offset_left   = -250.0
	_label.offset_right  =  250.0
	_label.offset_top    = -24.0
	_label.offset_bottom =  24.0
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65, 1.0))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.04, 0.8))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	# Gentle alpha pulse so the prompt feels alive.
	_start_pulse()


func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_label, "modulate:a", 0.55, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_label, "modulate:a", 1.0, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_dismiss()


func _dismiss() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	# Quick fade-out then free.
	var tw := create_tween()
	tw.tween_property(_backdrop, "color:a", 0.0, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_label, "modulate:a", 0.0, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		emit_signal("dismissed")
		queue_free()
	)
