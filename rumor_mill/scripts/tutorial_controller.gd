extends Node

## tutorial_controller.gd — Guided onboarding tutorial for all scenarios
## (SPA-775, SPA-804, SPA-835).
##
## Scenario 1 (7 steps): streamlined action-gated tutorial for first-time
## players.  Merged from the original 12-step sequence to reduce checkbox
## fatigue while preserving the core Observe → Eavesdrop → Craft → Spread loop.
## Scenarios 2-6 (2-3 steps each): short "What's New" banner sequence showing
## the unique mechanic for that scenario.  Steps auto-advance when each banner
## dismisses (no blocking).
##
## S1 Step sequence (SPA-835):
##   0  gtut_opening        — cinematic intro banner (auto 3 s)
##   1  gtut_explore         — gate: read_the_room_shown (pan + right-click)
##   2  gtut_observe_intel   — gate: journal opened (observe + check journal)
##   3  gtut_eavesdrop       — gate: eavesdrop action
##   4  gtut_craft_rumor     — gate: rumor_seeded (subject + claim + seed)
##   5  gtut_watch_spread    — gate: NPC reaches BELIEVE state
##   6  gtut_complete        — auto-dismiss 8 s, confetti, tutorial ends
##
## S2-S6 steps are short auto-dismiss sequences; see STEPS_S2..STEPS_S6 below.
##
## When guided_tutorial_active is true, non-guided contextual hints are suppressed
## so the player sees only the step sequence.
##
## Usage from main.gd:
##   var tc := preload("res://scripts/tutorial_controller.gd").new()
##   tc.name = "TutorialController"
##   add_child(tc)
##   tc.setup(tutorial_sys, tutorial_banner, camera, recon_ctrl, journal,
##            rumor_panel, world, "scenario_2")
##   tc.start()

class_name TutorialController

## Emitted when a tutorial step is completed (dismissed or action-gated).
## Used by AnalyticsManager to log tutorial_step_completed events (SPA-1241).
signal step_completed(step_id: String, scenario_id: String)

# ── Step definitions ─────────────────────────────────────────────────────────

## Scenario 1 — 7-step action-gated tutorial (SPA-835).
const STEPS_S1: Array = [
	{ "id": "gtut_opening",        "hint": "gtut_opening" },
	{ "id": "gtut_explore",        "hint": "gtut_explore" },
	{ "id": "gtut_observe_intel",  "hint": "gtut_observe_intel" },
	{ "id": "gtut_eavesdrop",      "hint": "gtut_eavesdrop" },
	{ "id": "gtut_craft_rumor",    "hint": "gtut_craft_rumor" },
	{ "id": "gtut_watch_spread",   "hint": "gtut_watch_spread" },
	{ "id": "gtut_complete",       "hint": "gtut_complete" },
]

## Scenario 2 — Plague Scare: mechanic shift + Maren warning (3 steps).
const STEPS_S2: Array = [
	{ "id": "wtut_s2_mechanic_shift", "hint": "wtut_s2_mechanic_shift" },
	{ "id": "wtut_s2_whats_new",      "hint": "wtut_s2_whats_new" },
	{ "id": "ctx_s2_maren_warning",   "hint": "ctx_s2_maren_warning" },
]

## Scenario 3 — Succession: two targets + rival agent (3 steps).
const STEPS_S3: Array = [
	{ "id": "wtut_s3_whats_new",   "hint": "wtut_s3_whats_new" },
	{ "id": "ctx_s3_dual_targets", "hint": "ctx_s3_dual_targets" },
	{ "id": "ctx_s3_rival_intro",  "hint": "ctx_s3_rival_intro" },
]

## Scenario 4 — Holy Inquisition: defense goal + inquisitor (3 steps).
const STEPS_S4: Array = [
	{ "id": "wtut_s4_whats_new",        "hint": "wtut_s4_whats_new" },
	{ "id": "ctx_s4_defense_goal",      "hint": "ctx_s4_defense_goal" },
	{ "id": "ctx_s4_inquisitor_info",   "hint": "ctx_s4_inquisitor_info" },
]

## Scenario 5 — Election: three-way race (2 steps).
const STEPS_S5: Array = [
	{ "id": "wtut_s5_whats_new",      "hint": "wtut_s5_whats_new" },
	{ "id": "ctx_s5_three_way_race",  "hint": "ctx_s5_three_way_race" },
]

## Scenario 6 — Merchant's Debt: heat ceiling + protect Marta (2 steps).
const STEPS_S6: Array = [
	{ "id": "wtut_s6_whats_new",   "hint": "wtut_s6_whats_new" },
	{ "id": "ctx_s6_heat_ceiling", "hint": "ctx_s6_heat_ceiling" },
]

## Legacy alias — external callers that referenced STEPS still work.
const STEPS: Array = STEPS_S1

const STEP_OPENING       := 0
const STEP_EXPLORE       := 1
const STEP_OBSERVE_INTEL := 2
const STEP_EAVESDROP     := 3
const STEP_CRAFT_RUMOR   := 4
const STEP_WATCH_SPREAD  := 5
const STEP_COMPLETE      := 6

# ── State ────────────────────────────────────────────────────────────────────

var _current_step: int = -1
var _active: bool = false
var _skipped: bool = false
var _scenario_id: String = "scenario_1"
## Active step array — set by setup() based on scenario_id.
var _steps: Array = []
## When true the player is in the guided tutorial and non-guided
## contextual hints are suppressed.  Only true during S1 (7-step gated tutorial).
var guided_tutorial_active: bool = false
## Name of the NPC the player just seeded a rumor on (for celebration pan).
var _last_seed_target_name: String = ""

# ── External references ───────────────────────────────────────────────────────

var _tutorial_sys:    TutorialSystem = null
var _tutorial_banner: Node           = null
var _camera:          Camera2D       = null
var _recon_ctrl:      Node           = null
var _journal:         CanvasLayer    = null
var _rumor_panel:     CanvasLayer    = null
var _world:           Node2D         = null

# ── Skip overlay ─────────────────────────────────────────────────────────────

var _skip_overlay:    CanvasLayer    = null
var _skip_shown:      bool           = false

# ── Highlight overlay ─────────────────────────────────────────────────────────

var _highlight_node:  Node2D         = null  # node currently highlighted
var _highlight_tween: Tween          = null

# ── SPA-881: Persistent target NPC marker ────────────────────────────────────
## Gold "▼ TARGET" label added as a child of the primary target NPC so it
## follows them automatically.  Visible from tutorial start until completion.
var _target_marker_label: Label      = null
var _target_marker_tween: Tween      = null

# ── Top-centre toast ──────────────────────────────────────────────────────────

var _toast_canvas:    CanvasLayer    = null
var _toast_label:     Label          = null
var _toast_tween:     Tween          = null


## Wire all external dependencies.  Must be called before start().
## scenario_id selects the step sequence: "scenario_1" (default) = 7-step gated
## tutorial; "scenario_2".."scenario_6" = short What's-New auto-dismiss sequence.
func setup(
		tutorial_sys: TutorialSystem,
		tutorial_banner: Node,
		cam: Camera2D,
		recon_ctrl: Node,
		journal_node: CanvasLayer,
		rumor_panel_node: CanvasLayer,
		world_node: Node2D,
		scenario_id: String = "scenario_1"
) -> void:
	_tutorial_sys    = tutorial_sys
	_tutorial_banner = tutorial_banner
	_camera          = cam
	_recon_ctrl      = recon_ctrl
	_journal         = journal_node
	_rumor_panel     = rumor_panel_node
	_world           = world_node
	_scenario_id     = scenario_id

	match _scenario_id:
		"scenario_2": _steps = STEPS_S2
		"scenario_3": _steps = STEPS_S3
		"scenario_4": _steps = STEPS_S4
		"scenario_5": _steps = STEPS_S5
		"scenario_6": _steps = STEPS_S6
		_:            _steps = STEPS_S1

	# Connect banner's hint_dismissed for auto-advance of non-action-gated steps.
	if _tutorial_banner != null and _tutorial_banner.has_signal("hint_dismissed"):
		if not _tutorial_banner.hint_dismissed.is_connected(_on_banner_hint_dismissed):
			_tutorial_banner.hint_dismissed.connect(_on_banner_hint_dismissed)

	_build_toast()


## Begin the interactive tutorial.
## S2-S6 always begin immediately (no skip dialog — the sequence is short and
## informational only, so returning players benefit from it too).
func start() -> void:
	if _tutorial_sys == null or _tutorial_banner == null:
		return
	if _scenario_id == "scenario_1" and SaveManager.has_any_save() and not SaveManager.session_was_loaded():
		_show_skip_option()
	else:
		_begin_tutorial()


## Force-skip the tutorial.
func skip() -> void:
	_skipped = true
	_active = false
	guided_tutorial_active = false
	_current_step = _steps.size()
	for step_def in _steps:
		if _tutorial_sys != null:
			_tutorial_sys.mark_seen(step_def["id"])
	_clear_highlight()
	_remove_target_marker()
	_disconnect_all()
	if _skip_overlay != null:
		_skip_overlay.queue_free()
		_skip_overlay = null


# ── Skip option UI ───────────────────────────────────────────────────────────

const C_SKIP_BG      := Color(0.06, 0.04, 0.02, 0.85)
const C_SKIP_BORDER  := Color(0.55, 0.38, 0.18, 1.0)
const C_SKIP_HEADING := Color(0.92, 0.78, 0.12, 1.0)
const C_SKIP_BODY    := Color(0.80, 0.72, 0.55, 1.0)
const C_BTN_NORMAL   := Color(0.35, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.55, 0.35, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.92, 0.82, 0.60, 1.0)

func _show_skip_option() -> void:
	if _skip_shown:
		return
	_skip_shown = true

	_skip_overlay = CanvasLayer.new()
	_skip_overlay.layer = 21
	add_child(_skip_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.02, 0.01, 0.70)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_overlay.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220
	panel.offset_top = -100
	panel.offset_right = 220
	panel.offset_bottom = 100
	var style := StyleBoxFlat.new()
	style.bg_color = C_SKIP_BG
	style.border_color = C_SKIP_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	_skip_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Interactive Tutorial"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", C_SKIP_HEADING)
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var body := Label.new()
	body.text = "Would you like to play the guided tutorial?\nIt walks you through the core mechanics step by step."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", C_SKIP_BODY)
	body.add_theme_font_size_override("font_size", 13)
	vbox.add_child(body)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var play_btn := _make_button("  Play Tutorial  ")
	play_btn.pressed.connect(_on_play_tutorial)
	btn_row.add_child(play_btn)

	var skip_btn := _make_button("  Skip  ")
	skip_btn.pressed.connect(_on_skip_tutorial)
	btn_row.add_child(skip_btn)

	play_btn.call_deferred("grab_focus")


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 34)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	btn.add_theme_color_override("font_hover_color", C_BTN_TEXT)
	btn.add_theme_color_override("font_pressed_color", C_BTN_TEXT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN_NORMAL
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_HOVER
	hover.set_corner_radius_all(4)
	hover.content_margin_left = 12.0
	hover.content_margin_right = 12.0
	hover.content_margin_top = 6.0
	hover.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn


func _on_play_tutorial() -> void:
	if _skip_overlay != null:
		_skip_overlay.queue_free()
		_skip_overlay = null
	_begin_tutorial()


func _on_skip_tutorial() -> void:
	skip()


# ── Tutorial flow ────────────────────────────────────────────────────────────

func _begin_tutorial() -> void:
	_active = true
	# Only suppress contextual hints during the full S1 gated tutorial.
	guided_tutorial_active = (_scenario_id == "scenario_1")
	_current_step = -1
	_connect_signals()
	_show_target_marker()
	_advance_step()


func _advance_step() -> void:
	if not _active:
		return
	_current_step += 1
	if _current_step >= _steps.size():
		_finish_tutorial()
		return
	_show_step(_current_step)


func _show_step(step_idx: int) -> void:
	var step_def: Dictionary = _steps[step_idx]
	var step_id: String = step_def["id"]

	if _tutorial_sys != null and _tutorial_sys.has_seen(step_id):
		_advance_step()
		return

	AudioManager.play_sfx_pitched("milestone_chime", 1.25)
	_apply_step_highlights(step_idx)

	if _tutorial_banner != null and _tutorial_banner.has_method("queue_hint"):
		_tutorial_banner.queue_hint(step_def["hint"])


func _apply_step_highlights(step_idx: int) -> void:
	_clear_highlight()
	match step_idx:
		STEP_EXPLORE:
			# Highlight the closest building (use first world building if available).
			if _world != null and _world.get("buildings") != null:
				var buildings: Array = _world.buildings
				if not buildings.is_empty():
					set_tutorial_highlight(buildings[0])
		STEP_EAVESDROP:
			# Highlight the first NPC in the world as the eavesdrop target.
			if _world != null and _world.get("npcs") != null:
				var npcs: Array = _world.npcs
				if not npcs.is_empty():
					set_tutorial_highlight(npcs[0])
		_:
			pass  # no highlight for other steps


func _finish_tutorial() -> void:
	_active = false
	guided_tutorial_active = false
	_disconnect_all()
	_clear_highlight()
	_remove_target_marker()


func _complete_current_step() -> void:
	if not _active or _current_step < 0 or _current_step >= _steps.size():
		return
	var step_def: Dictionary = _steps[_current_step]
	step_completed.emit(step_def["id"], _scenario_id)
	if _tutorial_sys != null:
		_tutorial_sys.mark_seen(step_def["id"])
	if _tutorial_banner != null and _tutorial_banner.has_method("dismiss_hint"):
		_tutorial_banner.dismiss_hint(step_def["hint"])
	_clear_highlight()

	# Juice on step 4: first rumor seeded — toast + camera pan to target NPC.
	if _current_step == STEP_CRAFT_RUMOR:
		_celebrate_first_rumor()

	# Juice on step 5: first NPC believes — brief camera focus + toast.
	if _current_step == STEP_WATCH_SPREAD:
		_celebrate_first_believe()

	_advance_step()


## Auto-advance handler connected to TutorialBanner.hint_dismissed.
## When a banner hint has no action_gate (auto-dismiss or manual X), the
## controller advances to the next step once the hint finishes dismissing.
## Action-gated S1 steps are handled by their own signal handlers and call
## _complete_current_step() directly, which already advances; by the time
## _finish_dismiss() fires for those, _current_step has moved on so the
## check below will not match and will not double-advance.
func _on_banner_hint_dismissed(hint_id: String) -> void:
	if not _active or _current_step < 0 or _current_step >= _steps.size():
		return
	var step_def: Dictionary = _steps[_current_step]
	if step_def["hint"] == hint_id:
		step_completed.emit(step_def["id"], _scenario_id)
		_advance_step()


# ── Highlight system ─────────────────────────────────────────────────────────

## Apply a gold pulse highlight to a Node2D (building or NPC).
## Call clear_tutorial_highlight() to remove it before the next step.
func set_tutorial_highlight(node: Node2D) -> void:
	_clear_highlight()
	if node == null or not is_instance_valid(node):
		return
	_highlight_node = node
	# Pulse between normal and a bright gold modulate.
	_highlight_tween = node.create_tween()
	_highlight_tween.set_loops()
	_highlight_tween.tween_property(node, "modulate",
		Color(1.6, 1.4, 0.5, 1.0), 0.55).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(node, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.55).set_ease(Tween.EASE_IN_OUT)


func _clear_highlight() -> void:
	if _highlight_tween != null and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = null
	if _highlight_node != null and is_instance_valid(_highlight_node):
		_highlight_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_highlight_node = null


# ── SPA-881: Persistent target NPC marker ────────────────────────────────────

## Map of scenario → primary target NPC id(s) for the marker.
const _TARGET_NPC_IDS: Dictionary = {
	"scenario_1": ["edric_fenn"],
}

## Find the world NPC node matching the given npc_data id.
func _find_npc_by_id(npc_id: String) -> Node2D:
	if _world == null or _world.get("npcs") == null:
		return null
	for npc in _world.npcs:
		if npc.npc_data.get("id", "") == npc_id:
			return npc
	return null


## Place a pulsing "▼ TARGET" label above the primary target NPC.
func _show_target_marker() -> void:
	var ids: Array = _TARGET_NPC_IDS.get(_scenario_id, [])
	if ids.is_empty():
		return
	var target_npc: Node2D = _find_npc_by_id(ids[0])
	if target_npc == null:
		return

	_target_marker_label = Label.new()
	_target_marker_label.text = "▼ TARGET"
	_target_marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_marker_label.add_theme_font_size_override("font_size", 11)
	_target_marker_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.40, 1.0))
	_target_marker_label.add_theme_constant_override("outline_size", 3)
	_target_marker_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	# Position above the NPC sprite; offset upward.
	_target_marker_label.position = Vector2(-30, -55)
	_target_marker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_npc.add_child(_target_marker_label)

	# Gentle pulse between full and half alpha.
	_target_marker_tween = _target_marker_label.create_tween()
	_target_marker_tween.set_loops()
	_target_marker_tween.tween_property(
		_target_marker_label, "modulate:a", 0.45, 0.8
	).set_ease(Tween.EASE_IN_OUT)
	_target_marker_tween.tween_property(
		_target_marker_label, "modulate:a", 1.0, 0.8
	).set_ease(Tween.EASE_IN_OUT)


## Remove the persistent target marker.
func _remove_target_marker() -> void:
	if _target_marker_tween != null and _target_marker_tween.is_valid():
		_target_marker_tween.kill()
	_target_marker_tween = null
	if _target_marker_label != null and is_instance_valid(_target_marker_label):
		_target_marker_label.queue_free()
	_target_marker_label = null


# ── Top-centre toast ──────────────────────────────────────────────────────────

func _build_toast() -> void:
	_toast_canvas = CanvasLayer.new()
	_toast_canvas.layer = 22
	add_child(_toast_canvas)

	_toast_label = Label.new()
	_toast_label.anchor_left   = 0.5
	_toast_label.anchor_top    = 0.0
	_toast_label.anchor_right  = 0.5
	_toast_label.anchor_bottom = 0.0
	_toast_label.offset_left   = -300
	_toast_label.offset_right  = 300
	_toast_label.offset_top    = 28
	_toast_label.offset_bottom = 60
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.40, 1.0))
	_toast_label.add_theme_constant_override("outline_size", 3)
	_toast_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.modulate.a = 0.0
	_toast_canvas.add_child(_toast_label)


func _show_toast(text: String, duration: float = 2.0) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


# ── Celebration (step 4: first rumor seeded) ──────────────────────────────────

func _celebrate_first_rumor() -> void:
	AudioManager.play_sfx("rumor_success")
	var target_label := _last_seed_target_name if _last_seed_target_name != "" else "NPC"
	_show_toast("Rumor planted! Watch %s's thought bubble..." % target_label, 4.0)
	# Camera pan to the target NPC so the player sees the rumor arrive.
	# Brief 0.3 s delay so the toast registers before the camera moves.
	if _camera != null and _world != null and _last_seed_target_name != "":
		get_tree().create_timer(0.3).timeout.connect(func() -> void:
			if not is_instance_valid(_camera) or not is_instance_valid(_world):
				return
			for npc in _world.npcs:
				if npc.npc_data.get("name", "") == _last_seed_target_name:
					if _camera.has_method("pan_to_target"):
						_camera.pan_to_target(npc.global_position, 1.2)
					break
		)


# ── Celebration (step 5: first NPC believes) ─────────────────────────────────

func _celebrate_first_believe() -> void:
	_show_toast("They believe it!", 2.5)
	# Brief camera focus on the NPC that triggered the belief, if findable.
	if _camera != null and _camera.has_method("shake_screen"):
		_camera.shake_screen(4.0, 0.3)
	# Particle burst: spawn simple CPUParticles2D at screen centre in world space.
	if _camera != null and _world != null:
		_spawn_celebrate_particles()


func _spawn_celebrate_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 40
	particles.lifetime = 1.2
	particles.speed_scale = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 120.0
	particles.gravity = Vector2(0, 120)
	particles.initial_velocity_min = 180.0
	particles.initial_velocity_max = 320.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = Color(0.96, 0.84, 0.40, 1.0)
	# Place at camera position in world coords.
	particles.global_position = _camera.global_position
	_world.add_child(particles)
	# Auto-free after animation completes.
	var t := particles.create_tween()
	t.tween_interval(2.5)
	t.tween_callback(particles.queue_free)


# ── Signal connections ───────────────────────────────────────────────────────

var _connected_read_the_room: bool = false
var _connected_recon:         bool = false
var _connected_journal:       bool = false
var _connected_rumor_seeded:  bool = false
var _connected_npc_states:    bool = false


func _connect_signals() -> void:
	# Step 1 (explore): right-click a building to read the room.
	if _recon_ctrl != null and _recon_ctrl.has_signal("read_the_room_shown") \
			and not _connected_read_the_room:
		_recon_ctrl.read_the_room_shown.connect(_on_tc_read_the_room)
		_connected_read_the_room = true

	# Step 2 (observe_intel): journal opened after observing.
	if _journal != null and not _connected_journal:
		_journal.visibility_changed.connect(_on_tc_journal_visibility)
		_connected_journal = true

	# Step 3 (eavesdrop): eavesdrop action performed.
	if _recon_ctrl != null and _recon_ctrl.has_signal("action_performed") \
			and not _connected_recon:
		_recon_ctrl.action_performed.connect(_on_tc_recon_action)
		_connected_recon = true

	# Step 4 (craft_rumor): rumor seeded (covers subject + claim + seed).
	if _rumor_panel != null and _rumor_panel.has_signal("rumor_seeded") \
			and not _connected_rumor_seeded:
		_rumor_panel.rumor_seeded.connect(_on_tc_rumor_seeded)
		_connected_rumor_seeded = true

	# Step 5 (watch_spread): NPC reaches BELIEVE.
	if _world != null and not _connected_npc_states:
		for npc in _world.npcs:
			if npc.has_signal("rumor_state_changed"):
				npc.rumor_state_changed.connect(_on_tc_rumor_state_changed)
		_connected_npc_states = true


func _disconnect_all() -> void:
	if _tutorial_banner != null and _tutorial_banner.has_signal("hint_dismissed"):
		if _tutorial_banner.hint_dismissed.is_connected(_on_banner_hint_dismissed):
			_tutorial_banner.hint_dismissed.disconnect(_on_banner_hint_dismissed)

	if _connected_read_the_room and _recon_ctrl != null \
			and _recon_ctrl.has_signal("read_the_room_shown"):
		if _recon_ctrl.read_the_room_shown.is_connected(_on_tc_read_the_room):
			_recon_ctrl.read_the_room_shown.disconnect(_on_tc_read_the_room)
	_connected_read_the_room = false

	if _connected_journal and _journal != null:
		if _journal.visibility_changed.is_connected(_on_tc_journal_visibility):
			_journal.visibility_changed.disconnect(_on_tc_journal_visibility)
	_connected_journal = false

	if _connected_recon and _recon_ctrl != null \
			and _recon_ctrl.has_signal("action_performed"):
		if _recon_ctrl.action_performed.is_connected(_on_tc_recon_action):
			_recon_ctrl.action_performed.disconnect(_on_tc_recon_action)
	_connected_recon = false

	if _connected_rumor_seeded and _rumor_panel != null \
			and _rumor_panel.has_signal("rumor_seeded"):
		if _rumor_panel.rumor_seeded.is_connected(_on_tc_rumor_seeded):
			_rumor_panel.rumor_seeded.disconnect(_on_tc_rumor_seeded)
	_connected_rumor_seeded = false

	if _connected_npc_states and _world != null:
		for npc in _world.npcs:
			if npc.has_signal("rumor_state_changed"):
				if npc.rumor_state_changed.is_connected(_on_tc_rumor_state_changed):
					npc.rumor_state_changed.disconnect(_on_tc_rumor_state_changed)
	_connected_npc_states = false


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_tc_read_the_room(_location_id: String) -> void:
	if _current_step == STEP_EXPLORE:
		_complete_current_step()


func _on_tc_journal_visibility() -> void:
	if _current_step == STEP_OBSERVE_INTEL and _journal != null and _journal.visible:
		_complete_current_step()


func _on_tc_recon_action(message: String, success: bool) -> void:
	if not success:
		return
	if _current_step == STEP_EAVESDROP and message.begins_with("Eavesdrop"):
		_complete_current_step()


func _on_tc_rumor_seeded(_rumor_id: String, _subject: String, _claim: String, target_name: String) -> void:
	if _current_step == STEP_CRAFT_RUMOR:
		_last_seed_target_name = target_name
		_complete_current_step()


func _on_tc_rumor_state_changed(_npc_name: String, new_state: String, _rumor_id: String) -> void:
	if _current_step == STEP_WATCH_SPREAD and new_state == "BELIEVE":
		_complete_current_step()


## Returns true if the guided tutorial is currently active and gating progression.
func is_active() -> bool:
	return _active


## Returns the current step index, or -1 if not started.
func get_current_step() -> int:
	return _current_step
