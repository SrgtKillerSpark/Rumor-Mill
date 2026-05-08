## test_spa1984_win_probability_hud.gd — GUT regression for the SPA-1984
## Apprentice win-probability forecast widget (SPA-2043).
##
## Coverage matrix (4 assertion classes):
##
##   A. Forecast widget appears only on Apprentice difficulty (gated)
##      • _win_forecast_lbl is null before _build_ui() — widget not pre-created.
##      • After _build_ui() the label starts hidden (visible = false).
##      • _update_win_forecast() makes the label visible on Apprentice when the
##        game is still in progress and count < threshold.
##
##   B. Probability value updates on day-tick and on score change
##      • compute_win_forecast() returns "on_track" with many days remaining
##        but switches to "tight" / "unlikely" as days_allowed - current_day
##        shrinks (day-tick advance simulation).
##      • compute_win_forecast() returns "on_track" when count approaches
##        threshold and "unlikely" when count is far behind (score change).
##
##   C. Probability range stays in [0.0, 1.0] across synthetic states
##      • AVG_PROPAGATION_RATE is in (0.0, 1.0] — the constant itself bounds
##        the implied probability.
##      • compute_win_forecast() never returns a value outside the valid set
##        {"on_track", "tight", "unlikely"} across 10+ synthetic state vectors.
##
##   D. Widget hides correctly on non-Apprentice difficulty (negative tests)
##      • _update_win_forecast() leaves _win_forecast_lbl.visible = false on
##        "normal" difficulty.
##      • _update_win_forecast() leaves _win_forecast_lbl.visible = false on
##        "master" difficulty.
##
## All tests run headlessly — no live scene tree required.
## _build_ui() is called explicitly where the label node must exist; it uses
## only Panel/Label/VBoxContainer/HBoxContainer nodes and is safe without a
## viewport (same pattern as TestSpa1822EndScreenShipRegression).
## GameState.selected_difficulty is a plain String var on the autoload and is
## restored after each test that mutates it.
## Tests that call _update_win_forecast() create a local ScenarioManager.new()
## instance (sm: ScenarioManager typed parameter — the class itself is rejected
## at runtime in headless context). ScenarioManager._days_allowed defaults to
## 30, which is ample for all gating tests.

class_name TestSpa1984WinProbabilityHud
extends RefCounted

const Scenario2HudScript := preload("res://scripts/scenario2_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return Scenario2HudScript.new()


## HUD with _build_ui() already run — _win_forecast_lbl will be non-null.
static func _make_hud_with_ui() -> CanvasLayer:
	var h := Scenario2HudScript.new()
	h._build_ui()
	return h


static func _valid_forecast_results() -> Array:
	return ["on_track", "tight", "unlikely"]


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# A. Gating — widget appears only on Apprentice
		"test_a1_forecast_lbl_null_before_build",
		"test_a2_forecast_lbl_hidden_after_build",
		"test_a3_forecast_lbl_visible_on_apprentice",
		# B. Value updates on day-tick and score change
		"test_b1_forecast_on_track_early_game",
		"test_b2_forecast_tightens_as_days_dwindle",
		"test_b3_forecast_unlikely_when_no_days_left",
		"test_b4_forecast_on_track_when_count_near_threshold",
		"test_b5_forecast_unlikely_when_count_far_behind",
		# C. Probability range stays valid across synthetic states
		"test_c1_avg_propagation_rate_in_unit_interval",
		"test_c2_forecast_range_all_valid_strings",
		"test_c3_forecast_already_won_returns_on_track",
		"test_c4_forecast_zero_seeds_returns_unlikely",
		"test_c5_forecast_exact_capacity_match_on_track",
		"test_c6_forecast_just_below_60pct_returns_unlikely",
		# D. Widget hides on non-Apprentice difficulty
		"test_d1_forecast_hidden_on_normal_difficulty",
		"test_d2_forecast_hidden_on_master_difficulty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-1984 WinProbabilityHud tests: %d passed, %d failed" % [passed, failed])


# ── A. Gating — widget appears only on Apprentice ─────────────────────────────

## _win_forecast_lbl must be null before _build_ui() — the label is not
## pre-initialised at class level, only created during UI construction.
static func test_a1_forecast_lbl_null_before_build() -> bool:
	var h := _make_hud()
	var ok: bool = h._win_forecast_lbl == null
	h.free()
	return ok


## After _build_ui() the label must exist but start hidden — it is only shown
## once _update_win_forecast() confirms Apprentice difficulty and active play.
static func test_a2_forecast_lbl_hidden_after_build() -> bool:
	var h := _make_hud_with_ui()
	if h._win_forecast_lbl == null:
		push_error("test_a2: _win_forecast_lbl null after _build_ui()")
		h.free()
		return false
	var ok: bool = h._win_forecast_lbl.visible == false
	h.free()
	return ok


## On Apprentice difficulty with count < threshold and game still active,
## _update_win_forecast() must make _win_forecast_lbl visible.
## Uses a local ScenarioManager.new() instance (sm: ScenarioManager typed param).
## _days_allowed defaults to 30; _day_night_ref is null → day 1; _world_ref is
## null → whispers = 0. effective_seeds = min(29, 0) = 0 → projected = 0 →
## "unlikely" label text, but the label IS shown (Apprentice gate passed).
func test_a3_forecast_lbl_visible_on_apprentice() -> bool:
	var h := _make_hud_with_ui()
	if h._win_forecast_lbl == null:
		push_error("test_a3: _win_forecast_lbl null after _build_ui()")
		h.free()
		return false
	var saved_diff: String = GameState.selected_difficulty
	GameState.selected_difficulty = "apprentice"
	var sm_a3 := ScenarioManager.new()
	h._update_win_forecast(2, 7, sm_a3, ScenarioManager.ScenarioState.ACTIVE)
	sm_a3.free()
	var ok: bool = h._win_forecast_lbl.visible == true
	GameState.selected_difficulty = saved_diff
	h.free()
	return ok


# ── B. Value updates on day-tick and score change ─────────────────────────────

## Early game: plenty of days and whisper tokens relative to remaining targets.
## count=2, threshold=7, current_day=1, days_allowed=24, whispers=10
## remaining_targets=5, remaining_days=23, effective_seeds=10
## projected=7.0 ≥ 5 → "on_track"
static func test_b1_forecast_on_track_early_game() -> bool:
	var h := _make_hud()
	var result: String = h.compute_win_forecast(2, 7, 1, 24, 10)
	var ok: bool = result == "on_track"
	if not ok:
		push_error("test_b1: expected 'on_track', got '%s'" % result)
	h.free()
	return ok


## Day-tick simulation: same parameters but day advanced to 21 → only 3 days left.
## remaining_targets=5, remaining_days=3, effective_seeds=3
## projected=2.1; 2.1 < 5 and 2.1 < 5*0.6=3.0 → "unlikely"
## (demonstrates value changes as current_day increases)
static func test_b2_forecast_tightens_as_days_dwindle() -> bool:
	var h := _make_hud()
	var result: String = h.compute_win_forecast(2, 7, 21, 24, 10)
	var ok: bool = result == "unlikely"
	if not ok:
		push_error("test_b2: expected 'unlikely' at day 21, got '%s'" % result)
	h.free()
	return ok


## Day-tick simulation: last day (current_day == days_allowed) → 0 days remaining.
## effective_seeds=0, projected=0.0 < any remaining_targets → "unlikely"
static func test_b3_forecast_unlikely_when_no_days_left() -> bool:
	var h := _make_hud()
	var result: String = h.compute_win_forecast(4, 7, 24, 24, 10)
	var ok: bool = result == "unlikely"
	if not ok:
		push_error("test_b3: expected 'unlikely' at last day, got '%s'" % result)
	h.free()
	return ok


## Score-change simulation: count rises to 6 (one short of win) with 5 days left.
## remaining_targets=1, remaining_days=5, effective_seeds=5
## projected=3.5 ≥ 1 → "on_track"
static func test_b4_forecast_on_track_when_count_near_threshold() -> bool:
	var h := _make_hud()
	var result: String = h.compute_win_forecast(6, 7, 19, 24, 5)
	var ok: bool = result == "on_track"
	if not ok:
		push_error("test_b4: expected 'on_track' when one believer short, got '%s'" % result)
	h.free()
	return ok


## Score-change simulation: count=1 very far behind with few whispers.
## remaining_targets=6, remaining_days=10, effective_seeds=2
## projected=1.4; 1.4 < 6*0.6=3.6 → "unlikely"
static func test_b5_forecast_unlikely_when_count_far_behind() -> bool:
	var h := _make_hud()
	var result: String = h.compute_win_forecast(1, 7, 14, 24, 2)
	var ok: bool = result == "unlikely"
	if not ok:
		push_error("test_b5: expected 'unlikely' with count far behind, got '%s'" % result)
	h.free()
	return ok


# ── C. Probability range across synthetic states ──────────────────────────────

## AVG_PROPAGATION_RATE must be in (0.0, 1.0] — the constant bounds the implied
## probability so the forecast can never claim more than 100% propagation.
static func test_c1_avg_propagation_rate_in_unit_interval() -> bool:
	var h := _make_hud()
	var rate: float = h.AVG_PROPAGATION_RATE
	var ok: bool = rate > 0.0 and rate <= 1.0
	if not ok:
		push_error("test_c1: AVG_PROPAGATION_RATE=%f not in (0.0, 1.0]" % rate)
	h.free()
	return ok


## Sweep 10 synthetic (count, threshold, day, days_allowed, whispers) vectors and
## assert every result is one of {"on_track", "tight", "unlikely"}.
## This guards against any future change that might introduce an invalid return.
static func test_c2_forecast_range_all_valid_strings() -> bool:
	var h := _make_hud()
	var valid := _valid_forecast_results()
	var states: Array = [
		[0, 7, 1, 24, 10],   # fresh start, plenty of resources
		[3, 7, 8, 24, 5],    # mid-game, moderate resources
		[5, 7, 18, 24, 8],   # late game, on track
		[5, 7, 22, 24, 2],   # late game, constrained
		[6, 7, 23, 24, 1],   # one shy of win, last days
		[0, 7, 24, 24, 10],  # last day, no time
		[7, 7, 10, 24, 5],   # already won
		[1, 7, 1, 24, 0],    # whisper-constrained (no tokens)
		[4, 7, 21, 24, 3],   # tight window (B-class tight example)
		[2, 7, 14, 24, 0],   # mid-game, zero whispers
	]
	for s in states:
		var result: String = h.compute_win_forecast(s[0], s[1], s[2], s[3], s[4])
		if result not in valid:
			push_error("test_c2: invalid result '%s' for state %s" % [result, str(s)])
			h.free()
			return false
	h.free()
	return true


## count >= threshold means remaining_targets = 0 → player already at win
## condition; function must short-circuit to "on_track".
static func test_c3_forecast_already_won_returns_on_track() -> bool:
	var h := _make_hud()
	var result: String = h.compute_win_forecast(7, 7, 10, 24, 5)
	var ok: bool = result == "on_track"
	if not ok:
		push_error("test_c3: expected 'on_track' when count==threshold, got '%s'" % result)
	h.free()
	return ok


## Zero effective seeds (whisper_tokens=0 and remaining_days=0) → projected=0.0.
## Any remaining_targets > 0 makes this "unlikely" — floor of range.
static func test_c4_forecast_zero_seeds_returns_unlikely() -> bool:
	var h := _make_hud()
	var result: String = h.compute_win_forecast(4, 7, 24, 24, 0)
	var ok: bool = result == "unlikely"
	if not ok:
		push_error("test_c4: expected 'unlikely' with zero seeds, got '%s'" % result)
	h.free()
	return ok


## Exact capacity: effective_seeds * AVG_PROPAGATION_RATE == remaining_targets.
## remaining_targets=7, AVG_PROPAGATION_RATE=0.7, so effective_seeds=10.
## projected=7.0 ≥ 7 → "on_track" (boundary at ceiling).
static func test_c5_forecast_exact_capacity_match_on_track() -> bool:
	var h := _make_hud()
	# 0 believers, threshold=7: need 7. 10 seeds * 0.7 = 7.0 ≥ 7 → on_track.
	var result: String = h.compute_win_forecast(0, 7, 14, 24, 10)
	var ok: bool = result == "on_track"
	if not ok:
		push_error("test_c5: expected 'on_track' at exact capacity, got '%s'" % result)
	h.free()
	return ok


## Just below the 60% tight threshold → "unlikely".
## remaining_targets=5, need 60% = 3.0. effective_seeds=4, projected=2.8 < 3.0 → "unlikely".
static func test_c6_forecast_just_below_60pct_returns_unlikely() -> bool:
	var h := _make_hud()
	# remaining_targets=5, whisper_tokens=4, remaining_days=20
	# effective_seeds=4, projected=2.8; 2.8 < 5*0.6=3.0 → unlikely
	var result: String = h.compute_win_forecast(2, 7, 4, 24, 4)
	var ok: bool = result == "unlikely"
	if not ok:
		push_error("test_c6: expected 'unlikely' just below 60%% threshold, got '%s'" % result)
	h.free()
	return ok


# ── D. Widget hides on non-Apprentice difficulty ──────────────────────────────

## On "normal" difficulty, _update_win_forecast() must leave the label hidden
## regardless of game state or believer count.
## Uses a local ScenarioManager.new() instance to satisfy sm: ScenarioManager typing.
func test_d1_forecast_hidden_on_normal_difficulty() -> bool:
	var h := _make_hud_with_ui()
	if h._win_forecast_lbl == null:
		push_error("test_d1: _win_forecast_lbl null after _build_ui()")
		h.free()
		return false
	# Pre-show the label so the test can confirm it is hidden, not just left as-is.
	h._win_forecast_lbl.visible = true
	var saved_diff: String = GameState.selected_difficulty
	GameState.selected_difficulty = "normal"
	var sm_d1 := ScenarioManager.new()
	h._update_win_forecast(2, 7, sm_d1, ScenarioManager.ScenarioState.ACTIVE)
	sm_d1.free()
	var ok: bool = h._win_forecast_lbl.visible == false
	if not ok:
		push_error("test_d1: _win_forecast_lbl still visible on 'normal' difficulty")
	GameState.selected_difficulty = saved_diff
	h.free()
	return ok


## On "master" difficulty (the default), the forecast must also stay hidden.
## Uses a local ScenarioManager.new() instance to satisfy sm: ScenarioManager typing.
func test_d2_forecast_hidden_on_master_difficulty() -> bool:
	var h := _make_hud_with_ui()
	if h._win_forecast_lbl == null:
		push_error("test_d2: _win_forecast_lbl null after _build_ui()")
		h.free()
		return false
	h._win_forecast_lbl.visible = true
	var saved_diff: String = GameState.selected_difficulty
	GameState.selected_difficulty = "master"
	var sm_d2 := ScenarioManager.new()
	h._update_win_forecast(2, 7, sm_d2, ScenarioManager.ScenarioState.ACTIVE)
	sm_d2.free()
	var ok: bool = h._win_forecast_lbl.visible == false
	if not ok:
		push_error("test_d2: _win_forecast_lbl still visible on 'master' difficulty")
	GameState.selected_difficulty = saved_diff
	h.free()
	return ok
