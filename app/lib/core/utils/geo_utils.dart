import 'package:latlong2/latlong.dart';

/// Ray-casting point-in-polygon test used for map tap hit-testing.
///
/// This is UI hit-testing only; no hazard calculation is performed here.
bool pointInPolygon(LatLng point, List<LatLng> ring) {
  if (ring.length < 3) return false;
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final yi = ring[i].latitude;
    final xi = ring[i].longitude;
    final yj = ring[j].latitude;
    final xj = ring[j].longitude;
    final crosses = (yi > point.latitude) != (yj > point.latitude);
    if (crosses) {
      final xAtY = (xj - xi) * (point.latitude - yi) / (yj - yi) + xi;
      if (point.longitude < xAtY) inside = !inside;
    }
  }
  return inside;
}
