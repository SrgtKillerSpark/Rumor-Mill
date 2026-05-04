extends BaseScenarioHud

## scenario5_hud.gd — Persistent three-candidate election progress display.
##
## Shows a thin header tracking the three election candidates' reputation
## scores against the Scenario 5 win targets: Aldric >= 65 & highest,
## both rivals < 45.
##
## Layout:
##   Scenario 5: The Election
##   [Aldric Vane]   Rep: 48 / 100   Target: 65+  [bar]
##   [Edric Fenn]    Rep: 58 / 100   Target: <45  [bar]
##   [Tomas Reeve]   Rep: 45 / 100   Target: <45  [bar]
##   Days remaining: 25       Endorsement: pending
##
## Wire via setup(world, day_night) from main.gd.

const BAR_WIDTH  := 120

const NPC_DISPLAY_NAMES := {
	"aldric_vane": "Aldric Vane",
	"edric_fenn":  "Edric Fenn",
	"tomas_reeve": "Tomas Reeve",
}

# ── Node refs ────────────────────────────────────────────────────────────────
var _aldric_score_lbl: Label     = null
var _edric_score_lbl:  Label     = null
var _tomas_score_lbl:  Label     = null
var _aldric_bar:       ColorRect = null
var _aldric_bar_bg:    ColorRect = null
var _edric_bar:        ColorRect = null
var _edric_bar_bg:     ColorRect = null
var _tomas_bar:        ColorRect = null
var _tomas_bar_bg:     ColorRect = null
var _endorse_lbl:      Label     = null


func _scenario_number() -> int:
	return 5


func _on_setup_extra(world: Node2D) -> void:
	if world != null and "scenario_manager" in world and world.scenario_manager != null:
		world.scenario_manager.endorsement_triggered.connect(_on_endorsement)


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var hbox := _make_panel("Scenario5Panel", 78, 14)

	# Title.
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 5:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	title_lbl.tooltip_text = "The Election — get Aldric Vane elected alderman. He must reach 65+ and be highest; both rivals below 45."
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(title_lbl)

	# Aldric track (patron's candidate — boost).
	var aldric_vbox := VBoxContainer.new()
	aldric_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(aldric_vbox)

	_aldric_score_lbl = Label.new()
	_aldric_score_lbl.add_theme_font_size_override("font_size", 11)
	_aldric_score_lbl.add_theme_color_override("font_color", C_BODY)
	_aldric_score_lbl.text = "Aldric Vane  Rep: 48 / 100  Target: 65+"
	_aldric_score_lbl.tooltip_text = "Aldric Vane's reputation. Win condition: raise to 65+ AND be the highest of all three candidates."
	_aldric_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_text_outline(_aldric_score_lbl)
	aldric_vbox.add_child(_aldric_score_lbl)

	var aldric_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Aldric's reputation. Grows with Praise rumors. Must reach 65+ to win.")
	_aldric_bar_bg = aldric_pair[0]
	_aldric_bar    = aldric_pair[1]
	aldric_vbox.add_child(_aldric_bar_bg)

	# Edric track (rival — undermine).
	var edric_vbox := VBoxContainer.new()
	edric_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(edric_vbox)

	_edric_score_lbl = Label.new()
	_edric_score_lbl.add_theme_font_size_override("font_size", 11)
	_edric_score_lbl.add_theme_color_override("font_color", C_BODY)
	_edric_score_lbl.text = "Edric Fenn  Rep: 58 / 100  Target: <45"
	_edric_score_lbl.tooltip_text = "Edric Fenn's reputation. Win condition: drag below 45."
	_edric_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_text_outline(_edric_score_lbl)
	edric_vbox.add_child(_edric_score_lbl)

	var edric_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Edric's reputation. Shrinks with Scandal/Accusation. Must be below 45 to win.")
	_edric_bar_bg = edric_pair[0]
	_edric_bar    = edric_pair[1]
	edric_vbox.add_child(_edric_bar_bg)

	# Tomas track (rival — undermine).
	var tomas_vbox := VBoxContainer.new()
	tomas_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(tomas_vbox)

	_tomas_score_lbl = Label.new()
	_tomas_score_lbl.add_theme_font_size_override("font_size", 11)
	_tomas_score_lbl.add_theme_color_override("font_color", C_BODY)
	_tomas_score_lbl.text = "Tomas Reeve  Rep: 45 / 100  Target: <45"
	_tomas_score_lbl.tooltip_text = "Tomas Reeve's reputation. Win condition: drag below 45."
	_tomas_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_text_outline(_tomas_score_lbl)
	tomas_vbox.add_child(_tomas_score_lbl)

	var tomas_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Tomas's reputation. Shrinks with Scandal/Accusation. Must be below 45 to win.")
	_tomas_bar_bg = tomas_pair[0]
	_tomas_bar    = tomas_pair[1]
	tomas_vbox.add_child(_tomas_bar_bg)

	# Right column: days + result + endorsement.
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 12)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 25"
	_days_lbl.tooltip_text = "Days before the election. Aldric must meet all win conditions by the deadline."
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
	legend_lbl.text = "Aldric: 65+ & highest | Rivals: <45"
	right_vbox.add_child(legend_lbl)

	_endorse_lbl = Label.new()
	_endorse_lbl.add_theme_font_size_override("font_size", 12)
	_endorse_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45, 0.80))
	var _e_day: int = 13
	_endorse_lbl.text = "Endorsement: day %d (pending)" % _e_day
	_endorse_lbl.tooltip_text = "On day %d, Prior Aldous endorses the candidate with the highest reputation — granting a +%d bonus. Make sure Aldric leads by then." % [_e_day, 8]
	_endorse_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	right_vbox.add_child(_endorse_lbl)


# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _has_world_deps():
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var sm:  ScenarioManager  = _world_ref.scenario_manager
	var progress: Dictionary  = sm.get_scenario_5_progress(rep)

	var aldric_score: int = progress["aldric_score"]
	var edric_score:  int = progress["edric_score"]
	var tomas_score:  int = progress["tomas_score"]
	var state             = progress["state"]

	_aldric_score_lbl.text = "Aldric Vane   Rep: %d / 100   Target: %d+" % [aldric_score, progress["win_aldric_min"]]
	_edric_score_lbl.text  = "Edric Fenn    Rep: %d / 100   Target: <%d" % [edric_score, progress["win_rivals_max"]]
	_tomas_score_lbl.text  = "Tomas Reeve   Rep: %d / 100   Target: <%d" % [tomas_score, progress["win_rivals_max"]]

	# Aldric bar: higher is better, target 65.
	_aldric_bar.custom_minimum_size.x = BAR_WIDTH * clamp(float(aldric_score) / 100.0, 0.0, 1.0)
	if aldric_score >= progress["win_aldric_min"]:
		_aldric_bar.color = C_WIN
	elif aldric_score >= progress["fail_aldric_below"]:
		_aldric_bar.color = C_NEUTRAL
	else:
		_aldric_bar.color = C_FAIL

	# Edric bar: lower is better, target < 45.
	_edric_bar.custom_minimum_size.x = BAR_WIDTH * clamp(float(edric_score) / 100.0, 0.0, 1.0)
	if edric_score < progress["win_rivals_max"]:
		_edric_bar.color = C_WIN
	else:
		_edric_bar.color = C_FAIL

	# Tomas bar: lower is better, target < 45.
	_tomas_bar.custom_minimum_size.x = BAR_WIDTH * clamp(float(tomas_score) / 100.0, 0.0, 1.0)
	if tomas_score < progress["win_rivals_max"]:
		_tomas_bar.color = C_WIN
	else:
		_tomas_bar.color = C_FAIL

	# Endorsement status.
	if progress["endorsement_fired"]:
		var endorsed: String = NPC_DISPLAY_NAMES.get(progress["endorsed_candidate"], progress["endorsed_candidate"])
		_endorse_lbl.text = "Endorsed: %s (+%d)" % [endorsed, sm.S5_ENDORSEMENT_BONUS]
		if progress["endorsed_candidate"] == ScenarioManager.ALDRIC_VANE_ID:
			_endorse_lbl.add_theme_color_override("font_color", C_WIN)
		else:
			_endorse_lbl.add_theme_color_override("font_color", C_FAIL)

	_update_days_remaining(sm)
	_update_result_label(state,
		"VICTORY — Aldric Vane wins the election",
		"FAILED — The election is lost")


# ── Endorsement event ────────────────────────────────────────────────────────

func _on_endorsement(candidate_id: String, bonus: int) -> void:
	if _endorse_lbl == null:
		return
	var name_str: String = NPC_DISPLAY_NAMES.get(candidate_id, _display_name(candidate_id))
	_endorse_lbl.text = "Endorsed: %s (+%d)" % [name_str, bonus]
	if candidate_id == ScenarioManager.ALDRIC_VANE_ID:
		_endorse_lbl.add_theme_color_override("font_color", C_WIN)
	else:
		_endorse_lbl.add_theme_color_override("font_color", C_FAIL)
	var tween := create_tween()
	tween.tween_property(_endorse_lbl, "modulate:a", 0.25, 0.12)
	tween.tween_property(_endorse_lbl, "modulate:a", 1.0, 0.30)
