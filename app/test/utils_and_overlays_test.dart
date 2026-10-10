import 'package:earth_risk_chain/core/utils/color_utils.dart';
import 'package:earth_risk_chain/core/utils/formatters.dart';
import 'package:earth_risk_chain/core/utils/geo_utils.dart';
import 'package:earth_risk_chain/data/mock/mock_data.dart';
import 'package:earth_risk_chain/features/explore/map_overlays.dart';
import 'package:earth_risk_chain/state/providers.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('formatters', () {
    test('thousands, signs and nulls', () {
      expect(formatThousands(1234567), '1,234,567');
      expect(formatThousands(-26.3, decimals: 1), '-26.3');
      expect(formatKm2(46.5, signed: true), '+46.5 km\u00b2');
      expect(formatKm2(null), 'Not available');
      expect(formatMm(-13.9), '-13.9 mm');
    });

    test('dates', () {
      final d = DateTime(2025, 6, 4);
      expect(formatDate(d), '4 Jun 2025');
      expect(formatIsoDate(d), '2025-06-04');
      expect(daysBetween(DateTime(2025, 6, 14), DateTime(2025, 7, 8)), 24);
    });
  });

  test('colorFromHex and withFraction', () {
    expect(colorFromHex('#38BDF8'), const Color(0xFF38BDF8));
    expect(colorFromHex('bad'), const Color(0xFF9AA7B8));
    expect(withFraction(const Color(0xFF38BDF8), 0.0), const Color(0x0038BDF8));
    expect(withFraction(const Color(0xFF38BDF8), 1.0), const Color(0xFF38BDF8));
  });

  test('pointInPolygon', () {
    final square = <LatLng>[LatLng(0, 0), LatLng(0, 2), LatLng(2, 2), LatLng(2, 0)];
    expect(pointInPolygon(LatLng(1, 1), square), isTrue);
    expect(pointInPolygon(LatLng(3, 1), square), isFalse);
    expect(pointInPolygon(LatLng(1, 1), <LatLng>[LatLng(0, 0)]), isFalse);
  });

  group('buildOverlays (flood_demo_001)', () {
    final bundle = MockData.bundleFor('flood_demo_001')!;
    final visible = <String>{'observed_extent', 'flood_change', 'priority_zones'};
    const full = ObservationSelection(beforeIndex: 0, afterIndex: 2);

    MapOverlays build(CompareMode mode, ObservationSelection? sel, {Set<String>? v}) =>
        buildOverlays(
          analysis: bundle.analysis,
          layers: bundle.layers,
          visible: v ?? visible,
          selection: sel,
          mode: mode,
        );

    test('before / after show one extent plus the zone outlines', () {
      expect(build(CompareMode.before, full).polygons, hasLength(1 + 3));
      expect(build(CompareMode.after, full).polygons, hasLength(1 + 3));
    });

    test('change mode shows after outline, change polygon and zones', () {
      final o = build(CompareMode.change, full);
      expect(o.polygons, hasLength(1 + 1 + 3));
      // The change polygon has a hole (the earlier extent).
      expect(o.polygons.where((p) => (p.holePointsList ?? const []).isNotEmpty), hasLength(1));
    });

    test('same before/after date yields no change polygon', () {
      const same = ObservationSelection(beforeIndex: 1, afterIndex: 1);
      expect(build(CompareMode.change, same).polygons, hasLength(1 + 3));
    });

    test('hidden layers draw nothing; unavailable layer is never drawn', () {
      expect(build(CompareMode.change, full, v: <String>{}).polygons, isEmpty);
      expect(build(CompareMode.change, full, v: <String>{'future_expansion'}).polygons, isEmpty);
    });

    test('infrastructure yields markers and a polyline', () {
      final o = build(CompareMode.change, full, v: <String>{'infrastructure'});
      expect(o.points, hasLength(7));
      expect(o.polylines, hasLength(1));
    });
  });

  test('default layer visibility hides context layers and unavailable layers', () {
    final b = MockData.bundleFor('flood_demo_001')!;
    final v = effectiveVisibleLayers(b.layers, null);
    expect(v, containsAll(<String>['observed_extent', 'flood_change', 'priority_zones']));
    expect(v, isNot(contains('infrastructure')));
    expect(v, isNot(contains('future_expansion')));
  });
}
