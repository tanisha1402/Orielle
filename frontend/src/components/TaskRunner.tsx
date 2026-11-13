import { ArrowLeft, ArrowRight, Radio } from "lucide-react";
import { useState } from "react";
import type { MissionTask } from "../gamification/api";

interface TaskRunnerProps {
  task: MissionTask;
  busy: boolean;
  onBack: () => void;
  onSubmit: (answer: string) => void;
}

export function TaskRunner({
  task,
  busy,
  onBack,
  onSubmit,
}: TaskRunnerProps) {
  const [selected, setSelected] = useState("");

  return (
    <div className="game-page game-page--narrow">
      <button className="game-back-button" disabled={busy} onClick={onBack}>
        <ArrowLeft aria-hidden="true" size={15} />
        Mission briefing
      </button>
      <section className="task-card">
        <div className="task-card-topline">
          <span>RADAR ROOKIE · TASK {task.id}</span>
          <span>{task.xp} XP</span>
        </div>
        <div className="task-simulation-label">
          <Radio aria-hidden="true" size={14} />
          SIMULATED TRAINING EXERCISE · NO REAL SAR DATA
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
          onClick={() => onSubmit(selected)}
        >
          {busy ? "Checking answer…" : "Submit answer"}
          {!busy && <ArrowRight aria-hidden="true" size={16} />}
        </button>
      </section>
    </div>
  );
}
