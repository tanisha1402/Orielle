import { AlertTriangle, CalendarDays, Database } from "lucide-react";
import type { ChangeSummary } from "../data/analysis";
import type { ApiDataStatus } from "../data/integration";
import type {
  SceneObservation,
  ScenePairMetadata,
} from "../data/mission";
import { PROCESSING_DEFAULTS } from "../data/mission";

interface EvidencePanelProps {
  analysis: ChangeSummary | null;
  dataStatus: ApiDataStatus;
  scenePair: ScenePairMetadata;
}

export function EvidencePanel({
  analysis,
  dataStatus,
  scenePair,
}: EvidencePanelProps) {
  const area = analysis
    ? `${analysis.newWaterAreaKm2.toLocaleString("en", {
        minimumFractionDigits: 4,
        maximumFractionDigits: 4,
      })} km²`
    : "—";
  const sharedCoverage = analysis
    ? `${analysis.commonValidPixels.toLocaleString("en")} pixels · ${(
        (analysis.commonValidPixels / analysis.comparisonGridPixels) *
        100
      ).toFixed(1)}% of comparison grid`
    : dataStatus === "waiting"
      ? "Waiting for SAR processing"
      : "Unavailable";

  return (
    <section aria-label="Analysis evidence" className="evidence-panel">
      <div className="evidence-heading">
        <div>
          <p className="eyebrow">RESULT EVIDENCE</p>
          <h3>Observed new-water extent</h3>
        </div>
        <span className="evidence-result-tag">SENTINEL-1 · VV</span>
      </div>

      <div className="evidence-metrics">
        <div>
          <span>Observed area</span>
          <strong>{area}</strong>
        </div>
        <div>
          <span>Water threshold</span>
          <strong>{analysis ? `${analysis.thresholdDb} dB` : "—"}</strong>
        </div>
        <div className="evidence-coverage">
          <Database aria-hidden="true" size={14} />
          <span>Shared valid coverage</span>
          <strong>{sharedCoverage}</strong>
        </div>
      </div>

      <div className="evidence-scenes">
        <EvidenceScene label="Before" scene={scenePair.before} />
        <EvidenceScene label="After" scene={scenePair.after} />
      </div>

      <div className="evidence-caveat" role="note">
        <AlertTriangle aria-hidden="true" size={18} />
        <div>
          <strong>Not confirmed flood damage</strong>
          <p>{PROCESSING_DEFAULTS.uncertainty}</p>
        </div>
      </div>
    </section>
  );
}

function EvidenceScene({
  label,
  scene,
}: {
  label: string;
  scene: SceneObservation;
}) {
  return (
    <div className="evidence-scene">
      <span>{label} observation</span>
      <strong>
        <CalendarDays aria-hidden="true" size={13} />
        {formatAcquisitionDate(scene.acquiredAtUtc)}
      </strong>
      <code title={scene.sceneId ?? undefined}>
        {scene.sceneId ?? "Scene ID unavailable"}
      </code>
    </div>
  );
}

function formatAcquisitionDate(value: string | null): string {
  if (!value) {
    return "Date unavailable";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return new Intl.DateTimeFormat("en", {
    dateStyle: "medium",
    timeZone: "UTC",
  }).format(date);
}
