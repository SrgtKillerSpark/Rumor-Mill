## run_all_tests.gd — Top-level test runner for Rumor Mill core systems (SPA-957).
##
## Runs all test suites in sequence and prints a consolidated summary.
##
## Suites included:
##   • TestPropagationEngine      — β/γ formulas, decay, chain detection & bonuses, lineage
##   • TestReputationSystem       — score formula, SOCIALLY_DEAD, illness tracking
##   • TestScenarioConditions     — win/fail evaluation for Scenarios 1–6
##   • TestSaveCorruption         — save/load hardening (SPA-864, SPA-896, SPA-901)
##   • TestSaveManager            — save_path(), prepare_load(), pending state, migration (SPA-964)
##   • TestAchievementManager     — unlock/query API and static definition table (SPA-964)
##   • TestFactionEventSystem     — scheduling, activation, effects, expiry, hotspots, foreshadow, serialization (SPA-965)
##   • TestSpa970976Regressions   — regression guard for SPA-970/974/975/976 bug fix batch (SPA-985)
##   • TestTutorialSystem         — seen tracking, tooltip/hint lookup, replay, static data integrity (SPA-981)
##   • TestTutorialController     — step constants, scenario routing, initial state, skip() (SPA-981)
##   • TestSuggestionEngine       — constants, cooldown logic, day-reset, unspent-actions text (SPA-981)
##   • TestWorld                  — tile/grid constants, faction schedules, initial state (SPA-981)
##   • TestAudioManager           — constants, phase detection, ambient state, dialogue duck, tension flags (SPA-982)
##   • TestTransitionManager      — initial state, _kill_tween guard, layer default (SPA-982)
##   • TestDailyPlanningOverlay   — priorities, counters, save/load round-trip, dawn handling, eval (SPA-982)
##   • TestIntelStore             — action budget, whisper tokens, heat, evidence, location/rel intel (SPA-987)
##   • TestGameState              — difficulty modifier keys, values, unknown preset fallback (SPA-987)
##   • TestSocialGraph            — edge weight, mutation cap, net delta, adjacency queries (SPA-987)
##   • TestAchievementHooks       — per-session state tracking: exposure, action flags, bribe (SPA-988)
##   • TestScenarioManager        — narrative getters, heat ceiling, time helpers, signals, progress dicts (SPA-997)
##   • TestNpcCore                — state queries, force_believe, credulity modifier, defense penalty, schedule avoidance, dialogue category, time phase (SPA-998)
##   • TestSocialGraphOverlay     — constants, initial state, pure-logic helpers, rumor event parsing (SPA-1000)
##   • TestReconController        — constants, coordinate conversion, belief_trend, initial state (SPA-1012)
##   • TestReconHud               — constants, pip/heat colours, initial state, contextual hint logic (SPA-1012)
##   • TestRumorPanel             — constants, colour helpers, initial state, believability/spread estimates (SPA-1012)
##   • TestPauseMenu              — palette constants, static var, initial state, setup wiring (SPA-1015)
##   • TestSettingsMenu           — palette constants, initial state, _close() behaviour (SPA-1015)
##   • TestMidGameEventAgent      — activation, window guards, probability firing, resolve choice, serialization, effects (SPA-1017)
##   • TestDayNightCycle          — initial state, TIME_COLORS, phase detection, shadow guard, skip_to_next_day, color interpolation, signals (SPA-1017)
##   • TestEndScreenAnimations    — initial state, setup wiring, start_count_up/start_btn_pulse null guards (SPA-1026)
##   • TestEndScreenFeedback      — presets, dimension/char constants, palette, initial state, setup wiring (SPA-1026)
##   • TestEndScreenNavigation    — initial state, set_scenario_id, next_scenario_id mapping table (SPA-1026)
##   • TestEndScreenPanelBuilder  — palette, dimension constants, initial public/private node refs (SPA-1026)
##   • TestEndScreenScoring       — PEAK_BELIEF_TARGET, NPC_OUTCOMES, palette, initial state, accessors, setup (SPA-1026)
##   • TestEndScreenSummary       — WHAT_WENT_WRONG, SUMMARY_TEXT, SUMMARY_FALLBACK, infer/lookup logic (SPA-1026)
##   • TestEndScreenReplayTab     — palette, initial state, setup wiring, populate null-analytics guard (SPA-1026)
##   • TestObjectiveHudMetrics    — initial state, _threat_word boundaries, _threat_color bands, refresh null guard (SPA-1026)
##   • TestObjectiveHudNudgeManager — palette, nudge texts, initial phase/budget/dep state (SPA-1026)
##   • TestObjectiveHudWinTracker — tempo colours, initial state, configure, setup_world, _get_progress_assessment, flash guard (SPA-1026)
##   • TestHudTooltip             — palette, layout constants, initial state, _hide_tooltip null-panel guard (SPA-1026)
##   • TestNpcTooltip             — FACTION_LABEL/COLOR, STATE_LABEL/COLOR/ICON, atlas constants, initial state (SPA-1026)
##   • TestBuildingTooltip        — palette, layout constants, initial state, setup, _world_to_cell conversion (SPA-1026)
##   • TestNpcDialogue            — _MAX_BUBBLES, _get_time_phase, initial state, on_exit_tree counter (SPA-1027)
##   • TestNpcMovement            — speed/chance constants, initial state, cell_to_world isometric math (SPA-1027)
##   • TestNpcRumorProcessing     — _MIN_EVAL_TICKS, initial state, setup, get_spread_preview guard clauses (SPA-1027)
##   • TestNpcVisuals             — sprite constants, STATE_TINT/EMOTES tables, hover tint, initial state (SPA-1027)
##   • TestJournalFactionsSection — palette, initial state, setup, _get_rumor_by_id null guard (SPA-1027)
##   • TestJournalIntelSection    — palette, initial state, setup, _tick_to_day_str (SPA-1027)
##   • TestJournalObjectivesSection — scenario day constants, palette, initial state, setup (SPA-1027)
##   • TestJournalRumorsSection   — initial state, setup, has_status_transitions, _rumor_journal_status, colours, transitions (SPA-1027)
##   • TestJournalTimelineSection — MAX_TIMELINE_ENTRIES, initial state, push/flush/restore, filters, has_new_entries_since (SPA-1027)
##   • TestRumorPanelClaimList    — CLAIM_ICON_INDEX, _claim_type_color, _intensity_color, initial state, setup (SPA-1027)
##   • TestRumorPanelEstimates    — estimate_spread and estimate_believability with mock world/heat (SPA-1027)
##   • TestRumorPanelSeedList     — faction colour constants, _faction_color, initial state, setup (SPA-1027)
##   • TestRumorPanelSubjectList  — portrait constants, palette, _faction_color, initial state, setup (SPA-1027)
##   • TestRumorPanelTooltip      — PERSIST_KEY, TOOLTIP_W/H, STEPS shape, _current_step initial value (SPA-1027)
##   • TestEndScreen              — initial state, subsystem refs null, setup() assignment (SPA-1024)
##   • TestJournal                — palette, Section enum, MAX_MILESTONE_ENTRIES, initial state,
##                                  push/get/restore milestone log, cap enforcement (SPA-1024)
##   • TestObjectiveHud           — urgency colour constants, CALLOUT_TOOLTIP_ID, initial state,
##                                  _get_urgency_color() all four bands, entrance animation guard (SPA-1024)
##   • TestMain                   — initial state, @onready scene refs null, _camera_shake null guard (SPA-1024)
##   • TestUILayerManager         — scene/public/private refs null, _on_player_exposed and flush null guards (SPA-1024)
##   • TestTutorialWiring         — all gate booleans false, counters zero, node refs null,
##                                  wire_pause_menu null guard (SPA-1024)
##   • TestObjectiveHudBanner     — colour constants, initial state, show_banner/snapshot/bulletin/check
##                                  null guards, on_deadline_warning text format (SPA-1024)
##   • TestNpcSchedule            — archetype_from_string, SLOTS_PER_DAY, get_location with base/work/overrides (SPA-1041)
##   • TestScenarioConfig         — all S1–S6 balance constants, NPC ids, arrays, phase windows (SPA-1041)
##   • TestRumor                  — create, base_believability, is_expired, decay_one_tick, is_positive_claim,
##                                  claim_type_name, NpcRumorSlot initial state (SPA-1041)
##   • TestRivalAgent             — initial state, activate, constants, _get_cooldown, can/apply_disruption,
##                                  _DEGRADE_MAP, scout (SPA-1041)
##   • TestGuildDefenseAgent      — initial state, config, activate, tick guards, effective cooldown (SPA-1041)
##   • TestIllnessEscalationAgent — constants, initial state, activate, _get_cooldown, tick guards (SPA-1041)
##   • TestInquisitorAgent        — constants, initial state, activate, tip/shield, _get_cooldown,
##                                  _pick_claim_type, tick guards (SPA-1041)
##   • TestS4FactionShiftAgent    — constants, initial state, activate, phase firing, bishop pressure,
##                                  _weakest_protected_npc null rep (SPA-1041)
##   • TestScenarioAnalytics      — initial state, _on_rumor_transmitted, _on_rumor_event, _on_socially_dead,
##                                  get_influence_ranking, finalize (SPA-1041)
##   • TestAstarPathfinder        — initial state, get_path guards, nearest_walkable static math (SPA-1041)
##   • TestQuarantineSystem       — constants, initial state, activate, query methods, tick expiry,
##                                  try_quarantine blocked/success cases (SPA-1041)
##   • TestWeatherSystem          — constants, initial state, _start_rain/_stop_rain state flags (SPA-1041)
##   • TestTownMoodController     — constants, initial state, set_camera, on_game_tick null guard (SPA-1041)
##   • TestNpcThoughtBubble       — MAX_VISIBLE, SYMBOL/STATE_COLOR/STATE_HINT dicts, initial state,
##                                  _exit_tree counter (SPA-1041)
##   • TestNpcInfoPanel           — palette, C_FACTION, C_BELIEF, BELIEF_LABEL/ICON, ACTIONS,
##                                  initial state (SPA-1041)
##
## Run from the Godot editor:  Scene → Run Script.
## All suites use synthetic in-memory data — no live game nodes required.

extends RefCounted

func _init() -> void:
	print("=== Rumor Mill unit tests ===\n")

	print("── PropagationEngine ──")
	TestPropagationEngine.new().run()

	print("\n── ReputationSystem ──")
	TestReputationSystem.new().run()

	print("\n── ScenarioConditions ──")
	TestScenarioConditions.new().run()

	print("\n── SaveCorruption ──")
	TestSaveCorruption.new().run()

	print("\n── SaveManager ──")
	TestSaveManager.new().run()

	print("\n── AchievementManager ──")
	TestAchievementManager.new().run()

	print("\n── FactionEventSystem ──")
	TestFactionEventSystem.new().run()

	print("\n── SPA-970..976 Regressions ──")
	TestSpa970976Regressions.run()

	print("\n── TutorialSystem ──")
	TestTutorialSystem.new().run()

	print("\n── TutorialController ──")
	TestTutorialController.new().run()

	print("\n── SuggestionEngine ──")
	TestSuggestionEngine.new().run()

	print("\n── World ──")
	TestWorld.new().run()

	print("\n── AudioManager ──")
	TestAudioManager.new().run()

	print("\n── TransitionManager ──")
	TestTransitionManager.new().run()

	print("\n── DailyPlanningOverlay ──")
	TestDailyPlanningOverlay.new().run()

	print("\n── IntelStore ──")
	TestIntelStore.new().run()

	print("\n── GameState ──")
	TestGameState.new().run()

	print("\n── SocialGraph ──")
	TestSocialGraph.new().run()

	print("\n── AchievementHooks ──")
	TestAchievementHooks.new().run()

	print("\n── ScenarioManager ──")
	TestScenarioManager.new().run()

	print("\n── NpcCore ──")
	TestNpcCore.new().run()

	print("\n── SocialGraphOverlay ──")
	TestSocialGraphOverlay.new().run()

	print("\n── ReconController ──")
	TestReconController.new().run()

	print("\n── ReconHud ──")
	TestReconHud.new().run()

	print("\n── RumorPanel ──")
	TestRumorPanel.new().run()

	print("\n── PauseMenu ──")
	TestPauseMenu.new().run()

	print("\n── SettingsMenu ──")
	TestSettingsMenu.new().run()

	print("\n── MidGameEventAgent ──")
	TestMidGameEventAgent.new().run()

	print("\n── DayNightCycle ──")
	TestDayNightCycle.new().run()

	print("\n── EndScreenAnimations ──")
	TestEndScreenAnimations.new().run()

	print("\n── EndScreenFeedback ──")
	TestEndScreenFeedback.new().run()

	print("\n── EndScreenNavigation ──")
	TestEndScreenNavigation.new().run()

	print("\n── EndScreenPanelBuilder ──")
	TestEndScreenPanelBuilder.new().run()

	print("\n── EndScreenScoring ──")
	TestEndScreenScoring.new().run()

	print("\n── EndScreenSummary ──")
	TestEndScreenSummary.new().run()

	print("\n── EndScreenReplayTab ──")
	TestEndScreenReplayTab.new().run()

	print("\n── ObjectiveHudMetrics ──")
	TestObjectiveHudMetrics.new().run()

	print("\n── ObjectiveHudNudgeManager ──")
	TestObjectiveHudNudgeManager.new().run()

	print("\n── ObjectiveHudWinTracker ──")
	TestObjectiveHudWinTracker.new().run()

	print("\n── HudTooltip ──")
	TestHudTooltip.new().run()

	print("\n── NpcTooltip ──")
	TestNpcTooltip.new().run()

	print("\n── BuildingTooltip ──")
	TestBuildingTooltip.new().run()

	print("\n── NpcDialogue ──")
	TestNpcDialogue.new().run()

	print("\n── NpcMovement ──")
	TestNpcMovement.new().run()

	print("\n── NpcRumorProcessing ──")
	TestNpcRumorProcessing.new().run()

	print("\n── NpcVisuals ──")
	TestNpcVisuals.new().run()

	print("\n── JournalFactionsSection ──")
	TestJournalFactionsSection.new().run()

	print("\n── JournalIntelSection ──")
	TestJournalIntelSection.new().run()

	print("\n── JournalObjectivesSection ──")
	TestJournalObjectivesSection.new().run()

	print("\n── JournalRumorsSection ──")
	TestJournalRumorsSection.new().run()

	print("\n── JournalTimelineSection ──")
	TestJournalTimelineSection.new().run()

	print("\n── RumorPanelClaimList ──")
	TestRumorPanelClaimList.new().run()

	print("\n── RumorPanelEstimates ──")
	TestRumorPanelEstimates.new().run()

	print("\n── RumorPanelSeedList ──")
	TestRumorPanelSeedList.new().run()

	print("\n── RumorPanelSubjectList ──")
	TestRumorPanelSubjectList.new().run()

	print("\n── RumorPanelTooltip ──")
	TestRumorPanelTooltip.new().run()

	print("\n── EndScreen ──")
	TestEndScreen.new().run()

	print("\n── Journal ──")
	TestJournal.new().run()

	print("\n── ObjectiveHud ──")
	TestObjectiveHud.new().run()

	print("\n── Main ──")
	TestMain.new().run()

	print("\n── UILayerManager ──")
	TestUILayerManager.new().run()

	print("\n── TutorialWiring ──")
	TestTutorialWiring.new().run()

	print("\n── ObjectiveHudBanner ──")
	TestObjectiveHudBanner.new().run()

	print("\n── NpcSchedule ──")
	TestNpcSchedule.new().run()

	print("\n── ScenarioConfig ──")
	TestScenarioConfig.new().run()

	print("\n── Rumor ──")
	TestRumor.new().run()

	print("\n── RivalAgent ──")
	TestRivalAgent.new().run()

	print("\n── GuildDefenseAgent ──")
	TestGuildDefenseAgent.new().run()

	print("\n── IllnessEscalationAgent ──")
	TestIllnessEscalationAgent.new().run()

	print("\n── InquisitorAgent ──")
	TestInquisitorAgent.new().run()

	print("\n── S4FactionShiftAgent ──")
	TestS4FactionShiftAgent.new().run()

	print("\n── ScenarioAnalytics ──")
	TestScenarioAnalytics.new().run()

	print("\n── AstarPathfinder ──")
	TestAstarPathfinder.new().run()

	print("\n── QuarantineSystem ──")
	TestQuarantineSystem.new().run()

	print("\n── WeatherSystem ──")
	TestWeatherSystem.new().run()

	print("\n── TownMoodController ──")
	TestTownMoodController.new().run()

	print("\n── NpcThoughtBubble ──")
	TestNpcThoughtBubble.new().run()

	print("\n── NpcInfoPanel ──")
	TestNpcInfoPanel.new().run()

	print("\n=== All suites complete ===")
