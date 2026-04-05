extends BaseScenarioHud

## scenario6_hud.gd — Dual-track reputation + heat stealth display.
##
## Shows Aldric Vane (target to expose) and Marta Coin (patron to protect)
## reputation tracks, plus a heat gauge with the S6 lower ceiling (60).
##
## Layout:
##   Scenario 6: The Merchant's Debt
##   [Aldric Vane]  Rep: 55 / 100  Target: ≤30  [bar]
##   [Marta Coin]   Rep: 52 / 100  Target: 60+  [bar]
##   Heat: 0 / 60                                [bar]
##   Days remaining: 22
##
## Wire via setup(world, day_night) from main.gd.

const BAR_WIDTH  := 130
const BAR_HEIGHT := 10

# ── Node refs ────────────────────────────────────────────────────────────────
var _aldric_score_lbl: Label     = null
var _marta_score_lbl:  Label     = null
var _heat_lbl:         Label     = null
var _aldric_bar:       ColorRect = null
var _aldric_bar_bg:    ColorRect = null
var _marta_bar:        ColorRect = null
var _marta_bar_bg:     ColorRect = null
var _heat_bar:         ColorRect = null
var _heat_bar_bg:      ColorRect = null


func _scenario_number() -> int:
	return 6


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var hbox := _make_panel("Scenario6Panel", 78, 14)

	# Title.
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 6:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	title_lbl.tooltip_text = "The Merchant's Debt — expose Aldric Vane (rep ≤ 30) while protecting Marta Coin (rep ≥ 60). Heat ceiling is 60."
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(title_lbl)

	# Aldric track (target — expose / undermine).
	var aldric_vbox := VBoxContainer.new()
	aldric_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(aldric_vbox)

	_aldric_score_lbl = Label.new()
	_aldric_score_lbl.add_theme_font_size_override("font_size", 11)
	_aldric_score_lbl.add_theme_color_override("font_color", C_BODY)
	_aldric_score_lbl.text = "Aldric Vane  Rep: 55 / 100  Target: \u226430"
	_aldric_score_lbl.tooltip_text = "Aldric Vane's reputation. Win condition: drag to 30 or below to expose his embezzlement."
	_aldric_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_text_outline(_aldric_score_lbl)
	aldric_vbox.add_child(_aldric_score_lbl)

	var aldric_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Aldric's reputation. Shrinks with Accusation/Scandal rumors. Must reach 30 or below to win.")
	_aldric_bar_bg = aldric_pair[0]
	_aldric_bar    = aldric_pair[1]
	aldric_vbox.add_child(_aldric_bar_bg)

	# Marta track (patron — protect / boost).
	var marta_vbox := VBoxContainer.new()
	marta_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(marta_vbox)

	_marta_score_lbl = Label.new()
	_marta_score_lbl.add_theme_font_size_override("font_size", 11)
	_marta_score_lbl.add_theme_color_override("font_color", C_BODY)
	_marta_score_lbl.text = "Marta Coin  Rep: 52 / 100  Target: 60+"
	_marta_score_lbl.tooltip_text = "Marta Coin's reputation. Win condition: keep at 60 or above. Below 30 = instant fail (she's been silenced)."
	_marta_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_text_outline(_marta_score_lbl)
	marta_vbox.add_child(_marta_score_lbl)

	var marta_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Marta's reputation. Grows with Praise rumors. Must stay at 60+ to win. Below 30 = instant fail.")
	_marta_bar_bg = marta_pair[0]
	_marta_bar    = marta_pair[1]
	marta_vbox.add_child(_marta_bar_bg)

	# Heat gauge.
	var heat_vbox := VBoxContainer.new()
	heat_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(heat_vbox)

	_heat_lbl = Label.new()
	_heat_lbl.add_theme_font_size_override("font_size", 11)
	_heat_lbl.add_theme_color_override("font_color", C_BODY)
	_heat_lbl.text = "Heat: 0 / 60"
	_heat_lbl.tooltip_text = "Your suspicion level. Guards are on Aldric's payroll — exposure threshold is 60 (not the usual 80). Keep it low."
	_heat_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_text_outline(_heat_lbl)
	heat_vbox.add_child(_heat_lbl)

	var heat_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Heat gauge. At 60, the Guard Captain exposes you. Route rumors through non-merchant channels to stay hidden.")
	_heat_bar_bg = heat_pair[0]
	_heat_bar    = heat_pair[1]
	heat_vbox.add_child(_heat_bar_bg)

	# Right column: days + result.
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 12)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 22"
	_days_lbl.tooltip_text = "Days before the guild closes its books. Aldric must be exposed and Marta safe by deadline."
	_days_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 16)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	right_vbox.add_child(_result_lbl)

	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 11)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "Aldric: \u226430 | Marta: 60+ | Heat: <60"
	right_vbox.add_child(legend_lbl)


# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _has_world_deps():
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var sm:  ScenarioManager  = _world_ref.scenario_manager
	var progress: Dictionary  = sm.get_scenario_6_progress(rep)

	var aldric_score: int   = progress["aldric_score"]
	var marta_score:  int   = progress["marta_score"]
	var max_heat:     float = progress["max_heat"]
	var heat_ceil:    float = progress["heat_ceiling"]
	var state               = progress["state"]

	_aldric_score_lbl.text = "Aldric Vane   Rep: %d / 100   Target: \u2264%d" % [aldric_score, progress["win_aldric_max"]]
	_marta_score_lbl.text  = "Marta Coin    Rep: %d / 100   Target: %d+" % [marta_score, progress["win_marta_min"]]
	_heat_lbl.text         = "Heat: %d / %d" % [int(max_heat), int(heat_ceil)]

	# Aldric bar: lower is better, target <= 30.
	_aldric_bar.custom_minimum_size.x = BAR_WIDTH * clamp(float(aldric_score) / 100.0, 0.0, 1.0)
	if aldric_score <= progress["win_aldric_max"]:
		_aldric_bar.color = C_WIN
	elif aldric_score <= 50:
		_aldric_bar.color = C_NEUTRAL
	else:
		_aldric_bar.color = C_FAIL

	# Marta bar: higher is better, target >= 60.
	_marta_bar.custom_minimum_size.x = BAR_WIDTH * clamp(float(marta_score) / 100.0, 0.0, 1.0)
	if marta_score >= progress["win_marta_min"]:
		_marta_bar.color = C_WIN
	elif marta_score >= progress["fail_marta_below"]:
		_marta_bar.color = C_NEUTRAL
	else:
		_marta_bar.color = C_FAIL

	# Heat bar: lower is better, ceiling at 60.
	var heat_ratio: float = clamp(max_heat / heat_ceil, 0.0, 1.0) if heat_ceil > 0 else 0.0
	_heat_bar.custom_minimum_size.x = BAR_WIDTH * heat_ratio
	if max_heat < heat_ceil * 0.5:
		_heat_bar.color = C_WIN
	elif max_heat < heat_ceil * 0.8:
		_heat_bar.color = C_NEUTRAL
	else:
		_heat_bar.color = C_FAIL

	_update_days_remaining(sm)
	_update_result_label(state,
		"VICTORY — Aldric Vane is exposed",
		"FAILED — The guild closes ranks")
