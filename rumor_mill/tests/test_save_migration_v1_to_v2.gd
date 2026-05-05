## test_save_migration_v1_to_v2.gd — Regression tests for the v1→v2 save migration (SPA-1724).
##
## Covers:
##   • test_v1_save_migrates_to_v2           — minimal v1 save gets all new fields stamped
##   • test_v1_save_with_existing_fields_untouched — pre-existing field values are preserved
##   • test_v1_save_empty_propagation        — missing live_rumors key does not crash
##   • test_v1_save_empty_intel_store        — empty intel_store gets evidence_target_cooldown added
##
## Tests call SaveManager._migrate_save_data() directly (no file I/O required).

class_name TestSaveMigrationV1ToV2
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_v1_save_migrates_to_v2",
		"test_v1_save_with_existing_fields_untouched",
		"test_v1_save_empty_propagation",
		"test_v1_save_empty_intel_store",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSaveMigrationV1ToV2 tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

## Returns a minimal v1 save dict with the given live_rumors dictionary.
static func _v1_save_with_rumors(live_rumors: Dictionary) -> Dictionary:
	return {
		"version": 1,
		"scenario_id": "test_migration",
		"tick": 0,
		"day": 1,
		"propagation": {
			"live_rumors": live_rumors,
		},
		"intel_store": {},
	}


# ── tests ─────────────────────────────────────────────────────────────────────

## A minimal v1 save with 2 rumors (missing the new Phase 2 fields) migrates to v2
## with all new fields stamped at their default values.
static func test_v1_save_migrates_to_v2() -> bool:
	var data := _v1_save_with_rumors({
		"rumor_a": {"content": "gossip A"},
		"rumor_b": {"content": "gossip B"},
	})
	var err := SaveManager._migrate_save_data(data, 1)
	if err != "":
		push_error("test_v1_save_migrates_to_v2: migration returned error: %s" % err)
		return false
	if data.get("version") != 2:
		push_error("test_v1_save_migrates_to_v2: version not 2 (got %s)" % str(data.get("version")))
		return false
	var live_rumors: Dictionary = data["propagation"]["live_rumors"]
	for rid in live_rumors:
		var rd: Dictionary = live_rumors[rid]
		if rd.get("evidence_credulity_boost") != 0.0:
			push_error("test_v1_save_migrates_to_v2: rumor '%s' evidence_credulity_boost != 0.0 (got %s)" % [rid, str(rd.get("evidence_credulity_boost"))])
			return false
		if rd.get("seed_target_npc_id") != "":
			push_error("test_v1_save_migrates_to_v2: rumor '%s' seed_target_npc_id != '' (got %s)" % [rid, str(rd.get("seed_target_npc_id"))])
			return false
	var intel_store: Dictionary = data.get("intel_store", {})
	if intel_store.get("evidence_target_cooldown") != {}:
		push_error("test_v1_save_migrates_to_v2: evidence_target_cooldown not {} (got %s)" % str(intel_store.get("evidence_target_cooldown")))
		return false
	return true


## If a v1 rumor already has evidence_credulity_boost set, migration must not overwrite it.
static func test_v1_save_with_existing_fields_untouched() -> bool:
	var data := _v1_save_with_rumors({
		"rumor_x": {"content": "gossip X", "evidence_credulity_boost": 0.5},
	})
	var err := SaveManager._migrate_save_data(data, 1)
	if err != "":
		push_error("test_v1_save_with_existing_fields_untouched: migration returned error: %s" % err)
		return false
	var boost: float = data["propagation"]["live_rumors"]["rumor_x"].get("evidence_credulity_boost", -1.0)
	if boost != 0.5:
		push_error("test_v1_save_with_existing_fields_untouched: evidence_credulity_boost overwritten (got %s)" % str(boost))
		return false
	return true


## A v1 save whose propagation dict has no live_rumors key must not crash.
static func test_v1_save_empty_propagation() -> bool:
	var data: Dictionary = {
		"version": 1,
		"scenario_id": "test_migration",
		"tick": 0,
		"day": 1,
		"propagation": {},
		"intel_store": {},
	}
	var err := SaveManager._migrate_save_data(data, 1)
	if err != "":
		push_error("test_v1_save_empty_propagation: migration returned error: %s" % err)
		return false
	if data.get("version") != 2:
		push_error("test_v1_save_empty_propagation: version not 2 (got %s)" % str(data.get("version")))
		return false
	return true


## A v1 save with an empty intel_store gets evidence_target_cooldown added as {}.
static func test_v1_save_empty_intel_store() -> bool:
	var data: Dictionary = {
		"version": 1,
		"scenario_id": "test_migration",
		"tick": 0,
		"day": 1,
		"propagation": {},
		"intel_store": {},
	}
	var err := SaveManager._migrate_save_data(data, 1)
	if err != "":
		push_error("test_v1_save_empty_intel_store: migration returned error: %s" % err)
		return false
	var intel_store: Dictionary = data.get("intel_store", {})
	if not intel_store.has("evidence_target_cooldown"):
		push_error("test_v1_save_empty_intel_store: evidence_target_cooldown key missing from intel_store")
		return false
	if intel_store["evidence_target_cooldown"] != {}:
		push_error("test_v1_save_empty_intel_store: evidence_target_cooldown not {} (got %s)" % str(intel_store["evidence_target_cooldown"]))
		return false
	return true
