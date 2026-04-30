extends BaseScenarioHud

## scenario3_hud.gd — Persistent dual-track reputation progress display.
##
## Shows a thin header at the top of the screen tracking Calder Fenn and
## Tomas Reeve's reputation scores against their Scenario 3 win targets.
##
## Layout:
##   [Calder Fenn]  Rep: 62 / 100  Target: 75+   [progress bar]
##   [Tomas Reeve]  Rep: 44 / 100  Target: ≤35   [decay bar]
##   Days remaining: 18
##
## Wire via setup(world, day_night) from main.gd.

const BAR_WIDTH  := 160

# ── Node refs ────────────────────────────────────────────────────────────────
var _calder_score_lbl: Label     = null
var _tomas_score_lbl:  Label     = null
var _calder_bar:       ColorRect = null
var _calder_bar_bg:    ColorRect = null
var _tomas_bar:        ColorRect = null
var _tomas_bar_bg:     ColorRect = null
var _rival_lbl:        Label     = null
var _disrupt_btn:      Button    = null
## SPA-868: Scout rival button and scouted target display.
var _scout_btn:        Button    = null
var _scout_lbl:        Label     = null
## SPA-868: Belief degradation activity label.
var _degrade_lbl:      Label     = null


func _scenario_number() -> int:
	return 3


func _on_setup_extra(world: Node2D) -> void:
	var rival = world.get("rival_agent") if world != null else null
	if rival != null:
		rival.rival_acted.connect(notify_rival_acted)
		rival.rival_disrupted.connect(notify_rival_disrupted)
		# SPA-868: belief degradation notification.
		rival.belief_degraded.connect(notify_belief_degraded)


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var hbox := _make_panel("Scenario3Panel", 62)

	# Scenario label.
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 3:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	hbox.add_child(title_lbl)

	# Calder track.
	var calder_vbox := VBoxContainer.new()
	calder_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(calder_vbox)

	_calder_score_lbl = Label.new()
	_calder_score_lbl.add_theme_font_size_override("font_size", 14)
	_calder_score_lbl.add_theme_color_override("font_color", C_BODY)
	_calder_score_lbl.text = "Calder Fenn  Rep: 50 / 100  Target: 75+"
	_calder_score_lbl.tooltip_text = "Calder Fenn's reputation. Win condition: raise to 75 or higher."
	_calder_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_calder_score_lbl.clip_text = true
	_apply_text_outline(_calder_score_lbl)
	calder_vbox.add_child(_calder_score_lbl)

	var calder_bar_hbox := HBoxContainer.new()
	calder_vbox.add_child(calder_bar_hbox)

	var calder_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Calder's reputation bar. Grows as you spread praise about him. Aim for 75+.")
	_calder_bar_bg = calder_pair[0]
	_calder_bar    = calder_pair[1]
	calder_bar_hbox.add_child(_calder_bar_bg)

	# Tomas track.
	var tomas_vbox := VBoxContainer.new()
	tomas_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(tomas_vbox)

	_tomas_score_lbl = Label.new()
	_tomas_score_lbl.add_theme_font_size_override("font_size", 14)
	_tomas_score_lbl.add_theme_color_override("font_color", C_BODY)
	_tomas_score_lbl.text = "Tomas Reeve  Rep: 50 / 100  Target: \u226435"
	_tomas_score_lbl.tooltip_text = "Tomas Reeve's reputation. Win condition: drag it down to 35 or lower."
	_tomas_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_tomas_score_lbl.clip_text = true
	_apply_text_outline(_tomas_score_lbl)
	tomas_vbox.add_child(_tomas_score_lbl)

	var tomas_bar_hbox := HBoxContainer.new()
	tomas_vbox.add_child(tomas_bar_hbox)

	var tomas_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Tomas's reputation bar. Shrinks as scandal and accusation rumors take hold. Aim to bring it below 35.")
	_tomas_bar_bg = tomas_pair[0]
	_tomas_bar    = tomas_pair[1]
	tomas_bar_hbox.add_child(_tomas_bar_bg)

	# Days remaining + result.
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 14)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 25"
	_days_lbl.clip_text = true
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 16)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	_result_lbl.clip_text = true
	right_vbox.add_child(_result_lbl)

	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 12)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "[\u2713] on track  [~] at risk  [\u2717] failing"
	right_vbox.add_child(legend_lbl)

	_rival_lbl = Label.new()
	_rival_lbl.add_theme_font_size_override("font_size", 12)
	_rival_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45, 0.80))
	_rival_lbl.text = "Rival: no activity yet"
	_rival_lbl.tooltip_text = "An unseen rival is working against you — praising Tomas and scandaling Calder. Their last known action is shown here."
	_rival_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_rival_lbl.clip_text = true
	right_vbox.add_child(_rival_lbl)

	_disrupt_btn = Button.new()
	_disrupt_btn.text = "Disrupt Rival (3)"
	_disrupt_btn.tooltip_text = (
		"Spend 1 Recon Action to slow the rival for 3 days (delays their next counter-rumor)."
		+ " Requires the rival to have acted at least once."
		+ " Limited to 3 charges per scenario — use them wisely in the later phases."
	)
	_disrupt_btn.add_theme_font_size_override("font_size", 12)
	_disrupt_btn.disabled = true
	_disrupt_btn.pressed.connect(_on_disrupt_pressed)
	_apply_hud_button_style(_disrupt_btn)
	right_vbox.add_child(_disrupt_btn)

	# SPA-868: Scout rival button — spend 1 recon to discover next degradation target.
	_scout_btn = Button.new()
	_scout_btn.text = "Scout Rival"
	_scout_btn.tooltip_text = "Spend 1 Recon action to discover which NPC the rival will undermine next."
	_scout_btn.add_theme_font_size_override("font_size", 12)
	_scout_btn.disabled = true
	_scout_btn.pressed.connect(_on_scout_pressed)
	_apply_hud_button_style(_scout_btn)
	right_vbox.add_child(_scout_btn)

	_scout_lbl = Label.new()
	_scout_lbl.add_theme_font_size_override("font_size", 11)
	_scout_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 0.90, 0.90))
	_scout_lbl.text = ""
	_scout_lbl.visible = false
	_scout_lbl.clip_text = true
	right_vbox.add_child(_scout_lbl)

	# SPA-868: Belief degradation activity display.
	_degrade_lbl = Label.new()
	_degrade_lbl.add_theme_font_size_override("font_size", 11)
	_degrade_lbl.add_theme_color_override("font_color", Color(0.85, 0.45, 0.20, 0.85))
	_degrade_lbl.text = ""
	_degrade_lbl.visible = false
	_degrade_lbl.clip_text = true
	right_vbox.add_child(_degrade_lbl)


# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _has_world_deps():
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var sm:  ScenarioManager  = _world_ref.scenario_manager
	var progress: Dictionary  = sm.get_scenario_3_progress(rep)

	var calder_score: int  = progress["calder_score"]
	var tomas_score:  int  = progress["tomas_score"]
	var calder_target: int = progress["calder_win_target"]
	var tomas_target:  int = progress["tomas_win_target"]
	var state              = progress["state"]

	_calder_score_lbl.text = "Calder Fenn   Rep: %d / 100   Target: %d+" % [calder_score, calder_target]
	_tomas_score_lbl.text  = "Tomas Reeve   Rep: %d / 100   Target: \u2264%d" % [tomas_score, tomas_target]

	var calder_ratio: float = clamp(float(calder_score) / 100.0, 0.0, 1.0)
	_calder_bar.custom_minimum_size.x = BAR_WIDTH * calder_ratio
	_calder_bar.color = _bar_color_for_score(calder_score, true, calder_target)

	var tomas_ratio: float = clamp(float(tomas_score) / 100.0, 0.0, 1.0)
	_tomas_bar.custom_minimum_size.x = BAR_WIDTH * tomas_ratio
	_tomas_bar.color = _bar_color_for_score(tomas_score, false, tomas_target)

	_update_days_remaining(sm)
	_update_result_label(state, "\u2713 VICTORY", "\u2717 FAILED")
	_update_disrupt_button()
	_update_scout_button()


func _bar_color_for_score(score: int, higher_is_better: bool, win_target: int) -> Color:
	var effective     := score if higher_is_better else (100 - score)
	var win_effective := win_target if higher_is_better else (100 - win_target)
	if effective >= win_effective:        return C_WIN
	elif effective >= win_effective / 2:  return C_NEUTRAL
	else:                                 return C_FAIL


# ── Rival activity ────────────────────────────────────────────────────────────

## Called by rival_agent.rival_acted signal each time the rival seeds a rumor.
func notify_rival_acted(day: int, claim_type: String, subject_id: String) -> void:
	if _rival_lbl == null:
		return
	_rival_lbl.text = "Rival: Day %d — %s on %s" % [day, claim_type.capitalize(), _display_name(subject_id)]
	_rival_lbl.add_theme_color_override("font_color", Color(1.0, 0.40, 0.20, 1.0))
	var tween := create_tween()
	tween.tween_property(_rival_lbl, "modulate:a", 0.25, 0.12)
	tween.tween_property(_rival_lbl, "modulate:a", 1.0, 0.30)
	# SPA-805: Red ripple VFX on the target NPC to make rival activity visible.
	_spawn_rival_ripple(subject_id)
	_update_disrupt_button()


## SPA-805: Spawn a red expanding ring at the NPC the rival just targeted.
func _spawn_rival_ripple(subject_id: String) -> void:
	if _world_ref == null:
		return
	var npc_pos := Vector2.ZERO
	var found := false
	for npc in _world_ref.npcs:
		if npc.npc_data.get("id", "") == subject_id:
			npc_pos = npc.global_position
			found = true
			break
	if not found:
		return
	var fx := preload("res://scripts/rumor_ripple_vfx.gd").new()
	fx.accent_color = Color(0.95, 0.15, 0.15, 0.80)  # red for rival threat
	_world_ref.add_child(fx)
	fx.global_position = npc_pos


## Called by rival_agent.rival_disrupted signal.
func notify_rival_disrupted(day: int) -> void:
	if _rival_lbl == null:
		return
	_rival_lbl.text = "Rival: Day %d — DISRUPTED (slowed 3 days)" % day
	_rival_lbl.add_theme_color_override("font_color", Color(0.10, 0.75, 0.40, 1.0))
	var tween := create_tween()
	tween.tween_property(_rival_lbl, "modulate:a", 0.25, 0.10)
	tween.tween_property(_rival_lbl, "modulate:a", 1.0, 0.25)
	_update_disrupt_button()


# ── Disrupt button ────────────────────────────────────────────────────────────

## Sync the Disrupt button enabled state and charge counter each refresh.
func _update_disrupt_button() -> void:
	if _disrupt_btn == null or _world_ref == null:
		return
	var rival = _world_ref.get("rival_agent")
	var intel = _world_ref.get("intel_store")
	var can_disrupt: bool = rival != null and rival.can_be_disrupted()
	var has_actions: bool = intel != null and intel.recon_actions_remaining > 0
	_disrupt_btn.disabled = not (can_disrupt and has_actions)
	# SPA-874: show remaining charges in the button label.
	var charges: int = rival.disrupt_charges_remaining if rival != null else 0
	_disrupt_btn.text = "Disrupt Rival (%d)" % charges


## Player clicked "Disrupt Rival" — spend 1 recon action and apply disruption.
func _on_disrupt_pressed() -> void:
	if _world_ref == null:
		return
	var rival = _world_ref.get("rival_agent")
	var intel: PlayerIntelStore = _world_ref.get("intel_store")
	if rival == null or intel == null:
		return
	if not intel.try_spend_action():
		return
	var current_day: int = 0
	if _day_night_ref != null:
		var sm: ScenarioManager = _world_ref.get("scenario_manager")
		current_day = _day_night_ref.current_tick / (sm.ticks_per_day if sm != null else 24) + 1
	rival.apply_disruption(current_day)
	_update_disrupt_button()


# ── SPA-868: Scout rival ─────────────────────────────────────────────────────

## Sync the Scout button enabled state each refresh.
func _update_scout_button() -> void:
	if _scout_btn == null or _world_ref == null:
		return
	var rival = _world_ref.get("rival_agent")
	var intel = _world_ref.get("intel_store")
	var has_actions: bool = intel != null and intel.recon_actions_remaining > 0
	var rival_active: bool = rival != null and rival._active
	_scout_btn.disabled = not (rival_active and has_actions)


## Player clicked "Scout Rival" — spend 1 recon action to discover next target.
func _on_scout_pressed() -> void:
	if _world_ref == null:
		return
	var rival = _world_ref.get("rival_agent")
	var intel: PlayerIntelStore = _world_ref.get("intel_store")
	if rival == null or intel == null:
		return
	if not intel.try_spend_action():
		return
	var current_day: int = 0
	if _day_night_ref != null:
		var sm: ScenarioManager = _world_ref.get("scenario_manager")
		current_day = _day_night_ref.current_tick / (sm.ticks_per_day if sm != null else 24) + 1
	var target_id: String = rival.scout_next_target(current_day)
	if target_id.is_empty():
		_scout_lbl.text = "Scout: no target found"
	else:
		_scout_lbl.text = "Next target: %s" % _display_name(target_id)
	_scout_lbl.visible = true
	# Flash the reveal.
	var tween := create_tween()
	tween.tween_property(_scout_lbl, "modulate:a", 0.25, 0.10)
	tween.tween_property(_scout_lbl, "modulate:a", 1.0, 0.25)
	_update_scout_button()


# ── SPA-868: Belief degradation notification ─────────────────────────────────

## Called by rival_agent.belief_degraded signal.
func notify_belief_degraded(day: int, npc_id: String, _old_state: int, _new_state: int) -> void:
	if _degrade_lbl == null:
		return
	_degrade_lbl.text = "Rival undermined %s (Day %d)" % [_display_name(npc_id), day]
	_degrade_lbl.visible = true
	_degrade_lbl.add_theme_color_override("font_color", Color(0.85, 0.45, 0.20, 0.90))
	var tween := create_tween()
	tween.tween_property(_degrade_lbl, "modulate:a", 0.25, 0.12)
	tween.tween_property(_degrade_lbl, "modulate:a", 1.0, 0.30)
