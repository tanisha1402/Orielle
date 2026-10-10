import '../core/utils/json_utils.dart';
import 'data_status.dart';
import 'hazard_zone.dart';

enum AssetCategory {
  buildings('buildings', 'Buildings', 'buildings'),
  roads('roads', 'Roads', 'km'),
  schools('schools', 'Schools', 'schools'),
  agriculture('agriculture', 'Agriculture', 'ha'),
  communities('communities', 'Communities', 'communities');

  const AssetCategory(this.apiValue, this.label, this.unit);
  final String apiValue;
  final String label;
  final String unit;

  static AssetCategory? tryParse(String? value) {
    for (final c in AssetCategory.values) {
      if (c.apiValue == value) return c;
    }
    return null;
  }
}

/// Potentially exposed amount of one asset category inside one zone.
/// "Potentially exposed" is not "damaged" and not "in danger".
class ExposureCount {
  const ExposureCount({
    required this.category,
    this.value,
    this.approximate = true,
    this.isIllustrative = false,
    this.note,
  });

  final AssetCategory category;

  /// `null` = no data for this category (shown as "Not available").
  final double? value;
  final bool approximate;
  final bool isIllustrative;
  final String? note;

  factory ExposureCount.fromJson(Json json) => ExposureCount(
        category: AssetCategory.tryParse(optString(json, 'category')) ??
            AssetCategory.buildings,
        value: optDouble(json, 'value'),
        approximate: optBool(json, 'approximate', fallback: true),
        isIllustrative: optBool(json, 'is_illustrative'),
        note: optString(json, 'note'),
      );
}

class ZoneImpact {
  const ZoneImpact({
    required this.zoneId,
    required this.zoneName,
    required this.basis,
    required this.exposures,
  });

  final String zoneId;
  final String zoneName;
  final ZoneBasis basis;
  final List<ExposureCount> exposures;

  ExposureCount? exposureFor(AssetCategory category) {
    for (final e in exposures) {
      if (e.category == category) return e;
    }
    return null;
  }

  factory ZoneImpact.fromJson(Json json) => ZoneImpact(
        zoneId: reqString(json, 'zone_id'),
        zoneName: optString(json, 'zone_name') ?? reqString(json, 'zone_id'),
        basis: ZoneBasis.fromApi(optString(json, 'basis')),
        exposures: mapList(json['exposures'], ExposureCount.fromJson),
      );
}

/// Source, date and coverage caveat for one asset category.
class ExposureDataNote {
  const ExposureDataNote({
    required this.category,
    required this.source,
    required this.coverage,
    this.dataDate,
  });

  final AssetCategory category;
  final String source;
  final String coverage;
  final String? dataDate;

  factory ExposureDataNote.fromJson(Json json) => ExposureDataNote(
        category: AssetCategory.tryParse(optString(json, 'category')) ??
            AssetCategory.buildings,
        source: reqString(json, 'source'),
        coverage: optString(json, 'coverage') ?? 'Coverage not stated',
        dataDate: optString(json, 'data_date'),
      );
}

/// `GET /api/v1/analyses/{id}/impact`.
class ImpactSummary {
  const ImpactSummary({
    required this.analysisId,
    required this.status,
    this.isSample = false,
    this.zoneImpacts = const <ZoneImpact>[],
    this.dataNotes = const <ExposureDataNote>[],
    this.disclaimer =
        'Exposure shows assets that intersect a hazard zone. It does not '
            'confirm damage or immediate danger.',
  });

  final String analysisId;
  final DataStatus status;
  final bool isSample;
  final List<ZoneImpact> zoneImpacts;
  final List<ExposureDataNote> dataNotes;
  final String disclaimer;

  ZoneImpact? impactForZone(String? zoneId) {
    if (zoneId == null) return null;
    for (final z in zoneImpacts) {
      if (z.zoneId == zoneId) return z;
    }
    return null;
  }

  ExposureDataNote? noteFor(AssetCategory category) {
    for (final n in dataNotes) {
      if (n.category == category) return n;
    }
    return null;
  }

  factory ImpactSummary.fromJson(Json json) => ImpactSummary(
        analysisId: reqString(json, 'analysis_id'),
        status: DataStatus.fromApi(optString(json, 'status')),
        isSample: optBool(json, 'is_sample'),
        zoneImpacts: mapList(json['zones'], ZoneImpact.fromJson),
        dataNotes: mapList(json['data_notes'], ExposureDataNote.fromJson),
        disclaimer: optString(json, 'disclaimer') ??
            'Exposure shows assets that intersect a hazard zone. It does not '
                'confirm damage or immediate danger.',
      );
}
