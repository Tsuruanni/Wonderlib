"use client";

import { useState, type FormEvent } from "react";
import emailjs from "@emailjs/browser";
import { Container } from "@/components/ui/Container";
import { Button } from "@/components/ui/Button";
import {
  EMAILJS_SERVICE_ID,
  EMAILJS_PUBLIC_KEY,
  EMAILJS_TEMPLATE_DEMO,
} from "@/lib/emailjs";

const countries = [
  "Turkey",
  "United States",
  "United Kingdom",
  "Germany",
  "France",
  "Netherlands",
  "Spain",
  "Italy",
  "Japan",
  "South Korea",
  "Brazil",
  "Other",
];

export default function DemoPage() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("sending");

    const form = e.currentTarget;
    const data = {
      name: (form.elements.namedItem("name") as HTMLInputElement).value,
      email: (form.elements.namedItem("email") as HTMLInputElement).value,
      school: (form.elements.namedItem("school") as HTMLInputElement).value,
      country: (form.elements.namedItem("country") as HTMLSelectElement).value,
      students: (form.elements.namedItem("students") as HTMLInputElement).value || "N/A",
      message: (form.elements.namedItem("message") as HTMLTextAreaElement).value || "N/A",
    };

    try {
      await emailjs.send(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_DEMO, data, EMAILJS_PUBLIC_KEY);
      setStatus("sent");
    } catch {
      setStatus("error");
    }
  }

  if (status === "sent") {
    return (
      <div className="py-20 md:py-28">
        <Container className="max-w-lg text-center">
          <div className="text-6xl mb-6">🦉</div>
          <h1 className="text-3xl font-black text-eel mb-4">Thank you!</h1>
          <p className="text-lg text-hare">
            We&apos;ve received your request. Our team will reach out to you
            within 24 hours to schedule a demo.
          </p>
        </Container>
      </div>
    );
  }

  return (
    <div className="py-16 md:py-24">
      <Container className="max-w-lg">
        <div className="text-center mb-10">
          <h1 className="text-3xl md:text-4xl font-black text-eel mb-3">
            See Owlio in action
          </h1>
          <p className="text-hare">
            Fill in the form below and we&apos;ll get back to you within 24
            hours to schedule a personalized demo.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label htmlFor="name" className="block text-sm font-bold text-eel mb-1">
              Full Name <span className="text-cardinal">*</span>
            </label>
            <input
              id="name"
              name="name"
              type="text"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
              placeholder="Jane Smith"
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
              placeholder="jane@school.edu"
            />
          </div>

          <div>
            <label htmlFor="school" className="block text-sm font-bold text-eel mb-1">
              School Name <span className="text-cardinal">*</span>
            </label>
            <input
              id="school"
              name="school"
              type="text"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
              placeholder="Springfield Elementary"
            />
          </div>

          <div>
            <label htmlFor="country" className="block text-sm font-bold text-eel mb-1">
              Country <span className="text-cardinal">*</span>
            </label>
            <select
              id="country"
              name="country"
              required
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel focus:border-sky focus:outline-none transition-colors bg-snow"
            >
              <option value="">Select your country</option>
              {countries.map((c) => (
                <option key={c} value={c}>{c}</option>
              ))}
            </select>
          </div>

          <div>
            <label htmlFor="students" className="block text-sm font-bold text-eel mb-1">
              Number of Students <span className="text-hare font-normal">(optional)</span>
            </label>
            <input
              id="students"
              name="students"
              type="number"
              min={1}
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors"
              placeholder="150"
            />
          </div>

          <div>
            <label htmlFor="message" className="block text-sm font-bold text-eel mb-1">
              Message <span className="text-hare font-normal">(optional)</span>
            </label>
            <textarea
              id="message"
              name="message"
              rows={3}
              className="w-full rounded-duo border-2 border-swan px-4 py-3 text-eel placeholder:text-hare focus:border-sky focus:outline-none transition-colors resize-none"
              placeholder="Tell us about your school or what you'd like to see"
            />
          </div>

          <Button
            type="submit"
            variant="green"
            size="lg"
            className={`w-full ${status === "sending" ? "opacity-70 pointer-events-none" : ""}`}
          >
            {status === "sending" ? "Sending..." : "Request a Demo"}
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
