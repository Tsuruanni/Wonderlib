import { Hero } from "@/components/home/Hero";
import { SocialProof } from "@/components/home/SocialProof";
import { ValueProps } from "@/components/home/ValueProps";
import { ForTeachers } from "@/components/home/ForTeachers";
import { Gamification } from "@/components/home/Gamification";
import { AppDownload } from "@/components/home/AppDownload";
import { FinalCTA } from "@/components/home/FinalCTA";

export default function Home() {
  return (
    <>
      <Hero />
      <SocialProof />
      <ValueProps />
      <ForTeachers />
      <Gamification />
      <AppDownload />
      <FinalCTA />
    </>
  );
}
