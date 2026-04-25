## test_npc_core.gd — Unit tests for NPC core systems (SPA-998 / SPA-1056).
##
## Covers:
##   • State query helpers: get_state_for_rumor, get_worst_rumor_state, has_evaluating_rumor
##   • Bribe mechanic:      force_believe (state flip, ticks reset, dirty flag)
##   • Credulity modifier:  apply/clamp/sync with npc_data
##   • Defense penalty:     apply, cap, tick expiry
##   • Schedule avoidance:  negative claim adds to avoid list; positive is no-op; no duplicates
##   • Illness detection:   _believes_illness scans slot claim_type + state
##   • Schedule override:   _is_schedule_overridden returns true only for SPREAD/ACT slots
##   • Rumor history:       _record_rumor_history appends correct fields
##   • Dialogue categories: _state_to_dialogue_category maps each state
##   • Time-of-day phase:   _get_time_phase returns morning/day/evening/night by hour
##   • hear_rumor:          new slot created in EVALUATING; re-hear increments count; terminal no-op; dirty flag
##   • _rebuild_npc_id_dict: all_npcs_ref setter populates id→node dict; blank id skipped
##   • _reroute_if_avoided: empty list passthrough; home passthrough; avoided match → "home"; no-match passthrough
##   • _is_chapel_frozen:   null quarantine_ref; chapel not quarantined; wrong location; chapel+quarantined → true
##   • _has_engine:         null propagation_engine_ref → false; set → true
##   • visual_state:        computed property delegates to get_worst_rumor_state()
##
## Strategy: preload npc.gd as an orphaned Node2D — @onready vars are null but
## all var-initialised data fields are ready. Only methods that operate purely on
## data fields are exercised; scene-tree calls (create_tween, add_child) are
## never triggered by these paths.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcCore
extends RefCounted

const NpcScript := preload("res://scripts/npc.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

## Build a minimal Rumor object.
static func _make_rumor(
		rumor_id: String,
		subject_id: String,
		claim_type: Rumor.ClaimType,
		intensity: int = 3,
		shelf: int = 330
) -> Rumor:
	return Rumor.create(rumor_id, subject_id, claim_type, intensity, 0.1, 0, shelf)


## Build a fresh NpcScript instance with minimal npc_data populated.
## sprite / name_label / hover_area remain null (not added to scene tree).
static func _make_npc(npc_id: String = "npc_test", faction: String = "merchant") -> Node:
	var npc = NpcScript.new()
	npc.npc_data = {"id": npc_id, "faction": faction, "credulity": 0.5}
	npc._credulity = 0.5
	npc._loyalty   = 0.5
	npc._temperament = 0.5
	return npc


## Inject a slot with the given state directly into npc.rumor_slots.
static func _inject_slot(
		npc: Node,
		rumor: Rumor,
		state: Rumor.RumorState,
		src_faction: String = "merchant"
) -> Rumor.NpcRumorSlot:
	var slot := Rumor.NpcRumorSlot.new(rumor, src_faction)
	slot.state = state
	slot.ticks_in_state = 0
	npc.rumor_slots[rumor.id] = slot
	npc._worst_state_dirty = true
	return slot


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── get_state_for_rumor ──
		"test_get_state_unaware_for_missing_rumor",
		"test_get_state_returns_slot_state",

		# ── get_worst_rumor_state ──
		"test_worst_state_empty_is_unaware",
		"test_worst_state_single_evaluating",
		"test_worst_state_believe_beats_evaluating",
		"test_worst_state_act_is_highest_priority",
		"test_worst_state_defending_beats_spread",
		"test_worst_state_cached_after_first_call",
		"test_worst_state_dirty_clears_cache",

		# ── has_evaluating_rumor ──
		"test_has_evaluating_false_when_empty",
		"test_has_evaluating_true_when_evaluating",
		"test_has_evaluating_false_when_only_believe",

		# ── force_believe ──
		"test_force_believe_returns_empty_no_evaluating",
		"test_force_believe_flips_to_believe",
		"test_force_believe_resets_ticks",
		"test_force_believe_sets_worst_state_dirty",

		# ── _apply_credulity_modifier ──
		"test_credulity_modifier_increases",
		"test_credulity_modifier_decreases",
		"test_credulity_modifier_clamps_at_ceiling",
		"test_credulity_modifier_clamps_at_floor",
		"test_credulity_modifier_updates_npc_data",
		"test_credulity_modifier_no_op_when_already_at_floor",

		# ── _apply_defense_penalty ──
		"test_defense_penalty_added",
		"test_defense_penalty_accumulates",
		"test_defense_penalty_capped_at_030",
		"test_defense_penalty_resets_timer",

		# ── _tick_defense_modifiers ──
		"test_tick_defense_modifiers_decrements_timer",
		"test_tick_defense_modifiers_removes_expired",
		"test_tick_defense_modifiers_keeps_active",

		# ── _update_schedule_avoidance ──
		"test_schedule_avoidance_negative_claim_adds_subject",
		"test_schedule_avoidance_positive_claim_no_op",
		"test_schedule_avoidance_no_duplicate",

		# ── _believes_illness ──
		"test_believes_illness_false_when_empty",
		"test_believes_illness_true_when_believe_illness",
		"test_believes_illness_true_when_spread_illness",
		"test_believes_illness_false_when_only_evaluating_illness",
		"test_believes_illness_false_when_believe_non_illness",

		# ── _is_schedule_overridden ──
		"test_schedule_override_false_when_empty",
		"test_schedule_override_true_when_spread",
		"test_schedule_override_true_when_act",
		"test_schedule_override_false_when_only_believe",

		# ── _record_rumor_history ──
		"test_record_history_appends_entry",
		"test_record_history_fields_correct",

		# ── _state_to_dialogue_category ──
		"test_dialogue_cat_evaluating",
		"test_dialogue_cat_believe",
		"test_dialogue_cat_reject",
		"test_dialogue_cat_spread",
		"test_dialogue_cat_act",
		"test_dialogue_cat_defending",
		"test_dialogue_cat_unaware_empty",
		"test_dialogue_cat_expired_empty",
		"test_dialogue_cat_contradicted_empty",

		# ── _get_time_phase ──
		"test_time_phase_morning_at_5",
		"test_time_phase_morning_at_11",
		"test_time_phase_day_at_12",
		"test_time_phase_day_at_16",
		"test_time_phase_evening_at_17",
		"test_time_phase_evening_at_21",
		"test_time_phase_night_at_22",
		"test_time_phase_night_at_0",
		"test_time_phase_night_at_4",

		# ── hear_rumor ──
		"test_hear_rumor_creates_evaluating_slot",
		"test_hear_rumor_new_sets_worst_state_dirty",
		"test_hear_rumor_re_hear_increments_count",
		"test_hear_rumor_terminal_believe_no_op",
		"test_hear_rumor_terminal_reject_no_op",
		"test_hear_rumor_terminal_spread_no_op",
		"test_hear_rumor_terminal_act_no_op",
		"test_hear_rumor_terminal_contradicted_no_op",
		"test_hear_rumor_terminal_expired_no_op",

		# ── _rebuild_npc_id_dict (via all_npcs_ref setter) ──
		"test_rebuild_dict_populates_from_all_npcs_ref",
		"test_rebuild_dict_skips_blank_id",
		"test_rebuild_dict_clears_stale_entries",

		# ── _reroute_if_avoided ──
		"test_reroute_empty_avoided_returns_same",
		"test_reroute_home_arg_always_returns_home",
		"test_reroute_returns_home_when_avoided_npc_at_location",
		"test_reroute_no_match_returns_same",

		# ── _is_chapel_frozen ──
		"test_chapel_frozen_false_when_no_quarantine_ref",
		"test_chapel_frozen_false_when_not_quarantined",
		"test_chapel_frozen_false_when_quarantined_wrong_location",
		"test_chapel_frozen_true_when_quarantined_at_chapel",

		# ── _has_engine ──
		"test_has_engine_false_when_null",
		"test_has_engine_true_when_set",

		# ── visual_state ──
		"test_visual_state_unaware_when_empty",
		"test_visual_state_matches_worst_state",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# get_state_for_rumor
# ══════════════════════════════════════════════════════════════════════════════

func test_get_state_unaware_for_missing_rumor() -> bool:
	var npc := _make_npc()
	var state := npc.get_state_for_rumor("nonexistent_id")
	npc.free()
	return state == Rumor.RumorState.UNAWARE


func test_get_state_returns_slot_state() -> bool:
	var npc  := _make_npc()
	var r    := _make_rumor("r1", "npc_subj", Rumor.ClaimType.ACCUSATION)
	_inject_slot(npc, r, Rumor.RumorState.BELIEVE)
	var state := npc.get_state_for_rumor("r1")
	npc.free()
	return state == Rumor.RumorState.BELIEVE


# ══════════════════════════════════════════════════════════════════════════════
# get_worst_rumor_state
# ══════════════════════════════════════════════════════════════════════════════

func test_worst_state_empty_is_unaware() -> bool:
	var npc   := _make_npc()
	var worst := npc.get_worst_rumor_state()
	npc.free()
	return worst == Rumor.RumorState.UNAWARE


func test_worst_state_single_evaluating() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.SCANDAL), Rumor.RumorState.EVALUATING)
	var worst := npc.get_worst_rumor_state()
	npc.free()
	return worst == Rumor.RumorState.EVALUATING


func test_worst_state_believe_beats_evaluating() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.SCANDAL), Rumor.RumorState.EVALUATING)
	_inject_slot(npc, _make_rumor("r2", "s", Rumor.ClaimType.ACCUSATION), Rumor.RumorState.BELIEVE)
	var worst := npc.get_worst_rumor_state()
	npc.free()
	return worst == Rumor.RumorState.BELIEVE


func test_worst_state_act_is_highest_priority() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.SCANDAL), Rumor.RumorState.SPREAD)
	_inject_slot(npc, _make_rumor("r2", "s", Rumor.ClaimType.ACCUSATION), Rumor.RumorState.ACT)
	_inject_slot(npc, _make_rumor("r3", "s", Rumor.ClaimType.HERESY), Rumor.RumorState.BELIEVE)
	var worst := npc.get_worst_rumor_state()
	npc.free()
	return worst == Rumor.RumorState.ACT


func test_worst_state_defending_beats_spread() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.ACCUSATION), Rumor.RumorState.SPREAD)
	npc._is_defending = true
	npc._worst_state_dirty = true
	var worst := npc.get_worst_rumor_state()
	npc.free()
	return worst == Rumor.RumorState.DEFENDING


func test_worst_state_cached_after_first_call() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.PRAISE), Rumor.RumorState.BELIEVE)
	var first  := npc.get_worst_rumor_state()
	var second := npc.get_worst_rumor_state()
	npc.free()
	return first == second and first == Rumor.RumorState.BELIEVE


func test_worst_state_dirty_clears_cache() -> bool:
	var npc := _make_npc()
	var r1  := _make_rumor("r1", "s", Rumor.ClaimType.ACCUSATION)
	var slot := _inject_slot(npc, r1, Rumor.RumorState.EVALUATING)
	var _first := npc.get_worst_rumor_state()  # caches EVALUATING
	# Mutate state and mark dirty — next call must recompute.
	slot.state = Rumor.RumorState.BELIEVE
	npc._worst_state_dirty = true
	var second := npc.get_worst_rumor_state()
	npc.free()
	return second == Rumor.RumorState.BELIEVE


# ══════════════════════════════════════════════════════════════════════════════
# has_evaluating_rumor
# ══════════════════════════════════════════════════════════════════════════════

func test_has_evaluating_false_when_empty() -> bool:
	var npc := _make_npc()
	var result := npc.has_evaluating_rumor()
	npc.free()
	return result == false


func test_has_evaluating_true_when_evaluating() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.SCANDAL), Rumor.RumorState.EVALUATING)
	var result := npc.has_evaluating_rumor()
	npc.free()
	return result == true


func test_has_evaluating_false_when_only_believe() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.ACCUSATION), Rumor.RumorState.BELIEVE)
	var result := npc.has_evaluating_rumor()
	npc.free()
	return result == false


# ══════════════════════════════════════════════════════════════════════════════
# force_believe
# ══════════════════════════════════════════════════════════════════════════════

func test_force_believe_returns_empty_no_evaluating() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.ACCUSATION), Rumor.RumorState.BELIEVE)
	var result := npc.force_believe()
	npc.free()
	return result == ""


func test_force_believe_flips_to_believe() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.SCANDAL), Rumor.RumorState.EVALUATING)
	var rid := npc.force_believe()
	var state := npc.get_state_for_rumor("r1")
	npc.free()
	return rid == "r1" and state == Rumor.RumorState.BELIEVE


func test_force_believe_resets_ticks() -> bool:
	var npc  := _make_npc()
	var slot := _inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.HERESY), Rumor.RumorState.EVALUATING)
	slot.ticks_in_state = 7
	npc.force_believe()
	var ticks := slot.ticks_in_state
	npc.free()
	return ticks == 0


func test_force_believe_sets_worst_state_dirty() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.ACCUSATION), Rumor.RumorState.EVALUATING)
	# Clear dirty flag first so we can detect it being set.
	var _w := npc.get_worst_rumor_state()  # caches result, clears dirty
	npc.force_believe()
	var dirty := npc._worst_state_dirty
	npc.free()
	return dirty == true


# ══════════════════════════════════════════════════════════════════════════════
# _apply_credulity_modifier
# ══════════════════════════════════════════════════════════════════════════════

func test_credulity_modifier_increases() -> bool:
	var npc := _make_npc()
	npc._credulity = 0.5
	npc._credulity_modifier = 0.0
	npc._apply_credulity_modifier(0.05)
	var ok := absf(npc._credulity - 0.55) < 0.0001
	npc.free()
	return ok


func test_credulity_modifier_decreases() -> bool:
	var npc := _make_npc()
	npc._credulity = 0.5
	npc._credulity_modifier = 0.0
	npc._apply_credulity_modifier(-0.05)
	var ok := absf(npc._credulity - 0.45) < 0.0001
	npc.free()
	return ok


func test_credulity_modifier_clamps_at_ceiling() -> bool:
	var npc := _make_npc()
	npc._credulity = 0.5
	npc._credulity_modifier = 0.14  # just below ceiling of 0.15
	npc._apply_credulity_modifier(0.10)  # would push to 0.24 — should stop at 0.15
	var ok := npc._credulity_modifier <= 0.15 + 0.0001
	npc.free()
	return ok


func test_credulity_modifier_clamps_at_floor() -> bool:
	var npc := _make_npc()
	npc._credulity = 0.5
	npc._credulity_modifier = -0.14  # just above floor of -0.15
	npc._apply_credulity_modifier(-0.10)  # would push to -0.24 — should stop at -0.15
	var ok := npc._credulity_modifier >= -0.15 - 0.0001
	npc.free()
	return ok


func test_credulity_modifier_updates_npc_data() -> bool:
	var npc := _make_npc()
	npc._credulity = 0.5
	npc._credulity_modifier = 0.0
	npc.npc_data = {"id": "npc_test", "faction": "merchant", "credulity": 0.5}
	npc._apply_credulity_modifier(0.10)
	var stored: float = float(npc.npc_data.get("credulity", -1.0))
	var ok := absf(stored - 0.60) < 0.0001
	npc.free()
	return ok


func test_credulity_modifier_no_op_when_already_at_floor() -> bool:
	var npc := _make_npc()
	npc._credulity = 0.35
	npc._credulity_modifier = -0.15  # already at floor
	var credulity_before := npc._credulity
	npc._apply_credulity_modifier(-0.05)  # further reduction is clamped to 0 actual delta
	var ok := absf(npc._credulity - credulity_before) < 0.0001
	npc.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _apply_defense_penalty
# ══════════════════════════════════════════════════════════════════════════════

func test_defense_penalty_added() -> bool:
	var npc := _make_npc()
	npc._apply_defense_penalty("subj_1", 0.15)
	var pen: float = npc._defense_modifiers.get("subj_1", 0.0)
	npc.free()
	return absf(pen - 0.15) < 0.0001


func test_defense_penalty_accumulates() -> bool:
	var npc := _make_npc()
	npc._apply_defense_penalty("subj_1", 0.10)
	npc._apply_defense_penalty("subj_1", 0.10)
	var pen: float = npc._defense_modifiers.get("subj_1", 0.0)
	npc.free()
	return absf(pen - 0.20) < 0.0001


func test_defense_penalty_capped_at_030() -> bool:
	var npc := _make_npc()
	npc._apply_defense_penalty("subj_1", 0.15)
	npc._apply_defense_penalty("subj_1", 0.15)
	npc._apply_defense_penalty("subj_1", 0.15)  # would push past 0.30 cap
	var pen: float = npc._defense_modifiers.get("subj_1", 0.0)
	npc.free()
	return pen <= 0.30 + 0.0001


func test_defense_penalty_resets_timer() -> bool:
	var npc := _make_npc()
	npc._apply_defense_penalty("subj_1", 0.15)
	var ticks: int = npc._defense_modifier_ticks.get("subj_1", 0)
	npc.free()
	return ticks == 3  # _DEFENSE_MOD_DURATION constant


# ══════════════════════════════════════════════════════════════════════════════
# _tick_defense_modifiers
# ══════════════════════════════════════════════════════════════════════════════

func test_tick_defense_modifiers_decrements_timer() -> bool:
	var npc := _make_npc()
	npc._apply_defense_penalty("subj_1", 0.15)  # sets timer to 3
	npc._tick_defense_modifiers()
	var ticks: int = npc._defense_modifier_ticks.get("subj_1", -1)
	npc.free()
	return ticks == 2


func test_tick_defense_modifiers_removes_expired() -> bool:
	var npc := _make_npc()
	npc._apply_defense_penalty("subj_1", 0.15)
	npc._defense_modifier_ticks["subj_1"] = 1  # force it to expire next tick
	npc._tick_defense_modifiers()
	var still_present := npc._defense_modifiers.has("subj_1")
	npc.free()
	return still_present == false


func test_tick_defense_modifiers_keeps_active() -> bool:
	var npc := _make_npc()
	npc._apply_defense_penalty("subj_1", 0.15)
	npc._defense_modifier_ticks["subj_1"] = 3
	npc._tick_defense_modifiers()
	var still_present := npc._defense_modifiers.has("subj_1")
	npc.free()
	return still_present == true


# ══════════════════════════════════════════════════════════════════════════════
# _update_schedule_avoidance
# ══════════════════════════════════════════════════════════════════════════════

func test_schedule_avoidance_negative_claim_adds_subject() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r1", "villain_npc", Rumor.ClaimType.ACCUSATION)
	npc._update_schedule_avoidance(r)
	var added := npc._avoided_subject_ids.has("villain_npc")
	npc.free()
	return added == true


func test_schedule_avoidance_positive_claim_no_op() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r1", "hero_npc", Rumor.ClaimType.PRAISE)
	npc._update_schedule_avoidance(r)
	var added := npc._avoided_subject_ids.has("hero_npc")
	npc.free()
	return added == false


func test_schedule_avoidance_no_duplicate() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r1", "villain_npc", Rumor.ClaimType.SCANDAL)
	npc._update_schedule_avoidance(r)
	npc._update_schedule_avoidance(r)  # second call should be a no-op
	var count := npc._avoided_subject_ids.count("villain_npc")
	npc.free()
	return count == 1


# ══════════════════════════════════════════════════════════════════════════════
# _believes_illness
# ══════════════════════════════════════════════════════════════════════════════

func test_believes_illness_false_when_empty() -> bool:
	var npc := _make_npc()
	var result := npc._believes_illness()
	npc.free()
	return result == false


func test_believes_illness_true_when_believe_illness() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.ILLNESS), Rumor.RumorState.BELIEVE)
	var result := npc._believes_illness()
	npc.free()
	return result == true


func test_believes_illness_true_when_spread_illness() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.ILLNESS), Rumor.RumorState.SPREAD)
	var result := npc._believes_illness()
	npc.free()
	return result == true


func test_believes_illness_false_when_only_evaluating_illness() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.ILLNESS), Rumor.RumorState.EVALUATING)
	var result := npc._believes_illness()
	npc.free()
	return result == false


func test_believes_illness_false_when_believe_non_illness() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.ACCUSATION), Rumor.RumorState.BELIEVE)
	var result := npc._believes_illness()
	npc.free()
	return result == false


# ══════════════════════════════════════════════════════════════════════════════
# _is_schedule_overridden
# ══════════════════════════════════════════════════════════════════════════════

func test_schedule_override_false_when_empty() -> bool:
	var npc := _make_npc()
	var result := npc._is_schedule_overridden()
	npc.free()
	return result == false


func test_schedule_override_true_when_spread() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.SCANDAL), Rumor.RumorState.SPREAD)
	var result := npc._is_schedule_overridden()
	npc.free()
	return result == true


func test_schedule_override_true_when_act() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.ACCUSATION), Rumor.RumorState.ACT)
	var result := npc._is_schedule_overridden()
	npc.free()
	return result == true


func test_schedule_override_false_when_only_believe() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.HERESY), Rumor.RumorState.BELIEVE)
	var result := npc._is_schedule_overridden()
	npc.free()
	return result == false


# ══════════════════════════════════════════════════════════════════════════════
# _record_rumor_history
# ══════════════════════════════════════════════════════════════════════════════

func test_record_history_appends_entry() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r1", "subj_npc", Rumor.ClaimType.ACCUSATION)
	npc._record_rumor_history(r, "subj_npc", "believed", 42)
	var count := npc.rumor_history.size()
	npc.free()
	return count == 1


func test_record_history_fields_correct() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r77", "target_npc", Rumor.ClaimType.SCANDAL)
	npc._record_rumor_history(r, "target_npc", "act", 99)
	var entry: Dictionary = npc.rumor_history[0]
	npc.free()
	return entry.get("rumor_id")   == "r77"       \
		and entry.get("subject_id") == "target_npc" \
		and entry.get("claim_type") == Rumor.ClaimType.SCANDAL \
		and entry.get("outcome")    == "act"        \
		and entry.get("tick")       == 99


# ══════════════════════════════════════════════════════════════════════════════
# _state_to_dialogue_category
# ══════════════════════════════════════════════════════════════════════════════

func test_dialogue_cat_evaluating() -> bool:
	var npc := _make_npc()
	var cat := npc._state_to_dialogue_category(Rumor.RumorState.EVALUATING)
	npc.free()
	return cat == "hear"


func test_dialogue_cat_believe() -> bool:
	var npc := _make_npc()
	var cat := npc._state_to_dialogue_category(Rumor.RumorState.BELIEVE)
	npc.free()
	return cat == "believe"


func test_dialogue_cat_reject() -> bool:
	var npc := _make_npc()
	var cat := npc._state_to_dialogue_category(Rumor.RumorState.REJECT)
	npc.free()
	return cat == "reject"


func test_dialogue_cat_spread() -> bool:
	var npc := _make_npc()
	var cat := npc._state_to_dialogue_category(Rumor.RumorState.SPREAD)
	npc.free()
	return cat == "spread"


func test_dialogue_cat_act() -> bool:
	var npc := _make_npc()
	var cat := npc._state_to_dialogue_category(Rumor.RumorState.ACT)
	npc.free()
	return cat == "act"


func test_dialogue_cat_defending() -> bool:
	var npc := _make_npc()
	var cat := npc._state_to_dialogue_category(Rumor.RumorState.DEFENDING)
	npc.free()
	return cat == "defending"


func test_dialogue_cat_unaware_empty() -> bool:
	var npc := _make_npc()
	var cat := npc._state_to_dialogue_category(Rumor.RumorState.UNAWARE)
	npc.free()
	return cat == ""


func test_dialogue_cat_expired_empty() -> bool:
	var npc := _make_npc()
	var cat := npc._state_to_dialogue_category(Rumor.RumorState.EXPIRED)
	npc.free()
	return cat == ""


func test_dialogue_cat_contradicted_empty() -> bool:
	var npc := _make_npc()
	var cat := npc._state_to_dialogue_category(Rumor.RumorState.CONTRADICTED)
	npc.free()
	return cat == ""


# ══════════════════════════════════════════════════════════════════════════════
# _get_time_phase
# ══════════════════════════════════════════════════════════════════════════════

func test_time_phase_morning_at_5() -> bool:
	var npc := _make_npc()
	npc._current_hour = 5
	var phase := npc._get_time_phase()
	npc.free()
	return phase == "morning"


func test_time_phase_morning_at_11() -> bool:
	var npc := _make_npc()
	npc._current_hour = 11
	var phase := npc._get_time_phase()
	npc.free()
	return phase == "morning"


func test_time_phase_day_at_12() -> bool:
	var npc := _make_npc()
	npc._current_hour = 12
	var phase := npc._get_time_phase()
	npc.free()
	return phase == "day"


func test_time_phase_day_at_16() -> bool:
	var npc := _make_npc()
	npc._current_hour = 16
	var phase := npc._get_time_phase()
	npc.free()
	return phase == "day"


func test_time_phase_evening_at_17() -> bool:
	var npc := _make_npc()
	npc._current_hour = 17
	var phase := npc._get_time_phase()
	npc.free()
	return phase == "evening"


func test_time_phase_evening_at_21() -> bool:
	var npc := _make_npc()
	npc._current_hour = 21
	var phase := npc._get_time_phase()
	npc.free()
	return phase == "evening"


func test_time_phase_night_at_22() -> bool:
	var npc := _make_npc()
	npc._current_hour = 22
	var phase := npc._get_time_phase()
	npc.free()
	return phase == "night"


func test_time_phase_night_at_0() -> bool:
	var npc := _make_npc()
	npc._current_hour = 0
	var phase := npc._get_time_phase()
	npc.free()
	return phase == "night"


func test_time_phase_night_at_4() -> bool:
	var npc := _make_npc()
	npc._current_hour = 4
	var phase := npc._get_time_phase()
	npc.free()
	return phase == "night"


# ══════════════════════════════════════════════════════════════════════════════
# hear_rumor
# ══════════════════════════════════════════════════════════════════════════════

## Hearing a new rumor inserts an EVALUATING slot into rumor_slots.
func test_hear_rumor_creates_evaluating_slot() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r1", "subj", Rumor.ClaimType.ACCUSATION)
	npc.hear_rumor(r, "merchant")
	var state := npc.get_state_for_rumor("r1")
	npc.free()
	return state == Rumor.RumorState.EVALUATING


## Hearing a new rumor marks _worst_state_dirty so the next cache read recomputes.
func test_hear_rumor_new_sets_worst_state_dirty() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r1", "subj", Rumor.ClaimType.SCANDAL)
	# Clear dirty flag first.
	var _w := npc.get_worst_rumor_state()
	npc.hear_rumor(r, "merchant")
	var dirty := npc._worst_state_dirty
	npc.free()
	return dirty == true


## Hearing the same rumor when still EVALUATING increments heard_from_count.
func test_hear_rumor_re_hear_increments_count() -> bool:
	var npc  := _make_npc()
	var r    := _make_rumor("r1", "subj", Rumor.ClaimType.HERESY)
	npc.hear_rumor(r, "merchant")  # first hear — creates slot, count = 0
	var slot: Rumor.NpcRumorSlot = npc.rumor_slots["r1"]
	var count_before := slot.heard_from_count
	npc.hear_rumor(r, "noble")    # second hear — increments count
	var count_after := slot.heard_from_count
	npc.free()
	return count_after == count_before + 1


## Hearing a rumor whose slot is already in BELIEVE is a no-op (slot unchanged).
func test_hear_rumor_terminal_believe_no_op() -> bool:
	var npc  := _make_npc()
	var r    := _make_rumor("r1", "subj", Rumor.ClaimType.ACCUSATION)
	var slot := _inject_slot(npc, r, Rumor.RumorState.BELIEVE)
	var count_before := slot.heard_from_count
	npc.hear_rumor(r, "merchant")
	var ok := slot.state == Rumor.RumorState.BELIEVE and slot.heard_from_count == count_before
	npc.free()
	return ok


## REJECT is also a terminal state — re-hearing is a no-op.
func test_hear_rumor_terminal_reject_no_op() -> bool:
	var npc  := _make_npc()
	var r    := _make_rumor("r1", "subj", Rumor.ClaimType.SCANDAL)
	_inject_slot(npc, r, Rumor.RumorState.REJECT)
	npc.hear_rumor(r, "merchant")
	var ok := npc.get_state_for_rumor("r1") == Rumor.RumorState.REJECT
	npc.free()
	return ok


## SPREAD is terminal — re-hearing is a no-op.
func test_hear_rumor_terminal_spread_no_op() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r1", "subj", Rumor.ClaimType.PRAISE)
	_inject_slot(npc, r, Rumor.RumorState.SPREAD)
	npc.hear_rumor(r, "merchant")
	var ok := npc.get_state_for_rumor("r1") == Rumor.RumorState.SPREAD
	npc.free()
	return ok


## ACT is terminal — re-hearing is a no-op.
func test_hear_rumor_terminal_act_no_op() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r1", "subj", Rumor.ClaimType.HERESY)
	_inject_slot(npc, r, Rumor.RumorState.ACT)
	npc.hear_rumor(r, "guild")
	var ok := npc.get_state_for_rumor("r1") == Rumor.RumorState.ACT
	npc.free()
	return ok


## CONTRADICTED is terminal — re-hearing is a no-op.
func test_hear_rumor_terminal_contradicted_no_op() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r1", "subj", Rumor.ClaimType.ACCUSATION)
	_inject_slot(npc, r, Rumor.RumorState.CONTRADICTED)
	npc.hear_rumor(r, "merchant")
	var ok := npc.get_state_for_rumor("r1") == Rumor.RumorState.CONTRADICTED
	npc.free()
	return ok


## EXPIRED is terminal — re-hearing is a no-op.
func test_hear_rumor_terminal_expired_no_op() -> bool:
	var npc := _make_npc()
	var r   := _make_rumor("r1", "subj", Rumor.ClaimType.SCANDAL)
	_inject_slot(npc, r, Rumor.RumorState.EXPIRED)
	npc.hear_rumor(r, "noble")
	var ok := npc.get_state_for_rumor("r1") == Rumor.RumorState.EXPIRED
	npc.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _rebuild_npc_id_dict  (exercised via the all_npcs_ref setter)
# ══════════════════════════════════════════════════════════════════════════════

## Assigning all_npcs_ref with peers that have ids populates _npc_id_dict.
func test_rebuild_dict_populates_from_all_npcs_ref() -> bool:
	var npc   := _make_npc("self_npc")
	var peer1 := _make_npc("peer_a")
	var peer2 := _make_npc("peer_b")
	npc.all_npcs_ref = [peer1, peer2]
	var ok := npc._npc_id_dict.has("peer_a") and npc._npc_id_dict.has("peer_b") \
		and npc._npc_id_dict["peer_a"] == peer1 and npc._npc_id_dict["peer_b"] == peer2
	peer1.free()
	peer2.free()
	npc.free()
	return ok


## Peers whose npc_data has no "id" key (or blank id) are not inserted.
func test_rebuild_dict_skips_blank_id() -> bool:
	var npc  := _make_npc()
	var peer := NpcScript.new()
	peer.npc_data = {}  # no "id" key → blank
	npc.all_npcs_ref = [peer]
	var ok := npc._npc_id_dict.is_empty()
	peer.free()
	npc.free()
	return ok


## Re-assigning all_npcs_ref clears stale entries from a previous assignment.
func test_rebuild_dict_clears_stale_entries() -> bool:
	var npc   := _make_npc()
	var peer1 := _make_npc("old_peer")
	npc.all_npcs_ref = [peer1]
	var peer2 := _make_npc("new_peer")
	npc.all_npcs_ref = [peer2]  # replaces — old_peer should be gone
	var ok := not npc._npc_id_dict.has("old_peer") and npc._npc_id_dict.has("new_peer")
	peer1.free()
	peer2.free()
	npc.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _reroute_if_avoided
# ══════════════════════════════════════════════════════════════════════════════

## Empty avoid list — the original location is returned unchanged.
func test_reroute_empty_avoided_returns_same() -> bool:
	var npc := _make_npc()
	var result := npc._reroute_if_avoided("market")
	npc.free()
	return result == "market"


## When the requested location is "home" it is always returned as-is,
## even if there are avoided subjects.
func test_reroute_home_arg_always_returns_home() -> bool:
	var npc  := _make_npc()
	var peer := _make_npc("villain")
	peer.work_location = "home"
	npc.all_npcs_ref = [peer]
	npc._avoided_subject_ids.append("villain")
	var result := npc._reroute_if_avoided("home")
	peer.free()
	npc.free()
	return result == "home"


## If an avoided NPC's work_location matches the destination, return "home".
func test_reroute_returns_home_when_avoided_npc_at_location() -> bool:
	var npc  := _make_npc()
	var peer := _make_npc("villain")
	peer.work_location = "market"
	npc.all_npcs_ref = [peer]
	npc._avoided_subject_ids.append("villain")
	var result := npc._reroute_if_avoided("market")
	peer.free()
	npc.free()
	return result == "home"


## Avoided subject works somewhere else — no reroute; original location returned.
func test_reroute_no_match_returns_same() -> bool:
	var npc  := _make_npc()
	var peer := _make_npc("villain")
	peer.work_location = "tavern"
	npc.all_npcs_ref = [peer]
	npc._avoided_subject_ids.append("villain")
	var result := npc._reroute_if_avoided("market")
	peer.free()
	npc.free()
	return result == "market"


# ══════════════════════════════════════════════════════════════════════════════
# _is_chapel_frozen
# ══════════════════════════════════════════════════════════════════════════════

## No quarantine reference → always false.
func test_chapel_frozen_false_when_no_quarantine_ref() -> bool:
	var npc    := _make_npc()
	npc.current_location_code = "chapel"
	var result := npc._is_chapel_frozen()
	npc.free()
	return result == false


## Quarantine system present but chapel not quarantined → false.
func test_chapel_frozen_false_when_not_quarantined() -> bool:
	var npc := _make_npc()
	npc.quarantine_ref         = QuarantineSystem.new()
	npc.current_location_code  = "chapel"
	var result := npc._is_chapel_frozen()
	npc.free()
	return result == false


## Chapel is quarantined but NPC is at a different location → false.
func test_chapel_frozen_false_when_quarantined_wrong_location() -> bool:
	var npc  := _make_npc()
	var qs   := QuarantineSystem.new()
	qs._quarantined["chapel"] = 9999  # simulate active quarantine
	npc.quarantine_ref        = qs
	npc.current_location_code = "market"
	var result := npc._is_chapel_frozen()
	npc.free()
	return result == false


## Chapel is quarantined AND the NPC is at the chapel → true.
func test_chapel_frozen_true_when_quarantined_at_chapel() -> bool:
	var npc  := _make_npc()
	var qs   := QuarantineSystem.new()
	qs._quarantined["chapel"] = 9999  # simulate active quarantine
	npc.quarantine_ref        = qs
	npc.current_location_code = "chapel"
	var result := npc._is_chapel_frozen()
	npc.free()
	return result == true


# ══════════════════════════════════════════════════════════════════════════════
# _has_engine
# ══════════════════════════════════════════════════════════════════════════════

## propagation_engine_ref defaults to null → _has_engine() is false.
func test_has_engine_false_when_null() -> bool:
	var npc := _make_npc()
	var ok  := npc._has_engine() == false
	npc.free()
	return ok


## Assigning a PropagationEngine instance → _has_engine() is true.
func test_has_engine_true_when_set() -> bool:
	var npc    := _make_npc()
	npc.propagation_engine_ref = PropagationEngine.new()
	var ok := npc._has_engine() == true
	npc.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# visual_state  (computed property — delegates to get_worst_rumor_state)
# ══════════════════════════════════════════════════════════════════════════════

## With no slots, visual_state equals UNAWARE (same as get_worst_rumor_state).
func test_visual_state_unaware_when_empty() -> bool:
	var npc := _make_npc()
	var ok  := npc.visual_state == Rumor.RumorState.UNAWARE
	npc.free()
	return ok


## With a BELIEVE slot, visual_state matches get_worst_rumor_state().
func test_visual_state_matches_worst_state() -> bool:
	var npc := _make_npc()
	_inject_slot(npc, _make_rumor("r1", "s", Rumor.ClaimType.ACCUSATION), Rumor.RumorState.BELIEVE)
	var ok := npc.visual_state == npc.get_worst_rumor_state()
	npc.free()
	return ok
