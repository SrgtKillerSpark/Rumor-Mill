extends Camera2D

## camera.gd — free pan (WASD / arrow keys), zoom (+/- or scroll wheel),
##             mouse edge-panning, and optional smooth follow target.
## Zoom range: 0.5× to 2.0× as specified in the vertical slice scope.

## Emitted once the first time the player pans the camera (keyboard or drag).
## Used by the tutorial hint system to unlock HINT-02 (hint_hover_npc).
signal camera_moved

@export var pan_speed: float = 400.0          # pixels/sec at zoom=1
@export var zoom_speed: float = 0.15          # zoom delta per scroll event
@export var zoom_min: float = 0.5
@export var zoom_max: float = 2.0
@export var zoom_lerp_speed: float = 8.0      # smoothing factor for zoom

## Edge panning — disabled while a follow target is active.
@export var edge_pan_enabled: bool = true
@export var edge_pan_margin: float = 40.0     # px from viewport edge that triggers pan
@export var edge_pan_speed: float = 350.0     # px/sec at zoom=1

## Smooth follow.  Call set_follow_target() / clear_follow_target() to control.
## Any player keyboard pan input automatically clears the follow target.
@export var follow_lerp_speed: float = 5.0    # higher = snappier tracking

var _target_zoom: float = 1.5
var _drag_origin: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _shake_tween: Tween = null
var _pan_tween: Tween = null
var _camera_moved_emitted: bool = false
var _follow_target: Node2D = null


func _ready() -> void:
	_target_zoom = zoom.x
	# Start camera centered over the town (approx middle of 48×48 isometric grid).
	# Isometric 48×48 at 64×32 tile size: centre ≈ (48*32, 48*16) = (1536, 768)
	position = Vector2(1536, 768)
	# Clamp camera to town extents so the player cannot pan into the void.
	limit_left   = 0
	limit_top    = 0
	limit_right  = 3072   # 48 * 64 px (tile width)
	limit_bottom = 1536   # 48 * 32 px (tile height)


func _process(delta: float) -> void:
	if _follow_target != null and is_instance_valid(_follow_target):
		_handle_smooth_follow(delta)
	else:
		_handle_keyboard_pan(delta)
		if edge_pan_enabled:
			_handle_edge_pan(delta)
	_smooth_zoom(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse-wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_zoom = clamp(_target_zoom + zoom_speed, zoom_min, zoom_max)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_zoom = clamp(_target_zoom - zoom_speed, zoom_min, zoom_max)
			get_viewport().set_input_as_handled()
		# Middle-mouse drag
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
			if _is_dragging:
				_drag_origin = get_viewport().get_mouse_position()
				clear_follow_target()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _is_dragging:
		var delta_pos: Vector2 = (get_viewport().get_mouse_position() - _drag_origin) / zoom.x
		position -= delta_pos
		_drag_origin = get_viewport().get_mouse_position()
		_emit_camera_moved()
		get_viewport().set_input_as_handled()


func _handle_keyboard_pan(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("camera_pan_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("camera_pan_down"):
		dir.y += 1.0
	if Input.is_action_pressed("camera_pan_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("camera_pan_right"):
		dir.x += 1.0

	if dir != Vector2.ZERO:
		clear_follow_target()
		position += dir.normalized() * pan_speed * delta / zoom.x
		_emit_camera_moved()

	if Input.is_action_pressed("zoom_in"):
		_target_zoom = clamp(_target_zoom + zoom_speed * delta * 5.0, zoom_min, zoom_max)
	if Input.is_action_pressed("zoom_out"):
		_target_zoom = clamp(_target_zoom - zoom_speed * delta * 5.0, zoom_min, zoom_max)


## Pan camera when the mouse cursor sits within edge_pan_margin of the viewport edge.
## Skipped when the mouse is outside the viewport window entirely.
func _handle_edge_pan(delta: float) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_viewport().get_mouse_position()

	# Only pan while mouse is inside the viewport.
	if mouse.x < 0.0 or mouse.y < 0.0 or mouse.x > vp_size.x or mouse.y > vp_size.y:
		return

	var dir := Vector2.ZERO
	if mouse.x < edge_pan_margin:
		dir.x -= 1.0
	elif mouse.x > vp_size.x - edge_pan_margin:
		dir.x += 1.0
	if mouse.y < edge_pan_margin:
		dir.y -= 1.0
	elif mouse.y > vp_size.y - edge_pan_margin:
		dir.y += 1.0

	if dir != Vector2.ZERO:
		position += dir.normalized() * edge_pan_speed * delta / zoom.x
		_emit_camera_moved()


## Lerp the camera toward the follow target's world position each frame.
func _handle_smooth_follow(delta: float) -> void:
	position = position.lerp(_follow_target.global_position, minf(follow_lerp_speed * delta, 1.0))


func _emit_camera_moved() -> void:
	if not _camera_moved_emitted:
		_camera_moved_emitted = true
		camera_moved.emit()


func _smooth_zoom(delta: float) -> void:
	var current := zoom.x
	var next: float = lerp(current, _target_zoom, minf(zoom_lerp_speed * delta, 1.0))
	zoom = Vector2(next, next)


## Attach a Node2D for the camera to smoothly track each frame.
## Cancels any in-progress auto-pan tween.
## Player keyboard or drag input will call clear_follow_target() to release.
func set_follow_target(target: Node2D) -> void:
	_follow_target = target
	if _pan_tween != null:
		_pan_tween.kill()
		_pan_tween = null


## Release the smooth follow target and resume free-pan behaviour.
func clear_follow_target() -> void:
	_follow_target = null


## SPA-626: Smoothly pan the camera to a target world position.
## Interrupts any in-progress auto-pan.  Player keyboard input can still override
## during the tween because _handle_keyboard_pan runs every frame.
func pan_to_target(target_pos: Vector2, duration: float = 2.0) -> void:
	clear_follow_target()
	if _pan_tween != null:
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pan_tween.tween_property(self, "position", target_pos, duration)


## SPA-775: Briefly ease to target_pos, hold for hold_secs, then release camera.
## Does NOT lock the camera — the player can still pan during or after.
func brief_focus(target_pos: Vector2, hold_secs: float = 0.3) -> void:
	clear_follow_target()
	if _pan_tween != null:
		_pan_tween.kill()
	var origin := position
	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pan_tween.tween_property(self, "position", target_pos, 0.3)
	_pan_tween.tween_interval(hold_secs)
	_pan_tween.tween_property(self, "position", origin, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Trigger a screen shake.  Safe to call mid-shake — restarts with new params.
## intensity: max pixel offset per step.  duration: total shake time in seconds.
func shake_screen(intensity: float = 8.0, duration: float = 0.4) -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var step := 0.05
	var steps := maxi(2, int(duration / step))
	for i in steps:
		# Decay intensity over the shake so it trails off naturally.
		var t := float(i) / float(steps)
		var cur_intensity := intensity * (1.0 - t * 0.6)
		var rand_offset := Vector2(
			randf_range(-cur_intensity, cur_intensity),
			randf_range(-cur_intensity, cur_intensity)
		)
		_shake_tween.tween_property(self, "offset", rand_offset, step)
	_shake_tween.tween_property(self, "offset", Vector2.ZERO, step)
