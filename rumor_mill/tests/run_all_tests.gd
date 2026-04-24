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

	print("\n=== All suites complete ===")
