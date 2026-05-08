class_name ObjectiveHudNudgeManager
extends Node

## objective_hud_nudge_manager.gd — Budget counter + nudge subsystems (SPA-1004).
##
## Extracted from objective_hud.gd.  Manages three UI subsystems:
##   • Daily action/whisper budget label + floating delta indicators (SPA-838/903)
##   • Context-sensitive "what to do next" tutorial nudge (SPA-520/537)
##   • "Press O to review mission" hint label (SPA-627)
##   • Mid-game contextual guidance nudge, slide-in from bottom-right (SPA-648)
##
## Call setup() in _ready(), then build_budget_label() after the win-target
## label has been inserted into the VBox, then build_midgame_nudge().
## Call setup_world() once the world node is available.
## Call refresh() every tick/day.

# ── Tutorial nudge constants ──────────────────────────────────────────────────
const C_NUDGE := Color(0.40, 1.0, 0.50, 1.0)

var _NUDGE_TEXTS: PackedStringArray = PackedStringArray([
	"NEXT: Right-click a building to Observe who is inside",
	"NEXT: Right-click two NPCs in conversation to Eavesdrop",
	"NEXT: Press R to craft your first Rumour",
	"Watch your rumour spread — check the Journal (J) for details",
])

# ── Mid-game nudge constants ──────────────────────────────────────────────────
const C_MIDGAME_NUDGE    := Color(0.80, 0.90, 0.65, 1.0)
const C_MIDGAME_NUDGE_BG := Color(0.08, 0.06, 0.04, 0.85)

# ── Budget label ──────────────────────────────────────────────────────────────
var _lbl_budget:          Label = null
var _budget_flash_tween:  Tween = null
var _budget_last_actions: int   = -1
var _budget_last_whispers: int  = -1
var _delta_layer:         CanvasLayer = null

# ── Tutorial nudge ────────────────────────────────────────────────────────────
var _nudge_panel:       PanelContainer = null
var _nudge_label:       Label          = null
var _nudge_pulse_tween: Tween          = null
var _nudge_phase:       int            = 0
var _nudge_last_phase:  int            = -1

# ── "Press O" hint label — public so coordinator can pass to win-tracker ──────
var o_hint_label: Label = null

# ── Mid-game nudge ────────────────────────────────────────────────────────────
var _midgame_nudge_label:          Label     = null
var _midgame_nudge_bg:             ColorRect = null
var _midgame_nudge_tween:          Tween     = null
var _midgame_nudge_last_phase_key: String    = ""
var _midgame_last_seen_rumor_states: Dictionary = {}

# ── Dependencies ──────────────────────────────────────────────────────────────
var _vbox:             VBoxContainer  = null
var _goal_label:       Label          = null
var _intel_store:      PlayerIntelStore  = null
var _day_night:        Node           = null
var _scenario_manager: ScenarioManager = null
var _world_ref:        Node2D         = null
var _hud_root:         Node           = null
## show_banner_fn(text: String, color: Color, duration: float)
var _show_banner_fn:   Callable


## Inject dependencies, build tutorial nudge panel and o_hint_label.
## `hud_root` is the parent CanvasLayer — required for midgame nudge and delta
## floating labels which must be direct children of that layer.
func setup(
		vbox: VBoxContainer,
		goal_label: Label,
		intel_store: PlayerIntelStore,
		day_night: Node,
		scenario_manager: ScenarioManager,
		hud_root: Node,
		show_banner_fn: Callable) -> void:
	_vbox             = vbox
	_goal_label       = goal_label
	_intel_store      = intel_store
	_day_night        = day_night
	_scenario_manager = scenario_manager
	_hud_root         = hud_root
	_show_banner_fn   = show_banner_fn
	_build_nudge_label()
	_build_o_hint_label()


## Build the budget label.  Call after `win_target_label` is already in the
## VBox so it is positioned correctly below it.
func build_budget_label(goal_flavor_label: Label, win_target_label: Label) -> void:
	_build_budget_label(goal_flavor_label, win_target_label)


## Build the mid-game slide-in nudge.  Adds nodes to `_hud_root` (CanvasLayer).
func build_midgame_nudge() -> void:
	_build_midgame_nudge()


## Called by coordinator once the world node is available.
func setup_world(world: Node2D) -> void:
	_world_ref = world


## Update all nudge states and budget label.  Safe to call every tick.
func refresh() -> void:
	_refresh_budget_label()
	_refresh_nudge()
	_refresh_midgame_nudge()


## SPA-903: Called immediately when the player spends a whisper token.
func on_whisper_spent() -> void:
	_spawn_budget_delta("-1", Color(1.0, 0.35, 0.25, 1.0))
	_pulse_budget_label(Color(1.0, 0.40, 0.25, 1.0))


## SPA-627: One-time flash banner shown after the initial briefing overlay is dismissed.
func show_o_hotkey_hint() -> void:
	_show_banner_fn.call("Press O anytime to review your mission",
		Color(0.70, 0.85, 0.55, 1.0), 5.0)


# ── Build ─────────────────────────────────────────────────────────────────────

func _build_nudge_label() -> void:
	_nudge_panel = PanelContainer.new()
	var nudge_style := StyleBoxFlat.new()
	nudge_style.bg_color = Color(0.05, 0.12, 0.05, 0.70)
	nudge_style.set_border_width_all(1)
	nudge_style.border_color = Color(0.40, 1.0, 0.50, 0.35)
	nudge_style.set_corner_radius_all(4)
	nudge_style.content_margin_left   = 8.0
	nudge_style.content_margin_right  = 8.0
	nudge_style.content_margin_top    = 4.0
	nudge_style.content_margin_bottom = 4.0
	_nudge_panel.add_theme_stylebox_override("panel", nudge_style)

	_nudge_label = Label.new()
	_nudge_label.text = ""
	_nudge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nudge_label.add_theme_font_size_override("font_size", 14)
	_nudge_label.add_theme_color_override("font_color", C_NUDGE)
	_nudge_label.add_theme_constant_override("outline_size", 3)
	_nudge_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_nudge_panel.add_child(_nudge_label)

	# Insert right after DayRow (index 0 in VBox).
	_vbox.add_child(_nudge_panel)
	_vbox.move_child(_nudge_panel, 1)


## SPA-627: Subtle "Press O to review mission" label beneath the objective line.
func _build_o_hint_label() -> void:
	o_hint_label = Label.new()
	o_hint_label.text = "Press O to review mission"
	o_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	o_hint_label.add_theme_font_size_override("font_size", 8)
	o_hint_label.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50, 0.40))
	o_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(o_hint_label)
	# Insert right after GoalLabel (goal_flavor may be null here; it shifts
	# naturally if inserted later at goal_label+1 via move_child).
	var hint_idx: int = _goal_label.get_index() + 1
	_vbox.move_child(o_hint_label, hint_idx)


func _build_budget_label(goal_flavor_label: Label, win_target_label: Label) -> void:
	_lbl_budget = Label.new()
	_lbl_budget.text = ""
	_lbl_budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_budget.add_theme_font_size_override("font_size", 14)
	_lbl_budget.add_theme_color_override("font_color", Color(0.88, 0.78, 0.48, 1.0))
	_lbl_budget.add_theme_constant_override("outline_size", 2)
	_lbl_budget.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_lbl_budget.tooltip_text = "Daily budget — actions and whispers refresh at dawn"
	_lbl_budget.mouse_filter = Control.MOUSE_FILTER_STOP
	_vbox.add_child(_lbl_budget)

	# Position right after the deepest preceding sibling that exists.
	var insert_idx: int = _goal_label.get_index() + 1
	if goal_flavor_label != null:
		insert_idx = goal_flavor_label.get_index() + 1
	if o_hint_label != null:
		insert_idx = o_hint_label.get_index() + 1
	if win_target_label != null:
		insert_idx = win_target_label.get_index() + 1
	_vbox.move_child(_lbl_budget, insert_idx)


func _build_midgame_nudge() -> void:
	_midgame_nudge_bg = ColorRect.new()
	_midgame_nudge_bg.color = C_MIDGAME_NUDGE_BG
	_midgame_nudge_bg.anchor_left   = 1.0
	_midgame_nudge_bg.anchor_right  = 1.0
	_midgame_nudge_bg.anchor_top    = 1.0
	_midgame_nudge_bg.anchor_bottom = 1.0
	_midgame_nudge_bg.offset_left   = -340.0
	_midgame_nudge_bg.offset_right  = -8.0
	_midgame_nudge_bg.offset_top    = -60.0
	_midgame_nudge_bg.offset_bottom = -8.0
	_midgame_nudge_bg.modulate.a = 0.0
	_midgame_nudge_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_midgame_nudge_bg.gui_input.connect(_on_midgame_nudge_clicked)
	_hud_root.add_child(_midgame_nudge_bg)

	_midgame_nudge_label = Label.new()
	_midgame_nudge_label.text = ""
	_midgame_nudge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_midgame_nudge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_midgame_nudge_label.offset_left   = 8.0
	_midgame_nudge_label.offset_top    = 6.0
	_midgame_nudge_label.offset_right  = -8.0
	_midgame_nudge_label.offset_bottom = -6.0
	_midgame_nudge_label.add_theme_font_size_override("font_size", 12)
	_midgame_nudge_label.add_theme_color_override("font_color", C_MIDGAME_NUDGE)
	_midgame_nudge_label.add_theme_constant_override("outline_size", 2)
	_midgame_nudge_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_midgame_nudge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_midgame_nudge_bg.add_child(_midgame_nudge_label)


# ── Budget label refresh ──────────────────────────────────────────────────────

func _refresh_budget_label() -> void:
	if _lbl_budget == null or _intel_store == null:
		return
	var actions:  int = _intel_store.recon_actions_remaining
	var whispers: int = _intel_store.whisper_tokens_remaining
	var day: int = _day_night.current_day if _day_night != null else 1

	# Detect recon action spend or dawn replenish.
	if _budget_last_actions >= 0 and actions < _budget_last_actions:
		var delta: int = _budget_last_actions - actions
		_spawn_budget_delta("-%d" % delta, Color(1.0, 0.35, 0.25, 1.0))
		if day == 1:
			_flash_budget_label(actions)
		else:
			_pulse_budget_label(Color(1.0, 0.65, 0.20, 1.0))
			_lbl_budget.text = "%d actions · %d whispers" % [actions, whispers]
	elif _budget_last_actions >= 0 and actions > _budget_last_actions:
		_spawn_budget_delta("+%d" % (actions - _budget_last_actions), Color(0.30, 0.95, 0.45, 1.0))
		_lbl_budget.text = "%d actions · %d whispers" % [actions, whispers]
	else:
		_lbl_budget.text = "%d actions · %d whispers" % [actions, whispers]
	_budget_last_actions = actions

	# Detect whisper replenish at dawn (spend is handled via on_whisper_spent).
	if _budget_last_whispers >= 0 and whispers > _budget_last_whispers:
		_spawn_budget_delta("+%d" % (whispers - _budget_last_whispers), Color(0.30, 0.95, 0.45, 1.0))
	_budget_last_whispers = whispers


## Brief gold flash on the budget label, then revert to the standard counter.
func _flash_budget_label(actions_remaining: int) -> void:
	if _lbl_budget == null:
		return
	if _budget_flash_tween != null and _budget_flash_tween.is_valid():
		_budget_flash_tween.kill()
		_lbl_budget.self_modulate = Color.WHITE
	_lbl_budget.text = "%d actions remaining today" % actions_remaining
	_budget_flash_tween = create_tween()
	_budget_flash_tween.tween_property(_lbl_budget, "self_modulate",
		Color(1.0, 0.85, 0.15, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	_budget_flash_tween.tween_property(_lbl_budget, "self_modulate",
		Color.WHITE, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	# Restore full counter text after flash.
	_budget_flash_tween.tween_callback(func() -> void:
		if _lbl_budget != null and _intel_store != null:
			_lbl_budget.text = "%d actions · %d whispers" % [
				_intel_store.recon_actions_remaining,
				_intel_store.whisper_tokens_remaining])


## SPA-903: Spawn a floating +/- number near the budget label that floats up and fades.
func _spawn_budget_delta(text: String, color: Color) -> void:
	if _lbl_budget == null or not is_inside_tree():
		return
	if _delta_layer == null:
		_delta_layer = CanvasLayer.new()
		_delta_layer.layer = 15
		_hud_root.add_child(_delta_layer)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	var rect := _lbl_budget.get_global_rect()
	lbl.position = Vector2(rect.position.x + rect.size.x * 0.5 - 12.0, rect.position.y - 4.0)
	_delta_layer.add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 36.0, 0.9) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.85) \
		.set_delay(0.08).set_ease(Tween.EASE_IN)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(lbl):
			lbl.queue_free()
	)


## Brief colour pulse on the budget label confirming a resource spend.
func _pulse_budget_label(pulse_color: Color) -> void:
	if _lbl_budget == null:
		return
	if _budget_flash_tween != null and _budget_flash_tween.is_valid():
		_budget_flash_tween.kill()
		_lbl_budget.self_modulate = Color.WHITE
	_budget_flash_tween = create_tween()
	_budget_flash_tween.tween_property(_lbl_budget, "self_modulate", pulse_color, 0.07) \
		.set_ease(Tween.EASE_OUT)
	_budget_flash_tween.tween_property(_lbl_budget, "self_modulate", Color.WHITE, 0.85) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


# ── Tutorial nudge refresh ────────────────────────────────────────────────────

func _refresh_nudge() -> void:
	if _nudge_label == null or _nudge_phase >= _NUDGE_TEXTS.size():
		return

	# SPA-675: nudge text is S1-only onboarding; hide it on all other scenarios.
	if _scenario_manager != null and _scenario_manager._active_scenario != 1:
		_nudge_label.text = ""
		_nudge_label.visible = false
		_nudge_phase = _NUDGE_TEXTS.size()  # mark done so midgame nudge can activate
		return

	# Phase 0 → 1: player has observed at least one building.
	if _nudge_phase == 0 and _intel_store != null:
		if not _intel_store.location_intel.is_empty():
			_nudge_phase = 1

	# Phase 1 → 2: player has eavesdropped on two or more NPC pairs.
	if _nudge_phase == 1 and _intel_store != null:
		if _intel_store.relationship_intel.size() >= 2:
			_nudge_phase = 2

	# Phase 2 → 3: player has seeded at least one rumor (any NPC has a rumor slot).
	if _nudge_phase == 2 and _world_ref != null and "npcs" in _world_ref:
		for npc in _world_ref.npcs:
			if not npc.rumor_slots.is_empty():
				_nudge_phase = 3
				break

	# Phase 3 → 4 (done): any NPC has entered the SPREAD state.
	if _nudge_phase == 3 and _world_ref != null and "npcs" in _world_ref:
		for npc in _world_ref.npcs:
			for rid in npc.rumor_slots:
				if npc.rumor_slots[rid].state == Rumor.RumorState.SPREAD:
					_nudge_phase = 4
					break
			if _nudge_phase == 4:
				break

	# Update label visibility and text.
	if _nudge_phase >= _NUDGE_TEXTS.size():
		_nudge_label.text = ""
		_nudge_label.visible = false
	else:
		_nudge_label.text = "▸ " + _NUDGE_TEXTS[_nudge_phase]
		_nudge_label.visible = true
		# SPA-537: pulse the nudge label when the phase changes so it's unmissable.
		if _nudge_phase != _nudge_last_phase:
			_nudge_last_phase = _nudge_phase
			_pulse_nudge()


## SPA-537: Attention pulse when the nudge text changes.
func _pulse_nudge() -> void:
	if _nudge_label == null:
		return
	if _nudge_pulse_tween != null and _nudge_pulse_tween.is_valid():
		_nudge_pulse_tween.kill()
		_nudge_label.scale = Vector2.ONE
		_nudge_label.add_theme_color_override("font_color", C_NUDGE)
	_nudge_label.pivot_offset = _nudge_label.size / 2.0
	_nudge_pulse_tween = create_tween()
	var flash_color := Color(0.90, 1.0, 0.70, 1.0)
	_nudge_pulse_tween.tween_property(_nudge_label, "scale", Vector2(1.15, 1.15), 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_nudge_pulse_tween.parallel().tween_method(
		func(c: Color) -> void: _nudge_label.add_theme_color_override("font_color", c),
		flash_color, C_NUDGE, 0.6
	)
	_nudge_pulse_tween.tween_property(_nudge_label, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


# ── Mid-game nudge refresh ────────────────────────────────────────────────────

func _refresh_midgame_nudge() -> void:
	# Only fire after tutorial nudges are done (phase >= 4) and after day 2.
	if _nudge_phase < 4:
		return
	if _day_night == null or _day_night.current_day < 3:
		return

	# Throttle: max 1 nudge per day-phase (morning/afternoon/evening/night).
	var tick: int = _day_night.current_tick if "current_tick" in _day_night else 0
	var tpd:  int = _day_night.ticks_per_day if "ticks_per_day" in _day_night else 24
	var hour: int = tick % tpd
	var phase_key: String
	if hour < 6:
		phase_key = "%d_dawn"      % _day_night.current_day
	elif hour < 12:
		phase_key = "%d_morning"   % _day_night.current_day
	elif hour < 18:
		phase_key = "%d_afternoon" % _day_night.current_day
	else:
		phase_key = "%d_evening"   % _day_night.current_day

	if phase_key == _midgame_nudge_last_phase_key:
		return

	var nudge_text: String = _pick_midgame_nudge(hour)
	if nudge_text.is_empty():
		return

	_midgame_nudge_last_phase_key = phase_key
	_show_midgame_nudge(nudge_text)


func _pick_midgame_nudge(hour_of_day: int) -> String:
	if _world_ref == null or not "npcs" in _world_ref:
		return ""

	# Priority 1: A rumor is CONTRADICTED — alert player.
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state == Rumor.RumorState.CONTRADICTED:
				return "A rumour was contradicted — consider crafting a new claim to regain momentum."

	# Priority 2: A rumor is stalling and player has whisper tokens.
	var stalling_count: int = 0
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state == Rumor.RumorState.BELIEVE:
				stalling_count += 1
	var whispers: int = _intel_store.whisper_tokens_remaining if _intel_store != null else 0
	if stalling_count > 0 and whispers > 0:
		return "A rumour is stalling — seed it to a new NPC or bolster with evidence."

	# Priority 3: Unused recon actions past morning.
	if _intel_store != null and hour_of_day >= 6:
		var actions:     int = _intel_store.recon_actions_remaining
		var max_actions: int = _intel_store.max_daily_actions
		if actions == max_actions and max_actions > 0:
			return "You have unused Recon actions — Observe or Eavesdrop to gather intel."

	# Priority 4: Journal has unseen rumor state changes.
	var unseen_changes: bool = false
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			var state_key: String = "%s_%s" % [rid, str(slot.state)]
			var prev: String = _midgame_last_seen_rumor_states.get(rid, "")
			if not prev.is_empty() and prev != state_key:
				unseen_changes = true
			_midgame_last_seen_rumor_states[rid] = state_key

	if unseen_changes:
		return "Check the Journal (J) — rumours have changed since you last looked."

	return ""


func _show_midgame_nudge(text: String) -> void:
	if _midgame_nudge_label == null or _midgame_nudge_bg == null:
		return
	if _midgame_nudge_tween != null and _midgame_nudge_tween.is_valid():
		_midgame_nudge_tween.kill()
	_midgame_nudge_label.text = text
	_midgame_nudge_bg.modulate.a = 0.0
	var final_left: float = -340.0
	_midgame_nudge_bg.offset_left  = -8.0
	_midgame_nudge_bg.offset_right = -8.0
	_midgame_nudge_tween = create_tween()
	_midgame_nudge_tween.tween_property(_midgame_nudge_bg, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_midgame_nudge_tween.parallel().tween_property(_midgame_nudge_bg, "offset_left", final_left, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Auto-dismiss after 6 seconds.
	_midgame_nudge_tween.tween_interval(6.0)
	_midgame_nudge_tween.tween_property(_midgame_nudge_bg, "modulate:a", 0.0, 0.8) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func _dismiss_midgame_nudge() -> void:
	if _midgame_nudge_bg == null:
		return
	if _midgame_nudge_tween != null and _midgame_nudge_tween.is_valid():
		_midgame_nudge_tween.kill()
	_midgame_nudge_tween = create_tween()
	_midgame_nudge_tween.tween_property(_midgame_nudge_bg, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func _on_midgame_nudge_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_midgame_nudge()
