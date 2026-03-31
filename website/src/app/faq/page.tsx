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
    <div className="py-16 md:py-24">
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
    </div>
  );
}
