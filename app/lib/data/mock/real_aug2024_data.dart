import 'package:latlong2/latlong.dart';

import '../../models/analysis_result.dart';
import '../../models/data_status.dart';
import '../../models/explanation_result.dart';
import '../../models/hazard_type.dart';
import '../../models/hazard_zone.dart';
import '../../models/impact_summary.dart';
import '../../models/observation.dart';
import '../../models/study_area.dart';
import '../../models/validation_result.dart';
import 'mock_data.dart' show MockBundle;

/// REAL historical records for the August 2024 floods in Bangladesh, bundled
/// in the app so it works offline. Everything here was taken from the sources
/// listed below. Where a source does not provide a value, the field is `null`
/// or absent: nothing is estimated, interpolated or invented.
///
/// Sources (details and verification notes: docs/real_data_aug2024.md)
///  [S1] Uddin, Hossain, Bajracharya, Ahmed, Islam (2025). Rapid Flood
///       Inundation Mapping for Effective Management ... Feni District,
///       Bangladesh. J. Flood Risk Management 18: e70087.
///       https://doi.org/10.1111/jfr3.70087  (Sentinel-1 GRD scenes
///       20240821T120417 and 20240821T120442).
///  [S2] UNOSAT (2024). Satellite detected water extents between 28 August &
///       4 September 2024 in Bangladesh (code FL20240825BGD), via the
///       Humanitarian Data Exchange, CC BY-SA.
///  [S3] World Bank (2024). Global RApid post-disaster Damage Estimation
///       (GRADE) Report: Floods in eastern Bangladesh, August 2024 (as of
///       7 Oct 2024). https://documents1.worldbank.org/curated/en/
///       099921506192542727/pdf/IDU-3c0e1de6-9af6-40b9-99a3-78397d1041ac.pdf
///       (district tables compiled from MoDMR/DDM; cropland from FAO DIEM).
///  [S4] Wikipedia / Banglapedia: administrative reference points used only
///       as zone positions (not boundaries).
///
/// These records are NOT sample data (`isSample: false`). The map has no
/// overlays for them because no verified flood-extent geometry is bundled.
class RealAug2024Data {
  const RealAug2024Data._();

  static const String datasetLabel = 'REAL: August 2024 Bangladesh floods';

  static const String feniAreaId = 'area_feni_aug2024';
  static const String easternAreaId = 'area_eastern_bd_aug2024';
  static const String feniAnalysisId = 'flood_real_feni_2024';
  static const String easternAnalysisId = 'flood_real_eastern_bd_2024';

  // Figures transcribed from screenshots supplied by the project owner.
  static const String nationalAreaId = 'area_bd_extent_aug2024';
  static const String nationalAnalysisId = 'flood_real_bd_extent_2024';
  static const String sceneAreaId = 'area_bd_scenes_aug2024';
  static const String sceneAnalysisId = 'flood_real_bd_scenes_2024';

  static const String _screenshotProvenance =
      'Transcribed from a screenshot supplied by the project owner. The '
      'primary source behind it has not been independently verified.';

  // ---------------------------------------------------------------------
  // Study areas (map view centres only; no boundaries are bundled)
  // ---------------------------------------------------------------------
  static final List<StudyArea> areas = <StudyArea>[
    StudyArea(
      id: feniAreaId,
      name: 'Feni District (Aug 2024 flood)',
      region: 'Bangladesh',
      // Feni District reference point (Wikipedia infobox: 23.000N 91.400E).
      center: LatLng(23.000, 91.400),
      zoom: 10,
      supportedHazards: const <HazardType>[HazardType.floodExpansion],
      description: 'Real Sentinel-1 flood inundation mapped on 21 Aug 2024, '
          'with inundated area for each of the six upazilas.',
      isSample: false,
    ),
    StudyArea(
      id: easternAreaId,
      name: 'Eastern Bangladesh (Aug 2024 floods)',
      region: 'Bangladesh',
      center: LatLng(23.000, 91.250),
      zoom: 8.5,
      supportedHazards: const <HazardType>[HazardType.floodExpansion],
      description: 'Real UNOSAT satellite flood analysis and World Bank GRADE '
          'district figures for the Noakhali, Cumilla and Feni floods.',
      isSample: false,
    ),
    StudyArea(
      id: nationalAreaId,
      name: 'Bangladesh - flood extent to 9 vs 21 Aug 2024',
      region: 'Bangladesh',
      center: LatLng(23.685, 90.356),
      zoom: 6.5,
      supportedHazards: const <HazardType>[HazardType.floodExpansion],
      description: 'National flooded area, exposed population and flooded '
          'cropland up to 9 Aug and up to 21 Aug 2024 (from a supplied '
          'screenshot; source not yet verified).',
      isSample: false,
    ),
    StudyArea(
      id: sceneAreaId,
      name: 'Bangladesh - water area per scene, 16-21 Aug 2024',
      region: 'Bangladesh',
      center: LatLng(23.685, 90.356),
      zoom: 6.5,
      supportedHazards: const <HazardType>[HazardType.floodExpansion],
      description: 'Water area measured in eight satellite scenes between '
          '16 and 21 Aug 2024 (from a supplied screenshot; source not yet '
          'verified).',
      isSample: false,
    ),
  ];

  static final List<MockBundle> bundles = <MockBundle>[
    _feni(),
    _eastern(),
    _national(),
    _scenes(),
  ];

  // ---------------------------------------------------------------------
  // 1. Feni District - Sentinel-1, 21 August 2024  [S1]
  // ---------------------------------------------------------------------
  static MockBundle _feni() {
    final observations = <Observation>[
      Observation(
        id: 'obs_0',
        date: DateTime(2024, 8, 21),
        label: 'S1 21 Aug',
        sensor: 'Sentinel-1 GRD (20240821T120417, 20240821T120442)',
        floodExtentKm2: 201.0,
        qualityNote: 'Feni District total, pixel-based classification '
            '(Uddin et al. 2025).',
      ),
    ];

    final zones = <HazardZone>[
      for (final u in _upazilas)
        HazardZone(
          id: u.id,
          name: '${u.name} upazila',
          hazard: HazardType.floodExpansion,
          rank: u.rank,
          basis: ZoneBasis.observed,
          centroid: LatLng(u.lat, u.lng),
          summary: 'Inundated area on 21 Aug 2024: '
              '${u.km2.toStringAsFixed(0)} km\u00b2 (Sentinel-1).',
          metricLabel: 'Inundated area on 21 Aug 2024 (km\u00b2)',
          evidence: <String>[
            '${u.km2.toStringAsFixed(0)} km\u00b2 inundated on 21 Aug 2024 '
                '(Sentinel-1, pixel-based classification).',
            'Feni District total on the same scene: 201 km\u00b2.',
            if (u.rank == 1)
              'The same study\'s random-forest classification gave 60 km\u00b2 '
                  'for this upazila; the pixel-based value is shown.',
          ],
          valuesByObservation: <String, double>{'obs_0': u.km2},
          dataQuality: u.quality,
        ),
    ];

    final analysis = AnalysisResult(
      id: feniAnalysisId,
      hazard: HazardType.floodExpansion,
      studyAreaId: feniAreaId,
      title: 'Feni District - flood inundation, 21 Aug 2024',
      status: DataStatus.available,
      isSample: false,
      datasetLabel: datasetLabel,
      statusNote: 'Real historical figures only. No verified flood-extent '
          'geometry is bundled, so this analysis has no map overlays.',
      observations: observations,
      prediction: const PredictionInfo(
        status: DataStatus.notAvailable,
        kind: PredictionKind.none,
        label: 'Future flood expansion',
        description: 'This record holds historical observations only. No '
            'forecast or expansion model was produced.',
        caveats: <String>[
          'A mapped flood extent on one date does not predict later flooding.',
        ],
      ),
      validationStatus: DataStatus.notEvaluated,
      zones: zones,
      dataSources: const <DataSourceRef>[
        DataSourceRef(
          label: 'Sentinel-1 flood inundation map, Feni District, 21 Aug 2024',
          provider: 'Uddin et al. (2025), J. Flood Risk Management 18: e70087',
          note: 'https://doi.org/10.1111/jfr3.70087',
        ),
        DataSourceRef(
          label: 'Upazila reference points used as zone positions',
          provider: 'Wikipedia / Banglapedia',
          note: 'Administrative reference points, not boundaries.',
        ),
      ],
      qualityFlags: const <QualityFlag>[
        QualityFlag(
          label: 'Single dated scene',
          detail: 'Only the 21 Aug 2024 scene is entered as a dated '
              'observation, so no change between dates is measured here.',
        ),
        QualityFlag(
          label: 'Earlier Augusts (not entered)',
          detail: 'The same study reports 27 km\u00b2 (August 2022) and '
              '17 km\u00b2 (August 2023) for the district, but gives the month '
              'only, so they are not entered as dated observations.',
        ),
        QualityFlag(
          label: 'Method choice',
          detail: 'Pixel-based and random-forest classification give '
              'different totals (for example Sonagazi 49 vs 60 km\u00b2). '
              'The pixel-based values are shown.',
          level: QualityLevel.warning,
        ),
        QualityFlag(
          label: 'Peak extent may be missed',
          detail: 'The World Bank GRADE report notes that open satellite data '
              'did not capture the full August 2024 flood extent because of '
              'cloud cover and missing images in critical periods.',
          level: QualityLevel.warning,
        ),
      ],
      limitations: const <String>[
        'Historical observation only; not a forecast.',
        'No map geometry is bundled, so Explore shows no overlays here.',
        'Zone positions are administrative reference points, not boundaries.',
        'Parshuram (31 km\u00b2) and Daganbhuiyan (16 km\u00b2) values come '
            'from a Wikipedia summary of the paper; the six values sum to the '
            'paper\'s 201 km\u00b2 total.',
      ],
      processingVersion: 'published figures (not reprocessed)',
    );

    return MockBundle(
      summary: AnalysisSummary(
        id: feniAnalysisId,
        hazard: HazardType.floodExpansion,
        studyAreaId: feniAreaId,
        title: analysis.title,
        status: DataStatus.available,
        isSample: false,
        observationCount: 1,
        latestObservationDate: DateTime(2024, 8, 21),
        headlineLabel: 'Mapped flood extent, 21 Aug 2024',
        headlineValue: 201.0,
        headlineUnit: 'km\u00b2',
      ),
      analysis: analysis,
      layers: const [],
      validation: const ValidationResult(
        analysisId: feniAnalysisId,
        status: DataStatus.notEvaluated,
        isSample: false,
        notes: <String>[
          'The study authors report their own accuracy assessment; those '
              'metrics were not extracted or checked for this app.',
          'No independent comparison was performed here.',
        ],
        limitations: <String>[
          '"Not evaluated" is not a pass.',
        ],
      ),
      explanation: const ExplanationResult(
        analysisId: feniAnalysisId,
        status: DataStatus.notAvailable,
        isSample: false,
        caveat: 'No model explanation: this record contains observed figures '
            'only.',
      ),
      impact: const ImpactSummary(
        analysisId: feniAnalysisId,
        status: DataStatus.notAvailable,
        isSample: false,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 3. Bangladesh flooded area / exposure, to 9 Aug vs to 21 Aug 2024
  //    (screenshot supplied by the project owner; source NOT verified)
  // ---------------------------------------------------------------------
  static MockBundle _national() {
    final observations = <Observation>[
      Observation(
        id: 'obs_0',
        date: DateTime(2024, 8, 9),
        label: 'To 9 Aug',
        sensor: 'Satellite flood mapping (layer not identified)',
        floodExtentKm2: 34696.0,
        qualityNote: 'Labelled "to 9 Aug" in the supplied screenshot. The '
            'baseline and whether perennial water is included are not '
            'stated.',
      ),
      Observation(
        id: 'obs_1',
        date: DateTime(2024, 8, 21),
        label: 'To 21 Aug',
        sensor: 'Satellite flood mapping (layer not identified)',
        floodExtentKm2: 39576.0,
        qualityNote: 'Labelled "to 21 Aug" in the supplied screenshot. The '
            'baseline and whether perennial water is included are not '
            'stated.',
      ),
    ];

    // 39,576 - 34,696 = 4,880 (matches the screenshot's own change column).
    // The percentage is plain arithmetic on those two figures.
    final changeStats = <ChangeStat>[
      ChangeStat(
        fromObservationId: 'obs_0',
        toObservationId: 'obs_1',
        areaBeforeKm2: 34696.0,
        areaAfterKm2: 39576.0,
        netChangeKm2: 4880.0,
        percentChange: 4880.0 / 34696.0 * 100.0,
      ),
    ];

    final zones = <HazardZone>[
      for (final d in _exposedDistricts)
        HazardZone(
          id: d.id,
          name: '${d.name} district',
          hazard: HazardType.floodExpansion,
          rank: d.rank,
          basis: ZoneBasis.observed,
          centroid: LatLng(d.lat, d.lng),
          summary: 'Population exposed rose by about ${d.increase} between '
              'the 9 Aug and 21 Aug 2024 scenes.',
          evidence: <String>[
            'Population exposed: +${d.increase} (up to 9 Aug to up to '
                '21 Aug 2024).',
            _screenshotProvenance,
          ],
          dataQuality: 'Screenshot transcription, source not verified. '
              'Position is an approximate district reference point, not a '
              'boundary.',
        ),
      const HazardZone(
        id: 'bd_all_extent',
        name: 'All mapped flooded areas (to 21 Aug 2024)',
        hazard: HazardType.floodExpansion,
        rank: 6,
        basis: ZoneBasis.observed,
        centroid: LatLng(23.685, 90.356),
        summary: 'National totals up to 21 Aug 2024: 39,576 km\u00b2 flooded, '
            '30.5 million people exposed, 34,606 km\u00b2 of cropland '
            'flooded.',
        evidence: <String>[
          'Flooded area: 34,696 km\u00b2 (to 9 Aug) to 39,576 km\u00b2 '
              '(to 21 Aug), +4,880 km\u00b2.',
          'Population exposed: 26.1 million to 30.5 million, +4.4 million.',
          'Flooded crop area: 30,611 km\u00b2 to 34,606 km\u00b2, '
              '+3,995 km\u00b2.',
          _screenshotProvenance,
        ],
        dataQuality: 'Screenshot transcription, source not verified. A '
            'region-wide total, not a single place.',
      ),
    ];

    final analysis = AnalysisResult(
      id: nationalAnalysisId,
      hazard: HazardType.floodExpansion,
      studyAreaId: nationalAreaId,
      title: 'Bangladesh - flooded area and exposure, to 9 vs 21 Aug 2024',
      status: DataStatus.preliminary,
      isSample: false,
      datasetLabel: datasetLabel,
      statusNote: 'Real figures transcribed from a supplied screenshot; the '
          'primary source is not yet verified. No map geometry is bundled.',
      observations: observations,
      changeStats: changeStats,
      prediction: const PredictionInfo(
        status: DataStatus.notAvailable,
        kind: PredictionKind.none,
        label: 'Future flood expansion',
        description: 'This record holds historical observations only. No '
            'forecast or expansion model was produced.',
        caveats: <String>[
          'An increase between two dates does not predict later flooding.',
        ],
      ),
      validationStatus: DataStatus.notEvaluated,
      zones: zones,
      dataSources: const <DataSourceRef>[
        DataSourceRef(
          label: 'Flooded area, population exposed and flooded crop area, '
              'to 9 Aug and to 21 Aug 2024',
          provider: 'Supplied screenshot (GeoHub flood layer analysis); '
              'primary source not verified',
          note: 'Replace this entry once the original dataset is confirmed.',
        ),
        DataSourceRef(
          label: 'District reference points used as zone positions',
          provider: 'Approximate town positions',
          note: 'Not boundaries and not looked up in this session.',
        ),
      ],
      qualityFlags: const <QualityFlag>[
        QualityFlag(
          label: 'Source not verified',
          detail: 'These figures were read from a screenshot. Their '
              'primary source has not been independently checked.',
          level: QualityLevel.warning,
        ),
        QualityFlag(
          label: 'Largest division increase',
          detail: 'Chattogram division went from 4.09 million to 5.31 '
              'million people exposed, the largest increase of any '
              'division. By 21 Aug it overtook Rajshahi and Rangpur as '
              'the most exposed division.',
        ),
        QualityFlag(
          label: 'Cropland differs from FAO figure',
          detail: 'The flooded cropland here (34,606 km\u00b2, about 3.46 '
              'million ha) is larger than the FAO DIEM estimate of about '
              'two million ha used for Eastern Bangladesh. Different '
              'methods and dates; they are not reconciled.',
          level: QualityLevel.warning,
        ),
        QualityFlag(
          label: 'Cumulative definition unclear',
          detail: 'The 9 Aug value (34,696 km\u00b2) is large for a date '
              'before the late-August peak. The screenshot does not define '
              'the baseline, so do not read it as a single-day extent.',
          level: QualityLevel.warning,
        ),
      ],
      limitations: const <String>[
        'Historical records only; not a forecast.',
        'No map geometry is bundled, so Explore shows no overlays here.',
        'Only the five districts listed in the screenshot are shown; '
            'other districts are not covered.',
        'Zone positions are approximate district reference points.',
      ],
      processingVersion: 'transcribed figures (not reprocessed)',
    );

    final nullExposures = <ExposureCount>[
      for (final c in AssetCategory.values)
        ExposureCount(
          category: c,
          value: null,
          approximate: true,
          note: 'Not in the supplied screenshot.',
        ),
    ];

    return MockBundle(
      summary: AnalysisSummary(
        id: nationalAnalysisId,
        hazard: HazardType.floodExpansion,
        studyAreaId: nationalAreaId,
        title: analysis.title,
        status: DataStatus.preliminary,
        isSample: false,
        observationCount: 2,
        latestObservationDate: DateTime(2024, 8, 21),
        headlineLabel: 'Flood extent change, 9 to 21 Aug 2024',
        headlineValue: 4880.0,
        headlineUnit: 'km\u00b2',
      ),
      analysis: analysis,
      layers: const [],
      validation: const ValidationResult(
        analysisId: nationalAnalysisId,
        status: DataStatus.notEvaluated,
        isSample: false,
        notes: <String>[
          'The source of these figures has not been verified.',
          'No independent comparison was performed here.',
        ],
        limitations: <String>[
          '"Not evaluated" is not a pass.',
        ],
      ),
      explanation: const ExplanationResult(
        analysisId: nationalAnalysisId,
        status: DataStatus.notAvailable,
        isSample: false,
        caveat: 'No model explanation: this record contains observed '
            'figures only.',
      ),
      impact: ImpactSummary(
        analysisId: nationalAnalysisId,
        status: DataStatus.preliminary,
        isSample: false,
        disclaimer: 'Only flooded cropland is available here, and it comes '
            'from an unverified screenshot. Exposed population is shown in '
            'the zone evidence. Nothing here describes current danger.',
        zoneImpacts: <ZoneImpact>[
          for (final d in _exposedDistricts)
            ZoneImpact(
              zoneId: d.id,
              zoneName: '${d.name} district',
              basis: ZoneBasis.observed,
              exposures: nullExposures,
            ),
          ZoneImpact(
            zoneId: 'bd_all_extent',
            zoneName: 'All mapped flooded areas (to 21 Aug 2024)',
            basis: ZoneBasis.observed,
            exposures: <ExposureCount>[
              for (final c in AssetCategory.values)
                ExposureCount(
                  category: c,
                  // 34,606 km2 = 3,460,600 ha.
                  value: c == AssetCategory.agriculture ? 3460600.0 : null,
                  approximate: true,
                  note: c == AssetCategory.agriculture
                      ? 'Flooded crop area up to 21 Aug 2024: 34,606 km\u00b2 '
                          '(unverified screenshot).'
                      : 'Not in the supplied screenshot.',
                ),
            ],
          ),
        ],
        dataNotes: const <ExposureDataNote>[
          ExposureDataNote(
            category: AssetCategory.agriculture,
            source: 'Supplied screenshot; primary source not verified',
            dataDate: '21 Aug 2024',
            coverage: 'National flooded crop area, not broken down by '
                'district.',
          ),
        ],
      ),
    );
  }

  /// Districts with the largest rise in exposed population between the
  /// 9 Aug and 21 Aug 2024 scenes (screenshot). Positions are approximate
  /// district-town reference points, not boundaries.
  static const List<_ExposedDistrict> _exposedDistricts = <_ExposedDistrict>[
    _ExposedDistrict('bd_mymensingh', 'Mymensingh', 1, 24.747, 90.420,
        '518,000'),
    _ExposedDistrict('bd_cumilla', 'Cumilla', 2, 23.270, 91.120, '291,000'),
    _ExposedDistrict('bd_noakhali', 'Noakhali', 3, 22.700, 91.100,
        '209,000'),
    _ExposedDistrict('bd_brahmanbaria', 'Brahmanbaria', 4, 23.957, 91.112,
        '183,000'),
    _ExposedDistrict('bd_kishoreganj', 'Kishoreganj', 5, 24.426, 90.982,
        '171,000'),
  ];

  // ---------------------------------------------------------------------
  // 4. Water area per satellite scene, 16-21 Aug 2024
  //    (screenshot supplied by the project owner; source NOT verified)
  // ---------------------------------------------------------------------
  static MockBundle _scenes() {
    final observations = <Observation>[
      for (var i = 0; i < _sceneRows.length; i++)
        Observation(
          id: 'obs_$i',
          date: DateTime(2024, 8, _sceneRows[i].day),
          label: _sceneRows[i].id,
          sensor: 'Satellite scene ${_sceneRows[i].id}',
          floodExtentKm2: _sceneRows[i].area,
          qualityNote: 'Water area in scene ${_sceneRows[i].id}. Region '
              'covered: ${_sceneRows[i].region}.',
        ),
    ];

    final zones = <HazardZone>[
      for (var i = 0; i < _sceneRows.length; i++)
        HazardZone(
          id: 'scene_${_sceneRows[i].id.toLowerCase()}',
          name: 'Scene ${_sceneRows[i].id} - ${_sceneRows[i].region}',
          hazard: HazardType.floodExpansion,
          rank: _sceneRows[i].rank,
          basis: ZoneBasis.observed,
          centroid: LatLng(_sceneRows[i].lat, _sceneRows[i].lng),
          summary: 'Water area in scene ${_sceneRows[i].id} on '
              '${_sceneRows[i].day} Aug 2024: '
              '${_sceneRows[i].area.toStringAsFixed(0)} km\u00b2.',
          metricLabel: 'Water area in scene (km\u00b2)',
          evidence: <String>[
            '${_sceneRows[i].area.toStringAsFixed(0)} km\u00b2 of water in '
                'scene ${_sceneRows[i].id} on ${_sceneRows[i].day} Aug 2024.',
            'Region covered: ${_sceneRows[i].region}.',
            _screenshotProvenance,
          ],
          valuesByObservation: <String, double>{
            'obs_$i': _sceneRows[i].area,
          },
          dataQuality: 'Screenshot transcription, source not verified. '
              'Position is the approximate centre of the named region, not '
              'the scene footprint.',
        ),
    ];

    final analysis = AnalysisResult(
      id: sceneAnalysisId,
      hazard: HazardType.floodExpansion,
      studyAreaId: sceneAreaId,
      title: 'Bangladesh - water area per scene, 16-21 Aug 2024',
      status: DataStatus.preliminary,
      isSample: false,
      datasetLabel: datasetLabel,
      statusNote: 'Real figures transcribed from a supplied screenshot; the '
          'primary source is not yet verified. No map geometry is bundled.',
      observations: observations,
      prediction: const PredictionInfo(
        status: DataStatus.notAvailable,
        kind: PredictionKind.none,
        label: 'Future flood expansion',
        description: 'This record holds historical observations only. No '
            'forecast or expansion model was produced.',
        caveats: <String>[
          'Scene areas do not predict later flooding.',
        ],
      ),
      validationStatus: DataStatus.notEvaluated,
      zones: zones,
      dataSources: const <DataSourceRef>[
        DataSourceRef(
          label: 'Water area per scene (km\u00b2), 16-21 Aug 2024',
          provider: 'Supplied screenshot; origin of the table not '
              'identified or verified',
          note: 'Replace this entry once the original dataset is confirmed.',
        ),
      ],
      qualityFlags: const <QualityFlag>[
        QualityFlag(
          label: 'Source not verified',
          detail: 'These figures were read from a screenshot. Their '
              'primary source has not been independently checked.',
          level: QualityLevel.warning,
        ),
        QualityFlag(
          label: 'Scenes are not one footprint',
          detail: 'Each scene covers a different area, so the bars compare '
              'scenes, not change over time. Do not read the sequence as '
              'one growing flood.',
          level: QualityLevel.warning,
        ),
        QualityFlag(
          label: 'Table may be incomplete',
          detail: 'The screenshot was cropped at the bottom of the table; '
              'only these eight scenes are entered. Whether perennial '
              'water is excluded is not stated.',
        ),
      ],
      limitations: const <String>[
        'Historical records only; not a forecast.',
        'No map geometry is bundled, so Explore shows no overlays here.',
        'Zone positions are approximate region centres, not scene '
            'footprints.',
      ],
      processingVersion: 'transcribed figures (not reprocessed)',
    );

    return MockBundle(
      summary: AnalysisSummary(
        id: sceneAnalysisId,
        hazard: HazardType.floodExpansion,
        studyAreaId: sceneAreaId,
        title: analysis.title,
        status: DataStatus.preliminary,
        isSample: false,
        observationCount: _sceneRows.length,
        latestObservationDate: DateTime(2024, 8, 21),
        headlineLabel: 'Largest single-scene water area (18 Aug 2024)',
        headlineValue: 6665.0,
        headlineUnit: 'km\u00b2',
      ),
      analysis: analysis,
      layers: const [],
      validation: const ValidationResult(
        analysisId: sceneAnalysisId,
        status: DataStatus.notEvaluated,
        isSample: false,
        notes: <String>[
          'The source of these figures has not been verified.',
          'No independent comparison was performed here.',
        ],
        limitations: <String>[
          '"Not evaluated" is not a pass.',
        ],
      ),
      explanation: const ExplanationResult(
        analysisId: sceneAnalysisId,
        status: DataStatus.notAvailable,
        isSample: false,
        caveat: 'No model explanation: this record contains observed '
            'figures only.',
      ),
      impact: const ImpactSummary(
        analysisId: sceneAnalysisId,
        status: DataStatus.notAvailable,
        isSample: false,
      ),
    );
  }

  /// Water area per scene (km2), in the order listed in the screenshot.
  /// Positions are approximate centres of the named regions.
  static const List<_SceneRow> _sceneRows = <_SceneRow>[
    _SceneRow('3069', 16, 540, 'Chattogram hills and coast', 22.5, 91.9, 6),
    _SceneRow('400F', 16, 6486, 'Sylhet, Mymensingh, north-east', 24.4, 90.7,
        2),
    _SceneRow('BA9A', 17, 394, 'north-west (Rangpur)', 25.7, 89.2, 7),
    _SceneRow('FD77', 17, 1953, 'north-west and Rajshahi', 24.6, 88.9, 4),
    _SceneRow('4CBE', 17, 128, 'south-west', 22.9, 89.2, 8),
    _SceneRow('B137', 18, 6665, 'Sylhet, Mymensingh, north-east', 24.8, 91.3,
        1),
    _SceneRow('157B', 18, 1194, 'Chattogram, Feni, Noakhali, Cox\'s Bazar',
        22.4, 91.6, 5),
    _SceneRow('0450', 21, 2203, 'Cumilla, Noakhali, Feni, Chattogram', 23.0,
        91.4, 3),
  ];

  /// Inundated area per upazila on 21 Aug 2024 [S1] and reference points [S4].
  static const List<_Upazila> _upazilas = <_Upazila>[
    _Upazila('sonagazi', 'Sonagazi', 1, 49, 22.8576, 91.3956,
        'Value: Uddin et al. (2025). Position: Wikipedia reference point.'),
    _Upazila('chhagalnaiya', 'Chhagalnaiya', 2, 37, 23.0367, 91.5200,
        'Value: Uddin et al. (2025). Position: Wikipedia reference point.'),
    _Upazila('fulgazi', 'Fulgazi', 3, 35, 23.133, 91.433,
        'Value: Uddin et al. (2025). Position: Wikipedia reference point.'),
    _Upazila('feni_sadar', 'Feni Sadar', 4, 33, 23.017, 91.3917,
        'Value: Uddin et al. (2025). Position: Wikipedia reference point.'),
    _Upazila('parshuram', 'Parshuram', 5, 31, 23.217, 91.4417,
        'Value: Wikipedia summary of Uddin et al. (2025). Position: '
            'Wikipedia reference point.'),
    // Position = centre of the Banglapedia bounding box (22.88-23.07N,
    // 91.25-91.37E).
    _Upazila('daganbhuiyan', 'Daganbhuiyan', 6, 16, 22.975, 91.308,
        'Value: Wikipedia summary of Uddin et al. (2025). Position: centre '
            'of the Banglapedia bounding box.'),
  ];

  // ---------------------------------------------------------------------
  // 2. Eastern Bangladesh - UNOSAT [S2] + World Bank GRADE [S3]
  // ---------------------------------------------------------------------
  static MockBundle _eastern() {
    final observations = <Observation>[
      Observation(
        id: 'obs_0',
        // End date of the UNOSAT composite window 18-26 Aug 2024.
        date: DateTime(2024, 8, 26),
        label: 'T0 18-26 Aug',
        sensor: 'Sentinel-1 composite, 18-26 Aug 2024 (UNOSAT)',
        qualityNote: 'Composite of scenes from 18-26 Aug; dated by its last '
            'day. Period-specific flooded area is not stated by the source.',
      ),
      Observation(
        id: 'obs_1',
        // End date of the UNOSAT composite window 28 Aug - 4 Sep 2024.
        date: DateTime(2024, 9, 4),
        label: 'T1 28 Aug-4 Sep',
        sensor: 'Sentinel-1 composite, 28 Aug-4 Sep 2024 (UNOSAT)',
        qualityNote: 'Composite of scenes from 28 Aug-4 Sep; dated by its '
            'last day. Period-specific flooded area is not stated by the '
            'source.',
      ),
    ];

    // Only the change reported by UNOSAT is entered. The two period totals
    // are not given separately, so they stay null.
    const changeStats = <ChangeStat>[
      ChangeStat(
        fromObservationId: 'obs_0',
        toObservationId: 'obs_1',
        netChangeKm2: -8700.0,
      ),
    ];

    final zones = <HazardZone>[
      for (final d in _districts)
        HazardZone(
          id: d.id,
          name: d.name,
          hazard: HazardType.floodExpansion,
          rank: d.rank,
          basis: ZoneBasis.observed,
          centroid: LatLng(d.lat, d.lng),
          summary: d.summary,
          evidence: d.evidence,
          dataQuality: d.id == _fao.id
              ? 'Satellite-based FAO DIEM analysis, cited by the World Bank '
                  'GRADE report (Oct 2024).'
              : 'Government-reported figures (MoDMR / DDM) as cited by the '
                  'World Bank GRADE report (Oct 2024).',
        ),
    ];

    final analysis = AnalysisResult(
      id: easternAnalysisId,
      hazard: HazardType.floodExpansion,
      studyAreaId: easternAreaId,
      title: 'Eastern Bangladesh - August 2024 floods (UNOSAT + World Bank)',
      status: DataStatus.preliminary,
      isSample: false,
      datasetLabel: datasetLabel,
      statusNote: 'Real historical figures only. No verified flood-extent '
          'geometry is bundled, so this analysis has no map overlays.',
      observations: observations,
      changeStats: changeStats,
      prediction: const PredictionInfo(
        status: DataStatus.notAvailable,
        kind: PredictionKind.none,
        label: 'Future flood expansion',
        description: 'This record holds historical observations and reported '
            'impacts only. No forecast or expansion model was produced.',
        caveats: <String>[
          'A decrease or increase between two dates does not predict what '
              'happens next.',
        ],
      ),
      validationStatus: DataStatus.notEvaluated,
      zones: zones,
      dataSources: const <DataSourceRef>[
        DataSourceRef(
          label: 'Satellite detected water extents between 28 August & '
              '4 September 2024 in Bangladesh (FL20240825BGD)',
          provider: 'UNOSAT via Humanitarian Data Exchange (CC BY-SA)',
          note: 'Sentinel-1, automated machine-learning analysis; '
              'preliminary, not validated in the field.',
        ),
        DataSourceRef(
          label: 'GRADE Report: Floods in eastern Bangladesh, August 2024 '
              '(as of 7 Oct 2024)',
          provider: 'World Bank (GFDRR / D-RAS)',
          note: 'District tables compiled from MoDMR / DDM reports; cropland '
              'estimate from FAO DIEM.',
        ),
        DataSourceRef(
          label: 'District reference points used as zone positions',
          provider: 'Wikipedia',
          note: 'Administrative reference points, not boundaries.',
        ),
      ],
      qualityFlags: const <QualityFlag>[
        QualityFlag(
          label: 'UNOSAT aggregate, 18 Aug - 4 Sep 2024',
          detail: 'Within the analysed area of about 140,000 km\u00b2, about '
              '8,100 km\u00b2 of land appears affected by flood waters and '
              'about 6.2 million people are exposed or living close to '
              'flooded areas (WorldPop). Floodwaters receded by about '
              '8,700 km\u00b2 between the two periods.',
        ),
        QualityFlag(
          label: 'Event totals (World Bank GRADE)',
          detail: 'Over six million people affected in 11 districts, '
              '597,552 displaced, 74 deaths, estimated direct damage '
              'US\$1.676 billion (about 0.38% of GDP).',
        ),
        QualityFlag(
          label: 'Observation dates',
          detail: 'Dates shown are the last days of the UNOSAT composite '
              'windows (18-26 Aug and 28 Aug - 4 Sep). The period totals are '
              'not given separately, so only the reported change is shown.',
        ),
        QualityFlag(
          label: 'Radar limitation',
          detail: 'UNOSAT warns that radar analysis may underestimate '
              'standing water in built-up and densely vegetated areas. The '
              'analysis is preliminary and not validated in the field.',
          level: QualityLevel.warning,
        ),
        QualityFlag(
          label: 'Reported, not mapped',
          detail: 'District figures are government-reported damage counts '
              'cited by the World Bank. They are not derived from the '
              'satellite mask.',
          level: QualityLevel.warning,
        ),
      ],
      limitations: const <String>[
        'Historical records only; no forecast or susceptibility was produced.',
        'No map geometry is bundled, so Explore shows no overlays here.',
        'UNOSAT totals cover about 140,000 km\u00b2 analysed nationally, not '
            'only the three districts listed as zones.',
        'The GRADE report gives two cropland figures (321,680 ha damaged in '
            'its text, at least 259,366 ha in its conclusion).',
        'Zone positions are Wikipedia district reference points, not '
            'boundaries.',
      ],
      processingVersion: 'published figures (not reprocessed)',
    );

    return MockBundle(
      summary: AnalysisSummary(
        id: easternAnalysisId,
        hazard: HazardType.floodExpansion,
        studyAreaId: easternAreaId,
        title: analysis.title,
        status: DataStatus.preliminary,
        isSample: false,
        observationCount: 2,
        latestObservationDate: DateTime(2024, 9, 4),
        headlineLabel: 'Net mapped flood-extent change',
        headlineValue: -8700.0,
        headlineUnit: 'km\u00b2',
      ),
      analysis: analysis,
      layers: const [],
      validation: const ValidationResult(
        analysisId: easternAnalysisId,
        status: DataStatus.notEvaluated,
        isSample: false,
        notes: <String>[
          'UNOSAT describes its analysis as preliminary and not yet validated '
              'in the field.',
          'No independent comparison was performed here.',
        ],
        limitations: <String>[
          '"Not evaluated" is not a pass.',
        ],
      ),
      explanation: const ExplanationResult(
        analysisId: easternAnalysisId,
        status: DataStatus.notAvailable,
        isSample: false,
        caveat: 'No model explanation: this record contains observed and '
            'reported figures only.',
      ),
      impact: ImpactSummary(
        analysisId: easternAnalysisId,
        status: DataStatus.preliminary,
        isSample: false,
        disclaimer: 'These are reported damage counts from Bangladesh '
            'authorities (as cited by the World Bank GRADE report) and a '
            'satellite-based cropland estimate, not modelled exposure from a '
            'flood footprint. They do not describe current danger.',
        zoneImpacts: <ZoneImpact>[
          for (final d in _districts)
            ZoneImpact(
              zoneId: d.id,
              zoneName: d.name,
              basis: ZoneBasis.observed,
              exposures: _exposures(d),
            ),
        ],
        dataNotes: const <ExposureDataNote>[
          ExposureDataNote(
            category: AssetCategory.buildings,
            source: 'MoDMR D-Form compiled by the Needs Assessment Working '
                'Group, cited in World Bank GRADE',
            dataDate: '26 Sep 2024',
            coverage: 'Reported damaged or destroyed structures in 8 of the '
                '11 affected districts.',
          ),
          ExposureDataNote(
            category: AssetCategory.roads,
            source: 'MoDMR D-Form compiled by the Needs Assessment Working '
                'Group, cited in World Bank GRADE',
            dataDate: '26 Sep 2024',
            coverage: 'Reported damaged road length in 8 of the 11 affected '
                'districts.',
          ),
          ExposureDataNote(
            category: AssetCategory.schools,
            source: 'MoDMR D-Form compiled by the Needs Assessment Working '
                'Group, cited in World Bank GRADE',
            dataDate: '26 Sep 2024',
            coverage: 'Reported damaged educational institutes (primary and '
                'high schools, colleges, madrasas, community schools).',
          ),
          ExposureDataNote(
            category: AssetCategory.agriculture,
            source: 'FAO DIEM satellite analysis, cited in World Bank GRADE',
            dataDate: '3 Sep 2024',
            coverage: 'Whole flood extent; not broken down by district in '
                'the report.',
          ),
          ExposureDataNote(
            category: AssetCategory.communities,
            source: 'Not available',
            coverage: 'No community-level figures are bundled.',
          ),
        ],
      ),
    );
  }

  /// District zones [S3] (rank = GRADE estimated direct damage, high to low)
  /// plus the whole-extent agricultural estimate [S3 / FAO DIEM].
  static const List<_District> _districts = <_District>[
    _District(
      'noakhali', 'Noakhali district', 1, 22.70, 91.10,
      houses: 154892, roadsKm: 5545, schools: 1107,
      summary: 'Worst-affected district in the World Bank GRADE estimate '
          '(about US\$508.8 million direct damage).',
      evidence: <String>[
        'Reported affected population: 2,125,500 (57% of the district); '
            '439,415 households cut off.',
        'Reported deaths: 11.',
        'Reported damaged: 154,892 structures, 5,545 km of roads, 1,107 '
            'educational institutes.',
      ],
    ),
    _District(
      'cumilla', 'Cumilla district', 2, 23.27, 91.12,
      houses: 82755, roadsKm: 3648, schools: 854,
      summary: 'Second-highest direct damage in the World Bank GRADE '
          'estimate (about US\$362.6 million).',
      evidence: <String>[
        'Reported affected population: 1,090,592 (17% of the district); '
            '213,224 households cut off.',
        'Reported deaths: 19.',
        'Reported damaged: 82,755 structures, 3,648 km of roads, 854 '
            'educational institutes.',
      ],
    ),
    _District(
      'feni', 'Feni district', 3, 23.000, 91.400,
      houses: 64415, roadsKm: 1871, schools: 598,
      summary: 'Third-highest direct damage in the World Bank GRADE estimate '
          '(about US\$312.7 million); highest death toll.',
      evidence: <String>[
        'Reported affected population: 1,000,000 (59% of the district); '
            '250,000 households cut off.',
        'Reported deaths: 28.',
        'Reported damaged: 64,415 structures, 1,871 km of roads, 598 '
            'educational institutes.',
      ],
    ),
    _fao,
  ];

  /// Not a place: the whole satellite-mapped flood extent (FAO DIEM, ~3 Sep
  /// 2024: about three million ha, of which about two million ha cropland).
  static const _District _fao = _District(
    'all_flooded_areas', 'All flooded areas (FAO DIEM, about 3 Sep 2024)', 4,
    23.000, 91.250,
    croplandHa: 2000000,
    summary: 'Satellite-based FAO analysis cited by the World Bank: flood '
        'extent of about three million ha by 3 Sep 2024, about two million '
        'ha of it cropland. A region-wide estimate, not a single place.',
    evidence: <String>[
      'Flood extent: about three million ha by 3 Sep 2024.',
      'About two million ha of the flooded area was cropland, with high '
          'impact on aman rice production.',
    ],
  );

  static List<ExposureCount> _exposures(_District d) {
    ExposureCount count(AssetCategory c, double? v, {String? note}) =>
        ExposureCount(
          category: c,
          value: v,
          approximate: c == AssetCategory.agriculture,
          isIllustrative: false,
          note: note,
        );
    return <ExposureCount>[
      count(
        AssetCategory.buildings,
        d.houses?.toDouble(),
        note: d.houses == null
            ? 'Not reported for this entry.'
            : 'Reported damaged or destroyed structures (MoDMR), not '
                'modelled exposure.',
      ),
      count(
        AssetCategory.roads,
        d.roadsKm?.toDouble(),
        note: d.roadsKm == null
            ? 'Not reported for this entry.'
            : 'Reported damaged road length (MoDMR).',
      ),
      count(
        AssetCategory.schools,
        d.schools?.toDouble(),
        note: d.schools == null
            ? 'Not reported for this entry.'
            : 'Reported damaged educational institutes (MoDMR), including '
                'colleges and madrasas.',
      ),
      count(
        AssetCategory.agriculture,
        d.croplandHa?.toDouble(),
        note: d.croplandHa == null
            ? 'No district-level cropland figure in the cited report.'
            : 'About two million ha of flooded cropland (FAO DIEM).',
      ),
      count(
        AssetCategory.communities,
        null,
        note: 'Not reported in the cited sources.',
      ),
    ];
  }
}

class _Upazila {
  const _Upazila(this.id, this.name, this.rank, this.km2, this.lat, this.lng,
      this.quality);

  final String id;
  final String name;
  final int rank;
  final double km2;
  final double lat;
  final double lng;
  final String quality;
}

class _District {
  const _District(
    this.id,
    this.name,
    this.rank,
    this.lat,
    this.lng, {
    this.houses,
    this.roadsKm,
    this.schools,
    this.croplandHa,
    required this.summary,
    required this.evidence,
  });

  final String id;
  final String name;
  final int rank;
  final double lat;
  final double lng;
  final int? houses;
  final int? roadsKm;
  final int? schools;
  final int? croplandHa;
  final String summary;
  final List<String> evidence;
}

class _ExposedDistrict {
  const _ExposedDistrict(
      this.id, this.name, this.rank, this.lat, this.lng, this.increase);

  final String id;
  final String name;
  final int rank;
  final double lat;
  final double lng;
  final String increase;
}

class _SceneRow {
  const _SceneRow(
      this.id, this.day, this.area, this.region, this.lat, this.lng, this.rank);

  final String id;
  final int day;
  final double area;
  final String region;
  final double lat;
  final double lng;
  final int rank;
}
