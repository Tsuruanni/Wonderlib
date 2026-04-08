"use client";

import { Button } from "@/components/ui/Button";
import { DashboardMockup } from "@/components/home/DashboardMockup";
import { Container } from "@/components/ui/Container";
import { ScrollReveal } from "@/components/ui/ScrollReveal";

const teacherBenefits = [
  {
    icon: "📖",
    text: "Assign books & vocabulary to your class",
  },
  {
    icon: "📊",
    text: "Monitor reading progress & quiz scores in real time",
  },
  {
    icon: "⚡",
    text: "Zero setup — works with your existing curriculum",
  },
];

export function ForTeachers() {
  return (
    <section id="for-teachers" className="relative py-16 md:py-24 bg-polar overflow-hidden">
      {/* Decorative shapes */}
      <div className="absolute top-10 right-10 w-32 h-32 bg-feather/5 rounded-full blur-2xl" />
      <div className="absolute bottom-10 left-10 w-24 h-24 bg-sky/5 rounded-full blur-xl" />

      <Container className="relative flex flex-col md:flex-row items-center gap-12">
        <ScrollReveal direction="left" className="flex-1 text-center md:text-left">
          <p className="inline-block text-sm font-extrabold uppercase tracking-wider text-sky bg-sky/10 px-3 py-1 rounded-full mb-4">
            Owlio for Schools
          </p>
          <h2 className="text-3xl md:text-4xl font-black text-eel mb-4 tracking-tight">
            Teachers, we&apos;re here to help you!
          </h2>
          <p className="text-lg text-hare mb-6 max-w-md leading-relaxed">
            Our free tools support your students as they build reading skills
            and vocabulary — both in and out of the classroom.
          </p>
          <ul className="space-y-4 mb-8">
            {teacherBenefits.map((benefit) => (
              <li key={benefit.text} className="flex items-center gap-3">
                <span className="flex-shrink-0 w-10 h-10 bg-feather/10 rounded-duo flex items-center justify-center text-lg">
                  {benefit.icon}
                </span>
                <span className="text-eel font-bold">{benefit.text}</span>
              </li>
            ))}
          </ul>
          <Button variant="green" size="lg" href="/demo">
            Request a Demo
          </Button>
        </ScrollReveal>

        <ScrollReveal direction="right" delay={0.15} className="flex-1 flex justify-center">
          <div className="relative">
            {/* Dashboard mockup frame */}
            <div className="bg-snow rounded-2xl shadow-[0_8px_30px_rgba(0,0,0,0.08)] border border-swan/50 p-4 md:p-6">
              <div className="flex gap-1.5 mb-4">
                <div className="w-3 h-3 rounded-full bg-cardinal/40" />
                <div className="w-3 h-3 rounded-full bg-bee/40" />
                <div className="w-3 h-3 rounded-full bg-feather/40" />
              </div>
              <DashboardMockup />
            </div>
          </div>
        </ScrollReveal>
      </Container>
    </section>
  );
}
