## test_thought_bubble_legend.gd — Unit tests for thought_bubble_legend.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • LEGEND_ENTRIES: 5 entries, each has symbol/color/desc keys
##   • COLLAPSE_AFTER_DAY, MARGIN constants
##   • Initial state: _panel/_content_vbox/_tab_btn null (built in _ready — not called here)
##   • Initial state: _expanded=true, _day_night=null
##
## Run from the Godot editor: Scene → Run Script.

class_name TestThoughtBubbleLegend
extends RefCounted

const ThoughtBubbleLegendScript := preload("res://scripts/thought_bubble_legend.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_tbl() -> CanvasLayer:
	return ThoughtBubbleLegendScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_bg_dark",
		"test_c_heading_gold",
		"test_c_symbol_warm",
		# LEGEND_ENTRIES
		"test_legend_entries_count",
		"test_legend_entries_have_symbol",
		"test_legend_entries_have_desc",
		"test_legend_entry_first_evaluating",
		# Constants
		"test_collapse_after_day",
		"test_margin",
		# Initial state
		"test_initial_panel_null",
		"test_initial_content_vbox_null",
		"test_initial_tab_btn_null",
		"test_initial_expanded_true",
		"test_initial_day_night_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nThoughtBubbleLegend tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_bg_dark() -> bool:
	var tbl := _make_tbl()
	var ok := tbl.C_BG.r < 0.15 and tbl.C_BG.a > 0.80
	tbl.free()
	return ok


static func test_c_heading_gold() -> bool:
	var tbl := _make_tbl()
	var ok := tbl.C_HEADING.r > 0.85 and tbl.C_HEADING.g > 0.70 and tbl.C_HEADING.b < 0.20
	tbl.free()
	return ok


static func test_c_symbol_warm() -> bool:
	var tbl := _make_tbl()
	var ok := tbl.C_SYMBOL.r > 0.85 and tbl.C_SYMBOL.g > 0.80 and tbl.C_SYMBOL.b > 0.55
	tbl.free()
	return ok


# ── LEGEND_ENTRIES ────────────────────────────────────────────────────────────

static func test_legend_entries_count() -> bool:
	var tbl := _make_tbl()
	var ok := tbl.LEGEND_ENTRIES.size() == 5
	tbl.free()
	return ok


static func test_legend_entries_have_symbol() -> bool:
	var tbl := _make_tbl()
	var ok := true
	for entry in tbl.LEGEND_ENTRIES:
		if not (entry as Dictionary).has("symbol"):
			ok = false
			break
	tbl.free()
	return ok


static func test_legend_entries_have_desc() -> bool:
	var tbl := _make_tbl()
	var ok := true
	for entry in tbl.LEGEND_ENTRIES:
		if not (entry as Dictionary).has("desc"):
			ok = false
			break
	tbl.free()
	return ok


static func test_legend_entry_first_evaluating() -> bool:
	var tbl := _make_tbl()
	var ok := tbl.LEGEND_ENTRIES[0].get("desc", "") == "Evaluating"
	tbl.free()
	return ok


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_collapse_after_day() -> bool:
	var tbl := _make_tbl()
	var ok := tbl.COLLAPSE_AFTER_DAY == 5
	tbl.free()
	return ok


static func test_margin() -> bool:
	var tbl := _make_tbl()
	var ok := tbl.MARGIN == 16
	tbl.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_panel_null() -> bool:
	var tbl := _make_tbl()
	var ok := tbl._panel == null
	tbl.free()
	return ok


static func test_initial_content_vbox_null() -> bool:
	var tbl := _make_tbl()
	var ok := tbl._content_vbox == null
	tbl.free()
	return ok


static func test_initial_tab_btn_null() -> bool:
	var tbl := _make_tbl()
	var ok := tbl._tab_btn == null
	tbl.free()
	return ok


static func test_initial_expanded_true() -> bool:
	var tbl := _make_tbl()
	var ok := tbl._expanded == true
	tbl.free()
	return ok


static func test_initial_day_night_null() -> bool:
	var tbl := _make_tbl()
	var ok := tbl._day_night == null
	tbl.free()
	return ok
