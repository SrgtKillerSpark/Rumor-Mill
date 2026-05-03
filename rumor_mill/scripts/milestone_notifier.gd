extends CanvasLayer

## milestone_notifier.gd — Styled popup card for narrative milestone moments (SPA-709).
##
## Procedurally-built CanvasLayer (layer 18) that displays a parchment-themed popup
## card when MilestoneTracker fires a milestone.  Features:
##   • Queue-based display: one card at a time, auto-dismissed after 4 seconds.
##   • Parchment card styling matching the manuscript UI palette.
##   • CPUParticles2D celebration burst.
##   • SFX playback via AudioManager.milestone_chime.
##   • Optional bonus reward (bribe charge / whisper token) applied from milestones.json.
##   • Journal logging via journal.push_milestone_event().
##
## Usage from main.gd:
##   _milestone_notifier = preload("res://scripts/milestone_notifier.gd").new()
##   _milestone_notifier.name = "MilestoneNotifier"
##   add_child(_milestone_notifier)
##   _milestone_notifier.setup(journal_ref, intel_store_ref)
##   world.milestone_tracker.setup(..., _milestone_notifier.show_milestone)

# ── Palette ───────────────────────────────────────────────────────────────────

const C_BG         := Color(0.10, 0.07, 0.04, 0.96)  # dark parchment background
const C_BORDER     := Color(0.72, 0.56, 0.18, 1.0)   # gold border
const C_BADGE      := Color(0.92, 0.78, 0.12, 1.0)   # gold badge text
const C_REWARD     := Color(0.70, 0.95, 0.45, 1.0)   # bright green reward
const C_REWARD_BG  := Color(0.08, 0.18, 0.04, 0.92)  # dark green reward pill bg

# ── Layout constants ──────────────────────────────────────────────────────────

const POPUP_W       := 480
const POPUP_H_BASE  := 108   # height without reward pill
const POPUP_H_FULL  := 134   # height with reward pill
const POPUP_Y       := 76    # distance from top of screen
const VW            := 1280
const PARTICLE_CNT  := 28
const AUTO_DISMISS  := 4.0   # seconds before fade-out begins

# ── Particle scaling by progress threshold (SPA-786) ─────────────────────────
# Maps progress-toast milestone IDs to scaled particle counts.
const PROGRESS_PARTICLE_MAP: Dictionary = {
	"progress_toast_25": 28,
	"progress_toast_50": 40,
	"progress_toast_75": 60,
}

# ── Golden vignette flash (SPA-786) ──────────────────────────────────────────
const C_VIGNETTE := Color(0.92, 0.78, 0.18, 0.45)  # translucent gold

# ── State ─────────────────────────────────────────────────────────────────────

var _journal_ref:    CanvasLayer      = null
var _intel_ref:      PlayerIntelStore = null
var _milestones:     Dictionary       = {}   ## milestone_id → data from milestones.json
var _queue:          Array            = []   ## Array[Dictionary] {text, color, id}
var _showing:        bool             = false
var _popup_root:     Control          = null
var _dismiss_tween:  Tween            = null
var _vignette_rect:  ColorRect        = null  ## SPA-786: golden vignette overlay
var _vignette_tween: Tween            = null
## Optional reference to ObjectiveHUD for flashing progress text (SPA-786).
var _objective_hud:  CanvasLayer      = null


func _ready() -> void:
	layer = 18
	_load_milestones_json()
	_build_vignette_overlay()


## Called from main.gd after journal and world systems are ready.
func setup(journal: CanvasLayer, intel_store: PlayerIntelStore, obj_hud: CanvasLayer = null) -> void:
	_journal_ref    = journal
	_intel_ref      = intel_store
	_objective_hud  = obj_hud


## Callback for MilestoneTracker.setup().  Signature: (text, color, id).
## When milestone_id is empty the popup still shows but no reward is applied.
func show_milestone(text: String, color: Color, milestone_id: String = "") -> void:
	_queue.append({"text": text, "color": color, "id": milestone_id})
	if not _showing:
		_show_next()


# ── Queue processing ──────────────────────────────────────────────────────────

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var entry: Dictionary = _queue.pop_front()
	_display_popup(entry["text"], entry["color"], entry["id"])


func _display_popup(text: String, color: Color, milestone_id: String) -> void:
	# ── Look up reward ──────────────────────────────────────────────────────
	var reward_data: Dictionary = {}
	if not milestone_id.is_empty() and _milestones.has(milestone_id):
		var rd: Variant = _milestones[milestone_id]
		if rd is Dictionary:
			reward_data = (rd as Dictionary).get("reward", {})

	# ── Apply reward ────────────────────────────────────────────────────────
	var reward_text: String = ""
	if not reward_data.is_empty() and _intel_ref != null:
		var rtype:   String = str(reward_data.get("type",   ""))
		var ramount: int    = int(reward_data.get("amount", 1))
		match rtype:
			"bribe_charge":
				_intel_ref.bribe_charges += ramount
				reward_text = "+%d bribe charge%s" % [ramount, "s" if ramount > 1 else ""]
			"whisper_token":
				_intel_ref.whisper_tokens_remaining += ramount
				reward_text = "+%d whisper token%s" % [ramount, "s" if ramount > 1 else ""]

	# ── SFX ─────────────────────────────────────────────────────────────────
	AudioManager.play_event("objective_progress")

	# ── Log to journal ──────────────────────────────────────────────────────
	if _journal_ref != null and _journal_ref.has_method("push_milestone_event"):
		_journal_ref.push_milestone_event(text, color, reward_text)

	# ── Build popup UI ──────────────────────────────────────────────────────
	_popup_root = _build_popup(text, color, reward_text)
	add_child(_popup_root)

	# ── Celebration particles (SPA-786: scaled by progress milestone) ──────
	var particle_count: int = PROGRESS_PARTICLE_MAP.get(milestone_id, PARTICLE_CNT)
	_spawn_particles(color, particle_count)

	# ── Golden vignette flash on screen edges (SPA-786) ────────────────────
	_flash_vignette()

	# ── Flash objective card progress text (SPA-786) ───────────────────────
	_flash_objective_progress()

	# ── Animate in: fade + slide down from slightly above ──────────────────
	var target_y: float = float(POPUP_Y)
	_popup_root.modulate.a = 0.0
	_popup_root.position.y = target_y - 18.0
	var tw_in: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(_popup_root, "modulate:a", 1.0, 0.28)
	tw_in.tween_property(_popup_root, "position:y", target_y, 0.28)

	# ── Auto-dismiss timer ──────────────────────────────────────────────────
	if _dismiss_tween != null and _dismiss_tween.is_valid():
		_dismiss_tween.kill()
	_dismiss_tween = create_tween()
	_dismiss_tween.tween_interval(AUTO_DISMISS)
	_dismiss_tween.tween_callback(_dismiss_current)


func _dismiss_current() -> void:
	if not is_instance_valid(_popup_root):
		_popup_root = null
		_showing = false
		_show_next()
		return

	var tw_out: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_out.tween_property(_popup_root, "modulate:a", 0.0, 0.38)
	tw_out.tween_property(_popup_root, "position:y", _popup_root.position.y - 16.0, 0.38)
	tw_out.chain().tween_callback(func() -> void:
		if is_instance_valid(_popup_root):
			_popup_root.queue_free()
		_popup_root = null
		_show_next()
	)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_popup(text: String, color: Color, reward_text: String) -> Control:
	var has_reward: bool  = not reward_text.is_empty()
	var popup_h:    float = float(POPUP_H_FULL if has_reward else POPUP_H_BASE)
	var popup_x:    float = float((VW - POPUP_W) / 2)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position     = Vector2(0.0, 0.0)

	# Background card
	var bg := ColorRect.new()
	bg.color    = C_BG
	bg.position = Vector2(popup_x, float(POPUP_Y))
	bg.size     = Vector2(float(POPUP_W), popup_h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# Gold border — top stripe
	var border_top := ColorRect.new()
	border_top.color    = C_BORDER
	border_top.position = bg.position
	border_top.size     = Vector2(float(POPUP_W), 3.0)
	border_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border_top)

	# Gold border — bottom stripe
	var border_bot := ColorRect.new()
	border_bot.color    = C_BORDER
	border_bot.position = bg.position + Vector2(0.0, popup_h - 3.0)
	border_bot.size     = Vector2(float(POPUP_W), 3.0)
	border_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border_bot)

	# Badge "★  MILESTONE  ★"
	var badge := Label.new()
	badge.text                  = "★  MILESTONE  ★"
	badge.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", C_BADGE)
	badge.add_theme_constant_override("outline_size", 1)
	badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	badge.position  = bg.position + Vector2(0.0, 9.0)
	badge.size      = Vector2(float(POPUP_W), 18.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(badge)

	# Divider under badge
	var div := ColorRect.new()
	div.color    = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.35)
	div.position = bg.position + Vector2(40.0, 30.0)
	div.size     = Vector2(float(POPUP_W) - 80.0, 1.0)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(div)

	# Main milestone text
	var text_lbl := Label.new()
	text_lbl.text               = text
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_lbl.autowrap_mode      = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.add_theme_font_size_override("font_size", 17)
	text_lbl.add_theme_color_override("font_color", color)
	text_lbl.add_theme_constant_override("outline_size", 2)
	text_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	text_lbl.position    = bg.position + Vector2(24.0, 36.0)
	text_lbl.size        = Vector2(float(POPUP_W) - 48.0, 56.0)
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(text_lbl)

	# Reward pill
	if has_reward:
		var pill_w:  float = 200.0
		var pill_h:  float = 22.0
		var pill_x:  float = popup_x + (float(POPUP_W) - pill_w) / 2.0
		var pill_y:  float = float(POPUP_Y) + popup_h - 30.0

		var pill_bg := ColorRect.new()
		pill_bg.color    = C_REWARD_BG
		pill_bg.position = Vector2(pill_x, pill_y)
		pill_bg.size     = Vector2(pill_w, pill_h)
		pill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(pill_bg)

		var reward_lbl := Label.new()
		reward_lbl.text               = reward_text
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_lbl.add_theme_font_size_override("font_size", 13)
		reward_lbl.add_theme_color_override("font_color", C_REWARD)
		reward_lbl.add_theme_constant_override("outline_size", 1)
		reward_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
		reward_lbl.position    = pill_bg.position
		reward_lbl.size        = Vector2(pill_w, pill_h)
		reward_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(reward_lbl)

	return root


# ── Particle effect ───────────────────────────────────────────────────────────

func _spawn_particles(color: Color, count: int = PARTICLE_CNT) -> void:
	var particles := CPUParticles2D.new()
	# Emit from the top-center of the popup card.
	particles.position         = Vector2(float(VW) / 2.0, float(POPUP_Y) + float(POPUP_H_BASE) / 2.0)
	particles.emitting         = true
	particles.one_shot         = true
	particles.amount           = count
	particles.lifetime         = 1.6
	particles.explosiveness    = 0.88
	particles.spread           = 130.0
	particles.gravity          = Vector2(0.0, 95.0)
	particles.initial_velocity_min = 70.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 5.5
	particles.color            = Color(color.r, color.g, color.b, 0.88)
	add_child(particles)

	# Free the node after the burst completes.
	get_tree().create_timer(particles.lifetime + 0.6).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


# ── Golden vignette flash (SPA-786) ──────────────────────────────────────────

func _build_vignette_overlay() -> void:
	# A full-screen ColorRect with a radial-vignette shader for golden edge flash.
	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float u_alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec4  u_color : source_color = vec4(0.92, 0.78, 0.18, 0.45);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float edge = smoothstep(0.5, 1.2, dist);
	COLOR = vec4(u_color.rgb, edge * u_alpha * u_color.a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("u_alpha", 0.0)
	mat.set_shader_parameter("u_color", C_VIGNETTE)
	_vignette_rect.material = mat
	add_child(_vignette_rect)


func _flash_vignette() -> void:
	if _vignette_rect == null or _vignette_rect.material == null:
		return
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	var mat: ShaderMaterial = _vignette_rect.material as ShaderMaterial
	_vignette_tween = create_tween()
	_vignette_tween.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("u_alpha", v)
	, 0.0, 1.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_vignette_tween.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("u_alpha", v)
	, 1.0, 0.0, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


# ── Objective progress flash (SPA-786) ───────────────────────────────────────

func _flash_objective_progress() -> void:
	if _objective_hud == null:
		return
	if _objective_hud.has_method("flash_win_progress"):
		_objective_hud.flash_win_progress()


# ── JSON loading ──────────────────────────────────────────────────────────────

func _load_milestones_json() -> void:
	const PATH := "res://data/milestones.json"
	if not FileAccess.file_exists(PATH):
		push_warning("MilestoneNotifier: milestones.json not found at %s" % PATH)
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("MilestoneNotifier: could not open milestones.json")
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("MilestoneNotifier: milestones.json is malformed")
		return
	_milestones = (parsed as Dictionary).get("milestones", {})
