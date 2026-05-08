extends CanvasLayer

## rumor_tracker_hud.gd — SPA-911: Compact HUD showing active player-seeded rumors.
##
## Displayed in the lower-right corner during play.
## Shows each live player-seeded rumor (rp_ prefix) with:
##   • Claim type + subject name
##   • Believer reach (count of NPCs in BELIEVE / SPREAD / ACT for any lineage variant)
##   • Mutation generation (depth of longest live descendant chain)
##   • A filled bar representing reach vs. total NPC count
##
## Updates every game tick.  Auto-hides when no player rumors are active.
## Wire via setup(world, day_night) from main.gd.

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BG        := Color(0.10, 0.07, 0.05, 0.88)
const C_BORDER    := Color(0.55, 0.40, 0.18, 0.80)
const C_TITLE     := Color(0.90, 0.78, 0.40, 1.0)
const C_LABEL     := Color(0.80, 0.74, 0.60, 1.0)
const C_REACH_LOW := Color(0.95, 0.45, 0.25, 1.0)
const C_REACH_MED := Color(0.95, 0.78, 0.25, 1.0)
const C_REACH_HI  := Color(0.35, 0.90, 0.45, 1.0)
const C_MUT_LABEL := Color(0.60, 0.75, 1.00, 1.0)
const C_KEY_NPC   := Color(1.00, 0.90, 0.35, 1.0)

# Max rumors to show in the panel at once.
const MAX_ROWS := 4

# ── References ────────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null

# ── UI nodes ──────────────────────────────────────────────────────────────────
var _panel:      Panel         = null
var _vbox:       VBoxContainer = null
var _title_lbl:  Label         = null

# ── Key NPC flash state ───────────────────────────────────────────────────────
## npc_name → ticks remaining for flash highlight.
var _key_npc_flashes: Dictionary = {}
const _FLASH_DURATION: int = 8


func _ready() -> void:
	layer = 16   # Above scenario HUDs (14) and rumor panel (15).
	_build_ui()
	visible = false


func setup(world: Node2D, day_night: Node) -> void:
	_world_ref = world
	if day_night != null:
		day_night.game_tick.connect(_on_game_tick)
	if world != null and world.has_signal("rumor_reached_key_npc"):
		world.rumor_reached_key_npc.connect(_on_key_npc_reached)
	visible = true
	_refresh()


func _on_game_tick(_tick: int) -> void:
	# Decrement flash timers.
	for k in _key_npc_flashes.keys():
		_key_npc_flashes[k] -= 1
		if _key_npc_flashes[k] <= 0:
			_key_npc_flashes.erase(k)
	_refresh()


func _on_key_npc_reached(npc_name: String, _rumor_id: String) -> void:
	_key_npc_flashes[npc_name] = _FLASH_DURATION
	_refresh()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "RumorTrackerPanel"

	# Anchor to lower-right corner.
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right    = -8.0
	_panel.offset_bottom   = -8.0
	_panel.custom_minimum_size = Vector2(240, 32)

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.name = "VBox"
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(_vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 11)
	_title_lbl.add_theme_color_override("font_color", C_TITLE)
	_title_lbl.text = "Active Rumors"
	_vbox.add_child(_title_lbl)


# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _world_ref == null or _world_ref.get("propagation_engine") == null:
		return

	var engine: PropagationEngine = _world_ref.propagation_engine
	var live: Dictionary = engine.live_rumors

	# Collect root player-seeded rumors (rp_ prefix, no parent).
	var player_roots: Array = []
	for rid in live:
		var r: Rumor = live[rid]
		if str(rid).begins_with("rp_") and r.lineage_parent_id.is_empty():
			player_roots.append(r)

	# Hide panel when no active player rumors.
	_panel.visible = not player_roots.is_empty()
	if not _panel.visible:
		return

	# Clear existing rows (keep title label).
	for child in _vbox.get_children():
		if child != _title_lbl:
			child.queue_free()

	_title_lbl.text = "Rumors: %d active" % player_roots.size()

	var npc_count: int = _world_ref.npcs.size() if _world_ref.get("npcs") != null else 1

	var shown := 0
	for root_rumor in player_roots:
		if shown >= MAX_ROWS:
			break
		shown += 1
		_add_rumor_row(root_rumor, engine, npc_count)

	if player_roots.size() > MAX_ROWS:
		var overflow_lbl := Label.new()
		overflow_lbl.text = "  + %d more..." % (player_roots.size() - MAX_ROWS)
		overflow_lbl.add_theme_font_size_override("font_size", 10)
		overflow_lbl.add_theme_color_override("font_color", C_LABEL)
		overflow_lbl.clip_text = true
		_vbox.add_child(overflow_lbl)

	# Resize panel height to fit content.
	await get_tree().process_frame
	if is_instance_valid(_panel) and is_instance_valid(_vbox):
		_panel.custom_minimum_size = Vector2(240, _vbox.size.y + 12)


func _add_rumor_row(root: Rumor, engine: PropagationEngine, npc_count: int) -> void:
	# Collect all lineage rumor IDs (root + all descendants).
	var all_ids: Array = _collect_lineage(root.id, engine)

	# Count believers across all lineage variants.
	var reach: int = 0
	var key_npc_believers: Array = []
	var key_ids: Array = _world_ref.key_npc_ids if _world_ref.get("key_npc_ids") != null else []
	for npc in _world_ref.npcs:
		for lid in all_ids:
			if npc.rumor_slots.has(lid):
				var slot_state: int = (npc.rumor_slots[lid] as Rumor.NpcRumorSlot).state
				if slot_state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
					reach += 1
					var nid: String = npc.npc_data.get("id", "")
					if nid in key_ids:
						var nm: String = npc.npc_data.get("name", nid)
						if nm not in key_npc_believers:
							key_npc_believers.append(nm)
					break  # count each NPC once

	# Mutation depth: longest descendant chain depth.
	var mut_depth: int = _max_descendant_depth(root.id, engine)

	# Subject name.
	var subject_name := root.subject_npc_id
	for npc in _world_ref.npcs:
		if npc.npc_data.get("id", "") == root.subject_npc_id:
			subject_name = npc.npc_data.get("name", root.subject_npc_id)
			break

	# ── Row layout ────────────────────────────────────────────────────────────
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	_vbox.add_child(row)

	# Header: claim type + subject.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	row.add_child(header)

	var claim_lbl := Label.new()
	var claim_name: String = Rumor.claim_type_name(root.claim_type).capitalize()
	claim_lbl.text = "[%s] %s" % [claim_name, subject_name]
	claim_lbl.add_theme_font_size_override("font_size", 11)
	claim_lbl.add_theme_color_override("font_color", C_LABEL)
	claim_lbl.clip_text = true
	header.add_child(claim_lbl)

	# Mutation badge.
	if mut_depth > 0:
		var mut_lbl := Label.new()
		mut_lbl.text = " [M%d]" % mut_depth
		mut_lbl.add_theme_font_size_override("font_size", 10)
		mut_lbl.add_theme_color_override("font_color", C_MUT_LABEL)
		mut_lbl.tooltip_text = "Mutation depth: this rumor has %d generation(s) of variants" % mut_depth
		mut_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		mut_lbl.clip_text = true
		header.add_child(mut_lbl)

	# Reach bar + count.
	var reach_row := HBoxContainer.new()
	reach_row.add_theme_constant_override("separation", 4)
	row.add_child(reach_row)

	var reach_ratio: float = float(reach) / float(max(npc_count, 1))
	var bar_filled: int = clampi(roundi(reach_ratio * 10.0), 0, 10)
	var bar_str: String = "▇".repeat(bar_filled) + "░".repeat(10 - bar_filled)
	var reach_color: Color
	if reach_ratio >= 0.4:
		reach_color = C_REACH_HI
	elif reach_ratio >= 0.15:
		reach_color = C_REACH_MED
	else:
		reach_color = C_REACH_LOW

	var reach_lbl := Label.new()
	reach_lbl.text = "  %s  %d NPCs" % [bar_str, reach]
	reach_lbl.add_theme_font_size_override("font_size", 10)
	reach_lbl.add_theme_color_override("font_color", reach_color)
	reach_lbl.clip_text = true
	reach_row.add_child(reach_lbl)

	# Key NPC badges (flash if recently reached).
	for nm in key_npc_believers:
		var kn_lbl := Label.new()
		var is_flashing: bool = _key_npc_flashes.has(nm)
		kn_lbl.text = " ★%s" % nm
		kn_lbl.add_theme_font_size_override("font_size", 10)
		kn_lbl.add_theme_color_override("font_color",
			Color(1.0, 1.0, 0.3, 1.0) if is_flashing else C_KEY_NPC)
		kn_lbl.tooltip_text = "%s (key NPC) believes this rumor" % nm
		kn_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		kn_lbl.clip_text = true
		reach_row.add_child(kn_lbl)

	row.add_child(HSeparator.new())


# ── Lineage helpers ───────────────────────────────────────────────────────────

## Collect root ID and all live descendant IDs from the lineage registry.
func _collect_lineage(root_id: String, engine: PropagationEngine) -> Array:
	var result: Array = [root_id]
	var lineage: Dictionary = engine.lineage
	# Build a children map from the lineage.
	var children: Dictionary = {}
	for rid in lineage:
		var parent: String = str(lineage[rid].get("parent_id", ""))
		if parent.is_empty():
			continue
		if not children.has(parent):
			children[parent] = []
		children[parent].append(rid)
	# BFS from root.
	var queue: Array = [root_id]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if children.has(current):
			for child_id in children[current]:
				result.append(child_id)
				queue.append(child_id)
	return result


## Returns the maximum depth of live descendants below root_id (0 = no mutations).
func _max_descendant_depth(root_id: String, engine: PropagationEngine) -> int:
	var lineage: Dictionary = engine.lineage
	var children: Dictionary = {}
	for rid in lineage:
		var parent: String = str(lineage[rid].get("parent_id", ""))
		if parent.is_empty():
			continue
		if not children.has(parent):
			children[parent] = []
		children[parent].append(rid)
	return _depth_dfs(root_id, children, engine.live_rumors)


func _depth_dfs(node_id: String, children: Dictionary, live: Dictionary) -> int:
	if not children.has(node_id):
		return 0
	var max_child := 0
	for child_id in children[node_id]:
		if live.has(child_id):
			max_child = maxi(max_child, 1 + _depth_dfs(child_id, children, live))
	return max_child
