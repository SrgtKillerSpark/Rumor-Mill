## guild_defense_agent.gd — Autonomous agent that defends Aldric Vane in Scenario 6.
##
## Ghost system: no sprite, no movement. Activates only in Scenario 6.
## On a cooldown schedule, merchant allies (Sybil, Rufus, Bess, Idris) spread
## praise rumors about Aldric Vane — simulating the guild closing ranks.
## This creates opposition: the player must outpace the defensive praise
## or route accusations through non-merchant channels.
##
## Integration:
##   - World instantiates GuildDefenseAgent and calls activate() for scenario_6.
##   - World._on_day_changed() calls guild_defense_agent.tick(day, self).

class_name GuildDefenseAgent

## Emitted each time a defender successfully seeds a praise rumor.
signal defense_fired(day: int, defender_id: String, target_id: String)

var _active: bool = false
var _last_defense_day: int = 0

## NPC IDs of the merchant allies who defend Aldric.
var defender_npc_ids: Array[String] = ["sybil_oats", "rufus_bolt", "bess_wicker", "idris_kemp"]

## The NPC being defended.
var defense_target_id: String = "aldric_vane"

## Reputation boost per praise rumor.
var praise_intensity: int = 2

## Days between defense rounds.
var cooldown_days: int = 3

## First day defense activates.
var start_day: int = 5

## Difficulty modifier applied to cooldown (positive = slower defense).
var cooldown_offset: int = 0


func activate() -> void:
	_active = true
	_last_defense_day = 0


## Called once per in-game day from World._on_day_changed().
## world must expose: inject_rumor(), npcs, intel_store.
func tick(current_day: int, world: Node) -> void:
	if not _active:
		return
	if current_day < start_day:
		return
	var effective_cooldown: int = maxi(1, cooldown_days + cooldown_offset)
	if _last_defense_day > 0 and current_day - _last_defense_day < effective_cooldown:
		return
	_seed_defense_rumor(current_day, world)
	_last_defense_day = current_day


func _seed_defense_rumor(day: int, world: Node) -> void:
	var defender_id := _pick_defender(world)
	if defender_id.is_empty():
		return

	var rumor_id: String = world.inject_rumor(
		defender_id, "praise", praise_intensity, defense_target_id, "guild_defense")
	if not rumor_id.is_empty():
		defense_fired.emit(day, defender_id, defense_target_id)


## Picks a defender NPC that is alive and has lowest heat.
## Rotates through defenders to spread the defense across multiple NPCs.
func _pick_defender(world: Node) -> String:
	var intel_store: PlayerIntelStore = world.intel_store
	var best_id: String = ""
	var best_heat: float = 999.0

	for npc in world.npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		if npc_id not in defender_npc_ids:
			continue
		var heat: float = intel_store.get_heat(npc_id) if intel_store != null else 0.0
		if heat < best_heat:
			best_heat = heat
			best_id = npc_id

	return best_id
