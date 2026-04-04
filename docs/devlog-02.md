# Devlog #2 — How Gossip Works: The Propagation Engine

*Rumor Mill | Devlog #2 | April 2026*

---

## Platform Titles

- **itch.io:** `Devlog #2 — How Gossip Works: The Propagation Engine`
- **Reddit (r/indiegaming):** `I built a medieval gossip game where rumors mutate as they spread. Here's how the propagation system actually works. [Devlog #2]`
- **Reddit (r/gamedev):** `Implementing a SIR-based rumor propagation engine in Godot 4.6 — mutation types, faction modifiers, and escalation chains [Devlog #2]`
- **Twitter/X thread opener:** `How do you make gossip feel *real* in a game? You start with epidemic modeling. Thread on the Rumor Mill propagation engine — Devlog #2 🧵 #indiedev #godotengine #RumorMill`

---

## The Post

---

**How Gossip Works**

In the last devlog I described Rumor Mill as a game where you plant information and watch it travel. That was the high-level pitch. This time I want to go deeper — into how the propagation system actually works, why rumors mutate, and what makes the mechanics tick.

This is the systems post.

---

### The Epidemic Model

Rumors spread like disease. That's not a metaphor — it's the design principle behind the propagation engine.

Rumor Mill uses an adapted **SIR model** (Susceptible → Infected → Recovered), the same framework epidemiologists use to model contagion through populations. Every NPC is in one of three states relative to any given rumor: they haven't heard it (**Susceptible**), they believe it and may spread it (**Infected**), or they've rejected it (**Recovered**).

Each game tick, the engine runs two probability calculations for every NPC carrying a rumor:

**β (spread probability)** — the chance they pass it to each connected neighbor this tick:

> β = sociability × credulity × relationship_weight × faction_modifier

A highly sociable NPC with a strong relationship to a credulous neighbor will spread almost every tick. A reserved NPC spreading across faction lines to a skeptic may have only a 10–15% daily chance.

**γ (recovery probability)** — the chance they reject it and stop spreading:

> γ = loyalty × (1 − temperament) × 0.30

High loyalty combined with stable temperament makes an NPC harder to convince — but once convinced, they hold the belief longer before natural rejection. A converted merchant stays converted.

The faction modifier is where social politics enter the math: same-faction NPCs spread rumors 20% more readily (+1.2×), neutral-faction pairs at a penalty (0.8×), and opposing factions at half effectiveness (0.5×). Merchants and nobles are opposing factions. Clergy and nobles are opposing factions. Spreading a rumor across those lines is mechanically difficult — and strategically meaningful.

---

### Mutation

Here's where it gets interesting.

Every time an NPC spreads a rumor, the engine rolls for **mutation** — a chance the story changes in transit. Four mutation types can fire independently on any single transmission:

**Exaggeration** — the rumor's intensity increases by 1 (max 5). A petty accusation of dishonesty escalates to a corruption scandal. The story gets worse in the telling.

**Softening** — intensity decreases by 1. Mutually exclusive with exaggeration. The gossip loses nerve halfway through and waters it down. Your carefully built scandal becomes "I heard something about him, I'm not sure."

**Target shift** — the subject of the rumor reassigns to a *randomly connected NPC*. This one is punishing. You plant a scandal about the Alderman, and somewhere in the chain it becomes a scandal about his wife — or the miller who was near him, or the guard captain he argued with last week. You cannot control this. You cannot predict it.

**Detail addition** — no mechanical change, but logged in the lineage. The story acquires narrative texture. "He was seen leaving early" becomes "He was seen leaving early, and his coat was bloodstained." Flavor that makes the rumor *feel* more credible to downstream NPCs.

The probability of each mutation fires proportional to the rumor's **mutability** — a value you control when you seed it. High-mutability rumors spread aggressively but drift unpredictably. Low-mutability rumors are stable and focused but move slowly. That tradeoff is a core seeding decision.

---

### Escalation Chains

The most strategically interesting mechanic is the **chain system**.

When you seed a second rumor about the same NPC, the engine checks what's already active on that target and applies a chain modifier:

**Escalation** — some claim types prime others. An active **Scandal** rumor primes the target for **Heresy**. An active **Illness** rumor primes for **Death**. If you seed the escalating type while the priming type is still live, the new rumor gets +25% believability at creation and reduced mutability — it locks in and spreads with conviction rather than drifting.

This is the combo system. You run a quiet scandal campaign first, spending a few days seeding accusation whispers through merchant-faction NPCs. Then you seed the heresy accusation into a primed social network. What would have struggled to spread instead floods through with the confidence of a story people were already half-believing.

**Contradiction** — seed an opposite-valence rumor on a target that already has an active one (say, a positive praise claim about someone you're running a scandal on) and the new rumor starts at -10% believability. The town has already heard the bad version. A contradictory story reads as suspicious.

**Same-type stacking** — seed the same claim type that's already live and it gets +15% believability and +1 intensity. Redundant sourcing makes stories more credible. Two independent witnesses are more convincing than one.

The chain type is shown in the **Rumor Crafting Panel** before you commit to a seed. It's the closest the game comes to giving you information about your own plan's strategic state.

---

### Two Examples

**The Plague Scare (Scenario 2):** You need seven NPCs to reach BELIEVE state on an illness rumor about a rival merchant. But Maren the Chapel nun will publicly rebut any illness claim she hears about a person she trusts — and she has strong edges to half the town.

Basic strategy: seed with high-credulity NPCs in the merchant district, avoid the clergy quarter entirely. The rumor self-propagates through the trade network without ever crossing into Chapel territory. The faction modifier does most of the work — illness rumors spread 20% faster inside the same faction.

What goes wrong: target shift. A mutation redirects the illness rumor mid-chain to a different subject, sometimes directly into Maren's network. When that fires, Maren hears a false illness claim about someone she trusts, investigates, and publicly contradicts it. Your believability craters. The contradiction spreads faster than the original rumor. You've got a few days to reseed before the scenario tips.

**The Holy Inquisition (Scenario 4):** Three NPCs are under active investigation. Your job is to keep their reputations above 50 across 20 full days while the Inquisitor runs his own rumor campaign against them — seeding scandal claims that prime for heresy escalation.

The correct play is interception. Let the Inquisitor's scandal claims land, then immediately layer same-type positive claims on the same targets. Same-type stacking means your praise claims get +15% believability and +1 intensity — enough to slow the reputation bleed. If you wait until the scandals have been live for several days, the priming window for heresy opens and you're defending against a +25% believability escalation chain instead. Timing is the skill.

---

### Build Update

Since devlog #1, a few systems shipped worth noting:

**Save / Load** — three manual save slots plus auto-save. Full game state persists across sessions: active rumors, NPC belief states, reputation scores, and the inquisitor's investigation progress. You can walk away mid-scenario and return to an honest state.

**Difficulty presets** — Apprentice, Master, and Spymaster. They adjust mutation rates, NPC credulity floors, and AI opponent aggression. Spymaster mode operates near the parameter edge where a single mistimed seed can collapse a campaign you've been running for ten days.

**Spread Prediction Overlay** — before committing a seed, you can preview the probable propagation radius based on current network state. It is an estimate derived from current β values, not a guarantee. Mutations still fire randomly. Use it to discard obviously bad seeds, not to plan with confidence.

**Post-Scenario Analytics** — after each scenario resolves (win or loss), a summary screen maps your seeding decisions against the full rumor chain and mutation history. The first time you see where a target-shift fired mid-chain and redirected your campaign against someone you didn't intend — displayed as a clean tree diagram — is clarifying.

**Speed controls** — the simulation runs at 1×, 2×, or 4×. Useful late in a scenario once you have the picture and are waiting on propagation to finish. Early play benefits from slow observation.

**Enhanced eavesdrop intelligence** — the eavesdrop system now surfaces more specific information per observed NPC: current belief state on active rumors, relationship edge weights to neighbors, faction standing flags. You are no longer guessing about whether someone is an Anchor before you seed through them.

---

### Next

Devlog #3 covers the town simulation — thirty NPCs, five factions, daily schedules, and the intel-gathering system. Not how rumors spread, but *who* they're spreading through.

- **Wishlist on Steam** — the Coming Soon page is live. Every wishlist helps.
- **Follow on itch.io** — demo coming.
- **GitHub:** https://github.com/SrgtKillerSpark/Rumor-Mill

Questions about the propagation mechanics welcome in the comments.

— SrgtKillerSpark

---

*Rumor Mill is in active development. Built in Godot 4.6.*

---

## Posting Notes

### Reddit
- Post to **r/indiegaming** first (broader audience, the mutation/chaos angle plays well here).
- Stagger 30 min, then post to **r/gamedev** (technical audience — mention Godot, SIR model, GDScript implementation).
- Post on **Tuesday, 8–10am EST**.
- Lead comment: *"Happy to answer questions about the propagation math, the chain system, or why target-shift is the mechanic I regret and keep anyway."*

### Twitter/X Thread (5-tweet structure)

Tweet 1 (hook):
> How do you make gossip feel *real* in a game? You start with epidemic modeling. Thread on how Rumor Mill's propagation engine works — Devlog #2 🧵 #indiedev #godotengine #RumorMill

Tweet 2 (SIR model):
> Rumors in Rumor Mill spread like disease. Each NPC is Susceptible, Infected (spreading), or Recovered (rejected). Two probability formulas run every tick: β = how likely they pass it on, γ = how likely they stop believing it. Faction, personality, and relationship weight feed both.

Tweet 3 (mutation):
> Every transmission has a chance to *mutate* the rumor. Exaggeration, softening, detail addition — or target shift, where the subject of the story reassigns to someone completely different mid-chain. You can't fully control the message once it's out. That's intentional.

Tweet 4 (chains):
> The escalation chain system is the combo mechanic. Scandal primes for Heresy. Illness primes for Death. Seed the escalating type into an already-primed network and it spreads with +25% believability. First move wins if your timing is right.

Tweet 5 (CTA):
> Devlog #3 is the town simulation — 30 NPCs, 5 factions, daily schedules, intel gathering. Steam Coming Soon page is live. Wishlist if this sounds like your thing. #indiedev #RumorMill

---

*Document version: 1.0 — 2026-04-04*
*Task: [SPA-224](/SPA/issues/SPA-224) | Series plan: [SPA-178](/SPA/issues/SPA-178) | Devlog #1: [SPA-190](/SPA/issues/SPA-190)*
