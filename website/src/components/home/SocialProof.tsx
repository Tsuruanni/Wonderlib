"use client";

import { Container } from "@/components/ui/Container";
import { ScrollReveal } from "@/components/ui/ScrollReveal";

const stats = [
  { value: "10,000+", label: "Students learning" },
  { value: "200+", label: "Schools" },
  { value: "50,000+", label: "Books read" },
  { value: "4.8★", label: "App rating" },
];

export function SocialProof() {
  return (
    <section className="py-10 border-y border-swan/50">
      <Container>
        <ScrollReveal>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6 md:gap-8">
            {stats.map((stat, i) => (
              <div key={stat.label} className="text-center">
                <div className="text-2xl md:text-3xl font-black text-feather tracking-tight">
                  {stat.value}
                </div>
                <div className="text-xs md:text-sm font-bold text-hare uppercase tracking-wider mt-1">
                  {stat.label}
                </div>
              </div>
            ))}
          </div>
        </ScrollReveal>
      </Container>
    </section>
  );
}
