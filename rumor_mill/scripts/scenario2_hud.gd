extends CanvasLayer

## scenario2_hud.gd — Persistent illness-spread tracking display.
##
## Shows a thin header at the top of the screen tracking how many NPCs
## believe the illness rumor about Alys Herbwife, who believes/rejects,
## and days remaining.
##
## Layout:
##   Scenario 2: The Plague Scare
##   Believers: 3 / 7+   [progress bar]   Days remaining: 18
##   ✓ Tomas, Calder, Finn   ✗ Sister Maren
##
## Wire via setup(world, day_night) from main.gd.
## Subscribes to game_tick and scenario_resolved signals.

# ── Palette (matches journal.gd / scenario3_hud.gd / scenario4_hud.gd) ─────
const C_PANEL_BG   := Color(0.15, 0.10, 0.08, 0.88)
const C_HEADING    := Color(0.91, 0.85, 0.70, 1.0)
const C_BODY       := Color(0.75, 0.70, 0.60, 1.0)
const C_WIN        := Color(0.10, 0.75, 0.22, 1.0)
const C_FAIL       := Color(0.85, 0.15, 0.15, 1.0)
const C_NEUTRAL    := Color(0.85, 0.55, 0.10, 1.0)
const C_ILLNESS    := Color(0.60, 0.85, 0.30, 1.0)  # sickly green for plague theme

const BAR_WIDTH  := 140
const BAR_HEIGHT := 10

# Maximum NPCs to show in the believer/rejecter name list before truncating.
const MAX_NAMES_SHOWN := 5

# ── Node refs (built in _ready) ─────────────────────────────────────────────
var _panel:            Panel     = null
var _count_lbl:        Label     = null
var _bar:              ColorRect = null
var _bar_bg:           ColorRect = null
var _days_lbl:         Label     = null
var _believers_lbl:    Label     = null
var _rejecters_lbl:    Label     = null
var _result_lbl:       Label     = null

# ── Runtime refs ────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null
var _day_night_ref: Node   = null


func _ready() -> void:
	layer = 14   # Above journal (12), consistent with S3/S4 HUDs.
	_build_ui()
	visible = false   # Hidden until setup() is called.


func setup(world: Node2D, day_night: Node) -> void:
	_world_ref     = world
	_day_night_ref = day_night
	visible = true
	if day_night != null:
		day_night.game_tick.connect(_on_game_tick)
	if world != null and "scenario_manager" in world and world.scenario_manager != null:
		world.scenario_manager.scenario_resolved.connect(_on_scenario_resolved)
	_refresh()


# ── UI construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "Scenario2Panel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_PANEL_BG
	panel_style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.custom_minimum_size = Vector2(0, 62)
	_panel.offset_top    = 4
	_panel.offset_bottom = 66
	_panel.offset_left   = 8
	_panel.offset_right  = -8
	add_child(_panel)

	# Root HBox inside panel.
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(hbox)

	# ── Scenario label ────────────────────────────────────────────────────
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 2:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	hbox.add_child(title_lbl)

	# ── Believer count + progress bar ─────────────────────────────────────
	var count_vbox := VBoxContainer.new()
	count_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(count_vbox)

	_count_lbl = Label.new()
	_count_lbl.add_theme_font_size_override("font_size", 12)
	_count_lbl.add_theme_color_override("font_color", C_BODY)
	_count_lbl.text = "Believers: 0 / 7+"
	count_vbox.add_child(_count_lbl)

	var bar_hbox := HBoxContainer.new()
	count_vbox.add_child(bar_hbox)

	_bar_bg = ColorRect.new()
	_bar_bg.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_bg.color = Color(0.25, 0.25, 0.25)
	bar_hbox.add_child(_bar_bg)

	_bar = ColorRect.new()
	_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_bar.color = C_NEUTRAL
	_bar_bg.add_child(_bar)

	# ── NPC names column ──────────────────────────────────────────────────
	var names_vbox := VBoxContainer.new()
	names_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(names_vbox)

	_believers_lbl = Label.new()
	_believers_lbl.add_theme_font_size_override("font_size", 11)
	_believers_lbl.add_theme_color_override("font_color", C_ILLNESS)
	_believers_lbl.text = "Believe: —"
	names_vbox.add_child(_believers_lbl)

	_rejecters_lbl = Label.new()
	_rejecters_lbl.add_theme_font_size_override("font_size", 11)
	_rejecters_lbl.add_theme_color_override("font_color", C_FAIL)
	_rejecters_lbl.text = ""
	_rejecters_lbl.visible = false
	names_vbox.add_child(_rejecters_lbl)

	# ── Days remaining / result ───────────────────────────────────────────
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 12)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 30"
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 14)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	right_vbox.add_child(_result_lbl)

	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 11)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "Target: 7+ believers"
	right_vbox.add_child(legend_lbl)


# ── Refresh ─────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _world_ref == null:
		return
	if not ("reputation_system" in _world_ref) or _world_ref.reputation_system == null:
		return
	if not ("scenario_manager" in _world_ref) or _world_ref.scenario_manager == null:
		return

	var rep: ReputationSystem  = _world_ref.reputation_system
	var sm:  ScenarioManager   = _world_ref.scenario_manager
	var progress: Dictionary   = sm.get_scenario_2_progress(rep)

	var count: int       = progress["illness_believer_count"]
	var threshold: int   = progress["win_threshold"]
	var believers: Array = progress["illness_believer_ids"]
	var rejecters: Array = progress["illness_rejecter_ids"]
	var state            = progress["state"]

	# Count label.
	_count_lbl.text = "Believers: %d / %d+" % [count, threshold]

	# Progress bar — fills toward the win threshold.
	var ratio: float = clamp(float(count) / float(threshold), 0.0, 1.0)
	_bar.custom_minimum_size.x = BAR_WIDTH * ratio
	if count >= threshold:
		_bar.color = C_WIN
	elif count >= threshold / 2:
		_bar.color = C_NEUTRAL
	else:
		_bar.color = C_ILLNESS

	# Believer names.
	if believers.size() > 0:
		var names: Array = []
		for npc_id in believers.slice(0, MAX_NAMES_SHOWN):
			names.append(_display_name(npc_id))
		var suffix := ""
		if believers.size() > MAX_NAMES_SHOWN:
			suffix = " +%d more" % (believers.size() - MAX_NAMES_SHOWN)
		_believers_lbl.text = "Believe: " + ", ".join(names) + suffix
	else:
		_believers_lbl.text = "Believe: —"

	# Rejecter names.
	if rejecters.size() > 0:
		var names: Array = []
		for npc_id in rejecters:
			names.append(_display_name(npc_id))
		_rejecters_lbl.text = "Reject: " + ", ".join(names)
		_rejecters_lbl.visible = true
	else:
		_rejecters_lbl.visible = false

	# Days remaining.
	var days_elapsed: int = (_day_night_ref.current_day - 1) if _day_night_ref != null else 0
	var days_allowed: int = sm.get_days_allowed() if sm != null else 30
	_days_lbl.text = "Days remaining: %d" % max(0, days_allowed - days_elapsed)

	# Result label.
	match state:
		ScenarioManager.ScenarioState.WON:
			_result_lbl.text = "VICTORY — The plague scare spreads"
			_result_lbl.add_theme_color_override("font_color", C_WIN)
		ScenarioManager.ScenarioState.FAILED:
			_result_lbl.text = "FAILED — The truth prevails"
			_result_lbl.add_theme_color_override("font_color", C_FAIL)
		_:
			_result_lbl.text = ""


## Convert npc_id like "tomas_reeve" to "Tomas Reeve".
func _display_name(npc_id: String) -> String:
	return npc_id.replace("_", " ").capitalize()


# ── Signals ─────────────────────────────────────────────────────────────────

func _on_game_tick(_tick: int) -> void:
	_refresh()


func _on_scenario_resolved(scenario_id: int, _state: ScenarioManager.ScenarioState) -> void:
	if scenario_id != 2:
		return
	_refresh()
	if _result_lbl != null:
		var tween := create_tween()
		tween.tween_property(_result_lbl, "modulate:a", 0.0, 0.3).set_delay(1.5)
		tween.tween_property(_result_lbl, "modulate:a", 1.0, 0.2)
