import { ArrowLeft, ArrowRight, Target } from "lucide-react";
import type { Mission } from "../gamification/api";

interface MissionBriefingProps {
  mission: Mission;
  onBack: () => void;
  onBegin: () => void;
}

export function MissionBriefing({
  mission,
  onBack,
  onBegin,
}: MissionBriefingProps) {
  const availableTask = mission.tasks.find((task) => task.released);

  return (
    <div className="game-page game-page--narrow">
      <button className="game-back-button" onClick={onBack}>
        <ArrowLeft aria-hidden="true" size={15} />
        Mission Control
      </button>
      <section className="briefing-card">
        <div className="briefing-mark" aria-hidden="true">
          <Target size={23} />
        </div>
        <p className="eyebrow">LEVEL {mission.level} · TRAINING SIMULATION</p>
        <h1>{mission.title}</h1>
        <p className="briefing-tagline">{mission.tagline}</p>
        <p className="briefing-copy">{mission.briefing}</p>
        <div className="briefing-objectives">
          <span className="game-overline">MISSION OBJECTIVES</span>
          {mission.tasks.map((task) => (
            <div className="briefing-objective" key={task.id}>
              <span>{task.id}</span>
              <strong>{task.title}</strong>
              <small>{task.released ? "AVAILABLE NOW" : "COMING NEXT"}</small>
            </div>
          ))}
        </div>
        <div className="training-disclaimer">
          <strong>Training data only</strong>
          <p>
            This mission teaches concepts with synthetic examples. It does not
            contain satellite observations or claim a flood finding.
          </p>
        </div>
        <button
          className="game-button game-button--primary game-button--wide"
          disabled={!availableTask}
          onClick={onBegin}
        >
          Begin {availableTask?.id ?? "training task"}
          <ArrowRight aria-hidden="true" size={16} />
        </button>
      </section>
    </div>
  );
}
