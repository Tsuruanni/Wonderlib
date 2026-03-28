import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";

export function FinalCTA() {
  return (
    <section className="py-20 md:py-28">
      <Container className="text-center">
        <h2 className="text-3xl md:text-5xl font-black text-eel mb-4">
          Bring Owlio to your school
        </h2>
        <p className="text-lg text-hare mb-8 max-w-lg mx-auto">
          Join schools already using Owlio to make English reading fun,
          effective, and easy to manage.
        </p>
        <Button variant="green" size="lg" href="/demo">
          Get Started
        </Button>
        <p className="mt-6 text-sm text-hare">
          Already have an account?{" "}
          <Link href="/login" className="text-sky font-bold hover:underline">
            Log in
          </Link>
        </p>
      </Container>
    </section>
  );
}
