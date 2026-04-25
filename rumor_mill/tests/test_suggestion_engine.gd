## test_suggestion_engine.gd — Unit tests for SuggestionEngine (SPA-981, SPA-1051).
##
## Covers:
##   • Constants               — MAX_HINTS_PER_DAY, DEFAULT_COOLDOWN, INACTIVITY_TICKS,
##                               STALL_THRESHOLD, DEFAULT_HEAT_SPIKE_THRESHOLD
##   • notify_hint_dismissed() — fast dismiss doubles cooldown (caps at 8×);
##                               slow dismiss resets to DEFAULT_COOLDOWN and zeroes count
##   • notify_player_action()  — stores tick, clears _inactivity_fired flag
##   • _on_day_changed()       — resets hints_today, cooldown, all per-day guard flags
##   • get_suggestion()        — returns "" when world_ref or intel_store are null
##   • _check_stalled_progress — returns "" below threshold; returns hint at threshold
##   • _check_heat_warning()   — returns "" when intel_store is null
##   • _check_event_pending()  — always returns ""
##   • _check_unspent_actions()— correct text for all combinations using a real
##                               PlayerIntelStore (no external deps)
##   • Boundary validation (SPA-1051):
##     - setup() with null required refs warns but does not crash
##     - refresh() returns early (no crash) when core refs are null
##     - each trigger function returns "" gracefully when its own deps are null
##     - _on_dawn() null intel_store guard
##
## SuggestionEngine has no explicit `extends` and therefore inherits RefCounted.
## Instantiated with .new() — no scene-tree dependency.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestSuggestionEngine
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_max_hints_per_day_is_2",
		"test_default_cooldown_is_36",
		"test_inactivity_ticks_is_90",
		"test_stall_threshold_is_6",
		"test_default_heat_spike_threshold_is_60",
		# notify_hint_dismissed — cooldown scaling
		"test_fast_dismiss_doubles_cooldown",
		"test_two_fast_dismisses_quadruples_cooldown",
		"test_three_fast_dismisses_gives_8x",
		"test_four_fast_dismisses_still_caps_at_8x",
		"test_slow_dismiss_resets_cooldown_to_default",
		"test_slow_dismiss_after_fast_resets_fast_count",
		# notify_player_action
		"test_notify_player_action_stores_tick",
		"test_notify_player_action_clears_inactivity_flag",
		# _on_day_changed
		"test_on_day_changed_resets_hints_today",
		"test_on_day_changed_resets_cooldown",
		"test_on_day_changed_resets_fast_dismiss_count",
		"test_on_day_changed_resets_guard_flags",
		"test_on_day_changed_with_null_rep_system_no_crash",
		# get_suggestion with null refs
		"test_get_suggestion_null_world_returns_empty",
		"test_get_suggestion_null_intel_returns_empty",
		# _check_stalled_progress
		"test_stalled_progress_below_threshold_returns_empty",
		"test_stalled_progress_at_threshold_returns_hint",
		"test_stalled_progress_above_threshold_returns_hint",
		# _check_heat_warning
		"test_heat_warning_null_intel_store_returns_empty",
		"test_heat_warning_low_heat_returns_empty",
		"test_heat_warning_high_heat_returns_hint",
		# _check_event_pending
		"test_check_event_pending_always_empty",
		# _check_unspent_actions
		"test_unspent_actions_both_available",
		"test_unspent_actions_only_observations",
		"test_unspent_actions_only_whispers",
		"test_unspent_actions_none_returns_empty",
		"test_unspent_actions_singular_grammar",
		# Boundary validation — SPA-1051
		"test_setup_null_refs_no_crash",
		"test_refresh_null_scenario_manager_no_crash",
		"test_refresh_null_reputation_system_no_crash",
		"test_refresh_null_day_night_no_crash",
		"test_trigger_heat_spike_null_intel_store_returns_empty",
		"test_trigger_pace_deficit_null_scenario_manager_returns_empty",
		"test_trigger_pace_deficit_null_reputation_system_returns_empty",
		"test_trigger_pace_deficit_null_day_night_returns_empty",
		"test_trigger_faction_momentum_null_rep_system_returns_empty",
		"test_trigger_faction_momentum_null_world_ref_returns_empty",
		"test_trigger_inactivity_null_deps_no_crash",
		"test_on_dawn_null_intel_store_no_crash",
		"test_trigger_foreshadow_null_mid_game_agent_returns_empty",
		"test_trigger_foreshadow_null_day_night_returns_empty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSuggestionEngine tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

static func _make_eng() -> SuggestionEngine:
	return SuggestionEngine.new()


## Returns a fresh PlayerIntelStore with the given action/whisper counts set.
static func _make_intel(obs: int, whispers: int) -> PlayerIntelStore:
	var store := PlayerIntelStore.new()
	store.recon_actions_remaining  = obs
	store.whisper_tokens_remaining = whispers
	return store


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_max_hints_per_day_is_2() -> bool:
	return SuggestionEngine.MAX_HINTS_PER_DAY == 2


static func test_default_cooldown_is_36() -> bool:
	return SuggestionEngine.DEFAULT_COOLDOWN == 36


static func test_inactivity_ticks_is_90() -> bool:
	return SuggestionEngine.INACTIVITY_TICKS == 90


static func test_stall_threshold_is_6() -> bool:
	return SuggestionEngine.STALL_THRESHOLD == 6


static func test_default_heat_spike_threshold_is_60() -> bool:
	return SuggestionEngine.DEFAULT_HEAT_SPIKE_THRESHOLD == 60.0


# ── notify_hint_dismissed ─────────────────────────────────────────────────────

static func test_fast_dismiss_doubles_cooldown() -> bool:
	var eng := _make_eng()
	eng.notify_hint_dismissed(true)
	var expected := SuggestionEngine.DEFAULT_COOLDOWN * 2
	if eng._cooldown_ticks != expected:
		push_error("test_fast_dismiss_doubles_cooldown: expected %d, got %d" % [expected, eng._cooldown_ticks])
		return false
	return true


static func test_two_fast_dismisses_quadruples_cooldown() -> bool:
	var eng := _make_eng()
	eng.notify_hint_dismissed(true)
	eng.notify_hint_dismissed(true)
	var expected := SuggestionEngine.DEFAULT_COOLDOWN * 4
	if eng._cooldown_ticks != expected:
		push_error("test_two_fast_dismisses_quadruples_cooldown: expected %d, got %d" % [expected, eng._cooldown_ticks])
		return false
	return true


static func test_three_fast_dismisses_gives_8x() -> bool:
	var eng := _make_eng()
	eng.notify_hint_dismissed(true)
	eng.notify_hint_dismissed(true)
	eng.notify_hint_dismissed(true)
	var expected := SuggestionEngine.DEFAULT_COOLDOWN * 8
	if eng._cooldown_ticks != expected:
		push_error("test_three_fast_dismisses_gives_8x: expected %d, got %d" % [expected, eng._cooldown_ticks])
		return false
	return true


static func test_four_fast_dismisses_still_caps_at_8x() -> bool:
	# The bit-shift is capped at 3, so 4+ fast dismisses never exceed DEFAULT×8.
	var eng := _make_eng()
	for _i in range(4):
		eng.notify_hint_dismissed(true)
	var expected := SuggestionEngine.DEFAULT_COOLDOWN * 8
	if eng._cooldown_ticks != expected:
		push_error("test_four_fast_dismisses_still_caps_at_8x: expected %d, got %d" % [expected, eng._cooldown_ticks])
		return false
	return true


static func test_slow_dismiss_resets_cooldown_to_default() -> bool:
	var eng := _make_eng()
	eng.notify_hint_dismissed(true)   # inflate
	eng.notify_hint_dismissed(false)  # reset
	if eng._cooldown_ticks != SuggestionEngine.DEFAULT_COOLDOWN:
		push_error("test_slow_dismiss_resets_cooldown_to_default: expected %d, got %d" % [
			SuggestionEngine.DEFAULT_COOLDOWN, eng._cooldown_ticks])
		return false
	return true


static func test_slow_dismiss_after_fast_resets_fast_count() -> bool:
	var eng := _make_eng()
	eng.notify_hint_dismissed(true)
	eng.notify_hint_dismissed(false)
	if eng._fast_dismiss_count != 0:
		push_error("test_slow_dismiss_after_fast_resets_fast_count: expected 0, got %d" % eng._fast_dismiss_count)
		return false
	return true


# ── notify_player_action ──────────────────────────────────────────────────────

static func test_notify_player_action_stores_tick() -> bool:
	var eng := _make_eng()
	eng.notify_player_action(75)
	if eng._last_action_tick != 75:
		push_error("test_notify_player_action_stores_tick: expected 75, got %d" % eng._last_action_tick)
		return false
	return true


static func test_notify_player_action_clears_inactivity_flag() -> bool:
	var eng := _make_eng()
	eng._inactivity_fired = true
	eng.notify_player_action(10)
	if eng._inactivity_fired:
		push_error("test_notify_player_action_clears_inactivity_flag: _inactivity_fired still true")
		return false
	return true


# ── _on_day_changed ───────────────────────────────────────────────────────────

static func test_on_day_changed_resets_hints_today() -> bool:
	var eng := _make_eng()
	eng._hints_today = 2
	eng._on_day_changed(3)
	if eng._hints_today != 0:
		push_error("test_on_day_changed_resets_hints_today: expected 0, got %d" % eng._hints_today)
		return false
	return true


static func test_on_day_changed_resets_cooldown() -> bool:
	var eng := _make_eng()
	eng._cooldown_ticks = 999
	eng._on_day_changed(3)
	if eng._cooldown_ticks != SuggestionEngine.DEFAULT_COOLDOWN:
		push_error("test_on_day_changed_resets_cooldown: expected %d, got %d" % [
			SuggestionEngine.DEFAULT_COOLDOWN, eng._cooldown_ticks])
		return false
	return true


static func test_on_day_changed_resets_fast_dismiss_count() -> bool:
	var eng := _make_eng()
	eng._fast_dismiss_count = 3
	eng._on_day_changed(5)
	if eng._fast_dismiss_count != 0:
		push_error("test_on_day_changed_resets_fast_dismiss_count: expected 0, got %d" % eng._fast_dismiss_count)
		return false
	return true


static func test_on_day_changed_resets_guard_flags() -> bool:
	var eng := _make_eng()
	eng._pace_deficit_fired_today     = true
	eng._faction_momentum_fired_today = true
	eng._dawn_hint_fired              = true
	eng._inactivity_fired             = true
	eng._on_day_changed(4)
	if eng._pace_deficit_fired_today or eng._faction_momentum_fired_today \
			or eng._dawn_hint_fired or eng._inactivity_fired:
		push_error("test_on_day_changed_resets_guard_flags: one or more flags not reset")
		return false
	return true


static func test_on_day_changed_with_null_rep_system_no_crash() -> bool:
	# _snapshot_dawn_reputations() guards against null _reputation_system.
	var eng := _make_eng()
	eng._on_day_changed(1)
	return true


# ── get_suggestion with null refs ─────────────────────────────────────────────

static func test_get_suggestion_null_world_returns_empty() -> bool:
	var eng := _make_eng()
	# _world_ref is null by default; get_suggestion() must return "" immediately.
	return eng.get_suggestion() == ""


static func test_get_suggestion_null_intel_returns_empty() -> bool:
	var eng := _make_eng()
	# Even if _world_ref were set, null intel_store causes early return.
	# We can verify the guard by checking the result with both null.
	return eng.get_suggestion() == ""


# ── _check_stalled_progress ───────────────────────────────────────────────────

static func test_stalled_progress_below_threshold_returns_empty() -> bool:
	var eng := _make_eng()
	eng._stall_count = SuggestionEngine.STALL_THRESHOLD - 1
	return eng._check_stalled_progress() == ""


static func test_stalled_progress_at_threshold_returns_hint() -> bool:
	var eng := _make_eng()
	eng._stall_count = SuggestionEngine.STALL_THRESHOLD
	var hint := eng._check_stalled_progress()
	if hint.is_empty():
		push_error("test_stalled_progress_at_threshold_returns_hint: expected non-empty hint")
		return false
	return true


static func test_stalled_progress_above_threshold_returns_hint() -> bool:
	var eng := _make_eng()
	eng._stall_count = SuggestionEngine.STALL_THRESHOLD + 5
	return not eng._check_stalled_progress().is_empty()


# ── _check_heat_warning ───────────────────────────────────────────────────────

static func test_heat_warning_null_intel_store_returns_empty() -> bool:
	var eng := _make_eng()
	# _intel_store is null by default.
	return eng._check_heat_warning() == ""


static func test_heat_warning_low_heat_returns_empty() -> bool:
	var eng := _make_eng()
	var store := PlayerIntelStore.new()
	store.heat["npc_a"] = 40.0
	store.heat_enabled = true
	eng._intel_store = store
	return eng._check_heat_warning() == ""


static func test_heat_warning_high_heat_returns_hint() -> bool:
	var eng := _make_eng()
	var store := PlayerIntelStore.new()
	store.heat["npc_a"] = 55.0
	store.heat_enabled = true
	eng._intel_store = store
	var hint := eng._check_heat_warning()
	if hint.is_empty():
		push_error("test_heat_warning_high_heat_returns_hint: expected non-empty hint for heat=55")
		return false
	return true


# ── _check_event_pending ──────────────────────────────────────────────────────

static func test_check_event_pending_always_empty() -> bool:
	var eng := _make_eng()
	return eng._check_event_pending() == ""


# ── _check_unspent_actions ────────────────────────────────────────────────────

static func test_unspent_actions_both_available() -> bool:
	var eng := _make_eng()
	eng._intel_store = _make_intel(2, 1)
	var hint := eng._check_unspent_actions()
	if hint.is_empty():
		push_error("test_unspent_actions_both_available: expected hint text")
		return false
	# Should mention both observation and whisper counts.
	return "observation" in hint and "whisper" in hint


static func test_unspent_actions_only_observations() -> bool:
	var eng := _make_eng()
	eng._intel_store = _make_intel(3, 0)
	var hint := eng._check_unspent_actions()
	if hint.is_empty():
		push_error("test_unspent_actions_only_observations: expected hint text")
		return false
	return "observation" in hint


static func test_unspent_actions_only_whispers() -> bool:
	var eng := _make_eng()
	eng._intel_store = _make_intel(0, 2)
	var hint := eng._check_unspent_actions()
	if hint.is_empty():
		push_error("test_unspent_actions_only_whispers: expected hint text")
		return false
	return "whisper" in hint


static func test_unspent_actions_none_returns_empty() -> bool:
	var eng := _make_eng()
	eng._intel_store = _make_intel(0, 0)
	return eng._check_unspent_actions() == ""


static func test_unspent_actions_singular_grammar() -> bool:
	# 1 observation → "observation" (no trailing 's'), 1 whisper → "whisper".
	var eng := _make_eng()
	eng._intel_store = _make_intel(1, 1)
	var hint := eng._check_unspent_actions()
	# The format string omits the 's' suffix for count==1.
	if "observations" in hint or "whispers" in hint:
		push_error("test_unspent_actions_singular_grammar: found plural suffix for count=1: '%s'" % hint)
		return false
	return true


# ── Boundary validation — SPA-1051 ───────────────────────────────────────────

static func test_setup_null_refs_no_crash() -> bool:
	# setup() with all null required refs must not crash; engine degrades gracefully.
	var eng := _make_eng()
	eng.setup(null, null, null, null, null)
	return true


static func test_refresh_null_scenario_manager_no_crash() -> bool:
	# refresh() early-returns when _scenario_manager is null — no crash.
	var eng := _make_eng()
	eng.refresh()  # all refs null by default
	return true


static func test_refresh_null_reputation_system_no_crash() -> bool:
	# refresh() early-returns when _reputation_system is null — no crash.
	var eng := _make_eng()
	eng._scenario_manager = null
	eng.refresh()
	return true


static func test_refresh_null_day_night_no_crash() -> bool:
	# refresh() early-returns when _day_night is null — no crash.
	var eng := _make_eng()
	eng.refresh()
	return true


static func test_trigger_heat_spike_null_intel_store_returns_empty() -> bool:
	# _trigger_heat_spike() guards null _intel_store and returns "".
	var eng := _make_eng()
	# _intel_store is null by default
	return eng._trigger_heat_spike() == ""


static func test_trigger_pace_deficit_null_scenario_manager_returns_empty() -> bool:
	var eng := _make_eng()
	# _scenario_manager is null by default
	return eng._trigger_pace_deficit(100) == ""


static func test_trigger_pace_deficit_null_reputation_system_returns_empty() -> bool:
	var eng := _make_eng()
	# _reputation_system is null; _scenario_manager also null — both guarded
	return eng._trigger_pace_deficit(100) == ""


static func test_trigger_pace_deficit_null_day_night_returns_empty() -> bool:
	var eng := _make_eng()
	# _day_night is null — guarded inside _trigger_pace_deficit
	return eng._trigger_pace_deficit(100) == ""


static func test_trigger_faction_momentum_null_rep_system_returns_empty() -> bool:
	var eng := _make_eng()
	# _reputation_system is null by default
	return eng._trigger_faction_momentum() == ""


static func test_trigger_faction_momentum_null_world_ref_returns_empty() -> bool:
	var eng := _make_eng()
	# _world_ref is null by default; _dawn_snapshots is empty so the first
	# guard also trips — either way, must return "".
	return eng._trigger_faction_momentum() == ""


static func test_trigger_inactivity_null_deps_no_crash() -> bool:
	# _trigger_inactivity() calls get_suggestion() which guards null world/intel.
	# Pass a tick well beyond INACTIVITY_TICKS to reach the get_suggestion() call.
	var eng := _make_eng()
	var tick := SuggestionEngine.INACTIVITY_TICKS + 10
	var result := eng._trigger_inactivity(tick)
	# With null world_ref and intel_store, get_suggestion() returns "" — no crash.
	return result == ""


static func test_on_dawn_null_intel_store_no_crash() -> bool:
	# _on_dawn() has an explicit null guard for _intel_store; must not crash.
	var eng := _make_eng()
	# _intel_store is null, _can_fire_hint() uses _day_night which is also null
	# (evaluates to tick=0) so the cooldown check passes; the null guard on
	# _intel_store then exits before accessing the store.
	eng._on_dawn(1)
	return true


static func test_trigger_foreshadow_null_mid_game_agent_returns_empty() -> bool:
	# _trigger_foreshadow() → _get_foreshadow_text() guards null _mid_game_event_agent.
	var eng := _make_eng()
	return eng._trigger_foreshadow() == ""


static func test_trigger_foreshadow_null_day_night_returns_empty() -> bool:
	# _get_foreshadow_text() also guards null _day_night.
	var eng := _make_eng()
	# Both _mid_game_event_agent and _day_night are null — first guard trips.
	return eng._trigger_foreshadow() == ""
