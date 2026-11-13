import { ArrowLeft, ArrowRight, Target } from "lucide-react";
import type { Mission } from "../gamification/api";
import { RadarFactCard } from "./RadarFactCard";
import { sound } from "../utils/audio";
import { PilotProfile } from "./PilotProfile";

interface MissionBriefingProps {
  mission: Mission;
  task: Mission["tasks"][number];
  replay: boolean;
  onBack: () => void;
  onBegin: () => void;
}

export function MissionBriefing({
  mission,
  task,
  replay,
  onBack,
  onBegin,
}: MissionBriefingProps) {
  return (
    <div className="game-page game-page--narrow">
      <button
        className="game-back-button"
        onClick={() => {
          sound.playKeyClick();
          onBack();
        }}
        type="button"
      >
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
        <PilotProfile compact />
        <div className="briefing-selected-task">
          <span>CHALLENGE {task.id}</span>
          <h2>{task.title}</h2>
          {replay && (
            <strong className="replay-chip">
              REPLAY MODE · NO ADDITIONAL XP
            </strong>
          )}
        </div>
        <div className="briefing-objectives">
          <span className="game-overline">MISSION OBJECTIVES</span>
          {mission.tasks.map((objective) => (
            <div
              className={`briefing-objective${objective.id === task.id ? " briefing-objective--selected" : ""}`}
              key={objective.id}
            >
              <span>{objective.id}</span>
              <strong>{objective.title}</strong>
              <small>
                {!objective.released
                  ? "COMING SOON"
                  : objective.unlocked
                    ? objective.id === task.id
                      ? "UNLOCKED"
                      : "AVAILABLE"
                    : "LOCKED · FINISH PRIOR TASK"}
              </small>
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
        <RadarFactCard />
        <button
          className="game-button game-button--primary game-button--wide"
          disabled={!task.released || !task.unlocked}
          onClick={() => {
            sound.playLaunchFanfare();
            onBegin();
          }}
          type="button"
        >
          {replay ? `Replay ${task.id}` : `Launch ${task.id}`}
          <ArrowRight aria-hidden="true" size={16} />
        </button>
      </section>
    </div>
  );
}
