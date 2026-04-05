# Rumor Mill -- Game Design Document

**Author:** Game Designer (SPA-702)
**Date:** 2026-04-05
**Status:** Living document -- updated each sprint

---

## The Pitch

Rumor Mill is a medieval social strategy game where your only weapon is information. You are a hired agent planted in a town of 30 NPCs -- your job is to spread, suppress, and mutate rumors through the social graph to shift reputations and achieve hidden objectives before time runs out. Every NPC has personality traits that affect how they receive, believe, and retell stories; every rumor mutates as it travels, sometimes in ways you didn't intend. The core loop -- observe the town, gather social intel, craft a rumor, seed it through the right person, then watch it ripple and adapt -- creates emergent narratives where no two playthroughs unfold the same way. Success requires reading people, not fighting them.

---

## Core Fun Loop

The player's moment-to-moment experience follows a tight cycle:

```
OBSERVE  -->  GATHER INTEL  -->  CRAFT RUMOR  -->  SEED  -->  WATCH & ADAPT
   |                                                              |
   +------- spend resources wisely, manage heat --------<---------+
```

1. **OBSERVE** -- Right-click buildings and NPCs to learn who is where, who talks to whom, and how strongly they're connected. Each observation costs 1 Recon Action (3/day).
2. **GATHER INTEL** -- Eavesdrop on NPC conversations to discover relationship strengths and collect evidence items that boost rumor believability.
3. **CRAFT RUMOR** -- Press R to open the three-panel crafting modal: pick a subject (who the rumor is about), a claim type (accusation, scandal, illness, etc.), and a seed target (who hears it first). Attach evidence for bonus impact. Costs 1 Whisper Token (2/day).
4. **SEED** -- The rumor enters the social graph. Its spread probability depends on the seed NPC's sociability, credulity, and relationship to the subject.
5. **WATCH & ADAPT** -- The rumor propagates via an SIR diffusion model. NPCs evaluate, believe or reject, spread to friends, and eventually act on what they believe. Rumors mutate in transit -- exaggeration, softening, target-shift, or detail-addition. The player monitors progress and plans the next move.

**What makes it fun:** The tension between control and chaos. You choose who hears the rumor first, but you can't control how it mutates or who it reaches. Strategic players learn to route rumors through high-sociability "conduit" NPCs while avoiding "firewall" NPCs who stall propagation. The limited daily resources (3 Recon, 2 Whisper) force hard choices about where to invest attention.

---

## Scenario Design

### Scenario 1: The Alderman's Ruin (Tutorial)

| | |
|---|---|
| **Days** | 30 |
| **Player Objective** | Destroy Lord Edric Fenn's reputation -- bring it below 30 (starts at 68) |
| **Primary Mechanic** | Pure offensive rumor campaign. No bribery. Player exposure = instant fail. |
| **What Makes It Engaging** | Edric is well-protected: low credulity (0.05), high loyalty from key allies (Bram Guard 0.90, Isolde 0.75). Direct attacks bounce off. Players must discover flanking paths through the merchant and clergy factions, learning that the social graph rewards indirect strategy over brute force. Three mid-game narrative events (The Ledger, The Midnight Meeting, The Feast Invitation) create dramatic turning points with meaningful choices. |
| **Win Condition** | `reputation(edric_fenn) < 30` |
| **Fail Conditions** | Day limit exceeded; player heat >= 80 (hard) / >= 95 (easy); caught eavesdropping on high-temperament NPC |

**Teaching goals:** Observe/eavesdrop cycle, rumor crafting fundamentals, reading the social graph, resource management, heat awareness.

---

### Scenario 2: The Plague Scare

| | |
|---|---|
| **Days** | 24 |
| **Player Objective** | Get 7+ NPCs to BELIEVE illness rumors about Alys Herbwife -- without Sister Maren rejecting the rumor |
| **Primary Mechanic** | Precision targeting with a defensive constraint. Bribery enabled (2 charges). An autonomous IllnessEscalationAgent seeds its own illness rumors on a cooldown. |
| **What Makes It Engaging** | The Maren constraint creates a puzzle-within-a-puzzle. Maren is a high-loyalty clergy NPC who will actively DEFEND Alys if she rejects the rumor -- triggering a 2-day grace window before scenario failure. Players must route illness rumors through the merchant faction (credulous, well-connected) while keeping them away from the clergy circle. The autonomous illness agent adds unpredictability -- sometimes helpful, sometimes catastrophic. |
| **Win Condition** | >= 7 NPCs in BELIEVE state for illness rumors targeting Alys Herbwife, Maren has not rejected |
| **Fail Conditions** | Maren rejects (2-day grace, then fail); day limit exceeded |

**Teaching goals:** Faction routing, bribery as a precision tool, managing autonomous agents, defensive awareness while attacking.

---

### Scenario 3: The Succession

| | |
|---|---|
| **Days** | 27 |
| **Player Objective** | Raise Calder Fenn's reputation to 75+ AND drop Tomas Reeve's reputation to 35 or below |
| **Primary Mechanic** | Two-front campaign (simultaneous offense and defense) against a RivalAgent that actively opposes you with counter-rumors. Rival escalates in 3 phases: 4-day cooldown -> 2-day -> 1-day. |
| **What Makes It Engaging** | This is the first scenario where the player faces active opposition. The RivalAgent seeds Praise rumors for Tomas and Scandal rumors against Calder, forcing the player to split attention between building up and tearing down. Calder dropping below 35 is an instant fail, creating constant defensive tension. The three-phase rival escalation means early game is manageable but late game becomes frantic. Players must choose: shore up Calder's defenses or hammer Tomas while they still have breathing room? |
| **Win Condition** | `reputation(calder_fenn) >= 75 AND reputation(tomas_reeve) <= 35` |
| **Fail Conditions** | Calder reputation < 35 (instant); day limit exceeded |

**Teaching goals:** Multi-objective management, playing offense and defense simultaneously, resource triage under AI pressure.

---

### Scenario 4: The Holy Inquisition

| | |
|---|---|
| **Days** | 20 |
| **Player Objective** | Keep Aldous Prior, Vera Midwife, and Finn Monk ALL above 45 reputation for 20 days |
| **Primary Mechanic** | Pure defense against an InquisitorAgent that relentlessly seeds heresy rumors. No bribery. Inquisitor escalates in 3 phases (4-day -> 2-day -> 1-day cooldown). |
| **What Makes It Engaging** | This flips the entire game on its head -- instead of attacking, you're protecting. The three targets have wildly different vulnerability profiles: Aldous Prior is nearly unshakeable (low credulity, high standing), Vera Midwife is moderate, and Finn Monk is dangerously credulous and easily swayed. Players must triage: who needs protection most? The Inquisitor never stops and only gets faster, creating an escalating crisis where the player must use Praise rumors and counter-narratives to shore up reputations while the Inquisitor tears them down. |
| **Win Condition** | All three targets remain above 45 reputation when Day 20 ends |
| **Fail Conditions** | Any of the three targets drops to 45 or below; day limit exceeded |

**Teaching goals:** Defensive strategy, triage under pressure, counter-narrative construction, long-term reputation management.

---

## Where Player Goals Are Currently Unclear

### Critical Clarity Gaps

**1. The Objective HUD does not show the win condition.**
The top-left HUD displays atmospheric flavour text from `startingText` rather than the actual numeric target. A first-time player sees "A foreign factor has entered the town quietly..." -- not "Drop Edric Fenn's reputation below 30." The mechanical win condition is buried in the Journal's Objectives tab, which requires discovering the J hotkey.

**Impact:** Players don't know what number they're chasing. They play reactively instead of strategically.

**2. No guidance connecting the player to their target NPC.**
After the briefing screen, players enter a town with ~25 visible NPCs and no visual distinction marking the primary target. Finding Edric Fenn requires hovering NPCs one by one. In a demo context, this costs critical first-impression minutes.

**Impact:** The first 2-3 minutes feel aimless, which reads as "this game doesn't know what it wants me to do."

**3. Faction dynamics are invisible to new players.**
The three-faction structure (Merchant, Noble, Clergy) and their dramatically different spreading behaviours are never explicitly taught. Merchants are fast but mutable, Clergy are credible but Maren blocks, Nobles are institutional. Understanding these differences is essential for Scenarios 2-4 but is left entirely to discovery.

**Impact:** Players who don't grasp faction routing hit a difficulty wall in Scenario 2 that feels unfair rather than challenging.

**4. Mid-game strategic guidance is absent.**
Once the initial tutorial hints fade (~Day 3-4), there is no system to help players evaluate whether they're on track. The Tier 3 Suggestion Engine (contextual nudges like "Marta Coin would spread this rumor to 12 NPCs") is a placeholder, not implemented. Players who fall behind have no scaffolding to course-correct.

**Impact:** Mid-game dead spots where players run out of ideas and don't know what to try next.

**5. Heat mechanic is opaque.**
Heat accumulates from eavesdropping, but per-NPC heat thresholds aren't shown. Players can't see which NPCs are "dangerously hot" (near exposure threshold). The relationship between individual NPC heat and scenario-level failure isn't explained in-game.

**Impact:** Exposure failures feel arbitrary ("I only eavesdropped twice!") rather than the consequence of a calculated risk.

---

## Top 3 Changes to Make the Game More Intuitive and Fun

### 1. Surface the Win Condition on the Objective HUD (High Impact, Low Cost)

**What:** Add a persistent target line below the objective text showing the primary metric:
- S1: `Edric Fenn: 68/100 -- need < 30`
- S2: `Believers: 2/7 -- Maren: Safe`
- S3: `Calder: 52/75 | Tomas: 58/35`
- S4: `Aldous: 72 | Vera: 61 | Finn: 55 -- all need > 45`

**Why:** Players need to see their goal at all times. The current design forces a Journal detour to check progress. Making the target visible turns every in-game action into a clear decision: "does this move my number in the right direction?"

**Where:** `scripts/objective_hud.gd` -- add a second label row reading from `ScenarioManager` win condition data.

### 2. Add a Pre-Game Strategic Brief and Target Marker (High Impact, Medium Cost)

**What:** Before the day counter starts, show a 15-second "Strategic Overview" screen for each scenario:
- Name and portrait of the target NPC(s)
- Their starting reputation and the threshold to hit
- The primary constraint (time limit, Maren's loyalty, rival agent, inquisitor)
- A one-sentence strategic hint ("Edric's inner circle is loyal -- attack from the outside in")

Then, when gameplay begins, mark the primary target NPC with a subtle crest icon for the first 60 seconds.

**Why:** The briefing screen is atmospheric but not actionable. Players need a bridge between "here's the story" and "here's your tactical situation." The target marker eliminates the "where is Edric Fenn?" friction that costs first-time players their opening minutes.

**Where:** New scene between briefing and gameplay start; target marker via temporary sprite overlay on NPC node.

### 3. Implement the Tier 3 Suggestion Engine (High Impact, High Cost)

**What:** A contextual hint system that fires 1-2 suggestions per day based on game state:
- "Nell Picker is a high-sociability merchant with connections to 8 NPCs -- she'd spread this rumor fast"
- "Edric's reputation hasn't moved in 3 days -- try a different claim type"
- "Your heat with Bram Guard is at 60% -- one more eavesdrop could expose you"
- "The Merchant faction is turning against Edric -- press the advantage with a scandal claim"

Suggestions appear as a small toast in the Tier 3 HUD slot. Dismissible, non-blocking, and only fire when the player hasn't acted in 90+ seconds or at dawn.

**Why:** This is the difference between "I don't know what to do" and "I have options and I'm choosing." The suggestion engine doesn't play the game for you -- it surfaces information the player already has access to (via Journal and Social Graph) but hasn't synthesised. It's training wheels for the strategic thinking the game rewards.

**Where:** New `scripts/suggestion_engine.gd` reading from `ReputationSystem`, `PropagationEngine`, and `SocialGraph` singletons. Wired into the ObjectiveHUD Tier 3 placeholder.

---

## Player Guidance Philosophy

Rumor Mill's strength is emergent discovery -- players should feel like they're figuring out the social graph, not following a walkthrough. But "discovery" requires scaffolding:

| Layer | Purpose | Example |
|-------|---------|---------|
| **Always visible** | What am I trying to do? | Objective HUD with numeric target |
| **On request** | What do I know? | Journal (intel, rumors, reputations) |
| **Contextual** | What should I try next? | Suggestion engine (when idle or stuck) |
| **Deep dive** | How does this system work? | How to Play screen, Social Graph overlay |

The goal is **progressive disclosure**: the game never dumps all its complexity at once, but the information is always available when the player is ready for it.

---

## NPC Archetype Quick Reference

Understanding NPC archetypes is the key strategic skill. Each archetype creates different gameplay:

| Archetype | Traits | Strategic Role | Examples |
|-----------|--------|---------------|----------|
| **Gatekeeper** | Low credulity, high loyalty | Blocks rumors about their allies; hard to seed through | Edric Fenn, Aldous Prior, Aldric Vane |
| **Conduit** | High sociability, high credulity | Fastest spreaders but highest mutation risk | Nell Picker, Greta Flint, Constance Widow |
| **Anchor** | High loyalty to specific NPC | Their rejection of a rumor collapses belief in their neighbourhood | Sister Maren, Bram Guard |
| **Vulnerable** | Low loyalty, high credulity | Easy to convince but unreliable (may flip when counter-rumors arrive) | Finn Monk, Cob Farrow, Old Hugh |
| **Firewall** | Low sociability | Rumors stall here; useful for containing spread you don't want | Rufus Bolt, Bess Wicker, Annit Scribe |

**Design note:** These archetypes are never explicitly labelled in-game. Players discover them through observation and experimentation. The Suggestion Engine (when implemented) can reference archetype behaviour indirectly: "Nell Picker talks to everyone -- rumors spread fast through her, but they also mutate more."

---

## Resource Economy

| Resource | Per Day | Total (S1, 30 days) | Design Intent |
|----------|---------|---------------------|---------------|
| Recon Actions | 3 | 90 | Enough to observe 2 buildings + 1 eavesdrop, or 3 eavesdrops. Forces choice between breadth (observe) and depth (eavesdrop). |
| Whisper Tokens | 2 | 60 | Enough to seed 2 rumors/day. Late-game players with good intel can chain 2 rumors effectively; early-game players should save tokens until they have intel. |
| Bribe Charges | 0-2/scenario | 0-2 | Scarce, powerful. One bribe can flip a gatekeeper or silence a conduit. Scenarios that include bribery are designed around "when do you spend your 2 charges?" |
| Evidence Slots | 3 max | 3 | Oldest evidence discarded when full. Creates urgency: use evidence or lose it. |

---

## Difficulty Curve Across Scenarios

```
S1 (Tutorial)     S2 (Precision)     S3 (Two-Front)     S4 (Defense)
   ___                ___                 ___                ___
  /   \              / | \               /   \              /   |
 /     \            /  |  \             / RvAg\            / Inq|
/ learn \          / Maren \           /  ↑↑↑  \          / ↑↑↑ |
  ramp    gentle   constraint  front   pressure  frantic  relentless
```

- **S1** ramps slowly: 7 days of pure recon, then three escalating act breaks
- **S2** is front-loaded: Maren threat is immediate, but IllnessAgent helps mid-game
- **S3** accelerates steadily: RivalAgent phases compress from 4-day to 1-day cooldowns
- **S4** is relentless: Inquisitor never stops, player is always reacting

---

## Appendix: Unbalanced Scenarios (Excluded from Rotation)

**Scenario 5 -- The Election** and **Scenario 6 -- The Merchant's Debt** exist in the data files but are flagged as unbalanced. They are excluded from the default scenario selection screen. These are candidates for Phase 2 expansion with proper balance tuning (see `docs/early-access-roadmap.md`).
