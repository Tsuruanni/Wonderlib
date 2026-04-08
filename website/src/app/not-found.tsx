import { Container } from "@/components/ui/Container";
import { OwlLogo } from "@/components/ui/OwlLogo";
import { Button } from "@/components/ui/Button";

export default function NotFound() {
  return (
    <div className="py-20 md:py-28">
      <Container className="text-center">
        <OwlLogo size={96} className="mx-auto mb-6" />
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-4">
          Oops! This page flew away
        </h1>
        <p className="text-lg text-hare mb-8">
          The page you&apos;re looking for doesn&apos;t exist.
        </p>
        <Button variant="green" size="lg" href="/">
          Go Home
        </Button>
      </Container>
    </div>
  );
}
