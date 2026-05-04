## test_save_corruption.gd — GUT unit tests for SaveManager corruption detection.
##
## Verifies that prepare_load() catches every corruption/mismatch category and
## that the static path helpers produce correctly structured paths.
##
## Tests use a temporary directory under user://saves/gut_tmp/ so they never
## interact with real player saves.  The directory is created in before_all()
## and removed in after_all().
##
## Run via GUT panel (Godot editor) or headless:
##   godot --headless -s addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/test_save_corruption.gd -gexit

extends GutTest

# ---------------------------------------------------------------------------
# Constants mirrored from SaveManager for assertion clarity
# ---------------------------------------------------------------------------

const SAVE_VERSION := 1   # must match SaveManager.SAVE_VERSION
const TMP_SCENARIO := "gut_tmp_scenario"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func before_all() -> void:
	# Ensure the saves directory and our test sub-directory exist.
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	# Clear any leftover test files from a previous aborted run.
	_delete_test_saves()


func after_all() -> void:
	_delete_test_saves()


func after_each() -> void:
	# Reset pending load state between tests.
	# prepare_load() stores data in a static var; clear it by calling
	# prepare_load() on a non-existent path (guaranteed to fail, leaving state empty).
	SaveManager.prepare_load("__no_such_scenario__", 99)


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
	# Remove any leftover .tmp file from the atomic write test.
	var tmp := SaveManager.save_path(TMP_SCENARIO, 1) + ".tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)


# ---------------------------------------------------------------------------
# save_path — path format
# ---------------------------------------------------------------------------

func test_save_path_manual_slot_contains_slot_number() -> void:
	var path := SaveManager.save_path("scenario_1", 1)
	assert_true(path.contains("slot1"), "slot path should contain 'slot1', got: " + path)


func test_save_path_manual_slot_is_json() -> void:
	var path := SaveManager.save_path("scenario_1", 2)
	assert_true(path.ends_with(".json"))


func test_save_path_auto_slot_contains_auto() -> void:
	var path := SaveManager.save_path("scenario_3", 0)
	assert_true(path.contains("_auto"), "auto-save path should contain '_auto', got: " + path)


func test_save_path_embeds_scenario_id() -> void:
	var path := SaveManager.save_path("scenario_5", 1)
	assert_true(path.contains("scenario_5"))


func test_save_path_different_scenarios_differ() -> void:
	var p1 := SaveManager.save_path("scenario_1", 1)
	var p2 := SaveManager.save_path("scenario_2", 1)
	assert_ne(p1, p2)


func test_save_path_different_slots_differ() -> void:
	var p1 := SaveManager.save_path("scenario_1", 1)
	var p2 := SaveManager.save_path("scenario_1", 2)
	assert_ne(p1, p2)


# ---------------------------------------------------------------------------
# has_save — file existence checks
# ---------------------------------------------------------------------------

func test_has_save_returns_false_when_no_file() -> void:
	assert_false(SaveManager.has_save(TMP_SCENARIO, 1))


func test_has_save_returns_true_after_file_written() -> void:
	_write_valid_save()
	assert_true(SaveManager.has_save(TMP_SCENARIO, 1))
	_delete_test_saves()


# ---------------------------------------------------------------------------
# prepare_load — missing file
# ---------------------------------------------------------------------------

func test_prepare_load_returns_error_for_missing_save() -> void:
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_ne(err, "", "should return an error string when no save file exists")


func test_prepare_load_missing_leaves_no_pending_load() -> void:
	SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_false(SaveManager.has_pending_load())


# ---------------------------------------------------------------------------
# prepare_load — corrupted JSON
# ---------------------------------------------------------------------------

func test_prepare_load_returns_error_for_empty_file() -> void:
	_write_raw("")
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_ne(err, "", "empty file should be rejected as corrupted")
	_delete_test_saves()


func test_prepare_load_returns_error_for_truncated_json() -> void:
	_write_raw('{"version":1,"scenario_id":"gut_tmp_scenario","tick":')
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_ne(err, "", "truncated JSON should be rejected as corrupted")
	_delete_test_saves()


func test_prepare_load_returns_error_for_json_array_instead_of_dict() -> void:
	_write_raw('[1, 2, 3]')
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_ne(err, "", "JSON array root should be rejected (expected dict)")
	_delete_test_saves()


func test_prepare_load_returns_error_for_plain_string() -> void:
	_write_raw('"just a string"')
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_ne(err, "", "plain JSON string should be rejected as corrupted")
	_delete_test_saves()


func test_prepare_load_returns_error_for_null_json() -> void:
	_write_raw('null')
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_ne(err, "", "null JSON should be rejected as corrupted")
	_delete_test_saves()


func test_prepare_load_corrupted_leaves_no_pending_load() -> void:
	_write_raw("NOT_JSON{{{{")
	SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_false(SaveManager.has_pending_load())
	_delete_test_saves()


# ---------------------------------------------------------------------------
# prepare_load — version mismatch
# ---------------------------------------------------------------------------

func test_prepare_load_returns_error_for_version_zero() -> void:
	_write_valid_save({"version": 0})
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_ne(err, "", "version 0 should be rejected as mismatched")
	_delete_test_saves()


func test_prepare_load_returns_error_for_future_version() -> void:
	_write_valid_save({"version": SAVE_VERSION + 1})
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_ne(err, "", "future version should be rejected as mismatched")
	_delete_test_saves()


func test_prepare_load_error_message_contains_version_numbers() -> void:
	_write_valid_save({"version": 42})
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_true(err.contains("42") or err.to_lower().contains("version"),
		"mismatch error should mention version numbers, got: " + err)
	_delete_test_saves()


func test_prepare_load_version_mismatch_leaves_no_pending_load() -> void:
	_write_valid_save({"version": 999})
	SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_false(SaveManager.has_pending_load())
	_delete_test_saves()


# ---------------------------------------------------------------------------
# prepare_load — valid save
# ---------------------------------------------------------------------------

func test_prepare_load_returns_empty_string_for_valid_save() -> void:
	_write_valid_save()
	var err := SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_eq(err, "", "valid save should return empty error string, got: " + err)
	_delete_test_saves()


func test_prepare_load_valid_sets_pending_load() -> void:
	_write_valid_save()
	SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_true(SaveManager.has_pending_load())
	_delete_test_saves()


func test_pending_scenario_id_matches_save() -> void:
	_write_valid_save()
	SaveManager.prepare_load(TMP_SCENARIO, 1)
	assert_eq(SaveManager.pending_scenario_id(), TMP_SCENARIO)
	_delete_test_saves()


# ---------------------------------------------------------------------------
# get_save_info — metadata extraction
# ---------------------------------------------------------------------------

func test_get_save_info_returns_empty_dict_when_no_save() -> void:
	var info := SaveManager.get_save_info(TMP_SCENARIO, 1)
	assert_eq(info, {})


func test_get_save_info_returns_day_and_tick() -> void:
	_write_valid_save({"day": 7, "tick": 18})
	var info := SaveManager.get_save_info(TMP_SCENARIO, 1)
	assert_eq(info.get("day",  -1), 7)
	assert_eq(info.get("tick", -1), 18)
	_delete_test_saves()


func test_get_save_info_corrupted_file_returns_empty_dict() -> void:
	_write_raw("GARBAGE")
	var info := SaveManager.get_save_info(TMP_SCENARIO, 1)
	assert_eq(info, {})
	_delete_test_saves()


# ---------------------------------------------------------------------------
# Auto-slot (slot 0) path and existence
# ---------------------------------------------------------------------------

func test_auto_slot_save_path_differs_from_slot_1() -> void:
	var auto_path := SaveManager.save_path(TMP_SCENARIO, 0)
	var slot1_path := SaveManager.save_path(TMP_SCENARIO, 1)
	assert_ne(auto_path, slot1_path)


func test_has_save_auto_slot_independent_from_manual_slots() -> void:
	_write_valid_save()  # writes to slot 1
	assert_false(SaveManager.has_save(TMP_SCENARIO, 0),
		"auto slot should not exist just because slot 1 exists")
	_delete_test_saves()
