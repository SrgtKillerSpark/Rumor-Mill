extends CanvasLayer

## hud_tooltip.gd — Custom themed tooltip overlay for all HUD elements.
##
## Replaces Godot's default tooltip rendering with a styled parchment-themed
## tooltip that matches the game's medieval aesthetic.  Reads tooltip_text
## from hovered Controls automatically.
##
## Usage: Add as child of Main (layer 99, above all HUD and overlay layers).
##        No per-element wiring needed — uses _process polling on viewport focus.
##
## SPA-1179 #32 — Tooltip layer precedence:
##   hud_tooltip (this file): layer 99 — auto-detected hover tooltips from tooltip_text.
##   TooltipManager (tooltip_manager.gd): layer 100 — explicit data-driven tooltips
##     shown via TooltipManager.show_at(key).  When both are active simultaneously,
##     TooltipManager wins by one layer.  In practice only one fires at a time because
##     TooltipManager is driven by explicit show_at() calls while hud_tooltip deactivates
##     itself when no tooltip_text control is hovered.

const C_BG       := Color(0.10, 0.07, 0.05, 0.95)
const C_BORDER   := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE    := Color(0.92, 0.78, 0.12, 1.0)
const C_BODY     := Color(0.82, 0.75, 0.60, 1.0)
const C_MUTED    := Color(0.65, 0.58, 0.45, 0.85)
const C_OUTLINE  := Color(0, 0, 0, 0.7)

const TOOLTIP_MAX_WIDTH := 320.0
const CURSOR_OFFSET := Vector2(16, -12)
const FADE_IN_SEC := 0.10
const HOVER_DELAY_SEC := 0.35

var _panel: PanelContainer = null
var _title_label: Label = null
var _body_label: Label = null
var _vbox: VBoxContainer = null
var _fade_tween: Tween = null

## Currently displayed tooltip text (to avoid redundant rebuilds).
var _current_text: String = ""
## Accumulated hover time on the same control before showing.
var _hover_time: float = 0.0
## Whether the tooltip is currently visible.
var _showing: bool = false
## The control we are currently hovering.
var _hovered_control: Control = null


func _ready() -> void:
	# SPA-1179 #32: raised from 25 to 99 so this is always visible above all HUD
	# layers (scenario HUD=14, objective=15, speed=16) and overlay layers (≤51).
	# TooltipManager runs at 100 and takes precedence for explicit data-driven tips.
	layer = 99
	_build_panel()


func _process(delta: float) -> void:
	var viewport := get_viewport()
	if viewport == null:
		_hide_tooltip()
		return

	var mouse_pos := viewport.get_mouse_position()
	var focused := _find_tooltip_control(viewport, mouse_pos)

	if focused == null or focused.tooltip_text.is_empty():
		if _showing:
			_hide_tooltip()
		_hovered_control = null
		_hover_time = 0.0
		_current_text = ""
		return

	# Track hover duration before showing.
	if focused != _hovered_control:
		_hovered_control = focused
		_hover_time = 0.0
		if _showing:
			_hide_tooltip()
		_current_text = ""

	_hover_time += delta

	if _hover_time < HOVER_DELAY_SEC:
		return

	var tip_text: String = focused.tooltip_text
	if tip_text != _current_text:
		_current_text = tip_text
		_update_content(tip_text)
		_show_tooltip()

	# Reposition each frame to follow cursor.
	_reposition(mouse_pos)


## Walk the GUI focus tree to find the deepest control with tooltip_text.
func _find_tooltip_control(viewport: Viewport, mouse_pos: Vector2) -> Control:
	var gui_root := viewport.gui_get_focus_owner()
	# Use a simpler approach: find what's under the mouse via the viewport.
	# Godot 4 doesn't expose gui_get_hovered_control easily, so we manually
	# walk CanvasLayers from highest to lowest.
	var best: Control = null
	var best_layer: int = -100

	# Check all CanvasLayer children of the scene tree root.
	var tree := get_tree()
	if tree == null:
		return null
	var root := tree.current_scene
	if root == null:
		return null

	# Collect all CanvasLayers and the root viewport.
	var layers: Array = []
	_collect_canvas_layers(root, layers)

	# Sort by layer descending so the topmost UI is checked first.
	layers.sort_custom(func(a: CanvasLayer, b: CanvasLayer) -> bool:
		return a.layer > b.layer
	)

	for cl: CanvasLayer in layers:
		if not cl.visible:
			continue
		# Skip self.
		if cl == self:
			continue
		var hit := _find_deepest_tooltip_at(cl, mouse_pos)
		if hit != null:
			return hit

	# Also check the default viewport layer (HUD CanvasLayer at layer 0).
	return null


func _collect_canvas_layers(node: Node, result: Array) -> void:
	if node is CanvasLayer:
		result.append(node)
	for child in node.get_children():
		_collect_canvas_layers(child, result)


## Recursively find the deepest visible Control with a tooltip_text at mouse_pos.
func _find_deepest_tooltip_at(parent: Node, mouse_pos: Vector2) -> Control:
	var best: Control = null
	# Walk children in reverse order (last child drawn on top).
	var count: int = parent.get_child_count()
	for i in range(count - 1, -1, -1):
		var child: Node = parent.get_child(i)
		if child is Control:
			var ctrl: Control = child as Control
			if not ctrl.visible:
				continue
			if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				# Still check children — they might have their own mouse_filter.
				var deeper := _find_deepest_tooltip_at(ctrl, mouse_pos)
				if deeper != null:
					return deeper
				continue
			# Check children first (deeper = higher priority).
			var deeper := _find_deepest_tooltip_at(ctrl, mouse_pos)
			if deeper != null:
				return deeper
			# Check this control itself.
			if ctrl.get_global_rect().has_point(mouse_pos) and not ctrl.tooltip_text.is_empty():
				return ctrl
		elif child.get_child_count() > 0:
			var deeper := _find_deepest_tooltip_at(child, mouse_pos)
			if deeper != null:
				return deeper
	return best


func _update_content(text: String) -> void:
	# Support a simple "Title\nBody" convention: if the first line is short
	# and followed by content, treat it as a title.
	var lines := text.split("\n", false)
	if lines.size() >= 2 and lines[0].length() <= 40:
		_title_label.text = lines[0]
		_title_label.visible = true
		_body_label.text = "\n".join(lines.slice(1))
	else:
		_title_label.visible = false
		_body_label.text = text


func _show_tooltip() -> void:
	_showing = true
	_panel.visible = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_panel.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_tooltip() -> void:
	_showing = false
	_current_text = ""
	if _panel != null:
		_panel.visible = false
		_panel.modulate.a = 0.0


func _reposition(mouse_pos: Vector2) -> void:
	if _panel == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	# Force layout so size is up to date.
	_panel.reset_size()
	var panel_size := _panel.size

	var pos := mouse_pos + CURSOR_OFFSET
	# Clamp to viewport edges.
	if pos.x + panel_size.x > vp_size.x - 8:
		pos.x = mouse_pos.x - panel_size.x - 8
	if pos.y - panel_size.y < 8:
		pos.y = mouse_pos.y + 24
	if pos.y + panel_size.y > vp_size.y - 8:
		pos.y = vp_size.y - panel_size.y - 8
	if pos.x < 8:
		pos.x = 8

	_panel.position = pos


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(120, 0)
	# Use anchors-free positioning (manual position).
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	# Subtle shadow via expand margin.
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	_panel.add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(_vbox)

	# Title label (optional, shown when tooltip has a title line).
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", C_TITLE)
	_title_label.add_theme_constant_override("outline_size", 2)
	_title_label.add_theme_color_override("font_outline_color", C_OUTLINE)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.custom_minimum_size = Vector2(0, 0)
	_title_label.visible = false
	_vbox.add_child(_title_label)

	# Body label.
	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 12)
	_body_label.add_theme_color_override("font_color", C_BODY)
	_body_label.add_theme_constant_override("outline_size", 1)
	_body_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_maximum_size = Vector2(TOOLTIP_MAX_WIDTH, 0)
	_body_label.custom_minimum_size = Vector2(100, 0)
	_vbox.add_child(_body_label)

	_panel.visible = false
	_panel.modulate.a = 0.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Make all children ignore mouse too.
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
