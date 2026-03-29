"use client";

import Image from "next/image";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";
import { FloatingElement } from "@/components/ui/FloatingElement";

export function Hero() {
  return (
    <section className="relative py-16 md:py-24 overflow-hidden">
      {/* Decorative background blobs */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden">
        <div className="absolute -top-20 -right-20 w-80 h-80 bg-feather/5 rounded-full blur-3xl" />
        <div className="absolute -bottom-20 -left-20 w-60 h-60 bg-sky/5 rounded-full blur-3xl" />
        <div className="absolute top-1/2 right-1/4 w-40 h-40 bg-bee/5 rounded-full blur-2xl" />
      </div>

      <Container className="relative flex flex-col md:flex-row items-center gap-12 md:gap-16">
        {/* Left: illustration with floating decorations */}
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.7, ease: "easeOut" }}
          className="flex-1 flex justify-center relative order-1 md:order-none"
        >
          {/* Floating decorative elements around illustration */}
          <FloatingElement
            className="absolute -top-4 -right-2 text-3xl"
            duration={4}
            distance={8}
            delay={0.5}
          >
            ⭐
          </FloatingElement>
          <FloatingElement
            className="absolute -bottom-2 -left-4 text-2xl"
            duration={3.5}
            distance={6}
            delay={1}
          >
            📚
          </FloatingElement>
          <FloatingElement
            className="absolute top-1/4 -right-6 text-2xl"
            duration={5}
            distance={10}
            delay={0.2}
          >
            🎯
          </FloatingElement>

          <Image
            src="/images/hero-illustration.svg"
            alt="Owlio — the friendly reading owl"
            width={500}
            height={450}
            priority
          />
        </motion.div>

        {/* Right: text + buttons */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="flex-1 text-center order-2 md:order-none"
        >
          <h1 className="text-3xl md:text-4xl lg:text-[2.5rem] font-black text-eel leading-snug tracking-tight mb-4">
            The fun way to read in English
          </h1>
          <p className="text-base md:text-lg text-hare mb-8 max-w-md mx-auto">
            Curriculum-aligned books and spaced repetition vocabulary. Gamified
            learning that students love and teachers trust.
          </p>
          <div className="flex flex-col gap-3 max-w-sm mx-auto">
            <Button variant="green" size="lg" href="/demo" className="w-full">
              Get Started
            </Button>
            <Button
              variant="neutral"
              size="lg"
              href="/login"
              className="w-full"
            >
              I Already Have an Account
            </Button>
          </div>
        </motion.div>
      </Container>
    </section>
  );
}
