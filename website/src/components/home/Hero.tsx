import Image from "next/image";
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";

export function Hero() {
  return (
    <section className="py-16 md:py-24 overflow-hidden">
      <Container className="flex flex-col md:flex-row items-center gap-12 md:gap-16">
        {/* Left: illustration */}
        <div className="flex-1 flex justify-center order-1 md:order-none">
          <Image
            src="/images/placeholder.svg"
            alt="Owlio app preview"
            width={500}
            height={400}
            priority
          />
        </div>

        {/* Right: text + buttons (centered, stacked) */}
        <div className="flex-1 text-center order-2 md:order-none">
          <h1 className="text-4xl md:text-5xl lg:text-[3.2rem] font-black text-eel leading-tight mb-8">
            The fun way to read in English
          </h1>
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
        </div>
      </Container>
    </section>
  );
}
