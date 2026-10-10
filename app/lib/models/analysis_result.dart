import '../core/utils/json_utils.dart';
import 'data_status.dart';
import 'hazard_type.dart';
import 'hazard_zone.dart';
import 'observation.dart';

/// Row of `GET /api/v1/analyses` (lightweight list item).
class AnalysisSummary {
  const AnalysisSummary({
    required this.id,
    required this.hazard,
    required this.studyAreaId,
    required this.title,
    required this.status,
    this.isSample = false,
    this.observationCount = 0,
    this.latestObservationDate,
    this.headlineLabel,
    this.headlineValue,
    this.headlineUnit,
  });

  final String id;
  final HazardType hazard;
  final String studyAreaId;
  final String title;
  final DataStatus status;
  final bool isSample;
  final int observationCount;
  final DateTime? latestObservationDate;

  /// One observed headline measurement for cards (may be null).
  final String? headlineLabel;
  final double? headlineValue;
  final String? headlineUnit;

  factory AnalysisSummary.fromJson(Json json) => AnalysisSummary(
        id: reqString(json, 'analysis_id'),
        hazard: HazardType.tryParse(optString(json, 'hazard')) ??
            HazardType.floodExpansion,
        studyAreaId: reqString(json, 'study_area'),
        title: optString(json, 'title') ?? reqString(json, 'analysis_id'),
        status: DataStatus.fromApi(optString(json, 'status')),
        isSample: optBool(json, 'is_sample'),
        observationCount: optInt(json, 'observation_count') ?? 0,
        latestObservationDate: optDate(json, 'latest_observation_date'),
        headlineLabel: optString(json, 'headline_label'),
        headlineValue: optDouble(json, 'headline_value'),
        headlineUnit: optString(json, 'headline_unit'),
      );
}

/// Pre-computed change between two observations (flood). Values come from the
/// research pipeline; the app never recomputes them.
class ChangeStat {
  const ChangeStat({
    required this.fromObservationId,
    required this.toObservationId,
    this.areaBeforeKm2,
    this.areaAfterKm2,
    this.netChangeKm2,
    this.percentChange,
  });

  final String fromObservationId;
  final String toObservationId;
  final double? areaBeforeKm2;
  final double? areaAfterKm2;
  final double? netChangeKm2;
  final double? percentChange;

  factory ChangeStat.fromJson(Json json) => ChangeStat(
        fromObservationId: reqString(json, 'from_observation'),
        toObservationId: reqString(json, 'to_observation'),
        areaBeforeKm2: optDouble(json, 'area_before_km2'),
        areaAfterKm2: optDouble(json, 'area_after_km2'),
        netChangeKm2: optDouble(json, 'net_change_km2'),
        percentChange: optDouble(json, 'percent_change'),
      );
}

/// Observed slope deformation summary (line-of-sight, NOT landslide risk).
class DeformationSummary {
  const DeformationSummary({
    required this.losConvention,
    this.maxLosDisplacementMm,
    this.medianLosDisplacementMm,
    this.monitoredAreaKm2,
    this.zoneCount,
    this.noiseNote,
  });

  final String losConvention;
  final double? maxLosDisplacementMm;
  final double? medianLosDisplacementMm;
  final double? monitoredAreaKm2;
  final int? zoneCount;
  final String? noiseNote;

  factory DeformationSummary.fromJson(Json json) => DeformationSummary(
        losConvention: optString(json, 'los_convention') ??
            'Line-of-sight (LOS) displacement along the sensor look direction.',
        maxLosDisplacementMm: optDouble(json, 'max_los_displacement_mm'),
        medianLosDisplacementMm: optDouble(json, 'median_los_displacement_mm'),
        monitoredAreaKm2: optDouble(json, 'monitored_area_km2'),
        zoneCount: optInt(json, 'zone_count'),
        noiseNote: optString(json, 'noise_note'),
      );
}

/// How a prediction value must be read.
enum PredictionKind {
  none('none', 'No prediction'),
  probability('probability', 'Calibrated probability'),
  relativeScore('relative_score', 'Relative score (not a probability)'),
  relativeClass('relative_class', 'Relative class (not a probability)');

  const PredictionKind(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static PredictionKind fromApi(String? value) {
    for (final k in PredictionKind.values) {
      if (k.apiValue == value) return k;
    }
    return PredictionKind.none;
  }
}

/// Model-based estimate (kept separate from observations).
class PredictionInfo {
  const PredictionInfo({
    required this.status,
    this.kind = PredictionKind.none,
    this.label,
    this.forecastHorizon,
    this.mapUrl,
    this.description,
    this.isCalibrated = false,
    this.caveats = const <String>[],
  });

  final DataStatus status;
  final PredictionKind kind;
  final String? label;
  final String? forecastHorizon;
  final String? mapUrl;
  final String? description;
  final bool isCalibrated;
  final List<String> caveats;

  factory PredictionInfo.fromJson(Json json) => PredictionInfo(
        status: DataStatus.fromApi(optString(json, 'status')),
        kind: PredictionKind.fromApi(optString(json, 'kind')),
        label: optString(json, 'label'),
        forecastHorizon: optString(json, 'forecast_horizon'),
        mapUrl: optString(json, 'map_url'),
        description: optString(json, 'description'),
        isCalibrated: optBool(json, 'is_calibrated'),
        caveats: stringList(json['caveats']),
      );
}

enum QualityLevel { info, warning }

class QualityFlag {
  const QualityFlag({
    required this.label,
    required this.detail,
    this.level = QualityLevel.info,
  });

  final String label;
  final String detail;
  final QualityLevel level;

  factory QualityFlag.fromJson(Json json) => QualityFlag(
        label: reqString(json, 'label'),
        detail: optString(json, 'detail') ?? '',
        level: optString(json, 'level') == 'warning'
            ? QualityLevel.warning
            : QualityLevel.info,
      );
}

class DataSourceRef {
  const DataSourceRef({required this.label, this.provider, this.note});

  final String label;
  final String? provider;
  final String? note;

  factory DataSourceRef.fromJson(Json json) => DataSourceRef(
        label: reqString(json, 'label'),
        provider: optString(json, 'provider'),
        note: optString(json, 'note'),
      );
}

/// Full analysis record (`GET /api/v1/analyses/{id}`).
///
/// Field groups are deliberately separate:
/// * observed:  [observations], [changeStats], [deformation]
/// * predicted: [prediction]
/// * validation: [validationStatus] (details at `/validation`)
/// * potential impact lives in `ImpactSummary`, not here.
class AnalysisResult {
  const AnalysisResult({
    required this.id,
    required this.hazard,
    required this.studyAreaId,
    required this.title,
    required this.status,
    required this.prediction,
    required this.validationStatus,
    this.isSample = false,
    this.datasetLabel,
    this.statusNote,
    this.observations = const <Observation>[],
    this.changeStats = const <ChangeStat>[],
    this.deformation,
    this.zones = const <HazardZone>[],
    this.dataSources = const <DataSourceRef>[],
    this.qualityFlags = const <QualityFlag>[],
    this.limitations = const <String>[],
    this.processingVersion,
    this.crs,
  });

  final String id;
  final HazardType hazard;
  final String studyAreaId;
  final String title;
  final DataStatus status;
  final bool isSample;
  final String? datasetLabel;
  final String? statusNote;
  final List<Observation> observations;
  final List<ChangeStat> changeStats;
  final DeformationSummary? deformation;
  final PredictionInfo prediction;
  final DataStatus validationStatus;
  final List<HazardZone> zones;
  final List<DataSourceRef> dataSources;
  final List<QualityFlag> qualityFlags;
  final List<String> limitations;
  final String? processingVersion;
  final String? crs;

  Observation? get firstObservation =>
      observations.isEmpty ? null : observations.first;
  Observation? get latestObservation =>
      observations.isEmpty ? null : observations.last;

  Observation? observationById(String id) {
    for (final o in observations) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Pre-computed change statistics for a pair of observations, if supplied.
  ChangeStat? changeFor(String fromId, String toId) {
    for (final c in changeStats) {
      if (c.fromObservationId == fromId && c.toObservationId == toId) return c;
    }
    return null;
  }

  HazardZone? zoneById(String? id) {
    if (id == null) return null;
    for (final z in zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  /// Zones ordered by rank (highest attention first).
  List<HazardZone> get zonesByRank {
    final sorted = List<HazardZone>.of(zones);
    sorted.sort((a, b) => a.rank.compareTo(b.rank));
    return sorted;
  }

  factory AnalysisResult.fromJson(Json json) {
    final observed = json['deformation'];
    final prediction = json['prediction'];
    final validation = json['validation'];
    final observations = _observationsFrom(json);
    return AnalysisResult(
      id: reqString(json, 'analysis_id'),
      hazard: HazardType.tryParse(optString(json, 'hazard')) ??
          HazardType.floodExpansion,
      studyAreaId: reqString(json, 'study_area'),
      title: optString(json, 'title') ?? reqString(json, 'analysis_id'),
      status: DataStatus.fromApi(optString(json, 'status')),
      isSample: optBool(json, 'is_sample'),
      datasetLabel: optString(json, 'dataset_label'),
      statusNote: optString(json, 'status_note'),
      observations: observations,
      changeStats: _changeStatsFrom(json, observations),
      deformation:
          observed is Map ? DeformationSummary.fromJson(asJson(observed)) : null,
      prediction: prediction is Map
          ? PredictionInfo.fromJson(asJson(prediction))
          : const PredictionInfo(status: DataStatus.notAvailable),
      validationStatus: DataStatus.fromApi(
        validation is Map ? optString(asJson(validation), 'status') : null,
      ),
      zones: mapList(json['zones'], HazardZone.fromJson),
      dataSources: mapList(json['data_sources'], DataSourceRef.fromJson),
      qualityFlags: mapList(json['quality_flags'], QualityFlag.fromJson),
      limitations: stringList(json['limitations']),
      processingVersion: optString(json, 'processing_version'),
      crs: optString(json, 'crs'),
    );
  }
}

/// Reads `observations` (rich objects). If absent, falls back to the minimal
/// roadmap schema `observation_dates: ["YYYY-MM-DD", ...]`.
List<Observation> _observationsFrom(Json json) {
  final rich = mapList(json['observations'], Observation.fromJson);
  if (rich.isNotEmpty) return rich;
  final dates = json['observation_dates'];
  if (dates is! List) return <Observation>[];
  final out = <Observation>[];
  for (var i = 0; i < dates.length; i++) {
    final parsed = dates[i] is String ? DateTime.tryParse(dates[i] as String) : null;
    if (parsed == null) continue;
    out.add(Observation(id: 'obs_$i', date: parsed, label: 'T$i'));
  }
  return out;
}

/// Reads `change_stats`. If absent, maps the roadmap's single
/// `observed_change` object onto first -> last observation.
List<ChangeStat> _changeStatsFrom(Json json, List<Observation> observations) {
  final rich = mapList(json['change_stats'], ChangeStat.fromJson);
  if (rich.isNotEmpty) return rich;
  final single = json['observed_change'];
  if (single is Map && observations.length >= 2) {
    final map = asJson(single);
    return <ChangeStat>[
      ChangeStat(
        fromObservationId: observations.first.id,
        toObservationId: observations.last.id,
        areaBeforeKm2: optDouble(map, 'area_before_km2'),
        areaAfterKm2: optDouble(map, 'area_after_km2'),
        netChangeKm2: optDouble(map, 'net_change_km2'),
        percentChange: optDouble(map, 'percent_change'),
      ),
    ];
  }
  return <ChangeStat>[];
}
