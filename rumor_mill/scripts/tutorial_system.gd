## tutorial_system.gd — Tutorial tooltip data and first-encounter tracking.
##
## Plain class (no Node).  Holds ten first-encounter tooltip definitions
## and tracks which ones the player has already seen this session.
##
## Tooltip IDs and their intended triggers (wired by main.gd):
##   "recon_actions"        — shown once on game start
##   "navigation_controls"  — shown once on game start (after recon_actions)
##   "observe"              — shown after the first successful Observe action
##   "eavesdrop"            — shown after the first successful Eavesdrop action
##   "npc_state_change"     — shown on first NPC state transition
##   "rumor_crafting"       — shown when the Rumor Panel first becomes visible
##   "reputation"           — shown when the Player Journal first becomes visible
##   "evidence_items"       — shown on first evidence discovery
##   "rival_agent"          — shown on Scenario 3 rival agent introduction
##   "inquisitor_agent"     — shown on Scenario 4 inquisitor introduction

class_name TutorialSystem

## Ordered list used to control queue priority when multiple tooltips fire at once.
const TOOLTIP_ORDER: Array = [
	"core_loop",
	"navigation_controls",
	"recon_actions",
	"observe",
	"eavesdrop",
	"npc_state_change",
	"rumor_crafting",
	"reputation",
	"evidence_items",
	"rival_agent",
	"inquisitor_agent",
]

## Tooltip content: title + BBCode body text.
const TOOLTIP_DATA: Dictionary = {
	"core_loop": {
		"title": "How to Play — The Core Loop",
		"body":  (
			"Your goal is to manipulate the town through rumours. Here is the loop:\n\n"
			+ "  1. [b]OBSERVE[/b] — Right-click a building to see who is inside.\n"
			+ "  2. [b]EAVESDROP[/b] — Right-click two NPCs talking to learn their bond.\n"
			+ "  3. [b]CRAFT A RUMOUR[/b] — Press [b]R[/b] to pick a subject, claim, and seed target.\n"
			+ "  4. [b]WATCH IT SPREAD[/b] — Believers tell others; reputations shift.\n\n"
			+ "Repeat this loop each day. Check the [b]Objective HUD[/b] (top) to track progress."
		),
	},
	"navigation_controls": {
		"title": "Navigation & Hotkeys",
		"body":  (
			"Moving around the map:\n"
			+ "• [b]WASD[/b] or [b]Arrow Keys[/b] — pan the camera\n"
			+ "• [b]Scroll Wheel[/b] — zoom in / out\n"
			+ "• [b]Middle Mouse Drag[/b] — free pan\n\n"
			+ "[b]Key Hotkeys:[/b]\n"
			+ "  [b]R[/b] = Rumour Panel   [b]J[/b] = Journal\n"
			+ "  [b]G[/b] = Social Graph   [b]Space[/b] = Pause"
		),
	},
	"recon_actions": {
		"title": "Daily Resources",
		"body":  (
			"Each day you have limited actions:\n"
			+ "• [b]3 Recon Actions[/b] — spent on Observe and Eavesdrop.\n"
			+ "• [b]2 Whisper Tokens[/b] — spent when seeding a rumour to an NPC.\n\n"
			+ "All resources [b]refresh at dawn[/b] each new day.\n"
			+ "Plan carefully — once you run out, you must wait for tomorrow."
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
	"evidence_items": {
		"title": "Evidence Items",
		"body":  (
			"Some recon actions yield [b]Evidence Items[/b] — consumable intel\n"
			+ "that boosts a rumour's believability when attached at seeding:\n"
			+ "• [b]Forged Document[/b] — double-action at Market or Guild\n"
			+ "• [b]Incriminating Artifact[/b] — late-night at Temple or Noble Estate\n"
			+ "• [b]Witness Account[/b] — eavesdrop a repeated conversation\n"
			+ "Evidence is consumed on use. Each item shows its boost bar and\n"
			+ "which claim types it works with in the Rumour Crafting panel."
		),
	},
	"rival_agent": {
		"title": "A Rival is Active",
		"body":  (
			"You are not alone. [b]An unseen rival[/b] is seeding counter-rumours\n"
			+ "against your Scenario 3 objectives:\n"
			+ "• They [b]praise Tomas Reeve[/b] to keep his reputation high.\n"
			+ "• They [b]scandal Calder Fenn[/b] to drag his reputation down.\n"
			+ "Their activity escalates as the deadline approaches.\n"
			+ "Counter with high-intensity claims and well-connected seed targets.\n"
			+ "Their last known action is shown in the [b]Scenario 3 HUD[/b]."
		),
	},
	"inquisitor_agent": {
		"title": "The Inquisitor Approaches",
		"body":  (
			"This scenario is [b]purely defensive[/b]. An [b]Inquisitor[/b] is targeting\n"
			+ "three people with scandal and heresy claims to destroy their reputations.\n"
			+ "• [b]Your goal:[/b] keep all three targets above the reputation threshold.\n"
			+ "• The Inquisitor seeds claims on a cooldown that [b]accelerates[/b] over time.\n"
			+ "• Counter with [b]Praise[/b] rumours and well-connected seed targets.\n"
			+ "• Watch for clergy NPCs losing reputation — that signals an Inquisitor move.\n"
			+ "Track Inquisitor activity in the [b]Scenario 4 HUD[/b]."
		),
	},
}

## ── Scenario 1 non-blocking hint banner data ──────────────────────────────────
##
## 10 contextual hints for the non-blocking bottom-left banner system.
## auto_dismiss_secs: how long the banner stays before auto-closing (7 or 9 s).
## body may contain "[evidence_name]" which TutorialBanner substitutes at queue time.

const HINT_DATA: Dictionary = {
	"hint_camera": {
		"title": "Your Mission Begins",
		"body":  (
			"You are a [b]rumor-monger[/b] — hired to [b]destroy Lord Edric Fenn's reputation[/b] "
			+ "before the tax rolls are signed.  Observe, eavesdrop, craft lies, and plant them.  "
			+ "Use [b]WASD[/b] to look around.  [b]Scroll[/b] to zoom."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_first_action": {
		"title": "Step 1: Observe a Building",
		"body":  (
			"[b]Right-click a building[/b] to [b]Observe[/b] who is inside.  "
			+ "Try the [b]Market Square[/b] — it's always busy.  "
			+ "You have [b]3 actions[/b] per day. This is your first."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_target_npc": {
		"title": "Step 2: Eavesdrop on Conversations",
		"body":  (
			"Your target is [b]Lord Edric Fenn[/b].  Hover over townspeople to find him.  "
			+ "[b]Right-click two NPCs in conversation[/b] to Eavesdrop — you will learn who trusts whom.  "
			+ "This intel is the raw material for your rumors."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_hover_npc": {
		"title": "Inspect NPCs",
		"body":  (
			"[b]Hover[/b] over any townsperson to see their name and reputation.  "
			+ "Their label colour shows how a rumour has affected them.  "
			+ "Find [b]Lord Edric Fenn[/b] — he is your primary target."
		),
		"auto_dismiss_secs": 7,
	},
	"hint_observe": {
		"title": "Observe a Location",
		"body":  (
			"[b]Right-click a building[/b] to spend a Recon Action and record who is present.  "
			+ "Choose well-attended locations to find the best rumour targets."
		),
		"auto_dismiss_secs": 7,
	},
	"hint_eavesdrop": {
		"title": "Eavesdrop",
		"body":  (
			"Two NPCs are nearby — [b]right-click[/b] to eavesdrop.  "
			+ "Learn how close they are.  Strong allies spread rumours fast.  "
			+ "Nervous types may notice you."
		),
		"auto_dismiss_secs": 7,
	},
	"hint_journal": {
		"title": "Review Intel",
		"body":  (
			"Press [b]J[/b] to open your Journal.  "
			+ "The Intelligence tab logs every observation and relationship you have gathered."
		),
		"auto_dismiss_secs": 7,
	},
	"hint_rumour_panel": {
		"title": "Step 3: Craft Your First Rumour",
		"body":  (
			"Press [b]R[/b] to open the Rumour Panel.  "
			+ "Pick a [b]subject[/b] (who the rumour is about), choose a [b]claim[/b] (scandal, illness, praise), "
			+ "then pick a [b]seed target[/b] — the person you will whisper it to.  This is the core of the game."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_seed_target": {
		"title": "Choose Your Seed Target",
		"body":  (
			"Pick someone [b]well-connected[/b] — high sociability spreads your rumour further.  "
			+ "NPCs you have eavesdropped will show their estimated reach."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_propagation": {
		"title": "Watch the Rumour Spread",
		"body":  (
			"The seed target is now [b]Evaluating[/b] your rumour.  "
			+ "Once they [b]Believe[/b], they will tell others.  "
			+ "Check [b]Journal → Rumours[/b] to follow every believer."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_objectives": {
		"title": "Track Your Goal",
		"body":  (
			"Press [b]J[/b] and open the [b]Objectives[/b] tab to track Edric Fenn's "
			+ "current reputation score.  You need to bring it below 30.  You have 30 days."
		),
		"auto_dismiss_secs": 7,
	},
	"hint_evidence": {
		"title": "Evidence Boosts Belief",
		"body":  (
			"You found [b][evidence_name][/b].  "
			+ "Attach it in the Rumour Panel (Step 2) to boost believability.  "
			+ "Evidence is consumed on use — choose the right moment."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_social_graph": {
		"title": "Social Graph",
		"body":  (
			"You have uncovered multiple relationships.  "
			+ "Press [b]G[/b] to open the Social Graph — it maps every connection you have found.  "
			+ "Use it to identify the strongest paths toward your target."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_speed_controls": {
		"title": "Time Controls",
		"body":  (
			"Press [b]Space[/b] to pause the game.  "
			+ "Use the [b]||  1×  3×[/b] buttons (top-right) to pause, run at normal speed, or fast-forward.  "
			+ "Pause to plan your next move without wasting daylight."
		),
		"auto_dismiss_secs": 7,
	},
}

## ── Cross-scenario contextual hint banner data ──────────────────────────────
##
## Day-gated and event-gated hints for all scenarios (not just S1).
## Triggered by main.gd based on day number and game events.

const CONTEXT_HINT_DATA: Dictionary = {
	"ctx_actions_refresh": {
		"title": "New Day, New Actions",
		"body":  (
			"Your [b]Recon Actions[/b] and [b]Whisper Tokens[/b] refresh at dawn.  "
			+ "Plan today's moves carefully — each action counts."
		),
		"auto_dismiss_secs": 8,
	},
	"ctx_check_journal": {
		"title": "Review Your Progress",
		"body":  (
			"Press [b]J[/b] to check your Journal.  "
			+ "See how yesterday's rumours spread overnight and track reputation changes."
		),
		"auto_dismiss_secs": 8,
	},
	"ctx_rumor_spreading": {
		"title": "Your Rumour is Spreading!",
		"body":  (
			"An NPC in [b]SPREAD[/b] state is actively telling others nearby.  "
			+ "Well-connected spreaders will reach more of the town."
		),
		"auto_dismiss_secs": 9,
	},
	"ctx_rumor_acted": {
		"title": "Behaviour Changed",
		"body":  (
			"An NPC is [b]acting[/b] on the rumour — real behavioural change.  "
			+ "Watch the reputation shift in the Objective HUD."
		),
		"auto_dismiss_secs": 9,
	},
	"ctx_rumor_rejected": {
		"title": "Rumour Rejected",
		"body":  (
			"A rumour was [b]rejected[/b].  That NPC will not believe it again easily.  "
			+ "Try different claim types or target different NPCs."
		),
		"auto_dismiss_secs": 9,
	},
	"ctx_out_of_tokens": {
		"title": "Out of Whisper Tokens",
		"body":  (
			"No Whisper Tokens remaining today.  "
			+ "Use your remaining [b]Recon Actions[/b] to scout targets for tomorrow."
		),
		"auto_dismiss_secs": 8,
	},
	"ctx_halfway_warning": {
		"title": "Time is Running Out",
		"body":  (
			"You are past the halfway mark and progress is slow.  "
			+ "Target [b]higher-sociability NPCs[/b] or use stronger claim types to accelerate."
		),
		"auto_dismiss_secs": 9,
	},
	"ctx_s2_opening": {
		"title": "The Plague Scare — First Move",
		"body":  (
			"[b]Observe[/b] the [b]Apothecary[/b] or [b]Market[/b] to find NPCs connected to [b]Alys Herbwife[/b].  "
			+ "Then craft an [b]Illness[/b] rumor — you need [b]6 believers[/b] to win.  "
			+ "Watch out for [b]Sister Maren[/b] — if she rejects the rumor, you lose."
		),
		"auto_dismiss_secs": 10,
	},
	"ctx_s3_opening": {
		"title": "The Succession — First Move",
		"body":  (
			"You fight on [b]two fronts[/b]: raise [b]Calder Fenn[/b] with [b]Praise[/b] "
			+ "and tear down [b]Tomas Reeve[/b] with [b]Scandal[/b].  "
			+ "A [b]rival agent[/b] works against you — act fast!"
		),
		"auto_dismiss_secs": 10,
	},
	"ctx_s4_opening": {
		"title": "The Holy Inquisition — First Move",
		"body":  (
			"This is a [b]defense mission[/b].  An Inquisitor will attack [b]Aldous[/b], [b]Vera[/b], and [b]Finn[/b].  "
			+ "Use [b]Praise[/b] rumours to keep their reputations [b]above 45[/b].  "
			+ "Watch the Inquisitor HUD for incoming attacks."
		),
		"auto_dismiss_secs": 10,
	},
	"ctx_idle_no_action": {
		"title": "Need a Nudge?",
		"body":  (
			"You haven't taken an action yet.  Try [b]right-clicking a building[/b] to Observe who is inside.  "
			+ "The [b]Market Square[/b] is a good first stop — it is usually busy."
		),
		"auto_dismiss_secs": 10,
	},
	"ctx_idle_no_rumor": {
		"title": "Ready to Spread a Rumour?",
		"body":  (
			"You have gathered intel but haven't crafted a rumour yet.  "
			+ "Press [b]R[/b] to open the Rumour Panel.  Pick a subject, choose a claim, "
			+ "then whisper it to a [b]well-connected NPC[/b] to start spreading."
		),
		"auto_dismiss_secs": 10,
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


## Returns how many distinct tutorial steps have been seen this session.
## Used by PlayerStats.record_tutorial_steps() at game end (SPA-335).
func get_seen_count() -> int:
	return _seen.size()


## Return the data dict for a tooltip, or an empty dict if not found.
func get_tooltip(tooltip_id: String) -> Dictionary:
	return TOOLTIP_DATA.get(tooltip_id, {})


## Return the data dict for a hint banner entry, or empty if not found.
## Checks both S1-specific HINT_DATA and cross-scenario CONTEXT_HINT_DATA.
func get_hint(hint_id: String) -> Dictionary:
	var result: Dictionary = HINT_DATA.get(hint_id, {})
	if result.is_empty():
		result = CONTEXT_HINT_DATA.get(hint_id, {})
	return result
