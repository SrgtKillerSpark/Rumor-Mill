## test_save_corruption.gd — Headless unit tests for SaveManager corruption detection.
##
## Verifies that prepare_load() catches every corruption/mismatch category and
## that the static path helpers produce correctly structured paths.
##
## Tests use a temporary directory under user://saves/gut_tmp/ so they never
## interact with real player saves.  The directory is created in _before_all()
## and removed in _after_all().
##
## Converted from GutTest to RefCounted runner pattern (SPA-2124).

class_name TestSaveCorruption
extends RefCounted

# ---------------------------------------------------------------------------
# Constants mirrored from SaveManager for assertion clarity
# ---------------------------------------------------------------------------

const SAVE_VERSION := 2   # must match SaveManager.SAVE_VERSION
const TMP_SCENARIO := "gut_tmp_scenario"

# ---------------------------------------------------------------------------
# Lifecycle helpers (replaces GUT before_all / after_all / after_each)
# ---------------------------------------------------------------------------

func _before_all() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	_delete_test_saves()


func _after_all() -> void:
	_delete_test_saves()


func _after_each() -> void:
	# Reset pending load state between tests.
	SaveManager.prepare_load("__no_such_scenario__", 99)


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

func run() -> void:
	var passed := 0
	var failed := 0

	_before_all()

	var tests := [
		# save_path — path format
		"test_save_path_manual_slot_contains_slot_number",
		"test_save_path_manual_slot_is_json",
		"test_save_path_auto_slot_contains_auto",
		"test_save_path_embeds_scenario_id",
		"test_save_path_different_scenarios_differ",
		"test_save_path_different_slots_differ",
		# has_save — file existence checks
		"test_has_save_returns_false_when_no_file",
		"test_has_save_returns_true_after_file_written",
		# prepare_load — missing file
		"test_prepare_load_returns_error_for_missing_save",
		"test_prepare_load_missing_leaves_no_pending_load",
		# prepare_load — corrupted JSON
		"test_prepare_load_returns_error_for_empty_file",
		"test_prepare_load_returns_error_for_truncated_json",
		"test_prepare_load_returns_error_for_json_array_instead_of_dict",
		"test_prepare_load_returns_error_for_plain_string",
		"test_prepare_load_returns_error_for_null_json",
		"test_prepare_load_corrupted_leaves_no_pending_load",
		# prepare_load — version mismatch
		"test_prepare_load_allows_version_zero_migration",
		"test_prepare_load_returns_error_for_future_version",
		"test_prepare_load_error_message_contains_version_numbers",
		"test_prepare_load_version_mismatch_leaves_no_pending_load",
		# prepare_load — valid save
		"test_prepare_load_returns_empty_string_for_valid_save",
		"test_prepare_load_valid_sets_pending_load",
		"test_pending_scenario_id_matches_save",
		# get_save_info — metadata extraction
		"test_get_save_info_returns_empty_dict_when_no_save",
		"test_get_save_info_returns_day_and_tick",
		"test_get_save_info_corrupted_file_returns_empty_dict",
		# Auto-slot path and existence
		"test_auto_slot_save_path_differs_from_slot_1",
		"test_has_save_auto_slot_independent_from_manual_slots",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		_after_each()
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	_after_all()
	print("\n  SaveCorruption: %d passed, %d failed" % [passed, failed])


# ---------------------------------------------------------------------------
# Helper: write a raw string to the slot-1 test path
# ---------------------------------------------------------------------------

func _write_raw(content: String) -> void:
	var path := SaveManager.save_path(TMP_SCENARIO, 1)
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()


func _write_valid_save(overrides: Dictionary = {}) -> void:
	var data: Dictionary = {
		"version":               SAVE_VERSION,
		"scenario_id":           TMP_SCENARIO,
		"selected_difficulty":   "normal",
		"tick":                  12,
		"day":                   3,
		"social_graph":          {},
		"propagation":           {},
		"npc_slots":             {},
		"intel_store":           {},
		"reputation":            {},
		"scenario":              {},
		"rival_agent":           {},
		"inquisitor_agent":      {},
		"s4_faction_shift_agent":   {},
		"illness_escalation_agent": {},
		"mid_game_event_agent":  {},
		"guild_defense_agent":   {},
		"faction_event_system":  {},
		"socially_dead_ids":     [],
		"timeline":              [],
		"milestone_log":         [],
		"tutorial_progress":     {},
		"milestone_fired":       {},
		"daily_planning":        {},
	}
	for key in overrides:
		data[key] = overrides[key]
	_write_raw(JSON.stringify(data))


func _delete_test_saves() -> void:
	for slot in range(0, 4):
		var path := SaveManager.save_path(TMP_SCENARIO, slot)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var tmp := SaveManager.save_path(TMP_SCENARIO, 1) + ".tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)


# ---------------------------------------------------------------------------
# save_path — path format
# ---------------------------------------------------------------------------

func test_save_path_manual_slot_contains_slot_number() -> bool:
	var path := SaveManager.save_path("scenario_1", 1)
	if not path.contains("slot1"):
		push_error("test_save_path_manual_slot_contains_slot_number: slot path should contain 'slot1', got: " + path)
		return false
	return true


func test_save_path_manual_slot_is_json() -> bool:
	var path := SaveManager.save_path("scenario_1", 2)
	if not path.ends_with(".json"):
		push_error("test_save_path_manual_slot_is_json: expected .json extension, got: " + path)
		return false
	return true


func test_save_path_auto_slot_contains_auto() -> bool:
	var path := SaveManager.save_path("scenario_3", 0)
	if not path.contains("_auto"):
		push_error("test_save_path_auto_slot_contains_auto: auto-save path should contain '_auto', got: " + path)
		return false
	return true


func test_save_path_embeds_scenario_id() -> bool:
	var path := SaveManager.save_path("scenario_5", 1)
	if not path.contains("scenario_5"):
		push_error("test_save_path_embeds_scenario_id: path should contain scenario id, got: " + path)
		return false
	return true


func test_save_path_different_scenarios_differ() -> bool:
	var p1 := SaveManager.save_path("scenario_1", 1)
	var p2 := SaveManager.save_path("scenario_2", 1)
	if p1 == p2:
		push_error("test_save_path_different_scenarios_differ: expected different paths for different scenarios")
		return false
	return true


func test_save_path_different_slots_differ() -> bool:
	var p1 := SaveManager.save_path("scenario_1", 1)
	var p2 := SaveManager.save_path("scenario_1", 2)
	if p1 == p2:
		push_error("test_save_path_different_slots_differ: expected different paths for different slots")
		return false
	return true


# ---------------------------------------------------------------------------
# has_save — file existence checks
# ---------------------------------------------------------------------------

func test_has_save_returns_false_when_no_file() -> bool:
	if SaveManager.has_save(TMP_SCENARIO, 1):
		push_error("test_has_save_returns_false_when_no_file: expected false when no file exists")
		return false
	return true


func test_has_save_returns_true_after_file_written() -> bool:
	_write_valid_save()
	var result := SaveManager.has_save(TMP_SCENARIO, 1)
	_delete_test_saves()
	if not result:
		push_error("test_has_save_returns_true_after_file_written: expected true after writing save")
		return false
	return true


# ---------------------------------------------------------------------------
# prepare_load — missing file
# ---------------------------------------------------------------------------

func test_prepare_load_returns_error_for_missing_save() -> bool:
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	if err == "":
		push_error("test_prepare_load_returns_error_for_missing_save: should return an error string when no save file exists")
		return false
	return true


func test_prepare_load_missing_leaves_no_pending_load() -> bool:
	SaveManager.prepare_load(TMP_SCENARIO, 1)
	if SaveManager.has_pending_load():
		push_error("test_prepare_load_missing_leaves_no_pending_load: expected no pending load after missing file")
		return false
	return true


# ---------------------------------------------------------------------------
# prepare_load — corrupted JSON
# ---------------------------------------------------------------------------

func test_prepare_load_returns_error_for_empty_file() -> bool:
	_write_raw("")
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	_delete_test_saves()
	if err == "":
		push_error("test_prepare_load_returns_error_for_empty_file: empty file should be rejected as corrupted")
		return false
	return true


func test_prepare_load_returns_error_for_truncated_json() -> bool:
	_write_raw('{"version":1,"scenario_id":"gut_tmp_scenario","tick":')
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	_delete_test_saves()
	if err == "":
		push_error("test_prepare_load_returns_error_for_truncated_json: truncated JSON should be rejected as corrupted")
		return false
	return true


func test_prepare_load_returns_error_for_json_array_instead_of_dict() -> bool:
	_write_raw('[1, 2, 3]')
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	_delete_test_saves()
	if err == "":
		push_error("test_prepare_load_returns_error_for_json_array_instead_of_dict: JSON array root should be rejected (expected dict)")
		return false
	return true


func test_prepare_load_returns_error_for_plain_string() -> bool:
	_write_raw('"just a string"')
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	_delete_test_saves()
	if err == "":
		push_error("test_prepare_load_returns_error_for_plain_string: plain JSON string should be rejected as corrupted")
		return false
	return true


func test_prepare_load_returns_error_for_null_json() -> bool:
	_write_raw('null')
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	_delete_test_saves()
	if err == "":
		push_error("test_prepare_load_returns_error_for_null_json: null JSON should be rejected as corrupted")
		return false
	return true


func test_prepare_load_corrupted_leaves_no_pending_load() -> bool:
	_write_raw("NOT_JSON{{{{")
	SaveManager.prepare_load(TMP_SCENARIO, 1)
	var result := not SaveManager.has_pending_load()
	_delete_test_saves()
	if not result:
		push_error("test_prepare_load_corrupted_leaves_no_pending_load: expected no pending load after corrupted file")
		return false
	return true


# ---------------------------------------------------------------------------
# prepare_load — version mismatch
# ---------------------------------------------------------------------------

func test_prepare_load_allows_version_zero_migration() -> bool:
	_write_valid_save({"version": 0})
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	_delete_test_saves()
	if err != "":
		push_error("test_prepare_load_allows_version_zero_migration: version 0 should be accepted for migration (SPA-1964), got: " + err)
		return false
	return true


func test_prepare_load_returns_error_for_future_version() -> bool:
	_write_valid_save({"version": SAVE_VERSION + 1})
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	_delete_test_saves()
	if err == "":
		push_error("test_prepare_load_returns_error_for_future_version: future version should be rejected as mismatched")
		return false
	return true


func test_prepare_load_error_message_contains_version_numbers() -> bool:
	_write_valid_save({"version": 42})
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	_delete_test_saves()
	if not (err.contains("42") or err.to_lower().contains("version")):
		push_error("test_prepare_load_error_message_contains_version_numbers: mismatch error should mention version numbers, got: " + err)
		return false
	return true


func test_prepare_load_version_mismatch_leaves_no_pending_load() -> bool:
	_write_valid_save({"version": 999})
	SaveManager.prepare_load(TMP_SCENARIO, 1)
	var result := not SaveManager.has_pending_load()
	_delete_test_saves()
	if not result:
		push_error("test_prepare_load_version_mismatch_leaves_no_pending_load: expected no pending load after version mismatch")
		return false
	return true


# ---------------------------------------------------------------------------
# prepare_load — valid save
# ---------------------------------------------------------------------------

func test_prepare_load_returns_empty_string_for_valid_save() -> bool:
	_write_valid_save()
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	_delete_test_saves()
	if err != "":
		push_error("test_prepare_load_returns_empty_string_for_valid_save: valid save should return empty error string, got: " + err)
		return false
	return true


func test_prepare_load_valid_sets_pending_load() -> bool:
	_write_valid_save()
	SaveManager.prepare_load(TMP_SCENARIO, 1)
	var result := SaveManager.has_pending_load()
	_delete_test_saves()
	if not result:
		push_error("test_prepare_load_valid_sets_pending_load: expected has_pending_load() true after valid prepare_load")
		return false
	return true


func test_pending_scenario_id_matches_save() -> bool:
	_write_valid_save()
	SaveManager.prepare_load(TMP_SCENARIO, 1)
	var sid := SaveManager.pending_scenario_id()
	_delete_test_saves()
	if sid != TMP_SCENARIO:
		push_error("test_pending_scenario_id_matches_save: expected '%s', got '%s'" % [TMP_SCENARIO, sid])
		return false
	return true


# ---------------------------------------------------------------------------
# get_save_info — metadata extraction
# ---------------------------------------------------------------------------

func test_get_save_info_returns_empty_dict_when_no_save() -> bool:
	var info := SaveManager.get_save_info(TMP_SCENARIO, 1)
	if info != {}:
		push_error("test_get_save_info_returns_empty_dict_when_no_save: expected empty dict, got: " + str(info))
		return false
	return true


func test_get_save_info_returns_day_and_tick() -> bool:
	_write_valid_save({"day": 7, "tick": 18})
	var info := SaveManager.get_save_info(TMP_SCENARIO, 1)
	_delete_test_saves()
	if info.get("day", -1) != 7:
		push_error("test_get_save_info_returns_day_and_tick: expected day=7, got: " + str(info.get("day")))
		return false
	if info.get("tick", -1) != 18:
		push_error("test_get_save_info_returns_day_and_tick: expected tick=18, got: " + str(info.get("tick")))
		return false
	return true


func test_get_save_info_corrupted_file_returns_empty_dict() -> bool:
	_write_raw("GARBAGE")
	var info := SaveManager.get_save_info(TMP_SCENARIO, 1)
	_delete_test_saves()
	if info != {}:
		push_error("test_get_save_info_corrupted_file_returns_empty_dict: expected empty dict for corrupted file, got: " + str(info))
		return false
	return true


# ---------------------------------------------------------------------------
# Auto-slot (slot 0) path and existence
# ---------------------------------------------------------------------------

func test_auto_slot_save_path_differs_from_slot_1() -> bool:
	var auto_path := SaveManager.save_path(TMP_SCENARIO, 0)
	var slot1_path := SaveManager.save_path(TMP_SCENARIO, 1)
	if auto_path == slot1_path:
		push_error("test_auto_slot_save_path_differs_from_slot_1: expected different paths for auto slot vs slot 1")
		return false
	return true


func test_has_save_auto_slot_independent_from_manual_slots() -> bool:
	_write_valid_save()  # writes to slot 1
	var result := not SaveManager.has_save(TMP_SCENARIO, 0)
	_delete_test_saves()
	if not result:
		push_error("test_has_save_auto_slot_independent_from_manual_slots: auto slot should not exist just because slot 1 exists")
		return false
	return true
