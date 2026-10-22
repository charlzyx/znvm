"use client";

import { useEffect, useState } from "react";

type Line = { kind: "in" | "out"; text: string };

const script: Line[] = [
  { kind: "in", text: "curl -fsSL https://znvm.dev/install-as-nvm.sh | bash" },
  { kind: "out", text: "nvm is ready." },
  { kind: "in", text: "nvm install 22" },
  { kind: "out", text: "Installed v22" },
  { kind: "in", text: "nvm use 22" },
  { kind: "out", text: "Using v22" },
  { kind: "in", text: "nvm current" },
  { kind: "out", text: "v22" },
];

function useReducedMotion() {
  const [reduced, setReduced] = useState(false);
  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const apply = () => setReduced(query.matches);
    apply();
    query.addEventListener("change", apply);
    return () => query.removeEventListener("change", apply);
  }, []);
  return reduced;
}

export function TypingTerminal() {
  const reduced = useReducedMotion();
  const total = script.reduce((sum, line) => sum + line.text.length, 0);
  const [shown, setShown] = useState(0);

  useEffect(() => {
    if (reduced) return;
    const delay = shown >= total ? 2200 : 28;
    const timer = window.setTimeout(() => {
      setShown((current) => (current >= total ? 0 : current + 1));
    }, delay);
    return () => window.clearTimeout(timer);
  }, [reduced, shown, total]);

  const visible = reduced ? total : shown;
  let remaining = visible;
  const drawn = script.flatMap((line) => {
    const take = Math.min(remaining, line.text.length);
    remaining -= take;
    if (take === 0) return [];
    return [{ ...line, text: line.text.slice(0, take) }];
  });

  const transcript = script.map((line) => (line.kind === "in" ? `$ ${line.text}` : line.text)).join(". ");

  return (
    <div>
      <div className="term-frame" aria-hidden="true">
        <div className="term-chrome">
          <span className="term-dot" />
          <span className="term-dot" />
          <span className="term-dot" />
          <span className="term-title">bash</span>
        </div>
        <pre className="term-body">
          {drawn.map((line, index) => (
            <div key={`${index}-${line.text}`}>
              {line.kind === "in" ? <span className="term-prompt">$ </span> : null}
              <span className={line.kind === "out" ? "term-out" : undefined}>{line.text}</span>
              {index === drawn.length - 1 ? <span className="term-caret" /> : null}
            </div>
          ))}
          {drawn.length === 0 ? (
            <div>
              <span className="term-prompt">$ </span>
              <span className="term-caret" />
            </div>
          ) : null}
        </pre>
      </div>
      <p className="sr-only">{transcript}</p>
    </div>
  );
}
