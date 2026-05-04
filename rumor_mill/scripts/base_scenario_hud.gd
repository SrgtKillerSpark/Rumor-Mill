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

# ── Canvas layer ─────────────────────────────────────────────────────────────
## Canonical CanvasLayer value set in _ready(). Tested by test_spa1179_z_order_layers.gd.
## Layer order: journal(12) < scenario(14) < objective(15) < speed(16).
const LAYER := 14

# ── Shared palette ───────────────────────────────────────────────────────────
const C_PANEL_BG := Color(0.15, 0.10, 0.08, 0.92)

# ── Shared layout constants ───────────────────────────────────────────────────
## Unified bar height for all scenario HUD progress bars (pixels).
const BAR_HEIGHT := 12
const C_HEADING  := Color(0.91, 0.85, 0.70, 1.0)
const C_BODY     := Color(0.75, 0.70, 0.60, 1.0)
const C_WIN      := Color(0.10, 0.75, 0.22, 1.0)
const C_FAIL     := Color(0.85, 0.15, 0.15, 1.0)
const C_NEUTRAL  := Color(0.85, 0.55, 0.10, 1.0)

# ── Shared state ─────────────────────────────────────────────────────────────
var _world_ref:       Node2D       = null
var _day_night_ref:   Node         = null
var _result_lbl:      Label        = null
var _days_lbl:        Label        = null
var _diff_lbl:        Label        = null
## Shared toast area anchored just below the main HUD panel. Subclass HUDs add
## toast Panels as children; VBoxContainer stacks them vertically. Populated by
## _make_panel() so it is always ready before _build_ui() appends toasts.
var _toast_container: VBoxContainer = null


func _ready() -> void:
	layer = 14   # Above journal (12), consistent across all scenario HUDs.
	_build_ui()
	_build_difficulty_badge()
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


# ── Label styling helper ─────────────────────────────────────────────────────

## Apply a subtle text outline to a label for better readability over varied backgrounds.
func _apply_text_outline(label: Label, size: int = 2, color: Color = Color(0, 0, 0, 0.6)) -> void:
	label.add_theme_constant_override("outline_size", size)
	label.add_theme_color_override("font_outline_color", color)


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

	_toast_container = VBoxContainer.new()
	_toast_container.name = "ToastContainer"
	_toast_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_container.offset_top    = height + 4
	_toast_container.offset_bottom = height + 4 + 100
	_toast_container.offset_left   = 8
	_toast_container.offset_right  = -8
	add_child(_toast_container)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", hbox_separation)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)
	return hbox


## Apply a consistent themed StyleBox to a HUD action button (normal/hover/pressed/disabled).
## Call immediately after Button.new() in any scenario HUD _build_ui().
func _apply_hud_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.16, 0.10, 0.90)
	normal.border_color = Color(0.60, 0.48, 0.30, 0.80)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left   = 8
	normal.content_margin_right  = 8
	normal.content_margin_top    = 3
	normal.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.30, 0.22, 0.13, 0.95)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.18, 0.13, 0.08, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate()
	disabled.bg_color    = Color(0.15, 0.12, 0.09, 0.60)
	disabled.border_color = Color(0.40, 0.35, 0.25, 0.40)
	btn.add_theme_stylebox_override("disabled", disabled)


## Build a progress bar (dark background + colored fill child) with rounded corners.
## Returns [bar_bg, bar_fill]. Caller adds bar_bg to the desired parent.
func _make_progress_bar(bar_width: int, bar_height: int, bg_tooltip: String = "") -> Array:
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(bar_width, bar_height)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.20, 0.18, 0.15)
	bg_style.set_corner_radius_all(3)
	bg_style.set_border_width_all(1)
	bg_style.border_color = Color(0.35, 0.28, 0.18, 0.6)
	bg.add_theme_stylebox_override("panel", bg_style)
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
			_result_lbl.add_theme_constant_override("outline_size", 3)
			_result_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		ScenarioManager.ScenarioState.FAILED:
			_result_lbl.text = fail_text
			_result_lbl.add_theme_color_override("font_color", C_FAIL)
			_result_lbl.add_theme_constant_override("outline_size", 3)
			_result_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
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


## Build a small difficulty badge anchored to the top-right corner.
## Displays the active difficulty preset so the player can see it during play.
func _build_difficulty_badge() -> void:
	var preset: String = GameState.selected_difficulty
	var label_text: String = preset.capitalize()

	_diff_lbl = Label.new()
	_diff_lbl.text = label_text
	_diff_lbl.add_theme_font_size_override("font_size", 12)
	_diff_lbl.add_theme_constant_override("outline_size", 2)
	_diff_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	match preset:
		"apprentice":
			_diff_lbl.add_theme_color_override("font_color", Color(0.50, 0.85, 0.50, 0.80))
		"spymaster":
			_diff_lbl.add_theme_color_override("font_color", Color(0.90, 0.30, 0.20, 0.90))
		_:
			_diff_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45, 0.75))
	_diff_lbl.set_anchor(SIDE_RIGHT,  1.0)
	_diff_lbl.set_anchor(SIDE_LEFT,   1.0)
	_diff_lbl.set_anchor(SIDE_TOP,    0.0)
	_diff_lbl.set_anchor(SIDE_BOTTOM, 0.0)
	_diff_lbl.set_offset(SIDE_RIGHT, -8)
	_diff_lbl.set_offset(SIDE_LEFT,  -80)
	_diff_lbl.set_offset(SIDE_TOP,    8)
	_diff_lbl.set_offset(SIDE_BOTTOM, 24)
	_diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_diff_lbl)


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_game_tick(_tick: int) -> void:
	_refresh()


func _on_scenario_resolved(scenario_id: int, _state: ScenarioManager.ScenarioState) -> void:
	if scenario_id != _scenario_number():
		return
	_refresh()
	_flash_result_lbl()
