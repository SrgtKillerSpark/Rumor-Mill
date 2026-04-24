## scenario_config.gd — Single source of truth for all scenario balance constants.
##
## All win/fail thresholds, NPC identifiers, day-specific event trigger windows,
## and scenario action costs live here.  ScenarioManager and the scenario HUDs
## initialise their working variables from these values; difficulty modifiers may
## override individual ScenarioManager vars at runtime, but ScenarioConfig itself
## is read-only and never mutated.
##
## Access via class name anywhere in the project:
##   ScenarioConfig.S1_WIN_EDRIC_BELOW   → 30
##   ScenarioConfig.S5_ENDORSEMENT_DAY   → 13
##   etc.
##
## No autoload registration is required — class_name makes it globally available.

class_name ScenarioConfig

# ---------------------------------------------------------------------------
# NPC identifiers — shared by ScenarioManager, HUDs, and tutorial_system.
# ---------------------------------------------------------------------------

const EDRIC_FENN_ID    := "edric_fenn"
const ALYS_HERBWIFE_ID := "alys_herbwife"
const MAREN_NUN_ID     := "maren_nun"
const CALDER_FENN_ID   := "calder_fenn"
const TOMAS_REEVE_ID   := "tomas_reeve"
const ALDRIC_VANE_ID   := "aldric_vane"
const MARTA_COIN_ID    := "marta_coin"
const ALDOUS_PRIOR_ID  := "aldous_prior"

# ---------------------------------------------------------------------------
# Scenario 1 — The Alderman's Ruin
# ---------------------------------------------------------------------------

## Edric's reputation must drop strictly below this value to win.
## SPA-98: raised from 25 (credulity=0.05 and loyalty=0.80 made 26-pt drop too punishing).
const S1_WIN_EDRIC_BELOW   := 30

## Edric's base reputation at scenario start (used for progress normalisation).
const S1_EDRIC_START_SCORE := 50

## Any NPC's heat at or above this value triggers an instant exposure fail.
## SPA-502: cumulative exposure threshold via Guard Captain.
const S1_EXPOSED_HEAT      := 80.0

## Edric's reputation below this value fires the "First Blood" celebration (SPA-805).
## Sits between the start score (50) and the win threshold (30) as an early-progress marker.
const S1_FIRST_BLOOD_THRESHOLD := 48

# ---------------------------------------------------------------------------
# Scenario 2 — The Plague Scare
# ---------------------------------------------------------------------------

## Number of NPCs that must believe illness rumors about Alys Herbwife to win.
## SPA-98 → SPA-530: raised 5 → 6 → 7 (6 was reachable in 3-4 days via merchant chain).
const S2_WIN_ILLNESS_MIN   := 7

## Grace period (days) after Maren first rejects before the scenario fails.
## SPA-592: prevents silent propagation chains ending the run without player agency.
const S2_MAREN_GRACE_DAYS  := 2

# ---------------------------------------------------------------------------
# Scenario 3 — The Succession
# ---------------------------------------------------------------------------

## Calder must reach this reputation to satisfy the win condition.
## SPA-98 → SPA-530: eased from 80 → 75.
const S3_WIN_CALDER_MIN    := 75

## Tomas must drop to this reputation or below to satisfy the win condition.
## SPA-98 → SPA-550: eased from 30 → 35.
const S3_WIN_TOMAS_MAX     := 35

## Calder dropping below this triggers an instant fail.
## SPA-550: lowered 40 → 35 (wider buffer rewards strategy over luck near 40).
const S3_FAIL_CALDER_BELOW := 35

# ---------------------------------------------------------------------------
# Scenario 4 — The Holy Inquisition
# ---------------------------------------------------------------------------

## The three NPCs the player must protect from the Inquisitor.
const S4_PROTECTED_NPC_IDS: Array[String] = ["aldous_prior", "vera_midwife", "finn_monk"]

## All protected NPCs must be at or above this score at the deadline to win.
## SPA-747: raised from 45 → 48 (new HUD systems give near-perfect info, needed tighter margin).
const S4_WIN_REP_MIN       := 48

## Any protected NPC dropping below this triggers an instant fail.
## SPA-550: separated from win threshold to create a "danger zone" for comeback plays.
const S4_FAIL_REP_BELOW    := 40

## Milestone warning threshold — a protected NPC below this score triggers a
## "dangerously close" toast in MilestoneTracker (4 points above the win floor).
const S4_CAUTION_REP       := 52

## Day window [first_day, last_day] for each mid-game faction shift event.
## Phase 1: Merchant Sympathy  — weakest NPC receives a praise rumour.
## Phase 2: Bishop Pressure    — inquisitor cooldown shortens, accusations accelerate.
## Phase 3: Clergy Solidarity  — all three protected NPCs receive a low-intensity praise.
const S4_PHASE_1_WINDOW: Array = [5,  7]
const S4_PHASE_2_WINDOW: Array = [10, 13]
const S4_PHASE_3_WINDOW: Array = [14, 17]

# ---------------------------------------------------------------------------
# Scenario 5 — The Election
# ---------------------------------------------------------------------------

## All three election candidates (order: edric, aldric, tomas).
const S5_CANDIDATE_IDS: Array[String] = ["edric_fenn", "aldric_vane", "tomas_reeve"]

## Aldric must reach this reputation (and lead all candidates) to win.
const S5_WIN_ALDRIC_MIN    := 65

## Both rivals must be strictly below this to win.
const S5_WIN_RIVALS_MAX    := 45

## Aldric dropping below this triggers an instant fail.
const S5_FAIL_ALDRIC_BELOW := 30

## In-game day when Prior Aldous endorses the candidate with the highest reputation.
const S5_ENDORSEMENT_DAY   := 13

## Reputation bonus applied to the endorsed candidate.
const S5_ENDORSEMENT_BONUS := 8

## Reputation boost per campaign appearance (Scenario 5 HUD action).
const S5_CAMPAIGN_REP_BOOST := 4

## Minimum days required between consecutive campaign appearances.
const S5_CAMPAIGN_COOLDOWN  := 3

# ---------------------------------------------------------------------------
# Scenario 6 — The Merchant's Debt
# ---------------------------------------------------------------------------

## Aldric's reputation must drop to this or below to expose his embezzlement.
const S6_WIN_ALDRIC_MAX   := 30

## Marta must stay at or above this reputation at all times to win.
## SPA-747: raised from 60 → 62.
const S6_WIN_MARTA_MIN    := 62

## Marta dropping below this triggers an instant fail.
const S6_FAIL_MARTA_BELOW := 30

## Heat ceiling — lower than S1 because guards are on Aldric's payroll.
## SPA-747: lowered from 60 → 55 (visible heat budget must be tighter with HUD info).
const S6_EXPOSED_HEAT     := 55.0

## Blackmail evidence action: whisper token cost per use.
const S6_BLACKMAIL_WHISPER_COST := 2

## Reputation delta applied to Aldric Vane per blackmail use (negative = damage).
const S6_BLACKMAIL_REP_HIT      := -18

## Heat added to Aldric's merchant defenders per blackmail use.
const S6_BLACKMAIL_HEAT_ADD     := 22.0

## Maximum times blackmail evidence can be used in one run (before intel store bonus).
const S6_BLACKMAIL_MAX_USES     := 2

## NPCs that receive heat when blackmail evidence is leaked.
const S6_BLACKMAIL_HEAT_NPCS: Array[String] = ["sybil_oats", "rufus_bolt"]
