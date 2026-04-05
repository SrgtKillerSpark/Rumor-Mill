extends CanvasLayer

## objective_hud.gd — Persistent 3-tier objective tracker.
##
## Tier 1 (always visible): Goal verb headline, win progress bar + milestone
##   label, day counter with tempo indicator (green/yellow/red based on
##   progress% vs time%).
## Tier 2 (placeholder): Reserved for daily planning system.
## Tier 3 (placeholder): Context-aware suggestion engine slot.
##
## Also includes: metrics row, faction influence mini-panel, tutorial nudge,
## mid-game nudge, dawn bulletin, deadline warnings.

@onready var day_label:          Label          = $Panel/VBox/DayRow/DayLabel
@onready var day_max_label:      Label          = $Panel/VBox/DayRow/DayMaxLabel
@onready var days_remaining_lbl: Label          = $Panel/VBox/DayRow/DaysRemaining
@onready var time_label:         Label          = $Panel/VBox/DayRow/TimeOfDayLabel
@onready var goal_label:         Label          = $Panel/VBox/GoalLabel
@onready var progress_bar:       ColorRect      = $Panel/VBox/DayProgressBG/DayProgressBar
@onready var progress_bg:        ColorRect      = $Panel/VBox/DayProgressBG
@onready var win_progress_bar:   ColorRect      = $Panel/VBox/WinProgressBG/WinProgressBar
@onready var win_progress_lbl:   Label          = $Panel/VBox/WinProgressBG/WinProgressLabel
@onready var milestone_label:    Label          = $Panel/VBox/MilestoneLabel
@onready var tier2_container:    VBoxContainer  = $Panel/VBox/Tier2Container
@onready var tier3_container:    VBoxContainer  = $Panel/VBox/Tier3Container

var _scenario_manager: ScenarioManager = null
var _day_night:        Node            = null
var _days_allowed:     int             = 30

# ── Dawn bulletin / deadline warning state ───────────────────────────────────
var _reputation_system: ReputationSystem = null
var _intel_store: PlayerIntelStore = null
## NPC id → score snapshot taken at previous dawn for overnight delta comparison.
var _prev_dawn_scores: Dictionary = {}
## The programmatically-created banner label (shared for bulletin & warnings).
var _banner_label: Label = null
var _banner_tween: Tween = null
## Programmatic metrics row added below the scene-defined progress bar.
var _metrics_row: HBoxContainer = null
var _lbl_rumors_active: Label = null
var _lbl_rep_avg: Label = null
var _lbl_believers: Label = null
var _lbl_threat: Label = null

# ── Reputation tween state ───────────────────────────────────────────────────
## Last "true" avg rep value from the reputation system.
var _last_avg_rep: int = -1
## Currently displayed (possibly mid-tween) value used to drive label text.
var _displayed_avg_rep: float = -1.0
var _avg_rep_tween: Tween = null
var _avg_rep_flash_tween: Tween = null

# ── Day counter pulse tween ──────────────────────────────────────────────────
var _day_counter_tween: Tween = null

# ── SPA-627: "Press O" hotkey reminder label ─────────────────────────────────
var _o_hint_label: Label = null

# ── SPA-719: Win condition target line (live metrics below objective) ────────
var _win_target_label: Label = null

# ── Faction overview mini-panel ──────────────────────────────────────────────
## SPA-561: Pulsing win progress bar tween when near completion.
var _win_pulse_tween: Tween = null
var _win_pulse_active: bool = false

# ── SPA-648: Mid-game guidance nudge system ─────────────────────────────────
## Slide-in contextual nudge label (bottom-right, below toast area).
var _midgame_nudge_label: Label = null
var _midgame_nudge_bg: ColorRect = null
var _midgame_nudge_tween: Tween = null
## Throttle: only one mid-game nudge per day-phase (tick / ticks_per_day combo).
var _midgame_nudge_last_phase_key: String = ""
## Track journal "unseen" state transitions for the journal-check nudge.
var _midgame_last_seen_rumor_states: Dictionary = {}  # rumor_id → state string

# ── SPA-648: Mini objective progress indicator (near day counter) ───────────
var _mini_progress_label: Label = null

var _faction_panel: Panel = null
var _faction_labels: Dictionary = {}  # faction_id → {mood: Label, bar: ColorRect}
var _world_ref: Node2D = null

# ── Context-sensitive "what to do next" nudge (SPA-520 / SPA-537) ───────────
var _nudge_label: Label = null
var _nudge_pulse_tween: Tween = null
## Tracks which loop step the player has reached.  Once phase reaches 4 the
## nudge hides permanently for this session.
## 0 = observe, 1 = eavesdrop ×2, 2 = open Rumour Panel, 3 = watch spread, 4 = done
var _nudge_phase: int = 0
var _nudge_last_phase: int = -1  # tracks phase transitions for pulse effect

var _NUDGE_TEXTS: PackedStringArray = PackedStringArray([
	"NEXT: Right-click a building to Observe who is inside",
	"NEXT: Right-click two NPCs in conversation to Eavesdrop",
	"NEXT: Press R to craft your first Rumour",
	"Watch your rumour spread — check the Journal (J) for details",
])
const C_NUDGE := Color(0.40, 1.0, 0.50, 1.0)  # brighter green for visibility

# ── Tempo indicator colours (progress% vs time%) ────────────────────────────
const C_TEMPO_AHEAD  := Color(0.30, 0.85, 0.35, 1.0)  # green — ahead of schedule
const C_TEMPO_ON_PACE := Color(0.95, 0.85, 0.15, 1.0) # yellow — on pace
const C_TEMPO_BEHIND := Color(0.95, 0.20, 0.10, 1.0)  # red — behind schedule

# ── Urgency colour palette for day counter ───────────────────────────────────
const C_DAY_SAFE    := Color(0.30, 0.85, 0.35, 1.0)  # green
const C_DAY_CAUTION := Color(0.95, 0.85, 0.15, 1.0)  # yellow
const C_DAY_URGENT  := Color(0.95, 0.55, 0.10, 1.0)  # orange
const C_DAY_CRITICAL := Color(0.95, 0.20, 0.10, 1.0) # red

# ── Milestone tracking ──────────────────────────────────────────────────────
## The current milestone label being displayed (e.g. "Cracks appearing").
var _current_milestone_text: String = ""
## Cached progressMilestones dict from objectiveCard.
var _progress_milestones: Dictionary = {}
## Cached goalVerb and goalTarget from objectiveCard.
var _goal_verb: String = ""
var _goal_target: String = ""

# ── Tier 3: Suggestion engine (SPA-743) ─────────────────────────────────────
var _suggestion_engine: SuggestionEngine = null
var _suggestion_toast:  SuggestionToast  = null
## Cached budget counts for detecting player action via polling each tick.
var _t3_last_obs:   int = -1
var _t3_last_whisp: int = -1


func _ready() -> void:
	layer = 4
	_build_nudge_label()
	_build_o_hint_label()
	_build_win_target_label()
	_build_banner()
	_build_metrics_row()
	_build_midgame_nudge()
	_build_mini_progress()
	_build_tier3_suggestion()


func setup(scenario_manager: ScenarioManager, day_night: Node, rep_system: ReputationSystem = null, intel_store: PlayerIntelStore = null) -> void:
	_scenario_manager  = scenario_manager
	_day_night         = day_night
	_days_allowed      = scenario_manager.get_days_allowed()
	_reputation_system = rep_system
	_intel_store       = intel_store
	day_max_label.text = "%d" % _days_allowed
	# Load Tier 1 objective card data.
	var card: Dictionary = scenario_manager.get_objective_card()
	_goal_verb = card.get("goalVerb", "")
	_goal_target = card.get("goalTarget", "")
	_progress_milestones = card.get("progressMilestones", {})
	_refresh()
	if day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_day_changed)
	if day_night.has_signal("game_tick"):
		day_night.game_tick.connect(_on_tick)
	if day_night.has_signal("day_transition_started"):
		day_night.day_transition_started.connect(_on_day_transition_started)
	if scenario_manager.has_signal("deadline_warning"):
		scenario_manager.deadline_warning.connect(_on_deadline_warning)
	# Capture initial reputation scores for the first dawn comparison.
	_snapshot_dawn_scores()


## Called by main.gd to provide world reference for faction overview.
func setup_world(world: Node2D) -> void:
	_world_ref = world
	_build_faction_panel()
	# Initialize suggestion engine for Tier 3.
	if _scenario_manager != null and _intel_store != null and _reputation_system != null:
		_suggestion_engine = SuggestionEngine.new()
		_suggestion_engine.setup(world, _intel_store, _reputation_system,
			_scenario_manager, _day_night)
		_suggestion_engine.hint_ready.connect(_on_suggestion_hint_ready)
		# Connect day signals so the engine resets its daily budget correctly.
		if _day_night != null:
			if _day_night.has_signal("day_changed"):
				_day_night.day_changed.connect(_suggestion_engine._on_day_changed)
			if _day_night.has_signal("day_transition_started"):
				_day_night.day_transition_started.connect(_suggestion_engine._on_dawn)


func _on_day_changed(_day: int) -> void:
	_refresh()
	_show_dawn_bulletin()
	_snapshot_dawn_scores()


func _on_day_transition_started(_day: int) -> void:
	_pulse_day_counter()


func _pulse_day_counter() -> void:
	if day_label == null:
		return
	if _day_counter_tween != null and _day_counter_tween.is_valid():
		_day_counter_tween.kill()
		day_label.scale = Vector2.ONE
	day_label.pivot_offset = day_label.size / 2.0
	_day_counter_tween = create_tween()
	_day_counter_tween.tween_property(day_label, "scale", Vector2(1.2, 1.2), 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_day_counter_tween.tween_property(day_label, "scale", Vector2(1.0, 1.0), 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _on_tick(_tick: int) -> void:
	_refresh_time()
	_refresh_nudge()
	_refresh_win_target()
	_refresh_midgame_nudge()
	_refresh_mini_progress()
	_refresh_tier3_suggestion()


func _refresh() -> void:
	if _scenario_manager == null:
		return

	# Tier 1: Goal verb headline — e.g. "DESTROY Edric Fenn's reputation"
	if _goal_verb.is_empty():
		# Fallback to legacy one-liner if no goalVerb set.
		goal_label.text = _scenario_manager.get_objective_one_liner()
	else:
		goal_label.text = "%s %s" % [_goal_verb, _goal_target]

	# Days remaining with tempo colour in DayRow.
	var current_day: int = _day_night.current_day if _day_night != null else 1
	var remaining: int = max(_days_allowed - current_day + 1, 0)
	days_remaining_lbl.text = "— %d day%s remain" % [remaining, "" if remaining == 1 else "s"]

	_refresh_time()
	_refresh_nudge()
	_refresh_win_target()
	_refresh_metrics()
	_refresh_win_progress()
	_refresh_milestone_label()
	_refresh_tempo_indicator()
	_refresh_faction_panel()
	_refresh_mini_progress()


# ── Context-sensitive nudge (SPA-520) ───────────────────────────────────────

func _build_nudge_label() -> void:
	var vbox: VBoxContainer = $Panel/VBox
	# Wrap the nudge in a PanelContainer with a semi-transparent background
	# so the "what to do next" hint stands out clearly against the HUD.
	var nudge_panel := PanelContainer.new()
	var nudge_style := StyleBoxFlat.new()
	nudge_style.bg_color = Color(0.05, 0.12, 0.05, 0.70)
	nudge_style.set_border_width_all(1)
	nudge_style.border_color = Color(0.40, 1.0, 0.50, 0.35)
	nudge_style.set_corner_radius_all(4)
	nudge_style.content_margin_left = 8.0
	nudge_style.content_margin_right = 8.0
	nudge_style.content_margin_top = 4.0
	nudge_style.content_margin_bottom = 4.0
	nudge_panel.add_theme_stylebox_override("panel", nudge_style)
	_nudge_label = Label.new()
	_nudge_label.text = ""
	_nudge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nudge_label.add_theme_font_size_override("font_size", 14)
	_nudge_label.add_theme_color_override("font_color", C_NUDGE)
	_nudge_label.add_theme_constant_override("outline_size", 3)
	_nudge_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	nudge_panel.add_child(_nudge_label)
	# Insert right after DayRow (index 0 in VBox).
	vbox.add_child(nudge_panel)
	vbox.move_child(nudge_panel, 1)


## SPA-627: Subtle "Press O to review mission" label beneath the objective line.
func _build_o_hint_label() -> void:
	var vbox: VBoxContainer = $Panel/VBox
	_o_hint_label = Label.new()
	_o_hint_label.text = "Press O to review mission"
	_o_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_o_hint_label.add_theme_font_size_override("font_size", 8)
	_o_hint_label.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50, 0.40))
	_o_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_o_hint_label)
	# Insert right after ObjectiveLabel.
	vbox.move_child(_o_hint_label, goal_label.get_index() + 1)


## SPA-627: One-time flash banner shown after the initial briefing overlay is dismissed.
func show_o_hotkey_hint() -> void:
	_show_banner("Press O anytime to review your mission", Color(0.70, 0.85, 0.55, 1.0), 5.0)


# ── SPA-719: Win condition target line ───────────��──────────────────────────

## Build a persistent label below the objective text showing live win metrics.
func _build_win_target_label() -> void:
	var vbox: VBoxContainer = $Panel/VBox
	_win_target_label = Label.new()
	_win_target_label.text = ""
	_win_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_target_label.add_theme_font_size_override("font_size", 13)
	_win_target_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1.0))
	_win_target_label.add_theme_constant_override("outline_size", 3)
	_win_target_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_win_target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_win_target_label)
	# Insert right after GoalLabel (and after the O-hint if present).
	var insert_idx: int = goal_label.get_index() + 1
	if _o_hint_label != null:
		insert_idx = _o_hint_label.get_index() + 1
	vbox.move_child(_win_target_label, insert_idx)


## Refresh the win condition target line with live scenario-specific data.
func _refresh_win_target() -> void:
	if _win_target_label == null or _scenario_manager == null or _reputation_system == null:
		return
	if _world_ref == null:
		return
	var sid: String = _world_ref.active_scenario_id if "active_scenario_id" in _world_ref else ""
	var text: String = ""
	match sid:
		"scenario_1":
			var p: Dictionary = _scenario_manager.get_scenario_1_progress(_reputation_system)
			var score: int = p.get("edric_score", 50)
			var threshold: int = p.get("win_threshold", 30)
			text = "Edric Fenn: %d/100 — need < %d" % [score, threshold]
		"scenario_2":
			var p: Dictionary = _scenario_manager.get_scenario_2_progress(_reputation_system)
			var count: int = p.get("illness_believer_count", 0)
			var target: int = p.get("win_threshold", 7)
			var rejecters: Array = p.get("illness_rejecter_ids", [])
			var maren_status: String = "Safe"
			if ScenarioManager.MAREN_NUN_ID in rejecters:
				maren_status = "REJECTED"
			text = "Believers: %d/%d — Maren: %s" % [count, target, maren_status]
		"scenario_3":
			var p: Dictionary = _scenario_manager.get_scenario_3_progress(_reputation_system)
			var calder: int = p.get("calder_score", 50)
			var tomas: int = p.get("tomas_score", 50)
			var calder_target: int = p.get("calder_win_target", 75)
			var tomas_target: int = p.get("tomas_win_target", 35)
			text = "Calder: %d/%d | Tomas: %d/%d" % [calder, calder_target, tomas, tomas_target]
		"scenario_4":
			var p: Dictionary = _scenario_manager.get_scenario_4_progress(_reputation_system)
			var scores: Dictionary = p.get("protected_scores", {})
			var threshold: int = p.get("win_threshold", 45)
			var parts: PackedStringArray = PackedStringArray()
			for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
				var npc_score: int = scores.get(npc_id, 50)
				var display_name: String = npc_id.split("_")[0].capitalize()
				parts.append("%s: %d" % [display_name, npc_score])
			text = "%s — all need > %d" % [" | ".join(parts), threshold]
		"scenario_5":
			var p: Dictionary = _scenario_manager.get_scenario_5_progress(_reputation_system)
			var aldric: int = p.get("aldric_score", 48)
			var edric: int = p.get("edric_score", 58)
			var tomas: int = p.get("tomas_score", 45)
			text = "Aldric: %d | Edric: %d | Tomas: %d — need 65+ & rivals < 45" % [aldric, edric, tomas]
		"scenario_6":
			var p: Dictionary = _scenario_manager.get_scenario_6_progress(_reputation_system)
			var aldric: int = p.get("aldric_score", 55)
			var marta: int = p.get("marta_score", 52)
			text = "Aldric: %d | Marta: %d — need ≤ 30 & ≥ 60" % [aldric, marta]
	_win_target_label.text = text
	_win_target_label.visible = not text.is_empty()


func _refresh_nudge() -> void:
	if _nudge_label == null or _nudge_phase >= _NUDGE_TEXTS.size():
		return

	# SPA-675: nudge text is S1-only onboarding; hide it on all other scenarios.
	if _scenario_manager != null and _scenario_manager._active_scenario != 1:
		_nudge_label.text = ""
		_nudge_label.visible = false
		_nudge_phase = _NUDGE_TEXTS.size()  # mark done so midgame/tier3 can activate
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


## SPA-537: Attention pulse when the nudge text changes — scales up then back,
## and flashes a bright colour so the player cannot miss the new instruction.
func _pulse_nudge() -> void:
	if _nudge_label == null:
		return
	if _nudge_pulse_tween != null and _nudge_pulse_tween.is_valid():
		_nudge_pulse_tween.kill()
		_nudge_label.scale = Vector2.ONE
		_nudge_label.add_theme_color_override("font_color", C_NUDGE)
	_nudge_label.pivot_offset = _nudge_label.size / 2.0
	_nudge_pulse_tween = create_tween()
	# Flash bright white-green, then settle back to normal.
	var flash_color := Color(0.90, 1.0, 0.70, 1.0)
	_nudge_pulse_tween.tween_property(_nudge_label, "scale", Vector2(1.15, 1.15), 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_nudge_pulse_tween.parallel().tween_method(
		func(c: Color) -> void: _nudge_label.add_theme_color_override("font_color", c),
		flash_color, C_NUDGE, 0.6
	)
	_nudge_pulse_tween.tween_property(_nudge_label, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _refresh_time() -> void:
	if _day_night == null:
		return

	var current_day: int = _day_night.current_day

	# ── Day counter with urgency colouring ───────────────────────────────
	day_label.text = "DAY %d" % current_day
	var fraction: float = clampf(float(current_day - 1) / float(max(_days_allowed - 1, 1)), 0.0, 1.0)
	var day_color: Color = _get_urgency_color(fraction)
	day_label.add_theme_color_override("font_color", day_color)

	# Update time-of-day label.
	if "current_tick" in _day_night and "ticks_per_day" in _day_night:
		var tick: int      = _day_night.current_tick
		var tpd:  int      = _day_night.ticks_per_day
		var hour: float    = float(tick) / float(tpd) * 24.0
		var h:    int      = int(hour) % 24
		var m:    int      = int((hour - int(hour)) * 60.0)
		var ampm: String   = "AM" if h < 12 else "PM"
		var h12:  int      = h % 12
		if h12 == 0:
			h12 = 12
		time_label.text = "%d:%02d %s" % [h12, m, ampm]

	# Update day timeline progress bar (shows time-of-day, not scenario progress).
	if progress_bar != null and progress_bg != null:
		var day_fraction: float = 0.0
		if "current_tick" in _day_night and "ticks_per_day" in _day_night:
			day_fraction = clampf(float(_day_night.current_tick) / float(max(_day_night.ticks_per_day, 1)), 0.0, 1.0)
		progress_bar.anchor_right = day_fraction
		progress_bar.color = day_color


## Map a 0-1 fraction to a green→yellow→orange→red gradient.
func _get_urgency_color(fraction: float) -> Color:
	if fraction < 0.50:
		return C_DAY_SAFE
	elif fraction < 0.70:
		var t: float = (fraction - 0.50) / 0.20
		return C_DAY_SAFE.lerp(C_DAY_CAUTION, t)
	elif fraction < 0.85:
		var t: float = (fraction - 0.70) / 0.15
		return C_DAY_CAUTION.lerp(C_DAY_URGENT, t)
	else:
		var t: float = (fraction - 0.85) / 0.15
		return C_DAY_URGENT.lerp(C_DAY_CRITICAL, t)


# ── Win-condition progress bar ───────────────────────────────────────────────

func _refresh_win_progress() -> void:
	if _scenario_manager == null or win_progress_bar == null or _reputation_system == null:
		return
	var prog: float = _compute_win_progress()
	win_progress_bar.anchor_right = prog
	if win_progress_lbl != null:
		var status_text: String = _get_progress_assessment(prog)
		win_progress_lbl.text = "%d%% — %s" % [int(prog * 100.0), status_text] if prog > 0.0 else "No progress yet — try Observing a building"
	# Colour: shifts from neutral amber → green as progress increases.
	if prog >= 0.80:
		win_progress_bar.color = Color(0.10, 0.85, 0.25, 1.0)
	elif prog >= 0.50:
		win_progress_bar.color = Color(0.50, 0.80, 0.20, 1.0)
	else:
		win_progress_bar.color = Color(0.85, 0.55, 0.10, 1.0)
	# SPA-561: Pulse the win bar when progress >= 80% (near completion).
	_update_win_pulse(prog)


## SPA-561: Start or stop the pulsing glow on the win progress bar.
func _update_win_pulse(prog: float) -> void:
	if win_progress_bar == null:
		return
	if prog >= 0.80 and not _win_pulse_active:
		_win_pulse_active = true
		_start_win_pulse()
	elif prog < 0.80 and _win_pulse_active:
		_win_pulse_active = false
		if _win_pulse_tween != null and _win_pulse_tween.is_valid():
			_win_pulse_tween.kill()
		win_progress_bar.modulate = Color.WHITE


func _start_win_pulse() -> void:
	if _win_pulse_tween != null and _win_pulse_tween.is_valid():
		_win_pulse_tween.kill()
	_win_pulse_tween = create_tween().set_loops() \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_win_pulse_tween.tween_property(win_progress_bar, "modulate",
		Color(1.3, 1.3, 1.3, 1.0), 0.5)
	_win_pulse_tween.tween_property(win_progress_bar, "modulate",
		Color.WHITE, 0.5)


# ── Milestone label (persistent, updates at 25/50/75%) ─────────────────────

func _refresh_milestone_label() -> void:
	if milestone_label == null or _progress_milestones.is_empty():
		return
	var prog: float = _compute_win_progress()
	var best_text: String = ""
	var best_threshold: float = 0.0
	for key in _progress_milestones:
		var threshold: float = float(key)
		if prog >= threshold and threshold > best_threshold:
			best_threshold = threshold
			best_text = _progress_milestones[key]
	if best_text != _current_milestone_text:
		_current_milestone_text = best_text
		milestone_label.text = best_text
		if not best_text.is_empty():
			milestone_label.visible = true
		else:
			milestone_label.visible = false


# ── Tempo indicator (colour days-remaining based on progress vs time) ──────

func _refresh_tempo_indicator() -> void:
	if days_remaining_lbl == null:
		return
	var prog: float = _compute_win_progress()
	var time_frac: float = 0.0
	if _day_night != null and _days_allowed > 1:
		var current_day: int = _day_night.current_day
		time_frac = clampf(float(current_day - 1) / float(_days_allowed - 1), 0.0, 1.0)
	var tempo_color: Color
	if prog > time_frac + 0.10:
		tempo_color = C_TEMPO_AHEAD
	elif prog >= time_frac - 0.10:
		tempo_color = C_TEMPO_ON_PACE
	else:
		tempo_color = C_TEMPO_BEHIND
	days_remaining_lbl.add_theme_color_override("font_color", tempo_color)


## Returns a plain-English "How am I doing?" assessment based on progress vs time.
func _get_progress_assessment(prog: float) -> String:
	var time_frac: float = 0.0
	if _day_night != null and _days_allowed > 1:
		var current_day: int = _day_night.current_day
		time_frac = clampf(float(current_day - 1) / float(_days_allowed - 1), 0.0, 1.0)

	# Compare progress to time elapsed to give a relative assessment.
	if prog >= 0.95:
		return "Almost there!"
	elif prog >= 0.80:
		return "Strong position — keep pushing"
	elif prog > time_frac + 0.15:
		return "Ahead of schedule"
	elif prog >= time_frac - 0.10:
		return "On track"
	elif prog >= time_frac - 0.30:
		return "Falling behind — act fast"
	else:
		return "Behind — change strategy"


## Compute a 0.0–1.0 win progress from scenario-specific progress data.
func _compute_win_progress() -> float:
	if _scenario_manager == null or _reputation_system == null or _world_ref == null:
		return 0.0
	var sid: String = _world_ref.active_scenario_id if "active_scenario_id" in _world_ref else ""
	match sid:
		"scenario_1":
			var p: Dictionary = _scenario_manager.get_scenario_1_progress(_reputation_system)
			var score: int  = p.get("edric_score", ScenarioManager.S1_EDRIC_START_SCORE)
			var start: int  = p.get("start_score",  ScenarioManager.S1_EDRIC_START_SCORE)
			var target: int = p.get("win_threshold", ScenarioManager.S1_WIN_EDRIC_BELOW)
			# From start → target: progress = (start - score) / (start - target)
			return clampf(float(start - score) / float(max(start - target, 1)), 0.0, 1.0)
		"scenario_2":
			var p: Dictionary = _scenario_manager.get_scenario_2_progress(_reputation_system)
			var count: int = p.get("illness_believer_count", 0)
			var target: int = p.get("win_threshold", 6)
			return clampf(float(count) / float(max(target, 1)), 0.0, 1.0)
		"scenario_3":
			var p: Dictionary = _scenario_manager.get_scenario_3_progress(_reputation_system)
			var calder: int = p.get("calder_score", 50)
			var tomas: int = p.get("tomas_score", 50)
			var calder_prog: float = clampf(float(calder - 50) / 25.0, 0.0, 1.0)
			var tomas_prog: float = clampf(float(50 - tomas) / 15.0, 0.0, 1.0)
			return (calder_prog + tomas_prog) / 2.0
		"scenario_4":
			# Survival scenario — progress = days survived / total days.
			var current_day: int = _day_night.current_day if _day_night != null else 1
			return clampf(float(current_day) / float(max(_days_allowed, 1)), 0.0, 1.0)
		"scenario_5":
			var p5: Dictionary = _scenario_manager.get_scenario_5_progress(_reputation_system)
			var aldric5: int = p5.get("aldric_score", 48)
			var edric5: int = p5.get("edric_score", 58)
			var tomas5: int = p5.get("tomas_score", 45)
			var pa: float = clampf((aldric5 - 48.0) / (65.0 - 48.0), 0.0, 1.0)
			var pe: float = clampf((58.0 - edric5) / (58.0 - 45.0), 0.0, 1.0)
			var win_rivals_max: float = float(p5.get("win_rivals_max", 45))
				var pt: float = clampf((45.0 - tomas5) / maxf(45.0 - win_rivals_max, 1.0), 0.0, 1.0)
			return minf(pa, minf(pe, pt))
		"scenario_6":
			var p6: Dictionary = _scenario_manager.get_scenario_6_progress(_reputation_system)
			var aldric6: int = p6.get("aldric_score", 55)
			var marta6: int = p6.get("marta_score", 52)
			var pad: float = clampf((55.0 - aldric6) / (55.0 - 30.0), 0.0, 1.0)
			var pmu: float = clampf((marta6 - 52.0) / maxf(60.0 - 52.0, 1.0), 0.0, 1.0)
			return minf(pad, pmu)
	return 0.0


# ── Metrics row (below progress bar) ─────────────────────────────────────────

func _build_metrics_row() -> void:
	# Expand the Panel to make room for the metrics row.
	var panel: Panel = $Panel
	panel.offset_bottom += 20

	# Add metrics row as a child of Panel/VBox.
	var vbox: VBoxContainer = $Panel/VBox
	_metrics_row = HBoxContainer.new()
	_metrics_row.add_theme_constant_override("separation", 16)
	_metrics_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_metrics_row)

	# Average reputation metric
	_lbl_rep_avg = _make_metric_label("Avg Rep: --")
	_lbl_rep_avg.add_theme_color_override("font_color", Color(0.784, 0.635, 0.180, 1.0))  # MERCH_TRIM gold
	_lbl_rep_avg.tooltip_text = "Average NPC reputation score (0-100)"
	_metrics_row.add_child(_lbl_rep_avg)

	# Believers count (unique NPCs in BELIEVE/SPREAD/ACT state for any rumor)
	_lbl_believers = _make_metric_label("Believers: 0")
	_lbl_believers.add_theme_color_override("font_color", Color(0.345, 0.580, 0.769, 1.0))  # WATER_L (#5894C4)
	_lbl_believers.tooltip_text = "NPCs who believe at least one active rumor"
	_metrics_row.add_child(_lbl_believers)

	# Socially dead count
	_lbl_rumors_active = _make_metric_label("Pariahs: 0")
	_lbl_rumors_active.add_theme_color_override("font_color", Color(0.90, 0.35, 0.25, 1.0))
	_lbl_rumors_active.tooltip_text = "NPCs whose reputation has collapsed beyond recovery"
	_metrics_row.add_child(_lbl_rumors_active)

	# Threat level indicator (SPA-479)
	_lbl_threat = _make_metric_label("")
	_lbl_threat.tooltip_text = "How close rivals or inquisitors are to exposing you"
	_metrics_row.add_child(_lbl_threat)


func _make_metric_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	return lbl


func _refresh_metrics() -> void:
	if _reputation_system == null:
		return
	var snaps: Dictionary = _reputation_system.get_all_snapshots()
	if snaps.is_empty():
		return
	var total_score: int = 0
	var dead_count: int = 0
	for npc_id in snaps:
		var snap: ReputationSystem.ReputationSnapshot = snaps[npc_id]
		total_score += snap.score
		if snap.is_socially_dead:
			dead_count += 1
	var avg: int = total_score / max(snaps.size(), 1)
	if _lbl_rep_avg != null:
		_update_avg_rep_display(avg)
	if _lbl_believers != null:
		_lbl_believers.text = "Believers: %d" % _reputation_system.get_global_believer_count()
	if _lbl_rumors_active != null:
		_lbl_rumors_active.text = "Pariahs: %d" % dead_count
	_refresh_threat()


## Animate the avg-rep label from its current displayed value to new_avg.
## Color flash: green tint for gains, red tint for losses, fading back to white.
func _update_avg_rep_display(new_avg: int) -> void:
	# Always keep the urgency color up-to-date.
	var urgency_color: Color
	if new_avg >= 40:
		urgency_color = Color(0.784, 0.635, 0.180, 1.0)  # MERCH_TRIM gold
	elif new_avg >= 25:
		urgency_color = Color(0.90, 0.75, 0.30, 1.0)
	else:
		urgency_color = Color(0.90, 0.45, 0.35, 1.0)
	_lbl_rep_avg.add_theme_color_override("font_color", urgency_color)

	# First call — initialise without animation.
	if _last_avg_rep < 0:
		_last_avg_rep      = new_avg
		_displayed_avg_rep = float(new_avg)
		_lbl_rep_avg.text  = "Avg Rep: %d" % new_avg
		return

	# No meaningful change — let any running tween finish.
	if new_avg == _last_avg_rep:
		return

	var delta: int = new_avg - _last_avg_rep
	_last_avg_rep = new_avg

	# Kill the previous number tween and start from wherever we currently are.
	if _avg_rep_tween != null and _avg_rep_tween.is_valid():
		_avg_rep_tween.kill()
	_avg_rep_tween = create_tween()
	_avg_rep_tween.tween_method(_set_displayed_avg_rep, _displayed_avg_rep, float(new_avg), 0.8) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Brief color flash using self_modulate (does not fight font_color override).
	var flash_color: Color = Color(0.20, 0.90, 0.35, 1.0) if delta > 0 else Color(0.90, 0.25, 0.15, 1.0)
	if _avg_rep_flash_tween != null and _avg_rep_flash_tween.is_valid():
		_avg_rep_flash_tween.kill()
		_lbl_rep_avg.self_modulate = Color.WHITE
	_avg_rep_flash_tween = create_tween()
	_avg_rep_flash_tween.tween_property(_lbl_rep_avg, "self_modulate", flash_color, 0.05) \
		.set_ease(Tween.EASE_OUT)
	_avg_rep_flash_tween.tween_property(_lbl_rep_avg, "self_modulate", Color.WHITE, 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func _set_displayed_avg_rep(value: float) -> void:
	_displayed_avg_rep = value
	if _lbl_rep_avg != null:
		_lbl_rep_avg.text = "Avg Rep: %d" % int(value)


# ── Threat level indicator (SPA-479) ────────────────────────────────────────

func _refresh_threat() -> void:
	if _lbl_threat == null:
		return
	if _intel_store == null or _scenario_manager == null:
		_lbl_threat.text = ""
		return

	var threat: float = 0.0   # 0.0 = safe, 1.0 = maximum danger
	var label_text: String = ""

	# S1: detection risk from eavesdrop heat exposure.
	if _scenario_manager._active_scenario == 1:
		# S1 has no heat system — threat is based on time pressure only.
		var current_day: int = _day_night.current_day if _day_night != null else 1
		threat = clampf(float(current_day) / float(max(_days_allowed, 1)), 0.0, 1.0)
		label_text = "Exposure: %s" % _threat_word(threat)

	# S2: threat = how close Maren is to rejecting (approx via heat + time).
	elif _scenario_manager._active_scenario == 2:
		var maren_heat: float = _intel_store.get_heat("maren_nun")
		threat = clampf(maren_heat / 80.0, 0.0, 1.0)
		# Also factor in time pressure.
		var time_frac: float = _scenario_manager.get_time_fraction(
			_day_night.current_tick if _day_night != null else 0)
		threat = maxf(threat, time_frac * 0.7)
		label_text = "Threat: %s" % _threat_word(threat)

	# S3: threat = rival agent intensity (based on time in final quarter).
	elif _scenario_manager._active_scenario == 3:
		var time_frac: float = _scenario_manager.get_time_fraction(
			_day_night.current_tick if _day_night != null else 0)
		# Rival escalates in final quarter.
		if time_frac >= 0.75:
			threat = clampf((time_frac - 0.75) / 0.25 * 0.6 + 0.4, 0.0, 1.0)
		else:
			threat = clampf(time_frac * 0.4, 0.0, 1.0)
		# Also factor in Calder's danger zone.
		if _reputation_system != null:
			var calder: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot("calder_fenn")
			if calder != null and calder.score < 50:
				threat = maxf(threat, clampf(1.0 - float(calder.score) / 50.0, 0.0, 1.0))
		label_text = "Rival: %s" % _threat_word(threat)

	# S4: threat = inverse of weakest protected NPC's score margin above 45.
	elif _scenario_manager._active_scenario == 4:
		var min_margin: int = 100
		for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
			if _reputation_system == null:
				break
			var snap: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot(npc_id)
			if snap != null:
				var margin: int = snap.score - ScenarioManager.S4_FAIL_REP_BELOW
				if margin < min_margin:
					min_margin = margin
		threat = clampf(1.0 - float(max(min_margin, 0)) / 30.0, 0.0, 1.0)
		label_text = "Inquisitor: %s" % _threat_word(threat)

	# S5: threat = time pressure + Aldric's distance from rivals.
	elif _scenario_manager._active_scenario == 5:
		var time_frac: float = _scenario_manager.get_time_fraction(
			_day_night.current_tick if _day_night != null else 0)
		threat = clampf(time_frac * 0.5, 0.0, 1.0)
		if _reputation_system != null:
			var aldric: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot("aldric_vane")
			if aldric != null and aldric.score < 50:
				threat = maxf(threat, clampf(1.0 - float(aldric.score - 30) / 20.0, 0.0, 1.0))
		label_text = "Election: %s" % _threat_word(threat)

	# S6: threat = heat approaching lower ceiling of 60.
	elif _scenario_manager._active_scenario == 6:
		var heat: float = _intel_store.get_heat("player") if _intel_store != null else 0.0
		threat = clampf(heat / ScenarioManager.S6_EXPOSED_HEAT, 0.0, 1.0)
		var time_frac: float = _scenario_manager.get_time_fraction(
			_day_night.current_tick if _day_night != null else 0)
		threat = maxf(threat, time_frac * 0.5)
		if _reputation_system != null:
			var marta: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot("marta_coin")
			if marta != null and marta.score < 45:
				threat = maxf(threat, clampf(1.0 - float(marta.score - 30) / 15.0, 0.0, 1.0))
		label_text = "Exposure: %s" % _threat_word(threat)

	else:
		_lbl_threat.text = ""
		return

	_lbl_threat.text = label_text
	_lbl_threat.add_theme_color_override("font_color", _threat_color(threat))


## Convert a 0-1 threat value to a descriptive word.
func _threat_word(t: float) -> String:
	if t < 0.25:
		return "Low"
	elif t < 0.50:
		return "Moderate"
	elif t < 0.75:
		return "High"
	else:
		return "Critical"


## Convert a 0-1 threat value to a colour (green → amber → red).
func _threat_color(t: float) -> Color:
	if t < 0.25:
		return Color(0.35, 0.80, 0.35, 1.0)
	elif t < 0.50:
		return Color(0.90, 0.80, 0.25, 1.0)
	elif t < 0.75:
		return Color(0.95, 0.55, 0.15, 1.0)
	else:
		return Color(0.95, 0.25, 0.15, 1.0)


# ── Faction influence mini-panel ─────────────────────────────────────────────

func _build_faction_panel() -> void:
	if _world_ref == null:
		return

	var panel: Panel = $Panel
	_faction_panel = Panel.new()
	_faction_panel.offset_left = panel.offset_left
	_faction_panel.offset_right = panel.offset_right
	_faction_panel.anchor_left = 0.5
	_faction_panel.anchor_right = 0.5
	_faction_panel.offset_top = panel.offset_bottom + 2
	_faction_panel.offset_bottom = panel.offset_bottom + 64

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.07, 0.05, 0.88)
	_faction_panel.add_child(bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 8.0
	hbox.offset_top = 4.0
	hbox.offset_right = -8.0
	hbox.offset_bottom = -4.0
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_faction_panel.add_child(hbox)

	const FACTIONS := {
		"merchant": {"name": "Merchants", "color": Color(0.784, 0.635, 0.180, 1.0)},
		"noble":    {"name": "Nobles",    "color": Color(0.65, 0.45, 0.85, 1.0)},
		"clergy":   {"name": "Clergy",    "color": Color(0.55, 0.80, 0.95, 1.0)},
	}

	for faction_id in ["merchant", "noble", "clergy"]:
		var info: Dictionary = FACTIONS[faction_id]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Faction name label
		var name_lbl := Label.new()
		name_lbl.text = info["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", info["color"])
		name_lbl.add_theme_constant_override("outline_size", 2)
		name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		col.add_child(name_lbl)

		# Mood label
		var mood_lbl := Label.new()
		mood_lbl.text = "Calm"
		mood_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mood_lbl.add_theme_font_size_override("font_size", 12)
		mood_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50, 1.0))
		mood_lbl.add_theme_constant_override("outline_size", 2)
		mood_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		col.add_child(mood_lbl)

		# Influence bar background
		var bar_bg := ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(0, 6)
		bar_bg.color = Color(0.20, 0.15, 0.08, 1.0)
		col.add_child(bar_bg)

		# Influence bar fill
		var bar_fill := ColorRect.new()
		bar_fill.anchor_bottom = 1.0
		bar_fill.anchor_right = 0.0
		bar_fill.color = info["color"]
		bar_bg.add_child(bar_fill)

		_faction_labels[faction_id] = {"mood": mood_lbl, "bar": bar_fill}
		hbox.add_child(col)

	add_child(_faction_panel)


func _refresh_faction_panel() -> void:
	if _faction_panel == null or _world_ref == null:
		return
	if not "npcs" in _world_ref:
		return

	for faction_id in ["merchant", "noble", "clergy"]:
		var member_count: int = 0
		var believer_count: int = 0
		for npc in _world_ref.npcs:
			if npc.npc_data.get("faction", "") != faction_id:
				continue
			member_count += 1
			for rid in npc.rumor_slots:
				var slot = npc.rumor_slots[rid]
				if slot.state in [Rumor.RumorState.BELIEVE,
								   Rumor.RumorState.SPREAD,
								   Rumor.RumorState.ACT]:
					believer_count += 1
					break  # count each NPC once

		# Derive faction mood from believer ratio.
		var ratio: float = float(believer_count) / float(max(member_count, 1))
		var mood: String
		var mood_color: Color
		if ratio < 0.1:
			mood = "Calm"
			mood_color = Color(0.50, 0.80, 0.45, 1.0)
		elif ratio < 0.3:
			mood = "Unsettled"
			mood_color = Color(0.90, 0.80, 0.30, 1.0)
		elif ratio < 0.6:
			mood = "Agitated"
			mood_color = Color(0.95, 0.55, 0.15, 1.0)
		else:
			mood = "Hostile"
			mood_color = Color(0.90, 0.25, 0.15, 1.0)

		if _faction_labels.has(faction_id):
			var entry: Dictionary = _faction_labels[faction_id]
			entry["mood"].text = mood
			entry["mood"].add_theme_color_override("font_color", mood_color)
			entry["bar"].anchor_right = ratio


# ── Banner system (dawn bulletin + deadline warnings) ────────────────────────

func _build_banner() -> void:
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Use proportional anchoring so the banner stays below the HUD panel on all resolutions.
	_banner_label.anchor_left = 0.15
	_banner_label.anchor_right = 0.85
	_banner_label.anchor_top = 0.0
	_banner_label.anchor_bottom = 0.0
	_banner_label.offset_top = 165.0
	_banner_label.offset_bottom = 235.0
	_banner_label.offset_left = 0.0
	_banner_label.offset_right = 0.0
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.add_theme_font_size_override("font_size", 13)
	_banner_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1.0))
	_banner_label.add_theme_constant_override("outline_size", 2)
	_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner_label.modulate.a = 0.0
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner_label)


func _show_banner(text: String, color: Color, duration: float = 6.0) -> void:
	if _banner_label == null:
		return
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)
	_banner_label.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_label, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(_banner_label, "modulate:a", 0.0, 1.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


## Capture reputation scores at dawn for overnight comparison.
func _snapshot_dawn_scores() -> void:
	if _reputation_system == null:
		return
	_prev_dawn_scores.clear()
	var snaps: Dictionary = _reputation_system.get_all_snapshots()
	for npc_id in snaps:
		var snap: ReputationSystem.ReputationSnapshot = snaps[npc_id]
		_prev_dawn_scores[npc_id] = snap.score


## Show a morning popup summarizing significant overnight reputation changes.
func _show_dawn_bulletin() -> void:
	if _reputation_system == null or _prev_dawn_scores.is_empty():
		return
	var snaps: Dictionary = _reputation_system.get_all_snapshots()
	var lines: Array[String] = []
	for npc_id in snaps:
		if not _prev_dawn_scores.has(npc_id):
			continue
		var snap: ReputationSystem.ReputationSnapshot = snaps[npc_id]
		var prev_score: int = _prev_dawn_scores[npc_id]
		var delta: int = snap.score - prev_score
		if abs(delta) < 3:
			continue
		var arrow: String = "+" if delta > 0 else ""
		var npc_name: String = npc_id.replace("_", " ").capitalize()
		lines.append("%s %s%d (%d)" % [npc_name, arrow, delta, snap.score])
	# SPA-648: Prepend strategic summary line (active rumors, believers, expirations).
	var summary_line: String = _build_dawn_summary_text()
	if lines.is_empty() and summary_line.is_empty():
		return
	var bulletin: String = "Dawn Report"
	if not summary_line.is_empty():
		bulletin += "\n" + summary_line
	if not lines.is_empty():
		bulletin += "\n" + "\n".join(lines)
	_show_banner(bulletin, Color(0.85, 0.78, 0.55, 1.0), 8.0)


## Show a deadline warning banner at 75% and 90% time thresholds.
func _on_deadline_warning(threshold: float, days_remaining: int) -> void:
	var urgency: String
	var color: Color
	if threshold >= 0.90:
		urgency = "CRITICAL"
		color = C_DAY_CRITICAL
	else:
		urgency = "WARNING"
		color = C_DAY_URGENT
	var text: String = "%s - %d day%s remaining!" % [
		urgency, days_remaining, "" if days_remaining == 1 else "s"]
	_show_banner(text, color, 5.0)


# ── SPA-648: Mid-game guidance nudge (slide-in from bottom-right) ───────────

const C_MIDGAME_NUDGE := Color(0.80, 0.90, 0.65, 1.0)
const C_MIDGAME_NUDGE_BG := Color(0.08, 0.06, 0.04, 0.85)

func _build_midgame_nudge() -> void:
	_midgame_nudge_bg = ColorRect.new()
	_midgame_nudge_bg.color = C_MIDGAME_NUDGE_BG
	_midgame_nudge_bg.anchor_left = 1.0
	_midgame_nudge_bg.anchor_right = 1.0
	_midgame_nudge_bg.anchor_top = 1.0
	_midgame_nudge_bg.anchor_bottom = 1.0
	_midgame_nudge_bg.offset_left = -340.0
	_midgame_nudge_bg.offset_right = -8.0
	_midgame_nudge_bg.offset_top = -60.0
	_midgame_nudge_bg.offset_bottom = -8.0
	_midgame_nudge_bg.modulate.a = 0.0
	_midgame_nudge_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_midgame_nudge_bg.gui_input.connect(_on_midgame_nudge_clicked)
	add_child(_midgame_nudge_bg)

	_midgame_nudge_label = Label.new()
	_midgame_nudge_label.text = ""
	_midgame_nudge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_midgame_nudge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_midgame_nudge_label.offset_left = 8.0
	_midgame_nudge_label.offset_top = 6.0
	_midgame_nudge_label.offset_right = -8.0
	_midgame_nudge_label.offset_bottom = -6.0
	_midgame_nudge_label.add_theme_font_size_override("font_size", 12)
	_midgame_nudge_label.add_theme_color_override("font_color", C_MIDGAME_NUDGE)
	_midgame_nudge_label.add_theme_constant_override("outline_size", 2)
	_midgame_nudge_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_midgame_nudge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_midgame_nudge_bg.add_child(_midgame_nudge_label)


func _on_midgame_nudge_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_midgame_nudge()


func _dismiss_midgame_nudge() -> void:
	if _midgame_nudge_bg == null:
		return
	if _midgame_nudge_tween != null and _midgame_nudge_tween.is_valid():
		_midgame_nudge_tween.kill()
	_midgame_nudge_tween = create_tween()
	_midgame_nudge_tween.tween_property(_midgame_nudge_bg, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func _show_midgame_nudge(text: String) -> void:
	if _midgame_nudge_label == null or _midgame_nudge_bg == null:
		return
	if _midgame_nudge_tween != null and _midgame_nudge_tween.is_valid():
		_midgame_nudge_tween.kill()
	_midgame_nudge_label.text = text
	_midgame_nudge_bg.modulate.a = 0.0
	# Slide in: start offscreen to the right, animate to final position.
	var final_left: float = -340.0
	_midgame_nudge_bg.offset_left = -8.0  # start collapsed at right edge
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


func _refresh_midgame_nudge() -> void:
	# Only fire after tutorial nudges are done (phase >= 4) and after day 2.
	if _nudge_phase < 4:
		return
	if _day_night == null or _day_night.current_day < 3:
		return

	# Throttle: max 1 nudge per day-phase (morning/afternoon/evening/night).
	var tick: int = _day_night.current_tick if "current_tick" in _day_night else 0
	var tpd: int = _day_night.ticks_per_day if "ticks_per_day" in _day_night else 24
	var hour: int = tick % tpd
	var phase_key: String
	if hour < 6:
		phase_key = "%d_dawn" % _day_night.current_day
	elif hour < 12:
		phase_key = "%d_morning" % _day_night.current_day
	elif hour < 18:
		phase_key = "%d_afternoon" % _day_night.current_day
	else:
		phase_key = "%d_evening" % _day_night.current_day

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

	# Priority 2: A rumor is STALLING and player has whisper tokens.
	var stalling_count: int = 0
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state == Rumor.RumorState.BELIEVE:
				# BELIEVE but not SPREAD = stalling
				stalling_count += 1
	var whispers: int = _intel_store.whisper_tokens_remaining if _intel_store != null else 0
	if stalling_count > 0 and whispers > 0:
		return "A rumour is stalling — seed it to a new NPC or bolster with evidence."

	# Priority 3: Unused recon actions past morning.
	if _intel_store != null and hour_of_day >= 6:
		var actions: int = _intel_store.recon_actions_remaining
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


# ── SPA-648: Enhanced dawn strategic summary ─────────────────────────────────

func _build_dawn_summary_text() -> String:
	if _reputation_system == null or _world_ref == null or not "npcs" in _world_ref:
		return ""
	# Count active rumors.
	var active_rumors: int = 0
	var expired_count: int = 0
	var seen_rids: Dictionary = {}
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			if seen_rids.has(rid):
				continue
			seen_rids[rid] = true
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD,
							   Rumor.RumorState.EVALUATING, Rumor.RumorState.ACT]:
				active_rumors += 1
			elif slot.state == Rumor.RumorState.EXPIRED:
				expired_count += 1

	# Believers delta.
	var believers: int = _reputation_system.get_global_believer_count()

	var parts: Array[String] = []
	if active_rumors > 0:
		parts.append("%d active rumour%s" % [active_rumors, "" if active_rumors == 1 else "s"])
	if believers > 0:
		parts.append("%d believer%s" % [believers, "" if believers == 1 else "s"])
	if expired_count > 0:
		parts.append("%d expired" % expired_count)
	if parts.is_empty():
		return ""
	return "Dawn — " + ", ".join(parts)


# ── SPA-648: Mini objective progress indicator ──────────────────────────────

func _build_mini_progress() -> void:
	var day_row: HBoxContainer = $Panel/VBox/DayRow
	_mini_progress_label = Label.new()
	_mini_progress_label.text = ""
	_mini_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mini_progress_label.add_theme_font_size_override("font_size", 13)
	_mini_progress_label.add_theme_constant_override("outline_size", 2)
	_mini_progress_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_mini_progress_label.add_theme_color_override("font_color", Color(0.50, 0.80, 0.35, 1.0))
	_mini_progress_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini_progress_label.tooltip_text = "Win progress — click to open Journal Objectives"
	_mini_progress_label.gui_input.connect(_on_mini_progress_clicked)
	day_row.add_child(_mini_progress_label)


func _on_mini_progress_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Simulate pressing J to open the journal (objectives tab).
		var j_event := InputEventAction.new()
		j_event.action = "toggle_journal"
		j_event.pressed = true
		Input.parse_input_event(j_event)


func _refresh_mini_progress() -> void:
	if _mini_progress_label == null or _scenario_manager == null:
		return
	var prog: float = _compute_win_progress()
	var pct: int = int(prog * 100.0)
	_mini_progress_label.text = "🏆 %d%%" % pct
	# Color: shifts with progress.
	if prog >= 0.80:
		_mini_progress_label.add_theme_color_override("font_color", Color(0.10, 0.90, 0.30, 1.0))
	elif prog >= 0.50:
		_mini_progress_label.add_theme_color_override("font_color", Color(0.50, 0.80, 0.25, 1.0))
	elif prog > 0.0:
		_mini_progress_label.add_theme_color_override("font_color", Color(0.85, 0.70, 0.20, 1.0))
	else:
		_mini_progress_label.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45, 0.6))


# ── Tier 3: Suggestion toast (SPA-743) ─────────────────────────────────────

func _build_tier3_suggestion() -> void:
	if tier3_container == null:
		return
	_suggestion_toast = SuggestionToast.new()
	_suggestion_toast.visible = false
	tier3_container.add_child(_suggestion_toast)
	_suggestion_toast.hint_dismissed.connect(_on_hint_dismissed)


func _refresh_tier3_suggestion() -> void:
	# Only activate after tutorial nudges complete (phase >= 4).
	if _nudge_phase < 4:
		return
	if _suggestion_engine == null:
		return

	# Detect player action by polling budget changes (inactivity reset).
	if _intel_store != null:
		var tick: int = _day_night.current_tick if _day_night != null and "current_tick" in _day_night else 0
		var cur_obs:   int = _intel_store.recon_actions_remaining
		var cur_whisp: int = _intel_store.whisper_tokens_remaining
		if (_t3_last_obs >= 0 and cur_obs != _t3_last_obs) or \
				(_t3_last_whisp >= 0 and cur_whisp != _t3_last_whisp):
			_suggestion_engine.notify_player_action(tick)
		_t3_last_obs   = cur_obs
		_t3_last_whisp = cur_whisp

	_suggestion_engine.refresh()


## Called when hint_ready fires on the engine — shows the toast.
func _on_suggestion_hint_ready(text: String) -> void:
	if _suggestion_toast == null:
		return
	_suggestion_toast.show_hint(text)


## Called when the toast is dismissed — forward to engine for cooldown tracking.
func _on_hint_dismissed(was_fast: bool) -> void:
	if _suggestion_engine != null:
		_suggestion_engine.notify_hint_dismissed(was_fast)
