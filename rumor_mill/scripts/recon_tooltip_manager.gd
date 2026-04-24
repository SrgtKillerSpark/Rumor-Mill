class_name ReconTooltipManager
extends RefCounted

## recon_tooltip_manager.gd — Tooltip text composition and hover activation for ReconHUD.
##
## Extracted from recon_hud.gd (SPA-999) to isolate tooltip creation, text
## composition, and mouse-filter wiring from the rest of the HUD logic.
##
## Call setup() once all HUD nodes are built, then setup_initial_tooltips() to
## apply static defaults.  Call the refresh_* methods whenever live values change.

var _counter_panel:       Panel         = null
var _heat_row:            HBoxContainer = null
var _feed_panel:          Panel         = null
var _key_hint_row:        HBoxContainer = null
var _action_pips_parent:  Control       = null
var _whisper_pips_parent: Control       = null
var _favors_row:          HBoxContainer = null
var _key_hint_rumor:      Label         = null
var _key_hint_journal:    Label         = null
var _key_hint_graph:      Label         = null
var _key_hint_help:       Label         = null


func setup(
		counter_panel:       Panel,
		heat_row:            HBoxContainer,
		feed_panel:          Panel,
		key_hint_row:        HBoxContainer,
		action_pips_parent:  Control,
		whisper_pips_parent: Control,
		favors_row:          HBoxContainer,
		key_hint_rumor:      Label,
		key_hint_journal:    Label,
		key_hint_graph:      Label,
		key_hint_help:       Label
) -> void:
	_counter_panel       = counter_panel
	_heat_row            = heat_row
	_feed_panel          = feed_panel
	_key_hint_row        = key_hint_row
	_action_pips_parent  = action_pips_parent
	_whisper_pips_parent = whisper_pips_parent
	_favors_row          = favors_row
	_key_hint_rumor      = key_hint_rumor
	_key_hint_journal    = key_hint_journal
	_key_hint_graph      = key_hint_graph
	_key_hint_help       = key_hint_help


## Apply static default tooltips to all managed nodes. Call once after all
## HUD nodes are built (replaces _setup_recon_tooltips in ReconHUD).
func setup_initial_tooltips() -> void:
	# Counter panel overall tooltip (SPA-870: what/how/why format).
	if _counter_panel != null:
		_counter_panel.tooltip_text = (
			"Recon Resources\n"
			+ "What: Your daily budget of Actions and Whisper Tokens.\n"
			+ "Actions let you gather intel; Whispers let you seed rumors.\n"
			+ "All resources refresh at the start of each new day."
		)
		_counter_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	# Heat meter tooltip (overridden dynamically by refresh_heat_tooltip, but
	# set here as a fallback before any live data arrives).
	if _heat_row != null:
		_heat_row.tooltip_text = (
			"Town Suspicion\n"
			+ "What: How suspicious NPCs are of your activities.\n"
			+ "Effect: High heat makes NPCs reject your rumors.\n"
			+ "Reduce it: Use Favors to bribe NPCs, or lay low and wait."
		)
		_heat_row.mouse_filter = Control.MOUSE_FILTER_PASS

	# Feed panel tooltip.
	if _feed_panel != null:
		_feed_panel.tooltip_text = (
			"Recent Actions\n"
			+ "What: A log of your last few recon actions and their results.\n"
			+ "Tip: Click an entry to filter the Journal to that event."
		)

	# Key hints row.
	if _key_hint_row != null:
		_key_hint_row.tooltip_text = (
			"Quick Actions\n"
			+ "Keyboard shortcuts to open game panels.\n"
			+ "R: Rumor crafting | J: Journal | G: Social Graph | F1: Help\n"
			+ "Greyed-out shortcuts require resources you don't currently have."
		)
		_key_hint_row.mouse_filter = Control.MOUSE_FILTER_PASS


## Update action and whisper pip row tooltips with live counts.
## Call from _refresh_pips() whenever remaining or max values change.
func refresh_resource_tooltips(
		remaining: int, max_val: int, whispers: int, max_w: int
) -> void:
	if _action_pips_parent != null:
		_action_pips_parent.tooltip_text = (
			"Recon Actions: %d / %d remaining\n"
			+ "What: Your daily budget for gathering intelligence.\n"
			+ "How to use: Right-click buildings to Observe, NPCs to Eavesdrop.\n"
			+ "Refresh: All actions replenish at dawn each day."
		) % [remaining, max_val]
		_action_pips_parent.mouse_filter = Control.MOUSE_FILTER_PASS

	if _whisper_pips_parent != null:
		_whisper_pips_parent.tooltip_text = (
			"Whisper Tokens: %d / %d remaining\n"
			+ "What: Tokens spent to seed rumors into the town.\n"
			+ "How to use: Press R to craft a rumor, then choose a seed target.\n"
			+ "Refresh: All tokens replenish at dawn each day."
		) % [whispers, max_w]
		_whisper_pips_parent.mouse_filter = Control.MOUSE_FILTER_PASS


## Update the favors row tooltip with the current count.
## Call from _refresh_pips() when the favors row is shown.
func refresh_favors_tooltip(favors: int) -> void:
	if _favors_row == null:
		return
	_favors_row.tooltip_text = (
		"Favors: %d available\n"
		+ "What: Tokens earned through successful actions.\n"
		+ "How to use: Bribe NPCs to reduce their suspicion of you.\n"
		+ "Earn more: Complete recon actions successfully."
	) % favors


## Update the heat row tooltip to reflect the current heat value and scenario
## failure ceiling.  Pass ceiling <= 0.0 when no ceiling applies (free-play).
##
## When a ceiling is active the tooltip warns of the failure threshold.
## Otherwise a severity-tiered message is shown (SPA-767 / SPA-869 format).
func refresh_heat_tooltip(heat_val: int, ceiling: float = -1.0) -> void:
	if _heat_row == null:
		return
	if ceiling > 0.0:
		_heat_row.tooltip_text = (
			"Suspicion: highest NPC heat (0-100). Reaches %d → exposed, scenario fails!\n"
			+ "High heat also makes NPCs reject your rumors (−15%% at 50, −30%% at 75)."
		) % int(ceiling)
	else:
		var severity := "Safe"
		var effect   := "No effect on rumor believability."
		if heat_val > 75:
			severity = "CRITICAL"
			effect   = "Severe penalty to believability. Risk of exposure!"
		elif heat_val > 50:
			severity = "Danger"
			effect   = "-30% rumor believability."
		elif heat_val > 25:
			severity = "Caution"
			effect   = "-15% rumor believability."
		_heat_row.tooltip_text = (
			"Town Suspicion: %d/100 (%s)\n%s\nReduce heat by using Favors (bribes) or waiting."
		) % [heat_val, severity, effect]


## Update key hint tooltips and re-enable mouse interaction.
## Call from _refresh_key_hint_availability() — only tooltip/mouse_filter
## is managed here; visual modulate state stays in ReconHUD.
func refresh_key_hint_tooltips(whisper_tokens: int) -> void:
	if _key_hint_rumor != null:
		if whisper_tokens <= 0:
			_key_hint_rumor.tooltip_text = (
				"Craft Rumor (R)\nUnavailable — no Whisper Tokens remaining.\nTokens refresh at dawn."
			)
		else:
			_key_hint_rumor.tooltip_text = (
				"Craft Rumor (R)\nOpen the Rumor Crafting panel to create and seed a new rumor.\nCosts 1 Whisper Token."
			)
		_key_hint_rumor.mouse_filter = Control.MOUSE_FILTER_PASS

	if _key_hint_journal != null:
		_key_hint_journal.tooltip_text = "Journal (J)\nReview your rumors, intel, faction standings, and objectives."
		_key_hint_journal.mouse_filter = Control.MOUSE_FILTER_PASS

	if _key_hint_graph != null:
		_key_hint_graph.tooltip_text = "Social Graph (G)\nVisualize NPC relationships and find the best paths to spread rumors."
		_key_hint_graph.mouse_filter = Control.MOUSE_FILTER_PASS

	if _key_hint_help != null:
		_key_hint_help.tooltip_text = "Help (F1)\nOpen the tutorial and help overlay."
		_key_hint_help.mouse_filter = Control.MOUSE_FILTER_PASS
