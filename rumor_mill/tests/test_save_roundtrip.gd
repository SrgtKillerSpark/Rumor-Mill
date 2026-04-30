## test_save_roundtrip.gd — Save/load serialization round-trip tests (SPA-1090).
##
## Verifies that every agent type and scenario-specific state field survives a
## serialize → JSON stringify → JSON parse → restore cycle without data loss.
##
## Coverage:
##   • RivalAgent         — all fields incl. _disruption_days_remaining (SPA-1090 fix)
##   • InquisitorAgent    — all fields incl. shielded_npc_ids set
##   • IllnessEscalation  — all fields
##   • S4FactionShift     — all three phase flags
##   • GuildDefenseAgent  — all fields
##   • ScenarioManager    — all S1–S6 state fields incl. S5/S6 specifics
##   • Empty-agent guard  — empty dict restores without touching agent state (S1/S2/S5)
##   • Mid-day save       — tick > 0 within a day survives correctly
##   • Disruption-active  — _disruption_days_remaining > 0 round-trip (bug SPA-1090)
##
## All tests use synthetic in-memory data — no live game scene required.

class_name TestSaveRoundtrip
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_rival_agent_all_fields_round_trip",
		"test_rival_agent_disruption_active_round_trip",
		"test_rival_agent_empty_dict_skips_restore",
		"test_inquisitor_agent_shielded_ids_round_trip",
		"test_inquisitor_agent_empty_shielded_ids",
		"test_illness_escalation_agent_round_trip",
		"test_s4_faction_shift_all_phases_fired_round_trip",
		"test_s4_faction_shift_partial_phases_round_trip",
		"test_guild_defense_agent_round_trip",
		"test_guild_defense_agent_empty_dict_skips_restore",
		"test_scenario_manager_s1_state_round_trip",
		"test_scenario_manager_s3_calder_scores_round_trip",
		"test_scenario_manager_s5_endorsement_round_trip",
		"test_scenario_manager_s6_state_round_trip",
		"test_scenario_manager_s2_maren_fields_round_trip",
		"test_scenario_manager_s1_first_blood_round_trip",
		"test_scenario_manager_heat_ceiling_negative_default",
		"test_mid_day_tick_and_day_round_trip",
		"test_all_scenario_ids_serialize_gracefully",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSave round-trip tests: %d passed, %d failed" % [passed, failed])


# ── helpers ───────────────────────────────────────────────────────────────────

## JSON round-trip a Dictionary: stringify then parse. Returns {} on parse error.
static func _json_rt(d: Dictionary) -> Dictionary:
	var text := JSON.stringify(d)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("test_save_roundtrip: JSON round-trip produced non-Dictionary result")
		return {}
	return parsed


# ── RivalAgent ────────────────────────────────────────────────────────────────

## All RivalAgent fields, including the previously-missing _disruption_days_remaining,
## survive a serialize → JSON → restore round-trip intact.
static func test_rival_agent_all_fields_round_trip() -> bool:
	var ra := RivalAgent.new()
	ra._active                    = true
	ra._last_seed_day             = 7
	ra._alternate_flag            = true
	ra.cooldown_offset            = -1
	ra.disrupt_charges_remaining  = 2
	ra._disruption_days_remaining = 0   # not disrupted

	var serialized := SaveManager._serialize_rival_agent(ra)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var ra2 := RivalAgent.new()
	SaveManager._restore_rival_agent(ra2, parsed)

	return (ra2._active                    == ra._active
		and ra2._last_seed_day             == ra._last_seed_day
		and ra2._alternate_flag            == ra._alternate_flag
		and ra2.cooldown_offset            == ra.cooldown_offset
		and ra2.disrupt_charges_remaining  == ra.disrupt_charges_remaining
		and ra2._disruption_days_remaining == ra._disruption_days_remaining)


## _disruption_days_remaining > 0 (disruption is active) must survive round-trip.
## This is the bug addressed in SPA-1090: previously the field was not serialized,
## so active disruptions were silently dropped on load.
static func test_rival_agent_disruption_active_round_trip() -> bool:
	var ra := RivalAgent.new()
	ra._active                    = true
	ra._last_seed_day             = 5
	ra._alternate_flag            = false
	ra.cooldown_offset            = 0
	ra.disrupt_charges_remaining  = 1
	ra._disruption_days_remaining = 3   ## disruption is active — MUST be preserved

	var serialized := SaveManager._serialize_rival_agent(ra)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var ra2 := RivalAgent.new()
	SaveManager._restore_rival_agent(ra2, parsed)

	if ra2._disruption_days_remaining != 3:
		push_error("test_rival_agent_disruption_active_round_trip: expected 3, got %d" % ra2._disruption_days_remaining)
		return false
	return true


## _restore_rival_agent with an empty dict must not touch agent state.
static func test_rival_agent_empty_dict_skips_restore() -> bool:
	var ra := RivalAgent.new()
	ra._active = true
	ra.disrupt_charges_remaining = 99   # sentinel

	SaveManager._restore_rival_agent(ra, {})

	## State must be unchanged — the empty-dict guard fires before any assignment.
	return ra._active == true and ra.disrupt_charges_remaining == 99


# ── InquisitorAgent ───────────────────────────────────────────────────────────

## All InquisitorAgent fields survive round-trip, including a non-empty shielded set.
static func test_inquisitor_agent_shielded_ids_round_trip() -> bool:
	var ia := InquisitorAgent.new()
	ia._active        = true
	ia._last_seed_day = 4
	ia._target_index  = 2
	ia.cooldown_offset = 1
	ia._shielded_npc_ids = {"npc_edric": true, "npc_bram": true}

	var serialized := SaveManager._serialize_inquisitor_agent(ia)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var ia2 := InquisitorAgent.new()
	SaveManager._restore_inquisitor_agent(ia2, parsed)

	if ia2._active != ia._active:
		push_error("test_inquisitor_agent_shielded_ids_round_trip: _active mismatch")
		return false
	if ia2._last_seed_day != ia._last_seed_day:
		push_error("test_inquisitor_agent_shielded_ids_round_trip: _last_seed_day mismatch")
		return false
	if ia2._target_index != ia._target_index:
		push_error("test_inquisitor_agent_shielded_ids_round_trip: _target_index mismatch")
		return false
	if ia2.cooldown_offset != ia.cooldown_offset:
		push_error("test_inquisitor_agent_shielded_ids_round_trip: cooldown_offset mismatch")
		return false
	if not ia2._shielded_npc_ids.has("npc_edric") or not ia2._shielded_npc_ids.has("npc_bram"):
		push_error("test_inquisitor_agent_shielded_ids_round_trip: shielded_npc_ids not restored correctly (got %s)" % str(ia2._shielded_npc_ids.keys()))
		return false
	return true


## Empty shielded_npc_ids array restores to an empty dict without crash.
static func test_inquisitor_agent_empty_shielded_ids() -> bool:
	var ia := InquisitorAgent.new()
	ia._active        = true
	ia._last_seed_day = 0
	ia._target_index  = 0
	ia.cooldown_offset = 0
	ia._shielded_npc_ids = {}

	var serialized := SaveManager._serialize_inquisitor_agent(ia)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var ia2 := InquisitorAgent.new()
	ia2._shielded_npc_ids["sentinel"] = true   # pre-populate to confirm it is cleared
	SaveManager._restore_inquisitor_agent(ia2, parsed)

	return ia2._shielded_npc_ids.is_empty()


# ── IllnessEscalationAgent ────────────────────────────────────────────────────

static func test_illness_escalation_agent_round_trip() -> bool:
	var iea := IllnessEscalationAgent.new()
	iea._active          = true
	iea._last_seed_day   = 3
	iea.cooldown_offset  = 2

	var serialized := SaveManager._serialize_illness_escalation_agent(iea)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var iea2 := IllnessEscalationAgent.new()
	SaveManager._restore_illness_escalation_agent(iea2, parsed)

	return (iea2._active         == iea._active
		and iea2._last_seed_day  == iea._last_seed_day
		and iea2.cooldown_offset == iea.cooldown_offset)


# ── S4FactionShiftAgent ───────────────────────────────────────────────────────

## All three phase flags true must survive round-trip.
static func test_s4_faction_shift_all_phases_fired_round_trip() -> bool:
	var agent := S4FactionShiftAgent.new()
	agent._active        = true
	agent._phase_1_fired = true
	agent._phase_2_fired = true
	agent._phase_3_fired = true

	var serialized := SaveManager._serialize_s4_faction_shift_agent(agent)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var agent2 := S4FactionShiftAgent.new()
	SaveManager._restore_s4_faction_shift_agent(agent2, parsed)

	return (agent2._active        == true
		and agent2._phase_1_fired == true
		and agent2._phase_2_fired == true
		and agent2._phase_3_fired == true)


## Mixed phase flags (only phase 1 fired) round-trip correctly.
static func test_s4_faction_shift_partial_phases_round_trip() -> bool:
	var agent := S4FactionShiftAgent.new()
	agent._active        = true
	agent._phase_1_fired = true
	agent._phase_2_fired = false
	agent._phase_3_fired = false

	var serialized := SaveManager._serialize_s4_faction_shift_agent(agent)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var agent2 := S4FactionShiftAgent.new()
	SaveManager._restore_s4_faction_shift_agent(agent2, parsed)

	return (agent2._phase_1_fired == true
		and agent2._phase_2_fired == false
		and agent2._phase_3_fired == false)


# ── GuildDefenseAgent ─────────────────────────────────────────────────────────

static func test_guild_defense_agent_round_trip() -> bool:
	var gda := GuildDefenseAgent.new()
	gda._active           = true
	gda._last_defense_day = 9
	gda.cooldown_offset   = 1

	var serialized := SaveManager._serialize_guild_defense_agent(gda)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var gda2 := GuildDefenseAgent.new()
	SaveManager._restore_guild_defense_agent(gda2, parsed)

	return (gda2._active           == gda._active
		and gda2._last_defense_day == gda._last_defense_day
		and gda2.cooldown_offset   == gda.cooldown_offset)


## Empty dict for guild_defense_agent (not active in S1–S5) must not mutate defaults.
static func test_guild_defense_agent_empty_dict_skips_restore() -> bool:
	var gda := GuildDefenseAgent.new()
	gda._active           = false
	gda._last_defense_day = 0

	SaveManager._restore_guild_defense_agent(gda, {})

	return gda._active == false and gda._last_defense_day == 0


# ── ScenarioManager ───────────────────────────────────────────────────────────

## S1 state flag and s1_first_blood_fired survive round-trip (S1-specific).
static func test_scenario_manager_s1_state_round_trip() -> bool:
	var sm := ScenarioManager.new()
	sm.scenario_1_state        = ScenarioManager.ScenarioState.ACTIVE
	sm._s1_first_blood_fired   = true

	var serialized := SaveManager._serialize_scenario_manager(sm)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var sm2 := ScenarioManager.new()
	SaveManager._restore_scenario_manager(sm2, parsed)

	return (int(sm2.scenario_1_state) == int(ScenarioManager.ScenarioState.ACTIVE)
		and sm2._s1_first_blood_fired == true)


## Calder/Tomas scores (S3) survive round-trip.
static func test_scenario_manager_s3_calder_scores_round_trip() -> bool:
	var sm := ScenarioManager.new()
	sm.calder_score_start = 55
	sm.calder_score_final = 80

	var serialized := SaveManager._serialize_scenario_manager(sm)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var sm2 := ScenarioManager.new()
	SaveManager._restore_scenario_manager(sm2, parsed)

	return sm2.calder_score_start == 55 and sm2.calder_score_final == 80


## S5 endorsement fields survive round-trip.
static func test_scenario_manager_s5_endorsement_round_trip() -> bool:
	var sm := ScenarioManager.new()
	sm._s5_endorsement_fired  = true
	sm.s5_endorsed_candidate  = "aldric_vane"
	sm.scenario_5_state       = ScenarioManager.ScenarioState.ACTIVE

	var serialized := SaveManager._serialize_scenario_manager(sm)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var sm2 := ScenarioManager.new()
	SaveManager._restore_scenario_manager(sm2, parsed)

	if not sm2._s5_endorsement_fired:
		push_error("test_scenario_manager_s5_endorsement_round_trip: _s5_endorsement_fired not restored")
		return false
	if sm2.s5_endorsed_candidate != "aldric_vane":
		push_error("test_scenario_manager_s5_endorsement_round_trip: s5_endorsed_candidate = '%s'" % sm2.s5_endorsed_candidate)
		return false
	return true


## S6 scenario_6_state survives round-trip.
static func test_scenario_manager_s6_state_round_trip() -> bool:
	var sm := ScenarioManager.new()
	sm.scenario_6_state = ScenarioManager.ScenarioState.ACTIVE

	var serialized := SaveManager._serialize_scenario_manager(sm)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var sm2 := ScenarioManager.new()
	SaveManager._restore_scenario_manager(sm2, parsed)

	return int(sm2.scenario_6_state) == int(ScenarioManager.ScenarioState.ACTIVE)


## S2 Maren-specific fields survive round-trip.
static func test_scenario_manager_s2_maren_fields_round_trip() -> bool:
	var sm := ScenarioManager.new()
	sm._s2_maren_first_reject_tick = 14
	sm.s2_maren_carrier_name       = "alys_herbwife"

	var serialized := SaveManager._serialize_scenario_manager(sm)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var sm2 := ScenarioManager.new()
	SaveManager._restore_scenario_manager(sm2, parsed)

	return (sm2._s2_maren_first_reject_tick == 14
		and sm2.s2_maren_carrier_name == "alys_herbwife")


## s1_first_blood_fired = false (default) restores to false, not some stale true.
static func test_scenario_manager_s1_first_blood_round_trip() -> bool:
	var sm := ScenarioManager.new()
	sm._s1_first_blood_fired = false

	var serialized := SaveManager._serialize_scenario_manager(sm)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var sm2 := ScenarioManager.new()
	sm2._s1_first_blood_fired = true   # pre-set to opposite to catch missed restore
	SaveManager._restore_scenario_manager(sm2, parsed)

	return sm2._s1_first_blood_fired == false


## heat_ceiling_override = -1.0 (inactive) is preserved as the sentinel default.
static func test_scenario_manager_heat_ceiling_negative_default() -> bool:
	var sm := ScenarioManager.new()
	sm._heat_ceiling_override             = -1.0
	sm._heat_ceiling_override_expires_day = -1

	var serialized := SaveManager._serialize_scenario_manager(sm)
	var parsed     := _json_rt(serialized)
	if parsed.is_empty():
		return false

	var sm2 := ScenarioManager.new()
	SaveManager._restore_scenario_manager(sm2, parsed)

	return (sm2._heat_ceiling_override == -1.0
		and sm2._heat_ceiling_override_expires_day == -1)


# ── Day/tick edge cases ───────────────────────────────────────────────────────

## A mid-day save (tick > 0, day > 1) preserves both values exactly.
## Verifies that the tick/day fields in the top-level save dict parse correctly.
static func test_mid_day_tick_and_day_round_trip() -> bool:
	var data := {
		"version":     SaveManager.SAVE_VERSION,
		"scenario_id": "scenario_3",
		"tick":        47,
		"day":         8,
	}
	var text := JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	return int(parsed.get("tick", -1)) == 47 and int(parsed.get("day", -1)) == 8


# ── Cross-scenario agent isolation ────────────────────────────────────────────

## All six scenario_id values must be parseable from the save dict without errors.
## Also verifies that absent agent dicts (scenario mismatch) don't cause crashes
## when the corresponding restore function receives an empty dict.
static func test_all_scenario_ids_serialize_gracefully() -> bool:
	var scenario_ids := [
		"scenario_1", "scenario_2", "scenario_3",
		"scenario_4", "scenario_5", "scenario_6",
	]
	for sid in scenario_ids:
		var data := {
			"version":     SaveManager.SAVE_VERSION,
			"scenario_id": sid,
			"tick":        0,
			"day":         1,
		}
		var text := JSON.stringify(data)
		var parsed: Variant = JSON.parse_string(text)
		if not (parsed is Dictionary):
			push_error("test_all_scenario_ids_serialize_gracefully: JSON parse failed for %s" % sid)
			return false
		## Simulate restore of absent agent blocks — all must return without crash.
		var ra  := RivalAgent.new()
		var ia  := InquisitorAgent.new()
		var iea := IllnessEscalationAgent.new()
		var gda := GuildDefenseAgent.new()
		var s4a := S4FactionShiftAgent.new()
		var sm  := ScenarioManager.new()
		SaveManager._restore_rival_agent(ra,   parsed.get("rival_agent", {}))
		SaveManager._restore_inquisitor_agent(ia,  parsed.get("inquisitor_agent", {}))
		SaveManager._restore_illness_escalation_agent(iea, parsed.get("illness_escalation_agent", {}))
		SaveManager._restore_guild_defense_agent(gda, parsed.get("guild_defense_agent", {}))
		SaveManager._restore_s4_faction_shift_agent(s4a, parsed.get("s4_faction_shift_agent", {}))
		SaveManager._restore_scenario_manager(sm, parsed.get("scenario", {}))
	return true
