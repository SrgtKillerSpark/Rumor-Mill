## npc_schedule.gd — NPC daily schedule archetype tables and lookup.
##
## Tick model: the game day is divided into 6 schedule slots (ticks 0–5),
## each representing a 4-hour block starting at midnight.
##
##   Slot 0 = 00:00  Night / sleep
##   Slot 1 = 04:00  Early morning
##   Slot 2 = 08:00  Morning
##   Slot 3 = 12:00  Midday
##   Slot 4 = 16:00  Afternoon
##   Slot 5 = 20:00  Evening

class_name NpcSchedule

enum ScheduleArchetype {
	MERCHANT_WORKER,
	TAVERN_STAFF,
	NOBLE_HOUSEHOLD,
	GUARD_CIVIC,
	CLERGY,
	INDEPENDENT,
}

## Location code → gathering_point is resolved by world.gd.
## "work"  is substituted with the NPC's work_location field.
## "home"  is substituted with the NPC's _home_cell.
const ARCHETYPE_TABLES: Dictionary = {
	ScheduleArchetype.MERCHANT_WORKER: [
		"home", "home", "work", "market", "work", "tavern",
	],
	ScheduleArchetype.TAVERN_STAFF: [
		"tavern", "home", "home", "tavern", "tavern", "tavern",
	],
	ScheduleArchetype.NOBLE_HOUSEHOLD: [
		"manor", "manor", "alderman_house", "town_hall", "alderman_house", "manor",
	],
	ScheduleArchetype.GUARD_CIVIC: [
		"guardhouse", "patrol", "guardhouse", "patrol", "courthouse", "patrol",
	],
	ScheduleArchetype.CLERGY: [
		"chapel", "chapel", "chapel", "market", "chapel", "chapel",
	],
	ScheduleArchetype.INDEPENDENT: [
		"home", "home", "well", "market", "market", "tavern",
	],
}

## Number of schedule slots per game day.
const SLOTS_PER_DAY := 6


## Convert a string archetype name (as stored in npcs.json) to the enum.
static func archetype_from_string(s: String) -> ScheduleArchetype:
	match s.to_lower():
		"merchant_worker": return ScheduleArchetype.MERCHANT_WORKER
		"tavern_staff":    return ScheduleArchetype.TAVERN_STAFF
		"noble_household": return ScheduleArchetype.NOBLE_HOUSEHOLD
		"guard_civic":     return ScheduleArchetype.GUARD_CIVIC
		"clergy":          return ScheduleArchetype.CLERGY
		_:                 return ScheduleArchetype.INDEPENDENT


## Returns the location code string for an NPC at a given schedule slot and day.
##
## Parameters:
##   archetype          — ScheduleArchetype enum value
##   slot               — 0–5 (schedule tick for this day)
##   work_location      — building key for MERCHANT_WORKER "work" substitution
##   tick_overrides     — Dictionary { "slot_int_as_string": location_code }
##   day_pattern_overrides — Array of Dictionaries, each with:
##                            { "day_mod": int, "tick": int, "location": string }
##                            (fires when day % day_mod == 0 and tick matches)
##                          OR { "day": int, "tick": int, "location": string }
##                            (fires on a specific day number)
##   day                — current game day (1-based, from DayNightCycle.current_day)
##
## Returns a location code string such as "tavern", "chapel", "home", "work", etc.
static func get_location(
		archetype: ScheduleArchetype,
		slot: int,
		work_location: String,
		tick_overrides: Dictionary,
		day_pattern_overrides: Array,
		day: int
) -> String:
	# 1. Day-pattern overrides take highest priority.
	for override in day_pattern_overrides:
		if int(override.get("tick", -1)) != slot:
			continue
		var matches := false
		if override.has("day_mod"):
			var mod_val: int = int(override["day_mod"])
			matches = mod_val > 0 and (day % mod_val == 0)
		elif override.has("day"):
			matches = (day == int(override["day"]))
		if matches:
			return str(override["location"])

	# 2. Per-tick overrides.
	var slot_key := str(slot)
	if tick_overrides.has(slot_key):
		return str(tick_overrides[slot_key])

	# 3. Base archetype table.
	var table: Array = ARCHETYPE_TABLES.get(
		archetype, ARCHETYPE_TABLES[ScheduleArchetype.INDEPENDENT]
	)
	var base_loc: String = table[clamp(slot, 0, SLOTS_PER_DAY - 1)]

	# 4. Substitute "work" token.
	if base_loc == "work":
		return work_location if not work_location.is_empty() else "market"

	return base_loc
