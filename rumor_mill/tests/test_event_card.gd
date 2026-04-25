## test_event_card.gd — Unit tests for event_card.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Layout constants: CARD_W, CARD_H, DIM_TIME, CARD_TIME, C_DIM_MAX
##   • Initial node refs null (no scene tree — show_event() not called)
##
## NOTE: show_event() calls _build_ui() and create_tween() — not tested here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEventCard
extends RefCounted

const EventCardScript := preload("res://scripts/event_card.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ec() -> CanvasLayer:
	return EventCardScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_panel_bg_dark",
		"test_c_accent_amber",
		"test_c_heading_warm_gold",
		"test_c_btn_text_warm",
		"test_c_dim_max_half",
		# Layout constants
		"test_card_w",
		"test_card_h",
		"test_dim_time",
		"test_card_time",
		# Initial node refs
		"test_initial_dim_null",
		"test_initial_card_null",
		"test_initial_title_lbl_null",
		"test_initial_body_lbl_null",
		"test_initial_day_lbl_null",
		"test_initial_dismiss_btn_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEventCard tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_panel_bg_dark() -> bool:
	var ec := _make_ec()
	var ok := ec.C_PANEL_BG.r < 0.10 and ec.C_PANEL_BG.a > 0.90
	ec.free()
	return ok


static func test_c_accent_amber() -> bool:
	var ec := _make_ec()
	# amber #F4A63A: high r, moderate-high g, low b
	var ok := ec.C_ACCENT.r > 0.90 and ec.C_ACCENT.g > 0.55 and ec.C_ACCENT.b < 0.30
	ec.free()
	return ok


static func test_c_heading_warm_gold() -> bool:
	var ec := _make_ec()
	var ok := ec.C_HEADING.r > 0.90 and ec.C_HEADING.g > 0.75 and ec.C_HEADING.b < 0.50
	ec.free()
	return ok


static func test_c_btn_text_warm() -> bool:
	var ec := _make_ec()
	var ok := ec.C_BTN_TEXT.r > 0.85 and ec.C_BTN_TEXT.g > 0.75
	ec.free()
	return ok


static func test_c_dim_max_half() -> bool:
	var ec := _make_ec()
	var ok := ec.C_DIM_MAX == 0.5
	ec.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_card_w() -> bool:
	var ec := _make_ec()
	var ok := ec.CARD_W == 450.0
	ec.free()
	return ok


static func test_card_h() -> bool:
	var ec := _make_ec()
	var ok := ec.CARD_H == 300.0
	ec.free()
	return ok


static func test_dim_time() -> bool:
	var ec := _make_ec()
	var ok := ec.DIM_TIME == 0.5
	ec.free()
	return ok


static func test_card_time() -> bool:
	var ec := _make_ec()
	var ok := ec.CARD_TIME == 0.25
	ec.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_dim_null() -> bool:
	var ec := _make_ec()
	var ok := ec._dim == null
	ec.free()
	return ok


static func test_initial_card_null() -> bool:
	var ec := _make_ec()
	var ok := ec._card == null
	ec.free()
	return ok


static func test_initial_title_lbl_null() -> bool:
	var ec := _make_ec()
	var ok := ec._title_lbl == null
	ec.free()
	return ok


static func test_initial_body_lbl_null() -> bool:
	var ec := _make_ec()
	var ok := ec._body_lbl == null
	ec.free()
	return ok


static func test_initial_day_lbl_null() -> bool:
	var ec := _make_ec()
	var ok := ec._day_lbl == null
	ec.free()
	return ok


static func test_initial_dismiss_btn_null() -> bool:
	var ec := _make_ec()
	var ok := ec._dismiss_btn == null
	ec.free()
	return ok
