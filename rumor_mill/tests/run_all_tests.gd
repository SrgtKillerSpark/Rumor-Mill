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

	print("\n=== All suites complete ===")
