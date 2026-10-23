import { Hero } from "@/components/hero";
import { Features } from "@/components/features";
import { GuideTerminal } from "@/components/guide-terminal";
import { Compare } from "@/components/compare";
import { Benchmark } from "@/components/benchmark";

export default function HomeZh() {
  return (
    <>
      <Hero lang="zh" />
      <GuideTerminal lang="zh" />
      <Features lang="zh" />
      <Compare lang="zh" />
      <Benchmark lang="zh" />
    </>
  );
}
