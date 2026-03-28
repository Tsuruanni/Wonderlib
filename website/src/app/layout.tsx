import type { Metadata } from "next";
import { Nunito } from "next/font/google";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import "./globals.css";

const nunito = Nunito({
  subsets: ["latin"],
  weight: ["400", "700", "800", "900"],
  variable: "--font-nunito",
});

export const metadata: Metadata = {
  title: {
    default: "Owlio — The fun way to read in English",
    template: "%s | Owlio",
  },
  description:
    "Curriculum-aligned reading and vocabulary platform with spaced repetition. Gamified learning that students love and teachers trust.",
  keywords: [
    "English reading",
    "vocabulary",
    "spaced repetition",
    "gamified learning",
    "schools",
    "education",
    "ESL",
    "EFL",
  ],
  openGraph: {
    title: "Owlio — The fun way to read in English",
    description:
      "Curriculum-aligned reading and vocabulary platform with spaced repetition.",
    url: "https://owlio.com",
    siteName: "Owlio",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Owlio — The fun way to read in English",
    description:
      "Curriculum-aligned reading and vocabulary platform with spaced repetition.",
  },
  robots: {
    index: true,
    follow: true,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={nunito.variable}>
      <body className="min-h-screen flex flex-col antialiased">
        <Navbar />
        <main className="flex-1">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
