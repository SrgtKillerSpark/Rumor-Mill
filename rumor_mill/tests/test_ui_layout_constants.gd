## test_ui_layout_constants.gd — Unit tests for UILayoutConstants (SPA-1669).
##
## Covers:
##   • MARGIN_STANDARD / MARGIN_TIGHT values and ordering
##   • clamp_to_viewport() — clamping behaviour at min, mid, and max ranges
##
## UILayoutConstants extends RefCounted — safe to test without scene tree.

class_name TestUILayoutConstants
extends RefCounted


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_margin_standard_value",
		"test_margin_tight_value",
		"test_margin_standard_gte_tight",
		"test_clamp_to_viewport_below_min",
		"test_clamp_to_viewport_at_target",
		"test_clamp_to_viewport_above_max",
		"test_clamp_to_viewport_exact_min",
		"test_clamp_to_viewport_exact_max",
		"test_clamp_to_viewport_1280x720_wide_panel",
		"test_clamp_to_viewport_800_wide_panel",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nUILayoutConstants tests: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		push_error("UILayoutConstants: %d test(s) FAILED" % failed)


# ── Margin constants ─────────────────────────────────────────────────────────

func test_margin_standard_value() -> bool:
	return UILayoutConstants.MARGIN_STANDARD == 20

func test_margin_tight_value() -> bool:
	return UILayoutConstants.MARGIN_TIGHT == 12

func test_margin_standard_gte_tight() -> bool:
	return UILayoutConstants.MARGIN_STANDARD >= UILayoutConstants.MARGIN_TIGHT


# ── clamp_to_viewport ──���─────────────────────────────────────────────────────

func test_clamp_to_viewport_below_min() -> bool:
	# Viewport so small that fraction * extent < min → should return min.
	return UILayoutConstants.clamp_to_viewport(400.0, 0.55, 500, 700) == 500

func test_clamp_to_viewport_at_target() -> bool:
	# 1280 * 0.55 = 704 → clamped to 700 (max).
	return UILayoutConstants.clamp_to_viewport(1280.0, 0.55, 500, 700) == 700

func test_clamp_to_viewport_above_max() -> bool:
	# 1920 * 0.55 = 1056 → clamped to max 700.
	return UILayoutConstants.clamp_to_viewport(1920.0, 0.55, 500, 700) == 700

func test_clamp_to_viewport_exact_min() -> bool:
	# 500 / 0.55 ≈ 909 → 909 * 0.55 = 499 → rounds to 499 < 500 → returns min.
	return UILayoutConstants.clamp_to_viewport(909.0, 0.55, 500, 700) == 500

func test_clamp_to_viewport_exact_max() -> bool:
	# 1273 * 0.55 = 700.15 → int(700.15) = 700 → exactly max.
	return UILayoutConstants.clamp_to_viewport(1273.0, 0.55, 500, 700) == 700

func test_clamp_to_viewport_1280x720_wide_panel() -> bool:
	# Typical base viewport: 1280 * 0.55 = 704 → clamped to 700.
	var w := UILayoutConstants.clamp_to_viewport(1280.0, 0.55, 500, 700)
	var h := UILayoutConstants.clamp_to_viewport(720.0, 0.72, 400, 520)
	return w == 700 and h == 518

func test_clamp_to_viewport_800_wide_panel() -> bool:
	# Narrow viewport: 800 * 0.55 = 440 → below 500 min, returns 500.
	var w := UILayoutConstants.clamp_to_viewport(800.0, 0.55, 500, 700)
	return w == 500
