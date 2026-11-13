# TERRALENS — Sentinel-1 Jamuna data preparation

This repository prepares calibrated Sentinel-1 GRD observations of the Jamuna
River, Bangladesh, as local Cloud Optimized GeoTIFFs (COGs) using ASF HyP3 RTC
processing. Each scene's VV/VH products share a pixel grid; different scenes
may use different native CRSs, transforms, or extents.

## Prepare Sentinel-1 RTC COGs

The fixed before-scene is:

`S1A_IW_GRDH_1SDV_20200713T120451_20200713T120516_033436_03DFD8_67E8`

Provide the later Sentinel-1 GRD scene identifier with `--after-scene`. The
script submits one RTC job per scene using Sigma0 radiometry, power scale,
10 m output spacing, and the Copernicus DEM.

ASF HyP3 SDK and product documentation:

- [HyP3 Python SDK](https://hyp3-docs.asf.alaska.edu/using/sdk/)
- [HyP3 SDK API reference](https://hyp3-docs.asf.alaska.edu/using/sdk_api/)
- [HyP3 authentication](https://hyp3-docs.asf.alaska.edu/using/authentication/)
- [Sentinel-1 RTC Product Guide](https://hyp3-docs.asf.alaska.edu/guides/rtc_product_guide/)

Install the pipeline dependencies in a local virtual environment (Windows
PowerShell):

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-data.txt
```

First inspect the exact job requests without authentication or network access:

```powershell
.\.venv\Scripts\python.exe scripts\data\prepare_sar.py --after-scene <AFTER_SCENE_ID> --dry-run
```

Live execution submits two publicly visible HyP3 jobs and may consume
processing credits. After verifying the scene ID and the HyP3 account's
available processing credits, explicitly authorize submission:

```powershell
.\.venv\Scripts\python.exe scripts\data\prepare_sar.py --after-scene <AFTER_SCENE_ID> --auth token --confirm-submit
```

Allow several gigabytes of free disk space: ASF's RTC guide gives an example
10 m VV product of about 2.35 GB; actual product sizes vary.

The default `token` authentication mode prompts for an Earthdata Login token
without echoing it or saving it. Alternatively, `--auth netrc` tells the SDK to
use its local `.netrc` credentials. Never pass credentials as command-line
arguments or commit them.

The script monitors both jobs, downloads their product archives, discovers the
VV and VH GeoTIFFs from the returned products, creates COGs when needed, and
checks CRS, 10 m resolution, dimensions, nodata, and exact within-scene VV/VH
alignment. It records each scene's native grid and whether cross-scene
reprojection is needed in `cache/sar/metadata.json`; it does not require the
before and after scenes to have identical grids. The complete
`cache/sar/` directory is ignored by Git; it contains downloaded products and
must remain local.

Run the focused local tests without submitting jobs:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -p "test_prepare_sar.py"
```

## Run change detection

After the prepared products are available, run the VV comparison from the
repository root:

```powershell
.\.venv\Scripts\python.exe -m scripts.data.run_change_detection
```

The runner reads each scene's `rasters.VV.path` from metadata, resolves those
repository-relative paths inside `cache/sar/`, and reprojects the after-scene
onto a cropped before-scene grid when needed. If a previous preparation run
stopped before writing `metadata.json`, the runner can reconstruct the scene
records from the local COGs and their matching HyP3 ZIP README/log manifests.
That recovery validates source scene IDs, Sigma0 power, and processing details;
it makes no network calls and does not submit jobs.
The default `-15 dB` threshold is an initial heuristic; override the threshold
or connected-component minimum when justified for the study:

```powershell
.\.venv\Scripts\python.exe -m scripts.data.run_change_detection --threshold-db -15 --min-component-pixels 1
```

It writes `before_water.tif`, `after_water.tif`, `new_water.tif`, and
`results.json` to `cache/outputs/`. The target is the before-scene grid cropped
to the transformed geographic bounds overlap. The after-scene linear Sigma0
power is resampled with nearest-neighbour; comparison masks are limited to
before-grid pixel centers with valid, finite, positive values in both scenes.
Pixels outside shared valid coverage are nodata in all three masks. Mask values
are 1 for water, 0 for observed non-water, and 255 for nodata. The JSON records
both source grids, the comparison grid and coverage rule, scene IDs and dates,
threshold, minimum component size, and area. This is pixel-center coverage;
partial edge pixels are not fractionally weighted.

Run all local synthetic tests without real SAR data or HyP3 jobs:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests
```

## Methods and interpretation

### Input and preprocessing

The preparation workflow uses ASF HyP3 Sentinel-1 GRD RTC products with
Sigma0 radiometry, linear power scale, 10 m output resolution, and the
Copernicus DEM. VV and VH products are downloaded and recorded in
`cache/sar/metadata.json`; the current change detector uses **VV only**.
The strict `detect_water_change()` array API requires matching CRS,
dimensions, and affine transforms. The geospatial runner handles differing
native scene grids by reprojecting the after-scene to the cropped before-scene
grid and comparing only shared valid coverage. Nodata, non-finite, zero, and
negative power values are excluded.

### Water masks and area

For valid positive VV Sigma0 power, the detector computes
`10 * log10(power)` and classifies pixels at or below the configured dB
threshold as water. The default **−15 dB is an initial heuristic**, not a
locally calibrated or universally valid water threshold. The current workflow
does not validate that threshold against ground truth; results should be
checked against independent reference data and tested for threshold
sensitivity.

Before and after water masks are classified and component-filtered separately
using 8-neighbour connectivity. The configured minimum is in pixels and
defaults to 1, which retains all components. “New water” is the after-water
mask minus the before-water mask, restricted to pixels valid in both scenes.
When native grids differ, after-scene linear power is reprojected to the
before-scene grid using nearest-neighbour sampling, avoiding interpolation of
nodata and mixed backscatter values. The comparison is cropped to the
transformed bounds intersection and further masked to valid shared pixel
centers; no pixels outside that coverage enter the masks or area. Components
are filtered within the shared coverage, so components cut by its edge may be
smaller than their full-scene counterparts.
Its area is the number of selected pixels multiplied by the affine pixel-area
determinant, with projected metric CRS units converted to square kilometres.
This is projected-grid area, not a hydrologically corrected or geodesic flood
measurement.

### What the result means

- **Observed water extent change:** pixels that meet the threshold in the
  after-scene but not the before-scene. This is the direct algorithm output.
- **Possible flood-related change:** a contextual interpretation that may be
  considered with independent rainfall, river-gauge, optical, or field
  evidence; this detector does not establish cause.
- **Confirmed flood:** **not claimed**. A thresholded SAR difference is not
  ground truth or event attribution.

For observations 17 days apart, the images only bracket change between two
acquisition times. They cannot establish when within that interval water
appeared, whether it persisted, or whether a flood caused it. Vegetation,
urban double-bounce, soil moisture, speckle, acquisition geometry, imperfect
registration, mixed pixels, and threshold choice can all affect the masks.

## Reproducibility and license status

The before scene ID is recorded above. Supply the intended after-scene ID to
the preparation command; both IDs, acquisition times, RTC settings, alignment
metadata, and HyP3 SDK version are recorded in `cache/sar/metadata.json`.
`cache/outputs/results.json` records the scene pair, threshold, minimum
component size, CRS, pixel spacing, and area. Re-run change detection with the
same `--threshold-db` and `--min-component-pixels` values to reproduce the
classification. Keep the downloaded COGs and metadata together; they are
inputs, not generated test fixtures.

`requirements-data.txt` currently pins the HyP3 SDK but leaves other direct
dependencies unpinned, so a fresh install is not a fully locked software
environment. For an exact run record the Python version and resolved packages
alongside the result, for example:

```powershell
.\.venv\Scripts\python.exe --version
.\.venv\Scripts\python.exe -m pip freeze > environment-lock.txt
```

No root `LICENSE` file is present. Therefore Apache-2.0 licensing cannot
currently be verified; do not treat the repository as Apache-2.0 licensed
until the canonical license is added.

## Local API and interactive frontend

The local FastAPI service exposes change results and transparent PNG XYZ tiles
for the before-water, after-water, and new-water GeoTIFF masks. It reads only
the files in `cache/outputs/`; it does not serve raw COGs or generate SAR
results. The new-water layer is rendered blue and the before/after water masks
use separate colors. The MapLibre dashboard includes a toggleable observed
new-water overlay and an evidence panel showing scene dates and IDs, threshold,
area, shared valid coverage, and a prominent caveat that the result is not
confirmed flood damage.

Install the backend dependencies in the existing virtual environment:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements-data.txt
```

In one terminal, run the API from the repository root:

```powershell
.\.venv\Scripts\python.exe -m uvicorn src.api:app --host 127.0.0.1 --port 8000 --reload
```

If change-detection outputs have not been generated, `/api/status` reports
`waiting_for_sar_processing`; the frontend displays **Waiting for SAR
processing**, keeps the area unknown, and polls the service every five
seconds. After preparing scenes, generate outputs with:

```powershell
.\.venv\Scripts\python.exe -m scripts.data.run_change_detection
```

The API provides `/api/results`, `/api/status`, and TileJSON / PNG tile routes
at `/tiles/{before_water|after_water|new_water}/tiles.json` and
`/tiles/{layer}/{z}/{x}/{y}.png`. SAR result and tile routes are read-only.
Local CORS is enabled for localhost Vite development origins.

In a second terminal, start the React, TypeScript, Vite, and MapLibre dashboard:

```powershell
cd frontend
npm install
npm run dev
```

The frontend connects to `http://127.0.0.1:8000` by default. To change the API
origin or individual endpoints, copy `frontend/.env.example` to
`frontend/.env.local` and set the relevant URLs. Vite environment variables
are client-visible; do not put credentials in them. The dark basemap and web
fonts use external services and require internet access; MapLibre displays
basemap attribution.

### Radar Rookie training

The existing dashboard includes a Mission Control training area. Level 1,
**Radar Rookie**, has four implemented exercises. Task 1.1 is initially
available; the remaining exercises unlock in sequence as the player completes
the preceding task. Completed exercises can be replayed for answer feedback,
but a replay cannot award XP or create another journal entry. Mission prompts
use simulated examples and are explicitly labeled as training—not as
measurements, flood findings, or NISAR observations. The existing SAR map,
methods panel, and uncertainty disclosures remain separate.

The current FastAPI service exposes:

- `GET /api/gamification/missions` — public mission content without answer
  keys. Add `?player_id=<uuid>` for that player's unlock state.
- `GET /api/gamification/config` — exposes whether the local development reset
  control is enabled.
- `POST /api/gamification/players/{player_id}/answers` — grades a submitted
  choice and awards XP once per completed task; completed-task replays return
  feedback but do not grant rewards again.
- `GET /api/gamification/players/{player_id}/progress` — returns XP, rank, and
  mission completion.
- `GET /api/gamification/players/{player_id}/journal` — returns the player's
  training submissions and explanations.
- `POST /api/gamification/players/{player_id}/reset` — deletes only that
  player's training progress, and returns 404 unless both development reset
  environment variables are enabled.

The browser creates an anonymous UUID stored in local storage. Progress is
persisted by the local API in `cache/gamification.sqlite3`, which is ignored by
Git and is not shared across machines. The API is intended for loopback local
development; do not expose this unauthenticated service to a public network.
SQLite uses Python's standard library, so no additional dependency or setup
command is required. Start the API and frontend using the existing commands
above, then select **Mission Control** in the dashboard header.

To enable the per-player training reset control for local development only,
set both variables in the same PowerShell terminal before starting the API:

```powershell
$env:TERRALENS_ENV = "development"
$env:TERRALENS_ENABLE_GAMIFICATION_RESET = "true"
.\.venv\Scripts\python.exe -m uvicorn src.api:app --host 127.0.0.1 --port 8000 --reload
```

The reset operates only on the selected player's SQLite training records; it
does not access SAR inputs or `cache/outputs/`. Keep the API bound to loopback.

Answer submissions use the player UUID in the URL and an idempotency UUID in
the request body, for example:

```json
{
  "submission_id": "9db3b5f0-b738-4d6c-88c2-7f07dd78a912",
  "task_id": "1.1",
  "answer": "A"
}
```

In the UI the submission ID is generated automatically. Repeated requests
cannot award XP more than once for the same task.

Create a production frontend build with `npm run build` from `frontend/`.
Backend endpoint tests and the existing synthetic processing tests run with:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests
```
