class_name BaseScenarioHud
extends CanvasLayer

## base_scenario_hud.gd — Shared base for scenario1_hud through scenario4_hud.
##
## Provides: palette constants, _ready, setup signal wiring, _on_game_tick,
## _on_scenario_resolved with result-label flash, days-remaining update helper,
## result-label update helper, null-guard, display-name utility, and the
## _make_panel() factory for building the top-strip UI shell.
##
## Subclasses must:
##   override _scenario_number() -> int  (return 1, 2, 3, or 4)
##   override _build_ui()                (build scenario-specific nodes)
##   override _refresh()                 (read game state, update labels/bars)
##   override _on_setup_extra(world)     (wire extra signals — S3, S4 only)

# ── Shared palette ───────────────────────────────────────────────────────────
const C_PANEL_BG := Color(0.15, 0.10, 0.08, 0.88)
const C_HEADING  := Color(0.91, 0.85, 0.70, 1.0)
const C_BODY     := Color(0.75, 0.70, 0.60, 1.0)
const C_WIN      := Color(0.10, 0.75, 0.22, 1.0)
const C_FAIL     := Color(0.85, 0.15, 0.15, 1.0)
const C_NEUTRAL  := Color(0.85, 0.55, 0.10, 1.0)

# ── Shared state ─────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null
var _day_night_ref: Node   = null
var _result_lbl:    Label  = null
var _days_lbl:      Label  = null


func _ready() -> void:
	layer = 14   # Above journal (12), consistent across all scenario HUDs.
	_build_ui()
	visible = false   # Hidden until setup() is called.


## Wire the HUD to world and day/night systems. Called from main.gd.
func setup(world: Node2D, day_night: Node) -> void:
	_world_ref     = world
	_day_night_ref = day_night
	visible = true
	if day_night != null:
		day_night.game_tick.connect(_on_game_tick)
	if world != null and "scenario_manager" in world and world.scenario_manager != null:
		world.scenario_manager.scenario_resolved.connect(_on_scenario_resolved)
	_on_setup_extra(world)
	_refresh()


## Override in subclasses that need extra signal wiring (S3: rival; S4: inquisitor).
func _on_setup_extra(_world: Node2D) -> void:
	pass


## Override to build scenario-specific UI nodes.
func _build_ui() -> void:
	pass


## Override with scenario-specific refresh logic.
func _refresh() -> void:
	pass


## Override to return this scenario's number (1–4) for resolved-signal filtering.
func _scenario_number() -> int:
	return 0


# ── Null-guard helper ────────────────────────────────────────────────────────

## Returns true when _world_ref has the required ReputationSystem and ScenarioManager.
func _has_world_deps() -> bool:
	if _world_ref == null:
		return false
	if not ("reputation_system" in _world_ref) or _world_ref.reputation_system == null:
		return false
	if not ("scenario_manager" in _world_ref) or _world_ref.scenario_manager == null:
		return false
	return true


# ── UI factories ─────────────────────────────────────────────────────────────

## Build the top-strip Panel and return the root HBoxContainer.
## Subclasses call this at the top of _build_ui() and append their nodes to the hbox.
func _make_panel(panel_name: String, height: int, hbox_separation: int = 16) -> HBoxContainer:
	var panel := Panel.new()
	panel.name = panel_name
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, height)
	panel.offset_top    = 4
	panel.offset_bottom = height + 4
	panel.offset_left   = 8
	panel.offset_right  = -8
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", hbox_separation)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)
	return hbox


## Build a progress bar (dark background + colored fill child).
## Returns [bar_bg, bar_fill]. Caller adds bar_bg to the desired parent.
func _make_progress_bar(bar_width: int, bar_height: int, bg_tooltip: String = "") -> Array:
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(bar_width, bar_height)
	bg.color = Color(0.25, 0.25, 0.25)
	if not bg_tooltip.is_empty():
		bg.tooltip_text  = bg_tooltip
		bg.mouse_filter  = Control.MOUSE_FILTER_PASS

	var fill := ColorRect.new()
	fill.custom_minimum_size = Vector2(0, bar_height)
	fill.color = C_NEUTRAL
	bg.add_child(fill)
	return [bg, fill]


# ── Refresh helpers ──────────────────────────────────────────────────────────

## Update _days_lbl with the current days-remaining count.
func _update_days_remaining(sm: ScenarioManager) -> void:
	if _days_lbl == null or sm == null:
		return
	var days_elapsed: int = (sm.get_current_day(_day_night_ref.current_tick) - 1) \
		if _day_night_ref != null else 0
	_days_lbl.text = "Days remaining: %d" % max(0, sm.get_days_allowed() - days_elapsed)


## Update _result_lbl text and colour based on scenario state.
func _update_result_label(
		state: ScenarioManager.ScenarioState,
		win_text: String,
		fail_text: String) -> void:
	if _result_lbl == null:
		return
	match state:
		ScenarioManager.ScenarioState.WON:
			_result_lbl.text = win_text
			_result_lbl.add_theme_color_override("font_color", C_WIN)
		ScenarioManager.ScenarioState.FAILED:
			_result_lbl.text = fail_text
			_result_lbl.add_theme_color_override("font_color", C_FAIL)
		_:
			_result_lbl.text = ""


## Flash _result_lbl with a brief fade-out / fade-in tween.
func _flash_result_lbl() -> void:
	if _result_lbl == null:
		return
	var tween := create_tween()
	tween.tween_property(_result_lbl, "modulate:a", 0.0, 0.3).set_delay(1.5)
	tween.tween_property(_result_lbl, "modulate:a", 1.0, 0.2)


## Convert a snake_case NPC id (e.g. "tomas_reeve") to "Title Case" display name.
func _display_name(npc_id: String) -> String:
	return npc_id.replace("_", " ").capitalize()


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_game_tick(_tick: int) -> void:
	_refresh()


func _on_scenario_resolved(scenario_id: int, _state: ScenarioManager.ScenarioState) -> void:
	if scenario_id != _scenario_number():
		return
	_refresh()
	_flash_result_lbl()
