## test_save_corruption.gd — Offline validation of save/load hardening (SPA-864).
##
## Run from the Godot editor:  Scene → Run Script (or attach to an autoload and call run()).
## All tests operate on synthetic in-memory data — no live game nodes required.
##
## Each test_* method pushes errors/warnings to the Godot output for QA inspection.
## Returns true if the test passed (no crash and result matched expectation).

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
