import { useEffect, useRef, useState } from "react";
import { Award, Printer, X } from "lucide-react";
import { loadAvatar, PilotAvatar } from "./Avatar";
import { sound } from "../utils/audio";

interface TrainingCertificateProps {
  callsign: string;
  completedAt: string | null;
  eligible: boolean;
}

export function TrainingCertificate({
  callsign,
  completedAt,
  eligible,
}: TrainingCertificateProps) {
  const dialogRef = useRef<HTMLDivElement>(null);
  const closeRef = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (!open) return;
    const dialog = dialogRef.current;
    const previousFocus =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;
    closeRef.current?.focus();
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        setOpen(false);
        return;
      }
      if (event.key !== "Tab") return;
      const focusable = dialog?.querySelectorAll<HTMLElement>(
        'button:not(:disabled), [href], input:not(:disabled), [tabindex]:not([tabindex="-1"])',
      );
      if (!focusable?.length) {
        event.preventDefault();
        dialog?.focus();
        return;
      }
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("keydown", closeOnEscape);
      previousFocus?.focus();
    };
  }, [open]);

  if (!eligible) {
    return (
      <button
        className="reference-button reference-button--locked"
        disabled
        title="Complete all Radar Rookie challenges to earn this training certificate."
        type="button"
      >
        <Award size={17} /> CERTIFICATE · LOCKED
      </button>
    );
  }

  return (
    <>
      <button
        className="reference-button reference-button--gold certificate-open"
        onClick={() => {
          sound.playSuccessChime();
          setOpen(true);
        }}
        type="button"
      >
        <Award size={17} /> VIEW TRAINING CERTIFICATE
      </button>
      {open && (
        <div
          className="certificate-overlay no-print"
          onClick={(event) => {
            if (event.target === event.currentTarget) setOpen(false);
          }}
        >
          <div
            aria-label="Radar Rookie training certificate"
            aria-modal="true"
            className="certificate-dialog"
            ref={dialogRef}
            role="dialog"
            tabIndex={-1}
          >
            <button
              aria-label="Close certificate preview"
              className="certificate-close"
              onClick={() => setOpen(false)}
              ref={closeRef}
              type="button"
            >
              <X size={19} />
            </button>
            <CertificatePaper callsign={callsign} completedAt={completedAt} />
            <div className="certificate-actions">
              <button
                className="reference-button reference-button--gold"
                onClick={() => {
                  sound.playKeyClick();
                  window.print();
                }}
                type="button"
              >
                <Printer size={16} /> PRINT / SAVE AS PDF
              </button>
              <button
                className="reference-button reference-button--quiet"
                onClick={() => setOpen(false)}
                type="button"
              >
                CLOSE
              </button>
            </div>
          </div>
          <CertificatePaper callsign={callsign} completedAt={completedAt} printOnly />
        </div>
      )}
    </>
  );
}

function CertificatePaper({
  callsign,
  completedAt,
  printOnly = false,
}: {
  callsign: string;
  completedAt: string | null;
  printOnly?: boolean;
}) {
  const date = completedAt
    ? new Date(completedAt).toLocaleDateString(undefined, {
        day: "numeric",
        month: "long",
        year: "numeric",
      })
    : null;
  return (
    <article className={`certificate-paper${printOnly ? " certificate-paper--print" : ""}`}>
      <div className="certificate-paper__orbit certificate-paper__orbit--one" />
      <div className="certificate-paper__orbit certificate-paper__orbit--two" />
      <div className="certificate-paper__content">
        <PilotAvatar cfg={loadAvatar()} size={62} ring />
        <span className="certificate-paper__brand">TERRALENS · TRAINING ACADEMY</span>
        <h1>CERTIFICATE OF COMPLETION</h1>
        <p className="certificate-paper__intro">This certificate is awarded to</p>
        <strong className="certificate-paper__callsign">{callsign}</strong>
        <p className="certificate-paper__achievement">
          for completing all four challenges in
        </p>
        <h2>RADAR ROOKIE · LEVEL 1</h2>
        <div className="certificate-paper__seal"><Award size={29} /></div>
        <p className="certificate-paper__date">
          {date ? `Training completion recorded ${date}` : "Training completion verified by the TERRALENS service"}
        </p>
        <p className="certificate-paper__scope">
          Recognition of a training achievement only. This is not a scientific
          credential, satellite-data validation, or flood confirmation.
        </p>
        <span className="certificate-paper__serial">PLAYER TRAINING RECORD · LOCAL TERRALENS INSTANCE</span>
      </div>
    </article>
  );
}
