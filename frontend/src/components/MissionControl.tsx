import { useState, type PointerEvent } from "react";
import {
  BookOpen,
  CheckCircle2,
  Circle,
  LockKeyhole,
  Play,
  RotateCcw,
  Sparkles,
} from "lucide-react";
import { sound } from "../utils/audio";
import { PilotProfile } from "./PilotProfile";
import type {
  Mission,
  MissionTask,
  PlayerProgress,
} from "../gamification/api";

interface MissionControlProps {
  mission: Mission;
  progress: PlayerProgress;
  developmentResetEnabled: boolean;
  onSelectTask: (task: MissionTask, replay: boolean) => void;
  onReset: () => void;
  onJournal: () => void;
}

export function MissionControl({
  mission,
  progress,
  developmentResetEnabled,
  onSelectTask,
  onReset,
  onJournal,
}: MissionControlProps) {
  const [tilt, setTilt] = useState({ x: 0, y: 0 });
  const missionProgress = progress.missions.find(
    (item) => item.mission_id === mission.id,
  );
  const handleCardPointerMove = (event: PointerEvent<HTMLElement>) => {
    if (
      event.pointerType !== "mouse" ||
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      return;
    }
    const bounds = event.currentTarget.getBoundingClientRect();
    const x = (event.clientX - bounds.left) / bounds.width;
    const y = (event.clientY - bounds.top) / bounds.height;
    setTilt({ x: (0.5 - y) * 4, y: (x - 0.5) * 5 });
  };
  const nextTask = mission.tasks.find(
    (task) =>
      task.released &&
      task.unlocked &&
      !progress.completed_task_ids.includes(task.id),
  );
  const replayTask = mission.tasks.find(
    (task) =>
      task.released &&
      task.unlocked &&
      progress.completed_task_ids.includes(task.id),
  );
  const featuredTask = nextTask ?? replayTask;
  const featuredTaskIsReplay = !nextTask && Boolean(replayTask);

  return (
    <div className="game-page mission-hub">
      <div className="game-page-heading">
        <div>
          <p className="eyebrow">TRAINING SIMULATION · LEVEL {mission.level}</p>
          <h1>Mission Control</h1>
          <p className="game-subtitle">
            Build radar literacy with guided exercises. Training progress is
            separate from satellite-derived findings.
          </p>
        </div>
        <div className="mission-control-actions">
          {developmentResetEnabled && (
            <button
              className="game-button game-button--reset"
              onClick={() => {
                sound.playKeyClick();
                onReset();
              }}
              type="button"
            >
              <RotateCcw aria-hidden="true" size={15} />
              Reset training
            </button>
          )}
          <button
            className="game-button game-button--quiet"
            onClick={() => {
              sound.playKeyClick();
              onJournal();
            }}
            type="button"
          >
            <BookOpen aria-hidden="true" size={16} />
            Research Journal
          </button>
        </div>
      </div>

      <section className="player-progress-card" aria-label="Player progress">
        <PilotProfile compact />
        <div className="progress-rank">
          <span className="progress-emblem">
            <Sparkles aria-hidden="true" size={19} />
          </span>
          <div>
            <span className="game-overline">CURRENT RANK</span>
            <strong>{progress.rank.name}</strong>
          </div>
        </div>
        <div className="progress-xp">
          <strong>{progress.total_xp}</strong>
          <span>XP earned</span>
        </div>
        {progress.rank.next_rank && progress.rank.xp_to_next !== null && (
          <div className="progress-next-rank">
            <span>{progress.rank.xp_to_next} XP to</span>
            <strong>{progress.rank.next_rank}</strong>
          </div>
        )}
      </section>

      <section
        className="mission-card mission-card--interactive"
        onPointerLeave={() => setTilt({ x: 0, y: 0 })}
        onPointerMove={handleCardPointerMove}
        style={{
          transform: `perspective(1100px) rotateX(${tilt.x}deg) rotateY(${tilt.y}deg)`,
        }}
      >
        <div className="mission-card-header">
          <div className="mission-card-index">01</div>
          <div className="mission-card-title">
            <p className="game-overline">LEVEL 1 · {mission.tasks.length} TASKS</p>
            <h2>{mission.title}</h2>
            <p>{mission.tagline}</p>
          </div>
          <span className="training-chip">SIMULATION</span>
        </div>
        <div
          aria-label={`${missionProgress?.completed_tasks ?? 0} of ${missionProgress?.total_tasks ?? mission.tasks.length} tasks complete`}
          className="mission-progress-track"
        >
          <span
            style={{
              width: `${((missionProgress?.completed_tasks ?? 0) / (missionProgress?.total_tasks ?? mission.tasks.length)) * 100}%`,
            }}
          />
        </div>
        <div className="mission-task-list">
          {mission.tasks.map((task) => {
            const completed = progress.completed_task_ids.includes(task.id);
            const available = task.released && task.unlocked;
            return (
              <button
                aria-label={
                  !task.released
                    ? `${task.title}, coming soon`
                    : !task.unlocked
                      ? `${task.title}, complete the previous challenge to unlock`
                      : completed
                        ? `Replay ${task.title}; no additional XP`
                        : `Play ${task.title}`
                }
                className={`mission-task-row${completed ? " mission-task-row--complete" : ""}`}
                disabled={!available}
                key={task.id}
                onClick={() => {
                  sound.playKeyClick();
                  onSelectTask(task, completed);
                }}
                type="button"
              >
                <span
                  className={`mission-task-icon ${completed ? "mission-task-icon--complete" : ""}`}
                  aria-hidden="true"
                >
                  {completed ? (
                    <CheckCircle2 size={17} />
                  ) : task.released ? (
                    <Circle size={17} />
                  ) : (
                    <LockKeyhole size={16} />
                  )}
                </span>
                <span className="mission-task-id">{task.id}</span>
                <span className="mission-task-name">{task.title}</span>
                <span className="mission-task-xp">
                  {completed ? "NO XP" : `${task.xp} XP`}
                </span>
                <span className="mission-task-state">
                  {completed
                    ? "COMPLETE · REPLAY"
                    : !task.released
                      ? "COMING SOON"
                      : task.unlocked
                        ? "AVAILABLE"
                        : "LOCKED"}
                </span>
              </button>
            );
          })}
        </div>
        <div className="mission-card-footer">
          <span>
            {missionProgress?.completed_tasks ?? 0} /{" "}
            {missionProgress?.total_tasks ?? mission.tasks.length} tasks
            complete
          </span>
          {featuredTask ? (
            <button
              className="game-button game-button--primary"
              onClick={() => {
                sound.playKeyClick();
                onSelectTask(featuredTask, featuredTaskIsReplay);
              }}
              type="button"
            >
              <Play aria-hidden="true" size={15} />
              {featuredTaskIsReplay ? "Replay a challenge" : "Continue mission"}
            </button>
          ) : (
            <span className="mission-all-complete">
              All released challenges complete
            </span>
          )}
        </div>
      </section>

      <p className="game-science-note">
        Training content is simulated. It does not display or represent real
        Sentinel-1, NISAR, flood, or river-change measurements.
      </p>
    </div>
  );
}
