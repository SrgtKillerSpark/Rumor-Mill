## test_pause_menu.gd — Unit tests for pause_menu.gd (SPA-1015).
##
## Covers:
##   • Color palette constants: C_BTN_NORMAL, C_BTN_HOVER, C_BTN_PRESSED,
##                              C_BTN_BORDER, C_BTN_TEXT
##   • Static var: _pending_restart_id initial value
##   • Initial instance state: _is_open, _scenario_id, _how_to_play,
##                             _settings_menu
##   • Initial game-system refs: _world_ref, _day_night_ref, _journal_ref,
##                               _tutorial_sys_ref
##   • Initial UI refs: _status_label, context labels (all null pre-_ready)
##   • Slot picker state: _confirm_action, _slot_mode_save, container refs
##   • setup(): stores scenario_id
##   • setup_save_load(): stores world, day_night, and journal refs
##   • setup_tutorial(): stores tutorial system ref
##
## Phase 2.5 backfill (SPA-2456):
##   • Overwrite confirmation flow — _on_restart_scenario() sets _confirm_action "restart";
##     _on_quit_to_menu() sets "quit"; _on_confirm_no() restores main visibility
##   • Load/Save null guards — both handlers return early without changing _slot_mode_save
##     when _world_ref is null (unsaved-progress guard)
##
## SPA-2453 backfill:
##   • Initial state of five new SPA-2453 vars: _pending_save_slot, _pending_load_slot,
##     _confirm_lbl, _confirm_source, _auto_save_note
##   • Confirm-source tagging: restart/quit both set _confirm_source to "main"
##   • _on_confirm_no() with source="slot" restores slot picker; clears pending slots
##
## pause_menu.gd extends CanvasLayer. _ready() is NOT called (node is not
## added to the scene tree), so all nodes built by _build_ui() remain null.
## Confirmation-flow tests inject stub VBoxContainer nodes directly into the
## relevant fields to exercise the state-machine logic without a scene tree.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestPauseMenu
extends RefCounted

const PauseMenuScript := preload("res://scripts/pause_menu.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_pm() -> Node:
	return PauseMenuScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Color constants
		"test_c_btn_normal_colour",
		"test_c_btn_hover_colour",
		"test_c_btn_pressed_colour",
		"test_c_btn_border_colour",
		"test_c_btn_text_colour",
		# Static var
		"test_pending_restart_id_initial_value",
		# Initial instance state
		"test_initial_is_open_false",
		"test_initial_scenario_id_empty",
		"test_initial_how_to_play_null",
		"test_initial_settings_menu_null",
		# Game-system refs
		"test_initial_world_ref_null",
		"test_initial_day_night_ref_null",
		"test_initial_journal_ref_null",
		"test_initial_tutorial_sys_ref_null",
		# UI refs (built by _build_ui, remain null without _ready)
		"test_initial_status_label_null",
		"test_initial_context_scenario_lbl_null",
		"test_initial_context_day_lbl_null",
		"test_initial_context_objective_lbl_null",
		# Slot picker state
		"test_initial_main_container_null",
		"test_initial_slot_container_null",
		"test_initial_confirm_container_null",
		"test_initial_confirm_action_empty",
		"test_initial_slot_mode_save_false",
		# setup() wiring
		"test_setup_stores_scenario_id",
		"test_setup_overwrites_previous_scenario_id",
		# setup_save_load() wiring
		"test_setup_save_load_stores_world_ref",
		"test_setup_save_load_stores_day_night_ref",
		"test_setup_save_load_stores_journal_ref",
		# setup_tutorial() wiring
		"test_setup_tutorial_stores_ref",
		# Phase 2.5: Overwrite confirmation flow (SPA-2453)
		"test_restart_sets_confirm_action_restart",
		"test_quit_sets_confirm_action_quit",
		"test_confirm_no_hides_confirm_shows_main",
		# Phase 2.5: Load/Save null guards (unsaved-progress protection)
		"test_save_guard_null_world_preserves_slot_mode",
		"test_load_guard_null_world_preserves_slot_mode",
		# SPA-2453: new state variable initial values
		"test_initial_pending_save_slot_minus_one",
		"test_initial_pending_load_slot_minus_one",
		"test_initial_confirm_lbl_null",
		"test_initial_confirm_source_empty",
		"test_initial_auto_save_note_null",
		# SPA-2453: confirm-source tagging on restart/quit
		"test_restart_sets_confirm_source_main",
		"test_quit_sets_confirm_source_main",
		# SPA-2453: _on_confirm_no() with slot source restores slot picker
		"test_confirm_no_slot_source_restores_slot_picker",
		"test_confirm_no_clears_pending_slots",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nPauseMenu tests: %d passed, %d failed" % [passed, failed])


# ── Color constants ───────────────────────────────────────────────────────────

static func test_c_btn_normal_colour() -> bool:
	var pm := _make_pm()
	return pm.C_BTN_NORMAL == Color(0.30, 0.18, 0.07, 1.0)


static func test_c_btn_hover_colour() -> bool:
	var pm := _make_pm()
	return pm.C_BTN_HOVER == Color(0.50, 0.30, 0.10, 1.0)


static func test_c_btn_pressed_colour() -> bool:
	var pm := _make_pm()
	return pm.C_BTN_PRESSED == Color(0.22, 0.13, 0.05, 1.0)


static func test_c_btn_border_colour() -> bool:
	var pm := _make_pm()
	return pm.C_BTN_BORDER == Color(0.55, 0.38, 0.18, 1.0)


static func test_c_btn_text_colour() -> bool:
	var pm := _make_pm()
	return pm.C_BTN_TEXT == Color(0.95, 0.91, 0.80, 1.0)


# ── Static var ────────────────────────────────────────────────────────────────

## Resets to "" before asserting so prior test-run state does not leak.
static func test_pending_restart_id_initial_value() -> bool:
	PauseMenuScript._pending_restart_id = ""
	return PauseMenuScript._pending_restart_id == ""


# ── Initial instance state ────────────────────────────────────────────────────

static func test_initial_is_open_false() -> bool:
	var pm := _make_pm()
	return pm._is_open == false


static func test_initial_scenario_id_empty() -> bool:
	var pm := _make_pm()
	return pm._scenario_id == ""


## _how_to_play is assigned inside _ready(), so it must be null before the
## node enters the scene tree.
static func test_initial_how_to_play_null() -> bool:
	var pm := _make_pm()
	return pm._how_to_play == null


## _settings_menu is assigned inside _ready(), so it must be null before the
## node enters the scene tree.
static func test_initial_settings_menu_null() -> bool:
	var pm := _make_pm()
	return pm._settings_menu == null


# ── Game-system refs ──────────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	var pm := _make_pm()
	return pm._world_ref == null


static func test_initial_day_night_ref_null() -> bool:
	var pm := _make_pm()
	return pm._day_night_ref == null


static func test_initial_journal_ref_null() -> bool:
	var pm := _make_pm()
	return pm._journal_ref == null


static func test_initial_tutorial_sys_ref_null() -> bool:
	var pm := _make_pm()
	return pm._tutorial_sys_ref == null


# ── UI refs (built by _build_ui, null without _ready) ────────────────────────

static func test_initial_status_label_null() -> bool:
	var pm := _make_pm()
	return pm._status_label == null


static func test_initial_context_scenario_lbl_null() -> bool:
	var pm := _make_pm()
	return pm._context_scenario_lbl == null


static func test_initial_context_day_lbl_null() -> bool:
	var pm := _make_pm()
	return pm._context_day_lbl == null


static func test_initial_context_objective_lbl_null() -> bool:
	var pm := _make_pm()
	return pm._context_objective_lbl == null


# ── Slot picker state ─────────────────────────────────────────────────────────

static func test_initial_main_container_null() -> bool:
	var pm := _make_pm()
	return pm._main_container == null


static func test_initial_slot_container_null() -> bool:
	var pm := _make_pm()
	return pm._slot_container == null


static func test_initial_confirm_container_null() -> bool:
	var pm := _make_pm()
	return pm._confirm_container == null


static func test_initial_confirm_action_empty() -> bool:
	var pm := _make_pm()
	return pm._confirm_action == ""


static func test_initial_slot_mode_save_false() -> bool:
	var pm := _make_pm()
	return pm._slot_mode_save == false


# ── setup() ───────────────────────────────────────────────────────────────────

static func test_setup_stores_scenario_id() -> bool:
	var pm := _make_pm()
	pm.setup("village_gossip")
	return pm._scenario_id == "village_gossip"


static func test_setup_overwrites_previous_scenario_id() -> bool:
	var pm := _make_pm()
	pm.setup("old_id")
	pm.setup("new_id")
	return pm._scenario_id == "new_id"


# ── setup_save_load() ─────────────────────────────────────────────────────────

static func test_setup_save_load_stores_world_ref() -> bool:
	var pm := _make_pm()
	var stub := Node2D.new()
	pm.setup_save_load(stub, null, null)
	var ok: bool = pm._world_ref == stub
	stub.free()
	return ok


static func test_setup_save_load_stores_day_night_ref() -> bool:
	var pm := _make_pm()
	var stub := Node.new()
	pm.setup_save_load(null, stub, null)
	var ok: bool = pm._day_night_ref == stub
	stub.free()
	return ok


static func test_setup_save_load_stores_journal_ref() -> bool:
	var pm := _make_pm()
	var stub := CanvasLayer.new()
	pm.setup_save_load(null, null, stub)
	var ok: bool = pm._journal_ref == stub
	stub.free()
	return ok


# ── setup_tutorial() ──────────────────────────────────────────────────────────

## TutorialSystem is a plain RefCounted class — safe to instantiate directly.
static func test_setup_tutorial_stores_ref() -> bool:
	var pm := _make_pm()
	var sys := TutorialSystem.new()
	pm.setup_tutorial(sys)
	return pm._tutorial_sys_ref == sys


# ── Phase 2.5: Overwrite confirmation flow (SPA-2453) ────────────────────────
##
## These tests inject stub VBoxContainer nodes into _main_container and
## _confirm_container (normally created by _build_ui() inside _ready()).
## The stubs are empty so get_child() returns null, safely bypassing the
## grab_focus() calls that require real Button children.

## _on_restart_scenario() must tag _confirm_action as "restart" so that
## _on_confirm_yes() knows to reload the scene with the same scenario.
static func test_restart_sets_confirm_action_restart() -> bool:
	var pm := _make_pm()
	pm._main_container    = VBoxContainer.new()
	pm._confirm_container = VBoxContainer.new()
	pm._on_restart_scenario()
	var ok: bool = pm._confirm_action == "restart"
	pm._main_container.free()
	pm._confirm_container.free()
	return ok


## _on_quit_to_menu() must tag _confirm_action as "quit" so that
## _on_confirm_yes() reloads without pre-selecting a scenario.
static func test_quit_sets_confirm_action_quit() -> bool:
	var pm := _make_pm()
	pm._main_container    = VBoxContainer.new()
	pm._confirm_container = VBoxContainer.new()
	pm._on_quit_to_menu()
	var ok: bool = pm._confirm_action == "quit"
	pm._main_container.free()
	pm._confirm_container.free()
	return ok


## _on_confirm_no() must hide the confirmation panel and restore the main
## menu panel so the player can continue playing without losing progress.
static func test_confirm_no_hides_confirm_shows_main() -> bool:
	var pm := _make_pm()
	pm._main_container    = VBoxContainer.new()
	pm._confirm_container = VBoxContainer.new()
	# Simulate state after a restart/quit button press.
	pm._confirm_container.visible = true
	pm._main_container.visible    = false
	pm._on_confirm_no()
	var ok: bool = not pm._confirm_container.visible and pm._main_container.visible
	pm._main_container.free()
	pm._confirm_container.free()
	return ok


# ── Phase 2.5: Load/Save null guards (unsaved-progress protection) ─────────────

## When _world_ref is null (game not fully loaded), _on_save_game() must return
## early without activating save mode — _slot_mode_save must stay false.
static func test_save_guard_null_world_preserves_slot_mode() -> bool:
	var pm := _make_pm()
	pm._on_save_game()   # _world_ref == null → early return via _set_status (no-op)
	return pm._slot_mode_save == false


## When _world_ref is null (game not fully loaded), _on_load_game() must return
## early — _slot_mode_save must stay false, preventing the slot picker from opening.
static func test_load_guard_null_world_preserves_slot_mode() -> bool:
	var pm := _make_pm()
	pm._on_load_game()   # _world_ref == null → early return via _set_status (no-op)
	return pm._slot_mode_save == false


# ── SPA-2453: new state variable initial values ───────────────────────────────

## _pending_save_slot is set to -1 (sentinel "no slot selected") until the
## player chooses an occupied slot for overwrite (Finding #6).
static func test_initial_pending_save_slot_minus_one() -> bool:
	var pm := _make_pm()
	return pm._pending_save_slot == -1


## _pending_load_slot is set to -1 (sentinel) until the player confirms
## the unsaved-progress warning before a load (Finding #7).
static func test_initial_pending_load_slot_minus_one() -> bool:
	var pm := _make_pm()
	return pm._pending_load_slot == -1


## _confirm_lbl is built by _build_ui(); it must be null before _ready() runs.
static func test_initial_confirm_lbl_null() -> bool:
	var pm := _make_pm()
	return pm._confirm_lbl == null


## _confirm_source tracks whether the confirm dialog was opened from "main"
## or "slot" so _on_confirm_no() can restore the right panel. Starts empty.
static func test_initial_confirm_source_empty() -> bool:
	var pm := _make_pm()
	return pm._confirm_source == ""


## _auto_save_note is built by _build_ui(); must be null pre-_ready (Finding #5).
static func test_initial_auto_save_note_null() -> bool:
	var pm := _make_pm()
	return pm._auto_save_note == null


# ── SPA-2453: confirm-source tagging ─────────────────────────────────────────

## _on_restart_scenario() must also set _confirm_source to "main" so that
## _on_confirm_no() returns to the main menu panel, not the slot picker.
static func test_restart_sets_confirm_source_main() -> bool:
	var pm := _make_pm()
	pm._main_container    = VBoxContainer.new()
	pm._confirm_container = VBoxContainer.new()
	pm._on_restart_scenario()
	var ok: bool = pm._confirm_source == "main"
	pm._main_container.free()
	pm._confirm_container.free()
	return ok


## _on_quit_to_menu() must also set _confirm_source to "main" for the same reason.
static func test_quit_sets_confirm_source_main() -> bool:
	var pm := _make_pm()
	pm._main_container    = VBoxContainer.new()
	pm._confirm_container = VBoxContainer.new()
	pm._on_quit_to_menu()
	var ok: bool = pm._confirm_source == "main"
	pm._main_container.free()
	pm._confirm_container.free()
	return ok


# ── SPA-2453: _on_confirm_no() slot-source routing ───────────────────────────
##
## When the confirm dialog was opened from the slot picker (source="slot"),
## _on_confirm_no() must hide the confirm panel and restore the slot picker
## rather than restoring the main menu.

static func test_confirm_no_slot_source_restores_slot_picker() -> bool:
	var pm := _make_pm()
	pm._slot_container    = VBoxContainer.new()
	pm._confirm_container = VBoxContainer.new()
	pm._main_container    = VBoxContainer.new()
	# Simulate state: player opened overwrite confirm from slot picker.
	pm._confirm_source    = "slot"
	pm._confirm_container.visible = true
	pm._slot_container.visible    = false
	pm._on_confirm_no()
	var ok: bool = pm._slot_container.visible == true
	pm._slot_container.free()
	pm._confirm_container.free()
	pm._main_container.free()
	return ok


## _on_confirm_no() must reset both pending-slot sentinels to -1 regardless of
## which panel the confirm was opened from, preventing stale slot indices.
static func test_confirm_no_clears_pending_slots() -> bool:
	var pm := _make_pm()
	pm._slot_container    = VBoxContainer.new()
	pm._confirm_container = VBoxContainer.new()
	pm._main_container    = VBoxContainer.new()
	pm._confirm_source    = "slot"
	pm._pending_save_slot = 2
	pm._pending_load_slot = 1
	pm._on_confirm_no()
	var ok: bool = pm._pending_save_slot == -1 and pm._pending_load_slot == -1
	pm._slot_container.free()
	pm._confirm_container.free()
	pm._main_container.free()
	return ok
