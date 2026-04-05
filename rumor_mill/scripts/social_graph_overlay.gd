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
	"noble":    Color(0.424, 0.086, 0.165, 1.0),  # NOBLE_BODY burgundy (#6C162A)
	"clergy":   Color(0.88, 0.88, 0.88, 1.0),   # pale grey-white
}

const STATE_RING_COLOR := {
	Rumor.RumorState.UNAWARE:       Color(0.25, 0.25, 0.25, 0.0),   # invisible ring
	Rumor.RumorState.EVALUATING:    Color(1.00, 1.00, 0.00, 1.0),
	Rumor.RumorState.BELIEVE:       Color(0.10, 0.90, 0.20, 1.0),
	Rumor.RumorState.REJECT:        Color(0.90, 0.15, 0.15, 1.0),
	Rumor.RumorState.SPREAD:        Color(1.00, 0.50, 0.00, 1.0),
	Rumor.RumorState.ACT:           Color(0.75, 0.05, 1.00, 1.0),
	Rumor.RumorState.DEFENDING:     Color(0.50, 0.80, 1.00, 1.0),   # sky blue — matches npc.gd STATE_TINT
	Rumor.RumorState.CONTRADICTED:  Color(0.75, 0.55, 1.00, 1.0),   # muted purple — matches npc.gd STATE_TINT
	Rumor.RumorState.EXPIRED:       Color(0.25, 0.25, 0.25, 0.6),
}

const EDGE_BASE_COLOR := Color(0.50, 0.80, 1.00, 1.0)

# Edge colour ramp by relationship weight (weak → strong).
const EDGE_WEAK_COLOR   := Color(0.40, 0.45, 0.55, 1.0)   # cool grey — low bond
const EDGE_MEDIUM_COLOR := Color(0.50, 0.75, 0.90, 1.0)   # soft blue — moderate bond
const EDGE_STRONG_COLOR := Color(0.20, 1.00, 0.70, 1.0)   # vivid teal — strong bond

# Active rumor glow on NPC nodes.
const ACTIVE_RUMOR_GLOW_COLOR := Color(1.0, 0.85, 0.10, 0.35)  # warm gold pulse
const ACTIVE_RUMOR_GLOW_RADIUS := 20.0

# Mutated edge tints: orange = trust decreased, blue = trust increased.
const EDGE_MUTATED_NEG_COLOR := Color(0.90, 0.55, 0.10, 1.0)
const EDGE_MUTATED_POS_COLOR := Color(0.30, 0.55, 0.90, 1.0)

# Persistent teal glow on edges where either endpoint is actively SPREADING.
const LIVE_SPREAD_EDGE_COLOR := Color(0.10, 0.85, 0.55, 0.65)
const LIVE_SPREAD_EDGE_WIDTH := 2.5

# Only draw edges above this weight threshold to reduce visual noise.
const EDGE_THRESHOLD := 0.30

# Node drawing sizes (scaled to match 48×72 NPC sprites).
const NODE_RADIUS     := 12.0
const RING_THICKNESS  := 4.0

# ── State ─────────────────────────────────────────────────────────────────────

var visible_overlay: bool = false
var _world_ref: Node2D = null
var _draw_node: Node2D = null
var _fade_tween: Tween = null

# Legend panel (built once in _ready).
var _legend_panel:  PanelContainer = null
var _legend_label:  RichTextLabel  = null

# Recent rumor transmissions: "from_id|to_id" → time_remaining (seconds).
# Populated by on_rumor_event(); edges glow while time_remaining > 0.
const SPREAD_HIGHLIGHT_DURATION := 3.0
const SPREAD_HIGHLIGHT_COLOR    := Color(1.0, 0.6, 0.0, 0.9)  # vivid orange
var _active_spread_edges: Dictionary = {}   # key → float (seconds remaining)


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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			visible_overlay = not visible_overlay
			if _fade_tween != null and _fade_tween.is_valid():
				_fade_tween.kill()
			if visible_overlay:
				visible = true
				_legend_panel.visible = true
				_draw_node.modulate.a = 0.0
				_legend_panel.modulate.a = 0.0
				_fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				_fade_tween.tween_property(_draw_node, "modulate:a", 1.0, 0.2)
				_fade_tween.parallel().tween_property(_legend_panel, "modulate:a", 1.0, 0.2)
			else:
				_fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				_fade_tween.tween_property(_draw_node, "modulate:a", 0.0, 0.15)
				_fade_tween.parallel().tween_property(_legend_panel, "modulate:a", 0.0, 0.15)
				_fade_tween.tween_callback(func() -> void:
					visible = false
					_legend_panel.visible = false
				)
			_draw_node.queue_redraw()
			get_viewport().set_input_as_handled()


# ── Draw loop ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if visible_overlay:
		_draw_node.queue_redraw()

	# Decay active spread edge highlight timers regardless of overlay visibility
	# so they're ready when the overlay opens.
	if not _active_spread_edges.is_empty():
		var expired: Array = []
		for key in _active_spread_edges:
			_active_spread_edges[key] -= delta
			if _active_spread_edges[key] <= 0.0:
				expired.append(key)
		for key in expired:
			_active_spread_edges.erase(key)


## Called by main.gd _on_rumor_event.  Parses transmission messages of the form
## "Alice whispered to Bob [rumor_id]" and highlights the social-graph edge.
func on_rumor_event(message: String) -> void:
	# We only care about transmission events ("X whispered to Y").
	if not message.contains(" whispered to "):
		return
	if _world_ref == null:
		return

	# Parse names — format: "FromName whispered to ToName [id]"
	var parts := message.split(" whispered to ", false)
	if parts.size() < 2:
		return
	var from_name := parts[0].strip_edges()
	var to_part   := parts[1].split(" [", false)
	var to_name   := to_part[0].strip_edges()

	# Resolve NPC ids from names.
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

	# Store the edge key in canonical order (smaller id first).
	var key := from_id + "|" + to_id if from_id < to_id else to_id + "|" + from_id
	_active_spread_edges[key] = SPREAD_HIGHLIGHT_DURATION


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
	# Precompute which NPC ids are actively spreading any rumor right now.
	var spreading_ids: Dictionary = {}   # npc_id → true
	for npc in npcs:
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state == Rumor.RumorState.SPREAD:
				spreading_ids[npc.npc_data.get("id", "")] = true
				break

	# Draw each directed edge once (from_id < to_id lexicographic to avoid doubles).
	var drawn: Dictionary = {}

	for npc in npcs:
		var nid: String = npc.npc_data.get("id", "")
		var from_screen := _world_to_screen(npc.global_position)
		var neighbours: Dictionary = sg.get_neighbours(nid)

		for tid in neighbours:
			# Draw each pair only once.
			var key: String = nid + "|" + (tid as String) if nid < (tid as String) else (tid as String) + "|" + nid
			if drawn.has(key):
				continue
			drawn[key] = true

			var target_npc := _find_npc_by_id(npcs, tid)
			if target_npc == null:
				continue

			var to_screen  := _world_to_screen(target_npc.global_position)
			var weight: float = neighbours[tid]

			# Check active spread BEFORE the weight threshold so sub-threshold
			# social-graph edges still show the event pulse.
			if _active_spread_edges.has(key):
				# Highlight: bright orange, thickness scaled by time remaining.
				var t: float = float(_active_spread_edges[key]) / SPREAD_HIGHLIGHT_DURATION
				var h_alpha := lerpf(0.2, 0.9, t)
				var h_width := lerpf(1.5, 4.0, t)
				var h_color := Color(SPREAD_HIGHLIGHT_COLOR.r, SPREAD_HIGHLIGHT_COLOR.g,
									 SPREAD_HIGHLIGHT_COLOR.b, h_alpha)
				_draw_node.draw_line(from_screen, to_screen, h_color, h_width)
				# Arrowhead at the receiver end to show rumor direction.
				var arr_dir := (to_screen - from_screen).normalized()
				var arr_perp := Vector2(-arr_dir.y, arr_dir.x)
				var arr_tip := to_screen - arr_dir * (NODE_RADIUS + 4.0)
				_draw_node.draw_line(arr_tip - arr_dir * 8.0 + arr_perp * 5.0, arr_tip, h_color, h_width * 0.8)
				_draw_node.draw_line(arr_tip - arr_dir * 8.0 - arr_perp * 5.0, arr_tip, h_color, h_width * 0.8)
			elif weight < EDGE_THRESHOLD:
				continue
			elif spreading_ids.has(nid) or spreading_ids.has(tid):
				# Persistent teal glow: either endpoint is actively spreading a rumor.
				_draw_node.draw_line(from_screen, to_screen,
									 LIVE_SPREAD_EDGE_COLOR, LIVE_SPREAD_EDGE_WIDTH)
			else:
				var alpha := clamp((weight - EDGE_THRESHOLD) / (1.0 - EDGE_THRESHOLD), 0.10, 0.65)
				var width := lerpf(0.5, 2.5, weight)
				# Check for social graph mutations in either direction.
				var mut_fwd: float = sg.get_net_mutation(nid, tid)
				var mut_rev: float = sg.get_net_mutation(tid, nid)
				var base_color: Color
				if mut_fwd < -0.001 or mut_rev < -0.001:
					base_color = EDGE_MUTATED_NEG_COLOR
				elif mut_fwd > 0.001 or mut_rev > 0.001:
					base_color = EDGE_MUTATED_POS_COLOR
				else:
					# Colour-code by relationship strength.
					base_color = _edge_strength_color(weight)
				_draw_node.draw_line(from_screen, to_screen,
									 Color(base_color.r, base_color.g, base_color.b, alpha), width)

	# Second pass: draw active spread edges for proximity-only pairs that have
	# no social graph entry at all (main loop only iterates sg.get_neighbours).
	for key in _active_spread_edges:
		if drawn.has(key):
			continue  # already handled in main loop
		var parts: PackedStringArray = (key as String).split("|")
		if parts.size() != 2:
			continue
		var npc_a := _find_npc_by_id(npcs, parts[0])
		var npc_b := _find_npc_by_id(npcs, parts[1])
		if npc_a == null or npc_b == null:
			continue
		var from_screen := _world_to_screen(npc_a.global_position)
		var to_screen   := _world_to_screen(npc_b.global_position)
		var t: float = float(_active_spread_edges[key]) / SPREAD_HIGHLIGHT_DURATION
		var h_alpha := lerpf(0.2, 0.9, t)
		var h_width := lerpf(1.5, 4.0, t)
		var h_color := Color(SPREAD_HIGHLIGHT_COLOR.r, SPREAD_HIGHLIGHT_COLOR.g,
							 SPREAD_HIGHLIGHT_COLOR.b, h_alpha)
		_draw_node.draw_line(from_screen, to_screen, h_color, h_width)
		# Arrowhead at receiver end.
		var arr_dir2 := (to_screen - from_screen).normalized()
		var arr_perp2 := Vector2(-arr_dir2.y, arr_dir2.x)
		var arr_tip2 := to_screen - arr_dir2 * (NODE_RADIUS + 4.0)
		_draw_node.draw_line(arr_tip2 - arr_dir2 * 8.0 + arr_perp2 * 5.0, arr_tip2, h_color, h_width * 0.8)
		_draw_node.draw_line(arr_tip2 - arr_dir2 * 8.0 - arr_perp2 * 5.0, arr_tip2, h_color, h_width * 0.8)


func _draw_nodes(npcs: Array) -> void:
	var sg: SocialGraph = _world_ref.social_graph if _world_ref != null else null
	for npc in npcs:
		var screen_pos := _world_to_screen(npc.global_position)
		var faction: String = npc.npc_data.get("faction", "merchant")
		var fill: Color = FACTION_FILL.get(faction, Color.GRAY)
		var state: Rumor.RumorState = npc.get_worst_rumor_state()
		var ring: Color = STATE_RING_COLOR.get(state, Color.TRANSPARENT)

		# Active rumor glow — draw a soft halo behind NPCs involved in any rumor.
		var has_active_rumor: bool = _npc_has_active_rumor(npc)
		if has_active_rumor:
			var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.003)
			var glow_col := Color(ACTIVE_RUMOR_GLOW_COLOR.r, ACTIVE_RUMOR_GLOW_COLOR.g,
								  ACTIVE_RUMOR_GLOW_COLOR.b, ACTIVE_RUMOR_GLOW_COLOR.a * pulse)
			_draw_node.draw_circle(screen_pos, ACTIVE_RUMOR_GLOW_RADIUS, glow_col)

		# Filled node.
		_draw_node.draw_circle(screen_pos, NODE_RADIUS, fill)

		# State ring (only drawn when not UNAWARE).
		if ring.a > 0.01:
			_draw_node.draw_arc(
				screen_pos, NODE_RADIUS + RING_THICKNESS * 0.5,
				0.0, TAU, 24, ring, RING_THICKNESS
			)

		# Name label — drawn with a dark background pill for legibility over any background.
		var npc_name: String = npc.npc_data.get("name", "?").split(" ")[0]  # first name only
		var label_pos := screen_pos + Vector2(-NODE_RADIUS * 1.2, NODE_RADIUS + 12.0)
		var font_size_px := 13
		var text_w: float = ThemeDB.fallback_font.get_string_size(npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_px).x
		_draw_node.draw_rect(
			Rect2(label_pos + Vector2(-3, -12), Vector2(text_w + 6, 16)),
			Color(0.0, 0.0, 0.0, 0.65)
		)
		_draw_node.draw_string(
			ThemeDB.fallback_font,
			label_pos,
			npc_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size_px,
			Color(0.95, 0.95, 0.85, 0.95)
		)

		var npc_id: String = npc.npc_data.get("id", "")

		# Trust level bar — average relationship weight from social graph.
		if sg != null and not npc_id.is_empty():
			var avg_trust: float = _avg_trust(sg, npc_id)
			if avg_trust > 0.01:
				var bar_pos := label_pos + Vector2(0.0, 14.0)
				var bar_w: float = 30.0
				var bar_h: float = 4.0
				# Background track.
				_draw_node.draw_rect(
					Rect2(bar_pos + Vector2(-1, -5), Vector2(bar_w + 2, bar_h + 2)),
					Color(0.0, 0.0, 0.0, 0.55)
				)
				# Filled portion.
				var trust_color := _trust_bar_color(avg_trust)
				_draw_node.draw_rect(
					Rect2(bar_pos + Vector2(0, -4), Vector2(bar_w * clamp(avg_trust, 0.0, 1.0), bar_h)),
					trust_color
				)
				# Trust label next to bar.
				var trust_text := "%d%%" % roundi(avg_trust * 100.0)
				_draw_node.draw_string(
					ThemeDB.fallback_font,
					bar_pos + Vector2(bar_w + 4.0, -1.0),
					trust_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					10,
					trust_color
				)

		# Reputation score sub-label — shown if reputation system is available.
		if not npc_id.is_empty() and _world_ref != null \
				and "reputation_system" in _world_ref and _world_ref.reputation_system != null:
			var snap: ReputationSystem.ReputationSnapshot = \
				_world_ref.reputation_system.get_snapshot(npc_id)
			if snap != null:
				var rep_text := "%d" % snap.score
				var rep_color: Color = ReputationSystem.score_color(snap.score)
				var rep_pos := label_pos + Vector2(0.0, 28.0)
				var rep_w: float = ThemeDB.fallback_font.get_string_size(rep_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				_draw_node.draw_rect(
					Rect2(rep_pos + Vector2(-3, -10), Vector2(rep_w + 6, 13)),
					Color(0.0, 0.0, 0.0, 0.55)
				)
				_draw_node.draw_string(
					ThemeDB.fallback_font,
					rep_pos,
					rep_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					11,
					rep_color
				)


# ── Helpers: strength / trust / active rumor ─────────────────────────────────

## Lerp edge colour from EDGE_WEAK_COLOR → EDGE_MEDIUM_COLOR → EDGE_STRONG_COLOR based on weight.
func _edge_strength_color(weight: float) -> Color:
	if weight < 0.55:
		var t: float = clamp((weight - EDGE_THRESHOLD) / (0.55 - EDGE_THRESHOLD), 0.0, 1.0)
		return EDGE_WEAK_COLOR.lerp(EDGE_MEDIUM_COLOR, t)
	else:
		var t: float = clamp((weight - 0.55) / (1.0 - 0.55), 0.0, 1.0)
		return EDGE_MEDIUM_COLOR.lerp(EDGE_STRONG_COLOR, t)


## Average social graph weight for an NPC across all their neighbours.
func _avg_trust(sg: SocialGraph, npc_id: String) -> float:
	var neighbours: Dictionary = sg.get_neighbours(npc_id)
	if neighbours.is_empty():
		return 0.0
	var total: float = 0.0
	for tid in neighbours:
		total += float(neighbours[tid])
	return total / float(neighbours.size())


## Colour for the trust bar: red → amber → green.
func _trust_bar_color(trust: float) -> Color:
	if trust >= 0.6:
		return Color(0.30, 0.90, 0.45, 0.90)
	elif trust >= 0.35:
		return Color(0.95, 0.80, 0.30, 0.90)
	else:
		return Color(0.95, 0.40, 0.25, 0.90)


## Whether an NPC has any rumor slot in an active state (not UNAWARE / EXPIRED).
func _npc_has_active_rumor(npc: Node2D) -> bool:
	for rid in npc.rumor_slots:
		var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
		if slot.state != Rumor.RumorState.UNAWARE and slot.state != Rumor.RumorState.EXPIRED:
			return true
	return false


# ── Legend ─────────────────────────────────────────────────────────────────────

func _build_legend() -> void:
	_legend_panel = PanelContainer.new()
	_legend_panel.name = "SGLegend"

	# Anchor top-right.
	_legend_panel.set_anchor_and_offset(SIDE_RIGHT,  1.0, -210.0)
	_legend_panel.set_anchor_and_offset(SIDE_LEFT,   1.0, -210.0)
	_legend_panel.set_anchor_and_offset(SIDE_TOP,    0.0,   10.0)
	_legend_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.0,  383.0)
	_legend_panel.custom_minimum_size = Vector2(195, 368)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.03, 0.92)
	style.border_color = Color(0.55, 0.38, 0.18, 1.0)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_legend_panel.add_theme_stylebox_override("panel", style)

	_legend_label = RichTextLabel.new()
	_legend_label.bbcode_enabled = true
	_legend_label.fit_content    = true
	_legend_label.custom_minimum_size = Vector2(180, 353)

	_legend_label.append_text("[b][color=white]Social Graph View[/color][/b]  [color=gray][G to hide][/color]\n\n")
	_legend_label.append_text("[b]Factions[/b]\n")
	_legend_label.append_text("[color=#d9a91a]■[/color] Merchant\n")
	_legend_label.append_text("[color=#6C162A]■[/color] Noble\n")
	_legend_label.append_text("[color=#e0e0e0]■[/color] Clergy\n\n")
	_legend_label.append_text("[b]Rumor State (ring)[/b]\n")
	_legend_label.append_text("[color=#ffff00]■[/color] Evaluating\n")
	_legend_label.append_text("[color=#1ae633]■[/color] Believe\n")
	_legend_label.append_text("[color=#e62626]■[/color] Reject\n")
	_legend_label.append_text("[color=#ff8000]■[/color] Spread\n")
	_legend_label.append_text("[color=#bf0dff]■[/color] Act\n")
	_legend_label.append_text("[color=#80ccff]■[/color] Defending\n")
	_legend_label.append_text("[color=#bf8cff]■[/color] Contradicted\n")
	_legend_label.append_text("[color=#404040]■[/color] Expired\n\n")
	_legend_label.append_text("[b]Edges[/b]\n")
	_legend_label.append_text("[color=#1ad98c]—[/color] Active spread path\n")
	_legend_label.append_text("[color=#ff8000]—[/color] Recent transmission\n")
	_legend_label.append_text("[color=#e68c1a]—[/color] Trust fell (NPC acted on rumor)\n")
	_legend_label.append_text("[color=#4d8ce6]—[/color] Trust rose (NPC spread praise)\n")
	_legend_label.append_text("[color=#667388]—[/color] Weak bond\n")
	_legend_label.append_text("[color=#80bfe6]—[/color] Moderate bond\n")
	_legend_label.append_text("[color=#33ffb3]—[/color] Strong bond\n\n")
	_legend_label.append_text("[b]Other[/b]\n")
	_legend_label.append_text("[color=#ffd91a]●[/color] Active rumor glow\n")
	_legend_label.append_text("▬ Trust level bar\n")

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
