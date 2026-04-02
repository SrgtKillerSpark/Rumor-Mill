## tutorial_system.gd — Tutorial tooltip data and first-encounter tracking.
##
## Plain class (no Node).  Holds the five first-encounter tooltip definitions
## and tracks which ones the player has already seen this session.
##
## Tooltip IDs and their intended triggers (wired by main.gd):
##   "recon_actions"  — shown once on game start
##   "observe"        — shown after the first successful Observe action
##   "eavesdrop"      — shown after the first successful Eavesdrop action
##   "rumor_crafting" — shown when the Rumor Panel first becomes visible
##   "reputation"     — shown when the Player Journal first becomes visible

class_name TutorialSystem

## Ordered list used to control queue priority when multiple tooltips fire at once.
const TOOLTIP_ORDER: Array = [
	"recon_actions",
	"navigation_controls",
	"observe",
	"eavesdrop",
	"npc_state_change",
	"rumor_crafting",
	"reputation",
]

## Tooltip content: title + BBCode body text.
const TOOLTIP_DATA: Dictionary = {
	"recon_actions": {
		"title": "Recon Actions",
		"body":  (
			"Each day you have [b]3 Recon Actions[/b] and [b]1 Whisper Token[/b].\n"
			+ "• [b]Right-click a building[/b] to [b]Observe[/b] — note who is present.\n"
			+ "• [b]Right-click an NPC[/b] in conversation to [b]Eavesdrop[/b] — learn relationships.\n"
			+ "• [b]Press R[/b] to craft and seed a rumour (costs one Whisper Token).\n"
			+ "Actions refresh at dawn each new day."
		),
	},
	"navigation_controls": {
		"title": "Navigation",
		"body":  (
			"Moving around the map:\n"
			+ "• [b]WASD[/b] or [b]Arrow Keys[/b] — pan the camera\n"
			+ "• [b]Scroll Wheel[/b] — zoom in / out\n"
			+ "• [b]Middle Mouse Drag[/b] — free pan\n\n"
			+ "[b]Hotkeys:[/b]\n"
			+ "  [b]R[/b] = Rumour Panel   [b]J[/b] = Journal\n"
			+ "  [b]G[/b] = Social Graph   [b]Esc[/b] = Pause"
		),
	},
	"observe": {
		"title": "Observe — Location Intel",
		"body":  (
			"You noted the NPCs present at this location.\n"
			+ "Use this to find the right [b]seed target[/b] when crafting a rumour —\n"
			+ "choosing someone who is already at a busy location will spread\n"
			+ "your rumour faster through their social circle.\n"
			+ "Review all observations under [b]J → Intelligence[/b]."
		),
	},
	"eavesdrop": {
		"title": "Eavesdrop — Relationship Intel",
		"body":  (
			"You have learned how two NPCs relate to each other.\n"
			+ "• [b]Allied[/b] pairs spread rumours quickly and believe each other.\n"
			+ "• [b]Neutral[/b] pairs propagate more slowly.\n"
			+ "• [b]Suspicious[/b] pairs may block or distort what they hear.\n"
			+ "Beware — NPCs with a high temperament may notice you listening!\n"
			+ "Review all relationships under [b]J → Intelligence[/b]."
		),
	},
	"npc_state_change": {
		"title": "NPC State Machine",
		"body":  (
			"NPCs process every rumour through a state machine:\n"
			+ "• [b]Evaluating[/b] — weighing up whether to believe it.\n"
			+ "• [b]Believe[/b] — accepted; mood and actions may shift.\n"
			+ "• [b]Spread[/b] — actively telling others.\n"
			+ "• [b]Act[/b] — behaviour changed (avoidance, confrontation).\n"
			+ "• [b]Reject[/b] — dismissed; harder to convince again.\n"
			+ "Watch the label above each NPC to track their current state."
		),
	},
	"rumor_crafting": {
		"title": "Rumour Crafting",
		"body":  (
			"Craft a rumour in three steps:\n"
			+ "  1. [b]Subject[/b] — whose reputation you want to shift.\n"
			+ "  2. [b]Claim[/b] — Praise, Scandal, Accusation, Heresy…\n"
			+ "  3. [b]Seed Target[/b] — the NPC who first hears the rumour.\n"
			+ "Each seeded rumour costs [b]1 Whisper Token[/b] (refreshes at dawn).\n"
			+ "Use your Recon intel to pick a well-connected seed target."
		),
	},
	"reputation": {
		"title": "Reputation Score",
		"body":  (
			"Every NPC has a [b]0–100 reputation score[/b] shaped by active rumours.\n"
			+ "• [b]Distinguished (71–100)[/b] — widely admired\n"
			+ "• [b]Respected (51–70)[/b] — in good standing\n"
			+ "• [b]Suspect (31–50)[/b] — under scrutiny\n"
			+ "• [b]Disgraced (0–30)[/b] — social pariah\n"
			+ "Win conditions target specific reputation thresholds — check\n"
			+ "[b]Objectives[/b] in this journal to see exactly what is required."
		),
	},
}

## Tracks which tooltip IDs have been seen this session.
var _seen: Dictionary = {}


## Returns true if the given tooltip has already been shown this session.
func has_seen(tooltip_id: String) -> bool:
	return _seen.get(tooltip_id, false)


## Mark a tooltip as seen (called by TutorialHUD when the player dismisses it).
func mark_seen(tooltip_id: String) -> void:
	_seen[tooltip_id] = true


## Return the data dict for a tooltip, or an empty dict if not found.
func get_tooltip(tooltip_id: String) -> Dictionary:
	return TOOLTIP_DATA.get(tooltip_id, {})
