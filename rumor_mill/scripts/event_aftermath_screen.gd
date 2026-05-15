extends CanvasLayer

## event_aftermath_screen.gd — SPA-2691: Post-event resolution summary screen.
##
## Displayed immediately after the player resolves a mid-game narrative event
## (after dismissing the choice modal).  Shows:
##   - Event name
##   - Outcome narrative text
##   - Formatted list of stat deltas (reputation, heat, etc.)
##   - "Continue" button to resume the game
##
## Usage from UILayerManager:
##   var aftermath := preload("res://scripts/event_aftermath_screen.gd").new()
##   aftermath.name = "EventAftermathScreen"
##   add_child(aftermath)
##   # After event_choice_modal.dismissed fires:
##   aftermath.present(event_name, outcome_text, effects_dict, world)

# ── Palette (matches parchment card theme) ────────────────────────────────────

const C_BACKDROP  := Color(0.02, 0.01, 0.00, 0.78)
const C_PANEL_BG  := Color(0.08, 0.05, 0.02, 0.97)
const C_BORDER    := Color(0.60, 0.40, 0.12, 1.0)
const C_BADGE     := Color(0.85, 0.60, 0.20, 0.75)
const C_HEADING   := Color(0.96, 0.84, 0.40, 1.0)   # warm gold
const C_BODY      := Color(0.80, 0.72, 0.55, 1.0)   # parchment
const C_GOOD      := Color(0.50, 0.85, 0.45, 1.0)   # green delta
const C_BAD       := Color(0.92, 0.35, 0.28, 1.0)   # red delta
const C_NEUTRAL   := Color(0.65, 0.60, 0.45, 1.0)
const C_BTN_BG    := Color(0.30, 0.18, 0.05, 0.90)
const C_BTN_HOVER := Color(0.50, 0.30, 0.08, 1.0)
const C_BTN_TEXT  := Color(0.92, 0.82, 0.60, 1.0)

const PANEL_W     := 560.0
const PANEL_H     := 440.0
const REVEAL_TIME := 0.3

## Emitted when the player dismisses the aftermath and the game should resume.
signal aftermath_dismissed()

# ── Node refs ─────────────────────────────────────────────────────────────────

var _backdrop:      ColorRect      = null
var _panel:         Panel          = null
var _title_lbl:     Label          = null
var _outcome_lbl:   RichTextLabel  = null
var _deltas_lbl:    RichTextLabel  = null
var _continue_btn:  Button         = null

# ── State ─────────────────────────────────────────────────────────────────────

var _world: Node = null


func _ready() -> void:
	layer        = 22   # Above EventChoiceModal (21)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


## Present the aftermath screen after a mid-game event is resolved.
##
## event_name:   display name of the event (String)
## outcome_text: narrative outcome text (String)
## effects:      the raw effects Dictionary from scenarios.json choices
## world:        Node reference used to look up NPC names
func present(
	event_name: String,
	outcome_text: String,
	effects: Dictionary,
	world: Node
) -> void:
	_world = world
	_title_lbl.text = event_name

	_outcome_lbl.text = outcome_text

	var delta_lines: String = _format_effects(effects)
	if delta_lines.is_empty():
		_deltas_lbl.visible = false
	else:
		_deltas_lbl.text    = delta_lines
		_deltas_lbl.visible = true

	# Animate in.
	_backdrop.color.a = 0.0
	_panel.modulate.a = 0.0
	visible = true
	get_tree().paused = true

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_backdrop, "color:a", C_BACKDROP.a, REVEAL_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_panel, "modulate:a", 1.0, REVEAL_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _continue_btn.grab_focus())


# ── Effects Formatter ─────────────────────────────────────────────────────────

func _format_effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return ""

	var lines: PackedStringArray = PackedStringArray()

	# Reputation changes.
	var rep_changes: Array = effects.get("reputationChanges", [])
	for rc in rep_changes:
		var npc_id: String  = str(rc.get("npcId", ""))
		var delta: int      = int(rc.get("delta", 0))
		if delta == 0:
			continue
		var npc_name: String = _resolve_npc_name(npc_id)
		var sign: String     = "+" if delta > 0 else ""
		var col: String      = "green" if delta > 0 else "red"
		lines.append(
			"[color=%s]%s%d[/color] Reputation — %s" % [col, sign, delta, npc_name]
		)

	# Heat changes.
	var heat_changes: Array = effects.get("heatChanges", [])
	for hc in heat_changes:
		var npc_id: String = str(hc.get("npcId", ""))
		var delta: int     = int(hc.get("delta", 0))
		if delta == 0:
			continue
		var npc_name: String = _resolve_npc_name(npc_id)
		var sign: String     = "+" if delta > 0 else ""
		# More heat is bad for the player.
		var col: String      = "red" if delta > 0 else "green"
		lines.append(
			"[color=%s]%s%d[/color] Suspicion — %s" % [col, sign, delta, npc_name]
		)

	# Heat ceiling override.
	var hco: Dictionary = effects.get("heatCeilingOverride", {})
	if not hco.is_empty():
		var new_ceil: float = float(hco.get("newCeiling", 70))
		var dur: int        = int(hco.get("durationDays", 0))
		lines.append(
			"[color=orange]Heat ceiling set to %.0f for %d day%s[/color]" % [
				new_ceil, dur, "s" if dur != 1 else ""
			]
		)

	# Instant believers.
	var ib: Dictionary = effects.get("instantBelievers", {})
	if not ib.is_empty():
		var count: int       = int(ib.get("count", 0))
		var subject: String  = _resolve_npc_name(str(ib.get("subjectNpcId", "")))
		lines.append(
			"[color=green]+%d[/color] believe the rumour about %s" % [count, subject]
		)

	# Suspicion freeze.
	var freeze: int = int(effects.get("suspicionFreezeDays", 0))
	if freeze > 0:
		lines.append(
			"[color=green]Suspicion frozen for %d day%s[/color]" % [
				freeze, "s" if freeze != 1 else ""
			]
		)

	# Ability bonuses.
	var ability_bonuses: Array = effects.get("abilityBonuses", [])
	for ab in ability_bonuses:
		var ability: String = str(ab.get("ability", ""))
		var bonus: int      = int(ab.get("bonus", 0))
		if ability.is_empty() or bonus == 0:
			continue
		var sign: String = "+" if bonus > 0 else ""
		lines.append(
			"[color=green]%s%d[/color] %s" % [sign, bonus, ability.capitalize()]
		)

	return "\n".join(lines)


func _resolve_npc_name(npc_id: String) -> String:
	if npc_id.is_empty():
		return "unknown"
	if _world == null:
		return npc_id
	# Try world.get_npc_by_id if available.
	if _world.has_method("get_npc_by_id"):
		var npc: Node = _world.get_npc_by_id(npc_id)
		if npc != null and npc.get("npc_data") != null:
			var disp: String = str(npc.npc_data.get("displayName", ""))
			if not disp.is_empty():
				return disp
	# Fallback: prettify the id.
	return npc_id.replace("_", " ").capitalize()


# ── Build UI ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen dim backdrop.
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = C_BACKDROP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# Centred parchment panel.
	_panel = Panel.new()
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left   = -PANEL_W * 0.5
	_panel.offset_right  =  PANEL_W * 0.5
	_panel.offset_top    = -PANEL_H * 0.5
	_panel.offset_bottom =  PANEL_H * 0.5
	_panel.mouse_filter  = Control.MOUSE_FILTER_STOP

	# Apply parchment texture if available, else dark fallback.
	var parchment_tex: Texture2D = load("res://assets/textures/ui_parchment.png") \
		if ResourceLoader.exists("res://assets/textures/ui_parchment.png") \
		else null

	if parchment_tex != null:
		var sb_tex := StyleBoxTexture.new()
		sb_tex.texture = parchment_tex
		sb_tex.modulate_color = Color(0.22, 0.14, 0.06, 0.97)
		sb_tex.set_content_margin_all(24)
		_panel.add_theme_stylebox_override("panel", sb_tex)
	else:
		var sb_flat := StyleBoxFlat.new()
		sb_flat.bg_color = C_PANEL_BG
		sb_flat.border_color = C_BORDER
		sb_flat.set_border_width_all(2)
		sb_flat.set_corner_radius_all(8)
		sb_flat.set_content_margin_all(24)
		_panel.add_theme_stylebox_override("panel", sb_flat)
	add_child(_panel)

	# VBox content.
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 24
	vbox.offset_right  = -24
	vbox.offset_top    = 20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# "AFTERMATH" badge.
	var badge := Label.new()
	badge.text = "AFTERMATH"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", C_BADGE)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge)

	_add_divider(vbox)

	# Event title.
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", C_HEADING)
	_title_lbl.add_theme_constant_override("outline_size", 2)
	_title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 0.9))
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_lbl)

	_add_divider(vbox)

	# Outcome narrative.
	_outcome_lbl = RichTextLabel.new()
	_outcome_lbl.bbcode_enabled   = true
	_outcome_lbl.fit_content      = false
	_outcome_lbl.scroll_active    = true
	_outcome_lbl.custom_minimum_size = Vector2(0, 80)
	_outcome_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outcome_lbl.add_theme_color_override("default_color", C_BODY)
	_outcome_lbl.add_theme_font_size_override("normal_font_size", 14)
	_outcome_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_outcome_lbl)

	# Stat deltas section.
	var deltas_header := Label.new()
	deltas_header.text = "EFFECTS"
	deltas_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	deltas_header.add_theme_font_size_override("font_size", 11)
	deltas_header.add_theme_color_override("font_color", C_BADGE)
	deltas_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(deltas_header)

	_deltas_lbl = RichTextLabel.new()
	_deltas_lbl.bbcode_enabled      = true
	_deltas_lbl.fit_content         = true
	_deltas_lbl.scroll_active       = false
	_deltas_lbl.custom_minimum_size = Vector2(0, 0)
	_deltas_lbl.add_theme_color_override("default_color", C_NEUTRAL)
	_deltas_lbl.add_theme_font_size_override("normal_font_size", 13)
	_deltas_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_deltas_lbl)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# Continue button.
	var btn_center := CenterContainer.new()
	btn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_center)

	_continue_btn = Button.new()
	_continue_btn.text = "CONTINUE"
	_continue_btn.custom_minimum_size = Vector2(160, 38)
	_continue_btn.add_theme_font_size_override("font_size", 14)
	_continue_btn.add_theme_color_override("font_color", C_BTN_TEXT)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = C_BTN_BG
	btn_normal.border_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.8)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(5)
	btn_normal.set_content_margin_all(8)
	_continue_btn.add_theme_stylebox_override("normal",  btn_normal)
	_continue_btn.add_theme_stylebox_override("pressed", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = C_BTN_HOVER
	btn_hover.border_color = C_BORDER
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(5)
	btn_hover.set_content_margin_all(8)
	_continue_btn.add_theme_stylebox_override("hover", btn_hover)

	_continue_btn.pressed.connect(_on_continue_pressed)
	btn_center.add_child(_continue_btn)

	# Keyboard hint.
	var hint := Label.new()
	hint.text = "or press ENTER"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.60, 0.54, 0.40, 0.55))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hint)


func _add_divider(parent: VBoxContainer) -> void:
	var div := HSeparator.new()
	div.add_theme_constant_override("separation", 2)
	var style := StyleBoxLine.new()
	style.color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.45)
	style.thickness = 1
	div.add_theme_stylebox_override("separator", style)
	parent.add_child(div)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_on_continue_pressed()


# ── Dismiss ───────────────────────────────────────────────────────────────────

func _on_continue_pressed() -> void:
	if AudioManager != null and AudioManager.has_method("play_ui"):
		AudioManager.play_ui("click")
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_backdrop, "color:a", 0.0, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_panel, "modulate:a", 0.0, 0.20) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_finish_dismiss)


func _finish_dismiss() -> void:
	get_tree().paused = false
	visible = false
	aftermath_dismissed.emit()
