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
    <main className="game-page game-page--narrow reference-page reference-task-page">
      <button
        className="reference-back"
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
      <section className="task-card reference-task-card">
        <div className="task-card-topline">
          <span>RADAR ROOKIE · TASK {task.id}</span>
          <span>{replay ? "REPLAY" : `+${task.xp} XP`}</span>
        </div>
        <div className="task-simulation-label">
          <Radio aria-hidden="true" size={14} />
          {replay
            ? "REPLAY MODE · REWARDS ALREADY EARNED"
            : "RADAR CONCEPT SIMULATION"}
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
          className="reference-button reference-button--gold reference-task-submit"
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
    </main>
  );
}
