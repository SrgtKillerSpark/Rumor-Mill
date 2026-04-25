## npc_visuals.gd — Sprite, state tints, heat shimmer, and flash VFX for NPC (SPA-1009).
## Extracted from npc.gd.  Owns the AnimatedSprite2D setup, faction badge,
## hover/selection ring, thought bubble, and all flash/glow/emote effects.
## Call setup() from npc.init_from_data().

class_name NpcVisuals
extends Node

# Suppress duplicate "npc_sprites.png not found" warnings across all NPC instances.
static var _sprite_missing_warned: bool = false

# ── Sprite sheet layout constants ─────────────────────────────────────────────
const FACTION_ROW := {"merchant": 0, "noble": 1, "clergy": 2}
const ARCHETYPE_ROW := {
	"guard_civic": 3, "tavern_staff": 5, "scholar": 6, "elder": 7, "spy": 8,
}
const COMMONER_ROLES := [
	"Craftsman", "Mill Operator", "Storage Keeper", "Transport Worker",
	"Merchant's Wife", "Traveling Merchant",
]
const BODY_TYPE_ROW_OFFSET := 9
const CLOTHING_VAR_BASE    := {"merchant": 27, "noble": 30, "clergy": 33}
const SPRITE_W     := 64
const SPRITE_H     := 96
const _IDLE_S_COL  := 0
const _WALK_S_COL  := 2
const _IDLE_N_COL  := 5
const _WALK_N_COL  := 7
const _IDLE_E_COL  := 10
const _WALK_E_COL  := 12
const _IDLE_FRAMES := 2
const _WALK_FRAMES := 3

# ── State tints ───────────────────────────────────────────────────────────────
const STATE_TINT := {
	Rumor.RumorState.UNAWARE:      Color(1.00, 1.00, 1.00, 1.0),
	Rumor.RumorState.EVALUATING:   Color(1.00, 1.00, 0.70, 1.0),
	Rumor.RumorState.BELIEVE:      Color(0.70, 1.00, 0.72, 1.0),
	Rumor.RumorState.SPREAD:       Color(1.00, 0.75, 0.45, 1.0),
	Rumor.RumorState.ACT:          Color(1.00, 0.55, 0.90, 1.0),
	Rumor.RumorState.REJECT:       Color(0.80, 0.80, 0.85, 1.0),
	Rumor.RumorState.CONTRADICTED: Color(0.75, 0.55, 1.00, 1.0),
	Rumor.RumorState.EXPIRED:      Color(0.65, 0.65, 0.65, 1.0),
	Rumor.RumorState.DEFENDING:    Color(0.50, 0.80, 1.00, 1.0),
}
## SPA-777: cool cyan-white hover tint applied directly to sprite.modulate.
const NPC_HOVER_TINT := Color(1.0, 1.6, 1.8, 1.0)

# ── Emote icons per state ─────────────────────────────────────────────────────
const STATE_EMOTES: Dictionary = {
	"EVALUATING": "🤔",
	"BELIEVE":    "💡",
	"SPREAD":     "📢",
	"ACT":        "⚡",
	"REJECT":     "✋",
	"DEFENDING":  "🛡️",
}

# ── Module state ──────────────────────────────────────────────────────────────
var _npc:         Node2D          = null
var _sprite:      AnimatedSprite2D = null
var _name_label:  Label           = null

var _faction_badge:  ColorRect  = null
var _selection_ring: Polygon2D  = null
var _thought_bubble: NpcThoughtBubble = null
var _flash_tween:    Tween      = null
var _emote_tween:    Tween      = null
var _ripple_tween:   Tween      = null

## Exposed so npc._draw() can read them for draw_arc().
var _ripple_radius: float = 0.0
var _ripple_alpha:  float = 0.0

var _cached_state_tint: Color = Color.WHITE
var _heat_pulse_phase:  float = 0.0
var _prev_heat:         float = 0.0
var _hovered:           bool  = false


# ── Initialisation ────────────────────────────────────────────────────────────

func setup(npc: Node2D, sprite: AnimatedSprite2D, name_label: Label, faction: String) -> void:
	_npc        = npc
	_sprite     = sprite
	_name_label = name_label
	setup_sprite(faction)
	_build_faction_badge(faction)
	_thought_bubble = NpcThoughtBubble.new()
	_npc.add_child(_thought_bubble)


func setup_sprite(faction: String) -> void:
	var tex := load("res://assets/textures/npc_sprites.png") as Texture2D
	if tex == null:
		if not _sprite_missing_warned:
			push_warning("NPC: npc_sprites.png not found; NPC sprites will not display")
			_sprite_missing_warned = true
		return

	var npc_archetype: String = _npc.npc_data.get("archetype", "")
	var npc_role:      String = _npc.npc_data.get("role", "")
	var body_type:   int      = clampi(_npc.npc_data.get("body_type", 0), 0, 2)
	var clothing_var: int     = clampi(_npc.npc_data.get("clothing_var", 0), 0, 3)
	var row: int
	if ARCHETYPE_ROW.has(npc_archetype):
		row = ARCHETYPE_ROW[npc_archetype] + body_type * BODY_TYPE_ROW_OFFSET
	elif npc_role in COMMONER_ROLES:
		row = 4 + body_type * BODY_TYPE_ROW_OFFSET
	elif clothing_var > 0 and CLOTHING_VAR_BASE.has(faction):
		row = CLOTHING_VAR_BASE[faction] + (clothing_var - 1)
	else:
		row = FACTION_ROW.get(faction, 0) + body_type * BODY_TYPE_ROW_OFFSET

	var frames := SpriteFrames.new()
	var _add_anim := func(anim: String, start_col: int, count: int, fps: float) -> void:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		frames.set_animation_loop(anim, true)
		for i in range(count):
			var at := AtlasTexture.new()
			at.atlas  = tex
			at.region = Rect2((start_col + i) * SPRITE_W, row * SPRITE_H, SPRITE_W, SPRITE_H)
			frames.add_frame(anim, at)

	_add_anim.call("idle_south", _IDLE_S_COL, _IDLE_FRAMES, 3.0)
	_add_anim.call("walk_south", _WALK_S_COL, _WALK_FRAMES, 8.0)
	_add_anim.call("idle_north", _IDLE_N_COL, _IDLE_FRAMES, 3.0)
	_add_anim.call("walk_north", _WALK_N_COL, _WALK_FRAMES, 8.0)
	_add_anim.call("idle_east",  _IDLE_E_COL, _IDLE_FRAMES, 3.0)
	_add_anim.call("walk_east",  _WALK_E_COL, _WALK_FRAMES, 8.0)

	_sprite.sprite_frames = frames
	_sprite.play("idle_south")


func _build_faction_badge(faction: String) -> void:
	var badge := ColorRect.new()
	badge.color               = FactionPalette.badge_color(faction)
	badge.custom_minimum_size = Vector2(8, 8)
	badge.size                = Vector2(8, 8)
	badge.position = Vector2(_name_label.position.x - 11, _name_label.position.y + 6)
	var outline := ColorRect.new()
	outline.color               = Color(0, 0, 0, 0.6)
	outline.custom_minimum_size = Vector2(10, 10)
	outline.size                = Vector2(10, 10)
	outline.position = Vector2(badge.position.x - 1, badge.position.y - 1)
	_npc.add_child(outline)
	_npc.add_child(badge)
	_faction_badge = badge


# ── Per-tick label + tint update ──────────────────────────────────────────────

## Refresh the name label text, state tint, emote, thought bubble, and
## state-change signals.  Called each tick from npc.on_tick().
func update_label(faction: String, dialogue: NpcDialogue) -> void:
	var worst:      Rumor.RumorState = _npc.get_worst_rumor_state()
	var state_str:  String           = Rumor.state_name(worst)
	var short_name: String           = _npc.npc_data.get("name", "NPC")
	var faction_abbr := {"merchant": "M", "noble": "N", "clergy": "C"}.get(faction, "")

	if _npc.rumor_slots.is_empty():
		_name_label.text = "%s [%s]" % [short_name, faction_abbr] if faction_abbr != "" else short_name
	else:
		_name_label.text = "%s\n[%s]" % [short_name, state_str]

	_cached_state_tint = STATE_TINT.get(worst, Color.WHITE)
	if not _hovered and _sprite != null and _sprite.sprite_frames != null:
		if get_heat() < 50.0:
			_sprite.modulate = _cached_state_tint

	# Emit state-change signal on transitions so journal + overlay react.
	if worst != _npc._last_worst_state:
		_npc._last_worst_state = worst
		var wrid := ""
		for rid in _npc.rumor_slots:
			if _npc.rumor_slots[rid].state == worst:
				wrid = rid
				break
		_npc.rumor_state_changed.emit(short_name, state_str, wrid,
			_npc._slot_diagnostics.get(wrid, ""))
		show_state_emote(state_str)
		# SPA-751: sprite scale bounce on high-impact belief transitions.
		if (worst == Rumor.RumorState.BELIEVE or worst == Rumor.RumorState.ACT) \
				and _sprite != null:
			var _sb := _npc.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_sb.tween_property(_sprite, "scale", Vector2(1.18, 1.18), 0.12)
			_sb.tween_property(_sprite, "scale", Vector2.ONE, 0.22)
		# SPA-861: conviction flash — thought bubble override for key transitions.
		if _thought_bubble != null:
			match worst:
				Rumor.RumorState.BELIEVE:
					_thought_bubble.show_override("✓", Color(0.40, 1.00, 0.50, 1.0), 1.4)
				Rumor.RumorState.ACT:
					_thought_bubble.show_override("!!", Color(1.00, 0.40, 0.90, 1.0), 1.2)
				Rumor.RumorState.REJECT:
					_thought_bubble.show_override("✗", Color(0.80, 0.55, 0.55, 1.0), 1.0)
		# Reaction dialogue bubble.
		var cat: String = _npc._state_to_dialogue_category(worst)
		if cat != "" and dialogue != null:
			dialogue.show_bubble(cat)

	# SPA-695: refresh thought bubble every tick.
	if _thought_bubble != null:
		_thought_bubble.refresh(worst)


# ── Heat shimmer (per-frame) ──────────────────────────────────────────────────

func get_heat() -> float:
	if _npc.propagation_engine_ref == null \
			or _npc.propagation_engine_ref.intel_store_ref == null \
			or not _npc.propagation_engine_ref.intel_store_ref.heat_enabled:
		return 0.0
	return _npc.propagation_engine_ref.intel_store_ref.get_heat(_npc.npc_data.get("id", ""))


## Heat shimmer per-frame logic.  Called from npc._process(delta).
## Also emits suspicion_danger when heat crosses 75 upward.
func process_heat(delta: float) -> void:
	var h := get_heat()
	if _prev_heat < 75.0 and h >= 75.0:
		_npc.suspicion_danger.emit(_npc.npc_data.get("name", "NPC"))
	_prev_heat = h
	if _hovered or _sprite == null or _sprite.sprite_frames == null:
		return
	if h < 50.0:
		return  # _update_label sets sprite.modulate directly when heat is low
	_heat_pulse_phase += delta * (3.0 if h >= 75.0 else 2.0)
	var pulse := sin(_heat_pulse_phase) * 0.5 + 0.5
	var heat_color: Color = \
		Color(1.45, 0.40, 0.25, 1.0) if h >= 75.0 else Color(1.30, 0.65, 0.35, 1.0)
	_sprite.modulate = _cached_state_tint.lerp(heat_color, pulse * 0.45)


# ── Hover / selection ─────────────────────────────────────────────────────────

func set_hover(hovered: bool) -> void:
	_hovered = hovered
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _hovered:
		_sprite.modulate = NPC_HOVER_TINT
		var _hw := _npc.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hw.tween_property(_sprite, "scale", Vector2(1.08, 1.08), 0.10)
		_hw.tween_property(_sprite, "scale", Vector2.ONE, 0.15)
	else:
		if get_heat() < 50.0:
			_sprite.modulate = STATE_TINT.get(_npc.get_worst_rumor_state(), Color.WHITE)


## Shows or hides the gold diamond selection ring drawn under the NPC.
func set_selected(selected: bool) -> void:
	if selected:
		if _selection_ring != null and is_instance_valid(_selection_ring):
			return  # already showing
		var ring := Polygon2D.new()
		ring.polygon = PackedVector2Array([
			Vector2(0, -18), Vector2(24, 0), Vector2(0, 18), Vector2(-24, 0)
		])
		ring.color    = Color(1.0, 0.85, 0.20, 0.60)
		ring.position = Vector2(0, 8)
		ring.z_index  = -1
		_npc.add_child(ring)
		_selection_ring = ring
	else:
		if _selection_ring != null and is_instance_valid(_selection_ring):
			_selection_ring.queue_free()
		_selection_ring = null


# ── SPA-561: Ripple ring ──────────────────────────────────────────────────────

## Expanding ripple ring when a rumor spreads from this NPC.
## _ripple_radius and _ripple_alpha are read by npc._draw() via this module.
func show_spread_ripple() -> void:
	_ripple_radius = 8.0
	_ripple_alpha  = 0.7
	if _ripple_tween != null and _ripple_tween.is_valid():
		_ripple_tween.kill()
	_ripple_tween = _npc.create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ripple_tween.tween_method(func(_v: float) -> void: _npc.queue_redraw(), 0.0, 1.0, 0.45)
	_ripple_tween.tween_property(self, "_ripple_radius", 48.0, 0.45)
	_ripple_tween.tween_property(self, "_ripple_alpha",  0.0,  0.45)


# ── Flash / glow effects ──────────────────────────────────────────────────────

## Brief colour flash on the NPC sprite when reputation changes.
func flash_reputation(gained: bool) -> void:
	if _sprite == null:
		return
	var flash_color := Color(0.4, 1.0, 0.5, 1.0) if gained else Color(1.0, 0.3, 0.2, 1.0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.self_modulate = flash_color
	_flash_tween = _npc.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_sprite, "self_modulate", Color.WHITE, 0.35)


## SPA-788: Dark vignette flash signalling a conviction shift.
func flash_belief_vignette() -> void:
	if _sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.self_modulate = Color(0.12, 0.12, 0.18, 1.0)
	_flash_tween = _npc.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_sprite, "self_modulate", Color.WHITE, 0.55)


## SPA-909: Warm greeting bob when the player initiates dialogue.
func flash_interaction_greeting() -> void:
	if _sprite == null:
		return
	_sprite.self_modulate = Color(1.5, 1.4, 1.0, 1.0)
	var _ct := _npc.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ct.tween_property(_sprite, "self_modulate", Color.WHITE, 0.35)
	var _bt := _npc.create_tween()
	_bt.tween_property(_sprite, "position:y", _sprite.position.y - 4.0, 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bt.tween_property(_sprite, "position:y", 0.0, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## SPA-909: Red shrink-pulse when a player action is rejected.
func flash_action_failed() -> void:
	if _sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.self_modulate = Color(1.9, 0.45, 0.45, 1.0)
	_flash_tween = _npc.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_sprite, "self_modulate", Color.WHITE, 0.42)
	_sprite.scale = Vector2.ONE
	var _ss := _npc.create_tween()
	_ss.tween_property(_sprite, "scale", Vector2(0.87, 0.87), 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_ss.tween_property(_sprite, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Floating emote icon above the NPC on rumor state change.
func show_state_emote(state_name: String) -> void:
	var icon: String = STATE_EMOTES.get(state_name, "")
	if icon.is_empty():
		return
	var lbl := Label.new()
	lbl.text = icon
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position  = Vector2(12.0, -76.0)
	lbl.modulate.a = 0.0
	_npc.add_child(lbl)
	if _emote_tween != null and _emote_tween.is_valid():
		_emote_tween.kill()
	_emote_tween = _npc.create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lbl.scale = Vector2(0.5, 0.5)
	_emote_tween.tween_property(lbl, "modulate:a", 1.0, 0.12)
	_emote_tween.tween_property(lbl, "scale", Vector2.ONE, 0.2)
	_emote_tween.chain().tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(1.0)
	_emote_tween.chain().tween_callback(lbl.queue_free)


## Brief highlight flash when the player clicks to select/interact with this NPC.
## SPA-869: also plays a quick scale pulse.
func flash_click() -> void:
	if _sprite == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	_sprite.self_modulate = Color(2.0, 1.8, 0.8, 1.0)
	_flash_tween = _npc.create_tween()
	_flash_tween.tween_property(_sprite, "self_modulate", Color.WHITE, 0.28)
	_sprite.scale = Vector2.ONE
	var _sp := _npc.create_tween()
	_sp.tween_property(_sprite, "scale", Vector2(1.1, 1.1), 0.075) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sp.tween_property(_sprite, "scale", Vector2.ONE, 0.075) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## SPA-777: Floating name + faction label when the player clicks this NPC.
func show_name_popup() -> void:
	var npc_name: String = _npc.npc_data.get("name", "?")
	var faction:  String = _npc.npc_data.get("faction", "")
	var text: String = npc_name if faction.is_empty() \
		else "%s\n[%s]" % [npc_name, faction.capitalize()]
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-32.0, -88.0)
	_npc.add_child(lbl)
	var tw := _npc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -16.0), 1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tw.chain().tween_callback(lbl.queue_free)


## SPA-777: Cyan glow flash when this NPC receives a new rumor.
func show_rumor_received_glow() -> void:
	if _sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.self_modulate = Color(0.6, 2.0, 1.8, 1.0)
	_flash_tween = _npc.create_tween()
	_flash_tween.tween_property(_sprite, "self_modulate", Color.WHITE, 0.50)


## SPA-903: Warm amber burst when the player targets this NPC with a seeded rumor.
func flash_seed_confirmation() -> void:
	if _sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.self_modulate = Color(1.8, 1.2, 0.4, 1.0)
	_flash_tween = _npc.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_sprite, "self_modulate", Color.WHITE, 0.45)
	_sprite.scale = Vector2.ONE
	var _sp := _npc.create_tween()
	_sp.tween_property(_sprite, "scale", Vector2(1.12, 1.12), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sp.tween_property(_sprite, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Floating coin-burst confirming a successful bribe.
func show_bribed_effect() -> void:
	var lbl := Label.new()
	lbl.text = "🪙"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.position = Vector2(-8.0, -72.0)
	lbl.modulate = Color(1.0, 0.90, 0.2, 1.0)
	_npc.add_child(lbl)
	var tw := _npc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -20.0), 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.3)
	tw.chain().tween_callback(lbl.queue_free)


## Floating "+N" / "−N" label indicating a reputation change.
func show_reputation_change(delta: int) -> void:
	if delta == 0:
		return
	flash_reputation(delta > 0)
	var lbl := Label.new()
	lbl.text = ("+" if delta > 0 else "") + str(delta)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.position = Vector2(-10.0, -68.0)
	lbl.modulate = Color(0.784, 0.635, 0.180, 1.0) if delta > 0 \
		else Color(0.698, 0.149, 0.149, 1.0)
	_npc.add_child(lbl)
	var tw := _npc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -18.0), 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)


## Subtle muted "!" when suspicion is raised (STONE_L colour, no bloom).
func show_suspicion_raised() -> void:
	var lbl := Label.new()
	lbl.text = "!"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(-4.0, -72.0)
	lbl.modulate = Color(0.635, 0.612, 0.545, 1.0)
	_npc.add_child(lbl)
	var tw := _npc.create_tween()
	tw.tween_property(lbl, "modulate:a", 0.3, 0.25)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.50).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)


## SPA-788: Apply / remove the belief-shaken speed penalty (0.72× for rest of day).
## Skipped for GUARD_CIVIC — their pace is owned by TownMoodController.
func set_belief_shaken(shaken: bool) -> void:
	if _npc.archetype == NpcSchedule.ScheduleArchetype.GUARD_CIVIC:
		return
	_npc.mood_speed_scale = 0.72 if shaken else 1.0
