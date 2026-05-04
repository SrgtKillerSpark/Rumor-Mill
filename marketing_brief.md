# SPA-895 — Marketing Prep: Game Description, Feature Highlights, Audience Brief

---

## 1. Game Description Copy

**Rumor Mill** is a medieval social strategy game where information is your only weapon. You play as a shadow operative — hired to shape the fate of a town through whisper, insinuation, and well-placed lies. Observe who speaks to whom, eavesdrop on conversations, craft rumors tailored to the social fault lines you've mapped, and seed them with the right voice at the right moment. The town will do the rest.

Beneath every conversation, every marketplace glance, and every chapel door is a living social graph — a web of trust, rivalry, and faction loyalty that routes your rumors in ways you cannot fully predict. NPCs evaluate what they hear, spread what they believe, and sometimes mutate your words into something far more damaging (or counterproductive) than you intended. High-loyalty allies will defend the powerful; a single skeptic in the wrong place can strangle a campaign before it spreads. Success demands reading the room: mapping relationships, managing your exposure, and knowing when to slow down before suspicion locks every door.

Each scenario drops you into a different political crisis with its own ticking clock and failure condition. Expose the corruption of a protected alderman. Drive a rival healer out of town before she steals your patron's clients. Orchestrate a noble succession against an AI adversary running its own counter-campaign. Play defense — using praise and corroboration to shield three accused townsfolk from an Inquisitor who escalates pressure every day until the very last hour. Swing a three-way election by building one candidate up while tearing rivals down, racing a Prior's endorsement deadline. Or uncover a merchant's embezzlement while keeping your informant's reputation intact against guards on the payroll. No two runs play out the same.

---

## 2. Feature Highlights

**Core Mechanics**
- **Living NPC social graph** — a weighted faction network where every relationship can be observed, exploited, or eroded through your campaigns
- **SIR diffusion model** — rumors spread through real epidemic-style propagation, mutating as they travel and decaying if belief collapses
- **Rumor crafting system** — choose your subject, claim type (accusation, scandal, heresy, illness, praise, prophecy), and evidence attachment across a three-panel interface
- **Evidence items** — gather Forged Documents, Incriminating Artifacts, and Witness Accounts in the field to boost rumor believability
- **Heat system** — per-NPC suspicion meter that closes off targets when you move too fast; decay over time forces tactical patience
- **Bribery** — spend limited charges to force NPCs past credulity checks when time is short
- **Counter-intelligence NPCs** — high-loyalty characters enter a DEFENDING state, broadcasting credulity penalties to every neighbor

**Scenario Design**
- **Six distinct scenarios** across a range of difficulty and play styles: offensive reputation destruction, crowd-belief racing, dual-track succession warfare, a purely defensive protection campaign, a three-way election race, and a merchant embezzlement exposure
- **AI rival agent (Scenario 3)** — a metric-driven opponent that adapts its seeding strategy to whichever of your goals is most vulnerable in the late game
- **Mid-game event system** — 28 branching narrative events across scenarios; the suggestion engine foreshadows each event 1–2 days in advance, and every choice (56 total) generates an aftermath bulletin in the daily planning overlay
- **Mission Briefing screen** — per-scenario briefing on load: win condition, strategy hint, first recommended action, and key danger; JSON-driven across all six scenarios
- **Difficulty modifiers** — easy/normal/hard per scenario, tuning time limits, NPC credulity, heat ceilings, and enemy loyalty

**Presentation**
- **Visual NPC state system** — color-coded sprite tints (yellow = evaluating, green = believes, orange = spreading, magenta = acting, sky-blue = defending) make the invisible visible without breaking immersion
- **Social Graph Overlay** — press G to toggle a live view of relationship edge weights and their mutation history
- **Lineage tree** — track how a single seeded rumor mutated and branched across the network
- **Day/night cycle with ambient audio** — distinct soundscapes per location (tavern, market, chapel, manor), time-of-day evidence windows, and atmospheric lighting shifts
- **Rumor ripple VFX and NPC thought bubbles** — real-time visual feedback as your campaign spreads

---

## 3. Screenshot Guide

Priority capture moments for press kit and store page, in rough priority order:

1. **The social graph in motion** — Press G mid-campaign with 8-10 NPCs in various belief states (green/orange/magenta) visually clustered and connected by tinted edges. Ideally captured in Scenario 1 mid-game when the merchant faction is fracturing.

2. **A rumor in flight** — Rumor ripple VFX + floating speech icon at the moment of transmission between a SPREAD NPC and a nearby target. Best captured in the Market at mid-day, high NPC density.

3. **The Defending cascade** — One or two sky-blue DEFENDING NPCs shielding Edric Fenn while orange SPREAD NPCs cluster nearby. Communicates the strategic tension of the counter-intelligence system.

4. **Rumor crafting panel open** — Panel 2 or 3 showing a SCANDAL or ACCUSATION claim with evidence attached and spread estimate displayed. Good for showing mechanical depth without being opaque.

5. **ACT state onset** — A magenta-pink NPC with pulsing lightning icon, physically moving away from the rumor subject. Dramatic and visually distinct.

6. **Scenario 3 dual-track split-screen** — Calder's reputation tracker climbing while Tomas's falls, with the rival agent's rumor trail visible on the overlay. Uniquely shows the asymmetric strategy layer.

7. **Night at the Noble Estate** — Incriminating Artifact acquisition window (post-6 PM) with the estate lit and an NPC silhouetted at the entrance. Strong atmospheric moment.

8. **Scenario 4 Inquisitor pressure** — S4 HUD showing two protected NPCs near the fail floor (reputation ~42-45) while the Inquisitor's latest HERESY rumor is mid-propagation. Communicates stakes.

9. **Scenario 5 Election — three-way split** — S5 HUD showing all three candidate reputations diverging: Aldric climbing, two rivals below 45. Prior Aldous endorsement timer visible. Shows the multi-track management and time pressure specific to this scenario.

10. **Scenario 6 blackmail activation** — S6 mid-campaign: Aldric Vane reputation mid-fall, Marta Coin's reputation bar highlighted near-threshold (≥62 zone). Guards' heat bars elevated from blackmail use. Shows the unique dual-constraint mechanic (damage one, protect the other, under tighter heat ceiling).

---

## 4. Target Audience Brief

### Primary Segment — Systems-First Strategy Players

**Profile:** PC strategy and tactics game players who enjoy games like _Crusader Kings_, _Cultist Simulator_, _Suzerain_, or _Slay the Spire_. Ages 22-40. Comfortable reading mechanical detail; attracted to games where mastery emerges from understanding underlying systems, not reflex.

**What resonates:** The SIR diffusion model, heat management, and counter-intelligence NPCs create the kind of systems-within-systems depth this segment seeks. The lack of direct combat forces lateral thinking. The rumor mutation mechanic provides emergent storytelling.

**Messaging angle:** "A political strategy game with real epidemic mechanics underneath." Emphasize the social graph overlay, lineage tree, and AI rival as evidence of simulation depth. Use the mechanics doc and scenario descriptions in PR/press kit.

**Where to reach:** Steam discovery queue (tags: strategy, simulation, social deduction), strategy game subreddits, BAFTA/IGF coverage, tactical strategy YouTube.

---

### Secondary Segment — Narrative Roleplayers and Medieval Setting Enthusiasts

**Profile:** Players attracted to immersive medieval or political fiction — _Disco Elysium_, _Pentiment_, _Pillars of Eternity_. Often play for story and atmosphere over pure optimization. Ages 18-35.

**What resonates:** The scenario writing (alderman corruption, plague panic, succession politics, holy inquisition) is period-authentic and dramatically grounded. The visual state system makes the story feel alive without dialogue-heavy exposition. Each scenario has its own narrative arc and loss conditions that feel consequential, not arbitrary.

**Messaging angle:** "Every rumor has consequences you didn't plan for." Lead with scenario hooks and the town-as-protagonist angle. Emphasize emergent storytelling from mutation and corroboration.

**Where to reach:** Narrative game blogs, Steam curator lists (strong writing), historical simulation communities, indie game coverage on YouTube.

---

### Tertiary Segment — Puzzle and Optimization Players

**Profile:** Players who engage games as optimization problems. Find satisfaction in identifying and executing optimal routing strategies. Attracted by the resource constraints (3 recon, 2 whispers, 2 bribes) and the tight time windows per scenario.

**Messaging angle:** "Map the social graph. Route the rumor. Beat the clock." Leaderboard potential and difficulty variants (hard mode) are hooks. The AI rival in Scenario 3 is particularly attractive to this segment.

**Where to reach:** Speedrun adjacent communities, puzzle game forums, strategy Discord servers.
