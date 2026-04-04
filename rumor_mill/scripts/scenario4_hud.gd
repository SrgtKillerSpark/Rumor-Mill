extends CanvasLayer

## scenario4_hud.gd — Persistent triple-track reputation defence display.
##
## Shows a thin header tracking the three protected NPCs' reputation scores
## against the Scenario 4 fail threshold (30) and win floor (50).
##
## Layout:
##   Scenario 4: The Holy Inquisition
##   [Aldous Prior]   Rep: 60 / 100   Floor: 50  [bar]
##   [Vera Midwife]   Rep: 55 / 100   Floor: 50  [bar]
##   [Finn Monk]      Rep: 50 / 100   Floor: 50  [bar]
##   Days remaining: 20       Inquisitor: no activity yet
##
## Wire via setup(world, day_night) from main.gd.

# ── Palette (matches journal.gd / scenario3_hud.gd) ─────────────────────────
const C_PANEL_BG   := Color(0.15, 0.10, 0.08, 0.88)
const C_HEADING    := Color(0.91, 0.85, 0.70, 1.0)
const C_BODY       := Color(0.75, 0.70, 0.60, 1.0)
const C_WIN        := Color(0.10, 0.75, 0.22, 1.0)
const C_FAIL       := Color(0.85, 0.15, 0.15, 1.0)
const C_NEUTRAL    := Color(0.85, 0.55, 0.10, 1.0)
const C_DEFEND     := Color(0.50, 0.80, 1.00, 1.0)  # sky blue for defending

const BAR_WIDTH  := 100
const BAR_HEIGHT := 8

const NPC_DISPLAY_NAMES := {
	"aldous_prior": "Aldous Prior",
	"vera_midwife": "Vera Midwife",
	"finn_monk":    "Finn Monk",
}

# ── Node refs ────────────────────────────────────────────────────────────────
var _panel:          Panel = null
var _score_labels:   Dictionary = {}  # npc_id -> Label
var _bars:           Dictionary = {}  # npc_id -> ColorRect (fill)
var _bar_bgs:        Dictionary = {}  # npc_id -> ColorRect (background)
var _days_lbl:       Label = null
var _result_lbl:     Label = null
var _inquisitor_lbl: Label = null

var _world_ref:     Node2D = null
var _day_night_ref: Node   = null


func _ready() -> void:
	layer = 14
	_build_ui()
	visible = false


func setup(world: Node2D, day_night: Node) -> void:
	_world_ref     = world
	_day_night_ref = day_night
	visible = true
	if day_night != null:
		day_night.game_tick.connect(_on_game_tick)
	if world != null and "scenario_manager" in world and world.scenario_manager != null:
		world.scenario_manager.scenario_resolved.connect(_on_scenario_resolved)
	var inquisitor = world.get("inquisitor_agent") if world != null else null
	if inquisitor != null:
		inquisitor.inquisitor_acted.connect(notify_inquisitor_acted)
	_refresh()


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "Scenario4Panel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_PANEL_BG
	panel_style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.custom_minimum_size = Vector2(0, 78)
	_panel.offset_top    = 4
	_panel.offset_bottom = 82
	_panel.offset_left   = 8
	_panel.offset_right  = -8
	add_child(_panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(hbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 4:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	hbox.add_child(title_lbl)

	# NPC tracks
	for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(vbox)

		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", C_BODY)
		lbl.text = "%s  Rep: 50 / 100  Floor: 50" % NPC_DISPLAY_NAMES.get(npc_id, npc_id)
		vbox.add_child(lbl)
		_score_labels[npc_id] = lbl

		var bar_bg := ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
		bar_bg.color = Color(0.25, 0.25, 0.25)
		vbox.add_child(bar_bg)
		_bar_bgs[npc_id] = bar_bg

		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
		bar.color = C_NEUTRAL
		bar_bg.add_child(bar)
		_bars[npc_id] = bar

	# Right column: days + result + inquisitor
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 12)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 20"
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 14)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	right_vbox.add_child(_result_lbl)

	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 11)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "[safe] > 50  [risk] 30-50  [danger] < 30"
	right_vbox.add_child(legend_lbl)

	_inquisitor_lbl = Label.new()
	_inquisitor_lbl.add_theme_font_size_override("font_size", 12)
	_inquisitor_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45, 0.80))
	_inquisitor_lbl.text = "Inquisitor: no activity yet"
	right_vbox.add_child(_inquisitor_lbl)


# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _world_ref == null:
		return
	if not ("reputation_system" in _world_ref) or _world_ref.reputation_system == null:
		return
	if not ("scenario_manager" in _world_ref) or _world_ref.scenario_manager == null:
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var sm:  ScenarioManager  = _world_ref.scenario_manager
	var progress: Dictionary  = sm.get_scenario_4_progress(rep)
	var scores: Dictionary    = progress["protected_scores"]
	var win_thr: int          = progress["win_threshold"]
	var fail_thr: int         = progress["fail_threshold"]
	var state                 = progress["state"]

	for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
		var score: int = scores.get(npc_id, 50)
		var display_name: String = NPC_DISPLAY_NAMES.get(npc_id, npc_id)

		if _score_labels.has(npc_id):
			_score_labels[npc_id].text = "%s  Rep: %d / 100  Floor: %d" % [display_name, score, win_thr]

		if _bars.has(npc_id):
			var ratio: float = clamp(float(score) / 100.0, 0.0, 1.0)
			_bars[npc_id].custom_minimum_size.x = BAR_WIDTH * ratio
			if score >= win_thr:
				_bars[npc_id].color = C_WIN
			elif score >= fail_thr:
				_bars[npc_id].color = C_NEUTRAL
			else:
				_bars[npc_id].color = C_FAIL

	# Days remaining.
	var days_elapsed: int = (_day_night_ref.current_day - 1) if _day_night_ref != null else 0
	var days_allowed: int = sm.get_days_allowed() if sm != null else 20
	_days_lbl.text = "Days remaining: %d" % max(0, days_allowed - days_elapsed)

	match state:
		ScenarioManager.ScenarioState.WON:
			_result_lbl.text = "VICTORY — The accused are safe"
			_result_lbl.add_theme_color_override("font_color", C_WIN)
		ScenarioManager.ScenarioState.FAILED:
			_result_lbl.text = "FAILED — The inquisitor prevails"
			_result_lbl.add_theme_color_override("font_color", C_FAIL)
		_:
			_result_lbl.text = ""


# ── Inquisitor activity ──────────────────────────────────────────────────────

func notify_inquisitor_acted(day: int, claim_type: String, subject_id: String) -> void:
	if _inquisitor_lbl == null:
		return
	var subject_display := NPC_DISPLAY_NAMES.get(subject_id, subject_id.replace("_", " ").capitalize())
	_inquisitor_lbl.text = "Inquisitor: Day %d — %s on %s" % [day, claim_type.capitalize(), subject_display]
	_inquisitor_lbl.add_theme_color_override("font_color", Color(1.0, 0.30, 0.15, 1.0))
	var tween := create_tween()
	tween.tween_property(_inquisitor_lbl, "modulate:a", 0.25, 0.12)
	tween.tween_property(_inquisitor_lbl, "modulate:a", 1.0, 0.30)


# ── Signals ──────────────────────────────────────────────────────────────────

func _on_game_tick(_tick: int) -> void:
	_refresh()


func _on_scenario_resolved(scenario_id: int, _state: ScenarioManager.ScenarioState) -> void:
	if scenario_id != 4:
		return
	_refresh()
	if _result_lbl != null:
		var tween := create_tween()
		tween.tween_property(_result_lbl, "modulate:a", 0.0, 0.3).set_delay(1.5)
		tween.tween_property(_result_lbl, "modulate:a", 1.0, 0.2)
