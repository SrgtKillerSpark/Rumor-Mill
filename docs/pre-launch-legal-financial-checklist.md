# Pre-Launch Legal & Financial Checklist

**Prepared by:** CFO  
**Date:** 2026-04-03  
**For:** Rumor Mill — board / founding team  
**Status:** Actionable — complete before any public release (itch.io early demo or Steam launch)

> **Prerequisite:** Complete the business formation and Steam setup steps in [`docs/business-setup-guide.md`](./business-setup-guide.md) before this checklist. This document covers what comes *after* the LLC and developer accounts are in place.

---

## Summary: Four Areas to Clear Before Launch

| Area | Blocking for itch.io | Blocking for Steam |
|------|---------------------|-------------------|
| Tax obligations | Partial (1099 threshold awareness) | Yes (W-9 required) |
| Open-source license compliance | Yes | Yes |
| Privacy policy | Recommended | **Required** (Steam policy page) |
| EULA | Optional | Optional (Valve fallback available) |

---

## 1. Tax Obligations

### 1A — Steam (Required Before Any Revenue)

Steam's W-9 / tax setup is covered in [`docs/business-setup-guide.md`](./business-setup-guide.md) §5A. Key reminders:

- [ ] W-9 submitted using your **EIN** (not personal SSN) and accepted by Valve before launch
- [ ] **1099-K threshold (Steam):** Valve issues a 1099-K when you receive $600+ in a calendar year (US). This is gross revenue before Steam's 30% cut. You owe income tax on net receipts — keep records of the Steam cut as a deductible business expense
- [ ] **State income tax:** Game revenue is ordinary business income. Flows through the LLC to your personal return (Schedule E / K-1 for single-member LLC). Talk to a CPA before your first taxable year
- [ ] **Sales tax — Steam:** Valve is the **merchant of record** on Steam. They collect and remit sales tax / VAT on your behalf in all applicable jurisdictions. **You do not need to register for sales tax separately for Steam sales.** No action required
- [ ] **VAT (EU/UK/Australia):** Valve handles VAT collection for all Steam sales. No separate VAT registration needed for Steam

### 1B — itch.io (Required Before Posting a Paid or Pay-What-You-Want Page)

itch.io's revenue model differs from Steam: **you can be the merchant of record** or use itch.io as the merchant, depending on your account configuration.

- [ ] **Check your itch.io payout model:**
  - **itch.io as MOR (recommended):** itch.io collects payments, handles VAT/sales tax, and pays you via Stripe/PayPal. You receive net payouts. Simpler legally; itch.io issues tax documents.
  - **Direct-to-developer:** You are the MOR. You must handle sales tax and VAT yourself. Avoid this model unless you have a specific reason.
  - Log in → **Account Settings → Payment Options** → confirm which model is active
- [ ] **1099-K threshold (itch.io):** itch.io pays via PayPal or Stripe. The issuing processor (not itch.io itself) sends the 1099-K. As of the 2025 tax year, the IRS 1099-K threshold is **$5,000** (transitional relief; the statutory $600 threshold is being phased in). Track all itch.io income regardless of 1099 status — it is taxable above your standard deduction
- [ ] **Connect payout method:** itch.io → Dashboard → Payouts → add PayPal or Stripe account
- [ ] **Set revenue share:** itch.io suggests you offer them 10–30% (completely optional). Set your preferred split in the game's pricing settings
- [ ] **For a free early demo:** no tax action required for $0 downloads; still confirm payout method is ready for when you add a paid tier

### 1C — Quarterly Estimated Taxes (Action Before First Revenue Quarter)

If Rumor Mill generates meaningful revenue (>$1,000 net profit in a quarter), the LLC owner should file quarterly estimated taxes to avoid underpayment penalties.

- [ ] Set aside **25–30% of net game revenue** in a separate savings account as it arrives
- [ ] File **Form 1040-ES** quarterly (due: April 15, June 15, September 15, January 15)
- [ ] At ~$40,000+ annual net profit, evaluate an **S-Corp election** (can reduce self-employment tax by ~15% on salary vs. distributions) — consult a CPA

---

## 2. Open-Source License Compliance

### 2A — Godot Engine (MIT License)

Rumor Mill is built on **Godot 4.6**, which is licensed under the **MIT License**. This is very permissive.

**Your obligations:**
- [ ] **Include the Godot MIT license notice** in your game credits or a bundled `THIRD_PARTY_LICENSES.txt` file. The license text is at: `https://github.com/godotengine/godot/blob/master/LICENSE.txt`
- [ ] The Godot export template you distribute is also MIT-licensed — the same attribution covers it
- [ ] You do **not** need to open-source your game code. MIT does not require that
- [ ] You do **not** need to pay royalties to Godot. MIT is royalty-free
- [ ] **Recommended action:** Create `docs/THIRD_PARTY_LICENSES.txt` in the repo (see template in §2D below) and bundle it in the export folder alongside the `.exe`

### 2B — Godot Plugins / Addons

As of the Sprint 7 build, **no addons are installed** in `rumor_mill/addons/`. If you add any addons before launch:

- [ ] For each addon, check its license in the addon folder (usually `LICENSE` or `README.md`)
- [ ] **Common addon licenses and what they require:**

| License | Requires attribution | Requires open-sourcing your code | Royalties |
|---------|---------------------|----------------------------------|-----------|
| MIT | Yes (credit text) | No | No |
| Apache 2.0 | Yes (credit text + NOTICE file) | No | No |
| MPL 2.0 | Yes | Only modified addon files | No |
| GPL v3 | Yes | **Yes — entire project** | No |
| CC0 | No | No | No |
| CC BY 4.0 | Yes | No | No |
| Commercial | Per license | Per license | Possibly |

> **Watch out for GPL addons:** If any plugin is GPL v3, your entire shipped game code may need to be open-sourced. Avoid GPL-licensed code in a commercial title unless you have explicitly negotiated a commercial exception with the author.

- [ ] **Godot Asset Library check:** most AssetLib addons are MIT or CC0. Confirm before adding any asset
- [ ] Add any addon attributions to `THIRD_PARTY_LICENSES.txt`

### 2C — Audio and Art Assets

The Sprint 7 build uses **silent placeholder audio files** (see `README.md` §Known Limitations). Before integrating final assets:

- [ ] **Audio (music and SFX):** Use only assets with explicit commercial-use licenses. Acceptable sources:
  - [Freesound.org](https://freesound.org) — filter by CC0 or CC BY; read each track's license
  - [OpenGameArt.org](https://opengameart.org) — verify license per asset
  - [itch.io game assets](https://itch.io/game-assets) — read each listing's license
  - Purchased/commissioned tracks (keep receipts)
  - **Avoid CC BY-NC or CC BY-SA** for commercial titles (NC = non-commercial restriction; SA = share-alike may propagate)
- [ ] **For each audio file integrated**, add a row to `THIRD_PARTY_LICENSES.txt`:
  - File name, artist/source, license type, URL
- [ ] **Textures and tilesets:** `assets/textures/town_tileset.tres` and other art assets — confirm each was created in-house or licensed for commercial use
- [ ] **Fonts:** if any custom fonts are used in the UI, verify their license allows embedding in commercial software (many require a desktop or web license separately)

### 2D — THIRD_PARTY_LICENSES.txt Template

Create this file at the root of the distributed build package:

```
THIRD PARTY LICENSES — Rumor Mill

=== Godot Engine ===
License: MIT
Copyright (c) 2014-present Godot Engine contributors
https://github.com/godotengine/godot/blob/master/LICENSE.txt

[Full MIT license text here — paste from the URL above]

=== [Plugin/Asset Name] ===
License: [License type]
Copyright (c) [Year] [Author]
[License text or link]

=== [Audio Track Name] ===
Artist: [Name]
Source: [URL]
License: [CC0 / CC BY 4.0 / etc.]
[Attribution as required by license]
```

- [ ] `THIRD_PARTY_LICENSES.txt` added to the repo at `rumor_mill/` root
- [ ] File is bundled in every distributed build package (alongside `.exe`)
- [ ] File is linked from the Steam store page's "Legal" section (can be a short line: "See THIRD_PARTY_LICENSES.txt in the game folder")

---

## 3. Privacy Policy

### 3A — When Is a Privacy Policy Required?

| Platform | Requirement |
|----------|------------|
| Steam | **Required.** You must link a privacy policy URL on your Steam store page before the page can go live. Valve will not approve a store page without one. |
| itch.io | Not formally required, but strongly recommended. Any payment-enabled page collects email; you must disclose how it is used. |
| Any EU/UK player | **GDPR / UK GDPR applies.** Even if you don't think you collect data, most game engines and storefronts do. You need a policy. |

### 3B — What Data Does Rumor Mill Collect?

Based on the current build:

| Data type | Collected? | By whom |
|-----------|-----------|---------|
| Personal info (name, email) | No (standalone offline game) | — |
| Crash reports / analytics | No (no Sentry, no analytics SDK) | — |
| Payment info | No (handled entirely by Steam/itch.io) | Steam / itch.io |
| Cookies / tracking | No (no web component) | — |
| Save files (local only) | Yes (local disk only) | Your game |

This is a **minimal data posture** — the game collects essentially nothing directly. Your privacy policy can be short.

### 3C — Privacy Policy Checklist

- [ ] **Draft a privacy policy** (see template in §3D). Key sections needed:
  - What data is collected (and what is NOT collected)
  - How data is used
  - Third-party data processors (Steam, itch.io, PayPal/Stripe — they collect your customer data, not you)
  - How to contact you for privacy requests
  - Effective date
- [ ] **Host the privacy policy** at a public URL. Options:
  - A simple page on a studio website (recommended long-term)
  - GitHub Pages (free, simple): create a `/privacy` page in a public repo
  - Google Sites or Notion public page (quick stopgap)
- [ ] **Add the privacy policy URL to your Steam store page** under Store Presence → Basic Info → Privacy Policy
- [ ] **Add the privacy policy URL to your itch.io game page** (footer or description)
- [ ] **GDPR minimum requirements** (applies to any EU customer):
  - Identify the data controller (your LLC name and contact email)
  - State the legal basis for any data processing
  - Describe data retention periods
  - Provide a contact method for data subject rights requests (access, deletion, portability)
- [ ] **COPPA:** Rumor Mill is rated for general audiences. If you add an age gate or the game could be marketed to children under 13 in the US, you must comply with COPPA. For a medieval strategy game, this is unlikely to be an issue — but confirm your Steam age rating is "Everyone" or "Teen" and marketing targets adults
- [ ] Review and update the privacy policy before each major platform release

### 3D — Minimal Privacy Policy Template

```markdown
# Privacy Policy — [Studio Name]
Effective date: [Date]

[Game Name] is a single-player offline game. We do not collect, store, or share 
personal information directly.

## What We Don't Collect
- We do not collect your name, email address, or any account information.
- We do not include analytics, tracking, or telemetry in the game.
- We do not store data outside your local device.

## Storefront Data (Steam / itch.io)
Your purchase and payment information is handled entirely by Valve (Steam) and 
itch.io, subject to their respective privacy policies:
- Steam: https://store.steampowered.com/privacy_agreement/
- itch.io: https://itch.io/docs/legal/privacy-policy

We receive aggregated sales data from these platforms but not your individual 
personal information.

## Local Save Data
The game saves your progress locally on your device. This data never leaves 
your computer and is not accessible to us.

## Contact
For privacy-related questions: [contact@yourstudio.com]

## Changes to This Policy
We will update the effective date when this policy changes.
```

---

## 4. End User License Agreement (EULA)

### 4A — Do You Need a Custom EULA?

| Platform | Default if no custom EULA | Recommendation |
|----------|--------------------------|----------------|
| Steam | Valve's **Steam Subscriber Agreement (SSA)** governs all purchases | Custom EULA optional but good practice |
| itch.io | No default EULA; itch.io's ToS covers the transaction | Custom EULA optional |

**For a first launch:** the Steam SSA is legally sufficient and covers most bases. A custom EULA adds protection but is not required to ship.

### 4B — Why Add a Custom EULA?

A custom EULA lets you:
- Prohibit unauthorized redistribution or piracy (beyond what SSA covers)
- Limit liability for bugs, data loss, or hardware damage
- Reserve rights to update or discontinue the game
- Prohibit use in certain contexts (e.g., commercial training, military simulation)
- Restrict reverse engineering / decompilation beyond what the SSA addresses

### 4C — EULA Checklist

- [ ] **Decision:** Will you use a custom EULA or rely on the Steam SSA?
  - For a solo indie studio at launch: **Steam SSA is fine.** Add a custom EULA before a full 1.0 release or if you have specific concerns
- [ ] If adding a custom EULA:
  - [ ] Draft the EULA (template §4D)
  - [ ] Host it at a public URL
  - [ ] In Steamworks: Store Presence → Basic Info → EULA → link your URL
  - [ ] Display it at game first-launch (optional but best practice: a simple click-through on first run)
  - [ ] Have it reviewed by a lawyer before public launch (not just a template)
- [ ] **Godot MIT note:** Your EULA governs the *game content* (your code, art, audio, story). The Godot engine itself remains MIT-licensed regardless of what your EULA says. Do not try to relicense the engine
- [ ] **Open-source attribution disclaimer:** Include a line in the EULA acknowledging third-party components are governed by their own licenses (see `THIRD_PARTY_LICENSES.txt`)

### 4D — Minimal EULA Template (Starting Point Only — Get Legal Review)

```markdown
# End User License Agreement — [Game Name]
Version 1.0 — Effective [Date]
[Studio Name] ("[Studio]", "we", "us")

PLEASE READ THIS AGREEMENT BEFORE PLAYING. BY INSTALLING OR PLAYING [GAME NAME], 
YOU AGREE TO THESE TERMS.

## 1. License Grant
We grant you a limited, non-exclusive, non-transferable, revocable license to 
install and play [Game Name] for your personal, non-commercial use.

## 2. Restrictions
You may not:
- Copy, distribute, or sell the game or any portion of it
- Reverse engineer, decompile, or disassemble the game (except where permitted by law)
- Use the game for commercial purposes without written permission
- Remove or alter any proprietary notices

## 3. Ownership
[Game Name] and all content (art, music, story, code) are owned by [Studio Name] 
or licensed to us. This agreement grants no ownership rights.

## 4. Third-Party Components
This game includes open-source software subject to their own licenses. See 
THIRD_PARTY_LICENSES.txt included with the game.

## 5. No Warranties
THE GAME IS PROVIDED "AS IS." WE MAKE NO WARRANTIES, EXPRESS OR IMPLIED, 
INCLUDING WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.

## 6. Limitation of Liability
TO THE MAXIMUM EXTENT PERMITTED BY LAW, [STUDIO NAME] IS NOT LIABLE FOR ANY 
INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING FROM USE OF THE GAME.

## 7. Termination
This license terminates automatically if you violate these terms.

## 8. Governing Law
This agreement is governed by the laws of [Your State], United States.

## Contact
[contact@yourstudio.com]
```

> **Legal note:** This template is a starting point only. Have a lawyer review before use, especially §§5–8. Liability limitation clauses vary in enforceability by jurisdiction.

---

## 5. Pre-Launch Completion Checklist (Summary)

Use this as your final go/no-go gate before each platform goes live:

### itch.io Early Demo Release

- [ ] itch.io payout method configured (PayPal or Stripe connected)
- [ ] itch.io revenue model set to "itch.io as merchant of record" (recommended)
- [ ] Godot MIT license attribution in `THIRD_PARTY_LICENSES.txt`
- [ ] All audio assets have confirmed royalty-free / commercial-use licenses
- [ ] Privacy policy drafted and hosted at a public URL
- [ ] Privacy policy URL added to itch.io game page

### Steam Early Access Launch

- [ ] All itch.io items above ✓
- [ ] W-9 submitted and accepted by Valve (EIN, not SSN)
- [ ] ACH payout configured in Steamworks
- [ ] Regional pricing set ($14.99 USD base + regional tiers)
- [ ] Privacy policy URL added to Steam store page (required — page won't go live without it)
- [ ] EULA decision made: Steam SSA (no action) or custom EULA (upload URL)
- [ ] `THIRD_PARTY_LICENSES.txt` bundled in build package
- [ ] 30-day Steam review window elapsed
- [ ] Coming Soon page live for ≥14 days before launch date

---

*Not legal or tax advice. Consult a CPA for tax filing and a business attorney for EULA / privacy policy review before your first public paid release. Sources: IRS Publication 334 (small business tax), GDPR Art. 13, Steam Partner documentation, itch.io developer FAQ.*
