import { Container } from "@/components/ui/Container";

export default function PrivacyPage() {
  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-2xl">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Privacy Policy
        </h1>
        <p className="text-sm text-hare mb-10">Last updated: April 2026</p>

        <div className="space-y-8 text-hare leading-relaxed">
          <p>
            Owlio (&quot;we&quot;, &quot;our&quot;, &quot;us&quot;) is committed
            to protecting the privacy of our users — especially our youngest
            learners. This Privacy Policy explains how we collect, use, and
            safeguard your information when you use the Owlio platform.
          </p>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              Information We Collect
            </h2>
            <p className="mb-3">
              <strong className="text-eel">Account Information:</strong> When a
              school or teacher creates accounts, we collect student names,
              usernames, and class assignments. Teacher accounts include name,
              email address, and school affiliation.
            </p>
            <p className="mb-3">
              <strong className="text-eel">Usage Data:</strong> We collect data
              about how the platform is used, including reading progress,
              vocabulary scores, quiz results, streaks, and activity timestamps.
              This data is essential for the learning experience and teacher
              dashboards.
            </p>
            <p>
              <strong className="text-eel">Device Information:</strong> We
              collect basic device and browser information (device type, OS
              version, browser type) to ensure compatibility and troubleshoot
              issues.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              How We Use Your Information
            </h2>
            <ul className="list-disc list-inside space-y-2">
              <li>Provide and personalize the learning experience</li>
              <li>
                Generate progress reports for teachers and school administrators
              </li>
              <li>Calculate spaced repetition schedules for vocabulary review</li>
              <li>Maintain streaks, leaderboards, and achievement systems</li>
              <li>Improve platform performance and fix bugs</li>
              <li>Communicate with teachers about their accounts</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              Children&apos;s Privacy
            </h2>
            <p className="mb-3">
              Owlio is designed for use in schools with students of all ages,
              including children under 13. We comply with applicable
              children&apos;s privacy laws, including COPPA (Children&apos;s
              Online Privacy Protection Act) and relevant provisions of KVKK
              (Turkish Personal Data Protection Law).
            </p>
            <p className="mb-3">
              Student accounts are created and managed by teachers or school
              administrators, who act as authorized agents providing consent on
              behalf of parents/guardians in the educational context.
            </p>
            <p>
              We do not collect more information from children than is necessary
              for the educational service. We do not serve advertising to
              students. We do not sell or share student data with third parties
              for commercial purposes.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Data Retention</h2>
            <p>
              We retain student data for as long as the school maintains an
              active account. When a school or teacher requests account deletion,
              we remove all associated student data within 30 days. Anonymized,
              aggregated usage statistics may be retained for platform
              improvement.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Data Sharing</h2>
            <p className="mb-3">
              We do not sell personal data to third parties. We may share data
              with the following categories of service providers who process data
              on our behalf:
            </p>
            <ul className="list-disc list-inside space-y-2">
              <li>
                <strong className="text-eel">Hosting:</strong> Supabase (database
                and authentication), Vercel (web hosting)
              </li>
              <li>
                <strong className="text-eel">Analytics:</strong> Vercel Analytics
                (anonymized usage metrics)
              </li>
            </ul>
            <p className="mt-3">
              All service providers are contractually required to protect data
              and use it only for the purposes we specify.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Data Security</h2>
            <p>
              We implement industry-standard security measures including
              encryption in transit (TLS), encrypted database storage, role-based
              access controls, and row-level security policies. Access to
              personal data is restricted to authorized personnel only.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Your Rights</h2>
            <p>
              Schools, teachers, and parents/guardians have the right to request
              access to, correction of, or deletion of student personal data. To
              exercise these rights, contact us at{" "}
              <a
                href="mailto:privacy@owlio.co"
                className="text-sky font-bold hover:underline"
              >
                privacy@owlio.co
              </a>
              . We will respond to all requests within 30 days.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Cookies</h2>
            <p>
              Owlio uses essential cookies required for authentication and
              session management. We use Vercel Analytics for anonymized usage
              metrics, which does not use cookies for tracking. We do not use
              advertising cookies or third-party tracking cookies.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">
              Changes to This Policy
            </h2>
            <p>
              We may update this Privacy Policy from time to time. If we make
              material changes, we will notify schools and teachers via email or
              an in-app notification. Continued use of the platform after changes
              constitutes acceptance of the updated policy.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-eel mb-3">Contact</h2>
            <p>
              For privacy-related inquiries, contact us at{" "}
              <a
                href="mailto:privacy@owlio.co"
                className="text-sky font-bold hover:underline"
              >
                privacy@owlio.co
              </a>
              .
            </p>
          </section>
        </div>
      </Container>
    </div>
  );
}
