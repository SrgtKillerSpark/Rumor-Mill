# Scenario Difficulty Curves & Mid-Scenario Narrative Events

Design specification for scenario pacing, difficulty curves, and mid-scenario narrative events across all four active scenarios. Each scenario now features three narrative events that create turning points and escalate tension toward the climax.

---

## Difficulty Curve Overview

### Scenario 1 — The Alderman's Ruin (30 days)

**Mechanic:** Pure offense. Destroy Lord Edric Fenn's reputation below 30.

| Phase | Days | Tension | Player Focus |
|-------|------|---------|--------------|
| Setup | 1–7 | Low | Recon: map the social graph, find weak loyalty links around Edric |
| Escalation | 8–12 | Medium | **The Ledger** fires — first major decision point. Seed initial scandal rumors through merchant chain |
| Mid-game | 13–17 | Medium-High | **The Midnight Meeting** fires — bridges toward the feast, forces risk/reward trade on heat vs. progress |
| Climax | 18–22 | High | **The Feast Invitation** fires — Edric's last-ditch reputation play. Player must counter or exploit |
| Endgame | 23–30 | Critical | Race to push Edric below 30 before time or heat ceiling hits |

**Difficulty levers:** Days allowed (36/30/25), credulity delta (+0.10/0/−0.10), heat rate multiplier (0.75/1.0/1.30), heat ceiling (95/80/65), Edric loyalty (0.70/0.70/0.85), Bram loyalty (default/default/0.75).

**Curve shape:** Slow ramp. The first 7 days are pure information-gathering. Events at days 8–12, 13–17, and 18–22 create three escalation steps. The final quarter is a pure execution sprint.

---

### Scenario 2 — The Plague Scare (24 days)

**Mechanic:** Epidemic spread. Get 7+ NPCs to believe illness rumors about Alys Herbwife without Sister Maren rejecting any.

| Phase | Days | Tension | Player Focus |
|-------|------|---------|--------------|
| Setup | 1–4 | Low | Identify credulous market NPCs, plan rumor routing away from Maren's orbit |
| Early push | 5–8 | Medium | **The Stranger's Cough** fires — first opportunity for instant believers or Maren suppression |
| Autonomous escalation | 9–12 | Medium-High | IllnessEscalationAgent accelerates (cooldown drops from 6 to 3 days). Player must guide spread |
| Counter-attack | 13–16 | High | **Alys Fights Back** fires — defensive event, risk of losing believers |
| Final push | 18–22 | Critical | **The Chapel Vigil** fires — Maren gathers the devout, creating both danger and opportunity. Last chance to reach 7 believers |
| Deadline | 23–24 | Maximum | No events; pure execution against the clock |

**Difficulty levers:** Days (29/24/20), credulity delta (+0.10/0/−0.10), believer threshold (5/7/9), Maren credulity override (default/0.20/0.30).

**Curve shape:** Front-loaded danger. The instant-fail condition (Maren rejection) creates constant background tension. The IllnessEscalationAgent adds mounting pressure through the mid-game. The new Chapel Vigil event at days 18–22 creates a climactic risk/reward moment just before the deadline.

---

### Scenario 3 — The Succession (27 days)

**Mechanic:** Two-front war. Raise Calder Fenn to 75+ reputation AND drop Tomas Reeve to 35 or below.

| Phase | Days | Tension | Player Focus |
|-------|------|---------|--------------|
| Setup | 1–5 | Low-Medium | Establish rumor pipelines on both fronts. RivalAgent starts praising Tomas (cooldown 4) |
| Intel phase | 6–9 | Medium | **The Debt Letter** fires — first major weapon against Tomas, but alerting the rival is a trade-off |
| Mid-game pivot | 10–14 | Medium-High | **The Merchant Pact** fires — guild alignment creates a faction-level shift. RivalAgent enters phase 2 (alternating attacks, cooldown 2) |
| Crisis | 15–19 | High | **Calder's Blunder** fires — defensive emergency. RivalAgent is now fully active on both fronts |
| Endgame | 20–27 | Critical | RivalAgent in metric-driven phase 3 (cooldown 1). Pure execution race on both fronts |

**Difficulty levers:** Days (32/27/23), credulity delta (+0.10/0/−0.10), rival start day (22/18/14), rival intensity delta (−1/0/+1), Calder win threshold (70/75/80), Tomas target (40/35/30), Calder fail floor (30/35/40), starting reps.

**Curve shape:** Steady acceleration. The RivalAgent's three-phase cooldown (4→2→1 days) creates an inexorable ramp. Events are spaced to match: a weapon at day 6–9, a strategic pivot at 10–14, and a defensive crisis at 15–19. The final third is pure pressure.

---

### Scenario 4 — The Holy Inquisition (20 days)

**Mechanic:** Pure defense. Keep Aldous Prior, Vera Midwife, and Finn Monk above 45 reputation for 20 days.

| Phase | Days | Tension | Player Focus |
|-------|------|---------|--------------|
| Opening salvo | 1–3 | Medium | InquisitorAgent seeds first heresy rumor (cooldown 4). Identify which accused is most vulnerable |
| Noble intervention | 4–7 | Medium-High | **A Noble Speaks** fires — first defensive boost, choice between concentrated or spread protection |
| Sustained assault | 8–10 | High | InquisitorAgent enters phase 2 (cooldown 2, intensity 3). Triage becomes essential |
| Evidence crisis | 11–14 | Very High | **Forged Evidence** fires — the Inquisitor's most aggressive move. Player must choose to confront or cushion |
| Inquisitor frenzy | 15 | Maximum | InquisitorAgent enters phase 3 (cooldown 1). Accusations come every day |
| Breaking point | 16–19 | Critical | **The Breaking Point** fires — the weakest accused is near collapse. Player's last chance to stabilize before the deadline |
| Final day | 20 | Resolution | Win condition checked: all three must be ≥ 45 |

**Difficulty levers:** Days (24/20/17), credulity delta (+0.10/0/−0.10), inquisitor cooldown delta (+2/0/−2), inquisitor intensity delta (−1/0/+1), win threshold (40/45/50), fail threshold (35/40/45), starting reps.

**Curve shape:** Relentless escalation. The InquisitorAgent never stops and only gets faster. The three events are spaced at early (4–7), middle (11–14), and late (16–19) to give the player exactly three moments of agency in an otherwise reactive scenario. The new Breaking Point event at days 16–19 provides a desperately needed intervention point just as the Inquisitor reaches maximum intensity.

---

## New Mid-Scenario Narrative Events (SPA-601)

Each scenario previously had 2 events. One new event per scenario has been added to fill pacing gaps and ensure three-act escalation structure.

### S1 — The Midnight Meeting (NEW)

| Field | Value |
|-------|-------|
| ID | `s1_midnight_meeting` |
| Day window | 13–17 |
| Probability | 0.60 |
| Trigger type | Day-gated, probabilistic |
| Narrative role | Bridges The Ledger (days 8–12) and The Feast (days 18–22) |

**Choice A — "Eavesdrop and spread what you overhear"**
- Edric reputation −4
- Annit Scribe loyalty −0.10, Isolde Fenn loyalty −0.10
- Bram Guard heat +12.0
- Design intent: High-reward/high-risk. Directly damages Edric's inner circle loyalty but generates significant heat. Suits aggressive players who are ahead on their timeline.

**Choice B — "Bribe the servant for details instead"**
- +2 bonus recon actions for 2 days
- Injects a scandal rumor (intensity 2) targeting Edric through merchant faction
- Design intent: Safe play. No heat cost, but the damage is indirect and slower. Suits cautious players or those already near the heat ceiling.

---

### S2 — The Chapel Vigil (NEW)

| Field | Value |
|-------|-------|
| ID | `s2_chapel_vigil` |
| Day window | 18–22 |
| Probability | 0.55 |
| Trigger type | Day-gated, probabilistic |
| Narrative role | Final push event. Creates climactic tension around Maren's proximity to the rumor |

**Choice A — "Use the empty market"**
- 2 instant believers from credulous market pool
- Maren credulity +0.05 (she becomes slightly more likely to hear rumors after the vigil)
- Design intent: Direct progress toward the 7-believer win condition, but slightly increases Maren's detection risk for the remaining days. Best when the player is 2–3 believers short.

**Choice B — "Attend the vigil and redirect the prayers toward Alys"**
- Finn Monk, Old Piety, Jude Bellringer each gain credulity +0.10
- Maren heat +8.0
- Design intent: Opens the clergy faction to illness rumors (previously a dead zone). High risk — heat on Maren means she's paying attention. Best for players who need to route rumors through new social clusters.

---

### S3 — The Merchant Pact (NEW)

| Field | Value |
|-------|-------|
| ID | `s3_merchant_pact` |
| Day window | 10–14 |
| Probability | 0.60 |
| Trigger type | Day-gated, probabilistic |
| Narrative role | Mid-game strategic pivot. Bridges The Debt Letter (days 6–9) and Calder's Blunder (days 15–19) |

**Choice A — "Convince Aldric that Calder is good for trade"**
- Calder Fenn reputation +4
- Aldric Vane loyalty +0.10, Sybil Oats loyalty +0.10
- Design intent: Strengthens Calder's support network. The loyalty boosts make praise rumors about Calder propagate more effectively through the merchant chain. Defensive play.

**Choice B — "Poison the well — make the guild distrust Tomas"**
- Tomas Reeve reputation −4
- Injects a scandal rumor (intensity 2) targeting Tomas through merchant faction
- Rival intensity +1 for 3 days
- Design intent: Offensive play that accelerates Tomas's decline but provokes the rival into a short burst of counter-activity. Best when Calder's rep is already stable and the player can absorb the rival's response.

---

### S4 — The Breaking Point (NEW)

| Field | Value |
|-------|-------|
| ID | `s4_breaking_point` |
| Day window | 16–19 |
| Probability | 0.70 |
| Trigger type | Day-gated, probabilistic |
| Narrative role | Climax event. Last intervention before the Inquisitor's maximum-intensity final days |

**Choice A — "Rally the accused"**
- Weakest protected NPC: reputation +5, loyalty +0.15
- Inquisitor cooldown −1 (he gets faster, sensing resistance)
- Design intent: Directly saves the most endangered accused but provokes the Inquisitor. Creates a dramatic final 2–3 days where the player must defend all three under maximum pressure. Best when one accused is near the danger zone and the others are safe.

**Choice B — "Redirect the Inquisitor — give him a false lead"**
- Inquisitor cooldown +2 (two days of breathing room)
- Weakest protected NPC: reputation +2
- Aldous Prior heat +8.0
- Design intent: Buys critical time by sending the Inquisitor on a wild-goose chase. The heat on Aldous is a cost — the player's own heat near a clergy NPC. Best when all three accused are in moderate danger and the player needs time to spread defensive rumors evenly.

---

## Event Trigger Reference

All events are **day-gated** with a **probability roll** per day within the window. Only one event can be pending at a time, and only one fires per day (enforced by `MidGameEventAgent`).

| Scenario | Event | Days | Prob | Gate Type |
|----------|-------|------|------|-----------|
| S1 | The Ledger | 8–12 | 0.65 | Day-gated |
| S1 | The Midnight Meeting | 13–17 | 0.60 | Day-gated |
| S1 | The Feast Invitation | 18–22 | 0.60 | Day-gated |
| S2 | The Stranger's Cough | 5–8 | 0.70 | Day-gated |
| S2 | Alys Fights Back | 13–16 | 0.60 | Day-gated |
| S2 | The Chapel Vigil | 18–22 | 0.55 | Day-gated |
| S3 | The Debt Letter | 6–9 | 0.70 | Day-gated |
| S3 | The Merchant Pact | 10–14 | 0.60 | Day-gated |
| S3 | Calder's Blunder | 15–19 | 0.55 | Day-gated |
| S4 | A Noble Speaks | 4–7 | 0.75 | Day-gated |
| S4 | Forged Evidence | 11–14 | 0.65 | Day-gated |
| S4 | The Breaking Point | 16–19 | 0.70 | Day-gated |

**Event density:** Events are spaced so that no two windows overlap within a scenario. The three events divide each scenario into roughly four acts: pre-event setup, early escalation, mid-game pivot, and climax sprint.

---

## Design Principles

1. **Every event offers a meaningful trade-off.** No "free lunch" choices — one option is aggressive (high reward, high cost), the other is conservative (moderate reward, low cost). This ensures the events feel like genuine turning points rather than interrupt bonuses.

2. **Events match the scenario's core tension.** S1 events expose information; S2 events manipulate belief count and Maren proximity; S3 events shift the two-front balance; S4 events trade Inquisitor pacing against accused stability.

3. **Events escalate across the timeline.** The first event in each scenario is an opportunity; the second is a crisis or counter-attack; the third is a climactic moment that defines the endgame.

4. **Effects use existing systems.** All event effects map to existing `MidGameEventAgent` effect types: `reputationChanges`, `heatChanges`, `personalityChanges`, `credulityChanges`, `bonusReconActions`, `instantBelievers`, `recoverBelievers`, `illnessEscalationCooldownDelta`, `rivalIntensityBonus`, `rivalCooldownBonus`, `injectRumor`, `inquisitorCooldownDelta`, `inquisitorFocusTarget`. No new effect types are introduced.
