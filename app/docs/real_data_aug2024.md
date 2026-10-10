# Real data: August 2024 Bangladesh floods

Two regions in the app use **real historical records** instead of sample data:
**Feni District (Aug 2024 flood)** and **Eastern Bangladesh (Aug 2024 floods)**.
They are marked **REAL DATA** (green) instead of **SAMPLE DATA** and have
`isSample: false`. The values are compiled into
`lib/data/mock/real_aug2024_data.dart`, so the app works fully offline and is
reproducible during a demo. Nothing is fetched at run time.

Values were read from the sources below on 10 Oct 2026. Where a source does
not give a value, the field is `null` and the UI shows "Not available".

## Datasets integrated

### 1. Feni District flood inundation, Sentinel-1, 21 Aug 2024
* Source: Uddin, K., Hossain, S., Bajracharya, B., Ahmed, B., Islam, M.K.
  (2025). *Rapid Flood Inundation Mapping for Effective Management: A Machine
  Learning and Pixel-Based Classification Approach in Feni District,
  Bangladesh.* Journal of Flood Risk Management 18: e70087.
  https://doi.org/10.1111/jfr3.70087 (Wiley; full text mirrored on Ovid)
* Scenes: Sentinel-1 GRD `20240821T120417` and `20240821T120442`.

| Value | Used as | Verification |
|---|---|---|
| 201 km2 inundated, Feni District, 21 Aug 2024 | observation `floodExtentKm2` | Stated in the paper abstract |
| Sonagazi 49, Chhagalnaiya 37, Fulgazi 35, Feni Sadar 33 km2 | zone values | Stated in the paper text (pixel-based classification) |
| Parshuram 31, Daganbhuiyan 16 km2 | zone values | Only in the Wikipedia summary of the paper; **checked: all six sum to 201** |
| Sonagazi 60 km2 (random forest) | zone evidence text | Stated in the paper |
| 27 km2 (Aug 2022), 17 km2 (Aug 2023) | quality-flag text only | Stated in the abstract; **month only, so not entered as dated observations** |

### 2. UNOSAT satellite flood analysis FL20240825BGD
* Source: UNOSAT (2024). *Satellite detected water extents between 28 August &
  4 September 2024 in Bangladesh.* Humanitarian Data Exchange, CC BY-SA.
  Read from the HDX metadata as mirrored at
  https://geo.btaa.org/catalog/007de930-02e7-4b32-8a6c-774c86eb2c8f
  (also listed on ReliefWeb, posted 10 Sep 2024).
* Method: Sentinel-1 composites 18-26 Aug and 28 Aug-4 Sep 2024, automated
  machine-learning analysis. "Preliminary analysis, not yet validated in the
  field."

| Value | Used as | Note |
|---|---|---|
| Floodwaters receded by about 8,700 km2 between the two periods | `ChangeStat.netChangeKm2 = -8700` | The two period totals are **not** given separately, so before/after areas and % change stay `null` |
| About 8,100 km2 affected within ~140,000 km2 analysed | quality-flag text | Ambiguous which period it refers to, so not used as an observation value |
| About 6.2 million people exposed or living close to flooded areas (WorldPop) | quality-flag text | The app has no population category |
| Window end dates 26 Aug and 4 Sep 2024 | observation dates | Disclosed in the record: each date is the last day of a composite window |

### 3. World Bank GRADE report, floods in eastern Bangladesh, Aug 2024
* Source: World Bank (2024). *Global RApid Post-Disaster Damage Estimation
  (GRADE) Report, report as of 7 Oct 2024.*
  https://documents1.worldbank.org/curated/en/099921506192542727/pdf/IDU-3c0e1de6-9af6-40b9-99a3-78397d1041ac.pdf
  District tables compile Bangladesh MoDMR / DDM reports (D-Form, 26 Sep 2024).

| District | Affected population | Households cut off | Deaths | Damaged structures | Damaged roads (km) | Damaged educational institutes | GRADE direct damage |
|---|---|---|---|---|---|---|---|
| Noakhali | 2,125,500 (57%) | 439,415 | 11 | 154,892 | 5,545 | 1,107 | US$508.8 M |
| Cumilla | 1,090,592 (17%) | 213,224 | 19 | 82,755 | 3,648 | 854 | US$362.6 M |
| Feni | 1,000,000 (59%) | 250,000 | 28 | 64,415 | 1,871 | 598 | US$312.7 M |

* Entered in the Impact screen as `buildings` / `roads` / `schools`. They are
  **reported damage counts, not modelled exposure**; the record's disclaimer and
  each card's note say so, and none is marked illustrative.
* Agriculture: FAO DIEM satellite analysis cited by GRADE, flood extent about
  three million ha by 3 Sep 2024, about two million ha of it cropland. Entered
  as one region-wide zone ("All flooded areas"), `agriculture` = about
  2,000,000 ha (approximate).
* Event totals (over six million affected, 597,552 displaced, 74 deaths,
  US$1.676 billion) are shown as quality-flag text.

### Zone positions
Zone map positions are administrative reference points, **not boundaries**:
Wikipedia infobox coordinates for Feni District (23.000N 91.400E), the five
upazilas that list one, Cumilla (23.27N 91.12E) and Noakhali (22.70N 91.10E);
Daganbhuiyan uses the centre of its Banglapedia bounding box. No real zone is
drawn on the map (no polygons are bundled), so these positions are only data.

## Checked but NOT used
* **NASA Disasters ARIA / OPERA DSWx-S1 water maps** list scenes of
  **9 Aug 2024 and 21 Aug 2024** (pre-event 5 May 2024)
  (https://maps.disasters.nasa.gov/ags03/rest/services/bangladesh_floods_202408/aria_opera_dswx/MapServer).
  The service confirms the dates but publishes **no area statistics**, and the
  sandbox could not query the raster. No water-area number for those scenes was
  verified, so none is used. If your screenshots show such figures, send the
  source link and they can be added.
* **ICIMOD flood-inundation map sheets** (Feni and Cumilla, 21 and 24 Aug) on
  Sentinel Asia are images with no area statistics.
* Flood-extent polygons (UNOSAT geodatabase, ARIA rasters): not downloadable
  from the authoring environment, so **no map overlays** are bundled for real
  regions. Explore says so instead of showing invented shapes.

## What is still mock
All four original sample regions (Sylhet, Jamuna, Haor basin, Chattogram hills)
and everything in them; all map overlays and infrastructure markers; every
prediction, susceptibility, validation metric and model explanation; slope
deformation. Real regions have **no** prediction or validation results
(`not available` / `not evaluated`).

## Updating or extending
Edit `lib/data/mock/real_aug2024_data.dart`; the tests in
`test/real_aug2024_data_test.dart` pin each number to this table. Do not add a
value without a source line here.

## Added later: figures transcribed from screenshots (UNVERIFIED source)

Two more regions were added from three screenshots supplied by the project
owner (taken from an earlier analysis session). The sandbox had no network
access, so **the primary source of these figures was NOT checked**. They are
marked `isSample: false` (REAL DATA badge) but every record carries a
"Source not verified" quality flag and the source entries say so. Replace
the source lines once the original dataset (for example the GeoHub layer) is
confirmed.

### Bangladesh - flood extent to 9 vs 21 Aug 2024
| Value | 9 Aug | 21 Aug | Change |
|---|---|---|---|
| Flooded area | 34,696 km2 | 39,576 km2 | +4,880 km2 (+14.06%, arithmetic) |
| Population exposed | 26.1 million | 30.5 million | +4.4 million |
| Flooded crop area | 30,611 km2 | 34,606 km2 | +3,995 km2 |

* Flooded area -> two observations and one `ChangeStat`.
* Largest rise in exposed population (zones): Mymensingh +518,000, Cumilla
  +291,000, Noakhali +209,000, Brahmanbaria +183,000, Kishoreganj +171,000.
* Chattogram division 4.09 -> 5.31 million exposed: quality-flag text.
* Flooded cropland 34,606 km2 (= 3,460,600 ha) -> Impact "Agriculture" for
  the zone "All mapped flooded areas". This is larger than the FAO figure
  (~2 million ha) used for Eastern Bangladesh; the two are not reconciled.
* Population has no Impact category, so it appears in zone evidence only.
* Zone positions are approximate district-town points typed in by the
  developer, **not looked up and not boundaries**.

### Bangladesh - water area per scene, 16-21 Aug 2024
Eight scenes, each entered as one observation with its area, plus one zone per
scene: 3069 (16 Aug) 540; 400F (16 Aug) 6,486; BA9A (17 Aug) 394; FD77
(17 Aug) 1,953; 4CBE (17 Aug) 128; B137 (18 Aug) 6,665; 157B (18 Aug) 1,194;
0450 (21 Aug) 2,203 km2.
* Scenes cover different footprints, so no change statistic is computed.
* The screenshot was cropped at the bottom; further rows may exist.
* Zone positions are approximate centres of the named regions, not footprints.

### Not entered
A third screenshot (21 Aug 2024 "Date A": about 486 km2 mapped flood area,
15.9% of the district, about 77 km2 perennial water, about 3,055 km2 district
area, Sentinel-1 SAR) does not name the district, so it is not entered. The
numbers are self-consistent (486 / 3,055 = 15.9%), but assigning them to a
district would be a guess.
