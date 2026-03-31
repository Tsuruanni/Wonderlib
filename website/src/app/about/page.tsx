import { Container } from "@/components/ui/Container";

export default function AboutPage() {
  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-8">
          About Owlio
        </h1>

        <section id="mission" className="mb-12">
          <h2 className="text-2xl font-black text-feather lowercase mb-4">
            our mission
          </h2>
          <p className="text-lg text-hare leading-relaxed">
            We believe every student deserves access to engaging, effective
            English reading tools — regardless of where they go to school. Owlio
            combines the best of learning science with game design to make
            reading practice something students look forward to, not avoid.
          </p>
        </section>

        <section className="mb-12">
          <h2 className="text-2xl font-black text-feather lowercase mb-4">
            our approach
          </h2>
          <p className="text-lg text-hare leading-relaxed mb-4">
            Owlio is built on three principles:
          </p>
          <ul className="space-y-3">
            <li className="flex items-start gap-3">
              <span className="mt-1 text-feather font-bold">1.</span>
              <span className="text-eel">
                <strong>Curriculum-first.</strong> Every book and word list
                aligns with what teachers are already teaching.
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="mt-1 text-feather font-bold">2.</span>
              <span className="text-eel">
                <strong>Science-backed.</strong> SM-2 spaced repetition ensures
                vocabulary sticks in long-term memory.
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="mt-1 text-feather font-bold">3.</span>
              <span className="text-eel">
                <strong>Fun by design.</strong> Streaks, leagues, badges, and
                collectibles keep students coming back every day.
              </span>
            </li>
          </ul>
        </section>

        <section id="careers">
          <h2 className="text-2xl font-black text-feather lowercase mb-4">
            careers
          </h2>
          <p className="text-lg text-hare leading-relaxed">
            We&apos;re a small, passionate team building the future of reading
            education. Interested in joining us? Reach out at{" "}
            <a
              href="mailto:careers@owlio.com"
              className="text-sky font-bold hover:underline"
            >
              careers@owlio.com
            </a>
            .
          </p>
        </section>
      </Container>
    </div>
  );
}
