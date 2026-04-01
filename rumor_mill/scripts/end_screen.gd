extends CanvasLayer

## end_screen.gd — Sprint 6 end screen overlay.
##
## Shown when ScenarioManager emits scenario_resolved (win or fail).
## Displays:
##   1. Win / Fail banner
##   2. Scenario narrative text (victoryText or failText from scenarios.json)
##   3. Reputation results — final scores for every key NPC
##   4. Propagation replay summary — rumors seeded, mutations, lineage depth
##   5. Play Again / Quit buttons
##
## Procedurally built CanvasLayer (layer 30 — above all other HUDs).
## Wire via setup(world, day_night) from main.gd.

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BACKDROP     := Color(0.04, 0.02, 0.02, 0.90)
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_WIN          := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_FAIL         := Color(0.85, 0.18, 0.12, 1.0)   # crimson
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)   # parchment
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_BTN_NORMAL   := Color(0.40, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.60, 0.34, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)
const C_SCORE_WIN    := Color(0.10, 0.78, 0.25, 1.0)
const C_SCORE_FAIL   := Color(0.85, 0.18, 0.12, 1.0)
const C_SCORE_NEU    := Color(0.85, 0.55, 0.10, 1.0)

const PANEL_W := 720
const PANEL_H := 560

# ── Node refs ─────────────────────────────────────────────────────────────────
var _backdrop:       ColorRect    = null
var _panel:          PanelContainer = null
var _result_banner:  Label        = null
var _scenario_title: Label        = null
var _narrative_lbl:  RichTextLabel = null
var _rep_container:  VBoxContainer = null
var _prop_lbl:       RichTextLabel = null
var _btn_again:      Button       = null
var _btn_quit:       Button       = null

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null
var _day_night_ref: Node   = null


func _ready() -> void:
	layer = 30
	_build_ui()
	visible = false


## Wire to world and day_night; subscribe to scenario_resolved.
func setup(world: Node2D, day_night: Node) -> void:
	_world_ref     = world
	_day_night_ref = day_night
	if world != null and "scenario_manager" in world and world.scenario_manager != null:
		world.scenario_manager.scenario_resolved.connect(_on_scenario_resolved)


# ── Signal handler ────────────────────────────────────────────────────────────

func _on_scenario_resolved(scenario_id: int, state: ScenarioManager.ScenarioState) -> void:
	if _world_ref == null:
		return
	var won: bool = (state == ScenarioManager.ScenarioState.WON)
	var sm: ScenarioManager = _world_ref.scenario_manager

	# ── Banner ────────────────────────────────────────────────────────────────
	_result_banner.text = "VICTORY" if won else "DEFEAT"
	_result_banner.add_theme_color_override("font_color", C_WIN if won else C_FAIL)

	# ── Scenario title ────────────────────────────────────────────────────────
	_scenario_title.text = sm.get_title() if sm != null else ""

	# ── Narrative text ────────────────────────────────────────────────────────
	var narrative: String = ""
	if sm != null:
		if won:
			narrative = sm.get_victory_text()
		else:
			# Determine fail reason from scenario state.
			var reason := _infer_fail_reason(scenario_id)
			narrative = sm.get_fail_text(reason)
			if narrative.is_empty():
				narrative = sm.get_fail_text("timeout")
	_narrative_lbl.text = narrative if not narrative.is_empty() \
		else ("Your scheming paid off." if won else "Your scheme unravelled.")

	# ── Reputation results ────────────────────────────────────────────────────
	_populate_reputation_results()

	# ── Propagation replay ────────────────────────────────────────────────────
	_populate_propagation_summary()

	visible = true


## Guess the fail reason for the fail-text lookup.
func _infer_fail_reason(scenario_id: int) -> String:
	if _world_ref == null or _world_ref.scenario_manager == null:
		return "timeout"
	var sm: ScenarioManager = _world_ref.scenario_manager
	if scenario_id == 3:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null:
			var calder := rep.get_snapshot(ScenarioManager.CALDER_FENN_ID)
			if calder != null and calder.score < ScenarioManager.S3_FAIL_CALDER_BELOW:
				return "calder_implicated"
	# Check days elapsed vs allowed.
	if _day_night_ref != null and sm.get_days_allowed() > 0:
		var days_elapsed: int = _day_night_ref.current_day if "current_day" in _day_night_ref else 0
		if days_elapsed >= sm.get_days_allowed():
			return "timeout"
	return "exposed"


## Rebuild the NPC reputation rows.
func _populate_reputation_results() -> void:
	for child in _rep_container.get_children():
		child.queue_free()

	if _world_ref == null or _world_ref.reputation_system == null:
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var snapshots: Dictionary = rep.get_all_snapshots()

	if snapshots.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No reputation data recorded."
		empty_lbl.add_theme_color_override("font_color", C_BODY)
		_rep_container.add_child(empty_lbl)
		return

	# Sort by score ascending for easy reading.
	var entries: Array = []
	for npc_id in snapshots:
		var snap: ReputationSystem.ReputationSnapshot = snapshots[npc_id]
		entries.append({"id": npc_id, "score": snap.score, "label": ReputationSystem.score_label(snap.score)})
	entries.sort_custom(func(a, b): return a["score"] < b["score"])

	for entry in entries:
		var row := HBoxContainer.new()

		var name_lbl := Label.new()
		name_lbl.text = _format_npc_name(entry["id"])
		name_lbl.custom_minimum_size = Vector2(200, 0)
		name_lbl.add_theme_color_override("font_color", C_HEADING)
		row.add_child(name_lbl)

		var score_lbl := Label.new()
		score_lbl.text = "%d  (%s)" % [entry["score"], entry["label"]]
		var col := C_SCORE_WIN if entry["score"] > 70 else \
				   (C_SCORE_FAIL if entry["score"] < 30 else C_SCORE_NEU)
		score_lbl.add_theme_color_override("font_color", col)
		row.add_child(score_lbl)

		_rep_container.add_child(row)


## Populate the propagation summary label.
func _populate_propagation_summary() -> void:
	if _world_ref == null or _world_ref.propagation_engine == null:
		_prop_lbl.text = "No propagation data."
		return

	var engine: PropagationEngine = _world_ref.propagation_engine
	var lineage: Dictionary = engine.lineage

	var total_rumors: int    = lineage.size()
	var mutations: int       = 0
	var max_depth: int       = 0

	# Walk lineage to count mutations and find tree depth.
	for rid in lineage:
		var entry: Dictionary = lineage[rid]
		if entry.get("mutation_type", "original") != "original":
			mutations += 1
		# Trace ancestors to find depth.
		var depth := 0
		var cur_id: String = rid
		var visited: Dictionary = {}
		while true:
			if visited.has(cur_id):
				break
			visited[cur_id] = true
			var cur_entry: Dictionary = lineage.get(cur_id, {})
			var parent: String = cur_entry.get("parent_id", "")
			if parent.is_empty():
				break
			cur_id = parent
			depth += 1
		max_depth = max(max_depth, depth)

	var original_rumors: int = total_rumors - mutations
	var live_count: int      = engine.live_rumors.size()

	_prop_lbl.text = (
		"Rumors seeded by player:  %d\n"
		+ "Mutations generated:       %d\n"
		+ "Max lineage depth:         %d\n"
		+ "Still spreading at end:    %d"
	) % [original_rumors, mutations, max_depth, live_count]


## Convert snake_case NPC id to a presentable name.
static func _format_npc_name(npc_id: String) -> String:
	var parts := npc_id.split("_")
	var out := ""
	for p in parts:
		if p.length() > 0:
			out += p[0].to_upper() + p.substr(1) + " "
	return out.strip_edges()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen dimming backdrop.
	_backdrop = ColorRect.new()
	_backdrop.color = C_BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# Centred panel container.
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.set_anchor(SIDE_LEFT,   0.5)
	_panel.set_anchor(SIDE_RIGHT,  0.5)
	_panel.set_anchor(SIDE_TOP,    0.5)
	_panel.set_anchor(SIDE_BOTTOM, 0.5)
	_panel.set_offset(SIDE_LEFT,   -PANEL_W / 2.0)
	_panel.set_offset(SIDE_RIGHT,   PANEL_W / 2.0)
	_panel.set_offset(SIDE_TOP,    -PANEL_H / 2.0)
	_panel.set_offset(SIDE_BOTTOM,  PANEL_H / 2.0)

	var style := StyleBoxFlat.new()
	style.bg_color           = C_PANEL_BG
	style.border_color       = C_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# ── Victory / Defeat banner ───────────────────────────────────────────────
	_result_banner = Label.new()
	_result_banner.text = "VICTORY"
	_result_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_banner.add_theme_font_size_override("font_size", 36)
	_result_banner.add_theme_color_override("font_color", C_WIN)
	vbox.add_child(_result_banner)

	# ── Scenario title ────────────────────────────────────────────────────────
	_scenario_title = Label.new()
	_scenario_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scenario_title.add_theme_font_size_override("font_size", 16)
	_scenario_title.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(_scenario_title)

	vbox.add_child(_separator())

	# ── Narrative text ────────────────────────────────────────────────────────
	_narrative_lbl = RichTextLabel.new()
	_narrative_lbl.custom_minimum_size = Vector2(0, 60)
	_narrative_lbl.fit_content          = true
	_narrative_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_narrative_lbl.add_theme_color_override("default_color", C_BODY)
	vbox.add_child(_narrative_lbl)

	vbox.add_child(_separator())

	# ── Reputation results ────────────────────────────────────────────────────
	var rep_heading := Label.new()
	rep_heading.text = "Reputation Results"
	rep_heading.add_theme_font_size_override("font_size", 14)
	rep_heading.add_theme_color_override("font_color", C_HEADING)
	vbox.add_child(rep_heading)

	_rep_container = VBoxContainer.new()
	_rep_container.add_theme_constant_override("separation", 3)
	vbox.add_child(_rep_container)

	vbox.add_child(_separator())

	# ── Propagation summary ───────────────────────────────────────────────────
	var prop_heading := Label.new()
	prop_heading.text = "Rumor Propagation"
	prop_heading.add_theme_font_size_override("font_size", 14)
	prop_heading.add_theme_color_override("font_color", C_HEADING)
	vbox.add_child(prop_heading)

	_prop_lbl = RichTextLabel.new()
	_prop_lbl.fit_content  = true
	_prop_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prop_lbl.add_theme_color_override("default_color", C_BODY)
	vbox.add_child(_prop_lbl)

	vbox.add_child(_separator())

	# ── Buttons ───────────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	_btn_again = _make_button("Play Again")
	_btn_again.pressed.connect(_on_play_again)
	btn_row.add_child(_btn_again)

	_btn_quit = _make_button("Quit")
	_btn_quit.pressed.connect(_on_quit)
	btn_row.add_child(_btn_quit)


func _separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_PANEL_BORDER
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep


func _make_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(140, 40)

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN_NORMAL
	normal.set_border_width_all(1)
	normal.border_color = C_PANEL_BORDER
	normal.set_content_margin_all(8)

	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_HOVER
	hover.set_border_width_all(1)
	hover.border_color = C_PANEL_BORDER
	hover.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover",  hover)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	return btn


# ── Button handlers ───────────────────────────────────────────────────────────

func _on_play_again() -> void:
	get_tree().reload_current_scene()


func _on_quit() -> void:
	get_tree().quit()
