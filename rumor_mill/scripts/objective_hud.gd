extends CanvasLayer

## objective_hud.gd — Coordinator for the persistent 3-tier objective tracker.
##
## Tier 1 (always visible): Goal verb headline, win progress bar + milestone
##   label, day counter with tempo indicator.
## Tier 2: Unused in this overlay — daily planning lives in DailyPlanningOverlay (separate CanvasLayer).
## Tier 3: Context-aware suggestion engine slot.
##
## Delegates to four extracted subsystems:
##   ObjectiveHudMetrics      — metrics row (Avg Rep, Believers, Pariahs, Threat)
##   ObjectiveHudNudgeManager — budget counter, tutorial nudge, mid-game nudge
##   ObjectiveHudWinTracker   — win progress bar, milestone, tempo, mini-progress
##   ObjectiveHudBanner       — dawn bulletin, deadline + failure warnings

@onready var day_label:          Label         = $Panel/VBox/DayRow/DayLabel
@onready var day_max_label:      Label         = $Panel/VBox/DayRow/DayMaxLabel
@onready var days_remaining_lbl: Label         = $Panel/VBox/DayRow/DaysRemaining
@onready var time_label:         Label         = $Panel/VBox/DayRow/TimeOfDayLabel
@onready var goal_label:         Label         = $Panel/VBox/GoalLabel
@onready var progress_bar:       ColorRect     = $Panel/VBox/DayProgressBG/DayProgressBar
@onready var progress_bg:        ColorRect     = $Panel/VBox/DayProgressBG
@onready var win_progress_bar:   ColorRect     = $Panel/VBox/WinProgressBG/WinProgressBar
@onready var win_progress_lbl:   Label         = $Panel/VBox/WinProgressBG/WinProgressLabel
@onready var milestone_label:    Label         = $Panel/VBox/MilestoneLabel
@onready var tier2_container:    VBoxContainer = $Panel/VBox/Tier2Container
@onready var tier3_container:    VBoxContainer = $Panel/VBox/Tier3Container

# ── Modules ───────────────────────────────────────────────────────────────────
var _metrics_module: ObjectiveHudMetrics     = null
var _nudge_module:   ObjectiveHudNudgeManager = null
var _win_tracker:    ObjectiveHudWinTracker   = null
var _banner_module:  ObjectiveHudBanner       = null

# ── Shared dependencies ───────────────────────────────────────────────────────
var _scenario_manager: ScenarioManager   = null
var _day_night:        Node              = null
var _days_allowed:     int               = 30
var _reputation_system: ReputationSystem = null
var _intel_store:      PlayerIntelStore  = null
var _world_ref:        Node2D            = null

# ── Goal label state ──────────────────────────────────────────────────────────
var _goal_verb:         String = ""
var _goal_target:       String = ""
var _goal_flavor_label: Label  = null

# ── Tier 3: Suggestion engine (SPA-743) ──────────────────────────────────────
var _suggestion_engine: SuggestionEngine = null
var _suggestion_toast:  SuggestionToast  = null
var _t3_last_obs:       int = -1
var _t3_last_whisp:     int = -1

# ── Day counter tween state ───────────────────────────────────────────────────
var _day_counter_tween:   Tween = null
var _urgency_pulse_tween: Tween = null

# ── SPA-859: First-time objective callout ─────────────────────────────────────
const CALLOUT_TOOLTIP_ID := "objective_hud_first_time"
var _callout_overlay: CanvasLayer = null

# ── SPA-797: Objective entrance animation ─────────────────────────────────────
var _entrance_played: bool = false

# ── Urgency colour palette ────────────────────────────────────────────────────
const C_DAY_SAFE     := Color(0.30, 0.85, 0.35, 1.0)
const C_DAY_CAUTION  := Color(0.95, 0.85, 0.15, 1.0)
const C_DAY_URGENT   := Color(0.95, 0.55, 0.10, 1.0)
const C_DAY_CRITICAL := Color(0.95, 0.20, 0.10, 1.0)

# ── Faction mini-panel (SPA-561) ─────────────────────────────────────────────
var _faction_panel:  Panel      = null
var _faction_labels: Dictionary = {}  # faction_id → {mood: Label, bar: ColorRect}


func _ready() -> void:
	layer = 4
	var vbox: VBoxContainer   = $Panel/VBox
	var day_row: HBoxContainer = $Panel/VBox/DayRow

	# Instantiate modules.
	_metrics_module = ObjectiveHudMetrics.new()
	_nudge_module   = ObjectiveHudNudgeManager.new()
	_win_tracker    = ObjectiveHudWinTracker.new()
	_banner_module  = ObjectiveHudBanner.new()
	add_child(_metrics_module)
	add_child(_nudge_module)
	add_child(_win_tracker)
	add_child(_banner_module)

	# Build order matches the original _ready():
	# 1. Nudge panel (inserts at vbox index 1, before GoalLabel)
	# 2. Goal flavor label (inserted after GoalLabel by coordinator)
	# 3. O-hint label (handled inside _nudge_module.setup, after GoalLabel)
	# All build_win_target / build_budget / build_midgame calls happen in setup()
	# after scene refs are resolved, because modules need goal_flavor_label.

	# Pre-build nudge panel + o_hint using temporary nulls for goal_flavor.
	# The coordinator calls the proper sequenced build in setup().
	_nudge_module.setup(vbox, goal_label, null, null, null, self,
		func(t: String, c: Color, d: float) -> void: _banner_module.show_banner(t, c, d))

	_build_goal_flavor_label()

	_win_tracker.setup(vbox, goal_label,
		win_progress_bar, win_progress_lbl, milestone_label, days_remaining_lbl,
		null, null, null, 30)

	_win_tracker.build_win_target(_goal_flavor_label, _nudge_module.o_hint_label)

	_nudge_module.build_budget_label(_goal_flavor_label, _win_tracker.win_target_label)
	_nudge_module.build_midgame_nudge()

	_build_tier3_suggestion()

	_win_tracker.build_mini_progress(day_row)


## Inject runtime dependencies and finish wiring all modules.
func setup(
		scenario_manager: ScenarioManager,
		day_night: Node,
		rep_system: ReputationSystem = null,
		intel_store: PlayerIntelStore = null) -> void:
	_scenario_manager  = scenario_manager
	_day_night         = day_night
	_days_allowed      = scenario_manager.get_days_allowed()
	_reputation_system = rep_system
	_intel_store       = intel_store

	day_max_label.text = "%d" % _days_allowed

	var card: Dictionary = scenario_manager.get_objective_card()
	_goal_verb    = card.get("goalVerb",    "")
	_goal_target  = card.get("goalTarget",  "")

	# Push dependencies into modules now that they're known.
	_metrics_module.setup($Panel/VBox, rep_system, intel_store, scenario_manager, day_night)

	_nudge_module._intel_store      = intel_store
	_nudge_module._day_night        = day_night
	_nudge_module._scenario_manager = scenario_manager

	_win_tracker._reputation_system = rep_system
	_win_tracker._scenario_manager  = scenario_manager
	_win_tracker._day_night         = day_night
	_win_tracker._days_allowed      = _days_allowed
	_win_tracker.configure(card.get("progressMilestones", {}),
		func(text: String) -> void:
			if _suggestion_toast != null:
				_suggestion_toast.show_hint(text))

	_banner_module.setup(self, rep_system, scenario_manager, day_night, intel_store)

	_refresh()
	_setup_tooltips()
	_enhance_visual_hierarchy()

	if day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_day_changed)
	if day_night.has_signal("game_tick"):
		day_night.game_tick.connect(_on_tick)
	if day_night.has_signal("day_transition_started"):
		day_night.day_transition_started.connect(_on_day_transition_started)
	if scenario_manager.has_signal("deadline_warning"):
		scenario_manager.deadline_warning.connect(_banner_module.on_deadline_warning)
	if intel_store != null and intel_store.has_signal("whisper_spent"):
		intel_store.whisper_spent.connect(_nudge_module.on_whisper_spent)

	_banner_module.snapshot_dawn_scores()
	_show_first_time_callout()


## Called by main.gd to provide world reference for faction panel + suggestions.
func setup_world(world: Node2D) -> void:
	_world_ref = world
	_nudge_module.setup_world(world)
	_win_tracker.setup_world(world)
	_banner_module.setup_world(world)
	_build_faction_panel()

	if _scenario_manager != null and _intel_store != null and _reputation_system != null:
		_suggestion_engine = SuggestionEngine.new()
		var mgea: MidGameEventAgent = world.mid_game_event_agent if "mid_game_event_agent" in world else null
		_suggestion_engine.setup(world, _intel_store, _reputation_system,
			_scenario_manager, _day_night, mgea)
		_suggestion_engine.hint_ready.connect(_on_suggestion_hint_ready)
		if _day_night != null:
			if _day_night.has_signal("day_changed"):
				_day_night.day_changed.connect(_suggestion_engine._on_day_changed)
			if _day_night.has_signal("day_transition_started"):
				_day_night.day_transition_started.connect(_suggestion_engine._on_dawn)

	# SPA-943: Populate win target immediately now that _world_ref is available.
	_win_tracker.refresh_tick()


# ── Public API delegations ─────────────────────────────────────────────────────

## SPA-805: Brief green flash on the Believers counter when the player seeds a rumor.
func pulse_believers_counter() -> void:
	_metrics_module.pulse_believers_counter()


## SPA-627: One-time flash banner shown after the initial briefing overlay is dismissed.
func show_o_hotkey_hint() -> void:
	_nudge_module.show_o_hotkey_hint()


## SPA-786: Flash the win progress label to highlight a milestone moment.
func flash_win_progress() -> void:
	_win_tracker.flash_win_progress()


## SPA-797: Slide the objective panel in from above on game start.
func play_entrance_animation() -> void:
	if _entrance_played:
		return
	_entrance_played = true
	var panel: Panel = $Panel
	if panel == null:
		return
	panel.modulate.a = 0.0
	panel.position.y -= 20.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(panel, "position:y", panel.position.y + 20.0, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.3)
	tw.tween_method(func(c: Color) -> void:
		goal_label.add_theme_color_override("font_color", c)
	, Color(1.0, 0.95, 0.55, 1.0), Color(0.92, 0.78, 0.12, 1.0), 0.8)


# ── Event handlers ─────────────────────────────────────────────────────────────

func _on_day_changed(_day: int) -> void:
	_refresh()
	_banner_module.show_dawn_bulletin()
	_banner_module.snapshot_dawn_scores()


func _on_day_transition_started(_day: int) -> void:
	_pulse_day_counter()


func _on_tick(_tick: int) -> void:
	_refresh_time()
	_refresh_goal_label()
	_nudge_module.refresh()
	_win_tracker.refresh_tick()
	_refresh_tier3_suggestion()
	_banner_module.check_failure_proximity()


func _refresh() -> void:
	if _scenario_manager == null:
		return
	_refresh_goal_label()
	_refresh_goal_flavor()

	var current_day: int = _day_night.current_day if _day_night != null else 1
	var remaining: int   = max(_days_allowed - current_day + 1, 0)
	days_remaining_lbl.text = "— %d day%s remain" % [remaining, "" if remaining == 1 else "s"]

	_refresh_time()
	_nudge_module.refresh()
	_metrics_module.refresh()
	_win_tracker.refresh_daily()
	_refresh_faction_panel()


# ── Goal label + flavor subtitle ──────────────────────────────────────────────

func _refresh_goal_label() -> void:
	if _scenario_manager == null or _reputation_system == null:
		return
	var tick: int = 0
	if _day_night != null and "current_tick" in _day_night:
		tick = _day_night.current_tick
	var concrete: String = _scenario_manager.get_concrete_goal_text(_reputation_system, tick)
	if not concrete.is_empty():
		goal_label.text = concrete
	elif not _goal_verb.is_empty():
		goal_label.text = "%s %s" % [_goal_verb, _goal_target]
	else:
		goal_label.text = _scenario_manager.get_objective_one_liner()


func _build_goal_flavor_label() -> void:
	if _goal_flavor_label != null:
		return
	var vbox: VBoxContainer = $Panel/VBox
	_goal_flavor_label = Label.new()
	_goal_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_flavor_label.add_theme_font_size_override("font_size", 11)
	_goal_flavor_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45, 0.85))
	_goal_flavor_label.add_theme_constant_override("outline_size", 2)
	_goal_flavor_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_goal_flavor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_goal_flavor_label)
	vbox.move_child(_goal_flavor_label, goal_label.get_index() + 1)


func _refresh_goal_flavor() -> void:
	if _goal_flavor_label == null:
		_build_goal_flavor_label()
	if _goal_flavor_label == null:
		return
	if not _goal_verb.is_empty():
		_goal_flavor_label.text = "%s %s" % [_goal_verb, _goal_target]
	else:
		_goal_flavor_label.text = _scenario_manager.get_objective_one_liner() \
			if _scenario_manager != null else ""
	_goal_flavor_label.visible = not _goal_flavor_label.text.is_empty()


# ── Time display ───────────────────────────────────────────────────────────────

func _refresh_time() -> void:
	if _day_night == null:
		return
	var current_day: int = _day_night.current_day

	# Day counter with urgency colouring.
	day_label.text = "DAY %d" % current_day
	var fraction: float = clampf(float(current_day - 1) / float(max(_days_allowed - 1, 1)), 0.0, 1.0)
	day_label.add_theme_color_override("font_color", _get_urgency_color(fraction))

	# Time-of-day label.
	if "current_tick" in _day_night and "ticks_per_day" in _day_night:
		var tick: int   = _day_night.current_tick
		var tpd:  int   = _day_night.ticks_per_day
		var hour: float = float(tick) / float(tpd) * 24.0
		var h:    int   = int(hour) % 24
		var m:    int   = int((hour - int(hour)) * 60.0)
		var ampm: String = "AM" if h < 12 else "PM"
		var h12:  int   = h % 12
		if h12 == 0:
			h12 = 12
		time_label.text = "%d:%02d %s" % [h12, m, ampm]

	# Day timeline progress bar (shows time-of-day).
	if progress_bar != null and progress_bg != null:
		var day_fraction: float = 0.0
		if "current_tick" in _day_night and "ticks_per_day" in _day_night:
			day_fraction = clampf(
				float(_day_night.current_tick) / float(max(_day_night.ticks_per_day, 1)), 0.0, 1.0)
		progress_bar.anchor_right = day_fraction
		progress_bar.color = _get_urgency_color(fraction)


func _get_urgency_color(frac: float) -> Color:
	if frac < 0.50:
		return C_DAY_SAFE
	elif frac < 0.70:
		return C_DAY_SAFE.lerp(C_DAY_CAUTION, (frac - 0.50) / 0.20)
	elif frac < 0.85:
		return C_DAY_CAUTION.lerp(C_DAY_URGENT, (frac - 0.70) / 0.15)
	else:
		return C_DAY_URGENT.lerp(C_DAY_CRITICAL, (frac - 0.85) / 0.15)


# ── Day counter animations ────────────────────────────────────────────────────

func _pulse_day_counter() -> void:
	if day_label == null:
		return
	if _day_counter_tween != null and _day_counter_tween.is_valid():
		_day_counter_tween.kill()
		day_label.scale = Vector2.ONE
		day_label.rotation = 0.0
	day_label.pivot_offset = day_label.size / 2.0
	_day_counter_tween = create_tween()
	_day_counter_tween.tween_property(day_label, "rotation", deg_to_rad(-2.0), 0.06) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_day_counter_tween.tween_property(day_label, "rotation", deg_to_rad(1.5), 0.06) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_day_counter_tween.tween_property(day_label, "rotation", 0.0, 0.08) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_day_counter_tween.parallel().tween_property(day_label, "scale", Vector2(1.2, 1.2), 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_day_counter_tween.tween_property(day_label, "scale", Vector2(1.0, 1.0), 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_apply_day_urgency_pulse()


func _apply_day_urgency_pulse() -> void:
	if day_label == null or _day_night == null:
		return
	var current_day: int = _day_night.current_day
	var fraction: float  = clampf(float(current_day - 1) / float(max(_days_allowed - 1, 1)), 0.0, 1.0)
	if fraction < 0.50:
		return
	var pulse_color: Color = Color(0.95, 0.25, 0.15, 1.0) if fraction >= 0.75 \
		else Color(1.0, 0.75, 0.15, 1.0)
	if _urgency_pulse_tween != null and _urgency_pulse_tween.is_valid():
		_urgency_pulse_tween.kill()
	var orig_color: Color = day_label.get_theme_color("font_color")
	_urgency_pulse_tween = create_tween().set_loops(3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_urgency_pulse_tween.tween_method(func(c: Color) -> void:
		day_label.add_theme_color_override("font_color", c)
	, orig_color, pulse_color, 0.2)
	_urgency_pulse_tween.tween_method(func(c: Color) -> void:
		day_label.add_theme_color_override("font_color", c)
	, pulse_color, orig_color, 0.2)


# ── Tier 3 suggestion engine ──────────────────────────────────────────────────

func _build_tier3_suggestion() -> void:
	if tier3_container == null:
		return
	_suggestion_toast = SuggestionToast.new()
	_suggestion_toast.visible = false
	tier3_container.add_child(_suggestion_toast)
	_suggestion_toast.hint_dismissed.connect(_on_hint_dismissed)


func _refresh_tier3_suggestion() -> void:
	if _nudge_module._nudge_phase < 4:
		return
	if _suggestion_engine == null:
		return
	if _intel_store != null:
		var tick: int = _day_night.current_tick \
			if _day_night != null and "current_tick" in _day_night else 0
		var cur_obs:   int = _intel_store.recon_actions_remaining
		var cur_whisp: int = _intel_store.whisper_tokens_remaining
		if (_t3_last_obs >= 0 and cur_obs != _t3_last_obs) or \
				(_t3_last_whisp >= 0 and cur_whisp != _t3_last_whisp):
			_suggestion_engine.notify_player_action(tick)
		_t3_last_obs   = cur_obs
		_t3_last_whisp = cur_whisp
	_suggestion_engine.refresh()


func _on_suggestion_hint_ready(text: String) -> void:
	if _suggestion_toast != null:
		_suggestion_toast.show_hint(text)


func _on_hint_dismissed(was_fast: bool) -> void:
	if _suggestion_engine != null:
		_suggestion_engine.notify_hint_dismissed(was_fast)


# ── Faction influence mini-panel ──────────────────────────────────────────────

func _build_faction_panel() -> void:
	if _world_ref == null:
		return
	var panel: Panel = $Panel
	_faction_panel = Panel.new()
	_faction_panel.offset_left  = panel.offset_left
	_faction_panel.offset_right = panel.offset_right
	_faction_panel.anchor_left  = 0.5
	_faction_panel.anchor_right = 0.5
	_faction_panel.offset_top   = panel.offset_bottom + 2
	_faction_panel.offset_bottom = panel.offset_bottom + 64

	var fp_style := StyleBoxFlat.new()
	fp_style.bg_color = Color(0.10, 0.07, 0.05, 0.90)
	fp_style.set_border_width_all(1)
	fp_style.border_color = Color(0.55, 0.38, 0.18, 0.50)
	fp_style.border_width_top = 2
	fp_style.set_corner_radius_all(1)
	_faction_panel.add_theme_stylebox_override("panel", fp_style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left  = 8.0
	hbox.offset_top   = 4.0
	hbox.offset_right = -8.0
	hbox.offset_bottom = -4.0
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_faction_panel.add_child(hbox)

	const FACTIONS := {
		"merchant": {"name": "Merchants", "color": Color(0.784, 0.635, 0.180, 1.0)},
		"noble":    {"name": "Nobles",    "color": Color(0.65, 0.45, 0.85, 1.0)},
		"clergy":   {"name": "Clergy",    "color": Color(0.55, 0.80, 0.95, 1.0)},
	}
	for faction_id in ["merchant", "noble", "clergy"]:
		var info: Dictionary = FACTIONS[faction_id]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = info["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", info["color"])
		name_lbl.add_theme_constant_override("outline_size", 2)
		name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		col.add_child(name_lbl)

		var mood_lbl := Label.new()
		mood_lbl.text = "Calm"
		mood_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mood_lbl.add_theme_font_size_override("font_size", 11)
		mood_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50, 1.0))
		mood_lbl.add_theme_constant_override("outline_size", 2)
		mood_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		col.add_child(mood_lbl)

		var bar_panel := Panel.new()
		bar_panel.custom_minimum_size = Vector2(0, 8)
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color = Color(0.20, 0.15, 0.08, 1.0)
		bar_style.set_corner_radius_all(2)
		bar_style.set_border_width_all(1)
		bar_style.border_color = Color(info["color"].r, info["color"].g, info["color"].b, 0.25)
		bar_panel.add_theme_stylebox_override("panel", bar_style)
		col.add_child(bar_panel)

		var bar_fill := ColorRect.new()
		bar_fill.anchor_bottom = 1.0
		bar_fill.anchor_right  = 0.0
		bar_fill.offset_left   = 1.0
		bar_fill.offset_top    = 1.0
		bar_fill.offset_bottom = -1.0
		bar_fill.color = info["color"]
		bar_panel.add_child(bar_fill)

		_faction_labels[faction_id] = {"mood": mood_lbl, "bar": bar_fill}
		hbox.add_child(col)

	add_child(_faction_panel)


func _refresh_faction_panel() -> void:
	if _faction_panel == null or _world_ref == null:
		return
	if not "npcs" in _world_ref:
		return
	for faction_id in ["merchant", "noble", "clergy"]:
		var member_count:   int = 0
		var believer_count: int = 0
		for npc in _world_ref.npcs:
			if npc.npc_data.get("faction", "") != faction_id:
				continue
			member_count += 1
			for rid in npc.rumor_slots:
				var slot = npc.rumor_slots[rid]
				if slot.state in [Rumor.RumorState.BELIEVE,
								   Rumor.RumorState.SPREAD,
								   Rumor.RumorState.ACT]:
					believer_count += 1
					break
		var ratio: float = float(believer_count) / float(max(member_count, 1))
		var mood:  String
		var mood_color: Color
		if ratio < 0.1:
			mood = "Calm"
			mood_color = Color(0.50, 0.80, 0.45, 1.0)
		elif ratio < 0.3:
			mood = "Unsettled"
			mood_color = Color(0.90, 0.80, 0.30, 1.0)
		elif ratio < 0.6:
			mood = "Agitated"
			mood_color = Color(0.95, 0.55, 0.15, 1.0)
		else:
			mood = "Hostile"
			mood_color = Color(0.90, 0.25, 0.15, 1.0)
		if _faction_labels.has(faction_id):
			var entry: Dictionary = _faction_labels[faction_id]
			entry["mood"].text = mood
			entry["mood"].add_theme_color_override("font_color", mood_color)
			entry["bar"].anchor_right = ratio


# ── Setup helpers ─────────────────────────────────────────────────────────────

func _setup_tooltips() -> void:
	var day_row: HBoxContainer = $Panel/VBox/DayRow
	day_row.tooltip_text = "Day Counter\nShows the current day and time. Days remaining until your deadline are shown to the right.\nThe color shifts from green to red as the deadline approaches."
	day_row.mouse_filter = Control.MOUSE_FILTER_PASS
	goal_label.tooltip_text = "Current Objective\nYour primary goal for this scenario. Complete it before the deadline to win."
	goal_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var win_bg: ColorRect = $Panel/VBox/WinProgressBG
	win_bg.tooltip_text = "Win Progress\nTracks how close you are to achieving your objective.\nFill the bar to complete your goal."
	win_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	var tempo_bg: ColorRect = $Panel/VBox/DayProgressBG
	tempo_bg.tooltip_text = "Day Timeline\nShows the time of day. Actions happen in real-time as the day progresses.\nResources refresh at dawn."
	tempo_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	milestone_label.tooltip_text = "Milestone\nShows your current progress milestone. Reaching milestones unlocks new narrative events."
	milestone_label.mouse_filter = Control.MOUSE_FILTER_PASS


func _enhance_visual_hierarchy() -> void:
	goal_label.add_theme_font_size_override("font_size", 18)
	goal_label.add_theme_constant_override("outline_size", 3)
	goal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	var panel: Panel = $Panel
	var accent := ColorRect.new()
	accent.color = Color(0.92, 0.78, 0.12, 0.75)
	accent.anchor_left   = 0.0
	accent.anchor_top    = 0.0
	accent.anchor_right  = 0.0
	accent.anchor_bottom = 1.0
	accent.offset_right  = 3.0
	accent.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)
	var win_bg: ColorRect = $Panel/VBox/WinProgressBG
	win_bg.custom_minimum_size.y = 14.0


# ── SPA-859: First-time objective callout ─────────────────────────────────────

func _show_first_time_callout() -> void:
	if SettingsManager.dismissed_tooltips.get(CALLOUT_TOOLTIP_ID, false):
		return
	call_deferred("_build_callout_overlay")


func _build_callout_overlay() -> void:
	_callout_overlay = CanvasLayer.new()
	_callout_overlay.layer = 15
	_callout_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_callout_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_callout_overlay.add_child(dim)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 0)
	card.anchor_left  = 0.0
	card.anchor_top   = 0.0
	card.offset_left  = 16.0
	card.offset_top   = 200.0
	card.offset_right = 336.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.10, 0.07, 0.04, 0.95)
	style.border_color = Color(0.92, 0.78, 0.12, 1.0)
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)
	_callout_overlay.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var arrow := Label.new()
	arrow.text = "▲  YOUR OBJECTIVE  ▲"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 14)
	arrow.add_theme_color_override("font_color", Color(0.92, 0.78, 0.12, 1.0))
	vbox.add_child(arrow)

	var body := Label.new()
	body.text = "This panel shows your current mission target,\ndays remaining, and progress toward winning.\nKeep an eye on it — complete your objective\nbefore the deadline runs out!"
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.82, 0.75, 0.60, 1.0))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var btn := Button.new()
	btn.text = "Got it!"
	btn.custom_minimum_size = Vector2(100, 32)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.95, 0.91, 0.80, 1.0))
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.30, 0.18, 0.07, 1.0)
	btn_style.border_color = Color(0.55, 0.38, 0.18, 1.0)
	btn_style.set_border_width_all(1)
	btn_style.set_content_margin_all(6)
	btn_style.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.50, 0.30, 0.10, 1.0)
	btn_hover.border_color = Color(0.55, 0.38, 0.18, 1.0)
	btn_hover.set_border_width_all(1)
	btn_hover.set_content_margin_all(6)
	btn_hover.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.pressed.connect(_on_callout_dismissed)
	vbox.add_child(btn)

	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_on_callout_dismissed()
	)

	var tw := arrow.create_tween().set_loops()
	tw.tween_property(arrow, "modulate:a", 0.4, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(arrow, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _on_callout_dismissed() -> void:
	if _callout_overlay != null:
		_callout_overlay.queue_free()
		_callout_overlay = null
	SettingsManager.dismissed_tooltips[CALLOUT_TOOLTIP_ID] = true
	SettingsManager.save_settings()
