"use client";

import { useState, type FormEvent } from "react";
import emailjs from "@emailjs/browser";
import { Container } from "@/components/ui/Container";
import { Button } from "@/components/ui/Button";
import {
  EMAILJS_SERVICE_ID,
  EMAILJS_PUBLIC_KEY,
  EMAILJS_TEMPLATE_CONTACT,
} from "@/lib/emailjs";

export default function ContactPage() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("sending");

    const form = e.currentTarget;
    const data = {
      name: (form.elements.namedItem("name") as HTMLInputElement).value,
      email: (form.elements.namedItem("email") as HTMLInputElement).value,
      message: (form.elements.namedItem("message") as HTMLTextAreaElement).value,
    };

    try {
      await emailjs.send(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_CONTACT, data, EMAILJS_PUBLIC_KEY);
      setStatus("sent");
    } catch {
      setStatus("error");
    }
  }

  if (status === "sent") {
    return (
      <div className="py-20 md:py-28">
        <Container className="max-w-lg text-center">
          <div className="text-6xl mb-6">📬</div>
          <h1 className="text-3xl font-black text-eel mb-4">Message sent!</h1>
          <p className="text-lg text-hare">
            Thanks for reaching out. We&apos;ll get back to you as soon as
            possible.
          </p>
        </Container>
      </div>
    );
  }

  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-lg">
        <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
          Contact us
        </h1>
        <p className="text-hare mb-10">
          Have a question or want to learn more? Drop us a message.
        </p>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label htmlFor="name" className="block text-sm font-bold text-eel mb-1">
              Name <span className="text-cardinal">*</span>
            </label>
            <input
              id="name"
              name="name"
              type="text"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
            />
          </div>

          <div>
            <label htmlFor="email" className="block text-sm font-bold text-eel mb-1">
              Email <span className="text-cardinal">*</span>
            </label>
            <input
              id="email"
              name="email"
              type="email"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
            />
          </div>

          <div>
            <label htmlFor="message" className="block text-sm font-bold text-eel mb-1">
              Message <span className="text-cardinal">*</span>
            </label>
            <textarea
              id="message"
              name="message"
              rows={5}
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors resize-none"
            />
          </div>

          <Button
            type="submit"
            variant="green"
            size="lg"
            className={`w-full ${status === "sending" ? "opacity-70 pointer-events-none" : ""}`}
          >
            {status === "sending" ? "Sending..." : "Send Message"}
          </Button>

          {status === "error" && (
            <p className="text-sm text-cardinal text-center">
              Something went wrong. Please try again.
            </p>
          )}
        </form>
      </Container>
    </div>
  );
}
