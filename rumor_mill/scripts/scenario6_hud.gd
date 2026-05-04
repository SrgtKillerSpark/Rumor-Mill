extends BaseScenarioHud

## scenario6_hud.gd — Dual-track reputation + heat stealth display.
##
## Shows Aldric Vane (target to expose) and Marta Coin (patron to protect)
## reputation tracks, plus a heat gauge with the S6 lower ceiling (60).
##
## Layout:
##   Scenario 6: The Merchant's Debt
##   [Aldric Vane]  Rep: 55 / 100  Target: ≤30  [bar]
##   [Marta Coin]   Rep: 52 / 100  Target: 62+  [bar]
##   Heat: 0 / 60                                [bar]
##   Days remaining: 22
##
## Wire via setup(world, day_night) from main.gd.

const BAR_WIDTH  := 160

const TOAST_CORNER_RADIUS := 4
const TOAST_PANEL_INSET_H := 8
const TOAST_PANEL_TOP     := 90
const TOAST_PANEL_BOTTOM  := 134

# Heat-bar colours — spec: yellow below 40, orange@40, red@50.
const C_HEAT_YELLOW := Color(0.95, 0.85, 0.10, 1.0)
const C_HEAT_ORANGE := Color(0.90, 0.50, 0.05, 1.0)

# ── Node refs ────────────────────────────────────────────────────────────────
var _aldric_score_lbl: Label     = null
var _marta_score_lbl:  Label     = null
var _heat_lbl:         Label     = null
var _aldric_bar:       ColorRect = null
var _aldric_bar_bg:    ColorRect = null
var _marta_bar:        ColorRect = null
var _marta_bar_bg:     ColorRect = null
var _heat_bar:         ColorRect = null
var _heat_bar_bg:      ColorRect = null

# ── Guild defense tracking ────────────────────────────────────────────────────
var _guild_defense_lbl:  Label     = null
var _guild_threat_bar:   ColorRect = null
var _guild_threat_bg:    Panel     = null
var _guild_defense_agent_ref             = null
var _guild_last_defense_day: int   = -1
var _guild_defenses_this_run: int  = 0

# ── Mid-game event display ───────────────────────────────────────────────────
var _event_lbl:         Label = null
var _event_toast_panel: Panel = null
var _event_toast_lbl:   Label = null
var _event_toast_tween: Tween = null

# ── S6 Blackmail Evidence verb ────────────────────────────────────────────────
## Blackmail evidence action — costs and effects sourced from ScenarioConfig.
const BLACKMAIL_WHISPER_COST := ScenarioConfig.S6_BLACKMAIL_WHISPER_COST
const BLACKMAIL_REP_HIT      := ScenarioConfig.S6_BLACKMAIL_REP_HIT
const BLACKMAIL_HEAT_ADD     := ScenarioConfig.S6_BLACKMAIL_HEAT_ADD
const BLACKMAIL_MAX_USES     := ScenarioConfig.S6_BLACKMAIL_MAX_USES
const BLACKMAIL_HEAT_NPCS    := ScenarioConfig.S6_BLACKMAIL_HEAT_NPCS
var _blackmail_btn: Button = null
var _blackmail_lbl: Label  = null


func _scenario_number() -> int:
	return 6


func _on_setup_extra(world: Node2D) -> void:
	# Wire guild defense agent (active for S6).
	var gda = world.get("guild_defense_agent") if world != null else null
	if gda != null and gda._active:
		_guild_defense_agent_ref = gda
		gda.defense_fired.connect(_on_guild_defense_fired)
	# Wire mid-game event outcome toast.
	var mga: MidGameEventAgent = world.get("mid_game_event_agent") if world != null else null
	if mga != null:
		mga.event_resolved.connect(_on_mid_game_event_resolved)


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var hbox := _make_panel("Scenario6Panel", 72)

	# Title — text updated each tick by BaseScenarioHud._update_title().
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 6 — Day 1 — Morning"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	title_lbl.tooltip_text = "The Merchant's Debt — expose Aldric Vane (rep \u2264 %d) while protecting Marta Coin (rep \u2265 %d). Heat ceiling is %d." % [ScenarioConfig.S6_WIN_ALDRIC_MAX, ScenarioConfig.S6_WIN_MARTA_MIN, int(ScenarioConfig.S6_EXPOSED_HEAT)]
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(title_lbl)
	_title_lbl = title_lbl

	# Aldric track (target — expose / undermine).
	var aldric_vbox := VBoxContainer.new()
	aldric_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(aldric_vbox)

	_aldric_score_lbl = Label.new()
	_aldric_score_lbl.add_theme_font_size_override("font_size", 14)
	_aldric_score_lbl.add_theme_color_override("font_color", C_BODY)
	_aldric_score_lbl.text = "Aldric Vane  Rep: 55 / 100  Target: \u226430"
	_aldric_score_lbl.tooltip_text = "Aldric Vane's reputation. Win condition: drag to %d or below to expose his embezzlement." % ScenarioConfig.S6_WIN_ALDRIC_MAX
	_aldric_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_aldric_score_lbl.clip_text = true
	_apply_text_outline(_aldric_score_lbl)
	aldric_vbox.add_child(_aldric_score_lbl)

	var aldric_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Aldric's reputation. Shrinks with Accusation/Scandal rumors. Must reach 30 or below to win.")
	_aldric_bar_bg = aldric_pair[0]
	_aldric_bar    = aldric_pair[1]
	aldric_vbox.add_child(_aldric_bar_bg)

	# Marta track (patron — protect / boost).
	var marta_vbox := VBoxContainer.new()
	marta_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(marta_vbox)

	_marta_score_lbl = Label.new()
	_marta_score_lbl.add_theme_font_size_override("font_size", 14)
	_marta_score_lbl.add_theme_color_override("font_color", C_BODY)
	_marta_score_lbl.text = "Marta Coin  Rep: 52 / 100  Target: %d+" % ScenarioConfig.S6_WIN_MARTA_MIN
	_marta_score_lbl.tooltip_text = "Marta Coin's reputation. Win condition: keep at %d or above. Below %d = instant fail (she's been silenced)." % [ScenarioConfig.S6_WIN_MARTA_MIN, ScenarioConfig.S6_FAIL_MARTA_BELOW]
	_marta_score_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_marta_score_lbl.clip_text = true
	_apply_text_outline(_marta_score_lbl)
	marta_vbox.add_child(_marta_score_lbl)

	var marta_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Marta's reputation. Grows with Praise rumors. Must stay at 62+ to win. Below 30 = instant fail.")
	_marta_bar_bg = marta_pair[0]
	_marta_bar    = marta_pair[1]
	marta_vbox.add_child(_marta_bar_bg)

	# Heat gauge.
	var heat_vbox := VBoxContainer.new()
	heat_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(heat_vbox)

	_heat_lbl = Label.new()
	_heat_lbl.add_theme_font_size_override("font_size", 14)
	_heat_lbl.add_theme_color_override("font_color", C_BODY)
	_heat_lbl.text = "Heat: 0 / 55"
	_heat_lbl.tooltip_text = "Your suspicion level. Guards are on Aldric's payroll — exposure threshold is %d (not the usual 80). Keep it low." % int(ScenarioConfig.S6_EXPOSED_HEAT)
	_heat_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_heat_lbl.clip_text = true
	_apply_text_outline(_heat_lbl)
	heat_vbox.add_child(_heat_lbl)

	var heat_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
		"Heat gauge. At %d, the Guard Captain exposes you. Route rumors through non-merchant channels to stay hidden." % int(ScenarioConfig.S6_EXPOSED_HEAT))
	_heat_bar_bg = heat_pair[0]
	_heat_bar    = heat_pair[1]
	heat_vbox.add_child(_heat_bar_bg)

	# Right column: days + result.
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 14)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 22"
	_days_lbl.tooltip_text = "Days before the guild closes its books. Aldric must be exposed and Marta safe by deadline."
	_days_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_days_lbl.clip_text = true
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 16)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	_result_lbl.clip_text = true
	right_vbox.add_child(_result_lbl)

	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 11)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "Aldric: \u2264%d | Marta: %d+ | Heat: <%d" % [ScenarioConfig.S6_WIN_ALDRIC_MAX, ScenarioConfig.S6_WIN_MARTA_MIN, int(ScenarioConfig.S6_EXPOSED_HEAT)]
	right_vbox.add_child(legend_lbl)

	# ── Guild defense status ──────────────────────────────────────────────────
	_guild_defense_lbl = Label.new()
	_guild_defense_lbl.add_theme_font_size_override("font_size", 11)
	_guild_defense_lbl.add_theme_color_override("font_color", Color(0.70, 0.50, 0.40, 0.80))
	_guild_defense_lbl.text = "Guild: waiting to defend Aldric"
	_guild_defense_lbl.tooltip_text = "Aldric's merchant allies periodically seed praise rumors to protect his reputation. Counter-route your attacks through non-merchant channels."
	_guild_defense_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_guild_defense_lbl.clip_text = true
	right_vbox.add_child(_guild_defense_lbl)

	var threat_pair := _make_progress_bar(100, 7,
		"Guild defense threat level — higher means they are defending more frequently.")
	_guild_threat_bg  = threat_pair[0]
	_guild_threat_bar = threat_pair[1]
	_guild_threat_bar.color = Color(0.85, 0.45, 0.15, 1.0)  # orange threat
	right_vbox.add_child(_guild_threat_bg)

	# ── Upcoming event indicator ──────────────────────────────────────────────
	_event_lbl = Label.new()
	_event_lbl.add_theme_font_size_override("font_size", 11)
	_event_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.40, 0.85))
	_event_lbl.text = ""
	_event_lbl.tooltip_text = "Next mid-game narrative event window."
	_event_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_event_lbl.clip_text = true
	right_vbox.add_child(_event_lbl)

	# ── Blackmail Evidence verb ──────────────────────────────────────────────
	_blackmail_btn = Button.new()
	_blackmail_btn.text = "Release Evidence"
	_blackmail_btn.tooltip_text = "Spend %d whisper tokens to leak blackmail evidence against Aldric (%d rep, +%.0f heat on his allies). Big risk, big impact. %d uses max." % [BLACKMAIL_WHISPER_COST, BLACKMAIL_REP_HIT, BLACKMAIL_HEAT_ADD, BLACKMAIL_MAX_USES]
	_blackmail_btn.add_theme_font_size_override("font_size", 12)
	_blackmail_btn.disabled = true
	_blackmail_btn.pressed.connect(_on_blackmail_pressed)
	right_vbox.add_child(_blackmail_btn)

	_blackmail_lbl = Label.new()
	_blackmail_lbl.add_theme_font_size_override("font_size", 11)
	_blackmail_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.20, 0.90))
	_blackmail_lbl.text = ""
	_blackmail_lbl.visible = false
	_blackmail_lbl.clip_text = true
	right_vbox.add_child(_blackmail_lbl)

	# ── Event outcome toast ───────────────────────────────────────────────────
	# Appears briefly when a mid-game event choice resolves.
	_event_toast_panel = Panel.new()
	var ev_toast_style := StyleBoxFlat.new()
	ev_toast_style.bg_color = Color(0.10, 0.08, 0.06, 0.93)
	ev_toast_style.set_corner_radius_all(TOAST_CORNER_RADIUS)
	_event_toast_panel.add_theme_stylebox_override("panel", ev_toast_style)
	_event_toast_panel.set_anchor(SIDE_LEFT,   0.0)
	_event_toast_panel.set_anchor(SIDE_RIGHT,  1.0)
	_event_toast_panel.set_anchor(SIDE_TOP,    0.0)
	_event_toast_panel.set_anchor(SIDE_BOTTOM, 0.0)
	_event_toast_panel.set_offset(SIDE_LEFT,    TOAST_PANEL_INSET_H)
	_event_toast_panel.set_offset(SIDE_RIGHT,  -TOAST_PANEL_INSET_H)
	_event_toast_panel.set_offset(SIDE_TOP,     TOAST_PANEL_TOP)
	_event_toast_panel.set_offset(SIDE_BOTTOM,  TOAST_PANEL_BOTTOM)
	_event_toast_panel.visible = false
	add_child(_event_toast_panel)

	_event_toast_lbl = Label.new()
	_event_toast_lbl.add_theme_font_size_override("font_size", 12)
	_event_toast_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.60, 1.0))
	_event_toast_lbl.add_theme_constant_override("outline_size", 2)
	_event_toast_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_event_toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_toast_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_event_toast_lbl.set_offset(SIDE_LEFT,   TOAST_PANEL_INSET_H)
	_event_toast_lbl.set_offset(SIDE_RIGHT, -TOAST_PANEL_INSET_H)
	_event_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_toast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_event_toast_panel.add_child(_event_toast_lbl)


# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _has_world_deps():
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var sm:  ScenarioManager  = _world_ref.scenario_manager
	var progress: Dictionary  = sm.get_scenario_6_progress(rep)

	var aldric_score: int   = progress["aldric_score"]
	var marta_score:  int   = progress["marta_score"]
	var max_heat:     float = progress["max_heat"]
	var heat_ceil:    float = progress["heat_ceiling"]
	var state               = progress["state"]

	_aldric_score_lbl.text = "Aldric Vane   Rep: %d / 100   Target: \u2264%d" % [aldric_score, progress["win_aldric_max"]]
	_marta_score_lbl.text  = "Marta Coin    Rep: %d / 100   Target: %d+" % [marta_score, progress["win_marta_min"]]
	_heat_lbl.text         = "Heat: %d / %d" % [int(max_heat), int(heat_ceil)]

	# Aldric bar: lower is better, target <= 30.
	_aldric_bar.custom_minimum_size.x = BAR_WIDTH * clamp(float(aldric_score) / 100.0, 0.0, 1.0)
	if aldric_score <= progress["win_aldric_max"]:
		_aldric_bar.color = C_WIN
	elif aldric_score <= 50:
		_aldric_bar.color = C_NEUTRAL
	else:
		_aldric_bar.color = C_FAIL

	# Marta bar: higher is better, target >= 60.
	_marta_bar.custom_minimum_size.x = BAR_WIDTH * clamp(float(marta_score) / 100.0, 0.0, 1.0)
	if marta_score >= progress["win_marta_min"]:
		_marta_bar.color = C_WIN
	elif marta_score >= progress["fail_marta_below"]:
		_marta_bar.color = C_NEUTRAL
	else:
		_marta_bar.color = C_FAIL

	# Heat bar: lower is better, ceiling at 55 (S6_EXPOSED_HEAT).
	# Spec thresholds: yellow below 40, orange@40, red@50.
	var heat_ratio: float = clamp(max_heat / heat_ceil, 0.0, 1.0) if heat_ceil > 0 else 0.0
	_heat_bar.custom_minimum_size.x = BAR_WIDTH * heat_ratio
	if max_heat >= 50.0:
		_heat_bar.color = C_FAIL
	elif max_heat >= 40.0:
		_heat_bar.color = C_HEAT_ORANGE
	else:
		_heat_bar.color = C_HEAT_YELLOW

	_update_days_remaining(sm)
	_update_result_label(state,
		"VICTORY — Aldric Vane is exposed",
		"FAILED — The guild closes ranks")
	_update_blackmail_button()
	_update_guild_defense_display()
	_update_event_display(sm)


# ── Blackmail Evidence verb ───────────────────────────────────────────────────

## Sync the Release Evidence button enabled state each refresh.
func _update_blackmail_button() -> void:
	if _blackmail_btn == null or _world_ref == null:
		return
	var intel: PlayerIntelStore = _world_ref.get("intel_store")
	var effective_max: int = BLACKMAIL_MAX_USES + (intel.bonus_expose_uses if intel != null else 0)
	var uses_left: int = effective_max - (intel.blackmail_uses_count if intel != null else 0)
	var has_whispers: bool = intel != null and intel.whisper_tokens_remaining >= BLACKMAIL_WHISPER_COST
	_blackmail_btn.disabled = not (has_whispers and uses_left > 0)
	var whispers: int = intel.whisper_tokens_remaining if intel != null else 0
	_blackmail_btn.tooltip_text = "Leak blackmail evidence (%d rep on Aldric, +%.0f heat). Costs %d whisper tokens (%d available). %d/%d uses remaining." % [BLACKMAIL_REP_HIT, BLACKMAIL_HEAT_ADD, BLACKMAIL_WHISPER_COST, whispers, uses_left, effective_max]


# ── Guild defense display ─────────────────────────────────────────────────────

## Update guild defense cooldown label and threat bar.
func _update_guild_defense_display() -> void:
	if _guild_defense_lbl == null:
		return
	if _guild_defense_agent_ref == null or not _guild_defense_agent_ref._active:
		_guild_defense_lbl.text = "Guild: waiting to defend Aldric"
		if _guild_threat_bar != null:
			_guild_threat_bar.custom_minimum_size.x = 0
		return
	var gda = _guild_defense_agent_ref
	var sm: ScenarioManager = _world_ref.get("scenario_manager") if _world_ref != null else null
	var current_day: int = sm.get_current_day(_day_night_ref.current_tick) \
		if sm != null and _day_night_ref != null else 0
	if _guild_last_defense_day < 0:
		_guild_defense_lbl.text = "Guild: first defense ~Day %d" % gda.start_day
		_guild_defense_lbl.add_theme_color_override("font_color", Color(0.70, 0.50, 0.40, 0.80))
	else:
		var next_day: int = _guild_last_defense_day + gda.cooldown_days
		var days_until: int = next_day - current_day
		if days_until <= 0:
			_guild_defense_lbl.text = "Guild: defending now!"
			_guild_defense_lbl.add_theme_color_override("font_color", C_FAIL)
		elif days_until == 1:
			_guild_defense_lbl.text = "Guild: defends tomorrow (Day %d)" % next_day
			_guild_defense_lbl.add_theme_color_override("font_color", C_NEUTRAL)
		else:
			_guild_defense_lbl.text = "Guild: next defense Day %d (in %d days)" % \
				[next_day, days_until]
			_guild_defense_lbl.add_theme_color_override("font_color",
				Color(0.70, 0.50, 0.40, 0.80))
	# Threat bar: fills based on how many defenses have fired (cap at 5 for full bar).
	if _guild_threat_bar != null:
		var threat_ratio: float = clamp(float(_guild_defenses_this_run) / 5.0, 0.0, 1.0)
		_guild_threat_bar.custom_minimum_size.x = 100 * threat_ratio
		if threat_ratio >= 0.80:
			_guild_threat_bar.color = C_FAIL
		elif threat_ratio >= 0.50:
			_guild_threat_bar.color = C_NEUTRAL
		else:
			_guild_threat_bar.color = Color(0.85, 0.45, 0.15, 1.0)


## Called by guild_defense_agent.defense_fired.
func _on_guild_defense_fired(day: int, _defender_id: String, _target_id: String) -> void:
	_guild_last_defense_day = day
	_guild_defenses_this_run += 1
	_update_guild_defense_display()


# ── Event display and toast ───────────────────────────────────────────────────

## Update upcoming event label.
func _update_event_display(sm: ScenarioManager) -> void:
	if _event_lbl == null or _world_ref == null:
		return
	var mga: MidGameEventAgent = _world_ref.get("mid_game_event_agent")
	if mga == null:
		return
	if mga.has_pending_event():
		var ev: Dictionary = mga.get_pending_event()
		_event_lbl.text = "Event: %s — choose now!" % ev.get("name", "?")
		_event_lbl.add_theme_color_override("font_color", C_NEUTRAL)
		return
	var current_day: int = sm.get_current_day(_day_night_ref.current_tick) \
		if _day_night_ref != null else 1
	var upcoming: Dictionary = mga.get_upcoming_event(current_day)
	if upcoming.is_empty():
		_event_lbl.text = ""
	else:
		var win_start: int = int(upcoming.get("dayWindowStart", 0))
		var win_end:   int = int(upcoming.get("dayWindowEnd", 0))
		var ev_name:   String = upcoming.get("name", "?")
		if current_day >= win_start:
			_event_lbl.text = "Event: %s (Day %d-%d)" % [ev_name, win_start, win_end]
			_event_lbl.add_theme_color_override("font_color", C_NEUTRAL)
		else:
			_event_lbl.text = "Next event: %s (Day %d)" % [ev_name, win_start]
			_event_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.45, 0.75))


## Called by mid_game_event_agent.event_resolved — shows outcome as a toast.
func _on_mid_game_event_resolved(_event_id: String, _choice_index: int, outcome_text: String) -> void:
	if _event_toast_panel == null or _event_toast_lbl == null:
		return
	AudioManager.play_sfx("milestone_chime")
	if _event_toast_tween != null and _event_toast_tween.is_valid():
		_event_toast_tween.kill()
	# Truncate long outcome text for HUD readability.
	var display_text: String = outcome_text.substr(0, mini(outcome_text.length(), 160))
	if outcome_text.length() > 160:
		display_text += "…"
	_event_toast_lbl.text = display_text
	_event_toast_panel.modulate.a = 1.0
	_event_toast_panel.visible = true
	_event_toast_tween = create_tween()
	_event_toast_tween.tween_interval(3.5)
	_event_toast_tween.tween_property(_event_toast_panel, "modulate:a", 0.0, 0.6)
	_event_toast_tween.tween_callback(func() -> void: _event_toast_panel.visible = false)


## Player clicked "Release Evidence" — spend whisper tokens, hit Aldric's rep, raise heat.
func _on_blackmail_pressed() -> void:
	if _world_ref == null:
		return
	var intel: PlayerIntelStore = _world_ref.get("intel_store")
	var rep: ReputationSystem = _world_ref.get("reputation_system")
	var sm: ScenarioManager = _world_ref.get("scenario_manager")
	if intel == null or rep == null or sm == null:
		return
	var effective_max: int = BLACKMAIL_MAX_USES + intel.bonus_expose_uses
	if intel.blackmail_uses_count >= effective_max:
		return
	# Spend 2 whisper tokens.
	if not intel.try_spend_whisper():
		return
	if not intel.try_spend_whisper():
		# Refund the first token if we couldn't spend the second.
		intel.whisper_tokens_remaining += 1
		return
	intel.blackmail_uses_count += 1
	AudioManager.play_sfx_pitched("reputation_down", 0.85)
	# Apply big reputation damage to Aldric.
	rep.apply_score_delta(ScenarioConfig.ALDRIC_VANE_ID, BLACKMAIL_REP_HIT)
	# Apply heat to Aldric's merchant defenders — they notice the source of the leak.
	for heat_npc_id in BLACKMAIL_HEAT_NPCS:
		intel.add_heat(heat_npc_id, BLACKMAIL_HEAT_ADD)
	var current_day: int = sm.get_current_day(_day_night_ref.current_tick) if _day_night_ref != null else 0
	var uses_left: int = effective_max - intel.blackmail_uses_count
	if _blackmail_lbl != null:
		_blackmail_lbl.text = "Day %d: Evidence released! Aldric %d rep. Heat spiking. (%d/%d uses left)" % [current_day, BLACKMAIL_REP_HIT, uses_left, effective_max]
		_blackmail_lbl.visible = true
		_blackmail_lbl.add_theme_color_override("font_color", Color(0.90, 0.45, 0.10, 1.0))
		var tween := create_tween()
		tween.tween_property(_blackmail_lbl, "modulate:a", 0.20, 0.10)
		tween.tween_property(_blackmail_lbl, "modulate:a", 1.0, 0.25)
	_update_blackmail_button()
