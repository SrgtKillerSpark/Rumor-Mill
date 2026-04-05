extends CanvasLayer

## objective_hud.gd — Persistent HUD showing scenario objective and day counter.
##
## Shows at the top-left of the screen:
##   • Scenario title (gold)
##   • One-line objective (first sentence of startingText)
##   • "Day X / Y" counter + current time-of-day label, updated each tick
##   • Amber day progress bar that fills as days pass

@onready var title_label:     Label     = $Panel/VBox/TitleLabel
@onready var objective_label: Label     = $Panel/VBox/ObjectiveLabel
@onready var target_label:    Label     = $Panel/VBox/TargetLabel
@onready var day_label:       Label     = $Panel/VBox/DayRow/DayLabel
@onready var time_label:      Label     = $Panel/VBox/DayRow/TimeOfDayLabel
@onready var progress_bar:    ColorRect = $Panel/VBox/DayProgressBG/DayProgressBar
@onready var progress_bg:     ColorRect = $Panel/VBox/DayProgressBG

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


func _ready() -> void:
	layer = 4
	title_label.add_theme_font_size_override("font_size", 20)
	objective_label.add_theme_font_size_override("font_size", 13)
	_build_banner()
	_build_metrics_row()


func setup(scenario_manager: ScenarioManager, day_night: Node, rep_system: ReputationSystem = null, intel_store: PlayerIntelStore = null) -> void:
	_scenario_manager  = scenario_manager
	_day_night         = day_night
	_days_allowed      = scenario_manager.get_days_allowed()
	_reputation_system = rep_system
	_intel_store       = intel_store
	_refresh()
	if day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_day_changed)
	if day_night.has_signal("game_tick"):
		day_night.game_tick.connect(_on_tick)
	if scenario_manager.has_signal("deadline_warning"):
		scenario_manager.deadline_warning.connect(_on_deadline_warning)
	# Capture initial reputation scores for the first dawn comparison.
	_snapshot_dawn_scores()


func _on_day_changed(_day: int) -> void:
	_refresh()
	_show_dawn_bulletin()
	_snapshot_dawn_scores()


func _on_tick(_tick: int) -> void:
	_refresh_time()


func _refresh() -> void:
	if _scenario_manager == null:
		return

	title_label.text = _scenario_manager.get_title()
	objective_label.text = _scenario_manager.get_objective_one_liner()
	target_label.text = _scenario_manager.get_win_condition_line()

	_refresh_time()
	_refresh_metrics()


func _refresh_time() -> void:
	if _day_night == null:
		return

	var current_day: int = _day_night.current_day
	day_label.text = "Day %d / %d" % [current_day, _days_allowed]

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

	# Update progress bar width as a fraction of days_allowed.
	if progress_bar != null and progress_bg != null:
		var fraction: float = clampf(float(current_day - 1) / float(max(_days_allowed - 1, 1)), 0.0, 1.0)
		# Animate the bar width by adjusting anchor_right.
		progress_bar.anchor_right = fraction
		# Colour shifts from amber → orange-red in the last 25% of days.
		if fraction >= 0.75:
			var t: float = (fraction - 0.75) / 0.25
			progress_bar.color = Color(0.85 + 0.1 * t, 0.55 - 0.35 * t, 0.10 - 0.10 * t, 1.0)
		else:
			progress_bar.color = Color(0.85, 0.55, 0.10, 1.0)


# ── Metrics row (below progress bar) ─────────────────────────────────────────

func _build_metrics_row() -> void:
	# Expand the Panel to make room for the metrics row.
	var panel: Panel = $Panel
	panel.offset_bottom += 22

	# Add metrics row as a child of Panel/VBox.
	var vbox: VBoxContainer = $Panel/VBox
	_metrics_row = HBoxContainer.new()
	_metrics_row.add_theme_constant_override("separation", 12)
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
		_lbl_rep_avg.text = "Avg Rep: %d" % avg
		if avg >= 40:
			_lbl_rep_avg.add_theme_color_override("font_color", Color(0.784, 0.635, 0.180, 1.0))  # MERCH_TRIM gold
		elif avg >= 25:
			_lbl_rep_avg.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30, 1.0))
		else:
			_lbl_rep_avg.add_theme_color_override("font_color", Color(0.90, 0.45, 0.35, 1.0))
	if _lbl_believers != null:
		_lbl_believers.text = "Believers: %d" % _reputation_system.get_global_believer_count()
	if _lbl_rumors_active != null:
		_lbl_rumors_active.text = "Pariahs: %d" % dead_count


# ── Banner system (dawn bulletin + deadline warnings) ────────────────────────

func _build_banner() -> void:
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Use proportional anchoring so the banner stays below the HUD panel on all resolutions.
	_banner_label.anchor_left = 0.05
	_banner_label.anchor_right = 0.95
	_banner_label.anchor_top = 0.0
	_banner_label.anchor_bottom = 0.0
	_banner_label.offset_top = 110.0
	_banner_label.offset_bottom = 180.0
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
		var arrow: String = "▲" if delta > 0 else "▼"
		var npc_name: String = npc_id.replace("_", " ").capitalize()
		lines.append("%s %s %+d (%d)" % [arrow, npc_name, delta, snap.score])
	if lines.is_empty():
		return
	var bulletin: String = "☀ Dawn Report\n" + "\n".join(lines)
	_show_banner(bulletin, Color(0.85, 0.78, 0.55, 1.0), 8.0)


## Show a deadline warning banner at 75% and 90% time thresholds.
func _on_deadline_warning(threshold: float, days_remaining: int) -> void:
	var urgency: String
	var color: Color
	if threshold >= 0.90:
		urgency = "CRITICAL"
		color = Color(0.95, 0.20, 0.10, 1.0)
	else:
		urgency = "WARNING"
		color = Color(0.95, 0.65, 0.10, 1.0)
	var text: String = "⚠ %s — %d day%s remaining!" % [
		urgency, days_remaining, "" if days_remaining == 1 else "s"]
	_show_banner(text, color, 5.0)
