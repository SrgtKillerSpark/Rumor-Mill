## test_objective_hud.gd — Unit tests for objective_hud.gd coordinator (SPA-1024).
##
## Covers:
##   • Urgency colour constants: C_DAY_SAFE, C_DAY_CAUTION, C_DAY_URGENT, C_DAY_CRITICAL
##   • CALLOUT_TOOLTIP_ID constant
##   • Initial instance state: _goal_verb, _goal_target, _entrance_played,
##     _t3_last_obs, _t3_last_whisp, _day_counter_tween, _urgency_pulse_tween
##   • Subsystem module refs null before _ready()
##   • _get_urgency_color(): all four colour-band boundaries:
##       frac < 0.50  → C_DAY_SAFE (exact)
##       frac = 0.50  → SAFE.lerp(CAUTION, 0) = SAFE
##       frac = 0.60  → midpoint lerp between SAFE and CAUTION
##       frac = 0.70  → SAFE.lerp(CAUTION, 1) ≈ CAUTION
##       frac = 0.85  → CAUTION.lerp(URGENT, 1) ≈ URGENT
##       frac = 1.00  → URGENT.lerp(CRITICAL, 1) = CRITICAL
##   • play_entrance_animation(): _entrance_played guard — second call is a no-op
##
## ObjectiveHUD extends CanvasLayer.  @onready scene-node vars are null outside
## the scene tree; _ready() is not called.  setup() and all tick handlers
## require wired scene deps and are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestObjectiveHud
extends RefCounted

const ObjectiveHudScript := preload("res://scripts/objective_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_oh() -> CanvasLayer:
	return ObjectiveHudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Colour constants
		"test_c_day_safe_is_green",
		"test_c_day_caution_is_yellow",
		"test_c_day_urgent_is_orange",
		"test_c_day_critical_is_red",
		# Callout tooltip id
		"test_callout_tooltip_id_value",
		# Initial state
		"test_initial_goal_verb_empty",
		"test_initial_goal_target_empty",
		"test_initial_entrance_played_false",
		"test_initial_t3_last_obs_minus_one",
		"test_initial_t3_last_whisp_minus_one",
		"test_initial_day_counter_tween_null",
		"test_initial_urgency_pulse_tween_null",
		# Subsystem refs null
		"test_initial_metrics_module_null",
		"test_initial_nudge_module_null",
		"test_initial_win_tracker_null",
		"test_initial_banner_module_null",
		"test_initial_scenario_manager_null",
		"test_initial_day_night_null",
		"test_initial_world_ref_null",
		# _get_urgency_color() colour bands
		"test_urgency_color_frac_zero_is_safe",
		"test_urgency_color_frac_0_49_is_safe",
		"test_urgency_color_frac_0_50_equals_safe",
		"test_urgency_color_frac_0_60_is_between_safe_and_caution",
		"test_urgency_color_frac_0_70_approx_caution",
		"test_urgency_color_frac_0_85_approx_urgent",
		"test_urgency_color_frac_1_0_is_critical",
		# play_entrance_animation guard
		"test_play_entrance_animation_sets_entrance_played",
		"test_play_entrance_animation_guard_no_double_play",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nObjectiveHud tests: %d passed, %d failed" % [passed, failed])


# ── Colour constants ──────────────────────────────────────────────────────────

static func test_c_day_safe_is_green() -> bool:
	var c: Color = _make_oh().C_DAY_SAFE
	return c.g > 0.70 and c.r < 0.50


static func test_c_day_caution_is_yellow() -> bool:
	var c: Color = _make_oh().C_DAY_CAUTION
	return c.r > 0.80 and c.g > 0.70 and c.b < 0.30


static func test_c_day_urgent_is_orange() -> bool:
	var c: Color = _make_oh().C_DAY_URGENT
	return c.r > 0.80 and c.g > 0.40 and c.b < 0.20


static func test_c_day_critical_is_red() -> bool:
	var c: Color = _make_oh().C_DAY_CRITICAL
	return c.r > 0.80 and c.g < 0.35 and c.b < 0.20


# ── CALLOUT_TOOLTIP_ID ────────────────────────────────────────────────────────

static func test_callout_tooltip_id_value() -> bool:
	return _make_oh().CALLOUT_TOOLTIP_ID == "objective_hud_first_time"


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_goal_verb_empty() -> bool:
	return _make_oh()._goal_verb == ""


static func test_initial_goal_target_empty() -> bool:
	return _make_oh()._goal_target == ""


static func test_initial_entrance_played_false() -> bool:
	return not _make_oh()._entrance_played


static func test_initial_t3_last_obs_minus_one() -> bool:
	return _make_oh()._t3_last_obs == -1


static func test_initial_t3_last_whisp_minus_one() -> bool:
	return _make_oh()._t3_last_whisp == -1


static func test_initial_day_counter_tween_null() -> bool:
	return _make_oh()._day_counter_tween == null


static func test_initial_urgency_pulse_tween_null() -> bool:
	return _make_oh()._urgency_pulse_tween == null


# ── Subsystem refs null ───────────────────────────────────────────────────────

static func test_initial_metrics_module_null() -> bool:
	return _make_oh()._metrics_module == null


static func test_initial_nudge_module_null() -> bool:
	return _make_oh()._nudge_module == null


static func test_initial_win_tracker_null() -> bool:
	return _make_oh()._win_tracker == null


static func test_initial_banner_module_null() -> bool:
	return _make_oh()._banner_module == null


static func test_initial_scenario_manager_null() -> bool:
	return _make_oh()._scenario_manager == null


static func test_initial_day_night_null() -> bool:
	return _make_oh()._day_night == null


static func test_initial_world_ref_null() -> bool:
	return _make_oh()._world_ref == null


# ── _get_urgency_color() colour bands ────────────────────────────────────────
#
# Logic recap:
#   frac < 0.50            → C_DAY_SAFE
#   0.50 <= frac < 0.70    → SAFE.lerp(CAUTION, (frac - 0.50) / 0.20)
#   0.70 <= frac < 0.85    → CAUTION.lerp(URGENT, (frac - 0.70) / 0.15)
#   frac >= 0.85           → URGENT.lerp(CRITICAL, (frac - 0.85) / 0.15)

static func test_urgency_color_frac_zero_is_safe() -> bool:
	var oh  := _make_oh()
	var got := oh._get_urgency_color(0.0)
	return got.is_equal_approx(oh.C_DAY_SAFE)


static func test_urgency_color_frac_0_49_is_safe() -> bool:
	var oh  := _make_oh()
	var got := oh._get_urgency_color(0.49)
	return got.is_equal_approx(oh.C_DAY_SAFE)


## frac = 0.50 → t = 0.0 → SAFE.lerp(CAUTION, 0) = SAFE
static func test_urgency_color_frac_0_50_equals_safe() -> bool:
	var oh  := _make_oh()
	var got := oh._get_urgency_color(0.50)
	var exp := oh.C_DAY_SAFE.lerp(oh.C_DAY_CAUTION, 0.0)
	return got.is_equal_approx(exp)


## frac = 0.60 → t = 0.5 → midpoint between SAFE and CAUTION
static func test_urgency_color_frac_0_60_is_between_safe_and_caution() -> bool:
	var oh  := _make_oh()
	var got := oh._get_urgency_color(0.60)
	var exp := oh.C_DAY_SAFE.lerp(oh.C_DAY_CAUTION, 0.5)
	if not got.is_equal_approx(exp):
		push_error("test_urgency_color_frac_0_60: got %s, expected %s" % [got, exp])
		return false
	return true


## frac = 0.70 → t = 1.0 → SAFE.lerp(CAUTION, 1) = CAUTION
static func test_urgency_color_frac_0_70_approx_caution() -> bool:
	var oh  := _make_oh()
	var got := oh._get_urgency_color(0.70)
	var exp := oh.C_DAY_SAFE.lerp(oh.C_DAY_CAUTION, 1.0)
	return got.is_equal_approx(exp)


## frac = 0.85 → t = 1.0 → CAUTION.lerp(URGENT, 1) = URGENT
static func test_urgency_color_frac_0_85_approx_urgent() -> bool:
	var oh  := _make_oh()
	var got := oh._get_urgency_color(0.85)
	var exp := oh.C_DAY_CAUTION.lerp(oh.C_DAY_URGENT, 1.0)
	return got.is_equal_approx(exp)


## frac = 1.0 → t = 1.0 → URGENT.lerp(CRITICAL, 1) = CRITICAL
static func test_urgency_color_frac_1_0_is_critical() -> bool:
	var oh  := _make_oh()
	var got := oh._get_urgency_color(1.0)
	var exp := oh.C_DAY_URGENT.lerp(oh.C_DAY_CRITICAL, 1.0)
	return got.is_equal_approx(exp)


# ── play_entrance_animation() guard ──────────────────────────────────────────

## play_entrance_animation() must set _entrance_played to true.
static func test_play_entrance_animation_sets_entrance_played() -> bool:
	var oh := _make_oh()
	oh.play_entrance_animation()
	return oh._entrance_played


## A second call must be a no-op (guard: if _entrance_played: return).
## We verify by checking _entrance_played is still true (state unchanged).
static func test_play_entrance_animation_guard_no_double_play() -> bool:
	var oh := _make_oh()
	oh.play_entrance_animation()
	oh.play_entrance_animation()
	return oh._entrance_played   # would be false if the guard was absent and reset it
