extends CanvasLayer

## scenario3_hud.gd — Persistent dual-track reputation progress display.
##
## Shows a thin header at the top of the screen tracking Calder Fenn and
## Tomas Reeve's reputation scores against their Scenario 3 win targets.
##
## Layout:
##   [Calder Fenn]  Rep: 62 / 100  Target: 75+   [progress bar]
##   [Tomas Reeve]  Rep: 44 / 100  Target: ≤35   [decay bar]
##   Days remaining: 18
##
## Wire via setup(world, day_night) from main.gd.
## Subscribes to game_tick and scenario_resolved signals.

# ── Palette (matches journal.gd) ─────────────────────────────────────────────
const C_PANEL_BG   := Color(0.15, 0.10, 0.08, 0.88)
const C_HEADING    := Color(0.91, 0.85, 0.70, 1.0)
const C_BODY       := Color(0.75, 0.70, 0.60, 1.0)
const C_WIN        := Color(0.10, 0.75, 0.22, 1.0)
const C_FAIL       := Color(0.85, 0.15, 0.15, 1.0)
const C_NEUTRAL    := Color(0.85, 0.55, 0.10, 1.0)

# Bar dimensions
const BAR_WIDTH    := 120
const BAR_HEIGHT   := 10

# ── Node refs (built in _ready) ───────────────────────────────────────────────
var _panel:            Panel          = null
var _calder_score_lbl: Label          = null
var _tomas_score_lbl:  Label          = null
var _calder_bar:       ColorRect      = null
var _calder_bar_bg:    ColorRect      = null
var _tomas_bar:        ColorRect      = null
var _tomas_bar_bg:     ColorRect      = null
var _days_lbl:         Label          = null
var _result_lbl:       Label          = null
var _rival_lbl:        Label          = null

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null
var _day_night_ref: Node   = null


func _ready() -> void:
	layer = 14   # Above journal (12), below nothing gameplay-critical.
	_build_ui()
	visible = false   # Hidden until setup() is called.


func setup(world: Node2D, day_night: Node) -> void:
	_world_ref     = world
	_day_night_ref = day_night
	visible = true
	if day_night != null:
		day_night.game_tick.connect(_on_game_tick)
	# Wire scenario_resolved if world exposes scenario_manager.
	if world != null and "scenario_manager" in world and world.scenario_manager != null:
		world.scenario_manager.scenario_resolved.connect(_on_scenario_resolved)
	# Wire rival_agent signal for activity indicator.
	var rival = world.get("rival_agent") if world != null else null
	if rival != null:
		rival.rival_acted.connect(notify_rival_acted)
	_refresh()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Outer panel — dark semi-transparent strip at top of screen.
	_panel = Panel.new()
	_panel.name = "Scenario3Panel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_PANEL_BG
	panel_style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.custom_minimum_size = Vector2(0, 58)
	_panel.offset_top    = 4
	_panel.offset_bottom = 62
	_panel.offset_left   = 8
	_panel.offset_right  = -8
	add_child(_panel)

	# Root HBox inside panel.
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(hbox)

	# ── Scenario label ────────────────────────────────────────────────────
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 3:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	hbox.add_child(title_lbl)

	# ── Calder track ──────────────────────────────────────────────────────
	var calder_vbox := VBoxContainer.new()
	calder_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(calder_vbox)

	_calder_score_lbl = Label.new()
	_calder_score_lbl.add_theme_font_size_override("font_size", 12)
	_calder_score_lbl.add_theme_color_override("font_color", C_BODY)
	_calder_score_lbl.text = "Calder Fenn  Rep: 50 / 100  Target: 75+"
	_calder_score_lbl.tooltip_text = "Calder Fenn's reputation. Win condition: raise to 75 or higher."
	_calder_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	calder_vbox.add_child(_calder_score_lbl)

	var calder_bar_hbox := HBoxContainer.new()
	calder_vbox.add_child(calder_bar_hbox)

	_calder_bar_bg = ColorRect.new()
	_calder_bar_bg.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_calder_bar_bg.color = Color(0.25, 0.25, 0.25)
	_calder_bar_bg.tooltip_text = "Calder's reputation bar. Grows as you spread praise about him. Aim for 75+."
	_calder_bar_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	calder_bar_hbox.add_child(_calder_bar_bg)

	_calder_bar = ColorRect.new()
	_calder_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_calder_bar.color = C_NEUTRAL
	_calder_bar_bg.add_child(_calder_bar)

	# ── Tomas track ───────────────────────────────────────────────────────
	var tomas_vbox := VBoxContainer.new()
	tomas_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(tomas_vbox)

	_tomas_score_lbl = Label.new()
	_tomas_score_lbl.add_theme_font_size_override("font_size", 12)
	_tomas_score_lbl.add_theme_color_override("font_color", C_BODY)
	_tomas_score_lbl.text = "Tomas Reeve  Rep: 50 / 100  Target: ≤35"
	_tomas_score_lbl.tooltip_text = "Tomas Reeve's reputation. Win condition: drag it down to 35 or lower."
	_tomas_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	tomas_vbox.add_child(_tomas_score_lbl)

	var tomas_bar_hbox := HBoxContainer.new()
	tomas_vbox.add_child(tomas_bar_hbox)

	_tomas_bar_bg = ColorRect.new()
	_tomas_bar_bg.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_tomas_bar_bg.color = Color(0.25, 0.25, 0.25)
	_tomas_bar_bg.tooltip_text = "Tomas's reputation bar. Shrinks as scandal and accusation rumors take hold. Aim to bring it below 35."
	_tomas_bar_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	tomas_bar_hbox.add_child(_tomas_bar_bg)

	_tomas_bar = ColorRect.new()
	_tomas_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_tomas_bar.color = C_NEUTRAL
	_tomas_bar_bg.add_child(_tomas_bar)

	# ── Days remaining / result ───────────────────────────────────────────
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 12)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 30"
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 14)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	right_vbox.add_child(_result_lbl)

	# ── Bar status legend — icons instead of colour names for colorblind safety ──
	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 12)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "[✓] on track  [~] at risk  [✗] failing"
	right_vbox.add_child(legend_lbl)

	# ── Rival activity indicator ──────────────────────────────────────────
	_rival_lbl = Label.new()
	_rival_lbl.add_theme_font_size_override("font_size", 12)
	_rival_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45, 0.80))
	_rival_lbl.text = "Rival: no activity yet"
	_rival_lbl.tooltip_text = "An unseen rival is working against you — praising Tomas and scandaling Calder. Their last known action is shown here."
	_rival_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	right_vbox.add_child(_rival_lbl)


# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _world_ref == null:
		return
	if not ("reputation_system" in _world_ref) or _world_ref.reputation_system == null:
		return
	if not ("scenario_manager" in _world_ref) or _world_ref.scenario_manager == null:
		return

	var rep: ReputationSystem           = _world_ref.reputation_system
	var sm:  ScenarioManager            = _world_ref.scenario_manager
	var progress: Dictionary            = sm.get_scenario_3_progress(rep)

	var calder_score: int = progress["calder_score"]
	var tomas_score:  int = progress["tomas_score"]
	var calder_target: int = progress["calder_win_target"]
	var tomas_target:  int = progress["tomas_win_target"]
	var state = progress["state"]

	# Labels.
	_calder_score_lbl.text = "Calder Fenn   Rep: %d / 100   Target: %d+" % [calder_score, calder_target]
	_tomas_score_lbl.text  = "Tomas Reeve   Rep: %d / 100   Target: \u2264%d" % [tomas_score, tomas_target]

	# Calder bar — grows toward target (75).
	var calder_ratio: float = clamp(float(calder_score) / 100.0, 0.0, 1.0)
	_calder_bar.custom_minimum_size.x = BAR_WIDTH * calder_ratio
	_calder_bar.color = _bar_color_for_score(calder_score, true, calder_target)

	# Tomas bar — represents how far above 30 he still is (we want it to decay).
	# Bar fills from left; reaching target means bar is nearly empty.
	var tomas_ratio: float = clamp(float(tomas_score) / 100.0, 0.0, 1.0)
	_tomas_bar.custom_minimum_size.x = BAR_WIDTH * tomas_ratio
	_tomas_bar.color = _bar_color_for_score(tomas_score, false, tomas_target)

	# Days remaining.
	var days_elapsed: int = (sm.get_current_day(_day_night_ref.current_tick) - 1) \
		if _day_night_ref != null else 0
	var days_allowed: int = sm.get_days_allowed() if sm != null else 30
	_days_lbl.text = "Days remaining: %d" % max(0, days_allowed - days_elapsed)

	# Result label.
	match state:
		ScenarioManager.ScenarioState.WON:
			_result_lbl.text = "✓ VICTORY"
			_result_lbl.add_theme_color_override("font_color", C_WIN)
		ScenarioManager.ScenarioState.FAILED:
			_result_lbl.text = "✗ FAILED"
			_result_lbl.add_theme_color_override("font_color", C_FAIL)
		_:
			_result_lbl.text = ""


func _bar_color_for_score(score: int, higher_is_better: bool, win_target: int) -> Color:
	# Calder: higher is better — effective == score, green at win_target (75).
	# Tomas:  lower is better — flip so effective == 100-score, green at 100-win_target (65).
	# Neutral/at-risk zone: below win_effective but above half of win_effective.
	var effective     := score if higher_is_better else (100 - score)
	var win_effective := win_target if higher_is_better else (100 - win_target)
	if effective >= win_effective:          return C_WIN
	elif effective >= win_effective / 2:    return C_NEUTRAL
	else:                                   return C_FAIL


# ── Rival activity ────────────────────────────────────────────────────────────

## Called by the rival_agent.rival_acted signal each time the rival seeds a rumor.
func notify_rival_acted(day: int, claim_type: String, subject_id: String) -> void:
	if _rival_lbl == null:
		return
	var subject_display := subject_id.replace("_", " ").capitalize()
	_rival_lbl.text = "Rival: Day %d — %s on %s" % [day, claim_type.capitalize(), subject_display]
	_rival_lbl.add_theme_color_override("font_color", Color(1.0, 0.40, 0.20, 1.0))
	# Brief pulse to draw attention.
	var tween := create_tween()
	tween.tween_property(_rival_lbl, "modulate:a", 0.25, 0.12)
	tween.tween_property(_rival_lbl, "modulate:a", 1.0, 0.30)


# ── Signals ───────────────────────────────────────────────────────────────────

func _on_game_tick(_tick: int) -> void:
	_refresh()


func _on_scenario_resolved(scenario_id: int, state: ScenarioManager.ScenarioState) -> void:
	if scenario_id != 3:
		return
	_refresh()
	# Flash the result label briefly.
	if _result_lbl != null:
		var tween := create_tween()
		tween.tween_property(_result_lbl, "modulate:a", 0.0, 0.3).set_delay(1.5)
		tween.tween_property(_result_lbl, "modulate:a", 1.0, 0.2)
