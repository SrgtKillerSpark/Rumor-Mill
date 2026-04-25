## test_help_reminder_ui.gd — Unit tests for help_reminder_ui.gd (SPA-1042).
##
## Covers:
##   • Initial state: controls_ref null (setup() not called)
##
## NOTE: setup() calls _init_controls_reference() which calls preload and add_child.
## Those require a scene tree — not tested here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestHelpReminderUI
extends RefCounted


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hrui() -> HelpReminderUI:
	return HelpReminderUI.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_initial_controls_ref_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nHelpReminderUI tests: %d passed, %d failed" % [passed, failed])


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_controls_ref_null() -> bool:
	var h := _make_hrui()
	var ok := h.controls_ref == null
	h.free()
	return ok
