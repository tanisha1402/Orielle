import {
  BookOpen,
  CheckCircle2,
  Circle,
  LockKeyhole,
  Play,
  Sparkles,
} from "lucide-react";
import type {
  Mission,
  PlayerProgress,
} from "../gamification/api";

interface MissionControlProps {
  mission: Mission;
  progress: PlayerProgress;
  onBriefing: () => void;
  onJournal: () => void;
}

export function MissionControl({
  mission,
  progress,
  onBriefing,
  onJournal,
}: MissionControlProps) {
  const missionProgress = progress.missions.find(
    (item) => item.mission_id === mission.id,
  );
  const hasAvailableTask = mission.tasks.some(
    (task) =>
      task.released && !progress.completed_task_ids.includes(task.id),
  );

  return (
    <div className="game-page">
      <div className="game-page-heading">
        <div>
          <p className="eyebrow">TRAINING SIMULATION · LEVEL {mission.level}</p>
          <h1>Mission Control</h1>
          <p className="game-subtitle">
            Build radar literacy with guided exercises. Training progress is
            separate from satellite-derived findings.
          </p>
        </div>
        <button className="game-button game-button--quiet" onClick={onJournal}>
          <BookOpen aria-hidden="true" size={16} />
          Research Journal
        </button>
      </div>

      <section className="player-progress-card" aria-label="Player progress">
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

      <section className="mission-card">
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
            return (
              <div className="mission-task-row" key={task.id}>
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
                <span className="mission-task-xp">{task.xp} XP</span>
                <span className="mission-task-state">
                  {completed
                    ? "COMPLETE"
                    : task.released
                      ? "AVAILABLE"
                      : "COMING NEXT"}
                </span>
              </div>
            );
          })}
        </div>
        <div className="mission-card-footer">
          <span>
            {missionProgress?.completed_tasks ?? 0} /{" "}
            {missionProgress?.total_tasks ?? mission.tasks.length} tasks
            complete
          </span>
          <button
            className="game-button game-button--primary"
            disabled={!hasAvailableTask}
            onClick={onBriefing}
          >
            <Play aria-hidden="true" size={15} />
            {missionProgress?.completed
              ? "Mission complete"
              : hasAvailableTask
                ? "Open mission briefing"
                : "Task complete · More coming soon"}
          </button>
        </div>
      </section>

      <p className="game-science-note">
        Training content is simulated. It does not display or represent real
        Sentinel-1, NISAR, flood, or river-change measurements.
      </p>
    </div>
  );
}
