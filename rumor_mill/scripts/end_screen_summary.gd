class_name EndScreenSummary
extends RefCounted

## end_screen_summary.gd — Fail-reason inference, outcome narrative lookup,
## and "what went wrong" defeat text for EndScreen.
##
## Extracted from end_screen.gd and end_screen_scoring.gd (SPA-1016).
## Owns all outcome-text logic: scenario summary narratives, fail-reason
## inference from world state, and the SPA-784 defeat one-liner table.
##
## Call setup(world_ref, day_night_ref) once refs are known. Then:
##   infer_fail_reason(scenario_id) -> String
##   get_summary_text(scenario_id, won, fail_reason) -> String
##   get_what_went_wrong(fail_reason) -> String

# ── SPA-784: "What went wrong" defeat one-liner ────────────────────────────
const WHAT_WENT_WRONG := {
	"exposed":              "You were identified — the rumor lost its anonymity.",
	"timeout":              "You ran out of time before the story could take hold.",
	"contradicted":         "A credible voice contradicted the rumor publicly.",
	"calder_implicated":    "Calder became the target of your own narrative.",
	"aldric_destroyed":     "Aldric's reputation collapsed under your campaign.",
	"marta_silenced":       "Marta was turned into the villain of her own story.",
	"reputation_collapsed": "A protected NPC's reputation fell below the threshold.",
}

# ── Summary text (SPA-128 design doc) ─────────────────────────────────────────
const SUMMARY_TEXT := {
	1: {
		"win": (
			"Edric Fenn resigned the aldermanship within a fortnight, citing ill health that no physician"
			+ " could confirm. Your patron's candidate was endorsed by Prior Aldous before the tax rolls"
			+ " were ever signed, and the autumn assessment passed quietly under new hands."
			+ " The story you planted has already grown three different endings — none of them yours."
		),
		"exposed": (
			"Bram the Guard Captain never moved against you openly — he didn't have to. Once your movements"
			+ " were common knowledge, every rumor you had planted lost its anonymous source and gained"
			+ " a suspect instead. The town closed around Edric Fenn like a fist,"
			+ " and your patron stopped sending letters."
		),
		"timeout": (
			"The tax rolls were sealed before your work could ripen. Fenn's position hardened rather than"
			+ " cracked — a man under rumored attack earns sympathy in a town that fears disruption more"
			+ " than corruption. Your patron made other arrangements. You were not part of them."
		),
	},
	2: {
		"win": (
			"Alys the Herb-Wife left quietly before anyone thought to ask why the illness talk had started."
			+ " Sister Maren's public correction came too late to help her — the customers had already"
			+ " returned to Vera the Midwife, and the market season closed without incident."
			+ " The rumor itself died the way it began: with no one admitting they had started it."
		),
		"contradicted": (
			"Sister Maren's public rebuttal did not name you, but it didn't need to. The town's sympathy"
			+ " shifted to Alys overnight, and the Midwife's customers began to wonder whether the illness"
			+ " talk had been honest concern or deliberate cruelty."
			+ " Alys is still here. You are somewhat less welcome than you were."
		),
		"timeout": (
			"The autumn market ran its full course, and Alys ran hers alongside it. By the last week,"
			+ " several of the Midwife's regular customers had begun buying from both stalls. The window"
			+ " to shape opinion had closed; the market had simply decided. Your wages were not forthcoming."
		),
	},
	3: {
		"win": (
			"Calder Fenn's name was read at the winter festival to a cheer that surprised even Lady Isolde."
			+ " Tomas Reeve accepted a minor administrative posting with the quiet dignity of a man who"
			+ " knows he has already lost. The nomination process moved forward without anyone examining"
			+ " too closely how the ground had shifted beneath it."
		),
		"calder_implicated": (
			"The story mutated somewhere between the Tavern and the Chapel steps — praise curdling into"
			+ " suspicion faster than anyone had expected. Calder Fenn became the subject rather than the"
			+ " beneficiary, and Lady Isolde recognised your fingerprints long before she said so."
			+ " Tomas Reeve, watching from the sidelines, appeared to find the situation quietly satisfying."
		),
		"timeout": (
			"The winter festival came and the nominations were read to a crowd that had settled on no opinion."
			+ " Calder Fenn's name earned the same polite acknowledgement as Tomas Reeve's — neither elevated,"
			+ " neither ruined, neither story quite landing. Lady Isolde paid what was agreed and said nothing"
			+ " beyond that. The ledger, at least, was square."
		),
	},
	4: {
		"win": (
			"Brother Cornelius departed with an unsigned writ and the Bishop's clerk recorded the outcome as"
			+ " 'insufficient evidence.' The three accused returned to their posts — Aldous to his sermons,"
			+ " Vera to her patients, Finn to his prayers — as though the inquisitor had been a passing storm."
			+ " The town chose its own, and the Church accepted the choice. This time."
		),
		"reputation_collapsed": (
			"The stories took root faster than you could uproot them. By the time you understood the shape"
			+ " of the inquisitor's campaign, the town had already chosen its side — and it was not yours."
			+ " The writ was signed before the twentieth day. The accused were led away quietly,"
			+ " and the town returned to its business with the relief of people who had found someone to blame."
		),
		"timeout": (
			"Twenty days passed and the inquisitor's patience outlasted yours. The stories you countered"
			+ " had not been silenced — only muffled. Brother Cornelius presented his findings with the quiet"
			+ " confidence of a man whose work was already done. The formal verdict was a formality."
		),
	},
	5: {
		"win": (
			"The votes were counted in the Town Hall with the doors open and the crowd pressing in."
			+ " Aldric Vane's name was called three times for every one of Edric's. Tomas Reeve's supporters"
			+ " had already left. The new alderman accepted the chain of office with a speech about honest"
			+ " trade and fair governance. Your patron watched from the second row, expressionless."
			+ " But when Vane finished, the old merchant raised his cup — just once, just slightly."
			+ " You were already packed."
		),
		"aldric_destroyed": (
			"The story had started as praise. Somewhere between the Tavern and the Market it curdled — too"
			+ " much too fast, the name repeated until the repetition itself became suspicious."
			+ " Aldric Vane withdrew his candidacy at noon without explanation. His supporters scattered"
			+ " like starlings from a broken eave. Your patron's investment, and whatever goodwill"
			+ " you had built in this town, went with them."
		),
		"timeout": (
			"The votes were counted. Edric Fenn's name was called first, as it had been called for nine years."
			+ " Aldric Vane came second — close enough to taste, far enough to know it was finished."
			+ " Tomas Reeve's handful of supporters consoled themselves with ale and reform pamphlets"
			+ " that no one would read. Your patron did not send for you again."
		),
	},
	6: {
		"win": (
			"The guild audit was called on a Tuesday — at Marta Coin's request, seconded by the Prior."
			+ " Aldric Vane did not attend. His seat in the Guild Hall was empty when the real ledger"
			+ " was read aloud, and the silence that followed it was louder than any accusation"
			+ " you had ever whispered. Marta Coin was elected interim Guild Master before the week was out."
			+ " She did not mention your name. She didn't need to."
		),
		"marta_silenced": (
			"The story changed overnight. Suddenly it was Marta who was the thief — Marta who had falsified"
			+ " records, Marta whose name could not be trusted in any ledger or marketplace."
			+ " Aldric's allies moved with the speed of people who had been waiting for exactly this opening."
			+ " By the time you understood what had happened, Marta's stall was shuttered and her name"
			+ " was poison in the market quarter. You had underestimated how quickly a guild can close ranks."
		),
		"exposed": (
			"The Guard Captain found you at the well, just after dawn."
			+ " 'Aldric Vane sends his regards,' he said — not a threat, a statement of fact."
			+ " By noon, every merchant in the quarter knew your face and your purpose."
			+ " Marta Coin denied ever meeting you. She had no choice, and you could not blame her for it."
		),
		"timeout": (
			"Twenty days passed. The ledger sat in Marta's locked chest, still waiting for the right moment."
			+ " The right moment never came. Aldric Vane's reputation was bruised but intact, and the guild"
			+ " closed its books for the season with the quiet efficiency of an institution that had survived"
			+ " worse than whispers. Marta Coin paid you the second half of your fee without a word."
			+ " You both knew it had been wasted."
		),
	},
}

const SUMMARY_FALLBACK := {
	"timeout": (
		"The days ran out before the story ran deep enough. Rumors without roots fade with the season,"
		+ " and a town that almost changed simply doesn't."
		+ " Whatever you were paid to accomplish remains undone — the ledger stays open."
	),
	"exposed": (
		"Someone noticed the pattern before the pattern was finished. A foreign face asking the wrong"
		+ " questions in too many places invites scrutiny, and scrutiny is the one thing a rumor campaign"
		+ " cannot survive. You left the town largely intact, with only your reputation as a casualty."
	),
	"contradicted": (
		"A credible voice stepped forward and named the story for what it was: invention. The correction"
		+ " spread faster than the original rumor — corrections usually do, in towns where people are"
		+ " already suspicious. The target emerged with more goodwill than before you arrived."
	),
	"calder_implicated": (
		"The narrative slipped control and landed on the wrong person. When the person you were protecting"
		+ " becomes the subject of the story you were telling, the mission is over"
		+ " — and the client is rarely forgiving about it."
	),
	"aldric_destroyed": (
		"The person you were meant to elevate became the casualty of your own campaign."
		+ " Praise turned to scrutiny, scrutiny to suspicion, and suspicion to collapse."
		+ " The difference between making someone's name and ruining it is thinner than most people suppose,"
		+ " and you found that line from the wrong side."
	),
	"marta_silenced": (
		"The person you were meant to protect became the one they destroyed instead."
		+ " When the opposition turns your patron into the villain of your own story,"
		+ " the mission has already ended — you simply haven't admitted it yet."
		+ " The client's name is now the story, and you are not in it."
	),
}

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null
var _day_night_ref: Node   = null


func setup(world_ref: Node2D, day_night_ref: Node) -> void:
	_world_ref     = world_ref
	_day_night_ref = day_night_ref


## Returns the one-liner defeat text for the given fail reason.
func get_what_went_wrong(fail_reason: String) -> String:
	return WHAT_WENT_WRONG.get(fail_reason, "Your scheme unravelled.")


## Guess the fail reason from current world state.
func infer_fail_reason(scenario_id: int) -> String:
	if _world_ref == null or _world_ref.scenario_manager == null:
		return "timeout"
	var sm: ScenarioManager = _world_ref.scenario_manager
	if scenario_id == 3:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null:
			var calder := rep.get_snapshot(ScenarioManager.CALDER_FENN_ID)
			if calder != null and calder.score < ScenarioManager.S3_FAIL_CALDER_BELOW:
				return "calder_implicated"
	if scenario_id == 2:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null and rep.has_illness_rejecter(ScenarioManager.ALYS_HERBWIFE_ID, ScenarioManager.MAREN_NUN_ID):
			return "contradicted"
	if scenario_id == 4:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null:
			for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
				var snap := rep.get_snapshot(npc_id)
				if snap != null and snap.score < ScenarioManager.S4_FAIL_REP_BELOW:
					return "reputation_collapsed"
	if scenario_id == 5:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null:
			var aldric := rep.get_snapshot(ScenarioManager.ALDRIC_VANE_ID)
			if aldric != null and aldric.score < ScenarioManager.S5_FAIL_ALDRIC_BELOW:
				return "aldric_destroyed"
	if scenario_id == 6:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null:
			var marta := rep.get_snapshot(ScenarioManager.MARTA_COIN_ID)
			if marta != null and marta.score < ScenarioManager.S6_FAIL_MARTA_BELOW:
				return "marta_silenced"
		if _world_ref.intel_store != null:
			for npc_id in _world_ref.intel_store.heat:
				if _world_ref.intel_store.heat[npc_id] >= ScenarioManager.S6_EXPOSED_HEAT:
					return "exposed"
	# Check days elapsed vs allowed.
	if _day_night_ref != null and sm.get_days_allowed() > 0:
		var days_elapsed: int = _day_night_ref.current_day if "current_day" in _day_night_ref else 0
		if days_elapsed >= sm.get_days_allowed():
			return "timeout"
	# Scenario-appropriate fallback.
	if scenario_id == 1:
		return "exposed"
	return "timeout"


## Look up summary text from the SPA-128 table.
func get_summary_text(scenario_id: int, won: bool, fail_reason: String) -> String:
	var key := "win" if won else fail_reason
	var scenario_table: Dictionary = SUMMARY_TEXT.get(scenario_id, {})
	if scenario_table.has(key):
		return scenario_table[key]
	# Fall back to ScenarioManager (scenarios.json) for any key not in the hard-coded table.
	if _world_ref != null and _world_ref.scenario_manager != null:
		var sm: ScenarioManager = _world_ref.scenario_manager
		var json_text := sm.get_victory_text() if won else sm.get_fail_text(key)
		if not json_text.is_empty():
			return json_text
	if SUMMARY_FALLBACK.has(key):
		return SUMMARY_FALLBACK[key]
	return "Your scheme ran its course." if won else "Your scheme unravelled."
