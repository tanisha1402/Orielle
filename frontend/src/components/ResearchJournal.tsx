import { ArrowLeft, BookOpen, CheckCircle2, CircleHelp } from "lucide-react";
import type { JournalEntry } from "../gamification/api";

interface ResearchJournalProps {
  entries: JournalEntry[];
  onBack: () => void;
}

export function ResearchJournal({ entries, onBack }: ResearchJournalProps) {
  return (
    <div className="game-page">
      <button className="game-back-button" onClick={onBack}>
        <ArrowLeft aria-hidden="true" size={15} />
        Mission Control
      </button>
      <div className="game-page-heading">
        <div>
          <p className="eyebrow">PLAYER RECORD · SIMULATED TRAINING</p>
          <h1>Research Journal</h1>
          <p className="game-subtitle">
            A record of training answers and learning notes—not satellite
            findings.
          </p>
        </div>
        <BookOpen aria-hidden="true" className="journal-heading-icon" size={27} />
      </div>
      {entries.length === 0 ? (
        <div className="journal-empty">
          <CircleHelp aria-hidden="true" size={22} />
          <strong>No training entries yet</strong>
          <p>Complete a mission exercise to start your journal.</p>
        </div>
      ) : (
        <div className="journal-list">
          {entries.map((entry, index) => (
            <article
              className="journal-entry"
              key={`${entry.task_id}-${entry.submitted_at}-${index}`}
            >
              <div
                className={`journal-entry-status ${entry.correct ? "journal-entry-status--correct" : "journal-entry-status--incorrect"}`}
                aria-hidden="true"
              >
                {entry.correct ? (
                  <CheckCircle2 size={18} />
                ) : (
                  <CircleHelp size={18} />
                )}
              </div>
              <div className="journal-entry-main">
                <div className="journal-entry-heading">
                  <div>
                    <span className="game-overline">
                      TRAINING TASK {entry.task_id}
                    </span>
                    <h2>{entry.task_title}</h2>
                  </div>
                  <time dateTime={entry.submitted_at}>
                    {new Date(entry.submitted_at).toLocaleString()}
                  </time>
                </div>
                <p className="journal-answer">
                  Answer selected: <strong>{entry.answer}</strong>
                  {entry.xp_awarded > 0 && (
                    <span> · +{entry.xp_awarded} XP</span>
                  )}
                </p>
                <p className="journal-explanation">{entry.explanation}</p>
              </div>
              <span className="training-chip">SIMULATED</span>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
