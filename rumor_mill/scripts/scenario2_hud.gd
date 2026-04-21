extends BaseScenarioHud

## scenario2_hud.gd — Persistent illness-spread tracking display.
##
## Shows a thin header at the top of the screen tracking how many NPCs
## believe the illness rumor about Alys Herbwife, who believes/rejects,
## and days remaining.
##
## Layout:
##   Scenario 2: The Plague Scare
##   Believers: 3 / 7+   [progress bar]   Days remaining: 18
##   ✓ Tomas, Calder, Finn   ✗ Sister Maren
##
## Wire via setup(world, day_night) from main.gd.

# ── S2-specific palette ──────────────────────────────────────────────────────
const C_ILLNESS := Color(0.60, 0.85, 0.30, 1.0)  # sickly green for plague theme

const BAR_WIDTH      := 160
const BAR_HEIGHT     := 12
const MAX_NAMES_SHOWN := 5

# ── Node refs ────────────────────────────────────────────────────────────────
var _count_lbl:         Label     = null
var _bar:               ColorRect = null
var _bar_bg:            ColorRect = null
var _believers_lbl:     Label     = null
var _rejecters_lbl:     Label     = null
var _maren_warning_lbl: Label     = null
var _escalation_lbl:    Label     = null

## SPA-805: pip row — filled ● / empty ○ circles showing believer progress.
var _pip_lbl: Label = null

## SPA-592: Maren's direct social-graph neighbours (NPC id → edge weight).
## Populated in _on_setup_extra; used to flag seed-target risk in the believers list.
var _maren_neighbours: Dictionary = {}

## SPA-868: Quarantine mechanic UI elements.
var _quarantine_btn:   Button       = null
var _quarantine_dropdown: OptionButton = null
var _quarantine_status_lbl: Label   = null


func _scenario_number() -> int:
	return 2


func _on_setup_extra(world: Node2D) -> void:
	var esc_agent = world.get("illness_escalation_agent") if world != null else null
	if esc_agent != null:
		esc_agent.illness_escalated.connect(notify_illness_escalated)
	# SPA-592: cache Maren's social neighbours so believers connected to her can be flagged.
	if world != null and world.get("social_graph") != null:
		_maren_neighbours = world.social_graph.get_neighbours(ScenarioManager.MAREN_NUN_ID)
	# SPA-592: connect to grace-window signal so the HUD can show the countdown warning.
	if world != null and world.get("scenario_manager") != null:
		world.scenario_manager.s2_maren_grace_started.connect(_on_maren_grace_started)
	# SPA-868: populate quarantine building dropdown.
	if world != null and _quarantine_dropdown != null:
		var q_sys = world.get("quarantine_system")
		if q_sys != null and q_sys.is_active():
			_populate_quarantine_dropdown(world)


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var hbox := _make_panel("Scenario2Panel", 62)

	# Scenario label.
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 2:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	hbox.add_child(title_lbl)

	# Believer count + progress bar.
	var count_vbox := VBoxContainer.new()
	count_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(count_vbox)

	_count_lbl = Label.new()
	_count_lbl.add_theme_font_size_override("font_size", 13)
	_count_lbl.add_theme_color_override("font_color", C_BODY)
	_count_lbl.text = "Believers: 0 / 7+"
	_count_lbl.tooltip_text = "Number of townspeople who believe the illness rumor about Alys Herbwife. Win when 7 or more believe it."
	_count_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_text_outline(_count_lbl)
	count_vbox.add_child(_count_lbl)

	var bar_hbox := HBoxContainer.new()
	count_vbox.add_child(bar_hbox)

	var bar_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Progress toward 7 believers. Green = win threshold reached; amber = halfway; sickly green = early stage.")
	_bar_bg = bar_pair[0]
	_bar    = bar_pair[1]
	bar_hbox.add_child(_bar_bg)

	# SPA-805: Pip row — ● filled / ○ empty circles showing believer count at a glance.
	_pip_lbl = Label.new()
	_pip_lbl.add_theme_font_size_override("font_size", 13)
	_pip_lbl.add_theme_color_override("font_color", C_ILLNESS)
	_pip_lbl.add_theme_constant_override("outline_size", 2)
	_pip_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_pip_lbl.text = "○○○○○○○"
	_pip_lbl.tooltip_text = "Each circle = one believer. Filled ● = believes; empty ○ = not yet."
	_pip_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	count_vbox.add_child(_pip_lbl)

	# NPC name columns.
	var names_vbox := VBoxContainer.new()
	names_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(names_vbox)

	_believers_lbl = Label.new()
	_believers_lbl.add_theme_font_size_override("font_size", 12)
	_believers_lbl.add_theme_color_override("font_color", C_ILLNESS)
	_believers_lbl.text = "Believe: —"
	names_vbox.add_child(_believers_lbl)

	_rejecters_lbl = Label.new()
	_rejecters_lbl.add_theme_font_size_override("font_size", 12)
	_rejecters_lbl.add_theme_color_override("font_color", C_FAIL)
	_rejecters_lbl.text = ""
	_rejecters_lbl.visible = false
	names_vbox.add_child(_rejecters_lbl)

	# SPA-592: grace-window countdown warning shown when Maren has rejected.
	_maren_warning_lbl = Label.new()
	_maren_warning_lbl.add_theme_font_size_override("font_size", 11)
	_maren_warning_lbl.add_theme_color_override("font_color", C_FAIL)
	_maren_warning_lbl.text = ""
	_maren_warning_lbl.visible = false
	_maren_warning_lbl.tooltip_text = (
		"Sister Maren has rejected the illness rumor. Reach 7 believers before"
		+ " the grace period expires or the scenario will fail."
	)
	_maren_warning_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	names_vbox.add_child(_maren_warning_lbl)

	# Days remaining + result.
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 13)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 22"
	_days_lbl.tooltip_text = "Days remaining before the autumn market closes. Fail if you run out of time."
	_days_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_text_outline(_days_lbl)
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 16)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	right_vbox.add_child(_result_lbl)

	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 12)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "Target: 7+ believers"
	right_vbox.add_child(legend_lbl)

	_escalation_lbl = Label.new()
	_escalation_lbl.add_theme_font_size_override("font_size", 12)
	_escalation_lbl.add_theme_color_override("font_color", Color(0.60, 0.85, 0.30, 0.80))
	_escalation_lbl.text = "Rumours: quiet so far"
	_escalation_lbl.tooltip_text = "Illness reports are escalating on their own. Each auto-spread increases the risk Sister Maren will notice."
	_escalation_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	right_vbox.add_child(_escalation_lbl)

	# SPA-868: Quarantine mechanic controls.
	var q_vbox := VBoxContainer.new()
	q_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(q_vbox)

	var q_title := Label.new()
	q_title.text = "Quarantine Zone"
	q_title.add_theme_font_size_override("font_size", 12)
	q_title.add_theme_color_override("font_color", C_HEADING)
	q_vbox.add_child(q_title)

	_quarantine_dropdown = OptionButton.new()
	_quarantine_dropdown.add_theme_font_size_override("font_size", 11)
	_quarantine_dropdown.tooltip_text = "Select a building to quarantine. Costs 2 Whisper tokens."
	_quarantine_dropdown.custom_minimum_size = Vector2(110, 0)
	q_vbox.add_child(_quarantine_dropdown)

	_quarantine_btn = Button.new()
	_quarantine_btn.text = "Quarantine (1R+1W)"
	_quarantine_btn.tooltip_text = (
		"Spend 1 Recon Action + 1 Whisper Token to quarantine the selected building for 2 days."
		+ " Outside NPCs will avoid the area. Chapel NPCs freeze in place."
		+ " Only one active quarantine at a time; 3-day cooldown per building after expiry."
	)
	_quarantine_btn.add_theme_font_size_override("font_size", 11)
	_quarantine_btn.disabled = true
	_quarantine_btn.pressed.connect(_on_quarantine_pressed)
	q_vbox.add_child(_quarantine_btn)

	_quarantine_status_lbl = Label.new()
	_quarantine_status_lbl.add_theme_font_size_override("font_size", 11)
	_quarantine_status_lbl.add_theme_color_override("font_color", Color(0.95, 0.30, 0.20, 0.90))
	_quarantine_status_lbl.text = ""
	_quarantine_status_lbl.visible = false
	q_vbox.add_child(_quarantine_status_lbl)


# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _has_world_deps():
		return

	var rep: ReputationSystem  = _world_ref.reputation_system
	var sm:  ScenarioManager   = _world_ref.scenario_manager
	var progress: Dictionary   = sm.get_scenario_2_progress(rep)

	var count: int       = progress["illness_believer_count"]
	var threshold: int   = progress["win_threshold"]
	var believers: Array = progress["illness_believer_ids"]
	var rejecters: Array = progress["illness_rejecter_ids"]
	var state            = progress["state"]

	_count_lbl.text = "Believers: %d / %d+" % [count, threshold]

	var ratio: float = clamp(float(count) / float(threshold), 0.0, 1.0)
	_bar.custom_minimum_size.x = BAR_WIDTH * ratio
	if count >= threshold:
		_bar.color = C_WIN
	elif count >= threshold / 2:
		_bar.color = C_NEUTRAL
	else:
		_bar.color = C_ILLNESS

	if believers.size() > 0:
		var names: Array = []
		for npc_id in believers.slice(0, MAX_NAMES_SHOWN):
			# SPA-592: flag NPCs directly connected to Maren — seeding them risked this chain.
			var display := _display_name(npc_id)
			if _maren_neighbours.has(npc_id):
				display += " (!)"
			names.append(display)
		var suffix := ""
		if believers.size() > MAX_NAMES_SHOWN:
			suffix = " +%d more" % (believers.size() - MAX_NAMES_SHOWN)
		_believers_lbl.text = "Believe: " + ", ".join(names) + suffix
	else:
		_believers_lbl.text = "Believe: —"

	if rejecters.size() > 0:
		var names: Array = []
		for npc_id in rejecters.slice(0, MAX_NAMES_SHOWN):
			names.append(_display_name(npc_id))
		var suffix := ""
		if rejecters.size() > MAX_NAMES_SHOWN:
			suffix = " +%d more" % (rejecters.size() - MAX_NAMES_SHOWN)
		_rejecters_lbl.text = "Reject: " + ", ".join(names) + suffix
		_rejecters_lbl.visible = true
	else:
		_rejecters_lbl.visible = false

	# SPA-805: Update pip display (● filled, ○ empty) for believer count.
	if _pip_lbl != null:
		var filled: int = mini(count, threshold)
		var pip_str := ""
		for i in threshold:
			pip_str += "●" if i < filled else "○"
		_pip_lbl.text = pip_str
		_pip_lbl.add_theme_color_override("font_color",
			C_WIN if count >= threshold else C_ILLNESS)

	_update_days_remaining(sm)
	_update_result_label(state,
		"VICTORY — The plague scare spreads",
		"FAILED — The truth prevails")
	_update_quarantine_button()


# ── Escalation activity ───────────────────────────────────────────────────────

## Called by illness_escalation_agent.illness_escalated signal.
func notify_illness_escalated(day: int, _claim_type: String, _subject_id: String) -> void:
	if _escalation_lbl == null:
		return
	_escalation_lbl.text = "Rumours: Day %d — illness spreading on its own" % day
	_escalation_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.10, 1.0))
	var tween := create_tween()
	tween.tween_property(_escalation_lbl, "modulate:a", 0.25, 0.12)
	tween.tween_property(_escalation_lbl, "modulate:a", 1.0,  0.30)


# ── SPA-592: Grace window warning ─────────────────────────────────────────────

# ── SPA-868: Quarantine mechanic ──────────────────────────────────────────────

## Populate the building dropdown from the world's building entries.
func _populate_quarantine_dropdown(world: Node2D) -> void:
	if _quarantine_dropdown == null:
		return
	_quarantine_dropdown.clear()
	var building_names: Array = ["tavern", "market", "chapel", "manor", "blacksmith",
		"mill", "storage", "guardpost", "town_hall", "well"]
	for bname in building_names:
		if world._building_entries.has(bname):
			_quarantine_dropdown.add_item(bname.replace("_", " ").capitalize())
			_quarantine_dropdown.set_item_metadata(_quarantine_dropdown.item_count - 1, bname)


## Update quarantine button enabled state each refresh.
func _update_quarantine_button() -> void:
	if _quarantine_btn == null or _world_ref == null:
		return
	var q_sys = _world_ref.get("quarantine_system")
	var intel = _world_ref.get("intel_store")
	if q_sys == null or not q_sys.is_active():
		_quarantine_btn.disabled = true
		return
	# SPA-874: Requires 1 Recon Action + 1 Whisper Token.
	var has_recon: bool = intel != null and intel.recon_actions_remaining >= QuarantineSystem.QUARANTINE_RECON_COST
	var has_whisper: bool = intel != null and intel.whisper_tokens_remaining >= QuarantineSystem.QUARANTINE_WHISPER_COST
	var selected_building: String = _get_selected_building()
	var already_quarantined: bool = not selected_building.is_empty() and q_sys.is_quarantined(selected_building)
	# SPA-874: Block when another quarantine is already active or on cooldown.
	var another_active: bool = not q_sys.get_quarantined_buildings().is_empty() and not already_quarantined
	var tick: int = _day_night_ref.current_tick if _day_night_ref != null else 0
	var on_cooldown: bool = not selected_building.is_empty() and q_sys.is_on_cooldown(selected_building, tick)
	_quarantine_btn.disabled = not has_recon or not has_whisper or already_quarantined \
		or selected_building.is_empty() or another_active or on_cooldown

	# Update status label for active quarantines and cooldowns.
	var active: Array = q_sys.get_quarantined_buildings()
	if active.is_empty():
		# SPA-874: show cooldown hint when selected building is on cooldown.
		if on_cooldown:
			_quarantine_status_lbl.text = "%s: 3-day cooldown" % selected_building.replace("_", " ").capitalize()
			_quarantine_status_lbl.visible = true
		else:
			_quarantine_status_lbl.visible = false
	else:
		var names: Array = []
		for b in active:
			names.append(b.replace("_", " ").capitalize())
		_quarantine_status_lbl.text = "Active: " + ", ".join(names)
		_quarantine_status_lbl.visible = true


## Get the internal building name from the currently selected dropdown item.
func _get_selected_building() -> String:
	if _quarantine_dropdown == null or _quarantine_dropdown.item_count == 0:
		return ""
	var idx: int = _quarantine_dropdown.selected
	if idx < 0:
		return ""
	return _quarantine_dropdown.get_item_metadata(idx)


## Player clicked "Quarantine" — spend 2 whisper tokens and quarantine the building.
func _on_quarantine_pressed() -> void:
	if _world_ref == null:
		return
	var q_sys = _world_ref.get("quarantine_system")
	var intel: PlayerIntelStore = _world_ref.get("intel_store")
	if q_sys == null or intel == null:
		return
	var building_name: String = _get_selected_building()
	if building_name.is_empty():
		return
	var tick: int = 0
	if _day_night_ref != null:
		tick = _day_night_ref.current_tick
	q_sys.try_quarantine(building_name, intel, tick)
	_update_quarantine_button()


## Called when Maren first rejects, starting the 2-day grace window.
func _on_maren_grace_started(days_remaining: int) -> void:
	if _maren_warning_lbl == null:
		return
	_maren_warning_lbl.text = "⚠ Maren rejected — %d days to reach 7 believers!" % days_remaining
	_maren_warning_lbl.visible = true
	# Flash the warning to draw the player's eye.
	var tween := create_tween()
	tween.tween_property(_maren_warning_lbl, "modulate:a", 0.1, 0.15)
	tween.tween_property(_maren_warning_lbl, "modulate:a", 1.0, 0.30)
	tween.tween_property(_maren_warning_lbl, "modulate:a", 0.1, 0.15)
	tween.tween_property(_maren_warning_lbl, "modulate:a", 1.0, 0.30)
