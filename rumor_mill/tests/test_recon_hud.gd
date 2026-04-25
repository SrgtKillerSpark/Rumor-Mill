## test_recon_hud.gd — Unit tests for ReconHUD (SPA-1012).
##
## Covers:
##   • Constants: TOAST_DURATION, FLASH_DURATION, MILESTONE_DISPLAY_SEC,
##                MILESTONE_QUEUE_GAP_SEC, FEED_MAX_ENTRIES, PIP_SIZE
##   • Pip colour constants — all four have alpha == 1.0
##   • Heat meter colour constants — C_HEAT_LOW and C_HEAT_CRIT have alpha == 1.0
##   • Initial state: _feed_collapsed, _low_action_warned, _low_whisper_warned,
##                    _first_action_spent, _first_whisper_spent, _auto_hint_shown,
##                    _milestone_queue (empty), _last_heat_val (negative)
##   • _generate_contextual_hint() — null intel_store returns explore fallback
##   • _generate_contextual_hint() — all resources spent → dawn-wait message
##   • _generate_contextual_hint() — actions > 0, world null → action-gather hint
##   • _generate_contextual_hint() — only whispers left, world null → whisper hint
##   • _generate_contextual_hint() — hint text contains the live action count
##
## ReconHUD extends CanvasLayer. @onready vars remain null (not in scene tree),
## so _ready() is never triggered. Only data-field and pure-logic methods are tested.
## _intel_store_ref is injected manually after construction where needed.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestReconHud
extends RefCounted

const ReconHudScript := preload("res://scripts/recon_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Return a fresh ReconHUD instance (not in scene tree, _ready() skipped).
static func _make_hud() -> CanvasLayer:
	return ReconHudScript.new()


## Return a fresh PlayerIntelStore with default (full) budgets.
static func _make_store() -> PlayerIntelStore:
	return PlayerIntelStore.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_toast_duration_constant",
		"test_flash_duration_constant",
		"test_milestone_display_sec_constant",
		"test_milestone_queue_gap_sec_constant",
		"test_feed_max_entries_constant",
		"test_pip_size_constant",
		# Pip colour constants — alpha check
		"test_pip_full_action_color_alpha_one",
		"test_pip_full_whisper_color_alpha_one",
		"test_pip_empty_action_color_alpha_one",
		"test_pip_empty_whisper_color_alpha_one",
		# Heat colour constants — alpha check
		"test_heat_low_color_alpha_one",
		"test_heat_crit_color_alpha_one",
		# Initial state
		"test_initial_feed_collapsed_false",
		"test_initial_low_action_warned_false",
		"test_initial_low_whisper_warned_false",
		"test_initial_first_action_spent_false",
		"test_initial_first_whisper_spent_false",
		"test_initial_auto_hint_shown_false",
		"test_initial_milestone_queue_empty",
		"test_initial_last_heat_val_negative",
		# _generate_contextual_hint
		"test_hint_null_store_returns_fallback",
		"test_hint_all_spent_returns_dawn_message",
		"test_hint_actions_positive_world_null_returns_action_hint",
		"test_hint_whispers_only_world_null_returns_whisper_hint",
		"test_hint_message_contains_action_count",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nReconHud tests: %d passed, %d failed" % [passed, failed])


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_toast_duration_constant() -> bool:
	var hud := _make_hud()
	return is_equal_approx(hud.TOAST_DURATION, 3.5)


static func test_flash_duration_constant() -> bool:
	var hud := _make_hud()
	return is_equal_approx(hud.FLASH_DURATION, 0.3)


static func test_milestone_display_sec_constant() -> bool:
	var hud := _make_hud()
	return is_equal_approx(hud.MILESTONE_DISPLAY_SEC, 3.5)


static func test_milestone_queue_gap_sec_constant() -> bool:
	var hud := _make_hud()
	return is_equal_approx(hud.MILESTONE_QUEUE_GAP_SEC, 1.0)


static func test_feed_max_entries_constant() -> bool:
	var hud := _make_hud()
	return hud.FEED_MAX_ENTRIES == 5


static func test_pip_size_constant() -> bool:
	var hud := _make_hud()
	return hud.PIP_SIZE == Vector2(20, 20)


# ── Pip colour constants ──────────────────────────────────────────────────────

static func test_pip_full_action_color_alpha_one() -> bool:
	var hud := _make_hud()
	return is_equal_approx(hud.PIP_FULL_ACTION.a, 1.0)


static func test_pip_full_whisper_color_alpha_one() -> bool:
	var hud := _make_hud()
	return is_equal_approx(hud.PIP_FULL_WHISPER.a, 1.0)


static func test_pip_empty_action_color_alpha_one() -> bool:
	var hud := _make_hud()
	return is_equal_approx(hud.PIP_EMPTY_ACTION.a, 1.0)


static func test_pip_empty_whisper_color_alpha_one() -> bool:
	var hud := _make_hud()
	return is_equal_approx(hud.PIP_EMPTY_WHISPER.a, 1.0)


# ── Heat colour constants ─────────────────────────────────────────────────────

static func test_heat_low_color_alpha_one() -> bool:
	var hud := _make_hud()
	return is_equal_approx(hud.C_HEAT_LOW.a, 1.0)


static func test_heat_crit_color_alpha_one() -> bool:
	var hud := _make_hud()
	return is_equal_approx(hud.C_HEAT_CRIT.a, 1.0)


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_feed_collapsed_false() -> bool:
	var hud := _make_hud()
	return hud._feed_collapsed == false


static func test_initial_low_action_warned_false() -> bool:
	var hud := _make_hud()
	return hud._low_action_warned == false


static func test_initial_low_whisper_warned_false() -> bool:
	var hud := _make_hud()
	return hud._low_whisper_warned == false


static func test_initial_first_action_spent_false() -> bool:
	var hud := _make_hud()
	return hud._first_action_spent == false


static func test_initial_first_whisper_spent_false() -> bool:
	var hud := _make_hud()
	return hud._first_whisper_spent == false


static func test_initial_auto_hint_shown_false() -> bool:
	var hud := _make_hud()
	return hud._auto_hint_shown == false


static func test_initial_milestone_queue_empty() -> bool:
	var hud := _make_hud()
	return hud._milestone_queue.is_empty()


## _last_heat_val starts at -1.0 so the first heat update never triggers a delta.
static func test_initial_last_heat_val_negative() -> bool:
	var hud := _make_hud()
	return hud._last_heat_val < 0.0


# ── _generate_contextual_hint ─────────────────────────────────────────────────

## Null intel_store → explore fallback.
static func test_hint_null_store_returns_fallback() -> bool:
	var hud := _make_hud()
	# _intel_store_ref is null by default.
	var hint: String = hud._generate_contextual_hint()
	return hint.begins_with("Explore the town")


## All resources spent → dawn-wait message (Priority 1).
static func test_hint_all_spent_returns_dawn_message() -> bool:
	var hud := _make_hud()
	var store := _make_store()
	store.recon_actions_remaining  = 0
	store.whisper_tokens_remaining = 0
	hud._intel_store_ref = store
	var hint: String = hud._generate_contextual_hint()
	return "dawn" in hint.to_lower()


## actions > 0, world null → Priority 2 (whisper check) skipped → Priority 3 fires.
static func test_hint_actions_positive_world_null_returns_action_hint() -> bool:
	var hud := _make_hud()
	var store := _make_store()
	store.recon_actions_remaining  = 2
	store.whisper_tokens_remaining = 0
	hud._intel_store_ref = store
	var hint: String = hud._generate_contextual_hint()
	return "action" in hint.to_lower()


## actions == 0, whispers > 0, world null → Priority 4 returns whisper hint.
static func test_hint_whispers_only_world_null_returns_whisper_hint() -> bool:
	var hud := _make_hud()
	var store := _make_store()
	store.recon_actions_remaining  = 0
	store.whisper_tokens_remaining = 2
	hud._intel_store_ref = store
	var hint: String = hud._generate_contextual_hint()
	return "whisper" in hint.to_lower()


## With 3 actions remaining the hint message should contain the literal "3".
static func test_hint_message_contains_action_count() -> bool:
	var hud := _make_hud()
	var store := _make_store()
	store.recon_actions_remaining  = 3
	store.whisper_tokens_remaining = 0
	hud._intel_store_ref = store
	var hint: String = hud._generate_contextual_hint()
	return "3" in hint
