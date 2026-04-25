## test_main_menu_stats_panel.gd — Unit tests for main_menu_stats_panel.gd (SPA-1042).
##
## Covers:
##   • Palette constants — characteristic colour assertions
##   • C_SCORE_WIN (gold) and C_SCORE_FAIL (red) for score display
##   • Initial state: panel null
##
## Run from the Godot editor: Scene → Run Script.

class_name TestMainMenuStatsPanel
extends RefCounted


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_sp() -> MainMenuStatsPanel:
	return MainMenuStatsPanel.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_panel_bg_dark_brown",
		"test_c_title_is_gold",
		"test_c_score_win_is_gold",
		"test_c_score_fail_is_red",
		"test_c_muted_low_saturation",
		# Initial state
		"test_initial_panel_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nMainMenuStatsPanel tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_panel_bg_dark_brown() -> bool:
	var sp := _make_sp()
	var ok := sp.C_PANEL_BG.r > sp.C_PANEL_BG.b and sp.C_PANEL_BG.r < 0.25
	sp.free()
	return ok


static func test_c_title_is_gold() -> bool:
	var sp := _make_sp()
	# gold: high r, high g, low b
	var ok := sp.C_TITLE.r > 0.85 and sp.C_TITLE.g > 0.70 and sp.C_TITLE.b < 0.20
	sp.free()
	return ok


static func test_c_score_win_is_gold() -> bool:
	var sp := _make_sp()
	# same gold hue as C_TITLE
	var ok := sp.C_SCORE_WIN.r > 0.85 and sp.C_SCORE_WIN.g > 0.70 and sp.C_SCORE_WIN.b < 0.20
	sp.free()
	return ok


static func test_c_score_fail_is_red() -> bool:
	var sp := _make_sp()
	var ok := sp.C_SCORE_FAIL.r > 0.80 and sp.C_SCORE_FAIL.g < 0.25 and sp.C_SCORE_FAIL.b < 0.20
	sp.free()
	return ok


static func test_c_muted_low_saturation() -> bool:
	var sp := _make_sp()
	# muted: all channels fairly close together, mid range
	var ok := sp.C_MUTED.r > 0.50 and sp.C_MUTED.r < 0.80
	sp.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_panel_null() -> bool:
	var sp := _make_sp()
	var ok := sp.panel == null
	sp.free()
	return ok
