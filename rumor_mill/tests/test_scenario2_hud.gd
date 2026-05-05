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
	var ok := h.C_ILLNESS.r > 0.40 and h.C_ILLNESS.g > 0.70 and h.C_ILLNESS.b < 0.40
	h.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_bar_width() -> bool:
	var h := _make_hud()
	var ok := h.BAR_WIDTH == 160
	h.free()
	return ok


static func test_bar_height() -> bool:
	var h := _make_hud()
	var ok := h.BAR_HEIGHT == 12
	h.free()
	return ok


static func test_max_names_shown() -> bool:
	var h := _make_hud()
	var ok := h.MAX_NAMES_SHOWN == 5
	h.free()
	return ok


# ── _scenario_number() ────────────────────────────────────────────────────────

static func test_scenario_number_is_two() -> bool:
	var h := _make_hud()
	var ok := h._scenario_number() == 2
	h.free()
	return ok


# ── Initial node refs (null without scene tree) ───────────────────────────────

static func test_initial_count_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._count_lbl == null
	h.free()
	return ok


static func test_initial_bar_null() -> bool:
	var h := _make_hud()
	var ok := h._bar == null
	h.free()
	return ok


static func test_initial_bar_bg_null() -> bool:
	var h := _make_hud()
	var ok := h._bar_bg == null
	h.free()
	return ok


static func test_initial_believers_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._believers_lbl == null
	h.free()
	return ok


static func test_initial_rejecters_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._rejecters_lbl == null
	h.free()
	return ok


static func test_initial_maren_warning_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._maren_warning_lbl == null
	h.free()
	return ok


static func test_initial_escalation_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._escalation_lbl == null
	h.free()
	return ok


static func test_initial_pip_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._pip_lbl == null
	h.free()
	return ok


static func test_initial_quarantine_btn_null() -> bool:
	var h := _make_hud()
	var ok := h._quarantine_btn == null
	h.free()
	return ok


static func test_initial_quarantine_dropdown_null() -> bool:
	var h := _make_hud()
	var ok := h._quarantine_dropdown == null
	h.free()
	return ok


static func test_initial_quarantine_status_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._quarantine_status_lbl == null
	h.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_maren_neighbours_empty() -> bool:
	var h := _make_hud()
	var ok := h._maren_neighbours.is_empty()
	h.free()
	return ok


# ── Inherited state ───────────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	var h := _make_hud()
	var ok := h._world_ref == null
	h.free()
	return ok


static func test_initial_day_night_ref_null() -> bool:
	var h := _make_hud()
	var ok := h._day_night_ref == null
	h.free()
	return ok


static func test_initial_result_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._result_lbl == null
	h.free()
	return ok


static func test_initial_days_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._days_lbl == null
	h.free()
	return ok


# ── SPA-1565: DEFENDING flag plumbed to HUD signal ───────────────────────────

static func test_initial_maren_is_defending_false() -> bool:
	var h := _make_hud()
	var ok := h._maren_is_defending == false
	h.free()
	return ok


static func test_initial_deconv_toast_panel_null() -> bool:
	var h := _make_hud()
	var ok := h._deconv_toast_panel == null
	h.free()
	return ok


static func test_initial_deconv_toast_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._deconv_toast_lbl == null
	h.free()
	return ok


## Verify _maren_is_defending is set when DEFENDING signal fires (even without scene tree).
static func test_on_maren_state_changed_defending_sets_flag() -> bool:
	var h := _make_hud()
	h._on_maren_rumor_state_changed("Sister Maren", "DEFENDING", "rid_test", "")
	var ok := h._maren_is_defending == true
	h.free()
	return ok


## Non-DEFENDING transitions must not set the flag.
static func test_on_maren_state_changed_non_defending_no_flag() -> bool:
	var h := _make_hud()
	h._on_maren_rumor_state_changed("Sister Maren", "reject", "rid_test", "")
	var ok := h._maren_is_defending == false
	h.free()
	return ok


## Neighbor rejection with _maren_is_defending=false must not crash and must not
## change any visible state (toast panel stays null without _ready).
static func test_neighbor_reject_no_toast_when_not_defending() -> bool:
	var h := _make_hud()
	h._on_neighbor_rumor_state_changed("Tomas", "reject", "rid_test", "")
	# _deconv_toast_panel is still null (no _ready) and no crash occurred.
	var ok := h._deconv_toast_panel == null
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
	var ok := "countering" in h._maren_watch_lbl.text
	h._maren_watch_lbl.free()
	h.free()
	return ok


# ── SPA-1701 B1: pre-trigger watch label ─────────────────────────────────────

## _maren_watch_lbl must be null before _build_ui() runs (no scene tree).
static func test_initial_maren_watch_lbl_null() -> bool:
	var h := _make_hud()
	var ok := h._maren_watch_lbl == null
	h.free()
	return ok


## C_DEFENDING_DORMANT must have low alpha so the dormant state appears dimmed.
static func test_c_defending_dormant_is_dimmed() -> bool:
	var h := _make_hud()
	# alpha ≤ 0.60 confirms the dormant color is visually suppressed.
	var ok := h.C_DEFENDING_DORMANT.a <= 0.60
	h.free()
	return ok


# ── SPA-1701 B2: grace-window warning includes hint text ─────────────────────

## After _on_maren_grace_started fires, the warning label must become visible.
static func test_on_maren_grace_started_makes_warning_visible() -> bool:
	var h := _make_hud()
	h._maren_warning_lbl = Label.new()
	h._on_maren_grace_started(2)
	var ok := h._maren_warning_lbl.visible == true
	h._maren_warning_lbl.free()
	h.free()
	return ok


## The grace-window warning text must contain a contextual recovery hint ("Tip").
static func test_on_maren_grace_started_warning_includes_tip() -> bool:
	var h := _make_hud()
	h._maren_warning_lbl = Label.new()
	h._on_maren_grace_started(2)
	var ok := "Tip" in h._maren_warning_lbl.text
	h._maren_warning_lbl.free()
	h.free()
	return ok


# ── SPA-1701 B3: non-S2 scenario has no watch label ──────────────────────────

## Scenario 1 HUD must not expose _maren_watch_lbl — the mechanic is S2-only.
static func test_scenario1_hud_has_no_maren_watch_lbl() -> bool:
	var h := Scenario1HudScript.new()
	# Use get() so a missing property returns null instead of crashing.
	var ok := h.get("_maren_watch_lbl") == null
	h.free()
	return ok
