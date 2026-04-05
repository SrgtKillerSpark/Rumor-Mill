extends CanvasLayer

## objective_hud.gd — Persistent HUD showing scenario objective and day counter.
##
## Redesigned: top-centre of the screen.
##   - Large day counter with urgency colouring (green → yellow → red)
##   - Plain-language objective line
##   - Day timeline progress bar (colour matches day counter urgency)
##   - Win-condition progress bar (green, driven by scenario manager)
##   - Metrics row: Avg Rep, Believers, Pariahs
##   - Faction influence mini-panel (merchant / noble / clergy)

@onready var day_label:        Label     = $Panel/VBox/DayRow/DayLabel
@onready var day_max_label:    Label     = $Panel/VBox/DayRow/DayMaxLabel
@onready var time_label:       Label     = $Panel/VBox/DayRow/TimeOfDayLabel
@onready var objective_label:  Label     = $Panel/VBox/ObjectiveLabel
@onready var target_label:     Label     = $Panel/VBox/TargetLabel
@onready var progress_bar:     ColorRect = $Panel/VBox/DayProgressBG/DayProgressBar
@onready var progress_bg:      ColorRect = $Panel/VBox/DayProgressBG
@onready var win_progress_bar: ColorRect = $Panel/VBox/WinProgressBG/WinProgressBar
@onready var win_progress_lbl: Label     = $Panel/VBox/WinProgressBG/WinProgressLabel

var _scenario_manager: ScenarioManager = null
var _day_night:        Node            = null
var _days_allowed:     int             = 30

# ── Dawn bulletin / deadline warning state ───────────────────────────────────
var _reputation_system: ReputationSystem = null
var _intel_store: PlayerIntelStore = null
## NPC id → score snapshot taken at previous dawn for overnight delta comparison.
var _prev_dawn_scores: Dictionary = {}
## The programmatically-created banner label (shared for bulletin & warnings).
var _banner_label: Label = null
var _banner_tween: Tween = null
## Programmatic metrics row added below the scene-defined progress bar.
var _metrics_row: HBoxContainer = null
var _lbl_rumors_active: Label = null
var _lbl_rep_avg: Label = null
var _lbl_believers: Label = null
var _lbl_threat: Label = null

# ── Reputation tween state ───────────────────────────────────────────────────
## Last "true" avg rep value from the reputation system.
var _last_avg_rep: int = -1
## Currently displayed (possibly mid-tween) value used to drive label text.
var _displayed_avg_rep: float = -1.0
var _avg_rep_tween: Tween = null
var _avg_rep_flash_tween: Tween = null

# ── Day counter pulse tween ──────────────────────────────────────────────────
var _day_counter_tween: Tween = null

# ── Faction overview mini-panel ──────────────────────────────────────────────
var _faction_panel: Panel = null
var _faction_labels: Dictionary = {}  # faction_id → {mood: Label, bar: ColorRect}
var _world_ref: Node2D = null

# ── Urgency colour palette for day counter ───────────────────────────────────
const C_DAY_SAFE    := Color(0.30, 0.85, 0.35, 1.0)  # green
const C_DAY_CAUTION := Color(0.95, 0.85, 0.15, 1.0)  # yellow
const C_DAY_URGENT  := Color(0.95, 0.55, 0.10, 1.0)  # orange
const C_DAY_CRITICAL := Color(0.95, 0.20, 0.10, 1.0) # red


func _ready() -> void:
	layer = 4
	_build_banner()
	_build_metrics_row()


func setup(scenario_manager: ScenarioManager, day_night: Node, rep_system: ReputationSystem = null, intel_store: PlayerIntelStore = null) -> void:
	_scenario_manager  = scenario_manager
	_day_night         = day_night
	_days_allowed      = scenario_manager.get_days_allowed()
	_reputation_system = rep_system
	_intel_store       = intel_store
	day_max_label.text = "%d" % _days_allowed
	_refresh()
	if day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_day_changed)
	if day_night.has_signal("game_tick"):
		day_night.game_tick.connect(_on_tick)
	if day_night.has_signal("day_transition_started"):
		day_night.day_transition_started.connect(_on_day_transition_started)
	if scenario_manager.has_signal("deadline_warning"):
		scenario_manager.deadline_warning.connect(_on_deadline_warning)
	# Capture initial reputation scores for the first dawn comparison.
	_snapshot_dawn_scores()


## Called by main.gd to provide world reference for faction overview.
func setup_world(world: Node2D) -> void:
	_world_ref = world
	_build_faction_panel()


func _on_day_changed(_day: int) -> void:
	_refresh()
	_show_dawn_bulletin()
	_snapshot_dawn_scores()


func _on_day_transition_started(_day: int) -> void:
	_pulse_day_counter()


func _pulse_day_counter() -> void:
	if day_label == null:
		return
	if _day_counter_tween != null and _day_counter_tween.is_valid():
		_day_counter_tween.kill()
		day_label.scale = Vector2.ONE
	day_label.pivot_offset = day_label.size / 2.0
	_day_counter_tween = create_tween()
	_day_counter_tween.tween_property(day_label, "scale", Vector2(1.2, 1.2), 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_day_counter_tween.tween_property(day_label, "scale", Vector2(1.0, 1.0), 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _on_tick(_tick: int) -> void:
	_refresh_time()


func _refresh() -> void:
	if _scenario_manager == null:
		return

	# Build a concise objective: "Discredit Edric Fenn — 12 days remaining"
	var one_liner: String = _scenario_manager.get_objective_one_liner()
	var current_day: int = _day_night.current_day if _day_night != null else 1
	var remaining: int = max(_days_allowed - current_day + 1, 0)
	objective_label.text = "%s — %d day%s remaining" % [
		one_liner, remaining, "" if remaining == 1 else "s"]

	target_label.text = _scenario_manager.get_win_condition_line()

	_refresh_time()
	_refresh_metrics()
	_refresh_win_progress()
	_refresh_faction_panel()


func _refresh_time() -> void:
	if _day_night == null:
		return

	var current_day: int = _day_night.current_day

	# ── Day counter with urgency colouring ───────────────────────────────
	day_label.text = "DAY %d" % current_day
	var fraction: float = clampf(float(current_day - 1) / float(max(_days_allowed - 1, 1)), 0.0, 1.0)
	var day_color: Color = _get_urgency_color(fraction)
	day_label.add_theme_color_override("font_color", day_color)

	# Update time-of-day label.
	if "current_tick" in _day_night and "ticks_per_day" in _day_night:
		var tick: int      = _day_night.current_tick
		var tpd:  int      = _day_night.ticks_per_day
		var hour: float    = float(tick) / float(tpd) * 24.0
		var h:    int      = int(hour) % 24
		var m:    int      = int((hour - int(hour)) * 60.0)
		var ampm: String   = "AM" if h < 12 else "PM"
		var h12:  int      = h % 12
		if h12 == 0:
			h12 = 12
		time_label.text = "%d:%02d %s" % [h12, m, ampm]

	# Update day timeline progress bar.
	if progress_bar != null and progress_bg != null:
		progress_bar.anchor_right = fraction
		progress_bar.color = day_color


## Map a 0-1 fraction to a green→yellow→orange→red gradient.
func _get_urgency_color(fraction: float) -> Color:
	if fraction < 0.50:
		return C_DAY_SAFE
	elif fraction < 0.70:
		var t: float = (fraction - 0.50) / 0.20
		return C_DAY_SAFE.lerp(C_DAY_CAUTION, t)
	elif fraction < 0.85:
		var t: float = (fraction - 0.70) / 0.15
		return C_DAY_CAUTION.lerp(C_DAY_URGENT, t)
	else:
		var t: float = (fraction - 0.85) / 0.15
		return C_DAY_URGENT.lerp(C_DAY_CRITICAL, t)


# ── Win-condition progress bar ───────────────────────────────────────────────

func _refresh_win_progress() -> void:
	if _scenario_manager == null or win_progress_bar == null or _reputation_system == null:
		return
	var prog: float = _compute_win_progress()
	win_progress_bar.anchor_right = prog
	if win_progress_lbl != null:
		var status_text: String = _get_progress_assessment(prog)
		win_progress_lbl.text = "%d%% — %s" % [int(prog * 100.0), status_text] if prog > 0.0 else "No progress yet — try Observing a building"
	# Colour: shifts from neutral amber → green as progress increases.
	if prog >= 0.80:
		win_progress_bar.color = Color(0.10, 0.85, 0.25, 1.0)
	elif prog >= 0.50:
		win_progress_bar.color = Color(0.50, 0.80, 0.20, 1.0)
	else:
		win_progress_bar.color = Color(0.85, 0.55, 0.10, 1.0)


## Returns a plain-English "How am I doing?" assessment based on progress vs time.
func _get_progress_assessment(prog: float) -> String:
	var time_frac: float = 0.0
	if _day_night != null and _days_allowed > 1:
		var current_day: int = _day_night.current_day
		time_frac = clampf(float(current_day - 1) / float(_days_allowed - 1), 0.0, 1.0)

	# Compare progress to time elapsed to give a relative assessment.
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
			var score: int = p.get("edric_score", 50)
			var target: int = p.get("win_threshold", 30)
			# From 50 → target: progress = (50 - score) / (50 - target)
			return clampf(float(50 - score) / float(max(50 - target, 1)), 0.0, 1.0)
		"scenario_2":
			var p: Dictionary = _scenario_manager.get_scenario_2_progress(_reputation_system)
			var count: int = p.get("illness_believer_count", 0)
			var target: int = p.get("win_threshold", 6)
			return clampf(float(count) / float(max(target, 1)), 0.0, 1.0)
		"scenario_3":
			var p: Dictionary = _scenario_manager.get_scenario_3_progress(_reputation_system)
			var calder: int = p.get("calder_score", 50)
			var tomas: int = p.get("tomas_score", 50)
			var calder_prog: float = clampf(float(calder - 50) / 25.0, 0.0, 1.0)
			var tomas_prog: float = clampf(float(50 - tomas) / 15.0, 0.0, 1.0)
			return (calder_prog + tomas_prog) / 2.0
		"scenario_4":
			# Survival scenario — progress = days survived / total days.
			var current_day: int = _day_night.current_day if _day_night != null else 1
			return clampf(float(current_day) / float(max(_days_allowed, 1)), 0.0, 1.0)
	return 0.0


# ── Metrics row (below progress bar) ─────────────────────────────────────────

func _build_metrics_row() -> void:
	# Expand the Panel to make room for the metrics row.
	var panel: Panel = $Panel
	panel.offset_bottom += 20

	# Add metrics row as a child of Panel/VBox.
	var vbox: VBoxContainer = $Panel/VBox
	_metrics_row = HBoxContainer.new()
	_metrics_row.add_theme_constant_override("separation", 16)
	_metrics_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_metrics_row)

	# Average reputation metric
	_lbl_rep_avg = _make_metric_label("Avg Rep: --")
	_lbl_rep_avg.add_theme_color_override("font_color", Color(0.784, 0.635, 0.180, 1.0))  # MERCH_TRIM gold
	_lbl_rep_avg.tooltip_text = "Average NPC reputation score (0-100)"
	_metrics_row.add_child(_lbl_rep_avg)

	# Believers count (unique NPCs in BELIEVE/SPREAD/ACT state for any rumor)
	_lbl_believers = _make_metric_label("Believers: 0")
	_lbl_believers.add_theme_color_override("font_color", Color(0.345, 0.580, 0.769, 1.0))  # WATER_L (#5894C4)
	_lbl_believers.tooltip_text = "NPCs who believe at least one active rumor"
	_metrics_row.add_child(_lbl_believers)

	# Socially dead count
	_lbl_rumors_active = _make_metric_label("Pariahs: 0")
	_lbl_rumors_active.add_theme_color_override("font_color", Color(0.90, 0.35, 0.25, 1.0))
	_lbl_rumors_active.tooltip_text = "NPCs whose reputation has collapsed beyond recovery"
	_metrics_row.add_child(_lbl_rumors_active)

	# Threat level indicator (SPA-479)
	_lbl_threat = _make_metric_label("")
	_lbl_threat.tooltip_text = "How close rivals or inquisitors are to exposing you"
	_metrics_row.add_child(_lbl_threat)


func _make_metric_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	return lbl


func _refresh_metrics() -> void:
	if _reputation_system == null:
		return
	var snaps: Dictionary = _reputation_system.get_all_snapshots()
	if snaps.is_empty():
		return
	var total_score: int = 0
	var dead_count: int = 0
	for npc_id in snaps:
		var snap: ReputationSystem.ReputationSnapshot = snaps[npc_id]
		total_score += snap.score
		if snap.is_socially_dead:
			dead_count += 1
	var avg: int = total_score / max(snaps.size(), 1)
	if _lbl_rep_avg != null:
		_update_avg_rep_display(avg)
	if _lbl_believers != null:
		_lbl_believers.text = "Believers: %d" % _reputation_system.get_global_believer_count()
	if _lbl_rumors_active != null:
		_lbl_rumors_active.text = "Pariahs: %d" % dead_count
	_refresh_threat()


## Animate the avg-rep label from its current displayed value to new_avg.
## Color flash: green tint for gains, red tint for losses, fading back to white.
func _update_avg_rep_display(new_avg: int) -> void:
	# Always keep the urgency color up-to-date.
	var urgency_color: Color
	if new_avg >= 40:
		urgency_color = Color(0.784, 0.635, 0.180, 1.0)  # MERCH_TRIM gold
	elif new_avg >= 25:
		urgency_color = Color(0.90, 0.75, 0.30, 1.0)
	else:
		urgency_color = Color(0.90, 0.45, 0.35, 1.0)
	_lbl_rep_avg.add_theme_color_override("font_color", urgency_color)

	# First call — initialise without animation.
	if _last_avg_rep < 0:
		_last_avg_rep      = new_avg
		_displayed_avg_rep = float(new_avg)
		_lbl_rep_avg.text  = "Avg Rep: %d" % new_avg
		return

	# No meaningful change — let any running tween finish.
	if new_avg == _last_avg_rep:
		return

	var delta: int = new_avg - _last_avg_rep
	_last_avg_rep = new_avg

	# Kill the previous number tween and start from wherever we currently are.
	if _avg_rep_tween != null and _avg_rep_tween.is_valid():
		_avg_rep_tween.kill()
	_avg_rep_tween = create_tween()
	_avg_rep_tween.tween_method(_set_displayed_avg_rep, _displayed_avg_rep, float(new_avg), 0.8) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Brief color flash using self_modulate (does not fight font_color override).
	var flash_color: Color = Color(0.20, 0.90, 0.35, 1.0) if delta > 0 else Color(0.90, 0.25, 0.15, 1.0)
	if _avg_rep_flash_tween != null and _avg_rep_flash_tween.is_valid():
		_avg_rep_flash_tween.kill()
		_lbl_rep_avg.self_modulate = Color.WHITE
	_avg_rep_flash_tween = create_tween()
	_avg_rep_flash_tween.tween_property(_lbl_rep_avg, "self_modulate", flash_color, 0.05) \
		.set_ease(Tween.EASE_OUT)
	_avg_rep_flash_tween.tween_property(_lbl_rep_avg, "self_modulate", Color.WHITE, 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func _set_displayed_avg_rep(value: float) -> void:
	_displayed_avg_rep = value
	if _lbl_rep_avg != null:
		_lbl_rep_avg.text = "Avg Rep: %d" % int(value)


# ── Threat level indicator (SPA-479) ────────────────────────────────────────

func _refresh_threat() -> void:
	if _lbl_threat == null:
		return
	if _intel_store == null or _scenario_manager == null:
		_lbl_threat.text = ""
		return

	var threat: float = 0.0   # 0.0 = safe, 1.0 = maximum danger
	var label_text: String = ""

	# S1: detection risk from eavesdrop heat exposure.
	if _scenario_manager._active_scenario == 1:
		# S1 has no heat system — threat is based on time pressure only.
		var current_day: int = _day_night.current_day if _day_night != null else 1
		threat = clampf(float(current_day) / float(max(_days_allowed, 1)), 0.0, 1.0)
		label_text = "Exposure: %s" % _threat_word(threat)

	# S2: threat = how close Maren is to rejecting (approx via heat + time).
	elif _scenario_manager._active_scenario == 2:
		var maren_heat: float = _intel_store.get_heat("maren_nun")
		threat = clampf(maren_heat / 80.0, 0.0, 1.0)
		# Also factor in time pressure.
		var time_frac: float = _scenario_manager.get_time_fraction(
			_day_night.current_tick if _day_night != null else 0)
		threat = maxf(threat, time_frac * 0.7)
		label_text = "Threat: %s" % _threat_word(threat)

	# S3: threat = rival agent intensity (based on time in final quarter).
	elif _scenario_manager._active_scenario == 3:
		var time_frac: float = _scenario_manager.get_time_fraction(
			_day_night.current_tick if _day_night != null else 0)
		# Rival escalates in final quarter.
		if time_frac >= 0.75:
			threat = clampf((time_frac - 0.75) / 0.25 * 0.6 + 0.4, 0.0, 1.0)
		else:
			threat = clampf(time_frac * 0.4, 0.0, 1.0)
		# Also factor in Calder's danger zone.
		if _reputation_system != null:
			var calder: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot("calder_fenn")
			if calder != null and calder.score < 50:
				threat = maxf(threat, clampf(1.0 - float(calder.score) / 50.0, 0.0, 1.0))
		label_text = "Rival: %s" % _threat_word(threat)

	# S4: threat = inverse of weakest protected NPC's score margin above 45.
	elif _scenario_manager._active_scenario == 4:
		var min_margin: int = 100
		for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
			if _reputation_system == null:
				break
			var snap: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot(npc_id)
			if snap != null:
				var margin: int = snap.score - ScenarioManager.S4_FAIL_REP_BELOW
				if margin < min_margin:
					min_margin = margin
		threat = clampf(1.0 - float(max(min_margin, 0)) / 30.0, 0.0, 1.0)
		label_text = "Inquisitor: %s" % _threat_word(threat)

	else:
		_lbl_threat.text = ""
		return

	_lbl_threat.text = label_text
	_lbl_threat.add_theme_color_override("font_color", _threat_color(threat))


## Convert a 0-1 threat value to a descriptive word.
func _threat_word(t: float) -> String:
	if t < 0.25:
		return "Low"
	elif t < 0.50:
		return "Moderate"
	elif t < 0.75:
		return "High"
	else:
		return "Critical"


## Convert a 0-1 threat value to a colour (green → amber → red).
func _threat_color(t: float) -> Color:
	if t < 0.25:
		return Color(0.35, 0.80, 0.35, 1.0)
	elif t < 0.50:
		return Color(0.90, 0.80, 0.25, 1.0)
	elif t < 0.75:
		return Color(0.95, 0.55, 0.15, 1.0)
	else:
		return Color(0.95, 0.25, 0.15, 1.0)


# ── Faction influence mini-panel ─────────────────────────────────────────────

func _build_faction_panel() -> void:
	if _world_ref == null:
		return

	var panel: Panel = $Panel
	_faction_panel = Panel.new()
	_faction_panel.offset_left = panel.offset_left
	_faction_panel.offset_right = panel.offset_right
	_faction_panel.anchor_left = 0.5
	_faction_panel.anchor_right = 0.5
	_faction_panel.offset_top = panel.offset_bottom + 2
	_faction_panel.offset_bottom = panel.offset_bottom + 58

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.07, 0.05, 0.88)
	_faction_panel.add_child(bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 8.0
	hbox.offset_top = 4.0
	hbox.offset_right = -8.0
	hbox.offset_bottom = -4.0
	hbox.add_theme_constant_override("separation", 12)
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
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Faction name label
		var name_lbl := Label.new()
		name_lbl.text = info["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", info["color"])
		col.add_child(name_lbl)

		# Mood label
		var mood_lbl := Label.new()
		mood_lbl.text = "Calm"
		mood_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mood_lbl.add_theme_font_size_override("font_size", 10)
		mood_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50, 1.0))
		mood_lbl.add_theme_constant_override("outline_size", 1)
		mood_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		col.add_child(mood_lbl)

		# Influence bar background
		var bar_bg := ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(0, 4)
		bar_bg.color = Color(0.20, 0.15, 0.08, 1.0)
		col.add_child(bar_bg)

		# Influence bar fill
		var bar_fill := ColorRect.new()
		bar_fill.anchor_bottom = 1.0
		bar_fill.anchor_right = 0.0
		bar_fill.color = info["color"]
		bar_bg.add_child(bar_fill)

		_faction_labels[faction_id] = {"mood": mood_lbl, "bar": bar_fill}
		hbox.add_child(col)

	add_child(_faction_panel)


func _refresh_faction_panel() -> void:
	if _faction_panel == null or _world_ref == null:
		return
	if not "npcs" in _world_ref:
		return

	for faction_id in ["merchant", "noble", "clergy"]:
		var member_count: int = 0
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
					break  # count each NPC once

		# Derive faction mood from believer ratio.
		var ratio: float = float(believer_count) / float(max(member_count, 1))
		var mood: String
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


# ── Banner system (dawn bulletin + deadline warnings) ────────────────────────

func _build_banner() -> void:
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Use proportional anchoring so the banner stays below the HUD panel on all resolutions.
	_banner_label.anchor_left = 0.15
	_banner_label.anchor_right = 0.85
	_banner_label.anchor_top = 0.0
	_banner_label.anchor_bottom = 0.0
	_banner_label.offset_top = 165.0
	_banner_label.offset_bottom = 235.0
	_banner_label.offset_left = 0.0
	_banner_label.offset_right = 0.0
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.add_theme_font_size_override("font_size", 13)
	_banner_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1.0))
	_banner_label.add_theme_constant_override("outline_size", 2)
	_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner_label.modulate.a = 0.0
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner_label)


func _show_banner(text: String, color: Color, duration: float = 6.0) -> void:
	if _banner_label == null:
		return
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)
	_banner_label.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_label, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(_banner_label, "modulate:a", 0.0, 1.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


## Capture reputation scores at dawn for overnight comparison.
func _snapshot_dawn_scores() -> void:
	if _reputation_system == null:
		return
	_prev_dawn_scores.clear()
	var snaps: Dictionary = _reputation_system.get_all_snapshots()
	for npc_id in snaps:
		var snap: ReputationSystem.ReputationSnapshot = snaps[npc_id]
		_prev_dawn_scores[npc_id] = snap.score


## Show a morning popup summarizing significant overnight reputation changes.
func _show_dawn_bulletin() -> void:
	if _reputation_system == null or _prev_dawn_scores.is_empty():
		return
	var snaps: Dictionary = _reputation_system.get_all_snapshots()
	var lines: Array[String] = []
	for npc_id in snaps:
		if not _prev_dawn_scores.has(npc_id):
			continue
		var snap: ReputationSystem.ReputationSnapshot = snaps[npc_id]
		var prev_score: int = _prev_dawn_scores[npc_id]
		var delta: int = snap.score - prev_score
		if abs(delta) < 3:
			continue
		var arrow: String = "+" if delta > 0 else ""
		var npc_name: String = npc_id.replace("_", " ").capitalize()
		lines.append("%s %s%d (%d)" % [npc_name, arrow, delta, snap.score])
	if lines.is_empty():
		return
	var bulletin: String = "Dawn Report\n" + "\n".join(lines)
	_show_banner(bulletin, Color(0.85, 0.78, 0.55, 1.0), 8.0)


## Show a deadline warning banner at 75% and 90% time thresholds.
func _on_deadline_warning(threshold: float, days_remaining: int) -> void:
	var urgency: String
	var color: Color
	if threshold >= 0.90:
		urgency = "CRITICAL"
		color = C_DAY_CRITICAL
	else:
		urgency = "WARNING"
		color = C_DAY_URGENT
	var text: String = "%s - %d day%s remaining!" % [
		urgency, days_remaining, "" if days_remaining == 1 else "s"]
	_show_banner(text, color, 5.0)
