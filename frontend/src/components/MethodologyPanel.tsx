import {
  ListChecks,
  Ruler,
  SlidersHorizontal,
} from "lucide-react";
import { PROCESSING_DEFAULTS } from "../data/mission";
import type { ChangeSummary } from "../data/analysis";

interface MethodologyPanelProps {
  analysis: ChangeSummary | null;
}

export function MethodologyPanel({ analysis }: MethodologyPanelProps) {
  const thresholdDb = analysis?.thresholdDb ?? PROCESSING_DEFAULTS.thresholdDb;
  const minComponentPixels =
    analysis?.minComponentPixels ?? PROCESSING_DEFAULTS.minComponentPixels;
  const pixelSpacing = analysis
    ? `${formatMeters(analysis.pixelSpacingMeters.x)} × ${formatMeters(analysis.pixelSpacingMeters.y)} m`
    : "—";

  return (
    <aside className="method-panel" id="methodology">
      <div className="panel-title">
        <div className="panel-icon">
          <ListChecks aria-hidden="true" size={18} />
        </div>
        <div>
          <p className="eyebrow">Transparent by design</p>
          <h2>Method &amp; data</h2>
        </div>
      </div>

      <div className="method-settings">
        <div className="method-setting">
          <div className="setting-icon setting-icon--blue">
            <SlidersHorizontal aria-hidden="true" size={15} />
          </div>
          <div>
            <span>Water threshold</span>
            <strong>{thresholdDb} dB</strong>
          </div>
          <span className="setting-note">initial heuristic</span>
        </div>
        <div className="method-setting">
          <div className="setting-icon setting-icon--teal">
            <Ruler aria-hidden="true" size={15} />
          </div>
          <div>
            <span>Pixel spacing</span>
            <strong>{pixelSpacing}</strong>
          </div>
          <span className="setting-note">{analysis?.crs ?? "awaiting output"}</span>
        </div>
      </div>

      <div className="steps-heading">
        <span>Processing sequence</span>
        <span>{PROCESSING_DEFAULTS.steps.length} steps</span>
      </div>
      <ol className="method-steps">
        {PROCESSING_DEFAULTS.steps.map((step, index) => (
          <li key={step}>
            <span className="step-number">{String(index + 1).padStart(2, "0")}</span>
            <span>{step}</span>
            <span aria-hidden="true" className="step-marker" />
          </li>
        ))}
      </ol>
      <p className="component-note">
        Connected-component minimum: {minComponentPixels} pixel
        {minComponentPixels === 1 ? "" : "s"} (8-neighbour connectivity).
      </p>

      <div className="sensor-note">
        <span className="sensor-indicator" />
        <span>Sentinel-1 C-band · RTC Sigma0 power</span>
      </div>
    </aside>
  );
}

function formatMeters(value: number): string {
  return new Intl.NumberFormat("en", { maximumFractionDigits: 2 }).format(value);
}
