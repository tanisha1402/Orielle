import { useEffect, useState } from "react";
import { Edit3 } from "lucide-react";
import {
  AvatarEditor,
  PilotAvatar,
  loadAvatar,
  saveAvatar,
  type AvatarConfig,
} from "./Avatar";
import { sound } from "../utils/audio";
import {
  LOCAL_GAME_STATE_EVENT,
  loadLocalGameState,
} from "../gamification/localGameState";

export const CALLSIGN_STORAGE_KEY = "terralens.pilot.callsign";
const DEFAULT_CALLSIGN = "Jamuna Explorer";

export function loadPilotCallsign(): string {
  try {
    return window.localStorage.getItem(CALLSIGN_STORAGE_KEY) || DEFAULT_CALLSIGN;
  } catch {
    return DEFAULT_CALLSIGN;
  }
}

export function PilotProfile({ compact = false }: { compact?: boolean }) {
  const [avatar, setAvatar] = useState<AvatarConfig>(loadAvatar);
  const [callsign, setCallsign] = useState(loadPilotCallsign);
  const [editorOpen, setEditorOpen] = useState(false);
  const [theme, setTheme] = useState(() => loadLocalGameState().activeTheme);

  useEffect(() => {
    const refreshTheme = () => setTheme(loadLocalGameState().activeTheme);
    window.addEventListener(LOCAL_GAME_STATE_EVENT, refreshTheme);
    window.addEventListener("storage", refreshTheme);
    return () => {
      window.removeEventListener(LOCAL_GAME_STATE_EVENT, refreshTheme);
      window.removeEventListener("storage", refreshTheme);
    };
  }, []);

  const saveProfile = (nextAvatar: AvatarConfig, nextCallsign: string): boolean => {
    const avatarSaved = saveAvatar(nextAvatar);
    let callsignSaved = true;
    try {
      window.localStorage.setItem(CALLSIGN_STORAGE_KEY, nextCallsign);
    } catch {
      callsignSaved = false;
    }
    setAvatar(nextAvatar);
    setCallsign(nextCallsign);
    if (!avatarSaved || !callsignSaved) {
      return false;
    }
    setEditorOpen(false);
    sound.playSuccessChime();
    return true;
  };

  return (
    <>
      <button
        aria-haspopup="dialog"
        aria-label={`Customize pilot ${callsign}`}
        className={`pilot-profile${compact ? " pilot-profile--compact" : ""}`}
        data-theme={theme}
        onClick={() => {
          sound.playKeyClick();
          setEditorOpen(true);
        }}
        type="button"
      >
        <span className="pilot-avatar-frame">
          <PilotAvatar cfg={avatar} ring size={compact ? 46 : 68} />
        </span>
        <span className="pilot-profile-copy">
          <span>MISSION PILOT</span>
          <strong>{callsign}</strong>
        </span>
        <Edit3 aria-hidden="true" className="pilot-profile-edit" size={15} />
      </button>
      {editorOpen && (
        <AvatarEditor
          callsign={callsign}
          initial={avatar}
          onClose={() => setEditorOpen(false)}
          onSave={saveProfile}
        />
      )}
    </>
  );
}
