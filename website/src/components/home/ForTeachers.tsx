import Image from "next/image";
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";

const teacherBenefits = [
  "Assign books & vocabulary to your class",
  "Monitor reading progress & quiz scores",
  "Zero setup — works with your existing curriculum",
];

export function ForTeachers() {
  return (
    <section id="for-teachers" className="py-16 md:py-24 bg-polar">
      <Container className="flex flex-col md:flex-row items-center gap-12">
        {/* Left: text */}
        <div className="flex-1 text-center md:text-left">
          <p className="text-sm font-bold uppercase tracking-wider text-sky mb-3">
            Owlio for Schools
          </p>
          <h2 className="text-3xl md:text-4xl font-black text-eel mb-4">
            Teachers, we&apos;re here to help you!
          </h2>
          <p className="text-lg text-hare mb-6 max-w-md">
            Our free tools support your students as they build reading skills
            and vocabulary — both in and out of the classroom.
          </p>
          <ul className="space-y-3 mb-8">
            {teacherBenefits.map((benefit) => (
              <li key={benefit} className="flex items-start gap-3">
                <span className="mt-1 text-feather text-lg">✓</span>
                <span className="text-eel font-bold">{benefit}</span>
              </li>
            ))}
          </ul>
          <Button variant="green" size="lg" href="/demo">
            Request a Demo
          </Button>
        </div>

        {/* Right: mockup */}
        <div className="flex-1 flex justify-center">
          <Image
            src="/images/placeholder.svg"
            alt="Teacher dashboard preview"
            width={500}
            height={400}
          />
        </div>
      </Container>
    </section>
  );
}
