extends CanvasLayer

## cascade_celebration.gd — "RUMOR WILDFIRE" burst overlay (SPA-850).
##
## Displayed when 3+ NPCs transition to BELIEVE for the same rumor in one day.
## Procedurally-built CanvasLayer (layer 16) with:
##   • Full-width amber banner: "RUMOR WILDFIRE — {count} new believers!"
##   • CPUParticles2D burst: 80–120 gold/amber particles (mirrors milestone_notifier pattern).
##   • SFX: AudioManager.milestone_chime (reused).
##   • Auto-dismiss after 3 seconds with fade.
##
## Usage from main.gd:
##   _cascade_celebration = preload("res://scripts/cascade_celebration.gd").new()
##   _cascade_celebration.name = "CascadeCelebration"
##   add_child(_cascade_celebration)
##   # Then connect world.cascade_triggered to _cascade_celebration.show_cascade()

# ── Palette ───────────────────────────────────────────────────────────────────

const C_BG       := Color(0.18, 0.10, 0.01, 0.95)   # deep amber-brown background
const C_BORDER   := Color(0.95, 0.68, 0.08, 1.0)    # bright gold border
const C_TITLE    := Color(1.00, 0.82, 0.20, 1.0)    # warm gold title text
const C_BODY     := Color(0.98, 0.92, 0.70, 1.0)    # cream body text
const C_PARTICLE := Color(0.95, 0.72, 0.10, 0.90)   # gold/amber particle colour

# ── Layout ────────────────────────────────────────────────────────────────────

const POPUP_W    := 560
const POPUP_H    := 96
const POPUP_Y    := 148   # below any milestone popup at y=76
const VW         := 1280

const PARTICLE_MIN := 80
const PARTICLE_MAX := 120

const AUTO_DISMISS := 3.0   # seconds before fade-out

# ── State ─────────────────────────────────────────────────────────────────────

var _popup_root:    Control = null
var _dismiss_tween: Tween   = null


func _ready() -> void:
	layer = 16


## Show the cascade banner for the given rumor and believer count.
## Called directly from main.gd's _on_cascade_triggered handler.
func show_cascade(believer_count: int) -> void:
	# Dismiss any current popup immediately before showing the new one.
	if is_instance_valid(_popup_root):
		if _dismiss_tween != null and _dismiss_tween.is_valid():
			_dismiss_tween.kill()
		_popup_root.queue_free()
		_popup_root = null

	# ── SFX ─────────────────────────────────────────────────────────────────
	AudioManager.play_sfx("milestone_chime")

	# ── Build banner ────────────────────────────────────────────────────────
	_popup_root = _build_banner(believer_count)
	add_child(_popup_root)

	# ── Particle burst ──────────────────────────────────────────────────────
	var particle_count: int = PARTICLE_MIN + randi() % (PARTICLE_MAX - PARTICLE_MIN + 1)
	_spawn_particles(particle_count)

	# ── Animate in: fade + slide down ───────────────────────────────────────
	var target_y := float(POPUP_Y)
	_popup_root.modulate.a = 0.0
	_popup_root.position.y = target_y - 16.0
	var tw_in := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(_popup_root, "modulate:a", 1.0, 0.25)
	tw_in.tween_property(_popup_root, "position:y", target_y, 0.25)

	# ── Auto-dismiss ────────────────────────────────────────────────────────
	_dismiss_tween = create_tween()
	_dismiss_tween.tween_interval(AUTO_DISMISS)
	_dismiss_tween.tween_callback(_dismiss)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_banner(believer_count: int) -> Control:
	var popup_x := float((VW - POPUP_W) / 2)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position     = Vector2(0.0, 0.0)

	# Background card
	var bg := ColorRect.new()
	bg.color    = C_BG
	bg.position = Vector2(popup_x, float(POPUP_Y))
	bg.size     = Vector2(float(POPUP_W), float(POPUP_H))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# Amber border — top stripe
	var border_top := ColorRect.new()
	border_top.color    = C_BORDER
	border_top.position = bg.position
	border_top.size     = Vector2(float(POPUP_W), 3.0)
	border_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border_top)

	# Amber border — bottom stripe
	var border_bot := ColorRect.new()
	border_bot.color    = C_BORDER
	border_bot.position = bg.position + Vector2(0.0, float(POPUP_H) - 3.0)
	border_bot.size     = Vector2(float(POPUP_W), 3.0)
	border_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border_bot)

	# Badge "🔥  RUMOR WILDFIRE  🔥"
	var badge := Label.new()
	badge.text                 = "RUMOR WILDFIRE"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", C_BORDER)
	badge.add_theme_constant_override("outline_size", 1)
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	badge.position     = bg.position + Vector2(0.0, 9.0)
	badge.size         = Vector2(float(POPUP_W), 16.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(badge)

	# Divider
	var div := ColorRect.new()
	div.color    = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.35)
	div.position = bg.position + Vector2(40.0, 28.0)
	div.size     = Vector2(float(POPUP_W) - 80.0, 1.0)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(div)

	# Main text
	var body := Label.new()
	body.text                 = "%d new believers today!" % believer_count
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", C_TITLE)
	body.add_theme_constant_override("outline_size", 2)
	body.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	body.position     = bg.position + Vector2(24.0, 34.0)
	body.size         = Vector2(float(POPUP_W) - 48.0, 46.0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)

	return root


# ── Dismiss ───────────────────────────────────────────────────────────────────

func _dismiss() -> void:
	if not is_instance_valid(_popup_root):
		_popup_root = null
		return
	var tw_out := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_out.tween_property(_popup_root, "modulate:a", 0.0, 0.35)
	tw_out.tween_property(_popup_root, "position:y", _popup_root.position.y - 14.0, 0.35)
	tw_out.chain().tween_callback(func() -> void:
		if is_instance_valid(_popup_root):
			_popup_root.queue_free()
		_popup_root = null
	)


# ── Particle burst ────────────────────────────────────────────────────────────

func _spawn_particles(count: int) -> void:
	var particles := CPUParticles2D.new()
	particles.position             = Vector2(float(VW) / 2.0, float(POPUP_Y) + float(POPUP_H) / 2.0)
	particles.emitting             = true
	particles.one_shot             = true
	particles.amount               = count
	particles.lifetime             = 1.8
	particles.explosiveness        = 0.90
	particles.spread               = 140.0
	particles.gravity              = Vector2(0.0, 100.0)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 240.0
	particles.scale_amount_min     = 3.0
	particles.scale_amount_max     = 6.0
	particles.color                = C_PARTICLE
	add_child(particles)

	get_tree().create_timer(particles.lifetime + 0.6).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)
