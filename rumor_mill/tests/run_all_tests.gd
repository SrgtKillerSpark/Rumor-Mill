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
##
## Run from the Godot editor:  Scene → Run Script.
## All suites use synthetic in-memory data — no live game nodes required.

extends RefCounted

func _init() -> void:
	print("=== Rumor Mill unit tests ===\n")

	print("── PropagationEngine ──")
	TestPropagationEngine.run()

	print("\n── ReputationSystem ──")
	TestReputationSystem.run()

	print("\n── ScenarioConditions ──")
	TestScenarioConditions.run()

	print("\n── SaveCorruption ──")
	TestSaveCorruption.run()

	print("\n── SaveManager ──")
	TestSaveManager.run()

	print("\n── AchievementManager ──")
	TestAchievementManager.run()

	print("\n── FactionEventSystem ──")
	TestFactionEventSystem.run()

	print("\n── SPA-970..976 Regressions ──")
	TestSpa970976Regressions.run()

	print("\n── TutorialSystem ──")
	TestTutorialSystem.run()

	print("\n── TutorialController ──")
	TestTutorialController.run()

	print("\n── SuggestionEngine ──")
	TestSuggestionEngine.run()

	print("\n── World ──")
	TestWorld.run()

	print("\n── AudioManager ──")
	TestAudioManager.run()

	print("\n── TransitionManager ──")
	TestTransitionManager.run()

	print("\n── DailyPlanningOverlay ──")
	TestDailyPlanningOverlay.run()

	print("\n── IntelStore ──")
	TestIntelStore.run()

	print("\n── GameState ──")
	TestGameState.run()

	print("\n── SocialGraph ──")
	TestSocialGraph.run()

	print("\n── AchievementHooks ──")
	TestAchievementHooks.run()

	print("\n── ScenarioManager ──")
	TestScenarioManager.run()

	print("\n── NpcCore ──")
	TestNpcCore.run()

	print("\n── SocialGraphOverlay ──")
	TestSocialGraphOverlay.run()

	print("\n── ReconController ──")
	TestReconController.run()

	print("\n── ReconHud ──")
	TestReconHud.run()

	print("\n── RumorPanel ──")
	TestRumorPanel.run()

	print("\n── PauseMenu ──")
	TestPauseMenu.run()

	print("\n── SettingsMenu ──")
	TestSettingsMenu.run()

	print("\n── MidGameEventAgent ──")
	TestMidGameEventAgent.run()

	print("\n── DayNightCycle ──")
	TestDayNightCycle.run()

	print("\n── EndScreenAnimations ──")
	TestEndScreenAnimations.run()

	print("\n── EndScreenFeedback ──")
	TestEndScreenFeedback.run()

	print("\n── EndScreenNavigation ──")
	TestEndScreenNavigation.run()

	print("\n── EndScreenPanelBuilder ──")
	TestEndScreenPanelBuilder.run()

	print("\n── EndScreenScoring ──")
	TestEndScreenScoring.run()

	print("\n── EndScreenSummary ──")
	TestEndScreenSummary.run()

	print("\n── EndScreenReplayTab ──")
	TestEndScreenReplayTab.run()

	print("\n── ObjectiveHudMetrics ──")
	TestObjectiveHudMetrics.run()

	print("\n── ObjectiveHudNudgeManager ──")
	TestObjectiveHudNudgeManager.run()

	print("\n── ObjectiveHudWinTracker ──")
	TestObjectiveHudWinTracker.run()

	print("\n── HudTooltip ──")
	TestHudTooltip.run()

	print("\n── NpcTooltip ──")
	TestNpcTooltip.run()

	print("\n── BuildingTooltip ──")
	TestBuildingTooltip.run()

	print("\n── NpcDialogue ──")
	TestNpcDialogue.run()

	print("\n── NpcMovement ──")
	TestNpcMovement.run()

	print("\n── NpcRumorProcessing ──")
	TestNpcRumorProcessing.run()

	print("\n── NpcVisuals ──")
	TestNpcVisuals.run()

	print("\n── JournalFactionsSection ──")
	TestJournalFactionsSection.run()

	print("\n── JournalIntelSection ──")
	TestJournalIntelSection.run()

	print("\n── JournalObjectivesSection ──")
	TestJournalObjectivesSection.run()

	print("\n── JournalRumorsSection ──")
	TestJournalRumorsSection.run()

	print("\n── JournalTimelineSection ──")
	TestJournalTimelineSection.run()

	print("\n── RumorPanelClaimList ──")
	TestRumorPanelClaimList.run()

	print("\n── RumorPanelEstimates ──")
	TestRumorPanelEstimates.run()

	print("\n── RumorPanelSeedList ──")
	TestRumorPanelSeedList.run()

	print("\n── RumorPanelSubjectList ──")
	TestRumorPanelSubjectList.run()

	print("\n── RumorPanelTooltip ──")
	TestRumorPanelTooltip.run()

	print("\n── EndScreen ──")
	TestEndScreen.run()

	print("\n── Journal ──")
	TestJournal.run()

	print("\n── ObjectiveHud ──")
	TestObjectiveHud.run()

	print("\n── Main ──")
	TestMain.run()

	print("\n── UILayerManager ──")
	TestUILayerManager.run()

	print("\n── TutorialWiring ──")
	TestTutorialWiring.run()

	print("\n── ObjectiveHudBanner ──")
	TestObjectiveHudBanner.run()

	print("\n=== All suites complete ===")
