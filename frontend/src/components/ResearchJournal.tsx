import { ArrowLeft, BookOpen, CheckCircle2, CircleHelp, Sparkles } from "lucide-react";
import type { JournalEntry, PlayerProgress } from "../gamification/api";
import { sound } from "../utils/audio";
import { CosmeticShop } from "./CosmeticShop";
import { Memories } from "./Memories";
import { TrainingCertificate } from "./TrainingCertificate";

interface ResearchJournalProps {
  entries: JournalEntry[];
  progress: PlayerProgress;
  callsign: string;
  onBack: () => void;
}

export function ResearchJournal({
  entries,
  progress,
  callsign,
  onBack,
}: ResearchJournalProps) {
  const missionProgress = progress.missions.find(
    (item) => item.mission_id === "level-1",
  );
  const completed = Boolean(missionProgress?.completed);
  const earnedEntries = entries.filter(
    (entry) =>
      entry.correct &&
      entry.xp_awarded > 0 &&
      progress.completed_task_ids.includes(entry.task_id),
  );
  const completedAt =
    earnedEntries
      .map((entry) => entry.submitted_at)
      .sort((left, right) => left.localeCompare(right))
      .at(-1) ?? null;

  return (
    <main className="game-page reference-page journal-page">
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
      <header className="reference-page-heading journal-heading">
        <div>
          <p className="reference-eyebrow"><BookOpen size={15} /> PILOT RECORD</p>
          <h1 className="reference-title">RESEARCH JOURNAL</h1>
          <p className="reference-subtitle">
            Training logs, earned progress, and your own field memories.
          </p>
        </div>
        <TrainingCertificate
          callsign={callsign}
          completedAt={completedAt}
          eligible={completed}
        />
      </header>

      <section className="journal-stat-grid" aria-label="Training progress summary">
        <article className="journal-stat-card journal-stat-card--cyan">
          <span>RANK</span><strong>{progress.rank.name}</strong>
        </article>
        <article className="journal-stat-card journal-stat-card--gold">
          <span>BACKEND XP</span><strong>{progress.total_xp}</strong>
        </article>
        <article className="journal-stat-card journal-stat-card--mint">
          <span>RADAR ROOKIE</span>
          <strong>{missionProgress?.completed_tasks ?? 0}/{missionProgress?.total_tasks ?? 4}</strong>
        </article>
        <article className="journal-stat-card journal-stat-card--purple">
          <span>ANSWER LOGS</span><strong>{entries.length}</strong>
        </article>
      </section>

      <section className="journal-progress-card">
        <div className="journal-progress-card__heading">
          <span className="level-sticker">LEVEL 1</span>
          <div>
            <p className="reference-eyebrow">TRAINING ACHIEVEMENT</p>
            <h2>RADAR ROOKIE</h2>
          </div>
          {completed && <span className="achievement-earned"><Sparkles size={14} /> COMPLETE</span>}
        </div>
        <div className="journal-task-progress">
          {["1.1", "1.2", "1.3", "1.4"].map((taskId) => {
            const done = progress.completed_task_ids.includes(taskId);
            return (
              <span className={done ? "is-complete" : ""} key={taskId}>
                {done ? <CheckCircle2 size={16} /> : <CircleHelp size={16} />}
                Challenge {taskId}
              </span>
            );
          })}
        </div>
        {!completed && (
          <p className="journal-certificate-progress">
            Complete all four challenges to earn the training certificate.
          </p>
        )}
      </section>

      <section className="journal-logs-section">
        <header className="journal-section-heading">
          <div>
            <p className="reference-eyebrow">SERVER-RECORDED ANSWERS</p>
            <h2>MISSION LOGS</h2>
          </div>
          <span>{entries.length} {entries.length === 1 ? "entry" : "entries"}</span>
        </header>
        {entries.length === 0 ? (
          <div className="journal-empty">
            <CircleHelp size={25} />
            <strong>No training answers logged yet</strong>
            <p>Complete a Radar Rookie challenge to add your first entry.</p>
          </div>
        ) : (
          <div className="journal-list">
            {entries.map((entry, index) => (
              <article
                className={`journal-entry reference-log-entry${entry.correct ? " is-correct" : " is-learning"}`}
                key={`${entry.task_id}-${entry.submitted_at}-${index}`}
              >
                <div className="journal-entry-status" aria-hidden="true">
                  {entry.correct ? <CheckCircle2 size={19} /> : <CircleHelp size={19} />}
                </div>
                <div className="journal-entry-main">
                  <div className="journal-entry-heading">
                    <div>
                      <span className="game-overline">CHALLENGE {entry.task_id}</span>
                      <h3>{entry.task_title}</h3>
                    </div>
                    <time dateTime={entry.submitted_at}>
                      {new Date(entry.submitted_at).toLocaleString()}
                    </time>
                  </div>
                  <p className="journal-answer">
                    Selected answer <strong>{entry.answer}</strong>
                    {entry.xp_awarded > 0 && <span> · +{entry.xp_awarded} backend XP</span>}
                  </p>
                  <p className="journal-explanation">{entry.explanation}</p>
                </div>
                <span className={`journal-result-tag${entry.correct ? " is-correct" : ""}`}>
                  {entry.correct ? "LEARNED" : "REVIEW"}
                </span>
              </article>
            ))}
          </div>
        )}
      </section>

      <Memories />
      <CosmeticShop />
    </main>
  );
}
