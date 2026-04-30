# Balance Reference: Scenario Parameters and Tuning Issues

*Baseline document for data-driven tuning post-EA launch.*
*Last updated: 2026-04-04 (pre-launch baseline)*

---

## 1. Per-Scenario Balance Levers

### Scenario 1 — The Alderman's Ruin (Tutorial)

| Parameter | Value | Source |
|-----------|-------|--------|
| **Win condition** | `reputation(Edric Fenn) < 30` | `scenario_manager.gd` S1_WIN_EDRIC_BELOW |
| **Fail — detection** | Eavesdrop detection = instant fail | `on_player_exposed()` |
| **Fail — timeout** | Day > 30 | `scenarios.json` daysAllowed |
| **Bribery** | Disabled (0 charges) | `world.gd` line 490 |
| **Edric starting reputation** | 50 (default) | `scenarios.json` |

**Key NPC stats (Edric Fenn):** credulity=0.05, sociability=0.40, loyalty=0.95, temperament=0.40.

Edric's extremely low credulity makes direct rumor targeting ineffective. The intended path is indirect — degrade faction sentiment among merchants/nobles until the reputation formula's faction_sentiment component (-20 to +20) does the work. Bram Guard (loyalty=0.90, edge to Edric=0.85) acts as a shield; the player must route around him.

**Tuning history:** Win threshold raised from 25 to 30 in SPA-98 because Edric's credulity+loyalty overrides made the original threshold punishing for a tutorial scenario.

---

### Scenario 2 — The Plague Scare

| Parameter | Value | Source |
|-----------|-------|--------|
| **Win condition** | >= 7 NPCs in BELIEVE/SPREAD/ACT for illness rumor about Alys Herbwife | `scenario_manager.gd` S2_WIN_ILLNESS_MIN |
| **Fail — Maren rejects** | Sister Maren transitions to REJECT for any illness rumor about Alys = instant fail | `has_illness_rejecter()` |
| **Fail — timeout** | Day > 24 | `scenarios.json` daysAllowed |
| **Bribery** | Enabled (2 charges) | |
| **Alys starting reputation** | Default (50) | |

**Counter-intelligence: Sister Maren**
- Stats: credulity=0.50, loyalty=0.90, temperament=0.40
- Maren-Alys edge weight: 0.35/0.30 (deliberately low to reduce accidental chain propagation to Maren)
- When Maren rejects, she enters DEFENDING (loyalty > 0.7): broadcasts -0.15 credulity penalty to neighbors for 5 ticks

**Tuning history:** Win threshold raised from 5 to 7 believers in SPA-98 because at 5, a single ILL-01 (intensity=5) could win in 3-4 days. The real design tension is supposed to be avoiding Maren while building to 7 believers.

---

### Scenario 3 — The Succession

| Parameter | Value | Source |
|-----------|-------|--------|
| **Win condition** | `reputation(Calder Fenn) >= 75` AND `reputation(Tomas Reeve) <= 35` | `scenario_manager.gd` S3_WIN_CALDER_MIN, S3_WIN_TOMAS_MAX |
| **Fail — Calder collapses** | `reputation(Calder Fenn) < 35` = instant fail | S3_FAIL_CALDER_BELOW |
| **Fail — timeout** | Day > 25 | `scenarios.json` daysAllowed |
| **Bribery** | Enabled (2 charges) | |
| **Starting reputations** | Calder=62, Tomas=48 | `scenarios.json` |
| **Target-shift exclusion** | Calder excluded from target-shift mutations | `scenarios.json` targetShiftExcluded |

**Required reputation swings:** Calder must gain +13 (62 -> 75), Tomas must lose -13 (48 -> 35). Simultaneously, Calder must never drop below 35 (27 points of safety margin from start).

**Rival Agent (AI opponent):**

| Phase | Days | Cooldown | Intensity | Behavior |
|-------|------|----------|-----------|----------|
| Early | 1-7 | 3 days | 2 | Always PRAISE Tomas |
| Mid | 8-15 | 2 days | 3 | Alternates PRAISE/Tomas and SCANDAL/Calder |
| Late | 16-25 | 1 day | 3 | Metric-driven targeting (attacks weakest gap) |

Late-phase targeting logic:
- `calder_gap = calder_score - 40` (distance above fail floor)
- `tomas_gap = 35 - tomas_score` (distance below win ceiling)
- If `tomas_gap <= 0` OR `calder_gap < 10` OR `calder_gap <= tomas_gap`: attacks Calder
- Otherwise: boosts Tomas

NPC selection: highest-sociability NPC at market/tavern with heat <= 50, not in SPREAD/ACT.

**Tuning history:** Win thresholds eased from (Calder >= 80, Tomas <= 30) to (Calder >= 75, Tomas <= 35) in SPA-98. With PRAISE intensity 1-2 and 2 whispers/day, reaching the original +22 reputation gain in 25 days was extremely difficult.

---

### Scenario 4 — The Holy Inquisition (Defensive)

| Parameter | Value | Source |
|-----------|-------|--------|
| **Win condition** | All 3 protected NPCs at or above 48 after day 20 elapses | `scenario_manager.gd` S4_WIN_REP_MIN |
| **Fail — reputation collapsed** | Any protected NPC drops below 40 at any time | S4_FAIL_REP_BELOW |
| **Fail — timeout** | Day > 20 AND any protected below 48 | |
| **Bribery** | Disabled | |
| **Protected NPCs** | Aldous Prior (start=70), Vera Midwife (start=68), Finn Monk (start=68) | `scenarios.json` |
| **Target-shift exclusion** | All 3 protected NPCs excluded from target-shift mutations | `scenarios.json` |

**Critical observation:** Win threshold is 48 and fail threshold is 40, creating an 8-point "danger zone" (40–47) where NPCs are alive but not yet meeting the win condition. All three protected NPCs start well above both thresholds (Aldous=70, Vera=68, Finn=68), giving meaningful buffer.

**Inquisitor Agent (AI opponent):**

| Phase | Days | Cooldown | Intensity | Claim Types |
|-------|------|----------|-----------|-------------|
| Early | 1-5 | 3 days | 2 | Heresy only |
| Mid | 6-12 | 2 days | 3 | Heresy / Accusation / Scandal rotation |
| Late | 13-20 | 1 day | 4 | Heresy / Accusation / Scandal rotation |

Target selection: always attacks the protected NPC with the **highest current reputation**.

**Protected NPC vulnerability analysis:**

| NPC | Start Rep | Buffer (to fail) | Buffer (to win) | Credulity | Loyalty | Risk Level |
|-----|-----------|------------------|-----------------|-----------|---------|------------|
| Aldous Prior | 70 | 30 pts | 22 pts | 0.10 (very low) | 0.95 (very high) | LOW — hardest to damage |
| Vera Midwife | 68 | 28 pts | 20 pts | 0.70 (high) | 0.65 (medium) | MEDIUM — credulous but decent loyalty |
| Finn Monk | 68 | 28 pts | 20 pts | 0.60 (high) | 0.45 (low) | HIGH — credulous with low loyalty, most likely to be dragged down |

---

### Scenario 5 — The Election

| Parameter | Value | Source |
|-----------|-------|--------|
| **Win condition** | `reputation(aldric_vane) >= 65` AND highest of 3 candidates AND rivals < 45 | `scenario_config.gd` S5_WIN_ALDRIC_MIN, S5_WIN_RIVALS_MAX |
| **Fail — Aldric collapses** | `reputation(aldric_vane) < 30` = instant fail | S5_FAIL_ALDRIC_BELOW |
| **Fail — timeout** | Day > 21 | `scenarios.json` daysAllowed |
| **Bribery** | Enabled (2 charges) | |
| **Starting reputations** | Edric=58, Aldric=45, Tomas=45 | `scenarios.json` |
| **Endorsement** | Day 13: Prior Aldous endorses the leader (+8 rep) | S5_ENDORSEMENT_DAY, S5_ENDORSEMENT_BONUS |
| **Campaign action** | +4 rep to Aldric, 3-day cooldown | S5_CAMPAIGN_REP_BOOST, S5_CAMPAIGN_COOLDOWN |

**Required reputation swings:** Aldric must gain +20 (45 -> 65). Edric must lose -14 (58 -> below 45). Tomas must stay below 45 (starts at 45 — any upward movement is a problem).

**Key mechanic — endorsement:** The Day 13 endorsement is a make-or-break moment. If Aldric receives it (+8), his effective gap drops to +12. If Edric receives it, the gap widens to +21 and the scenario becomes very difficult.

---

### Scenario 6 — The Merchant's Debt

| Parameter | Value | Source |
|-----------|-------|--------|
| **Win condition** | `reputation(aldric_vane) <= 30` AND `reputation(marta_coin) >= 62` | `scenario_config.gd` S6_WIN_ALDRIC_MAX, S6_WIN_MARTA_MIN |
| **Fail — Marta silenced** | `reputation(marta_coin) < 30` = instant fail | S6_FAIL_MARTA_BELOW |
| **Fail — exposed** | Player heat >= 55 = instant fail | S6_EXPOSED_HEAT |
| **Fail — timeout** | Day > 20 | `scenarios.json` daysAllowed |
| **Bribery** | Enabled | |
| **Starting reputations** | Aldric=55, Marta=48 | `scenarios.json` |
| **Protected NPC** | Marta Coin (must stay >= 62 to win) | |

**Required reputation swings:** Aldric must lose -25 (55 -> 30). Marta must gain +14 (48 -> 62). The heat ceiling of 55 severely constrains aggressive play.

**Guild Defense system:** Aldric's merchant allies (Sybil Oats, Rufus Bolt, Bess Wicker, Idris Kemp) spread praise rumors about him every 3 days starting Day 5. This creates an active reputation recovery that the player must outpace.

**Blackmail evidence:** 2 uses maximum. Each use: -18 rep to Aldric, +22 heat to Sybil/Rufus. Powerful but dangerous — two blackmail uses generate 44 heat on merchant defenders, risking exposure cascades.

---

## 2. Whisper Token Economy

### Base Economy (Master Difficulty)

| Resource | Daily | Per Scenario | Replenish |
|----------|-------|--------------|-----------|
| Whisper Tokens | 2 | Unlimited (daily) | Dawn |
| Recon Actions | 3 | Unlimited (daily) | Dawn |
| Bribe Charges | — | 2 (Scenarios 2-3 only) | Never |
| Evidence Slots | — | 3 max | Oldest discarded on overflow |

### Costs

| Action | Whisper Cost | Other Costs |
|--------|-------------|-------------|
| Seed a rumor | 1 whisper | — |
| Bribe an NPC | 1 whisper | 1 recon action + 1 bribe charge |
| Vouch for NPC (Scenario 4) | 1 whisper | — |

### Difficulty Modifiers

| Parameter | Apprentice | Master | Spymaster |
|-----------|-----------|--------|-----------|
| Daily whispers | 3 | **2** | 1 |
| Daily recon actions | 4 | **3** | 2 |
| Days allowed bonus | +5 | 0 | -5 |
| Heat decay/day | 8.0 | **6.0** | 3.0 |
| Rival cooldown offset | +1 (slower) | 0 | -1 (faster) |

### Economy Pressure Analysis

At Master difficulty with 2 whispers/day:
- **Scenario 1** (30 days): 60 total whispers. Generous budget; economy is not the constraint.
- **Scenario 2** (24 days): 48 whispers + 2 bribes. Need 7 believers — economy is adequate but requires efficient seeding.
- **Scenario 3** (25 days): 50 whispers + 2 bribes, but rival agent actively counteracts. Must split between PRAISE/Calder and negative/Tomas. Tightest economy relative to task.
- **Scenario 4** (20 days): 40 whispers. Defensive use (VOUCH/PRAISE) is less token-efficient than offensive seeding. Most token-constrained scenario.
- **Scenario 5** (21 days): 42 whispers + 2 bribes + campaign action (free, 3-day cooldown). Campaign appearances supplement the whisper budget but the three-target split creates pressure.
- **Scenario 6** (20 days): 40 whispers + 2 bribes + 2 blackmail uses (cost 2 whispers each). Blackmail is the most token-expensive action in the game (2 whispers per use) but delivers -18 rep per shot.

At Spymaster (1/day): Scenario 3 drops to 20 whispers against an accelerated rival. Scenario 4 drops to 15 whispers over 15 days against a daily inquisitor from day 13. Scenario 6 drops to 15 whispers — barely enough for 2 blackmail uses plus a handful of rumor seeds.

---

## 3. NPC Personality Stats — Key Ranges and Effects

### Stat Effects on Propagation

**Spread probability (beta):**
```
beta = sociability_spreader x credulity_target x edge_weight x faction_mod x 1.8
```
- Faction modifiers: same=x1.2, neutral=x0.8, opposing=x0.5
- Heat modifiers on credulity: heat 50-74 = -0.15; heat >= 75 = -0.30

**Recovery probability (gamma):**
```
gamma = loyalty x (1 - temperament) x 0.30
```

**EVALUATING -> BELIEVE chance:**
```
chance = (credulity - defense_penalty) x believability
       + 0.15 if source shares faction
       + min(heard_count - 1, 3) x 0.10 (corroboration, max +0.30)
```
Minimum 3 ticks in EVALUATING before roll fires.

**ACT timing:** `act_threshold_ticks = round(8.0 x (1.0 - temperament))`

### Extreme NPCs (Design-Relevant Outliers)

| NPC | Notable Stat | Value | Design Role |
|-----|-------------|-------|-------------|
| Edric Fenn | Credulity | **0.05** | Near-immune to direct rumor; must be taken down via faction sentiment |
| Finn Monk | Credulity | **0.95** | Believes almost anything; combined with loyalty=0.20, extremely vulnerable |
| Aldous Prior | Loyalty | **0.95** | Enters DEFENDING easily; strong neighborhood shield |
| Maren Nun | Loyalty | **0.90** | Scenario 2 fail trigger; DEFENDING suppresses nearby credulity |
| Old Hugh | Temperament | **0.15** | ACT threshold = 7 ticks; slow to act on beliefs |
| Calder Fenn | Temperament | **0.85** | ACT threshold = 1 tick; acts almost immediately on belief |
| Nell Picker | Sociability | **0.90** | Top-tier rumor spreader (merchant faction) |
| Sybil Oats | Sociability | **0.90** | Top-tier rumor spreader (merchant faction) |
| Greta Flint | Cred+Soc | 0.85/0.85 | Most effective conduit NPC in the game |
| Bess Wicker | Sociability | **0.15** | Firewall — rumors stall here |

---

## 4. Evidence Item Impact

| Item | Believability Bonus | Mutability Mod | Compatible Claims | Acquisition |
|------|-------------------|----------------|-------------------|-------------|
| Forged Document | **+0.20** | 0.0 | ACCUSATION, SCANDAL, HERESY | Observe Market/Guild with >= 2 recon actions |
| Incriminating Artifact | **+0.25** | 0.0 | SCANDAL, HERESY | Observe Manor/Chapel after tick > 18 (post-6pm) |
| Witness Account | **+0.15** | **-0.15** | Any | Re-eavesdrop same NPC pair >= 24 ticks after first |

Evidence is applied at rumor creation time and not recalculated. The Witness Account's -0.15 mutability modifier is the only way to reduce mutation chance, making it strategically valuable for precision campaigns.

Inventory cap: 3 items, oldest silently discarded on overflow.

---

## 5. Known Balance Concerns

### HIGH: Scenario 4 — Finn Monk as Primary Target

Finn Monk starts at reputation 68 (28 points above the fail threshold of 40), but his credulity=0.60 and loyalty=0.45 make him the most vulnerable of the three protected NPCs. The Inquisitor's targeting logic (always attacks the highest-rep NPC) means Finn won't be first-targeted initially, but once Aldous or Vera dip, Finn's low loyalty makes recovery slow.

**Risk factors:**
- Inquisitor's first seed fires day 1-3 (cooldown=3 initially)
- Finn's credulity makes him likely to transition EVALUATING -> BELIEVE for heresy rumors
- His lower loyalty means gamma recovery is slower than the other two
- No bribery available in Scenario 4

**Recommended analytics to watch:** Scenario 4 fail rate by protected NPC, percentage of Scenario 4 games where Finn is the first NPC to trigger failure (drops below 40).

### HIGH: Scenario 2 — Sister Maren Counter-Intelligence Calibration

The Maren instant-fail mechanic creates a binary difficulty curve. The Maren-Alys edge weight was deliberately lowered to 0.35/0.30 to reduce accidental propagation, but:

- If Maren's edge weights are too low, the scenario lacks meaningful tension from counter-intelligence
- If too high, the fail condition becomes RNG-driven and frustrating
- The current 0.35/0.30 value has not been validated with broad playtesting

**Recommended analytics:** Maren-triggered fail rate vs. timeout fail rate vs. win rate. If Maren fails dominate, edge weights may need further reduction. If Maren rarely triggers, the scenario may be too easy once players learn to avoid her neighborhood.

### HIGH: Scenario 3 — Rival Agent Late-Phase Pacing

The rival agent's late-phase behavior (days 16-25, daily seeds) previously escalated to intensity 4, creating steep difficulty that made late-game recovery nearly impossible for players who fell behind.

**Fix (SPA-471):** Late-phase intensity capped at 3 (same as mid-phase). The rival still seeds daily with metric-driven targeting, but at reduced impact.

**Recommended analytics:** Win rate by day-15 reputation snapshot. If wins still correlate almost entirely with early-game performance, consider also extending late-phase cooldown to 2 days.

### MEDIUM: Scenario 4 — Danger Zone Width

Win threshold is 48 and fail threshold is 40, creating an 8-point danger zone (40–47). NPCs in this range are alive but not meeting the win condition — the player must recover them before the deadline. This separation (introduced in SPA-550/SPA-747) replaced the original design where win and fail were both at 50.

**Monitor:** Whether the 8-point danger zone feels meaningful in practice. If players rarely occupy the 40–47 range (either staying safe or failing outright), the zone may need widening.

### MEDIUM: Whisper Token Economy on Spymaster

At 1 whisper/day:
- Scenario 3: 20 whispers (with -5 day penalty) against an accelerated rival. Players may feel resource-starved to the point of helplessness.
- Scenario 4: 15 whispers over 15 days with no bribery. The defensive toolkit may be insufficient.

**Recommended analytics:** Spymaster completion rates per scenario. If Scenario 3 or 4 Spymaster completion is < 5%, the economy may need a floor (e.g., minimum 2 whispers on Spymaster for Scenarios 3-4).

### LOW: Evidence Item Balance

Forged Document (+0.20) and Incriminating Artifact (+0.25) have very similar effects. The Artifact's +0.05 advantage over the Document, combined with its time restriction (post-6pm only), may not create a meaningful strategic choice. Players will likely just use whichever they find first.

**Consider:** Differentiating the items further — e.g., Artifact could also reduce mutability, or Document could be usable on a wider claim set.

### LOW: Faction Event Timing

Faction events fire between days 2-7 only (MAX_EVENTS=2). In longer scenarios (Scenario 1: 30 days, Scenario 3: 25 days), this means events are frontloaded and the mid/late game has no environmental variation. In Scenario 4 (20 days), events are better paced relative to total duration.

---

## 6. Phase 1 Post-Launch Tuning Priorities

Based on the balance concerns above and the analytics infrastructure shipping at launch (SPA-273), these are the recommended tuning priorities ordered by expected player impact:

### Priority 1 — Scenario 4 Protected NPC Fail Distribution
**Metric:** Which protected NPC triggers fail (drops below 40) most often, and at what day.
**Action threshold:** If > 60% of Scenario 4 failures come from the same NPC, consider adjusting that NPC's personality overrides or starting reputation. If most failures cluster in the first 5 days despite the 68-point starting reps, the Inquisitor's early intensity may need reduction.

### Priority 2 — Scenario 2 Maren Fail Distribution
**Metric:** Ratio of Maren-triggered fails to timeout fails to wins.
**Action threshold:** If Maren triggers > 60% of all Scenario 2 failures, reduce Maren-Alys edge weights further (to 0.25/0.20). If Maren triggers < 10% of failures, consider raising edges to 0.45/0.40 for more tension.

### Priority 3 — Scenario 3 Win Correlation with Day-15 State
**Metric:** Win rate segmented by day-15 Calder/Tomas reputation values.
**Action threshold:** If 90%+ of wins require Calder > 65 at day 15, the late-phase rival is too punishing. Consider: cap rival intensity at 3, or extend late-phase cooldown to 2 days.

### Priority 4 — Spymaster Difficulty Completion Rates
**Metric:** Per-scenario completion rate on Spymaster difficulty.
**Action threshold:** If any scenario has < 5% Spymaster completion rate after 500+ attempts, adjust the difficulty modifier (e.g., floor whispers at 2/day for that scenario, or reduce rival cooldown offset to 0 on Spymaster).

### Priority 5 — Evidence Item Usage Distribution
**Metric:** Which evidence items players craft with, and whether Witness Account's mutability reduction is valued.
**Action threshold:** If one evidence type accounts for > 80% of usage, consider rebalancing acquisition conditions or bonus values.

---

## Appendix: Key File Locations

| File | Contents |
|------|----------|
| `rumor_mill/scripts/scenario_manager.gd` | Win/fail constants (S1_WIN, S2_WIN, S3_WIN/FAIL, S4_WIN/FAIL) |
| `rumor_mill/data/scenarios.json` | daysAllowed, edgeOverrides, personalityOverrides, startingReputations, targetShiftExcluded |
| `rumor_mill/data/npcs.json` | All 30 NPC personality stats |
| `rumor_mill/data/claims.json` | Claim templates with intensity and mutability |
| `rumor_mill/scripts/intel_store.gd` | MAX_DAILY_WHISPERS=2, MAX_DAILY_ACTIONS=3, MAX_EVIDENCE=3, heat system |
| `rumor_mill/scripts/game_state.gd` | Difficulty preset modifiers (Apprentice/Master/Spymaster) |
| `rumor_mill/scripts/propagation_engine.gd` | beta scale=1.8, gamma scale=0.30, faction mods, chain bonuses |
| `rumor_mill/scripts/npc.gd` | Belief state machine, EVALUATING->BELIEVE formula, ACT timing |
| `rumor_mill/scripts/rival_agent.gd` | Scenario 3 rival cooldowns, intensities, phase behavior |
| `rumor_mill/scripts/inquisitor_agent.gd` | Scenario 4 inquisitor cooldowns, intensities, claim rotation |
| `rumor_mill/scripts/faction_event_system.gd` | Random event triggers and effects |
| `rumor_mill/scripts/reputation_system.gd` | Reputation score formula |
| `rumor_mill/scripts/recon_controller.gd` | Evidence acquisition, eavesdrop mechanics |
