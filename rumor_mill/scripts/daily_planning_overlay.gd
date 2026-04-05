extends CanvasLayer

## daily_planning_overlay.gd — Dawn planning overlay controller (SPA-708).
##
## Shown automatically at dawn (tick 0 each day, day >= 2) before the player
## can act.  Populates an overnight bulletin from game state, lets the player
## pick up to 3 priorities for the day, and wires BEGIN DAY to resume the
## DayNightCycle.  Selected priorities are forwarded to ObjectiveHUD
## tier2_container and evaluated at end-of-day for bonus rewards.

signal planning_completed(selected_priorities: Array[String])

# ── Priority definitions ─────────────────────────────────────────────────────
# Each entry: { id, label, eval_key, bonus_desc }
# eval_key is checked against simple game-state counters at end-of-day.

const PRIORITIES: Array[Dictionary] = [
	{ "id": "gather_intel",    "label": "Gather intel at the Market",        "eval_key": "observe_count",     "bonus_desc": "+1 observation tomorrow" },
	{ "id": "seed_rumor",      "label": "Seed rumor to a clergy member",     "eval_key": "whisper_clergy",    "bonus_desc": "+1 whisper token tomorrow" },
	{ "id": "check_journal",   "label": "Check on rumor spread (Journal)",   "eval_key": "journal_opened",    "bonus_desc": "+1 evidence insight" },
	{ "id": "eavesdrop",       "label": "Eavesdrop at the Chapel",           "eval_key": "eavesdrop_count",   "bonus_desc": "+1 observation tomorrow" },
	{ "id": "bribe_npc",       "label": "Bribe a suspicious NPC",            "eval_key": "bribe_count",       "bonus_desc": "+1 bribe charge" },
	{ "id": "wait_observe",    "label": "Wait and observe",                  "eval_key": "any_action",        "bonus_desc": "+1 whisper token tomorrow" },
]

const MAX_SELECTIONS := 3

# ── External references (set via setup()) ────────────────────────────────────
var _world: Node2D = null
var _day_night: Node = null
var _objective_hud: CanvasLayer = null

# ── State ────────────────────────────────────────────────────────────────────
var _selected_ids: Array[String] = []
var _is_showing: bool = false
## Counters tracked during the day for priority evaluation.
var _day_counters: Dictionary = {}
## Priorities selected for the current day (persists until next dawn).
var _current_day_priorities: Array[String] = []

# ── Node references (resolved in _ready) ─────────────────────────────────────
var _dim_bg: ColorRect = null
var _planning_panel: Panel = null
var _dawn_header: Label = null
var _bulletin_vbox: VBoxContainer = null
var _bulletin_line1: Label = null
var _priority_list: VBoxContainer = null
var _begin_day_btn: Button = null
var _selection_hint: Label = null
var _observations_label: Label = null
var _whispers_label: Label = null
var _bribes_label: Label = null
var _tutorial_hint: Panel = null
var _checkboxes: Array[CheckBox] = []
var _fade_tween: Tween = null
var _slide_tween: Tween = null
var _btn_glow_tween: Tween = null
var _nudge_label: Label = null  # "Select at least one priority" nudge
var _skip_btn: Button = null    # Explicit "Skip Planning" button

# ── Audio preloads (optional; gracefully skipped if missing) ─────────────────
var _sfx_checkbox: AudioStreamPlayer = null


func _ready() -> void:
	layer = 10
	# Resolve node references from the scene tree.
	_dim_bg = $DimBG
	_planning_panel = $PlanningPanel
	_dawn_header = $PlanningPanel/ContentMargin/MainHBox/LeftColumn/DawnHeader
	_bulletin_vbox = $PlanningPanel/ContentMargin/MainHBox/LeftColumn/BulletinScroll/BulletinVBox
	_bulletin_line1 = $PlanningPanel/ContentMargin/MainHBox/LeftColumn/BulletinScroll/BulletinVBox/BulletinLine1
	_priority_list = $PlanningPanel/ContentMargin/MainHBox/RightColumn/PriorityScroll/PriorityList
	_begin_day_btn = $PlanningPanel/ContentMargin/MainHBox/RightColumn/ButtonRow/BeginDayButton
	_selection_hint = $PlanningPanel/ContentMargin/MainHBox/RightColumn/PlanHeaderRow/SelectionHint
	_observations_label = $PlanningPanel/ContentMargin/MainHBox/LeftColumn/ActionsRow/ObservationsLabel
	_whispers_label = $PlanningPanel/ContentMargin/MainHBox/LeftColumn/ActionsRow/WhispersLabel
	_bribes_label = $PlanningPanel/ContentMargin/MainHBox/LeftColumn/ActionsRow/BribesLabel
	_tutorial_hint = $PlanningPanel/TutorialHint

	# Gather checkbox references.
	for i in range(PRIORITIES.size()):
		var cb: CheckBox = _priority_list.get_node_or_null("Option%d" % (i + 1))
		if cb != null:
			_checkboxes.append(cb)
			cb.toggled.connect(_on_checkbox_toggled.bind(i))

	# Wire BEGIN DAY button.
	if _begin_day_btn != null:
		_begin_day_btn.pressed.connect(_on_begin_day_pressed)
		_begin_day_btn.mouse_entered.connect(_on_begin_btn_hover)

	# Build the "no selection" nudge label (hidden until needed).
	_build_nudge_label()

	# Build explicit Skip Planning button next to SkipLabel hint.
	_build_skip_button()

	# Lightweight click sound for checkbox toggling.
	_build_checkbox_sfx()

	# Start hidden.
	visible = false


## Called by main.gd after systems are ready.
func setup(w: Node2D, dn: Node, obj_hud: CanvasLayer) -> void:
	_world = w
	_day_night = dn
	_objective_hud = obj_hud
	# Connect to day_transition_started so we show at dawn.
	if _day_night != null and _day_night.has_signal("day_transition_started"):
		_day_night.day_transition_started.connect(_on_dawn)


## Called by main.gd on game_tick to track action counters for priority eval.
func on_game_tick(_tick: int) -> void:
	pass  # Counters are incremented externally via increment_counter().


## Increment a named counter for priority evaluation.
func increment_counter(key: String, amount: int = 1) -> void:
	_day_counters[key] = _day_counters.get(key, 0) + amount


## Returns the currently selected priority IDs for this day.
func get_current_priorities() -> Array[String]:
	return _current_day_priorities.duplicate()


# ── Show / hide ──────────────────────────────────────────────────────────────

func _on_dawn(day: int) -> void:
	# Evaluate previous day's priorities before showing new planning.
	if not _current_day_priorities.is_empty():
		_evaluate_priorities()
	# Reset for the new day.
	_day_counters.clear()
	_current_day_priorities.clear()
	# Skip day 1 — player uses ReadyOverlay instead.
	if day <= 1:
		return
	_show_overlay(day)


func _show_overlay(day: int) -> void:
	if _is_showing:
		return
	_is_showing = true
	# Pause the game while planning.
	if _day_night != null:
		_day_night.set_paused(true)
	# Sync SpeedHUD to paused state.
	var speed_node: Node = get_parent().get_node_or_null("SpeedHUD") if get_parent() != null else null
	if speed_node != null and speed_node.has_method("_set_speed"):
		speed_node._set_speed(speed_node.Speed.PAUSE)

	_populate_bulletin(day)
	_populate_action_counts()
	_reset_checkboxes()
	_update_selection_hint()
	_update_tutorial_hint()
	_hide_nudge()

	# Fade in backdrop + slide up panel.
	visible = true
	modulate.a = 0.0
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	# Dim backdrop fades in.
	_fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.3)

	# Planning panel slides up from below.
	if _planning_panel != null:
		var target_top: float = _planning_panel.anchor_top
		_planning_panel.anchor_top = 1.0  # start off-screen (below)
		_planning_panel.anchor_bottom = 1.4
		_slide_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_slide_tween.tween_property(_planning_panel, "anchor_top", target_top, 0.4)
		_slide_tween.parallel().tween_property(_planning_panel, "anchor_bottom", 1.0, 0.4)


func _hide_overlay() -> void:
	if not _is_showing:
		return
	_is_showing = false
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_fade_tween.tween_callback(func() -> void: visible = false)

	# Resume game.
	var speed_node: Node = get_parent().get_node_or_null("SpeedHUD") if get_parent() != null else null
	if speed_node != null and speed_node.has_method("_set_speed"):
		speed_node._set_speed(speed_node.Speed.NORMAL)
	if _day_night != null:
		_day_night.set_paused(false)


# ── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_begin_day_pressed()
			get_viewport().set_input_as_handled()


func _on_checkbox_toggled(_pressed: bool, index: int) -> void:
	_selected_ids.clear()
	for i in range(_checkboxes.size()):
		if _checkboxes[i].button_pressed:
			if _selected_ids.size() < MAX_SELECTIONS:
				_selected_ids.append(PRIORITIES[i].id)
			else:
				# Exceeded limit — uncheck this one.
				_checkboxes[i].set_pressed_no_signal(false)
	_update_selection_hint()
	_hide_nudge()

	# Click sound.
	if _sfx_checkbox != null:
		_sfx_checkbox.play()

	# Brief highlight pulse on the toggled checkbox.
	if index >= 0 and index < _checkboxes.size():
		var cb := _checkboxes[index]
		var orig_color: Color = cb.get_theme_color("font_color")
		var flash_color := Color(0.30, 0.85, 0.35, 1.0) if cb.button_pressed else Color(0.80, 0.72, 0.56, 1.0)
		var tw := create_tween()
		cb.add_theme_color_override("font_color", flash_color)
		cb.scale = Vector2(1.03, 1.03)
		tw.tween_property(cb, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_callback(func() -> void:
			cb.add_theme_color_override("font_color", orig_color if not cb.button_pressed else flash_color)
		).set_delay(0.15)


func _on_begin_day_pressed() -> void:
	# Nudge if nothing selected (skip-planning via Space is always allowed).
	if _selected_ids.is_empty():
		_show_nudge()
		# Still allow proceeding — the nudge is gentle, not blocking.
	_current_day_priorities = _selected_ids.duplicate()

	# Satisfying button press animation: glow + scale pop.
	if _begin_day_btn != null:
		_begin_day_btn.pivot_offset = _begin_day_btn.size / 2.0
		var tw := create_tween()
		tw.tween_property(_begin_day_btn, "scale", Vector2(1.12, 1.12), 0.08) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(_begin_day_btn, "scale", Vector2(1.0, 1.0), 0.1) \
			.set_ease(Tween.EASE_IN)

	_push_priorities_to_hud()
	planning_completed.emit(_current_day_priorities)
	# Small delay to let the button animation land before closing.
	var close_tw := create_tween()
	close_tw.tween_interval(0.12)
	close_tw.tween_callback(_hide_overlay)


func _on_begin_btn_hover() -> void:
	if _begin_day_btn == null:
		return
	# Subtle glow pulse on hover.
	if _btn_glow_tween != null and _btn_glow_tween.is_valid():
		_btn_glow_tween.kill()
	_begin_day_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70, 1.0))
	_btn_glow_tween = create_tween()
	_btn_glow_tween.tween_property(_begin_day_btn, "theme_override_colors/font_color",
		Color(0.95, 0.90, 0.72, 1.0), 0.3)


# ── Bulletin population ──────────────────────────────────────────────────────

func _populate_bulletin(day: int) -> void:
	if _dawn_header != null:
		_dawn_header.text = "DAWN — DAY %d" % day

	# Clear old bulletin lines.
	if _bulletin_vbox != null:
		for child in _bulletin_vbox.get_children():
			child.queue_free()

	var lines: Array[String] = _gather_overnight_events()
	if lines.is_empty():
		lines.append("- No significant events overnight")

	for line_text in lines:
		var lbl := Label.new()
		lbl.text = line_text
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.80, 0.72, 0.56, 1.0))
		_bulletin_vbox.add_child(lbl)


func _gather_overnight_events() -> Array[String]:
	var lines: Array[String] = []
	if _world == null:
		return lines

	# Reputation changes.
	var rep: ReputationSystem = _world.reputation_system if "reputation_system" in _world else null
	if rep != null:
		var snaps: Dictionary = rep.get_all_snapshots()
		for npc_id in snaps:
			var snap: ReputationSystem.ReputationSnapshot = snaps[npc_id]
			# Show notable scores.
			if snap.score >= 70:
				var npc_name: String = npc_id.replace("_", " ").capitalize()
				lines.append("- %s: reputation strong (%d)" % [npc_name, snap.score])
			elif snap.score <= 20 and snap.score > 0:
				var npc_name: String = npc_id.replace("_", " ").capitalize()
				lines.append("- %s: reputation low (%d)" % [npc_name, snap.score])

	# Active rumor spread summary.
	var prop: PropagationEngine = _world.propagation_engine if "propagation_engine" in _world else null
	if prop != null and prop.has_method("get_active_rumors"):
		var active: Array = prop.get_active_rumors()
		if active.size() > 0:
			lines.append("- %d rumor%s still spreading" % [
				active.size(), "" if active.size() == 1 else "s"])

	# NPC mood/belief shifts — summarize faction-level belief states.
	var npcs: Array = _world.npcs if "npcs" in _world else []
	var believers := 0
	var rejectors := 0
	for npc in npcs:
		if npc.has_method("get_rumor_state"):
			var state = npc.get_rumor_state()
			if state == Rumor.RumorState.BELIEVE or state == Rumor.RumorState.SPREAD:
				believers += 1
			elif state == Rumor.RumorState.REJECT:
				rejectors += 1
	if believers > 0:
		lines.append("- %d NPC%s believe%s your rumor" % [
			believers, "" if believers == 1 else "s", "s" if believers == 1 else ""])
	if rejectors > 0:
		lines.append("- %d NPC%s rejected your rumor" % [
			rejectors, "" if rejectors == 1 else "s"])

	return lines


func _populate_action_counts() -> void:
	if _world == null:
		return
	var intel: PlayerIntelStore = _world.intel_store if "intel_store" in _world else null
	if intel == null:
		return
	if _observations_label != null:
		_observations_label.text = "%d Observations" % intel.recon_actions_remaining
	if _whispers_label != null:
		_whispers_label.text = "%d Whispers" % intel.whisper_tokens_remaining
	if _bribes_label != null:
		_bribes_label.text = "%d Bribe%s" % [intel.bribe_charges, "" if intel.bribe_charges == 1 else "s"]


func _reset_checkboxes() -> void:
	_selected_ids.clear()
	for i in range(_checkboxes.size()):
		_checkboxes[i].set_pressed_no_signal(false)
		if i < PRIORITIES.size():
			_checkboxes[i].text = PRIORITIES[i].label


func _update_selection_hint() -> void:
	if _selection_hint != null:
		var remaining := MAX_SELECTIONS - _selected_ids.size()
		if remaining == 0:
			_selection_hint.text = "All 3 chosen"
		else:
			_selection_hint.text = "Choose up to %d" % MAX_SELECTIONS


func _update_tutorial_hint() -> void:
	if _tutorial_hint == null:
		return
	# Show tutorial hint only during Scenario 1.
	if _world != null and "active_scenario_id" in _world:
		_tutorial_hint.visible = (_world.active_scenario_id == "scenario_1")
	else:
		_tutorial_hint.visible = false


# ── Priority HUD integration ────────────────────────────────────────────────

func _push_priorities_to_hud() -> void:
	if _objective_hud == null:
		return
	var tier2: VBoxContainer = _objective_hud.get_node_or_null("Panel/VBox/Tier2Container")
	if tier2 == null:
		return
	# Clear previous priority labels.
	for child in tier2.get_children():
		child.queue_free()
	# Add selected priorities as compact labels.
	for pid in _current_day_priorities:
		var pdef: Dictionary = _get_priority_def(pid)
		if pdef.is_empty():
			continue
		var lbl := Label.new()
		lbl.text = "▸ " + pdef.label
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.45, 0.9))
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		tier2.add_child(lbl)


func _get_priority_def(pid: String) -> Dictionary:
	for p in PRIORITIES:
		if p.id == pid:
			return p
	return {}


# ── End-of-day priority evaluation ──────────────────────────────────────────

func _evaluate_priorities() -> void:
	var completed_count := 0
	for pid in _current_day_priorities:
		var pdef: Dictionary = _get_priority_def(pid)
		if pdef.is_empty():
			continue
		var key: String = pdef.eval_key
		var count: int = _day_counters.get(key, 0)
		if key == "any_action":
			# "Wait and observe" succeeds if the player performed at least one action.
			count = _day_counters.get("observe_count", 0) + _day_counters.get("eavesdrop_count", 0) + _day_counters.get("bribe_count", 0)
		if count > 0:
			completed_count += 1
			_apply_bonus(pdef)

	# Mark tier2 labels as completed/missed.
	if _objective_hud != null:
		var tier2: VBoxContainer = _objective_hud.get_node_or_null("Panel/VBox/Tier2Container")
		if tier2 != null:
			var idx := 0
			for child in tier2.get_children():
				if child is Label and idx < _current_day_priorities.size():
					var pid: String = _current_day_priorities[idx]
					var pdef: Dictionary = _get_priority_def(pid)
					var key: String = pdef.get("eval_key", "")
					var count: int = _day_counters.get(key, 0)
					if key == "any_action":
						count = _day_counters.get("observe_count", 0) + _day_counters.get("eavesdrop_count", 0) + _day_counters.get("bribe_count", 0)
					if count > 0:
						child.add_theme_color_override("font_color", Color(0.30, 0.85, 0.35, 0.9))
						child.text = "✓ " + pdef.label
					else:
						child.add_theme_color_override("font_color", Color(0.55, 0.40, 0.30, 0.7))
						child.text = "✗ " + pdef.label
					idx += 1


func _apply_bonus(pdef: Dictionary) -> void:
	if _world == null:
		return
	var intel: PlayerIntelStore = _world.intel_store if "intel_store" in _world else null
	if intel == null:
		return
	match pdef.eval_key:
		"observe_count", "eavesdrop_count":
			# +1 observation action for tomorrow (applied at dawn refresh).
			intel.recon_actions_remaining += 1
		"whisper_clergy", "wait_observe":
			# +1 whisper token.
			intel.whisper_tokens_remaining += 1
		"bribe_count":
			# +1 bribe charge.
			intel.bribe_charges += 1
		"journal_opened":
			# +1 evidence insight — award a random evidence item if possible.
			pass  # Evidence system integration TBD based on evidence inventory API.


# ── UX helpers (SPA-713) ─────────────────────────────────────────────────────

func _build_nudge_label() -> void:
	_nudge_label = Label.new()
	_nudge_label.text = "Select at least one priority — or press Space to skip"
	_nudge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nudge_label.add_theme_font_size_override("font_size", 12)
	_nudge_label.add_theme_color_override("font_color", Color(0.95, 0.60, 0.20, 0.0))
	_nudge_label.add_theme_constant_override("outline_size", 1)
	_nudge_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_nudge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Place below the priority list, inside the right column.
	var right_col: VBoxContainer = $PlanningPanel/ContentMargin/MainHBox/RightColumn if has_node("PlanningPanel/ContentMargin/MainHBox/RightColumn") else null
	if right_col != null:
		var idx := right_col.get_child_count() - 1  # before button row
		right_col.add_child(_nudge_label)
		right_col.move_child(_nudge_label, idx)


func _show_nudge() -> void:
	if _nudge_label == null:
		return
	var tw := create_tween()
	tw.tween_property(_nudge_label, "theme_override_colors/font_color",
		Color(0.95, 0.60, 0.20, 0.9), 0.25)


func _hide_nudge() -> void:
	if _nudge_label == null:
		return
	_nudge_label.add_theme_color_override("font_color", Color(0.95, 0.60, 0.20, 0.0))


func _build_skip_button() -> void:
	# Replace the static "Space: Skip Planning" label with an actual clickable button.
	var skip_label_node: Label = $PlanningPanel/ContentMargin/MainHBox/RightColumn/ButtonRow/SkipLabel if has_node("PlanningPanel/ContentMargin/MainHBox/RightColumn/ButtonRow/SkipLabel") else null
	if skip_label_node != null:
		_skip_btn = Button.new()
		_skip_btn.text = "Skip Planning"
		_skip_btn.flat = true
		_skip_btn.add_theme_font_size_override("font_size", 12)
		_skip_btn.add_theme_color_override("font_color", Color(0.50, 0.44, 0.32, 0.7))
		_skip_btn.add_theme_color_override("font_hover_color", Color(0.70, 0.60, 0.42, 1.0))
		_skip_btn.pressed.connect(func() -> void:
			_selected_ids.clear()
			_on_begin_day_pressed()
		)
		var parent := skip_label_node.get_parent()
		var idx := skip_label_node.get_index()
		parent.remove_child(skip_label_node)
		skip_label_node.queue_free()
		parent.add_child(_skip_btn)
		parent.move_child(_skip_btn, idx)


func _build_checkbox_sfx() -> void:
	# Lightweight procedural click via AudioStreamPlayer.
	_sfx_checkbox = AudioStreamPlayer.new()
	_sfx_checkbox.volume_db = -12.0
	_sfx_checkbox.bus = &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"
	add_child(_sfx_checkbox)
	# Generate a short click waveform (no external file needed).
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.03
	_sfx_checkbox.stream = gen


# ── Save / load integration ──────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"selected_priorities": _current_day_priorities.duplicate(),
		"day_counters": _day_counters.duplicate(),
	}


func apply_load_data(data: Dictionary) -> void:
	_current_day_priorities.clear()
	var saved_priorities: Array = data.get("selected_priorities", [])
	for p in saved_priorities:
		_current_day_priorities.append(str(p))
	_day_counters = data.get("day_counters", {}).duplicate()
	# Restore HUD display of loaded priorities.
	if not _current_day_priorities.is_empty():
		_push_priorities_to_hud()
