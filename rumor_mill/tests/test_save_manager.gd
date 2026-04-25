## test_save_manager.gd — Unit tests for SaveManager public API (SPA-964).
##
## Covers:
##   • save_path()               — correct file path for AUTO_SLOT and manual slots 1–3
##   • prepare_load()            — error returns for missing file, bad JSON, version-too-new
##   • prepare_load() (valid)    — returns "" and sets pending state
##   • has_pending_load()        — true after a successful prepare_load()
##   • pending_scenario_id()     — returns correct id after a successful prepare_load()
##   • _migrate_save_data()      — v0 data stamped to current SAVE_VERSION
##   • Edge: out-of-range slot   — save_path() does not crash
##
## File-IO tests write to user://saves/ under the sentinel scenario id
## "test_sm_unit" to avoid colliding with real game saves.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestSaveManager
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_save_path_auto_slot",
		"test_save_path_manual_slots",
		"test_save_path_out_of_range_no_crash",
		"test_prepare_load_missing_file",
		"test_prepare_load_corrupted_json",
		"test_prepare_load_version_too_new",
		"test_prepare_load_valid_sets_pending",
		"test_migrate_v0_stamps_version",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSaveManager tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

const _TEST_SCENARIO_ID := "test_sm_unit"


## Writes a Dictionary as JSON to the given sentinel save slot. Returns true on success.
static func _write_test_save(data: Dictionary, slot: int) -> bool:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var path := SaveManager.save_path(_TEST_SCENARIO_ID, slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("test_save_manager: could not open '%s' for writing" % path)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


## Writes raw text (for corrupted-JSON tests) to the given sentinel save slot.
static func _write_raw(text: String, slot: int) -> bool:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var path := SaveManager.save_path(_TEST_SCENARIO_ID, slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


## Minimal valid save dict that satisfies prepare_load() version and type checks.
static func _valid_save() -> Dictionary:
	return {
		"version":     SaveManager.SAVE_VERSION,
		"scenario_id": _TEST_SCENARIO_ID,
		"tick": 0,
		"day":  1,
	}


# ── tests ────────────────────────────────────────────────────────────────────

## AUTO_SLOT (0) produces a path ending in "<scenario_id>_auto.json".
static func test_save_path_auto_slot() -> bool:
	var path := SaveManager.save_path("scenario_1", SaveManager.AUTO_SLOT)
	return path.ends_with("scenario_1_auto.json")


## Manual slots 1–3 each produce a path ending in "<scenario_id>_slotN.json".
static func test_save_path_manual_slots() -> bool:
	for slot in [1, 2, 3]:
		var path := SaveManager.save_path("scenario_2", slot)
		if not path.ends_with("scenario_2_slot%d.json" % slot):
			push_error("test_save_path_manual_slots: unexpected path for slot %d: %s" % [slot, path])
			return false
	return true


## An out-of-range slot (e.g. 99) does not crash; save_path() returns a non-empty string.
static func test_save_path_out_of_range_no_crash() -> bool:
	var path := SaveManager.save_path("scenario_1", 99)
	return path.length() > 0


## prepare_load() returns a non-empty error when the file does not exist on disk.
static func test_prepare_load_missing_file() -> bool:
	var err := SaveManager.prepare_load("nonexistent_scenario_xyz_unit_test", 1)
	if err == "":
		push_error("test_prepare_load_missing_file: expected error string, got empty")
		return false
	return true


## prepare_load() returns a non-empty error when the file contains invalid JSON.
static func test_prepare_load_corrupted_json() -> bool:
	if not _write_raw("{ this is not valid json !! }", 1):
		push_error("test_prepare_load_corrupted_json: could not write test file")
		return false
	var err := SaveManager.prepare_load(_TEST_SCENARIO_ID, 1)
	return err != ""


## prepare_load() returns a non-empty error (containing "newer") when save version > SAVE_VERSION.
static func test_prepare_load_version_too_new() -> bool:
	var data := _valid_save()
	data["version"] = SaveManager.SAVE_VERSION + 1
	if not _write_test_save(data, 2):
		push_error("test_prepare_load_version_too_new: could not write test file")
		return false
	var err := SaveManager.prepare_load(_TEST_SCENARIO_ID, 2)
	return err != "" and "newer" in err


## prepare_load() returns "" for a valid file, and sets has_pending_load() / pending_scenario_id().
static func test_prepare_load_valid_sets_pending() -> bool:
	var data := _valid_save()
	if not _write_test_save(data, 3):
		push_error("test_prepare_load_valid_sets_pending: could not write test file")
		return false
	var err := SaveManager.prepare_load(_TEST_SCENARIO_ID, 3)
	if err != "":
		push_error("test_prepare_load_valid_sets_pending: expected no error, got: %s" % err)
		return false
	if not SaveManager.has_pending_load():
		push_error("test_prepare_load_valid_sets_pending: has_pending_load() is false after success")
		return false
	var sid := SaveManager.pending_scenario_id()
	if sid != _TEST_SCENARIO_ID:
		push_error("test_prepare_load_valid_sets_pending: pending_scenario_id() = '%s', expected '%s'" % [sid, _TEST_SCENARIO_ID])
		return false
	return true


## _migrate_save_data() stamps a v0 dict (version absent / 0) with the current SAVE_VERSION.
static func test_migrate_v0_stamps_version() -> bool:
	var data: Dictionary = {"scenario_id": "scenario_1", "tick": 0, "day": 1}
	var err := SaveManager._migrate_save_data(data, 0)
	if err != "":
		push_error("test_migrate_v0_stamps_version: migration returned error: %s" % err)
		return false
	if data.get("version", -1) != SaveManager.SAVE_VERSION:
		push_error("test_migrate_v0_stamps_version: version not stamped (got %s)" % str(data.get("version")))
		return false
	return true
