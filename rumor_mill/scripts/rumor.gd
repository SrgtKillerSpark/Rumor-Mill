## rumor.gd — Rumor data class and NpcRumorSlot state container.
## No Node inheritance; used as plain data objects.

class_name Rumor

enum ClaimType {
	ACCUSATION,
	SCANDAL,
	ILLNESS,
	PROPHECY,
	PRAISE,
	DEATH,
	HERESY,
	BLACKMAIL,
	SECRET_ALLIANCE,
	FORBIDDEN_ROMANCE
}

enum RumorState {
	UNAWARE,
	EVALUATING,
	BELIEVE,
	REJECT,
	SPREAD,
	ACT,
	CONTRADICTED, # subject has conflicting opposite-sentiment rumors both actively spreading
	EXPIRED,  # believability decayed to zero; stops propagating
	DEFENDING # NPC rejected a rumor about a high-loyalty ally and is actively countering it
}

var id: String
var subject_npc_id: String
var claim_type: ClaimType
var intensity: int          # 1–5
var mutability: float       # 0.0–1.0
var created_tick: int
var shelf_life_ticks: int
var current_believability: float
var lineage_parent_id: String  # "" = original
var bolstered_by_evidence: bool = false


static func create(
		rumor_id: String,
		subject_id: String,
		c_type: ClaimType,
		inten: int,
		mut: float,
		tick: int,
		shelf: int = 330,
		parent_id: String = ""
) -> Rumor:
	var r := Rumor.new()
	r.id = rumor_id
	r.subject_npc_id = subject_id
	r.claim_type = c_type
	r.intensity = clamp(inten, 1, 5)
	r.mutability = clamp(mut, 0.0, 1.0)
	r.created_tick = tick
	r.shelf_life_ticks = shelf
	r.current_believability = r.base_believability()
	r.lineage_parent_id = parent_id
	return r


func base_believability() -> float:
	return float(intensity) / 5.0


static func claim_type_from_string(s: String) -> ClaimType:
	match s.to_lower():
		"accusation":        return ClaimType.ACCUSATION
		"scandal":           return ClaimType.SCANDAL
		"illness":           return ClaimType.ILLNESS
		"prophecy":          return ClaimType.PROPHECY
		"praise":            return ClaimType.PRAISE
		"death":             return ClaimType.DEATH
		"heresy":            return ClaimType.HERESY
		"blackmail":         return ClaimType.BLACKMAIL
		"secret_alliance":   return ClaimType.SECRET_ALLIANCE
		"forbidden_romance": return ClaimType.FORBIDDEN_ROMANCE
		_:                   return ClaimType.ACCUSATION


## Returns true when shelf life has fully decayed.
func is_expired() -> bool:
	return current_believability <= 0.0


## Reduce believability by one tick's worth of decay.
## Called once per game tick by PropagationEngine.tick_decay().
func decay_one_tick() -> void:
	if shelf_life_ticks <= 0:
		current_believability = 0.0
		return
	current_believability = maxf(current_believability - (1.0 / float(shelf_life_ticks)), 0.0)


static func claim_type_name(ct: ClaimType) -> String:
	match ct:
		ClaimType.ACCUSATION:        return "accusation"
		ClaimType.SCANDAL:           return "scandal"
		ClaimType.ILLNESS:           return "illness"
		ClaimType.PROPHECY:          return "prophecy"
		ClaimType.PRAISE:            return "praise"
		ClaimType.DEATH:             return "death"
		ClaimType.HERESY:            return "heresy"
		ClaimType.BLACKMAIL:         return "blackmail"
		ClaimType.SECRET_ALLIANCE:   return "secret_alliance"
		ClaimType.FORBIDDEN_ROMANCE: return "forbidden_romance"
		_:                           return "rumor"


static func state_name(state: RumorState) -> String:
	match state:
		RumorState.UNAWARE:      return "UNAWARE"
		RumorState.EVALUATING:   return "EVALUATING"
		RumorState.BELIEVE:      return "BELIEVE"
		RumorState.REJECT:       return "REJECT"
		RumorState.SPREAD:       return "SPREAD"
		RumorState.ACT:          return "ACT"
		RumorState.CONTRADICTED: return "CONTRADICTED"
		RumorState.EXPIRED:      return "EXPIRED"
		RumorState.DEFENDING:    return "DEFENDING"
		_:                       return "UNKNOWN"


## Returns true for claim types with positive sentiment (PRAISE, PROPHECY).
## All other claim types are treated as negative sentiment.
static func is_positive_claim(ct: ClaimType) -> bool:
	return ct == ClaimType.PRAISE or ct == ClaimType.PROPHECY


# ---------------------------------------------------------------------------
# NpcRumorSlot — tracks one NPC's state for a single rumor.
# ---------------------------------------------------------------------------
class NpcRumorSlot:
	var state: Rumor.RumorState = Rumor.RumorState.UNAWARE
	var rumor: Rumor = null
	var ticks_in_state: int = 0
	var heard_from_count: int = 0
	var source_faction: String = ""

	func _init(r: Rumor, src_faction: String) -> void:
		rumor = r
		source_faction = src_faction
		state = Rumor.RumorState.EVALUATING
		ticks_in_state = 0
		heard_from_count = 1
