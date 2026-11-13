import { useEffect, useState } from "react";
import {
  ArrowUpRight,
  BookOpen,
  Compass,
  Database,
  Gamepad2,
  Info,
  Radio,
  Satellite,
  Waves,
} from "lucide-react";
import { MapView } from "./components/MapView";
import { GamificationHub } from "./components/GamificationHub";
import type { GamificationScreen } from "./components/GamificationHub";
import { CosmicBackground } from "./components/CosmicBackground";
import { EvidencePanel } from "./components/EvidencePanel";
import { MethodologyPanel } from "./components/MethodologyPanel";
import { ObservationCard } from "./components/ObservationCard";
import { SoundToggle } from "./components/SoundToggle";
import { WelcomeScreen } from "./components/WelcomeScreen";
import { parseChangeSummary, type ChangeSummary } from "./data/analysis";
import {
  LOCAL_INTEGRATION,
  parseApiDataStatus,
  type ApiDataStatus,
} from "./data/integration";
import {
  INITIAL_SCENE_PAIR,
  JAMUNA_STUDY_AREA,
  parseScenePairMetadata,
  type ScenePairMetadata,
} from "./data/mission";
import {
  readSoundPreference,
  sound,
} from "./utils/audio";

export default function App() {
  const [activeWorkspace, setActiveWorkspace] = useState<
    "welcome" | "dashboard" | "training" | "journal" | "arcade"
  >("welcome");
  const [scenePair, setScenePair] =
    useState<ScenePairMetadata>(INITIAL_SCENE_PAIR);
  const [analysis, setAnalysis] = useState<ChangeSummary | null>(null);
  const [integrationError, setIntegrationError] = useState<string | null>(null);
  const [dataStatus, setDataStatus] = useState<ApiDataStatus>("checking");
  const [soundEnabled, setSoundEnabled] = useState(() => {
    const enabled = readSoundPreference();
    sound.enabled = enabled;
    return enabled;
  });

  useEffect(() => {
    const controller = new AbortController();
    let requestInProgress = false;

    const fetchJson = async (url: string): Promise<unknown> => {
      const response = await fetch(url, { signal: controller.signal });
      if (!response.ok) {
        throw new Error(`${response.status} ${response.statusText}`);
      }
      return response.json();
    };

    const refresh = async () => {
      if (requestInProgress) {
        return;
      }
      requestInProgress = true;
      try {
        const remoteStatus = parseApiDataStatus(
          await fetchJson(LOCAL_INTEGRATION.statusUrl),
        );
        if (remoteStatus === "waiting") {
          setDataStatus("waiting");
          setScenePair(INITIAL_SCENE_PAIR);
          setAnalysis(null);
          setIntegrationError(null);
          return;
        }

        let scenePayload: unknown;
        let changePayload: unknown;
        if (
          LOCAL_INTEGRATION.sceneMetadataUrl ===
          LOCAL_INTEGRATION.changeResultUrl
        ) {
          scenePayload = await fetchJson(LOCAL_INTEGRATION.sceneMetadataUrl);
          changePayload = scenePayload;
        } else {
          [scenePayload, changePayload] = await Promise.all([
            fetchJson(LOCAL_INTEGRATION.sceneMetadataUrl),
            fetchJson(LOCAL_INTEGRATION.changeResultUrl),
          ]);
        }
        const updatedScenePair = parseScenePairMetadata(scenePayload);
        const updatedAnalysis = parseChangeSummary(changePayload);
        setScenePair(updatedScenePair);
        setAnalysis(updatedAnalysis);
        setDataStatus("ready");
        setIntegrationError(null);
      } catch (error) {
        if (controller.signal.aborted) {
          return;
        }
        setDataStatus("unavailable");
        setScenePair(INITIAL_SCENE_PAIR);
        setAnalysis(null);
        setIntegrationError(
          `Local SAR backend is unavailable: ${error instanceof Error ? error.message : "unknown error"}`,
        );
      } finally {
        requestInProgress = false;
      }
    };

    void refresh();
    const refreshTimer = window.setInterval(() => void refresh(), 5000);

    return () => {
      window.clearInterval(refreshTimer);
      controller.abort();
    };
  }, []);

  return (
    <div className="app-shell">
      <CosmicBackground />
      {activeWorkspace === "welcome" ? (
        <WelcomeScreen
          soundEnabled={soundEnabled}
          onSoundChange={setSoundEnabled}
          onLaunchMission={() => setActiveWorkspace("training")}
          onExploreDashboard={() => setActiveWorkspace("dashboard")}
        />
      ) : (
        <>
      <header className="topbar tl-header">
        <a
          aria-label="TERRALENS home"
          className="brand"
          href="#welcome"
          onClick={(event) => {
            event.preventDefault();
            sound.playKeyClick();
            setActiveWorkspace("welcome");
          }}
        >
          <span className="brand-mark">
            <Satellite aria-hidden="true" size={21} strokeWidth={1.8} />
          </span>
          <span className="brand-wordmark">TERRA<span>LENS</span></span>
        </a>
        <div className="topbar-context">
          <span className="context-divider" />
          <span>EARTH OBSERVATION LAB</span>
          <span className="context-slash">/</span>
          <span>JAMUNA RIVER</span>
        </div>
        <nav aria-label="Workspace" className="topbar-nav tl-nav">
          {([
            { id: "dashboard", label: "SAR Lab", icon: <Compass aria-hidden="true" size={15} /> },
            { id: "training", label: "Missions", icon: <Satellite aria-hidden="true" size={15} /> },
            { id: "journal", label: "Journal", icon: <BookOpen aria-hidden="true" size={15} /> },
            { id: "arcade", label: "Arcade", icon: <Gamepad2 aria-hidden="true" size={15} /> },
          ] as const).map((item) => (
            <button
              aria-current={activeWorkspace === item.id ? "page" : undefined}
              className={`tl-nav-btn${activeWorkspace === item.id ? " is-active" : ""}`}
              key={item.id}
              onClick={() => {
                sound.playKeyClick();
                setActiveWorkspace(item.id);
              }}
              type="button"
            >
              {item.icon}
              <span className="tl-nav-label">{item.label}</span>
            </button>
          ))}
        </nav>
        <SoundToggle enabled={soundEnabled} onChange={setSoundEnabled} />
        <div className="topbar-status">
          <span className="status-pulse" />
          <span>MISSION WORKSPACE</span>
        </div>
      </header>

      <main className="workspace" id="top">
        {activeWorkspace === "training" ||
        activeWorkspace === "journal" ||
        activeWorkspace === "arcade" ? (
          <GamificationHub
            initialScreen={
              activeWorkspace === "journal"
                ? "journal"
                : activeWorkspace === "arcade"
                  ? "arcade"
                  : "control"
            }
            onScreenChange={(screen: GamificationScreen) => {
              setActiveWorkspace(
                screen === "journal"
                  ? "journal"
                  : screen === "arcade"
                    ? "arcade"
                    : "training",
              );
            }}
          />
        ) : (
          <>
        <section className="mission-heading" id="investigation">
          <div>
            <div className="mission-kicker">
              <span className="mission-index">MISSION 01</span>
              <span className="mission-kicker-line" />
              <span className="mission-type">SAR CHANGE INVESTIGATION</span>
            </div>
            <h1>
              The changing <span>Jamuna</span>
            </h1>
            <p className="mission-subtitle">
              Compare radar observations near Sirajganj, Bangladesh.
              Investigate what changed along the river.
            </p>
          </div>
          <a className="method-link" href="#methodology">
            <Info aria-hidden="true" size={15} />
            <span>How this analysis works</span>
            <ArrowUpRight aria-hidden="true" size={14} />
          </a>
        </section>

        {integrationError && (
          <div className="integration-error" role="status">
            <Info aria-hidden="true" size={15} />
            {integrationError}
          </div>
        )}

        <section aria-label="Scene metadata" className="observation-row">
          <ObservationCard label="Before" scene={scenePair.before} />
          <div aria-hidden="true" className="observation-connector">
            <span />
            <span />
            <span />
          </div>
          <ObservationCard label="After" scene={scenePair.after} />
          <div className="observation-context">
            <div className="context-icon">
              <Compass aria-hidden="true" size={17} />
            </div>
            <div>
              <span>STUDY AREA</span>
              <strong>{JAMUNA_STUDY_AREA.name}</strong>
              <small>{JAMUNA_STUDY_AREA.subregion}</small>
            </div>
          </div>
        </section>

        <div className="content-grid">
          <section aria-label="Interactive before and after map" className="map-column">
            <div className="section-heading">
              <div>
                <p className="eyebrow">CHANGE DETECTIVE</p>
                <h2>Radar comparison</h2>
              </div>
              <div className="map-source-tag">
                <Radio aria-hidden="true" size={14} />
                SENTINEL-1 · C-BAND
              </div>
            </div>
            <MapView
              analysis={analysis}
              dataStatus={dataStatus}
              rasterTileJson={LOCAL_INTEGRATION.rasterTileJson}
            />
            <p className="map-caption">
              <Waves aria-hidden="true" size={14} />
              Drag the divider to compare the two observations. The overlay
              appears when local SAR outputs are available.
            </p>
            <EvidencePanel
              analysis={analysis}
              dataStatus={dataStatus}
              scenePair={scenePair}
            />
          </section>

          <MethodologyPanel analysis={analysis} />
        </div>

        <footer className="workspace-footer">
          <span>
            <Database aria-hidden="true" size={13} />
            DATA STATE:{" "}
              {dataStatus === "ready"
                ? "ANALYSIS SUMMARY RECEIVED"
                : dataStatus === "waiting"
                  ? "WAITING FOR SAR PROCESSING"
                  : dataStatus === "unavailable"
                    ? "LOCAL BACKEND UNAVAILABLE"
                    : "CHECKING LOCAL SAR OUTPUTS"}
          </span>
          <span>Jamuna River · Sentinel-1 RTC investigation</span>
        </footer>
          </>
        )}
      </main>
        </>
      )}
    </div>
  );
}
