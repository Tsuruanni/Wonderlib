import Image from "next/image";
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";

export function Hero() {
  return (
    <section className="py-16 md:py-24 overflow-hidden">
      <Container className="flex flex-col md:flex-row items-center gap-12">
        {/* Left: text */}
        <div className="flex-1 text-center md:text-left">
          <h1 className="text-4xl md:text-5xl lg:text-6xl font-black text-eel leading-tight mb-6">
            The fun way to read in English
          </h1>
          <p className="text-lg md:text-xl text-hare mb-8 max-w-lg">
            Curriculum-aligned reading and spaced repetition vocabulary.
            Gamified learning that students love and teachers trust.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center md:justify-start">
            <Button variant="green" size="lg" href="/demo">
              Get Started
            </Button>
            <Button variant="neutral" size="lg" href="/login">
              I Already Have an Account
            </Button>
          </div>
        </div>

        {/* Right: illustration */}
        <div className="flex-1 flex justify-center">
          <Image
            src="/images/placeholder.svg"
            alt="Owlio app preview"
            width={500}
            height={400}
            priority
          />
        </div>
      </Container>
    </section>
  );
}
