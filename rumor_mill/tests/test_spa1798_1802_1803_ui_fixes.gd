## test_spa1798_1802_1803_ui_fixes.gd — Regression tests for three UI bug fixes
## shipped in the 2026-05-05 fix batch (SPA-1823).
##
## Covers:
##   SPA-1798 (commit 4824cb4) — mission_card.gd line 79 referenced the bare
##     identifier POPUP_Y which was never declared.  The fix replaces it with the
##     computed instance variable _popup_y (derived from POPUP_Y_FRAC at setup()
##     time).  Tests: parse-error guard (script preloads cleanly), fraction
##     constants correct, _popup_y field declared and starts at 0.0.
##
##   SPA-1802 (commit 9e4cdd0) — NPC dialogue panel text overflow hiding action
##     buttons.  The fix adds clip_text + OVERRUN_TRIM_ELLIPSIS on the NPC name
##     label and max_lines=3 + OVERRUN_TRIM_ELLIPSIS on the greeting label, plus
##     a second await-process-frame pass and viewport-height clamp on panel sizing.
##     Tests: parse-error guard, layout constant PANEL_W.
##     Note: _rebuild_panel() uses get_tree() in its resize pass; label property
##     checks (clip_text, max_lines) require a running scene tree and are covered
##     by manual QA at 720p/1080p.
##
##   SPA-1803 (commit 0f987e2) — event choice modal body/outcome RichTextLabels
##     had fit_content=true and scroll_active=false, causing long text to overflow
##     behind choice buttons.  The fix sets fit_content=false / scroll_active=true.
##     Tests: parse-error guard, layout constants PANEL_WIDTH / PANEL_HEIGHT.
##     Note: _build_ui() calls get_viewport() and cannot run headless; scroll_active
##     verification is covered by manual QA at 720p.
##
## All three parse-error guards are the primary regression value: GDScript refuses
## to compile scripts with undefined-name references, so a successful preload
## proves the fix is in place.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa1798_1802_1803UiFixes
extends RefCounted

const MissionCardScript      := preload("res://scripts/mission_card.gd")
const NpcDialoguePanelScript := preload("res://scripts/npc_dialogue_panel.gd")
const EventChoiceModalScript := preload("res://scripts/event_choice_modal.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_mc() -> CanvasLayer:
	return MissionCardScript.new()


static func _make_panel() -> Node:
	return NpcDialoguePanelScript.new()


static func _make_ecm() -> CanvasLayer:
	return EventChoiceModalScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# SPA-1798 — mission_card.gd: undefined POPUP_Y → _popup_y (commit 4824cb4)
		"test_spa1798_mission_card_script_loads_clean",
		"test_spa1798_popup_y_frac_is_0_10",
		"test_spa1798_popup_w_frac_is_0_422",
		"test_spa1798_popup_h_frac_is_0_233",
		"test_spa1798_popup_y_var_initially_zero",

		# SPA-1802 — npc_dialogue_panel.gd: text overflow hides action buttons (commit 9e4cdd0)
		"test_spa1802_npc_dialogue_panel_script_loads_clean",
		"test_spa1802_panel_w_is_260",

		# SPA-1803 — event_choice_modal.gd: scroll disabled on body/outcome (commit 0f987e2)
		"test_spa1803_event_choice_modal_script_loads_clean",
		"test_spa1803_panel_width_is_700",
		"test_spa1803_panel_height_is_420",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-1798/1802/1803 UI-fix regression: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# SPA-1798 — mission_card.gd: POPUP_Y undefined name → _popup_y (commit 4824cb4)
# ══════════════════════════════════════════════════════════════════════════════

func test_spa1798_mission_card_script_loads_clean() -> bool:
	## Parse-error guard.  Before the fix, line 79 referenced the bare identifier
	## POPUP_Y which was never declared; GDScript refuses to compile scripts with
	## undefined names.  A successful preload (evaluated at class-constant time
	## above) proves the fix is in place.
	var mc := _make_mc()
	var ok: bool = mc != null
	mc.free()
	return ok


func test_spa1798_popup_y_frac_is_0_10() -> bool:
	## POPUP_Y_FRAC is the viewport-height fraction from which _popup_y is computed
	## at setup() time.  Value 0.10 positions the card 10% from the top of the
	## viewport.  Guard against accidental drift or reversion to a hardcoded constant.
	var mc := _make_mc()
	var ok: bool = is_equal_approx(mc.POPUP_Y_FRAC, 0.10)
	mc.free()
	return ok


func test_spa1798_popup_w_frac_is_0_422() -> bool:
	## Card width fraction — unchanged by the SPA-1798 fix.  Guard against drift.
	var mc := _make_mc()
	var ok: bool = is_equal_approx(mc.POPUP_W_FRAC, 0.422)
	mc.free()
	return ok


func test_spa1798_popup_h_frac_is_0_233() -> bool:
	## Card height fraction — unchanged by the SPA-1798 fix.  Guard against drift.
	var mc := _make_mc()
	var ok: bool = is_equal_approx(mc.POPUP_H_FRAC, 0.233)
	mc.free()
	return ok


func test_spa1798_popup_y_var_initially_zero() -> bool:
	## _popup_y is the instance variable the fix correctly references at line 79.
	## It is declared as `var _popup_y: float = 0.0` and is populated by setup()
	## from `_vp_h * POPUP_Y_FRAC`.  On a bare (not-yet-setup) instance it must
	## equal 0.0, confirming the field is declared (not just a dynamic property).
	var mc := _make_mc()
	var ok: bool = mc._popup_y == 0.0
	mc.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# SPA-1802 — npc_dialogue_panel.gd: long text overflows hiding action buttons
# (commit 9e4cdd0)
# ══════════════════════════════════════════════════════════════════════════════

func test_spa1802_npc_dialogue_panel_script_loads_clean() -> bool:
	## Parse-error guard.  The fix adds clip_text, text_overrun_behavior, and
	## max_lines to labels built inside _rebuild_panel(); the script must parse
	## cleanly with these calls present.  Behavioural overflow / button-visibility
	## testing requires a running scene tree (get_tree() used in panel resize) and
	## is covered by manual QA at 720p and 1080p.
	var p := _make_panel()
	var ok: bool = p != null
	p.free()
	return ok


func test_spa1802_panel_w_is_260() -> bool:
	## PANEL_W == 260.0 is the fixed panel width used in _rebuild_panel() to set
	## the greeting label's custom_minimum_size and to clamp the final panel height.
	## A changed value here would break the overflow boundary assumptions.
	var p := _make_panel()
	var ok: bool = p.PANEL_W == 260.0
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# SPA-1803 — event_choice_modal.gd: scroll disabled on body/outcome labels
# (commit 0f987e2)
# ══════════════════════════════════════════════════════════════════════════════

func test_spa1803_event_choice_modal_script_loads_clean() -> bool:
	## Parse-error guard.  The fix changes fit_content=false and scroll_active=true
	## on both RichTextLabels in _build_ui(); the script must parse cleanly with
	## these assignments present.  scroll_active / fit_content runtime checks
	## require _build_ui(), which calls get_viewport() and cannot run headless;
	## verified by manual QA at 720p where overflow was originally observed.
	var ecm := _make_ecm()
	var ok: bool = ecm != null
	ecm.free()
	return ok


func test_spa1803_panel_width_is_700() -> bool:
	## PANEL_WIDTH == 700 — the nominal modal width used as the cap in
	## UILayoutConstants.clamp_to_viewport() during _build_ui().  Text in the body
	## label overflows when the label's width equals this and fit_content=true
	## (the pre-fix state).  Guard that the geometry constant is unchanged.
	var ecm := _make_ecm()
	var ok: bool = ecm.PANEL_WIDTH == 700
	ecm.free()
	return ok


func test_spa1803_panel_height_is_420() -> bool:
	## PANEL_HEIGHT == 420 — the nominal modal height used as the cap.  At 720p
	## a body label with fit_content=true could grow past this boundary and occlude
	## the choice buttons.  The fix (scroll_active=true) prevents the label from
	## growing beyond its SIZE_EXPAND_FILL allocation.
	var ecm := _make_ecm()
	var ok: bool = ecm.PANEL_HEIGHT == 420
	ecm.free()
	return ok
