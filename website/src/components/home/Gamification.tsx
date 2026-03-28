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
    description:
      "Build a daily habit with streak tracking and freeze protection",
    color: "bg-fox/10",
  },
  {
    emoji: "🏆",
    title: "Leagues",
    description:
      "Compete with classmates in weekly leaderboard challenges",
    color: "bg-bee/10",
  },
  {
    emoji: "🎖️",
    title: "Badges",
    description:
      "Earn achievements for reading milestones and mastering vocabulary",
    color: "bg-sky/10",
  },
  {
    emoji: "🦉",
    title: "Avatar",
    description:
      "Customize your own Owlio character with items earned through learning",
    color: "bg-feather/10",
  },
  {
    emoji: "🃏",
    title: "Card Collection",
    description:
      "Collect 96 mythological cards across 8 categories by opening packs",
    color: "bg-macaw/10",
  },
  {
    emoji: "⚡",
    title: "Daily Quests",
    description:
      "Complete daily challenges for bonus rewards and extra packs",
    color: "bg-cardinal/10",
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
              className="rounded-duo border-2 border-swan p-6 hover:border-feather hover:shadow-[0_4px_0_#E5E5E5] transition-all duration-200"
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
