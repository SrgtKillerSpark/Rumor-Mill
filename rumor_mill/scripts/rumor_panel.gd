extends CanvasLayer

## rumor_panel.gd — Sprint 3 Rumor Crafting Modal (3-panel flow).
##
## Panel 1 — Subject Selection
##   Shows all NPCs with faction badges and known relationship intel.
##   Lock icon for NPCs with no eavesdrop data.
##
## Panel 2 — Claim Selection
##   Shows all 15 claim cards filtered by subject faction.
##   Displays claim type, template text, intensity bars, and mutability.
##
## Panel 3 — Seed Target + Confirm
##   Shows all NPCs as seed targets with spread estimate and believability.
##   Displays Whisper Token count. Confirm & Seed button calls world.seed_rumor_from_player().
##
## Toggle via R key (handled by ReconHUD) → call toggle().
## Call setup(world, intel_store) after the scene tree is ready.
##
## Content for each panel is delegated to focused sub-modules (SPA-1014):
##   RumorPanelSubjectList, RumorPanelClaimList, RumorPanelSeedList,
##   RumorPanelEstimates.

signal rumor_seeded(rumor_id: String, subject_name: String, claim_id: String, seed_target_name: String)
signal evidence_first_shown
## Emitted the first time the player reaches the Seed Target panel (panel 3).
## Used by the tutorial hint system to trigger HINT-07 (hint_seed_target).
signal panel_seed_shown

# Panel index constants.
const PANEL_SUBJECT := 0
const PANEL_CLAIM   := 1
const PANEL_SEED    := 2

# ── Colour palette (coordinator-level: nav buttons, status, spread overlay) ───

const C_GOLD           := Color(0.90, 0.75, 0.20, 1.0)
const C_GOLD_BRIGHT    := Color(0.92, 0.78, 0.12, 1.0)
const C_FOCUS_RING     := Color(1.00, 0.90, 0.40, 1.0)
const C_STATUS_WARN    := Color(1.0,  0.65, 0.20, 1.0)
const C_BTN_NORMAL_BG  := Color(0.35, 0.22, 0.08, 1.0)
const C_BTN_BORDER     := Color(0.55, 0.38, 0.18, 1.0)
const C_BTN_HOVER_BG   := Color(0.55, 0.35, 0.12, 1.0)
const C_BTN_TEXT       := Color(0.92, 0.82, 0.60, 1.0)

# Spread-overlay ring colours.
const C_SPREAD_RING_SEED := Color(1.0,  1.0,  1.0,  0.90)
const C_SPREAD_HIGH      := Color(1.0,  0.35, 0.15, 0.85)
const C_SPREAD_MED       := Color(1.0,  0.80, 0.15, 0.80)
const C_SPREAD_LOW       := Color(0.30, 0.90, 0.30, 0.75)

# ── Scene nodes (from RumorPanel.tscn) ───────────────────────────────────────

@onready var panel:       Panel = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var hint_label:  Label = $Panel/VBox/HintLabel

# Panel 1's content container (from .tscn).
@onready var _p1_scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var _npc_list:  VBoxContainer   = $Panel/VBox/Scroll/NPCList

# Built dynamically in _ready().
var _p2_scroll:    ScrollContainer = null
var _claim_list:   VBoxContainer   = null
var _p3_scroll:    ScrollContainer = null
var _seed_list:    VBoxContainer   = null
var _whisper_bar:  Label           = null
var _nav_row:      HBoxContainer   = null
var _btn_back:     Button          = null
var _btn_next:     Button          = null
var _status_label: Label           = null

# ── References ────────────────────────────────────────────────────────────────

var _world_ref:          Node2D           = null
var _intel_store_ref:    PlayerIntelStore = null
var _analytics_manager                   = null  ## SPA-1530: set via set_analytics_manager()

## SPA-1539: Maren's direct social-graph neighbours (NPC id → edge weight).
## Populated in setup(); used to show a proximity warning when the player
## selects a seed target that is adjacent to Maren in the social graph.
var _maren_neighbours: Dictionary = {}

# Texture atlases.
var _portrait_tex:   Texture2D = null
var _claim_icon_tex: Texture2D = null

# ── Sub-modules ───────────────────────────────────────────────────────────────

var _estimates:    RumorPanelEstimates   = null
var _subject_list: RumorPanelSubjectList = null
var _claim_list_m: RumorPanelClaimList   = null
var _seed_list_m:  RumorPanelSeedList    = null

# ── Crafting state ────────────────────────────────────────────────────────────

var _current_panel:        int    = PANEL_SUBJECT
var _selected_subject:     String = ""
var _selected_claim_id:    String = ""
var _selected_seed_npc:    String = ""
var _confirm_pending:      bool   = false
var _selected_evidence_item               = null
var _panel_tween:          Tween  = null
var _evidence_tutorial_fired: bool        = false
var _panel_seed_shown_fired:  bool        = false

# SPA-894: Confirm-pending glow tween for decision tension.
var _confirm_glow_tween: Tween = null
# SPA-992: Status label fade-in tween.
var _status_flash_tween: Tween = null

# Spread prediction overlay — draw node + hovered seed NPC.
var _spread_draw_node:  Node2D = null
var _hover_seed_npc_id: String = ""

# Panel titles / hints.
const TITLES := [
	"Rumor Crafting — (1/3) Subject Selection",
	"Rumor Crafting — (2/3) Choose a Claim",
	"Rumor Crafting — (3/3) Seed Target & Confirm",
]
const HINTS := [
	"Select the NPC this rumor will be about.  Press R or Esc to close.",
	"Choose what kind of rumor to spread.  Click ← Back to change subject.",
	"Choose who to whisper the rumor to.  Click ← Back to change claim.  Seeding costs 1 Whisper Token.",
]


func _ready() -> void:
	layer = 15
	panel.visible = false
	_load_ui_textures()
	_build_dynamic_panels()
	_init_modules()
	_init_spread_overlay()


func _load_ui_textures() -> void:
	_portrait_tex   = load("res://assets/textures/ui_npc_portraits.png")
	_claim_icon_tex = load("res://assets/textures/ui_claim_icons.png")


func _init_modules() -> void:
	_estimates    = RumorPanelEstimates.new()
	_subject_list = RumorPanelSubjectList.new()
	_claim_list_m = RumorPanelClaimList.new()
	_seed_list_m  = RumorPanelSeedList.new()
	# setup() calls that need refs are deferred to setup() below.


## SPA-1530: Receive analytics manager reference so evidence_used events can be logged.
func set_analytics_manager(am) -> void:
	_analytics_manager = am


func setup(world: Node2D, intel_store: PlayerIntelStore) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store
	_estimates.setup(world, intel_store)
	_subject_list.setup(world, intel_store, _portrait_tex)
	_claim_list_m.setup(world, _claim_icon_tex)
	_seed_list_m.setup(world, intel_store, _estimates)
	# SPA-1539: cache Maren's neighbours so seed-target proximity warnings can be shown.
	if world != null and world.get("social_graph") != null:
		_maren_neighbours = world.social_graph.get_neighbours(ScenarioManager.MAREN_NUN_ID)


func toggle() -> void:
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	if panel.visible:
		AudioManager.play_ui("panel_close")
		_on_seed_hover_exit()
		# Slide out to left.
		_panel_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_panel_tween.tween_property(panel, "modulate:a", 0.0, 0.12)
		_panel_tween.parallel().tween_property(panel, "position:x", panel.position.x - 30.0, 0.15)
		_panel_tween.tween_callback(func() -> void:
			panel.visible = false
			panel.position.x += 30.0
		)
	else:
		AudioManager.play_ui("panel_open")
		_open_panel(PANEL_SUBJECT)
		panel.visible = true
		# Slide in from left.
		panel.modulate.a = 0.0
		var target_x: float = panel.position.x
		panel.position.x -= 30.0
		_panel_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_panel_tween.tween_property(panel, "modulate:a", 1.0, 0.18)
		_panel_tween.parallel().tween_property(panel, "position:x", target_x, 0.22)
		if _btn_next != null:
			_btn_next.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()


# ── Dynamic panel construction ────────────────────────────────────────────────

func _build_dynamic_panels() -> void:
	var vbox: VBoxContainer = $Panel/VBox

	_whisper_bar = Label.new()
	_whisper_bar.add_theme_font_size_override("font_size", 12)
	_whisper_bar.add_theme_color_override("font_color", C_GOLD)
	_whisper_bar.tooltip_text = "Whisper Tokens Remaining\nHow many times you can seed rumors today. Replenishes at dawn."
	_whisper_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_whisper_bar.visible = false
	vbox.add_child(_whisper_bar)

	# Panel 2: Claim selection.
	_p2_scroll = ScrollContainer.new()
	_p2_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_p2_scroll.custom_minimum_size = Vector2(0, 120)
	_p2_scroll.visible = false
	_claim_list = VBoxContainer.new()
	_claim_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p2_scroll.add_child(_claim_list)
	vbox.add_child(_p2_scroll)

	# Panel 3: Seed target selection.
	_p3_scroll = ScrollContainer.new()
	_p3_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_p3_scroll.custom_minimum_size = Vector2(0, 120)
	_p3_scroll.visible = false
	_seed_list = VBoxContainer.new()
	_seed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p3_scroll.add_child(_seed_list)
	vbox.add_child(_p3_scroll)

	# Status label (feedback on panel 3).
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.20, 1.0))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(200, 0)
	_status_label.custom_maximum_size = Vector2(0, 40)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.visible = false
	vbox.add_child(_status_label)

	# Navigation row.
	_nav_row = HBoxContainer.new()
	_btn_back = _make_nav_button("← Back")
	_btn_back.visible = false
	_btn_back.pressed.connect(_on_back_pressed)
	_nav_row.add_child(_btn_back)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nav_row.add_child(spacer)

	_btn_next = _make_nav_button("Next →")
	_btn_next.visible = false
	_btn_next.pressed.connect(_on_next_pressed)
	_nav_row.add_child(_btn_next)

	vbox.add_child(_nav_row)


# ── Panel switching ───────────────────────────────────────────────────────────

func _open_panel(idx: int) -> void:
	if idx != PANEL_SEED:
		_on_seed_hover_exit()
	_current_panel = idx
	title_label.text = TITLES[idx]
	hint_label.text  = HINTS[idx]

	# SPA-769: Step-specific tooltip on the title label.
	var step_tooltips: Array = [
		"Subject Selection\nChoose which NPC this rumor targets. Their faction and reputation affect spread.",
		"Claim Type\nThe kind of rumor you are spreading. Intensity and mutability affect how it travels.",
		"Seed Target\nThe first NPC to hear the rumor. Well-connected NPCs spread it farther.",
	]
	if idx < step_tooltips.size():
		title_label.tooltip_text = step_tooltips[idx]

	_p1_scroll.visible = (idx == PANEL_SUBJECT)
	_p2_scroll.visible = (idx == PANEL_CLAIM)
	_p3_scroll.visible = (idx == PANEL_SEED)
	_whisper_bar.visible = (idx == PANEL_SEED)
	_btn_back.visible    = (idx != PANEL_SUBJECT)

	_confirm_pending = false
	_stop_confirm_glow()
	_btn_next.visible = true
	if idx == PANEL_SEED:
		_btn_next.text = "Confirm & Seed"
		if not _panel_seed_shown_fired:
			_panel_seed_shown_fired = true
			panel_seed_shown.emit()
	else:
		_btn_next.text = "Next →"

	_status_label.visible = false

	match idx:
		PANEL_SUBJECT:
			_rebuild_subject_list()
		PANEL_CLAIM:
			_rebuild_claim_list()
		PANEL_SEED:
			_rebuild_seed_list()

	if idx == PANEL_SUBJECT:
		if _btn_next != null:
			_btn_next.call_deferred("grab_focus")
	else:
		if _btn_back != null:
			_btn_back.call_deferred("grab_focus")


# ── List rebuilds (delegate to modules) ──────────────────────────────────────

func _rebuild_subject_list() -> void:
	_subject_list.build(_npc_list, _selected_subject, func(npc_id: String) -> void:
		_selected_subject  = npc_id
		_selected_claim_id = ""
		_selected_seed_npc = ""
		_pop_selection_confirm()
		_rebuild_subject_list()
	)


func _rebuild_claim_list() -> void:
	var subject_faction := _get_npc_faction(_selected_subject)
	_claim_list_m.build(_claim_list, subject_faction, _selected_claim_id, func(claim_id: String) -> void:
		_selected_claim_id      = claim_id
		_selected_seed_npc      = ""
		_selected_evidence_item = null
		_pop_selection_confirm()
		_rebuild_claim_list()
	)


func _rebuild_seed_list() -> void:
	# Check evidence tutorial flag from seed list module.
	var pre_fired: bool = _seed_list_m.evidence_tutorial_fired
	_seed_list_m.build(
		_seed_list,
		_whisper_bar,
		_selected_subject,
		_selected_claim_id,
		_selected_seed_npc,
		_selected_evidence_item,
		func(npc_id: String) -> void:  # on_select_seed
			_selected_seed_npc = npc_id
			_confirm_pending   = false
			_stop_confirm_glow()
			_btn_next.text     = "Confirm & Seed"
			# SPA-1539: warn when the chosen seed target is a direct Maren neighbour.
			if not _maren_neighbours.is_empty() and _maren_neighbours.has(npc_id):
				_flash_status("⚠ This NPC is close to Maren — rumor may be countered quickly"),
		func(npc_id: String) -> void:  # on_hover_enter
			_on_seed_hover_enter(npc_id),
		func() -> void:  # on_hover_exit
			_on_seed_hover_exit(),
		func(item) -> void:  # on_evidence_select
			_selected_evidence_item = item
			_confirm_pending        = false
			_btn_next.text          = "Confirm & Seed"
			_rebuild_seed_list(),
		func() -> void:  # on_evidence_clear
			_selected_evidence_item = null
			_confirm_pending        = false
			_btn_next.text          = "Confirm & Seed"
			_rebuild_seed_list(),
		func() -> void:  # on_pop_confirm
			_pop_selection_confirm()
	)
	# Emit evidence tutorial signal if the module just set the flag for the first time.
	if not pre_fired and _seed_list_m.evidence_tutorial_fired:
		evidence_first_shown.emit()


# ── Nav callbacks ─────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	_open_panel(maxi(0, _current_panel - 1))


func _on_next_pressed() -> void:
	match _current_panel:
		PANEL_SUBJECT:
			if _selected_subject.is_empty():
				_flash_status("Select a subject NPC first.")
				return
			_open_panel(PANEL_CLAIM)
		PANEL_CLAIM:
			if _selected_claim_id.is_empty():
				_flash_status("Select a claim first.")
				return
			_open_panel(PANEL_SEED)
		PANEL_SEED:
			if not _confirm_pending:
				if _selected_seed_npc.is_empty():
					_flash_status("Select a seed target first.")
					return
				var tokens: int = _intel_store_ref.whisper_tokens_remaining if _intel_store_ref != null else 0
				var subj_name := _get_npc_name(_selected_subject)
				var seed_name := _get_npc_name(_selected_seed_npc)

				# SPA-894: Build risk/reward summary for decision tension.
				var seed_node: Node2D = null
				for npc in _world_ref.npcs:
					if npc.npc_data.get("id", "") == _selected_seed_npc:
						seed_node = npc
						break
				var spread_est: float = 0.0
				var belief_est: float = 0.0
				if seed_node != null:
					spread_est = _estimates.estimate_spread(seed_node)["value"]
					belief_est = _estimates.estimate_believability(
						_selected_seed_npc, _selected_claim_id, _selected_subject, seed_name
					)["value"]
				var heat_risk := "None"
				if _intel_store_ref != null and _intel_store_ref.heat_enabled:
					var cur_heat: float = _intel_store_ref.get_heat(_selected_seed_npc)
					if cur_heat >= 50.0:
						heat_risk = "HIGH — suspicion will rise"
					elif cur_heat >= 25.0:
						heat_risk = "Moderate — some suspicion"
					else:
						heat_risk = "Low"
				var summary := (
					"▸ REWARD: ~%d NPCs reached, %d%% believability\n"
					+ "▸ RISK: Heat %s | Tokens after: %d\n"
					+ "▸ Target: %s about %s → whisper to %s\n"
					+ "\nClick 'Confirm & Seed' once more to commit."
				) % [
					roundi(spread_est), roundi(belief_est * 100.0),
					heat_risk, tokens - 1,
					_selected_claim_id, subj_name, seed_name,
				]
				_flash_status(summary)
				_confirm_pending = true
				_btn_next.text   = "Confirm & Seed ✓"
				_start_confirm_glow()
			else:
				_try_confirm_seed()


# ── Status / animation feedback ───────────────────────────────────────────────

func _flash_status(msg: String) -> void:
	_status_label.text = msg
	_status_label.visible = true
	# SPA-992: Fade in instead of snapping visible.
	_status_label.modulate.a = 0.0
	if _status_flash_tween != null and _status_flash_tween.is_valid():
		_status_flash_tween.kill()
	_status_flash_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_status_flash_tween.tween_property(_status_label, "modulate:a", 1.0, 0.18)


## SPA-992: Brief scale pop on the Next/Confirm button to confirm a selection.
func _pop_selection_confirm() -> void:
	if _btn_next == null:
		return
	_btn_next.pivot_offset = _btn_next.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_next, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(_btn_next, "scale", Vector2.ONE, 0.12)


## SPA-894: Looping glow pulse on the Confirm button while _confirm_pending is true.
func _start_confirm_glow() -> void:
	if _btn_next == null:
		return
	_stop_confirm_glow()
	_confirm_glow_tween = create_tween().set_loops()
	var bright := Color(0.95, 0.78, 0.20, 1.0)
	var dim    := Color(0.65, 0.45, 0.12, 1.0)
	_confirm_glow_tween.tween_property(
		_btn_next, "theme_override_colors/font_color", bright, 0.5
	).set_trans(Tween.TRANS_SINE)
	_confirm_glow_tween.tween_property(
		_btn_next, "theme_override_colors/font_color", dim, 0.5
	).set_trans(Tween.TRANS_SINE)


func _stop_confirm_glow() -> void:
	if _confirm_glow_tween != null and _confirm_glow_tween.is_valid():
		_confirm_glow_tween.kill()
		_confirm_glow_tween = null
	if _btn_next != null:
		_btn_next.add_theme_color_override("font_color", C_BTN_TEXT)


# ── Confirm & Seed ────────────────────────────────────────────────────────────

func _try_confirm_seed() -> void:
	if _selected_seed_npc.is_empty():
		_flash_status("Select a seed target first.")
		return
	if _intel_store_ref == null or _intel_store_ref.whisper_tokens_remaining <= 0:
		_flash_status("No Whisper Tokens remaining. Wait until dawn.")
		return
	if _world_ref == null:
		return

	var rumor_id: String = _world_ref.seed_rumor_from_player(
		_selected_subject,
		_selected_claim_id,
		_selected_seed_npc,
		_selected_evidence_item
	)

	if rumor_id.is_empty():
		_flash_status("Failed to seed rumor. Check subject / claim / target.")
		AudioManager.on_rumor_fail()
		return

	if _selected_evidence_item != null and _intel_store_ref != null:
		_intel_store_ref.consume_evidence(_selected_evidence_item)
		if _analytics_manager != null:
			_analytics_manager.log_evidence_used(
				_selected_evidence_item.type.to_lower().replace(" ", "_"),
				_selected_claim_id,
				_get_npc_name(_selected_seed_npc),
				_get_npc_name(_selected_subject)
			)

	var subj_name := _get_npc_name(_selected_subject)
	var seed_name := _get_npc_name(_selected_seed_npc)

	emit_signal("rumor_seeded", rumor_id, subj_name, _selected_claim_id, seed_name)

	_selected_subject       = ""
	_selected_claim_id      = ""
	_selected_seed_npc      = ""
	_confirm_pending        = false
	_selected_evidence_item = null
	toggle()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_nav_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size      = Vector2(140, 32)
	btn.clip_text                = true
	btn.text_overrun_behavior    = TextServer.OVERRUN_TRIM_ELLIPSIS
	var normal := StyleBoxFlat.new()
	normal.bg_color     = C_BTN_NORMAL_BG
	normal.border_color = C_BTN_BORDER
	normal.set_border_width_all(1)
	normal.set_content_margin_all(6)
	var hover := StyleBoxFlat.new()
	hover.bg_color     = C_BTN_HOVER_BG
	hover.border_color = C_GOLD_BRIGHT
	hover.set_border_width_all(1)
	hover.set_content_margin_all(6)
	var focus := StyleBoxFlat.new()
	focus.bg_color     = C_BTN_HOVER_BG
	focus.border_color = C_FOCUS_RING
	focus.set_border_width_all(2)
	focus.set_content_margin_all(6)
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color     = Color(0.20, 0.12, 0.04, 1.0)
	pressed_style.border_color = C_GOLD_BRIGHT
	pressed_style.set_border_width_all(2)
	pressed_style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("focus",   focus)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func() -> void: AudioManager.play_ui("click"))
	btn.mouse_entered.connect(func() -> void: AudioManager.play_sfx_pitched("ui_click", 2.0))
	return btn


func _get_npc_faction(npc_id: String) -> String:
	if _world_ref == null:
		return ""
	for npc in _world_ref.npcs:
		if npc.npc_data.get("id", "") == npc_id:
			return npc.npc_data.get("faction", "")
	return ""


func _get_npc_name(npc_id: String) -> String:
	if _world_ref == null:
		return npc_id
	for npc in _world_ref.npcs:
		if npc.npc_data.get("id", "") == npc_id:
			return npc.npc_data.get("name", npc_id)
	return npc_id


# ── Spread prediction overlay ─────────────────────────────────────────────────

func _init_spread_overlay() -> void:
	_spread_draw_node = Node2D.new()
	_spread_draw_node.name = "SpreadOverlay"
	add_child(_spread_draw_node)
	_spread_draw_node.draw.connect(_draw_spread_rings)


func _on_seed_hover_enter(npc_id: String) -> void:
	_hover_seed_npc_id = npc_id
	if _spread_draw_node != null:
		_spread_draw_node.queue_redraw()


func _on_seed_hover_exit() -> void:
	_hover_seed_npc_id = ""
	if _spread_draw_node != null:
		_spread_draw_node.queue_redraw()


func _draw_spread_rings() -> void:
	if _world_ref == null or _hover_seed_npc_id.is_empty():
		return
	var vp := get_viewport()
	if vp == null:
		return

	var seed_node: Node2D = null
	for npc in _world_ref.npcs:
		if npc.npc_data.get("id", "") == _hover_seed_npc_id:
			seed_node = npc
			break
	if seed_node == null:
		return

	var ct := vp.get_canvas_transform()
	const SPREAD_RADIUS_OVERLAY := 8

	var seed_screen := ct * seed_node.global_position
	_spread_draw_node.draw_arc(seed_screen, 20.0, 0.0, TAU, 32, C_SPREAD_RING_SEED, 3.0)

	for npc in _world_ref.npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		if npc_id == _hover_seed_npc_id:
			continue
		var dist: int = abs((npc.current_cell as Vector2i).x - (seed_node.current_cell as Vector2i).x) \
		              + abs((npc.current_cell as Vector2i).y - (seed_node.current_cell as Vector2i).y)
		if dist > SPREAD_RADIUS_OVERLAY:
			continue
		var soc: float = float(npc.npc_data.get("sociability", 0.5))
		var ring_color: Color
		if soc >= 0.7:
			ring_color = C_SPREAD_HIGH
		elif soc >= 0.4:
			ring_color = C_SPREAD_MED
		else:
			ring_color = C_SPREAD_LOW
		var npc_screen: Vector2 = ct * npc.global_position
		_spread_draw_node.draw_arc(npc_screen, 15.0, 0.0, TAU, 24, ring_color, 2.0)
