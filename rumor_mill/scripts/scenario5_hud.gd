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

const BAR_WIDTH  := 160

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

# ── Momentum tracking ────────────────────────────────────────────────────────
var _prev_aldric_score: int = -1
var _prev_edric_score:  int = -1
var _prev_tomas_score:  int = -1

# ── Rival threat + event tracking ────────────────────────────────────────────
var _rival_gap_lbl:    Label     = null
var _rival_gap_bar:    ColorRect = null
var _rival_gap_bg:     Panel     = null
var _event_lbl:         Label    = null

# ── S5 Endorsement Campaign verb ─────────────────────────────────────────────
## Spend 1 recon to stage a public appearance for Aldric (+4 rep boost, 3-day cooldown).
## Campaign action costs/effects sourced from ScenarioConfig.
const CAMPAIGN_REP_BOOST  := ScenarioConfig.S5_CAMPAIGN_REP_BOOST
const CAMPAIGN_COOLDOWN   := ScenarioConfig.S5_CAMPAIGN_COOLDOWN
var _campaign_btn:       Button = null
var _campaign_lbl:       Label  = null
var _campaign_last_day:  int    = -999  # day the last appearance was staged


func _scenario_number() -> int:
	return 5


func _on_setup_extra(world: Node2D) -> void:
	if world != null and "scenario_manager" in world and world.scenario_manager != null:
		world.scenario_manager.endorsement_triggered.connect(_on_endorsement)


## Returns a momentum arrow string based on current vs previous score.
## Returns "" on the first call (no prior data), "↑" if rising, "↓" if falling, "→" if flat.
func _momentum_arrow(current: int, prev: int) -> String:
	if prev < 0:
		return ""
	if current > prev:
		return " ↑"
	elif current < prev:
		return " ↓"
	return " →"


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var hbox := _make_panel("Scenario5Panel", 72)

	# Title.
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 5:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	title_lbl.tooltip_text = "The Election — get Aldric Vane elected alderman. He must reach %d+ and be highest; both rivals below %d." % [ScenarioConfig.S5_WIN_ALDRIC_MIN, ScenarioConfig.S5_WIN_RIVALS_MAX]
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(title_lbl)

	# Aldric track (patron's candidate — boost).
	var aldric_vbox := VBoxContainer.new()
	aldric_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(aldric_vbox)

	_aldric_score_lbl = Label.new()
	_aldric_score_lbl.add_theme_font_size_override("font_size", 14)
	_aldric_score_lbl.add_theme_color_override("font_color", C_BODY)
	_aldric_score_lbl.text = "Aldric Vane  Rep: 48 / 100  Target: 65+"
	_aldric_score_lbl.tooltip_text = "Aldric Vane's reputation. Win condition: raise to 65+ AND be the highest of all three candidates."
	_aldric_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_aldric_score_lbl.clip_text = true
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
	_edric_score_lbl.add_theme_font_size_override("font_size", 14)
	_edric_score_lbl.add_theme_color_override("font_color", C_BODY)
	_edric_score_lbl.text = "Edric Fenn  Rep: 58 / 100  Target: <45"
	_edric_score_lbl.tooltip_text = "Edric Fenn's reputation. Win condition: drag below 45."
	_edric_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_edric_score_lbl.clip_text = true
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
	_tomas_score_lbl.add_theme_font_size_override("font_size", 14)
	_tomas_score_lbl.add_theme_color_override("font_color", C_BODY)
	_tomas_score_lbl.text = "Tomas Reeve  Rep: 45 / 100  Target: <45"
	_tomas_score_lbl.tooltip_text = "Tomas Reeve's reputation. Win condition: drag below 45."
	_tomas_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_tomas_score_lbl.clip_text = true
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
	_days_lbl.add_theme_font_size_override("font_size", 14)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 25"
	_days_lbl.tooltip_text = "Days before the election. Aldric must meet all win conditions by the deadline."
	_days_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_days_lbl.clip_text = true
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 16)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	_result_lbl.clip_text = true
	right_vbox.add_child(_result_lbl)

	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 11)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "Aldric: %d+ & highest | Rivals: <%d" % [ScenarioConfig.S5_WIN_ALDRIC_MIN, ScenarioConfig.S5_WIN_RIVALS_MAX]
	right_vbox.add_child(legend_lbl)

	_endorse_lbl = Label.new()
	_endorse_lbl.add_theme_font_size_override("font_size", 12)
	_endorse_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45, 0.80))
	var _e_day: int = ScenarioConfig.S5_ENDORSEMENT_DAY
	_endorse_lbl.text = "Endorsement: day %d (pending)" % _e_day
	_endorse_lbl.tooltip_text = "On day %d, Prior Aldous endorses the candidate with the highest reputation — granting a +%d bonus. Make sure Aldric leads by then." % [_e_day, ScenarioConfig.S5_ENDORSEMENT_BONUS]
	_endorse_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_endorse_lbl.clip_text = true
	right_vbox.add_child(_endorse_lbl)

	# ── Rival threat bar ─────────────────────────────────────────────────────
	# Shows the gap between the leading rival and Aldric. Filled = danger.
	_rival_gap_lbl = Label.new()
	_rival_gap_lbl.add_theme_font_size_override("font_size", 11)
	_rival_gap_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.50, 0.85))
	_rival_gap_lbl.text = "Rival threat: —"
	_rival_gap_lbl.tooltip_text = "How far the leading rival is ahead of Aldric. Bar is green when Aldric leads; red when rivals threaten."
	_rival_gap_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_rival_gap_lbl.clip_text = true
	right_vbox.add_child(_rival_gap_lbl)

	var gap_pair := _make_progress_bar(100, 7,
		"Rival threat. Fills red when the leading rival is ahead of Aldric.")
	_rival_gap_bg  = gap_pair[0]
	_rival_gap_bar = gap_pair[1]
	_rival_gap_bar.color = C_FAIL
	right_vbox.add_child(_rival_gap_bg)

	# ── Upcoming mid-game event ───────────────────────────────────────────────
	_event_lbl = Label.new()
	_event_lbl.add_theme_font_size_override("font_size", 11)
	_event_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.40, 0.85))
	_event_lbl.text = ""
	_event_lbl.tooltip_text = "Next mid-game narrative event window."
	_event_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_event_lbl.clip_text = true
	right_vbox.add_child(_event_lbl)

	# ── Endorsement Campaign verb ────────────────────────────────────────────
	_campaign_btn = Button.new()
	_campaign_btn.text = "Stage Appearance"
	_campaign_btn.tooltip_text = "Spend 1 recon action to stage a public appearance for Aldric (+%d reputation). %d-day cooldown between appearances." % [CAMPAIGN_REP_BOOST, CAMPAIGN_COOLDOWN]
	_campaign_btn.add_theme_font_size_override("font_size", 12)
	_campaign_btn.disabled = true
	_campaign_btn.pressed.connect(_on_campaign_pressed)
	right_vbox.add_child(_campaign_btn)

	_campaign_lbl = Label.new()
	_campaign_lbl.add_theme_font_size_override("font_size", 11)
	_campaign_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.45, 0.90))
	_campaign_lbl.text = ""
	_campaign_lbl.visible = false
	_campaign_lbl.clip_text = true
	right_vbox.add_child(_campaign_lbl)


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

	# ── Leaderboard ranks ────────────────────────────────────────────────────
	# Sort candidates descending by score to assign 1st/2nd/3rd positions.
	var ranked: Array = [
		["aldric_vane", aldric_score],
		["edric_fenn",  edric_score],
		["tomas_reeve", tomas_score],
	]
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var aldric_rank: int = 0
	var edric_rank:  int = 0
	var tomas_rank:  int = 0
	for i: int in ranked.size():
		match ranked[i][0]:
			"aldric_vane": aldric_rank = i + 1
			"edric_fenn":  edric_rank  = i + 1
			"tomas_reeve": tomas_rank  = i + 1
	const RANK_LABEL: Array = ["", "1st", "2nd", "3rd"]

	# ── Score labels with rank prefix and momentum arrow suffix ──────────────
	_aldric_score_lbl.text = "%s  Aldric Vane   Rep: %d / 100   Target: %d+%s" % [
		RANK_LABEL[aldric_rank], aldric_score, progress["win_aldric_min"],
		_momentum_arrow(aldric_score, _prev_aldric_score)]
	_edric_score_lbl.text  = "%s  Edric Fenn    Rep: %d / 100   Target: <%d%s" % [
		RANK_LABEL[edric_rank],  edric_score,  progress["win_rivals_max"],
		_momentum_arrow(edric_score, _prev_edric_score)]
	_tomas_score_lbl.text  = "%s  Tomas Reeve   Rep: %d / 100   Target: <%d%s" % [
		RANK_LABEL[tomas_rank],  tomas_score,  progress["win_rivals_max"],
		_momentum_arrow(tomas_score, _prev_tomas_score)]

	# ── Save scores for next tick's momentum calculation ─────────────────────
	_prev_aldric_score = aldric_score
	_prev_edric_score  = edric_score
	_prev_tomas_score  = tomas_score

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

	# ── Endorsement: countdown or result ─────────────────────────────────────
	if progress["endorsement_fired"]:
		var endorsed: String = NPC_DISPLAY_NAMES.get(progress["endorsed_candidate"], progress["endorsed_candidate"])
		_endorse_lbl.text = "Endorsed: %s (+%d)" % [endorsed, sm.S5_ENDORSEMENT_BONUS]
		if progress["endorsed_candidate"] == ScenarioConfig.ALDRIC_VANE_ID:
			_endorse_lbl.add_theme_color_override("font_color", C_WIN)
		else:
			_endorse_lbl.add_theme_color_override("font_color", C_FAIL)
	else:
		var current_day: int = sm.get_current_day(_day_night_ref.current_tick) \
			if _day_night_ref != null else 1
		var days_until: int = sm.S5_ENDORSEMENT_DAY - current_day
		if days_until > 0:
			_endorse_lbl.text = "Endorsement: day %d (in %d day%s)" % [
				sm.S5_ENDORSEMENT_DAY, days_until, "s" if days_until != 1 else ""]
		elif days_until == 0:
			_endorse_lbl.text = "Endorsement: today!"
		else:
			_endorse_lbl.text = "Endorsement: day %d (pending)" % sm.S5_ENDORSEMENT_DAY

	_update_days_remaining(sm)
	_update_result_label(state,
		"VICTORY — Aldric Vane wins the election",
		"FAILED — The election is lost")
	_update_campaign_button()
	_update_rival_gap(aldric_score, edric_score, tomas_score)
	_update_event_countdown(sm)


# ── Endorsement Campaign verb ─────────────────────────────────────────────────

## Sync the Stage Appearance button enabled state each refresh.
func _update_campaign_button() -> void:
	if _campaign_btn == null or _world_ref == null:
		return
	var intel: PlayerIntelStore = _world_ref.get("intel_store")
	var sm: ScenarioManager = _world_ref.get("scenario_manager")
	var has_free: bool = intel != null and intel.free_campaign_charges > 0
	var has_recon: bool = intel != null and intel.recon_actions_remaining > 0
	var current_day: int = sm.get_current_day(_day_night_ref.current_tick) if sm != null and _day_night_ref != null else 0
	var cooldown_clear: bool = current_day - _campaign_last_day >= CAMPAIGN_COOLDOWN
	_campaign_btn.disabled = not (has_free or (has_recon and cooldown_clear))
	if has_free:
		_campaign_btn.tooltip_text = "Free appearance available (no recon cost, cooldown bypassed). +%d reputation for Aldric." % CAMPAIGN_REP_BOOST
	elif has_recon and not cooldown_clear:
		var days_left: int = CAMPAIGN_COOLDOWN - (current_day - _campaign_last_day)
		_campaign_btn.tooltip_text = "Cooldown: %d day%s remaining before next appearance." % [days_left, "s" if days_left != 1 else ""]
	else:
		_campaign_btn.tooltip_text = "Spend 1 recon action to stage a public appearance for Aldric (+%d reputation). %d-day cooldown." % [CAMPAIGN_REP_BOOST, CAMPAIGN_COOLDOWN]


## Player clicked "Stage Appearance" — spend 1 recon (or a free charge) and boost Aldric's reputation.
func _on_campaign_pressed() -> void:
	if _world_ref == null:
		return
	var intel: PlayerIntelStore = _world_ref.get("intel_store")
	var rep: ReputationSystem = _world_ref.get("reputation_system")
	var sm: ScenarioManager = _world_ref.get("scenario_manager")
	if intel == null or rep == null or sm == null:
		return
	# Consume a free charge (bypasses cooldown and recon cost) if available,
	# otherwise use the normal recon action path.
	var used_free: bool = false
	if intel.free_campaign_charges > 0:
		intel.free_campaign_charges -= 1
		used_free = true
	else:
		if not intel.try_spend_action():
			return
	var current_day: int = sm.get_current_day(_day_night_ref.current_tick) if _day_night_ref != null else 0
	if not used_free:
		_campaign_last_day = current_day
	rep.apply_score_delta(ScenarioConfig.ALDRIC_VANE_ID, CAMPAIGN_REP_BOOST)
	AudioManager.play_sfx_pitched("reputation_up", 1.0)
	if _campaign_lbl != null:
		_campaign_lbl.text = "Day %d: Aldric rallied the crowd (+%d rep)" % [current_day, CAMPAIGN_REP_BOOST]
		_campaign_lbl.visible = true
		_campaign_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.45, 0.90))
		var tween := create_tween()
		tween.tween_property(_campaign_lbl, "modulate:a", 0.20, 0.10)
		tween.tween_property(_campaign_lbl, "modulate:a", 1.0, 0.25)
	_update_campaign_button()


# ── Rival gap threat bar ─────────────────────────────────────────────────────

## Update the rival threat bar showing the leading rival's gap versus Aldric.
## Bar fills red when a rival leads; green when Aldric is ahead.
func _update_rival_gap(aldric: int, edric: int, tomas: int) -> void:
	if _rival_gap_lbl == null or _rival_gap_bar == null:
		return
	var top_rival: int = maxi(edric, tomas)
	var gap: int = top_rival - aldric  # positive = rival leads, negative = Aldric leads
	if gap > 0:
		_rival_gap_lbl.text = "Rival threat: +%d ahead" % gap
		_rival_gap_lbl.add_theme_color_override("font_color", C_FAIL)
		_rival_gap_bar.color = C_FAIL
		_rival_gap_bar.custom_minimum_size.x = 100 * clamp(float(gap) / 30.0, 0.0, 1.0)
	elif gap == 0:
		_rival_gap_lbl.text = "Rival threat: tied"
		_rival_gap_lbl.add_theme_color_override("font_color", C_NEUTRAL)
		_rival_gap_bar.color = C_NEUTRAL
		_rival_gap_bar.custom_minimum_size.x = 4
	else:
		_rival_gap_lbl.text = "Aldric leads by %d" % (-gap)
		_rival_gap_lbl.add_theme_color_override("font_color", C_WIN)
		_rival_gap_bar.color = C_WIN
		_rival_gap_bar.custom_minimum_size.x = 100 * clamp(float(-gap) / 30.0, 0.0, 1.0)


# ── Event countdown ───────────────────────────────────────────────────────────

## Show the name and day window of the next unfired mid-game event, if any.
func _update_event_countdown(sm: ScenarioManager) -> void:
	if _event_lbl == null or _world_ref == null:
		return
	var mga: MidGameEventAgent = _world_ref.get("mid_game_event_agent")
	if mga == null:
		return
	if mga.has_pending_event():
		var ev: Dictionary = mga.get_pending_event()
		_event_lbl.text = "Event: %s — choose now!" % ev.get("name", "?")
		_event_lbl.add_theme_color_override("font_color", C_NEUTRAL)
		return
	var current_day: int = sm.get_current_day(_day_night_ref.current_tick) \
		if _day_night_ref != null else 1
	var upcoming: Dictionary = mga.get_upcoming_event(current_day)
	if upcoming.is_empty():
		_event_lbl.text = ""
	else:
		var win_start: int = int(upcoming.get("dayWindowStart", 0))
		var win_end:   int = int(upcoming.get("dayWindowEnd", 0))
		var ev_name:   String = upcoming.get("name", "?")
		if current_day >= win_start:
			_event_lbl.text = "Event: %s (active, Day %d-%d)" % [ev_name, win_start, win_end]
			_event_lbl.add_theme_color_override("font_color", C_NEUTRAL)
		else:
			_event_lbl.text = "Next event: %s (Day %d)" % [ev_name, win_start]
			_event_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.45, 0.75))


# ── Endorsement event ────────────────────────────────────────────────────────

func _on_endorsement(candidate_id: String, bonus: int) -> void:
	if _endorse_lbl == null:
		return
	if candidate_id == ScenarioConfig.ALDRIC_VANE_ID:
		AudioManager.play_sfx_pitched("reputation_up", 1.1)
	else:
		AudioManager.play_sfx_pitched("reputation_down", 0.9)
	var name_str: String = NPC_DISPLAY_NAMES.get(candidate_id, _display_name(candidate_id))
	_endorse_lbl.text = "Endorsed: %s (+%d)" % [name_str, bonus]
	if candidate_id == ScenarioConfig.ALDRIC_VANE_ID:
		_endorse_lbl.add_theme_color_override("font_color", C_WIN)
	else:
		_endorse_lbl.add_theme_color_override("font_color", C_FAIL)
	var tween := create_tween()
	tween.tween_property(_endorse_lbl, "modulate:a", 0.25, 0.12)
	tween.tween_property(_endorse_lbl, "modulate:a", 1.0, 0.30)
