import type { ReactNode } from "react";
import { ArrowRight, Check, Info, Trophy } from "lucide-react";
import { Confetti, CountUp } from "./RewardEffects";
import { sound } from "../utils/audio";

interface RevealProps {
  status: "success" | "learning";
  eyebrow?: string;
  title: string;
  message: string;
  xpAwarded?: number;
  rankUp?: string | null;
  alreadyCompleted?: boolean;
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
  rankUp = null,
  alreadyCompleted = false,
  visual,
  children,
  onContinue,
  continueLabel = "Return to Mission Control",
}: RevealProps) {
  const success = status === "success";

  return (
    <section
      aria-live="polite"
      className={`reveal-panel reference-reveal-panel ${success ? "reveal-panel--success" : "reveal-panel--learning"}`}
    >
      {success && xpAwarded > 0 && <Confetti />}
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
      {alreadyCompleted && (
        <p className="replay-result-note" role="note">
          Replay answer checked. Your original completion, XP, and journal
          entry are unchanged.
        </p>
      )}
      {children && <div className="reveal-evidence">{children}</div>}
      {xpAwarded > 0 && (
        <div className="reveal-xp" aria-label={`${xpAwarded} experience points earned`}>
          <span>+</span>
          <strong>
            <CountUp to={xpAwarded} />
          </strong>
          <small>XP</small>
        </div>
      )}
      {rankUp && (
        <div className="reveal-rank-up" role="status">
          <Trophy aria-hidden="true" size={16} />
          <span>NEW RANK</span>
          <strong>{rankUp}</strong>
        </div>
      )}
      <button
        className="reference-button reference-button--gold"
        onClick={() => {
          sound.playKeyClick();
          onContinue();
        }}
        type="button"
      >
        {continueLabel}
        <ArrowRight aria-hidden="true" size={16} />
      </button>
    </section>
  );
}
