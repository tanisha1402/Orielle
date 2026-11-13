import { Volume2, VolumeX } from "lucide-react";
import { setSoundPreference, sound } from "../utils/audio";

interface SoundToggleProps {
  enabled: boolean;
  onChange: (enabled: boolean) => void;
}

export function SoundToggle({ enabled, onChange }: SoundToggleProps) {
  const toggle = () => {
    const nextEnabled = !enabled;
    setSoundPreference(nextEnabled);
    if (nextEnabled) {
      sound.playKeyClick();
    }
    onChange(nextEnabled);
  };

  return (
    <button
      aria-label={enabled ? "Turn sound off" : "Turn sound on"}
      aria-pressed={enabled}
      className="sound-toggle"
      onClick={toggle}
      type="button"
    >
      {enabled ? (
        <Volume2 aria-hidden="true" size={16} />
      ) : (
        <VolumeX aria-hidden="true" size={16} />
      )}
      <span>Sound {enabled ? "on" : "off"}</span>
    </button>
  );
}
