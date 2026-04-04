# We Shipped Rumor Mill. Here is What We Learned.

*Rumor Mill | Launch Devlog | April 2026*

---

## Platform Titles

- **itch.io:** `We Shipped Rumor Mill. Here is What We Learned. [Launch Devlog]`
- **Reddit (r/indiegaming):** `I launched my medieval gossip game on Steam Early Access. Here's what the first week actually taught me. [Launch Devlog]`
- **Reddit (r/gamedev):** `Solo dev post-launch retrospective — what I got wrong and what I didn't expect when Rumor Mill went live on Steam Early Access [Launch Devlog]`
- **Reddit (r/IndieDev):** `What I learned shipping a solo Godot game on Steam Early Access — an honest post-launch breakdown [Rumor Mill]`
- **Twitter/X thread opener:** `Rumor Mill is out on Steam Early Access. One week in. Here's what I actually learned. 🧵 #indiedev #solodev #RumorMill`

*This is a special launch post, outside the numbered devlog series. Devlog #3 — the town simulation deep dive — follows.*

---

## The Post

---

**We Shipped Rumor Mill. Here is What We Learned.**

Rumor Mill launched on Steam Early Access on [LAUNCH DATE].

Four scenarios. Thirty NPCs. A medieval social strategy game where your only tool is information — plant rumors, watch them mutate in transit, guide them toward your objective before time runs out.

This is not the next post in the devlog series. That one — the town simulation deep dive, 30 NPCs, faction dynamics, how daily schedules feed the propagation engine — is drafted and coming soon.

This post is about shipping, and what the first week looked like from the inside.

---

### The Final Sprint

The last two weeks before launch were not a polish pass. They were a stability pass — the difference between "this works" and "this is ready."

The full list of late-stage fixes included things I should have caught earlier: a reputation cache rebuild bug that could corrupt mid-scenario state if a faction event was active at save time; a deadline warning system that was losing float precision on the JSON round-trip, causing warnings to fire twice after load; missing keyboard navigation on most UI screens; tooltips that either didn't exist or surfaced information in the wrong order.

None of these are catastrophic. All of them are the kind of thing a player encounters in the first session and uses to form a judgment about the whole game.

The lesson, written out plainly: "working" and "ready" are different standards, and I was treating them as synonymous too late into the cycle.

---

### What Players Found That I Didn't Expect

**The eavesdrop system is a tutorial I didn't know I had.**

I built the eavesdrop mechanic as an information-gathering tool — a way to surface NPC belief states, relationship edge weights, and faction standing before you commit to seeding a rumor. Useful for planning. Mechanically correct.

What I did not anticipate: players describe it as the moment the game becomes clear. Multiple Steam and itch reviews specifically cite the eavesdrop phase as the thing that made them understand how the system works. It is functioning as an embedded tutorial without a single tooltip instructing anyone to use it that way.

I underbuilt it. It deserves more.

**Target-shift generates the most complaints and the highest replay rates.**

Target-shift — the mutation type that reassigns the subject of a rumor to a randomly connected NPC mid-chain — is the most hated mechanic in the game. Comments about it on launch day ranged from "unfair" to "broken." One person called it a design flaw.

The replay data shows that Spymaster difficulty, where target-shift is most frequent and most costly, has the highest per-player session count of any difficulty preset so far.

I designed it to be ungovernable by intent. Players who encounter it once immediately start thinking about how to constrain it — not avoid it. That's the correct response. I expected the frustration. I did not expect the engagement.

---

### What I Underestimated

Three things, in rough order of how much they affected the launch:

**1. The analytics screen is the game's strongest replayability argument.**

The post-scenario analytics — the spread timeline, mutation log, faction exposure table — were built as a post-mortem tool. A way to see what happened and why.

Players treat them as a design document for the next attempt. Several reviews describe the analytics screen specifically as a reason to replay. I should have positioned it more prominently in pre-launch material. It didn't appear in the Steam short description. It should.

**2. Early Access framing moves fast.**

The first 24 hours of reviews set a tone that subsequent reviews echoed. Getting the Steam short description, the launch Reddit post, and the first community discussion right matters disproportionately. I spent less time on those than I spent on the launch-week social calendar.

One thing I would do differently: write the launch Reddit post before the launch week starts, not the night before. It's not a creative problem — it's a clarity problem. You want to state exactly what the game is to the audience that has never heard of it. That takes more passes than one night allows.

**3. Bugs before the first scenario end are not equivalent to bugs after.**

A crash in Scenario 3 on Spymaster difficulty affects a small percentage of sessions. A confusing UI behavior on the scenario select screen affects everyone. I knew this principle abstractly. I did not triage accordingly. My bug priority list during the final sprint was ordered by severity of impact, not frequency of encounter.

The first patch addresses both — but the order in which I fixed things during the sprint was wrong.

---

### What Comes Next

Immediate: a stability patch addressing the launch-week reported issues — the save/load edge cases that have come up in Steam discussions, and a keyboard navigation fix for the scenario select screen.

After that: Devlog #3 on the town simulation — thirty characters, five factions, how the daily schedule system creates the conditions for the propagation engine, and what the social network looks like when no one is actively targeting anyone.

The Early Access roadmap will go up in Steam discussions before that.

Thank you to everyone who played, reported bugs, asked about the SIR model, or complained about target-shift in enough detail that I could understand exactly what you were seeing.

Especially the ones who complained about target-shift in detail.

— SrgtKillerSpark

---

*[Steam page: [LINK]] [itch.io: [LINK]]*

---

*Document version: 1.0 — 2026-04-04*
*Task: [SPA-278](/SPA/issues/SPA-278)*
*Builds on: devlog-01.md, devlog-02.md, launch-announcements.md, devlog-series-plan.md*
