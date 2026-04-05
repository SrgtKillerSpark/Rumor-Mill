extends CanvasLayer

## npc_conversation_overlay.gd — Visual conversation indicators between nearby NPCs.
## SPA-211: Tier 2, Item #7.
##
## Always visible (no toggle):
##   • Subtle dashed lines between NPC pairs within CONVO_RANGE Manhattan tiles.
##   • Line colour reflects social graph relationship quality.
##   • Glow pulse on the line when a rumor transmission occurs.
##   • Small speech-bubble "..." indicator above NPCs actively transmitting.

const CONVO_RANGE_MANHATTAN := 3        ## Tile range for showing a proximity line
const PULSE_DURATION        := 1.5     ## Seconds the glow lingers after a transmission

# Base line colours (alpha encodes subtlety)
const COL_STRONG := Color(0.90, 0.70, 0.30, 0.40)   # warm amber — close allies (≥ 0.7)
const COL_MEDIUM := Color(0.60, 0.60, 0.60, 0.22)   # neutral grey (0.3–0.7)
const COL_WEAK   := Color(0.40, 0.50, 0.60, 0.12)   # cool faint (< 0.3)

# Transmission pulse colour
const COL_PULSE  := Color(1.00, 0.80, 0.20, 0.90)   # bright gold

# Speech-bubble dot colour
const COL_BUBBLE := Color(1.00, 1.00, 0.70, 0.90)

var _world_ref: Node2D = null
var _draw_node: Node2D = null

## npc_id → float seconds remaining for the transmission indicator.
var _active_convos: Dictionary = {}

## Array of { from_pos, to_pos, ttl } for directional whisper lines drawn on
## transmission events where the two NPCs are beyond CONVO_RANGE_MANHATTAN.
var _whisper_lines: Array = []


func _ready() -> void:
	layer = 3    # below ObjectiveHUD (4) and SocialGraphOverlay (8), above world
	_draw_node = Node2D.new()
	_draw_node.name = "ConvoDraw"
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw)


func setup(world: Node2D) -> void:
	_world_ref = world
	for npc in world.npcs:
		npc.rumor_transmitted.connect(_on_rumor_transmitted)


func _process(delta: float) -> void:
	_draw_node.queue_redraw()
	if not _active_convos.is_empty():
		var expired: Array = []
		for nid in _active_convos:
			_active_convos[nid] -= delta
			if _active_convos[nid] <= 0.0:
				expired.append(nid)
		for nid in expired:
			_active_convos.erase(nid)
	if not _whisper_lines.is_empty():
		var keep: Array = []
		for entry in _whisper_lines:
			entry["ttl"] -= delta
			if entry["ttl"] > 0.0:
				keep.append(entry)
		_whisper_lines = keep


func _on_rumor_transmitted(from_name: String, to_name: String, _rumor_id: String) -> void:
	if _world_ref == null:
		return
	var from_node = null
	var to_node   = null
	for npc in _world_ref.npcs:
		var n: String = npc.npc_data.get("name", "")
		if n == from_name:
			_active_convos[npc.npc_data.get("id", "")] = PULSE_DURATION
			from_node = npc
		elif n == to_name:
			_active_convos[npc.npc_data.get("id", "")] = PULSE_DURATION
			to_node = npc

	# For long-range transmissions (> CONVO_RANGE_MANHATTAN), draw a one-shot
	# directional whisper line so the player can see the rumor leap across distance.
	if from_node != null and to_node != null:
		var cell_a: Vector2i = from_node.current_cell
		var cell_b: Vector2i = to_node.current_cell
		var manhattan: int = abs(cell_a.x - cell_b.x) + abs(cell_a.y - cell_b.y)
		if manhattan > CONVO_RANGE_MANHATTAN:
			_whisper_lines.append({
				"from_pos": from_node.global_position,
				"to_pos":   to_node.global_position,
				"ttl":      PULSE_DURATION,
			})


func _on_draw() -> void:
	if _world_ref == null:
		return
	var npcs: Array = _world_ref.npcs
	if npcs.is_empty():
		return

	var sg: SocialGraph = _world_ref.social_graph
	var drawn: Dictionary = {}    # canonical pair key → true

	# ── Pass 1: proximity lines ──────────────────────────────────────────────────
	for i in range(npcs.size()):
		var npc_a = npcs[i]
		var aid: String    = npc_a.npc_data.get("id", "")
		var cell_a: Vector2i = npc_a.current_cell
		var pos_a  := _world_to_screen(npc_a.global_position)

		for j in range(i + 1, npcs.size()):
			var npc_b = npcs[j]
			var bid: String      = npc_b.npc_data.get("id", "")
			var cell_b: Vector2i = npc_b.current_cell

			var manhattan: int = abs(cell_a.x - cell_b.x) + abs(cell_a.y - cell_b.y)
			if manhattan > CONVO_RANGE_MANHATTAN:
				continue

			var key := aid + "|" + bid if aid < bid else bid + "|" + aid
			if drawn.has(key):
				continue
			drawn[key] = true

			var pos_b := _world_to_screen(npc_b.global_position)
			var is_pulsing: bool = _active_convos.has(aid) or _active_convos.has(bid)

			if is_pulsing:
				# Animate: brightness and width scale with time remaining.
				var t_a: float = _active_convos.get(aid, 0.0)
				var t_b: float = _active_convos.get(bid, 0.0)
				var t: float   = maxf(t_a, t_b) / PULSE_DURATION
				var col := Color(COL_PULSE.r, COL_PULSE.g, COL_PULSE.b, t * COL_PULSE.a)
				_draw_node.draw_dashed_line(pos_a, pos_b, col, lerpf(1.5, 3.0, t), 6.0)
			else:
				# Colour by relationship strength.
				var weight: float = 0.0
				if sg != null:
					var nb: Dictionary = sg.get_neighbours(aid)
					weight = nb.get(bid, 0.0)
				var col: Color
				if weight >= 0.7:
					col = COL_STRONG
				elif weight >= 0.3:
					col = COL_MEDIUM
				else:
					col = COL_WEAK
				_draw_node.draw_dashed_line(pos_a, pos_b, col, 1.0, 5.0)

	# ── Pass 2: directional whisper lines for long-range transmissions ───────────
	for entry in _whisper_lines:
		var t: float = entry["ttl"] / PULSE_DURATION
		var from_s := _world_to_screen(entry["from_pos"])
		var to_s   := _world_to_screen(entry["to_pos"])
		# Fade from vivid gold to transparent as ttl decreases.
		var col := Color(1.00, 0.75, 0.20, t * 0.75)
		_draw_node.draw_dashed_line(from_s, to_s, col, lerpf(1.0, 2.5, t), 8.0)
		# Small arrowhead at the receiver end.
		var dir := (to_s - from_s).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var tip  := to_s - dir * 6.0
		_draw_node.draw_line(tip, to_s, col, lerpf(1.0, 2.5, t))
		_draw_node.draw_line(tip + perp * 4.0, to_s, col, 1.0)
		_draw_node.draw_line(tip - perp * 4.0, to_s, col, 1.0)

	# ── Pass 3: speech-bubble above actively conversing NPCs ────────────────────
	for npc in npcs:
		var nid: String = npc.npc_data.get("id", "")
		if not _active_convos.has(nid):
			continue
		var t: float = _active_convos[nid] / PULSE_DURATION
		var screen_pos := _world_to_screen(npc.global_position)
		# Bubble floats upward as it fades out.
		var float_offset: float = lerpf(0.0, -8.0, 1.0 - t)
		var bubble_pos := screen_pos + Vector2(12.0, -34.0 + float_offset)
		var alpha: float = t * COL_BUBBLE.a

		# Larger dark pill background for clear readability.
		_draw_node.draw_rect(
			Rect2(bubble_pos - Vector2(13, 9), Vector2(30, 18)),
			Color(0.08, 0.05, 0.02, alpha * 0.90)
		)
		# Gold border ring for visual pop against any background.
		_draw_node.draw_rect(
			Rect2(bubble_pos - Vector2(13, 9), Vector2(30, 18)),
			Color(COL_PULSE.r, COL_PULSE.g, COL_PULSE.b, alpha * 0.65),
			false,
			1.0
		)
		# Whisper icon "✦" — more distinctive than plain "...".
		_draw_node.draw_string(
			ThemeDB.fallback_font,
			bubble_pos + Vector2(-9, 6),
			"✦ ·",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(COL_BUBBLE.r, COL_BUBBLE.g, COL_BUBBLE.b, alpha)
		)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	return viewport.get_canvas_transform() * world_pos
