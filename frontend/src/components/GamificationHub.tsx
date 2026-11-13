import { useEffect, useState } from "react";
import {
  fetchMissions,
  fetchGamificationConfig,
  fetchPlayerProgress,
  fetchResearchJournal,
  getOrCreatePlayerId,
  resetPlayerProgress,
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
import { ArcadeHub } from "./ArcadeHub";
import { playRankUp, sound } from "../utils/audio";
import { loadPilotCallsign } from "./PilotProfile";

export type GamificationScreen =
  | "control"
  | "briefing"
  | "task"
  | "reveal"
  | "journal"
  | "arcade";

interface GamificationHubProps {
  initialScreen?: GamificationScreen;
  onScreenChange?: (screen: GamificationScreen) => void;
}

export function GamificationHub({
  initialScreen = "control",
  onScreenChange,
}: GamificationHubProps) {
  const [playerId, setPlayerId] = useState<string | null>(null);
  const [missions, setMissions] = useState<Mission[]>([]);
  const [progress, setProgress] = useState<PlayerProgress | null>(null);
  const [journal, setJournal] = useState<JournalEntry[]>([]);
  const [selectedTask, setSelectedTask] = useState<MissionTask | null>(null);
  const [answerResult, setAnswerResult] = useState<AnswerResult | null>(null);
  const [rankUp, setRankUp] = useState<string | null>(null);
  const [developmentResetEnabled, setDevelopmentResetEnabled] = useState(false);
  const [isReplay, setIsReplay] = useState(false);
  const [screen, setScreenState] = useState<GamificationScreen>(initialScreen);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  const setScreen = (next: GamificationScreen) => {
    setScreenState(next);
    onScreenChange?.(next);
  };

  useEffect(() => {
    setScreenState(initialScreen);
  }, [initialScreen]);

  useEffect(() => {
    let active = true;
    const load = async () => {
      setLoading(true);
      setError(null);
      try {
        const id = getOrCreatePlayerId();
        const [missionData, progressData, journalData, configData] = await Promise.all([
          fetchMissions(id),
          fetchPlayerProgress(id),
          fetchResearchJournal(id),
          fetchGamificationConfig(),
        ]);
        if (!active) {
          return;
        }
        setPlayerId(id);
        setMissions(missionData);
        setProgress(progressData);
        setJournal(journalData);
        setDevelopmentResetEnabled(configData.development_reset_enabled);
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
    const [updatedProgress, updatedJournal, updatedMissions] = await Promise.all(
      [
        fetchPlayerProgress(id),
        fetchResearchJournal(id),
        fetchMissions(id),
      ],
    );
    setProgress(updatedProgress);
    setJournal(updatedJournal);
    setMissions(updatedMissions);
    return updatedProgress;
  };

  const selectTask = (task: MissionTask, replay: boolean) => {
    setSelectedTask(task);
    setIsReplay(replay);
    setScreen("briefing");
  };

  const handleDevelopmentReset = async () => {
    if (!playerId || !developmentResetEnabled) {
      return;
    }
    const confirmed = window.confirm(
      "Reset this player's training XP, challenge progress, and journal? This does not touch SAR data or analysis outputs.",
    );
    if (!confirmed) {
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await resetPlayerProgress(playerId);
      setSelectedTask(null);
      setAnswerResult(null);
      setRankUp(null);
      setIsReplay(false);
      await refreshPlayerRecords(playerId);
      setScreen("control");
    } catch (resetError) {
      setError(
        `Training progress could not be reset: ${resetError instanceof Error ? resetError.message : "unknown error"}`,
      );
    } finally {
      setSubmitting(false);
    }
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
      setRankUp(
        result.xp_awarded > 0 &&
          progress &&
          progress.rank.name !== result.rank.name
          ? result.rank.name
          : null,
      );
      setScreen("reveal");
      if (result.correct) {
        sound.playSuccessChime();
        if (
          result.xp_awarded > 0 &&
          progress &&
          progress.rank.name !== result.rank.name
        ) {
          window.setTimeout(playRankUp, 350);
        }
      } else if (!result.correct) {
        sound.playRadarPing();
      }
      try {
        const updatedProgress = await refreshPlayerRecords(playerId);
        const previousMission = progress?.missions.find(
          (item) => item.mission_id === mission?.id,
        );
        const updatedMission = updatedProgress.missions.find(
          (item) => item.mission_id === mission?.id,
        );
        if (
          !previousMission?.completed &&
          updatedMission?.completed &&
          result.xp_awarded > 0
        ) {
          window.setTimeout(() => sound.playTrophyFanfare(), 850);
        }
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
          developmentResetEnabled={developmentResetEnabled}
          mission={mission}
          progress={progress}
          onReset={() => void handleDevelopmentReset()}
          onSelectTask={selectTask}
          onJournal={() => setScreen("journal")}
        />
      )}
      {screen === "briefing" && (
        <MissionBriefing
          mission={mission}
          replay={isReplay}
          task={selectedTask ?? mission.tasks[0]}
          onBack={() => setScreen("control")}
          onBegin={() => {
            if (selectedTask?.released && selectedTask.unlocked) {
              setScreen("task");
            }
          }}
        />
      )}
      {screen === "task" && selectedTask && (
        <TaskRunner
          task={selectedTask}
          replay={isReplay}
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
            rankUp={rankUp}
            alreadyCompleted={answerResult.already_completed}
            onContinue={() => {
              setAnswerResult(null);
              setSelectedTask(null);
              setRankUp(null);
              setScreen("control");
            }}
          >
            <strong>Correct training answer: {answerResult.correct_answer}</strong>
          </Reveal>
        </div>
      )}
      {screen === "journal" && (
        <ResearchJournal
          entries={journal}
          callsign={loadPilotCallsign()}
          progress={progress}
          onBack={() => setScreen("control")}
        />
      )}
      {screen === "arcade" && <ArcadeHub />}
    </div>
  );
}
