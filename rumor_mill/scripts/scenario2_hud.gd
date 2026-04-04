extends BaseScenarioHud

## scenario2_hud.gd — Persistent illness-spread tracking display.
##
## Shows a thin header at the top of the screen tracking how many NPCs
## believe the illness rumor about Alys Herbwife, who believes/rejects,
## and days remaining.
##
## Layout:
##   Scenario 2: The Plague Scare
##   Believers: 3 / 7+   [progress bar]   Days remaining: 18
##   ✓ Tomas, Calder, Finn   ✗ Sister Maren
##
## Wire via setup(world, day_night) from main.gd.

# ── S2-specific palette ──────────────────────────────────────────────────────
const C_ILLNESS := Color(0.60, 0.85, 0.30, 1.0)  # sickly green for plague theme

const BAR_WIDTH      := 140
const BAR_HEIGHT     := 10
const MAX_NAMES_SHOWN := 5

# ── Node refs ────────────────────────────────────────────────────────────────
var _count_lbl:     Label     = null
var _bar:           ColorRect = null
var _bar_bg:        ColorRect = null
var _believers_lbl: Label     = null
var _rejecters_lbl: Label     = null


func _scenario_number() -> int:
	return 2


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var hbox := _make_panel("Scenario2Panel", 62)

	# Scenario label.
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 2:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	hbox.add_child(title_lbl)

	# Believer count + progress bar.
	var count_vbox := VBoxContainer.new()
	count_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(count_vbox)

	_count_lbl = Label.new()
	_count_lbl.add_theme_font_size_override("font_size", 12)
	_count_lbl.add_theme_color_override("font_color", C_BODY)
	_count_lbl.text = "Believers: 0 / 7+"
	_count_lbl.tooltip_text = "Number of townspeople who believe the illness rumor about Alys Herbwife. Win when 7 or more believe it."
	_count_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	count_vbox.add_child(_count_lbl)

	var bar_hbox := HBoxContainer.new()
	count_vbox.add_child(bar_hbox)

	var bar_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Progress toward 7 believers. Green = win threshold reached; amber = halfway; sickly green = early stage.")
	_bar_bg = bar_pair[0]
	_bar    = bar_pair[1]
	bar_hbox.add_child(_bar_bg)

	# NPC name columns.
	var names_vbox := VBoxContainer.new()
	names_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(names_vbox)

	_believers_lbl = Label.new()
	_believers_lbl.add_theme_font_size_override("font_size", 11)
	_believers_lbl.add_theme_color_override("font_color", C_ILLNESS)
	_believers_lbl.text = "Believe: —"
	names_vbox.add_child(_believers_lbl)

	_rejecters_lbl = Label.new()
	_rejecters_lbl.add_theme_font_size_override("font_size", 11)
	_rejecters_lbl.add_theme_color_override("font_color", C_FAIL)
	_rejecters_lbl.text = ""
	_rejecters_lbl.visible = false
	names_vbox.add_child(_rejecters_lbl)

	# Days remaining + result.
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 12)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 30"
	_days_lbl.tooltip_text = "Days remaining before the autumn market closes. Fail if you run out of time."
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
	legend_lbl.text = "Target: 7+ believers"
	right_vbox.add_child(legend_lbl)


# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _has_world_deps():
		return

	var rep: ReputationSystem  = _world_ref.reputation_system
	var sm:  ScenarioManager   = _world_ref.scenario_manager
	var progress: Dictionary   = sm.get_scenario_2_progress(rep)

	var count: int       = progress["illness_believer_count"]
	var threshold: int   = progress["win_threshold"]
	var believers: Array = progress["illness_believer_ids"]
	var rejecters: Array = progress["illness_rejecter_ids"]
	var state            = progress["state"]

	_count_lbl.text = "Believers: %d / %d+" % [count, threshold]

	var ratio: float = clamp(float(count) / float(threshold), 0.0, 1.0)
	_bar.custom_minimum_size.x = BAR_WIDTH * ratio
	if count >= threshold:
		_bar.color = C_WIN
	elif count >= threshold / 2:
		_bar.color = C_NEUTRAL
	else:
		_bar.color = C_ILLNESS

	if believers.size() > 0:
		var names: Array = []
		for npc_id in believers.slice(0, MAX_NAMES_SHOWN):
			names.append(_display_name(npc_id))
		var suffix := ""
		if believers.size() > MAX_NAMES_SHOWN:
			suffix = " +%d more" % (believers.size() - MAX_NAMES_SHOWN)
		_believers_lbl.text = "Believe: " + ", ".join(names) + suffix
	else:
		_believers_lbl.text = "Believe: —"

	if rejecters.size() > 0:
		var names: Array = []
		for npc_id in rejecters:
			names.append(_display_name(npc_id))
		_rejecters_lbl.text = "Reject: " + ", ".join(names)
		_rejecters_lbl.visible = true
	else:
		_rejecters_lbl.visible = false

	_update_days_remaining(sm)
	_update_result_label(state,
		"VICTORY — The plague scare spreads",
		"FAILED — The truth prevails")
