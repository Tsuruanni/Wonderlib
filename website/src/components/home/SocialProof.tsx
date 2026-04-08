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
