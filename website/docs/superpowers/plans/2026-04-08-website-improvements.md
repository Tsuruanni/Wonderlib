# Owlio Website Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship 14 website improvements covering form submission, SEO, UX, content, and analytics.

**Architecture:** All changes are independent, leaf-level modifications to existing Next.js 16 app. No shared state between tasks. EmailJS handles forms client-side. Next.js file conventions handle SEO (sitemap.ts, robots.ts, opengraph-image.tsx). Framer Motion handles animations.

**Tech Stack:** Next.js 16.2.1, React 19, Tailwind CSS 4, Framer Motion 12, EmailJS, Vercel Analytics

**Spec:** `docs/superpowers/specs/2026-04-08-website-improvements-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `src/lib/emailjs.ts` | EmailJS config constants from env vars |
| `.env.example` | Placeholder env vars (committed) |
| `src/components/home/DashboardMockup.tsx` | CSS teacher dashboard mockup |
| `src/app/opengraph-image.tsx` | Dynamic OG image via ImageResponse |
| `src/app/sitemap.ts` | XML sitemap generation |
| `src/app/robots.ts` | robots.txt generation |
| `src/app/not-found.tsx` | Custom 404 page |

### Modified Files
| File | Change |
|------|--------|
| `package.json` | Add `@emailjs/browser`, `@vercel/analytics` |
| `src/lib/constants.ts` | Remove `APP_STORE_URL`, `GOOGLE_PLAY_URL` |
| `src/app/layout.tsx` | Add Vercel Analytics component |
| `src/app/demo/page.tsx` | EmailJS integration + loading/error states |
| `src/app/contact/page.tsx` | EmailJS integration + loading/error states |
| `src/components/home/AppDownload.tsx` | Full rewrite → Coming Soon + email |
| `src/components/home/SocialProof.tsx` | Full rewrite → Testimonials |
| `src/components/home/ForTeachers.tsx` | Replace placeholder with DashboardMockup |
| `src/components/layout/Navbar.tsx` | Animated mobile menu |
| `src/app/faq/page.tsx` | Accordion + JSON-LD |
| `src/app/login/page.tsx` | Server-side redirect |
| `src/app/privacy/page.tsx` | Content expansion |
| `src/app/terms/page.tsx` | Content expansion |

### Deleted Files
| File | Reason |
|------|--------|
| `public/images/placeholder.svg` | Replaced by DashboardMockup component |

---

## Task 1: Install dependencies and create EmailJS config

**Files:**
- Modify: `package.json`
- Create: `src/lib/emailjs.ts`
- Create: `.env.example`

- [ ] **Step 1: Install packages**

```bash
cd /Users/wonderelt/Desktop/Owlio/website && npm install @emailjs/browser @vercel/analytics
```

- [ ] **Step 2: Create EmailJS config**

Create `src/lib/emailjs.ts`:

```ts
export const EMAILJS_SERVICE_ID = process.env.NEXT_PUBLIC_EMAILJS_SERVICE_ID ?? "";
export const EMAILJS_PUBLIC_KEY = process.env.NEXT_PUBLIC_EMAILJS_PUBLIC_KEY ?? "";
export const EMAILJS_TEMPLATE_DEMO = process.env.NEXT_PUBLIC_EMAILJS_TEMPLATE_DEMO ?? "";
export const EMAILJS_TEMPLATE_CONTACT = process.env.NEXT_PUBLIC_EMAILJS_TEMPLATE_CONTACT ?? "";
export const EMAILJS_TEMPLATE_NOTIFY = process.env.NEXT_PUBLIC_EMAILJS_TEMPLATE_NOTIFY ?? "";
```

- [ ] **Step 3: Create .env.example**

Create `.env.example`:

```
NEXT_PUBLIC_EMAILJS_SERVICE_ID=your_service_id
NEXT_PUBLIC_EMAILJS_PUBLIC_KEY=your_public_key
NEXT_PUBLIC_EMAILJS_TEMPLATE_DEMO=your_demo_template_id
NEXT_PUBLIC_EMAILJS_TEMPLATE_CONTACT=your_contact_template_id
NEXT_PUBLIC_EMAILJS_TEMPLATE_NOTIFY=your_notify_template_id
```

- [ ] **Step 4: Verify build**

```bash
cd /Users/wonderelt/Desktop/Owlio/website && npx next build 2>&1 | tail -20
```

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add package.json package-lock.json src/lib/emailjs.ts .env.example
git commit -m "chore: install emailjs + vercel analytics, add emailjs config"
```

---

## Task 2: Demo page EmailJS integration

**Files:**
- Modify: `src/app/demo/page.tsx`

- [ ] **Step 1: Rewrite demo page with EmailJS**

Replace the full content of `src/app/demo/page.tsx`:

```tsx
"use client";

import { useState, type FormEvent } from "react";
import emailjs from "@emailjs/browser";
import { Container } from "@/components/ui/Container";
import { Button } from "@/components/ui/Button";
import {
  EMAILJS_SERVICE_ID,
  EMAILJS_PUBLIC_KEY,
  EMAILJS_TEMPLATE_DEMO,
} from "@/lib/emailjs";

const countries = [
  "Turkey",
  "United States",
  "United Kingdom",
  "Germany",
  "France",
  "Netherlands",
  "Spain",
  "Italy",
  "Japan",
  "South Korea",
  "Brazil",
  "Other",
];

export default function DemoPage() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("sending");

    const form = e.currentTarget;
    const data = {
      name: (form.elements.namedItem("name") as HTMLInputElement).value,
      email: (form.elements.namedItem("email") as HTMLInputElement).value,
      school: (form.elements.namedItem("school") as HTMLInputElement).value,
      country: (form.elements.namedItem("country") as HTMLSelectElement).value,
      students: (form.elements.namedItem("students") as HTMLInputElement).value || "N/A",
      message: (form.elements.namedItem("message") as HTMLTextAreaElement).value || "N/A",
    };

    try {
      await emailjs.send(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_DEMO, data, EMAILJS_PUBLIC_KEY);
      setStatus("sent");
    } catch {
      setStatus("error");
    }
  }

  if (status === "sent") {
    return (
      <div className="py-20 md:py-28">
        <Container className="max-w-lg text-center">
          <div className="text-6xl mb-6">🦉</div>
          <h1 className="text-3xl font-black text-eel mb-4">Thank you!</h1>
          <p className="text-lg text-hare">
            We&apos;ve received your request. Our team will reach out to you
            within 24 hours to schedule a demo.
          </p>
        </Container>
      </div>
    );
  }

  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-lg">
        <div className="text-center mb-10">
          <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
            See Owlio in action
          </h1>
          <p className="text-hare">
            Fill in the form below and we&apos;ll get back to you within 24
            hours to schedule a personalized demo.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label htmlFor="name" className="block text-sm font-bold text-eel mb-1">
              Full Name <span className="text-cardinal">*</span>
            </label>
            <input
              id="name"
              name="name"
              type="text"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
              placeholder="Jane Smith"
            />
          </div>

          <div>
            <label htmlFor="email" className="block text-sm font-bold text-eel mb-1">
              Email <span className="text-cardinal">*</span>
            </label>
            <input
              id="email"
              name="email"
              type="email"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
              placeholder="jane@school.edu"
            />
          </div>

          <div>
            <label htmlFor="school" className="block text-sm font-bold text-eel mb-1">
              School Name <span className="text-cardinal">*</span>
            </label>
            <input
              id="school"
              name="school"
              type="text"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
              placeholder="Springfield Elementary"
            />
          </div>

          <div>
            <label htmlFor="country" className="block text-sm font-bold text-eel mb-1">
              Country <span className="text-cardinal">*</span>
            </label>
            <select
              id="country"
              name="country"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel focus:border-sky focus:outline-none transition-colors bg-snow"
            >
              <option value="">Select your country</option>
              {countries.map((c) => (
                <option key={c} value={c}>{c}</option>
              ))}
            </select>
          </div>

          <div>
            <label htmlFor="students" className="block text-sm font-bold text-eel mb-1">
              Number of Students <span className="text-hare font-normal">(optional)</span>
            </label>
            <input
              id="students"
              name="students"
              type="number"
              min={1}
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
              placeholder="150"
            />
          </div>

          <div>
            <label htmlFor="message" className="block text-sm font-bold text-eel mb-1">
              Message <span className="text-hare font-normal">(optional)</span>
            </label>
            <textarea
              id="message"
              name="message"
              rows={3}
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors resize-none"
              placeholder="Tell us about your school or what you'd like to see"
            />
          </div>

          <Button
            type="submit"
            variant="green"
            size="lg"
            className={`w-full ${status === "sending" ? "opacity-70 pointer-events-none" : ""}`}
          >
            {status === "sending" ? "Sending..." : "Request a Demo"}
          </Button>

          {status === "error" && (
            <p className="text-sm text-cardinal text-center">
              Something went wrong. Please try again.
            </p>
          )}
        </form>
      </Container>
    </div>
  );
}
```

- [ ] **Step 2: Verify dev server renders**

```bash
cd /Users/wonderelt/Desktop/Owlio/website && npm run dev &
sleep 3 && curl -s http://localhost:3000/demo | head -5
```

Expected: HTML output (page renders without crash).

- [ ] **Step 3: Commit**

```bash
git add src/app/demo/page.tsx
git commit -m "feat: integrate EmailJS in demo request form"
```

---

## Task 3: Contact page EmailJS integration

**Files:**
- Modify: `src/app/contact/page.tsx`

- [ ] **Step 1: Rewrite contact page with EmailJS**

Replace the full content of `src/app/contact/page.tsx`:

```tsx
"use client";

import { useState, type FormEvent } from "react";
import emailjs from "@emailjs/browser";
import { Container } from "@/components/ui/Container";
import { Button } from "@/components/ui/Button";
import {
  EMAILJS_SERVICE_ID,
  EMAILJS_PUBLIC_KEY,
  EMAILJS_TEMPLATE_CONTACT,
} from "@/lib/emailjs";

export default function ContactPage() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("sending");

    const form = e.currentTarget;
    const data = {
      name: (form.elements.namedItem("name") as HTMLInputElement).value,
      email: (form.elements.namedItem("email") as HTMLInputElement).value,
      message: (form.elements.namedItem("message") as HTMLTextAreaElement).value,
    };

    try {
      await emailjs.send(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_CONTACT, data, EMAILJS_PUBLIC_KEY);
      setStatus("sent");
    } catch {
      setStatus("error");
    }
  }

  if (status === "sent") {
    return (
      <div className="py-20 md:py-28">
        <Container className="max-w-lg text-center">
          <div className="text-6xl mb-6">📬</div>
          <h1 className="text-3xl font-black text-eel mb-4">Message sent!</h1>
          <p className="text-lg text-hare">
            Thanks for reaching out. We&apos;ll get back to you as soon as
            possible.
          </p>
        </Container>
      </div>
    );
  }

  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-lg">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Contact us
        </h1>
        <p className="text-hare mb-10">
          Have a question or want to learn more? Drop us a message.
        </p>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label htmlFor="name" className="block text-sm font-bold text-eel mb-1">
              Name <span className="text-cardinal">*</span>
            </label>
            <input
              id="name"
              name="name"
              type="text"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
            />
          </div>

          <div>
            <label htmlFor="email" className="block text-sm font-bold text-eel mb-1">
              Email <span className="text-cardinal">*</span>
            </label>
            <input
              id="email"
              name="email"
              type="email"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
            />
          </div>

          <div>
            <label htmlFor="message" className="block text-sm font-bold text-eel mb-1">
              Message <span className="text-cardinal">*</span>
            </label>
            <textarea
              id="message"
              name="message"
              rows={5}
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors resize-none"
            />
          </div>

          <Button
            type="submit"
            variant="green"
            size="lg"
            className={`w-full ${status === "sending" ? "opacity-70 pointer-events-none" : ""}`}
          >
            {status === "sending" ? "Sending..." : "Send Message"}
          </Button>

          {status === "error" && (
            <p className="text-sm text-cardinal text-center">
              Something went wrong. Please try again.
            </p>
          )}
        </form>
      </Container>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/app/contact/page.tsx
git commit -m "feat: integrate EmailJS in contact form"
```

---

## Task 4: SocialProof → Testimonials

**Files:**
- Modify: `src/components/home/SocialProof.tsx`

- [ ] **Step 1: Rewrite SocialProof as Testimonials**

Replace the full content of `src/components/home/SocialProof.tsx`:

```tsx
"use client";

import { Container } from "@/components/ui/Container";
import { ScrollReveal } from "@/components/ui/ScrollReveal";

interface Testimonial {
  quote: string;
  name: string;
  role: string;
  school?: string;
  accent: string;
}

const testimonials: Testimonial[] = [
  {
    quote:
      "My students actually ask to practice English now. The streaks and leagues keep them coming back every day.",
    name: "Ms. Johnson",
    role: "English Teacher",
    school: "Greenfield Academy",
    accent: "border-l-feather",
  },
  {
    quote:
      "Finally a platform that matches our curriculum. I assign books and vocabulary, and Owlio handles the rest.",
    name: "Mr. Demir",
    role: "English Teacher",
    school: "Istanbul International School",
    accent: "border-l-sky",
  },
  {
    quote:
      "I love collecting cards and competing in leagues. I didn't even realize how much English I was learning!",
    name: "Sofia",
    role: "6th Grade Student",
    accent: "border-l-fox",
  },
];

export function SocialProof() {
  return (
    <section className="py-12 md:py-16">
      <Container>
        <ScrollReveal>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {testimonials.map((t) => (
              <div
                key={t.name}
                className={`relative bg-polar rounded-2xl border-l-4 ${t.accent} p-6`}
              >
                <span className="absolute top-3 left-5 text-5xl font-black text-feather/10 leading-none select-none">
                  &ldquo;
                </span>
                <p className="relative text-eel italic leading-relaxed mb-4 pt-4">
                  {t.quote}
                </p>
                <div>
                  <p className="text-sm font-bold text-eel">{t.name}</p>
                  <p className="text-xs text-hare">
                    {t.role}
                    {t.school && ` — ${t.school}`}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </ScrollReveal>
      </Container>
    </section>
  );
}
```

- [ ] **Step 2: Verify renders**

Open `http://localhost:3000` — the stats row should now show 3 testimonial cards.

- [ ] **Step 3: Commit**

```bash
git add src/components/home/SocialProof.tsx
git commit -m "feat: replace social proof stats with testimonial cards"
```

---

## Task 5: AppDownload → Coming Soon + Email

**Files:**
- Modify: `src/components/home/AppDownload.tsx`

- [ ] **Step 1: Rewrite AppDownload as Coming Soon**

Replace the full content of `src/components/home/AppDownload.tsx`:

```tsx
"use client";

import { useState, type FormEvent } from "react";
import emailjs from "@emailjs/browser";
import { Container } from "@/components/ui/Container";
import { ScrollReveal } from "@/components/ui/ScrollReveal";
import { Button } from "@/components/ui/Button";
import {
  EMAILJS_SERVICE_ID,
  EMAILJS_PUBLIC_KEY,
  EMAILJS_TEMPLATE_NOTIFY,
} from "@/lib/emailjs";

export function AppDownload() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("sending");

    const form = e.currentTarget;
    const data = {
      email: (form.elements.namedItem("notify-email") as HTMLInputElement).value,
    };

    try {
      await emailjs.send(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_NOTIFY, data, EMAILJS_PUBLIC_KEY);
      setStatus("sent");
    } catch {
      setStatus("error");
    }
  }

  return (
    <section className="relative py-16 md:py-24 bg-polar overflow-hidden">
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-0 left-1/4 w-40 h-40 bg-feather/5 rounded-full blur-2xl" />
        <div className="absolute bottom-0 right-1/4 w-32 h-32 bg-sky/5 rounded-full blur-2xl" />
      </div>

      <Container className="relative text-center">
        <ScrollReveal>
          <div className="inline-flex items-center gap-2 bg-snow rounded-full px-4 py-2 shadow-[0_2px_0_#E5E5E5] mb-6">
            <span className="text-xl">📱</span>
            <span className="text-sm font-bold text-hare uppercase tracking-wider">
              Coming Soon
            </span>
          </div>
          <h2 className="text-3xl md:text-4xl font-black text-eel mb-4 tracking-tight">
            Coming soon to your phone
          </h2>
          <p className="text-lg text-hare mb-8 max-w-lg mx-auto leading-relaxed">
            We&apos;re building the Owlio mobile app. Leave your email and
            we&apos;ll let you know when it&apos;s ready.
          </p>

          {status === "sent" ? (
            <div className="flex items-center justify-center gap-2 text-feather font-bold">
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                <circle cx="10" cy="10" r="10" fill="currentColor" opacity="0.15" />
                <path d="M6 10l3 3 5-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              You&apos;re on the list!
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
              <input
                id="notify-email"
                name="notify-email"
                type="email"
                required
                placeholder="your@email.com"
                className="flex-1 rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
              />
              <Button
                type="submit"
                variant="green"
                size="lg"
                className={status === "sending" ? "opacity-70 pointer-events-none" : ""}
              >
                {status === "sending" ? "..." : "Notify Me"}
              </Button>
            </form>
          )}

          {status === "error" && (
            <p className="text-sm text-cardinal mt-3">
              Something went wrong. Please try again.
            </p>
          )}

          <div className="flex justify-center gap-4 mt-8">
            <span className="inline-flex items-center gap-1.5 text-sm font-bold text-hare bg-swan/50 rounded-full px-4 py-1.5">
              iOS
            </span>
            <span className="inline-flex items-center gap-1.5 text-sm font-bold text-hare bg-swan/50 rounded-full px-4 py-1.5">
              Android
            </span>
          </div>
        </ScrollReveal>
      </Container>
    </section>
  );
}
```

- [ ] **Step 2: Remove store URLs from constants.ts**

Edit `src/lib/constants.ts` — remove the `APP_STORE_URL` and `GOOGLE_PLAY_URL` lines. Final file:

```ts
export const APP_LOGIN_URL = "https://app.owlio.com/login";

export const SOCIAL_LINKS = {
  instagram: "https://instagram.com/owlio",
  tiktok: "https://tiktok.com/@owlio",
  twitter: "https://twitter.com/owlio",
  youtube: "https://youtube.com/@owlio",
  linkedin: "https://linkedin.com/company/owlio",
} as const;
```

- [ ] **Step 3: Verify build compiles**

```bash
cd /Users/wonderelt/Desktop/Owlio/website && npx next build 2>&1 | tail -5
```

Expected: Build succeeds (AppDownload no longer imports store URLs, constants are removed).

- [ ] **Step 4: Commit**

```bash
git add src/components/home/AppDownload.tsx src/lib/constants.ts
git commit -m "feat: convert app download to coming soon with email notify"
```

---

## Task 6: ForTeachers Dashboard Mockup

**Files:**
- Create: `src/components/home/DashboardMockup.tsx`
- Modify: `src/components/home/ForTeachers.tsx`

- [ ] **Step 1: Create DashboardMockup component**

Create `src/components/home/DashboardMockup.tsx`:

```tsx
export function DashboardMockup() {
  const students = [
    { name: "Emma S.", books: 5, vocab: "120 words", active: "Today" },
    { name: "Liam K.", books: 3, vocab: "85 words", active: "Yesterday" },
    { name: "Sofia R.", books: 4, vocab: "102 words", active: "Today" },
  ];

  return (
    <div className="text-left select-none">
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-black text-eel">Class 5-A</h3>
        <span className="text-[10px] font-bold text-sky bg-sky/10 px-2 py-0.5 rounded-full">
          12 Students
        </span>
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-3 gap-2 mb-3">
        {[
          { label: "Books Read", value: "47", color: "text-feather" },
          { label: "Avg. Quiz", value: "82%", color: "text-sky" },
          { label: "Streaks", value: "9", color: "text-fox" },
        ].map((stat) => (
          <div
            key={stat.label}
            className="bg-polar rounded-lg p-2 text-center"
          >
            <div className={`text-lg font-black ${stat.color}`}>
              {stat.value}
            </div>
            <div className="text-[9px] font-bold text-hare uppercase tracking-wider">
              {stat.label}
            </div>
          </div>
        ))}
      </div>

      {/* Student table */}
      <table className="w-full text-[11px]">
        <thead>
          <tr className="text-left text-hare uppercase tracking-wider border-b border-swan">
            <th className="pb-1.5 font-bold">Student</th>
            <th className="pb-1.5 font-bold">Books</th>
            <th className="pb-1.5 font-bold">Vocab</th>
            <th className="pb-1.5 font-bold">Active</th>
          </tr>
        </thead>
        <tbody>
          {students.map((s) => (
            <tr key={s.name} className="border-b border-swan/50">
              <td className="py-1.5 font-bold text-eel">{s.name}</td>
              <td className="py-1.5 text-hare">{s.books}</td>
              <td className="py-1.5 text-hare">{s.vocab}</td>
              <td className="py-1.5">
                <span
                  className={`text-[10px] font-bold ${
                    s.active === "Today" ? "text-feather" : "text-hare"
                  }`}
                >
                  {s.active}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 2: Replace placeholder in ForTeachers**

Edit `src/components/home/ForTeachers.tsx`:

Remove the `import Image from "next/image";` line.

Add import:
```tsx
import { DashboardMockup } from "@/components/home/DashboardMockup";
```

Replace the `<Image>` block inside the browser frame:
```tsx
// FIND THIS:
              <Image
                src="/images/placeholder.svg"
                alt="Teacher dashboard preview"
                width={440}
                height={320}
              />

// REPLACE WITH:
              <DashboardMockup />
```

- [ ] **Step 3: Delete placeholder.svg**

```bash
rm /Users/wonderelt/Desktop/Owlio/website/public/images/placeholder.svg
```

- [ ] **Step 4: Commit**

```bash
git add src/components/home/DashboardMockup.tsx src/components/home/ForTeachers.tsx
git rm public/images/placeholder.svg
git commit -m "feat: replace placeholder with CSS dashboard mockup in ForTeachers"
```

---

## Task 7: OG Image

**Files:**
- Create: `src/app/opengraph-image.tsx`

- [ ] **Step 1: Create OG image file**

Create `src/app/opengraph-image.tsx`:

```tsx
import { ImageResponse } from "next/og";

export const alt = "Owlio — The fun way to read in English";

export const size = {
  width: 1200,
  height: 630,
};

export const contentType = "image/png";

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          background: "#58CC02",
          fontFamily: "sans-serif",
        }}
      >
        {/* Owl eyes */}
        <div style={{ display: "flex", gap: "8px", marginBottom: "16px" }}>
          <div
            style={{
              width: "64px",
              height: "64px",
              borderRadius: "50%",
              background: "white",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <div
              style={{
                width: "32px",
                height: "32px",
                borderRadius: "50%",
                background: "#4B4B4B",
              }}
            />
          </div>
          <div
            style={{
              width: "64px",
              height: "64px",
              borderRadius: "50%",
              background: "white",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <div
              style={{
                width: "32px",
                height: "32px",
                borderRadius: "50%",
                background: "#4B4B4B",
              }}
            />
          </div>
        </div>
        <div
          style={{
            fontSize: "72px",
            fontWeight: "900",
            color: "white",
            letterSpacing: "-0.02em",
            marginBottom: "8px",
          }}
        >
          owlio
        </div>
        <div
          style={{
            fontSize: "28px",
            fontWeight: "700",
            color: "rgba(255,255,255,0.85)",
          }}
        >
          The fun way to read in English
        </div>
      </div>
    ),
    { ...size }
  );
}
```

- [ ] **Step 2: Verify OG image generates**

```bash
cd /Users/wonderelt/Desktop/Owlio/website && curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/opengraph-image
```

Expected: `200`

- [ ] **Step 3: Commit**

```bash
git add src/app/opengraph-image.tsx
git commit -m "feat: add dynamic OG image with Owlio branding"
```

---

## Task 8: Sitemap + robots.txt

**Files:**
- Create: `src/app/sitemap.ts`
- Create: `src/app/robots.ts`

- [ ] **Step 1: Create sitemap.ts**

Create `src/app/sitemap.ts`:

```ts
import type { MetadataRoute } from "next";

const BASE_URL = "https://owlio.co";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: BASE_URL, lastModified: new Date(), changeFrequency: "monthly", priority: 1 },
    { url: `${BASE_URL}/about`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.8 },
    { url: `${BASE_URL}/demo`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.9 },
    { url: `${BASE_URL}/contact`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.7 },
    { url: `${BASE_URL}/faq`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.7 },
    { url: `${BASE_URL}/privacy`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.3 },
    { url: `${BASE_URL}/terms`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.3 },
  ];
}
```

- [ ] **Step 2: Create robots.ts**

Create `src/app/robots.ts`:

```ts
import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: "/login",
    },
    sitemap: "https://owlio.co/sitemap.xml",
  };
}
```

- [ ] **Step 3: Verify endpoints**

```bash
curl -s http://localhost:3000/sitemap.xml | head -10
curl -s http://localhost:3000/robots.txt
```

Expected: Valid XML sitemap and robots.txt output.

- [ ] **Step 4: Commit**

```bash
git add src/app/sitemap.ts src/app/robots.ts
git commit -m "feat: add sitemap.xml and robots.txt"
```

---

## Task 9: FAQ Accordion + JSON-LD

**Files:**
- Modify: `src/app/faq/page.tsx`

- [ ] **Step 1: Rewrite FAQ page with accordion and JSON-LD**

Replace the full content of `src/app/faq/page.tsx`:

```tsx
"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Container } from "@/components/ui/Container";

interface FAQItem {
  question: string;
  answer: string;
}

const faqs: FAQItem[] = [
  {
    question: "What is Owlio?",
    answer:
      "Owlio is a gamified reading and vocabulary platform designed for schools. Students read curriculum-aligned books, practice vocabulary with spaced repetition, and stay motivated with game-like features like streaks, badges, and leaderboards.",
  },
  {
    question: "Is Owlio free for teachers?",
    answer:
      "Owlio is free for teachers and schools during our early access period. Request a demo to get started with your class.",
  },
  {
    question: "Which curricula does Owlio support?",
    answer:
      "Owlio works with any English reading curriculum. Teachers can assign specific books and vocabulary lists that match their class syllabus.",
  },
  {
    question: "How does spaced repetition work?",
    answer:
      "Owlio uses the SM-2 algorithm — the same system used by the world's best flashcard apps. It calculates the optimal time to review each word based on how well the student remembers it, maximizing long-term retention.",
  },
  {
    question: "Can students use Owlio at home?",
    answer:
      "Yes! Students can use Owlio on any device — phone, tablet, or computer. Progress syncs automatically, so they can practice at school and continue at home.",
  },
  {
    question: "How do I get started?",
    answer:
      "Request a demo through our website and our team will help you set up your classes. Students can start reading within minutes.",
  },
];

function FAQAccordionItem({
  faq,
  isOpen,
  onToggle,
}: {
  faq: FAQItem;
  isOpen: boolean;
  onToggle: () => void;
}) {
  return (
    <div className="border-b border-swan">
      <button
        onClick={onToggle}
        className="w-full flex items-center justify-between py-5 text-left cursor-pointer"
      >
        <h2 className="text-lg font-bold text-eel pr-4">{faq.question}</h2>
        <span className="flex-shrink-0 w-6 h-6 flex items-center justify-center text-hare text-xl font-bold">
          {isOpen ? "\u2212" : "+"}
        </span>
      </button>
      <AnimatePresence initial={false}>
        {isOpen && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2, ease: "easeOut" }}
            className="overflow-hidden"
          >
            <p className="text-hare leading-relaxed pb-5">{faq.answer}</p>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function FAQPage() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs.map((faq) => ({
      "@type": "Question",
      name: faq.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: faq.answer,
      },
    })),
  };

  return (
    <div className="py-16 md:py-24">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-10">
          Frequently Asked Questions
        </h1>

        <div>
          {faqs.map((faq, i) => (
            <FAQAccordionItem
              key={faq.question}
              faq={faq}
              isOpen={openIndex === i}
              onToggle={() => setOpenIndex(openIndex === i ? null : i)}
            />
          ))}
        </div>
      </Container>
    </div>
  );
}
```

- [ ] **Step 2: Verify JSON-LD renders**

```bash
curl -s http://localhost:3000/faq | grep -o 'application/ld+json' | head -1
```

Expected: `application/ld+json`

- [ ] **Step 3: Commit**

```bash
git add src/app/faq/page.tsx
git commit -m "feat: convert FAQ to accordion with JSON-LD structured data"
```

---

## Task 10: Login Server-Side Redirect

**Files:**
- Modify: `src/app/login/page.tsx`

- [ ] **Step 1: Rewrite as server-side redirect**

Replace the full content of `src/app/login/page.tsx`:

```tsx
import { redirect } from "next/navigation";
import { APP_LOGIN_URL } from "@/lib/constants";

export default function LoginPage() {
  redirect(APP_LOGIN_URL);
}
```

- [ ] **Step 2: Commit**

```bash
git add src/app/login/page.tsx
git commit -m "fix: use server-side redirect for login page"
```

---

## Task 11: 404 Page

**Files:**
- Create: `src/app/not-found.tsx`

- [ ] **Step 1: Create not-found page**

Create `src/app/not-found.tsx`:

```tsx
import { Container } from "@/components/ui/Container";
import { OwlLogo } from "@/components/ui/OwlLogo";
import { Button } from "@/components/ui/Button";

export default function NotFound() {
  return (
    <div className="py-20 md:py-28">
      <Container className="text-center">
        <OwlLogo size={96} className="mx-auto mb-6" />
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-4">
          Oops! This page flew away
        </h1>
        <p className="text-lg text-hare mb-8">
          The page you&apos;re looking for doesn&apos;t exist.
        </p>
        <Button variant="green" size="lg" href="/">
          Go Home
        </Button>
      </Container>
    </div>
  );
}
```

- [ ] **Step 2: Verify renders**

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/this-page-does-not-exist
```

Expected: `404`

- [ ] **Step 3: Commit**

```bash
git add src/app/not-found.tsx
git commit -m "feat: add branded 404 page"
```

---

## Task 12: Mobile Menu Animation

**Files:**
- Modify: `src/components/layout/Navbar.tsx`

- [ ] **Step 1: Add animated mobile menu**

Replace the full content of `src/components/layout/Navbar.tsx`:

```tsx
"use client";

import { useState } from "react";
import Link from "next/link";
import { motion, AnimatePresence } from "framer-motion";
import { Container } from "@/components/ui/Container";
import { OwlLogo } from "@/components/ui/OwlLogo";

export function Navbar() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <nav className="sticky top-0 z-50 bg-snow/95 backdrop-blur-sm border-b border-swan">
      <Container className="flex items-center justify-between h-16">
        <Link href="/" className="flex items-center gap-1.5">
          <OwlLogo size={34} />
          <span className="text-2xl font-black text-feather tracking-tight">
            owlio
          </span>
        </Link>

        {/* Desktop nav */}
        <div className="hidden sm:flex items-center gap-6">
          <Link
            href="/#for-teachers"
            className="text-sm font-bold uppercase tracking-wider text-hare hover:text-eel transition-colors"
          >
            For Teachers
          </Link>
          <Link
            href="/login"
            className="rounded-duo border-2 border-swan bg-snow px-5 py-2 text-sm font-extrabold uppercase tracking-wider text-sky shadow-[0_2px_0_#E5E5E5] hover:bg-polar hover:border-[#CECECE] hover:shadow-[0_2px_0_#CECECE] active:shadow-none active:translate-y-[2px] transition-all duration-100"
          >
            Log in
          </Link>
        </div>

        {/* Mobile hamburger */}
        <button
          onClick={() => setMobileOpen(!mobileOpen)}
          className="sm:hidden flex flex-col gap-1.5 p-2"
          aria-label="Toggle menu"
        >
          <span
            className={`block w-6 h-0.5 bg-eel transition-transform duration-200 ${
              mobileOpen ? "rotate-45 translate-y-2" : ""
            }`}
          />
          <span
            className={`block w-6 h-0.5 bg-eel transition-opacity duration-200 ${
              mobileOpen ? "opacity-0" : ""
            }`}
          />
          <span
            className={`block w-6 h-0.5 bg-eel transition-transform duration-200 ${
              mobileOpen ? "-rotate-45 -translate-y-2" : ""
            }`}
          />
        </button>
      </Container>

      {/* Mobile dropdown */}
      <AnimatePresence>
        {mobileOpen && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2, ease: "easeOut" }}
            className="sm:hidden overflow-hidden border-t border-swan bg-snow"
          >
            <Container className="py-4 flex flex-col gap-4">
              <Link
                href="/#for-teachers"
                onClick={() => setMobileOpen(false)}
                className="text-sm font-bold uppercase tracking-wider text-hare"
              >
                For Teachers
              </Link>
              <Link
                href="/login"
                onClick={() => setMobileOpen(false)}
                className="rounded-duo border-2 border-swan bg-snow px-5 py-2 text-sm font-extrabold uppercase tracking-wider text-sky shadow-[0_2px_0_#E5E5E5] text-center"
              >
                Log in
              </Link>
            </Container>
          </motion.div>
        )}
      </AnimatePresence>
    </nav>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/layout/Navbar.tsx
git commit -m "feat: animate mobile navigation menu"
```

---

## Task 13: Privacy Policy + Terms Expansion

**Files:**
- Modify: `src/app/privacy/page.tsx`
- Modify: `src/app/terms/page.tsx`

- [ ] **Step 1: Expand Privacy Policy**

Replace the full content of `src/app/privacy/page.tsx`:

```tsx
import { Container } from "@/components/ui/Container";

export default function PrivacyPage() {
  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Privacy Policy
        </h1>
        <p className="text-sm text-hare mb-10">Last updated: April 2026</p>

        <div className="space-y-8 text-hare leading-relaxed">
          <p>
            Owlio (&quot;we&quot;, &quot;our&quot;, &quot;us&quot;) is committed
            to protecting the privacy of our users — especially our youngest
            learners. This Privacy Policy explains how we collect, use, and
            safeguard your information when you use the Owlio platform.
          </p>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              Information We Collect
            </h2>
            <p className="mb-3">
              <strong className="text-eel">Account Information:</strong> When a
              school or teacher creates accounts, we collect student names,
              usernames, and class assignments. Teacher accounts include name,
              email address, and school affiliation.
            </p>
            <p className="mb-3">
              <strong className="text-eel">Usage Data:</strong> We collect data
              about how the platform is used, including reading progress,
              vocabulary scores, quiz results, streaks, and activity timestamps.
              This data is essential for the learning experience and teacher
              dashboards.
            </p>
            <p>
              <strong className="text-eel">Device Information:</strong> We
              collect basic device and browser information (device type, OS
              version, browser type) to ensure compatibility and troubleshoot
              issues.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              How We Use Your Information
            </h2>
            <ul className="list-disc list-inside space-y-2">
              <li>Provide and personalize the learning experience</li>
              <li>
                Generate progress reports for teachers and school administrators
              </li>
              <li>Calculate spaced repetition schedules for vocabulary review</li>
              <li>Maintain streaks, leaderboards, and achievement systems</li>
              <li>Improve platform performance and fix bugs</li>
              <li>Communicate with teachers about their accounts</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              Children&apos;s Privacy
            </h2>
            <p className="mb-3">
              Owlio is designed for use in schools with students of all ages,
              including children under 13. We comply with applicable
              children&apos;s privacy laws, including COPPA (Children&apos;s
              Online Privacy Protection Act) and relevant provisions of KVKK
              (Turkish Personal Data Protection Law).
            </p>
            <p className="mb-3">
              Student accounts are created and managed by teachers or school
              administrators, who act as authorized agents providing consent on
              behalf of parents/guardians in the educational context.
            </p>
            <p>
              We do not collect more information from children than is necessary
              for the educational service. We do not serve advertising to
              students. We do not sell or share student data with third parties
              for commercial purposes.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Data Retention</h2>
            <p>
              We retain student data for as long as the school maintains an
              active account. When a school or teacher requests account deletion,
              we remove all associated student data within 30 days. Anonymized,
              aggregated usage statistics may be retained for platform
              improvement.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Data Sharing</h2>
            <p className="mb-3">
              We do not sell personal data to third parties. We may share data
              with the following categories of service providers who process data
              on our behalf:
            </p>
            <ul className="list-disc list-inside space-y-2">
              <li>
                <strong className="text-eel">Hosting:</strong> Supabase (database
                and authentication), Vercel (web hosting)
              </li>
              <li>
                <strong className="text-eel">Analytics:</strong> Vercel Analytics
                (anonymized usage metrics)
              </li>
            </ul>
            <p className="mt-3">
              All service providers are contractually required to protect data
              and use it only for the purposes we specify.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Data Security</h2>
            <p>
              We implement industry-standard security measures including
              encryption in transit (TLS), encrypted database storage, role-based
              access controls, and row-level security policies. Access to
              personal data is restricted to authorized personnel only.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Your Rights</h2>
            <p>
              Schools, teachers, and parents/guardians have the right to request
              access to, correction of, or deletion of student personal data. To
              exercise these rights, contact us at{" "}
              <a
                href="mailto:privacy@owlio.co"
                className="text-sky font-bold hover:underline"
              >
                privacy@owlio.co
              </a>
              . We will respond to all requests within 30 days.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Cookies</h2>
            <p>
              Owlio uses essential cookies required for authentication and
              session management. We use Vercel Analytics for anonymized usage
              metrics, which does not use cookies for tracking. We do not use
              advertising cookies or third-party tracking cookies.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              Changes to This Policy
            </h2>
            <p>
              We may update this Privacy Policy from time to time. If we make
              material changes, we will notify schools and teachers via email or
              an in-app notification. Continued use of the platform after changes
              constitutes acceptance of the updated policy.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Contact</h2>
            <p>
              For privacy-related inquiries, contact us at{" "}
              <a
                href="mailto:privacy@owlio.co"
                className="text-sky font-bold hover:underline"
              >
                privacy@owlio.co
              </a>
              .
            </p>
          </section>
        </div>
      </Container>
    </div>
  );
}
```

- [ ] **Step 2: Expand Terms of Service**

Replace the full content of `src/app/terms/page.tsx`:

```tsx
import { Container } from "@/components/ui/Container";

export default function TermsPage() {
  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Terms of Service
        </h1>
        <p className="text-sm text-hare mb-10">Last updated: April 2026</p>

        <div className="space-y-8 text-hare leading-relaxed">
          <p>
            By using Owlio, you agree to the following terms. Please read them
            carefully.
          </p>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Eligibility</h2>
            <p>
              Owlio is an educational platform intended for use by schools,
              teachers, and their students. Student accounts must be created by a
              teacher or school administrator. Individual student sign-ups are
              not available. Users under 13 must have accounts created and
              managed by their teacher or school.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              Account Responsibilities
            </h2>
            <p>
              Teachers and school administrators are responsible for creating and
              managing student accounts within their classes. They must ensure
              that student information is accurate and that accounts are used in
              accordance with their school&apos;s policies. Login credentials
              should be kept confidential and not shared outside the intended
              users.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Acceptable Use</h2>
            <p className="mb-3">
              Users must use Owlio for its intended educational purpose. The
              following are prohibited:
            </p>
            <ul className="list-disc list-inside space-y-2">
              <li>Attempting to access accounts belonging to other users</li>
              <li>
                Using automated tools or bots to interact with the platform
              </li>
              <li>
                Uploading or sharing inappropriate, offensive, or harmful content
              </li>
              <li>
                Attempting to interfere with or disrupt the platform&apos;s
                operation
              </li>
              <li>
                Using the platform for any commercial purpose unrelated to
                education
              </li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Content</h2>
            <p>
              All books, vocabulary lists, quizzes, and educational content on
              Owlio are provided for educational use within the platform.
              Redistribution, copying, or commercial use of any content is
              strictly prohibited. Owlio retains all intellectual property rights
              over platform content, design, and functionality.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Termination</h2>
            <p>
              Schools and teachers may request account deletion at any time by
              contacting us. We reserve the right to suspend or terminate
              accounts that violate these terms. Upon termination, associated
              student data will be deleted in accordance with our Privacy Policy.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              Limitation of Liability
            </h2>
            <p>
              Owlio is provided &quot;as is&quot; without warranties of any kind.
              We are not liable for any indirect, incidental, or consequential
              damages arising from the use of the platform. Our total liability
              is limited to the amount paid for the service in the preceding 12
              months, if any.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Governing Law</h2>
            <p>
              These terms are governed by and construed in accordance with the
              laws of the Republic of Turkey. Any disputes shall be resolved in
              the courts of Istanbul, Turkey.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Contact</h2>
            <p>
              For questions about these terms, contact us at{" "}
              <a
                href="mailto:legal@owlio.co"
                className="text-sky font-bold hover:underline"
              >
                legal@owlio.co
              </a>
              .
            </p>
          </section>
        </div>
      </Container>
    </div>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add src/app/privacy/page.tsx src/app/terms/page.tsx
git commit -m "docs: expand privacy policy and terms of service"
```

---

## Task 14: Vercel Analytics

**Files:**
- Modify: `src/app/layout.tsx`

- [ ] **Step 1: Add Analytics to layout**

Edit `src/app/layout.tsx`:

Add import at the top (after existing imports):
```tsx
import { Analytics } from "@vercel/analytics/next";
```

Inside the `<body>` tag, add `<Analytics />` after `<Footer />`:
```tsx
      <body className="min-h-screen flex flex-col antialiased">
        <Navbar />
        <main className="flex-1">{children}</main>
        <Footer />
        <Analytics />
      </body>
```

- [ ] **Step 2: Verify build**

```bash
cd /Users/wonderelt/Desktop/Owlio/website && npx next build 2>&1 | tail -5
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add src/app/layout.tsx
git commit -m "feat: add Vercel Analytics"
```

---

## Task 15: Final Build Verification

- [ ] **Step 1: Run full build**

```bash
cd /Users/wonderelt/Desktop/Owlio/website && npx next build
```

Expected: Build succeeds with no errors.

- [ ] **Step 2: Run lint**

```bash
cd /Users/wonderelt/Desktop/Owlio/website && npx eslint src/
```

Expected: No errors (warnings acceptable).

- [ ] **Step 3: Verify all pages render**

```bash
cd /Users/wonderelt/Desktop/Owlio/website && npm run dev &
sleep 3
for path in "" "about" "demo" "contact" "faq" "privacy" "terms" "not-a-real-page"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/$path")
  echo "/$path → $code"
done
```

Expected output:
```
/ → 200
/about → 200
/demo → 200
/contact → 200
/faq → 200
/privacy → 200
/terms → 200
/not-a-real-page → 404
```

- [ ] **Step 4: Verify SEO endpoints**

```bash
curl -s http://localhost:3000/sitemap.xml | head -5
curl -s http://localhost:3000/robots.txt
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/opengraph-image
```

Expected: Valid sitemap XML, valid robots.txt, OG image returns 200.
