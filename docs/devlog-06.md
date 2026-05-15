# What You Told Us

*Rumor Mill | Steam Early Access | Evidence Economy in Practice + Phase 2.5 Preview*

---

## Platform Titles

- **itch.io:** `What You Told Us [Devlog #6 — Rumor Mill]`
- **Reddit (r/indiegaming):** `We built an evidence economy for our medieval gossip game. You found the arbitrage before we expected you to. Here is what that looks like. [Devlog #6]`
- **Reddit (r/gamedev):** `Evidence economies in practice — what player data from Days 5–9 revealed about design intent vs. actual behavior [Rumor Mill / Godot 4.6]`
- **Twitter/X thread opener:** `Devlog #6 is about what actually happened once players got into the evidence economy. The 4× efficiency gap. The Witness Account question. The town that doesn't react. And what Phase 2.5 is doing about it. 🧵 #indiedev #RumorMill`

---

## The Post

---

**What You Told Us**

*"Is burning a Witness Account ever actually worth it, or is it always a tax?"*

That question showed up in Discord, in Steam reviews, and in direct messages across Days 5–9. It is the clearest signal we got from the first phase of Early Access, and it is the question this devlog is organized around.

This is Devlog #6. Devlog #5 explained how the evidence economy was designed. This one is about what happened once players got into it.

---

### Section 1: What You Actually Did with the Evidence Economy

The efficiency gap on Master is wider than we expected. Between the top runs and the median run, we are seeing roughly a 4× difference in how much players accomplish per unit of evidence spent. That gap is not a random distribution — it has a shape, and the shape tells us something.

Top runs on Master share a pattern: players are choosing when *not* to act as often as they are choosing when to act. They hold evidence. They eavesdrop to surface the credulity state of high-value nodes before committing to a seed. They treat the Witness Account bypass not as a relief valve but as a timing instrument — burning it at the moment when bypassing a cooldown creates a propagation window that wouldn't otherwise exist.

Median runs look different. Evidence gets spent as it arrives. The Witness Account bypass gets used when cooldowns feel punishing, not when the social graph is in the right state to reward it. The result is lower fidelity propagation, more waste, and scenarios that stall before reaching critical faction thresholds.

We want to be direct about what this means: the 4× gap is partly a skill ceiling and partly a design problem. Experienced players found the leverage. New players are not finding the same levers, and the feedback we are getting suggests they do not know those levers exist. That is on us, not on the players.

The Witness Account specifically: usage across difficulty tiers tells us the mechanic reads as a punishment rather than a tactical option. The cooldown reduction patch (3→2 days on Master) shifted behavior at the high end, but the bypass itself remains underused relative to design intent everywhere below Spymaster. Players are not avoiding it because it is bad — they are avoiding it because the moment when it becomes valuable is not legible from within a run.

There is also a discoverability gap on Apprentice that we are naming plainly. Players on Apprentice often do not encounter the evidence economy in a meaningful way. They complete scenarios without engaging with the systems Devlog #5 described, because the scenarios are completable on social maneuvering alone at that difficulty. That is not a problem to patch away — it is a difficulty design question we are actively working through.

---

### Section 2: What We Learned, and What Phase 2 Changes

Phase 2 is not a content drop. It is a feedback-driven design pass on the systems that the first nine days of Early Access stress-tested.

The Witness Account economy is getting clearer signaling. The goal is not to make it easier — it is to make the moment of leverage visible within the run, so players at every difficulty can make the choice rather than missing it. The credulity curve on Normal is also being adjusted: the current version compresses the early game in a way that makes economy decisions feel arbitrary before players have a mental model of how the graph works.

We are not committing to a tutorial rewrite for Apprentice. What we are committing to is making the evidence layer present and readable at that difficulty, rather than dormant.

A fuller data appendix — evidence action counts, Witness Account burn rates by difficulty tier, efficiency distribution on Master — will accompany this post once the telemetry pipeline is complete. The qualitative read is accurate; the exact numbers will be added when they are ready.

---

### Section 3: The Town That Reacts

The other recurring question from Days 5–9 was this: *"Why doesn't the town seem to respond to what I'm doing?"*

Several players described it as watching a simulation run rather than playing inside one. Once a rumor is seeded, you are waiting. The graph updates, but the updates are not visible until the next analytics screen. If a rumor stalls, there is no signal that it has stalled — just an outcome at the end of the cycle.

This is the correct read of how the current version works. It is also the thing Phase 2.5 is directly built to address.

Three things coming in Phase 2.5:

**Live social graph updates during a run.** Edge weights will shift in real time as rumors propagate. You will see the graph change — nodes lighting as information reaches them, edges strengthening or degrading as transmission occurs — not just read a static snapshot at the analytics screen. The graph becomes a live instrument, not a report.

**Propagation feedback layer.** When a rumor stalls, you will know which nodes are holding and which are blocking. This is a deliberate information design choice: not to make the game easier, but to remove the inference gap that players currently describe as frustrating rather than strategic. A blocked rumor should be a puzzle, not a mystery. The distinction matters.

**Scenario event triggers.** At high-propagation thresholds, the town will respond visibly. Faction investigations open. NPCs mobilize. The scenario target's behavior changes. This is the answer to *"does the town know I'm here?"* — at sufficient propagation, yes, and you will see it.

Phase 2.5 is not a roadmap promise. It is an explanation of why the current version is a snapshot of a social network, and what a live version of that same network looks like. The mechanics exist. The interface to make them legible is what 2.5 is building.

---

### What We Want From You

One question before we close: which scenario produced your most surprising run, and where did it break down?

Not the most successful run. The one where something happened that you did not expect — a rumor that spread further than it should have, a faction that held against all probability, a bypass that paid off or failed in a way you did not predict. That is the signal that feeds the next design pass.

Steam Discussions, Discord, wherever you land — we are reading it.

More soon.

— SrgtKillerSpark

---

*[Steam page: [LINK]] [itch.io: [LINK]]*

---

## Platform Variants (Full Copy)

---

### itch.io Devlog Body

**What You Told Us [Devlog #6 — Rumor Mill]**

Days 5–9 of Early Access produced the clearest design signal we have gotten yet. This devlog is the full accounting.

The evidence economy: top runs on Master are running 4× more efficiently than median runs. The gap is not random — it has a shape. High-performers are holding evidence and reading credulity states before committing to seeds. Median players are spending evidence as it arrives. The Witness Account bypass is underused across all tiers below Spymaster: players read it as a cooldown tax, not a timing instrument. That is a legibility problem, and Phase 2 is fixing it.

The town that doesn't respond: players asked why the simulation doesn't feel alive. The answer is that it isn't, yet. Phase 2.5 is building the interface that makes it live — real-time graph updates, propagation feedback, scenario event triggers at high-propagation thresholds. The mechanics already exist. The feedback layer is what 2.5 is delivering.

Data appendix (exact usage counts, burn rates, efficiency distribution) coming once the telemetry pipeline is complete. Qualitative read above is accurate; exact numbers pending.

One question: which scenario produced your most surprising run? Not your best. The one where something happened you didn't expect. That is the signal that feeds the next pass.

— SrgtKillerSpark

---

### Reddit (r/indiegaming)

**We built an evidence economy for our medieval gossip game. You found the arbitrage before we expected you to. Here is what that looks like. [Devlog #6]**

Devlog #6 for Rumor Mill (social deduction strategy, Steam EA). This one is about what players actually did with the evidence economy once they got into it.

**tl;dr:**
- 4× efficiency gap on Master between top and median runs. Top players hold evidence and read credulity states. Median players spend as they arrive.
- Witness Account bypass is underused below Spymaster. Players read it as a cooldown tax, not a timing instrument. Phase 2 is fixing the legibility.
- Apprentice discoverability gap: scenarios are completable without engaging the evidence systems at that difficulty. Design question, not a patch.
- Phase 2.5: live social graph updates, propagation feedback layer, scenario event triggers. The town will respond.

The Witness Account question came up independently in Discord, Steam, and DMs. That is a signal we are taking seriously.

Full devlog with design detail + Phase 2.5 breakdown: [link]

---

### Reddit (r/gamedev)

**Evidence economies in practice — what player data from Days 5–9 revealed about design intent vs. actual behavior [Rumor Mill / Godot 4.6]**

Nine days into Steam Early Access for Rumor Mill (solo dev, Godot 4.6). Devlog #6 is the first design-signal post — what we actually observed vs. what we designed for.

**The useful thing I learned:** Top vs. median player behavior diverged faster and more cleanly than expected. By Day 9, the top-end Master runs were 4× more evidence-efficient than median runs, and the gap was structural. High performers were reading the social graph state before spending — they found the credulity-scouting loop without it being explicitly taught. Median players were spending on instinct. Same mechanic, completely different engagement pattern.

**What I did not predict:** The Witness Account bypass would read as a punishment at most difficulty levels. I designed it as a timing instrument. Players are treating it as a cooldown tax. The mechanic is not wrong — the moment of value is not legible from inside a run. Phase 2 is addressing the signaling, not the underlying mechanic.

**The design question I'm still working on:** Apprentice difficulty lets players complete scenarios without engaging the evidence economy at all. That is a difficulty tuning question, not a patch. I don't know the answer yet.

Full post: [link]

---

### Twitter/X Thread

Devlog #6 is about what actually happened once players got into the evidence economy. The 4× efficiency gap. The Witness Account question. The town that doesn't react. And what Phase 2.5 is doing about it. 🧵 #indiedev #RumorMill

1/ On Master, top runs are 4× more evidence-efficient than median runs. The gap is structural. High performers hold evidence and read credulity states before spending. Median players spend as it arrives. Same mechanic, completely different engagement.

2/ The Witness Account bypass: designed as a timing instrument. Players are reading it as a cooldown tax. The mechanic is not wrong — the moment of value is not legible from inside a run. Phase 2 is fixing the signaling.

3/ Apprentice gap: scenarios are completable at that difficulty without engaging the evidence economy. That is a design question, not a patch. We're working through it.

4/ Phase 2.5 — the town that reacts. Live graph updates during runs (not just at the analytics screen). Propagation feedback layer (when a rumor stalls, you'll know where). Scenario event triggers at high-propagation thresholds (faction investigations, NPC mobilization).

5/ One question for you: which scenario produced your most surprising run? Not your best. The one where something happened you didn't expect. That's the signal that feeds the next design pass. Steam Discussions, Discord, wherever you land. 🧵 end

---

## Publish Record

| Platform | Status | URL | Posted |
|----------|--------|-----|--------|
| itch.io devlog | **Pending** | — | — |
| Reddit r/indiegaming | **Pending** | — | — |
| Reddit r/gamedev | **Pending** | — | — |
| Twitter/X | **Pending** | — | — |

*Note: Data appendix (evidence action counts, Witness Account burn rates by difficulty tier, Master efficiency distribution) to be added when telemetry pipeline is complete. Phase 2.5 WIP screenshots not yet available — Section 3 is prose-only per outline dependency guidance.*

---

*Document version: 1.0 — 2026-05-14 (Marketing Lead: draft from inline thread content)*
*Task: [SPA-2413](/SPA/issues/SPA-2413)*
*Outline: docs/devlog-6-outline.md ([SPA-2360](/SPA/issues/SPA-2360))*
*Builds on: devlog-05 (evidence economy design + Phase 1 data)*
