import { useEffect, useMemo, useState } from "react";

interface ConfettiProps {
  pieces?: number;
}

export function Confetti({ pieces = 70 }: ConfettiProps) {
  const bits = useMemo(
    () =>
      Array.from({ length: pieces }, (_, index) => ({
        left: Math.random() * 100,
        delay: Math.random() * 0.45,
        duration: 1.6 + Math.random() * 1.1,
        size: 6 + Math.random() * 6,
        rotation: Math.random() * 360,
        color: ["#00f0ff", "#ffd166", "#c084fc", "#34d399", "#f472b6"][
          index % 5
        ],
      })),
    [pieces],
  );
  const [reducedMotion, setReducedMotion] = useState(
    () =>
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches,
  );

  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReducedMotion(query.matches);
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);

  if (reducedMotion) {
    return null;
  }

  return (
    <div aria-hidden="true" className="reward-confetti">
      {bits.map((bit, index) => (
        <span
          className="reward-confetti-piece"
          key={index}
          style={{
            left: `${bit.left}%`,
            width: bit.size,
            height: bit.size * 0.45,
            background: bit.color,
            animationDelay: `${bit.delay}s`,
            animationDuration: `${bit.duration}s`,
            transform: `rotate(${bit.rotation}deg)`,
          }}
        />
      ))}
    </div>
  );
}

interface CountUpProps {
  to: number;
  durationMs?: number;
}

export function CountUp({ to, durationMs = 900 }: CountUpProps) {
  const [value, setValue] = useState(0);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setValue(to);
      return;
    }

    let frame = 0;
    const start = performance.now();
    const step = (now: number) => {
      const progress = Math.min(1, (now - start) / durationMs);
      setValue(Math.round(to * (1 - (1 - progress) ** 3)));
      if (progress < 1) {
        frame = window.requestAnimationFrame(step);
      }
    };
    frame = window.requestAnimationFrame(step);
    return () => window.cancelAnimationFrame(frame);
  }, [durationMs, to]);

  return <>{value}</>;
}
