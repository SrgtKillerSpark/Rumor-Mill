## test_suggestion_toast.gd — Unit tests for suggestion_toast.gd (SPA-1042).
##
## Covers:
##   • Palette: C_SUGGESTION (soft green)
##   • Constants: AUTO_DISMISS_SEC, FAST_DISMISS_THRESHOLD_SEC
##
## NOTE: SuggestionToast calls _build_style() and _build_children() in _init(),
## so _hint_label and _dismiss_btn are always non-null after construction.
## Node-ref null checks are therefore omitted.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSuggestionToast
extends RefCounted


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_toast() -> SuggestionToast:
	return SuggestionToast.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_suggestion_soft_green",
		# Constants
		"test_auto_dismiss_sec",
		"test_fast_dismiss_threshold_sec",
		# Initial state accessible without scene tree
		"test_initial_shown_at_sec_zero",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSuggestionToast tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_suggestion_soft_green() -> bool:
	var t := _make_toast()
	# soft green: moderate r, high g, moderate b
	var ok := t.C_SUGGESTION.g > 0.80 and t.C_SUGGESTION.r > 0.70 and t.C_SUGGESTION.r < 0.90
	t.free()
	return ok


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_auto_dismiss_sec() -> bool:
	var t := _make_toast()
	var ok := t.AUTO_DISMISS_SEC == 8.0
	t.free()
	return ok


static func test_fast_dismiss_threshold_sec() -> bool:
	var t := _make_toast()
	var ok := t.FAST_DISMISS_THRESHOLD_SEC == 1.0
	t.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_shown_at_sec_zero() -> bool:
	var t := _make_toast()
	var ok := t._shown_at_sec == 0.0
	t.free()
	return ok
