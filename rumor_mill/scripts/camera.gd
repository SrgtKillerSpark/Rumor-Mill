extends Camera2D

## camera.gd — free pan (WASD / arrow keys) and zoom (+/- or mouse wheel).
## Zoom range: 0.5× to 2.0× as specified in the vertical slice scope.

@export var pan_speed: float = 400.0          # pixels/sec at zoom=1
@export var zoom_speed: float = 0.15          # zoom delta per scroll event
@export var zoom_min: float = 0.5
@export var zoom_max: float = 2.0
@export var zoom_lerp_speed: float = 8.0      # smoothing factor

var _target_zoom: float = 1.0
var _drag_origin: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

# ── Screen shake ──────────────────────────────────────────────────────────────
var _shake_intensity: float = 0.0
var _shake_duration:  float = 0.0
var _shake_timer:     float = 0.0


func _ready() -> void:
	_target_zoom = zoom.x
	# Start camera centered over the town (approx middle of 48x48 isometric grid).
	# Isometric 48x48 at 64x32 tile size: centre ≈ (48*32, 48*16) = (1536, 768)
	position = Vector2(1536, 768)


func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_smooth_zoom(delta)
	_update_shake(delta)


## Trigger a decaying screen shake.  intensity = max pixel offset, duration = seconds.
func shake_screen(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration  = max(duration, 0.001)
	_shake_timer     = duration


func _update_shake(delta: float) -> void:
	if _shake_timer <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	_shake_timer -= delta
	var t := clamp(_shake_timer / _shake_duration, 0.0, 1.0)
	var mag := _shake_intensity * t
	offset = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
	if _shake_timer <= 0.0:
		offset = Vector2.ZERO


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
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _is_dragging:
		var delta_pos: Vector2 = (get_viewport().get_mouse_position() - _drag_origin) / zoom.x
		position -= delta_pos
		_drag_origin = get_viewport().get_mouse_position()
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
		position += dir.normalized() * pan_speed * delta / zoom.x

	if Input.is_action_pressed("zoom_in"):
		_target_zoom = clamp(_target_zoom + zoom_speed * delta * 5.0, zoom_min, zoom_max)
	if Input.is_action_pressed("zoom_out"):
		_target_zoom = clamp(_target_zoom - zoom_speed * delta * 5.0, zoom_min, zoom_max)


func _smooth_zoom(delta: float) -> void:
	var current := zoom.x
	var next: float = lerp(current, _target_zoom, zoom_lerp_speed * delta)
	zoom = Vector2(next, next)
