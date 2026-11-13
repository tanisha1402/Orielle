import { useState } from "react";
import {
  ArrowRight,
  Compass,
  Radar,
  Satellite,
} from "lucide-react";
import { SoundToggle } from "./SoundToggle";
import { PilotProfile } from "./PilotProfile";
import { sound } from "../utils/audio";

interface WelcomeScreenProps {
  soundEnabled: boolean;
  onSoundChange: (enabled: boolean) => void;
  onLaunchMission: () => void;
  onExploreDashboard: () => void;
}

export function WelcomeScreen({
  soundEnabled,
  onSoundChange,
  onLaunchMission,
  onExploreDashboard,
}: WelcomeScreenProps) {
  const [launching, setLaunching] = useState(false);

  const launchMission = () => {
    if (launching) {
      return;
    }
    sound.playLaunchFanfare();
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      onLaunchMission();
      return;
    }
    setLaunching(true);
    window.setTimeout(onLaunchMission, 430);
  };

  return (
    <main className={`welcome-screen${launching ? " welcome-screen--launching" : ""}`}>
      <header className="welcome-header">
        <div className="welcome-brand" aria-label="TERRALENS">
          <span className="welcome-brand-mark">
            <Satellite aria-hidden="true" size={18} />
          </span>
          <span>TERRA<span>LENS</span></span>
        </div>
        <div className="welcome-header-actions">
          <div className="welcome-program-tag">
            <span className="welcome-live-dot" />
            EARTH OBSERVATION LAB
          </div>
          <SoundToggle enabled={soundEnabled} onChange={onSoundChange} />
        </div>
      </header>

      <section className="welcome-hero">
        <div className="welcome-copy">
          <p className="welcome-kicker">
            <span>JAMUNA RIVER</span>
            <span className="welcome-kicker-line" />
            SIRAJGANJ, BANGLADESH
          </p>
          <h1
            aria-label="TERRALENS. Dance with the signals."
            className="welcome-title"
          >
            <span aria-hidden="true" className="welcome-title__brand">
              {"TERRALENS".split("").map((letter, index) => (
                <span key={`${letter}-${index}`} style={{ animationDelay: `${index * 65}ms` }}>
                  {letter}
                </span>
              ))}
            </span>
            <span className="welcome-title__tagline">Dance with the signals.</span>
          </h1>
          <p className="welcome-description">
            Explore how radar observes a changing river. Compare the real
            Sentinel-1 analysis, or build radar literacy in a separate training
            mission.
          </p>

          <div className="welcome-actions">
            <button
              className="welcome-launch-button"
              disabled={launching}
              onClick={launchMission}
              type="button"
            >
              Enter Mission Hub
              <ArrowRight aria-hidden="true" size={18} />
            </button>
            <button
              className="welcome-explore-button"
              onClick={() => {
                sound.playRadarPing();
                onExploreDashboard();
              }}
              type="button"
            >
              <Compass aria-hidden="true" size={16} />
              Explore SAR dashboard
            </button>
          </div>

          <PilotProfile />
        </div>

        <div className="welcome-radar-art" aria-hidden="true">
          <div className="welcome-orbit welcome-orbit--outer" />
          <div className="welcome-orbit welcome-orbit--middle" />
          <div className="welcome-orbit welcome-orbit--inner" />
          <div className="welcome-radar-crosshair welcome-radar-crosshair--horizontal" />
          <div className="welcome-radar-crosshair welcome-radar-crosshair--vertical" />
          <div className="welcome-radar-sweep" />
          <div className="welcome-radar-core">
            <Radar size={42} strokeWidth={1.2} />
          </div>
          <span className="welcome-signal welcome-signal--one" />
          <span className="welcome-signal welcome-signal--two" />
          <span className="welcome-signal welcome-signal--three" />
          <span className="welcome-radar-caption">C-BAND · JAMUNA STUDY AREA</span>
        </div>
      </section>

      <footer className="welcome-footer">
        <span>FIELD SITE 01 / JAMUNA RIVER</span>
      </footer>
    </main>
  );
}
