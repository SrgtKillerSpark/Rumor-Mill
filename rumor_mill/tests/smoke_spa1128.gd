## smoke_spa1128.gd — Targeted smoke test for SPA-1128 regression items.
##
## Tests only the data/constant-level changes that can be verified headless
## without autoload singletons:
##   1. SPA-1122: scenarios.json difficulty keys are apprentice/master/spymaster
##   2. SPA-862:  SCENARIO_DIFFICULTY labels in MainMenuScenarioSelect
##   3. SPA-1110: MainMenuSettingsPanel panel field initialises null
##   4. HUD unification: BAR_WIDTH constants in scenario1–6 HUDs
##
## Run: godot --headless --path rumor_mill --script tests/smoke_spa1128.gd

extends RefCounted

const MainMenuScenarioSelectScript := preload("res://scripts/main_menu_scenario_select.gd")
const ScenarioConfigScript         := preload("res://scripts/scenario_config.gd")

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("\n=== SPA-1128 Smoke Tests ===\n")

	_section("SPA-1122 — scenarios.json difficulty keys")
	_check_scenarios_json_keys()

	_section("SPA-862 — MainMenuScenarioSelect SCENARIO_DIFFICULTY labels")
	_check_scenario_difficulty_labels()

	_section("SPA-1110 — MainMenuSettingsPanel initial state")
	_check_settings_panel_initial_state()

	_section("HUD unification — BAR_WIDTH constants")
	_check_hud_bar_widths()

	_section("SPA-1102 — ScenarioManager fresh instance state")
	_check_scenario_manager_fresh_state()

	print("\n=== Results: %d passed, %d failed ===\n" % [_passed, _failed])
	if _failed > 0:
		push_error("SMOKE FAILED: %d test(s) failed" % _failed)


func _section(name: String) -> void:
	print("── %s ──" % name)


func _pass(name: String) -> void:
	print("  PASS  %s" % name)
	_passed += 1


func _fail(name: String, detail: String = "") -> void:
	var msg: String = "  FAIL  %s" % name
	if detail != "":
		msg += "  (%s)" % detail
	push_error(msg)
	_failed += 1


# ── SPA-1122: scenarios.json difficulty keys ──────────────────────────────────

func _check_scenarios_json_keys() -> void:
	var file := FileAccess.open("res://data/scenarios.json", FileAccess.READ)
	if file == null:
		_fail("scenarios_json_readable", "FileAccess returned null")
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		_fail("scenarios_json_parseable", "JSON.parse error %d" % err)
		return
	_pass("scenarios_json_readable")

	var data: Array = json.data
	if data.size() != 6:
		_fail("scenarios_json_has_6_entries", "got %d" % data.size())
		return
	_pass("scenarios_json_has_6_entries")

	var valid_keys: Array = ["apprentice", "master", "spymaster"]
	var old_keys_found: Array = []
	var missing_keys: Array = []

	for entry in data:
		var sid: String = entry.get("scenarioId", "?")
		var dm: Dictionary = entry.get("difficultyModifiers", {})

		# No old keys
		for old_k in ["easy", "normal", "hard"]:
			if old_k in dm:
				old_keys_found.append("%s:%s" % [sid, old_k])

		# All valid keys present
		for vk in valid_keys:
			if vk not in dm:
				missing_keys.append("%s:%s" % [sid, vk])

	if old_keys_found.is_empty():
		_pass("no_old_difficulty_keys")
	else:
		_fail("no_old_difficulty_keys", str(old_keys_found))

	if missing_keys.is_empty():
		_pass("all_new_difficulty_keys_present")
	else:
		_fail("all_new_difficulty_keys_present", str(missing_keys))


# ── SPA-862: SCENARIO_DIFFICULTY labels ───────────────────────────────────────

func _check_scenario_difficulty_labels() -> void:
	var ss := MainMenuScenarioSelectScript.new()

	var expected: Dictionary = {
		"scenario_1": "Introductory",
		"scenario_2": "Moderate",
		"scenario_3": "Challenging",
		"scenario_4": "Expert",
		"scenario_5": "Advanced",
		"scenario_6": "Master",
	}

	if ss.SCENARIO_DIFFICULTY.size() == 6:
		_pass("scenario_difficulty_count_6")
	else:
		_fail("scenario_difficulty_count_6", "got %d" % ss.SCENARIO_DIFFICULTY.size())

	var mismatches: Array = []
	for sid in expected:
		var got: String = ss.SCENARIO_DIFFICULTY.get(sid, "")
		if got != expected[sid]:
			mismatches.append("%s: expected '%s' got '%s'" % [sid, expected[sid], got])

	if mismatches.is_empty():
		_pass("all_scenario_difficulty_labels_correct")
	else:
		_fail("all_scenario_difficulty_labels_correct", str(mismatches))

	# Accent count
	if ss.SCENARIO_ACCENT.size() == 6:
		_pass("scenario_accent_count_6")
	else:
		_fail("scenario_accent_count_6", "got %d" % ss.SCENARIO_ACCENT.size())

	ss.free()


# ── SPA-1110: MainMenuSettingsPanel initial state ─────────────────────────────

func _check_settings_panel_initial_state() -> void:
	# Load via preload path — SettingsManager refs are in function bodies only,
	# so the class itself should compile cleanly.
	var script: GDScript = load("res://scripts/main_menu_settings_panel.gd")
	if script == null:
		_fail("settings_panel_script_loads", "load() returned null")
		return
	_pass("settings_panel_script_loads")

	# The class uses SettingsManager in build() which we don't call — just verify
	# that class_name and initial var declarations are intact.
	var sp: Object = script.new()
	if sp.get("panel") == null:
		_pass("settings_panel_initial_null")
	else:
		_fail("settings_panel_initial_null", "panel was not null on new()")
	sp.free()


# ── HUD unification: BAR_WIDTH constants ─────────────────────────────────────

func _check_hud_bar_widths() -> void:
	# These scripts reference GameState/AudioManager inside methods only,
	# so they should compile. We just read the constants.
	var hud_files: Dictionary = {
		"scenario1_hud": "res://scripts/scenario1_hud.gd",
		"scenario2_hud": "res://scripts/scenario2_hud.gd",
		"scenario3_hud": "res://scripts/scenario3_hud.gd",
		"scenario4_hud": "res://scripts/scenario4_hud.gd",
		"scenario5_hud": "res://scripts/scenario5_hud.gd",
		"scenario6_hud": "res://scripts/scenario6_hud.gd",
	}
	var expected_width: int = 160

	for hud_name in hud_files:
		var path: String = hud_files[hud_name]
		var script: GDScript = load(path)
		if script == null:
			_fail("%s_loads" % hud_name, "load() returned null — likely autoload compile failure")
			continue

		var inst: Object = script.new()
		var bar_w = inst.get("BAR_WIDTH")
		inst.free()

		if bar_w == null:
			# No BAR_WIDTH constant on this HUD (shouldn't happen)
			_fail("%s_has_BAR_WIDTH" % hud_name)
		elif int(bar_w) == expected_width:
			_pass("%s_BAR_WIDTH_%d" % [hud_name, expected_width])
		else:
			_fail("%s_BAR_WIDTH_%d" % [hud_name, expected_width],
				"got %d" % int(bar_w))


# ── SPA-1102: ScenarioManager fresh instance ─────────────────────────────────

func _check_scenario_manager_fresh_state() -> void:
	var script: GDScript = load("res://scripts/scenario_manager.gd")
	if script == null:
		_fail("scenario_manager_loads")
		return
	_pass("scenario_manager_loads")

	var sm: Object = script.new()

	# All states must be ACTIVE (0) on fresh instance
	var all_active: bool = true
	for i in range(1, 7):
		var key: String = "scenario_%d_state" % i
		var val = sm.get(key)
		if val != 0:  # 0 = ScenarioManager.ScenarioState.ACTIVE
			all_active = false
			push_error("  %s = %s (expected 0/ACTIVE)" % [key, str(val)])

	if all_active:
		_pass("fresh_instance_all_states_active")
	else:
		_fail("fresh_instance_all_states_active")

	# _pending_load_data must not exist or be empty on ScenarioManager (it's on SaveManager)
	# Just verify the key event flags start cleared
	var s1_fired = sm.get("_s1_first_blood_fired")
	var s5_fired = sm.get("_s5_endorsement_fired")

	if s1_fired == false:
		_pass("fresh_instance_s1_first_blood_not_fired")
	else:
		_fail("fresh_instance_s1_first_blood_not_fired", "was %s" % str(s1_fired))

	if s5_fired == false:
		_pass("fresh_instance_s5_endorsement_not_fired")
	else:
		_fail("fresh_instance_s5_endorsement_not_fired", "was %s" % str(s5_fired))

	sm.free()
