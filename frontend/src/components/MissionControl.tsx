import { useEffect, useState, type PointerEvent } from "react";
import {
  Award,
  BookOpen,
  CheckCircle2,
  Flame,
  LockKeyhole,
  Play,
  RotateCcw,
  Sparkles,
  Trophy,
} from "lucide-react";
import { sound } from "../utils/audio";
import {
  loadLocalGameState,
  LOCAL_GAME_STATE_EVENT,
  saveLocalGameState,
  touchLocalStreak,
} from "../gamification/localGameState";
import type { Mission, MissionTask, PlayerProgress } from "../gamification/api";
import { loadAvatar, PilotAvatar } from "./Avatar";
import { loadPilotCallsign } from "./PilotProfile";

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
  const [storageMessage, setStorageMessage] = useState("");
  const [localState, setLocalState] = useState(() => {
    return touchLocalStreak(loadLocalGameState());
  });
  const missionProgress = progress.missions.find((item) => item.mission_id === mission.id);
  const completedTasks = progress.completed_task_ids;
  const progressRatio =
    (missionProgress?.completed_tasks ?? 0) /
    (missionProgress?.total_tasks ?? Math.max(1, mission.tasks.length));

  useEffect(() => {
    const refresh = () => setLocalState(loadLocalGameState());
    window.addEventListener(LOCAL_GAME_STATE_EVENT, refresh);
    window.addEventListener("storage", refresh);
    if (!saveLocalGameState(localState)) {
      setStorageMessage("Local streak and cosmetic data could not be saved in this browser.");
    }
    return () => {
      window.removeEventListener(LOCAL_GAME_STATE_EVENT, refresh);
      window.removeEventListener("storage", refresh);
    };
  }, []);

  const onCardMove = (event: PointerEvent<HTMLElement>) => {
    if (
      event.pointerType !== "mouse" ||
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) return;
    const bounds = event.currentTarget.getBoundingClientRect();
    const x = (event.clientX - bounds.left) / bounds.width;
    const y = (event.clientY - bounds.top) / bounds.height;
    setTilt({ x: (0.5 - y) * 4, y: (x - 0.5) * 6 });
  };

  const achievements = [
    { label: "FIRST SIGNAL", earned: completedTasks.length >= 1, icon: <Sparkles size={14} /> },
    { label: "PATTERN READER", earned: completedTasks.length >= 2, icon: <Award size={14} /> },
    { label: "RADAR ROOKIE", earned: Boolean(missionProgress?.completed), icon: <Trophy size={14} /> },
  ];

  return (
    <main className="game-page reference-page mission-hub">
      <header className="reference-page-heading">
        <div>
          <p className="reference-eyebrow"><Sparkles size={15} /> EARTH INVESTIGATOR TRAINING</p>
          <h1 className="reference-title">MISSION CONTROL</h1>
          <p className="reference-subtitle">
            Pick a challenge, tune your radar instincts, and build your pilot record.
          </p>
        </div>
        <div className="mission-control-actions">
          {developmentResetEnabled && (
            <button
              className="reference-button reference-button--quiet"
              onClick={() => {
                sound.playKeyClick();
                onReset();
              }}
              type="button"
            >
              <RotateCcw size={15} /> RESET TRAINING
            </button>
          )}
          <button
            className="reference-button reference-button--gold"
            onClick={() => {
              sound.playKeyClick();
              onJournal();
            }}
            type="button"
          >
            <BookOpen size={16} /> RESEARCH JOURNAL
          </button>
        </div>
      </header>

      <div className="mission-hub-layout">
        <aside className="pilot-dossier reference-game-card reference-game-card--purple">
          <div className="pilot-dossier__label">PILOT PROFILE</div>
          <div className="pilot-radar-frame">
            <span className="pilot-radar-ring pilot-radar-ring--outer" />
            <span className="pilot-radar-ring pilot-radar-ring--middle" />
            <span className="pilot-radar-crosshair pilot-radar-crosshair--horizontal" />
            <span className="pilot-radar-crosshair pilot-radar-crosshair--vertical" />
            <span className="pilot-radar-sweep" />
            <div className="pilot-radar-profile">
              <PilotAvatar cfg={loadAvatar()} size={66} ring />
              <span>MISSION PILOT</span>
              <strong>{loadPilotCallsign()}</strong>
            </div>
          </div>
          <div className="pilot-rank">
            <span><Award size={14} /> CURRENT RANK</span>
            <strong>{progress.rank.name}</strong>
          </div>
          <div className="pilot-xp-progress">
            <div>
              <span>BACKEND XP</span>
              <strong>{progress.total_xp}</strong>
            </div>
            {progress.rank.xp_to_next !== null && (
              <small>{progress.rank.xp_to_next} XP to {progress.rank.next_rank}</small>
            )}
            <div className="pilot-xp-track">
              <span
                style={{
                  width: progress.rank.xp_to_next === null
                    ? "100%"
                    : `${Math.min(100, (progress.total_xp / (progress.total_xp + progress.rank.xp_to_next)) * 100)}%`,
                }}
              />
            </div>
          </div>
          <div className="pilot-mini-stats">
            <div><Flame size={15} /><strong>{localState.streak.count}</strong><span>DAY STREAK</span></div>
            <div><span className="pilot-coin">✦</span><strong>{localState.coins}</strong><span>LOCAL COINS</span></div>
          </div>
          <div className="pilot-achievements">
            <span className="pilot-dossier__label">EARNED BADGES</span>
            <div>
              {achievements.map((achievement) => (
                <span
                  aria-label={`${achievement.label}: ${achievement.earned ? "earned" : "not yet earned"}`}
                  className={achievement.earned ? "is-earned" : ""}
                  key={achievement.label}
                  title={achievement.earned ? `${achievement.label} earned` : `${achievement.label} locked`}
                >
                  {achievement.earned ? achievement.icon : <LockKeyhole size={13} />}
                  {achievement.label}
                </span>
              ))}
            </div>
          </div>
        </aside>

        <section className="mission-selection">
          <div className="mission-selection__heading">
            <div>
              <p className="reference-eyebrow">LEVEL 01 · RADAR LITERACY</p>
              <h2>CHOOSE YOUR CHALLENGE</h2>
            </div>
            <span className="mission-level-sticker">RADAR ROOKIE</span>
          </div>
          <article
            className="reference-mission-card"
            onPointerLeave={() => setTilt({ x: 0, y: 0 })}
            onPointerMove={onCardMove}
            style={{
              transform: `perspective(1200px) rotateX(${tilt.x}deg) rotateY(${tilt.y}deg)`,
            }}
          >
            <header className="reference-mission-card__header">
              <div className="mission-level-emblem">01</div>
              <div>
                <span className="reference-eyebrow">LEVEL {mission.level} · {mission.tasks.length} CHALLENGES</span>
                <h3>{mission.title}</h3>
                <p>{mission.tagline}</p>
              </div>
              <span className="simulation-sticker">SIMULATION</span>
            </header>
            <div className="mission-hero-art" aria-label="Decorative radar training illustration">
              <span className="mission-hero-orbit mission-hero-orbit--one" />
              <span className="mission-hero-orbit mission-hero-orbit--two" />
              <span className="mission-hero-sweep" />
              <span className="mission-hero-blip mission-hero-blip--one" />
              <span className="mission-hero-blip mission-hero-blip--two" />
              <span className="mission-hero-label">CONCEPT RADAR · TRAINING ART</span>
            </div>
            <div className="mission-progress-heading">
              <span>MISSION PROGRESS</span>
              <strong>{missionProgress?.completed_tasks ?? 0} / {missionProgress?.total_tasks ?? mission.tasks.length}</strong>
            </div>
            <div
              aria-label={`${missionProgress?.completed_tasks ?? 0} of ${missionProgress?.total_tasks ?? mission.tasks.length} challenges complete`}
              className="reference-progress-track"
            >
              <span style={{ width: `${progressRatio * 100}%` }} />
            </div>
            <div className="challenge-card-grid">
              {mission.tasks.map((task, index) => {
                const completed = completedTasks.includes(task.id);
                const available = task.released && task.unlocked;
                return (
                  <button
                    aria-label={
                      !task.released
                        ? `${task.title}, coming soon`
                        : !task.unlocked
                          ? `${task.title}, locked until the previous challenge is completed`
                          : completed
                            ? `Replay ${task.title}; no additional XP`
                            : `Launch ${task.title}`
                    }
                    className={`challenge-card${completed ? " is-complete" : ""}${!available ? " is-locked" : ""}`}
                    disabled={!available}
                    key={task.id}
                    onClick={() => {
                      sound.playKeyClick();
                      onSelectTask(task, completed);
                    }}
                    style={{ "--challenge-index": index } as React.CSSProperties}
                    type="button"
                  >
                    <span className="challenge-card__top">
                      <span className="challenge-card__number">{task.id}</span>
                      {completed ? <CheckCircle2 size={17} /> : available ? <Play size={16} /> : <LockKeyhole size={15} />}
                    </span>
                    <span className="challenge-card__art" aria-hidden="true">
                      <span className="challenge-card__art-ring" />
                      <span className="challenge-card__art-core" />
                    </span>
                    <strong>{task.title}</strong>
                    <span className="challenge-card__reward">
                      {completed ? "COMPLETE · REPLAY" : !task.released ? "COMING SOON" : !task.unlocked ? "LOCKED" : `${task.xp} XP`}
                    </span>
                    {completed && <span className="challenge-card__no-xp">NO EXTRA XP</span>}
                  </button>
                );
              })}
            </div>
            <footer className="reference-mission-card__footer">
              <span><CheckCircle2 size={15} /> {missionProgress?.completed_tasks ?? 0} OF {mission.tasks.length} COMPLETED</span>
              {missionProgress?.completed ? (
                <span className="mission-complete-badge"><Trophy size={16} /> LEVEL COMPLETE</span>
              ) : (
                <span>Complete challenges in order to unlock the next one.</span>
              )}
            </footer>
          </article>
        </section>
      </div>
      {storageMessage && <p className="arcade-storage-message" role="status">{storageMessage}</p>}
    </main>
  );
}
