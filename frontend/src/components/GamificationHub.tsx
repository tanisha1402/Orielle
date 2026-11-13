import { useEffect, useState } from "react";
import {
  fetchMissions,
  fetchPlayerProgress,
  fetchResearchJournal,
  getOrCreatePlayerId,
  submitMissionAnswer,
  type AnswerResult,
  type JournalEntry,
  type Mission,
  type MissionTask,
  type PlayerProgress,
} from "../gamification/api";
import { MissionBriefing } from "./MissionBriefing";
import { MissionControl } from "./MissionControl";
import { ResearchJournal } from "./ResearchJournal";
import { Reveal } from "./Reveal";
import { TaskRunner } from "./TaskRunner";

type Screen = "control" | "briefing" | "task" | "reveal" | "journal";

export function GamificationHub() {
  const [playerId, setPlayerId] = useState<string | null>(null);
  const [missions, setMissions] = useState<Mission[]>([]);
  const [progress, setProgress] = useState<PlayerProgress | null>(null);
  const [journal, setJournal] = useState<JournalEntry[]>([]);
  const [selectedTask, setSelectedTask] = useState<MissionTask | null>(null);
  const [answerResult, setAnswerResult] = useState<AnswerResult | null>(null);
  const [screen, setScreen] = useState<Screen>("control");
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    const load = async () => {
      setLoading(true);
      setError(null);
      try {
        const id = getOrCreatePlayerId();
        const [missionData, progressData, journalData] = await Promise.all([
          fetchMissions(),
          fetchPlayerProgress(id),
          fetchResearchJournal(id),
        ]);
        if (!active) {
          return;
        }
        setPlayerId(id);
        setMissions(missionData);
        setProgress(progressData);
        setJournal(journalData);
      } catch (loadError) {
        if (active) {
          setError(
            `Training service is unavailable: ${loadError instanceof Error ? loadError.message : "unknown error"}`,
          );
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };
    void load();
    return () => {
      active = false;
    };
  }, [retry]);

  const mission = missions[0];

  const refreshPlayerRecords = async (id: string) => {
    const [updatedProgress, updatedJournal] = await Promise.all([
      fetchPlayerProgress(id),
      fetchResearchJournal(id),
    ]);
    setProgress(updatedProgress);
    setJournal(updatedJournal);
  };

  const handleAnswer = async (answer: string) => {
    if (!playerId || !selectedTask) {
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const result = await submitMissionAnswer(
        playerId,
        selectedTask.id,
        answer,
      );
      setAnswerResult(result);
      setScreen("reveal");
      try {
        await refreshPlayerRecords(playerId);
      } catch (refreshError) {
        setError(
          `Answer saved, but player records could not be refreshed: ${refreshError instanceof Error ? refreshError.message : "unknown error"}`,
        );
      }
    } catch (submitError) {
      setError(
        `Answer was not submitted: ${submitError instanceof Error ? submitError.message : "unknown error"}`,
      );
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return <div className="game-service-state">Loading training missions…</div>;
  }
  if (error && (!mission || !progress)) {
    return (
      <div className="game-service-state game-service-state--error" role="alert">
        <p>{error}</p>
        <button
          className="game-button game-button--quiet"
          onClick={() => setRetry((value) => value + 1)}
        >
          Retry connection
        </button>
      </div>
    );
  }
  if (!mission || !progress) {
    return (
      <div className="game-service-state">
        No training mission is currently available.
      </div>
    );
  }

  return (
    <div className="gamification-hub">
      {error && (
        <div className="game-inline-error" role="status">
          {error}
        </div>
      )}
      {screen === "control" && (
        <MissionControl
          mission={mission}
          progress={progress}
          onBriefing={() => setScreen("briefing")}
          onJournal={() => setScreen("journal")}
        />
      )}
      {screen === "briefing" && (
        <MissionBriefing
          mission={mission}
          onBack={() => setScreen("control")}
          onBegin={() => {
            const task = mission.tasks.find(
              (item) =>
                item.released && !progress.completed_task_ids.includes(item.id),
            );
            if (task) {
              setSelectedTask(task);
              setScreen("task");
            }
          }}
        />
      )}
      {screen === "task" && selectedTask && (
        <TaskRunner
          task={selectedTask}
          busy={submitting}
          onBack={() => setScreen("briefing")}
          onSubmit={(answer) => void handleAnswer(answer)}
        />
      )}
      {screen === "reveal" && answerResult && selectedTask && (
        <div className="game-page game-page--narrow">
          <Reveal
            status={answerResult.correct ? "success" : "learning"}
            title={
              answerResult.correct
                ? answerResult.already_completed
                  ? "Task already complete"
                  : "Signal understood"
                : "Review the signal"
            }
            message={answerResult.explanation}
            xpAwarded={answerResult.xp_awarded}
            onContinue={() => {
              setAnswerResult(null);
              setSelectedTask(null);
              setScreen("control");
            }}
          >
            <strong>Correct training answer: {answerResult.correct_answer}</strong>
            <span>
              This reveal is a learning aid, not a result from satellite data.
            </span>
          </Reveal>
        </div>
      )}
      {screen === "journal" && (
        <ResearchJournal
          entries={journal}
          onBack={() => setScreen("control")}
        />
      )}
    </div>
  );
}
