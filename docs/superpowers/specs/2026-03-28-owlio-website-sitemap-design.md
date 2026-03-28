# Owlio Marketing Website — Sitemap Design

## Context

Owlio is a gamified reading and vocabulary learning platform for schools. This design defines the sitemap and information architecture for Owlio's public-facing marketing website.

**Target audience:** Teachers (primary), students (login access)
**Business model:** B2B school sales — no pricing on site, demo request CTA
**Language:** English (international market)
**Approach:** Single-page scroll + footer quick links to secondary pages (Lean Launch)
**Reference:** Duolingo's website structure (product site + login gateway)

---

## Pages

| URL | Type | Purpose |
|-----|------|---------|
| `/` | Scroll page | Main marketing page — all key sections |
| `/login` | Redirect | Redirects to existing app login |
| `/demo` | Standalone | Demo request form for teachers |
| `/about` | Standalone | Mission + team |
| `/privacy` | Standalone | Privacy policy |
| `/terms` | Standalone | Terms of service |
| `/contact` | Standalone | Contact form or email |
| `/faq` | Standalone | Frequently asked questions |

**Total: 8 pages** (1 scroll + 1 redirect + 6 standalone)

---

## Navbar

```
┌──────────────────────────────────────────────────────┐
│  Owlio Logo              [For Teachers]      [Log in] │
└──────────────────────────────────────────────────────┘
```

- **Logo** → `/` (scroll to top)
- **For Teachers** → `/#for-teachers` (anchor scroll to teacher section)
- **Log in** → `/login` (redirects to existing app login)

---

## Main Page Scroll Sections (`/`)

### 1. Hero

- Bold headline + subtitle + CTA
- Messaging: "The fun way to read in English" or similar
- Subtitle: Curriculum-aligned reading + spaced repetition vocabulary
- CTA: **[Get Started]** → `/demo`
- Visual: Owlio owl mascot + stylized app mockup (right side)

### 2. Value Props — Zigzag Layout (Duolingo-style)

Alternating left-right layout. Each block: one side text (headline + paragraph), other side illustration. Zigzag pattern creates breathing room and editorial feel.

**Block A** — Left text / Right illustration
- **"curriculum-aligned"**
- "Books and vocabulary that match what's taught in class. Your students read what they're already learning."
- Illustration: book + curriculum visual

**Block B** — Left illustration / Right text
- **"backed by science"**
- "Powered by SM-2 spaced repetition — the world's most proven memory algorithm. Every word reviewed at the perfect moment."
- Illustration: brain/memory visual

**Block C** — Left text / Right illustration
- **"stay motivated"**
- "XP, streaks, leagues, avatars, card collections — students actually want to practice every day."
- Illustration: gamification elements

### 3. For Teachers (anchor: `#for-teachers`)

- Left: text block — how Owlio makes teachers' lives easier
- Right: stylized teacher dashboard mockup
- Key points:
  - Assign books & vocabulary to your class
  - Monitor reading progress & quiz scores
  - Zero setup — works with your existing curriculum
- CTA: **[Request a Demo]** → `/demo`

### 4. Gamification Showcase

- Headline: "Learning that feels like playing"
- Stylized mockups showing: streak, badges, leaderboard, avatar customization, card collection
- Brief descriptions with each visual
- Carousel or grid layout

### 5. App Download

- Headline: "Learn anytime, anywhere"
- App Store + Google Play badges
- (Include when mobile app is available/published)

### 6. Final CTA

- Headline: "Bring Owlio to your school"
- CTA: **[Get Started]** → `/demo`
- Sub-text: "Already have an account? [Log in](/login)"

### 7. Footer

(See Footer section below)

---

## Footer

```
┌─────────────────────────────────────────────────────────────────┐
│  Owlio Logo                                                      │
│                                                                  │
│  About              Product             Help & Legal             │
│  ├── About Us       ├── Owlio App       ├── FAQ                  │
│  ├── Mission        ├── For Schools     ├── Contact              │
│  └── Careers        └── Blog            ├── Privacy Policy       │
│                                          └── Terms of Service    │
│                                                                  │
│  Social                                                          │
│  Instagram · TikTok · Twitter · YouTube · LinkedIn               │
│                                                                  │
│  ─────────────────────────────────────────────────────────────── │
│  © 2026 Owlio. All rights reserved.                              │
└─────────────────────────────────────────────────────────────────┘
```

**Footer link destinations:**
- About Us, Mission → `/about`
- Careers → `/about#careers` or mailto link (early stage)
- Owlio App → App Store / Google Play links
- For Schools → `/#for-teachers` (anchor scroll)
- Blog → External link (Medium) or placeholder
- FAQ → `/faq`
- Contact → `/contact`
- Privacy Policy → `/privacy`
- Terms of Service → `/terms`
- Social links → respective platform profiles

---

## Demo Request Page (`/demo`)

- Headline: "See Owlio in action"
- Short paragraph explaining what happens after request
- Navbar: same as main page

**Form fields:**

| Field | Required | Type |
|-------|----------|------|
| Full Name | Yes | Text |
| Email | Yes | Email |
| School Name | Yes | Text |
| Country | Yes | Dropdown |
| Number of Students | No | Number |
| Message | No | Textarea |

- CTA: **[Request a Demo]**

---

## Login (`/login`)

Redirects to the existing app login page. No new design needed — the app already has a login flow.

---

## Design Notes

- **Brand character:** Owlio owl mascot — used in hero, illustrations, and as brand element throughout
- **Visual style:** Stylized mockups/illustrations (not real screenshots)
- **Tone:** Friendly, educational, playful (Duolingo-inspired) — not corporate/B2B
- **Responsive:** Mobile-first design, single-column on mobile
- **Future expansion:** URL structure supports adding `/schools`, `/blog`, `/research` pages later without restructuring
