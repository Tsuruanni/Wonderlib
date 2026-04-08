"use client";

import { useState, type FormEvent } from "react";
import emailjs from "@emailjs/browser";
import { Container } from "@/components/ui/Container";
import { ScrollReveal } from "@/components/ui/ScrollReveal";
import { Button } from "@/components/ui/Button";
import {
  EMAILJS_SERVICE_ID,
  EMAILJS_PUBLIC_KEY,
  EMAILJS_TEMPLATE_NOTIFY,
} from "@/lib/emailjs";

export function AppDownload() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("sending");

    const form = e.currentTarget;
    const data = {
      email: (form.elements.namedItem("notify-email") as HTMLInputElement).value,
    };

    try {
      await emailjs.send(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_NOTIFY, data, EMAILJS_PUBLIC_KEY);
      setStatus("sent");
    } catch {
      setStatus("error");
    }
  }

  return (
    <section className="relative py-16 md:py-24 bg-polar overflow-hidden">
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-0 left-1/4 w-40 h-40 bg-feather/5 rounded-full blur-2xl" />
        <div className="absolute bottom-0 right-1/4 w-32 h-32 bg-sky/5 rounded-full blur-2xl" />
      </div>

      <Container className="relative text-center">
        <ScrollReveal>
          <div className="inline-flex items-center gap-2 bg-snow rounded-full px-4 py-2 shadow-[0_2px_0_#E5E5E5] mb-6">
            <span className="text-xl">📱</span>
            <span className="text-sm font-bold text-hare uppercase tracking-wider">
              Coming Soon
            </span>
          </div>
          <h2 className="text-3xl md:text-4xl font-black text-eel mb-4 tracking-tight">
            Coming soon to your phone
          </h2>
          <p className="text-lg text-hare mb-8 max-w-lg mx-auto leading-relaxed">
            We&apos;re building the Owlio mobile app. Leave your email and
            we&apos;ll let you know when it&apos;s ready.
          </p>

          {status === "sent" ? (
            <div className="flex items-center justify-center gap-2 text-feather font-bold">
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                <circle cx="10" cy="10" r="10" fill="currentColor" opacity="0.15" />
                <path d="M6 10l3 3 5-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              You&apos;re on the list!
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
              <input
                id="notify-email"
                name="notify-email"
                type="email"
                required
                placeholder="your@email.com"
                className="flex-1 rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
              />
              <Button
                type="submit"
                variant="green"
                size="lg"
                className={status === "sending" ? "opacity-70 pointer-events-none" : ""}
              >
                {status === "sending" ? "..." : "Notify Me"}
              </Button>
            </form>
          )}

          {status === "error" && (
            <p className="text-sm text-cardinal mt-3">
              Something went wrong. Please try again.
            </p>
          )}

          <div className="flex justify-center gap-4 mt-8">
            <span className="inline-flex items-center gap-1.5 text-sm font-bold text-hare bg-swan/50 rounded-full px-4 py-1.5">
              iOS
            </span>
            <span className="inline-flex items-center gap-1.5 text-sm font-bold text-hare bg-swan/50 rounded-full px-4 py-1.5">
              Android
            </span>
          </div>
        </ScrollReveal>
      </Container>
    </section>
  );
}
