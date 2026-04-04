extends CanvasLayer

## scenario1_hud.gd — Persistent Edric Fenn reputation tracker for Scenario 1.
##
## Shows a thin header at the top of the screen tracking Lord Edric Fenn's
## current reputation score versus the <30 win threshold, plus days remaining.
##
## Layout:
##   Scenario 1: The Alderman's Ruin
##   Edric Fenn  Rep: 67 / 100  Target: <30   [reputation bar]   Days remaining: 29
##   ⚠ Avoid detection — do not get caught eavesdropping
##
## Wire via setup(world, day_night) from main.gd.
## Subscribes to game_tick and scenario_resolved signals.

# ── Palette (matches scenario2_hud.gd / scenario3_hud.gd / scenario4_hud.gd) ─
const C_PANEL_BG  := Color(0.15, 0.10, 0.08, 0.88)
const C_HEADING   := Color(0.91, 0.85, 0.70, 1.0)
const C_BODY      := Color(0.75, 0.70, 0.60, 1.0)
const C_WIN       := Color(0.10, 0.75, 0.22, 1.0)
const C_FAIL      := Color(0.85, 0.15, 0.15, 1.0)
const C_SAFE      := Color(0.85, 0.55, 0.10, 1.0)   # amber — rep still high
const C_DANGER    := Color(0.90, 0.30, 0.10, 1.0)   # orange-red — nearing win
const C_CAUTION   := Color(0.95, 0.80, 0.15, 1.0)   # yellow — getting close

const BAR_WIDTH  := 140
const BAR_HEIGHT := 10

# Win threshold — rep must fall BELOW this.
const WIN_THRESHOLD := 30

# ── Node refs (built in _ready) ─────────────────────────────────────────────
var _panel:       Panel     = null
var _score_lbl:   Label     = null
var _bar:         ColorRect = null
var _bar_bg:      ColorRect = null
var _days_lbl:    Label     = null
var _result_lbl:  Label     = null
var _caution_lbl: Label     = null

# ── Runtime refs ────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null
var _day_night_ref: Node   = null


func _ready() -> void:
	layer = 14   # Above journal (12), consistent with S2/S3/S4 HUDs.
	_build_ui()
	visible = false   # Hidden until setup() is called.


func setup(world: Node2D, day_night: Node) -> void:
	_world_ref     = world
	_day_night_ref = day_night
	visible = true
	if day_night != null:
		day_night.game_tick.connect(_on_game_tick)
	if world != null and "scenario_manager" in world and world.scenario_manager != null:
		world.scenario_manager.scenario_resolved.connect(_on_scenario_resolved)
	_refresh()


# ── UI construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "Scenario1Panel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_PANEL_BG
	panel_style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.custom_minimum_size = Vector2(0, 62)
	_panel.offset_top    = 4
	_panel.offset_bottom = 66
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
	title_lbl.text = "Scenario 1:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	title_lbl.tooltip_text = "The Alderman's Ruin — ruin Lord Edric Fenn's reputation before the tax rolls are signed."
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(title_lbl)

	# ── Rep score + bar ───────────────────────────────────────────────────
	var score_vbox := VBoxContainer.new()
	score_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(score_vbox)

	_score_lbl = Label.new()
	_score_lbl.add_theme_font_size_override("font_size", 12)
	_score_lbl.add_theme_color_override("font_color", C_BODY)
	_score_lbl.text = "Edric Fenn  Rep: — / 100  Target: <30"
	_score_lbl.tooltip_text = "Lord Edric Fenn's current reputation (0–100). Win when it drops below 30."
	_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	score_vbox.add_child(_score_lbl)

	var bar_hbox := HBoxContainer.new()
	score_vbox.add_child(bar_hbox)

	_bar_bg = ColorRect.new()
	_bar_bg.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_bg.color = Color(0.25, 0.25, 0.25)
	_bar_bg.tooltip_text = "Edric's reputation bar — shrinks as rumors take hold. Win when the bar drops into the red zone."
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	bar_hbox.add_child(_bar_bg)

	_bar = ColorRect.new()
	_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar.color = C_SAFE
	_bar_bg.add_child(_bar)

	# ── Caution note ──────────────────────────────────────────────────────
	_caution_lbl = Label.new()
	_caution_lbl.add_theme_font_size_override("font_size", 11)
	_caution_lbl.add_theme_color_override("font_color", Color(0.75, 0.60, 0.35, 0.85))
	_caution_lbl.text = "⚠ Avoid detection"
	_caution_lbl.tooltip_text = "Getting caught eavesdropping fails the scenario immediately."
	_caution_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(_caution_lbl)

	# ── Days remaining / result ───────────────────────────────────────────
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 12)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 30"
	_days_lbl.tooltip_text = "Days left before the tax rolls are signed. The scenario fails on timeout."
	_days_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 14)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	right_vbox.add_child(_result_lbl)

	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 11)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "Target: Edric Fenn Rep < 30"
	legend_lbl.tooltip_text = "Ruin Edric Fenn's reputation below 30 to win the scenario."
	legend_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	right_vbox.add_child(legend_lbl)


# ── Refresh ─────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _world_ref == null:
		return
	if not ("reputation_system" in _world_ref) or _world_ref.reputation_system == null:
		return
	if not ("scenario_manager" in _world_ref) or _world_ref.scenario_manager == null:
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var sm:  ScenarioManager  = _world_ref.scenario_manager
	var progress: Dictionary  = sm.get_scenario_1_progress(rep)

	var score: int = progress["edric_score"]
	var state      = progress["state"]

	# Score label — show the actual value.
	_score_lbl.text = "Edric Fenn  Rep: %d / 100  Target: <%d" % [score, WIN_THRESHOLD]

	# Color the label to reflect proximity to the win threshold.
	if score < WIN_THRESHOLD:
		_score_lbl.add_theme_color_override("font_color", C_WIN)
	elif score < WIN_THRESHOLD + 15:
		_score_lbl.add_theme_color_override("font_color", C_CAUTION)
	else:
		_score_lbl.add_theme_color_override("font_color", C_BODY)

	# Progress bar — shows how far Edric's rep has fallen (100 → 0 is full → empty).
	# The bar shrinks as his reputation drops — visually it "drains" toward victory.
	var ratio: float = clamp(float(score) / 100.0, 0.0, 1.0)
	_bar.anchor_right = ratio
	if score < WIN_THRESHOLD:
		_bar.color = C_WIN
	elif score < WIN_THRESHOLD + 15:
		_bar.color = C_DANGER
	elif score < WIN_THRESHOLD + 30:
		_bar.color = C_CAUTION
	else:
		_bar.color = C_SAFE

	# Days remaining.
	var days_elapsed: int = (sm.get_current_day(_day_night_ref.current_tick) - 1) \
		if _day_night_ref != null else 0
	var days_allowed: int = sm.get_days_allowed()
	_days_lbl.text = "Days remaining: %d" % max(0, days_allowed - days_elapsed)

	# Result label.
	match state:
		ScenarioManager.ScenarioState.WON:
			_result_lbl.text = "VICTORY — Fenn steps down"
			_result_lbl.add_theme_color_override("font_color", C_WIN)
		ScenarioManager.ScenarioState.FAILED:
			_result_lbl.text = "FAILED"
			_result_lbl.add_theme_color_override("font_color", C_FAIL)
		_:
			_result_lbl.text = ""


# ── Signals ─────────────────────────────────────────────────────────────────

func _on_game_tick(_tick: int) -> void:
	_refresh()


func _on_scenario_resolved(scenario_id: int, _state: ScenarioManager.ScenarioState) -> void:
	if scenario_id != 1:
		return
	_refresh()
	if _result_lbl != null:
		var tween := create_tween()
		tween.tween_property(_result_lbl, "modulate:a", 0.0, 0.3).set_delay(1.5)
		tween.tween_property(_result_lbl, "modulate:a", 1.0, 0.2)
