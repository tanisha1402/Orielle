import { CalendarDays, ScanLine } from "lucide-react";
import type { SceneObservation } from "../data/mission";

interface ObservationCardProps {
  label: "Before" | "After";
  scene: SceneObservation;
}

export function ObservationCard({ label, scene }: ObservationCardProps) {
  return (
    <article className="observation-card">
      <div className="observation-heading">
        <span className={`observation-dot observation-dot--${label.toLowerCase()}`} />
        <span>{label} observation</span>
      </div>
      <div className="observation-detail">
        <CalendarDays aria-hidden="true" size={14} />
        <span>{formatAcquisitionDate(scene.acquiredAtUtc)}</span>
      </div>
      <div className="observation-id" title={scene.sceneId ?? undefined}>
        <ScanLine aria-hidden="true" size={14} />
        <span>{scene.sceneId ?? "Awaiting scene metadata"}</span>
      </div>
    </article>
  );
}

function formatAcquisitionDate(value: string | null): string {
  if (!value) {
    return "Date not available";
  }

  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) {
    return "Date not available";
  }

  return new Intl.DateTimeFormat("en", {
    dateStyle: "medium",
    timeZone: "UTC",
  }).format(date);
}
