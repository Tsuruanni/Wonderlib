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
