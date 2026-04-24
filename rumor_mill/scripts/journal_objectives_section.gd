class_name JournalObjectivesSection
extends RefCounted

## journal_objectives_section.gd — Objectives tab content builder for Journal.
##
## Extracted from journal.gd (SPA-1003). Renders win/fail conditions for all
## six scenarios, reading live reputation and scenario-state from the world.
##
## Call setup() once refs are known. Call build(content_vbox) to populate the
## content area for the current tab.

# ── Palette ───────────────────────────────────────────────────────────────────

const C_HEADING      := Color(0.92, 0.78, 0.12, 1.0)
const C_BODY         := Color(0.80, 0.72, 0.56, 1.0)
const C_SPREADING    := Color(0.10, 0.68, 0.22, 1.0)
const C_CONTRADICTED := Color(0.80, 0.10, 0.10, 1.0)

# ── Fallback day limits (used for inactive scenarios) ─────────────────────────

const S1_DAYS := 30
const S2_DAYS := 20
const S3_DAYS := 25
const S4_DAYS := 20
const S5_DAYS := 25
const S6_DAYS := 22

# ── Refs ──────────────────────────────────────────────────────────────────────

var _world_ref:     Node2D = null
var _day_night_ref: Node   = null


func setup(world: Node2D, day_night: Node) -> void:
	_world_ref     = world
	_day_night_ref = day_night


## Build the Objectives tab content into content_vbox.
func build(content_vbox: VBoxContainer) -> void:
	_add_section_header(content_vbox, "Objectives")

	# Pull reputation snapshots and scenario manager (may be null early in game).
	var rep: ReputationSystem = null
	var sm:  ScenarioManager  = null
	if _world_ref != null and "reputation_system" in _world_ref:
		rep = _world_ref.reputation_system
	if _world_ref != null and "scenario_manager" in _world_ref:
		sm = _world_ref.scenario_manager

	var days_elapsed: int = (_day_night_ref.current_day - 1) if _day_night_ref != null else 0

	# Read day limit from ScenarioManager to avoid hardcoded drift.
	var sm_days: int = sm.get_days_allowed() if sm != null else 30
	@warning_ignore("unused_variable")
	var days_remaining: int = max(0, sm_days - days_elapsed)

	var s1_days_remaining: int = max(0, S1_DAYS - days_elapsed)
	var s2_days_remaining: int = max(0, S2_DAYS - days_elapsed)
	var s3_days_remaining: int = max(0, S3_DAYS - days_elapsed)
	var s4_days_remaining: int = max(0, S4_DAYS - days_elapsed)
	var s5_days_remaining: int = max(0, S5_DAYS - days_elapsed)
	var s6_days_remaining: int = max(0, S6_DAYS - days_elapsed)

	var edric_snap:  ReputationSystem.ReputationSnapshot = rep.get_snapshot("edric_fenn")   if rep != null else null
	var calder_snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot("calder_fenn")  if rep != null else null
	var tomas_snap:  ReputationSystem.ReputationSnapshot = rep.get_snapshot("tomas_reeve")  if rep != null else null
	var aldous_snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot("aldous_prior") if rep != null else null
	var vera_snap:   ReputationSystem.ReputationSnapshot = rep.get_snapshot("vera_midwife") if rep != null else null
	var finn_snap:   ReputationSystem.ReputationSnapshot = rep.get_snapshot("finn_monk")    if rep != null else null
	var aldric_snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot("aldric_vane")  if rep != null else null
	var marta_snap:  ReputationSystem.ReputationSnapshot = rep.get_snapshot("marta_coin")   if rep != null else null

	var active_scenario_id: String = ""
	if _world_ref != null and "active_scenario_id" in _world_ref:
		active_scenario_id = _world_ref.active_scenario_id

	var s1_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null: s1_state = sm.scenario_1_state

	var s4_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null: s4_state = sm.scenario_4_state

	var s5_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null: s5_state = sm.scenario_5_state

	var s6_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null: s6_state = sm.scenario_6_state

	# ── Scenario 1 ────────────────────────────────────────────────────────
	var s1_lbl := Label.new()
	s1_lbl.text = "Scenario 1: The Alderman's Ruin"
	s1_lbl.add_theme_font_size_override("font_size", 14)
	s1_lbl.add_theme_color_override("font_color", C_HEADING)
	content_vbox.add_child(s1_lbl)

	if active_scenario_id == "scenario_1" or active_scenario_id.is_empty():
		var days_lbl := Label.new()
		days_lbl.text = "Days remaining: %d / %d" % [s1_days_remaining, S1_DAYS]
		days_lbl.add_theme_font_size_override("font_size", 12)
		days_lbl.add_theme_color_override("font_color", C_BODY)
		content_vbox.add_child(days_lbl)

	content_vbox.add_child(HSeparator.new())

	var win_hdr := Label.new()
	win_hdr.text = "WIN CONDITION"
	win_hdr.add_theme_font_size_override("font_size", 12)
	win_hdr.add_theme_color_override("font_color", C_SPREADING)
	content_vbox.add_child(win_hdr)

	var edric_score_str := "50"
	var edric_band_str  := "Respected"
	if edric_snap != null:
		edric_score_str = str(edric_snap.score)
		edric_band_str  = ReputationSystem.score_label(edric_snap.score)

	var s1_win_status := "[ACTIVE]"
	var s1_win_color  := C_BODY
	match s1_state:
		ScenarioManager.ScenarioState.WON:
			s1_win_status = "[WON]";    s1_win_color = C_SPREADING
		ScenarioManager.ScenarioState.FAILED:
			s1_win_status = "[FAILED]"; s1_win_color = C_CONTRADICTED

	var win_body := Label.new()
	win_body.text = (
		"  Lord Edric Fenn reputation drops below %d.\n"
		+ "  Current:  %s / 100  — %s  %s\n"
		+ "  Target:   < %d (Disgraced — faction loyalty collapses)"
	) % [ScenarioManager.S1_WIN_EDRIC_BELOW, edric_score_str, edric_band_str, s1_win_status, ScenarioManager.S1_WIN_EDRIC_BELOW]
	win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	win_body.add_theme_font_size_override("font_size", 12)
	win_body.add_theme_color_override("font_color", s1_win_color)
	content_vbox.add_child(win_body)

	content_vbox.add_child(HSeparator.new())

	var fail_hdr := Label.new()
	fail_hdr.text = "FAIL CONDITIONS"
	fail_hdr.add_theme_font_size_override("font_size", 12)
	fail_hdr.add_theme_color_override("font_color", C_CONTRADICTED)
	content_vbox.add_child(fail_hdr)

	var fail_body := Label.new()
	fail_body.text = (
		"  [ ] Identified as rumor source by Sergeant Bram — suspicion: LOW\n"
		+ "  [ ] %d days elapsed without win condition  (days remaining: %d)"
	) % [S1_DAYS, s1_days_remaining]
	fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	fail_body.add_theme_font_size_override("font_size", 12)
	fail_body.add_theme_color_override("font_color", C_BODY)
	content_vbox.add_child(fail_body)

	content_vbox.add_child(HSeparator.new())

	# ── Scenario 2 ────────────────────────────────────────────────────────
	var s2_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null: s2_state = sm.scenario_2_state

	var s2_lbl := Label.new()
	s2_lbl.text = "Scenario 2: The Plague Scare"
	s2_lbl.add_theme_font_size_override("font_size", 14)
	s2_lbl.add_theme_color_override("font_color", C_HEADING)
	content_vbox.add_child(s2_lbl)

	var s2_win_status := "[ACTIVE]"
	var s2_win_color  := C_BODY
	match s2_state:
		ScenarioManager.ScenarioState.WON:
			s2_win_status = "[WON]";    s2_win_color = C_SPREADING
		ScenarioManager.ScenarioState.FAILED:
			s2_win_status = "[FAILED]"; s2_win_color = C_CONTRADICTED

	var s2_win_hdr := Label.new()
	s2_win_hdr.text = "WIN CONDITION"
	s2_win_hdr.add_theme_font_size_override("font_size", 12)
	s2_win_hdr.add_theme_color_override("font_color", C_SPREADING)
	content_vbox.add_child(s2_win_hdr)

	var illness_count := 0
	if sm != null and rep != null:
		illness_count = sm.get_scenario_2_progress(rep).get("illness_believer_count", 0)

	var s2_win_body := Label.new()
	s2_win_body.text = (
		"  %d / %d townsfolk believe Alys Herbwife is spreading illness.  %s"
	) % [illness_count, sm.s2_win_illness_min if sm != null else ScenarioManager.S2_WIN_ILLNESS_MIN_DEFAULT, s2_win_status]
	s2_win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s2_win_body.add_theme_font_size_override("font_size", 12)
	s2_win_body.add_theme_color_override("font_color", s2_win_color)
	content_vbox.add_child(s2_win_body)

	content_vbox.add_child(HSeparator.new())

	var s2_fail_hdr := Label.new()
	s2_fail_hdr.text = "FAIL CONDITIONS"
	s2_fail_hdr.add_theme_font_size_override("font_size", 12)
	s2_fail_hdr.add_theme_color_override("font_color", C_CONTRADICTED)
	content_vbox.add_child(s2_fail_hdr)

	var maren_rejected := rep != null and rep.has_illness_rejecter(ScenarioManager.ALYS_HERBWIFE_ID, ScenarioManager.MAREN_NUN_ID)
	var s2_timed_out   := s2_days_remaining == 0

	var s2_fail_body := Label.new()
	s2_fail_body.text = (
		"  %s Sister Maren contradicts illness rumors about Alys Herbwife\n"
		+ "  %s %d days elapsed without win condition  (days remaining: %d)"
	) % ["[x]" if maren_rejected else "[ ]",
		"[x]" if s2_timed_out else "[ ]", S2_DAYS, s2_days_remaining]
	s2_fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s2_fail_body.add_theme_font_size_override("font_size", 12)
	s2_fail_body.add_theme_color_override("font_color", C_BODY)
	content_vbox.add_child(s2_fail_body)

	content_vbox.add_child(HSeparator.new())

	# ── Scenario 3 ────────────────────────────────────────────────────────
	var s3_suffix := "  (upcoming)" if active_scenario_id != "scenario_3" else ""
	var s3_lbl := Label.new()
	s3_lbl.text = "Scenario 3: The Succession%s" % s3_suffix
	s3_lbl.add_theme_font_size_override("font_size", 14)
	s3_lbl.add_theme_color_override("font_color", C_HEADING)
	content_vbox.add_child(s3_lbl)

	if active_scenario_id == "scenario_3":
		var s3_days_lbl := Label.new()
		s3_days_lbl.text = "Days remaining: %d / %d" % [s3_days_remaining, S3_DAYS]
		s3_days_lbl.add_theme_font_size_override("font_size", 12)
		s3_days_lbl.add_theme_color_override("font_color", C_BODY)
		content_vbox.add_child(s3_days_lbl)

	var calder_score_str := "50"
	var calder_band_str  := "Respected"
	if calder_snap != null:
		calder_score_str = str(calder_snap.score)
		calder_band_str  = ReputationSystem.score_label(calder_snap.score)

	var tomas_score_str := "50"
	var tomas_band_str  := "Respected"
	if tomas_snap != null:
		tomas_score_str = str(tomas_snap.score)
		tomas_band_str  = ReputationSystem.score_label(tomas_snap.score)

	var s3_body := Label.new()
	s3_body.text = (
		"  WIN:  Calder Fenn \u2265 %d  AND  Tomas Reeve \u2264 %d\n"
		+ "  FAIL: Calder Fenn < 40\n\n"
		+ "  Calder Fenn:   %s / 100  — %s  (target: \u2265%d)\n"
		+ "  Tomas Reeve:   %s / 100  — %s  (target: \u2264%d)"
	) % [ScenarioManager.S3_WIN_CALDER_MIN, ScenarioManager.S3_WIN_TOMAS_MAX,
		calder_score_str, calder_band_str, ScenarioManager.S3_WIN_CALDER_MIN,
		tomas_score_str, tomas_band_str, ScenarioManager.S3_WIN_TOMAS_MAX]
	s3_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s3_body.add_theme_font_size_override("font_size", 12)
	s3_body.add_theme_color_override("font_color", C_BODY)
	content_vbox.add_child(s3_body)

	content_vbox.add_child(HSeparator.new())

	# ── Scenario 4 ────────────────────────────────────────────────────────
	var s4_suffix := "  (upcoming)" if active_scenario_id != "scenario_4" else ""
	var s4_lbl := Label.new()
	s4_lbl.text = "Scenario 4: The Holy Inquisition%s" % s4_suffix
	s4_lbl.add_theme_font_size_override("font_size", 14)
	s4_lbl.add_theme_color_override("font_color", C_HEADING)
	content_vbox.add_child(s4_lbl)

	var s4_win_status := "[ACTIVE]"
	var s4_win_color  := C_BODY
	match s4_state:
		ScenarioManager.ScenarioState.WON:
			s4_win_status = "[WON]";    s4_win_color = C_SPREADING
		ScenarioManager.ScenarioState.FAILED:
			s4_win_status = "[FAILED]"; s4_win_color = C_CONTRADICTED

	if active_scenario_id == "scenario_4":
		var s4_days_lbl := Label.new()
		s4_days_lbl.text = "Days remaining: %d / %d" % [s4_days_remaining, S4_DAYS]
		s4_days_lbl.add_theme_font_size_override("font_size", 12)
		s4_days_lbl.add_theme_color_override("font_color", C_BODY)
		content_vbox.add_child(s4_days_lbl)

	content_vbox.add_child(HSeparator.new())

	var s4_win_hdr := Label.new()
	s4_win_hdr.text = "WIN CONDITION"
	s4_win_hdr.add_theme_font_size_override("font_size", 12)
	s4_win_hdr.add_theme_color_override("font_color", C_SPREADING)
	content_vbox.add_child(s4_win_hdr)

	var aldous_score_str := "50"
	var aldous_band_str  := "Respected"
	if aldous_snap != null:
		aldous_score_str = str(aldous_snap.score)
		aldous_band_str  = ReputationSystem.score_label(aldous_snap.score)

	var vera_score_str := "50"
	var vera_band_str  := "Respected"
	if vera_snap != null:
		vera_score_str = str(vera_snap.score)
		vera_band_str  = ReputationSystem.score_label(vera_snap.score)

	var finn_score_str := "50"
	var finn_band_str  := "Respected"
	if finn_snap != null:
		finn_score_str = str(finn_snap.score)
		finn_band_str  = ReputationSystem.score_label(finn_snap.score)

	var s4_win_body := Label.new()
	s4_win_body.text = (
		"  All three accused survive %d days with reputation \u2265 %d.  %s\n\n"
		+ "  Aldous Prior:  %s / 100  \u2014 %s\n"
		+ "  Vera Midwife:  %s / 100  \u2014 %s\n"
		+ "  Finn Monk:     %s / 100  \u2014 %s\n"
		+ "  Floor: \u2265 %d  (all three must stay above this)"
	) % [S4_DAYS, ScenarioManager.S4_WIN_REP_MIN, s4_win_status,
		aldous_score_str, aldous_band_str,
		vera_score_str, vera_band_str,
		finn_score_str, finn_band_str,
		ScenarioManager.S4_WIN_REP_MIN]
	s4_win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s4_win_body.add_theme_font_size_override("font_size", 12)
	s4_win_body.add_theme_color_override("font_color", s4_win_color)
	content_vbox.add_child(s4_win_body)

	content_vbox.add_child(HSeparator.new())

	var s4_fail_hdr := Label.new()
	s4_fail_hdr.text = "FAIL CONDITIONS"
	s4_fail_hdr.add_theme_font_size_override("font_size", 12)
	s4_fail_hdr.add_theme_color_override("font_color", C_CONTRADICTED)
	content_vbox.add_child(s4_fail_hdr)

	var s4_fail_body := Label.new()
	s4_fail_body.text = (
		"  [ ] Any accused NPC drops below %d reputation\n"
		+ "  [ ] %d days elapsed without all three surviving  (days remaining: %d)"
	) % [ScenarioManager.S4_FAIL_REP_BELOW, S4_DAYS, s4_days_remaining]
	s4_fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s4_fail_body.add_theme_font_size_override("font_size", 12)
	s4_fail_body.add_theme_color_override("font_color", C_BODY)
	content_vbox.add_child(s4_fail_body)

	# ── Scenario 5 ────────────────────────────────────────────────────────
	var s5_suffix := "  (upcoming)" if active_scenario_id != "scenario_5" else ""
	var s5_lbl := Label.new()
	s5_lbl.text = "Scenario 5: The Election%s" % s5_suffix
	s5_lbl.add_theme_font_size_override("font_size", 14)
	s5_lbl.add_theme_color_override("font_color", C_HEADING)
	content_vbox.add_child(s5_lbl)

	if active_scenario_id == "scenario_5":
		var s5_days_lbl := Label.new()
		s5_days_lbl.text = "Days remaining: %d / %d" % [s5_days_remaining, S5_DAYS]
		s5_days_lbl.add_theme_font_size_override("font_size", 12)
		s5_days_lbl.add_theme_color_override("font_color", C_BODY)
		content_vbox.add_child(s5_days_lbl)

	content_vbox.add_child(HSeparator.new())

	var s5_win_hdr := Label.new()
	s5_win_hdr.text = "WIN CONDITION"
	s5_win_hdr.add_theme_font_size_override("font_size", 12)
	s5_win_hdr.add_theme_color_override("font_color", C_SPREADING)
	content_vbox.add_child(s5_win_hdr)

	var s5_win_status := ""
	var s5_win_color  := C_BODY
	match s5_state:
		ScenarioManager.ScenarioState.WON:
			s5_win_status = "[WON]";    s5_win_color = C_SPREADING
		ScenarioManager.ScenarioState.FAILED:
			s5_win_status = "[FAILED]"; s5_win_color = C_CONTRADICTED

	var aldric_score_str := "48"
	var aldric_band_str  := "Suspect"
	if aldric_snap != null:
		aldric_score_str = str(aldric_snap.score)
		aldric_band_str  = ReputationSystem.score_label(aldric_snap.score)

	var edric_s5_str := "58"
	var edric_s5_band := "Respected"
	if edric_snap != null:
		edric_s5_str  = str(edric_snap.score)
		edric_s5_band = ReputationSystem.score_label(edric_snap.score)

	var tomas_s5_str := "45"
	var tomas_s5_band := "Suspect"
	if tomas_snap != null:
		tomas_s5_str  = str(tomas_snap.score)
		tomas_s5_band = ReputationSystem.score_label(tomas_snap.score)

	var s5_win_body := Label.new()
	s5_win_body.text = (
		"  Aldric Vane must reach \u2265 %d rep AND be the highest of three candidates.  %s\n"
		+ "  Both rivals must drop below %d.\n\n"
		+ "  Aldric Vane:  %s / 100  \u2014 %s\n"
		+ "  Edric Fenn:   %s / 100  \u2014 %s\n"
		+ "  Tomas Reeve:  %s / 100  \u2014 %s\n"
		+ "  Endorsement: Day %d (Prior Aldous grants +%d to leader)"
	) % [sm.S5_WIN_ALDRIC_MIN if sm != null else ScenarioConfig.S5_WIN_ALDRIC_MIN, s5_win_status,
		sm.S5_WIN_RIVALS_MAX if sm != null else ScenarioConfig.S5_WIN_RIVALS_MAX,
		aldric_score_str, aldric_band_str,
		edric_s5_str, edric_s5_band,
		tomas_s5_str, tomas_s5_band,
		ScenarioManager.S5_ENDORSEMENT_DAY, sm.S5_ENDORSEMENT_BONUS if sm != null else ScenarioConfig.S5_ENDORSEMENT_BONUS]
	s5_win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s5_win_body.add_theme_font_size_override("font_size", 12)
	s5_win_body.add_theme_color_override("font_color", s5_win_color)
	content_vbox.add_child(s5_win_body)

	content_vbox.add_child(HSeparator.new())

	var s5_fail_hdr := Label.new()
	s5_fail_hdr.text = "FAIL CONDITIONS"
	s5_fail_hdr.add_theme_font_size_override("font_size", 12)
	s5_fail_hdr.add_theme_color_override("font_color", C_CONTRADICTED)
	content_vbox.add_child(s5_fail_hdr)

	var s5_fail_body := Label.new()
	s5_fail_body.text = (
		"  [ ] Aldric Vane drops below %d reputation\n"
		+ "  [ ] %d days elapsed without Aldric winning the election  (days remaining: %d)"
	) % [sm.S5_FAIL_ALDRIC_BELOW if sm != null else 30, S5_DAYS, s5_days_remaining]
	s5_fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s5_fail_body.add_theme_font_size_override("font_size", 12)
	s5_fail_body.add_theme_color_override("font_color", C_BODY)
	content_vbox.add_child(s5_fail_body)

	# ── Scenario 6 ────────────────────────────────────────────────────────
	var s6_suffix := "  (upcoming)" if active_scenario_id != "scenario_6" else ""
	var s6_lbl := Label.new()
	s6_lbl.text = "Scenario 6: The Merchant's Debt%s" % s6_suffix
	s6_lbl.add_theme_font_size_override("font_size", 14)
	s6_lbl.add_theme_color_override("font_color", C_HEADING)
	content_vbox.add_child(s6_lbl)

	if active_scenario_id == "scenario_6":
		var s6_days_lbl := Label.new()
		s6_days_lbl.text = "Days remaining: %d / %d" % [s6_days_remaining, S6_DAYS]
		s6_days_lbl.add_theme_font_size_override("font_size", 12)
		s6_days_lbl.add_theme_color_override("font_color", C_BODY)
		content_vbox.add_child(s6_days_lbl)

	content_vbox.add_child(HSeparator.new())

	var s6_win_hdr := Label.new()
	s6_win_hdr.text = "WIN CONDITION"
	s6_win_hdr.add_theme_font_size_override("font_size", 12)
	s6_win_hdr.add_theme_color_override("font_color", C_SPREADING)
	content_vbox.add_child(s6_win_hdr)

	var s6_win_status := ""
	var s6_win_color  := C_BODY
	match s6_state:
		ScenarioManager.ScenarioState.WON:
			s6_win_status = "[WON]";    s6_win_color = C_SPREADING
		ScenarioManager.ScenarioState.FAILED:
			s6_win_status = "[FAILED]"; s6_win_color = C_CONTRADICTED

	var aldric_s6_str := "55"
	var aldric_s6_band := "Respected"
	if aldric_snap != null:
		aldric_s6_str  = str(aldric_snap.score)
		aldric_s6_band = ReputationSystem.score_label(aldric_snap.score)

	var marta_score_str := "52"
	var marta_band_str  := "Respected"
	if marta_snap != null:
		marta_score_str = str(marta_snap.score)
		marta_band_str  = ReputationSystem.score_label(marta_snap.score)

	var s6_win_body := Label.new()
	s6_win_body.text = (
		"  Expose Aldric Vane (rep \u2264 %d) and protect Marta Coin (rep \u2265 %d).  %s\n\n"
		+ "  Aldric Vane:  %s / 100  \u2014 %s\n"
		+ "  Marta Coin:   %s / 100  \u2014 %s\n"
		+ "  Heat ceiling: %d  (guards on Aldric's payroll)"
	) % [sm.S6_WIN_ALDRIC_MAX if sm != null else 30,
		sm.S6_WIN_MARTA_MIN if sm != null else 62, s6_win_status,
		aldric_s6_str, aldric_s6_band,
		marta_score_str, marta_band_str,
		int(sm.S6_EXPOSED_HEAT) if sm != null else 55]
	s6_win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s6_win_body.add_theme_font_size_override("font_size", 12)
	s6_win_body.add_theme_color_override("font_color", s6_win_color)
	content_vbox.add_child(s6_win_body)

	content_vbox.add_child(HSeparator.new())

	var s6_fail_hdr := Label.new()
	s6_fail_hdr.text = "FAIL CONDITIONS"
	s6_fail_hdr.add_theme_font_size_override("font_size", 12)
	s6_fail_hdr.add_theme_color_override("font_color", C_CONTRADICTED)
	content_vbox.add_child(s6_fail_hdr)

	var s6_fail_body := Label.new()
	s6_fail_body.text = (
		"  [ ] Marta Coin drops below %d reputation  (silenced)\n"
		+ "  [ ] Heat reaches %d  (exposed by guards)\n"
		+ "  [ ] %d days elapsed without meeting both targets  (days remaining: %d)"
	) % [sm.S6_FAIL_MARTA_BELOW if sm != null else 30,
		int(sm.S6_EXPOSED_HEAT) if sm != null else 55,
		S6_DAYS, s6_days_remaining]
	s6_fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s6_fail_body.add_theme_font_size_override("font_size", 12)
	s6_fail_body.add_theme_color_override("font_color", C_BODY)
	content_vbox.add_child(s6_fail_body)


# ── UI helpers ────────────────────────────────────────────────────────────────

func _add_section_header(parent: VBoxContainer, title: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	parent.add_child(spacer)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_HEADING)
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
	parent.add_child(lbl)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	parent.add_child(sep)
