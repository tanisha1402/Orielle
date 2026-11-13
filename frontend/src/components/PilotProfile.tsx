import { useState } from "react";
import { Edit3 } from "lucide-react";
import {
  AvatarEditor,
  PilotAvatar,
  loadAvatar,
  saveAvatar,
  type AvatarConfig,
} from "./Avatar";
import { sound } from "../utils/audio";

const CALLSIGN_STORAGE_KEY = "terralens.pilot.callsign";
const DEFAULT_CALLSIGN = "Jamuna Explorer";

function loadCallsign(): string {
  try {
    return window.localStorage.getItem(CALLSIGN_STORAGE_KEY) || DEFAULT_CALLSIGN;
  } catch {
    return DEFAULT_CALLSIGN;
  }
}

export function PilotProfile({ compact = false }: { compact?: boolean }) {
  const [avatar, setAvatar] = useState<AvatarConfig>(loadAvatar);
  const [callsign, setCallsign] = useState(loadCallsign);
  const [editorOpen, setEditorOpen] = useState(false);

  const saveProfile = (nextAvatar: AvatarConfig, nextCallsign: string) => {
    saveAvatar(nextAvatar);
    try {
      window.localStorage.setItem(CALLSIGN_STORAGE_KEY, nextCallsign);
    } catch {
      // The saved look remains available for the current session.
    }
    setAvatar(nextAvatar);
    setCallsign(nextCallsign);
    setEditorOpen(false);
    sound.playSuccessChime();
  };

  return (
    <>
      <button
        aria-haspopup="dialog"
        aria-label={`Customize pilot ${callsign}`}
        className={`pilot-profile${compact ? " pilot-profile--compact" : ""}`}
        onClick={() => {
          sound.playKeyClick();
          setEditorOpen(true);
        }}
        type="button"
      >
        <PilotAvatar cfg={avatar} ring size={compact ? 46 : 68} />
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
