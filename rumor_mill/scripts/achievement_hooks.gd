## achievement_hooks.gd — SPA-988: Achievement signal wiring extracted from main.gd.
##
## Bridges between in-game events (signals) and AchievementManager.
## Instantiated once per game session by main.gd's _init_achievement_hooks().
##
## External refs (day_night, analytics) must be set before connect_signals() is called.
## Per-session state resets automatically when a new AchievementHooks is created.

class_name AchievementHooks
extends RefCounted

## Nullable reference to the DayNight node; read current_day on scenario end.
var day_night: Node = null

## Nullable reference to the analytics logger; used for whisper_network check.
var analytics: Object = null

## True if the player was detected at any point this session.
var _ach_exposed: bool = false

## Tracks which action types the player has used this session.
## Keys: "observe", "eavesdrop", "craft", "bribe" → true when used.
var _ach_actions_used: Dictionary = {}


## Wire all per-session achievement signals.  Called once per game start.
func connect_signals(
		scenario_manager: Object,
		recon_ctrl: Object,
		rumor_panel: Object
) -> void:
	if scenario_manager != null:
		scenario_manager.scenario_resolved.connect(_on_achievement_scenario_resolved)
	if recon_ctrl != null:
		recon_ctrl.player_exposed.connect(_on_achievement_player_exposed)
		recon_ctrl.action_performed.connect(_on_achievement_action_performed)
		recon_ctrl.bribe_executed.connect(_on_achievement_bribe_executed)
	if rumor_panel != null:
		rumor_panel.rumor_seeded.connect(_on_achievement_rumor_seeded)


## Flags that the player was detected this session.
func _on_achievement_player_exposed() -> void:
	_ach_exposed = true


## Tracks Observe and Eavesdrop usage from action_performed messages.
func _on_achievement_action_performed(message: String, success: bool) -> void:
	if not success:
		return
	if message.begins_with("Observed"):
		_ach_actions_used["observe"] = true
	elif message.begins_with("Eavesdropped"):
		_ach_actions_used["eavesdrop"] = true


## Flags that Bribe was used at least once this session.
func _on_achievement_bribe_executed(_npc_name: String, _tick: int) -> void:
	_ach_actions_used["bribe"] = true


## Tracks Craft Rumor usage and unlocks "It Starts With a Whisper" on first seed.
func _on_achievement_rumor_seeded(
		_rumor_id: String,
		_subject_name: String,
		_claim_id: String,
		_seed_target_name: String
) -> void:
	_ach_actions_used["craft"] = true
	AchievementManager.unlock("a_rumor_begins")


## Central achievement evaluator called when a scenario resolves.
func _on_achievement_scenario_resolved(
		scenario_id: int,
		state: ScenarioManager.ScenarioState
) -> void:
	if state != ScenarioManager.ScenarioState.WON:
		return

	# Per-scenario completion.
	AchievementManager.unlock("scenario_%d_complete" % scenario_id)

	# Difficulty-based achievements.
	var diff: String = GameState.selected_difficulty
	if diff == "master":
		AchievementManager.unlock("master_victory")
	elif diff == "spymaster":
		AchievementManager.unlock("spymaster_victory")

	# Speed run: win within 10 days (inclusive).
	var current_day: int = day_night.current_day if day_night != null and "current_day" in day_night else 99
	if current_day <= 10:
		AchievementManager.unlock("speedrunner")

	# Ghost: won without any detection event.
	if not _ach_exposed:
		AchievementManager.unlock("ghost")

	# Jack of all trades: all four action types used.
	if (_ach_actions_used.has("observe") and _ach_actions_used.has("eavesdrop")
			and _ach_actions_used.has("craft") and _ach_actions_used.has("bribe")):
		AchievementManager.unlock("jack_of_all_trades")

	# Whisper network: 20+ unique NPCs received a rumor.
	if analytics != null:
		var ranking: Array = analytics.get_influence_ranking(9999)
		var recipients: int = 0
		for entry in ranking:
			if entry.get("received_count", 0) > 0:
				recipients += 1
		if recipients >= 20:
			AchievementManager.unlock("whisper_network")

	# Mastermind: all six scenarios completed (checks persisted unlock state).
	if (AchievementManager.is_unlocked("scenario_1_complete")
			and AchievementManager.is_unlocked("scenario_2_complete")
			and AchievementManager.is_unlocked("scenario_3_complete")
			and AchievementManager.is_unlocked("scenario_4_complete")
			and AchievementManager.is_unlocked("scenario_5_complete")
			and AchievementManager.is_unlocked("scenario_6_complete")):
		AchievementManager.unlock("mastermind")
