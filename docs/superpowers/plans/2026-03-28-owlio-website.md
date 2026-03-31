# Owlio Marketing Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Duolingo-inspired marketing website for Owlio at `/website` — single scroll landing page with demo request form, login redirect, and secondary pages.

**Architecture:** Next.js 15 App Router with TypeScript, Tailwind CSS v4, deployed as a standalone web project inside the Owlio monorepo at `/website`. Duolingo's design language: Nunito font, 3D buttons with bottom borders, generous border-radius, zigzag value prop layout, playful color palette.

**Tech Stack:** Next.js 15, TypeScript, Tailwind CSS v4, Nunito (Google Fonts), Framer Motion (animations)

**Design Spec:** `docs/superpowers/specs/2026-03-28-owlio-website-sitemap-design.md`

**Duolingo Design Reference:**
- Font: Nunito (free DIN Round alternative) via Google Fonts, weight 800 for buttons/headings
- 3D "island" buttons: `box-shadow: 0 4px 0 darkerShade` + `transform: translateY(4px)` on press (NOT border-bottom)
- Border radius: 15px (Duolingo's exact value)
- Colors: green `#58CC02`/`#46A302`, blue `#1CB0F6`/`#BBE7FC`, red `#FF4B4B`, yellow `#FFC800`, neutrals `#4B4B4B`/`#AFAFAF`/`#E5E5E5`/`#F7F7F7`
- Button height: 44px (Duolingo standard)
- Layout: generous padding (64-100px per section), max-width 1080-1200px
- Depth comes from box-shadow only — no border-bottom for 3D effect

**Button Variants (exact Duolingo specs):**
| Variant | BG | Text | Shadow | Border |
|---------|-----|------|--------|--------|
| Green (CTA) | `#58CC02` | white | `0 4px 0 #46A302` | none |
| Blue (secondary) | `#fff` | `#1CB0F6` | `0 4px 0 #BBE7FC` | none |
| Neutral (ghost) | `#fff` | `#4B4B4B` | `0 2px 0 #E5E5E5` | `2px solid #E5E5E5` |

All buttons: `:active` → `box-shadow: none; transform: translateY(Npx)`
Neutral hover: `bg: #E5E5E5`, `border-color: #CECECE`, `box-shadow: 0 2px 0 #CECECE`

---

## File Structure

```
website/
├── src/
│   ├── app/
│   │   ├── layout.tsx              # Root layout: fonts, metadata, Navbar+Footer
│   │   ├── page.tsx                # Home: assembles all scroll sections
│   │   ├── demo/
│   │   │   └── page.tsx            # Demo request form
│   │   ├── about/
│   │   │   └── page.tsx            # Mission + team
│   │   ├── privacy/
│   │   │   └── page.tsx            # Privacy policy
│   │   ├── terms/
│   │   │   └── page.tsx            # Terms of service
│   │   ├── contact/
│   │   │   └── page.tsx            # Contact form
│   │   ├── faq/
│   │   │   └── page.tsx            # FAQ
│   │   └── login/
│   │       └── page.tsx            # Redirect to app login
│   ├── components/
│   │   ├── ui/
│   │   │   ├── Button.tsx          # 3D Duolingo-style button
│   │   │   └── Container.tsx       # Max-width centered container
│   │   ├── layout/
│   │   │   ├── Navbar.tsx          # Logo + For Teachers + Log in
│   │   │   └── Footer.tsx          # 4-column footer
│   │   └── home/
│   │       ├── Hero.tsx            # Hero with mascot + CTA
│   │       ├── ValueProps.tsx      # Zigzag: curriculum, science, motivation
│   │       ├── ForTeachers.tsx     # Teacher section with mockup
│   │       ├── Gamification.tsx    # Showcase: streak, badge, league, etc.
│   │       ├── AppDownload.tsx     # Store badges
│   │       └── FinalCTA.tsx        # Closing CTA + login link
│   └── lib/
│       └── constants.ts            # URLs, external links, app config
├── public/
│   ├── images/                     # Illustrations, mockups, mascot
│   │   └── placeholder.svg         # Placeholder for illustrations
│   └── icons/
│       ├── app-store.svg           # App Store badge
│       └── google-play.svg         # Google Play badge
├── next.config.ts
├── tailwind.config.ts
├── tsconfig.json
├── package.json
└── .gitignore
```

---

## Task 1: Project Scaffolding

**Files:**
- Create: `website/package.json`
- Create: `website/next.config.ts`
- Create: `website/tsconfig.json`
- Create: `website/tailwind.config.ts`
- Create: `website/src/app/layout.tsx`
- Create: `website/src/app/page.tsx`
- Create: `website/src/app/globals.css`
- Create: `website/.gitignore`

- [ ] **Step 1: Create Next.js project**

```bash
cd /Users/wonderelt/Desktop/Owlio
npx create-next-app@latest website --typescript --tailwind --eslint --app --src-dir --no-import-alias --use-npm
```

When prompted:
- Would you like to use Turbopack? → Yes
- Would you like to customize the import alias? → No

- [ ] **Step 2: Install additional dependencies**

```bash
cd /Users/wonderelt/Desktop/Owlio/website
npm install framer-motion
```

- [ ] **Step 3: Configure Nunito font in layout.tsx**

Replace `website/src/app/layout.tsx`:

```tsx
import type { Metadata } from "next";
import { Nunito } from "next/font/google";
import "./globals.css";

const nunito = Nunito({
  subsets: ["latin"],
  weight: ["400", "700", "800", "900"],
  variable: "--font-nunito",
});

export const metadata: Metadata = {
  title: "Owlio — The fun way to read in English",
  description:
    "Curriculum-aligned reading and vocabulary platform with spaced repetition. Gamified learning that students love and teachers trust.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={nunito.variable}>
      <body className="font-sans antialiased text-eel bg-snow">
        {children}
      </body>
    </html>
  );
}
```

- [ ] **Step 4: Set up Tailwind with Duolingo-inspired design tokens**

Replace `website/tailwind.config.ts`:

```ts
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["var(--font-nunito)", "Nunito", "sans-serif"],
      },
      colors: {
        feather: {
          DEFAULT: "#58CC02",
          dark: "#46A302",
        },
        cardinal: "#FF4B4B",
        bee: "#FFC800",
        sky: {
          DEFAULT: "#1CB0F6",
          dark: "#1899D6",
        },
        macaw: "#CE82FF",
        fox: "#FF9600",
        eel: "#4B4B4B",
        hare: "#AFAFAF",
        swan: "#E5E5E5",
        polar: "#F7F7F7",
        snow: "#FFFFFF",
      },
      borderRadius: {
        duo: "15px",
      },
      maxWidth: {
        site: "1140px",
      },
    },
  },
  plugins: [],
};

export default config;
```

- [ ] **Step 5: Set up global CSS**

Replace `website/src/app/globals.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  html {
    scroll-behavior: smooth;
  }

  body {
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }
}
```

- [ ] **Step 6: Create placeholder home page**

Replace `website/src/app/page.tsx`:

```tsx
export default function Home() {
  return (
    <main className="min-h-screen flex items-center justify-center">
      <h1 className="text-4xl font-black text-feather">Owlio</h1>
    </main>
  );
}
```

- [ ] **Step 7: Verify dev server runs**

```bash
cd /Users/wonderelt/Desktop/Owlio/website
npm run dev
```

Expected: Server starts at `http://localhost:3000`, shows green "Owlio" text.

- [ ] **Step 8: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio
git add website/
git commit -m "feat(website): scaffold Next.js project with Tailwind + Nunito"
```

---

## Task 2: UI Primitives — Button + Container

**Files:**
- Create: `website/src/components/ui/Button.tsx`
- Create: `website/src/components/ui/Container.tsx`

- [ ] **Step 1: Create the 3D Button component**

Create `website/src/components/ui/Button.tsx`:

```tsx
import Link from "next/link";

type ButtonVariant = "green" | "blue" | "neutral";
type ButtonSize = "md" | "lg";

interface ButtonProps {
  children: React.ReactNode;
  href?: string;
  variant?: ButtonVariant;
  size?: ButtonSize;
  onClick?: () => void;
  type?: "button" | "submit";
  className?: string;
}

const variantStyles: Record<ButtonVariant, string> = {
  green:
    "bg-feather text-snow border-none shadow-[0_4px_0_#46A302] hover:brightness-110 active:shadow-none active:translate-y-[4px]",
  blue:
    "bg-snow text-sky border-none shadow-[0_4px_0_#BBE7FC] hover:brightness-95 active:shadow-none active:translate-y-[4px]",
  neutral:
    "bg-snow text-eel border-2 border-swan shadow-[0_2px_0_#E5E5E5] hover:bg-swan hover:border-[#CECECE] hover:shadow-[0_2px_0_#CECECE] active:shadow-none active:translate-y-[2px]",
};

const sizeStyles: Record<ButtonSize, string> = {
  md: "px-6 py-2.5 text-sm h-[36px]",
  lg: "px-8 py-3 text-base h-[44px]",
};

export function Button({
  children,
  href,
  variant = "green",
  size = "lg",
  onClick,
  type = "button",
  className = "",
}: ButtonProps) {
  const baseStyles =
    "inline-flex items-center justify-center rounded-duo font-extrabold uppercase tracking-wider transition-all duration-100 text-center cursor-pointer select-none";
  const styles = `${baseStyles} ${variantStyles[variant]} ${sizeStyles[size]} ${className}`;

  if (href) {
    return (
      <Link href={href} className={styles}>
        {children}
      </Link>
    );
  }

  return (
    <button type={type} onClick={onClick} className={styles}>
      {children}
    </button>
  );
}
```

- [ ] **Step 2: Create the Container component**

Create `website/src/components/ui/Container.tsx`:

```tsx
interface ContainerProps {
  children: React.ReactNode;
  className?: string;
}

export function Container({ children, className = "" }: ContainerProps) {
  return (
    <div className={`mx-auto max-w-site px-6 ${className}`}>{children}</div>
  );
}
```

- [ ] **Step 3: Test buttons visually on home page**

Replace `website/src/app/page.tsx`:

```tsx
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";

export default function Home() {
  return (
    <main className="min-h-screen flex items-center justify-center">
      <Container className="flex flex-col items-center gap-4">
        <h1 className="text-4xl font-black text-feather">Owlio</h1>
        <div className="flex gap-4">
          <Button variant="green" href="/demo">
            Get Started
          </Button>
          <Button variant="neutral" href="/login">
            I Already Have an Account
          </Button>
        </div>
      </Container>
    </main>
  );
}
```

- [ ] **Step 4: Verify in browser**

Expected: Green 3D button and white outlined button, both with press-down effect on click.

- [ ] **Step 5: Commit**

```bash
git add website/src/components/
git commit -m "feat(website): add 3D Button and Container components"
```

---

## Task 3: Navbar + Footer Layout

**Files:**
- Create: `website/src/components/layout/Navbar.tsx`
- Create: `website/src/components/layout/Footer.tsx`
- Create: `website/src/lib/constants.ts`
- Modify: `website/src/app/layout.tsx`

- [ ] **Step 1: Create constants file**

Create `website/src/lib/constants.ts`:

```ts
export const APP_LOGIN_URL = "https://app.owlio.com/login";

export const SOCIAL_LINKS = {
  instagram: "https://instagram.com/owlio",
  tiktok: "https://tiktok.com/@owlio",
  twitter: "https://twitter.com/owlio",
  youtube: "https://youtube.com/@owlio",
  linkedin: "https://linkedin.com/company/owlio",
} as const;

export const APP_STORE_URL = "#";
export const GOOGLE_PLAY_URL = "#";
```

- [ ] **Step 2: Create Navbar**

Create `website/src/components/layout/Navbar.tsx`:

```tsx
"use client";

import Link from "next/link";
import { Container } from "@/components/ui/Container";

export function Navbar() {
  return (
    <nav className="sticky top-0 z-50 bg-snow/95 backdrop-blur-sm border-b border-swan">
      <Container className="flex items-center justify-between h-16">
        <Link href="/" className="flex items-center gap-2">
          <span className="text-2xl font-black text-feather tracking-tight">
            owlio
          </span>
        </Link>

        <div className="flex items-center gap-6">
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
      </Container>
    </nav>
  );
}
```

- [ ] **Step 3: Create Footer**

Create `website/src/components/layout/Footer.tsx`:

```tsx
import Link from "next/link";
import { Container } from "@/components/ui/Container";
import { SOCIAL_LINKS } from "@/lib/constants";

const footerSections = [
  {
    title: "About",
    links: [
      { label: "About Us", href: "/about" },
      { label: "Mission", href: "/about#mission" },
      { label: "Careers", href: "mailto:careers@owlio.com" },
    ],
  },
  {
    title: "Product",
    links: [
      { label: "Owlio App", href: "#" },
      { label: "For Schools", href: "/#for-teachers" },
      { label: "Blog", href: "#" },
    ],
  },
  {
    title: "Help & Legal",
    links: [
      { label: "FAQ", href: "/faq" },
      { label: "Contact", href: "/contact" },
      { label: "Privacy Policy", href: "/privacy" },
      { label: "Terms of Service", href: "/terms" },
    ],
  },
];

export function Footer() {
  return (
    <footer className="bg-eel text-snow pt-16 pb-8">
      <Container>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-10 mb-12">
          {/* Logo column */}
          <div>
            <span className="text-2xl font-black text-feather tracking-tight">
              owlio
            </span>
          </div>

          {/* Link columns */}
          {footerSections.map((section) => (
            <div key={section.title}>
              <h3 className="text-sm font-bold uppercase tracking-wider text-hare mb-4">
                {section.title}
              </h3>
              <ul className="space-y-3">
                {section.links.map((link) => (
                  <li key={link.label}>
                    <Link
                      href={link.href}
                      className="text-sm text-swan hover:text-snow transition-colors"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Social + copyright */}
        <div className="border-t border-white/10 pt-8 flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex gap-6">
            {Object.entries(SOCIAL_LINKS).map(([name, url]) => (
              <a
                key={name}
                href={url}
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm text-hare hover:text-snow transition-colors capitalize"
              >
                {name}
              </a>
            ))}
          </div>
          <p className="text-sm text-hare">
            &copy; {new Date().getFullYear()} Owlio. All rights reserved.
          </p>
        </div>
      </Container>
    </footer>
  );
}
```

- [ ] **Step 4: Wire Navbar + Footer into root layout**

Replace `website/src/app/layout.tsx`:

```tsx
import type { Metadata } from "next";
import { Nunito } from "next/font/google";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import "./globals.css";

const nunito = Nunito({
  subsets: ["latin"],
  weight: ["400", "700", "800", "900"],
  variable: "--font-nunito",
});

export const metadata: Metadata = {
  title: "Owlio — The fun way to read in English",
  description:
    "Curriculum-aligned reading and vocabulary platform with spaced repetition. Gamified learning that students love and teachers trust.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={nunito.variable}>
      <body className="font-sans antialiased text-eel bg-snow">
        <Navbar />
        {children}
        <Footer />
      </body>
    </html>
  );
}
```

- [ ] **Step 5: Verify in browser**

Expected: Sticky navbar with "owlio" logo + "For Teachers" + "Log in" button. Dark footer at bottom with 4-column layout.

- [ ] **Step 6: Commit**

```bash
git add website/src/components/layout/ website/src/lib/ website/src/app/layout.tsx
git commit -m "feat(website): add Navbar and Footer with Duolingo-style design"
```

---

## Task 4: Hero Section

**Files:**
- Create: `website/src/components/home/Hero.tsx`
- Create: `website/public/images/placeholder.svg`

- [ ] **Step 1: Create a placeholder illustration SVG**

Create `website/public/images/placeholder.svg`:

```svg
<svg width="500" height="400" viewBox="0 0 500 400" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="500" height="400" rx="24" fill="#F7F7F7"/>
  <circle cx="250" cy="170" r="80" fill="#58CC02" opacity="0.3"/>
  <text x="250" y="180" text-anchor="middle" font-family="sans-serif" font-size="40" fill="#58CC02">🦉</text>
  <text x="250" y="300" text-anchor="middle" font-family="sans-serif" font-size="16" fill="#AFAFAF">Illustration placeholder</text>
</svg>
```

- [ ] **Step 2: Create Hero component**

Create `website/src/components/home/Hero.tsx`:

```tsx
import Image from "next/image";
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";

export function Hero() {
  return (
    <section className="py-16 md:py-24 overflow-hidden">
      <Container className="flex flex-col md:flex-row items-center gap-12">
        {/* Left: text */}
        <div className="flex-1 text-center md:text-left">
          <h1 className="text-4xl md:text-5xl lg:text-6xl font-black text-eel leading-tight mb-6">
            The fun way to read in English
          </h1>
          <p className="text-lg md:text-xl text-hare mb-8 max-w-lg">
            Curriculum-aligned reading and spaced repetition vocabulary.
            Gamified learning that students love and teachers trust.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center md:justify-start">
            <Button variant="green" size="lg" href="/demo">
              Get Started
            </Button>
            <Button variant="neutral" size="lg" href="/login">
              I Already Have an Account
            </Button>
          </div>
        </div>

        {/* Right: illustration */}
        <div className="flex-1 flex justify-center">
          <Image
            src="/images/placeholder.svg"
            alt="Owlio app preview"
            width={500}
            height={400}
            priority
          />
        </div>
      </Container>
    </section>
  );
}
```

- [ ] **Step 3: Add Hero to home page**

Replace `website/src/app/page.tsx`:

```tsx
import { Hero } from "@/components/home/Hero";

export default function Home() {
  return (
    <main>
      <Hero />
    </main>
  );
}
```

- [ ] **Step 4: Verify in browser**

Expected: Large headline left, placeholder illustration right, two buttons below text. Responsive: stacks vertically on mobile.

- [ ] **Step 5: Commit**

```bash
git add website/src/components/home/Hero.tsx website/src/app/page.tsx website/public/images/
git commit -m "feat(website): add Hero section with CTA buttons"
```

---

## Task 5: Value Props — Zigzag Section

**Files:**
- Create: `website/src/components/home/ValueProps.tsx`

- [ ] **Step 1: Create ValueProps component**

Create `website/src/components/home/ValueProps.tsx`:

```tsx
import Image from "next/image";
import { Container } from "@/components/ui/Container";

interface ValuePropData {
  heading: string;
  description: string;
  image: string;
  imageAlt: string;
}

const valueProps: ValuePropData[] = [
  {
    heading: "curriculum-aligned",
    description:
      "Books and vocabulary that match what's taught in class. Your students read what they're already learning — no extra materials needed.",
    image: "/images/placeholder.svg",
    imageAlt: "Curriculum-aligned library illustration",
  },
  {
    heading: "backed by science",
    description:
      "Powered by SM-2 spaced repetition — the world's most proven memory algorithm. Every word is reviewed at the perfect moment for long-term retention.",
    image: "/images/placeholder.svg",
    imageAlt: "Spaced repetition science illustration",
  },
  {
    heading: "stay motivated",
    description:
      "XP, streaks, leagues, avatars, card collections — students actually want to practice every day. Learning that feels like playing.",
    image: "/images/placeholder.svg",
    imageAlt: "Gamification elements illustration",
  },
];

function ValuePropBlock({
  prop,
  index,
}: {
  prop: ValuePropData;
  index: number;
}) {
  const isReversed = index % 2 === 1;

  return (
    <div
      className={`flex flex-col ${
        isReversed ? "md:flex-row-reverse" : "md:flex-row"
      } items-center gap-12 md:gap-16`}
    >
      {/* Text */}
      <div className="flex-1 text-center md:text-left">
        <h2 className="text-3xl md:text-4xl font-black text-feather lowercase mb-4">
          {prop.heading}
        </h2>
        <p className="text-lg text-hare max-w-md">{prop.description}</p>
      </div>

      {/* Illustration */}
      <div className="flex-1 flex justify-center">
        <Image
          src={prop.image}
          alt={prop.imageAlt}
          width={460}
          height={360}
        />
      </div>
    </div>
  );
}

export function ValueProps() {
  return (
    <section className="py-16 md:py-24">
      <Container className="space-y-20 md:space-y-32">
        {valueProps.map((prop, i) => (
          <ValuePropBlock key={prop.heading} prop={prop} index={i} />
        ))}
      </Container>
    </section>
  );
}
```

- [ ] **Step 2: Add ValueProps to home page**

Replace `website/src/app/page.tsx`:

```tsx
import { Hero } from "@/components/home/Hero";
import { ValueProps } from "@/components/home/ValueProps";

export default function Home() {
  return (
    <main>
      <Hero />
      <ValueProps />
    </main>
  );
}
```

- [ ] **Step 3: Verify in browser**

Expected: Three zigzag blocks. First: text left, image right. Second: image left, text right. Third: text left, image right. Green headings, gray descriptions.

- [ ] **Step 4: Commit**

```bash
git add website/src/components/home/ValueProps.tsx website/src/app/page.tsx
git commit -m "feat(website): add zigzag Value Props section"
```

---

## Task 6: For Teachers Section

**Files:**
- Create: `website/src/components/home/ForTeachers.tsx`

- [ ] **Step 1: Create ForTeachers component**

Create `website/src/components/home/ForTeachers.tsx`:

```tsx
import Image from "next/image";
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";

const teacherBenefits = [
  "Assign books & vocabulary to your class",
  "Monitor reading progress & quiz scores",
  "Zero setup — works with your existing curriculum",
];

export function ForTeachers() {
  return (
    <section id="for-teachers" className="py-16 md:py-24 bg-polar">
      <Container className="flex flex-col md:flex-row items-center gap-12">
        {/* Left: text */}
        <div className="flex-1 text-center md:text-left">
          <p className="text-sm font-bold uppercase tracking-wider text-sky mb-3">
            Owlio for Schools
          </p>
          <h2 className="text-3xl md:text-4xl font-black text-eel mb-4">
            Teachers, we&apos;re here to help you!
          </h2>
          <p className="text-lg text-hare mb-6 max-w-md">
            Our free tools support your students as they build reading skills
            and vocabulary — both in and out of the classroom.
          </p>
          <ul className="space-y-3 mb-8">
            {teacherBenefits.map((benefit) => (
              <li key={benefit} className="flex items-start gap-3">
                <span className="mt-1 text-feather text-lg">✓</span>
                <span className="text-eel font-bold">{benefit}</span>
              </li>
            ))}
          </ul>
          <Button variant="green" size="lg" href="/demo">
            Request a Demo
          </Button>
        </div>

        {/* Right: mockup */}
        <div className="flex-1 flex justify-center">
          <Image
            src="/images/placeholder.svg"
            alt="Teacher dashboard preview"
            width={500}
            height={400}
          />
        </div>
      </Container>
    </section>
  );
}
```

- [ ] **Step 2: Add to home page**

Replace `website/src/app/page.tsx`:

```tsx
import { Hero } from "@/components/home/Hero";
import { ValueProps } from "@/components/home/ValueProps";
import { ForTeachers } from "@/components/home/ForTeachers";

export default function Home() {
  return (
    <main>
      <Hero />
      <ValueProps />
      <ForTeachers />
    </main>
  );
}
```

- [ ] **Step 3: Verify in browser**

Expected: Gray background section with anchor id `for-teachers`. Text left with bullet points and green CTA, mockup right. Clicking "For Teachers" in navbar scrolls here.

- [ ] **Step 4: Commit**

```bash
git add website/src/components/home/ForTeachers.tsx website/src/app/page.tsx
git commit -m "feat(website): add For Teachers section with anchor link"
```

---

## Task 7: Gamification Showcase

**Files:**
- Create: `website/src/components/home/Gamification.tsx`

- [ ] **Step 1: Create Gamification component**

Create `website/src/components/home/Gamification.tsx`:

```tsx
import { Container } from "@/components/ui/Container";

interface Feature {
  emoji: string;
  title: string;
  description: string;
  color: string;
}

const features: Feature[] = [
  {
    emoji: "🔥",
    title: "Daily Streaks",
    description: "Build a daily habit with streak tracking and freeze protection",
    color: "bg-fox/10 text-fox",
  },
  {
    emoji: "🏆",
    title: "Leagues",
    description: "Compete with classmates in weekly leaderboard challenges",
    color: "bg-bee/10 text-bee",
  },
  {
    emoji: "🎖️",
    title: "Badges",
    description: "Earn achievements for reading milestones and mastering vocabulary",
    color: "bg-sky/10 text-sky",
  },
  {
    emoji: "🦉",
    title: "Avatar",
    description: "Customize your own Owlio character with items earned through learning",
    color: "bg-feather/10 text-feather",
  },
  {
    emoji: "🃏",
    title: "Card Collection",
    description: "Collect 96 mythological cards across 8 categories by opening packs",
    color: "bg-macaw/10 text-macaw",
  },
  {
    emoji: "⚡",
    title: "Daily Quests",
    description: "Complete daily challenges for bonus rewards and extra packs",
    color: "bg-cardinal/10 text-cardinal",
  },
];

export function Gamification() {
  return (
    <section className="py-16 md:py-24">
      <Container>
        <div className="text-center mb-12">
          <h2 className="text-3xl md:text-4xl font-black text-eel mb-4">
            Learning that feels like playing
          </h2>
          <p className="text-lg text-hare max-w-xl mx-auto">
            Every reading session, every vocabulary drill, every quiz earns
            rewards. Students stay engaged because progress is visible and fun.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature) => (
            <div
              key={feature.title}
              className="rounded-duo border-2 border-swan p-6 hover:border-feather transition-colors"
            >
              <div
                className={`w-12 h-12 rounded-xl ${feature.color} flex items-center justify-center text-2xl mb-4`}
              >
                {feature.emoji}
              </div>
              <h3 className="text-lg font-bold text-eel mb-2">
                {feature.title}
              </h3>
              <p className="text-sm text-hare">{feature.description}</p>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
```

- [ ] **Step 2: Add to home page**

Replace `website/src/app/page.tsx`:

```tsx
import { Hero } from "@/components/home/Hero";
import { ValueProps } from "@/components/home/ValueProps";
import { ForTeachers } from "@/components/home/ForTeachers";
import { Gamification } from "@/components/home/Gamification";

export default function Home() {
  return (
    <main>
      <Hero />
      <ValueProps />
      <ForTeachers />
      <Gamification />
    </main>
  );
}
```

- [ ] **Step 3: Verify in browser**

Expected: 6-card grid (3 columns on desktop, 2 on tablet, 1 on mobile). Each card has colored icon, title, description. Cards have border hover effect.

- [ ] **Step 4: Commit**

```bash
git add website/src/components/home/Gamification.tsx website/src/app/page.tsx
git commit -m "feat(website): add Gamification Showcase grid section"
```

---

## Task 8: App Download + Final CTA

**Files:**
- Create: `website/src/components/home/AppDownload.tsx`
- Create: `website/src/components/home/FinalCTA.tsx`

- [ ] **Step 1: Create AppDownload component**

Create `website/src/components/home/AppDownload.tsx`:

```tsx
import { Container } from "@/components/ui/Container";
import { APP_STORE_URL, GOOGLE_PLAY_URL } from "@/lib/constants";

export function AppDownload() {
  return (
    <section className="py-16 md:py-24 bg-polar">
      <Container className="text-center">
        <h2 className="text-3xl md:text-4xl font-black text-eel mb-4">
          Learn anytime, anywhere
        </h2>
        <p className="text-lg text-hare mb-8 max-w-lg mx-auto">
          Download Owlio on your phone or tablet. Pick up where you left off,
          on any device.
        </p>
        <div className="flex flex-col sm:flex-row gap-4 justify-center">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center justify-center gap-2 rounded-duo bg-eel text-snow px-6 py-3 font-bold text-sm hover:bg-black transition-colors"
          >
            <span className="text-xl">🍎</span>
            <span>
              <span className="block text-[10px] font-normal leading-none">
                Download on the
              </span>
              App Store
            </span>
          </a>
          <a
            href={GOOGLE_PLAY_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center justify-center gap-2 rounded-duo bg-eel text-snow px-6 py-3 font-bold text-sm hover:bg-black transition-colors"
          >
            <span className="text-xl">▶️</span>
            <span>
              <span className="block text-[10px] font-normal leading-none">
                Get it on
              </span>
              Google Play
            </span>
          </a>
        </div>
      </Container>
    </section>
  );
}
```

- [ ] **Step 2: Create FinalCTA component**

Create `website/src/components/home/FinalCTA.tsx`:

```tsx
import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";

export function FinalCTA() {
  return (
    <section className="py-20 md:py-28">
      <Container className="text-center">
        <h2 className="text-3xl md:text-5xl font-black text-eel mb-4">
          Bring Owlio to your school
        </h2>
        <p className="text-lg text-hare mb-8 max-w-lg mx-auto">
          Join schools already using Owlio to make English reading fun,
          effective, and easy to manage.
        </p>
        <Button variant="green" size="lg" href="/demo">
          Get Started
        </Button>
        <p className="mt-6 text-sm text-hare">
          Already have an account?{" "}
          <Link href="/login" className="text-sky font-bold hover:underline">
            Log in
          </Link>
        </p>
      </Container>
    </section>
  );
}
```

- [ ] **Step 3: Add both to home page**

Replace `website/src/app/page.tsx`:

```tsx
import { Hero } from "@/components/home/Hero";
import { ValueProps } from "@/components/home/ValueProps";
import { ForTeachers } from "@/components/home/ForTeachers";
import { Gamification } from "@/components/home/Gamification";
import { AppDownload } from "@/components/home/AppDownload";
import { FinalCTA } from "@/components/home/FinalCTA";

export default function Home() {
  return (
    <main>
      <Hero />
      <ValueProps />
      <ForTeachers />
      <Gamification />
      <AppDownload />
      <FinalCTA />
    </main>
  );
}
```

- [ ] **Step 4: Verify in browser**

Expected: Full scroll page — Hero → Zigzag → Teachers → Gamification → App Download → CTA → Footer.

- [ ] **Step 5: Commit**

```bash
git add website/src/components/home/ website/src/app/page.tsx
git commit -m "feat(website): add App Download and Final CTA sections — home page complete"
```

---

## Task 9: Demo Request Page

**Files:**
- Create: `website/src/app/demo/page.tsx`

- [ ] **Step 1: Create demo page with form**

Create `website/src/app/demo/page.tsx`:

```tsx
"use client";

import { useState, type FormEvent } from "react";
import { Container } from "@/components/ui/Container";
import { Button } from "@/components/ui/Button";

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
  const [submitted, setSubmitted] = useState(false);

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    // TODO: Wire to backend (Supabase, email service, etc.)
    setSubmitted(true);
  }

  if (submitted) {
    return (
      <main className="py-20 md:py-28">
        <Container className="max-w-lg text-center">
          <div className="text-6xl mb-6">🦉</div>
          <h1 className="text-3xl font-black text-eel mb-4">Thank you!</h1>
          <p className="text-lg text-hare">
            We&apos;ve received your request. Our team will reach out to you
            within 24 hours to schedule a demo.
          </p>
        </Container>
      </main>
    );
  }

  return (
    <main className="py-16 md:py-24">
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
            <label
              htmlFor="name"
              className="block text-sm font-bold text-eel mb-1"
            >
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
            <label
              htmlFor="email"
              className="block text-sm font-bold text-eel mb-1"
            >
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
            <label
              htmlFor="school"
              className="block text-sm font-bold text-eel mb-1"
            >
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
            <label
              htmlFor="country"
              className="block text-sm font-bold text-eel mb-1"
            >
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
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label
              htmlFor="students"
              className="block text-sm font-bold text-eel mb-1"
            >
              Number of Students{" "}
              <span className="text-hare font-normal">(optional)</span>
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
            <label
              htmlFor="message"
              className="block text-sm font-bold text-eel mb-1"
            >
              Message{" "}
              <span className="text-hare font-normal">(optional)</span>
            </label>
            <textarea
              id="message"
              name="message"
              rows={3}
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors resize-none"
              placeholder="Tell us about your school or what you'd like to see"
            />
          </div>

          <Button type="submit" variant="green" size="lg" className="w-full">
            Request a Demo
          </Button>
        </form>
      </Container>
    </main>
  );
}
```

- [ ] **Step 2: Verify in browser**

Navigate to `http://localhost:3000/demo`.
Expected: Clean form with Duolingo-style inputs (rounded, bordered). Submit shows thank-you state.

- [ ] **Step 3: Commit**

```bash
git add website/src/app/demo/
git commit -m "feat(website): add Demo request page with form"
```

---

## Task 10: Secondary Pages (About, Contact, FAQ)

**Files:**
- Create: `website/src/app/about/page.tsx`
- Create: `website/src/app/contact/page.tsx`
- Create: `website/src/app/faq/page.tsx`

- [ ] **Step 1: Create About page**

Create `website/src/app/about/page.tsx`:

```tsx
import { Container } from "@/components/ui/Container";

export default function AboutPage() {
  return (
    <main className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-8">
          About Owlio
        </h1>

        <section id="mission" className="mb-12">
          <h2 className="text-2xl font-black text-feather lowercase mb-4">
            our mission
          </h2>
          <p className="text-lg text-hare leading-relaxed">
            We believe every student deserves access to engaging, effective
            English reading tools — regardless of where they go to school. Owlio
            combines the best of learning science with game design to make
            reading practice something students look forward to, not avoid.
          </p>
        </section>

        <section className="mb-12">
          <h2 className="text-2xl font-black text-feather lowercase mb-4">
            our approach
          </h2>
          <p className="text-lg text-hare leading-relaxed mb-4">
            Owlio is built on three principles:
          </p>
          <ul className="space-y-3">
            <li className="flex items-start gap-3">
              <span className="mt-1 text-feather font-bold">1.</span>
              <span className="text-eel">
                <strong>Curriculum-first.</strong> Every book and word list
                aligns with what teachers are already teaching.
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="mt-1 text-feather font-bold">2.</span>
              <span className="text-eel">
                <strong>Science-backed.</strong> SM-2 spaced repetition ensures
                vocabulary sticks in long-term memory.
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="mt-1 text-feather font-bold">3.</span>
              <span className="text-eel">
                <strong>Fun by design.</strong> Streaks, leagues, badges, and
                collectibles keep students coming back every day.
              </span>
            </li>
          </ul>
        </section>

        <section id="careers">
          <h2 className="text-2xl font-black text-feather lowercase mb-4">
            careers
          </h2>
          <p className="text-lg text-hare leading-relaxed">
            We&apos;re a small, passionate team building the future of reading
            education. Interested in joining us? Reach out at{" "}
            <a
              href="mailto:careers@owlio.com"
              className="text-sky font-bold hover:underline"
            >
              careers@owlio.com
            </a>
            .
          </p>
        </section>
      </Container>
    </main>
  );
}
```

- [ ] **Step 2: Create Contact page**

Create `website/src/app/contact/page.tsx`:

```tsx
"use client";

import { useState, type FormEvent } from "react";
import { Container } from "@/components/ui/Container";
import { Button } from "@/components/ui/Button";

export default function ContactPage() {
  const [submitted, setSubmitted] = useState(false);

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setSubmitted(true);
  }

  if (submitted) {
    return (
      <main className="py-20 md:py-28">
        <Container className="max-w-lg text-center">
          <div className="text-6xl mb-6">📬</div>
          <h1 className="text-3xl font-black text-eel mb-4">Message sent!</h1>
          <p className="text-lg text-hare">
            Thanks for reaching out. We&apos;ll get back to you as soon as
            possible.
          </p>
        </Container>
      </main>
    );
  }

  return (
    <main className="py-16 md:py-24">
      <Container className="max-w-lg">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Contact us
        </h1>
        <p className="text-hare mb-10">
          Have a question or want to learn more? Drop us a message.
        </p>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label
              htmlFor="name"
              className="block text-sm font-bold text-eel mb-1"
            >
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
            <label
              htmlFor="email"
              className="block text-sm font-bold text-eel mb-1"
            >
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
            <label
              htmlFor="message"
              className="block text-sm font-bold text-eel mb-1"
            >
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

          <Button type="submit" variant="green" size="lg" className="w-full">
            Send Message
          </Button>
        </form>
      </Container>
    </main>
  );
}
```

- [ ] **Step 3: Create FAQ page**

Create `website/src/app/faq/page.tsx`:

```tsx
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

export default function FAQPage() {
  return (
    <main className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-10">
          Frequently Asked Questions
        </h1>

        <div className="space-y-8">
          {faqs.map((faq) => (
            <div key={faq.question}>
              <h2 className="text-lg font-bold text-eel mb-2">
                {faq.question}
              </h2>
              <p className="text-hare leading-relaxed">{faq.answer}</p>
            </div>
          ))}
        </div>
      </Container>
    </main>
  );
}
```

- [ ] **Step 4: Verify all three pages in browser**

- `http://localhost:3000/about` — Mission, approach, careers sections
- `http://localhost:3000/contact` — Contact form with submit
- `http://localhost:3000/faq` — 6 Q&A items

- [ ] **Step 5: Commit**

```bash
git add website/src/app/about/ website/src/app/contact/ website/src/app/faq/
git commit -m "feat(website): add About, Contact, and FAQ pages"
```

---

## Task 11: Legal Pages + Login Redirect

**Files:**
- Create: `website/src/app/privacy/page.tsx`
- Create: `website/src/app/terms/page.tsx`
- Create: `website/src/app/login/page.tsx`

- [ ] **Step 1: Create Privacy Policy page**

Create `website/src/app/privacy/page.tsx`:

```tsx
import { Container } from "@/components/ui/Container";

export default function PrivacyPage() {
  return (
    <main className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Privacy Policy
        </h1>
        <p className="text-sm text-hare mb-10">Last updated: March 2026</p>

        <div className="prose prose-lg text-hare space-y-6">
          <p>
            Owlio (&quot;we&quot;, &quot;our&quot;, &quot;us&quot;) is committed
            to protecting the privacy of our users. This Privacy Policy explains
            how we collect, use, and safeguard your information when you use the
            Owlio platform.
          </p>
          <h2 className="text-xl font-bold text-eel">
            Information We Collect
          </h2>
          <p>
            We collect information that your school or teacher provides when
            creating your account, including name, email address, and class
            assignment. We also collect usage data such as reading progress,
            vocabulary scores, and app activity to personalize the learning
            experience.
          </p>
          <h2 className="text-xl font-bold text-eel">
            How We Use Your Information
          </h2>
          <p>
            Your information is used solely to provide and improve the Owlio
            learning experience. We do not sell personal data to third parties.
            Teachers and school administrators can view student progress through
            the Owlio dashboard.
          </p>
          <h2 className="text-xl font-bold text-eel">Contact</h2>
          <p>
            For privacy-related inquiries, contact us at{" "}
            <a
              href="mailto:privacy@owlio.com"
              className="text-sky font-bold hover:underline"
            >
              privacy@owlio.com
            </a>
            .
          </p>
        </div>
      </Container>
    </main>
  );
}
```

- [ ] **Step 2: Create Terms of Service page**

Create `website/src/app/terms/page.tsx`:

```tsx
import { Container } from "@/components/ui/Container";

export default function TermsPage() {
  return (
    <main className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Terms of Service
        </h1>
        <p className="text-sm text-hare mb-10">Last updated: March 2026</p>

        <div className="prose prose-lg text-hare space-y-6">
          <p>
            By using Owlio, you agree to the following terms. Please read them
            carefully.
          </p>
          <h2 className="text-xl font-bold text-eel">Use of Service</h2>
          <p>
            Owlio is an educational platform intended for use by schools,
            teachers, and students. Accounts are created by school
            administrators or teachers. Users must use the platform in
            accordance with their school&apos;s policies.
          </p>
          <h2 className="text-xl font-bold text-eel">Content</h2>
          <p>
            All books, vocabulary lists, and educational content on Owlio are
            provided for educational use within the platform. Redistribution or
            commercial use of content is prohibited.
          </p>
          <h2 className="text-xl font-bold text-eel">Contact</h2>
          <p>
            For questions about these terms, contact us at{" "}
            <a
              href="mailto:legal@owlio.com"
              className="text-sky font-bold hover:underline"
            >
              legal@owlio.com
            </a>
            .
          </p>
        </div>
      </Container>
    </main>
  );
}
```

- [ ] **Step 3: Create Login redirect page**

Create `website/src/app/login/page.tsx`:

```tsx
"use client";

import { useEffect } from "react";
import { Container } from "@/components/ui/Container";
import { APP_LOGIN_URL } from "@/lib/constants";

export default function LoginPage() {
  useEffect(() => {
    window.location.href = APP_LOGIN_URL;
  }, []);

  return (
    <main className="py-20 md:py-28">
      <Container className="text-center">
        <div className="text-6xl mb-6">🦉</div>
        <h1 className="text-2xl font-black text-eel mb-4">
          Redirecting to Owlio...
        </h1>
        <p className="text-hare">
          If you&apos;re not redirected automatically,{" "}
          <a href={APP_LOGIN_URL} className="text-sky font-bold hover:underline">
            click here
          </a>
          .
        </p>
      </Container>
    </main>
  );
}
```

- [ ] **Step 4: Verify all pages**

- `http://localhost:3000/privacy` — Privacy policy content
- `http://localhost:3000/terms` — Terms of service content
- `http://localhost:3000/login` — Shows redirect message then navigates to app login URL

- [ ] **Step 5: Commit**

```bash
git add website/src/app/privacy/ website/src/app/terms/ website/src/app/login/
git commit -m "feat(website): add Privacy, Terms, and Login redirect pages"
```

---

## Task 12: Responsive Polish + SEO Meta

**Files:**
- Modify: `website/src/app/layout.tsx`
- Modify: `website/src/components/layout/Navbar.tsx` (mobile menu)

- [ ] **Step 1: Add mobile hamburger menu to Navbar**

Replace `website/src/components/layout/Navbar.tsx`:

```tsx
"use client";

import { useState } from "react";
import Link from "next/link";
import { Container } from "@/components/ui/Container";

export function Navbar() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <nav className="sticky top-0 z-50 bg-snow/95 backdrop-blur-sm border-b border-swan">
      <Container className="flex items-center justify-between h-16">
        <Link href="/" className="flex items-center gap-2">
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
            className={`block w-6 h-0.5 bg-eel transition-transform ${
              mobileOpen ? "rotate-45 translate-y-2" : ""
            }`}
          />
          <span
            className={`block w-6 h-0.5 bg-eel transition-opacity ${
              mobileOpen ? "opacity-0" : ""
            }`}
          />
          <span
            className={`block w-6 h-0.5 bg-eel transition-transform ${
              mobileOpen ? "-rotate-45 -translate-y-2" : ""
            }`}
          />
        </button>
      </Container>

      {/* Mobile dropdown */}
      {mobileOpen && (
        <div className="sm:hidden border-t border-swan bg-snow">
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
              className="rounded-duo border-2 border-swan border-b-4 border-b-swan bg-snow px-5 py-2 text-sm font-bold uppercase tracking-wider text-sky text-center"
            >
              Log in
            </Link>
          </Container>
        </div>
      )}
    </nav>
  );
}
```

- [ ] **Step 2: Add comprehensive SEO metadata**

Replace the metadata export in `website/src/app/layout.tsx`:

```tsx
export const metadata: Metadata = {
  title: {
    default: "Owlio — The fun way to read in English",
    template: "%s | Owlio",
  },
  description:
    "Curriculum-aligned reading and vocabulary platform with spaced repetition. Gamified learning that students love and teachers trust.",
  keywords: [
    "English reading",
    "vocabulary",
    "spaced repetition",
    "gamified learning",
    "schools",
    "education",
    "ESL",
    "EFL",
  ],
  openGraph: {
    title: "Owlio — The fun way to read in English",
    description:
      "Curriculum-aligned reading and vocabulary platform with spaced repetition.",
    url: "https://owlio.com",
    siteName: "Owlio",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Owlio — The fun way to read in English",
    description:
      "Curriculum-aligned reading and vocabulary platform with spaced repetition.",
  },
  robots: {
    index: true,
    follow: true,
  },
};
```

- [ ] **Step 3: Test responsive behavior**

Resize browser from desktop → tablet → mobile:
- Navbar: hamburger menu appears below `sm` breakpoint
- Hero: stacks vertically on mobile
- Value Props: stacks vertically on mobile
- Gamification grid: 3 cols → 2 cols → 1 col
- Footer: 4 cols → stacked

- [ ] **Step 4: Commit**

```bash
git add website/src/components/layout/Navbar.tsx website/src/app/layout.tsx
git commit -m "feat(website): add mobile menu and SEO metadata"
```

---

## Task 13: Final Verification + Root Gitignore

**Files:**
- Modify: `website/.gitignore`

- [ ] **Step 1: Verify .gitignore includes standard Next.js ignores**

Check that `website/.gitignore` (created by create-next-app) contains:

```
/.next/
/out/
/build/
/node_modules/
.env*.local
```

- [ ] **Step 2: Run production build**

```bash
cd /Users/wonderelt/Desktop/Owlio/website
npm run build
```

Expected: Build succeeds with no errors.

- [ ] **Step 3: Full browser walkthrough**

Navigate through all pages:
1. `/` — Full scroll page (Hero → Value Props → Teachers → Gamification → App Download → CTA → Footer)
2. `/demo` — Form works, submit shows thank you
3. `/about` — Three sections with anchor links
4. `/contact` — Form works
5. `/faq` — 6 Q&A items
6. `/privacy` — Privacy policy
7. `/terms` — Terms of service
8. `/login` — Redirects (or shows redirect message)
9. Navbar "For Teachers" scrolls to `#for-teachers`
10. All footer links work

- [ ] **Step 4: Final commit**

```bash
git add -A website/
git commit -m "feat(website): Owlio marketing website complete — Duolingo-inspired design"
```
