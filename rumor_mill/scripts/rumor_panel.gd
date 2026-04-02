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
var _current_panel:     int    = PANEL_SUBJECT
var _selected_subject:  String = ""  # npc_id
var _selected_claim_id: String = ""  # claims.json id
var _selected_seed_npc: String = ""  # npc_id
var _confirm_pending:   bool   = false  # true after first "Confirm & Seed" press

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


func setup(world: Node2D, intel_store: PlayerIntelStore) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store


func toggle() -> void:
	if panel.visible:
		panel.visible = false
	else:
		_open_panel(PANEL_SUBJECT)
		panel.visible = true


# ── Dynamic panel construction ────────────────────────────────────────────────

func _build_dynamic_panels() -> void:
	var vbox: VBoxContainer = $Panel/VBox

	# Whisper Token bar (shown only on panel 3, hidden otherwise).
	_whisper_bar = Label.new()
	_whisper_bar.add_theme_font_size_override("font_size", 11)
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
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2, 1.0))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.visible = false
	vbox.add_child(_status_label)

	# ── Navigation row ───────────────────────────────────────────────────────
	_nav_row = HBoxContainer.new()
	_btn_back = Button.new()
	_btn_back.text = "← Back"
	_btn_back.visible = false
	_btn_back.pressed.connect(_on_back_pressed)
	_nav_row.add_child(_btn_back)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nav_row.add_child(spacer)

	_btn_next = Button.new()
	_btn_next.text = "Next →"
	_btn_next.visible = false
	_btn_next.pressed.connect(_on_next_pressed)
	_nav_row.add_child(_btn_next)

	vbox.add_child(_nav_row)


# ── Panel switching ───────────────────────────────────────────────────────────

func _open_panel(idx: int) -> void:
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
	name_lbl.add_theme_font_size_override("font_size", 11)
	header.add_child(name_lbl)

	var faction_lbl := Label.new()
	faction_lbl.text = "  [" + faction.capitalize() + "]"
	faction_lbl.add_theme_font_size_override("font_size", 10)
	faction_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))
	header.add_child(faction_lbl)

	# Relationship rows.
	if rels.is_empty():
		var lock_lbl := Label.new()
		lock_lbl.text = "    [Lock] Relationship: Unknown"
		lock_lbl.add_theme_font_size_override("font_size", 10)
		lock_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 1.0))
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
			rel_lbl.add_theme_font_size_override("font_size", 10)
			rel_lbl.add_theme_color_override("font_color", color)
			vbox.add_child(rel_lbl)

	vbox.add_child(HSeparator.new())

	# Select on click.
	var btn := Button.new()
	btn.text = "Select as Subject"
	btn.add_theme_font_size_override("font_size", 10)
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
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", _claim_type_color(type_str))
	header.add_child(type_lbl)

	# Template text (the actual rumor wording).
	var tmpl_lbl := Label.new()
	tmpl_lbl.text = '  "' + tmpl_text + '"'
	tmpl_lbl.add_theme_font_size_override("font_size", 10)
	tmpl_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.80, 1.0))
	tmpl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(tmpl_lbl)

	# Stats row.
	var stats_row := HBoxContainer.new()
	vbox.add_child(stats_row)

	var inten_lbl := Label.new()
	inten_lbl.text = "  Intensity: " + "█".repeat(intensity) + "░".repeat(5 - intensity)
	inten_lbl.add_theme_font_size_override("font_size", 10)
	inten_lbl.add_theme_color_override("font_color", _intensity_color(intensity))
	stats_row.add_child(inten_lbl)

	var mut_bars: int = roundi(mutability * 5.0)
	var mut_lbl  := Label.new()
	mut_lbl.text = "   Mutability: " + "█".repeat(mut_bars) + "░".repeat(5 - mut_bars)
	mut_lbl.add_theme_font_size_override("font_size", 10)
	mut_lbl.add_theme_color_override("font_color", Color(0.60, 0.75, 1.0, 1.0))
	stats_row.add_child(mut_lbl)

	vbox.add_child(HSeparator.new())

	var btn := Button.new()
	btn.text = "Select Claim"
	btn.add_theme_font_size_override("font_size", 10)
	var captured_id := claim_id
	btn.pressed.connect(func():
		_selected_claim_id = captured_id
		_selected_seed_npc = ""
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
	name_lbl.add_theme_font_size_override("font_size", 11)
	header.add_child(name_lbl)

	# Estimates.
	var spread_est:  float = _estimate_spread(npc_node)
	var belief_est:  float = _estimate_believability(npc_id)

	var est_lbl := Label.new()
	est_lbl.text = "    Spread est: ~%d NPCs   Believability: %d%%" % [
		roundi(spread_est), roundi(belief_est * 100.0)
	]
	est_lbl.add_theme_font_size_override("font_size", 10)
	est_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.65, 1.0))
	vbox.add_child(est_lbl)

	vbox.add_child(HSeparator.new())

	var btn := Button.new()
	btn.text = "Whisper to " + npc_name
	btn.add_theme_font_size_override("font_size", 10)
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
		_selected_seed_npc
	)

	if rumor_id.is_empty():
		_flash_status("Failed to seed rumor. Check subject / claim / target.")
		return

	# Resolve names for the signal.
	var subj_name  := _get_npc_name(_selected_subject)
	var seed_name  := _get_npc_name(_selected_seed_npc)

	emit_signal("rumor_seeded", rumor_id, subj_name, _selected_claim_id, seed_name)

	# Reset state and close the panel.
	_selected_subject  = ""
	_selected_claim_id = ""
	_selected_seed_npc = ""
	_confirm_pending   = false
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
		var dist := abs(npc.current_cell.x - seed_npc.current_cell.x) \
		          + abs(npc.current_cell.y - seed_npc.current_cell.y)
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


# ── Helpers ───────────────────────────────────────────────────────────────────

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
