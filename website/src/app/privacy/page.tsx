import { Container } from "@/components/ui/Container";

export default function PrivacyPage() {
  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Privacy Policy
        </h1>
        <p className="text-sm text-hare mb-10">Last updated: March 2026</p>

        <div className="space-y-6 text-hare leading-relaxed">
          <p>
            Owlio (&quot;we&quot;, &quot;our&quot;, &quot;us&quot;) is committed
            to protecting the privacy of our users. This Privacy Policy explains
            how we collect, use, and safeguard your information when you use the
            Owlio platform.
          </p>
          <h2 className="text-xl font-bold text-eel">
            Information We Collect
          </h2>
          <p>
            We collect information that your school or teacher provides when
            creating your account, including name, email address, and class
            assignment. We also collect usage data such as reading progress,
            vocabulary scores, and app activity to personalize the learning
            experience.
          </p>
          <h2 className="text-xl font-bold text-eel">
            How We Use Your Information
          </h2>
          <p>
            Your information is used solely to provide and improve the Owlio
            learning experience. We do not sell personal data to third parties.
            Teachers and school administrators can view student progress through
            the Owlio dashboard.
          </p>
          <h2 className="text-xl font-bold text-eel">Contact</h2>
          <p>
            For privacy-related inquiries, contact us at{" "}
            <a
              href="mailto:privacy@owlio.com"
              className="text-sky font-bold hover:underline"
            >
              privacy@owlio.com
            </a>
            .
          </p>
        </div>
      </Container>
    </div>
  );
}
