import Link from "next/link";
import { Container } from "@/components/ui/Container";
import { SOCIAL_LINKS } from "@/lib/constants";

const footerSections = [
  {
    title: "About",
    links: [
      { label: "About Us", href: "/about" },
      { label: "Mission", href: "/about#mission" },
      { label: "Careers", href: "mailto:careers@owlio.com" },
    ],
  },
  {
    title: "Product",
    links: [
      { label: "Owlio App", href: "#" },
      { label: "For Schools", href: "/#for-teachers" },
      { label: "Blog", href: "#" },
    ],
  },
  {
    title: "Help & Legal",
    links: [
      { label: "FAQ", href: "/faq" },
      { label: "Contact", href: "/contact" },
      { label: "Privacy Policy", href: "/privacy" },
      { label: "Terms of Service", href: "/terms" },
    ],
  },
];

export function Footer() {
  return (
    <footer className="bg-eel text-snow pt-16 pb-8">
      <Container>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-10 mb-12">
          {/* Logo column */}
          <div>
            <span className="text-2xl font-black text-feather tracking-tight">
              owlio
            </span>
          </div>

          {/* Link columns */}
          {footerSections.map((section) => (
            <div key={section.title}>
              <h3 className="text-sm font-bold uppercase tracking-wider text-hare mb-4">
                {section.title}
              </h3>
              <ul className="space-y-3">
                {section.links.map((link) => (
                  <li key={link.label}>
                    <Link
                      href={link.href}
                      className="text-sm text-swan hover:text-snow transition-colors"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Social + copyright */}
        <div className="border-t border-white/10 pt-8 flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex gap-6">
            {Object.entries(SOCIAL_LINKS).map(([name, url]) => (
              <a
                key={name}
                href={url}
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm text-hare hover:text-snow transition-colors capitalize"
              >
                {name}
              </a>
            ))}
          </div>
          <p className="text-sm text-hare">
            &copy; {new Date().getFullYear()} Owlio. All rights reserved.
          </p>
        </div>
      </Container>
    </footer>
  );
}
