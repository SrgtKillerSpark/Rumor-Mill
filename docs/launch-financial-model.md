# Launch Financial Model — Rumor Mill Early Access

**Prepared by:** CFO  
**Date:** 2026-04-04 (updated 2026-04-04, v3.0)  
**For:** Rumor Mill — board / founding team  
**Status:** Actionable — review before setting final EA launch date

> **References:** `docs/business-setup-guide.md` (LLC and Steam setup), `docs/pre-launch-legal-financial-checklist.md` (legal/tax blockers), `docs/demo-readiness-review.md` (build status), `docs/steam-store-page-final.md` (pricing baseline)

---

## 1. Executive Summary

Rumor Mill is **launch-ready from a content standpoint** (four scenarios, demo-ready per the Sprint 7 review). The financial picture is straightforward: this is a zero-marketing-spend, sweat-equity indie title with very low cash exposure. Break-even is achievable with approximately 40 Steam sales. The highest-probability outcome is modest but profitable: 400–800 units in the first 90 days at $14.99, generating $4,200–$8,400 net after Steam's cut — a strong return on a sub-$500 cash investment.

**Recommended launch sequence:** Free itch.io demo → Steam Early Access at **$14.99 USD** within 2–4 weeks.

---

## 2. Cost Projections

### 2A — What Has Been Spent (Estimated)

All development cost is **sweat equity** (solo developer). Zero cash outlay on labor.

| Item | Status | Cost |
|------|--------|------|
| Development labor | Sweat equity | $0 cash |
| Godot 4.6 engine | MIT license, free | $0 |
| Claude Code (AI-assisted dev) | Usage-based, absorbed | ~$0–50 (estimated) |
| Audio assets (current build) | Silent placeholders — not yet purchased | $0 |
| Art / UI assets | In-house | $0 |
| **Subtotal spent** | | **~$0–50** |

### 2B — What Remains Before Launch

| Item | Required For | Estimated Cost | Notes |
|------|-------------|----------------|-------|
| Steam Direct fee | Steam EA | **$100** | Recoupable at $1,000 gross. One-time per game. |
| EIN (IRS.gov) | Both platforms | **$0** | Free, ~5 min online |
| LLC formation (home state, mid-range) | Recommended | **$100–200** | One-time filing fee |
| Registered agent service | Optional | **$0–150/yr** | Keeps personal address off public filings |
| Business bank account (Mercury) | Steam payout | **$0** | No monthly fees |
| Privacy policy hosting | Steam (required) | **$0** | GitHub Pages or Notion public page |
| Audio assets (royalty-free) | Both platforms | **$0–200** | CC0/CC-BY sources (Freesound, OpenGameArt) |
| THIRD_PARTY_LICENSES.txt | Both platforms | **$0** | CFO + dev work only |
| **Total remaining (mid-range)** | | **~$200–650** | |
| **Total remaining (lean)** | | **~$100–300** | If registered agent skipped, free audio only |

### 2C — Ongoing Annual Costs Post-Launch

| Item | Annual Cost |
|------|------------|
| LLC annual filing / franchise tax (home state, mid) | $60–200 |
| Registered agent (if used) | $50–150 |
| Business bank account (Mercury) | $0 |
| **Total annual overhead** | **$60–350/yr** |

At the moderate revenue scenario (~$7,800 net in year one), annual overhead is less than 5% of revenue — negligible.

---

## 3. Pricing Recommendation: Early Access

### 3A — Comparable Titles

**Simulation / social-deduction / narrative-strategy comps:**

| Game | Genre / Tone | Steam Price | itch.io | Notes |
|------|-------------|-------------|---------|-------|
| **Dwarf Fortress** (Steam) | Simulation / systems depth | $29.99 | Free (classic) | Premium tier enabled by decades of free reputation; not a realistic comp for EA pricing but sets genre ceiling |
| **RimWorld** | Colony sim / emergent narrative | $34.99 | N/A | High price justified by replayability and scope; 10+ years of development; sets the top of the sim genre bracket |
| **Pentiment** | Narrative / mystery, indie | $19.99 | N/A | Obsidian single-purchase narrative game; closest to Rumor Mill's tone and length; strong comp for 1.0 pricing target |
| Cultist Simulator | Systems-first occult simulation | $19.99 | $14.99 | Closest tonal comp; sold well across both platforms |
| Wildermyth | Strategy/narrative, indie | $24.99 EA | $20 | More content-heavy but similar niche |
| Slay the Spire | Roguelike strategy, EA | $15.99 | N/A | Defined the $15 EA sweet spot |
| Into the Breach | Turn-based tactics, small team | $14.99 | N/A | Premium solo-dev pricing benchmark |
| Shadows of Doubt | Social deduction/simulation | $19.99 | N/A | Closest mechanical comp; useful ceiling reference |

**Key takeaways from comparables:**

- Dwarf Fortress and RimWorld command premium pricing ($30–35) because of enormous scope and long track records. Rumor Mill is not in that category at EA.
- Pentiment ($19.99) is the best 1.0 ceiling reference: acclaimed narrative game, fixed-length play, Obsidian pedigree. Rumor Mill can realistically aim for this tier at 1.0 after post-EA polish and reviews.
- Cultist Simulator's itch.io pricing ($14.99) is a strong validation that the $14.99 Steam EA price also holds on itch.io if a paid itch tier is introduced post-demo.
- The $14.99 EA entry point correctly positions Rumor Mill as a premium indie title without triggering buyer hesitation about content completeness.

**Positioning verdict:** Rumor Mill is a niche strategy/simulation title with a strong concept and four playable scenarios but limited audio polish at launch. It sits below Cultist Simulator in scope at EA stage, but above simple puzzle games. The $14.99 price point is correct: it signals premium indie quality without the risk of overpricing a content-incomplete release.

### 3B — Recommended Pricing

| Platform | Price | Rationale |
|----------|-------|-----------|
| **Steam Early Access** | **$14.99 USD** | Aligns with the indie strategy EA tier; matches Steamworks regional pricing baseline already documented |
| **itch.io demo** | **Free** | Maximizes plays, wishlist conversions, and devlog audience ahead of Steam EA. No paid tier on itch.io until post-1.0 |

### 3C — Regional Pricing (Steam)

Apply Steam's Regional Pricing Templates as the baseline, then verify against the table in `docs/business-setup-guide.md §5C`. No manual overrides needed at EA stage — the template calibrations are appropriate for this price tier.

**Full 1.0 pricing target:** $17.99–$19.99 USD (increase coincides with audio integration, content updates, and critical mass of reviews).

---

## 4. Revenue Projections — First 90 Days (Steam EA)

### 4A — Assumptions

- **Platform:** Steam Early Access only (itch.io is free demo; no paid revenue included)
- **Base price:** $14.99
- **Developer net per unit:** $14.99 × 0.70 (Steam cut) = **$10.49**
- **Refund adjustment:** ~8% refund rate typical for early-access indie = effective net ~**$9.65 per unit**
- **Marketing budget:** $0 (organic: devlogs, Reddit, itch.io audience, wishlist conversion)
- **Wishlist conversion rate:** 10–15% of wishlists convert to sales in first two weeks (Steam baseline for non-promoted titles)
- **No paid advertising, no influencer budget**

### 4B — Three Scenarios

| Scenario | Units Sold (90 days) | Gross Revenue | Steam Cut (30%) | Net Developer Revenue |
|----------|---------------------|---------------|-----------------|----------------------|
| **Conservative** | 200 | $2,998 | $899 | **$2,098** |
| **Moderate** | 600 | $8,994 | $2,698 | **$6,296** |
| **Optimistic** | 1,500 | $22,485 | $6,746 | **$15,740** |

**Notes:**
- *Conservative* (200 units): assumes minimal social traction, itch.io demo converts ~100 wishlisters, and organic Reddit/devlog reach is modest. Realistic floor for a zero-marketing launch.
- *Moderate* (600 units): 1–2 Reddit posts gain meaningful traction (>500 upvotes), itch.io demo generates 1,000+ plays and 300–400 wishlist conversions. Normal execution of the devlog plan.
- *Optimistic* (1,500 units): one viral Reddit post, itch.io front-page visibility, or a small curator/streamer pickup. Not planned for but not impossible.

### 4C — Monthly Pacing (Moderate Scenario)

Steam EA sales typically follow a steep launch curve then taper:

| Period | Units | Cumulative Net |
|--------|-------|---------------|
| Launch week (days 1–7) | ~200 | ~$2,099 |
| Weeks 2–4 | ~150 | ~$3,672 |
| Month 2 | ~150 | ~$5,244 |
| Month 3 | ~100 | ~$6,296 |

Valve pays monthly with a 30-day lag. **First payout expected ~60 days after launch** (end of first revenue month + Valve's 30-day cycle). Minimum payout threshold: $100.

### 4D — First-Year Revenue Projections (Steam EA, Full Year)

Year-1 projections extend the 90-day model through month 12 using Steam's typical long-tail decay curve. Assumptions: no major content updates in months 4–12 (baseline); one seasonal/Summer sale in month 7 (+10–15% unit lift); EA price held at $14.99 throughout.

| Scenario | Months 1–3 | Months 4–6 | Months 7–9 | Months 10–12 | **Year 1 Net** |
|----------|-----------|-----------|-----------|-------------|----------------|
| **Conservative** | $2,098 | $770 | $580 | $450 | **~$3,900** |
| **Moderate** | $6,296 | $2,310 | $1,740 | $1,350 | **~$11,700** |
| **Optimistic** | $15,740 | $5,780 | $4,350 | $3,370 | **~$29,200** |

**Notes:**
- Post-launch decay is modeled at ~30% per quarter after the initial 90-day window — consistent with no-marketing EA titles.
- Each major content update (new scenario, audio integration) can spike revenue 15–25% above the baseline curve for 2–4 weeks.
- A Steam sale participation (Summer/Autumn) typically generates 2–4× the normal weekly rate for the sale window.
- **Full-year moderate scenario (~$11,700 net) represents a 9–11× return on cash investment.** Even the conservative year-1 outcome ($3,900) comfortably covers all operating costs.

---

## 5. Break-Even Analysis

### 5A — Cash Break-Even (Steam EA)

| Cost Scenario | Total Launch Cash Cost | Units to Break Even | At $14.99 / $10.49 net |
|--------------|----------------------|--------------------|-----------------------|
| Lean (no LLC, free audio) | ~$100 | **~10 units** | Month 1 |
| Mid (LLC + Steam fee, free audio) | ~$300 | **~29 units** | Month 1 |
| Full (LLC + Steam + registered agent + audio budget) | ~$650 | **~62 units** | Month 1 |

**All scenarios break even within the first month of launch**, assuming conservative sales projections. This is a low-risk financial profile.

### 5B — Steam Direct Recoupment

The $100 Steam Direct fee is credited back once the game earns **$1,000 in adjusted gross revenue** (after refunds, before Valve's 30% cut).

$1,000 gross ÷ $14.99 per unit ≈ **~67 units**

At conservative projections (200 units in 90 days), the Steam fee is fully recouped in approximately **4–5 weeks** after launch.

### 5C — Annual Operating Break-Even

To cover ongoing LLC + registered agent overhead (~$200/yr):

$200 ÷ $10.49 net per unit ≈ **~20 units/year**

Ongoing overhead is negligible against any reasonable sales volume. The business is cash-flow positive from the first month with minimal sales.

---

## 6. Launch Sequence Recommendation: itch.io First or Steam EA Directly?

**Recommendation: itch.io free demo first, then Steam EA within 2–4 weeks.**

### Rationale

| Factor | itch.io Demo First | Steam EA Directly |
|--------|-------------------|-------------------|
| Wishlist building | **Yes** — itch.io audience follows to Steam | Wishlists only from Steam itself |
| Risk | **Lower** — test player reception before paid launch | Higher — no audience signal before committing |
| Revenue timing | Slight delay (~2–4 weeks) | Immediate but smaller audience |
| Devlog/community seeding | **Yes** — itch.io devlogs are permanent, SEO-indexed | Less community traction before launch |
| Data before pricing lock | **Yes** — can validate engagement before $14.99 commitment | No pre-launch signal |
| Conversion rate signal | Play count + wishlist rate informs Steam launch timing | None |

**The free itch.io demo is a low-cost audience development tool.** Devlog #1 and #2 are ready. The itch.io page is drafted (`docs/itchio-game-page.md`). Running the demo for 2–4 weeks before Steam EA launch gives the game devlog momentum, player feedback, and a warm wishlist audience to convert on day one of Steam EA.

**If the Steam 30-day review window has not yet started:** begin that process now in parallel with the itch.io demo period. The two timelines can overlap perfectly.

---

## 7. Outstanding Legal / Tax Items from Pre-Launch Checklist

Items from `docs/pre-launch-legal-financial-checklist.md` that are **unresolved and required before revenue**:

### Blocking for Steam EA Launch

| Item | Status | Action Required |
|------|--------|----------------|
| W-9 submitted and accepted by Valve | ⬜ Unknown | Submit via Steamworks → Account → Tax Information. Use LLC EIN. Allow 2–7 days for Valve verification. **Cannot receive revenue without this.** |
| ACH payout configured in Steamworks | ⬜ Unknown | Add business bank account (Mercury) routing + account numbers. Must match LLC entity name exactly. |
| Regional pricing set in Steamworks | ⬜ Unknown | Set $14.99 USD base + apply Steam Regional Pricing Templates. Do before Coming Soon page. |
| Privacy policy hosted at public URL | ⬜ Unknown | Minimal policy (template in §3D of checklist) is sufficient. GitHub Pages is fastest. **Steam page cannot go live without this URL.** |
| 30-day Steam review window elapsed | ⬜ Depends on registration date | Must begin registration now if not already started. |
| Coming Soon page live ≥ 14 days before launch | ⬜ Unknown | Publish Coming Soon as soon as the review window opens. |

### Blocking for itch.io Demo (if any revenue/PWYW)

| Item | Status | Action Required |
|------|--------|----------------|
| itch.io payout method configured | ⬜ Unknown | Dashboard → Payouts → connect PayPal or Stripe. Required before any paid tier. For free demo: optional but set up now. |
| itch.io revenue model = "itch.io as MOR" | ⬜ Unknown | Account Settings → Payment Options. Confirm itch.io is merchant of record (recommended). |

### Not Yet Blocking (Address Before 1.0 or First Revenue Quarter)

| Item | Priority | Notes |
|------|----------|-------|
| LLC formation | High | Strongly recommended before Steam EA. Protects personal assets. ~$100–200 + 1–3 weeks processing. Start now. |
| `THIRD_PARTY_LICENSES.txt` created | High | Must include Godot MIT attribution. Audio assets currently placeholder — update this file when final audio is integrated. |
| Quarterly estimated taxes (Form 1040-ES) | Medium | Required once net game revenue exceeds ~$1,000 in a quarter. Set aside 25–30% of net receipts immediately. First filing due April 15 if revenue begins this quarter. |
| EULA decision | Low | Steam SSA is sufficient for EA. Defer custom EULA to 1.0. |
| CPA consultation | Medium | Recommended before first taxable year. At $6,000–$15,000 net, a one-hour CPA consult (~$200–$400) pays for itself. |

---

## 6B. Launch Discount Strategy

### Recommendation: 10% Launch Week Discount

**Launch price:** $14.99 → **$13.49** for the first 7 days (launch week only).

| Discount | Effective Price | Rationale |
|----------|----------------|-----------|
| **10% (recommended)** | $13.49 | Signals active launch; improves impulse conversion without leaving too much money on the table. Industry standard for EA. |
| 15% | $12.74 | Stronger urgency signal; useful if wishlist count is lower than expected going into launch. |
| 20% | $11.99 | Only warranted for $19.99+ games to bridge the EA hesitancy gap. Unnecessary at $14.99. |
| 0% (no discount) | $14.99 | Acceptable — but foregoes the Steam "discount badge" that increases storefront visibility. Not recommended. |

**Why 10%:**
- Steam algorithmically surfaces discounted games in launch visibility windows. Even a 10% discount earns the visual badge and filters.
- The $14.99 → $13.49 jump is psychologically meaningful to budget-conscious indie buyers without establishing a low price expectation.
- Post-launch, the base price of $14.99 is clearly the "real" price — buyers who missed launch week have a clear reference point.
- Sets up natural rhythm: launch discount (10%) → Steam Next Fest or major content update discount (15%) → Autumn/Winter sale (20%) → 1.0 launch (full price bump to $17.99–19.99).

**Do NOT do a permanent launch discount.** Set the end date to day 7 and do not extend it. Extending dilutes the urgency signal and trains the audience to wait for discounts.

---

## 7B. Monetization Strategy

### Recommendation: Single-Purchase Now; Scenario DLC at 1.0

**For Early Access:** Keep it a clean single-purchase game. Do not introduce any paid DLC, season passes, or optional purchases during EA. Reasons:
- EA buyers are investing in the game's future — paid DLC during EA creates resentment.
- Steam reviews will call out monetization aggressiveness; this kills conversion for a discovery-stage title.
- The current content (4 scenarios) fully justifies $14.99 as a complete purchase.

**Post-1.0 monetization options (evaluated):**

| Option | Revenue Potential | Effort | Recommendation |
|--------|-----------------|--------|---------------|
| **Scenario DLC packs** | High | Medium | **Best option** — each new scenario is self-contained and natural DLC. Price at $3.99–$5.99 per pack. Builds long-term revenue without inflating base price. |
| **Original Soundtrack** | Low-Medium | Low (if music exists) | Standard $2.99–$4.99 DLC if original audio is created. Low effort to package and list. Worth doing once audio is integrated. |
| Cosmetic packs | Low | Medium-High | Poor fit — the game is not cosmetic-driven. Skip. |
| Season pass / subscription | Very Low | High | Not appropriate for a single-player indie with this scope. Skip. |
| Paid itch.io tier | Low-Medium | None | After 1.0, add a paid $14.99 tier on itch.io alongside the free demo. Cultist Simulator did this successfully. |
| Free updates strategy | Revenue multiplier | Low-Medium | Each meaningful free update (new mechanics, scenario variety updates) can trigger a 2–3 week visibility spike and convert long-tail wishlists. Best ROI for solo dev. |

**Long-term monetization roadmap:**
1. **EA launch:** $14.99 single-purchase; no DLC
2. **1.0 launch:** Base price increases to $17.99–$19.99; existing EA buyers are not charged the difference (Steam handles this)
3. **Post-1.0:** Add scenario DLC packs ($3.99–$5.99 each) if development continues
4. **Soundtrack DLC:** If original music is composed, package and sell at $2.99–$4.99
5. **itch.io paid tier:** Mirror Steam 1.0 pricing on itch.io; keep demo free

**Single-purchase is the right model for Rumor Mill.** The comparables (Pentiment, Into the Breach, Cultist Simulator) are all single-purchase; the game's audience strongly prefers this. The scenario-pack DLC model is only appropriate after establishing the base game's reputation post-1.0.

---

## 8. Revenue Tracking Plan (Post-Launch)

### 8A — What to Track

**Daily (launch week, days 1–7):**

| Metric | Why | Where |
|--------|-----|-------|
| Units sold (daily) | Velocity signal; tells you if the launch curve is healthy | Steamworks → Sales & Activation Reports |
| Gross revenue (daily) | Confirms pricing is converting | Steamworks → Sales & Activation Reports |
| Wishlists added/removed (daily) | Demand signal; net wishlist change shows organic momentum | Steamworks → Wishlists |
| Refund requests (daily) | Quality signal; >10% in first 48 hrs = gameplay or expectation problem | Steamworks → Refunds |
| itch.io demo plays (daily) | Top-of-funnel; validates demo → wishlist pipeline | itch.io Dashboard → Analytics |

**Weekly (weeks 2–8):**

| Metric | Why | Where |
|--------|-----|-------|
| Cumulative units sold | Running total vs. scenario benchmarks (conservative = 200 units by day 90) | Steamworks |
| Refund rate (%) | If >8%, investigate; if >15%, flag immediately | Steamworks |
| Conversion rate (wishlists → sales) | Baseline: 10–15% of pre-launch wishlist count in first 2 weeks | Manual calc: (units sold ÷ wishlist count at launch) |
| Revenue pacing vs. model | Compare actual to moderate scenario ($6,296 at 90 days) | Manual calc from Steamworks export |
| Review count + sentiment | Validates content quality; drives conversion | Steam Store page → Reviews |
| Geographic breakdown | Identifies unexpected strong markets for future campaigns | Steamworks → Geography |

**Monthly (ongoing):**

| Metric | Why | Where |
|--------|-----|-------|
| Net developer revenue (after Steam cut + refunds) | P&L reality; set aside 25–30% for taxes | Steamworks → Financial Summary |
| Organic traffic sources | Where buyers are finding the game | Steamworks → Traffic & Conversions |
| Long-tail sales rate | Velocity decay; signal for when to schedule a seasonal discount | Steamworks |

### 8B — Where to Monitor (Tooling)

| Source | What It Covers | Access |
|--------|---------------|--------|
| **Steamworks** (partner.steamgames.com) | All sales data, refunds, wishlists, traffic, geography | Steamworks account (after game live) |
| **itch.io Dashboard** | Demo plays, referrers, ratings, downloads | itch.io creator account |
| **Steam Spy** (unofficial) | Estimated unit counts for comparables; sanity-check your trajectory | steamspy.com |
| **Google Sheets / local spreadsheet** | Manual revenue tracker; weekly snapshot vs. scenarios | Solo dev — one tab is enough |

### 8C — Refund Rate Thresholds

| Refund Rate | Interpretation | Action |
|-------------|---------------|--------|
| <5% | Excellent | No action |
| 5–8% | Normal for EA | Monitor weekly |
| 8–12% | Elevated — investigate triggers | Check Steam reviews; likely a specific bug or expectation gap |
| >12% | Critical | Pause launch discount; fix the issue; post a community update |

### 8D — First-Payout Timeline (Reminder)

Valve pays monthly, 30-day lag. **Revenue earned in April → paid in late May.** Minimum payout: $100. Ensure ACH payout is configured in Steamworks before launch or the first payout will be delayed by one additional cycle.

---

## 9. Summary: Key Numbers

| Metric | Value |
|--------|-------|
| Recommended EA price | **$14.99 USD** |
| Launch week discount | **10% ($13.49 effective, 7 days only)** |
| Developer net per Steam unit | **$10.49** (~$9.65 after ~8% refunds) |
| Total cash to launch (mid-range) | **~$300–500** |
| Break-even units | **~29–62 units** |
| Steam Direct recoupment | **~67 units** |
| Conservative 90-day net | **~$2,100** |
| Moderate 90-day net | **~$6,300** |
| Optimistic 90-day net | **~$15,700** |
| Conservative year-1 net | **~$3,900** |
| Moderate year-1 net | **~$11,700** |
| Optimistic year-1 net | **~$29,200** |
| Minimum annual overhead (post-launch) | **~$60–350/yr** |
| Launch sequence | **itch.io free demo → Steam EA (2–4 weeks)** |
| Post-EA monetization | **Single-purchase; scenario DLC at 1.0** |
| 1.0 price target | **$17.99–$19.99 USD** |

---

*Not financial or legal advice. Revenue projections are estimates based on comparable indie title performance and zero-marketing launch assumptions. Consult a CPA before filing taxes. Sources: docs/business-setup-guide.md, docs/pre-launch-legal-financial-checklist.md, Steam Partner documentation, public comparable title sales data.*

*Document version: 3.0 — 2026-04-04 (v1.0 origin: [SPA-248](/SPA/issues/SPA-248); v2.0 update: [SPA-266](/SPA/issues/SPA-266); v3.0 update: [SPA-277](/SPA/issues/SPA-277))*
