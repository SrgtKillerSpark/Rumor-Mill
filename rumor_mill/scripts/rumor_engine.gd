## rumor_engine.gd — A3.1 SPA-3294: Rumor priority decay curves.
##
## Manages a separate priority dimension alongside PropagationEngine's believability decay.
## Each tick, effective_priority = base_priority * decay_multiplier, where the multiplier
## falls from 1.0 toward DECAY_FLOOR (0.15) at DECAY_RATE (0.03) per tick elapsed since
## the player last interacted with the rumor.
##
## Interaction resets:
##   on_seed_reset     — full reset (decay_mult = 1.0): seeding same claim+subject
##   on_evidence_reset — full reset: attaching evidence to a seed
##   on_eavesdrop_reset — partial reset (clamp mult to ≥ 0.7): eavesdropping believer NPC
##   on_observe_reset   — partial reset (clamp mult to ≥ 0.7): observing subject NPC location
##
## Usage (called from World.on_game_tick after PropagationEngine.tick_decay):
##   rumor_engine.recalculate_priorities(current_tick)
##
## Interaction hooks are called from recon_controller and rumor_panel after qualifying actions.

class_name RumorEngine

## Priority decay rate per tick elapsed since last interaction.
## At 0.03/tick: 20 ticks ≈ 40% priority remaining (1.0 - 20*0.03 = 0.40).
const DECAY_RATE: float = 0.03

## Minimum decay multiplier — rumors never fully vanish from priority ranking.
const DECAY_FLOOR: float = 0.15

## Partial reset target multiplier — eavesdrop/observe raise decay_mult to at least this.
const PARTIAL_RESET_MULT: float = 0.7

## Shared reference to PropagationEngine.live_rumors. Set during world init.
## RumorEngine does not own this dict; PropagationEngine manages additions/removals.
var live_rumors: Dictionary = {}


# ── Per-tick priority recalculation ──────────────────────────────────────────

## Recompute effective_priority for every live rumor based on ticks elapsed since
## last_interaction_tick. Call once per game tick, after PropagationEngine.tick_decay().
func recalculate_priorities(current_tick: int) -> void:
	for rid in live_rumors:
		var r: Rumor = live_rumors[rid]
		var ticks_elapsed := current_tick - r.last_interaction_tick
		var decay_mult := maxf(DECAY_FLOOR, 1.0 - float(ticks_elapsed) * DECAY_RATE)
		r.effective_priority = r.base_priority * decay_mult


# ── Interaction reset API ─────────────────────────────────────────────────────

## Full priority reset: player seeded a rumor with the same claim type + subject.
## Sets last_interaction_tick = current_tick so decay_mult returns to 1.0.
func on_seed_reset(rumor: Rumor, current_tick: int) -> void:
	rumor.last_interaction_tick = current_tick


## Full priority reset: player attached evidence to a seed.
## Same mechanics as on_seed_reset; separated for clarity and future tuning.
func on_evidence_reset(rumor: Rumor, current_tick: int) -> void:
	rumor.last_interaction_tick = current_tick


## Partial priority reset: player eavesdropped on an NPC that believes this rumor.
## Raises the decay multiplier to at least PARTIAL_RESET_MULT (0.7) without exceeding
## the current value if it is already higher.
func on_eavesdrop_reset(rumor: Rumor, current_tick: int) -> void:
	_apply_partial_reset(rumor, current_tick)


## Partial priority reset: player observed a building where the rumor's subject NPC is.
## Same mechanics as on_eavesdrop_reset; separated for clarity and future tuning.
func on_observe_reset(rumor: Rumor, current_tick: int) -> void:
	_apply_partial_reset(rumor, current_tick)


# ── Internal helpers ──────────────────────────────────────────────────────────

## Raises rumor's decay_mult to PARTIAL_RESET_MULT if it has fallen below that threshold.
## To set last_interaction_tick so the new mult equals exactly PARTIAL_RESET_MULT:
##   decay_mult = 1.0 - ticks_elapsed * DECAY_RATE = PARTIAL_RESET_MULT
##   → ticks_elapsed = (1.0 - PARTIAL_RESET_MULT) / DECAY_RATE = 10 ticks
## No change if the current mult already meets or exceeds PARTIAL_RESET_MULT.
func _apply_partial_reset(rumor: Rumor, current_tick: int) -> void:
	var ticks_elapsed := current_tick - rumor.last_interaction_tick
	var current_mult := maxf(DECAY_FLOOR, 1.0 - float(ticks_elapsed) * DECAY_RATE)
	if current_mult < PARTIAL_RESET_MULT:
		var target_elapsed := int((1.0 - PARTIAL_RESET_MULT) / DECAY_RATE)
		rumor.last_interaction_tick = current_tick - target_elapsed
