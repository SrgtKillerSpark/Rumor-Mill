extends CanvasLayer

## mission_card.gd — Non-blocking Mission Card shown at game start (SPA-812).
##
## Procedurally-built CanvasLayer (layer 17) that displays a parchment-themed
## card after the ReadyOverlay dismisses.  Shows three key lines:
##   • mission     — Primary Objective in plain mechanical terms
##   • winCondition — Key Constraint / win condition
##   • firstAction  — Core Action the player should take first
##
## Auto-dismisses after 8 seconds. Dismissable with any key. Non-blocking.
##
## Usage from main.gd:
##   _mission_card = preload("res://scripts/mission_card.gd").new()
##   _mission_card.name = "MissionCard"
##   add_child(_mission_card)
##   _mission_card.setup(scenario_manager.get_objective_card())

# ── Palette (matches milestone_notifier) ──────────────────────────────────────

const C_BG     := Color(0.10, 0.07, 0.04, 0.96)
const C_BORDER := Color(0.72, 0.56, 0.18, 1.0)
const C_BADGE  := Color(0.92, 0.78, 0.12, 1.0)   # gold header
const C_BODY   := Color(0.95, 0.88, 0.70, 1.0)   # warm parchment text
const C_LABEL  := Color(0.65, 0.55, 0.30, 1.0)   # muted section label
const C_ACTION := Color(0.60, 0.90, 0.50, 1.0)   # green first-action line

# ── Layout ────────────────────────────────────────────────────────────────────

const POPUP_W      := 540
const POPUP_H      := 168
const POPUP_Y      := 72.0
const VW           := 1280
const AUTO_DISMISS := 8.0
const PARTICLE_CNT := 22

# ── Signals ───────────────────────────────────────────────────────────────────

signal dismissed

# ── State ─────────────────────────────────────────────────────────────────────

var _popup_root:    Control = null
var _dismiss_tween: Tween   = null
var _is_dismissed:  bool    = false


func _ready() -> void:
	layer = 17


## Called from main.gd immediately after adding to the scene tree.
## card_data: the objectiveCard dict from scenarios.json.
func setup(card_data: Dictionary) -> void:
	var mission:    String = str(card_data.get("mission",      ""))
	var win_cond:   String = str(card_data.get("winCondition", ""))
	var first_act:  String = str(card_data.get("firstAction",  ""))

	_popup_root = _build_popup(mission, win_cond, first_act)
	add_child(_popup_root)
	_spawn_particles()

	# Animate in: fade + slide down.
	_popup_root.modulate.a  = 0.0
	_popup_root.position.y  = POPUP_Y - 18.0
	var tw_in := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(_popup_root, "modulate:a", 1.0, 0.30)
	tw_in.tween_property(_popup_root, "position:y", POPUP_Y, 0.30)

	# Auto-dismiss timer.
	_dismiss_tween = create_tween()
	_dismiss_tween.tween_interval(AUTO_DISMISS)
	_dismiss_tween.tween_callback(_dismiss)


## Any key press closes the card early.
func _input(event: InputEvent) -> void:
	if _is_dismissed:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		_dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_dismiss()
		get_viewport().set_input_as_handled()


func _dismiss() -> void:
	if _is_dismissed:
		return
	_is_dismissed = true
	if _dismiss_tween != null and _dismiss_tween.is_valid():
		_dismiss_tween.kill()
	if not is_instance_valid(_popup_root):
		dismissed.emit()
		queue_free()
		return
	var tw_out := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_out.tween_property(_popup_root, "modulate:a", 0.0, 0.32)
	tw_out.tween_property(_popup_root, "position:y", _popup_root.position.y - 14.0, 0.32)
	tw_out.chain().tween_callback(func() -> void:
		if is_instance_valid(_popup_root):
			_popup_root.queue_free()
		dismissed.emit()
		queue_free()
	)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_popup(mission: String, win_cond: String, first_act: String) -> Control:
	var popup_x: float = float((VW - POPUP_W) / 2)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position     = Vector2(0.0, 0.0)

	# Background card.
	var bg := ColorRect.new()
	bg.color        = C_BG
	bg.position     = Vector2(popup_x, POPUP_Y)
	bg.size         = Vector2(float(POPUP_W), float(POPUP_H))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# Gold border — top stripe.
	var border_top := ColorRect.new()
	border_top.color        = C_BORDER
	border_top.position     = bg.position
	border_top.size         = Vector2(float(POPUP_W), 3.0)
	border_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border_top)

	# Gold border — bottom stripe.
	var border_bot := ColorRect.new()
	border_bot.color        = C_BORDER
	border_bot.position     = bg.position + Vector2(0.0, float(POPUP_H) - 3.0)
	border_bot.size         = Vector2(float(POPUP_W), 3.0)
	border_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border_bot)

	# Header badge.
	var badge := Label.new()
	badge.text                 = "⚔  MISSION BRIEFING  ⚔"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", C_BADGE)
	badge.add_theme_constant_override("outline_size", 1)
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	badge.position     = bg.position + Vector2(0.0, 8.0)
	badge.size         = Vector2(float(POPUP_W), 18.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(badge)

	# Divider under badge.
	var div := ColorRect.new()
	div.color        = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.35)
	div.position     = bg.position + Vector2(32.0, 28.0)
	div.size         = Vector2(float(POPUP_W) - 64.0, 1.0)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(div)

	# Three content rows.
	var row_y: float = bg.position.y + 34.0
	_add_row(root, popup_x, row_y, "OBJECTIVE", mission, C_BODY)
	row_y += 40.0
	_add_row(root, popup_x, row_y, "WIN WHEN", win_cond, C_BODY)
	row_y += 40.0
	_add_row(root, popup_x, row_y, "FIRST MOVE", first_act, C_ACTION)

	# Dismiss hint.
	var hint := Label.new()
	hint.text                 = "press any key to dismiss"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.45))
	hint.position     = bg.position + Vector2(0.0, float(POPUP_H) - 16.0)
	hint.size         = Vector2(float(POPUP_W), 14.0)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	return root


func _add_row(root: Control, popup_x: float, y: float, label_text: String, body_text: String, body_color: Color) -> void:
	var pad_x: float = 20.0

	var lbl := Label.new()
	lbl.text                 = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", C_LABEL)
	lbl.position     = Vector2(popup_x + pad_x, y)
	lbl.size         = Vector2(float(POPUP_W) - pad_x * 2.0, 13.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)

	var body := Label.new()
	body.text                 = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", body_color)
	body.add_theme_constant_override("outline_size", 1)
	body.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	body.position     = Vector2(popup_x + pad_x, y + 13.0)
	body.size         = Vector2(float(POPUP_W) - pad_x * 2.0, 24.0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)


# ── Particle effect ───────────────────────────────────────────────────────────

func _spawn_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.position             = Vector2(float(VW) / 2.0, POPUP_Y + float(POPUP_H) / 2.0)
	particles.emitting             = true
	particles.one_shot             = true
	particles.amount               = PARTICLE_CNT
	particles.lifetime             = 1.6
	particles.explosiveness        = 0.85
	particles.spread               = 120.0
	particles.gravity              = Vector2(0.0, 80.0)
	particles.initial_velocity_min = 55.0
	particles.initial_velocity_max = 170.0
	particles.scale_amount_min     = 2.0
	particles.scale_amount_max     = 4.5
	particles.color                = Color(C_BADGE.r, C_BADGE.g, C_BADGE.b, 0.80)
	add_child(particles)
	get_tree().create_timer(particles.lifetime + 0.6).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)
