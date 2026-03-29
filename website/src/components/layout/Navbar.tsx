"use client";

import { useState } from "react";
import Link from "next/link";
import { Container } from "@/components/ui/Container";
import { OwlLogo } from "@/components/ui/OwlLogo";

export function Navbar() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <nav className="sticky top-0 z-50 bg-snow/95 backdrop-blur-sm border-b border-swan">
      <Container className="flex items-center justify-between h-16">
        <Link href="/" className="flex items-center gap-1.5">
          <OwlLogo size={34} />
          <span className="text-2xl font-black text-feather tracking-tight">
            owlio
          </span>
        </Link>

        {/* Desktop nav */}
        <div className="hidden sm:flex items-center gap-6">
          <Link
            href="/#for-teachers"
            className="text-sm font-bold uppercase tracking-wider text-hare hover:text-eel transition-colors"
          >
            For Teachers
          </Link>
          <Link
            href="/login"
            className="rounded-duo border-2 border-swan bg-snow px-5 py-2 text-sm font-extrabold uppercase tracking-wider text-sky shadow-[0_2px_0_#E5E5E5] hover:bg-polar hover:border-[#CECECE] hover:shadow-[0_2px_0_#CECECE] active:shadow-none active:translate-y-[2px] transition-all duration-100"
          >
            Log in
          </Link>
        </div>

        {/* Mobile hamburger */}
        <button
          onClick={() => setMobileOpen(!mobileOpen)}
          className="sm:hidden flex flex-col gap-1.5 p-2"
          aria-label="Toggle menu"
        >
          <span
            className={`block w-6 h-0.5 bg-eel transition-transform duration-200 ${
              mobileOpen ? "rotate-45 translate-y-2" : ""
            }`}
          />
          <span
            className={`block w-6 h-0.5 bg-eel transition-opacity duration-200 ${
              mobileOpen ? "opacity-0" : ""
            }`}
          />
          <span
            className={`block w-6 h-0.5 bg-eel transition-transform duration-200 ${
              mobileOpen ? "-rotate-45 -translate-y-2" : ""
            }`}
          />
        </button>
      </Container>

      {/* Mobile dropdown */}
      {mobileOpen && (
        <div className="sm:hidden border-t border-swan bg-snow">
          <Container className="py-4 flex flex-col gap-4">
            <Link
              href="/#for-teachers"
              onClick={() => setMobileOpen(false)}
              className="text-sm font-bold uppercase tracking-wider text-hare"
            >
              For Teachers
            </Link>
            <Link
              href="/login"
              onClick={() => setMobileOpen(false)}
              className="rounded-duo border-2 border-swan bg-snow px-5 py-2 text-sm font-extrabold uppercase tracking-wider text-sky shadow-[0_2px_0_#E5E5E5] text-center"
            >
              Log in
            </Link>
          </Container>
        </div>
      )}
    </nav>
  );
}
