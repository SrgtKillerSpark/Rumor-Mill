## test_whats_changed_card.gd — Unit tests for whats_changed_card.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Initial node refs null (setup() calls _build_shell() — not called here)
##
## Run from the Godot editor: Scene → Run Script.

class_name TestWhatsChangedCard
extends RefCounted

const WhatsChangedCardScript := preload("res://scripts/whats_changed_card.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_wcc() -> CanvasLayer:
	return WhatsChangedCardScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_backdrop_near_black",
		"test_c_title_warm_gold",
		"test_c_btn_normal_dark_green",
		"test_c_btn_text_near_white",
		# Initial node refs
		"test_initial_backdrop_null",
		"test_initial_card_null",
		"test_initial_vbox_null",
		"test_initial_btn_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nWhatsChangedCard tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_backdrop_near_black() -> bool:
	var w := _make_wcc()
	var ok := w.C_BACKDROP.r < 0.10 and w.C_BACKDROP.a > 0.70
	w.free()
	return ok


static func test_c_title_warm_gold() -> bool:
	var w := _make_wcc()
	var ok := w.C_TITLE.r > 0.90 and w.C_TITLE.g > 0.75 and w.C_TITLE.b < 0.50
	w.free()
	return ok


static func test_c_btn_normal_dark_green() -> bool:
	var w := _make_wcc()
	var ok := w.C_BTN_NORMAL.g > 0.35 and w.C_BTN_NORMAL.r < 0.25
	w.free()
	return ok


static func test_c_btn_text_near_white() -> bool:
	var w := _make_wcc()
	var ok := w.C_BTN_TEXT.r > 0.90 and w.C_BTN_TEXT.g > 0.90 and w.C_BTN_TEXT.b > 0.85
	w.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_backdrop_null() -> bool:
	var w := _make_wcc()
	var ok := w._backdrop == null
	w.free()
	return ok


static func test_initial_card_null() -> bool:
	var w := _make_wcc()
	var ok := w._card == null
	w.free()
	return ok


static func test_initial_vbox_null() -> bool:
	var w := _make_wcc()
	var ok := w._vbox == null
	w.free()
	return ok


static func test_initial_btn_null() -> bool:
	var w := _make_wcc()
	var ok := w._btn == null
	w.free()
	return ok
