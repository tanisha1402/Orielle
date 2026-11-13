# Copilot instructions for TERRALENS

## Project shape

TERRALENS is a local-first Earth-observation investigation app. The repository
contains:

- `src/`: FastAPI API, SAR preparation/change detection, and gamification
  service.
- `scripts/data/`: local RTC preparation and change-detection commands.
- `frontend/`: Vite, React, TypeScript, and MapLibre application.
- `tests/`: Python `unittest` coverage for processing, API, and gamification.
- `docs/reference/TERRALENS.md`: project reference.
- `design-reference/`: read-only teammate prototype; inspect for inspiration,
  but do not modify it or copy its mock scientific data into the application.

Read `README.md` and the relevant code before making changes. Preserve existing
work and the real Sentinel-1 processing/output path. Do not invent SAR results,
imagery, detections, or field evidence. Label training simulations clearly and
never describe Sentinel-1 results as NISAR observations.

## Scientific and data-integrity requirements

- The water threshold is heuristic, not ground truth. Preserve the documented
  uncertainty and distinguish observed water-extent change from possible
  flood-related change and confirmed flood (which is not claimed).
- Keep raster alignment, CRS, nodata, validity masks, and area calculations
  explicit; do not weaken strict grid checks to hide mismatches.
- Do not alter, delete, or regenerate downloaded RTC products or SAR outputs
  unless the user specifically requests that operation.
- Gamification answer keys and reward decisions belong on the backend.
  Replaying a completed task may provide feedback but must not award duplicate
  XP or journal entries.
- Keep the API bound to loopback during local development; it is unauthenticated.
  The progress reset is development-only and must not touch SAR files.

## Existing development commands

From the repository root, run the Python suite:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests
```

Run the local API:

```powershell
.\.venv\Scripts\python.exe -m uvicorn src.api:app --host 127.0.0.1 --port 8000 --reload
```

Run the frontend from `frontend/`:

```powershell
npm install
npm run dev
npm run build
```

The frontend package currently defines `dev`, `build`, and `preview`; there is
no configured frontend test or lint script. Use existing Python tests and the
production frontend build as the available automated checks. Consult
`README.md` for data preparation, reset configuration, and scientific workflow
details. Do not add a framework or tooling solely to satisfy a generic check.

## Frontend conventions

- Preserve the existing React application, routes/workspaces, MapLibre map,
  synchronized swipe, raster overlays, evidence panel, and live API contracts.
- Follow the playful, animated space-exploration direction in the prototype,
  while keeping real scientific results visually and semantically distinct
  from training content.
- Reuse existing components, assets, audio utilities, and motion preferences.
  Keep sound opt-in, respect reduced motion, and maintain keyboard-accessible
  controls and visible focus.
- Keep scene metadata and analysis data separate from presentation components.

## Documentation and project status

Use the repository's manifests and current source as the authority for what
exists. `TERRALENS_MASTER_PROMPT.md` describes a broader product vision; do not
claim its future features are implemented unless verified in the code.
Scientific ground-truth validation and the Apache-2.0 license are not
established by the current repository. Do not claim either without adding the
required evidence or canonical license.
