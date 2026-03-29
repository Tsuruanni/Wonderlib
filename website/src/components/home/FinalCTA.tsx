"use client";

import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";
import { ScrollReveal } from "@/components/ui/ScrollReveal";
import { FloatingElement } from "@/components/ui/FloatingElement";

export function FinalCTA() {
  return (
    <section className="relative py-20 md:py-32 overflow-hidden">
      {/* Playful background */}
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-1/4 left-10 w-48 h-48 bg-feather/5 rounded-full blur-3xl" />
        <div className="absolute bottom-1/4 right-10 w-48 h-48 bg-sky/5 rounded-full blur-3xl" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-bee/3 rounded-full blur-3xl" />
      </div>

      {/* Floating emojis */}
      <FloatingElement className="absolute top-16 left-[15%] text-3xl opacity-20" duration={4} distance={12} delay={0}>
        📚
      </FloatingElement>
      <FloatingElement className="absolute top-20 right-[18%] text-3xl opacity-20" duration={5} distance={10} delay={1}>
        🦉
      </FloatingElement>
      <FloatingElement className="absolute bottom-20 left-[22%] text-2xl opacity-20" duration={3.5} distance={8} delay={0.5}>
        ⭐
      </FloatingElement>
      <FloatingElement className="absolute bottom-24 right-[25%] text-2xl opacity-20" duration={4.5} distance={10} delay={1.5}>
        🏆
      </FloatingElement>

      <Container className="relative text-center">
        <ScrollReveal>
          <h2 className="text-3xl md:text-5xl font-black text-eel mb-4 tracking-tight">
            Bring Owlio to your school
          </h2>
          <p className="text-lg text-hare mb-8 max-w-lg mx-auto leading-relaxed">
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
        </ScrollReveal>
      </Container>
    </section>
  );
}
