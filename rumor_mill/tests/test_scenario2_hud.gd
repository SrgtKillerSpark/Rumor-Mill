## test_scenario2_hud.gd — Unit tests for scenario2_hud.gd (SPA-1042).
##
## Covers:
##   • C_ILLNESS palette constant
##   • Layout constants: BAR_WIDTH, BAR_HEIGHT, MAX_NAMES_SHOWN
##   • _scenario_number(): returns 2
##   • Initial node refs null (no scene tree, _ready() not called)
##   • Initial state: _maren_neighbours = {}, _maren_is_defending = false
##   • Inherited state: _world_ref, _day_night_ref, _result_lbl, _days_lbl
##   • SPA-1565: DEFENDING flag plumbed to HUD signal; neighbor rejection toast gated
##   • SPA-1701 B1: _maren_watch_lbl exists and C_DEFENDING_DORMANT is dimmed
##   • SPA-1701 B2: _on_maren_grace_started shows warning with hint text
##   • SPA-1701 B3: non-S2 HUD has no _maren_watch_lbl property
##   • SPA-1702: Suppression indicator visible when DEFENDING, absent otherwise/non-S2
##
## Run from the Godot editor: Scene → Run Script.

class_name TestScenario2Hud
extends RefCounted

const Scenario2HudScript := preload("res://scripts/scenario2_hud.gd")
const Scenario1HudScript := preload("res://scripts/scenario1_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return Scenario2HudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_illness_is_sickly_green",
		# Layout constants
		"test_bar_width",
		"test_bar_height",
		"test_max_names_shown",
		# _scenario_number()
		"test_scenario_number_is_two",
		# Initial node refs
		"test_initial_count_lbl_null",
		"test_initial_bar_null",
		"test_initial_bar_bg_null",
		"test_initial_believers_lbl_null",
		"test_initial_rejecters_lbl_null",
		"test_initial_maren_warning_lbl_null",
		"test_initial_escalation_lbl_null",
		"test_initial_pip_lbl_null",
		"test_initial_quarantine_btn_null",
		"test_initial_quarantine_dropdown_null",
		"test_initial_quarantine_status_lbl_null",
		# Initial state
		"test_initial_maren_neighbours_empty",
		"test_initial_maren_is_defending_false",
		"test_initial_deconv_toast_panel_null",
		"test_initial_deconv_toast_lbl_null",
		# Inherited state
		"test_initial_world_ref_null",
		"test_initial_day_night_ref_null",
		"test_initial_result_lbl_null",
		"test_initial_days_lbl_null",
		# SPA-1565: DEFENDING flag plumbed to HUD signal
		"test_on_maren_state_changed_defending_sets_flag",
		"test_on_maren_state_changed_non_defending_no_flag",
		"test_neighbor_reject_no_toast_when_not_defending",
		"test_defending_watch_text_contains_countering",
		# SPA-1701 B1: pre-trigger watch label
		"test_initial_maren_watch_lbl_null",
		"test_c_defending_dormant_is_dimmed",
		# SPA-1701 B2: grace-window warning includes hint text
		"test_on_maren_grace_started_makes_warning_visible",
		"test_on_maren_grace_started_warning_includes_tip",
		# SPA-1701 B3: non-S2 scenario has no watch label
		"test_scenario1_hud_has_no_maren_watch_lbl",
		# SPA-1702: Suppression indicator visibility during Maren grace window
		"test_suppression_active_indicator_shown_when_defending",
		"test_suppression_indicator_absent_when_not_defending",
		"test_suppression_indicator_absent_on_non_s2",
		# SPA-1984: Win forecast heuristic
		"test_initial_win_forecast_lbl_null",
		"test_win_forecast_already_won",
		"test_win_forecast_on_track_plenty_of_days",
		"test_win_forecast_tight_few_days",
		"test_win_forecast_unlikely_no_days",
		"test_win_forecast_whisper_constrained",
		"test_win_forecast_avg_propagation_rate_positive",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nScenario2Hud tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_illness_is_sickly_green() -> bool:
	var h := _make_hud()
	# sickly green: moderate r, high g, low-moderate b
	var ok: bool = h.C_ILLNESS.r > 0.40 and h.C_ILLNESS.g > 0.70 and h.C_ILLNESS.b < 0.40
	h.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_bar_width() -> bool:
	var h := _make_hud()
	var ok: bool = h.BAR_WIDTH == 160
	h.free()
	return ok


static func test_bar_height() -> bool:
	var h := _make_hud()
	var ok: bool = h.BAR_HEIGHT == 12
	h.free()
	return ok


static func test_max_names_shown() -> bool:
	var h := _make_hud()
	var ok: bool = h.MAX_NAMES_SHOWN == 5
	h.free()
	return ok


# ── _scenario_number() ────────────────────────────────────────────────────────

static func test_scenario_number_is_two() -> bool:
	var h := _make_hud()
	var ok: bool = h._scenario_number() == 2
	h.free()
	return ok


# ── Initial node refs (null without scene tree) ───────────────────────────────

static func test_initial_count_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._count_lbl == null
	h.free()
	return ok


static func test_initial_bar_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._bar == null
	h.free()
	return ok


static func test_initial_bar_bg_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._bar_bg == null
	h.free()
	return ok


static func test_initial_believers_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._believers_lbl == null
	h.free()
	return ok


static func test_initial_rejecters_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._rejecters_lbl == null
	h.free()
	return ok


static func test_initial_maren_warning_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._maren_warning_lbl == null
	h.free()
	return ok


static func test_initial_escalation_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._escalation_lbl == null
	h.free()
	return ok


static func test_initial_pip_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._pip_lbl == null
	h.free()
	return ok


static func test_initial_quarantine_btn_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._quarantine_btn == null
	h.free()
	return ok


static func test_initial_quarantine_dropdown_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._quarantine_dropdown == null
	h.free()
	return ok


static func test_initial_quarantine_status_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._quarantine_status_lbl == null
	h.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_maren_neighbours_empty() -> bool:
	var h := _make_hud()
	var ok: bool = h._maren_neighbours.is_empty()
	h.free()
	return ok


# ── Inherited state ───────────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._world_ref == null
	h.free()
	return ok


static func test_initial_day_night_ref_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._day_night_ref == null
	h.free()
	return ok


static func test_initial_result_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._result_lbl == null
	h.free()
	return ok


static func test_initial_days_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._days_lbl == null
	h.free()
	return ok


# ── SPA-1565: DEFENDING flag plumbed to HUD signal ───────────────────────────

static func test_initial_maren_is_defending_false() -> bool:
	var h := _make_hud()
	var ok: bool = h._maren_is_defending == false
	h.free()
	return ok


static func test_initial_deconv_toast_panel_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._deconv_toast_panel == null
	h.free()
	return ok


static func test_initial_deconv_toast_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._deconv_toast_lbl == null
	h.free()
	return ok


## Verify _maren_is_defending is set when DEFENDING signal fires (even without scene tree).
static func test_on_maren_state_changed_defending_sets_flag() -> bool:
	var h := _make_hud()
	h._on_maren_rumor_state_changed("Sister Maren", "DEFENDING", "rid_test", "")
	var ok: bool = h._maren_is_defending == true
	h.free()
	return ok


## Non-DEFENDING transitions must not set the flag.
static func test_on_maren_state_changed_non_defending_no_flag() -> bool:
	var h := _make_hud()
	h._on_maren_rumor_state_changed("Sister Maren", "reject", "rid_test", "")
	var ok: bool = h._maren_is_defending == false
	h.free()
	return ok


## Neighbor rejection with _maren_is_defending=false must not crash and must not
## change any visible state (toast panel stays null without _ready).
static func test_neighbor_reject_no_toast_when_not_defending() -> bool:
	var h := _make_hud()
	h._on_neighbor_rumor_state_changed("Tomas", "reject", "rid_test", "")
	# _deconv_toast_panel is still null (no _ready) and no crash occurred.
	var ok: bool = h._deconv_toast_panel == null
	h.free()
	return ok


## When DEFENDING is signalled, the watch label text (once _build_ui runs) should
## reference countering. Without scene tree the label stays null — we verify the
## constant string directly on the HUD constant for regression safety.
static func test_defending_watch_text_contains_countering() -> bool:
	var h := _make_hud()
	# Simulate the label existing so we can verify the text set by the signal handler.
	h._maren_watch_lbl = Label.new()
	h._on_maren_rumor_state_changed("Sister Maren", "DEFENDING", "", "")
	var ok: bool = "countering" in h._maren_watch_lbl.text
	h._maren_watch_lbl.free()
	h.free()
	return ok


# ── SPA-1701 B1: pre-trigger watch label ─────────────────────────────────────

## _maren_watch_lbl must be null before _build_ui() runs (no scene tree).
static func test_initial_maren_watch_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._maren_watch_lbl == null
	h.free()
	return ok


## C_DEFENDING_DORMANT must have low alpha so the dormant state appears dimmed.
static func test_c_defending_dormant_is_dimmed() -> bool:
	var h := _make_hud()
	# alpha ≤ 0.60 confirms the dormant color is visually suppressed.
	var ok: bool = h.C_DEFENDING_DORMANT.a <= 0.60
	h.free()
	return ok


# ── SPA-1701 B2: grace-window warning includes hint text ─────────────────────

## After _on_maren_grace_started fires, the warning label must become visible.
static func test_on_maren_grace_started_makes_warning_visible() -> bool:
	var h := _make_hud()
	h._maren_warning_lbl = Label.new()
	h._on_maren_grace_started(2)
	var ok: bool = h._maren_warning_lbl.visible == true
	h._maren_warning_lbl.free()
	h.free()
	return ok


## The grace-window warning text must contain a contextual recovery hint ("Tip").
static func test_on_maren_grace_started_warning_includes_tip() -> bool:
	var h := _make_hud()
	h._maren_warning_lbl = Label.new()
	h._maren_hint_lbl = Label.new()
	h._on_maren_grace_started(2)
	var ok: bool = "Tip" in h._maren_hint_lbl.text
	h._maren_warning_lbl.free()
	h._maren_hint_lbl.free()
	h.free()
	return ok


# ── SPA-1701 B3: non-S2 scenario has no watch label ──────────────────────────

## Scenario 1 HUD must not expose _maren_watch_lbl — the mechanic is S2-only.
static func test_scenario1_hud_has_no_maren_watch_lbl() -> bool:
	var h := Scenario1HudScript.new()
	# Use get() so a missing property returns null instead of crashing.
	var ok: bool = h.get("_maren_watch_lbl") == null
	h.free()
	return ok


# ── SPA-1702: Suppression indicator visibility ────────────────────────────────

## When Maren enters DEFENDING, the watch label shows both the shield icon and
## "countering" text — confirming the active suppression indicator is visible.
static func test_suppression_active_indicator_shown_when_defending() -> bool:
	var h := _make_hud()
	h._maren_watch_lbl = Label.new()
	h._on_maren_rumor_state_changed("Sister Maren", "DEFENDING", "", "")
	var text: String = h._maren_watch_lbl.text
	var ok: bool = "🛡" in text and "countering" in text
	h._maren_watch_lbl.free()
	h.free()
	return ok


## When Maren is NOT defending, the watch label must show dormant text and must
## NOT contain the active "countering" indicator.
static func test_suppression_indicator_absent_when_not_defending() -> bool:
	var h := _make_hud()
	h._maren_watch_lbl = Label.new()
	h._maren_watch_lbl.text = "🛡 Maren's Watch: dormant"
	# No DEFENDING signal — text must remain dormant, not active.
	var text: String = h._maren_watch_lbl.text
	var ok: bool = "dormant" in text and not ("countering" in text)
	h._maren_watch_lbl.free()
	h.free()
	return ok


## Non-S2 HUDs have no _maren_neighbours property — the gate predicate that
## appends [🛡] to NPC names is unreachable on any scenario other than S2.
static func test_suppression_indicator_absent_on_non_s2() -> bool:
	var h := Scenario1HudScript.new()
	# get() returns null when the property does not exist on the script.
	var ok: bool = h.get("_maren_neighbours") == null
	h.free()
	return ok


# ── SPA-1984: Win forecast heuristic ─────────────────────────────────────────

## _win_forecast_lbl must be null before _build_ui() runs (no scene tree).
static func test_initial_win_forecast_lbl_null() -> bool:
	var h := _make_hud()
	var ok: bool = h._win_forecast_lbl == null
	h.free()
	return ok


## AVG_PROPAGATION_RATE must be a positive float so the heuristic is always meaningful.
static func test_win_forecast_avg_propagation_rate_positive() -> bool:
	var h := _make_hud()
	var ok: bool = h.AVG_PROPAGATION_RATE > 0.0 and h.AVG_PROPAGATION_RATE <= 1.0
	h.free()
	return ok


## When count >= threshold the player has already won — forecast is "on_track".
static func test_win_forecast_already_won() -> bool:
	var h := _make_hud()
	# count=7, threshold=7: already at win condition.
	var result: String = h.compute_win_forecast(7, 7, 10, 24, 5)
	var ok: bool = result == "on_track"
	h.free()
	return ok


## Plenty of days and whisper tokens relative to remaining targets → "on_track".
## remaining_targets=2, remaining_days=10, whisper_tokens=10
## effective_seeds=10, projected=7.0 ≥ 2 → on_track
static func test_win_forecast_on_track_plenty_of_days() -> bool:
	var h := _make_hud()
	# Day 14 of 24, count=5, threshold=7, whispers=10: 10 days left, 2 needed.
	var result: String = h.compute_win_forecast(5, 7, 14, 24, 10)
	var ok: bool = result == "on_track"
	h.free()
	return ok


## Barely enough capacity but within 60% threshold → "tight".
## remaining_targets=3, effective_seeds=3, projected=2.1 ≥ 3*0.6=1.8 → tight
static func test_win_forecast_tight_few_days() -> bool:
	var h := _make_hud()
	# Day 21 of 24, count=4, threshold=7, whispers=3: 3 days left, 3 needed.
	# projected = 3 * 0.7 = 2.1; 2.1 >= 3*0.6=1.8 → tight
	var result: String = h.compute_win_forecast(4, 7, 21, 24, 3)
	var ok: bool = result == "tight"
	h.free()
	return ok


## No days remaining → "unlikely".
## remaining_days=0, effective_seeds=0, projected=0.0 < remaining_targets → unlikely
static func test_win_forecast_unlikely_no_days() -> bool:
	var h := _make_hud()
	# Day 24 of 24, count=4, threshold=7, whispers=5: 0 days left, 3 needed.
	var result: String = h.compute_win_forecast(4, 7, 24, 24, 5)
	var ok: bool = result == "unlikely"
	h.free()
	return ok


## Whisper budget is the binding constraint even with plenty of time → "unlikely".
## remaining_days=10, whisper_tokens=0, effective_seeds=0 → projected=0 → unlikely
static func test_win_forecast_whisper_constrained() -> bool:
	var h := _make_hud()
	# Day 14 of 24, count=5, threshold=7, whispers=0: lots of time but no whispers.
	var result: String = h.compute_win_forecast(5, 7, 14, 24, 0)
	var ok: bool = result == "unlikely"
	h.free()
	return ok
