## journal_recommended_actions.gd — SPA-2454: Apprentice-only recommended action sidebar.
##
## Context-aware next-step suggestions shown in a right-hand panel inside the
## Journal.  Only active on Apprentice difficulty.  Reads world state each time
## the journal opens and generates 1–3 prioritized action suggestions.
##
## Usage (journal.gd):
##   var rec_panel := JournalRecommendedActions.new()
##   rec_panel.setup(world_ref, intel_store_ref)
##   main_layout.add_child(rec_panel)

class_name JournalRecommendedActions
extends VBoxContainer


# ── Palette (matches Journal) ────────────────────────────────────────────────

const C_PANEL_BG     := Color(0.14, 0.10, 0.06, 1.0)
const C_HEADING      := Color(0.92, 0.78, 0.12, 1.0)
const C_BODY         := Color(0.80, 0.72, 0.56, 1.0)
const C_ACCENT       := Color(0.55, 0.38, 0.18, 1.0)
const C_HIGHLIGHT    := Color(0.25, 0.45, 0.90, 0.8)

# ── References ───────────────────────────────────────────────────────────────

var _world_ref:       Node2D           = null
var _intel_store_ref: Node             = null  # PlayerIntelStore


func setup(world: Node2D, intel_store: Node) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store


func _ready() -> void:
	custom_minimum_size = Vector2(200, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)


## Rebuild the recommended actions list.  Called each time the journal opens.
func refresh() -> void:
	for child in get_children():
		child.queue_free()

	_add_header()
	var suggestions: Array = _compute_suggestions()
	if suggestions.is_empty():
		_add_body("No specific suggestions right now. Keep gathering intel!")
	else:
		for s in suggestions:
			_add_suggestion(s)


func _add_header() -> void:
	var lbl := Label.new()
	lbl.text = "Recommended Actions"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_HEADING)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = C_ACCENT
	add_child(rule)


func _add_body(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.text = text
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.add_theme_font_size_override("normal_font_size", 11)
	lbl.add_theme_color_override("default_color", C_BODY)
	add_child(lbl)


func _add_suggestion(data: Dictionary) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.08, 0.95)
	style.border_color = C_ACCENT
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var title_lbl := Label.new()
	title_lbl.text = data.get("title", "")
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	vbox.add_child(title_lbl)

	var body_lbl := RichTextLabel.new()
	body_lbl.bbcode_enabled = true
	body_lbl.text = data.get("body", "")
	body_lbl.fit_content = true
	body_lbl.scroll_active = false
	body_lbl.add_theme_font_size_override("normal_font_size", 10)
	body_lbl.add_theme_color_override("default_color", C_BODY)
	vbox.add_child(body_lbl)

	panel.add_child(vbox)
	add_child(panel)


# ── Suggestion engine ────────────────────────────────────────────────────────

func _compute_suggestions() -> Array:
	var suggestions: Array = []
	if _world_ref == null or _intel_store_ref == null:
		return suggestions

	var day: int = 1
	if _world_ref.day_night != null and _world_ref.day_night.has_method("get_current_day"):
		day = _world_ref.day_night.get_current_day()

	var actions_left: int = _intel_store_ref.recon_actions_remaining if _intel_store_ref.has_method("get") else 0
	if "recon_actions_remaining" in _intel_store_ref:
		actions_left = _intel_store_ref.recon_actions_remaining
	var tokens_left: int = 0
	if "whisper_tokens_remaining" in _intel_store_ref:
		tokens_left = _intel_store_ref.whisper_tokens_remaining

	var has_observations: bool = false
	if _intel_store_ref.has_method("get_observation_count"):
		has_observations = _intel_store_ref.get_observation_count() > 0
	elif "observations" in _intel_store_ref:
		has_observations = _intel_store_ref.observations.size() > 0

	var has_relationships: bool = false
	if _intel_store_ref.has_method("get_relationship_count"):
		has_relationships = _intel_store_ref.get_relationship_count() > 0
	elif "relationships" in _intel_store_ref:
		has_relationships = _intel_store_ref.relationships.size() > 0

	var active_rumors: int = 0
	if _world_ref.has_method("get_active_rumor_count"):
		active_rumors = _world_ref.get_active_rumor_count()
	elif "rumor_engine" in _world_ref and _world_ref.rumor_engine != null:
		if _world_ref.rumor_engine.has_method("get_active_count"):
			active_rumors = _world_ref.rumor_engine.get_active_count()

	# ── S2: Clergy contradiction-risk (slot 0, highest priority) ────────────
	# SPA-2653: When a clergy investigator is evaluating illness rumors about
	# Alys Herbwife, warn the player before the 3x decay contradiction lands.
	var npcs_ref: Array = _world_ref.npcs if "npcs" in _world_ref else []
	var clergy_suggestion: Dictionary = _build_clergy_investigation_suggestion(npcs_ref)
	if not clergy_suggestion.is_empty():
		suggestions.append(clergy_suggestion)

	# Priority 1: No observations yet — tell them to observe
	if not has_observations and actions_left > 0:
		suggestions.append({
			"title": "Observe a Building",
			"body": "[b]Right-click[/b] the Market or Tavern to see who's inside. Busy hubs reveal the best targets.",
		})

	# Priority 2: Has observations but no relationships — tell them to eavesdrop
	elif has_observations and not has_relationships and actions_left > 0:
		suggestions.append({
			"title": "Eavesdrop on NPCs",
			"body": "[b]Right-click two nearby NPCs[/b] to learn their bond. Strong allies spread rumours fastest.",
		})

	# Priority 3: Has intel but no rumors yet — tell them to craft
	elif has_relationships and active_rumors == 0 and tokens_left > 0:
		suggestions.append({
			"title": "Craft Your First Rumour",
			"body": "Press [b]R[/b] to open the Rumour Panel. Pick a subject, choose a claim, and seed it to a well-connected NPC.",
		})

	# Priority 4: Has active rumors — tell them to diversify
	elif active_rumors > 0 and active_rumors < 3 and tokens_left > 0:
		suggestions.append({
			"title": "Seed Another Rumour",
			"body": "Redundancy wins — seed a [b]different claim[/b] through a different NPC to hedge against rejection.",
		})

	# Day-based suggestions
	if day >= 2 and actions_left > 0 and has_observations:
		suggestions.append({
			"title": "Follow Up on Intel",
			"body": "Revisit observed locations — NPCs move around. New faces = new seed targets.",
		})

	if tokens_left == 0 and actions_left > 0:
		suggestions.append({
			"title": "Scout for Tomorrow",
			"body": "Out of Whisper Tokens. Use remaining actions to [b]observe and eavesdrop[/b] — prepare targets for dawn.",
		})

	# Cap at 3 suggestions
	if suggestions.size() > 3:
		suggestions.resize(3)

	return suggestions


## SPA-2653: Returns a high-priority suggestion dict when a clergy investigator
## (faction=clergy, role=investigator) has an illness rumor about Alys in
## EVALUATING state — the precursor before contradiction fires.
## Returns an empty dict when the condition is not met.
func _build_clergy_investigation_suggestion(npcs: Array) -> Dictionary:
	var sm: ScenarioManager = _world_ref.get("scenario_manager") if _world_ref != null else null
	if sm == null:
		return {}
	if sm.get_active_scenario_number() != 2:
		return {}
	if sm.scenario_2_state != ScenarioManager.ScenarioState.ACTIVE:
		return {}

	if not _has_clergy_investigating(npcs, ScenarioManager.ALYS_HERBWIFE_ID):
		return {}

	var body: String = (
		"Clergy investigation detected — [b]consider diverting attention or seeding"
		+ " a counter-narrative among Merchants[/b] before contradiction lands."
	)
	if "selected_difficulty" in GameState and GameState.selected_difficulty == "apprentice":
		body += (
			"\n[color=#c8a054]Tip: Contradictions destroy entire rumor chains."
			+ " Target NPCs who trust the Clergy less.[/color]"
		)
	return {
		"title": "⚠ Clergy Investigation Detected",
		"body": body,
	}


## SPA-2653: Returns true if any NPC in the list has faction=clergy,
## role=investigator, and an EVALUATING illness rumor targeting alys_herbwife.
## Extracted as a static helper so tests can call it without a full world.
static func _has_clergy_investigating(npcs: Array, alys_id: String) -> bool:
	for npc in npcs:
		if npc == null:
			continue
		var nd: Dictionary = npc.get("npc_data") if npc.has_method("get") else {}
		if nd.get("faction", "") != "clergy":
			continue
		if nd.get("role", "") != "investigator":
			continue
		if not ("rumor_slots" in npc):
			continue
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state != Rumor.RumorState.EVALUATING:
				continue
			if slot.rumor == null:
				continue
			if slot.rumor.claim_type != Rumor.ClaimType.ILLNESS:
				continue
			if slot.rumor.subject_npc_id != alys_id:
				continue
			return true
	return false
