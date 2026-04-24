extends CanvasLayer

## feedback_sequence.gd — SPA-784: Victory / defeat feedback sequences.
##
## Orchestrates the timed cinematic sequence between scenario_resolved and
## the end screen overlay.  Sits on layer 28 (above game world, below end
## screen at 30).
##
## Victory (~8 s):
##   1. 500 ms gameplay freeze
##   2. win.wav + warm golden vignette
##   3. Sepia desaturation + 5 % camera zoom over 2 s
##   4. 120 gold/amber celebration particles
##   5. Parchment banner with scenario-specific victory text (hold 3 s)
##   6. Stinger fade, town ambient at 50 %
##   7. Gentle iris-out to end screen
##
## Defeat (~6 s):
##   1. 200 ms screen shudder
##   2. fail.wav + cold blue-grey desaturation
##   3. Vignette closes in, music crossfades to silence (1.5 s)
##   4. Fail-reason text on red-tinted parchment banner (hold 3 s)
##   5. Hard cut to end screen (abrupt)
##
## Usage from main.gd:
##   var seq := preload("res://scripts/feedback_sequence.gd").new()
##   add_child(seq)
##   seq.setup(camera, day_night, world)
##   seq.sequence_finished.connect(_on_feedback_done)

signal sequence_finished

# ── Palette ──────────────────────────────────────────────────────────────────
const C_GOLD_VIGNETTE  := Color(0.92, 0.72, 0.10, 0.45)
const C_BLUE_DESAT     := Color(0.35, 0.42, 0.55, 0.55)
const C_BANNER_WIN_BG  := Color(0.18, 0.14, 0.08, 0.92)
const C_BANNER_FAIL_BG := Color(0.22, 0.08, 0.08, 0.92)
const C_BANNER_WIN_TX  := Color(0.95, 0.88, 0.55, 1.0)
const C_BANNER_FAIL_TX := Color(0.95, 0.40, 0.30, 1.0)
const C_IRIS_BLACK     := Color(0.0, 0.0, 0.0, 1.0)
const C_PARTICLE_GOLD  := Color(1.0, 0.82, 0.22, 1.0)
const C_PARTICLE_AMBER := Color(0.95, 0.65, 0.12, 1.0)

# ── Shaders (inline) ────────────────────────────────────────────────────────
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint_color : source_color = vec4(0.92, 0.72, 0.1, 0.45);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 2.0;
	float vig = smoothstep(0.3, 1.2, dist);
	COLOR = vec4(tint_color.rgb, tint_color.a * vig * intensity);
}
"""

const DESATURATION_SHADER := """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.75, 0.65, 0.50, 1.0);
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec4 col = texture(screen_tex, SCREEN_UV);
	float grey = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sepia = mix(col.rgb, vec3(grey) * tint.rgb, amount);
	COLOR = vec4(sepia, col.a);
}
"""

const IRIS_SHADER := """
shader_type canvas_item;
uniform float radius : hint_range(0.0, 1.5) = 1.5;
uniform vec2 center = vec2(0.5, 0.5);
void fragment() {
	vec2 uv = UV - center;
	float aspect = 1.777;
	uv.x *= aspect;
	float dist = length(uv);
	float edge = smoothstep(radius, radius - 0.08, dist);
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - edge);
}
"""

# ── References ───────────────────────────────────────────────────────────────
var _camera_ref: Camera2D = null
var _day_night_ref: Node = null
var _world_ref: Node2D = null

# ── UI nodes ─────────────────────────────────────────────────────────────────
var _vignette_rect: ColorRect = null
var _desat_rect: ColorRect = null
var _iris_rect: ColorRect = null
var _banner_panel: PanelContainer = null
var _banner_label: RichTextLabel = null
var _particle_layer: CanvasLayer = null

# ── State ────────────────────────────────────────────────────────────────────
var _running: bool = false


func _ready() -> void:
	layer = 28
	visible = false


func setup(cam: Camera2D, day_night: Node, world: Node2D) -> void:
	_camera_ref = cam
	_day_night_ref = day_night
	_world_ref = world


## Run the victory feedback sequence.  Awaitable.
func play_victory(scenario_id: int) -> void:
	if _running:
		return
	_running = true
	visible = true
	_build_overlays()

	# 1. Freeze gameplay for 500 ms.
	if _day_night_ref != null and _day_night_ref.has_method("set_paused"):
		_day_night_ref.set_paused(true)
	await get_tree().create_timer(0.5).timeout

	# 2. win.wav + warm golden vignette.
	AudioManager.on_win()
	_show_vignette(C_GOLD_VIGNETTE, 0.6)

	# 3. Sepia desaturation + 5 % camera zoom over 2 s.
	_show_desaturation(Color(0.85, 0.72, 0.52, 1.0), 0.55, 2.0)
	_zoom_camera(0.05, 2.0)
	await get_tree().create_timer(1.0).timeout

	# 4. 70 gold/amber celebration particles.
	_spawn_celebration_particles(70)
	await get_tree().create_timer(0.5).timeout

	# 5. Parchment banner with scenario-specific victory text (hold 2.5 s).
	var victory_text := _get_victory_banner_text(scenario_id)
	_show_banner(victory_text, true)
	await get_tree().create_timer(2.5).timeout
	_hide_banner(0.5)

	# 6. Stinger fade, town ambient at 50 %.
	AudioManager.set_ambient_volume_db(-24.0)
	await get_tree().create_timer(0.5).timeout

	# 7. Gentle iris-out to end screen.
	await _play_iris_out(1.5)

	_running = false
	sequence_finished.emit()


## Run the defeat feedback sequence.  Awaitable.
func play_defeat(scenario_id: int) -> void:
	if _running:
		return
	_running = true
	visible = true
	_build_overlays()

	# 1. 200 ms screen shudder.
	if _camera_ref != null and _camera_ref.has_method("shake_screen"):
		_camera_ref.shake_screen(18.0, 0.4)
	await get_tree().create_timer(0.2).timeout

	# 2. fail.wav + cold blue-grey desaturation.
	AudioManager.on_fail()
	_show_desaturation(Color(0.5, 0.55, 0.65, 1.0), 0.7, 1.0)
	_show_vignette(C_BLUE_DESAT, 0.4)

	# 3. Vignette closes in, music crossfades to silence (1.5 s).
	_intensify_vignette(0.85, 1.5)
	await get_tree().create_timer(1.5).timeout

	# Freeze the game world.
	if _day_night_ref != null and _day_night_ref.has_method("set_paused"):
		_day_night_ref.set_paused(true)

	# 4. Fail-reason text on red-tinted parchment banner (hold 3 s).
	var fail_text := _get_defeat_banner_text(scenario_id)
	_show_banner(fail_text, false)
	await get_tree().create_timer(3.0).timeout

	# 5. Fade out then cut to end screen.
	await TransitionManager.fade_out(0.3)
	_hide_all_overlays()

	_running = false
	sequence_finished.emit()


# ── Visual effect helpers ────────────────────────────────────────────────────

func _build_overlays() -> void:
	var vp_size := get_viewport().get_visible_rect().size

	# Vignette overlay.
	if _vignette_rect == null:
		_vignette_rect = ColorRect.new()
		_vignette_rect.size = vp_size
		_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = _create_shader(VIGNETTE_SHADER)
		mat.set_shader_parameter("intensity", 0.0)
		_vignette_rect.material = mat
		add_child(_vignette_rect)

	# Desaturation overlay.
	if _desat_rect == null:
		_desat_rect = ColorRect.new()
		_desat_rect.size = vp_size
		_desat_rect.color = Color(1, 1, 1, 0)
		_desat_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = _create_shader(DESATURATION_SHADER)
		mat.set_shader_parameter("amount", 0.0)
		_desat_rect.material = mat
		add_child(_desat_rect)

	# Iris overlay (starts transparent — full screen visible).
	if _iris_rect == null:
		_iris_rect = ColorRect.new()
		_iris_rect.size = vp_size
		_iris_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_iris_rect.visible = false
		var mat := ShaderMaterial.new()
		mat.shader = _create_shader(IRIS_SHADER)
		mat.set_shader_parameter("radius", 1.5)
		_iris_rect.material = mat
		add_child(_iris_rect)

	# Banner panel.
	if _banner_panel == null:
		_banner_panel = PanelContainer.new()
		_banner_panel.custom_minimum_size = Vector2(520, 90)
		_banner_panel.anchors_preset = Control.PRESET_CENTER
		_banner_panel.position = Vector2(
			(vp_size.x - 520) * 0.5,
			(vp_size.y - 90) * 0.5
		)
		var style := StyleBoxFlat.new()
		style.bg_color = C_BANNER_WIN_BG
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.55, 0.38, 0.18, 0.8)
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 16
		style.content_margin_bottom = 16
		_banner_panel.add_theme_stylebox_override("panel", style)
		_banner_panel.modulate.a = 0.0
		_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		_banner_label = RichTextLabel.new()
		_banner_label.bbcode_enabled = true
		_banner_label.fit_content = true
		_banner_label.scroll_active = false
		_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner_panel.add_child(_banner_label)
		add_child(_banner_panel)


func _create_shader(source: String) -> Shader:
	var shader := Shader.new()
	shader.code = source
	return shader


func _show_vignette(tint: Color, duration: float) -> void:
	if _vignette_rect == null:
		return
	var mat: ShaderMaterial = _vignette_rect.material as ShaderMaterial
	mat.set_shader_parameter("tint_color", tint)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("intensity", v)
	, 0.0, 1.0, duration)


func _intensify_vignette(target_intensity: float, duration: float) -> void:
	if _vignette_rect == null:
		return
	var mat: ShaderMaterial = _vignette_rect.material as ShaderMaterial
	var current: float = mat.get_shader_parameter("intensity")
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("intensity", v)
	, current, target_intensity, duration)


func _show_desaturation(tint: Color, amount: float, duration: float) -> void:
	if _desat_rect == null:
		return
	var mat: ShaderMaterial = _desat_rect.material as ShaderMaterial
	mat.set_shader_parameter("tint", tint)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("amount", v)
	, 0.0, amount, duration)


func _zoom_camera(zoom_delta: float, duration: float) -> void:
	if _camera_ref == null:
		return
	var start_zoom := _camera_ref.zoom.x
	var end_zoom := start_zoom + zoom_delta
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(_camera_ref):
			_camera_ref.zoom = Vector2(v, v)
	, start_zoom, end_zoom, duration)


func _spawn_celebration_particles(count: int) -> void:
	if _particle_layer != null:
		_particle_layer.queue_free()
	_particle_layer = CanvasLayer.new()
	_particle_layer.layer = 27
	add_child(_particle_layer)

	var vp_size := get_viewport().get_visible_rect().size
	var center := vp_size * 0.5

	for i in count:
		var lbl := Label.new()
		var symbols := ["✦", "★", "◆", "●", "✧"]
		lbl.text = symbols[i % symbols.size()]
		var font_size := randi_range(12, 28)
		lbl.add_theme_font_size_override("font_size", font_size)

		# Alternate gold and amber.
		var color: Color = C_PARTICLE_GOLD if i % 2 == 0 else C_PARTICLE_AMBER
		color.a = randf_range(0.7, 1.0)
		lbl.add_theme_color_override("font_color", color)

		# Spawn from center with spread.
		var spawn_x := center.x + randf_range(-200.0, 200.0)
		var spawn_y := center.y + randf_range(-80.0, 80.0)
		lbl.position = Vector2(spawn_x, spawn_y)
		_particle_layer.add_child(lbl)

		# Animate: float upward and outward, fade out.
		var delay := randf_range(0.0, 0.6)
		var travel := Vector2(
			randf_range(-160.0, 160.0),
			randf_range(-220.0, -60.0)
		)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(lbl, "position",
			lbl.position + travel, randf_range(1.5, 2.5)) \
			.set_delay(delay) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, randf_range(1.2, 2.0)) \
			.set_delay(delay + 0.5)

	# Clean up particles after they're all done.
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		if is_instance_valid(_particle_layer):
			_particle_layer.queue_free()
			_particle_layer = null
	)


func _show_banner(text: String, is_victory: bool) -> void:
	if _banner_panel == null:
		return

	var style: StyleBoxFlat = _banner_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = C_BANNER_WIN_BG if is_victory else C_BANNER_FAIL_BG
		style.border_color = Color(0.75, 0.62, 0.25, 0.8) if is_victory else Color(0.65, 0.18, 0.12, 0.8)

	var color := C_BANNER_WIN_TX if is_victory else C_BANNER_FAIL_TX
	_banner_label.text = "[center][color=#%s]%s[/color][/center]" % [color.to_html(false), text]

	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner_panel, "modulate:a", 1.0, 0.4)


func _hide_banner(duration: float) -> void:
	if _banner_panel == null:
		return
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_banner_panel, "modulate:a", 0.0, duration)


func _play_iris_out(duration: float) -> void:
	if _iris_rect == null:
		return
	_iris_rect.visible = true
	var mat: ShaderMaterial = _iris_rect.material as ShaderMaterial
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("radius", v)
	, 1.5, 0.0, duration)
	await tw.finished


func _hide_all_overlays() -> void:
	if _vignette_rect != null:
		_vignette_rect.modulate.a = 0.0
	if _desat_rect != null:
		var mat: ShaderMaterial = _desat_rect.material as ShaderMaterial
		mat.set_shader_parameter("amount", 0.0)
	if _iris_rect != null:
		_iris_rect.visible = false
	if _banner_panel != null:
		_banner_panel.modulate.a = 0.0
	visible = false


# ── Banner text helpers ──────────────────────────────────────────────────────

const VICTORY_BANNERS := {
	1: "The Alderman's reputation crumbles.\nYour patron's will is done.",
	2: "The plague scare spreads unchecked.\nFear is your finest weapon.",
	3: "Calder Fenn rises to power.\nThe succession is assured.",
	4: "The faithful stand protected.\nThe inquisition finds nothing.",
	5: "Aldric Vane wins the election.\nThe people have spoken — as you intended.",
	6: "The merchant's debts are called.\nThe guild bows to new masters.",
}

const DEFEAT_BANNERS := {
	1: "Your schemes were uncovered.\nThe town sees through you.",
	2: "The truth prevailed over fear.\nYour plague scare collapses.",
	3: "Calder's ambitions are ruined.\nThe succession slips away.",
	4: "The inquisition found its marks.\nYou could not shield them all.",
	5: "Aldric's campaign crumbles.\nThe election is lost.",
	6: "The guild holds firm.\nYour machinations come undone.",
}


func _get_victory_banner_text(scenario_id: int) -> String:
	return VICTORY_BANNERS.get(scenario_id, "Victory is yours.")


func _get_defeat_banner_text(scenario_id: int) -> String:
	return DEFEAT_BANNERS.get(scenario_id, "Your scheme has failed.")
