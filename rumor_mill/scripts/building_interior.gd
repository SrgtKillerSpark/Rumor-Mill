extends CanvasLayer

## building_interior.gd — Sprint 5 (Art Pass 1, SPA-41)
## Base controller for flat 2D interior panels: Tavern, Manor, Chapel.
##
## Usage: call show_interior() to open; panel closes on E key or × button.
## The scene tree expects:
##   $Overlay   (ColorRect)    — dim background
##   $Panel     (Panel)        — parchment panel
##   $Panel/Layout/.../CloseBtn (Button)
##
## Intended to be instanced into Main.tscn and toggled by world.gd or the
## recon controller when the player interacts with a building.

signal interior_opened
signal interior_closed

@onready var _overlay:    ColorRect = $Overlay
@onready var _panel:      Panel     = $Panel
@onready var _close_btn:  Button    = _find_close_btn()

var _open: bool = false
var _transitioning: bool = false
var _anim_tween: Tween = null


func _ready() -> void:
	_overlay.visible = false
	_panel.visible   = false
	if _close_btn != null:
		_close_btn.pressed.connect(close_interior)


func _find_close_btn() -> Button:
	# Walk the panel tree looking for a Button named "CloseBtn".
	var btn := _panel.find_child("CloseBtn", true, false) as Button
	if btn == null:
		push_warning("BuildingInterior: CloseBtn not found in panel — Escape/E key fallback only.")
	return btn


# ── Public API ────────────────────────────────────────────────────────────────

func show_interior() -> void:
	if _open or _transitioning:
		return
	_transitioning = true

	# Prepare initial states for the animation.
	_overlay.modulate.a = 0.0
	_overlay.visible    = true
	_panel.modulate.a   = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale        = Vector2(0.95, 0.95)
	_panel.visible      = true

	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Overlay dims in over 0.3s.
	_anim_tween.tween_property(_overlay, "modulate:a", 1.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	# Panel fades in and scales up over 0.25s.
	_anim_tween.tween_property(_panel, "modulate:a", 1.0, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_anim_tween.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# After all parallels finish, mark open and emit.
	_anim_tween.set_parallel(false)
	_anim_tween.tween_callback(func() -> void:
		_transitioning = false
		_open = true
		emit_signal("interior_opened")
		if _close_btn != null:
			_close_btn.call_deferred("grab_focus")
	)


func close_interior() -> void:
	if not _open or _transitioning:
		return
	_transitioning = true
	_open = false

	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Overlay and panel fade out together over 0.2s.
	_anim_tween.tween_property(_overlay, "modulate:a", 0.0, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_panel, "modulate:a", 0.0, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_anim_tween.tween_property(_panel, "scale", Vector2(0.95, 0.95), 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_anim_tween.set_parallel(false)
	_anim_tween.tween_callback(func() -> void:
		_overlay.visible    = false
		_panel.visible      = false
		# Reset modulate/scale so the next open starts clean.
		_overlay.modulate.a = 1.0
		_panel.modulate.a   = 1.0
		_panel.scale        = Vector2(1.0, 1.0)
		_transitioning = false
		emit_signal("interior_closed")
	)


func is_open() -> bool:
	return _open


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Block input while a transition is playing.
	if not _open or _transitioning:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E or event.keycode == KEY_ESCAPE:
			close_interior()
			get_viewport().set_input_as_handled()
