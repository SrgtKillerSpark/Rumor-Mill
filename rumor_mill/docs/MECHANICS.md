# Rumor Mill — Gameplay Mechanics Reference

> Version: SPA art-pass 3 (post-SPA-99). All numbers reflect the latest balance tuning.

---

## Table of Contents

1. [Core Loop](#1-core-loop)
2. [Controls & Keyboard Shortcuts](#2-controls--keyboard-shortcuts)
3. [Recon Actions](#3-recon-actions)
4. [Evidence Items](#4-evidence-items)
5. [Rumor Crafting](#5-rumor-crafting)
6. [Rumor Propagation](#6-rumor-propagation)
7. [NPC Behavior & State Machine](#7-npc-behavior--state-machine)
8. [Player Heat](#8-player-heat)
9. [Bribery](#9-bribery)
10. [Counter-Intelligence NPCs](#10-counter-intelligence-npcs)
11. [Social Graph Evolution](#11-social-graph-evolution)
12. [Reputation System](#12-reputation-system)
13. [Rival Agent (Scenario 3)](#13-rival-agent-scenario-3)
14. [Scenarios & Win/Fail Conditions](#14-scenarios--winfail-conditions)
15. [Key Numerical Reference](#15-key-numerical-reference)

---

## 1. Core Loop

```
Observe locations / Eavesdrop NPCs
        ↓
Gather Intel (relationship data, location schedules, evidence items)
        ↓
Craft Rumor (choose subject, claim type, attach evidence)
        ↓
Seed Rumor (spend Whisper Token, plant into a target NPC)
        ↓
Watch Propagation (SIR diffusion spreads belief through the social graph)
        ↓
Monitor Reputation / Heat / Win Conditions
```

Each **game tick** equals 1/24 of an in-game day (24 ticks = 1 day). Daily resources replenish at dawn (tick 0 each day).

---

## 2. Controls & Keyboard Shortcuts

### Gameplay Keys

| Key | Action |
|-----|--------|
| **R** | Open / close Rumor Crafting Panel |
| **J** | Open / close Player Journal |
| **G** | Toggle Social Graph Overlay |
| **Escape** | Pause menu / return to main menu |

### Camera

| Input | Action |
|-------|--------|
| Middle-mouse drag | Pan camera |
| Scroll wheel | Zoom in/out |

### World Interaction

| Input | Action |
|-------|--------|
| Right-click building | Observe (costs 1 Recon Action) |
| Right-click NPC in conversation | Eavesdrop (costs 1 Recon Action) |
| Left-click NPC | Hover tooltip (shows name, faction, heat) |

### Building Interior

| Key | Action |
|-----|--------|
| **E** or **Escape** | Exit building interior |

### Debug Tools (developer use)

| Key | Action |
|-----|--------|
| F1 | Toggle debug console |
| F2 | Toggle NPC state badges |
| F3 | Toggle social graph debug overlay |
| F4 | Toggle lineage tree view |

---

## 3. Recon Actions

### Daily Resources

| Resource | Amount | Replenishes |
|----------|--------|-------------|
| Recon Actions | **3 per day** | Dawn (start of each new day) |
| Whisper Tokens | **2 per day** | Dawn |
| Bribe Charges | **2 per scenario** | Never (scenario-wide limit) |
| Evidence Inventory | **3 slots max** | Oldest item discarded when full |

The HUD (top-right corner) displays: `Actions: X/3 | Whispers: X/2 | Favors: X`

---

### Observe

**Cost:** 1 Recon Action

Right-click a building to observe it. The game snapshots all NPCs within **4 tiles** of the building's entry cell and records:
- NPC name and faction
- Approximate arrival and departure time at that location

**Evidence acquired during Observe** (see §4 for full details):
- **Forged Document** — 20% chance when observing **Market or Guild** with ≥2 Recon Actions remaining
- **Incriminating Artifact** — acquired after 6 PM (ticks 18–24) at **Noble Estate or Temple**

---

### Eavesdrop

**Cost:** 1 Recon Action

Right-click an NPC who is currently **within 3 tiles** of another NPC (i.e., "in conversation") to eavesdrop. Records the relationship between the two NPCs and adds it to your Intel Store.

**What you learn:**
- Affinity label: **Allied** (edge weight >0.60), **Neutral** (0.33–0.60), or **Suspicious** (<0.33)
- The exact weight is hidden; only the label is shown

**Heat cost:** +8 heat to both NPCs in the conversation (see §8)

**Detection risk:** If either NPC has temperament >0.7, there is a **20% chance** they detect you.
- On detection: +4 additional heat to both NPCs
- In Scenario 1 only: detection triggers an **instant fail**

**Special evidence — Witness Account:**
Re-eavesdrop on the **same NPC pair** after ≥24 ticks have passed since your last eavesdrop of that pair to acquire a Witness Account (+15% believability, −15% mutability when attached to a rumor).

---

## 4. Evidence Items

Evidence items are optional attachments that modify a rumor when seeding. The inventory holds a maximum of **3 items**; acquiring a 4th discards the oldest.

| Item | Acquisition | Bonus | Compatible Claims |
|------|-------------|-------|-------------------|
| **Forged Document** | Observe Market or Guild with ≥2 Actions remaining | +20% believability | ACCUSATION, SCANDAL, HERESY |
| **Incriminating Artifact** | Observe Noble Estate or Temple after 6 PM (ticks 18–24) | +25% believability | SCANDAL, HERESY |
| **Witness Account** | Re-eavesdrop same NPC pair after ≥24 ticks | +15% believability, −15% mutability | Any |

Evidence is consumed when attached to a seeded rumor. If the evidence type is incompatible with the chosen claim, it will not appear as an option in Panel 3 of the Rumor Crafting panel.

---

## 5. Rumor Crafting

Open the Rumor Crafting Panel with **R**. Crafting takes place across three panels:

### Panel 1 — Choose Subject

Select the NPC to be the subject of the rumor. Displays:
- Faction badge (Merchant = gold, Noble = blue, Clergy = cream)
- Known relationship intel (from eavesdropping), shown as:
  - `[*] Close with: Name [***] (strong)` — allied pair
  - `[!] Suspicious of: Name [*] (weak)` — suspicious pair
- Lock icon on NPCs with no eavesdrop intel (you can still target them but won't have relationship data)

---

### Panel 2 — Choose Claim

Claims are filtered by the subject's faction (each claim type has `targetFactions` restrictions). Displays for each claim:
- Claim ID and type (e.g., `[ACCUSATION] ACC-01`)
- Template text with `[subject]`, `[faction]`, `[location]` placeholders filled in
- Intensity bars (1–5) and Mutability bars (1–5)

#### Claim Types

| Type | Count | Intensity | Sentiment | Notes |
|------|-------|-----------|-----------|-------|
| ACCUSATION | 3 | 3–4 | Negative | Theft, betrayal, embezzlement |
| SCANDAL | 3 | 2 | Negative | Illicit meetings, debts |
| ILLNESS | 2 | 3–5 | Negative | Plague, strange behavior |
| PROPHECY | 2 | 2 | Positive | Misfortune or divine favor |
| PRAISE | 2 | 1–2 | Positive | Heroism, generosity |
| DEATH | 1 | 5 | Negative | Found dead; see SOCIALLY_DEAD |
| HERESY | 2 | 3–4 | Negative | Blasphemy, forbidden rites |

**Intensity** affects base believability (`intensity / 5.0`), mutation resistance, and decay rate. **Mutability** (0.0–1.0, from 1–5 scaled) affects how often the rumor mutates as it spreads.

---

### Panel 3 — Seed Target & Confirm

Select a target NPC to receive the rumor. Each candidate shows:
- **Spread estimate**: approximate number of NPCs within an 8-tile radius weighted by sociability
- **Believability estimate**: base claim intensity + 15% bonus if target shares faction with subject

Optionally attach one compatible evidence item (see §4). The evidence bonuses are shown inline.

**Confirmation is two-step**: first click shows a summary; second click spends 1 Whisper Token and plants the rumor into the target (placing them in the EVALUATING state).

---

### Rumor Properties

| Property | Details |
|----------|---------|
| **Believability** | 0.0–1.0. Base = `intensity / 5.0`. Modified by evidence and corroboration. Decays over time. |
| **Mutability** | 0.0–1.0. Scales mutation probability per tick (`mutability × 0.15` per type). |
| **Shelf Life** | Default 330 ticks (~13.75 days). Believability drops by `1 / shelf_life_ticks` per tick. |
| **Lineage** | Each rumor tracks `parent_id` and mutation type for the lineage tree (F4). |

---

## 6. Rumor Propagation

The propagation engine runs a **SIR (Susceptible–Infected–Recovered) diffusion model** each tick.

### Spread Probability (β)

```
β = sociability_spreader × credulity_target × edge_weight × faction_modifier × 1.8
```

Clamped to [0.0, 1.0].

**Faction modifiers:**

| Relationship | Modifier |
|-------------|---------|
| Same faction | ×1.2 |
| Neutral pair | ×0.8 |
| Opposing pair (merchant↔noble, noble↔clergy) | ×0.5 |

**Heat modifier** (reduces effective credulity of the target):

| Target's Heat | Credulity Reduction |
|--------------|---------------------|
| 50–74 | −0.15 |
| ≥75 | −0.30 |

### Recovery Probability (γ)

```
γ = loyalty × (1 − temperament) × 0.30
```

Each tick, an NPC in the BELIEVE state rolls against γ. On success they transition to REJECT (forget the rumor). High loyalty + low temperament = more persistent beliefs.

### Mutations

When a rumor spreads to a new NPC, four independent mutation checks run, each with probability `mutability × 0.15`:

| Mutation | Effect |
|----------|--------|
| **Exaggeration** | intensity += 1 (max 5) |
| **Softening** | intensity −= 1 (min 1); mutually exclusive with Exaggeration |
| **Target Shift** | Subject NPC is reassigned to a random connected NPC (excluded NPCs per scenario) |
| **Detail Addition** | No mechanical change; adds flavor to the lineage log |

Mutated rumors get a new ID in the format `parent_id_m{counter}` and are tracked in the lineage registry.

---

## 7. NPC Behavior & State Machine

### Personality Stats (each 0.0–1.0)

| Stat | Effect |
|------|--------|
| **Credulity** | Probability of believing a rumor (EVALUATING → BELIEVE) |
| **Sociability** | Frequency of spreading rumors (affects β) |
| **Loyalty** | Resistance to forgetting (affects γ); high loyalty can trigger DEFENDING |
| **Temperament** | Resistance to acting; high temperament = quicker action, higher eavesdrop detection risk |

### Rumor State Machine

```
UNAWARE
  └─→ EVALUATING (heard the rumor)
        ├─→ BELIEVE (convinced)
        │     ├─→ SPREAD (telling others)
        │     │     └─→ ACT (terminal: behavior change)
        │     └─→ REJECT (forgotten)
        │           └─→ DEFENDING* (high-loyalty NPC shielding an ally)
        └─→ REJECT (unconvinced)
```

Additional terminal/special states: **CONTRADICTED** (conflicting rumors), **EXPIRED** (shelf-life ran out), **DEFENDING** (active shielding).

### EVALUATING → BELIEVE

```
chance = credulity × rumor.believability
       + 0.15  (if source NPC shares faction with target)
       + min(heard_from_count − 1, 3) × 0.10  (corroboration bonus, max +0.30)
       − defense_penalty  (if a neighbor is DEFENDING the subject; see §10)
```

### BELIEVE → ACT

```
act_threshold_ticks = round(8.0 × (1.0 − temperament))
```

After the NPC has been in BELIEVE for that many ticks, they transition to ACT.
- Low temperament → short threshold → acts faster
- High temperament → waits longer before acting

### ACT Behavior

On entering ACT, the NPC's social graph edge to the subject is mutated:

| Claim Type | Actor→Subject | Subject→Actor |
|-----------|--------------|--------------|
| ACCUSATION / SCANDAL / HERESY / ILLNESS | −0.15 | −0.075 |
| PRAISE | +0.10 | +0.05 |
| PROPHECY / DEATH | No change | No change |

The NPC also moves: toward the subject for positive claims, away for negative claims.

### Visual State Cues

| State | Sprite Tint |
|-------|------------|
| UNAWARE | White (normal) |
| EVALUATING | Yellow |
| BELIEVE | Soft green |
| SPREAD | Orange |
| ACT | Magenta-pink |
| REJECT | Cool grey-blue |
| CONTRADICTED | Muted purple |
| DEFENDING | Sky blue |
| EXPIRED | Grey |

**Heat Shimmer**: At heat ≥50, sprite pulses between state tint and warm amber; at heat ≥75, the pulse shifts to red-orange and speeds up.

**Interaction feedback:**
- Bribe success: single slow gold pulse (~0.7 s)
- Eavesdrop detected: two red pulses (~0.8 s)
- Rumor transmission: floating 💬 icon drifts upward (1.5 s)
- ACT onset: pulsing ⚡ icon (~2 s, 2–3 pulses/s depending on heat)

---

## 8. Player Heat

Heat is a **per-NPC suspicion meter** (0–100). NPCs with high heat become harder targets for rumor propagation.

### Heat Sources

| Action | Heat Added |
|--------|-----------|
| Eavesdrop on an NPC pair | +8 to **both** NPCs |
| Eavesdrop detection | +4 additional to both NPCs |
| NPC relays a player-seeded rumor (spreader) | +2 to the spreading NPC |

### Heat Thresholds

| Heat Level | Label | Effect |
|-----------|-------|--------|
| <50 | Normal | No penalty |
| 50–74 | **Wary** | −15% credulity for incoming rumors |
| ≥75 | **Suspicious** | −30% credulity for incoming rumors |

### Heat Decay

Heat decays by **−6 per day** at dawn. At this rate, a maximally suspicious NPC (heat 100) becomes Wary after ~4 days and returns to normal after ~17 days. Avoid repeatedly eavesdropping the same NPC pairs.

---

## 9. Bribery

**Cost:** 1 Recon Action + 1 Whisper Token + 1 Bribe Charge

Bribery forces a target NPC currently in the **EVALUATING** state to immediately transition to **BELIEVE** for a specific rumor, bypassing the normal credulity roll.

**Bribe Charges:** 2 total per scenario. They do **not** replenish at dawn.

**Availability:** Bribery is enabled in **Scenarios 2 and 3 only** (disabled in the tutorial Scenario 1).

Visual confirmation: the bribed NPC's sprite plays a single slow gold pulse.

---

## 10. Counter-Intelligence NPCs

Certain NPCs with **loyalty >0.7** will actively defend allies when they hear and reject a negative rumor about them. This is the DEFENDING state.

### DEFENDING Behavior

1. Triggered when a high-loyalty NPC transitions to REJECT for a negative rumor about a close ally (edge weight implies alliance).
2. While DEFENDING (lasts **5 ticks**), the NPC broadcasts a **−0.15 credulity penalty** to all neighboring NPCs within conversation range.
3. This penalty stacks with multiple defenders, capped at **−0.30 total**.
4. The penalty on neighbors lasts **3 ticks** after being applied.

The DEFENDING NPC is visually identified by a **sky-blue** sprite tint.

**Strategic implication:** Targeting an NPC with many high-loyalty allies is much harder. Use eavesdrop intel to identify relationship strengths and avoid triggering defensive cascades.

---

## 11. Social Graph Evolution

The social graph is a **weighted directed adjacency list**. Each directed edge (A→B) has a weight from 0.0–1.0.

### Initial Edge Weight Formula

```
weight = (faction_affinity × 0.5) + (proximity × 0.3) + (role_affinity × 0.2)
```

| Factor | Values |
|--------|--------|
| Faction affinity | Same = 0.8, Opposing (merchant↔noble, noble↔clergy) = 0.1, Neutral = 0.4 |
| Proximity | Randomised 0.1–0.5 at map generation |
| Role affinity | Same faction = 0.3, Different = 0.1 |

### How Edges Mutate

When an NPC enters the **ACT** state, they mutate their edge to the rumor subject (and the reverse edge more weakly). Each directed edge can mutate a maximum of **3 times**. Mutations are logged with: `from_id`, `to_id`, `delta`, `tick`.

The **Social Graph Overlay** (G key) visualises edge weights and cumulative mutation direction with color tinting. Use this to track which relationships have been degraded or strengthened by your campaigns.

---

## 12. Reputation System

Each NPC has a reputation score (0–100) that drives the win/fail conditions.

### Score Formula

```
score = clamp(base_score + faction_sentiment + rumor_delta, 0, 100)
```

**Base score:** 50 (default; overridden per scenario for key NPCs)

**Faction Sentiment** (−20 to +20):
```
(same_faction_believers / faction_size) × direction × 20
```
- `direction` = +1 for PRAISE, −1 for negative claims

**Rumor Delta** (−40 to +30 total):
```
per rumor: direction × intensity × believability × min(believer_count / 10, 3.0)
```

### Reputation Tiers

| Score | Label | Color |
|-------|-------|-------|
| ≥85 | Revered | Gold |
| 70–84 | Distinguished | Gold |
| 50–69 | Respected | Warm white |
| 35–49 | Suspicious | Amber |
| 20–34 | Disgraced | Red |
| <20 | Despised | Red |

### Special Condition: SOCIALLY_DEAD

When ≥5 NPCs believe a **DEATH** rumor about a target with believability >0.6, that target's reputation is **locked** — it cannot change further. This is a terminal state for that NPC.

---

## 13. Rival Agent (Scenario 3)

In Scenario 3 ("The Succession"), an AI rival is working against you. It seeds its own rumors each day.

### Rival Phases

**Days 1–7 (Establishment):**
- Seeds PRAISE (intensity 2) about Tomas Reeve every 3 days.

**Days 8–15 (Escalation):**
- Alternates: PRAISE for Tomas / SCANDAL about Calder (intensity 3) every 2 days.

**Days 16–25 (Metric-Driven):**
- Calculates two gap values:
  - `calder_gap = calder_score − 40` (how far Calder is above his instant-fail floor)
  - `tomas_gap = 35 − tomas_score` (how far Tomas is below the win ceiling)
- If `calder_gap ≤ tomas_gap`: seeds SCANDAL about **Calder** (intensity 4) — most dangerous to you.
- Otherwise: seeds PRAISE about **Tomas** (intensity 4).

**NPC Selection:** The rival picks the highest-sociability NPC at a social location (market/tavern) with heat ≤50 who is not already in SPREAD or ACT state.

**Strategic implication:** In the late game, the rival targets whichever of your metrics is weaker. Protect Calder's reputation floor (≥40) aggressively — if Calder is close to failing, the rival will accelerate SCANDAL seeding against him.

---

## 14. Scenarios & Win/Fail Conditions

### Scenario 1 — "The Alderman's Ruin"

| Parameter | Value |
|-----------|-------|
| Time limit | **30 days** |
| Goal | Destroy Edric Fenn's reputation |
| **WIN** | `reputation(Edric Fenn) < 30` |
| **FAIL — caught** | Player is detected eavesdropping (instant) |
| **FAIL — timeout** | Day > 30 |

**Key info:** Edric has very high loyalty (0.80) and very low credulity (0.05), making him resistant to rumors. You must spread rumors widely through the town so the faction sentiment and rumor-delta scores drag him below 30 indirectly.

This is the tutorial scenario. Bribery is **disabled**.

---

### Scenario 2 — "The Plague Scare"

| Parameter | Value |
|-----------|-------|
| Time limit | **20 days** |
| Goal | Spread illness rumors about Alys Herbwife |
| **WIN** | ≥7 NPCs in BELIEVE/SPREAD/ACT for an illness rumor about Alys |
| **FAIL — defender** | Sister Maren transitions to REJECT for any illness rumor about Alys (instant) |
| **FAIL — timeout** | Day > 20 |

**Key info:** Alys has high temperament (0.65). Sister Maren is the main counter-intelligence risk — do not let illness rumors reach her, or keep her from reaching REJECT by ensuring she stays EVALUATING or BELIEVE. Bribery is **enabled** (2 charges).

---

### Scenario 3 — "The Succession"

| Parameter | Value |
|-----------|-------|
| Time limit | **25 days** |
| Goal | Elevate Calder Fenn, tank Tomas Reeve |
| **WIN** | `reputation(Calder Fenn) ≥ 75` AND `reputation(Tomas Reeve) ≤ 35` |
| **FAIL — Calder collapses** | `reputation(Calder Fenn) < 40` (instant) |
| **FAIL — timeout** | Day > 25 |

**Starting reputations:** Calder = 58, Tomas = 52.

**Key info:** You must simultaneously run a positive campaign (PRAISE for Calder) and a negative one (ACCUSATION/SCANDAL for Tomas). The rival agent (see §13) actively counters both goals. Target-shift mutations are configured to **exclude Calder** as a possible shift target — your positive rumors about him won't accidentally become scandals. Bribery is **enabled** (2 charges).

---

## 15. Key Numerical Reference

| Parameter | Value | Notes |
|-----------|-------|-------|
| Max daily Recon Actions | 3 | Replenish at dawn |
| Max daily Whisper Tokens | 2 | Replenish at dawn |
| Max Bribe Charges | 2 | Scenario-wide, no replenish; Scenarios 2–3 only |
| Max Evidence slots | 3 | Oldest discarded on overflow |
| Eavesdrop conversation range | 3 tiles | NPC must be near another NPC |
| Eavesdrop detection chance | 20% | Only if target temperament >0.7 |
| Observe NPC snapshot radius | 4 tiles | Around building entry cell |
| Rumor spread radius | 8 tiles | Manhattan distance |
| β scale factor | 1.8 | Overall spread probability multiplier |
| γ scale factor | 0.30 | Recovery probability scale |
| Same-faction spread bonus | ×1.2 | |
| Opposing-faction spread penalty | ×0.5 | Merchant↔Noble, Noble↔Clergy |
| Heat: Wary threshold | 50 | −15% credulity to incoming rumors |
| Heat: Suspicious threshold | 75 | −30% credulity to incoming rumors |
| Heat decay | −6 per day | Applied at dawn |
| Eavesdrop heat cost | +8 per NPC | Both NPCs in the pair |
| Detection heat cost | +4 per NPC | On top of eavesdrop cost |
| Rumor relay heat cost | +2 | To the spreading NPC |
| Default shelf life | 330 ticks | ~13.75 days |
| Believability decay | 1 / shelf_life per tick | |
| Mutation probability per type | mutability × 0.15 | Up to 4 independent checks |
| Max edge mutations | 3 per directed pair | |
| DEFENDING loyalty threshold | >0.7 | |
| DEFENDING duration | 5 ticks | |
| DEFENDING credulity penalty | −0.15 per defender | |
| DEFENDING penalty cap | −0.30 total | |
| DEFENDING neighbor penalty duration | 3 ticks | |
| ACT threshold ticks | 8 × (1 − temperament) | Varies per NPC |
| Corroboration bonus | +0.10 per additional source | Capped at +0.30 (+3 sources) |
| Same-faction source believe bonus | +0.15 | |
| SOCIALLY_DEAD trigger | 5+ believers, believability >0.6 | DEATH claims only |
| Reputation base score | 50 | Default; overridden per scenario |
| Scenario 1 win threshold | Edric reputation < 30 | |
| Scenario 2 win threshold | 7+ illness believers | |
| Scenario 3 win threshold | Calder ≥75, Tomas ≤35 | |
| Scenario 3 instant-fail floor | Calder < 40 | |
