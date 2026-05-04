extends RefCounted

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
##   • TestSaveRoundtrip          — full serialize/restore round-trips for all 6 scenarios + all agent types (SPA-1090)
##   • TestAchievementManager     — unlock/query API and static definition table (SPA-964)
##   • TestAchievementSignal      — achievement_unlocked signal emission, payload, dedup (SPA-1093)
##   • TestFactionEventSystem     — scheduling, activation, effects, expiry, hotspots, foreshadow, serialization (SPA-965)
##   • TestSpa970976Regressions   — regression guard for SPA-970/974/975/976 bug fix batch (SPA-985)
##   • TestSpa1106NewGameRegression — fresh New Game must never trigger instant-victory (SPA-1106)
##   • TestSpa1544NewGameStateIsolation — DayNightCycle reset, SaveManager statics, MilestoneTracker
##                                        S1 threshold fix (SPA-1544)
##   • TestSpa1599AnalyticsDisabledGating — A4 acceptance criterion: evidence acquisition emits no
##                                          event when analytics disabled; positive control (SPA-1599)
##   • TestSpa1613EvidenceAcquired       — evidence_acquired NDJSON field shape for all 3 fire sites,
##                                          no double-emission guard, pre-setup queuing (SPA-1613)
##   • TestTutorialSystem         — seen tracking, tooltip/hint lookup, replay, static data integrity (SPA-981)
##   • TestTutorialController     — step constants, scenario routing, initial state, skip() (SPA-981)
##   • TestSuggestionEngine       — constants, cooldown logic, day-reset, unspent-actions text,
##                                  boundary validation for null deps in setup/refresh/triggers (SPA-981, SPA-1051)
##   • TestWorld                  — tile/grid constants, faction schedules, initial state (SPA-981)
##   • TestAudioManager           — constants, phase detection, ambient state, dialogue duck, tension flags (SPA-982)
##   • TestTransitionManager      — initial state, _kill_tween guard, layer default (SPA-982)
##   • TestDailyPlanningOverlay   — priorities, counters, save/load round-trip, dawn handling, eval (SPA-982)
##   • TestIntelStore             — action budget, whisper tokens, heat, evidence, location/rel intel (SPA-987)
##   • TestGameState              — difficulty modifier keys, values, unknown preset fallback (SPA-987)
##   • TestSocialGraph            — edge weight, mutation cap, net delta, adjacency queries (SPA-987)
##   • TestAchievementHooks       — per-session state tracking: exposure, action flags, bribe (SPA-988)
##   • TestScenarioManager        — narrative getters, heat ceiling, time helpers, signals, progress dicts (SPA-997)
##   • TestNpcCore                — state queries, force_believe, credulity modifier, defense penalty, schedule avoidance, dialogue category, time phase, hear_rumor, rebuild_npc_id_dict, reroute_if_avoided, chapel_frozen, has_engine, visual_state (SPA-998/SPA-1056)
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
##   • TestBuildingInterior       — ROSTER_RADIUS, FACTION_LABEL, initial state, setup_world_ref, _refresh_npc_roster guards and roster text (SPA-1078)
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
##   • TestAnalyticsManager       — initial state, _enqueue bounds/eviction, _flush_queue, handler queuing,
##                                  evidence passthrough guards (SPA-1054)
##   • TestAstarPathfinder        — initial state, get_path guards, nearest_walkable static math (SPA-1041)
##   • TestQuarantineSystem       — constants, initial state, activate, query methods, tick expiry,
##                                  try_quarantine blocked/success cases (SPA-1041)
##   • TestWeatherSystem          — constants, initial state, _start_rain/_stop_rain state flags (SPA-1041)
##   • TestTownMoodController     — constants, initial state, set_camera, on_game_tick null guard (SPA-1041)
##   • TestNpcThoughtBubble       — MAX_VISIBLE, SYMBOL/STATE_COLOR/STATE_HINT dicts, initial state,
##                                  _exit_tree counter (SPA-1041)
##   • TestNpcInfoPanel           — palette, C_FACTION, C_BELIEF, BELIEF_LABEL/ICON, ACTIONS,
##                                  initial state (SPA-1041)
##   • TestBaseScenarioHud        — palette, score/bar constants, node refs null (SPA-1042)
##   • TestScenario1Hud           — palette, bar constants, node refs null (SPA-1042)
##   • TestScenario2Hud           — palette, bar constants, node refs null (SPA-1042)
##   • TestScenario3Hud           — palette, bar constants, _bar_color_for_score() branches (SPA-1042)
##   • TestScenario4Hud           — palette, bar constants, node refs null (SPA-1042)
##   • TestScenario5Hud           — palette, bar constants, _momentum_arrow() branches (SPA-1042)
##   • TestScenario6Hud           — palette, bar/blackmail constants, node refs null (SPA-1042)
##   • TestMainMenu               — Phase enum, palette, initial state, module refs null (SPA-1042)
##   • TestMainMenuBriefingPanel  — portrait constants, faction row, clothing base, initial refs null (SPA-1042)
##   • TestMainMenuScenarioSelect — SCENARIO_ACCENT/DIFFICULTY/DESCRIPTOR, initial state (SPA-1042)
##   • TestMainMenuSettingsPanel  — palette, node refs null (SPA-1042)
##   • TestMainMenuStatsPanel     — palette, panel ref null (SPA-1042)
##   • TestHowToPlay              — Tab enum, palette, initial state, node refs null (SPA-1042)
##   • TestLoadingTips            — constants, palette, initial state, end_transition() guard (SPA-1042)
##   • TestMilestoneNotifier      — layout constants, PROGRESS_PARTICLE_MAP, initial state (SPA-1042)
##   • TestMilestoneTracker       — palette, initial state, _fire() dedup guard (SPA-1042)
##   • TestSpeedHud               — Speed enum, TICK_DURATION, initial state (SPA-1042)
##   • TestZoneIndicator          — LOCATION_NAMES, SKIP_LOCATIONS, tile constants, initial state (SPA-1042)
##   • TestFeedbackSequence       — palette, shader constants, initial state (SPA-1042)
##   • TestStoryRecap             — palette, initial node refs null (SPA-1042)
##   • TestMissionBriefing        — palette, sprite constants, faction rows, initial state (SPA-1042)
##   • TestMissionCard            — palette, layout constants, initial state (SPA-1042)
##   • TestEventCard              — palette, dimension constants, initial node refs null (SPA-1042)
##   • TestEventChoiceModal       — dimension constants, initial node refs null (SPA-1042)
##   • TestStrategicOverview      — palette, AUTO_DISMISS, sprite constants, initial state (SPA-1042)
##   • TestDistrictOverlay        — DISTRICTS, tile constants, _iso() pure math (SPA-1042)
##   • TestTownMapOverlay         — tile/gather constants, FACTION_COLORS, initial state (SPA-1042)
##   • TestTooltipManager         — fade/panel constants, OFFSET, initial state (SPA-1042)
##   • TestReconTooltipManager    — initial node refs null (SPA-1042)
##   • TestSuggestionToast        — palette, AUTO_DISMISS constants, _shown_at_sec (SPA-1042)
##   • TestAchievementToast       — constants, initial queue state, enqueue-when-showing, drain no-op (SPA-1144)
##   • TestVisualAffordances      — palette, fade constants, initial state, _enabled default true (SPA-1042)
##   • TestWhatsChangedCard       — palette, initial node refs null (SPA-1042)
##   • TestTutorialBanner         — layout constants, palette, initial state (SPA-1042)
##   • TestTutorialHud            — layout constants, initial state (SPA-1042)
##   • TestContextControlsPanel   — Mode enum, MODE_BINDINGS, palette, initial state (SPA-1042)
##   • TestControlsReference      — BINDINGS, initial state, toggle() visibility flip (SPA-1042)
##   • TestHelpReminderUI         — controls_ref null (SPA-1042)
##   • TestThoughtBubbleLegend    — palette, LEGEND_ENTRIES, constants, initial state (SPA-1042)
##   • TestReadyOverlay           — palette, initial node refs null, initial state (SPA-1042)
##   • TestCamera                 — export defaults, initial state (SPA-1042)
##   • TestNpcDialoguePanel       — layout/palette constants, initial state, faction colour helpers,
##                                  state→category map, belief hints, greeting picker (SPA-1057)
##   • TestRumorTrackerHud        — constants, palette, initial state, flash timer logic,
##                                  _depth_dfs, _collect_lineage, _max_descendant_depth (SPA-1057)
##   • TestAmbientParticles       — hour-window constants, initial state, _apply_hour() emitter logic (SPA-1065)
##   • TestAnalyticsLogger        — SAVE_PATH, initial state, start_session, get_session_duration (SPA-1065)
##   • TestDistrictPropsRegistry  — PROPS count, required keys, no duplicate ids, props_for_district,
##                                  district_labels (SPA-1065)
##   • TestFactionPalette         — ZONE_COLORS/BADGE_COLORS/DISPLAY_NAMES, accessor methods,
##                                  fallback behavior, all_ids (SPA-1065)
##   • TestGameInputHandler       — initial state, setup wiring, signal declaration (SPA-1065)
##   • TestNpc                    — grid/defender/credulity constants, initial state, subsystem refs null,
##                                  signal declarations (SPA-1065)
##   • TestNpcConversationOverlay — range/duration constants, color constants, initial state (SPA-1065)
##   • TestPlayerStats            — constants, initial state, start_session, flush guard, get_totals (SPA-1065)
##   • TestProgressData           — SAVE_PATH, is_completed guard, mark/get round-trip (SPA-1065)
##   • TestRumorEventWiring       — initial state, reward guards, planning handler null guards (SPA-1065)
##   • TestRumorRippleVfx         — constants, initial _elapsed, accent_color default and writability (SPA-1065)
##   • TestScenarioEnvironmentPalette — SCENARIO_MOODS/DISTRICT_PALETTES, accessor methods,
##                                  fallback behavior, all_ids (SPA-1065)
##   • TestSettingsManager        — DEFAULT_* constants, scale presets, _to_db(), label helpers,
##                                  set_text_size_index (SPA-1065)
##
## Run from the Godot editor:  Scene → Run Script.
## All suites use synthetic in-memory data — no live game nodes required.

const TestAchievementHooks = preload("res://tests/test_achievement_hooks.gd")
const TestAchievementManager = preload("res://tests/test_achievement_manager.gd")
const TestAchievementSignal = preload("res://tests/test_achievement_signal.gd")
const TestAchievementToast = preload("res://tests/test_achievement_toast.gd")
const TestAmbientParticles = preload("res://tests/test_ambient_particles.gd")
const TestAnalyticsLogger = preload("res://tests/test_analytics_logger.gd")
const TestAnalyticsManager = preload("res://tests/test_analytics_manager.gd")
const TestAstarPathfinder = preload("res://tests/test_astar_pathfinder.gd")
const TestAudioManager = preload("res://tests/test_audio_manager.gd")
const TestBaseScenarioHud = preload("res://tests/test_base_scenario_hud.gd")
const TestBuildingInterior = preload("res://tests/test_building_interior.gd")
const TestBuildingTooltip = preload("res://tests/test_building_tooltip.gd")
const TestCamera = preload("res://tests/test_camera.gd")
const TestContextControlsPanel = preload("res://tests/test_context_controls_panel.gd")
const TestControlsReference = preload("res://tests/test_controls_reference.gd")
const TestDailyPlanningOverlay = preload("res://tests/test_daily_planning_overlay.gd")
const TestDayNightCycle = preload("res://tests/test_day_night_cycle.gd")
const TestDistrictOverlay = preload("res://tests/test_district_overlay.gd")
const TestDistrictPropsRegistry = preload("res://tests/test_district_props_registry.gd")
const TestEndScreen = preload("res://tests/test_end_screen.gd")
const TestEndScreenAnimations = preload("res://tests/test_end_screen_animations.gd")
const TestEndScreenFeedback = preload("res://tests/test_end_screen_feedback.gd")
const TestEndScreenNavigation = preload("res://tests/test_end_screen_navigation.gd")
const TestEndScreenPanelBuilder = preload("res://tests/test_end_screen_panel_builder.gd")
const TestEndScreenReplayTab = preload("res://tests/test_end_screen_replay_tab.gd")
const TestEndScreenScoring = preload("res://tests/test_end_screen_scoring.gd")
const TestEndScreenSummary = preload("res://tests/test_end_screen_summary.gd")
const TestEventCard = preload("res://tests/test_event_card.gd")
const TestEventChoiceModal = preload("res://tests/test_event_choice_modal.gd")
const TestFactionEventSystem = preload("res://tests/test_faction_event_system.gd")
const TestFactionPalette = preload("res://tests/test_faction_palette.gd")
const TestFeedbackSequence = preload("res://tests/test_feedback_sequence.gd")
const TestGameInputHandler = preload("res://tests/test_game_input_handler.gd")
const TestGameState = preload("res://tests/test_game_state.gd")
const TestGuildDefenseAgent = preload("res://tests/test_guild_defense_agent.gd")
const TestHelpReminderUI = preload("res://tests/test_help_reminder_ui.gd")
const TestHowToPlay = preload("res://tests/test_how_to_play.gd")
const TestHudTooltip = preload("res://tests/test_hud_tooltip.gd")
const TestIllnessEscalationAgent = preload("res://tests/test_illness_escalation_agent.gd")
const TestInquisitorAgent = preload("res://tests/test_inquisitor_agent.gd")
const TestIntelStore = preload("res://tests/test_intel_store.gd")
const TestJournal = preload("res://tests/test_journal.gd")
const TestJournalFactionsSection = preload("res://tests/test_journal_factions_section.gd")
const TestJournalIntelSection = preload("res://tests/test_journal_intel_section.gd")
const TestJournalObjectivesSection = preload("res://tests/test_journal_objectives_section.gd")
const TestJournalRumorsSection = preload("res://tests/test_journal_rumors_section.gd")
const TestJournalTimelineSection = preload("res://tests/test_journal_timeline_section.gd")
const TestLoadingTips = preload("res://tests/test_loading_tips.gd")
const TestMain = preload("res://tests/test_main.gd")
const TestMainMenu = preload("res://tests/test_main_menu.gd")
const TestMainMenuBriefingPanel = preload("res://tests/test_main_menu_briefing_panel.gd")
const TestMainMenuScenarioSelect = preload("res://tests/test_main_menu_scenario_select.gd")
const TestMainMenuSettingsPanel = preload("res://tests/test_main_menu_settings_panel.gd")
const TestMainMenuStatsPanel = preload("res://tests/test_main_menu_stats_panel.gd")
const TestMidGameEventAgent = preload("res://tests/test_mid_game_event_agent.gd")
const TestMilestoneNotifier = preload("res://tests/test_milestone_notifier.gd")
const TestMilestoneTracker = preload("res://tests/test_milestone_tracker.gd")
const TestMissionBriefing = preload("res://tests/test_mission_briefing.gd")
const TestMissionCard = preload("res://tests/test_mission_card.gd")
const TestNpc = preload("res://tests/test_npc.gd")
const TestNpcConversationOverlay = preload("res://tests/test_npc_conversation_overlay.gd")
const TestNpcCore = preload("res://tests/test_npc_core.gd")
const TestNpcDialogue = preload("res://tests/test_npc_dialogue.gd")
const TestNpcDialoguePanel = preload("res://tests/test_npc_dialogue_panel.gd")
const TestNpcInfoPanel = preload("res://tests/test_npc_info_panel.gd")
const TestNpcMovement = preload("res://tests/test_npc_movement.gd")
const TestNpcRumorProcessing = preload("res://tests/test_npc_rumor_processing.gd")
const TestNpcSchedule = preload("res://tests/test_npc_schedule.gd")
const TestNpcThoughtBubble = preload("res://tests/test_npc_thought_bubble.gd")
const TestNpcTooltip = preload("res://tests/test_npc_tooltip.gd")
const TestNpcVisuals = preload("res://tests/test_npc_visuals.gd")
const TestObjectiveHud = preload("res://tests/test_objective_hud.gd")
const TestObjectiveHudBanner = preload("res://tests/test_objective_hud_banner.gd")
const TestObjectiveHudMetrics = preload("res://tests/test_objective_hud_metrics.gd")
const TestObjectiveHudNudgeManager = preload("res://tests/test_objective_hud_nudge_manager.gd")
const TestObjectiveHudWinTracker = preload("res://tests/test_objective_hud_win_tracker.gd")
const TestPauseMenu = preload("res://tests/test_pause_menu.gd")
const TestPlayerStats = preload("res://tests/test_player_stats.gd")
const TestProgressData = preload("res://tests/test_progress_data.gd")
const TestPropagationEngine = preload("res://tests/test_propagation_engine.gd")
const TestQuarantineSystem = preload("res://tests/test_quarantine_system.gd")
const TestReadyOverlay = preload("res://tests/test_ready_overlay.gd")
const TestReconController = preload("res://tests/test_recon_controller.gd")
const TestReconHud = preload("res://tests/test_recon_hud.gd")
const TestReconTooltipManager = preload("res://tests/test_recon_tooltip_manager.gd")
const TestReputationSystem = preload("res://tests/test_reputation_system.gd")
const TestRivalAgent = preload("res://tests/test_rival_agent.gd")
const TestRumor = preload("res://tests/test_rumor.gd")
const TestRumorEventWiring = preload("res://tests/test_rumor_event_wiring.gd")
const TestRumorPanel = preload("res://tests/test_rumor_panel.gd")
const TestRumorPanelClaimList = preload("res://tests/test_rumor_panel_claim_list.gd")
const TestRumorPanelEstimates = preload("res://tests/test_rumor_panel_estimates.gd")
const TestRumorPanelSeedList = preload("res://tests/test_rumor_panel_seed_list.gd")
const TestRumorPanelSubjectList = preload("res://tests/test_rumor_panel_subject_list.gd")
const TestRumorPanelTooltip = preload("res://tests/test_rumor_panel_tooltip.gd")
const TestRumorRippleVfx = preload("res://tests/test_rumor_ripple_vfx.gd")
const TestRumorTrackerHud = preload("res://tests/test_rumor_tracker_hud.gd")
const TestS4FactionShiftAgent = preload("res://tests/test_s4_faction_shift_agent.gd")
const TestSaveCorruption = preload("res://tests/test_save_corruption.gd")
const TestSaveManager = preload("res://tests/test_save_manager.gd")
const TestSaveRoundtrip = preload("res://tests/test_save_roundtrip.gd")
const TestScenario1Hud = preload("res://tests/test_scenario1_hud.gd")
const TestScenario2Hud = preload("res://tests/test_scenario2_hud.gd")
const TestScenario3Hud = preload("res://tests/test_scenario3_hud.gd")
const TestScenario4Hud = preload("res://tests/test_scenario4_hud.gd")
const TestScenario5Hud = preload("res://tests/test_scenario5_hud.gd")
const TestScenario6Hud = preload("res://tests/test_scenario6_hud.gd")
const TestScenarioAnalytics = preload("res://tests/test_scenario_analytics.gd")
const TestScenarioConditions = preload("res://tests/test_scenario_conditions.gd")
const TestScenarioConfig = preload("res://tests/test_scenario_config.gd")
const TestScenarioEnvironmentPalette = preload("res://tests/test_scenario_environment_palette.gd")
const TestScenarioManager = preload("res://tests/test_scenario_manager.gd")
const TestSettingsManager = preload("res://tests/test_settings_manager.gd")
const TestSettingsMenu = preload("res://tests/test_settings_menu.gd")
const TestSocialGraph = preload("res://tests/test_social_graph.gd")
const TestSocialGraphOverlay = preload("res://tests/test_social_graph_overlay.gd")
const TestSpa970976Regressions = preload("res://tests/test_spa970_976_regressions.gd")
const TestSpa1106NewGameRegression = preload("res://tests/test_spa1106_new_game_regression.gd")
const TestSpa1544NewGameStateIsolation = preload("res://tests/test_spa1544_new_game_state_isolation.gd")
const TestSpa1599AnalyticsDisabledGating = preload("res://tests/test_spa1599_analytics_disabled_gating.gd")
const TestSpa1613EvidenceAcquired = preload("res://tests/test_spa1613_evidence_acquired.gd")
const TestSpeedHud = preload("res://tests/test_speed_hud.gd")
const TestStoryRecap = preload("res://tests/test_story_recap.gd")
const TestStrategicOverview = preload("res://tests/test_strategic_overview.gd")
const TestSuggestionEngine = preload("res://tests/test_suggestion_engine.gd")
const TestSuggestionToast = preload("res://tests/test_suggestion_toast.gd")
const TestThoughtBubbleLegend = preload("res://tests/test_thought_bubble_legend.gd")
const TestTooltipManager = preload("res://tests/test_tooltip_manager.gd")
const TestTownMapOverlay = preload("res://tests/test_town_map_overlay.gd")
const TestTownMoodController = preload("res://tests/test_town_mood_controller.gd")
const TestTransitionManager = preload("res://tests/test_transition_manager.gd")
const TestTutorialBanner = preload("res://tests/test_tutorial_banner.gd")
const TestTutorialController = preload("res://tests/test_tutorial_controller.gd")
const TestTutorialHud = preload("res://tests/test_tutorial_hud.gd")
const TestTutorialSystem = preload("res://tests/test_tutorial_system.gd")
const TestTutorialWiring = preload("res://tests/test_tutorial_wiring.gd")
const TestUILayerManager = preload("res://tests/test_ui_layer_manager.gd")
const TestVisualAffordances = preload("res://tests/test_visual_affordances.gd")
const TestWeatherSystem = preload("res://tests/test_weather_system.gd")
const TestWhatsChangedCard = preload("res://tests/test_whats_changed_card.gd")
const TestWorld = preload("res://tests/test_world.gd")
const TestZoneIndicator = preload("res://tests/test_zone_indicator.gd")

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

	print("\n── SaveRoundtrip ──")
	TestSaveRoundtrip.new().run()

	print("\n── AchievementManager ──")
	TestAchievementManager.new().run()

	print("\n── AchievementSignal ──")
	TestAchievementSignal.new().run()

	print("\n── AchievementToast ──")
	TestAchievementToast.new().run()

	print("\n── FactionEventSystem ──")
	TestFactionEventSystem.new().run()

	print("\n── SPA-970..976 Regressions ──")
	TestSpa970976Regressions.new().run()

	print("\n── SPA-1106 NewGame Regression ──")
	TestSpa1106NewGameRegression.new().run()

	print("\n── SPA-1544 NewGame State Isolation ──")
	TestSpa1544NewGameStateIsolation.new().run()

	print("\n── SPA-1599 Analytics-Disabled Gating (A4) ──")
	TestSpa1599AnalyticsDisabledGating.new().run()

	print("\n── SPA-1613 evidence_acquired field shape + fire sites ──")
	TestSpa1613EvidenceAcquired.new().run()

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

	print("\n── BuildingInterior ──")
	TestBuildingInterior.new().run()

	print("\n── BuildingTooltip ──")
	TestBuildingTooltip.new().run()

	print("\n── NpcDialogue ──")
	TestNpcDialogue.new().run()

	print("\n── NpcDialoguePanel ──")
	TestNpcDialoguePanel.new().run()

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

	print("\n── RumorTrackerHud ──")
	TestRumorTrackerHud.new().run()

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

	print("\n── AnalyticsManager ──")
	TestAnalyticsManager.new().run()

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

	print("\n── BaseScenarioHud ──")
	TestBaseScenarioHud.new().run()

	print("\n── Scenario1Hud ──")
	TestScenario1Hud.new().run()

	print("\n── Scenario2Hud ──")
	TestScenario2Hud.new().run()

	print("\n── Scenario3Hud ──")
	TestScenario3Hud.new().run()

	print("\n── Scenario4Hud ──")
	TestScenario4Hud.new().run()

	print("\n── Scenario5Hud ──")
	TestScenario5Hud.new().run()

	print("\n── Scenario6Hud ──")
	TestScenario6Hud.new().run()

	print("\n── MainMenu ──")
	TestMainMenu.new().run()

	print("\n── MainMenuBriefingPanel ──")
	TestMainMenuBriefingPanel.new().run()

	print("\n── MainMenuScenarioSelect ──")
	TestMainMenuScenarioSelect.new().run()

	print("\n── MainMenuSettingsPanel ──")
	TestMainMenuSettingsPanel.new().run()

	print("\n── MainMenuStatsPanel ──")
	TestMainMenuStatsPanel.new().run()

	print("\n── HowToPlay ──")
	TestHowToPlay.new().run()

	print("\n── LoadingTips ──")
	TestLoadingTips.new().run()

	print("\n── MilestoneNotifier ──")
	TestMilestoneNotifier.new().run()

	print("\n── MilestoneTracker ──")
	TestMilestoneTracker.new().run()

	print("\n── SpeedHud ──")
	TestSpeedHud.new().run()

	print("\n── ZoneIndicator ──")
	TestZoneIndicator.new().run()

	print("\n── FeedbackSequence ──")
	TestFeedbackSequence.new().run()

	print("\n── StoryRecap ──")
	TestStoryRecap.new().run()

	print("\n── MissionBriefing ──")
	TestMissionBriefing.new().run()

	print("\n── MissionCard ──")
	TestMissionCard.new().run()

	print("\n── EventCard ──")
	TestEventCard.new().run()

	print("\n── EventChoiceModal ──")
	TestEventChoiceModal.new().run()

	print("\n── StrategicOverview ──")
	TestStrategicOverview.new().run()

	print("\n── DistrictOverlay ──")
	TestDistrictOverlay.new().run()

	print("\n── TownMapOverlay ──")
	TestTownMapOverlay.new().run()

	print("\n── TooltipManager ──")
	TestTooltipManager.new().run()

	print("\n── ReconTooltipManager ──")
	TestReconTooltipManager.new().run()

	print("\n── SuggestionToast ──")
	TestSuggestionToast.new().run()

	print("\n── VisualAffordances ──")
	TestVisualAffordances.new().run()

	print("\n── WhatsChangedCard ──")
	TestWhatsChangedCard.new().run()

	print("\n── TutorialBanner ──")
	TestTutorialBanner.new().run()

	print("\n── TutorialHud ──")
	TestTutorialHud.new().run()

	print("\n── ContextControlsPanel ──")
	TestContextControlsPanel.new().run()

	print("\n── ControlsReference ──")
	TestControlsReference.new().run()

	print("\n── HelpReminderUI ──")
	TestHelpReminderUI.new().run()

	print("\n── ThoughtBubbleLegend ──")
	TestThoughtBubbleLegend.new().run()

	print("\n── ReadyOverlay ──")
	TestReadyOverlay.new().run()

	print("\n── Camera ──")
	TestCamera.new().run()

	print("\n── AmbientParticles ──")
	TestAmbientParticles.new().run()

	print("\n── AnalyticsLogger ──")
	TestAnalyticsLogger.new().run()

	print("\n── DistrictPropsRegistry ──")
	TestDistrictPropsRegistry.new().run()

	print("\n── FactionPalette ──")
	TestFactionPalette.new().run()

	print("\n── GameInputHandler ──")
	TestGameInputHandler.new().run()

	print("\n── Npc ──")
	TestNpc.new().run()

	print("\n── NpcConversationOverlay ──")
	TestNpcConversationOverlay.new().run()

	print("\n── PlayerStats ──")
	TestPlayerStats.new().run()

	print("\n── ProgressData ──")
	TestProgressData.new().run()

	print("\n── RumorEventWiring ──")
	TestRumorEventWiring.new().run()

	print("\n── RumorRippleVfx ──")
	TestRumorRippleVfx.new().run()

	print("\n── ScenarioEnvironmentPalette ──")
	TestScenarioEnvironmentPalette.new().run()

	print("\n── SettingsManager ──")
	TestSettingsManager.new().run()

	print("\n=== All suites complete ===")
