"use client";

import { Container } from "@/components/ui/Container";
import { ScrollReveal } from "@/components/ui/ScrollReveal";
import { APP_STORE_URL, GOOGLE_PLAY_URL } from "@/lib/constants";

export function AppDownload() {
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
              Available on mobile
            </span>
          </div>
          <h2 className="text-3xl md:text-4xl font-black text-eel mb-4 tracking-tight">
            Learn anytime, anywhere
          </h2>
          <p className="text-lg text-hare mb-8 max-w-lg mx-auto leading-relaxed">
            Download Owlio on your phone or tablet. Pick up where you left off,
            on any device.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center gap-3 rounded-duo bg-eel text-snow px-8 py-3.5 font-bold text-sm shadow-[0_4px_0_#2a2a2a] hover:brightness-110 active:shadow-none active:translate-y-[4px] transition-all duration-100"
            >
              <svg width="20" height="24" viewBox="0 0 20 24" fill="currentColor">
                <path d="M16.52 12.46c-.03-3.13 2.55-4.63 2.67-4.71-1.45-2.12-3.72-2.41-4.53-2.45-1.93-.2-3.76 1.14-4.74 1.14-.98 0-2.49-1.11-4.1-1.08-2.11.03-4.05 1.23-5.14 3.12-2.19 3.8-.56 9.44 1.57 12.53 1.04 1.51 2.29 3.2 3.92 3.14 1.57-.06 2.17-1.02 4.07-1.02 1.9 0 2.44 1.02 4.1.99 1.69-.03 2.77-1.54 3.8-3.06 1.2-1.75 1.69-3.45 1.72-3.54-.04-.02-3.3-1.27-3.34-5.06z"/>
              </svg>
              <span>
                <span className="block text-[10px] font-normal leading-none opacity-70">
                  Download on the
                </span>
                App Store
              </span>
            </a>
            <a
              href={GOOGLE_PLAY_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center gap-3 rounded-duo bg-eel text-snow px-8 py-3.5 font-bold text-sm shadow-[0_4px_0_#2a2a2a] hover:brightness-110 active:shadow-none active:translate-y-[4px] transition-all duration-100"
            >
              <svg width="20" height="22" viewBox="0 0 20 22" fill="currentColor">
                <path d="M1 1.26l8.43 8.74L1 18.74V1.26zm1.41-1L11.3 9.14l2.37-2.45L2.95.08c-.19-.1-.37-.06-.54.18zM11.3 10.86L2.41 19.74c.17.24.35.28.54.18l10.72-6.61-2.37-2.45zM14.68 7.57L12.17 10l2.51 2.43 3.01-1.86c.44-.27.44-.7 0-.97l-3.01-2.03z"/>
              </svg>
              <span>
                <span className="block text-[10px] font-normal leading-none opacity-70">
                  Get it on
                </span>
                Google Play
              </span>
            </a>
          </div>
        </ScrollReveal>
      </Container>
    </section>
  );
}
