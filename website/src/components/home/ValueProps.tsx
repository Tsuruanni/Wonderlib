"use client";

import Image from "next/image";
import { Container } from "@/components/ui/Container";
import { ScrollReveal } from "@/components/ui/ScrollReveal";

interface ValuePropData {
  heading: string;
  description: string;
  image: string;
  imageAlt: string;
  accent: string;
}

const valueProps: ValuePropData[] = [
  {
    heading: "curriculum-aligned",
    description:
      "Books and vocabulary that match what's taught in class. Your students read what they're already learning — no extra materials needed.",
    image: "/images/value-curriculum.svg",
    imageAlt: "Curriculum-aligned library illustration",
    accent: "text-feather",
  },
  {
    heading: "backed by science",
    description:
      "Powered by SM-2 spaced repetition — the world's most proven memory algorithm. Every word is reviewed at the perfect moment for long-term retention.",
    image: "/images/value-science.svg",
    imageAlt: "Spaced repetition science illustration",
    accent: "text-sky",
  },
  {
    heading: "stay motivated",
    description:
      "XP, streaks, leagues, avatars, card collections — students actually want to practice every day. Learning that feels like playing.",
    image: "/images/value-motivation.svg",
    imageAlt: "Gamification elements illustration",
    accent: "text-fox",
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
      <ScrollReveal
        direction={isReversed ? "right" : "left"}
        className="flex-1 text-center md:text-left"
      >
        <h2
          className={`text-3xl md:text-4xl font-black ${prop.accent} lowercase mb-4`}
        >
          {prop.heading}
        </h2>
        <p className="text-lg text-hare max-w-md leading-relaxed">
          {prop.description}
        </p>
      </ScrollReveal>

      <ScrollReveal
        direction={isReversed ? "left" : "right"}
        delay={0.15}
        className="flex-1 flex justify-center"
      >
        <Image
          src={prop.image}
          alt={prop.imageAlt}
          width={460}
          height={360}
        />
      </ScrollReveal>
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
