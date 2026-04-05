extends BaseScenarioHud

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

# ── S1-specific palette ──────────────────────────────────────────────────────
const C_SAFE    := Color(0.85, 0.55, 0.10, 1.0)   # amber — rep still high
const C_DANGER  := Color(0.90, 0.30, 0.10, 1.0)   # orange-red — nearing win
const C_CAUTION := Color(0.95, 0.80, 0.15, 1.0)   # yellow — getting close

const WIN_THRESHOLD := 30
const BAR_WIDTH     := 160
const BAR_HEIGHT    := 12

# ── Node refs ────────────────────────────────────────────────────────────────
var _score_lbl:   Label     = null
var _bar:         ColorRect = null
var _bar_bg:      ColorRect = null
var _caution_lbl: Label     = null


func _scenario_number() -> int:
	return 1


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var hbox := _make_panel("Scenario1Panel", 62)

	# Scenario label.
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 1:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	title_lbl.tooltip_text = "The Alderman's Ruin — ruin Lord Edric Fenn's reputation before the tax rolls are signed."
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(title_lbl)

	# Rep score + bar.
	var score_vbox := VBoxContainer.new()
	score_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(score_vbox)

	_score_lbl = Label.new()
	_score_lbl.add_theme_font_size_override("font_size", 13)
	_score_lbl.add_theme_color_override("font_color", C_BODY)
	_score_lbl.text = "Edric Fenn  Rep: — / 100  Target: <30"
	_score_lbl.tooltip_text = "Lord Edric Fenn's current reputation (0–100). Win when it drops below 30."
	_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_text_outline(_score_lbl)
	score_vbox.add_child(_score_lbl)

	var bar_hbox := HBoxContainer.new()
	score_vbox.add_child(bar_hbox)

	var bar_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Edric's reputation bar — shrinks as rumors take hold. Win when the bar drops into the red zone.")
	_bar_bg = bar_pair[0]
	_bar    = bar_pair[1]
	_bar.color = C_SAFE
	bar_hbox.add_child(_bar_bg)

	# Caution note.
	_caution_lbl = Label.new()
	_caution_lbl.add_theme_font_size_override("font_size", 12)
	_caution_lbl.add_theme_color_override("font_color", Color(0.75, 0.60, 0.35, 0.85))
	_caution_lbl.text = "⚠ Avoid detection"
	_caution_lbl.tooltip_text = "Getting caught eavesdropping fails the scenario immediately."
	_caution_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(_caution_lbl)

	# Days remaining + result.
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 13)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 30"
	_days_lbl.tooltip_text = "Days left before the tax rolls are signed. The scenario fails on timeout."
	_days_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_text_outline(_days_lbl)
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 16)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	right_vbox.add_child(_result_lbl)

	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 12)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "Target: Edric Fenn Rep < 30"
	legend_lbl.tooltip_text = "Ruin Edric Fenn's reputation below 30 to win the scenario."
	legend_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	right_vbox.add_child(legend_lbl)


# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _has_world_deps():
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var sm:  ScenarioManager  = _world_ref.scenario_manager
	var progress: Dictionary  = sm.get_scenario_1_progress(rep)

	var score: int     = progress["edric_score"]
	var state          = progress["state"]
	var threshold: int = progress.get("win_threshold", WIN_THRESHOLD)

	_score_lbl.text = "Edric Fenn  Rep: %d / 100  Target: <%d" % [score, threshold]

	if score < threshold:
		_score_lbl.add_theme_color_override("font_color", C_WIN)
	elif score < threshold + 15:
		_score_lbl.add_theme_color_override("font_color", C_CAUTION)
	else:
		_score_lbl.add_theme_color_override("font_color", C_BODY)

	var ratio: float = clamp(float(score) / 100.0, 0.0, 1.0)
	_bar.custom_minimum_size.x = BAR_WIDTH * ratio
	if score < threshold:
		_bar.color = C_WIN
	elif score < threshold + 15:
		_bar.color = C_DANGER
	elif score < threshold + 30:
		_bar.color = C_CAUTION
	else:
		_bar.color = C_SAFE

	_update_days_remaining(sm)
	_update_result_label(state, "VICTORY — Fenn steps down", "FAILED")
