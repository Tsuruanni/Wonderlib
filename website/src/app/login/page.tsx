"use client";

import { useEffect } from "react";
import { Container } from "@/components/ui/Container";
import { APP_LOGIN_URL } from "@/lib/constants";

export default function LoginPage() {
  useEffect(() => {
    window.location.href = APP_LOGIN_URL;
  }, []);

  return (
    <div className="py-20 md:py-28">
      <Container className="text-center">
        <div className="text-6xl mb-6">🦉</div>
        <h1 className="text-2xl font-black text-eel mb-4">
          Redirecting to Owlio...
        </h1>
        <p className="text-hare">
          If you&apos;re not redirected automatically,{" "}
          <a
            href={APP_LOGIN_URL}
            className="text-sky font-bold hover:underline"
          >
            click here
          </a>
          .
        </p>
      </Container>
    </div>
  );
}
