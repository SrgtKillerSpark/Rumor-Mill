# Phase 1 Results: What the Data Said

*Rumor Mill | Devlog #5 | May 2026*

---

## Platform Titles

- **itch.io:** `Phase 1 Results: What the Data Said [Devlog #5]`
- **Reddit (r/indiegaming):** `Rumor Mill Phase 1 — what we changed, why, and what the telemetry actually showed [Devlog #5]`
- **Reddit (r/gamedev):** `Solo dev Phase 1 post-mortem — data-gated balance patches, what worked, what surprised me [Devlog #5]`
- **Twitter/X thread opener:** `Phase 1 is done. Here's what the numbers showed, what we changed, and why we didn't change the thing everyone expected. 🧵 #indiedev #RumorMill`

---

## The Post

---

**Phase 1 Results: What the Data Said**

Phase 1 is done. Here's the full accounting.

In Devlog #4 I described Phase 1 as a precision pass — not a feature wave, not a response to every complaint, but a structured process for confirming or contradicting specific hypotheses with real data. Either direction was a valid outcome. The point was to let telemetry answer the question, not speculation.

The data is in. Here's what it said.

---

### The Premise of Phase 1: Data-Gated Decisions

Before Early Access launched, we identified two balance candidates with enough pre-release signal to be worth watching closely: Sister Maren's counter-intelligence calibration in Scenario 2, and Finn Monk's vulnerability in Scenario 4. Both had clear failure modes flagged in internal testing. Both had specific, measurable thresholds: if a single character was responsible for more than 60% of scenario losses, the mechanic had drifted from "puzzle" into "coin flip" territory.

The review cadence ran Monday, Wednesday, Friday — three checkpoints per week. No adjustment was made on a single data point. The protocol required the threshold to hold for two or more consecutive review cycles before any action was taken. That two-cycle rule exists to filter out early-session variance and noise from players who hadn't yet learned the systems.

Three full review cycles ran on the first week of data before either threshold was formally evaluated against minimum sample sizes. What the data returned on both candidates was not ambiguous.

---

### Scenario 2: Sister Maren

This was the most-reported balance complaint in the community log — six independent reports across Steam and itch.io, all describing the same experience. Players who understood the rumor system, who were making deliberate seeding decisions, who were doing everything right, still hit Maren and lost. The phrase "feels like a coin flip" appeared in multiple posts independently.

The community was right.

When the telemetry crossed its minimum sample threshold for S2 failures, the Maren-fail ratio came back at **100%**. Not 61%. Not 73%. Every tracked S2 failure in the data window included a Maren counter-intelligence rejection event. The timeout-fail cases — players who simply ran out of time without triggering Maren — were statistically absent from the loss data.

This is what "the threshold hasn't been hit yet" would look like in the other direction. In our direction, it meant the patch was not discretionary.

The adjustment: Maren's edge weights to Alys have been reduced from **0.35/0.30 to 0.25/0.20** in `scenarios.json`. This lowers the probability that accidental propagation chains route through Maren's network — but it doesn't remove her. Players who seed recklessly near her orbit will still trigger her. The threat is preserved; the "unlucky first move loses the scenario" edge case is reduced.

One thing I want to say directly: the community reports came before the telemetry confirmed them. The feedback arrived first and the data validated it, not the other way around. I don't think that's a coincidence — itch.io players in particular are describing systems-level behavior accurately because they're engaging with the game at a systems level. That's the feedback loop working as intended.

---

### Scenario 4: Finn Monk

The Finn scenario had a different texture. The community signal was quieter — internal testing caught the Finn-triage problem before launch, and the public reports about S4 tended to describe the feeling rather than the specific cause. Players said the scenario felt like "keeping one person alive." They were right about the experience without necessarily knowing why.

The data was equally unambiguous. Finn Monk's fail share in S4 came back at **87.5%**. More than four out of every five S4 losses in the telemetry ran through Finn — his low starting loyalty (0.45) making him dramatically more vulnerable to the Inquisitor's cycling pressure than Aldous Prior or Vera Midwife. The scenario's intended identity — a three-front defensive operation — was collapsing into single-NPC triage for most players.

The proposed fix targets exactly that: a loyalty floor raise from **0.45 to 0.55** for Finn's starting personality override in `npcs.json`. This improves his gamma recovery rate — how quickly he stabilizes after Inquisitor attention — without touching his credulity. Finn should still *believe* rumors easily; the tension in S4 is whether he *recovers* when pressure focuses on him. An alternative proposal, raising his starting reputation from 68 to 72, provides a 4-point buffer without changing his mechanical behavior at all.

This patch is currently in final review. The S4 balance change will ship in a follow-on update once confirmed.

---

### The Things We Didn't Change (and Why)

This section matters as much as the ones above. Players notice when complaints are ignored. Naming what we chose *not* to change is as important as naming what we did.

**Evidence item economy.** The Forged Document, Incriminating Artifact, and Witness Account are not changing in Phase 1. The balance proposal made this explicit before launch: this is a strategic depth concern, not a player frustration issue. Players are not losing scenarios because of evidence imbalance — the items work. What we don't have yet is usage telemetry. We can't see how often each item is being selected, in which scenarios, at what difficulty tier. Adjusting evidence weights without that data risks nerfing something players rely on. We're building the measurement first. Evidence economy is Phase 2 work.

**Target-shift.** The propagation mechanic that lets rumors redirect toward unintended targets remains unchanged. This was not on the Phase 1 balance list and it isn't going on the Phase 2 list either. Target-shift is not a broken mechanic — it's working as designed. The problem is that new players encounter it mid-campaign without any prior frame for it, and it reads as a malfunction. The fix here is comprehension, not code. A "How Propagation Works" explainer for Steam Discussions is in progress. Players who understand the mechanic before encountering it respond to it completely differently — the same behavior reads as the game's signature feature rather than a bug.

**Audio.** This one isn't a balance call, it's its own track. Fourteen independent reports — the single most-mentioned gap in Early Access feedback. Players have been patient. The audio scope and timeline are addressed separately below.

---

### Audio Status

Fourteen reports is a consistent signal, and the absence of audio has been the most patient complaint in the feedback log. Players mention it in the same review as genuine praise for the social graph. They understand the Early Access context. That patience deserves a direct update.

Audio work is in progress. The current scope covers ambient soundscape, scenario mood tracks, and UI feedback sounds. A specific timeline will be posted as a Steam update when the Lead Engineer has a confirmed delivery window — I'm not going to publish a date that hasn't been validated. What I can say is that it's the top non-balance deliverable and it will ship as a standalone update, not bundled into a balance patch.

*[Note: This section requires a specific scope and ETA confirmation from Lead Engineer before final publish. Placeholder language above is directional only.]*

---

### What's Next (Phase 2 Directional)

Phase 1 was the precision pass. Phase 2 is the expansion pass.

The evidence item economy is the next balance frontier. Forged Document, Incriminating Artifact, Witness Account — players have been asking whether these items are truly differentiated or whether two of them do the same thing. The honest answer is: we think they're differentiated, but we haven't been measuring usage patterns. Phase 2 adds the telemetry to answer that question properly before we touch any values. Players who asked about this by name: we heard you, we're not ready to act yet, but it's actively tracked.

New scenarios are the content horizon after Phase 2 balance work is complete. I don't have a scenario count or a release window to share. The focus right now is getting the evidence-economy measurement right so that whatever comes next launches on a verified foundation.

Mac and Linux remain on the roadmap. No window yet. I won't commit to a date I haven't validated.

---

### The Community's Role

At the end of Devlog #4, I asked you to keep filing feedback. You did.

The Maren result — 100% fail rate — would have been unactionable without the community reports that flagged the pattern before the telemetry had enough volume to evaluate it. The detailed five-paragraph posts about what players were trying to do, what the scenario felt like, why the loss read as unfair — those posts gave us the hypothesis to test. The telemetry confirmed it. That sequence matters: the feedback arrived first, the data validated it.

The same loop applies to Phase 2. If you have a position on the evidence items — if Forged Document and Incriminating Artifact feel interchangeable to you, or if one of them feels underpowered — that's the kind of specific signal that will inform the design before we set thresholds. File it in Steam Discussions, drop it on itch.io, or find me on Reddit. If you already did, it's already in the log.

— SrgtKillerSpark

---

*[Steam page: [STEAM_PAGE_URL]] [itch.io: https://rumor-mill.itch.io/rumor-mill]*

---

## Platform Variants (Full Copy)

---

### itch.io Devlog Body

**Phase 1 Results: What the Data Said [Devlog #5]**

Phase 1 is done. Here's what the telemetry showed.

The two balance candidates flagged before launch — Sister Maren's counter-intelligence (S2) and Finn Monk's vulnerability (S4) — both hit their thresholds. Clearly.

**Scenario 2 — Maren:** The Maren-fail ratio came back at 100%. Every tracked S2 failure in the data window included a Maren rejection event. The community reports about "feels like a coin flip" were accurate. The patch reduces her edge weights from 0.35/0.30 to 0.25/0.20 — lower accidental propagation, preserved threat for reckless seeding. Already shipped.

**Scenario 4 — Finn:** Finn's fail share was 87.5%. The "three-front defense collapsing into single-NPC triage" feeling players reported is real in the data. The patch raises his loyalty floor from 0.45 to 0.55, improving recovery rate without changing his credulity. In final review now.

**What we didn't change:** Evidence item economy (no usage data yet — Phase 2 work), target-shift (comprehension fix, not a patch), audio (its own timeline, update coming separately).

**Phase 2 teaser:** Evidence-economy telemetry is the next milestone. Forged Document vs. Incriminating Artifact vs. Witness Account — we're building the measurement before we touch the values.

Keep filing feedback. The Phase 1 result came from community reports arriving before the data had volume to confirm them. The same loop applies to Phase 2.

— SrgtKillerSpark

---

### Reddit (r/indiegaming)

**Rumor Mill Phase 1 — what we changed, why, and what the telemetry actually showed [Devlog #5]**

Devlog #5 is up. Phase 1 post-mortem — the specific numbers, what shipped, and what didn't.

**tl;dr:**

- Sister Maren (S2): fail ratio came back at 100%. Patch shipped — edge weights reduced, accidental chains less likely, threat preserved for reckless play.
- Finn Monk (S4): fail share at 87.5%. Loyalty floor buff in final review.
- Evidence items: not touched. No usage telemetry yet. Phase 2 work.
- Target-shift: not a patch, it's a comprehension fix. Explainer in progress.
- Audio: in progress, update coming separately.

The interesting thing about the Maren result is that community reports arrived *before* the telemetry had enough volume to evaluate the hypothesis. Players described the failure mode accurately before the data confirmed it. That's not a surprise if you've been paying attention to the itch.io audience — those players are describing systems-level behavior because they're engaging with the game at a systems level.

Full devlog with all the numbers and Phase 2 directional tease: [devlog link]

---

### Reddit (r/gamedev)

**Solo dev Phase 1 post-mortem — data-gated balance patches, what worked, what surprised me [Devlog #5]**

Sharing the Phase 1 post-mortem for Rumor Mill (my indie strategy game in Steam Early Access since April 25).

The premise of Phase 1 was explicit: no balance adjustment without telemetry confirmation. Two candidates going in, both with >60% fail-attribution thresholds. Here's what happened.

**What worked about the process:** Setting specific thresholds before launch removed a lot of the pressure to react to individual reports. When a community complaint came in, the question wasn't "should we fix this?" — it was "does the data confirm this?" For Maren, it did (100% fail rate). For Finn, it did (87.5%). The decision was already made in advance; the telemetry just pulled the trigger.

**What surprised me:** The community reports arrived before the telemetry had enough volume to evaluate. The feedback-to-data sequence was: community reports → hypothesis → telemetry confirmation, not the other way around. I expected more divergence between what players said and what the data showed. There was none.

**What the two-cycle rule is for:** The watchlist requires a threshold to hold for 2+ consecutive Monday/Wednesday/Friday review cycles before actioning. This filtered out noise in week 1 when sample sizes were small. Worth the friction — single-cycle spikes don't warrant a patch.

Full post with numbers and Phase 2 directional: [devlog link]

---

### Twitter/X Thread Opener

Phase 1 is done. Here's what the numbers showed, what we changed, and why we didn't change the thing everyone expected. 🧵 #indiedev #RumorMill

1/ Phase 1 was data-gated from the start. Two balance candidates, two thresholds (>60% fail attribution), three review cycles per week. No patch until the data said so.

2/ Scenario 2 — Sister Maren. The community said "feels like a coin flip." The telemetry said Maren was responsible for 100% of tracked S2 losses. Community was right. Patch shipped: edge weights reduced from 0.35/0.30 → 0.25/0.20.

3/ Scenario 4 — Finn Monk. Fail share: 87.5%. Four out of five S4 losses ran through Finn's low loyalty stat. Loyalty floor buff (0.45 → 0.55) in final review. The "single-NPC triage" feeling was real in the data.

4/ What we didn't change: evidence item economy (no usage telemetry yet), target-shift (comprehension fix not a patch), audio (its own timeline). Phase 1 was always narrow on purpose.

5/ Phase 2 teaser: evidence economy is next. Building the measurement before touching the values. More scenarios after that. No windows yet.

6/ Keep filing feedback. Community reports arrived before the data had volume to confirm Maren. That sequence — hypothesis first, data second — is the feedback loop working. Same applies to Phase 2. 🧵 end

---

## Publish Record

| Platform | Status | URL | Posted |
|----------|--------|-----|--------|
| itch.io devlog | **Pending** | — | — |
| Reddit r/indiegaming | **Pending** | — | — |
| Reddit r/gamedev | **Pending** | — | — |
| Twitter/X | **Pending** | — | — |

*Note: Audio section (§ "Audio Status") requires Lead Engineer fill on scope + ETA before final publish. All other sections are publishable as-is pending CEO/board review.*

---

*Document version: 1.0 — 2026-05-04 (Marketing Lead: initial draft)*
*Task: [SPA-1628](/SPA/issues/SPA-1628)*
*Sources: `docs/devlog-05-outline.md`, `docs/phase1-balance-proposal.md`, `docs/phase1-balance-watchlist.md`, `docs/devlog-04.md`, SPA-1579 (Maren patch), SPA-1578 (Finn buff)*
