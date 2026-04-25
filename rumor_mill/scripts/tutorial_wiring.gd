## tutorial_wiring.gd — SPA-1002: Tutorial, banner, idle hints, context hints, and onboarding.
##
## Extracted from main.gd (_init_tutorial_system, _init_tutorial_banner_s1,
## _init_context_banner, all banner signal handlers, idle hints, context hints,
## waypoint system, S1 onboarding flow, What's Changed card).
## Add as a child of main then call setup().

class_name TutorialWiring
extends Node

# Exposed so main.gd can pass these to SaveManager, PauseMenu, GameInputHandler, etc.
var tutorial_sys: TutorialSystem = null
var tutorial_banner: CanvasLayer = null

var _tutorial_hud: CanvasLayer = null
var _tutorial_ctrl: TutorialController = null

var _world: Node2D = null
var _day_night: Node = null
var _camera: Camera2D = null
var _recon_hud: CanvasLayer = null
var _rumor_panel: CanvasLayer = null
var _journal: CanvasLayer = null
var _visual_affordances: CanvasLayer = null
var _recon_ctrl_ref: Node = null

# ── SPA-629: Rumor Panel first-time tooltip walkthrough ──────────────────────
var _rumor_panel_tooltip: CanvasLayer = null
var _rumor_panel_tooltip_wired: bool  = false

# Prevent duplicate tooltip triggers for observe / eavesdrop / npc_state_change.
var _observe_tooltip_fired:          bool = false
var _eavesdrop_tooltip_fired:        bool = false
var _npc_state_change_tooltip_fired: bool = false
var _evidence_tooltip_fired:         bool = false

# ── SPA-724: Onboarding action counter for goal strip fade ──────────────────
var _spa724_action_count: int = 0

# ── Sprint 10: S1 banner hint gates ───────────────────────────────────────────
var _banner_camera_gate:       bool = false
var _banner_observe_gate:      bool = false
var _banner_eavesdrop_gate:    bool = false
var _banner_seed_fired:        bool = false
var _banner_hint06_fired:      bool = false
var _banner_believe_fired:     bool = false
var _banner_journal_hint_fired: bool = false
var _banner_social_graph_fired: bool = false
var _banner_s1_market_cleared: bool = false
# Cross-scenario contextual hint gates (S2/S3/S4).
var _ctx_spread_fired:   bool = false
var _ctx_act_fired:      bool = false
var _ctx_reject_fired:   bool = false
var _ctx_tokens_fired:   bool = false
var _ctx_heat_warn_fired: bool = false
var _ctx_rival_first_act_fired:      bool = false
var _ctx_inquisitor_first_act_fired: bool = false
var _ctx_halfway_fired:  bool = false
var _banner_eavesdrop_count:    int  = 0

# ── SPA-487: Idle-detection hint system ───────────────────────────────────────
var _idle_timer: Timer = null
var _idle_hint_fired_no_action:  bool = false
var _idle_hint_fired_no_rumor:   bool = false
var _has_performed_any_action:   bool = false
var _has_crafted_any_rumor:      bool = false

# ── SPA-758: Onboarding waypoint marker ─────────────────────────────────────
var _waypoint_node:  Node2D = null
var _waypoint_tween: Tween  = null
var _waypoint_step:  int    = 0

# ── SPA-805: S1 manor golden-pulse highlight ────────────────────────────────
var _s1_manor_highlight: Polygon2D = null

# ── SPA-1033: Scene timer references — prevents callback fires after free ────
var _scene_timers: Array = []

# ── SPA-948: "What's Changed" card ──────────────────────────────────────────
var _whats_changed_card: CanvasLayer = null


func setup(
		world: Node2D,
		day_night: Node,
		camera: Camera2D,
		recon_hud: CanvasLayer,
		rumor_panel: CanvasLayer,
		journal: CanvasLayer,
		visual_affordances: CanvasLayer,
		recon_ctrl: Node,
) -> void:
	_world = world
	_day_night = day_night
	_camera = camera
	_recon_hud = recon_hud
	_rumor_panel = rumor_panel
	_journal = journal
	_visual_affordances = visual_affordances
	_recon_ctrl_ref = recon_ctrl

	tutorial_sys = TutorialSystem.new()

	if _world.active_scenario_id == "scenario_1":
		_init_tutorial_banner_s1()
	else:
		_init_context_banner()

	_init_idle_hints()

	# Pipe action results to the tutorial system (observe / eavesdrop tooltips).
	if _recon_ctrl_ref != null:
		_recon_ctrl_ref.action_performed.connect(_on_recon_action_for_tutorial)

	tree_exiting.connect(_on_tree_exiting)


func _on_tree_exiting() -> void:
	_scene_timers.clear()


## Called from main.gd _on_mission_briefing_dismissed() to start the appropriate
## onboarding flow (S1 guided flow vs S2-S6 What's Changed card).
func start_onboarding(scenario_id: String) -> void:
	if scenario_id == "scenario_1":
		_init_s1_onboarding_flow()
	else:
		_show_whats_changed_card(scenario_id)


# ── Tutorial system init ─────────────────────────────────────────────────────

## All scenarios except S1: non-blocking contextual hint banner for day-gated tips.
## Opening and onboarding hint timers are NOT started here — they start after the
## Mission Briefing is dismissed (via _start_sx_timed_hints called from
## _init_sx_onboarding_flow) so banners never overlap the blocking briefing screen.
func _init_context_banner() -> void:
	tutorial_banner = preload("res://scripts/tutorial_banner.gd").new()
	tutorial_banner.name = "TutorialBanner"
	add_child(tutorial_banner)
	tutorial_banner.setup(tutorial_sys)

	# Day-gated hints: hook into day_changed signal.
	if _day_night != null and _day_night.has_signal("day_changed"):
		_day_night.day_changed.connect(_on_ctx_day_changed)

	# Whisper token exhaustion hint (SPA-448).
	if _world.intel_store != null:
		_world.intel_store.tokens_exhausted.connect(_on_ctx_tokens_exhausted)

	# Heat warning hint (SPA-608).
	if _world.intel_store != null and _world.active_scenario_id in ["scenario_1", "scenario_6"]:
		_world.intel_store.heat_warning.connect(_on_heat_warning)

	# NPC state change hints: first SPREAD, ACT, or REJECT triggers.
	for npc in _world.npcs:
		npc.rumor_state_changed.connect(_on_ctx_rumor_state_changed)

	# Suppression: pause banner while Journal / Rumour Panel are open.
	if _journal != null:
		_journal.visibility_changed.connect(_on_journal_visibility_changed_banner)
	if _rumor_panel != null:
		_rumor_panel.visibility_changed.connect(_on_rumor_panel_visibility_changed_banner)

	# SPA-937: S3 rival first-action hint.
	if _world.active_scenario_id == "scenario_3" and _world.rival_agent != null \
			and _world.rival_agent.has_signal("rival_acted"):
		_world.rival_agent.rival_acted.connect(_on_rival_first_acted_tutorial)

	# SPA-937: S4 inquisitor first-action hint.
	if _world.active_scenario_id == "scenario_4" and _world.inquisitor_agent != null \
			and _world.inquisitor_agent.has_signal("inquisitor_acted"):
		_world.inquisitor_agent.inquisitor_acted.connect(_on_inquisitor_first_acted_tutorial)


## SPA-804 DEPRECATED — no longer called.  Kept to avoid breaking tool-generated refs.
func _init_tutorial_hud_s2s3s4() -> void:
	_tutorial_hud = preload("res://scripts/tutorial_hud.gd").new()
	_tutorial_hud.name = "TutorialHUD"
	add_child(_tutorial_hud)
	_tutorial_hud.setup(tutorial_sys)

	_tutorial_hud.queue_tooltip("core_loop")
	if _world.active_scenario_id == "scenario_3":
		_tutorial_hud.queue_tooltip("rival_agent")
	if _world.active_scenario_id == "scenario_4":
		_tutorial_hud.queue_tooltip("inquisitor_agent")
	if _world.active_scenario_id == "scenario_5":
		_tutorial_hud.queue_tooltip("election_race")
	if _world.active_scenario_id == "scenario_6":
		_tutorial_hud.queue_tooltip("guild_defense")

	var _nav_timer := get_tree().create_timer(10.0)
	_nav_timer.timeout.connect(func() -> void:
		if _tutorial_hud != null and tutorial_sys != null:
			if not tutorial_sys.has_seen("navigation_controls"):
				_tutorial_hud.queue_tooltip("navigation_controls")
	)
	var _recon_timer := get_tree().create_timer(20.0)
	_recon_timer.timeout.connect(func() -> void:
		if _tutorial_hud != null and tutorial_sys != null:
			if not tutorial_sys.has_seen("recon_actions"):
				_tutorial_hud.queue_tooltip("recon_actions")
	)

	if _rumor_panel != null:
		_rumor_panel.visibility_changed.connect(_on_rumor_panel_visibility_changed)
	if _journal != null:
		_journal.visibility_changed.connect(_on_journal_visibility_changed)
	for npc in _world.npcs:
		npc.first_npc_became_evaluating.connect(_on_first_npc_state_change)


## S1: non-blocking banner hint system (SPA-131).
func _init_tutorial_banner_s1() -> void:
	tutorial_banner = preload("res://scripts/tutorial_banner.gd").new()
	tutorial_banner.name = "TutorialBanner"
	add_child(tutorial_banner)
	tutorial_banner.setup(tutorial_sys)

	# HINT-01: immediate first action — fires 2 s after game start.
	var _first_action_timer := get_tree().create_timer(2.0)
	_scene_timers.append(_first_action_timer)
	_first_action_timer.timeout.connect(func() -> void:
		if tutorial_banner != null:
			tutorial_banner.queue_hint("hint_first_action")
	)

	# HINT-02: point toward target NPC — fires 8 s after game start.
	var _target_hint_timer := get_tree().create_timer(8.0)
	_scene_timers.append(_target_hint_timer)
	_target_hint_timer.timeout.connect(func() -> void:
		if tutorial_banner != null:
			tutorial_banner.queue_hint("hint_target_npc")
	)

	# hint_speed_controls: fires 14 s after game start.
	var _speed_hint_timer := get_tree().create_timer(14.0)
	_scene_timers.append(_speed_hint_timer)
	_speed_hint_timer.timeout.connect(func() -> void:
		if tutorial_banner != null:
			tutorial_banner.queue_hint("hint_speed_controls")
	)

	# Suppression: pause banner while Journal / Rumour Panel / Pause Menu are open.
	if _journal != null:
		_journal.visibility_changed.connect(_on_journal_visibility_changed_banner)
	if _rumor_panel != null:
		_rumor_panel.visibility_changed.connect(_on_rumor_panel_visibility_changed_banner)

	# Wire camera_moved for HINT-02 gate.
	var cam: Camera2D = _world.get_node_or_null("Camera2D")
	if cam == null:
		for child in get_parent().get_children():
			if child is Camera2D:
				cam = child
				break
	if cam != null and cam.has_signal("camera_moved"):
		cam.camera_moved.connect(_on_s1_camera_moved)

	# HINT-06: day 2 tick (gated behind eavesdrop — SPA-1045).
	if _day_night != null:
		_day_night.game_tick.connect(_on_s1_game_tick)

	# HINT-07: panel seed shown.
	if _rumor_panel != null:
		_rumor_panel.panel_seed_shown.connect(_on_s1_panel_seed_shown)

	# HINT-08: 5 s after seed.
	if _rumor_panel != null:
		_rumor_panel.rumor_seeded.connect(_on_s1_rumor_seeded)

	# HINT-09: first NPC reaches BELIEVE state.
	for npc in _world.npcs:
		npc.rumor_state_changed.connect(_on_s1_rumor_state_changed)

	# HINT-10: evidence acquired.
	if _rumor_panel != null:
		_rumor_panel.evidence_first_shown.connect(_on_s1_evidence_first_shown)

	# SPA-629: Rumor Panel first-time tooltip walkthrough.
	if _rumor_panel != null:
		_rumor_panel_tooltip = preload("res://scripts/rumor_panel_tooltip.gd").new()
		_rumor_panel_tooltip.name = "RumorPanelTooltip"
		add_child(_rumor_panel_tooltip)
		_rumor_panel_tooltip.setup(_rumor_panel)
		_rumor_panel.visibility_changed.connect(_on_rumor_panel_first_open_tooltip)

	# Wire hover signals now that banner is ready.
	if _recon_ctrl_ref != null:
		_wire_s1_recon_hints(_recon_ctrl_ref)


## Wires S1 hint signals from recon_ctrl and NPCs to the tutorial banner.
func _wire_s1_recon_hints(recon_ctrl: Node) -> void:
	if tutorial_banner == null:
		return
	if recon_ctrl.has_signal("valid_eavesdrop_hovered"):
		recon_ctrl.valid_eavesdrop_hovered.connect(_on_s1_valid_eavesdrop_hovered)
	if recon_ctrl.has_signal("building_first_hovered"):
		recon_ctrl.building_first_hovered.connect(_on_s1_building_first_hovered)
	for npc in _world.npcs:
		if npc.has_signal("npc_hovered"):
			npc.npc_hovered.connect(_on_s1_npc_hovered)


## Wire pause menu banner suppression (called from main.gd after pause menu is created).
func wire_pause_menu(pause_menu: CanvasLayer) -> void:
	if tutorial_banner != null and pause_menu != null:
		pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed_banner.bind(pause_menu))


# ── Recon action handler ─────────────────────────────────────────────────────

## Connected to recon_ctrl.action_performed — drives S1 banner gates.
func _on_recon_action_for_tutorial(message: String, success: bool) -> void:
	if not success:
		return
	# SPA-589: Notify visual affordances so they fade after enough actions.
	if _visual_affordances != null and _visual_affordances.has_method("on_action_performed"):
		_visual_affordances.on_action_performed()
	# SPA-724: Fade goal strip after player has taken 3 successful actions.
	_spa724_action_count += 1
	if _spa724_action_count >= 3 and _recon_hud != null and _recon_hud.has_method("fade_goal_strip"):
		_recon_hud.fade_goal_strip()

	# SPA-626: Clear the Market highlight and dismiss the gated banner on first recon action.
	if not _banner_s1_market_cleared:
		_banner_s1_market_cleared = true
		if _visual_affordances != null and _visual_affordances.has_method("clear_single_target"):
			_visual_affordances.clear_single_target()
		if tutorial_banner != null and tutorial_banner.has_method("dismiss_hint"):
			tutorial_banner.dismiss_hint("hint_s1_investigate_gate")

	# SPA-758: Notify banner of action for action-gated hints + advance waypoint.
	if message.begins_with("Observed"):
		if tutorial_banner != null and tutorial_banner.has_method("notify_action"):
			tutorial_banner.notify_action("observe")
		_advance_waypoint("observe")
	elif message.begins_with("Eavesdropped"):
		if tutorial_banner != null and tutorial_banner.has_method("notify_action"):
			tutorial_banner.notify_action("eavesdrop")
		_advance_waypoint("eavesdrop")

	# S1 banner: open observe gate (HINT-04 unlocks) and eavesdrop gate (HINT-05).
	if tutorial_banner != null:
		if message.begins_with("Observed") and not _banner_observe_gate:
			_banner_observe_gate = true
			if not _banner_journal_hint_fired:
				_banner_journal_hint_fired = true
				tutorial_banner.queue_hint("hint_journal")
		if message.begins_with("Eavesdropped"):
			if not _banner_eavesdrop_gate:
				_banner_eavesdrop_gate = true
				if not _banner_journal_hint_fired:
					_banner_journal_hint_fired = true
					tutorial_banner.queue_hint("hint_journal")
				if not _banner_seed_fired:
					var _rumour_nudge_timer := get_tree().create_timer(4.0)
					_scene_timers.append(_rumour_nudge_timer)
					_rumour_nudge_timer.timeout.connect(func() -> void:
						if not is_instance_valid(self):
							return
						if tutorial_banner != null and not _banner_seed_fired:
							tutorial_banner.queue_hint("hint_rumour_panel")
							_banner_hint06_fired = true
						if is_instance_valid(_rumor_panel) and _rumor_panel.panel != null and not _rumor_panel.panel.visible and not _banner_seed_fired:
							_rumor_panel.toggle()
					)
			_banner_eavesdrop_count += 1
			if _banner_eavesdrop_count >= 2 and not _banner_social_graph_fired:
				_banner_social_graph_fired = true
				tutorial_banner.queue_hint("hint_social_graph")


# ── S1 banner signal handlers ─────────────────────────────────────────────────

func _on_s1_camera_moved() -> void:
	_banner_camera_gate = true


func _on_s1_npc_hovered(_npc: Node2D) -> void:
	if _banner_camera_gate and tutorial_banner != null:
		tutorial_banner.queue_hint("hint_hover_npc")
		for npc in _world.npcs:
			if npc.has_signal("npc_hovered") and npc.npc_hovered.is_connected(_on_s1_npc_hovered):
				npc.npc_hovered.disconnect(_on_s1_npc_hovered)


func _on_s1_building_first_hovered() -> void:
	if tutorial_banner != null:
		tutorial_banner.queue_hint("hint_observe")


func _on_s1_valid_eavesdrop_hovered() -> void:
	if _banner_observe_gate and tutorial_banner != null:
		tutorial_banner.queue_hint("hint_eavesdrop")


func _on_s1_game_tick(tick: int) -> void:
	if tick >= 24 and _banner_eavesdrop_gate and not _banner_hint06_fired and tutorial_banner != null and not _banner_seed_fired:
		var intel: PlayerIntelStore = _world.intel_store
		if intel != null and intel.whisper_tokens_remaining >= 1:
			_banner_hint06_fired = true
			tutorial_banner.queue_hint("hint_rumour_panel")


func _on_s1_panel_seed_shown() -> void:
	if tutorial_banner != null:
		tutorial_banner.queue_hint("hint_seed_target")


func _on_s1_rumor_seeded(
		_rumor_id: String,
		_subject_name: String,
		_claim_id: String,
		_seed_target_name: String
) -> void:
	# SPA-758: Dismiss action-gated craft_rumor banner and clear waypoint step 3.
	if tutorial_banner != null and tutorial_banner.has_method("notify_action"):
		tutorial_banner.notify_action("craft_rumor")
	if _waypoint_step == 3:
		_clear_waypoint()
		_waypoint_step = 0
	if _banner_seed_fired or tutorial_banner == null:
		return
	_banner_seed_fired = true
	if _recon_hud != null and _recon_hud.has_method("show_toast"):
		_recon_hud.show_toast("Rumours take time to spread. Watch the dawn bulletin tomorrow.", false)
	var timer := get_tree().create_timer(5.0)
	_scene_timers.append(timer)
	timer.timeout.connect(func() -> void:
		if tutorial_banner != null:
			tutorial_banner.queue_hint("hint_propagation")
	)


func _on_s1_rumor_state_changed(
		_npc_name: String, new_state_name: String, _rumor_id: String
) -> void:
	if new_state_name == "BELIEVE" and not _banner_believe_fired and tutorial_banner != null:
		_banner_believe_fired = true
		tutorial_banner.queue_hint("hint_objectives")


func _on_s1_evidence_first_shown() -> void:
	if tutorial_banner != null and not _evidence_tooltip_fired:
		_evidence_tooltip_fired = true
		tutorial_banner.queue_hint("hint_evidence")


## S1 banner suppression: pause when Journal opens/closes.
func _on_journal_visibility_changed_banner() -> void:
	if tutorial_banner == null or _journal == null:
		return
	if _journal.visible:
		tutorial_banner.suppress()
	else:
		tutorial_banner.unsuppress()


## SPA-629: Show first-time tooltip walkthrough when Rumor Panel opens in S1.
func _on_rumor_panel_first_open_tooltip() -> void:
	if _rumor_panel_tooltip_wired or _rumor_panel_tooltip == null or _rumor_panel == null:
		return
	if not _rumor_panel.visible:
		return
	_rumor_panel_tooltip_wired = true
	_rumor_panel_tooltip.show_walkthrough()
	if _rumor_panel.visibility_changed.is_connected(_on_rumor_panel_first_open_tooltip):
		_rumor_panel.visibility_changed.disconnect(_on_rumor_panel_first_open_tooltip)


## S1 banner suppression: pause when Rumour Panel opens/closes.
func _on_rumor_panel_visibility_changed_banner() -> void:
	if tutorial_banner == null or _rumor_panel == null:
		return
	if _rumor_panel.visible:
		tutorial_banner.suppress()
	else:
		tutorial_banner.unsuppress()


## S1 banner suppression: pause when Pause Menu opens/closes.
func _on_pause_menu_visibility_changed_banner(pause_menu: CanvasLayer) -> void:
	if tutorial_banner == null or pause_menu == null:
		return
	if pause_menu.visible:
		tutorial_banner.suppress()
	else:
		tutorial_banner.unsuppress()


# ── Cross-scenario contextual hint handlers ──────────────────────────────────

func _on_ctx_day_changed(day: int) -> void:
	if tutorial_banner == null:
		return
	if day == 2:
		tutorial_banner.queue_hint("ctx_actions_refresh")
	elif day == 3:
		tutorial_banner.queue_hint("ctx_check_journal")
	# S5: endorsement approaches — warn the player 2 days before.
	if _world.active_scenario_id == "scenario_5" and _world.scenario_manager != null:
		var _endorse_day: int = _world.scenario_manager.S5_ENDORSEMENT_DAY
		if day == _endorse_day - 2:
			tutorial_banner.queue_hint("ctx_s5_endorsement_warning")
	# Halfway warning.
	if not _ctx_halfway_fired and _world.scenario_manager != null:
		var total: int = _world.scenario_manager.get_days_allowed()
		if day > total / 2:
			_ctx_halfway_fired = true
			tutorial_banner.queue_hint("ctx_halfway_warning")
	# SPA-786: Late-game audio tension shift at 75% days used.
	if _world.scenario_manager != null:
		var total_days: int = _world.scenario_manager.get_days_allowed()
		var frac: float = clampf(float(day - 1) / float(max(total_days - 1, 1)), 0.0, 1.0)
		AudioManager.set_late_game_tension(frac >= 0.75)
	# SPA-952: Faction event foreshadow.
	if _world.faction_event_system != null:
		for text in _world.faction_event_system.get_foreshadow_for_day(day):
			tutorial_banner.queue_hint("foreshadow_event", text)


func _on_ctx_rumor_state_changed(
		_npc_name: String, new_state_name: String, _rumor_id: String
) -> void:
	if tutorial_banner == null:
		return
	if new_state_name == "SPREAD" and not _ctx_spread_fired:
		_ctx_spread_fired = true
		tutorial_banner.queue_hint("ctx_rumor_spreading")
	elif new_state_name == "ACT" and not _ctx_act_fired:
		_ctx_act_fired = true
		tutorial_banner.queue_hint("ctx_rumor_acted")
	elif new_state_name == "REJECT" and not _ctx_reject_fired:
		_ctx_reject_fired = true
		tutorial_banner.queue_hint("ctx_rumor_rejected")


func _on_ctx_tokens_exhausted() -> void:
	if _ctx_tokens_fired or tutorial_banner == null:
		return
	_ctx_tokens_fired = true
	tutorial_banner.queue_hint("ctx_out_of_tokens")


func _on_heat_warning() -> void:
	if _ctx_heat_warn_fired:
		return
	_ctx_heat_warn_fired = true
	AudioManager.on_heat_warning()
	if tutorial_banner != null:
		tutorial_banner.queue_hint("ctx_heat_warning")


func _on_rival_first_acted_tutorial(_day: int, _claim: String, _subject: String) -> void:
	if _ctx_rival_first_act_fired or tutorial_banner == null:
		return
	_ctx_rival_first_act_fired = true
	tutorial_banner.queue_hint("ctx_s3_disrupt_tip")


func _on_inquisitor_first_acted_tutorial(_day: int, _claim: String, _subject: String) -> void:
	if _ctx_inquisitor_first_act_fired or tutorial_banner == null:
		return
	_ctx_inquisitor_first_act_fired = true
	tutorial_banner.queue_hint("ctx_s4_prioritize_finn")


# ── SPA-487: Idle-detection hint system ──────────────────────────────────────

func _init_idle_hints() -> void:
	_idle_timer = Timer.new()
	_idle_timer.name = "IdleHintTimer"
	_idle_timer.wait_time = 30.0
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(_on_idle_timeout)
	add_child(_idle_timer)
	_idle_timer.start()

	if _recon_ctrl_ref != null and _recon_ctrl_ref.has_signal("action_performed"):
		_recon_ctrl_ref.action_performed.connect(_on_action_reset_idle)
	if _rumor_panel != null and _rumor_panel.has_signal("rumor_seeded"):
		_rumor_panel.rumor_seeded.connect(_on_rumor_seeded_idle)


func _on_action_reset_idle(message: String, success: bool) -> void:
	if success:
		_has_performed_any_action = true
	if _idle_timer != null:
		_idle_timer.start()


func _on_rumor_seeded_idle(_rid: String = "", _subj: String = "", _claim: String = "", _tgt: String = "") -> void:
	_has_crafted_any_rumor = true
	if _idle_timer != null:
		_idle_timer.start()


func _on_idle_timeout() -> void:
	if tutorial_banner == null:
		return
	if not _has_performed_any_action and not _idle_hint_fired_no_action:
		_idle_hint_fired_no_action = true
		tutorial_banner.queue_hint("ctx_idle_no_action")
	elif _has_performed_any_action and not _has_crafted_any_rumor and not _idle_hint_fired_no_rumor:
		_idle_hint_fired_no_rumor = true
		tutorial_banner.queue_hint("ctx_idle_no_rumor")
	if _idle_timer != null:
		_idle_timer.wait_time = 60.0
		_idle_timer.start()


## Evidence tutorial trigger (S2/S3).
func _on_evidence_first_shown() -> void:
	if _evidence_tooltip_fired or _tutorial_hud == null:
		return
	_evidence_tooltip_fired = true
	_tutorial_hud.queue_tooltip("evidence_items")


## Tooltip (npc_state_change) trigger (S2/S3).
func _on_first_npc_state_change() -> void:
	if _npc_state_change_tooltip_fired or _tutorial_hud == null:
		return
	_npc_state_change_tooltip_fired = true
	_tutorial_hud.queue_tooltip("npc_state_change")


## Tooltip 4 trigger — Rumor Panel first opens (S2/S3).
func _on_rumor_panel_visibility_changed() -> void:
	if _rumor_panel == null or not _rumor_panel.visible:
		return
	if _tutorial_hud != null:
		_tutorial_hud.queue_tooltip("rumor_crafting")
	_rumor_panel.visibility_changed.disconnect(_on_rumor_panel_visibility_changed)


## Tooltip 5 trigger — Journal first opens (S2/S3).
func _on_journal_visibility_changed() -> void:
	if _journal == null or not _journal.visible:
		return
	if _tutorial_hud != null:
		_tutorial_hud.queue_tooltip("reputation")
	_journal.visibility_changed.disconnect(_on_journal_visibility_changed)


# ── S1 onboarding flow ──────────────────────────────────────────────────────

## SPA-626: Camera auto-pan to Market, single-target highlight, and persistent gated banner.
func _init_s1_onboarding_flow() -> void:
	var market_cell: Vector2i = _world._building_entries.get("market", Vector2i(12, 30))
	var market_world_pos: Vector2 = Vector2.ZERO
	if _recon_ctrl_ref != null and _recon_ctrl_ref.has_method("_cell_to_world"):
		market_world_pos = _recon_ctrl_ref._cell_to_world(market_cell)

	if _camera.has_method("pan_to_target"):
		_camera.pan_to_target(market_world_pos, 2.0)

	if _visual_affordances != null and _visual_affordances.has_method("highlight_single_target"):
		_visual_affordances.highlight_single_target(market_world_pos)

	_init_s1_manor_highlight()

	if tutorial_banner != null:
		tutorial_banner.queue_hint("hint_s1_investigate_gate")

	_show_waypoint_step1_market(market_world_pos)

	_tutorial_ctrl = preload("res://scripts/tutorial_controller.gd").new()
	_tutorial_ctrl.name = "TutorialController"
	add_child(_tutorial_ctrl)
	_tutorial_ctrl.setup(
		tutorial_sys, tutorial_banner, _camera,
		_recon_ctrl_ref, _journal, _rumor_panel, _world
	)
	_tutorial_ctrl.start()


## SPA-948: Show the non-auto-dismiss "What's Changed" card for S2-S6.
func _show_whats_changed_card(scenario_id: String) -> void:
	if tutorial_sys == null:
		_init_sx_onboarding_flow(scenario_id)
		return
	var card_data: Dictionary = tutorial_sys.get_whats_changed(scenario_id)
	if card_data.is_empty():
		_init_sx_onboarding_flow(scenario_id)
		return
	var title: String  = card_data.get("title", "What's Changed")
	var bullets: Array = card_data.get("bullets", [])
	_whats_changed_card = preload("res://scripts/whats_changed_card.gd").new()
	_whats_changed_card.name = "WhatsChangedCard"
	add_child(_whats_changed_card)
	_whats_changed_card.setup(title, bullets)
	_whats_changed_card.dismissed.connect(func() -> void:
		_whats_changed_card = null
		_init_sx_onboarding_flow(scenario_id)
	)


## SPA-804: S2-S6 "What's New" banner sequence via TutorialController.
## Also starts the timed opening/onboarding hints now that the Mission Briefing
## has been dismissed and the player can actually read the gameplay tips.
func _init_sx_onboarding_flow(scenario_id: String) -> void:
	if tutorial_sys == null or tutorial_banner == null:
		return
	_tutorial_ctrl = preload("res://scripts/tutorial_controller.gd").new()
	_tutorial_ctrl.name = "TutorialController"
	add_child(_tutorial_ctrl)
	_tutorial_ctrl.setup(
		tutorial_sys, tutorial_banner, _camera,
		_recon_ctrl_ref, _journal, _rumor_panel, _world,
		scenario_id
	)
	_tutorial_ctrl.start()
	# SPA-1020: Start timed hints now that the blocking briefing screen is gone.
	_start_sx_timed_hints(scenario_id)


## SPA-1020: "Your First Move" opening hint + scenario onboarding banners, deferred
## until after the Mission Briefing is dismissed so they never overlap the briefing.
## Timings are relative to when gameplay actually begins (post-briefing), not scene load.
func _start_sx_timed_hints(scenario_id: String) -> void:
	# SPA-537: "Your First Move" opening hint at 2 s after briefing dismissed.
	var opening_hint_id: String = ""
	match scenario_id:
		"scenario_2": opening_hint_id = "ctx_s2_opening"
		"scenario_3": opening_hint_id = "ctx_s3_opening"
		"scenario_4": opening_hint_id = "ctx_s4_opening"
		"scenario_5": opening_hint_id = "ctx_s5_opening"
		"scenario_6": opening_hint_id = "ctx_s6_opening"
	if opening_hint_id != "":
		var _open_timer := get_tree().create_timer(2.0)
		_scene_timers.append(_open_timer)
		var _hint_copy: String = opening_hint_id
		_open_timer.timeout.connect(func() -> void:
			if tutorial_banner != null:
				tutorial_banner.queue_hint(_hint_copy)
		)

	# SPA-549: Scenario-specific onboarding banners at 10/16/22 s from gameplay start.
	var s_hints: Array = []
	match scenario_id:
		"scenario_2":
			s_hints = ["ctx_s2_illness_mechanic", "ctx_s2_maren_warning", "ctx_s2_believer_check"]
		"scenario_3":
			s_hints = ["ctx_s3_dual_targets", "ctx_s3_rival_intro"]
		"scenario_4":
			s_hints = ["ctx_s4_defense_goal", "ctx_s4_inquisitor_info"]
		"scenario_5":
			s_hints = ["ctx_s5_three_way_race", "ctx_s5_endorsement_tip"]
		"scenario_6":
			s_hints = ["ctx_s6_heat_ceiling", "ctx_s6_protect_marta"]
	var delays: Array = [10.0, 16.0, 22.0]
	for i in range(s_hints.size()):
		var hint_id: String = s_hints[i]
		var t := get_tree().create_timer(delays[i])
		_scene_timers.append(t)
		t.timeout.connect(func() -> void:
			if tutorial_banner != null:
				tutorial_banner.queue_hint(hint_id)
		)


# ── SPA-805: S1 manor golden-pulse affordance ────────────────────────────────

func _init_s1_manor_highlight() -> void:
	if _world == null or _recon_ctrl_ref == null:
		return
	var manor_cell: Vector2i = _world._building_entries.get("manor", Vector2i(8, 14))
	var manor_pos := Vector2.ZERO
	if _recon_ctrl_ref.has_method("_cell_to_world"):
		manor_pos = _recon_ctrl_ref._cell_to_world(manor_cell)
	if manor_pos == Vector2.ZERO:
		return
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0.0,  -22.0),
		Vector2(34.0,   0.0),
		Vector2(0.0,   22.0),
		Vector2(-34.0,  0.0),
	])
	poly.color    = Color(1.00, 0.80, 0.12, 0.22)
	poly.name     = "S1ManorHighlight"
	poly.position = manor_pos
	poly.z_index  = 1
	_world.add_child(poly)
	_s1_manor_highlight = poly
	var pulse_tw := poly.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(poly, "modulate:a", 0.35, 1.2)
	pulse_tw.tween_property(poly, "modulate:a", 1.0,  1.2)
	if _day_night != null and _day_night.has_signal("day_changed"):
		var _clear_manor := func(day: int) -> void:
			if day >= 3:
				_clear_s1_manor_highlight()
		_day_night.day_changed.connect(_clear_manor)


func _clear_s1_manor_highlight() -> void:
	if _s1_manor_highlight != null and is_instance_valid(_s1_manor_highlight):
		var tw := create_tween()
		tw.tween_property(_s1_manor_highlight, "modulate:a", 0.0, 0.8)
		tw.tween_callback(_s1_manor_highlight.queue_free)
	_s1_manor_highlight = null


# ── SPA-758: Onboarding waypoint marker system ──────────────────────────────

func _show_waypoint_step1_market(market_pos: Vector2) -> void:
	_clear_waypoint()
	_waypoint_step = 1
	_waypoint_node = _create_waypoint_marker(
		market_pos + Vector2(0.0, -48.0),
		"▼  Start here — Observe who's inside"
	)
	if _world != null:
		_world.add_child(_waypoint_node)


func _show_waypoint_step2_eavesdrop() -> void:
	_clear_waypoint()
	_waypoint_step = 2
	var best_pair_pos: Vector2 = Vector2.ZERO
	var found: bool = false
	if _world != null:
		for i in range(_world.npcs.size()):
			if found:
				break
			for j in range(i + 1, _world.npcs.size()):
				var npc_a: Node2D = _world.npcs[i]
				var npc_b: Node2D = _world.npcs[j]
				var dist: int = abs(npc_a.current_cell.x - npc_b.current_cell.x) \
				              + abs(npc_a.current_cell.y - npc_b.current_cell.y)
				if dist <= 3:
					best_pair_pos = (npc_a.position + npc_b.position) * 0.5
					found = true
					break
	if not found:
		if _world != null and _world.npcs.size() > 0:
			best_pair_pos = _world.npcs[0].position
	_waypoint_node = _create_waypoint_marker(
		best_pair_pos + Vector2(0.0, -56.0),
		"▼  Eavesdrop on their relationship"
	)
	if _world != null:
		_world.add_child(_waypoint_node)


func _show_waypoint_step3_craft() -> void:
	_clear_waypoint()
	_waypoint_step = 3
	var cl := CanvasLayer.new()
	cl.name = "WaypointCraftPrompt"
	cl.layer = 18
	add_child(cl)
	var lbl := Label.new()
	lbl.text = "Press  R  to craft your first rumor"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.957, 0.651, 0.227, 1.0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.anchor_left   = 0.5
	lbl.anchor_right  = 0.5
	lbl.anchor_top    = 0.7
	lbl.anchor_bottom = 0.7
	lbl.offset_left   = -200
	lbl.offset_right  = 200
	lbl.offset_top    = -20
	lbl.offset_bottom = 20
	cl.add_child(lbl)
	_waypoint_tween = cl.create_tween().set_loops()
	_waypoint_tween.tween_property(lbl, "modulate:a", 0.3, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_waypoint_tween.tween_property(lbl, "modulate:a", 1.0, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var _craft_timeout := get_tree().create_timer(30.0)
	_scene_timers.append(_craft_timeout)
	_craft_timeout.timeout.connect(func() -> void:
		if _waypoint_step == 3:
			_clear_waypoint()
			_waypoint_step = 0
	)


func _advance_waypoint(action: String) -> void:
	if _waypoint_step == 1 and action == "observe":
		_show_waypoint_step2_eavesdrop()
	elif _waypoint_step == 2 and action == "eavesdrop":
		_show_waypoint_step3_craft()


func _clear_waypoint() -> void:
	if _waypoint_tween != null and _waypoint_tween.is_valid():
		_waypoint_tween.kill()
	_waypoint_tween = null
	if _waypoint_node != null and is_instance_valid(_waypoint_node):
		_waypoint_node.queue_free()
		_waypoint_node = null
	var craft_prompt := get_node_or_null("WaypointCraftPrompt")
	if craft_prompt != null:
		craft_prompt.queue_free()


func _create_waypoint_marker(pos: Vector2, text: String) -> Node2D:
	var root := Node2D.new()
	root.name = "WaypointMarker"
	root.position = pos
	root.z_index = 12

	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0.0,  -10.0),
		Vector2(7.0,   0.0),
		Vector2(0.0,   10.0),
		Vector2(-7.0,  0.0),
	])
	diamond.color = Color(0.957, 0.651, 0.227, 0.90)
	root.add_child(diamond)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.84, 0.40, 1.0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl.position = Vector2(12, -10)
	root.add_child(lbl)

	_waypoint_tween = root.create_tween().set_loops()
	_waypoint_tween.tween_property(root, "modulate:a", 0.35, 1.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_waypoint_tween.tween_property(root, "modulate:a", 1.0, 1.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	return root
