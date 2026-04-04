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

signal rumor_seeded(rumor_id: String, subject_name: String, claim_id: String, seed_target_name: String)
signal evidence_first_shown
## Emitted the first time the player reaches the Seed Target panel (panel 3).
## Used by the tutorial hint system to trigger HINT-07 (hint_seed_target).
signal panel_seed_shown

# Panel index constants.
const PANEL_SUBJECT   := 0
const PANEL_CLAIM     := 1
const PANEL_SEED      := 2

# Scene nodes (from RumorPanel.tscn).
@onready var panel:       Panel         = $Panel
@onready var title_label: Label         = $Panel/VBox/TitleLabel
@onready var hint_label:  Label         = $Panel/VBox/HintLabel

# The Scroll + NPCList from the .tscn are Panel 1's content container.
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
var _btn_next:     Button          = null   # becomes "Confirm & Seed" on panel 3
var _status_label: Label           = null   # inline feedback for panel 3

# References.
var _world_ref:       Node2D           = null
var _intel_store_ref: PlayerIntelStore = null

# Crafting state.
var _current_panel:        int    = PANEL_SUBJECT
var _selected_subject:     String = ""  # npc_id
var _selected_claim_id:    String = ""  # claims.json id
var _selected_seed_npc:    String = ""  # npc_id
var _confirm_pending:      bool   = false  # true after first "Confirm & Seed" press
var _selected_evidence_item               = null  # PlayerIntelStore.EvidenceItem or null
var _evidence_tutorial_fired: bool        = false
var _panel_seed_shown_fired:  bool        = false  # guard for panel_seed_shown signal

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
	"Select the NPC this rumor will be about.  R to close.",
	"Choose what kind of rumor to spread.  ← Back to change subject.",
	"Choose who to whisper to.  ← Back to change claim.  Confirm uses 1 Whisper Token.",
]


func _ready() -> void:
	layer = 15
	panel.visible = false
	_build_dynamic_panels()
	_init_spread_overlay()


func setup(world: Node2D, intel_store: PlayerIntelStore) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store


func toggle() -> void:
	if panel.visible:
		AudioManager.play_sfx("rumor_panel_close")
		panel.visible = false
		_on_seed_hover_exit()
	else:
		AudioManager.play_sfx("rumor_panel_open")
		_open_panel(PANEL_SUBJECT)
		panel.visible = true
		# Set keyboard focus on the Back/Next nav buttons when panel opens.
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

	# Whisper Token bar (shown only on panel 3, hidden otherwise).
	_whisper_bar = Label.new()
	_whisper_bar.add_theme_font_size_override("font_size", 12)
	_whisper_bar.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20, 1.0))
	_whisper_bar.visible = false
	vbox.add_child(_whisper_bar)

	# ── Panel 2: Claim selection ─────────────────────────────────────────────
	_p2_scroll = ScrollContainer.new()
	_p2_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_p2_scroll.visible = false
	_claim_list = VBoxContainer.new()
	_claim_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p2_scroll.add_child(_claim_list)
	vbox.add_child(_p2_scroll)

	# ── Panel 3: Seed target selection ──────────────────────────────────────
	_p3_scroll = ScrollContainer.new()
	_p3_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_p3_scroll.visible = false
	_seed_list = VBoxContainer.new()
	_seed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p3_scroll.add_child(_seed_list)
	vbox.add_child(_p3_scroll)

	# ── Status label (feedback on panel 3) ──────────────────────────────────
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2, 1.0))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.visible = false
	vbox.add_child(_status_label)

	# ── Navigation row ───────────────────────────────────────────────────────
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

	# Show / hide content areas.
	_p1_scroll.visible = (idx == PANEL_SUBJECT)
	_p2_scroll.visible = (idx == PANEL_CLAIM)
	_p3_scroll.visible = (idx == PANEL_SEED)

	# Whisper bar only on Panel 3.
	_whisper_bar.visible = (idx == PANEL_SEED)

	# Back button: hidden on panel 1.
	_btn_back.visible = (idx != PANEL_SUBJECT)

	# Next/Confirm button.  Reset confirmation state on any panel change.
	_confirm_pending  = false
	_btn_next.visible = true
	if idx == PANEL_SEED:
		_btn_next.text = "Confirm & Seed"
		if not _panel_seed_shown_fired:
			_panel_seed_shown_fired = true
			panel_seed_shown.emit()
	else:
		_btn_next.text = "Next →"

	# Status label only relevant on panel 3.
	_status_label.visible = false

	# Rebuild the appropriate list.
	match idx:
		PANEL_SUBJECT:
			_rebuild_subject_list()
		PANEL_CLAIM:
			_rebuild_claim_list()
		PANEL_SEED:
			_rebuild_seed_list()

	# Grab keyboard focus on the primary nav button for the active panel.
	if idx == PANEL_SUBJECT:
		if _btn_next != null:
			_btn_next.call_deferred("grab_focus")
	else:
		if _btn_back != null:
			_btn_back.call_deferred("grab_focus")


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
				# First press — validate selection and show a summary for review.
				if _selected_seed_npc.is_empty():
					_flash_status("Select a seed target first.")
					return
				var tokens: int = _intel_store_ref.whisper_tokens_remaining if _intel_store_ref != null else 0
				var subj_name := _get_npc_name(_selected_subject)
				var seed_name := _get_npc_name(_selected_seed_npc)
				_flash_status(
					"Seed [%s] about %s → whisper to %s?\nWhisper tokens remaining: %d.\nClick 'Confirm & Seed' once more to proceed." % [
						_selected_claim_id, subj_name, seed_name, tokens
					]
				)
				_confirm_pending  = true
				_btn_next.text    = "Confirm & Seed ✓"
			else:
				_try_confirm_seed()


func _flash_status(msg: String) -> void:
	_status_label.text = msg
	_status_label.visible = true


# ── Panel 1: Subject list ─────────────────────────────────────────────────────

func _rebuild_subject_list() -> void:
	for child in _npc_list.get_children():
		child.queue_free()

	if _world_ref == null or _intel_store_ref == null:
		return

	for npc in _world_ref.npcs:
		var npc_id:   String = npc.npc_data.get("id",      "")
		var npc_name: String = npc.npc_data.get("name",    "")
		var faction:  String = npc.npc_data.get("faction", "")
		var rels: Array = _intel_store_ref.get_relationships_for_npc(npc_id)

		var entry := _build_subject_entry(npc_id, npc_name, faction, rels)
		_npc_list.add_child(entry)


func _build_subject_entry(
		npc_id:   String,
		npc_name: String,
		faction:  String,
		rels:     Array
) -> Control:
	var outer := PanelContainer.new()

	# Highlight if selected.
	if npc_id == _selected_subject:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.20, 0.45, 0.20, 0.55)
		outer.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	outer.add_child(vbox)

	# Header row.
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = _faction_color(faction)
	header.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = "  " + npc_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.80, 0.60, 1.0))
	header.add_child(name_lbl)

	var faction_lbl := Label.new()
	faction_lbl.text = "  [" + faction.capitalize() + "]"
	faction_lbl.add_theme_font_size_override("font_size", 12)
	faction_lbl.add_theme_color_override("font_color", _faction_color(faction))
	header.add_child(faction_lbl)

	# Relationship rows.
	if rels.is_empty():
		var lock_lbl := Label.new()
		lock_lbl.text = "    🔒 Relationship: Unknown"
		lock_lbl.add_theme_font_size_override("font_size", 12)
		lock_lbl.add_theme_color_override("font_color", Color(0.42, 0.38, 0.30, 1.0))
		vbox.add_child(lock_lbl)
	else:
		for intel in rels:
			var other_name: String
			if intel.npc_a_id == npc_id:
				other_name = intel.npc_b_name
			else:
				other_name = intel.npc_a_name

			var bar_str := "[" + "*".repeat(intel.bars()) + " ".repeat(3 - intel.bars()) + "]"
			var prefix: String
			var color: Color
			if intel.affinity_label == "suspicious":
				prefix = "    [!] Suspicious of: "
				color  = Color(1.0, 0.40, 0.35, 1.0)
			elif intel.affinity_label == "allied":
				prefix = "    [*] Close with: "
				color  = Color(0.35, 1.0, 0.45, 1.0)
			else:
				prefix = "    [~] Knows: "
				color  = Color(0.95, 0.95, 0.40, 1.0)

			var rel_lbl := Label.new()
			rel_lbl.text = "%s%s  %s (%s)" % [
				prefix, other_name, bar_str, intel.strength_label()
			]
			rel_lbl.add_theme_font_size_override("font_size", 12)
			rel_lbl.add_theme_color_override("font_color", color)
			vbox.add_child(rel_lbl)

	vbox.add_child(HSeparator.new())

	# Select on click.
	var btn := Button.new()
	btn.text = "Select as Subject"
	btn.add_theme_font_size_override("font_size", 12)
	var captured_id := npc_id
	btn.pressed.connect(func():
		_selected_subject = captured_id
		_selected_claim_id = ""  # reset downstream selections
		_selected_seed_npc = ""
		_rebuild_subject_list()
	)
	vbox.add_child(btn)

	return outer


# ── Panel 2: Claim list ───────────────────────────────────────────────────────

func _rebuild_claim_list() -> void:
	for child in _claim_list.get_children():
		child.queue_free()

	if _world_ref == null:
		return

	# Determine subject faction for filtering.
	var subject_faction := _get_npc_faction(_selected_subject)
	var claims: Array = _world_ref.get_claims()

	for claim in claims:
		var target_factions: Array = claim.get("targetFactions", [])
		# Show claim if no faction filter OR subject faction matches.
		if not target_factions.is_empty() and not subject_faction.is_empty():
			if not (subject_faction in target_factions):
				continue

		var entry := _build_claim_entry(claim)
		_claim_list.add_child(entry)


func _build_claim_entry(claim: Dictionary) -> Control:
	var claim_id:  String = claim.get("id",           "?")
	var type_str:  String = claim.get("type",         "?")
	var tmpl_text: String = claim.get("templateText", "")
	var intensity: int    = int(claim.get("intensity",  3))
	var mutability: float = float(claim.get("mutability", 3)) / 5.0

	var outer := PanelContainer.new()

	if claim_id == _selected_claim_id:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.20, 0.35, 0.60, 0.55)
		outer.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	outer.add_child(vbox)

	# Type badge + ID.
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var type_lbl := Label.new()
	type_lbl.text = "[%s]  %s" % [type_str.to_upper(), claim_id]
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", _claim_type_color(type_str))
	header.add_child(type_lbl)

	# Template text (the actual rumor wording).
	var tmpl_lbl := Label.new()
	tmpl_lbl.text = '  "' + tmpl_text + '"'
	tmpl_lbl.add_theme_font_size_override("font_size", 12)
	tmpl_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.80, 1.0))
	tmpl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(tmpl_lbl)

	# Stats row.
	var stats_row := HBoxContainer.new()
	vbox.add_child(stats_row)

	var inten_lbl := Label.new()
	inten_lbl.text = "  Intensity: " + "█".repeat(intensity) + "░".repeat(5 - intensity)
	inten_lbl.add_theme_font_size_override("font_size", 12)
	inten_lbl.add_theme_color_override("font_color", _intensity_color(intensity))
	stats_row.add_child(inten_lbl)

	var mut_bars: int = roundi(mutability * 5.0)
	var mut_lbl  := Label.new()
	mut_lbl.text = "   Mutability: " + "█".repeat(mut_bars) + "░".repeat(5 - mut_bars)
	mut_lbl.add_theme_font_size_override("font_size", 12)
	mut_lbl.add_theme_color_override("font_color", Color(0.60, 0.75, 1.0, 1.0))
	stats_row.add_child(mut_lbl)

	vbox.add_child(HSeparator.new())

	var btn := Button.new()
	btn.text = "Select Claim"
	btn.add_theme_font_size_override("font_size", 12)
	var captured_id := claim_id
	btn.pressed.connect(func():
		_selected_claim_id = captured_id
		_selected_seed_npc = ""
		_selected_evidence_item = null  # new claim may change compatible evidence
		_rebuild_claim_list()
	)
	vbox.add_child(btn)

	return outer


# ── Panel 3: Seed target list ─────────────────────────────────────────────────

func _rebuild_seed_list() -> void:
	for child in _seed_list.get_children():
		child.queue_free()

	if _world_ref == null or _intel_store_ref == null:
		return

	# Update Whisper Token bar.
	var tokens: int = _intel_store_ref.whisper_tokens_remaining
	var max_t:  int = PlayerIntelStore.MAX_DAILY_WHISPERS
	_whisper_bar.text = "Whisper Tokens: %s  (%d/%d)  — replenishes at dawn" % [
		"[W]".repeat(tokens) + "[ ]".repeat(max_t - tokens),
		tokens, max_t
	]

	# Chain indicator — show when seeding would create a rumor chain.
	var chain_info := _detect_current_chain()
	var chain_type: PropagationEngine.ChainType = chain_info.get("chain_type", PropagationEngine.ChainType.NONE)
	if chain_type != PropagationEngine.ChainType.NONE:
		_add_chain_indicator(chain_type)

	# Evidence attachment section — only shown when inventory is non-empty.
	if _intel_store_ref != null and not _intel_store_ref.evidence_inventory.is_empty():
		var claim_type_upper := _get_claim_type_upper(_selected_claim_id)
		var compatible := _intel_store_ref.get_compatible_evidence(claim_type_upper)
		_add_evidence_section(compatible)

	for npc in _world_ref.npcs:
		var npc_id:   String = npc.npc_data.get("id",      "")
		# Cannot seed to the subject themselves.
		if npc_id == _selected_subject:
			continue
		var npc_name: String = npc.npc_data.get("name",    "")
		var faction:  String = npc.npc_data.get("faction", "")

		var entry := _build_seed_entry(npc, npc_id, npc_name, faction)
		_seed_list.add_child(entry)


func _build_seed_entry(
		npc_node: Node2D,
		npc_id:   String,
		npc_name: String,
		faction:  String
) -> Control:
	var outer := PanelContainer.new()

	if npc_id == _selected_seed_npc:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.50, 0.25, 0.10, 0.55)
		outer.add_theme_stylebox_override("panel", style)

	# Spread prediction overlay: hover triggers ring drawing on world map.
	var captured_npc_id := npc_id
	outer.mouse_entered.connect(func() -> void: _on_seed_hover_enter(captured_npc_id))
	outer.mouse_exited.connect(_on_seed_hover_exit)

	var vbox := VBoxContainer.new()
	outer.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = _faction_color(faction)
	header.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = "  " + npc_name + "  [" + faction.capitalize() + "]"
	name_lbl.add_theme_font_size_override("font_size", 12)
	header.add_child(name_lbl)

	# Estimates.
	var spread_est:  float = _estimate_spread(npc_node)
	var belief_est:  float = _estimate_believability(npc_id)

	var est_lbl := Label.new()
	est_lbl.text = "    Spread est: ~%d NPCs   Believability: %d%%" % [
		roundi(spread_est), roundi(belief_est * 100.0)
	]
	est_lbl.add_theme_font_size_override("font_size", 12)
	est_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.65, 1.0))
	vbox.add_child(est_lbl)

	vbox.add_child(HSeparator.new())

	var btn := Button.new()
	btn.text = "Whisper to " + npc_name
	btn.add_theme_font_size_override("font_size", 12)
	var captured_id := npc_id
	btn.pressed.connect(func():
		_selected_seed_npc = captured_id
		_confirm_pending   = false
		_btn_next.text     = "Confirm & Seed"
		_rebuild_seed_list()
	)
	vbox.add_child(btn)

	return outer


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
		return

	# Consume evidence now that seeding succeeded.
	if _selected_evidence_item != null and _intel_store_ref != null:
		_intel_store_ref.consume_evidence(_selected_evidence_item)

	# Resolve names for the signal.
	var subj_name  := _get_npc_name(_selected_subject)
	var seed_name  := _get_npc_name(_selected_seed_npc)

	emit_signal("rumor_seeded", rumor_id, subj_name, _selected_claim_id, seed_name)

	# Reset state and close the panel.
	_selected_subject       = ""
	_selected_claim_id      = ""
	_selected_seed_npc      = ""
	_confirm_pending        = false
	_selected_evidence_item = null
	panel.visible = false

	print("[RumorPanel] Seeded rumor '%s' via %s" % [rumor_id, seed_name])


# ── Estimates ─────────────────────────────────────────────────────────────────

## Rough spread estimate: count of NPCs within the 8-tile spread radius,
## weighted by their average sociability.
func _estimate_spread(seed_npc: Node2D) -> float:
	if _world_ref == null:
		return 0.0
	const SPREAD_RADIUS := 8
	var count: float = 0.0
	for npc in _world_ref.npcs:
		if npc == seed_npc:
			continue
		var dist: int = abs((npc.current_cell as Vector2i).x - (seed_npc.current_cell as Vector2i).x) \
		              + abs((npc.current_cell as Vector2i).y - (seed_npc.current_cell as Vector2i).y)
		if dist <= SPREAD_RADIUS:
			var soc: float = float(npc.npc_data.get("sociability", 0.5))
			count += soc
	return count


## Believability estimate: claim base + same-faction bonus if subject faction == seed faction.
func _estimate_believability(seed_npc_id: String) -> float:
	var claim_intensity: int = 3
	if _world_ref != null:
		for c in _world_ref.get_claims():
			if c.get("id", "") == _selected_claim_id:
				claim_intensity = int(c.get("intensity", 3))
				break

	var base: float = float(claim_intensity) / 5.0

	# Same-faction bonus mirrors NPC credulity logic in npc.gd.
	var subj_faction: String = _get_npc_faction(_selected_subject)
	var seed_faction: String = _get_npc_faction(seed_npc_id)
	if not subj_faction.is_empty() and subj_faction == seed_faction:
		base += 0.15

	return clampf(base, 0.0, 1.0)


# ── Evidence helpers ──────────────────────────────────────────────────────────

## Returns the claim type string (upper-case) for the given claim_id, or "".
func _get_claim_type_upper(claim_id: String) -> String:
	if _world_ref == null:
		return ""
	for c in _world_ref.get_claims():
		if c.get("id", "") == claim_id:
			return c.get("type", "").to_upper()
	return ""


## Detect whether the current subject + claim selection would form a rumor chain.
func _detect_current_chain() -> Dictionary:
	if _world_ref == null or _world_ref.propagation_engine == null:
		return { "chain_type": PropagationEngine.ChainType.NONE, "existing_rumor": null }
	if _selected_subject.is_empty() or _selected_claim_id.is_empty():
		return { "chain_type": PropagationEngine.ChainType.NONE, "existing_rumor": null }
	var claim_type := Rumor.claim_type_from_string(_get_claim_type_upper(_selected_claim_id).to_lower())
	return _world_ref.propagation_engine.detect_chain(_selected_subject, claim_type)


## Builds the chain indicator banner at the top of Panel 3's seed list.
func _add_chain_indicator(chain_type: PropagationEngine.ChainType) -> void:
	var banner := PanelContainer.new()
	var style := StyleBoxFlat.new()
	match chain_type:
		PropagationEngine.ChainType.SAME_TYPE:
			style.bg_color = Color(0.20, 0.45, 0.70, 0.50)
		PropagationEngine.ChainType.ESCALATION:
			style.bg_color = Color(0.55, 0.20, 0.60, 0.50)
		PropagationEngine.ChainType.CONTRADICTION:
			style.bg_color = Color(0.70, 0.35, 0.15, 0.50)
	style.set_corner_radius_all(4)
	banner.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	banner.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = " [CHAIN] "
	icon_lbl.add_theme_font_size_override("font_size", 13)
	icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	hbox.add_child(icon_lbl)

	var desc_lbl := Label.new()
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85, 1.0))
	match chain_type:
		PropagationEngine.ChainType.SAME_TYPE:
			desc_lbl.text = "Same-Type Chain: +15% believability, +1 intensity"
		PropagationEngine.ChainType.ESCALATION:
			desc_lbl.text = "Escalation Chain: +25% believability, -50% mutation"
		PropagationEngine.ChainType.CONTRADICTION:
			desc_lbl.text = "Contradiction Chain: faster CONTRADICTED, -10% believability"
	hbox.add_child(desc_lbl)

	_seed_list.add_child(banner)


## Builds and inserts the evidence attachment sub-section at the top of _seed_list.
func _add_evidence_section(compatible: Array) -> void:
	var hdr := Label.new()
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20, 1.0))
	if compatible.is_empty():
		hdr.text = "  [Evidence] No compatible evidence for this claim type."
		_seed_list.add_child(hdr)
		_seed_list.add_child(HSeparator.new())
		return

	hdr.text = "  [Evidence] Attach evidence to boost this rumor (optional):"
	_seed_list.add_child(hdr)

	# Fire evidence tutorial once the player first sees usable evidence items.
	if not _evidence_tutorial_fired:
		_evidence_tutorial_fired = true
		evidence_first_shown.emit()

	# When evidence is already attached, show a compact summary under the header.
	if _selected_evidence_item != null:
		var attached_lbl := Label.new()
		attached_lbl.add_theme_font_size_override("font_size", 12)
		attached_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 0.50, 1.0))
		var bonus_str := ""
		if _selected_evidence_item.believability_bonus != 0.0:
			bonus_str = "  +%d%% Belief" % roundi(_selected_evidence_item.believability_bonus * 100.0)
		attached_lbl.text = "  ✓ Attached: %s%s" % [_selected_evidence_item.type, bonus_str]
		_seed_list.add_child(attached_lbl)

	for item in compatible:
		_seed_list.add_child(_build_evidence_entry(item))

	if _selected_evidence_item != null:
		var clear_btn := Button.new()
		clear_btn.text = "Remove Evidence"
		clear_btn.add_theme_font_size_override("font_size", 12)
		clear_btn.pressed.connect(func() -> void:
			_selected_evidence_item = null
			_confirm_pending = false
			_btn_next.text   = "Confirm & Seed"
			_rebuild_seed_list()
		)
		_seed_list.add_child(clear_btn)

	_seed_list.add_child(HSeparator.new())


func _build_evidence_entry(item) -> Control:
	var outer := PanelContainer.new()
	if item == _selected_evidence_item:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.45, 0.30, 0.05, 0.55)
		outer.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	outer.add_child(vbox)

	# Type + bonus text.
	var bonus_parts: Array = []
	if item.believability_bonus != 0.0:
		bonus_parts.append("Believability +%.2f" % item.believability_bonus)
	if item.mutability_modifier != 0.0:
		var sign_str: String = "+" if item.mutability_modifier >= 0.0 else ""
		bonus_parts.append("Mutability %s%.2f" % [sign_str, item.mutability_modifier])
	var type_lbl := Label.new()
	type_lbl.text = "  %s — %s" % [item.type, "  |  ".join(bonus_parts)]
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.50, 1.0))
	vbox.add_child(type_lbl)

	# Visual boost bar — scale 0.0–0.25 bonus onto 1–5 bars.
	if item.believability_bonus > 0.0:
		var boost_bars: int = clampi(roundi(item.believability_bonus * 20.0), 1, 5)
		var bar_lbl := Label.new()
		bar_lbl.text = "    Boost: " + "▇".repeat(boost_bars) + "░".repeat(5 - boost_bars)
		bar_lbl.add_theme_font_size_override("font_size", 12)
		bar_lbl.add_theme_color_override("font_color", Color(0.35, 0.88, 0.52, 1.0))
		vbox.add_child(bar_lbl)

	# Compatible claim types hint.
	if not item.compatible_claims.is_empty():
		var compat_lbl := Label.new()
		compat_lbl.text = "    Works with: " + ", ".join(item.compatible_claims)
		compat_lbl.add_theme_font_size_override("font_size", 12)
		compat_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.58, 0.90))
		vbox.add_child(compat_lbl)

	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 12)
	if item == _selected_evidence_item:
		btn.text = "✓ Attached"
	else:
		btn.text = "Attach"
	var captured_item = item
	btn.pressed.connect(func() -> void:
		_selected_evidence_item = captured_item
		_confirm_pending = false
		_btn_next.text   = "Confirm & Seed"
		_rebuild_seed_list()
	)
	vbox.add_child(btn)

	return outer


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_nav_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(100, 32)
	var normal := StyleBoxFlat.new()
	normal.bg_color     = Color(0.35, 0.22, 0.08, 1.0)
	normal.border_color = Color(0.55, 0.38, 0.18, 1.0)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(6)
	var hover := StyleBoxFlat.new()
	hover.bg_color     = Color(0.55, 0.35, 0.12, 1.0)
	hover.border_color = Color(0.92, 0.78, 0.12, 1.0)
	hover.set_border_width_all(1)
	hover.set_content_margin_all(6)
	var focus := StyleBoxFlat.new()
	focus.bg_color     = Color(0.55, 0.35, 0.12, 1.0)
	focus.border_color = Color(1.00, 0.90, 0.40, 1.0)  # bright gold focus ring
	focus.set_border_width_all(2)
	focus.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover",  hover)
	btn.add_theme_stylebox_override("focus",  focus)
	btn.add_theme_color_override("font_color", Color(0.92, 0.82, 0.60, 1.0))
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
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


static func _faction_color(faction: String) -> Color:
	match faction:
		"merchant": return Color(1.0, 0.80, 0.20, 1.0)
		"noble":    return Color(0.40, 0.60, 1.0,  1.0)
		"clergy":   return Color(0.90, 0.90, 0.90, 1.0)
		_:          return Color.WHITE


static func _claim_type_color(type_str: String) -> Color:
	match type_str.to_lower():
		"accusation": return Color(1.0,  0.35, 0.25, 1.0)
		"scandal":    return Color(1.0,  0.70, 0.10, 1.0)
		"illness":    return Color(0.60, 1.0,  0.55, 1.0)
		"prophecy":   return Color(0.70, 0.55, 1.0,  1.0)
		"praise":     return Color(0.40, 0.85, 1.0,  1.0)
		"death":      return Color(0.55, 0.55, 0.55, 1.0)
		"heresy":     return Color(1.0,  0.45, 0.85, 1.0)
		_:            return Color.WHITE


static func _intensity_color(intensity: int) -> Color:
	match intensity:
		1, 2: return Color(0.55, 1.0, 0.55, 1.0)
		3:    return Color(1.0,  0.85, 0.30, 1.0)
		4, 5: return Color(1.0,  0.35, 0.25, 1.0)
		_:    return Color.WHITE


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

	# Find the hovered seed NPC node.
	var seed_node: Node2D = null
	for npc in _world_ref.npcs:
		if npc.npc_data.get("id", "") == _hover_seed_npc_id:
			seed_node = npc
			break
	if seed_node == null:
		return

	var ct := vp.get_canvas_transform()
	const SPREAD_RADIUS_OVERLAY := 8  # matches _estimate_spread

	# White ring on the seed NPC (initial whisper target).
	var seed_screen := ct * seed_node.global_position
	_spread_draw_node.draw_arc(seed_screen, 20.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.90), 3.0)

	# Rings on NPCs within SPREAD_RADIUS, colored by sociability (spread likelihood).
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
			ring_color = Color(1.0, 0.35, 0.15, 0.85)   # high — orange/red
		elif soc >= 0.4:
			ring_color = Color(1.0, 0.80, 0.15, 0.80)   # medium — yellow
		else:
			ring_color = Color(0.30, 0.90, 0.30, 0.75)  # low — green
		var npc_screen: Vector2 = ct * npc.global_position
		_spread_draw_node.draw_arc(npc_screen, 15.0, 0.0, TAU, 24, ring_color, 2.0)
