import { Container } from "@/components/ui/Container";

export default function TermsPage() {
  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Terms of Service
        </h1>
        <p className="text-sm text-hare mb-10">Last updated: April 2026</p>

        <div className="space-y-8 text-hare leading-relaxed">
          <p>
            By using Owlio, you agree to the following terms. Please read them
            carefully.
          </p>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Eligibility</h2>
            <p>
              Owlio is an educational platform intended for use by schools,
              teachers, and their students. Student accounts must be created by a
              teacher or school administrator. Individual student sign-ups are
              not available. Users under 13 must have accounts created and
              managed by their teacher or school.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              Account Responsibilities
            </h2>
            <p>
              Teachers and school administrators are responsible for creating and
              managing student accounts within their classes. They must ensure
              that student information is accurate and that accounts are used in
              accordance with their school&apos;s policies. Login credentials
              should be kept confidential and not shared outside the intended
              users.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Acceptable Use</h2>
            <p className="mb-3">
              Users must use Owlio for its intended educational purpose. The
              following are prohibited:
            </p>
            <ul className="list-disc list-inside space-y-2">
              <li>Attempting to access accounts belonging to other users</li>
              <li>
                Using automated tools or bots to interact with the platform
              </li>
              <li>
                Uploading or sharing inappropriate, offensive, or harmful content
              </li>
              <li>
                Attempting to interfere with or disrupt the platform&apos;s
                operation
              </li>
              <li>
                Using the platform for any commercial purpose unrelated to
                education
              </li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Content</h2>
            <p>
              All books, vocabulary lists, quizzes, and educational content on
              Owlio are provided for educational use within the platform.
              Redistribution, copying, or commercial use of any content is
              strictly prohibited. Owlio retains all intellectual property rights
              over platform content, design, and functionality.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Termination</h2>
            <p>
              Schools and teachers may request account deletion at any time by
              contacting us. We reserve the right to suspend or terminate
              accounts that violate these terms. Upon termination, associated
              student data will be deleted in accordance with our Privacy Policy.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              Limitation of Liability
            </h2>
            <p>
              Owlio is provided &quot;as is&quot; without warranties of any kind.
              We are not liable for any indirect, incidental, or consequential
              damages arising from the use of the platform. Our total liability
              is limited to the amount paid for the service in the preceding 12
              months, if any.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Governing Law</h2>
            <p>
              These terms are governed by and construed in accordance with the
              laws of the Republic of Turkey. Any disputes shall be resolved in
              the courts of Istanbul, Turkey.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Contact</h2>
            <p>
              For questions about these terms, contact us at{" "}
              <a
                href="mailto:legal@owlio.co"
                className="text-sky font-bold hover:underline"
              >
                legal@owlio.co
              </a>
              .
            </p>
          </section>
        </div>
      </Container>
    </div>
  );
}
