## run_all_tests.gd — Top-level test runner for Rumor Mill core systems (SPA-957).
##
## Runs all test suites in sequence and prints a consolidated summary.
##
## Suites included:
##   • TestPropagationEngine  — β/γ formulas, decay, chain detection & bonuses, lineage
##   • TestReputationSystem   — score formula, SOCIALLY_DEAD, illness tracking
##   • TestScenarioConditions — win/fail evaluation for Scenarios 1–6
##   • TestSaveCorruption     — save/load hardening (SPA-864, SPA-896, SPA-901)
##   • TestSaveManager        — save_path(), prepare_load(), pending state, migration (SPA-964)
##   • TestAchievementManager — unlock/query API and static definition table (SPA-964)
##   • TestFactionEventSystem — scheduling, activation, effects, expiry, hotspots, foreshadow, serialization (SPA-965)
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

	print("\n=== All suites complete ===")
