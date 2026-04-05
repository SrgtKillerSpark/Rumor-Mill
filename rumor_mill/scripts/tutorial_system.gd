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
		"title": "How to Play — Four Steps",
		"body":  (
			"You manipulate the town through rumours. Every day, repeat this loop:\n\n"
			+ "  1. [b]OBSERVE[/b] — Right-click a building to see who is inside.\n"
			+ "  2. [b]EAVESDROP[/b] — Right-click two NPCs talking to learn their bond.\n"
			+ "  3. [b]CRAFT A RUMOUR[/b] — Press [b]R[/b], pick a subject + claim + seed target.\n"
			+ "  4. [b]WATCH IT SPREAD[/b] — Believers tell others; reputations shift.\n\n"
			+ "The [b]Objective HUD[/b] (top of screen) always shows your next step."
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
			+ "  [b]G[/b] = Social Graph   [b]Space[/b] = Pause\n"
			+ "  [b]H[/b] = Replay last hint"
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
	"hint_s1_investigate_gate": {
		"title": "Gather Your First Intel",
		"body":  (
			"[b]Right-click the Market[/b] to see who is inside.  "
			+ "Investigating a building costs one Recon Action.  "
			+ "This banner clears once you take your first action."
		),
		"auto_dismiss_secs": 999,
	},
	"hint_camera": {
		"title": "Your Mission",
		"body":  (
			"[b]GOAL:[/b] Destroy [b]Lord Edric Fenn's[/b] reputation (below 30).  "
			+ "[b]HOW:[/b] Observe → Eavesdrop → Craft Rumour → Watch it Spread.  "
			+ "Use [b]WASD[/b] to pan, [b]Scroll[/b] to zoom, [b]Space[/b] to pause."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_first_action": {
		"title": "Step 1: Observe a Building",
		"body":  (
			"[b]Right-click any building[/b] to see who is inside.  "
			+ "Start with the [b]Market Square[/b] — it has the most NPCs.  "
			+ "You get [b]3 actions per day[/b] (recon + eavesdrop share this pool)."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_target_npc": {
		"title": "Step 2: Find Your Target",
		"body":  (
			"[b]Hover[/b] over townspeople to see their names.  Find [b]Lord Edric Fenn[/b].  "
			+ "[b]Right-click two NPCs near each other[/b] to Eavesdrop on their relationship.  "
			+ "Strong bonds = fast rumour spread."
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
			"Press [b]R[/b] now to open the Rumour Panel.  Three steps:\n"
			+ "  1. Pick a [b]subject[/b] — who the rumour targets\n"
			+ "  2. Choose a [b]claim[/b] — Scandal works well against Edric\n"
			+ "  3. Pick a [b]seed target[/b] — whisper it to a well-connected NPC"
		),
		"auto_dismiss_secs": 10,
	},
	"hint_seed_target": {
		"title": "Pick a Well-Connected Seed Target",
		"body":  (
			"Choose someone with [b]high sociability[/b] — they spread rumours faster.  "
			+ "NPCs you eavesdropped show their [b]estimated reach[/b].  "
			+ "Merchants in the Market are often well-connected."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_propagation": {
		"title": "Step 4: Watch It Spread",
		"body":  (
			"Your rumour is planted! The seed target is [b]Evaluating[/b] it.  "
			+ "If they [b]Believe[/b], they tell others → the rumour [b]Spreads[/b].  "
			+ "Press [b]J[/b] to track believers. Press [b]G[/b] to see the social graph."
		),
		"auto_dismiss_secs": 9,
	},
	"hint_objectives": {
		"title": "Check Your Progress",
		"body":  (
			"The [b]Objective HUD[/b] at the top tracks Edric's reputation.  "
			+ "Press [b]J → Objectives[/b] for the full breakdown.  "
			+ "Target: below [b]30[/b]. You have [b]30 days[/b]. Keep seeding rumours!"
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
		"title": "Your First Move",
		"body":  (
			"[b]Right-click[/b] the [b]Market[/b] or [b]Apothecary[/b] to find NPCs near [b]Alys Herbwife[/b].  "
			+ "Then press [b]R[/b] → pick Alys → choose [b]Illness[/b] → whisper to someone credulous like [b]Sybil Oats[/b].  "
			+ "[b]AVOID Sister Maren[/b] — if she rejects ANY illness rumour, you lose instantly."
		),
		"auto_dismiss_secs": 12,
	},
	"ctx_s3_opening": {
		"title": "Your First Move",
		"body":  (
			"Two targets, two actions:\n"
			+ "  1. Press [b]R[/b] → [b]Praise Calder Fenn[/b] → whisper to his allies\n"
			+ "  2. Press [b]R[/b] → [b]Scandal Tomas Reeve[/b] → whisper to the merchants\n"
			+ "A [b]rival agent[/b] works against you — check the Scenario HUD for their moves."
		),
		"auto_dismiss_secs": 12,
	},
	"ctx_s4_opening": {
		"title": "Your First Move",
		"body":  (
			"This is [b]defense[/b]. Check the [b]Scenario HUD[/b] — see who is closest to the danger zone.  "
			+ "Press [b]R[/b] → pick the most threatened NPC → choose [b]Praise[/b] → whisper to their strongest ally.  "
			+ "[b]Finn Monk[/b] is the most vulnerable — prioritize him first."
		),
		"auto_dismiss_secs": 12,
	},
	# ── Scenario 2: Plague Scare onboarding banners ─────────────────────────────
	"ctx_s2_illness_mechanic": {
		"title": "Illness Rumours",
		"body":  (
			"In this scenario, NPCs transition through [b]BELIEVE → SPREAD → ACT[/b].  "
			+ "Once [b]7 NPCs[/b] reach BELIEVE or beyond, the plague scare takes hold and you win."
		),
		"auto_dismiss_secs": 10,
	},
	"ctx_s2_maren_warning": {
		"title": "Avoid Sister Maren",
		"body":  (
			"[b]Sister Maren[/b] is immune to illness rumours.  "
			+ "If she [b]rejects[/b] any illness claim about Alys, you lose instantly.  "
			+ "Keep the rumour away from clergy circles."
		),
		"auto_dismiss_secs": 10,
	},
	"ctx_s2_believer_check": {
		"title": "Track Your Believers",
		"body":  (
			"The [b]Scenario HUD[/b] (top-left) shows your believer count.  "
			+ "You need [b]7[/b] — seed to credulous NPCs like merchants for faster uptake."
		),
		"auto_dismiss_secs": 9,
	},
	# ── Scenario 3: Succession onboarding banners ────────────────────────────
	"ctx_s3_dual_targets": {
		"title": "Two-Front War",
		"body":  (
			"You must [b]raise Calder Fenn[/b] to 75+ reputation AND [b]drop Tomas Reeve[/b] to 35 or below.  "
			+ "Balance both — if Calder drops below 40, you fail instantly."
		),
		"auto_dismiss_secs": 10,
	},
	"ctx_s3_rival_intro": {
		"title": "The Rival Agent",
		"body":  (
			"A [b]rival agent[/b] is working against you — praising Tomas and scandalising Calder.  "
			+ "Check the [b]Scenario HUD[/b] to see their latest move and counter it."
		),
		"auto_dismiss_secs": 10,
	},
	"ctx_s3_disrupt_tip": {
		"title": "Disrupt the Rival",
		"body":  (
			"Press the [b]Disrupt[/b] button in the Scenario HUD to spend 1 recon action "
			+ "and slow the rival for 3 days. Time it when their activity spikes."
		),
		"auto_dismiss_secs": 9,
	},
	# ── Scenario 4: Holy Inquisition onboarding banners ──────────────────────
	"ctx_s4_defense_goal": {
		"title": "Defend the Accused",
		"body":  (
			"Keep [b]Aldous Prior[/b], [b]Vera Midwife[/b], and [b]Finn Monk[/b] above [b]45 reputation[/b].  "
			+ "This scenario is purely [b]defensive[/b] — counter slander with Praise rumours."
		),
		"auto_dismiss_secs": 10,
	},
	"ctx_s4_inquisitor_info": {
		"title": "The Inquisitor",
		"body":  (
			"The [b]Inquisitor[/b] seeds accusations on a cooldown that [b]accelerates[/b] over time.  "
			+ "Watch the Scenario HUD for his targets and counter quickly with Praise."
		),
		"auto_dismiss_secs": 10,
	},
	"ctx_s4_prioritize_finn": {
		"title": "Protect Finn First",
		"body":  (
			"[b]Finn Monk[/b] is the most vulnerable — he absorbs slander faster than the others.  "
			+ "Prioritize his reputation when multiple targets are threatened."
		),
		"auto_dismiss_secs": 9,
	},
	# ── Scenario 1: Heat / exposure warning ──────────────────────────────────
	"ctx_heat_warning": {
		"title": "You Are Drawing Attention",
		"body":  (
			"NPCs are growing [b]suspicious[/b] of you.  "
			+ "If any NPC's suspicion reaches [b]80[/b], the Guard Captain will identify you and your mission will [b]fail instantly[/b].  "
			+ "Vary your targets and [b]wait a day[/b] between actions on the same NPC — suspicion fades overnight."
		),
		"auto_dismiss_secs": 12,
	},
	# ── General idle hints ───────────────────────────────────────────────────
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

## The most recently shown hint/tooltip ID (for replay via H hotkey).
var _last_hint_id: String = ""


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


## Record the most recently displayed hint so H can replay it.
func set_last_hint(hint_id: String) -> void:
	_last_hint_id = hint_id


## Replay the most recently shown hint by un-marking it as seen and returning
## its ID.  Returns "" if no hint has been shown yet.
func replay_current_hint() -> String:
	if _last_hint_id == "":
		return ""
	_seen.erase(_last_hint_id)
	return _last_hint_id
