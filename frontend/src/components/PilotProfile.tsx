export const CALLSIGN_STORAGE_KEY = "terralens.pilot.callsign";
const DEFAULT_CALLSIGN = "Jamuna Explorer";

export function loadPilotCallsign(): string {
  try {
    return window.localStorage.getItem(CALLSIGN_STORAGE_KEY) || DEFAULT_CALLSIGN;
  } catch {
    return DEFAULT_CALLSIGN;
  }
}

export function savePilotCallsign(callsign: string): boolean {
  try {
    window.localStorage.setItem(CALLSIGN_STORAGE_KEY, callsign);
    return true;
  } catch {
    return false;
  }
}
