# Business Setup Guide: LLC + Steam Developer Account

**Prepared by:** CFO  
**Date:** 2026-04-03  
**For:** Rumor Mill — board / founding team  
**Status:** Actionable — complete steps in order  

This guide consolidates prior research into a single checklist. Work top to bottom; later steps depend on earlier ones. Estimated total time: **3–8 weeks** (most of the wait is the bank account and the mandatory Steam 30-day window). Estimated total cost: **$150–$400 one-time**.

---

## Phase 1 — Get an EIN (Do This First)

> **Time: ~5 minutes. Cost: Free.**

An EIN (Employer Identification Number) is a federal tax ID issued by the IRS. You need it before you can open a business bank account or complete Steamworks tax forms. Get it before anything else — it unlocks every subsequent step.

- [ ] Go to **IRS.gov → Apply for an EIN Online**  
  - Select entity type: **Sole Proprietor** (if publishing as an individual) or **LLC** (if you've already formed one — see Phase 2)  
  - Complete the online wizard — takes about 5 minutes  
  - Your EIN is issued instantly on screen  
- [ ] **Save the confirmation letter (CP 575) as a PDF** — you will need it for the bank and for Valve  
- [ ] Write down your EIN: `___-_______`

> **Note:** You can get the EIN as a sole proprietor now and later convert the Steamworks account to use the LLC EIN. Getting the EIN first does not lock you into a particular entity structure.

---

## Phase 2 — Form an LLC (Recommended; Can Be Done in Parallel)

> **Time: 1–3 weeks (state processing). Cost: $50–$200 filing fee + $60–$300/yr.**

Publishing on Steam does not legally require an LLC — individuals can publish as sole proprietors. However, forming a home-state LLC is recommended for:
- Personal liability protection (your personal assets are shielded)
- Cleaner IP ownership (rights belong to the company, not an individual)
- Professional storefront presence (studio name on Steam, not your legal name)
- Easier business banking

**Recommended approach:** Form a single-member LLC in your **home state** unless you have specific investor or privacy reasons to use Delaware or Wyoming.

| State | Filing Fee | Annual Fee | Notes |
|-------|-----------|-----------|-------|
| Home state | $50–200 | Varies | Simplest; no dual-registration headache |
| Wyoming | $100 | $60/yr | Good low-cost alternative if home state fees are high |
| Delaware | $90 | $300/yr min | Best for VC fundraising; overkill for indie studio |

### Steps

- [ ] **Choose your state** — home state is the default recommendation  
- [ ] **File Articles of Organization** with your state's Secretary of State  
  - Most states have an online portal; search `[your state] LLC filing online`  
  - Pay the filing fee by card  
- [ ] **Designate a registered agent**  
  - You can list yourself (free) or use a registered agent service ($50–$150/yr)  
  - A service keeps your personal address off public filings — worth it for privacy  
- [ ] **Draft a simple operating agreement**  
  - Required in most states; free templates are widely available online  
  - For a single-member LLC this is a one-page document  
  - Search: `single member LLC operating agreement template [your state]`  
- [ ] **Wait for state confirmation** — typically 1–3 weeks by mail/email; expedited processing often available for $50–$100  
- [ ] **Once confirmed, get a new EIN in the LLC's name** (if you got one as a sole proprietor in Phase 1)  
  - Go back to IRS.gov → Apply for EIN → LLC  
  - Use the new LLC EIN for all subsequent business accounts and Steamworks  

---

## Phase 3 — Open a Business Bank Account

> **Time: 1–2 weeks (verification). Cost: $0 (Mercury/Relay have no monthly fees).**

A dedicated business bank account is required before Steamworks can pay you. The account name must exactly match your Steamworks entity name.

### What You'll Need

- EIN (from Phase 1 or 2)
- LLC formation documents (Articles of Organization + state confirmation)
- Government-issued ID
- Initial deposit (varies; many online banks require $0–$25)

### Recommended Banks

| Bank | Monthly Fee | Notes |
|------|------------|-------|
| **Mercury** | $0 | Best for indie studios; online-only; fast setup |
| **Relay** | $0 | Similar to Mercury; no minimum balance |
| Local credit union | $0–10 | Good if you prefer in-person; may require branch visit |
| Chase Business | $15 (waivable) | Good if you already bank with Chase personally |

**Recommended: Mercury** — no fees, easy online setup, widely used by small software companies.

### Steps

- [ ] Apply at Mercury (mercury.com) or your preferred bank  
- [ ] Upload LLC documents and EIN confirmation when prompted  
- [ ] Complete identity verification (typically 1–5 business days)  
- [ ] Note your **routing number** and **account number** — you'll need these for Steamworks  
- [ ] Keep this account separate from personal finances

---

## Phase 4 — Register the Steam Developer Account

> **Time: 1–3 days (registration) + 30-day mandatory waiting period. Cost: $100 (recoupable).**

The $100 Steam Direct fee is **recoupable** — once the game earns $1,000 in adjusted gross revenue, the fee is credited back to your account. It is effectively free for any game that finds an audience.

### Requirements Before You Start

You need all of the following before beginning Steam registration:
- [ ] EIN (from Phase 1/2)
- [ ] Business bank account open (from Phase 3) — needed to complete tax forms
- [ ] Government-issued ID
- [ ] Credit or debit card for the $100 fee

### Steps

- [ ] Go to **partner.steamgames.com** → Create Account  
- [ ] Use the LLC name (or your legal name if publishing as an individual)  
- [ ] Agree to the Steam Distribution Agreement  
- [ ] Pay the **$100 Steam Direct fee** (per game; applies to Rumor Mill)  
- [ ] **Complete tax information** (see Phase 5 below — do this immediately after registration)  
- [ ] **Wait out the mandatory 30-day review window** — this begins after tax/banking info is submitted and verified  
  - Use this time to build out your store page assets (capsule art, screenshots, trailer)

> **Timeline note:** From first registration to being able to publish, budget **6–10 weeks minimum** (registration + tax verification + 30-day wait + store review + 14-day Coming Soon minimum). Start this process at least **2–3 months before your target launch date.**

---

## Phase 5 — Set Up Steamworks Tax & Payment Info

> **Time: 2–7 business days (Valve verification). Cost: $0.**

These two items are the **hardest blockers** between you and receiving money. Do them immediately after creating the Steam account.

### 5A — Tax Forms (W-9)

- [ ] Log into Steamworks Partner portal  
- [ ] Navigate to: **Account → Tax Information**  
- [ ] Complete the **W-9 form** (US persons and entities)  
  - Use your **EIN** (preferred) rather than SSN — keeps your personal SSN off Valve's system  
  - Non-US developers: complete **W-8BEN** (individuals) or **W-8BEN-E** (entities)  
- [ ] Submit and wait for Valve confirmation (2–7 business days)  
- [ ] Valve cannot release earnings until a valid tax form is accepted  
- [ ] At year-end, Valve will issue a **1099-K** if you receive $600+ in the calendar year (US)

### 5B — Payment / Payout Setup (ACH)

- [ ] Log into Steamworks Partner portal  
- [ ] Navigate to: **Revenue & Payments → Payment Information**  
- [ ] Add your bank account via **ACH** (US):  
  - Routing number  
  - Account number  
  - Account type: Checking  
- [ ] The account name must exactly match your Steamworks registered entity name  
- [ ] Valve pays monthly; minimum payout threshold is **$100**  
- [ ] Payments are issued approximately 30 days after the end of the reporting month  
- [ ] Confirm payout method is active and verified before launch

### 5C — Regional Pricing

> Set this up before launching, not after. Revenue from unpriced regions defaults to USD conversion, which is often wrong.

- [ ] In Steamworks: navigate to **Store Presence → Pricing**  
- [ ] Set base USD price to **$14.99** (Early Access)  
- [ ] Apply **Steam Regional Pricing Templates** as a baseline  
- [ ] Review and adjust to match regional purchasing power:

| Region | Recommended Price | Discount vs. USD |
|--------|-----------------|-----------------|
| United States | $14.99 | — |
| Eurozone | €13.99 | ~–7% |
| United Kingdom | £11.99 | ~–10% |
| Brazil | R$29.99 | ~–60% |
| Russia / CIS | ₽599 | ~–75% |
| Turkey | ₺119 | ~–85% |
| India | ₹599 | ~–80% |
| Southeast Asia | ~$7.99 eq. | ~–47% |

- [ ] Enable pricing for **all regions** — leaving regions blank limits your addressable market  

---

## Timeline: What to Do First, What Can Wait

```
Week 1 (do immediately)
  ├─ Get EIN from IRS.gov [~5 min, free]
  ├─ Start LLC filing in your home state [$50–200]
  └─ Apply for business bank account (Mercury recommended) [~1 hr]

Weeks 1–3 (waiting / parallel)
  ├─ LLC state processing (1–3 weeks)
  ├─ Bank account verification (1–5 business days)
  └─ Gather Steam registration assets (ID, payment method)

Week 3–4 (once bank is open)
  ├─ Register Steam developer account [$100]
  ├─ Complete W-9 in Steamworks (use EIN)
  └─ Configure ACH payout in Steamworks

Weeks 4–7 (mandatory waiting)
  ├─ 30-day Steam review window
  └─ Build store page: capsule art, screenshots, description, trailer

Week 7–10 (pre-launch)
  ├─ Set $14.99 EA price + regional pricing
  ├─ Publish Coming Soon page (14-day minimum before launch)
  └─ ✅ Ready to launch Early Access

Can Wait Until Post-Launch
  └─ S-Corp election (worthwhile at ~$40–50k/yr net profit)
  └─ Paid accountant / CPA (useful once revenue is flowing)
  └─ Additional LLC cleanup (operating agreement refinement, etc.)
```

---

## Cost Summary

| Item | One-Time Cost | Annual Cost |
|------|-------------|------------|
| EIN (IRS.gov) | Free | — |
| LLC filing (home state, mid-range) | $100–200 | $60–200 |
| Registered agent (optional) | — | $50–150 |
| Business bank account (Mercury) | Free | Free |
| Steam Direct fee (Rumor Mill) | $100 (recoupable) | — |
| **Total out-of-pocket** | **~$200–500** | **~$60–350** |

The Steam fee is recouped at $1,000 in gross sales. Net cost after recoupment: **$100–400 one-time**.

---

## Revenue Split Reminder

For Rumor Mill operating at its current scale:

| Tier | Steam Cut | Developer Keeps |
|------|----------|----------------|
| First $10M (lifetime per game) | 30% | **70%** |

At $14.99 base price, net per unit after Steam's cut: **~$10.49 USD**

---

## Quick Reference: Critical Blockers Before Launch

Must be completed before Rumor Mill can go live on Steam and receive revenue:

1. **EIN obtained** (IRS.gov)
2. **W-9 submitted and accepted by Valve**
3. **Business bank account open**
4. **ACH payout configured in Steamworks**
5. **Regional pricing set**
6. **30-day mandatory Steam review window elapsed**

---

*Sources: CFO research memos in SPA-136 (LLC analysis), SPA-155 (Steam account research), SPA-142 (pre-launch financial checklist). Not legal or tax advice — consult a CPA for jurisdiction-specific guidance before filing.*
