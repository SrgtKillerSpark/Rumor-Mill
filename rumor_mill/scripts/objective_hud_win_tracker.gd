class_name ObjectiveHudWinTracker
extends Node

## objective_hud_win_tracker.gd — Win progress subsystems for ObjectiveHUD (SPA-1004).
##
## Extracted from objective_hud.gd.  Manages:
##   • Win-condition target line (SPA-719) — live per-scenario NPC score readout
##   • Win progress bar colour + pulsing near completion (SPA-561)
##   • Milestone label (25/50/75% thresholds)
##   • Tempo indicator on days-remaining label
##   • Mini objective progress indicator in the day row (SPA-648)
##
## Call setup() in _ready() with scene node refs, then build_win_target() once
## goal_flavor and o_hint are in the VBox, then build_mini_progress().
## Call setup_world() when the world node becomes available.

# ── Scene node refs ───────────────────────────────────────────────────────────
var _win_progress_bar: ColorRect = null
var _win_progress_lbl: Label     = null
var _milestone_label:  Label     = null
var _days_remaining_lbl: Label   = null
var _vbox:             VBoxContainer = null
var _goal_label:       Label         = null

# ── Public: coordinator passes this to nudge_manager for budget positioning ───
var win_target_label: Label = null

# ── Mini progress label (inside DayRow) ──────────────────────────────────────
var _mini_progress_label: Label = null

# ── Win-progress pulse tween ──────────────────────────────────────────────────
var _win_pulse_tween:  Tween = null
var _win_pulse_active: bool  = false

# ── Milestone tracking ────────────────────────────────────────────────────────
var _current_milestone_text: String     = ""
var _progress_milestones:    Dictionary = {}

# ── Target rep change tracking (SPA-837) ─────────────────────────────────────
var _last_target_scores: Dictionary = {}
## show_hint_fn(text: String) — forward to SuggestionToast.show_hint
var _show_hint_fn: Callable

# ── Tempo colours ─────────────────────────────────────────────────────────────
const C_TEMPO_AHEAD   := Color(0.30, 0.85, 0.35, 1.0)
const C_TEMPO_ON_PACE := Color(0.95, 0.85, 0.15, 1.0)
const C_TEMPO_BEHIND  := Color(0.95, 0.20, 0.10, 1.0)

# ── Dependencies ──────────────────────────────────────────────────────────────
var _reputation_system: ReputationSystem  = null
var _scenario_manager:  ScenarioManager   = null
var _day_night:         Node              = null
var _days_allowed:      int               = 30
var _world_ref:         Node2D            = null


## Inject scene nodes and dependencies.
func setup(
		vbox: VBoxContainer,
		goal_label: Label,
		win_progress_bar: ColorRect,
		win_progress_lbl: Label,
		milestone_label: Label,
		days_remaining_lbl: Label,
		rep_system: ReputationSystem,
		scenario_manager: ScenarioManager,
		day_night: Node,
		days_allowed: int) -> void:
	_vbox              = vbox
	_goal_label        = goal_label
	_win_progress_bar  = win_progress_bar
	_win_progress_lbl  = win_progress_lbl
	_milestone_label   = milestone_label
	_days_remaining_lbl = days_remaining_lbl
	_reputation_system = rep_system
	_scenario_manager  = scenario_manager
	_day_night         = day_night
	_days_allowed      = days_allowed


## Load milestone dictionary and provide a Callable for showing toast hints.
## Must be called after setup() but before the first refresh().
func configure(milestones: Dictionary, show_hint_fn: Callable) -> void:
	_progress_milestones = milestones
	_show_hint_fn        = show_hint_fn


## Build the win-condition target label.  Call after goal_flavor and o_hint are
## already in the VBox so it slots below them correctly.
func build_win_target(goal_flavor_label: Label, o_hint_label: Label) -> void:
	win_target_label = Label.new()
	win_target_label.text = ""
	win_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_target_label.add_theme_font_size_override("font_size", 13)
	win_target_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1.0))
	win_target_label.add_theme_constant_override("outline_size", 3)
	win_target_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	win_target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(win_target_label)
	var insert_idx: int = _goal_label.get_index() + 1
	if goal_flavor_label != null:
		insert_idx = goal_flavor_label.get_index() + 1
	if o_hint_label != null:
		insert_idx = o_hint_label.get_index() + 1
	_vbox.move_child(win_target_label, insert_idx)


## Build the mini progress label inside `day_row` (HBoxContainer in scene).
func build_mini_progress(day_row: HBoxContainer) -> void:
	_mini_progress_label = Label.new()
	_mini_progress_label.text = ""
	_mini_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mini_progress_label.add_theme_font_size_override("font_size", 13)
	_mini_progress_label.add_theme_constant_override("outline_size", 2)
	_mini_progress_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_mini_progress_label.add_theme_color_override("font_color", Color(0.50, 0.80, 0.35, 1.0))
	_mini_progress_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini_progress_label.tooltip_text = "Win progress — click to open Journal Objectives"
	_mini_progress_label.gui_input.connect(_on_mini_progress_clicked)
	day_row.add_child(_mini_progress_label)


## Call once the world node is available (after setup_world in coordinator).
func setup_world(world: Node2D) -> void:
	_world_ref = world


## Full refresh — call from coordinator._refresh() (day change).
func refresh_daily() -> void:
	_refresh_win_progress()
	_refresh_milestone_label()
	_refresh_tempo_indicator()
	_refresh_win_target()
	_refresh_mini_progress()


## Tick refresh — call from coordinator._on_tick().
func refresh_tick() -> void:
	_refresh_win_target()
	_refresh_mini_progress()


## SPA-786: Flash the win progress label to highlight a milestone moment.
## Called from coordinator when a milestone is reached.
func flash_win_progress() -> void:
	if _win_progress_lbl == null:
		return
	var orig_color: Color = _win_progress_lbl.get_theme_color("font_color")
	var flash_color := Color(1.0, 0.95, 0.55, 1.0)
	var tw := create_tween()
	_win_progress_lbl.add_theme_color_override("font_color", flash_color)
	_win_progress_lbl.pivot_offset = _win_progress_lbl.size / 2.0
	tw.tween_property(_win_progress_lbl, "scale", Vector2(1.15, 1.15), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_win_progress_lbl, "scale", Vector2(1.0, 1.0), 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_method(func(c: Color) -> void:
		_win_progress_lbl.add_theme_color_override("font_color", c)
	, flash_color, orig_color, 0.6)


# ── Win-condition target line ──────────────────────────────────────────────────

func _refresh_win_target() -> void:
	if win_target_label == null or _scenario_manager == null or _reputation_system == null:
		return
	if _world_ref == null:
		return
	var sid: String = _world_ref.active_scenario_id if "active_scenario_id" in _world_ref else ""
	var text: String = ""
	var cur_scores: Dictionary = {}
	match sid:
		"scenario_1":
			var p: Dictionary = _scenario_manager.get_scenario_1_progress(_reputation_system)
			var score:     int = p.get("edric_score", 50)
			var threshold: int = p.get("win_threshold", 30)
			text = "Edric Fenn: %d/100 — need < %d" % [score, threshold]
			cur_scores["edric_fenn"] = score
		"scenario_2":
			var p: Dictionary = _scenario_manager.get_scenario_2_progress(_reputation_system)
			var count:    int   = p.get("illness_believer_count", 0)
			var target:   int   = p.get("win_threshold", 7)
			var rejecters: Array = p.get("illness_rejecter_ids", [])
			var maren_status: String = "Safe"
			if ScenarioManager.MAREN_NUN_ID in rejecters:
				maren_status = "REJECTED"
			text = "Believers: %d/%d — Maren: %s" % [count, target, maren_status]
		"scenario_3":
			var p: Dictionary = _scenario_manager.get_scenario_3_progress(_reputation_system)
			var calder:        int = p.get("calder_score", 50)
			var tomas:         int = p.get("tomas_score", 50)
			var calder_target: int = p.get("calder_win_target", 75)
			var tomas_target:  int = p.get("tomas_win_target", 35)
			text = "Calder: %d/%d | Tomas: %d/%d" % [calder, calder_target, tomas, tomas_target]
			cur_scores["calder_fenn"] = calder
			cur_scores["tomas_reeve"] = tomas
		"scenario_4":
			var p: Dictionary = _scenario_manager.get_scenario_4_progress(_reputation_system)
			var scores:    Dictionary = p.get("protected_scores", {})
			var threshold: int        = p.get("win_threshold", 45)
			var parts: PackedStringArray = PackedStringArray()
			for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
				var npc_score:    int    = scores.get(npc_id, 50)
				var display_name: String = npc_id.split("_")[0].capitalize()
				parts.append("%s: %d" % [display_name, npc_score])
				cur_scores[npc_id] = npc_score
			text = "%s — all need > %d" % [" | ".join(parts), threshold]
		"scenario_5":
			var p: Dictionary = _scenario_manager.get_scenario_5_progress(_reputation_system)
			var aldric: int = p.get("aldric_score", 48)
			var edric:  int = p.get("edric_score",  58)
			var tomas:  int = p.get("tomas_score",  45)
			text = "Aldric: %d | Edric: %d | Tomas: %d — need 65+ & rivals < 45" % [aldric, edric, tomas]
			cur_scores["aldric_vane"] = aldric
			cur_scores["edric_fenn"]  = edric
			cur_scores["tomas_reeve"] = tomas
		"scenario_6":
			var p: Dictionary = _scenario_manager.get_scenario_6_progress(_reputation_system)
			var aldric: int = p.get("aldric_score", 55)
			var marta:  int = p.get("marta_score",  52)
			text = "Aldric: %d | Marta: %d — need ≤ 30 & ≥ 60" % [aldric, marta]
			cur_scores["aldric_vane"] = aldric
			cur_scores["marta_coin"]  = marta
	if not cur_scores.is_empty():
		_check_target_rep_change(cur_scores)
	win_target_label.text = text
	win_target_label.visible = not text.is_empty()


## SPA-837: Show a toast when a scenario target NPC's rep shifts by >=2 points.
func _check_target_rep_change(cur_scores: Dictionary) -> void:
	if not _show_hint_fn.is_valid():
		return
	if _last_target_scores.is_empty():
		_last_target_scores = cur_scores.duplicate()
		return
	var best_npc_id:    String = ""
	var best_delta:     int    = 0
	var best_new_score: int    = 0
	for npc_id in cur_scores:
		if not _last_target_scores.has(npc_id):
			continue
		var delta: int = cur_scores[npc_id] - _last_target_scores[npc_id]
		if abs(delta) > abs(best_delta):
			best_delta     = delta
			best_npc_id    = npc_id
			best_new_score = cur_scores[npc_id]
	_last_target_scores = cur_scores.duplicate()
	if abs(best_delta) < 2:
		return
	if best_delta > 0:
		AudioManager.play_sfx_pitched("reputation_up", 1.05)
	else:
		AudioManager.play_sfx_pitched("reputation_down", 0.95)
	var npc_name:  String = best_npc_id.replace("_", " ").capitalize()
	var direction: String = "dropped to" if best_delta < 0 else "rose to"
	var sign:      String = "+" if best_delta > 0 else ""
	_show_hint_fn.call(
		"%s reputation %s %d (%s%d)" % [npc_name, direction, best_new_score, sign, best_delta]
	)


# ── Win progress bar ───────────────────────────────────────────────────────────

func _refresh_win_progress() -> void:
	if _scenario_manager == null or _win_progress_bar == null or _reputation_system == null:
		return
	var prog: float = _compute_win_progress()
	_win_progress_bar.anchor_right = prog
	if _win_progress_lbl != null:
		var status_text: String = _get_progress_assessment(prog)
		_win_progress_lbl.text = "%d%% — %s" % [int(prog * 100.0), status_text] \
			if prog > 0.0 else "No progress yet — try Observing a building"
	if prog >= 0.80:
		_win_progress_bar.color = Color(0.10, 0.85, 0.25, 1.0)
	elif prog >= 0.50:
		_win_progress_bar.color = Color(0.50, 0.80, 0.20, 1.0)
	else:
		_win_progress_bar.color = Color(0.85, 0.55, 0.10, 1.0)
	_update_win_pulse(prog)


func _update_win_pulse(prog: float) -> void:
	if _win_progress_bar == null:
		return
	if prog >= 0.80 and not _win_pulse_active:
		_win_pulse_active = true
		_start_win_pulse()
	elif prog < 0.80 and _win_pulse_active:
		_win_pulse_active = false
		if _win_pulse_tween != null and _win_pulse_tween.is_valid():
			_win_pulse_tween.kill()
		_win_progress_bar.modulate = Color.WHITE


func _start_win_pulse() -> void:
	if _win_pulse_tween != null and _win_pulse_tween.is_valid():
		_win_pulse_tween.kill()
	_win_pulse_tween = create_tween().set_loops() \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_win_pulse_tween.tween_property(_win_progress_bar, "modulate",
		Color(1.3, 1.3, 1.3, 1.0), 0.5)
	_win_pulse_tween.tween_property(_win_progress_bar, "modulate",
		Color.WHITE, 0.5)


# ── Milestone label ────────────────────────────────────────────────────────────

func _refresh_milestone_label() -> void:
	if _milestone_label == null or _progress_milestones.is_empty():
		return
	var prog: float = _compute_win_progress()
	var best_text:      String = ""
	var best_threshold: float  = 0.0
	for key in _progress_milestones:
		var threshold: float = float(key)
		if prog >= threshold and threshold > best_threshold:
			best_threshold = threshold
			best_text      = _progress_milestones[key]
	if best_text != _current_milestone_text:
		_current_milestone_text = best_text
		_milestone_label.text = best_text
		_milestone_label.visible = not best_text.is_empty()


# ── Tempo indicator ────────────────────────────────────────────────────────────

func _refresh_tempo_indicator() -> void:
	if _days_remaining_lbl == null:
		return
	var prog:      float = _compute_win_progress()
	var time_frac: float = 0.0
	if _day_night != null and _days_allowed > 1:
		var current_day: int = _day_night.current_day
		time_frac = clampf(float(current_day - 1) / float(_days_allowed - 1), 0.0, 1.0)
	var tempo_color: Color
	if prog > time_frac + 0.10:
		tempo_color = C_TEMPO_AHEAD
	elif prog >= time_frac - 0.10:
		tempo_color = C_TEMPO_ON_PACE
	else:
		tempo_color = C_TEMPO_BEHIND
	_days_remaining_lbl.add_theme_color_override("font_color", tempo_color)


func _get_progress_assessment(prog: float) -> String:
	var time_frac: float = 0.0
	if _day_night != null and _days_allowed > 1:
		var current_day: int = _day_night.current_day
		time_frac = clampf(float(current_day - 1) / float(_days_allowed - 1), 0.0, 1.0)
	if prog >= 0.95:
		return "Almost there!"
	elif prog >= 0.80:
		return "Strong position — keep pushing"
	elif prog > time_frac + 0.15:
		return "Ahead of schedule"
	elif prog >= time_frac - 0.10:
		return "On track"
	elif prog >= time_frac - 0.30:
		return "Falling behind — act fast"
	else:
		return "Behind — change strategy"


## Compute a 0.0–1.0 win progress from scenario-specific progress data.
func _compute_win_progress() -> float:
	if _scenario_manager == null or _reputation_system == null or _world_ref == null:
		return 0.0
	var sid: String = _world_ref.active_scenario_id if "active_scenario_id" in _world_ref else ""
	match sid:
		"scenario_1":
			var p: Dictionary = _scenario_manager.get_scenario_1_progress(_reputation_system)
			var score:  int = p.get("edric_score",  ScenarioConfig.S1_EDRIC_START_SCORE)
			var start:  int = p.get("start_score",  ScenarioConfig.S1_EDRIC_START_SCORE)
			var target: int = p.get("win_threshold", ScenarioConfig.S1_WIN_EDRIC_BELOW)
			return clampf(float(start - score) / float(max(start - target, 1)), 0.0, 1.0)
		"scenario_2":
			var p: Dictionary = _scenario_manager.get_scenario_2_progress(_reputation_system)
			var count:  int = p.get("illness_believer_count", 0)
			var target: int = p.get("win_threshold", 6)
			return clampf(float(count) / float(max(target, 1)), 0.0, 1.0)
		"scenario_3":
			var p: Dictionary = _scenario_manager.get_scenario_3_progress(_reputation_system)
			var calder: int   = p.get("calder_score", 50)
			var tomas: int    = p.get("tomas_score",  50)
			var calder_prog: float = clampf(float(calder - 50) / 25.0, 0.0, 1.0)
			var tomas_prog:  float = clampf(float(50 - tomas)  / 15.0, 0.0, 1.0)
			return (calder_prog + tomas_prog) / 2.0
		"scenario_4":
			var current_day: int = _day_night.current_day if _day_night != null else 1
			return clampf(float(current_day) / float(max(_days_allowed, 1)), 0.0, 1.0)
		"scenario_5":
			var p5: Dictionary = _scenario_manager.get_scenario_5_progress(_reputation_system)
			var aldric5: int = p5.get("aldric_score", 48)
			var edric5:  int = p5.get("edric_score",  58)
			var tomas5:  int = p5.get("tomas_score",  45)
			var pa: float = clampf((aldric5 - 48.0) / (65.0 - 48.0), 0.0, 1.0)
			var pe: float = clampf((58.0 - edric5) / (58.0 - 45.0), 0.0, 1.0)
			var win_rivals_max: float = float(p5.get("win_rivals_max", 45))
			var pt: float = clampf((45.0 - tomas5) / maxf(45.0 - win_rivals_max, 1.0), 0.0, 1.0)
			return minf(pa, minf(pe, pt))
		"scenario_6":
			var p6: Dictionary = _scenario_manager.get_scenario_6_progress(_reputation_system)
			var aldric6: int = p6.get("aldric_score", 55)
			var marta6:  int = p6.get("marta_score",  52)
			var pad: float = clampf((55.0 - aldric6) / (55.0 - 30.0), 0.0, 1.0)
			var pmu: float = clampf((marta6 - 52.0) / maxf(60.0 - 52.0, 1.0), 0.0, 1.0)
			return minf(pad, pmu)
	return 0.0


# ── Mini progress ─────────────────────────────────────────────────────────────

func _refresh_mini_progress() -> void:
	if _mini_progress_label == null or _scenario_manager == null:
		return
	var prog: float = _compute_win_progress()
	var pct: int = int(prog * 100.0)
	_mini_progress_label.text = "🏆 %d%%" % pct
	if prog >= 0.80:
		_mini_progress_label.add_theme_color_override("font_color", Color(0.10, 0.90, 0.30, 1.0))
	elif prog >= 0.50:
		_mini_progress_label.add_theme_color_override("font_color", Color(0.50, 0.80, 0.25, 1.0))
	elif prog > 0.0:
		_mini_progress_label.add_theme_color_override("font_color", Color(0.85, 0.70, 0.20, 1.0))
	else:
		_mini_progress_label.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45, 0.6))


func _on_mini_progress_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var j_event := InputEventAction.new()
		j_event.action = "toggle_journal"
		j_event.pressed = true
		Input.parse_input_event(j_event)
