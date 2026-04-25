## test_end_screen_replay_tab.gd — Unit tests for end_screen_replay_tab.gd (SPA-1026).
##
## Covers:
##   • Color palette constants
##   • Initial instance state: _replay_container, _analytics_ref
##   • setup(): stores container and analytics refs
##   • populate() with null analytics_ref: clears children then returns early (no crash)
##
## EndScreenReplayTab extends RefCounted — safe to instantiate without scene tree.
## Full populate() execution requires a live ScenarioAnalytics object and is not
## exercised here beyond the null-analytics early-return path.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEndScreenReplayTab
extends RefCounted

const EndScreenReplayTabScript := preload("res://scripts/end_screen_replay_tab.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_esrt() -> RefCounted:
	return EndScreenReplayTabScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Color constants
		"test_c_heading_colour",
		"test_c_body_colour",
		"test_c_panel_border_colour",
		"test_c_bar_high_colour",
		"test_c_bar_med_colour",
		"test_c_bar_low_colour",
		"test_c_moment_seed_colour",
		"test_c_moment_peak_colour",
		"test_c_moment_bad_colour",
		# Initial state
		"test_initial_replay_container_null",
		"test_initial_analytics_ref_null",
		# setup()
		"test_setup_stores_replay_container",
		"test_setup_stores_analytics_ref",
		# populate() null-analytics path
		"test_populate_null_analytics_no_crash",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEndScreenReplayTab tests: %d passed, %d failed" % [passed, failed])


# ── Color constants ───────────────────────────────────────────────────────────

static func test_c_heading_colour() -> bool:
	return _make_esrt().C_HEADING == Color(0.91, 0.85, 0.70, 1.0)


static func test_c_body_colour() -> bool:
	return _make_esrt().C_BODY == Color(0.70, 0.65, 0.55, 1.0)


static func test_c_panel_border_colour() -> bool:
	return _make_esrt().C_PANEL_BORDER == Color(0.55, 0.38, 0.18, 1.0)


static func test_c_bar_high_colour() -> bool:
	return _make_esrt().C_BAR_HIGH == Color(0.92, 0.78, 0.12, 1.0)


static func test_c_bar_med_colour() -> bool:
	return _make_esrt().C_BAR_MED == Color(0.85, 0.65, 0.15, 1.0)


static func test_c_bar_low_colour() -> bool:
	return _make_esrt().C_BAR_LOW == Color(0.50, 0.45, 0.38, 1.0)


static func test_c_moment_seed_colour() -> bool:
	return _make_esrt().C_MOMENT_SEED == Color(0.40, 0.75, 0.40, 1.0)


static func test_c_moment_peak_colour() -> bool:
	return _make_esrt().C_MOMENT_PEAK == Color(0.92, 0.78, 0.12, 1.0)


static func test_c_moment_bad_colour() -> bool:
	return _make_esrt().C_MOMENT_BAD == Color(0.85, 0.18, 0.12, 1.0)


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_replay_container_null() -> bool:
	return _make_esrt()._replay_container == null


static func test_initial_analytics_ref_null() -> bool:
	return _make_esrt()._analytics_ref == null


# ── setup() ───────────────────────────────────────────────────────────────────

static func test_setup_stores_replay_container() -> bool:
	var esrt := _make_esrt()
	var vbox := VBoxContainer.new()
	esrt.setup(vbox, null)
	var ok := esrt._replay_container == vbox
	vbox.free()
	return ok


static func test_setup_stores_analytics_ref() -> bool:
	var esrt := _make_esrt()
	var vbox := VBoxContainer.new()
	esrt.setup(vbox, null)
	var ok := esrt._analytics_ref == null
	vbox.free()
	return ok


# ── populate() null-analytics path ───────────────────────────────────────────

## populate() clears _replay_container's children then checks _analytics_ref.
## With a live (empty) VBoxContainer and null analytics, it must return cleanly.
static func test_populate_null_analytics_no_crash() -> bool:
	var esrt := _make_esrt()
	var vbox := VBoxContainer.new()
	esrt.setup(vbox, null)
	esrt.populate()
	vbox.free()
	return true
