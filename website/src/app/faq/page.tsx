"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
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

function FAQAccordionItem({
  faq,
  isOpen,
  onToggle,
}: {
  faq: FAQItem;
  isOpen: boolean;
  onToggle: () => void;
}) {
  return (
    <div className="border-b border-swan">
      <button
        onClick={onToggle}
        className="w-full flex items-center justify-between py-5 text-left cursor-pointer"
      >
        <h2 className="text-lg font-bold text-eel pr-4">{faq.question}</h2>
        <span className="flex-shrink-0 w-6 h-6 flex items-center justify-center text-hare text-xl font-bold">
          {isOpen ? "\u2212" : "+"}
        </span>
      </button>
      <AnimatePresence initial={false}>
        {isOpen && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2, ease: "easeOut" }}
            className="overflow-hidden"
          >
            <p className="text-hare leading-relaxed pb-5">{faq.answer}</p>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function FAQPage() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs.map((faq) => ({
      "@type": "Question",
      name: faq.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: faq.answer,
      },
    })),
  };

  return (
    <div className="py-16 md:py-24">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-10">
          Frequently Asked Questions
        </h1>

        <div>
          {faqs.map((faq, i) => (
            <FAQAccordionItem
              key={faq.question}
              faq={faq}
              isOpen={openIndex === i}
              onToggle={() => setOpenIndex(openIndex === i ? null : i)}
            />
          ))}
        </div>
      </Container>
    </div>
  );
}
