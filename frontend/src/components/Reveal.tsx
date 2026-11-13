import type { ReactNode } from "react";
import { ArrowRight, Check, Info } from "lucide-react";

interface RevealProps {
  status: "success" | "learning";
  eyebrow?: string;
  title: string;
  message: string;
  xpAwarded?: number;
  visual?: ReactNode;
  children?: ReactNode;
  onContinue: () => void;
  continueLabel?: string;
}

export function Reveal({
  status,
  eyebrow = "TRAINING REVEAL",
  title,
  message,
  xpAwarded = 0,
  visual,
  children,
  onContinue,
  continueLabel = "Return to Mission Control",
}: RevealProps) {
  const success = status === "success";

  return (
    <section
      aria-live="polite"
      className={`reveal-panel ${success ? "reveal-panel--success" : "reveal-panel--learning"}`}
    >
      <div className="reveal-visual">
        {visual ?? (
          <div className="reveal-symbol" aria-hidden="true">
            {success ? <Check size={25} /> : <Info size={25} />}
          </div>
        )}
      </div>
      <p className="eyebrow">{eyebrow} · SIMULATED EXERCISE</p>
      <h2>{title}</h2>
      <p className="reveal-message">{message}</p>
      {children && <div className="reveal-evidence">{children}</div>}
      {xpAwarded > 0 && (
        <div className="reveal-xp" aria-label={`${xpAwarded} experience points earned`}>
          <span>+</span>
          <strong>{xpAwarded}</strong>
          <small>XP</small>
        </div>
      )}
      <button className="game-button game-button--primary" onClick={onContinue}>
        {continueLabel}
        <ArrowRight aria-hidden="true" size={16} />
      </button>
    </section>
  );
}
