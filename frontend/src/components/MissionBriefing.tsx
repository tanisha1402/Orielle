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
    <main className="game-page game-page--narrow reference-page reference-briefing-page">
      <button
        className="reference-back"
        onClick={() => {
          sound.playKeyClick();
          onBack();
        }}
        type="button"
      >
        <ArrowLeft aria-hidden="true" size={15} />
        Mission Control
      </button>
      <section className="reference-briefing-card">
        <div className="reference-briefing-card__header">
          <div className="mission-level-emblem" aria-hidden="true">
            <Target size={24} />
          </div>
          <div>
            <p className="reference-eyebrow">LEVEL {mission.level} · RADAR ROOKIE</p>
            <h1>{mission.title}</h1>
            <p>{mission.tagline}</p>
          </div>
          <span className="simulation-sticker">TRAINING SIM</span>
        </div>
        <p className="reference-briefing-copy">{mission.briefing}</p>
        <div className="reference-briefing-pilot">
          <PilotProfile compact />
          <span>YOUR PILOT IS READY</span>
        </div>
        <div className="briefing-selected-task">
          <span className="reference-eyebrow">SELECTED CHALLENGE {task.id}</span>
          <h2><span>{task.id}</span>{task.title}</h2>
          {replay && (
            <strong className="replay-chip">
              REPLAY · REWARDS ALREADY EARNED
            </strong>
          )}
        </div>
        <div className="briefing-objectives">
          <span className="reference-eyebrow">MISSION CHALLENGES</span>
          <div className="briefing-objective-grid">
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
                        ? "SELECTED"
                        : "READY"
                      : "LOCKED"}
                </small>
              </div>
            ))}
          </div>
        </div>
        <RadarFactCard />
        <button
          className="reference-button reference-button--gold reference-briefing-launch"
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
    </main>
  );
}
