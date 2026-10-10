import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../models/analysis_result.dart';
import '../../models/data_status.dart';
import '../../models/explanation_result.dart';
import '../../models/hazard_type.dart';
import '../../models/hazard_zone.dart';
import '../../models/impact_summary.dart';
import '../../models/map_layer.dart';
import '../../models/observation.dart';
import '../../models/study_area.dart';
import '../../models/validation_result.dart';
import 'real_aug2024_data.dart';

/// Everything the backend would eventually return for one analysis.
class MockBundle {
  const MockBundle({
    required this.summary,
    required this.analysis,
    required this.layers,
    required this.validation,
    required this.explanation,
    required this.impact,
  });

  final AnalysisSummary summary;
  final AnalysisResult analysis;
  final List<MapLayer> layers;
  final ValidationResult validation;
  final ExplanationResult explanation;
  final ImpactSummary impact;
}

/// Deterministic SAMPLE dataset.
///
/// IMPORTANT: every value, date, geometry and count in this file is
/// illustrative. None of it is a satellite-derived measurement, a validated
/// model output or a real infrastructure inventory. Place names only indicate
/// the kind of region the real pipeline would target.
///
/// To change the demo, edit the builders below. Geometry is generated from
/// the sample areas so polygons stay roughly proportional to the numbers.
class MockData {
  const MockData._();

  static const String datasetLabel = 'SAMPLE-DATASET v1';
  static const String sampleTag = '(sample)';

  // ---------------------------------------------------------------------
  // Study areas
  // ---------------------------------------------------------------------
  static final LatLng _sylhet = LatLng(24.90, 91.87);
  static final LatLng _jamuna = LatLng(25.45, 89.65);
  static final LatLng _haor = LatLng(24.85, 91.20);
  static final LatLng _hills = LatLng(22.38, 91.83);

  static final List<StudyArea> areas = <StudyArea>[
    StudyArea(
      id: 'area_sylhet_floodplain',
      name: 'Sylhet floodplain',
      region: 'Bangladesh',
      center: _sylhet,
      zoom: 10.5,
      supportedHazards: const <HazardType>[HazardType.floodExpansion],
      description: 'Low-lying floodplain used to demonstrate flood-extent '
          'change between three SAR dates.',
      boundary: _rect(_sylhet, 22, 26),
      isSample: true,
    ),
    StudyArea(
      id: 'area_jamuna_floodplain',
      name: 'Jamuna riverine floodplain',
      region: 'Bangladesh',
      center: _jamuna,
      zoom: 10.5,
      supportedHazards: const <HazardType>[HazardType.floodExpansion],
      description: 'River-channel floodplain whose sample extent expands and '
          'then partly recedes; includes a preliminary estimate layer.',
      boundary: _rect(_jamuna, 26, 22),
      isSample: true,
    ),
    StudyArea(
      id: 'area_haor_basin',
      name: 'Haor basin',
      region: 'Bangladesh',
      center: _haor,
      zoom: 9.5,
      supportedHazards: const <HazardType>[HazardType.floodExpansion],
      description: 'Demonstrates the unavailable-data state: no suitable '
          'observations have been identified yet.',
      boundary: _rect(_haor, 30, 24),
      isSample: true,
    ),
    StudyArea(
      id: 'area_chattogram_hills',
      name: 'Chattogram hill slopes',
      region: 'Bangladesh',
      center: _hills,
      zoom: 13.5,
      supportedHazards: const <HazardType>[HazardType.slopeDeformation],
      description: 'Hill catchment used to demonstrate slope-deformation '
          'monitoring kept separate from preliminary susceptibility.',
      boundary: _rect(_hills, 4.6, 3.8),
      isSample: true,
    ),
    // Real historical records (August 2024 floods), see real_aug2024_data.dart.
    ...RealAug2024Data.areas,
  ];

  // ---------------------------------------------------------------------
  // Analyses
  // ---------------------------------------------------------------------
  static final List<MockBundle> bundles = <MockBundle>[
    _flood001(),
    _flood002(),
    _flood003(),
    _slope001(),
    // Real historical records (August 2024 floods), see real_aug2024_data.dart.
    ...RealAug2024Data.bundles,
  ];

  static MockBundle? bundleFor(String analysisId) {
    for (final b in bundles) {
      if (b.analysis.id == analysisId) return b;
    }
    return null;
  }

  static StudyArea? areaFor(String id) {
    for (final a in areas) {
      if (a.id == id) return a;
    }
    return null;
  }

  // =====================================================================
  // Flood analysis 001 - monotonic expansion, no prediction available
  // =====================================================================
  static MockBundle _flood001() {
    final observations = _floodObservations(
      <DateTime>[DateTime(2025, 6, 14), DateTime(2025, 6, 26), DateTime(2025, 7, 8)],
      <double>[118.4, 141.9, 164.9],
    );
    const zoneSpecs = <_ZoneSpec>[
      _ZoneSpec(
        id: 'flood_001_zone_a',
        name: 'Zone A - north-east lobe',
        rank: 1,
        basis: ZoneBasis.observed,
        dx: 4.2, dy: 4.4, footprintKm2: 24.0,
        summary: 'Largest increase in mapped inundation between the first and '
            'last sample dates.',
        evidence: <String>[
          'Flooded area inside the zone grows at every sample date.',
          'Largest absolute increase of the three mapped zones.',
          'Outside the reference river channel in the sample terrain layer.',
        ],
        values: <double>[2.1, 9.8, 20.3],
        dataQuality: 'Good SAR coverage on all three dates (sample).',
      ),
      _ZoneSpec(
        id: 'flood_001_zone_b',
        name: 'Zone B - western margin',
        rank: 2,
        basis: ZoneBasis.observed,
        dx: -4.6, dy: 2.8, footprintKm2: 18.0,
        summary: 'Steady widening along the western floodplain margin.',
        evidence: <String>[
          'Flooded area increases at both intervals.',
          'Low elevation relative to the nearest drainage (sample terrain).',
        ],
        values: <double>[3.0, 8.1, 15.7],
        dataQuality: 'Partial shadow in the T1 scene (sample).',
      ),
      _ZoneSpec(
        id: 'flood_001_zone_c',
        name: 'Zone C - southern channel',
        rank: 3,
        basis: ZoneBasis.observed,
        dx: -0.6, dy: -8.5, footprintKm2: 12.0,
        summary: 'Smaller but consistent expansion near the southern channel.',
        evidence: <String>[
          'Flooded area increases at both intervals.',
          'Adjacent to mapped communities (see Impact).',
        ],
        values: <double>[1.2, 4.0, 9.1],
        dataQuality: 'Mixed pixels near the channel edge (sample).',
      ),
    ];
    final zones = _zones(HazardType.floodExpansion, _sylhet, zoneSpecs,
        'Flooded area inside zone (km\u00b2)', observations);
    final analysis = AnalysisResult(
      id: 'flood_demo_001',
      hazard: HazardType.floodExpansion,
      studyAreaId: 'area_sylhet_floodplain',
      title: 'Sylhet floodplain - flood extent $sampleTag',
      status: DataStatus.available,
      isSample: true,
      datasetLabel: datasetLabel,
      observations: observations,
      changeStats: _changeStats(observations),
      prediction: const PredictionInfo(
        status: DataStatus.notAvailable,
        kind: PredictionKind.none,
        label: 'Future flood expansion',
        description: 'No validated expansion model exists for this area yet. '
            'Historical flood labels and independent validation data are '
            'still to be assembled.',
        caveats: <String>[
          'A detected increase in flooded area does not prove that flooding '
              'will keep spreading.',
        ],
      ),
      validationStatus: DataStatus.notEvaluated,
      zones: zones,
      dataSources: _floodSources(),
      qualityFlags: const <QualityFlag>[
        QualityFlag(
          label: 'Observation interval',
          detail: 'Dates are 12 days apart; short-lived flooding between '
              'acquisitions cannot be seen (sample).',
        ),
        QualityFlag(
          label: 'Reference data',
          detail: 'No independent reference flood extent is linked, so map '
              'accuracy is not yet quantified.',
          level: QualityLevel.warning,
        ),
      ],
      limitations: const <String>[
        'Mapped area describes observed inundation only; it is not a forecast.',
        'Sample polygons are schematic and only roughly scaled to the areas.',
        'No accuracy assessment against independent data has been performed.',
      ],
      processingVersion: 'sample-0.1',
      crs: 'EPSG:32646 (areas) / EPSG:4326 (display)',
    );
    final layers = _floodLayers(
      center: _sylhet,
      aspect: 1.8,
      seed: 0.7,
      observations: observations,
      zones: zones,
      predictionStatus: DataStatus.notAvailable,
      predictionReason: 'No validated expansion model for this area yet.',
      infraScale: 1.0,
    );
    return MockBundle(
      summary: _summaryOf(analysis),
      analysis: analysis,
      layers: layers,
      validation: const ValidationResult(
        analysisId: 'flood_demo_001',
        status: DataStatus.notEvaluated,
        isSample: true,
        notes: <String>[
          'No model has been trained, so there are no held-out metrics.',
          'Flood-mask accuracy needs an independent reference extent.',
        ],
        limitations: <String>[
          'Validation status is "not evaluated" - this is not a pass.',
        ],
      ),
      explanation: const ExplanationResult(
        analysisId: 'flood_demo_001',
        status: DataStatus.notAvailable,
        isSample: true,
        caveat: 'Model-based explanations need a validated model. The zone '
            'evidence shown elsewhere is based on observations only.',
      ),
      impact: _floodImpact('flood_demo_001', zones, <List<double?>>[
        <double?>[1200, 18, 3, 420, 5],
        <double?>[800, 11, 2, 310, 3],
        <double?>[300, 6, null, 150, 2],
      ]),
    );
  }

  // =====================================================================
  // Flood analysis 002 - expansion then partial recession, preliminary
  // estimate and sample validation
  // =====================================================================
  static MockBundle _flood002() {
    final observations = _floodObservations(
      <DateTime>[DateTime(2025, 7, 2), DateTime(2025, 7, 14), DateTime(2025, 7, 26)],
      <double>[80.1, 104.7, 92.3],
    );
    const zoneSpecs = <_ZoneSpec>[
      _ZoneSpec(
        id: 'flood_002_zone_a',
        name: 'Zone A - main channel bend',
        rank: 1,
        basis: ZoneBasis.observed,
        dx: 3.8, dy: 2.2, footprintKm2: 20.0,
        summary: 'Peak inundation at T1, partly receded by T2.',
        evidence: <String>[
          'Flooded area rises then falls across the three dates.',
          'Still larger at T2 than at T0.',
        ],
        values: <double>[5.0, 14.6, 11.2],
        dataQuality: 'Good coverage on all dates (sample).',
      ),
      _ZoneSpec(
        id: 'flood_002_zone_b',
        name: 'Zone B - north bank',
        rank: 2,
        basis: ZoneBasis.observed,
        dx: -5.5, dy: 4.0, footprintKm2: 15.0,
        summary: 'Rapid rise between T0 and T1, slow recession afterwards.',
        evidence: <String>[
          'Largest relative increase of the observed zones.',
          'Remains partly inundated at T2.',
        ],
        values: <double>[2.4, 9.9, 8.7],
        dataQuality: 'Wet-soil ambiguity in the T0 scene (sample).',
      ),
      _ZoneSpec(
        id: 'flood_002_zone_c',
        name: 'Zone C - eastern margin (estimated)',
        rank: 3,
        basis: ZoneBasis.predicted,
        dx: 6.5, dy: -3.5, footprintKm2: 14.0,
        summary: 'Preliminary estimate of where inundation could extend. '
            'Not an observation.',
        evidence: <String>[
          'Sample relative score is high compared with other margins.',
          'Not validated: treat as a hypothesis to check against new data.',
        ],
        values: <double>[],
        dataQuality: 'Depends on a preliminary, uncalibrated sample layer.',
      ),
    ];
    final zones = _zones(HazardType.floodExpansion, _jamuna, zoneSpecs,
        'Flooded area inside zone (km\u00b2)', observations);
    final analysis = AnalysisResult(
      id: 'flood_demo_002',
      hazard: HazardType.floodExpansion,
      studyAreaId: 'area_jamuna_floodplain',
      title: 'Jamuna floodplain - flood extent $sampleTag',
      status: DataStatus.available,
      isSample: true,
      datasetLabel: datasetLabel,
      observations: observations,
      changeStats: _changeStats(observations),
      prediction: const PredictionInfo(
        status: DataStatus.preliminary,
        kind: PredictionKind.relativeScore,
        label: 'Relative expansion-proneness',
        forecastHorizon: 'Next observation interval (about 12 days)',
        description: 'A fixed sample layer that ranks margins of the current '
            'flood extent against each other. In the live product this would '
            'come from a baseline model trained on historical flood labels.',
        isCalibrated: false,
        caveats: <String>[
          'Relative score only - not a calibrated probability.',
          'Not validated on independent future floods.',
          'Observed change between two dates does not prove continued '
              'expansion.',
        ],
      ),
      validationStatus: DataStatus.preliminary,
      zones: zones,
      dataSources: _floodSources(),
      qualityFlags: const <QualityFlag>[
        QualityFlag(
          label: 'Training labels',
          detail: 'Only a short sample history is available, so any model '
              'result is preliminary.',
          level: QualityLevel.warning,
        ),
        QualityFlag(
          label: 'Observation interval',
          detail: 'Dates are 12 days apart (sample).',
        ),
      ],
      limitations: const <String>[
        'Estimated zones are separate from observed zones and are labelled '
            'as predicted.',
        'Sample geometry is schematic.',
        'Preliminary validation uses placeholder numbers for layout only.',
      ],
      processingVersion: 'sample-0.1',
      crs: 'EPSG:32646 (areas) / EPSG:4326 (display)',
    );
    final layers = _floodLayers(
      center: _jamuna,
      aspect: 2.2,
      seed: 2.1,
      observations: observations,
      zones: zones,
      predictionStatus: DataStatus.preliminary,
      predictionReason: null,
      infraScale: 1.0,
    );
    return MockBundle(
      summary: _summaryOf(analysis),
      analysis: analysis,
      layers: layers,
      validation: const ValidationResult(
        analysisId: 'flood_demo_002',
        status: DataStatus.preliminary,
        isSample: true,
        method: 'Baseline classifier (sample placeholder)',
        testPeriod: 'Held-out later season (sample description)',
        splitStrategy: 'Temporal hold-out with spatial blocks (sample '
            'description)',
        metrics: <ValidationMetric>[
          ValidationMetric(
            name: 'Precision',
            value: 0.62,
            description: 'Share of flagged area that was flooded.',
          ),
          ValidationMetric(
            name: 'Recall',
            value: 0.55,
            description: 'Share of flooded area that was flagged.',
          ),
          ValidationMetric(
            name: 'IoU',
            value: 0.41,
            description: 'Overlap between flagged and flooded area.',
          ),
        ],
        notes: <String>[
          'These are SAMPLE numbers shown to demonstrate the layout. They '
              'were not computed from real data.',
        ],
        limitations: <String>[
          'Metrics must come from a real held-out evaluation, not training '
              'accuracy.',
          'Short history: confidence in any metric would be low.',
        ],
      ),
      explanation: const ExplanationResult(
        analysisId: 'flood_demo_002',
        status: DataStatus.preliminary,
        isSample: true,
        method: 'Qualitative factor ranking (sample, no numeric attribution)',
        factors: <ContributingFactor>[
          ContributingFactor(
            rank: 1,
            name: 'Height above nearest drainage',
            description: 'Lower ground near channels is more likely to flood.',
            direction: 'decreases',
          ),
          ContributingFactor(
            rank: 2,
            name: 'Antecedent rainfall',
            description: 'Wetter preceding weeks coincide with larger extents.',
            direction: 'increases',
          ),
          ContributingFactor(
            rank: 3,
            name: 'Distance to current flood edge',
            description: 'Margins next to existing water change first.',
            direction: 'decreases',
          ),
          ContributingFactor(
            rank: 4,
            name: 'Land cover',
            description: 'Open cropland drains differently from settlements.',
            direction: 'context',
          ),
        ],
        caveat: 'Explanations describe associations in the model inputs. '
            'They do not prove causes.',
      ),
      impact: _floodImpact('flood_demo_002', zones, <List<double?>>[
        <double?>[900, 12, 2, 380, 4],
        <double?>[600, 8, 1, 260, 3],
        <double?>[400, 7, 1, 230, 2],
      ]),
    );
  }

  // =====================================================================
  // Flood analysis 003 - demonstrates "not available"
  // =====================================================================
  static MockBundle _flood003() {
    const analysis = AnalysisResult(
      id: 'flood_demo_003',
      hazard: HazardType.floodExpansion,
      studyAreaId: 'area_haor_basin',
      title: 'Haor basin - flood extent (sample)',
      status: DataStatus.notAvailable,
      isSample: true,
      datasetLabel: datasetLabel,
      statusNote: 'No suitable SAR acquisitions have been identified for this '
          'area yet. This is a demonstration of the unavailable-data state.',
      prediction: PredictionInfo(status: DataStatus.notAvailable),
      validationStatus: DataStatus.notEvaluated,
      limitations: <String>[
        'No observations, so no change can be measured.',
        'The absence of data must not be read as the absence of hazard.',
      ],
    );
    return MockBundle(
      summary: _summaryOf(analysis),
      analysis: analysis,
      layers: const <MapLayer>[],
      validation: const ValidationResult(
        analysisId: 'flood_demo_003',
        status: DataStatus.notEvaluated,
        isSample: true,
      ),
      explanation: const ExplanationResult(
        analysisId: 'flood_demo_003',
        status: DataStatus.notAvailable,
        isSample: true,
      ),
      impact: const ImpactSummary(
        analysisId: 'flood_demo_003',
        status: DataStatus.notAvailable,
        isSample: true,
      ),
    );
  }

  // =====================================================================
  // Slope analysis 001 - deformation monitoring + preliminary susceptibility
  // =====================================================================
  static MockBundle _slope001() {
    final dates = <DateTime>[
      DateTime(2025, 1, 10),
      DateTime(2025, 3, 6),
      DateTime(2025, 5, 1),
      DateTime(2025, 6, 26),
      DateTime(2025, 8, 21),
      DateTime(2025, 10, 16),
    ];
    const meanLos = <double>[0, -2.4, -4.3, -7.7, -11.0, -13.9];
    final observations = <Observation>[
      for (var i = 0; i < dates.length; i++)
        Observation(
          id: 'obs_$i',
          date: dates[i],
          label: 'T$i',
          sensor: 'SAR (sample)',
          meanLosDisplacementMm: meanLos[i],
          qualityNote: i == 3 ? 'Reduced coherence after heavy rain (sample).' : null,
        ),
    ];
    const zoneSpecs = <_ZoneSpec>[
      _ZoneSpec(
        id: 'slope_001_zone_a',
        name: 'Zone A - upper cut slope',
        rank: 1,
        basis: ZoneBasis.observed,
        dx: -0.5, dy: 0.5, footprintKm2: 1.9,
        summary: 'Largest cumulative line-of-sight displacement in the '
            'monitored area.',
        evidence: <String>[
          'Cumulative displacement grows at every acquisition.',
          'Trend is steady rather than a single jump.',
          'Largest magnitude of the three monitored zones.',
        ],
        values: <double>[0, -4.2, -7.9, -14.0, -20.6, -26.3],
        dataQuality: 'Moderate coherence; vegetation gaps (sample).',
      ),
      _ZoneSpec(
        id: 'slope_001_zone_b',
        name: 'Zone B - road embankment',
        rank: 2,
        basis: ZoneBasis.observed,
        dx: 0.9, dy: -0.4, footprintKm2: 1.4,
        summary: 'Moderate, steady line-of-sight displacement.',
        evidence: <String>[
          'Cumulative displacement grows at every acquisition.',
          'Adjacent to the sample road layer (see Impact).',
        ],
        values: <double>[0, -2.1, -3.5, -6.2, -8.8, -10.9],
        dataQuality: 'Good coherence on built surfaces (sample).',
      ),
      _ZoneSpec(
        id: 'slope_001_zone_c',
        name: 'Zone C - lower terrace',
        rank: 3,
        basis: ZoneBasis.observed,
        dx: -0.2, dy: -1.1, footprintKm2: 0.5,
        summary: 'Small displacement close to the estimated noise level.',
        evidence: <String>[
          'Total change is small compared with the sample noise estimate.',
          'Should be monitored rather than interpreted as movement.',
        ],
        values: <double>[0, -1.0, -1.6, -2.9, -3.6, -4.4],
        dataQuality: 'Low signal-to-noise ratio (sample).',
      ),
      _ZoneSpec(
        id: 'slope_001_zone_s',
        name: 'Zone S - upper catchment (relative class: high)',
        rank: 4,
        basis: ZoneBasis.predicted,
        dx: 0.4, dy: 0.9, footprintKm2: 4.2,
        summary: 'Relative susceptibility class from a preliminary sample '
            'assessment. Not a probability and not an observation.',
        evidence: <String>[
          'Steep terrain and high sample rainfall index.',
          'Overlaps the strongest deformation evidence (Zone A).',
          'No landslide inventory was used to validate this class.',
        ],
        values: <double>[],
        dataQuality: 'Depends on preliminary, unvalidated sample inputs.',
        susceptibilityClass: 'high',
      ),
    ];
    final zones = _zones(HazardType.slopeDeformation, _hills, zoneSpecs,
        'Cumulative LOS displacement (mm)', observations);
    final analysis = AnalysisResult(
      id: 'slope_demo_001',
      hazard: HazardType.slopeDeformation,
      studyAreaId: 'area_chattogram_hills',
      title: 'Chattogram hill slopes - deformation $sampleTag',
      status: DataStatus.preliminary,
      isSample: true,
      datasetLabel: datasetLabel,
      observations: observations,
      deformation: const DeformationSummary(
        losConvention: 'Negative values mean motion away from the sensor '
            'along the line of sight (LOS).',
        maxLosDisplacementMm: -26.3,
        medianLosDisplacementMm: -10.9,
        monitoredAreaKm2: 3.8,
        zoneCount: 3,
        noiseNote: 'Zone C changes (about -4 mm) are close to the sample '
            'noise estimate and should not be read as movement.',
      ),
      prediction: const PredictionInfo(
        status: DataStatus.preliminary,
        kind: PredictionKind.relativeClass,
        label: 'Landslide susceptibility (relative)',
        description: 'Relative classes rank areas against each other using '
            'terrain, rainfall and deformation context. Here they are fixed '
            'sample polygons.',
        isCalibrated: false,
        caveats: <String>[
          'Not a probability of a landslide and not a timing forecast.',
          'No landslide inventory was used to validate the classes.',
          'Deformation evidence alone does not imply an imminent landslide.',
        ],
      ),
      validationStatus: DataStatus.notEvaluated,
      zones: zones,
      dataSources: const <DataSourceRef>[
        DataSourceRef(
          label: 'SAR acquisitions for InSAR (sample)',
          provider: 'Sample dataset',
          note: 'Illustrative dates; not a real acquisition list.',
        ),
        DataSourceRef(
          label: 'Digital elevation model (sample)',
          provider: 'Sample dataset',
        ),
        DataSourceRef(
          label: 'Rainfall history (sample)',
          provider: 'Sample dataset',
        ),
        DataSourceRef(
          label: 'Landslide inventory',
          note: 'Not linked - susceptibility cannot be validated.',
        ),
      ],
      qualityFlags: const <QualityFlag>[
        QualityFlag(
          label: 'Coherence',
          detail: 'Vegetation lowers InSAR coherence in parts of the area '
              '(sample).',
          level: QualityLevel.warning,
        ),
        QualityFlag(
          label: 'Single look direction',
          detail: 'LOS displacement is one component of three-dimensional '
              'ground motion.',
        ),
      ],
      limitations: const <String>[
        'Line-of-sight displacement is not a landslide prediction.',
        'Susceptibility classes are preliminary and uncalibrated.',
        'Sample geometry is schematic.',
      ],
      processingVersion: 'sample-0.1',
      crs: 'EPSG:32646 (areas) / EPSG:4326 (display)',
    );
    final layers = _slopeLayers(zones, zoneSpecs);
    return MockBundle(
      summary: _summaryOf(analysis),
      analysis: analysis,
      layers: layers,
      validation: const ValidationResult(
        analysisId: 'slope_demo_001',
        status: DataStatus.notEvaluated,
        isSample: true,
        notes: <String>[
          'Susceptibility has not been evaluated against an independent '
              'landslide inventory.',
          'Deformation measurements have no independent ground-truth '
              'comparison in the sample.',
        ],
        limitations: <String>[
          '"Not evaluated" is not a pass: treat the susceptibility layer as '
              'a hypothesis.',
        ],
      ),
      explanation: const ExplanationResult(
        analysisId: 'slope_demo_001',
        status: DataStatus.preliminary,
        isSample: true,
        method: 'Qualitative factor ranking (sample, no numeric attribution)',
        factors: <ContributingFactor>[
          ContributingFactor(
            rank: 1,
            name: 'Slope angle',
            description: 'Steeper slopes are more susceptible in general.',
            direction: 'increases',
          ),
          ContributingFactor(
            rank: 2,
            name: 'Antecedent rainfall',
            description: 'Prolonged rain raises pore pressure in slope '
                'material.',
            direction: 'increases',
          ),
          ContributingFactor(
            rank: 3,
            name: 'Lithology',
            description: 'Weathered, weak material is more prone to failure.',
            direction: 'context',
          ),
          ContributingFactor(
            rank: 4,
            name: 'Distance to drainage',
            description: 'Undercutting near channels can destabilise slopes.',
            direction: 'context',
          ),
          ContributingFactor(
            rank: 5,
            name: 'Observed LOS deformation',
            description: 'Shown as evidence; kept separate from the '
                'susceptibility class.',
            direction: 'context',
          ),
        ],
        caveat: 'Explanations describe associations in the model inputs. '
            'They do not prove causes.',
      ),
      impact: ImpactSummary(
        analysisId: 'slope_demo_001',
        status: DataStatus.preliminary,
        isSample: true,
        zoneImpacts: _zoneImpacts(zones, <List<double?>>[
          <double?>[160, 1.2, 1, 12, 2],
          <double?>[90, 2.4, 0, 5, 1],
          <double?>[30, 0.6, null, 20, 1],
          <double?>[320, 3.8, 1, 60, 3],
        ]),
        dataNotes: _dataNotes(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Builders
  // ---------------------------------------------------------------------
  static List<Observation> _floodObservations(
    List<DateTime> dates,
    List<double> extents,
  ) {
    return <Observation>[
      for (var i = 0; i < dates.length; i++)
        Observation(
          id: 'obs_$i',
          date: dates[i],
          label: 'T$i',
          sensor: 'SAR (sample)',
          floodExtentKm2: extents[i],
        ),
    ];
  }

  static double _round1(double v) => (v * 10).round() / 10;

  /// Change statistics for every ordered pair, derived once from the sample
  /// extents (the real pipeline would supply these values).
  static List<ChangeStat> _changeStats(List<Observation> obs) {
    final out = <ChangeStat>[];
    for (var i = 0; i < obs.length; i++) {
      for (var j = i + 1; j < obs.length; j++) {
        final a = obs[i].floodExtentKm2;
        final b = obs[j].floodExtentKm2;
        final net = (a != null && b != null) ? _round1(b - a) : null;
        final pct = (a != null && b != null && a != 0)
            ? _round1((b - a) / a * 100)
            : null;
        out.add(ChangeStat(
          fromObservationId: obs[i].id,
          toObservationId: obs[j].id,
          areaBeforeKm2: a,
          areaAfterKm2: b,
          netChangeKm2: net,
          percentChange: pct,
        ));
      }
    }
    return out;
  }

  static List<DataSourceRef> _floodSources() => const <DataSourceRef>[
        DataSourceRef(
          label: 'SAR backscatter acquisitions (sample)',
          provider: 'Sample dataset',
          note: 'Illustrative dates; not a real acquisition list.',
        ),
        DataSourceRef(
          label: 'Elevation / terrain (sample)',
          provider: 'Sample dataset',
        ),
        DataSourceRef(
          label: 'Rainfall history (sample)',
          provider: 'Sample dataset',
        ),
        DataSourceRef(
          label: 'Independent reference flood extent',
          note: 'Not linked yet.',
        ),
      ];

  static AnalysisSummary _summaryOf(AnalysisResult a) {
    String? label;
    double? value;
    String? unit;
    if (a.status.hasResult) {
      if (a.hazard == HazardType.floodExpansion &&
          a.firstObservation != null &&
          a.latestObservation != null) {
        final stat =
            a.changeFor(a.firstObservation!.id, a.latestObservation!.id);
        label = 'Net mapped flood-extent change';
        value = stat?.netChangeKm2;
        unit = 'km\u00b2';
      } else if (a.hazard == HazardType.slopeDeformation) {
        label = 'Max cumulative LOS displacement';
        value = a.deformation?.maxLosDisplacementMm;
        unit = 'mm';
      }
    }
    return AnalysisSummary(
      id: a.id,
      hazard: a.hazard,
      studyAreaId: a.studyAreaId,
      title: a.title,
      status: a.status,
      isSample: a.isSample,
      observationCount: a.observations.length,
      latestObservationDate: a.latestObservation?.date,
      headlineLabel: label,
      headlineValue: value,
      headlineUnit: unit,
    );
  }

  static List<HazardZone> _zones(
    HazardType hazard,
    LatLng center,
    List<_ZoneSpec> specs,
    String metricLabel,
    List<Observation> observations,
  ) {
    return <HazardZone>[
      for (final s in specs)
        HazardZone(
          id: s.id,
          name: s.name,
          hazard: hazard,
          rank: s.rank,
          basis: s.basis,
          centroid: _at(center, s.dx, s.dy),
          summary: s.summary,
          areaKm2: s.footprintKm2,
          metricLabel: s.values.isEmpty ? null : metricLabel,
          susceptibilityClass: s.susceptibilityClass,
          evidence: s.evidence,
          valuesByObservation: <String, double>{
            for (var i = 0; i < s.values.length && i < observations.length; i++)
              observations[i].id: s.values[i],
          },
          dataQuality: s.dataQuality,
        ),
    ];
  }

  // ---------------------------------------------------------------------
  // Layers
  // ---------------------------------------------------------------------
  static List<MapLayer> _floodLayers({
    required LatLng center,
    required double aspect,
    required double seed,
    required List<Observation> observations,
    required List<HazardZone> zones,
    required DataStatus predictionStatus,
    required String? predictionReason,
    required double infraScale,
  }) {
    final extents = <double>[
      for (final o in observations) o.floodExtentKm2 ?? 0,
    ];

    final extentFeatures = <LayerFeature>[
      for (var i = 0; i < observations.length; i++)
        LayerFeature(
          id: 'extent_${observations[i].id}',
          kind: GeometryKind.polygon,
          points: _blob(center, extents[i], aspect: aspect, seed: seed),
          styleKey: 'extent',
          observationId: observations[i].id,
        ),
    ];

    final changeFeatures = <LayerFeature>[];
    for (var i = 0; i < observations.length; i++) {
      for (var j = i + 1; j < observations.length; j++) {
        final grew = extents[j] >= extents[i];
        final outer = grew ? j : i;
        final inner = grew ? i : j;
        changeFeatures.add(LayerFeature(
          id: 'change_${i}_$j',
          kind: GeometryKind.polygon,
          points: _blob(center, extents[outer], aspect: aspect, seed: seed),
          holes: <List<LatLng>>[
            _blob(center, extents[inner], aspect: aspect, seed: seed),
          ],
          styleKey: grew ? 'newly_inundated' : 'receded',
          fromObservationId: observations[i].id,
          toObservationId: observations[j].id,
        ));
      }
    }

    final latest = extents.isEmpty ? 0.0 : extents.last;
    final predictionFeatures = predictionStatus.hasResult && latest > 0
        ? <LayerFeature>[
            LayerFeature(
              id: 'expansion_prone_band',
              kind: GeometryKind.polygon,
              points: _blob(center, latest * 1.3, aspect: aspect, seed: seed),
              holes: <List<LatLng>>[
                _blob(center, latest, aspect: aspect, seed: seed),
              ],
              styleKey: 'expansion_prone',
            ),
          ]
        : <LayerFeature>[];

    return <MapLayer>[
      MapLayer(
        id: 'observed_extent',
        label: 'Observed flood extent',
        hazard: HazardType.floodExpansion,
        format: LayerFormat.geojson,
        classification: LayerClassification.observed,
        status: DataStatus.available,
        source: 'SAR flood mask $sampleTag',
        units: 'mapped inundated area',
        description: 'Flood mask at the selected before / after dates. Sample '
            'polygons, not satellite-derived.',
        legend: const <LegendItem>[
          LegendItem(
              key: 'before', label: 'Flooded - before date', colorHex: '#2BB5B8', fillOpacity: 0.40),
          LegendItem(
              key: 'after', label: 'Flooded - after date', colorHex: '#38BDF8', fillOpacity: 0.40),
        ],
        features: extentFeatures,
      ),
      MapLayer(
        id: 'flood_change',
        label: 'Detected change',
        hazard: HazardType.floodExpansion,
        format: LayerFormat.geojson,
        classification: LayerClassification.derived,
        status: DataStatus.available,
        source: 'Change between the selected dates $sampleTag',
        description: 'Area that became inundated or receded between the '
            'selected dates. A change between two dates is not a forecast.',
        legend: const <LegendItem>[
          LegendItem(
              key: 'newly_inundated', label: 'Newly inundated', colorHex: '#F5A524', fillOpacity: 0.60),
          LegendItem(
              key: 'receded', label: 'Receded (no longer inundated)', colorHex: '#5FCB8A', fillOpacity: 0.55),
        ],
        features: changeFeatures,
      ),
      MapLayer(
        id: 'future_expansion',
        label: 'Estimated future expansion',
        hazard: HazardType.floodExpansion,
        format: LayerFormat.geojson,
        classification: LayerClassification.predicted,
        status: predictionStatus,
        source: 'Preliminary sample estimate',
        unavailableReason: predictionReason,
        description: 'Relative expansion-proneness band around the latest '
            'extent. Preliminary and uncalibrated.',
        legend: const <LegendItem>[
          LegendItem(
              key: 'expansion_prone', label: 'Expansion-prone (preliminary)', colorHex: '#A78BFA', fillOpacity: 0.35),
        ],
        features: predictionFeatures,
      ),
      _priorityLayer(HazardType.floodExpansion, zones),
      _infrastructureLayer(center, infraScale, HazardType.floodExpansion),
    ];
  }

  static List<MapLayer> _slopeLayers(
    List<HazardZone> zones,
    List<_ZoneSpec> specs,
  ) {
    final c = _hills;
    // Deformation zones are the three observed zones (not the susceptibility).
    final styleKeys = <String>[
      'deformation_strong',
      'deformation_moderate',
      'deformation_slight',
    ];
    final deformationFeatures = <LayerFeature>[
      for (var i = 0; i < 3; i++)
        LayerFeature(
          id: 'deformation_${specs[i].id}',
          kind: GeometryKind.polygon,
          points: _blob(_at(c, specs[i].dx, specs[i].dy), specs[i].footprintKm2,
              aspect: 1.3, seed: i + 0.4),
          styleKey: styleKeys[i],
          zoneId: specs[i].id,
        ),
    ];
    final suscCenter = _at(c, 0.2, 0.4);
    return <MapLayer>[
      MapLayer(
        id: 'deformation_zones',
        label: 'Observed LOS displacement',
        hazard: HazardType.slopeDeformation,
        format: LayerFormat.geojson,
        classification: LayerClassification.observed,
        status: DataStatus.preliminary,
        source: 'InSAR time series $sampleTag',
        units: 'mm (line of sight, cumulative)',
        description: 'Monitored zones coloured by size of cumulative '
            'line-of-sight displacement over the full period.',
        legend: const <LegendItem>[
          LegendItem(
              key: 'deformation_strong', label: 'Larger displacement', colorHex: '#E5736B', fillOpacity: 0.55),
          LegendItem(
              key: 'deformation_moderate', label: 'Moderate displacement', colorHex: '#E6B450', fillOpacity: 0.50),
          LegendItem(
              key: 'deformation_slight', label: 'Small (near noise level)', colorHex: '#A9BAD0', fillOpacity: 0.45),
        ],
        features: deformationFeatures,
      ),
      MapLayer(
        id: 'susceptibility',
        label: 'Susceptibility (preliminary)',
        hazard: HazardType.slopeDeformation,
        format: LayerFormat.geojson,
        classification: LayerClassification.predicted,
        status: DataStatus.preliminary,
        source: 'Preliminary sample classes',
        description: 'Relative susceptibility classes. Not a probability, '
            'not validated, kept separate from measured displacement.',
        legend: const <LegendItem>[
          LegendItem(
              key: 'susc_high', label: 'Higher relative susceptibility', colorHex: '#8B5CF6', fillOpacity: 0.40),
          LegendItem(
              key: 'susc_moderate', label: 'Moderate relative susceptibility', colorHex: '#A78BFA', fillOpacity: 0.22),
        ],
        features: <LayerFeature>[
          LayerFeature(
            id: 'susc_moderate_1',
            kind: GeometryKind.polygon,
            points: _blob(suscCenter, 9.0, aspect: 1.4, seed: 1.3),
            styleKey: 'susc_moderate',
          ),
          LayerFeature(
            id: 'susc_high_1',
            kind: GeometryKind.polygon,
            points: _blob(_at(c, specs[3].dx, specs[3].dy), specs[3].footprintKm2,
                aspect: 1.3, seed: 3.4),
            styleKey: 'susc_high',
            zoneId: specs[3].id,
          ),
        ],
      ),
      const MapLayer(
        id: 'landslide_probability',
        label: 'Landslide probability',
        hazard: HazardType.slopeDeformation,
        format: LayerFormat.geotiff,
        classification: LayerClassification.predicted,
        status: DataStatus.notAvailable,
        source: 'Not produced',
        unavailableReason: 'A calibrated landslide probability needs an event '
            'inventory and independent validation.',
      ),
      MapLayer(
        id: 'terrain_slope',
        label: 'Steep terrain',
        hazard: HazardType.slopeDeformation,
        format: LayerFormat.geojson,
        classification: LayerClassification.context,
        status: DataStatus.available,
        source: 'DEM-derived slope $sampleTag',
        units: 'degrees',
        defaultVisible: false,
        legend: const <LegendItem>[
          LegendItem(
              key: 'steep', label: 'Slope above 25\u00b0', colorHex: '#9AA7B8', fillOpacity: 0.18),
        ],
        features: <LayerFeature>[
          LayerFeature(
            id: 'steep_band',
            kind: GeometryKind.polygon,
            points: _blob(_at(c, -0.2, 0.1), 11.0, aspect: 2.0, seed: 2.2),
            styleKey: 'steep',
          ),
        ],
      ),
      _priorityLayer(HazardType.slopeDeformation, zones),
      _infrastructureLayer(c, 0.12, HazardType.slopeDeformation),
    ];
  }

  static MapLayer _priorityLayer(HazardType hazard, List<HazardZone> zones) {
    return MapLayer(
      id: 'priority_zones',
      label: 'Priority zones',
      hazard: hazard,
      format: LayerFormat.geojson,
      classification: LayerClassification.derived,
      status: DataStatus.available,
      source: 'Zones listed in the analysis record $sampleTag',
      description: 'Zones that need attention first. Solid outline = observed, '
          'violet outline = estimated.',
      legend: const <LegendItem>[
        LegendItem(
            key: 'zone_observed', label: 'Priority zone (observed)', colorHex: '#FFFFFF', fillOpacity: 0.06),
        LegendItem(
            key: 'zone_predicted', label: 'Priority zone (estimated)', colorHex: '#C4B5FD', fillOpacity: 0.10),
      ],
      features: <LayerFeature>[
        for (final z in zones)
          LayerFeature(
            id: 'zone_${z.id}',
            kind: GeometryKind.polygon,
            points: _blob(z.centroid, z.areaKm2 ?? 1.0,
                aspect: 1.3, seed: (z.rank - 1) + 0.4),
            styleKey: z.basis == ZoneBasis.observed
                ? 'zone_observed'
                : 'zone_predicted',
            zoneId: z.id,
            label: z.name,
          ),
      ],
    );
  }

  static MapLayer _infrastructureLayer(
      LatLng center, double scale, HazardType hazard) {
    LatLng p(double dx, double dy) => _at(center, dx * scale, dy * scale);
    return MapLayer(
      id: 'infrastructure',
      label: 'Infrastructure',
      hazard: hazard,
      format: LayerFormat.geojson,
      classification: LayerClassification.context,
      status: DataStatus.available,
      source: 'Illustrative asset locations $sampleTag',
      defaultVisible: false,
      description: 'Schematic schools, communities and a road. Locations '
          'are illustrative.',
      legend: const <LegendItem>[
        LegendItem(key: 'school', label: 'School', colorHex: '#E6B450'),
        LegendItem(key: 'community', label: 'Community', colorHex: '#5FCB8A'),
        LegendItem(key: 'road', label: 'Road', colorHex: '#E2E8F0'),
      ],
      features: <LayerFeature>[
        LayerFeature(
            id: 'school_1', kind: GeometryKind.point, points: <LatLng>[p(3.0, 5.5)], styleKey: 'school', label: 'School 1'),
        LayerFeature(
            id: 'school_2', kind: GeometryKind.point, points: <LatLng>[p(-5.5, 1.0)], styleKey: 'school', label: 'School 2'),
        LayerFeature(
            id: 'school_3', kind: GeometryKind.point, points: <LatLng>[p(0.5, -7.0)], styleKey: 'school', label: 'School 3'),
        LayerFeature(
            id: 'community_1', kind: GeometryKind.point, points: <LatLng>[p(4.5, 3.0)], styleKey: 'community', label: 'Community 1'),
        LayerFeature(
            id: 'community_2', kind: GeometryKind.point, points: <LatLng>[p(-3.5, 3.5)], styleKey: 'community', label: 'Community 2'),
        LayerFeature(
            id: 'community_3', kind: GeometryKind.point, points: <LatLng>[p(-1.0, -6.0)], styleKey: 'community', label: 'Community 3'),
        LayerFeature(
            id: 'community_4', kind: GeometryKind.point, points: <LatLng>[p(6.0, -2.0)], styleKey: 'community', label: 'Community 4'),
        LayerFeature(
          id: 'road_1',
          kind: GeometryKind.line,
          points: <LatLng>[p(-9, -1), p(-4, 0.5), p(0, 1.5), p(4, 1.0), p(9, 2.5)],
          styleKey: 'road',
          label: 'Road',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Impact
  // ---------------------------------------------------------------------
  static ImpactSummary _floodImpact(
    String analysisId,
    List<HazardZone> zones,
    List<List<double?>> rows,
  ) {
    return ImpactSummary(
      analysisId: analysisId,
      status: DataStatus.preliminary,
      isSample: true,
      zoneImpacts: _zoneImpacts(zones, rows),
      dataNotes: _dataNotes(),
    );
  }

  /// Rows are ordered like [AssetCategory.values]:
  /// buildings, roads (km), schools, agriculture (ha), communities.
  static List<ZoneImpact> _zoneImpacts(
    List<HazardZone> zones,
    List<List<double?>> rows,
  ) {
    return <ZoneImpact>[
      for (var i = 0; i < zones.length && i < rows.length; i++)
        ZoneImpact(
          zoneId: zones[i].id,
          zoneName: zones[i].name,
          basis: zones[i].basis,
          exposures: <ExposureCount>[
            for (var c = 0; c < AssetCategory.values.length; c++)
              ExposureCount(
                category: AssetCategory.values[c],
                value: rows[i][c],
                approximate: true,
                isIllustrative: true,
                note: rows[i][c] == null
                    ? 'No data for this category in this zone $sampleTag.'
                    : null,
              ),
          ],
        ),
    ];
  }

  static List<ExposureDataNote> _dataNotes() => const <ExposureDataNote>[
        ExposureDataNote(
          category: AssetCategory.buildings,
          source: 'Building footprints $sampleTag',
          dataDate: '2024 (sample)',
          coverage: 'Partial: rural buildings may be missing.',
        ),
        ExposureDataNote(
          category: AssetCategory.roads,
          source: 'Road network $sampleTag',
          dataDate: '2024 (sample)',
          coverage: 'Main roads only; tracks are not included.',
        ),
        ExposureDataNote(
          category: AssetCategory.schools,
          source: 'School locations $sampleTag',
          dataDate: '2023 (sample)',
          coverage: 'Registered schools only.',
        ),
        ExposureDataNote(
          category: AssetCategory.agriculture,
          source: 'Cropland land-cover class $sampleTag',
          dataDate: '2024 (sample)',
          coverage: 'Seasonal crops may be misclassified.',
        ),
        ExposureDataNote(
          category: AssetCategory.communities,
          source: 'Settlement polygons $sampleTag',
          dataDate: '2022 (sample)',
          coverage: 'Named communities; population is not estimated.',
        ),
      ];

  // ---------------------------------------------------------------------
  // Geometry helpers (sample geometry only)
  // ---------------------------------------------------------------------
  /// Offsets [c] by kilometres east ([dxKm]) and north ([dyKm]).
  static LatLng _at(LatLng c, double dxKm, double dyKm) {
    final lat = c.latitude + dyKm / 111.0;
    final lng = c.longitude +
        dxKm / (111.0 * math.cos(c.latitude * math.pi / 180.0));
    return LatLng(lat, lng);
  }

  static List<LatLng> _rect(LatLng c, double widthKm, double heightKm) {
    final hw = widthKm / 2;
    final hh = heightKm / 2;
    return <LatLng>[
      _at(c, -hw, -hh),
      _at(c, hw, -hh),
      _at(c, hw, hh),
      _at(c, -hw, hh),
    ];
  }

  /// Wobbly ellipse with the given area. Equal [seed]/[aspect]/centre make
  /// blobs of different areas nest inside each other.
  static List<LatLng> _blob(
    LatLng c,
    double areaKm2, {
    double aspect = 1.0,
    double seed = 0.0,
    double wobble = 0.2,
    int n = 36,
  }) {
    final rKm = math.sqrt(areaKm2 / math.pi);
    final ryKm = rKm * math.sqrt(aspect);
    final rxKm = rKm / math.sqrt(aspect);
    final points = <LatLng>[];
    for (var i = 0; i < n; i++) {
      final t = 2 * math.pi * i / n;
      final w = 1 +
          wobble *
              (0.55 * math.sin(3 * t + seed) +
                  0.30 * math.sin(5 * t + 2 * seed) +
                  0.15 * math.sin(7 * t + 3 * seed));
      points.add(_at(c, rxKm * w * math.cos(t), ryKm * w * math.sin(t)));
    }
    return points;
  }
}

/// Compact description of a sample zone used by the builders above.
class _ZoneSpec {
  const _ZoneSpec({
    required this.id,
    required this.name,
    required this.rank,
    required this.basis,
    required this.dx,
    required this.dy,
    required this.footprintKm2,
    required this.summary,
    required this.evidence,
    required this.values,
    required this.dataQuality,
    this.susceptibilityClass,
  });

  final String id;
  final String name;
  final int rank;
  final ZoneBasis basis;
  final double dx;
  final double dy;
  final double footprintKm2;
  final String summary;
  final List<String> evidence;
  final List<double> values;
  final String dataQuality;
  final String? susceptibilityClass;
}
