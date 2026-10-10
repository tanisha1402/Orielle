import 'package:earth_risk_chain/core/errors/app_exception.dart';
import 'package:earth_risk_chain/models/analysis_result.dart';
import 'package:earth_risk_chain/models/chat_message.dart';
import 'package:earth_risk_chain/models/data_status.dart';
import 'package:earth_risk_chain/models/hazard_type.dart';
import 'package:earth_risk_chain/models/impact_summary.dart';
import 'package:earth_risk_chain/models/map_layer.dart';
import 'package:earth_risk_chain/models/study_area.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataStatus', () {
    test('parses all documented values', () {
      expect(DataStatus.fromApi('available'), DataStatus.available);
      expect(DataStatus.fromApi('preliminary'), DataStatus.preliminary);
      expect(DataStatus.fromApi('not_available'), DataStatus.notAvailable);
      expect(DataStatus.fromApi('not_evaluated'), DataStatus.notEvaluated);
      expect(DataStatus.fromApi('error'), DataStatus.error);
    });

    test('unknown or missing values never pretend a result exists', () {
      expect(DataStatus.fromApi('pending').hasResult, isFalse);
      expect(DataStatus.fromApi(null), DataStatus.notAvailable);
    });
  });

  group('AnalysisResult.fromJson', () {
    test('accepts the minimal roadmap schema', () {
      final result = AnalysisResult.fromJson(<String, dynamic>{
        'analysis_id': 'flood_demo_001',
        'hazard': 'flood_expansion',
        'study_area': 'selected_floodplain',
        'observation_dates': <String>['2025-06-14', '2025-07-08'],
        'observed_change': <String, dynamic>{
          'area_before_km2': null,
          'area_after_km2': null,
          'net_change_km2': null,
        },
        'prediction': <String, dynamic>{
          'status': 'not_available',
          'forecast_horizon': null,
          'map_url': null,
        },
        'validation': <String, dynamic>{'status': 'not_evaluated'},
        'data_sources': <dynamic>[],
        'limitations': <dynamic>[],
      });
      expect(result.hazard, HazardType.floodExpansion);
      expect(result.observations, hasLength(2));
      expect(result.observations.first.date, DateTime(2025, 6, 14));
      expect(result.prediction.status, DataStatus.notAvailable);
      expect(result.validationStatus, DataStatus.notEvaluated);
      final stat = result.changeFor('obs_0', 'obs_1');
      expect(stat, isNotNull);
      // Unknown measurements stay null, never invented.
      expect(stat!.netChangeKm2, isNull);
    });

    test('parses rich observations and change stats', () {
      final result = AnalysisResult.fromJson(<String, dynamic>{
        'analysis_id': 'a1',
        'hazard': 'slope_deformation',
        'study_area': 'hills',
        'status': 'preliminary',
        'observations': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'o1', 'date': '2025-01-10', 'mean_los_displacement_mm': 0},
          <String, dynamic>{'id': 'o2', 'date': '2025-03-06', 'mean_los_displacement_mm': -2.4},
        ],
        'deformation': <String, dynamic>{'max_los_displacement_mm': -26.3},
        'zones': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'z1',
            'name': 'Zone 1',
            'hazard': 'slope_deformation',
            'rank': 1,
            'basis': 'observed',
            'centroid': <String, dynamic>{'lat': 22.4, 'lng': 91.8},
            'values_by_observation': <String, dynamic>{'o2': -4.2},
          },
        ],
      });
      expect(result.status, DataStatus.preliminary);
      expect(result.deformation!.maxLosDisplacementMm, -26.3);
      expect(result.zones.single.valuesByObservation['o2'], -4.2);
      expect(result.latestObservation!.meanLosDisplacementMm, -2.4);
    });

    test('missing required id throws ParseException', () {
      expect(
        () => AnalysisResult.fromJson(<String, dynamic>{'hazard': 'flood_expansion'}),
        throwsA(isA<ParseException>()),
      );
    });
  });

  group('MapLayer.fromJson', () {
    test('roadmap example: boolean available + url', () {
      final layer = MapLayer.fromJson(<String, dynamic>{
        'id': 'observed_extent',
        'label': 'Observed flood extent',
        'format': 'geotiff',
        'url': '/data/flood_extent_t2.tif',
        'available': true,
      });
      expect(layer.status, DataStatus.available);
      expect(layer.format, LayerFormat.geotiff);
      // Raster layers cannot be drawn in this build and say why.
      expect(layer.isRenderable, isFalse);
      expect(layer.blockedReason, contains('geotiff'));
    });

    test('unavailable layer reports its reason', () {
      final layer = MapLayer.fromJson(<String, dynamic>{
        'id': 'future_expansion',
        'label': 'Estimated future expansion',
        'format': 'geotiff',
        'url': null,
        'available': false,
        'unavailable_reason': 'No validated model.',
      });
      expect(layer.status, DataStatus.notAvailable);
      expect(layer.blockedReason, 'No validated model.');
    });

    test('inline GeoJSON polygon with a hole, line and point', () {
      final layer = MapLayer.fromJson(<String, dynamic>{
        'id': 'l',
        'label': 'L',
        'format': 'geojson',
        'status': 'available',
        'classification': 'derived',
        'legend': <Map<String, dynamic>>[
          <String, dynamic>{'key': 'a', 'label': 'A', 'color': '#FF0000'},
        ],
        'geojson': <String, dynamic>{
          'type': 'FeatureCollection',
          'features': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'Feature',
              'properties': <String, dynamic>{'style_key': 'a', 'zone_id': 'z1'},
              'geometry': <String, dynamic>{
                'type': 'Polygon',
                'coordinates': <dynamic>[
                  <dynamic>[[91.0, 24.0], [91.1, 24.0], [91.1, 24.1], [91.0, 24.0]],
                  <dynamic>[[91.02, 24.02], [91.05, 24.02], [91.05, 24.05], [91.02, 24.02]],
                ],
              },
            },
            <String, dynamic>{
              'type': 'Feature',
              'geometry': <String, dynamic>{
                'type': 'LineString',
                'coordinates': <dynamic>[[91.0, 24.0], [91.1, 24.1]],
              },
            },
            <String, dynamic>{
              'type': 'Feature',
              'geometry': <String, dynamic>{
                'type': 'Point',
                'coordinates': <dynamic>[91.0, 24.0],
              },
            },
          ],
        },
      });
      expect(layer.classification, LayerClassification.derived);
      expect(layer.features, hasLength(3));
      final polygon = layer.features.first;
      expect(polygon.kind, GeometryKind.polygon);
      expect(polygon.holes, hasLength(1));
      // GeoJSON is [lng, lat].
      expect(polygon.points.first.latitude, 24.0);
      expect(polygon.points.first.longitude, 91.0);
      expect(polygon.zoneId, 'z1');
      expect(layer.features[1].kind, GeometryKind.line);
      expect(layer.features[2].kind, GeometryKind.point);
      expect(layer.isRenderable, isTrue);
    });

    test('unsupported geometry throws ParseException', () {
      expect(
        () => LayerFeature.fromGeoJson(<String, dynamic>{
          'geometry': <String, dynamic>{'type': 'MultiPolygon', 'coordinates': <dynamic>[]},
        }),
        throwsA(isA<ParseException>()),
      );
    });
  });

  group('Other models', () {
    test('StudyArea.fromJson', () {
      final area = StudyArea.fromJson(<String, dynamic>{
        'id': 'a',
        'name': 'Area',
        'center': <String, dynamic>{'lat': 24.9, 'lng': 91.87},
        'zoom': 10,
        'hazards': <String>['flood_expansion', 'unknown_hazard'],
      });
      expect(area.supportedHazards, <HazardType>[HazardType.floodExpansion]);
      expect(area.center.latitude, 24.9);
    });

    test('ImpactSummary keeps null counts null', () {
      final impact = ImpactSummary.fromJson(<String, dynamic>{
        'analysis_id': 'a',
        'status': 'preliminary',
        'zones': <Map<String, dynamic>>[
          <String, dynamic>{
            'zone_id': 'z1',
            'basis': 'predicted',
            'exposures': <Map<String, dynamic>>[
              <String, dynamic>{'category': 'schools', 'value': null},
              <String, dynamic>{'category': 'roads', 'value': 12.5, 'is_illustrative': true},
            ],
          },
        ],
      });
      final zone = impact.impactForZone('z1')!;
      expect(zone.exposureFor(AssetCategory.schools)!.value, isNull);
      expect(zone.exposureFor(AssetCategory.roads)!.isIllustrative, isTrue);
      expect(impact.disclaimer, contains('does not'));
    });

    test('AskRequest serialises to the documented body', () {
      const request = AskRequest(question: 'q', analysisId: 'a', selectedZoneId: 'z');
      expect(request.toJson(), <String, dynamic>{
        'question': 'q',
        'analysis_id': 'a',
        'selected_zone_id': 'z',
      });
    });
  });
}
