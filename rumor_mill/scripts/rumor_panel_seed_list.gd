class_name RumorPanelSeedList
extends RefCounted

## rumor_panel_seed_list.gd — Panel 3 seed-target list builder.
##
## Extracted from rumor_panel.gd (SPA-1014). Owns evidence-section rendering,
## chain-indicator display, spread/believability per-entry stats, and the
## recommended-seed badge (SPA-758). Evidence tutorial tracking also lives here.
##
## Call setup() once refs are known. Call build() on each Panel 3 open.

# ── Palette ───────────────────────────────────────────────────────────────────

const C_NPC_NAME             := Color(0.88, 0.80, 0.60, 1.0)
const C_GOLD                 := Color(0.90, 0.75, 0.20, 1.0)
const C_STATUS_WARN          := Color(1.0,  0.65, 0.20, 1.0)
const C_ESTIMATE             := Color(0.75, 0.85, 0.65, 1.0)
const C_CHAIN_DESC           := Color(0.95, 0.95, 0.85, 1.0)
const C_COMPAT_HINT          := Color(0.60, 0.60, 0.58, 0.90)
const C_SELECTED_SEED_BG     := Color(0.50, 0.25, 0.10, 0.55)
const C_SELECTED_EVIDENCE_BG := Color(0.45, 0.30, 0.05, 0.55)
const C_EVIDENCE_TYPE        := Color(0.95, 0.85, 0.50, 1.0)
const C_EVIDENCE_ATTACHED    := Color(0.35, 0.90, 0.50, 1.0)
const C_BOOST_BAR            := Color(0.35, 0.88, 0.52, 1.0)

const C_FACTION_MERCHANT := Color(1.0,  0.80, 0.20, 1.0)
const C_FACTION_NOBLE    := Color(0.40, 0.60, 1.0,  1.0)
const C_FACTION_CLERGY   := Color(0.90, 0.90, 0.90, 1.0)

# ── State ─────────────────────────────────────────────────────────────────────

## Set to true once the "Recommended" badge has been shown for the first S1 open.
var seed_recommended_shown: bool = false

## Set to true the first time compatible evidence items are shown to the player.
var evidence_tutorial_fired: bool = false

# ── Refs ──────────────────────────────────────────────────────────────────────

var _world_ref:       Node2D               = null
var _intel_store_ref: PlayerIntelStore     = null
var _estimates:       RumorPanelEstimates  = null


func setup(
		world:       Node2D,
		intel_store: PlayerIntelStore,
		estimates:   RumorPanelEstimates
) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store
	_estimates       = estimates


## Clears and rebuilds the seed-target list for Panel 3.
##
## whisper_bar       — Label node in the coordinator; updated here.
## on_select_seed    — Callable(npc_id: String): player chose a seed target.
## on_hover_enter    — Callable(npc_id: String): mouse entered an entry.
## on_hover_exit     — Callable(): mouse exited an entry.
## on_evidence_select — Callable(item): player attached an evidence item.
## on_evidence_clear  — Callable(): player removed attached evidence.
## on_pop_confirm    — Callable(): brief scale-pop on the confirm button.
func build(
		container:              VBoxContainer,
		whisper_bar:            Label,
		selected_subject:       String,
		selected_claim_id:      String,
		selected_seed_npc:      String,
		selected_evidence_item,
		on_select_seed:         Callable,
		on_hover_enter:         Callable,
		on_hover_exit:          Callable,
		on_evidence_select:     Callable,
		on_evidence_clear:      Callable,
		on_pop_confirm:         Callable
) -> void:
	for child in container.get_children():
		child.queue_free()

	if _world_ref == null or _intel_store_ref == null:
		return

	# Update Whisper Token bar — show cost prominently.
	var tokens: int = _intel_store_ref.whisper_tokens_remaining
	var max_t:  int = _intel_store_ref.max_daily_whispers
	whisper_bar.text = (
		"Whisper Tokens: %d / %d remaining  |  Cost: 1 token per rumor  |  Replenishes at dawn"
		% [tokens, max_t]
	)
	whisper_bar.add_theme_font_size_override("font_size", 13)
	if tokens == 0:
		whisper_bar.add_theme_color_override("font_color", Color(0.95, 0.40, 0.25, 1.0))
	else:
		whisper_bar.add_theme_color_override("font_color", C_GOLD)

	# Chain indicator — show when seeding would create a rumor chain.
	var chain_info := _detect_current_chain(selected_subject, selected_claim_id)
	var chain_type: PropagationEngine.ChainType = chain_info.get(
		"chain_type", PropagationEngine.ChainType.NONE
	)
	if chain_type != PropagationEngine.ChainType.NONE:
		_add_chain_indicator(container, chain_type)

	# Evidence attachment section — only shown when inventory is non-empty.
	if not _intel_store_ref.evidence_inventory.is_empty():
		var claim_type_upper := _get_claim_type_upper(selected_claim_id)
		var compatible := _intel_store_ref.get_compatible_evidence(claim_type_upper)
		_add_evidence_section(
			container, compatible, selected_evidence_item,
			on_evidence_select, on_evidence_clear
		)

	# SPA-758: Determine recommended seed target on first Panel 3 open in S1.
	var recommended_id: String = ""
	var is_s1: bool = _world_ref != null and _world_ref.get("active_scenario_id") == "scenario_1"
	if is_s1 and not seed_recommended_shown:
		var best_soc: float = -1.0
		for npc in _world_ref.npcs:
			var nid: String = npc.npc_data.get("id", "")
			if nid == selected_subject:
				continue
			var soc: float = float(npc.npc_data.get("sociability", 0.5))
			if soc > best_soc:
				best_soc = soc
				recommended_id = nid
		seed_recommended_shown = true

	for npc in _world_ref.npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		# Cannot seed to the subject themselves.
		if npc_id == selected_subject:
			continue
		var npc_name: String = npc.npc_data.get("name",    "")
		var faction:  String = npc.npc_data.get("faction", "")

		var entry := _build_seed_entry(
			npc, npc_id, npc_name, faction,
			npc_id == recommended_id,
			selected_seed_npc, selected_claim_id, selected_subject,
			selected_evidence_item,
			on_select_seed, on_hover_enter, on_hover_exit, on_pop_confirm
		)
		container.add_child(entry)


# ── Per-NPC seed entry ────────────────────────────────────────────────────────

func _build_seed_entry(
		npc_node:               Node2D,
		npc_id:                 String,
		npc_name:               String,
		faction:                String,
		is_recommended:         bool,
		selected_seed_npc:      String,
		selected_claim_id:      String,
		selected_subject:       String,
		selected_evidence_item,
		on_select_seed:         Callable,
		on_hover_enter:         Callable,
		on_hover_exit:          Callable,
		on_pop_confirm:         Callable
) -> Control:
	var outer := PanelContainer.new()

	if is_recommended:
		# SPA-758: Gold border highlight for recommended seed target.
		var rec_style := StyleBoxFlat.new()
		rec_style.bg_color = Color(0.12, 0.09, 0.04, 0.95)
		rec_style.border_color = Color(0.957, 0.651, 0.227, 0.85)
		rec_style.set_border_width_all(2)
		rec_style.set_corner_radius_all(4)
		outer.add_theme_stylebox_override("panel", rec_style)
	elif npc_id == selected_seed_npc:
		var style := StyleBoxFlat.new()
		style.bg_color = C_SELECTED_SEED_BG
		outer.add_theme_stylebox_override("panel", style)

	# Spread prediction overlay: hover triggers ring drawing on world map.
	var captured_npc_id := npc_id
	outer.mouse_entered.connect(func() -> void: on_hover_enter.call(captured_npc_id))
	outer.mouse_exited.connect(func() -> void: on_hover_exit.call())

	var vbox := VBoxContainer.new()
	outer.add_child(vbox)

	# Header row: faction swatch + name + recommended badge.
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var swatch_panel := Panel.new()
	swatch_panel.custom_minimum_size = Vector2(18, 18)
	swatch_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sw_col := _faction_color(faction)
	var sw_style := StyleBoxFlat.new()
	sw_style.bg_color = sw_col
	sw_style.set_corner_radius_all(3)
	sw_style.set_border_width_all(1)
	sw_style.border_color = Color(sw_col.r * 0.6, sw_col.g * 0.6, sw_col.b * 0.6, 0.8)
	swatch_panel.add_theme_stylebox_override("panel", sw_style)
	header.add_child(swatch_panel)

	var name_lbl := Label.new()
	name_lbl.text = "  " + npc_name + "  [" + faction.capitalize() + "]"
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", C_NPC_NAME)
	name_lbl.add_theme_constant_override("outline_size", 1)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	header.add_child(name_lbl)

	# SPA-758: "Recommended" badge for highest-sociability NPC on first S1 open.
	if is_recommended:
		var rec_badge := Label.new()
		rec_badge.text = "★ Recommended — highest reach"
		rec_badge.add_theme_font_size_override("font_size", 12)
		rec_badge.add_theme_color_override("font_color", Color(0.957, 0.651, 0.227, 1.0))
		header.add_child(rec_badge)

	# Estimates with numeric percentages.
	var spread_result := _estimates.estimate_spread(npc_node)
	var belief_result := _estimates.estimate_believability(
		npc_id, selected_claim_id, selected_subject, npc_name
	)
	var spread_est:    float  = spread_result["value"]
	var spread_reason: String = spread_result["reason"]
	var belief_est:    float  = belief_result["value"]
	var belief_reason: String = belief_result["reason"]
	var belief_pct:    int    = roundi(belief_est * 100.0)

	# Spread estimate row.
	var spread_row := HBoxContainer.new()
	spread_row.add_theme_constant_override("separation", 6)
	vbox.add_child(spread_row)

	var spread_lbl := Label.new()
	spread_lbl.text = "    Spread: ~%d NPCs" % roundi(spread_est)
	spread_lbl.add_theme_font_size_override("font_size", 13)
	var spread_color: Color
	if spread_est >= 4.0:
		spread_color = Color(0.40, 0.90, 0.45, 1.0)
	elif spread_est >= 2.0:
		spread_color = Color(0.95, 0.80, 0.30, 1.0)
	else:
		spread_color = Color(0.95, 0.45, 0.25, 1.0)
	spread_lbl.add_theme_color_override("font_color", spread_color)
	spread_row.add_child(spread_lbl)

	# Believability with colour-coded badge.
	var belief_color: Color
	if belief_pct >= 60:
		belief_color = Color(0.40, 0.90, 0.45, 1.0)
	elif belief_pct >= 35:
		belief_color = Color(0.95, 0.80, 0.30, 1.0)
	else:
		belief_color = Color(0.95, 0.45, 0.25, 1.0)

	var belief_lbl := Label.new()
	belief_lbl.text = "Believability: %d%%" % belief_pct
	belief_lbl.add_theme_font_size_override("font_size", 13)
	belief_lbl.add_theme_color_override("font_color", belief_color)
	spread_row.add_child(belief_lbl)

	# Success probability hint — combines spread + believability for a quick read.
	var success_score: float = (spread_est / 6.0) * 0.4 + belief_est * 0.6
	var hint_text: String
	var hint_color: Color
	if success_score >= 0.65:
		hint_text  = "Very Likely"
		hint_color = Color(0.30, 0.95, 0.50, 1.0)
	elif success_score >= 0.45:
		hint_text  = "Good Chance"
		hint_color = Color(0.50, 0.90, 0.40, 1.0)
	elif success_score >= 0.30:
		hint_text  = "Moderate"
		hint_color = Color(0.95, 0.80, 0.30, 1.0)
	elif success_score >= 0.15:
		hint_text  = "Risky"
		hint_color = Color(0.95, 0.55, 0.25, 1.0)
	else:
		hint_text  = "Unlikely"
		hint_color = Color(0.95, 0.35, 0.25, 1.0)

	var hint_lbl := Label.new()
	hint_lbl.text = "[%s]" % hint_text
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", hint_color)
	spread_row.add_child(hint_lbl)

	# SPA-849: 1-line forecast reasons below the stats row.
	var reason_row := HBoxContainer.new()
	reason_row.add_theme_constant_override("separation", 14)
	vbox.add_child(reason_row)
	var spread_reason_lbl := Label.new()
	spread_reason_lbl.text = "    " + spread_reason
	spread_reason_lbl.add_theme_font_size_override("font_size", 11)
	spread_reason_lbl.add_theme_color_override("font_color", Color(0.70, 0.82, 0.70, 0.80))
	reason_row.add_child(spread_reason_lbl)
	var belief_reason_lbl := Label.new()
	belief_reason_lbl.text = belief_reason
	belief_reason_lbl.add_theme_font_size_override("font_size", 11)
	belief_reason_lbl.add_theme_color_override("font_color", Color(0.70, 0.76, 0.90, 0.80))
	reason_row.add_child(belief_reason_lbl)

	# Heat warning indicator.
	if _intel_store_ref != null and _intel_store_ref.heat_enabled:
		var heat_val: float = _intel_store_ref.get_heat(npc_id)
		if heat_val >= 50.0:
			var heat_warn := Label.new()
			heat_warn.text = "  ⚠ Suspicious — estimate reduced"
			heat_warn.add_theme_font_size_override("font_size", 11)
			heat_warn.add_theme_color_override("font_color", C_STATUS_WARN)
			vbox.add_child(heat_warn)

	vbox.add_child(HSeparator.new())

	var btn := Button.new()
	btn.text = "Whisper to " + npc_name
	btn.add_theme_font_size_override("font_size", 12)
	var captured_id := npc_id
	btn.pressed.connect(func():
		on_select_seed.call(captured_id)
		on_pop_confirm.call()
	)
	vbox.add_child(btn)

	return outer


# ── Chain indicator ───────────────────────────────────────────────────────────

func _detect_current_chain(selected_subject: String, selected_claim_id: String) -> Dictionary:
	if _world_ref == null or _world_ref.propagation_engine == null:
		return {"chain_type": PropagationEngine.ChainType.NONE, "existing_rumor": null}
	if selected_subject.is_empty() or selected_claim_id.is_empty():
		return {"chain_type": PropagationEngine.ChainType.NONE, "existing_rumor": null}
	var claim_type := Rumor.claim_type_from_string(
		_get_claim_type_upper(selected_claim_id).to_lower()
	)
	return _world_ref.propagation_engine.detect_chain(selected_subject, claim_type)


func _add_chain_indicator(
		container:  VBoxContainer,
		chain_type: PropagationEngine.ChainType
) -> void:
	var badge_color: Color
	var badge_text:  String
	var desc_text:   String
	match chain_type:
		PropagationEngine.ChainType.SAME_TYPE:
			badge_color = Color(0.60, 0.60, 0.55, 1.0)
			badge_text  = "Echo"
			desc_text   = "Same-Type Chain: +15% believability, +1 intensity"
		PropagationEngine.ChainType.ESCALATION:
			badge_color = Color(0.92, 0.22, 0.18, 1.0)
			badge_text  = "Escalation"
			desc_text   = "Escalation Chain: +25% believability, -50% mutation"
		PropagationEngine.ChainType.CONTRADICTION:
			badge_color = Color(0.90, 0.50, 0.15, 1.0)
			badge_text  = "Contradiction"
			desc_text   = "Contradiction Chain: faster CONTRADICTED, -10% believability"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	container.add_child(row)

	var badge_panel := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color     = Color(badge_color.r * 0.25, badge_color.g * 0.25, badge_color.b * 0.25, 0.90)
	badge_style.border_color = badge_color
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(3)
	badge_style.set_content_margin_all(4)
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	badge_panel.tooltip_text = desc_text

	var badge_lbl := Label.new()
	badge_lbl.text = badge_text
	badge_lbl.add_theme_font_size_override("font_size", 12)
	badge_lbl.add_theme_color_override("font_color", badge_color)
	badge_panel.add_child(badge_lbl)
	row.add_child(badge_panel)

	var desc_lbl := Label.new()
	desc_lbl.text = desc_text
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", C_CHAIN_DESC)
	desc_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(desc_lbl)


# ── Evidence section ──────────────────────────────────────────────────────────

func _add_evidence_section(
		container:              VBoxContainer,
		compatible:             Array,
		selected_evidence_item,
		on_evidence_select:     Callable,
		on_evidence_clear:      Callable
) -> void:
	var hdr := Label.new()
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", C_GOLD)
	if compatible.is_empty():
		hdr.text = "  [Evidence] No compatible evidence for this claim type."
		container.add_child(hdr)
		container.add_child(HSeparator.new())
		return

	hdr.text = "  [Evidence] Attach evidence to boost this rumor (optional):"
	container.add_child(hdr)

	# Fire evidence tutorial once the player first sees usable evidence items.
	if not evidence_tutorial_fired:
		evidence_tutorial_fired = true
		# Coordinator connects to this flag externally via poll or callback.
		# Signal firing is left to the coordinator's on_evidence_tutorial check.

	# When evidence is already attached, show a compact summary under the header.
	if selected_evidence_item != null:
		var attached_lbl := Label.new()
		attached_lbl.add_theme_font_size_override("font_size", 12)
		attached_lbl.add_theme_color_override("font_color", C_EVIDENCE_ATTACHED)
		var bonus_str := ""
		if selected_evidence_item.believability_bonus != 0.0:
			bonus_str = "  +%d%% Belief" % roundi(selected_evidence_item.believability_bonus * 100.0)
		attached_lbl.text = "  ✓ Attached: %s%s" % [selected_evidence_item.type, bonus_str]
		container.add_child(attached_lbl)

	for item in compatible:
		container.add_child(_build_evidence_entry(item, selected_evidence_item, on_evidence_select, on_evidence_clear))

	if selected_evidence_item != null:
		var clear_btn := Button.new()
		clear_btn.text = "Remove Evidence"
		clear_btn.add_theme_font_size_override("font_size", 12)
		clear_btn.pressed.connect(func() -> void:
			on_evidence_clear.call()
		)
		container.add_child(clear_btn)

	container.add_child(HSeparator.new())


func _build_evidence_entry(
		item,
		selected_evidence_item,
		on_evidence_select: Callable,
		on_evidence_clear:  Callable
) -> Control:
	var outer := PanelContainer.new()
	if item == selected_evidence_item:
		var style := StyleBoxFlat.new()
		style.bg_color = C_SELECTED_EVIDENCE_BG
		outer.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	outer.add_child(vbox)

	# Type + bonus text.
	var bonus_parts: Array = []
	if item.believability_bonus != 0.0:
		bonus_parts.append("Believability +%.2f" % item.believability_bonus)
	if item.mutability_modifier != 0.0:
		var sign_str: String = "+" if item.mutability_modifier >= 0.0 else ""
		bonus_parts.append("Mutability %s%.2f" % [sign_str, item.mutability_modifier])
	var type_lbl := Label.new()
	type_lbl.text = "  %s — %s" % [item.type, "  |  ".join(bonus_parts)]
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", C_EVIDENCE_TYPE)
	vbox.add_child(type_lbl)

	# Visual boost bar — scale 0.0–0.25 bonus onto 1–5 bars.
	if item.believability_bonus > 0.0:
		var boost_bars: int = clampi(roundi(item.believability_bonus * 20.0), 1, 5)
		var bar_lbl := Label.new()
		bar_lbl.text = "    Boost: " + "▇".repeat(boost_bars) + "░".repeat(5 - boost_bars)
		bar_lbl.add_theme_font_size_override("font_size", 12)
		bar_lbl.add_theme_color_override("font_color", C_BOOST_BAR)
		vbox.add_child(bar_lbl)

	# Compatible claim types hint.
	if not item.compatible_claims.is_empty():
		var compat_lbl := Label.new()
		compat_lbl.text = "    Works with: " + ", ".join(item.compatible_claims)
		compat_lbl.add_theme_font_size_override("font_size", 12)
		compat_lbl.add_theme_color_override("font_color", C_COMPAT_HINT)
		vbox.add_child(compat_lbl)

	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 12)
	if item == selected_evidence_item:
		btn.text = "✓ Attached"
	else:
		btn.text = "Attach"
	var captured_item = item
	btn.pressed.connect(func() -> void:
		on_evidence_select.call(captured_item)
	)
	vbox.add_child(btn)

	return outer


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns the claim type string (upper-case) for the given claim_id, or "".
func _get_claim_type_upper(claim_id: String) -> String:
	if _world_ref == null:
		return ""
	for c in _world_ref.get_claims():
		if c.get("id", "") == claim_id:
			return c.get("type", "").to_upper()
	return ""


static func _faction_color(faction: String) -> Color:
	match faction:
		"merchant": return C_FACTION_MERCHANT
		"noble":    return C_FACTION_NOBLE
		"clergy":   return C_FACTION_CLERGY
		_:          return Color.WHITE
