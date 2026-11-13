import { ArrowLeft, ArrowRight, Radio } from "lucide-react";
import { useState } from "react";
import type { MissionTask } from "../gamification/api";
import { sound } from "../utils/audio";

interface TaskRunnerProps {
  task: MissionTask;
  replay: boolean;
  busy: boolean;
  onBack: () => void;
  onSubmit: (answer: string) => void;
}

export function TaskRunner({
  task,
  replay,
  busy,
  onBack,
  onSubmit,
}: TaskRunnerProps) {
  const [selected, setSelected] = useState("");

  return (
    <div className="game-page game-page--narrow">
      <button
        className="game-back-button"
        disabled={busy}
        onClick={() => {
          sound.playKeyClick();
          onBack();
        }}
        type="button"
      >
        <ArrowLeft aria-hidden="true" size={15} />
        Mission briefing
      </button>
      <section className="task-card">
        <div className="task-card-topline">
          <span>RADAR ROOKIE · TASK {task.id}</span>
          <span>{replay ? "REPLAY · NO XP" : `${task.xp} XP`}</span>
        </div>
        <div className="task-simulation-label">
          <Radio aria-hidden="true" size={14} />
          {replay
            ? "REPLAY MODE · NO ADDITIONAL XP OR JOURNAL ENTRY"
            : "SIMULATED TRAINING EXERCISE · NO REAL SAR DATA"}
        </div>
        <h1>{task.title}</h1>
        <p className="task-prompt">{task.prompt}</p>
        <fieldset className="task-options">
          <legend>Choose one answer</legend>
          {task.options.map((option) => (
            <label
              className={`task-option ${selected === option.id ? "task-option--selected" : ""}`}
              key={option.id}
            >
              <input
                checked={selected === option.id}
                disabled={busy}
                name="training-answer"
                onChange={() => setSelected(option.id)}
                type="radio"
                value={option.id}
              />
              <span className="task-option-id">{option.id}</span>
              <span>{option.label}</span>
            </label>
          ))}
        </fieldset>
        <button
          className="game-button game-button--primary game-button--wide"
          disabled={!selected || busy}
          onClick={() => {
            sound.playKeyClick();
            onSubmit(selected);
          }}
          type="button"
        >
          {busy ? "Checking answer…" : "Submit answer"}
          {!busy && <ArrowRight aria-hidden="true" size={16} />}
        </button>
      </section>
    </div>
  );
}
