extends Node

## tutorial_controller.gd — Interactive step-gated tutorial for Scenario 1 (SPA-768).
##
## Drives new players through the core gameplay loop in 6 ordered steps:
##   Step 0: Camera / movement intro  (gate: camera_moved signal)
##   Step 1: Observe a building       (gate: successful observe action)
##   Step 2: Open journal             (gate: journal becomes visible)
##   Step 3: Craft a rumor            (gate: rumor panel panel_seed_shown)
##   Step 4: Seed via whisper token   (gate: rumor_seeded signal)
##   Step 5: Watch propagation        (gate: NPC reaches BELIEVE state)
##
## Each step highlights the relevant UI element via TutorialBanner and blocks
## progression until the gate condition is met.
##
## Returning players (detected via SaveManager.has_any_save()) are offered a
## "Skip Tutorial" option.  Skipping marks all steps seen and exits immediately.
##
## Usage from main.gd:
##   var tc := preload("res://scripts/tutorial_controller.gd").new()
##   tc.name = "TutorialController"
##   add_child(tc)
##   tc.setup(tutorial_sys, tutorial_banner, camera, recon_ctrl, journal,
##            rumor_panel, world)
##   tc.start()

class_name TutorialController

signal tutorial_completed
signal tutorial_skipped

# ── Step definitions ─────────────────────────────────────────────────────────

const STEPS: Array = [
	{
		"id": "tut_camera",
		"hint": "hint_camera",
		"title": "Move the Camera",
		"body": (
			"[b]WASD[/b] or [b]Arrow Keys[/b] to pan the camera.\n"
			+ "[b]Scroll Wheel[/b] to zoom in and out.\n"
			+ "Try moving the camera now to continue."
		),
	},
	{
		"id": "tut_observe",
		"hint": "hint_first_action",
		"title": "Step 1: Observe a Building",
		"body": (
			"[b]Right-click any building[/b] to see who is inside.\n"
			+ "Start with the [b]Market Square[/b] — it has the most NPCs.\n"
			+ "You get [b]3 actions per day[/b]."
		),
		"action_gate": "observe",
	},
	{
		"id": "tut_journal",
		"hint": "hint_journal",
		"title": "Step 2: Review Your Intel",
		"body": (
			"Press [b]J[/b] to open your Journal.\n"
			+ "The Intelligence tab logs every observation you have gathered.\n"
			+ "Open the Journal now to continue."
		),
	},
	{
		"id": "tut_craft",
		"hint": "hint_rumour_panel",
		"title": "Step 3: Craft a Rumor",
		"body": (
			"Press [b]R[/b] to open the Rumor Panel.\n"
			+ "Pick a [b]subject[/b], choose a [b]claim[/b] (Scandal works well),\n"
			+ "then pick a [b]seed target[/b] — a well-connected NPC."
		),
		"action_gate": "craft_rumor",
	},
	{
		"id": "tut_seed",
		"hint": "hint_seed_target",
		"title": "Step 4: Seed Your Rumor",
		"body": (
			"Choose someone with [b]high sociability[/b] — they spread rumors faster.\n"
			+ "Each seed costs [b]1 Whisper Token[/b] (refreshes at dawn).\n"
			+ "Seed your rumor now to continue."
		),
	},
	{
		"id": "tut_propagation",
		"hint": "hint_propagation",
		"title": "Step 5: Watch It Spread",
		"body": (
			"Your rumor is planted! The seed target is [b]Evaluating[/b] it.\n"
			+ "If they [b]Believe[/b], they tell others and the rumor [b]Spreads[/b].\n"
			+ "Wait for an NPC to believe your rumor."
		),
	},
]

# ── Step IDs for convenience ─────────────────────────────────────────────────

const STEP_CAMERA      := 0
const STEP_OBSERVE     := 1
const STEP_JOURNAL     := 2
const STEP_CRAFT       := 3
const STEP_SEED        := 4
const STEP_PROPAGATION := 5

# ── State ────────────────────────────────────────────────────────────────────

var _current_step: int = -1  ## -1 = not started, 0–5 = active step, 6 = done
var _active: bool = false
var _skipped: bool = false

# ── External references (set via setup()) ────────────────────────────────────

var _tutorial_sys:    TutorialSystem = null
var _tutorial_banner: Node           = null  # TutorialBanner CanvasLayer
var _camera:          Camera2D       = null
var _recon_ctrl:      Node           = null  # ReconController
var _journal:         CanvasLayer    = null
var _rumor_panel:     CanvasLayer    = null
var _world:           Node2D         = null

# ── Skip overlay ─────────────────────────────────────────────────────────────

var _skip_overlay:    CanvasLayer    = null
var _skip_shown:      bool           = false


## Wire all external dependencies.  Must be called before start().
func setup(
		tutorial_sys: TutorialSystem,
		tutorial_banner: Node,
		cam: Camera2D,
		recon_ctrl: Node,
		journal_node: CanvasLayer,
		rumor_panel_node: CanvasLayer,
		world_node: Node2D
) -> void:
	_tutorial_sys    = tutorial_sys
	_tutorial_banner = tutorial_banner
	_camera          = cam
	_recon_ctrl      = recon_ctrl
	_journal         = journal_node
	_rumor_panel     = rumor_panel_node
	_world           = world_node


## Begin the interactive tutorial.
## If the player has saves (returning player), show skip option first.
func start() -> void:
	if _tutorial_sys == null or _tutorial_banner == null:
		return

	# Detect returning player via SaveManager.
	if SaveManager.has_any_save():
		_show_skip_option()
	else:
		_begin_tutorial()


## Force-skip the tutorial (called from skip overlay or externally).
func skip() -> void:
	_skipped = true
	_active = false
	_current_step = STEPS.size()
	# Mark all tutorial controller steps as seen so they don't re-trigger.
	for step_def in STEPS:
		if _tutorial_sys != null:
			_tutorial_sys.mark_seen(step_def["id"])
	_disconnect_all()
	if _skip_overlay != null:
		_skip_overlay.queue_free()
		_skip_overlay = null
	tutorial_skipped.emit()


# ── Skip option UI ───────────────────────────────────────────────────────────

const C_SKIP_BG      := Color(0.06, 0.04, 0.02, 0.85)
const C_SKIP_BORDER  := Color(0.55, 0.38, 0.18, 1.0)
const C_SKIP_HEADING := Color(0.92, 0.78, 0.12, 1.0)
const C_SKIP_BODY    := Color(0.80, 0.72, 0.55, 1.0)
const C_BTN_NORMAL   := Color(0.35, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.55, 0.35, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.92, 0.82, 0.60, 1.0)

func _show_skip_option() -> void:
	if _skip_shown:
		return
	_skip_shown = true

	_skip_overlay = CanvasLayer.new()
	_skip_overlay.layer = 21  # above TutorialHUD (20)
	add_child(_skip_overlay)

	# Backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.02, 0.01, 0.70)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_overlay.add_child(backdrop)

	# Panel
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220
	panel.offset_top = -100
	panel.offset_right = 220
	panel.offset_bottom = 100
	var style := StyleBoxFlat.new()
	style.bg_color = C_SKIP_BG
	style.border_color = C_SKIP_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	_skip_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Interactive Tutorial"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", C_SKIP_HEADING)
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var body := Label.new()
	body.text = "Would you like to play the guided tutorial?\nIt walks you through the core mechanics step by step."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", C_SKIP_BODY)
	body.add_theme_font_size_override("font_size", 13)
	vbox.add_child(body)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var play_btn := _make_button("  Play Tutorial  ")
	play_btn.pressed.connect(_on_play_tutorial)
	btn_row.add_child(play_btn)

	var skip_btn := _make_button("  Skip  ")
	skip_btn.pressed.connect(_on_skip_tutorial)
	btn_row.add_child(skip_btn)

	# Focus the play button by default.
	play_btn.call_deferred("grab_focus")


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 34)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	btn.add_theme_color_override("font_hover_color", C_BTN_TEXT)
	btn.add_theme_color_override("font_pressed_color", C_BTN_TEXT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN_NORMAL
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_HOVER
	hover.set_corner_radius_all(4)
	hover.content_margin_left = 12.0
	hover.content_margin_right = 12.0
	hover.content_margin_top = 6.0
	hover.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn


func _on_play_tutorial() -> void:
	if _skip_overlay != null:
		_skip_overlay.queue_free()
		_skip_overlay = null
	_begin_tutorial()


func _on_skip_tutorial() -> void:
	skip()


# ── Tutorial flow ────────────────────────────────────────────────────────────

func _begin_tutorial() -> void:
	_active = true
	_current_step = -1
	_connect_signals()
	_advance_step()


func _advance_step() -> void:
	if not _active:
		return
	_current_step += 1
	if _current_step >= STEPS.size():
		_finish_tutorial()
		return
	_show_step(_current_step)


func _show_step(step_idx: int) -> void:
	var step_def: Dictionary = STEPS[step_idx]
	var step_id: String = step_def["id"]

	# Already completed (e.g. from a save restore) — skip silently.
	if _tutorial_sys != null and _tutorial_sys.has_seen(step_id):
		_advance_step()
		return

	# Queue the hint via the existing banner system.
	# We use a custom body for the tutorial controller steps so they read as a
	# coherent guided sequence, but fall back to the hint data if no body is set.
	if _tutorial_banner != null and _tutorial_banner.has_method("queue_hint"):
		var body: String = step_def.get("body", "")
		_tutorial_banner.queue_hint(step_def["hint"], body)


func _finish_tutorial() -> void:
	_active = false
	_disconnect_all()
	tutorial_completed.emit()


func _complete_current_step() -> void:
	if not _active or _current_step < 0 or _current_step >= STEPS.size():
		return
	var step_def: Dictionary = STEPS[_current_step]
	if _tutorial_sys != null:
		_tutorial_sys.mark_seen(step_def["id"])
	# Dismiss the current banner hint for this step.
	if _tutorial_banner != null and _tutorial_banner.has_method("dismiss_hint"):
		_tutorial_banner.dismiss_hint(step_def["hint"])
	_advance_step()


# ── Signal connections ───────────────────────────────────────────────────────

var _connected_camera: bool = false
var _connected_recon: bool = false
var _connected_journal: bool = false
var _connected_rumor_seeded: bool = false
var _connected_panel_seed: bool = false
var _connected_npc_states: bool = false


func _connect_signals() -> void:
	# Step 0: camera moved
	if _camera != null and _camera.has_signal("camera_moved") and not _connected_camera:
		_camera.camera_moved.connect(_on_tc_camera_moved)
		_connected_camera = true

	# Step 1: observe action
	if _recon_ctrl != null and _recon_ctrl.has_signal("action_performed") and not _connected_recon:
		_recon_ctrl.action_performed.connect(_on_tc_recon_action)
		_connected_recon = true

	# Step 2: journal opened
	if _journal != null and not _connected_journal:
		_journal.visibility_changed.connect(_on_tc_journal_visibility)
		_connected_journal = true

	# Step 3: craft rumor (panel_seed_shown fires when step 3 of rumor panel is reached)
	if _rumor_panel != null and _rumor_panel.has_signal("panel_seed_shown") and not _connected_panel_seed:
		_rumor_panel.panel_seed_shown.connect(_on_tc_panel_seed_shown)
		_connected_panel_seed = true

	# Step 4: rumor seeded
	if _rumor_panel != null and _rumor_panel.has_signal("rumor_seeded") and not _connected_rumor_seeded:
		_rumor_panel.rumor_seeded.connect(_on_tc_rumor_seeded)
		_connected_rumor_seeded = true

	# Step 5: NPC reaches BELIEVE
	if _world != null and not _connected_npc_states:
		for npc in _world.npcs:
			if npc.has_signal("rumor_state_changed"):
				npc.rumor_state_changed.connect(_on_tc_rumor_state_changed)
		_connected_npc_states = true


func _disconnect_all() -> void:
	if _connected_camera and _camera != null and _camera.has_signal("camera_moved"):
		if _camera.camera_moved.is_connected(_on_tc_camera_moved):
			_camera.camera_moved.disconnect(_on_tc_camera_moved)
	_connected_camera = false

	if _connected_recon and _recon_ctrl != null:
		if _recon_ctrl.action_performed.is_connected(_on_tc_recon_action):
			_recon_ctrl.action_performed.disconnect(_on_tc_recon_action)
	_connected_recon = false

	if _connected_journal and _journal != null:
		if _journal.visibility_changed.is_connected(_on_tc_journal_visibility):
			_journal.visibility_changed.disconnect(_on_tc_journal_visibility)
	_connected_journal = false

	if _connected_panel_seed and _rumor_panel != null:
		if _rumor_panel.panel_seed_shown.is_connected(_on_tc_panel_seed_shown):
			_rumor_panel.panel_seed_shown.disconnect(_on_tc_panel_seed_shown)
	_connected_panel_seed = false

	if _connected_rumor_seeded and _rumor_panel != null:
		if _rumor_panel.rumor_seeded.is_connected(_on_tc_rumor_seeded):
			_rumor_panel.rumor_seeded.disconnect(_on_tc_rumor_seeded)
	_connected_rumor_seeded = false

	if _connected_npc_states and _world != null:
		for npc in _world.npcs:
			if npc.has_signal("rumor_state_changed"):
				if npc.rumor_state_changed.is_connected(_on_tc_rumor_state_changed):
					npc.rumor_state_changed.disconnect(_on_tc_rumor_state_changed)
	_connected_npc_states = false


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_tc_camera_moved() -> void:
	if _current_step == STEP_CAMERA:
		_complete_current_step()


func _on_tc_recon_action(message: String, success: bool) -> void:
	if not success:
		return
	if _current_step == STEP_OBSERVE and message.begins_with("Observed"):
		_complete_current_step()


func _on_tc_journal_visibility() -> void:
	if _current_step == STEP_JOURNAL and _journal != null and _journal.visible:
		_complete_current_step()


func _on_tc_panel_seed_shown() -> void:
	if _current_step == STEP_CRAFT:
		_complete_current_step()


func _on_tc_rumor_seeded(_rumor_id: String, _subject: String, _claim: String, _target: String) -> void:
	if _current_step == STEP_SEED:
		_complete_current_step()


func _on_tc_rumor_state_changed(_npc_name: String, new_state: String, _rumor_id: String) -> void:
	if _current_step == STEP_PROPAGATION and new_state == "BELIEVE":
		_complete_current_step()


## Returns true if the tutorial is currently active and gating progression.
func is_active() -> bool:
	return _active


## Returns the current step index, or -1 if not started.
func get_current_step() -> int:
	return _current_step
