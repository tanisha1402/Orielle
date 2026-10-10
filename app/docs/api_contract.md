# API contract (frontend expectations)

Base URL: `--dart-define=ERC_API_BASE_URL=http://host:port` (no trailing
slash, no `/api/v1`). All responses are JSON. Errors should use FastAPI's
`{"detail": "..."}`; HTTP 404 maps to `NotFoundException`, other non-2xx to
`HttpStatusException`.

> **Status:** `ApiAnalysisRepository` implements this contract and is covered
> by unit tests with a fake HTTP client. It has **not** been run against a real
> backend (none exists yet). Treat field names as the proposal to agree with
> the backend/research teams, and change `fromJson` in `lib/models` if the
> agreed contract differs.

Unknown measurements must be `null`; statuses use
`available | preliminary | not_available | not_evaluated | error`.
Never send raster files inside JSON.

| Method | Path | Response |
|---|---|---|
| GET | `/api/v1/health` | `{"status":"ok","version":"..."}` |
| GET | `/api/v1/areas` | array or `{"areas":[...]}` of study areas |
| GET | `/api/v1/analyses?hazard=flood_expansion` | array or `{"analyses":[...]}` of summaries |
| GET | `/api/v1/analyses/{id}` | analysis record |
| GET | `/api/v1/analyses/{id}/layers` | array or `{"layers":[...]}` |
| GET | `/api/v1/analyses/{id}/validation` | validation record |
| GET | `/api/v1/analyses/{id}/explanation` | explanation record |
| GET | `/api/v1/analyses/{id}/impact` | impact summary |
| POST | `/api/v1/ask` | `{"answer", "status", "sources"}` |

## Study area (`/areas`)

```json
{
  "id": "area_sylhet_floodplain",
  "name": "Sylhet floodplain",
  "region": "Bangladesh",
  "center": {"lat": 24.9, "lng": 91.87},
  "zoom": 10.5,
  "hazards": ["flood_expansion"],
  "boundary": [[91.7, 24.8], [92.0, 24.8], [92.0, 25.0], [91.7, 25.0]],
  "is_sample": false
}
```
`boundary` uses GeoJSON order `[lng, lat]`.

## Analysis summary (`/analyses`)

```json
{
  "analysis_id": "flood_demo_001", "hazard": "flood_expansion",
  "study_area": "area_sylhet_floodplain", "title": "...", "status": "available",
  "is_sample": false, "observation_count": 3,
  "latest_observation_date": "2025-07-08",
  "headline_label": "Net mapped flood-extent change",
  "headline_value": 46.5, "headline_unit": "km²"
}
```

## Analysis record (`/analyses/{id}`)

Superset of the roadmap's shared schema. Both forms are accepted:

* minimal: `observation_dates: ["YYYY-MM-DD", ...]` and a single
  `observed_change {area_before_km2, area_after_km2, net_change_km2}`
  (mapped to first -> last observation);
* rich: `observations: [{id, date, label, sensor, flood_extent_km2,
  mean_los_displacement_mm, quality_note}]` and
  `change_stats: [{from_observation, to_observation, area_before_km2,
  area_after_km2, net_change_km2, percent_change}]` for every pair the UI may
  select (the app does not compute differences itself).

```json
{
  "analysis_id": "flood_demo_001", "hazard": "flood_expansion",
  "study_area": "area_sylhet_floodplain", "status": "available",
  "is_sample": false, "status_note": null,
  "observations": [], "change_stats": [],
  "deformation": {
    "los_convention": "Negative = away from sensor",
    "max_los_displacement_mm": null, "median_los_displacement_mm": null,
    "monitored_area_km2": null, "zone_count": null, "noise_note": null
  },
  "prediction": {
    "status": "not_available", "kind": "none",
    "label": null, "forecast_horizon": null, "map_url": null,
    "description": null, "is_calibrated": false, "caveats": []
  },
  "validation": {"status": "not_evaluated"},
  "zones": [{
    "id": "z1", "name": "Zone A", "hazard": "flood_expansion", "rank": 1,
    "basis": "observed", "centroid": {"lat": 24.9, "lng": 91.9},
    "summary": "...", "area_km2": 24.0, "metric_label": "Flooded area (km²)",
    "susceptibility_class": null, "evidence": ["..."],
    "values_by_observation": {"obs_0": 2.1}, "data_quality": "..."
  }],
  "data_sources": [{"label": "...", "provider": "...", "note": "..."}],
  "quality_flags": [{"label": "...", "detail": "...", "level": "warning"}],
  "limitations": ["..."], "processing_version": "1.0", "crs": "EPSG:32646"
}
```
`prediction.kind`: `none | probability | relative_score | relative_class`.
Only `probability` with `is_calibrated: true` should be presented as a
probability.

## Layers (`/layers`)

```json
{
  "id": "observed_extent", "label": "Observed flood extent",
  "hazard": "flood_expansion", "format": "geotiff",
  "classification": "observed", "status": "available",
  "url": "/data/flood_extent_t2.tif", "observation_date": "2025-07-08",
  "source": "...", "units": null, "unavailable_reason": null,
  "default_visible": true,
  "legend": [{"key": "after", "label": "Flooded", "color": "#38BDF8", "fill_opacity": 0.4}],
  "geojson": {"type": "FeatureCollection", "features": []}
}
```
* `format`: `geotiff | geojson | tiles | png`. `classification`:
  `observed | derived | predicted | context`.
* The roadmap's boolean `available` is accepted when `status` is absent.
* **Drawable now:** inline `geojson` (Polygon with holes, LineString, Point).
  Feature `properties`: `style_key` (matches a `legend[].key`),
  `observation_id`, `from_observation_id`, `to_observation_id`, `zone_id`,
  `label`.
* **Not drawable yet:** `url`-only layers (GeoTIFF, tiles, remote GeoJSON). The
  UI lists them disabled with an explanation. Future integration: serve
  rasters as XYZ tiles and render with a `TileLayer`.

## Validation, explanation, impact

```json
// /validation
{"analysis_id": "...", "status": "preliminary", "is_sample": false,
 "method": "...", "test_period": "...", "split_strategy": "...",
 "metrics": [{"name": "IoU", "value": 0.41, "unit": null, "description": "..."}],
 "notes": [], "limitations": []}

// /explanation
{"analysis_id": "...", "status": "preliminary", "method": "...",
 "factors": [{"rank": 1, "name": "...", "description": "...",
              "direction": "increases", "importance": null}],
 "caveat": "Associations, not causes."}

// /impact
{"analysis_id": "...", "status": "preliminary", "is_sample": false,
 "disclaimer": "Exposure does not confirm damage...",
 "zones": [{"zone_id": "z1", "zone_name": "Zone A", "basis": "observed",
            "exposures": [{"category": "buildings", "value": 1200,
                           "approximate": true, "is_illustrative": false,
                           "note": null}]}],
 "data_notes": [{"category": "buildings", "source": "...",
                 "data_date": "2024", "coverage": "..."}]}
```
`category`: `buildings | roads | schools | agriculture | communities`
(roads in km, agriculture in ha, others counts). `value: null` = no data.

## Ask (`POST /ask`)

Request: `{"question": "...", "analysis_id": "...|null", "selected_zone_id": "...|null"}`
Response: `{"answer": "...", "status": "answered|unavailable|error", "sources": ["..."]}`.
The backend must answer only from stored records and say so when data are
missing. The in-app demo engine (`MockAskEngine`) is a keyword matcher, not an
AI model.
