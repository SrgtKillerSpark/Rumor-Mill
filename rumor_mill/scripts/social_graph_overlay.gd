extends CanvasLayer

## social_graph_overlay.gd — Sprint 6: Player-facing Social Graph View.
##
## G              — toggle the overlay
## Scroll wheel   — zoom 0.5x–2.0x, centered on cursor
## Click-drag     — pan the graph
## Double-click / Home — reset zoom and pan
## Search box (top-left) — type to find NPC, gold pulse on match, Esc clears
## Legend faction rows   — click to hide/show that faction's nodes and edges
## Legend state rows     — click to highlight nodes in that rumor state
##
## Draws on CanvasLayer 8, below debug tools (10/20) but above game world.

# ── Node colours ─────────────────────────────────────────────────────────────

const FACTION_FILL := {
	"merchant": Color(0.85, 0.65, 0.10, 1.0),   # warm gold
	"noble":    Color(0.424, 0.086, 0.165, 1.0), # NOBLE_BODY burgundy (#6C162A)
	"clergy":   Color(0.88, 0.88, 0.88, 1.0),   # pale grey-white
}

const STATE_RING_COLOR := {
	Rumor.RumorState.UNAWARE:       Color(0.25, 0.25, 0.25, 0.0),
	Rumor.RumorState.EVALUATING:    Color(1.00, 1.00, 0.00, 1.0),
	Rumor.RumorState.BELIEVE:       Color(0.00, 0.45, 0.70, 1.0),  # blue — colorblind-safe (replaces green)
	Rumor.RumorState.REJECT:        Color(0.84, 0.37, 0.00, 1.0),  # vermilion — colorblind-safe (replaces red)
	Rumor.RumorState.SPREAD:        Color(1.00, 0.50, 0.00, 1.0),
	Rumor.RumorState.ACT:           Color(0.75, 0.05, 1.00, 1.0),
	Rumor.RumorState.DEFENDING:     Color(0.50, 0.80, 1.00, 1.0),
	Rumor.RumorState.CONTRADICTED:  Color(0.75, 0.55, 1.00, 1.0),
	Rumor.RumorState.EXPIRED:       Color(0.25, 0.25, 0.25, 0.6),
}

const EDGE_BASE_COLOR       := Color(0.50, 0.80, 1.00, 1.0)
const EDGE_WEAK_COLOR       := Color(0.40, 0.45, 0.55, 1.0)  # cool grey — low bond
const EDGE_MEDIUM_COLOR     := Color(0.50, 0.75, 0.90, 1.0)  # soft blue — moderate bond
const EDGE_STRONG_COLOR     := Color(0.20, 1.00, 0.70, 1.0)  # vivid teal — strong bond
const ACTIVE_RUMOR_GLOW_COLOR  := Color(1.0, 0.85, 0.10, 0.35)
const ACTIVE_RUMOR_GLOW_RADIUS := 20.0
const EDGE_MUTATED_NEG_COLOR   := Color(0.90, 0.55, 0.10, 1.0)
const EDGE_MUTATED_POS_COLOR   := Color(0.30, 0.55, 0.90, 1.0)
const LIVE_SPREAD_EDGE_COLOR   := Color(0.10, 0.85, 0.55, 0.65)
const LIVE_SPREAD_EDGE_WIDTH   := 2.5
const EDGE_THRESHOLD           := 0.30

# ── Faction Influence Heatmap ─────────────────────────────────────────────────
const HEATMAP_LOCATIONS: Array[String] = ["market", "tavern", "chapel", "manor"]
const LOCATION_DISPLAY_NAMES: Dictionary = {
	"market": "Market", "tavern": "Tavern", "chapel": "Chapel", "manor": "Manor",
}
const ZONE_RADIUS        := 68.0
const HEATMAP_LERP_SPEED := 3.0
# Isometric cell → world (matches npc.gd / recon_controller.gd):
# world_x = (col - row) * 32,  world_y = (col + row) * 16
const HM_TILE_W := 64
const HM_TILE_H := 32

# Node drawing sizes.
const NODE_RADIUS      := 12.0
const RING_THICKNESS   :=  4.0
const NPC_LABEL_MAX_W  := 80.0  # Max pill width for NPC name labels.

# Search match: pulsing gold ring around the matched NPC.
const SEARCH_MATCH_COLOR := Color(1.0, 0.85, 0.0, 1.0)

# ── State ─────────────────────────────────────────────────────────────────────

var visible_overlay: bool = false
var _world_ref: Node2D = null
var _draw_node: Node2D = null
var _fade_tween: Tween = null

# Legend panel (rebuilt in _ready).
var _legend_panel: PanelContainer = null

# Spread-edge highlights.
const SPREAD_HIGHLIGHT_DURATION := 3.0
const SPREAD_HIGHLIGHT_COLOR    := Color(1.0, 0.6, 0.0, 0.9)
var _active_spread_edges: Dictionary = {}   # "from_id|to_id" → seconds remaining

# ── Heatmap mode ──────────────────────────────────────────────────────────────
var _heatmap_mode: bool = false
var _heatmap_influence: Dictionary = {}   # loc → { faction → float 0..1 }
var _mode_btn_social:  Button = null
var _mode_btn_heatmap: Button = null
var _sg_legend_box:    VBoxContainer = null
var _hm_legend_box:    VBoxContainer = null
var _hm_legend_label:  RichTextLabel = null

# ── Zoom / pan ────────────────────────────────────────────────────────────────

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
var _zoom_level:   float   = 1.0
var _pan_offset:   Vector2 = Vector2.ZERO
var _is_panning:   bool    = false
var _pan_last_pos: Vector2 = Vector2.ZERO

# ── NPC search ────────────────────────────────────────────────────────────────

var _search_text:      String = ""
var _search_target_id: String = ""
var _search_input:     LineEdit        = null
var _search_panel:     PanelContainer  = null

# ── NPC id → Node2D lookup (rebuilt each _on_draw for O(1) access) ───────────
var _npc_lookup: Dictionary = {}

# ── Legend filter state ───────────────────────────────────────────────────────

# faction_name → true  when that faction's nodes/edges are hidden.
var _factions_hidden: Dictionary = {}
# int(RumorState) → true  when that state's nodes are highlighted (rest dimmed).
var _states_highlighted: Dictionary = {}


func _ready() -> void:
	layer = 8
	_draw_node = Node2D.new()
	_draw_node.name = "SGDraw"
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw)

	_build_legend()
	_build_search_ui()
	visible = false


func set_world(world: Node2D) -> void:
	_world_ref = world


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_G:
				_toggle_overlay()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				if visible_overlay:
					_toggle_heatmap_mode()
					get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if visible_overlay:
					if not _search_text.is_empty():
						_clear_search()
					else:
						_close_overlay()
					get_viewport().set_input_as_handled()
			KEY_HOME:
				if visible_overlay:
					_reset_view()
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and visible_overlay:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					var old_zoom := _zoom_level
					_zoom_level = clamp(_zoom_level * 1.1, ZOOM_MIN, ZOOM_MAX)
					_adjust_pan_for_zoom(event.position, old_zoom)
					_draw_node.queue_redraw()
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					var old_zoom := _zoom_level
					_zoom_level = clamp(_zoom_level / 1.1, ZOOM_MIN, ZOOM_MAX)
					_adjust_pan_for_zoom(event.position, old_zoom)
					_draw_node.queue_redraw()
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_LEFT:
				if event.double_click:
					_reset_view()
					get_viewport().set_input_as_handled()
				elif event.pressed:
					_is_panning = true
					_pan_last_pos = event.position
				else:
					_is_panning = false

	elif event is InputEventMouseMotion and visible_overlay and _is_panning:
		_pan_offset += event.position - _pan_last_pos
		_pan_last_pos = event.position
		_draw_node.queue_redraw()
		get_viewport().set_input_as_handled()


func _toggle_overlay() -> void:
	visible_overlay = not visible_overlay
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if visible_overlay:
		AudioManager.play_sfx("journal_open")
		visible = true
		_legend_panel.visible = true
		_search_panel.visible = true
		_draw_node.modulate.a = 0.0
		_legend_panel.modulate.a = 0.0
		_search_panel.modulate.a = 0.0
		_fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_fade_tween.tween_property(_draw_node, "modulate:a", 1.0, 0.2)
		_fade_tween.parallel().tween_property(_legend_panel, "modulate:a", 1.0, 0.2)
		_fade_tween.parallel().tween_property(_search_panel, "modulate:a", 1.0, 0.2)
	else:
		_close_overlay()
	_draw_node.queue_redraw()


func _close_overlay() -> void:
	_set_heatmap_mode(false)
	visible_overlay = false
	AudioManager.play_sfx("journal_close")
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fade_tween.tween_property(_draw_node, "modulate:a", 0.0, 0.15)
	_fade_tween.parallel().tween_property(_legend_panel, "modulate:a", 0.0, 0.15)
	_fade_tween.parallel().tween_property(_search_panel, "modulate:a", 0.0, 0.15)
	_fade_tween.tween_callback(func() -> void:
		visible = false
		_legend_panel.visible = false
		_search_panel.visible = false
	)
	_draw_node.queue_redraw()


func _reset_view() -> void:
	_zoom_level = 1.0
	_pan_offset = Vector2.ZERO
	_draw_node.queue_redraw()


## Keep the point under the cursor fixed when zoom changes.
func _adjust_pan_for_zoom(cursor_pos: Vector2, old_zoom: float) -> void:
	var center := get_viewport().get_visible_rect().size * 0.5
	# p_rel is the "logical" distance of the cursor from centre in unzoomed space.
	var p_rel := (cursor_pos - center - _pan_offset) / old_zoom
	_pan_offset = cursor_pos - center - p_rel * _zoom_level


# ── Search UI ─────────────────────────────────────────────────────────────────

func _build_search_ui() -> void:
	_search_panel = PanelContainer.new()
	_search_panel.name = "SGSearch"
	_search_panel.set_anchor_and_offset(SIDE_LEFT,   0.0,  10.0)
	_search_panel.set_anchor_and_offset(SIDE_RIGHT,  0.0, 215.0)
	_search_panel.set_anchor_and_offset(SIDE_TOP,    0.0,  10.0)
	_search_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.0,  40.0)

	var style := StyleBoxFlat.new()
	style.bg_color    = Color(0.08, 0.05, 0.03, 0.88)
	style.border_color = Color(0.55, 0.38, 0.18, 1.0)
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	_search_panel.add_theme_stylebox_override("panel", style)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search NPC…"
	_search_input.custom_minimum_size = Vector2(192, 22)
	_search_input.add_theme_font_size_override("font_size", 12)
	_search_input.text_changed.connect(_on_search_changed)
	_search_input.gui_input.connect(_on_search_gui_input)
	_search_panel.add_child(_search_input)
	add_child(_search_panel)
	_search_panel.visible = false


func _on_search_changed(new_text: String) -> void:
	_search_text = new_text.strip_edges().to_lower()
	_search_target_id = ""
	if _search_text.is_empty() or _world_ref == null:
		_draw_node.queue_redraw()
		return
	for npc in _world_ref.npcs:
		var npc_name: String = npc.npc_data.get("name", "").to_lower()
		if npc_name.begins_with(_search_text) or npc_name.contains(_search_text):
			_search_target_id = npc.npc_data.get("id", "")
			_center_on_npc(npc)
			break
	_draw_node.queue_redraw()


func _on_search_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not _search_text.is_empty():
			_clear_search()
			_search_input.release_focus()
			get_viewport().set_input_as_handled()
		# If already empty, let the event fall through to _unhandled_input → close overlay.


func _clear_search() -> void:
	_search_text = ""
	_search_target_id = ""
	if _search_input != null:
		_search_input.text = ""
	_draw_node.queue_redraw()


func _center_on_npc(npc: Node2D) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var base_screen := viewport.get_canvas_transform() * npc.global_position
	var center := viewport.get_visible_rect().size * 0.5
	# Solve: center + (base_screen - center)*zoom + pan = center  →  pan = -(base_screen - center)*zoom
	_pan_offset = -(base_screen - center) * _zoom_level


# ── Draw loop ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if visible_overlay:
		_draw_node.queue_redraw()

		_tick_heatmap_influence(delta)
		if _heatmap_mode and _hm_legend_label != null:
			_update_heatmap_legend_label()

		if not _active_spread_edges.is_empty():
			var expired: Array = []
			for key in _active_spread_edges:
				_active_spread_edges[key] -= delta
				if _active_spread_edges[key] <= 0.0:
					expired.append(key)
			for key in expired:
				_active_spread_edges.erase(key)


## Called by main.gd _on_rumor_event.  Highlights the social-graph edge for a
## "Alice whispered to Bob [id]" transmission message.
func on_rumor_event(message: String) -> void:
	if not message.contains(" whispered to "):
		return
	if _world_ref == null:
		return
	var parts := message.split(" whispered to ", false)
	if parts.size() < 2:
		return
	var from_name := parts[0].strip_edges()
	var to_name   := parts[1].split(" [", false)[0].strip_edges()
	var from_id := ""
	var to_id   := ""
	for npc in _world_ref.npcs:
		var n: String = npc.npc_data.get("name", "")
		if n == from_name:
			from_id = npc.npc_data.get("id", "")
		if n == to_name:
			to_id = npc.npc_data.get("id", "")
	if from_id.is_empty() or to_id.is_empty():
		return
	var key := from_id + "|" + to_id if from_id < to_id else to_id + "|" + from_id
	_active_spread_edges[key] = SPREAD_HIGHLIGHT_DURATION


func _on_draw() -> void:
	if not visible_overlay or _world_ref == null:
		return
	if _heatmap_mode:
		_draw_heatmap()
		return
	var npcs: Array = _world_ref.npcs
	if npcs.is_empty():
		return
	# Build id→node lookup once per draw call (O(n)) instead of scanning
	# per-edge inside _draw_edges (was O(n × edges) per frame).
	_npc_lookup.clear()
	for npc in npcs:
		_npc_lookup[npc.npc_data.get("id", "")] = npc
	var sg: SocialGraph = _world_ref.social_graph
	if sg != null:
		_draw_edges(npcs, sg)
	_draw_nodes(npcs)


func _draw_edges(npcs: Array, sg: SocialGraph) -> void:
	# Precompute which NPC ids are actively spreading.
	var spreading_ids: Dictionary = {}
	for npc in npcs:
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state == Rumor.RumorState.SPREAD:
				spreading_ids[npc.npc_data.get("id", "")] = true
				break

	var drawn: Dictionary = {}

	for npc in npcs:
		var nid: String = npc.npc_data.get("id", "")
		var npc_faction: String = npc.npc_data.get("faction", "merchant")
		if _factions_hidden.get(npc_faction, false):
			continue

		var from_screen := _world_to_screen(npc.global_position)
		var neighbours: Dictionary = sg.get_neighbours(nid)

		for tid in neighbours:
			var key: String = nid + "|" + (tid as String) if nid < (tid as String) \
							  else (tid as String) + "|" + nid
			if drawn.has(key):
				continue
			drawn[key] = true

			var target_npc := _find_npc_by_id(npcs, tid)
			if target_npc == null:
				continue
			var target_faction: String = target_npc.npc_data.get("faction", "merchant")
			if _factions_hidden.get(target_faction, false):
				continue

			var to_screen := _world_to_screen(target_npc.global_position)
			var weight: float = neighbours[tid]

			if _active_spread_edges.has(key):
				var t: float = float(_active_spread_edges[key]) / SPREAD_HIGHLIGHT_DURATION
				var h_alpha := lerpf(0.2, 0.9, t)
				var h_width := lerpf(1.5, 4.0, t)
				var h_color := Color(SPREAD_HIGHLIGHT_COLOR.r, SPREAD_HIGHLIGHT_COLOR.g,
									 SPREAD_HIGHLIGHT_COLOR.b, h_alpha)
				_draw_node.draw_line(from_screen, to_screen, h_color, h_width)
				_draw_arrowhead(from_screen, to_screen, h_color, h_width)
			elif weight < EDGE_THRESHOLD:
				continue
			elif spreading_ids.has(nid) or spreading_ids.has(tid):
				_draw_node.draw_line(from_screen, to_screen,
									 LIVE_SPREAD_EDGE_COLOR, LIVE_SPREAD_EDGE_WIDTH)
			else:
				var alpha := clamp((weight - EDGE_THRESHOLD) / (1.0 - EDGE_THRESHOLD), 0.10, 0.65)
				var width := lerpf(0.5, 2.5, weight)
				var mut_fwd: float = sg.get_net_mutation(nid, tid)
				var mut_rev: float = sg.get_net_mutation(tid, nid)
				var base_color: Color
				if mut_fwd < -0.001 or mut_rev < -0.001:
					base_color = EDGE_MUTATED_NEG_COLOR
				elif mut_fwd > 0.001 or mut_rev > 0.001:
					base_color = EDGE_MUTATED_POS_COLOR
				else:
					base_color = _edge_strength_color(weight)
				_draw_node.draw_line(from_screen, to_screen,
									 Color(base_color.r, base_color.g, base_color.b, alpha), width)

	# Second pass: spread edges for proximity-only pairs with no social graph entry.
	for key in _active_spread_edges:
		if drawn.has(key):
			continue
		var parts: PackedStringArray = (key as String).split("|")
		if parts.size() != 2:
			continue
		var npc_a := _find_npc_by_id(npcs, parts[0])
		var npc_b := _find_npc_by_id(npcs, parts[1])
		if npc_a == null or npc_b == null:
			continue
		if _factions_hidden.get(npc_a.npc_data.get("faction", ""), false):
			continue
		if _factions_hidden.get(npc_b.npc_data.get("faction", ""), false):
			continue
		var from_screen := _world_to_screen(npc_a.global_position)
		var to_screen   := _world_to_screen(npc_b.global_position)
		var t: float = float(_active_spread_edges[key]) / SPREAD_HIGHLIGHT_DURATION
		var h_alpha := lerpf(0.2, 0.9, t)
		var h_width := lerpf(1.5, 4.0, t)
		var h_color := Color(SPREAD_HIGHLIGHT_COLOR.r, SPREAD_HIGHLIGHT_COLOR.g,
							 SPREAD_HIGHLIGHT_COLOR.b, h_alpha)
		_draw_node.draw_line(from_screen, to_screen, h_color, h_width)
		_draw_arrowhead(from_screen, to_screen, h_color, h_width)


func _draw_arrowhead(from_screen: Vector2, to_screen: Vector2,
					 color: Color, line_width: float) -> void:
	var dir  := (to_screen - from_screen).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip  := to_screen - dir * (NODE_RADIUS + 4.0)
	_draw_node.draw_line(tip - dir * 8.0 + perp * 5.0, tip, color, line_width * 0.8)
	_draw_node.draw_line(tip - dir * 8.0 - perp * 5.0, tip, color, line_width * 0.8)


func _draw_nodes(npcs: Array) -> void:
	var sg: SocialGraph = _world_ref.social_graph if _world_ref != null else null
	var any_state_hl: bool = not _states_highlighted.is_empty()

	for npc in npcs:
		var faction: String  = npc.npc_data.get("faction", "merchant")
		if _factions_hidden.get(faction, false):
			continue

		var screen_pos := _world_to_screen(npc.global_position)
		var fill:  Color           = FACTION_FILL.get(faction, Color.GRAY)
		var state: Rumor.RumorState = npc.get_worst_rumor_state()
		var ring:  Color           = STATE_RING_COLOR.get(state, Color.TRANSPARENT)
		var npc_id: String         = npc.npc_data.get("id", "")

		# Dim nodes whose state is not in the active highlight set.
		var node_alpha := 1.0
		if any_state_hl and not _states_highlighted.get(int(state), false):
			node_alpha = 0.22

		# Search match: pulsing gold ring.
		if not _search_target_id.is_empty() and npc_id == _search_target_id:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
			_draw_node.draw_circle(screen_pos,
				NODE_RADIUS * 1.9 + pulse * 5.0,
				Color(SEARCH_MATCH_COLOR.r, SEARCH_MATCH_COLOR.g, SEARCH_MATCH_COLOR.b,
					  (0.30 + 0.25 * pulse) * node_alpha))

		# Active rumor glow.
		if _npc_has_active_rumor(npc):
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.003)
			_draw_node.draw_circle(screen_pos, ACTIVE_RUMOR_GLOW_RADIUS,
				Color(ACTIVE_RUMOR_GLOW_COLOR.r, ACTIVE_RUMOR_GLOW_COLOR.g,
					  ACTIVE_RUMOR_GLOW_COLOR.b, ACTIVE_RUMOR_GLOW_COLOR.a * pulse * node_alpha))

		# Filled node.
		_draw_node.draw_circle(screen_pos, NODE_RADIUS,
			Color(fill.r, fill.g, fill.b, fill.a * node_alpha))

		# State ring (only when not UNAWARE).
		if ring.a > 0.01:
			_draw_node.draw_arc(
				screen_pos, NODE_RADIUS + RING_THICKNESS * 0.5,
				0.0, TAU, 24,
				Color(ring.r, ring.g, ring.b, ring.a * node_alpha),
				RING_THICKNESS)

		# Rumor count badge — top-right circle showing active slot count.
		var active_count := _count_active_rumor_slots(npc)
		if active_count > 0:
			var badge_pos := screen_pos + Vector2(NODE_RADIUS * 0.65, -NODE_RADIUS * 0.65)
			_draw_node.draw_circle(badge_pos, 7.0,
				Color(0.12, 0.08, 0.04, 0.90 * node_alpha))
			_draw_node.draw_arc(badge_pos, 7.0, 0.0, TAU, 16,
				Color(1.0, 0.70, 0.10, 0.95 * node_alpha), 1.5)
			_draw_node.draw_string(
				ThemeDB.fallback_font,
				badge_pos + Vector2(-4.5, 4.0),
				str(active_count),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(1.0, 0.90, 0.70, node_alpha))

		# Name label — dark pill for legibility.
		var npc_name: String = npc.npc_data.get("name", "?").split(" ")[0]
		var label_pos := screen_pos + Vector2(-NODE_RADIUS * 1.2, NODE_RADIUS + 12.0)
		var font_size_px := clamp(roundi(13.0 * _zoom_level), 10, 18)

		# When zoomed in above 1.2x show rep score inline with the name.
		var rep_inline := ""
		if _zoom_level > 1.2 and not npc_id.is_empty() and _world_ref != null \
				and "reputation_system" in _world_ref \
				and _world_ref.reputation_system != null:
			var snap: ReputationSystem.ReputationSnapshot = \
				_world_ref.reputation_system.get_snapshot(npc_id)
			if snap != null:
				rep_inline = " %d" % snap.score

		var display_name := npc_name + rep_inline
		var text_w: float = minf(ThemeDB.fallback_font.get_string_size(
			display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_px).x,
			NPC_LABEL_MAX_W)
		_draw_node.draw_rect(
			Rect2(label_pos + Vector2(-3, -12), Vector2(text_w + 6, 16)),
			Color(0.0, 0.0, 0.0, 0.65 * node_alpha))
		_draw_node.draw_string(
			ThemeDB.fallback_font, label_pos, display_name,
			HORIZONTAL_ALIGNMENT_LEFT, NPC_LABEL_MAX_W, font_size_px,
			Color(0.95, 0.95, 0.85, 0.95 * node_alpha))

		# Affinity bar (avg relationship weight — previously labelled "trust").
		if sg != null and not npc_id.is_empty():
			var avg_trust: float = _avg_trust(sg, npc_id)
			if avg_trust > 0.01:
				var bar_pos := label_pos + Vector2(0.0, 14.0)
				var bar_w   := 30.0
				var bar_h   :=  4.0
				_draw_node.draw_rect(
					Rect2(bar_pos + Vector2(-1, -5), Vector2(bar_w + 2, bar_h + 2)),
					Color(0.0, 0.0, 0.0, 0.55 * node_alpha))
				var tc := _trust_bar_color(avg_trust)
				_draw_node.draw_rect(
					Rect2(bar_pos + Vector2(0, -4),
						  Vector2(bar_w * clamp(avg_trust, 0.0, 1.0), bar_h)),
					Color(tc.r, tc.g, tc.b, tc.a * node_alpha))
				_draw_node.draw_string(
					ThemeDB.fallback_font,
					bar_pos + Vector2(bar_w + 4.0, -1.0),
					"%d%%" % roundi(avg_trust * 100.0),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					Color(tc.r, tc.g, tc.b, tc.a * node_alpha))

		# Reputation sub-label — below name when zoom ≤ 1.2x (inline above that).
		if _zoom_level <= 1.2 and not npc_id.is_empty() and _world_ref != null \
				and "reputation_system" in _world_ref \
				and _world_ref.reputation_system != null:
			var snap: ReputationSystem.ReputationSnapshot = \
				_world_ref.reputation_system.get_snapshot(npc_id)
			if snap != null:
				var rep_text  := "%d" % snap.score
				var rep_color := ReputationSystem.score_color(snap.score)
				var rep_pos   := label_pos + Vector2(0.0, 28.0)
				var rep_w: float = ThemeDB.fallback_font.get_string_size(
					rep_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				_draw_node.draw_rect(
					Rect2(rep_pos + Vector2(-3, -10), Vector2(rep_w + 6, 13)),
					Color(0.0, 0.0, 0.0, 0.55 * node_alpha))
				_draw_node.draw_string(
					ThemeDB.fallback_font, rep_pos, rep_text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					Color(rep_color.r, rep_color.g, rep_color.b, rep_color.a * node_alpha))


# ── Helpers: strength / trust / active rumor ─────────────────────────────────

func _edge_strength_color(weight: float) -> Color:
	if weight < 0.55:
		var t: float = clamp((weight - EDGE_THRESHOLD) / (0.55 - EDGE_THRESHOLD), 0.0, 1.0)
		return EDGE_WEAK_COLOR.lerp(EDGE_MEDIUM_COLOR, t)
	else:
		var t: float = clamp((weight - 0.55) / (1.0 - 0.55), 0.0, 1.0)
		return EDGE_MEDIUM_COLOR.lerp(EDGE_STRONG_COLOR, t)


func _avg_trust(sg: SocialGraph, npc_id: String) -> float:
	var neighbours: Dictionary = sg.get_neighbours(npc_id)
	if neighbours.is_empty():
		return 0.0
	var total: float = 0.0
	for tid in neighbours:
		total += float(neighbours[tid])
	return total / float(neighbours.size())


func _trust_bar_color(trust: float) -> Color:
	if trust >= 0.6:
		return Color(0.30, 0.90, 0.45, 0.90)
	elif trust >= 0.35:
		return Color(0.95, 0.80, 0.30, 0.90)
	else:
		return Color(0.95, 0.40, 0.25, 0.90)


func _npc_has_active_rumor(npc: Node2D) -> bool:
	for rid in npc.rumor_slots:
		var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
		if slot.state != Rumor.RumorState.UNAWARE and slot.state != Rumor.RumorState.EXPIRED:
			return true
	return false


func _count_active_rumor_slots(npc: Node2D) -> int:
	var count := 0
	for rid in npc.rumor_slots:
		var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
		if slot.state != Rumor.RumorState.UNAWARE and slot.state != Rumor.RumorState.EXPIRED:
			count += 1
	return count


# ── Legend ────────────────────────────────────────────────────────────────────

func _build_legend() -> void:
	_legend_panel = PanelContainer.new()
	_legend_panel.name = "SGLegend"
	# Anchored to right + bottom so it never overflows on any viewport size (SPA-1113).
	_legend_panel.set_anchor_and_offset(SIDE_RIGHT,  1.0, -10.0)
	_legend_panel.set_anchor_and_offset(SIDE_LEFT,   1.0, -220.0)
	_legend_panel.set_anchor_and_offset(SIDE_TOP,    0.0,  100.0)
	_legend_panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0,  -10.0)
	_legend_panel.custom_minimum_size = Vector2(210, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = Color(0.08, 0.05, 0.03, 0.92)
	panel_style.border_color = Color(0.55, 0.38, 0.18, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(6)
	_legend_panel.add_theme_stylebox_override("panel", panel_style)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(190, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_legend_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(vbox)

	# ── Mode toggle row ──────────────────────────────────────────────────────
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 4)

	_mode_btn_social = Button.new()
	_mode_btn_social.text = "Social Graph"
	_mode_btn_social.flat = false
	_mode_btn_social.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_btn_social.add_theme_font_size_override("font_size", 11)
	_mode_btn_social.pressed.connect(func() -> void: _set_heatmap_mode(false))
	mode_row.add_child(_mode_btn_social)

	_mode_btn_heatmap = Button.new()
	_mode_btn_heatmap.text = "Heatmap"
	_mode_btn_heatmap.flat = true
	_mode_btn_heatmap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_btn_heatmap.add_theme_font_size_override("font_size", 11)
	_mode_btn_heatmap.pressed.connect(func() -> void: _set_heatmap_mode(true))
	mode_row.add_child(_mode_btn_heatmap)

	vbox.add_child(mode_row)
	_legend_sep(vbox)

	# ── Social Graph legend section ──────────────────────────────────────────
	_sg_legend_box = VBoxContainer.new()
	_sg_legend_box.add_theme_constant_override("separation", 2)
	vbox.add_child(_sg_legend_box)

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content    = true
	title.append_text(
		"[b][color=white]Social Graph[/color][/b]  [color=gray][G to hide][/color]\n" +
		"[color=gray]Scroll: zoom  Drag: pan  Home: reset[/color]"
	)
	_sg_legend_box.add_child(title)
	_legend_sep(_sg_legend_box)

	_legend_header(_sg_legend_box, "Factions  [color=gray](click to hide)[/color]")
	_faction_btn(_sg_legend_box, "merchant", Color(0.85, 0.65, 0.10), "Merchant")
	_faction_btn(_sg_legend_box, "noble",    Color(0.424, 0.086, 0.165), "Noble")
	_faction_btn(_sg_legend_box, "clergy",   Color(0.88, 0.88, 0.88), "Clergy")
	_legend_sep(_sg_legend_box)

	_legend_header(_sg_legend_box, "Rumor State  [color=gray](click to highlight)[/color]")
	_state_btn(_sg_legend_box, Rumor.RumorState.EVALUATING,   Color(1.00, 1.00, 0.00), "Evaluating")
	_state_btn(_sg_legend_box, Rumor.RumorState.BELIEVE,      Color(0.00, 0.45, 0.70), "Believe")
	_state_btn(_sg_legend_box, Rumor.RumorState.REJECT,       Color(0.84, 0.37, 0.00), "Reject")
	_state_btn(_sg_legend_box, Rumor.RumorState.SPREAD,       Color(1.00, 0.50, 0.00), "Spread")
	_state_btn(_sg_legend_box, Rumor.RumorState.ACT,          Color(0.75, 0.05, 1.00), "Act")
	_state_btn(_sg_legend_box, Rumor.RumorState.DEFENDING,    Color(0.50, 0.80, 1.00), "Defending")
	_state_btn(_sg_legend_box, Rumor.RumorState.CONTRADICTED, Color(0.75, 0.55, 1.00), "Contradicted")
	_state_btn(_sg_legend_box, Rumor.RumorState.EXPIRED,      Color(0.40, 0.40, 0.40), "Expired")
	_legend_sep(_sg_legend_box)

	_legend_header(_sg_legend_box, "Edges")
	var edge_lbl := RichTextLabel.new()
	edge_lbl.bbcode_enabled = true
	edge_lbl.fit_content    = true
	edge_lbl.append_text(
		"[color=#1ad98c]—[/color] Active spread path\n" +
		"[color=#ff8000]—[/color] Recent transmission\n" +
		"[color=#e68c1a]—[/color] Trust fell\n" +
		"[color=#4d8ce6]—[/color] Trust rose\n" +
		"[color=#667388]—[/color] Weak  [color=#80bfe6]—[/color] Moderate  [color=#33ffb3]—[/color] Strong\n"
	)
	_sg_legend_box.add_child(edge_lbl)
	_legend_sep(_sg_legend_box)

	_legend_header(_sg_legend_box, "Other")
	var other_lbl := RichTextLabel.new()
	other_lbl.bbcode_enabled = true
	other_lbl.fit_content    = true
	other_lbl.append_text(
		"[color=#ffd91a]●[/color] Active rumor glow\n" +
		"▬ Affinity bar  (avg relationship)\n" +
		"[color=#ffa31a]⬤[/color] Rumor slot count badge\n" +
		"[color=#ffd700]72[/color] Rep score (zoom > 1.2×)\n"
	)
	_sg_legend_box.add_child(other_lbl)

	# ── Faction Heatmap legend section ───────────────────────────────────────
	_hm_legend_box = VBoxContainer.new()
	_hm_legend_box.add_theme_constant_override("separation", 2)
	_hm_legend_box.visible = false
	vbox.add_child(_hm_legend_box)

	var hm_title := RichTextLabel.new()
	hm_title.bbcode_enabled = true
	hm_title.fit_content    = true
	hm_title.append_text(
		"[b][color=white]Faction Influence[/color][/b]  [color=gray][G/Tab][/color]\n" +
		"[color=gray]Zones show faction presence per location[/color]"
	)
	_hm_legend_box.add_child(hm_title)
	_legend_sep(_hm_legend_box)

	_legend_header(_hm_legend_box, "Faction Colours")
	var fac_clr_lbl := RichTextLabel.new()
	fac_clr_lbl.bbcode_enabled = true
	fac_clr_lbl.fit_content    = true
	fac_clr_lbl.append_text(
		"[color=#d9a61a]■[/color] Merchant\n" +
		"[color=#6C162A]■[/color] Noble\n" +
		"[color=#e0e0e0]■[/color] Clergy\n"
	)
	_hm_legend_box.add_child(fac_clr_lbl)
	_legend_sep(_hm_legend_box)

	_legend_header(_hm_legend_box, "Overall Influence")
	_hm_legend_label = RichTextLabel.new()
	_hm_legend_label.bbcode_enabled = true
	_hm_legend_label.fit_content    = true
	_hm_legend_label.append_text("[color=gray]—[/color]")
	_hm_legend_box.add_child(_hm_legend_label)

	add_child(_legend_panel)
	_legend_panel.visible = false


func _legend_sep(vbox: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.55, 0.38, 0.18, 0.5))
	vbox.add_child(sep)


func _legend_header(vbox: VBoxContainer, text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content    = true
	lbl.append_text("[b]" + text + "[/b]")
	vbox.add_child(lbl)


func _faction_btn(vbox: VBoxContainer, faction_key: String,
				  color: Color, label: String) -> void:
	var btn := Button.new()
	btn.text         = "■ " + label
	btn.toggle_mode  = true
	btn.flat         = true
	btn.alignment    = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 36  # Touch-friendly sizing (SPA-713).
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color",         color)
	btn.add_theme_color_override("font_hover_color",   color.lightened(0.2))
	# Pressed appearance: dimmed to signal "hidden".
	btn.add_theme_color_override("font_pressed_color",
		Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 1.0))
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_factions_hidden[faction_key] = true
		else:
			_factions_hidden.erase(faction_key)
		# Smooth crossfade redraw (SPA-713).
		_crossfade_redraw()
	)
	vbox.add_child(btn)


func _state_btn(vbox: VBoxContainer, state: Rumor.RumorState,
				color: Color, label: String) -> void:
	var btn := Button.new()
	btn.text        = "■ " + label
	btn.toggle_mode = true
	btn.flat        = true
	btn.alignment   = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 36  # Touch-friendly sizing (SPA-713).
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color",         color)
	btn.add_theme_color_override("font_hover_color",   color.lightened(0.15))
	# Pressed appearance: brightened to signal "highlighted".
	btn.add_theme_color_override("font_pressed_color", color.lightened(0.35))
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_states_highlighted[int(state)] = true
		else:
			_states_highlighted.erase(int(state))
		# Smooth crossfade redraw (SPA-713).
		_crossfade_redraw()
	)
	vbox.add_child(btn)


# ── Crossfade redraw (SPA-713) ────────────────────────────────────────────────
## Smooth visual transition when toggling faction/state filters.  Fades the
## draw layer to 60% and back while triggering a redraw, giving the impression
## of a crossfade rather than an abrupt flicker.

var _crossfade_tween: Tween = null

func _crossfade_redraw() -> void:
	if _draw_node == null:
		return
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	_draw_node.modulate.a = 0.6
	_draw_node.queue_redraw()
	_crossfade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_crossfade_tween.tween_property(_draw_node, "modulate:a", 1.0, 0.2)


# ── Utilities ──────────────────────────────────────────────────────────────────

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	var base_screen := viewport.get_canvas_transform() * world_pos
	var center := viewport.get_visible_rect().size * 0.5
	return center + (base_screen - center) * _zoom_level + _pan_offset


func _find_npc_by_id(_npcs: Array, npc_id: String) -> Node2D:
	return _npc_lookup.get(npc_id, null)


# ── Faction Influence Heatmap ─────────────────────────────────────────────────

func _toggle_heatmap_mode() -> void:
	_set_heatmap_mode(not _heatmap_mode)


func _set_heatmap_mode(enabled: bool) -> void:
	_heatmap_mode = enabled
	if _sg_legend_box != null:
		_sg_legend_box.visible = not enabled
	if _hm_legend_box != null:
		_hm_legend_box.visible = enabled
	if _mode_btn_social != null:
		_mode_btn_social.flat = enabled        # flat = inactive look
	if _mode_btn_heatmap != null:
		_mode_btn_heatmap.flat = not enabled
	_draw_node.queue_redraw()


func _tick_heatmap_influence(delta: float) -> void:
	if _world_ref == null:
		return
	var targets := _compute_heatmap_targets()
	var lerp_t: float = clamp(delta * HEATMAP_LERP_SPEED, 0.0, 1.0)
	for loc in HEATMAP_LOCATIONS:
		if not _heatmap_influence.has(loc):
			_heatmap_influence[loc] = {}
		var target: Dictionary = targets.get(loc, {})
		var current: Dictionary = _heatmap_influence[loc]
		for f in ["merchant", "noble", "clergy"]:
			current[f] = lerpf(current.get(f, 0.0), target.get(f, 0.0), lerp_t)
		_heatmap_influence[loc] = current


func _compute_heatmap_targets() -> Dictionary:
	var result: Dictionary = {}
	for loc in HEATMAP_LOCATIONS:
		var counts: Dictionary = {}
		for npc in _world_ref.npcs:
			if npc.current_location_code == loc:
				var f: String = npc.npc_data.get("faction", "merchant")
				counts[f] = counts.get(f, 0) + 1
		var total: int = 0
		for f in counts:
			total += counts[f]
		var influence: Dictionary = {}
		if total > 0:
			for f in counts:
				influence[f] = float(counts[f]) / float(total)
		result[loc] = influence
	return result


func _update_heatmap_legend_label() -> void:
	var totals: Dictionary = {"merchant": 0.0, "noble": 0.0, "clergy": 0.0}
	var loc_count := 0
	for loc in HEATMAP_LOCATIONS:
		var inf: Dictionary = _heatmap_influence.get(loc, {})
		var has_anyone := false
		for f in ["merchant", "noble", "clergy"]:
			if inf.get(f, 0.0) > 0.01:
				has_anyone = true
				break
		if has_anyone:
			for f in totals:
				totals[f] += inf.get(f, 0.0)
			loc_count += 1
	var text := ""
	if loc_count > 0:
		for f in ["merchant", "noble", "clergy"]:
			var avg_pct: float = (totals[f] / float(loc_count)) * 100.0
			var hex: String
			match f:
				"merchant": hex = "#d9a61a"
				"noble":    hex = "#6C162A"
				_:          hex = "#e0e0e0"
			text += "[color=%s]■ %s[/color]  %d%%\n" % [hex, f.capitalize(), roundi(avg_pct)]
	else:
		text = "[color=gray]No NPCs at tracked locations[/color]"
	_hm_legend_label.clear()
	_hm_legend_label.append_text(text)


func _draw_heatmap() -> void:
	if not "_gathering_points" in _world_ref:
		return
	var gp: Dictionary = _world_ref._gathering_points
	for loc in HEATMAP_LOCATIONS:
		if not gp.has(loc):
			continue
		var cell: Vector2i = gp[loc]
		var world_pos := Vector2(
			float(cell.x - cell.y) * (HM_TILE_W * 0.5),
			float(cell.x + cell.y) * (HM_TILE_H * 0.5)
		)
		var screen_pos := _world_to_screen(world_pos)
		var influence: Dictionary = _heatmap_influence.get(loc, {})

		# Background dim circle.
		_draw_node.draw_circle(screen_pos, ZONE_RADIUS, Color(0.04, 0.02, 0.01, 0.50))

		# Faction pie slices.
		var total_inf: float = 0.0
		for f in ["merchant", "noble", "clergy"]:
			total_inf += influence.get(f, 0.0)

		if total_inf > 0.01:
			var start_angle := -PI * 0.5
			for f in ["merchant", "noble", "clergy"]:
				var fval: float = influence.get(f, 0.0)
				if fval < 0.005:
					start_angle += TAU * fval
					continue
				var arc_angle := TAU * fval
				var fc: Color = FACTION_FILL.get(f, Color.GRAY)
				var fill_alpha := clamp(0.25 + fval * 0.55, 0.0, 0.85)
				var slice_pts := _pie_slice_points(
					screen_pos, ZONE_RADIUS * 0.82, start_angle, start_angle + arc_angle)
				_draw_node.draw_polygon(slice_pts,
					PackedColorArray([Color(fc.r, fc.g, fc.b, fill_alpha)]))
				start_angle += arc_angle

		# Zone border ring.
		_draw_node.draw_arc(screen_pos, ZONE_RADIUS, 0.0, TAU, 48,
			Color(0.55, 0.38, 0.18, 0.55), 1.5)

		# Location name above zone.
		var loc_name: String = LOCATION_DISPLAY_NAMES.get(loc, loc)
		var name_sz: Vector2 = ThemeDB.fallback_font.get_string_size(
			loc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var name_pos := screen_pos + Vector2(-name_sz.x * 0.5, -ZONE_RADIUS - 6.0)
		_draw_node.draw_rect(
			Rect2(name_pos + Vector2(-3, -13), Vector2(name_sz.x + 6, 17)),
			Color(0.0, 0.0, 0.0, 0.65))
		_draw_node.draw_string(ThemeDB.fallback_font, name_pos, loc_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.90, 0.70, 0.95))

		# Faction percentages below zone.
		var pct_y := screen_pos.y + ZONE_RADIUS + 8.0
		var line_h := 13.0
		var line_idx := 0
		for f in ["merchant", "noble", "clergy"]:
			var fval: float = influence.get(f, 0.0)
			if fval < 0.005:
				continue
			var fc: Color = FACTION_FILL.get(f, Color.GRAY)
			var pct_str: String = "%s %d%%" % [f.substr(0, 3).to_upper(), roundi(fval * 100.0)]
			var str_w: float = ThemeDB.fallback_font.get_string_size(
				pct_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var px := screen_pos.x - str_w * 0.5
			_draw_node.draw_rect(
				Rect2(Vector2(px - 2, pct_y + line_idx * line_h - 10),
					  Vector2(str_w + 4, 13)),
				Color(0.0, 0.0, 0.0, 0.60))
			_draw_node.draw_string(ThemeDB.fallback_font,
				Vector2(px, pct_y + line_idx * line_h),
				pct_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(fc.r, fc.g, fc.b, 0.92))
			line_idx += 1


func _pie_slice_points(center: Vector2, radius: float,
		start_angle: float, end_angle: float, segments: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.push_back(center)
	var step: float = (end_angle - start_angle) / float(segments)
	for i in range(segments + 1):
		var a: float = start_angle + step * float(i)
		pts.push_back(center + Vector2(cos(a), sin(a)) * radius)
	return pts
