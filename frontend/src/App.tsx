import { useEffect, useState } from "react";
import {
  ArrowUpRight,
  Compass,
  Database,
  Info,
  Radio,
  Satellite,
  Waves,
} from "lucide-react";
import { MapView } from "./components/MapView";
import { GamificationHub } from "./components/GamificationHub";
import { EvidencePanel } from "./components/EvidencePanel";
import { MethodologyPanel } from "./components/MethodologyPanel";
import { ObservationCard } from "./components/ObservationCard";
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

export default function App() {
  const [activeWorkspace, setActiveWorkspace] = useState<"dashboard" | "training">(
    "dashboard",
  );
  const [scenePair, setScenePair] =
    useState<ScenePairMetadata>(INITIAL_SCENE_PAIR);
  const [analysis, setAnalysis] = useState<ChangeSummary | null>(null);
  const [integrationError, setIntegrationError] = useState<string | null>(null);
  const [dataStatus, setDataStatus] = useState<ApiDataStatus>("checking");

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
      <header className="topbar">
        <a aria-label="TERRALENS home" className="brand" href="#top">
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
        <nav aria-label="Workspace" className="topbar-nav">
          <button
            aria-current={activeWorkspace === "dashboard" ? "page" : undefined}
            className={activeWorkspace === "dashboard" ? "active" : ""}
            onClick={() => setActiveWorkspace("dashboard")}
          >
            SAR Dashboard
          </button>
          <button
            aria-current={activeWorkspace === "training" ? "page" : undefined}
            className={activeWorkspace === "training" ? "active" : ""}
            onClick={() => setActiveWorkspace("training")}
          >
            Mission Control
          </button>
        </nav>
        <div className="topbar-status">
          <span className="status-pulse" />
          <span>MISSION WORKSPACE</span>
        </div>
      </header>

      <main className="workspace" id="top">
        {activeWorkspace === "training" ? (
          <GamificationHub />
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
              Drag the divider to compare dates. Raster layers appear when a
              local tile service is configured.
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
          <span>Observed change is not a confirmed flood extent.</span>
        </footer>
          </>
        )}
      </main>
    </div>
  );
}
