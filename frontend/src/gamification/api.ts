export interface MissionOption {
  id: string;
  label: string;
}

export interface MissionTask {
  id: string;
  title: string;
  prompt: string;
  options: MissionOption[];
  xp: number;
  released: boolean;
  training_only: boolean;
}

export interface Mission {
  id: string;
  slug: string;
  level: number;
  title: string;
  tagline: string;
  briefing: string;
  training_only: boolean;
  tasks: MissionTask[];
}

export interface Rank {
  name: string;
  minimum_xp: number;
  next_rank: string | null;
  xp_to_next: number | null;
}

export interface MissionProgress {
  mission_id: string;
  completed_tasks: number;
  total_tasks: number;
  completed: boolean;
}

export interface PlayerProgress {
  player_id: string;
  total_xp: number;
  rank: Rank;
  completed_task_ids: string[];
  missions: MissionProgress[];
}

export interface AnswerResult {
  player_id: string;
  submission_id: string;
  task_id: string;
  correct: boolean;
  correct_answer: string;
  explanation: string;
  xp_awarded: number;
  total_xp: number;
  rank: Rank;
  duplicate_submission: boolean;
  already_completed: boolean;
  training_only: true;
}

export interface JournalEntry {
  task_id: string;
  task_title: string;
  answer: string;
  correct: boolean;
  xp_awarded: number;
  submitted_at: string;
  explanation: string;
  training_only: true;
}

const apiBaseUrl = (
  import.meta.env.VITE_TERRALENS_API_URL?.trim() || "http://127.0.0.1:8000"
).replace(/\/+$/, "");
const playerStorageKey = "terralens.training.player-id";
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function requestJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...init?.headers,
    },
  });
  if (!response.ok) {
    let detail = `${response.status} ${response.statusText}`;
    try {
      const payload = (await response.json()) as { detail?: unknown };
      if (typeof payload.detail === "string") {
        detail = payload.detail;
      }
    } catch {
      // Keep the HTTP status when the server does not return JSON.
    }
    throw new Error(detail);
  }
  return (await response.json()) as T;
}

export function getOrCreatePlayerId(): string {
  const existing = window.localStorage.getItem(playerStorageKey);
  if (existing && uuidPattern.test(existing)) {
    return existing;
  }
  const playerId = window.crypto.randomUUID();
  window.localStorage.setItem(playerStorageKey, playerId);
  return playerId;
}

export async function fetchMissions(): Promise<Mission[]> {
  const payload = await requestJson<{ missions: Mission[] }>(
    "/api/gamification/missions",
  );
  return payload.missions;
}

export function fetchPlayerProgress(
  playerId: string,
): Promise<PlayerProgress> {
  return requestJson(
    `/api/gamification/players/${encodeURIComponent(playerId)}/progress`,
  );
}

export async function fetchResearchJournal(
  playerId: string,
): Promise<JournalEntry[]> {
  const payload = await requestJson<{ entries: JournalEntry[] }>(
    `/api/gamification/players/${encodeURIComponent(playerId)}/journal`,
  );
  return payload.entries;
}

export function submitMissionAnswer(
  playerId: string,
  taskId: string,
  answer: string,
): Promise<AnswerResult> {
  return requestJson(
    `/api/gamification/players/${encodeURIComponent(playerId)}/answers`,
    {
      method: "POST",
      body: JSON.stringify({
        submission_id: window.crypto.randomUUID(),
        task_id: taskId,
        answer,
      }),
    },
  );
}
