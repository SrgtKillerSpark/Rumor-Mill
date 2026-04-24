class_name ObjectiveHudMetrics
extends Node

## objective_hud_metrics.gd — Metrics row subsystem for ObjectiveHUD (SPA-1004).
##
## Extracted from objective_hud.gd.  Manages the HBoxContainer metrics row
## (Avg Rep, Believers, Pariahs, Threat) that sits below the win-progress bar.
## Call setup() once, then refresh() each tick/day.

# ── Metrics row UI ────────────────────────────────────────────────────────────
var _metrics_row:       HBoxContainer = null
var _lbl_rep_avg:       Label         = null
var _lbl_believers:     Label         = null
var _lbl_rumors_active: Label         = null
var _lbl_threat:        Label         = null

# ── Avg-rep animation state ───────────────────────────────────────────────────
var _last_avg_rep:      int   = -1
var _displayed_avg_rep: float = -1.0
var _avg_rep_tween:       Tween = null
var _avg_rep_flash_tween: Tween = null

# ── Dependencies ──────────────────────────────────────────────────────────────
var _reputation_system:  ReputationSystem  = null
var _intel_store:        PlayerIntelStore  = null
var _scenario_manager:   ScenarioManager   = null
var _day_night:          Node              = null


## Inject dependencies and build the metrics row inside `vbox`.
func setup(
		vbox: VBoxContainer,
		rep_system: ReputationSystem,
		intel_store: PlayerIntelStore,
		scenario_manager: ScenarioManager,
		day_night: Node) -> void:
	_reputation_system = rep_system
	_intel_store       = intel_store
	_scenario_manager  = scenario_manager
	_day_night         = day_night
	_build_metrics_row(vbox)


## Update all metrics labels from live data.  Safe to call every tick.
func refresh() -> void:
	if _reputation_system == null:
		return
	var snaps: Dictionary = _reputation_system.get_all_snapshots()
	if snaps.is_empty():
		return
	var total_score: int = 0
	var dead_count: int  = 0
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


## SPA-805: Scale-pop + green flash on the Believers counter when a rumor is seeded.
func pulse_believers_counter() -> void:
	if _lbl_believers == null:
		return
	_lbl_believers.pivot_offset = _lbl_believers.size / 2.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lbl_believers, "scale", Vector2(1.2, 1.2), 0.12)
	tw.tween_property(_lbl_believers, "scale", Vector2(1.0, 1.0), 0.18) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_method(
		func(c: Color) -> void: _lbl_believers.add_theme_color_override("font_color", c),
		Color(0.20, 1.00, 0.40, 1.0),
		Color(0.345, 0.580, 0.769, 1.0),
		0.40
	)


# ── Build ─────────────────────────────────────────────────────────────────────

func _build_metrics_row(vbox: VBoxContainer) -> void:
	var panel: Panel = vbox.get_parent() as Panel
	if panel != null:
		panel.offset_bottom += 20

	_metrics_row = HBoxContainer.new()
	_metrics_row.add_theme_constant_override("separation", 16)
	_metrics_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_metrics_row)

	_lbl_rep_avg = _make_metric_label("Avg Rep: --")
	_lbl_rep_avg.add_theme_color_override("font_color", Color(0.784, 0.635, 0.180, 1.0))
	_lbl_rep_avg.tooltip_text = "Average NPC reputation score (0-100)"
	_metrics_row.add_child(_lbl_rep_avg)

	_lbl_believers = _make_metric_label("Believers: 0")
	_lbl_believers.add_theme_color_override("font_color", Color(0.345, 0.580, 0.769, 1.0))
	_lbl_believers.tooltip_text = "NPCs who believe at least one active rumor"
	_metrics_row.add_child(_lbl_believers)

	_lbl_rumors_active = _make_metric_label("Pariahs: 0")
	_lbl_rumors_active.add_theme_color_override("font_color", Color(0.90, 0.35, 0.25, 1.0))
	_lbl_rumors_active.tooltip_text = "NPCs whose reputation has collapsed beyond recovery"
	_metrics_row.add_child(_lbl_rumors_active)

	_lbl_threat = _make_metric_label("")
	_lbl_threat.tooltip_text = "How close rivals or inquisitors are to exposing you"
	_metrics_row.add_child(_lbl_threat)


func _make_metric_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	return lbl


# ── Avg-rep animated display ──────────────────────────────────────────────────

func _update_avg_rep_display(new_avg: int) -> void:
	var urgency_color: Color
	if new_avg >= 40:
		urgency_color = Color(0.784, 0.635, 0.180, 1.0)
	elif new_avg >= 25:
		urgency_color = Color(0.90, 0.75, 0.30, 1.0)
	else:
		urgency_color = Color(0.90, 0.45, 0.35, 1.0)
	_lbl_rep_avg.add_theme_color_override("font_color", urgency_color)

	if _last_avg_rep < 0:
		_last_avg_rep      = new_avg
		_displayed_avg_rep = float(new_avg)
		_lbl_rep_avg.text  = "Avg Rep: %d" % new_avg
		return

	if new_avg == _last_avg_rep:
		return

	var delta: int = new_avg - _last_avg_rep
	_last_avg_rep = new_avg

	if _avg_rep_tween != null and _avg_rep_tween.is_valid():
		_avg_rep_tween.kill()
	_avg_rep_tween = create_tween()
	_avg_rep_tween.tween_method(_set_displayed_avg_rep, _displayed_avg_rep, float(new_avg), 0.8) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

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


# ── Threat indicator ──────────────────────────────────────────────────────────

func _refresh_threat() -> void:
	if _lbl_threat == null:
		return
	if _intel_store == null or _scenario_manager == null:
		_lbl_threat.text = ""
		return

	var threat: float = 0.0
	var label_text: String = ""

	if _scenario_manager._active_scenario == 1:
		var current_day: int = _day_night.current_day if _day_night != null else 1
		threat = clampf(float(current_day) / float(max(_scenario_manager.get_days_allowed(), 1)), 0.0, 1.0)
		label_text = "Exposure: %s" % _threat_word(threat)

	elif _scenario_manager._active_scenario == 2:
		var maren_heat: float = _intel_store.get_heat("maren_nun")
		threat = clampf(maren_heat / 80.0, 0.0, 1.0)
		var time_frac: float = _scenario_manager.get_time_fraction(
			_day_night.current_tick if _day_night != null else 0)
		threat = maxf(threat, time_frac * 0.7)
		label_text = "Threat: %s" % _threat_word(threat)

	elif _scenario_manager._active_scenario == 3:
		var time_frac: float = _scenario_manager.get_time_fraction(
			_day_night.current_tick if _day_night != null else 0)
		if time_frac >= 0.75:
			threat = clampf((time_frac - 0.75) / 0.25 * 0.6 + 0.4, 0.0, 1.0)
		else:
			threat = clampf(time_frac * 0.4, 0.0, 1.0)
		if _reputation_system != null:
			var calder: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot("calder_fenn")
			if calder != null and calder.score < 50:
				threat = maxf(threat, clampf(1.0 - float(calder.score) / 50.0, 0.0, 1.0))
		label_text = "Rival: %s" % _threat_word(threat)

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

	elif _scenario_manager._active_scenario == 5:
		var time_frac: float = _scenario_manager.get_time_fraction(
			_day_night.current_tick if _day_night != null else 0)
		threat = clampf(time_frac * 0.5, 0.0, 1.0)
		if _reputation_system != null:
			var aldric: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot("aldric_vane")
			if aldric != null and aldric.score < 50:
				threat = maxf(threat, clampf(1.0 - float(aldric.score - 30) / 20.0, 0.0, 1.0))
		label_text = "Election: %s" % _threat_word(threat)

	elif _scenario_manager._active_scenario == 6:
		var heat: float = _intel_store.get_heat("player") if _intel_store != null else 0.0
		threat = clampf(heat / ScenarioManager.S6_EXPOSED_HEAT, 0.0, 1.0)
		var time_frac: float = _scenario_manager.get_time_fraction(
			_day_night.current_tick if _day_night != null else 0)
		threat = maxf(threat, time_frac * 0.5)
		if _reputation_system != null:
			var marta: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot("marta_coin")
			if marta != null and marta.score < 45:
				threat = maxf(threat, clampf(1.0 - float(marta.score - 30) / 15.0, 0.0, 1.0))
		label_text = "Exposure: %s" % _threat_word(threat)

	else:
		_lbl_threat.text = ""
		return

	_lbl_threat.text = label_text
	_lbl_threat.add_theme_color_override("font_color", _threat_color(threat))


func _threat_word(t: float) -> String:
	if t < 0.25:
		return "Low"
	elif t < 0.50:
		return "Moderate"
	elif t < 0.75:
		return "High"
	else:
		return "Critical"


func _threat_color(t: float) -> Color:
	if t < 0.25:
		return Color(0.35, 0.80, 0.35, 1.0)
	elif t < 0.50:
		return Color(0.90, 0.80, 0.25, 1.0)
	elif t < 0.75:
		return Color(0.95, 0.55, 0.15, 1.0)
	else:
		return Color(0.95, 0.25, 0.15, 1.0)
