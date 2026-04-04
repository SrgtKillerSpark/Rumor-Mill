# Pre-Launch Action Plan — Rumor Mill EA

**Prepared by:** CFO  
**Date:** 2026-04-04  
**For:** Board / founding team  
**Status:** Awaiting board confirmation on starred items (⭐)  
**Task:** [SPA-290](/SPA/issues/SPA-290)

> This document consolidates all legal and financial blockers from `docs/pre-launch-legal-financial-checklist.md` and `docs/launch-financial-model.md` into a single, timestamped action plan with owners, status, and target dates. Update this file as each item is completed.

---

## Proposed Launch Timeline

| Milestone | Target Date | Dependencies |
|-----------|-------------|--------------|
| All itch.io demo blockers cleared | **2026-04-11** | Items 1–5 below |
| itch.io demo goes live | **2026-04-11** | Above |
| Steam review window begins (if not already started) | **2026-04-11** | Steam app registered |
| Coming Soon page live on Steam | **2026-04-14** | Steam review approved or window already running |
| All Steam EA blockers cleared | **2026-04-18** | Items 6–12 below |
| Steam Early Access launch | **2026-04-25 – 2026-05-09** | 30-day review window + 14-day Coming Soon |

> The 2-4 week itch.io → Steam EA window is built into this timeline. If the Steam review window started before today, the Steam EA date can pull forward to the earlier end of the range.

---

## Track 1: itch.io Demo (Target: live by 2026-04-11)

These are blockers for any revenue-generating itch.io page. The demo is free, so items 4–5 are optional-but-recommended — they become blocking the moment a paid tier is added.

| # | Item | Status | Owner | Target Date | Notes |
|---|------|--------|-------|-------------|-------|
| 1 | itch.io payout method configured (PayPal or Stripe) | ⭐ **Unknown** | Board | 2026-04-08 | Dashboard → Payouts. Required before any paid tier. Do now so it's ready. |
| 2 | itch.io revenue model set to "itch.io as MOR" | ⭐ **Unknown** | Board | 2026-04-08 | Account Settings → Payment Options. Strongly recommended — avoids solo VAT/sales tax liability. |
| 3 | `THIRD_PARTY_LICENSES.txt` created and bundled in build | ⭐ **Unknown** | Developer | 2026-04-09 | Must include Godot MIT attribution. Template in `docs/pre-launch-legal-financial-checklist.md §2D`. Audio is currently placeholder — update this file when final audio is integrated post-launch. |
| 4 | Privacy policy drafted | ⭐ **Unknown** | Board | 2026-04-09 | Minimal template in `docs/pre-launch-legal-financial-checklist.md §3D`. No personal data is collected by the game; policy can be very short. |
| 5 | Privacy policy hosted at public URL | ⭐ **Unknown** | Board | 2026-04-10 | GitHub Pages is fastest and free. Required for Steam; strongly recommended for itch.io. |

---

## Track 2: Steam Early Access (Target: launch by 2026-04-25 – 2026-05-09)

Items 6–8 can be worked in parallel with itch.io demo period. Items 9–11 depend on the review window timeline.

| # | Item | Status | Owner | Target Date | Notes |
|---|------|--------|-------|-------------|-------|
| 6 | LLC formation initiated | ⭐ **Unknown** | Board | 2026-04-08 | ~$100–200, 1–3 weeks processing. Start now — can launch without LLC but it's a personal liability risk. File online at your state's SOS website. |
| 7 | EIN obtained (IRS.gov) | ⭐ **Unknown** | Board | 2026-04-08 | Free, ~5 minutes online at IRS.gov. Can be done today. Required for W-9. |
| 8 | W-9 submitted and accepted by Valve | ⭐ **Unknown** | Board | 2026-04-10 | Steamworks → Account → Tax Information. Use LLC EIN (or personal SSN if LLC not yet formed). Allow 2–7 days for Valve verification. **Cannot receive revenue without this.** |
| 9 | ACH payout configured in Steamworks | ⭐ **Unknown** | Board | 2026-04-11 | Add business bank account (Mercury — free) routing + account numbers. Must match LLC entity name exactly. Set up Mercury account first if not done. |
| 10 | Regional pricing set in Steamworks | ⭐ **Unknown** | Board | 2026-04-12 | $14.99 USD base + apply Steam Regional Pricing Templates. Do before Coming Soon page goes live. See `docs/business-setup-guide.md §5C`. |
| 11 | Privacy policy URL added to Steam store page | ⭐ **Unknown** | Board | 2026-04-12 | Steamworks → Store Presence → Basic Info → Privacy Policy. **Steam page cannot go live without this URL.** (Depends on item 5.) |
| 12 | Steam review window: confirm start date | ⭐ **Unknown — CRITICAL** | Board | 2026-04-04 | Confirm whether the 30-day review window has already started. If not, begin now. This is the longest lead-time item — it gates everything. If started ≥14 days ago, Coming Soon can go live immediately. |
| 13 | Coming Soon page live on Steam | ⭐ **Unknown** | Board | 2026-04-14 | Must be live ≥14 days before EA launch date. Publish as soon as the review window clears. |
| 14 | Launch week 10% discount configured in Steamworks | ⭐ **Unknown** | Board | 3 days before launch | Set $14.99 → $13.49 for 7 days only. Do not extend. See `docs/launch-financial-model.md §6B`. |

---

## Track 3: High-Priority Pre-Revenue Items (Address Before First Revenue Quarter)

| # | Item | Status | Owner | Target Date | Notes |
|---|------|--------|-------|-------------|-------|
| 15 | Tax set-aside account set up | ⭐ **Unknown** | Board | Before first payout | Open a separate savings account. Set aside 25–30% of every net payout for estimated taxes. First quarterly filing: April 15 (Q1) if any revenue lands this quarter; otherwise June 15. |
| 16 | Quarterly estimated taxes (Form 1040-ES) | ⭐ **Unknown** | Board | April 15 (if Q1 revenue) | Required if net game income exceeds ~$1,000 in a quarter. See `docs/pre-launch-legal-financial-checklist.md §1C`. |
| 17 | CPA consultation scheduled | Not yet blocking | Board | Before end of Q2 2026 | Recommended before first taxable year. At $6K–$15K net revenue, a one-hour CPA consult (~$200–$400) pays for itself. |
| 18 | Audio assets sourced with confirmed licenses | Not yet blocking | Developer | Before Phase 1 audio update | Use CC0/CC-BY sources (Freesound, OpenGameArt). Update `THIRD_PARTY_LICENSES.txt` for each asset integrated. |
| 19 | EULA decision | Not yet blocking | Board | Before Steam EA launch | Steam SSA is legally sufficient for EA. Custom EULA optional — defer to 1.0 unless there are specific concerns. |

---

## Status Summary (as of 2026-04-04)

| Category | Items | Confirmed Done | Needs Board Action | Not Yet Blocking |
|----------|-------|---------------|-------------------|------------------|
| itch.io demo blockers | 5 | 0 | 5 | 0 |
| Steam EA blockers | 9 | 0 | 9 | 0 |
| Pre-revenue items | 5 | 0 | 3 | 2 |
| **Total** | **19** | **0** | **17** | **2** |

**All items are unconfirmed.** The board should review this checklist and update statuses immediately. Items 6 (LLC), 7 (EIN), and 12 (Steam review window start) should be addressed today — they have the longest lead times.

---

## Critical Path

The longest-lead-time item is the **Steam 30-day review window** (item 12). This gates the Coming Soon page (14 days before launch) and therefore the EA launch date. Every other item can be completed within 1–2 weeks.

```
TODAY (Apr 4) ──► EIN + LLC start + Steam review begins
                  │
Week 1 (Apr 4-11) ► itch.io payout + MOR + privacy policy + THIRD_PARTY_LICENSES.txt
                  │
Apr 11 ──────────► itch.io DEMO LIVE + Steam W-9 submitted
                  │
Week 2 (Apr 11-18)► ACH payout + regional pricing + privacy policy → Steam store page
                  │
Apr 14-18 ───────► Coming Soon page live (if review window cleared)
                  │
2-week itch.io    ► Collect wishlist conversions, player feedback, demo data
demo period       │
                  │
Apr 25 – May 9 ──► STEAM EA LAUNCH (14+ days after Coming Soon; 30+ days after review start)
```

---

## Board Action Required This Week

Please confirm or complete the following items by **2026-04-08**:

1. **Has the Steam 30-day review window started?** If yes, what date? This determines whether the Apr 25 or May 9 launch target is realistic.
2. **Is the EIN already obtained?** If yes, record it — W-9 requires it.
3. **Is LLC formation in progress?** If yes, estimated completion date?
4. **Is the itch.io payout method configured?** If yes, mark item 1 done.
5. **Is the itch.io revenue model set to itch.io as MOR?** If yes, mark item 2 done.

Once the board confirms statuses, this document should be updated and the launch date can be locked.

---

*Prepared per [SPA-290](/SPA/issues/SPA-290). See also: `docs/pre-launch-legal-financial-checklist.md` (full legal detail), `docs/launch-financial-model.md` (financial projections), `docs/business-setup-guide.md` (LLC + Steam setup steps).*
