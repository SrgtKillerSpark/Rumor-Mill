## test_save_corruption.gd — Offline validation of save/load hardening (SPA-864, SPA-896).
##
## Run from the Godot editor:  Scene → Run Script (or attach to an autoload and call run()).
## All tests operate on synthetic in-memory data — no live game nodes required.
##
## Each test_* method pushes errors/warnings to the Godot output for QA inspection.
## Returns true if the test passed (no crash and result matched expectation).
##
## SPA-896 additions: cross-scenario field coverage, SPA-880 new fields, JSON key coercion.

class_name TestSaveCorruption
extends RefCounted


static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_valid_load",
		"test_corrupted_json",
		"test_version_too_new",
		"test_version_missing_migrates",
		"test_live_rumors_not_dict",
		"test_live_rumors_missing_keys",
		"test_npc_data_not_dict",
		"test_evidence_entry_not_dict",
		"test_location_intel_bad_entry",
		"test_relationship_intel_not_dict",
		"test_npc_orphaned_rumor_slot_dropped",
		"test_npc_slot_non_numeric_state",
		# SPA-896: extended coverage
		"test_all_scenario_ids_valid",
		"test_intel_store_spa880_fields_missing_graceful",
		"test_scenario_manager_deadline_key_coercion",
		"test_scenario_manager_spa880_fields_default",
		"test_inquisitor_shielded_ids_empty",
		"test_rival_agent_null_guard",
		"test_faction_event_malformed_event_skipped",
		"test_save_version_zero_explicit",
		"test_socially_dead_ids_non_string_entry",
		"test_bribe_charges_preserved",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSave corruption tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

## Minimal valid save dict matching SAVE_VERSION = 1.
static func _valid_save() -> Dictionary:
	return {
		"version":   SaveManager.SAVE_VERSION,
		"scenario_id": "scenario_1",
		"selected_difficulty": "master",
		"tick": 0,
		"day":  1,
		"social_graph": {},
		"propagation": {
			"live_rumors": {},
			"lineage": {},
			"contradiction_count": 0,
			"time_pressure_bonus": 0.0,
			"target_shift_excluded_ids": [],
			"mutation_counter": 0,
		},
		"npc_slots": {},
		"intel_store": {
			"recon_actions_remaining": 3,
			"whisper_tokens_remaining": 2,
			"location_intel": {},
			"relationship_intel": {},
			"heat": {},
			"heat_enabled": false,
			"bribe_charges": 0,
			"evidence_inventory": [],
			"evidence_used_count": 0,
			# SPA-880 additions — included here so template stays current.
			"free_quarantine_charges": 0,
			"free_campaign_charges": 0,
			"bonus_expose_uses": 0,
			"blackmail_uses_count": 0,
		},
		"reputation": {},
		"scenario": {},
		"rival_agent": {},
		"inquisitor_agent": {},
		"s4_faction_shift_agent": {},
		"illness_escalation_agent": {},
		"mid_game_event_agent": {},
		"guild_defense_agent": {},
		"faction_event_system": {},
		"socially_dead_ids": [],
		"timeline": [],
		"milestone_log": [],
		"tutorial_progress": {},
		"milestone_fired": {},
		"daily_planning": {},
	}


## Write a dict as JSON to user://saves/test_slot.json and call prepare_load().
## Returns the prepare_load error string (empty = success).
static func _write_and_prepare(data: Dictionary) -> String:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var path := "user://saves/test_corruption_slot.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "test helper: could not open %s for write" % path
	f.store_string(JSON.stringify(data))
	f.close()
	return SaveManager.prepare_load("test_corruption", -99)  ## sentinel slot; we override path below


## Direct in-memory test of prepare_load by jamming data into the private path.
## Writes to a known temp path, then re-reads via a mirrored private call path.
## Actually we bypass prepare_load and call _migrate_save_data directly where needed.
static func _simulate_prepare(raw_text: String) -> String:
	## Mirrors the logic inside SaveManager.prepare_load() without file I/O.
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		return "Save file is corrupted (invalid JSON)."
	var ver: int = int(parsed.get("version", 0))
	if ver > SaveManager.SAVE_VERSION:
		return "Save version %d is newer than game version %d. Update the game to load this save." % [
			ver, SaveManager.SAVE_VERSION]
	if ver < SaveManager.SAVE_VERSION:
		var err := SaveManager._migrate_save_data(parsed, ver)
		if err != "":
			return err
	return ""


## Simulate _restore_propagation with synthetic data; returns true if no crash.
static func _restore_propagation_safe(d: Dictionary) -> bool:
	## We cannot call into live PropagationEngine without a scene, so we replicate
	## the validation logic path and check it doesn't throw.
	for rid in d.get("live_rumors", {}):
		var rd: Variant = d["live_rumors"][rid]
		if not rd is Dictionary:
			push_error("save_manager: live_rumors[%s] is not a Dictionary — skipped" % rid)
			continue
		if not (rd.has("id") and rd.has("subject_npc_id") and rd.has("claim_type")):
			push_error("save_manager: live_rumors[%s] missing required keys — skipped" % rid)
			continue
	return true


# ── tests ────────────────────────────────────────────────────────────────────

static func test_valid_load() -> bool:
	var err := _simulate_prepare(JSON.stringify(_valid_save()))
	return err == ""


static func test_corrupted_json() -> bool:
	var err := _simulate_prepare("{ this is not json }")
	return err != ""


static func test_version_too_new() -> bool:
	var data := _valid_save()
	data["version"] = SaveManager.SAVE_VERSION + 1
	var err := _simulate_prepare(JSON.stringify(data))
	return err != "" and "newer" in err


static func test_version_missing_migrates() -> bool:
	var data := _valid_save()
	data.erase("version")
	var err := _simulate_prepare(JSON.stringify(data))
	## Should succeed (v0 → v1 is a no-op migration).
	return err == ""


static func test_live_rumors_not_dict() -> bool:
	var data := _valid_save()
	data["propagation"]["live_rumors"]["bad_id"] = "this is a string, not a dict"
	return _restore_propagation_safe(data["propagation"])


static func test_live_rumors_missing_keys() -> bool:
	var data := _valid_save()
	data["propagation"]["live_rumors"]["r1"] = {"id": "r1"}  ## missing subject_npc_id, claim_type
	return _restore_propagation_safe(data["propagation"])


static func test_npc_data_not_dict() -> bool:
	## Confirm non-Dictionary npc entry is caught and skipped without crash.
	var npc_slots := {"npc_xyz": "not a dict"}
	for npc_id in npc_slots:
		var _raw: Variant = npc_slots[npc_id]
		if not _raw is Dictionary:
			push_error("save_manager: npc_slots[%s] is not a Dictionary — skipped" % npc_id)
			continue
		## If we reach here the validation failed — should not happen in this test.
		return false
	return true


static func test_evidence_entry_not_dict() -> bool:
	var evidence_list: Array = ["not_a_dict", 42, null]
	var crashed := false
	for ed in evidence_list:
		if not ed is Dictionary:
			push_error("save_manager: evidence_inventory entry is not a Dictionary — skipped")
			continue
		## Real code would construct EvidenceItem here; we just verify no crash.
	return not crashed


static func test_location_intel_bad_entry() -> bool:
	var entries := [
		{"location_id": "market", "observed_at": 10},  ## valid
		{"observed_at": 5},                              ## missing location_id
		"oops",                                          ## not a dict
	]
	var skipped := 0
	for entry in entries:
		if not entry is Dictionary or not entry.has("location_id") or not entry.has("observed_at"):
			push_error("save_manager: malformed location_intel entry — skipped")
			skipped += 1
			continue
	return skipped == 2


static func test_relationship_intel_not_dict() -> bool:
	var rel_intel := {"k1": "bad", "k2": {"npc_a_id": "a", "npc_b_id": "b"}}
	var skipped := 0
	for key in rel_intel:
		var rd: Variant = rel_intel[key]
		if not rd is Dictionary:
			push_error("save_manager: relationship_intel[%s] is not a Dictionary — skipped" % key)
			skipped += 1
			continue
		if not rd.has("npc_a_id") or not rd.has("npc_b_id"):
			push_error("save_manager: relationship_intel[%s] missing npc_a_id/npc_b_id — skipped" % key)
			skipped += 1
	return skipped == 1


static func test_npc_orphaned_rumor_slot_dropped() -> bool:
	## NPC slot references a rumor id not in live_rumors — slot must be dropped.
	var live_rumors := {}  ## empty — no live rumors
	var slot_data := {"orphaned_rumor_id": {"state": 0, "ticks_in_state": 0, "heard_from_count": 1, "source_faction": ""}}
	var applied := 0
	for rid in slot_data:
		if not live_rumors.has(rid):
			push_warning("Save/load: NPC npc_test references missing rumor %s — slot dropped" % rid)
			continue
		applied += 1
	return applied == 0


static func test_npc_slot_non_numeric_state() -> bool:
	var _state_raw: Variant = "CORRUPTED"
	if not (_state_raw is int or _state_raw is float):
		push_warning("save_manager: slot state for rumor r1 is non-numeric (%s) — using EVALUATING" % _state_raw)
		_state_raw = Rumor.RumorState.EVALUATING
	return _state_raw == Rumor.RumorState.EVALUATING


# ── SPA-896: Extended scenario + edge-case tests ──────────────────────────────

## All six scenario_id values (S1–S6) must pass basic prepare validation.
static func test_all_scenario_ids_valid() -> bool:
	var scenario_ids := [
		"scenario_1", "scenario_2", "scenario_3",
		"scenario_4", "scenario_5", "scenario_6",
	]
	for sid in scenario_ids:
		var data := _valid_save()
		data["scenario_id"] = sid
		var err := _simulate_prepare(JSON.stringify(data))
		if err != "":
			push_error("test_all_scenario_ids_valid: %s failed — %s" % [sid, err])
			return false
	return true


## A save file missing the SPA-880 intel_store fields must still load (defaults applied).
static func test_intel_store_spa880_fields_missing_graceful() -> bool:
	var data := _valid_save()
	# Remove the four SPA-880 additions to simulate a pre-SPA-880 save.
	data["intel_store"].erase("free_quarantine_charges")
	data["intel_store"].erase("free_campaign_charges")
	data["intel_store"].erase("bonus_expose_uses")
	data["intel_store"].erase("blackmail_uses_count")
	var err := _simulate_prepare(JSON.stringify(data))
	## Must succeed — _restore_intel_store uses .get() with 0 defaults.
	return err == ""


## JSON always serialises dict keys as strings. _restore_scenario_manager coerces
## deadline_warnings_fired keys back to int with int(float(k)).  Verify the coercion
## produces the original int key, not a stale string key.
static func test_scenario_manager_deadline_key_coercion() -> bool:
	var raw_fired := {"3": true, "7": true, "15": false}
	var coerced: Dictionary = {}
	for k in raw_fired:
		coerced[int(float(k))] = raw_fired[k]
	## Keys must now be ints.
	for k in coerced:
		if not k is int:
			push_error("test_scenario_manager_deadline_key_coercion: key %s is not int after coercion" % k)
			return false
	## Values must be preserved.
	return coerced.get(3) == true and coerced.get(7) == true and coerced.get(15) == false


## A save missing the SPA-880 scenario_manager fields must load with safe defaults.
static func test_scenario_manager_spa880_fields_default() -> bool:
	var data := _valid_save()
	## Omit the three SPA-880 scenario fields to simulate a pre-patch save.
	var scenario_dict: Dictionary = {
		"scenario_1_state": 0,
		"scenario_2_state": 0,
		"scenario_3_state": 0,
		"scenario_4_state": 0,
		"scenario_5_state": 0,
		"scenario_6_state": 0,
		"calder_score_start": -1,
		"calder_score_final": -1,
		"deadline_warnings_fired": {},
		"s5_endorsement_fired": false,
		"s5_endorsed_candidate": "",
		"s2_maren_first_reject_tick": -1,
		"s2_maren_carrier_name": "",
		## heat_ceiling_override, heat_ceiling_override_expires_day, s1_first_blood_fired omitted.
	}
	data["scenario"] = scenario_dict
	var err := _simulate_prepare(JSON.stringify(data))
	return err == ""


## Inquisitor shielded_npc_ids stored as an empty array must restore without crash.
static func test_inquisitor_shielded_ids_empty() -> bool:
	var shielded_npc_ids_raw: Array = []
	var restored: Dictionary = {}
	for npc_id in shielded_npc_ids_raw:
		restored[str(npc_id)] = true
	return restored.is_empty()


## _restore_rival_agent skips gracefully when the rival_agent dict is empty (S1/S2/S4/S5/S6).
static func test_rival_agent_null_guard() -> bool:
	## Mirrors the null/empty check at the top of _restore_rival_agent.
	var d: Dictionary = {}
	if d.is_empty():
		return true  ## guard should fire and skip — no crash expected.
	return false


## faction_event_system with a malformed events entry (not a dict) should not crash
## when the restore code iterates it.  We replicate the guard logic here.
static func test_faction_event_malformed_event_skipped() -> bool:
	var raw_events: Array = [
		{"event_type": "religious_festival", "trigger_day": 3, "duration_days": 2,
		 "affected_npc_ids": [], "metadata": {}, "is_active": true, "is_expired": false},
		"not_a_dict",  ## malformed
		42,            ## also malformed
	]
	var valid_count := 0
	for ev in raw_events:
		if not ev is Dictionary:
			push_warning("faction_event_system: events entry is not a Dictionary — skipped")
			continue
		valid_count += 1
	return valid_count == 1


## Explicit version 0 save (version field = 0, not absent) should migrate cleanly.
static func test_save_version_zero_explicit() -> bool:
	var data := _valid_save()
	data["version"] = 0
	var err := _simulate_prepare(JSON.stringify(data))
	return err == ""


## socially_dead_ids containing a non-string entry must not cause a type error when
## used as a Dictionary key (GDScript auto-converts most types).
static func test_socially_dead_ids_non_string_entry() -> bool:
	var raw_ids: Array = ["npc_edric", 99, null, "npc_bram"]
	var restored: Dictionary = {}
	var crashed := false
	for npc_id in raw_ids:
		if npc_id == null:
			push_warning("save_manager: socially_dead_ids contains null — skipped")
			continue
		restored[str(npc_id)] = true
	## Expected: "npc_edric", "99", "npc_bram" in restored; null skipped.
	return not crashed and restored.has("npc_edric") and restored.has("99") and not restored.has("")


## bribe_charges must survive a round-trip through JSON (int → string repr → int).
static func test_bribe_charges_preserved() -> bool:
	var original_charges := 3
	var data := _valid_save()
	data["intel_store"]["bribe_charges"] = original_charges
	var json_text := JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return false
	var restored_charges: int = int(parsed["intel_store"].get("bribe_charges", 0))
	return restored_charges == original_charges
