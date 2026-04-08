# Owlio Website Improvements — Design Spec

**Date:** 2026-04-08
**Status:** Approved
**Scope:** 14 improvements across forms, SEO, UX, content, and analytics

---

## 1. Form Submission via EmailJS

### Overview
Demo, Contact, and Coming Soon forms will send emails via EmailJS (client-side, free tier: 200 emails/month).

### Dependencies
- `@emailjs/browser` npm package
- EmailJS account with 1 service + 3 templates

### Templates
| Template ID | Fields | Used By |
|------------|--------|---------|
| `demo_request` | name, email, school, country, students, message | `/demo` |
| `contact_message` | name, email, message | `/contact` |
| `notify_launch` | email | AppDownload section |

### Implementation
- **`src/lib/emailjs.ts`** — exports `SERVICE_ID`, `TEMPLATE_*` constants from env vars
- **`.env.local`** — `NEXT_PUBLIC_EMAILJS_SERVICE_ID`, `NEXT_PUBLIC_EMAILJS_PUBLIC_KEY`, `NEXT_PUBLIC_EMAILJS_TEMPLATE_DEMO`, `NEXT_PUBLIC_EMAILJS_TEMPLATE_CONTACT`, `NEXT_PUBLIC_EMAILJS_TEMPLATE_NOTIFY`
- **`demo/page.tsx`** — call `emailjs.send()` in `handleSubmit`, add loading/error states
- **`contact/page.tsx`** — same pattern
- **`AppDownload.tsx`** — email input + "Notify Me" button + `emailjs.send()`

### UX States
- **Loading:** Button text → "Sending...", disabled
- **Success:** Current "Thank you" screen (demo/contact), "You're on the list!" (coming soon)
- **Error:** Red text below form: "Something went wrong. Please try again."

---

## 2. AppDownload → "Coming Soon" + Email Collection

### Overview
Replace store download buttons with a "Coming Soon" section + email signup.

### Content
- Heading: "Coming soon to your phone"
- Subtext: "We're building the Owlio mobile app. Leave your email and we'll let you know when it's ready."
- Single email input + "Notify Me" green button
- After submit: "You're on the list!" confirmation
- Below: "iOS & Android" non-clickable grey badges

### Changes
- Remove `APP_STORE_URL` and `GOOGLE_PLAY_URL` from `constants.ts`
- Rewrite `AppDownload.tsx` entirely
- Remove Apple/Google Play SVG icons, replace with simple grey text badges

---

## 3. SocialProof → Testimonials

### Overview
Replace fake stats with 3 placeholder testimonial cards.

### Layout
- Desktop: 3-column grid
- Mobile: vertical stack
- Each card: quote text (italic), name + role, school name
- Left accent bar per card (feather / sky / fox colors)
- Decorative large quote mark

### Placeholder Data
1. **Ms. Johnson, English Teacher — Greenfield Academy**
   "My students actually ask to practice English now. The streaks and leagues keep them coming back every day."

2. **Mr. Demir, English Teacher — Istanbul International School**
   "Finally a platform that matches our curriculum. I assign books and vocabulary, and Owlio handles the rest."

3. **Sofia, 6th Grade Student**
   "I love collecting cards and competing in leagues. I didn't even realize how much English I was learning!"

### Styling
- `bg-polar` card background, `rounded-2xl`
- Left border: 4px solid accent color
- Large `"` decorative element (feather color, semi-transparent)
- ScrollReveal animation preserved

---

## 4. ForTeachers Dashboard Mockup

### Overview
Replace `placeholder.svg` with a CSS/HTML dashboard mockup component.

### Mockup Content
- Header: "Class 5-A" + "12 Students" badge
- Stat row: "Books Read: 47" | "Avg. Quiz Score: 82%" | "Active Streaks: 9"
- Student table (3 rows):

| Student | Books | Vocabulary | Last Active |
|---------|-------|-----------|-------------|
| Emma S. | 5 | 120 words | Today |
| Liam K. | 3 | 85 words | Yesterday |
| Sofia R. | 4 | 102 words | Today |

### Implementation
- New component: `src/components/home/DashboardMockup.tsx`
- Used inside `ForTeachers.tsx` replacing the `<Image src="/images/placeholder.svg" />` block
- Browser chrome frame (red/yellow/green dots) preserved from current design
- All data hardcoded, non-interactive
- Compact fonts for readability at small size

---

## 5. OG Image

### Overview
Static branded Open Graph image for social media sharing.

### Approach
- `src/app/opengraph-image.tsx` using Next.js `ImageResponse` API
- 1200x630px, green (#58CC02) background
- White Owlio text logo centered
- Tagline: "The fun way to read in English" below logo
- Simple owl icon (simplified SVG version)

### Metadata Updates
- Next.js auto-detects `opengraph-image.tsx` in the `app/` directory — no manual metadata needed in `layout.tsx`
- The file-based convention automatically sets `og:image` and `twitter:image` meta tags

---

## 6. Sitemap + robots.txt

### Sitemap (`src/app/sitemap.ts`)
```
/              — priority 1.0
/about         — priority 0.8
/demo          — priority 0.9
/contact       — priority 0.7
/faq           — priority 0.7
/privacy       — priority 0.3
/terms         — priority 0.3
```
- `/login` excluded (redirect page)
- `changeFrequency: 'monthly'` for all

### robots.txt (`src/app/robots.ts`)
```
User-Agent: *
Allow: /
Disallow: /login
Sitemap: https://owlio.co/sitemap.xml
```

---

## 7. FAQ Accordion

### Overview
Convert static FAQ list to interactive accordion with animation.

### Behavior
- Click question → expand answer with Framer Motion animation
- Only one question open at a time (clicking another closes the current)
- `+` / `−` icon indicator on the right side
- Smooth height animation via `AnimatePresence` + `motion.div`

### Data
- Same `faqs` array, no data changes
- Component refactored to `FAQAccordionItem` sub-component

---

## 8. FAQ JSON-LD Structured Data

### Overview
Add FAQPage schema markup for Google rich snippets.

### Implementation
- `faq/page.tsx`: add `<script type="application/ld+json">` in the page
- Schema type: `FAQPage` with `mainEntity` array of `Question` + `acceptedAnswer`
- Generated from the same `faqs` data array

---

## 9. Login Server-Side Redirect

### Overview
Replace client-side `window.location.href` with Next.js server-side redirect.

### Implementation
- `login/page.tsx` becomes a server component
- Uses `redirect(APP_LOGIN_URL)` from `next/navigation`
- Remove `"use client"`, `useEffect`, and fallback UI
- Instant redirect, no flash of content

---

## 10. 404 Page

### Overview
Branded not-found page consistent with Owlio's playful style.

### Content
- Large Owlio owl logo (centered)
- Heading: "Oops! This page flew away"
- Subtext: "The page you're looking for doesn't exist."
- "Go Home" button (`variant="green"`, links to `/`)

### Implementation
- `src/app/not-found.tsx`

---

## 11. Privacy Policy Expansion

### New Sections
1. Information We Collect (account data, usage data, device info)
2. How We Use Your Information (expanded)
3. Children's Privacy (COPPA/KVKK, under-13, school/teacher consent)
4. Data Retention
5. Data Sharing (analytics, hosting providers)
6. Data Security (encryption, access controls)
7. Your Rights (deletion, correction requests)
8. Cookies
9. Changes to This Policy
10. Contact (privacy@owlio.co)

> Note: This is a reasonable starting template, not legal advice. Professional legal review recommended before launch.

---

## 12. Terms of Service Expansion

### New Sections
1. Eligibility (school accounts, age requirements)
2. Account Responsibilities (teacher/school account management)
3. Acceptable Use (prohibited behaviors)
4. Intellectual Property (content rights)
5. Termination (account closure conditions)
6. Limitation of Liability
7. Governing Law
8. Contact (legal@owlio.co)

> Note: Same disclaimer as Privacy — legal review recommended.

---

## 13. Vercel Analytics

### Implementation
- Install `@vercel/analytics`
- Add `<Analytics />` component to `layout.tsx` inside `<body>`
- Auto-activates on Vercel deployment
- Zero config beyond the import

---

## 14. Mobile Menu Animation

### Overview
Animate the mobile navigation dropdown instead of instant show/hide.

### Implementation
- Wrap mobile dropdown in Framer Motion `AnimatePresence`
- `motion.div` with slide-down animation:
  - Enter: `height: 0 → auto`, `opacity: 0 → 1`
  - Exit: reverse
- Replace `{mobileOpen && <div>` conditional with `AnimatePresence` pattern
- Duration: ~200ms ease-out

---

## Files Changed Summary

### New Files
- `src/lib/emailjs.ts`
- `src/components/home/DashboardMockup.tsx`
- `src/app/opengraph-image.tsx`
- `src/app/sitemap.ts`
- `src/app/robots.ts`
- `src/app/not-found.tsx`
- `.env.local` (gitignored)
- `.env.example` (committed, with placeholder values)

### Modified Files
- `src/app/layout.tsx` — OG metadata + Vercel Analytics
- `src/app/page.tsx` — no changes (imports unchanged)
- `src/components/home/AppDownload.tsx` — full rewrite (Coming Soon)
- `src/components/home/SocialProof.tsx` — full rewrite (Testimonials)
- `src/components/home/ForTeachers.tsx` — replace placeholder with DashboardMockup
- `src/components/home/FinalCTA.tsx` — no changes
- `src/components/layout/Navbar.tsx` — mobile menu animation
- `src/app/demo/page.tsx` — EmailJS integration
- `src/app/contact/page.tsx` — EmailJS integration
- `src/app/login/page.tsx` — server-side redirect
- `src/app/faq/page.tsx` — accordion + JSON-LD
- `src/app/privacy/page.tsx` — content expansion
- `src/app/terms/page.tsx` — content expansion
- `src/lib/constants.ts` — remove store URLs, keep other constants
- `package.json` — add `@emailjs/browser`, `@vercel/analytics`

### Deleted Assets
- `public/images/placeholder.svg` (replaced by DashboardMockup component)

---

## Out of Scope
- Blog infrastructure
- Pricing page
- Real testimonials (placeholder only)
- Domain purchase/DNS setup
- EmailJS account creation (user will do this)
- Vercel project setup
- Actual app screenshots (CSS mockup instead)
