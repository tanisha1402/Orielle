import { useState } from "react";
import { ArrowLeft, Sparkles } from "lucide-react";
import {
  AvatarEditor,
  loadAvatar,
  saveAvatar,
  type AvatarConfig,
} from "./Avatar";
import { loadPilotCallsign, savePilotCallsign } from "./PilotProfile";
import { sound } from "../utils/audio";

interface MissionPilotProps {
  onBack: () => void;
}

export function MissionPilot({ onBack }: MissionPilotProps) {
  const [avatar, setAvatar] = useState<AvatarConfig>(loadAvatar);
  const [callsign, setCallsign] = useState(loadPilotCallsign);

  const saveProfile = (nextAvatar: AvatarConfig, nextCallsign: string) => {
    const avatarSaved = saveAvatar(nextAvatar);
    const callsignSaved = savePilotCallsign(nextCallsign);
    setAvatar(nextAvatar);
    setCallsign(nextCallsign);
    const saved = avatarSaved && callsignSaved;
    if (saved) {
      sound.playSuccessChime();
    }
    return saved;
  };

  return (
    <main className="game-page reference-page mission-pilot-page">
      <button
        className="reference-back"
        onClick={() => {
          sound.playKeyClick();
          onBack();
        }}
        type="button"
      >
        <ArrowLeft aria-hidden="true" size={15} />
        Mission Control
      </button>
      <header className="reference-page-heading">
        <div>
          <p className="reference-eyebrow">
            <Sparkles aria-hidden="true" size={15} /> FLIGHT DECK
          </p>
          <h1 className="reference-title">MISSION PILOT</h1>
          <p className="reference-subtitle">
            Customize your callsign and look. Your pilot profile stays saved in
            this browser.
          </p>
        </div>
      </header>
      <AvatarEditor
        callsign={callsign}
        cancelLabel="BACK TO MISSION CONTROL"
        initial={avatar}
        onCancel={() => {
          sound.playKeyClick();
          onBack();
        }}
        onSave={saveProfile}
      />
    </main>
  );
}
