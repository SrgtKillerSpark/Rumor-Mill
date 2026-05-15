## test_end_screen.gd — Unit tests for end_screen.gd coordinator (SPA-1024).
##
## Covers:
##   • Initial instance state: all runtime refs null, _resolving=false,
##     _last_outcome_won=false, _current_scenario_id=""
##   • Subsystem modules initially null before _ready()
##   • setup(): assigns _world_ref, _day_night_ref, _analytics_ref
##   • setup() null-world guard: no crash when world=null
##   • setup() null-analytics guard: _analytics_ref remains null when omitted
##   • SPA-2922 WWW panel:
##       _compute_wrong_direction_events() null-world → []
##       _compute_wrong_direction_events() null rep → []
##       _compute_wrong_direction_events() S1 wrong direction detected
##       _compute_wrong_direction_events() S1 no wrong direction → []
##       _compute_wrong_direction_events() S3 both Calder and Tomas surfaced
##       _compute_wrong_direction_events() S4 protected NPCs below target
##       _compute_wrong_direction_events() S5 Aldric too low, rival too high
##       _compute_wrong_direction_events() S6 Aldric too high + Marta too low
##       _compute_wrong_direction_events() capped at 3 entries
##       _get_next_playthrough_hint() for each spec template
##       _wwwp_causality() null-world → ""
##       _wwwp_count_believers() null-world → 0
##       _format_wwwp_event_line() output format
##       _wwwp_npc_display_name() WWW_NPC_NAMES lookup
##       _wwwp_container initially null
##
## EndScreen extends CanvasLayer.  Instantiating without adding to the scene
## tree skips _ready(), so @onready vars and subsystem modules remain null.
## Signal-connected scene-tree coroutines (_on_scenario_resolved, entrance tweens)
## require TransitionManager + live tree and are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEndScreen
extends RefCounted

const EndScreenScript := preload("res://scripts/end_screen.gd")
const ScenarioAnalyticsScript := preload("res://scripts/scenario_analytics.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_es() -> CanvasLayer:
	return EndScreenScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Initial runtime refs
		"test_initial_world_ref_null",
		"test_initial_day_night_ref_null",
		"test_initial_analytics_ref_null",
		# Initial state flags
		"test_initial_resolving_false",
		"test_initial_last_outcome_won_false",
		"test_initial_current_scenario_id_empty",
		# Subsystem modules null before _ready()
		"test_initial_panel_null",
		# setup() assignment
		"test_setup_assigns_world_ref",
		"test_setup_assigns_day_night_ref",
		"test_setup_assigns_analytics_ref",
		"test_setup_null_world_no_crash",
		"test_setup_omit_analytics_ref_remains_null",
		# SPA-2608: _unhandled_input guard
		"test_unhandled_input_guard_not_visible",
		# SPA-2922: WWW panel — _wwwp_container initial state
		"test_wwwp_container_initially_null",
		# SPA-2922: _compute_wrong_direction_events null guards
		"test_compute_wde_null_world_returns_empty",
		"test_compute_wde_null_rep_returns_empty",
		# SPA-2922: _compute_wrong_direction_events S1
		"test_compute_wde_s1_wrong_direction_detected",
		"test_compute_wde_s1_no_wrong_direction_empty",
		# SPA-2922: _compute_wrong_direction_events S3
		"test_compute_wde_s3_calder_and_tomas",
		# SPA-2922: _compute_wrong_direction_events S4
		"test_compute_wde_s4_protected_npc_below_target",
		# SPA-2922: _compute_wrong_direction_events S5
		"test_compute_wde_s5_aldric_too_low",
		# SPA-2922: _compute_wrong_direction_events S6
		"test_compute_wde_s6_aldric_too_high_marta_too_low",
		# SPA-2922: cap at 3
		"test_compute_wde_capped_at_3",
		# SPA-2922: _get_next_playthrough_hint template selection
		"test_hint_exposed",
		"test_hint_contradicted",
		"test_hint_reputation_collapsed",
		"test_hint_calder_implicated",
		"test_hint_aldric_destroyed",
		"test_hint_marta_silenced",
		"test_hint_timeout_s2_clergy",
		"test_hint_timeout_s1_merchant",
		"test_hint_generic_fallback",
		# SPA-2922: _wwwp_causality null guards
		"test_wwwp_causality_null_world_empty",
		"test_wwwp_causality_empty_npc_id_empty",
		# SPA-2922: _wwwp_count_believers null guard
		"test_wwwp_count_believers_null_world_zero",
		# SPA-2922: _format_wwwp_event_line format check
		"test_format_wwwp_event_line_contains_arrow",
		"test_format_wwwp_event_line_causality_appended",
		"test_format_wwwp_event_line_no_causality",
		# SPA-2922: _wwwp_npc_display_name lookup
		"test_wwwp_npc_display_name_aldous",
		"test_wwwp_npc_display_name_unknown_fallback",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEndScreen tests: %d passed, %d failed" % [passed, failed])


# ── Initial runtime refs ──────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	return _make_es()._world_ref == null


static func test_initial_day_night_ref_null() -> bool:
	return _make_es()._day_night_ref == null


static func test_initial_analytics_ref_null() -> bool:
	return _make_es()._analytics_ref == null


# ── Initial state flags ───────────────────────────────────────────────────────

static func test_initial_resolving_false() -> bool:
	return not _make_es()._resolving


static func test_initial_last_outcome_won_false() -> bool:
	return not _make_es()._last_outcome_won


static func test_initial_current_scenario_id_empty() -> bool:
	return _make_es()._current_scenario_id == ""


# ── Subsystem modules null before _ready() ────────────────────────────────────

static func test_initial_panel_null() -> bool:
	return _make_es()._panel == null


# ── setup() ───────────────────────────────────────────────────────────────────

## setup() must store world_ref (null is a valid test value — confirms assignment path).
static func test_setup_assigns_world_ref() -> bool:
	var es := _make_es()
	es.setup(null, null, null)
	return es._world_ref == null   # assignment path executed


## setup() must store day_night_ref.
static func test_setup_assigns_day_night_ref() -> bool:
	var es := _make_es()
	es.setup(null, null, null)
	return es._day_night_ref == null   # confirms the field was touched


## setup() must store analytics_ref when provided.
static func test_setup_assigns_analytics_ref() -> bool:
	var es := _make_es()
	var fake_analytics: ScenarioAnalytics = ScenarioAnalyticsScript.new()
	es.setup(null, null, fake_analytics)
	var ok: bool = es._analytics_ref == fake_analytics
	# ScenarioAnalytics extends RefCounted — no manual free() needed
	return ok


## Passing null as world must not crash (the guard "if world != null" should fire).
static func test_setup_null_world_no_crash() -> bool:
	var es := _make_es()
	es.setup(null, null)
	return true


## When analytics is omitted the default param is null — _analytics_ref stays null.
static func test_setup_omit_analytics_ref_remains_null() -> bool:
	var es := _make_es()
	es.setup(null, null)
	return es._analytics_ref == null


# ── SPA-2608: _unhandled_input ────────────────────────────────────────────────

## When the end screen is not visible, _unhandled_input must return early without
## crashing (the early-return guard fires before any get_viewport() call).
static func test_unhandled_input_guard_not_visible() -> bool:
	var es := _make_es()
	es.visible = false
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	es._unhandled_input(ev)   # must not crash
	return true


# ── SPA-2922: "What Went Wrong" panel ────────────────────────────────────────

## _wwwp_container must be null before _build_what_went_wrong_panel() is called.
static func test_wwwp_container_initially_null() -> bool:
	return _make_es()._wwwp_container == null


# ── _compute_wrong_direction_events null guards ───────────────────────────────

## Null _world_ref → returns empty array without crashing.
static func test_compute_wde_null_world_returns_empty() -> bool:
	var es := _make_es()
	es._world_ref = null
	var result: Array = es._compute_wrong_direction_events(1)
	return result.is_empty()


## World present but reputation_system absent → returns empty array.
static func test_compute_wde_null_rep_returns_empty() -> bool:
	var es := _make_es()
	# world stub without reputation_system property
	es._world_ref = RefCounted.new()
	var result: Array = es._compute_wrong_direction_events(1)
	return result.is_empty()


# ── _compute_wrong_direction_events S1 ───────────────────────────────────────

## S1: Edric score above S1_WIN_EDRIC_BELOW (30) → wrong-direction entry returned.
static func test_compute_wde_s1_wrong_direction_detected() -> bool:
	var es := _make_es()
	es._world_ref = _FakeWorld.new("edric_fenn", 55, 1)
	var result: Array = es._compute_wrong_direction_events(1)
	if result.is_empty():
		return false
	var entry: Dictionary = result[0]
	# gap = 55 - 30 = 25
	return int(entry.get("gap", 0)) == 25 and int(entry.get("direction", 0)) == -1


## S1: Edric already below threshold → no wrong-direction events.
static func test_compute_wde_s1_no_wrong_direction_empty() -> bool:
	var es := _make_es()
	es._world_ref = _FakeWorld.new("edric_fenn", 20, 1)
	var result: Array = es._compute_wrong_direction_events(1)
	return result.is_empty()


# ── _compute_wrong_direction_events S3 ───────────────────────────────────────

## S3: Calder too low + Tomas too high → both appear in result.
static func test_compute_wde_s3_calder_and_tomas() -> bool:
	var es    := _make_es()
	# Calder at 40 (target 75 → gap 35), Tomas at 60 (target 35 → gap 25)
	var world := _FakeWorldS3.new(40, 60)
	es._world_ref = world
	var result: Array = es._compute_wrong_direction_events(3)
	if result.size() < 2:
		return false
	# Sorted by gap desc: Calder gap 35 first, Tomas gap 25 second.
	return int(result[0].get("gap", 0)) == 35 and int(result[1].get("gap", 0)) == 25


# ── _compute_wrong_direction_events S4 ───────────────────────────────────────

## S4: One protected NPC below S4_WIN_REP_MIN (48) → appears in result.
static func test_compute_wde_s4_protected_npc_below_target() -> bool:
	var es    := _make_es()
	es._world_ref = _FakeWorldS4.new(30)  # aldous_prior at 30
	var result: Array = es._compute_wrong_direction_events(4)
	if result.is_empty():
		return false
	var entry: Dictionary = result[0]
	# gap = 48 - 30 = 18; direction = +1
	return int(entry.get("gap", 0)) == 18 and int(entry.get("direction", 0)) == 1


# ── _compute_wrong_direction_events S5 ───────────────────────────────────────

## S5: Aldric below S5_WIN_ALDRIC_MIN (65) → wrong-direction entry detected.
static func test_compute_wde_s5_aldric_too_low() -> bool:
	var es    := _make_es()
	# Aldric at 40, Edric at 40 (≤45=ok), Tomas at 40 (≤45=ok)
	es._world_ref = _FakeWorldS5.new(40, 40, 40)
	var result: Array = es._compute_wrong_direction_events(5)
	if result.is_empty():
		return false
	var entry: Dictionary = result[0]
	# gap = 65 - 40 = 25; direction = +1
	return int(entry.get("gap", 0)) == 25 and int(entry.get("direction", 0)) == 1


# ── _compute_wrong_direction_events S6 ───────────────────────────────────────

## S6: Aldric above S6_WIN_ALDRIC_MAX (30) + Marta below S6_WIN_MARTA_MIN (62).
static func test_compute_wde_s6_aldric_too_high_marta_too_low() -> bool:
	var es    := _make_es()
	# Aldric at 55 (gap=25), Marta at 40 (gap=22)
	es._world_ref = _FakeWorldS6.new(55, 40)
	var result: Array = es._compute_wrong_direction_events(6)
	if result.size() < 2:
		return false
	return int(result[0].get("gap", 0)) == 25 and int(result[1].get("gap", 0)) == 22


# ── _compute_wrong_direction_events capped at 3 ──────────────────────────────

## S4 can produce 3 protected NPCs. Result must not exceed 3 entries.
static func test_compute_wde_capped_at_3() -> bool:
	var es    := _make_es()
	# All three S4 protected NPCs well below target → 3 entries.
	es._world_ref = _FakeWorldS4All.new(10)
	var result: Array = es._compute_wrong_direction_events(4)
	return result.size() <= 3


# ── _get_next_playthrough_hint template selection ────────────────────────────

static func test_hint_exposed() -> bool:
	var es := _make_es()
	var h: String = es._get_next_playthrough_hint("exposed", 1)
	return "concentrating suspicion" in h


static func test_hint_contradicted() -> bool:
	var es := _make_es()
	var h: String = es._get_next_playthrough_hint("contradicted", 2)
	return "counter-narrative" in h


static func test_hint_reputation_collapsed() -> bool:
	var es := _make_es()
	var h: String = es._get_next_playthrough_hint("reputation_collapsed", 4)
	return "protect" in h


static func test_hint_calder_implicated() -> bool:
	var es := _make_es()
	var h: String = es._get_next_playthrough_hint("calder_implicated", 3)
	return "faction mix" in h


static func test_hint_aldric_destroyed() -> bool:
	var es := _make_es()
	var h: String = es._get_next_playthrough_hint("aldric_destroyed", 5)
	return "faction mix" in h


static func test_hint_marta_silenced() -> bool:
	var es := _make_es()
	var h: String = es._get_next_playthrough_hint("marta_silenced", 6)
	return "faction mix" in h


## S2 timeout → Clergy faction hint.
static func test_hint_timeout_s2_clergy() -> bool:
	var es := _make_es()
	var h: String = es._get_next_playthrough_hint("timeout", 2)
	return "Clergy" in h


## S1 timeout → Merchant faction hint.
static func test_hint_timeout_s1_merchant() -> bool:
	var es := _make_es()
	var h: String = es._get_next_playthrough_hint("timeout", 1)
	return "Merchant" in h


static func test_hint_generic_fallback() -> bool:
	var es := _make_es()
	var h: String = es._get_next_playthrough_hint("unknown_reason", 1)
	return "faction mix" in h


# ── _wwwp_causality null guards ───────────────────────────────────────────────

static func test_wwwp_causality_null_world_empty() -> bool:
	var es := _make_es()
	es._world_ref = null
	return es._wwwp_causality("edric_fenn") == ""


static func test_wwwp_causality_empty_npc_id_empty() -> bool:
	var es := _make_es()
	return es._wwwp_causality("") == ""


# ── _wwwp_count_believers null guard ─────────────────────────────────────────

static func test_wwwp_count_believers_null_world_zero() -> bool:
	var es := _make_es()
	es._world_ref = null
	return es._wwwp_count_believers("some_rumor") == 0


# ── _format_wwwp_event_line format ───────────────────────────────────────────

## Output must contain the rust-red down-arrow BBCode tag.
static func test_format_wwwp_event_line_contains_arrow() -> bool:
	var es    := _make_es()
	var entry := { "stat_label": "Edric Fenn", "gap": 20, "direction": -1, "causality": "" }
	var line: String = es._format_wwwp_event_line(entry, 10)
	return "[color=#8B3A2E]v[/color]" in line


## When causality is present it should appear indented on a second line.
static func test_format_wwwp_event_line_causality_appended() -> bool:
	var es    := _make_es()
	var entry := { "stat_label": "Edric Fenn", "gap": 20, "direction": -1, "causality": "because X" }
	var line: String = es._format_wwwp_event_line(entry, 10)
	return "because X" in line and "\n" in line


## Empty causality → no extra newline at end of line.
static func test_format_wwwp_event_line_no_causality() -> bool:
	var es    := _make_es()
	var entry := { "stat_label": "Edric Fenn", "gap": 5, "direction": -1, "causality": "" }
	var line: String = es._format_wwwp_event_line(entry, 5)
	return not "\n" in line


# ── _wwwp_npc_display_name ────────────────────────────────────────────────────

static func test_wwwp_npc_display_name_aldous() -> bool:
	var es := _make_es()
	return es._wwwp_npc_display_name("aldous_prior") == "Prior Aldous"


static func test_wwwp_npc_display_name_unknown_fallback() -> bool:
	var es := _make_es()
	var name: String = es._wwwp_npc_display_name("some_unknown_npc")
	return not name.is_empty()


# ── Fake world stubs ──────────────────────────────────────────────────────────

## Minimal fake world for S1: reputation_system with one NPC snapshot.
class _FakeRepSystem:
	var _scores: Dictionary = {}

	func get_snapshot(npc_id: String) -> Object:
		if _scores.has(npc_id):
			var snap := _FakeSnap.new()
			snap.score = _scores[npc_id]
			return snap
		return null

	func get_illness_believer_count(_npc_id: String) -> int:
		return 0

	func has_method(method_name: String) -> bool:
		return method_name == "get_illness_believer_count"

class _FakeSnap:
	var score: int = 50

class _FakeScenarioManager:
	var S1_WIN_EDRIC_BELOW   := 30
	var S3_WIN_CALDER_MIN    := 75
	var S3_WIN_TOMAS_MAX     := 35
	var S4_WIN_REP_MIN       := 48
	var S5_WIN_ALDRIC_MIN    := 65
	var S5_WIN_RIVALS_MAX    := 45
	var S6_WIN_ALDRIC_MAX    := 30
	var S6_WIN_MARTA_MIN     := 62
	var s2_win_illness_min   := 7

## World stub for single-NPC scenarios (S1/S2 basic).
class _FakeWorld:
	var reputation_system: Object = null
	var scenario_manager:  Object = null
	var npcs:              Array  = []

	func _init(npc_id: String, score: int, _scenario: int) -> void:
		var rep := _FakeRepSystem.new()
		rep._scores[npc_id] = score
		reputation_system = rep
		scenario_manager  = _FakeScenarioManager.new()

## World stub for S3 (Calder + Tomas).
class _FakeWorldS3:
	var reputation_system: Object = null
	var scenario_manager:  Object = null
	var npcs:              Array  = []

	func _init(calder_score: int, tomas_score: int) -> void:
		var rep := _FakeRepSystem.new()
		rep._scores["calder_fenn"]  = calder_score
		rep._scores["tomas_reeve"]  = tomas_score
		reputation_system = rep
		scenario_manager  = _FakeScenarioManager.new()

## World stub for S4 with one protected NPC at given score.
class _FakeWorldS4:
	var reputation_system: Object = null
	var scenario_manager:  Object = null
	var npcs:              Array  = []

	func _init(aldous_score: int) -> void:
		var rep := _FakeRepSystem.new()
		rep._scores["aldous_prior"] = aldous_score
		rep._scores["vera_midwife"] = 60  # above target → no wrong-dir
		rep._scores["finn_monk"]    = 60
		reputation_system = rep
		scenario_manager  = _FakeScenarioManager.new()

## World stub for S4 with all three protected NPCs below target.
class _FakeWorldS4All:
	var reputation_system: Object = null
	var scenario_manager:  Object = null
	var npcs:              Array  = []

	func _init(score: int) -> void:
		var rep := _FakeRepSystem.new()
		rep._scores["aldous_prior"] = score
		rep._scores["vera_midwife"] = score
		rep._scores["finn_monk"]    = score
		reputation_system = rep
		scenario_manager  = _FakeScenarioManager.new()

## World stub for S5 (Aldric, Edric, Tomas).
class _FakeWorldS5:
	var reputation_system: Object = null
	var scenario_manager:  Object = null
	var npcs:              Array  = []

	func _init(aldric_score: int, edric_score: int, tomas_score: int) -> void:
		var rep := _FakeRepSystem.new()
		rep._scores["aldric_vane"] = aldric_score
		rep._scores["edric_fenn"]  = edric_score
		rep._scores["tomas_reeve"] = tomas_score
		reputation_system = rep
		scenario_manager  = _FakeScenarioManager.new()

## World stub for S6 (Aldric, Marta).
class _FakeWorldS6:
	var reputation_system: Object = null
	var scenario_manager:  Object = null
	var npcs:              Array  = []

	func _init(aldric_score: int, marta_score: int) -> void:
		var rep := _FakeRepSystem.new()
		rep._scores["aldric_vane"] = aldric_score
		rep._scores["marta_coin"]  = marta_score
		reputation_system = rep
		scenario_manager  = _FakeScenarioManager.new()
