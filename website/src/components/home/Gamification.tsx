"use client";

import { motion } from "framer-motion";
import { Container } from "@/components/ui/Container";
import { ScrollReveal } from "@/components/ui/ScrollReveal";

interface Feature {
  emoji: string;
  title: string;
  description: string;
  gradient: string;
  shadowColor: string;
}

const features: Feature[] = [
  {
    emoji: "🔥",
    title: "Daily Streaks",
    description:
      "Build a daily habit with streak tracking and freeze protection",
    gradient: "from-fox/10 to-cardinal/5",
    shadowColor: "hover:shadow-fox/20",
  },
  {
    emoji: "🏆",
    title: "Leagues",
    description:
      "Compete with classmates in weekly leaderboard challenges",
    gradient: "from-bee/10 to-fox/5",
    shadowColor: "hover:shadow-bee/20",
  },
  {
    emoji: "🎖️",
    title: "Badges",
    description:
      "Earn achievements for reading milestones and mastering vocabulary",
    gradient: "from-sky/10 to-macaw/5",
    shadowColor: "hover:shadow-sky/20",
  },
  {
    emoji: "🦉",
    title: "Avatar",
    description:
      "Customize your own Owlio character with items earned through learning",
    gradient: "from-feather/10 to-sky/5",
    shadowColor: "hover:shadow-feather/20",
  },
  {
    emoji: "🃏",
    title: "Card Collection",
    description:
      "Collect 96 mythological cards across 8 categories by opening packs",
    gradient: "from-macaw/10 to-cardinal/5",
    shadowColor: "hover:shadow-macaw/20",
  },
  {
    emoji: "⚡",
    title: "Daily Quests",
    description:
      "Complete daily challenges for bonus rewards and extra packs",
    gradient: "from-cardinal/10 to-fox/5",
    shadowColor: "hover:shadow-cardinal/20",
  },
];

const cardVariants = {
  hidden: { opacity: 0, y: 30 },
  visible: (i: number) => ({
    opacity: 1,
    y: 0,
    transition: {
      delay: i * 0.1,
      duration: 0.5,
      ease: [0.21, 0.47, 0.32, 0.98] as const,
    },
  }),
};

export function Gamification() {
  return (
    <section className="relative py-16 md:py-24 overflow-hidden">
      {/* Background decoration */}
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-1/3 -left-20 w-60 h-60 bg-bee/5 rounded-full blur-3xl" />
        <div className="absolute bottom-1/4 -right-20 w-60 h-60 bg-macaw/5 rounded-full blur-3xl" />
      </div>

      <Container className="relative">
        <ScrollReveal className="text-center mb-12">
          <h2 className="text-3xl md:text-4xl font-black text-eel mb-4 tracking-tight">
            Learning that feels like playing
          </h2>
          <p className="text-lg text-hare max-w-xl mx-auto leading-relaxed">
            Every reading session, every vocabulary drill, every quiz earns
            rewards. Students stay engaged because progress is visible and fun.
          </p>
        </ScrollReveal>

        <motion.div
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-50px" }}
          className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5"
        >
          {features.map((feature, i) => (
            <motion.div
              key={feature.title}
              custom={i}
              variants={cardVariants}
              whileHover={{ y: -4, transition: { duration: 0.2 } }}
              className={`bg-gradient-to-br ${feature.gradient} rounded-2xl border-2 border-swan/60 p-6 cursor-default transition-shadow duration-200 hover:shadow-lg ${feature.shadowColor}`}
            >
              <div className="w-14 h-14 bg-snow rounded-xl shadow-[0_2px_0_#E5E5E5] flex items-center justify-center text-2xl mb-4">
                {feature.emoji}
              </div>
              <h3 className="text-lg font-black text-eel mb-2">
                {feature.title}
              </h3>
              <p className="text-sm text-hare leading-relaxed">
                {feature.description}
              </p>
            </motion.div>
          ))}
        </motion.div>
      </Container>
    </section>
  );
}
