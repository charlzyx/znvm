import { Hero } from "@/components/hero";
import { Features } from "@/components/features";
import { GuideTerminal } from "@/components/guide-terminal";
import { Compare } from "@/components/compare";
import { Benchmark } from "@/components/benchmark";

export default function Home() {
  return (
    <>
      <Hero lang="en" />
      <Features lang="en" />
      <GuideTerminal lang="en" />
      <Compare lang="en" />
      <Benchmark lang="en" />
    </>
  );
}
