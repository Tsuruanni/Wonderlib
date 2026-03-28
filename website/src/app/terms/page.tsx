import { Container } from "@/components/ui/Container";

export default function TermsPage() {
  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Terms of Service
        </h1>
        <p className="text-sm text-hare mb-10">Last updated: March 2026</p>

        <div className="space-y-6 text-hare leading-relaxed">
          <p>
            By using Owlio, you agree to the following terms. Please read them
            carefully.
          </p>
          <h2 className="text-xl font-bold text-eel">Use of Service</h2>
          <p>
            Owlio is an educational platform intended for use by schools,
            teachers, and students. Accounts are created by school
            administrators or teachers. Users must use the platform in
            accordance with their school&apos;s policies.
          </p>
          <h2 className="text-xl font-bold text-eel">Content</h2>
          <p>
            All books, vocabulary lists, and educational content on Owlio are
            provided for educational use within the platform. Redistribution or
            commercial use of content is prohibited.
          </p>
          <h2 className="text-xl font-bold text-eel">Contact</h2>
          <p>
            For questions about these terms, contact us at{" "}
            <a
              href="mailto:legal@owlio.com"
              className="text-sky font-bold hover:underline"
            >
              legal@owlio.com
            </a>
            .
          </p>
        </div>
      </Container>
    </div>
  );
}
