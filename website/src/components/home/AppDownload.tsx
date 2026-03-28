import { Container } from "@/components/ui/Container";
import { APP_STORE_URL, GOOGLE_PLAY_URL } from "@/lib/constants";

export function AppDownload() {
  return (
    <section className="py-16 md:py-24 bg-polar">
      <Container className="text-center">
        <h2 className="text-3xl md:text-4xl font-black text-eel mb-4">
          Learn anytime, anywhere
        </h2>
        <p className="text-lg text-hare mb-8 max-w-lg mx-auto">
          Download Owlio on your phone or tablet. Pick up where you left off,
          on any device.
        </p>
        <div className="flex flex-col sm:flex-row gap-4 justify-center">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center justify-center gap-2 rounded-duo bg-eel text-snow px-6 py-3 font-bold text-sm hover:bg-black transition-colors"
          >
            <span className="text-xl">🍎</span>
            <span>
              <span className="block text-[10px] font-normal leading-none">
                Download on the
              </span>
              App Store
            </span>
          </a>
          <a
            href={GOOGLE_PLAY_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center justify-center gap-2 rounded-duo bg-eel text-snow px-6 py-3 font-bold text-sm hover:bg-black transition-colors"
          >
            <span className="text-xl">▶️</span>
            <span>
              <span className="block text-[10px] font-normal leading-none">
                Get it on
              </span>
              Google Play
            </span>
          </a>
        </div>
      </Container>
    </section>
  );
}
