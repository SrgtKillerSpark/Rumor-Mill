extends CanvasLayer

## social_graph_overlay.gd — Sprint 6: Player-facing Social Graph View.
##
## G — toggle the overlay
##
## Inspired by CK3 relationship maps but simplified:
##   • NPC nodes:  faction-coloured circles, state-coloured ring/outline
##   • Edges:      social-graph connections weighted by opacity/thickness
##   • Legend:     faction palette + rumor state key (top-right panel)
##
## This is a player-facing feature (not debug). It draws on CanvasLayer 8,
## below the debug tools (10/20) but above the game world.

# ── Node colours ─────────────────────────────────────────────────────────────

const FACTION_FILL := {
	"merchant": Color(0.85, 0.65, 0.10, 1.0),   # warm gold
	"noble":    Color(0.35, 0.50, 0.85, 1.0),   # muted royal blue
	"clergy":   Color(0.88, 0.88, 0.88, 1.0),   # pale grey-white
}

const STATE_RING_COLOR := {
	Rumor.RumorState.UNAWARE:    Color(0.25, 0.25, 0.25, 0.0),   # invisible ring
	Rumor.RumorState.EVALUATING: Color(1.00, 1.00, 0.00, 1.0),
	Rumor.RumorState.BELIEVE:    Color(0.10, 0.90, 0.20, 1.0),
	Rumor.RumorState.REJECT:     Color(0.90, 0.15, 0.15, 1.0),
	Rumor.RumorState.SPREAD:     Color(1.00, 0.50, 0.00, 1.0),
	Rumor.RumorState.ACT:        Color(0.75, 0.05, 1.00, 1.0),
	Rumor.RumorState.EXPIRED:    Color(0.25, 0.25, 0.25, 0.6),
}

const EDGE_BASE_COLOR := Color(0.50, 0.80, 1.00, 1.0)

# Only draw edges above this weight threshold to reduce visual noise.
const EDGE_THRESHOLD := 0.30

# Node drawing sizes.
const NODE_RADIUS     := 9.0
const RING_THICKNESS  := 3.0

# ── State ─────────────────────────────────────────────────────────────────────

var visible_overlay: bool = false
var _world_ref: Node2D = null
var _draw_node: Node2D = null

# Legend panel (built once in _ready).
var _legend_panel:  PanelContainer = null
var _legend_label:  RichTextLabel  = null


func _ready() -> void:
	layer = 8
	_draw_node = Node2D.new()
	_draw_node.name = "SGDraw"
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw)

	_build_legend()
	visible = false   # The whole CanvasLayer starts hidden.


func set_world(world: Node2D) -> void:
	_world_ref = world


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			visible_overlay = not visible_overlay
			visible = visible_overlay
			_legend_panel.visible = visible_overlay
			_draw_node.queue_redraw()
			print("[SocialGraphOverlay] %s" % ("ON" if visible_overlay else "OFF"))


# ── Draw loop ──────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if visible_overlay:
		_draw_node.queue_redraw()


func _on_draw() -> void:
	if not visible_overlay or _world_ref == null:
		return

	var npcs: Array = _world_ref.npcs
	if npcs.is_empty():
		return

	var sg: SocialGraph = _world_ref.social_graph

	# ── Pass 1: edges ────────────────────────────────────────────────────────
	if sg != null:
		_draw_edges(npcs, sg)

	# ── Pass 2: nodes ────────────────────────────────────────────────────────
	_draw_nodes(npcs)


func _draw_edges(npcs: Array, sg: SocialGraph) -> void:
	# Draw each directed edge once (from_id < to_id lexicographic to avoid doubles).
	var drawn: Dictionary = {}

	for npc in npcs:
		var nid: String = npc.npc_data.get("id", "")
		var from_screen := _world_to_screen(npc.global_position)
		var neighbours: Dictionary = sg.get_neighbours(nid)

		for tid in neighbours:
			# Draw each pair only once.
			var key := nid + "|" + tid if nid < tid else tid + "|" + nid
			if drawn.has(key):
				continue
			drawn[key] = true

			var weight: float = neighbours[tid]
			if weight < EDGE_THRESHOLD:
				continue

			var target_npc := _find_npc_by_id(npcs, tid)
			if target_npc == null:
				continue

			var to_screen := _world_to_screen(target_npc.global_position)
			var alpha  := clamp((weight - EDGE_THRESHOLD) / (1.0 - EDGE_THRESHOLD), 0.05, 0.55)
			var width  := lerpf(0.5, 2.5, weight)
			var color  := Color(EDGE_BASE_COLOR.r, EDGE_BASE_COLOR.g, EDGE_BASE_COLOR.b, alpha)
			_draw_node.draw_line(from_screen, to_screen, color, width)


func _draw_nodes(npcs: Array) -> void:
	for npc in npcs:
		var screen_pos := _world_to_screen(npc.global_position)
		var faction: String = npc.npc_data.get("faction", "merchant")
		var fill   := FACTION_FILL.get(faction, Color.GRAY)
		var state  := npc.get_worst_rumor_state()
		var ring   := STATE_RING_COLOR.get(state, Color.TRANSPARENT)

		# Filled node.
		_draw_node.draw_circle(screen_pos, NODE_RADIUS, fill)

		# State ring (only drawn when not UNAWARE).
		if ring.a > 0.01:
			# Draw as an arc outline by drawing a slightly larger circle then
			# the fill circle on top. Godot 4 draw_arc handles this cleanly.
			_draw_node.draw_arc(
				screen_pos, NODE_RADIUS + RING_THICKNESS * 0.5,
				0.0, TAU, 24, ring, RING_THICKNESS
			)

		# Name label (small, rendered as a draw_string call).
		var npc_name: String = npc.npc_data.get("name", "?").split(" ")[0]  # first name only
		var label_pos := screen_pos + Vector2(-NODE_RADIUS * 1.2, NODE_RADIUS + 8.0)
		_draw_node.draw_string(
			ThemeDB.fallback_font,
			label_pos,
			npc_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			Color(0.95, 0.95, 0.85, 0.9)
		)


# ── Legend ─────────────────────────────────────────────────────────────────────

func _build_legend() -> void:
	_legend_panel = PanelContainer.new()
	_legend_panel.name = "SGLegend"

	# Anchor top-right.
	_legend_panel.set_anchor_and_offset(SIDE_RIGHT,  1.0, -210.0)
	_legend_panel.set_anchor_and_offset(SIDE_LEFT,   1.0, -210.0)
	_legend_panel.set_anchor_and_offset(SIDE_TOP,    0.0,   10.0)
	_legend_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.0,  230.0)
	_legend_panel.custom_minimum_size = Vector2(195, 215)

	_legend_label = RichTextLabel.new()
	_legend_label.bbcode_enabled = true
	_legend_label.fit_content    = true
	_legend_label.custom_minimum_size = Vector2(180, 200)

	_legend_label.append_text("[b][color=white]Social Graph View[/color][/b]  [color=gray][G to hide][/color]\n\n")
	_legend_label.append_text("[b]Factions[/b]\n")
	_legend_label.append_text("[color=#d9a91a]■[/color] Merchant\n")
	_legend_label.append_text("[color=#5980d9]■[/color] Noble\n")
	_legend_label.append_text("[color=#e0e0e0]■[/color] Clergy\n\n")
	_legend_label.append_text("[b]Rumor State (ring)[/b]\n")
	_legend_label.append_text("[color=#ffff00]■[/color] Evaluating\n")
	_legend_label.append_text("[color=#1ae633]■[/color] Believe\n")
	_legend_label.append_text("[color=#e62626]■[/color] Reject\n")
	_legend_label.append_text("[color=#ff8000]■[/color] Spread\n")
	_legend_label.append_text("[color=#bf0dff]■[/color] Act\n")
	_legend_label.append_text("[color=#404040]■[/color] Expired\n")

	_legend_panel.add_child(_legend_label)
	add_child(_legend_panel)
	_legend_panel.visible = false


# ── Utilities ──────────────────────────────────────────────────────────────────

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	var canvas_transform := viewport.get_canvas_transform()
	return canvas_transform * world_pos


func _find_npc_by_id(npcs: Array, npc_id: String) -> Node2D:
	for npc in npcs:
		if npc.npc_data.get("id", "") == npc_id:
			return npc
	return null
