export interface LocalGameState {
  coins: number;
  bestSpot: number;
  bestSpeed: number;
  streak: { count: number; last: string };
  ownedThemes: string[];
  activeTheme: string;
}

export const COSMETIC_THEMES = [
  { id: "aurora", name: "Aurora", cost: 0, accent: "#00f0ff" },
  { id: "solar", name: "Solar", cost: 25, accent: "#ffb84d" },
  { id: "ocean", name: "Ocean", cost: 40, accent: "#38bdf8" },
  { id: "forest", name: "Forest", cost: 60, accent: "#34d399" },
] as const;

const STORAGE_KEY = "terralens.fun.v1";
export const LOCAL_GAME_STATE_EVENT = "terralens:local-game-state-change";

export const EMPTY_LOCAL_GAME_STATE: LocalGameState = {
  coins: 0,
  bestSpot: 0,
  bestSpeed: 0,
  streak: { count: 0, last: "" },
  ownedThemes: ["aurora"],
  activeTheme: "aurora",
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export function loadLocalGameState(): LocalGameState {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return EMPTY_LOCAL_GAME_STATE;
    const parsed: unknown = JSON.parse(raw);
    if (!isRecord(parsed)) return EMPTY_LOCAL_GAME_STATE;

    const streak = isRecord(parsed.streak) ? parsed.streak : {};
    const ownedThemes = Array.isArray(parsed.ownedThemes)
      ? parsed.ownedThemes.filter(
          (item): item is string =>
            typeof item === "string" &&
            COSMETIC_THEMES.some((theme) => theme.id === item),
        )
      : ["aurora"];
    const activeTheme =
      typeof parsed.activeTheme === "string" &&
      COSMETIC_THEMES.some((theme) => theme.id === parsed.activeTheme) &&
      ownedThemes.includes(parsed.activeTheme)
        ? parsed.activeTheme
        : "aurora";

    return {
      coins:
        typeof parsed.coins === "number" && Number.isFinite(parsed.coins)
          ? Math.max(0, Math.floor(parsed.coins))
          : 0,
      bestSpot:
        typeof parsed.bestSpot === "number" && Number.isFinite(parsed.bestSpot)
          ? Math.max(0, Math.floor(parsed.bestSpot))
          : 0,
      bestSpeed:
        typeof parsed.bestSpeed === "number" &&
        Number.isFinite(parsed.bestSpeed)
          ? Math.max(0, Math.floor(parsed.bestSpeed))
          : 0,
      streak: {
        count:
          typeof streak.count === "number" && Number.isFinite(streak.count)
            ? Math.max(0, Math.floor(streak.count))
            : 0,
        last: typeof streak.last === "string" ? streak.last : "",
      },
      ownedThemes: [...new Set(["aurora", ...ownedThemes])],
      activeTheme,
    };
  } catch {
    return EMPTY_LOCAL_GAME_STATE;
  }
}

export function saveLocalGameState(state: LocalGameState): boolean {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    window.dispatchEvent(new Event(LOCAL_GAME_STATE_EVENT));
    return true;
  } catch {
    return false;
  }
}

function dayKey(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

export function touchLocalStreak(state: LocalGameState): LocalGameState {
  const today = dayKey(new Date());
  if (state.streak.last === today) return state;
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  return {
    ...state,
    streak: {
      count:
        state.streak.last === dayKey(yesterday)
          ? state.streak.count + 1
          : 1,
      last: today,
    },
  };
}
